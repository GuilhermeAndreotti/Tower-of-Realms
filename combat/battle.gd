class_name Battle
extends Node2D
## Batalha de um andar (Floors.current()): a equipe escolhida no seletor
## contra os inimigos do andar. Controles: as teclas da barra (Q/W/E/R),
## ←/→ ou clique troca o alvo. Terminado o andar (vitória ou derrota), o
## resultado aparece e Enter, Esc ou clique voltam ao saguão. Ações com "options" abrem um seletor
## (lista na HUD ou, com "selector": "radial", um anel no próprio lutador):
## ↑/↓ ou 1-9 escolhem (no anel, ←/→ também giram), ←/→ trocam o alvo,
## Enter (ou a tecla da ação) confirma e Esc cancela. W e S não navegam no
## seletor: as teclas da barra têm prioridade (a lente do Andri abre sozinha
## e o W tem que continuar chamando a skill 2).
## A vez, os pontos de skill do time e o alvo ficam aqui; o que cada ação faz
## na arena fica nas CharacterActions de cada um; a HUD só mostra.
## Invocações (Summon) entram na fila e no lado aliado, mas não são da
## equipe: agem sozinhas aqui e não contam para a derrota.

signal action_chosen(action: String)

const MAX_POINTS := 5
const STARTING_POINTS := 3
const QUEUE_SIZE := 7
const LOBBY_SCENE := "res://lobby/lobby.tscn"

## Onde ficam os aliados, por tamanho da equipe (o primeiro vai na frente).
const ALLY_POSITIONS := [
	[Vector2(220, 430)],
	[Vector2(250, 432), Vector2(160, 410)],
	[Vector2(265, 434), Vector2(175, 410), Vector2(110, 436)],
]
## Onde ficam os inimigos, por quantidade (o do meio um pouco à frente).
const ENEMY_POSITIONS := [
	[Vector2(720, 430)],
	[Vector2(650, 420), Vector2(800, 420)],
	[Vector2(590, 410), Vector2(720, 430), Vector2(850, 410)],
]
## Onde ficam as invocações, à frente da equipe (por vaga).
const SUMMON_POSITIONS := [Vector2(345, 458), Vector2(440, 414)]
const CHARGE_COLOR := Color(0.75, 0.65, 1.0)

var team: Array[Combatant] = []
var enemies: Array[Enemy] = []
var fighters: Array[Combatant] = []
var summons: Array[Summon] = []  ## as que estão em campo
var points := STARTING_POINTS
var waiting_for_player := false
var over := false
var active: Combatant  ## aliado da vez (ou o último que agiu)
var target := 0  ## índice entre os inimigos vivos
var ally_target := 0  ## índice em allies_on_field() (ações com alvo "ally")
var option := ""  ## opção escolhida para a ação em execução (elemento, artefato...)
var floor_number := 1  ## número do andar (Floors)
var team_ids: Array[String] = []  ## ids do Roster da equipe, na ordem de `team`
## Resultado da vitória (Progression.reward_victory), dado uma vez só.
var rewards: Array[Dictionary] = []
## Floors.complete() da vitória ({} até lá).
var completion := {}
var _rewarded := false
var _leaving := false  ## já pediu a volta ao saguão (tecla e clique juntos)

var world: Node2D
var hud: BattleHud

var _visuals := {}  ## Combatant -> FighterVisual
var _portraits := {}  ## Combatant -> Texture2D, para a HUD
var _summon_slots := {}  ## Summon -> índice em SUMMON_POSITIONS
var _actions := {}  ## aliado -> CharacterActions
var _focus := ""  ## habilidade com o mouse em cima (prévia de alvos)
var _actor: Combatant
var _choosing := ""  ## ação com o seletor de opções aberto
var _option_index := 0
var _radial: RadialSelector  ## o seletor em anel, quando a ação pede
## Primeiro inimigo que a ação de aliado em curso acertou (ver
## _follow_up_attacks); zerado no começo de cada ação.
var _first_hit: Combatant


func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	var background := Sprite2D.new()
	floor_number = Floors.current()
	var floor_data := Floors.data(floor_number)
	background.texture = load(floor_data.get("background", Floors.DEFAULT_BACKGROUND))
	background.centered = false
	background.scale = Vector2(3, 3)
	world.add_child(background)

	team_ids = Roster.team().slice(0, Floors.max_team(floor_number))
	var ids := team_ids
	var positions: Array = ALLY_POSITIONS[ids.size() - 1]
	# quem está mais ao fundo (y menor) é desenhado antes
	var order := range(ids.size())
	order.sort_custom(func(a: int, b: int) -> bool: return positions[a].y < positions[b].y)
	var ally_visuals := []
	for i in ids.size():
		var data := Roster.data(ids[i])
		var c := Roster.create(ids[i])
		var vs := FighterVisual.new()
		var sp: Dictionary = data.sprite
		vs.setup_animated(c, sp.png, sp.json, sp.foot, sp.height, sp.face)
		vs.position = positions[i]
		team.append(c)
		c.living_allies = living_allies
		ally_visuals.append(vs)
		_visuals[c] = vs
		_actions[c] = (data.actions as GDScript).new(self, c, vs)
	for i in order:
		world.add_child(ally_visuals[i])
	active = team[0]

	enemies = Floors.create_enemies(floor_number)
	var enemy_positions: Array = ENEMY_POSITIONS[clampi(enemies.size(), 1, ENEMY_POSITIONS.size()) - 1]
	for i in enemies.size():
		var vi := FighterVisual.new()
		vi.setup_static(enemies[i], enemies[i].texture)
		vi.position = enemy_positions[i]
		world.add_child(vi)
		_visuals[enemies[i]] = vi

	fighters.append_array(team)
	fighters.append_array(enemies)

	hud = BattleHud.new()
	add_child(hud)
	hud.action_requested.connect(request_action)
	hud.skill_focused.connect(func(action: String) -> void:
		_focus = action
		refresh())
	hud.lobby_requested.connect(_back_to_lobby)
	hud.option_clicked.connect(func(i: int) -> void:
		if i == _option_index:
			confirm_choice()
		else:
			select_option(i))
	for c in _visuals:
		_portraits[c] = _visuals[c].portrait()
	hud.set_portraits(_portraits)
	var names := ", ".join(team.map(func(c: Combatant) -> String: return BattleHud.fighter_name(c)))
	hud.log_line("Andar %d, %s: %s %s os guardiões da Torre." % [floor_number, floor_data.name, names, "meets" if team.size() == 1 else "meet"])
	refresh()
	_run.call_deferred()


# ---------------------------------------------------------------- entrada
func request_action(action: String) -> void:
	if not waiting_for_player:
		return
	if _choosing != "":
		if action == _choosing:
			confirm_choice()
			return
		cancel_choice()
	var h := _skill(active, action)
	if h.has("options") and active.can_use(action, points):
		_choosing = action
		var ids: Array = h.options.map(func(o: Dictionary) -> String: return o.id)
		_option_index = maxi(0, ids.find(h.get("default_option", "")))
		if h.get("selector", "") == "radial":
			_open_radial(action)
		_refresh_choice()
		refresh()
		return
	_confirm(action, "")


## Manda a ação para o turno, se a regra do kit permitir. Devolve se foi.
func _confirm(action: String, op: String) -> bool:
	if active.can_use(action, points):
		var reason := active.invalid_reason(action, op, action_target(action))
		if reason != "":
			hud.warn(reason)
			return false
		hud.trigger(action)
	option = op
	action_chosen.emit(action)
	return true


func select_option(i: int) -> void:
	var options: Array = _skill(active, _choosing).get("options", [])
	if i >= 0 and i < options.size():
		_option_index = i
		_refresh_choice()
		refresh()  # a opção pode mirar outro tipo de alvo


func confirm_choice() -> bool:
	var action := _choosing
	var options: Array = _skill(active, action).get("options", [])
	if action == "" or options.is_empty():
		return false
	if not _confirm(action, options[_option_index].id):
		return false
	_close_choice()
	return true


func cancel_choice() -> void:
	if _choosing != "":
		_close_choice()
		refresh()


func _close_choice() -> void:
	_choosing = ""
	hud.close_options()
	if is_instance_valid(_radial):
		_radial.close()
	_radial = null


## Anel de opções preso ao lutador da vez, no ponto que as ações dele indicam.
func _open_radial(action: String) -> void:
	_radial = RadialSelector.new()
	_radial.position = (_actions[active] as CharacterActions).selector_anchor(action)
	_radial.option_focused.connect(select_option)
	_radial.option_clicked.connect(func(i: int) -> void:
		select_option(i)
		confirm_choice())
	_visuals[active].add_child(_radial)


## Mostra o seletor com o motivo de cada opção não servir no alvo atual.
func _refresh_choice() -> void:
	var h := _skill(active, _choosing)
	var chosen_target := action_target(_choosing)
	var reasons: Array[String] = []
	for o: Dictionary in h.options:
		reasons.append(active.invalid_reason(_choosing, o.id, chosen_target))
	# escolha sobre si mesmo (a lente, por exemplo) não precisa mostrar alvo
	var target_name := chosen_target.name if chosen_target and target_type(_choosing) != "self" else ""
	if is_instance_valid(_radial):
		_radial.display(h.options, _option_index, reasons)
	else:
		hud.show_options(h, _option_index, reasons, target_name)


func _unhandled_input(event: InputEvent) -> void:
	if over:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
				_back_to_lobby()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if _choosing != "":
			var n: int = _skill(active, _choosing).get("options", []).size()
			var step := 0
			match event.keycode:
				KEY_UP: step = -1
				KEY_DOWN: step = 1
				KEY_LEFT, KEY_A: step = -1 if is_instance_valid(_radial) else 0
				KEY_RIGHT, KEY_D: step = 1 if is_instance_valid(_radial) else 0
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: confirm_choice()
				KEY_ESCAPE: cancel_choice()
			if step != 0:
				# no anel, ←/→ giram o tambor em vez de trocar o alvo
				select_option(posmod(_option_index + step, n))
				return
			if event.keycode >= KEY_1 and event.keycode <= KEY_9:
				select_option(event.keycode - KEY_1)
		match event.keycode:
			KEY_LEFT, KEY_A: _change_target(-1)
			KEY_RIGHT, KEY_D: _change_target(1)
			_:
				# teclas das habilidades vêm do kit de quem está na vez
				var key := OS.get_keycode_string(event.keycode)
				for h in active.skills(points):
					if h.key == key:
						request_action(h.action)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var on_ally := _aiming_at_ally()
		var alive: Array = allies_on_field() if on_ally else living_enemies()
		for i in alive.size():
			var v: FighterVisual = _visuals[alive[i]]
			var area := Rect2(v.position.x - 60, v.position.y - v.height - 20, 120, v.height + 30)
			if area.has_point(get_global_mouse_position()):
				if on_ally:
					ally_target = i
				else:
					target = i
				_on_target_changed()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_choice()


## A ação em foco (ou no seletor) mira um aliado?
func _aiming_at_ally() -> bool:
	var action := _choosing if _choosing != "" else _focus
	return target_type(action) == "ally"


## Tipo de alvo de `action` do aliado da vez: o da opção marcada no seletor,
## se ela tiver um, ou o da própria ação.
func target_type(action: String) -> String:
	var h := _skill(active, action)
	if action != "" and action == _choosing:
		var options: Array = h.get("options", [])
		if _option_index < options.size() and (options[_option_index] as Dictionary).has("target"):
			return options[_option_index].target
	return h.get("target", "")


func _change_target(direction: int) -> void:
	if _aiming_at_ally():
		var n := allies_on_field().size()
		if n > 0:
			ally_target = posmod(ally_target + direction, n)
	else:
		var n := living_enemies().size()
		if n > 0:
			target = posmod(target + direction, n)
	_on_target_changed()


func _on_target_changed() -> void:
	if _choosing != "":
		_refresh_choice()
	refresh()


## Volta ao saguão pela porta, onde os eventos de história pendentes rodam.
func _back_to_lobby() -> void:
	if not over or _leaving:
		return
	_leaving = true
	Engine.set_meta(Lobby.ENTRANCE_META, "door")
	get_tree().change_scene_to_file(LOBBY_SCENE)


# ------------------------------------------------------------ fluxo da luta
func living_enemies() -> Array[Enemy]:
	return enemies.filter(func(i: Enemy) -> bool: return i.is_alive())


func living_allies() -> Array[Combatant]:
	return team.filter(func(c: Combatant) -> bool: return c.is_alive())


## Quem os inimigos podem atacar e as ações "ally" podem mirar: a equipe
## de pé e as invocações em campo.
func allies_on_field() -> Array[Combatant]:
	var list := living_allies()
	for inv in summons:
		if inv.in_play():
			list.append(inv)
	return list


func _run() -> void:
	await wait(0.6)
	while not over:
		_actor = TurnQueue.next(fighters)
		TurnQueue.advance_to(fighters, _actor)
		var summoned := _actor as Summon
		if _actor.ally and not summoned:
			active = _actor
		refresh()
		if summoned:
			_first_hit = null
			await summon_strike(summoned, summoned.strike)
			await _follow_up_attacks(summoned)
		elif _actor.ally:
			await _ally_turn(_actor)
		else:
			await _enemy_turn(_actor as Enemy)
		_actor.reset_av()
		if _actor.is_alive():
			_pass_turn(_actor)
		if summoned and summoned.in_play() and summoned.consume_turn():
			hud.log_line("%s volta ao abismo." % BattleHud.fighter_name(summoned))
			await last_act(summoned)
			remove_summon(summoned)
		_check_end()
		refresh()
		await wait(0.25)


func _ally_turn(a: Combatant) -> void:
	var actions: CharacterActions = _actions[a]
	if not await actions.start_turn():
		if not a.is_alive():
			await _fall(a)
		return

	ally_target = maxi(0, allies_on_field().find(a))  # o próprio, por padrão
	waiting_for_player = true
	refresh()
	# escolhas de começo de turno (ex.: a lente do Andri) abrem sozinhas;
	# usar outra ação direto fecha o seletor e mantém a escolha anterior
	for h in a.skills(points):
		if h.get("on_turn_start", false) and a.can_use(h.action, points):
			request_action(h.action)
			break
	while true:
		var action: String = await action_chosen
		if not a.can_use(action, points):
			continue
		var h := _skill(a, action)
		waiting_for_player = false
		_focus = ""
		points -= h.get("point_cost", 0)
		refresh()
		_first_hit = null
		await actions.execute(action)
		await _follow_up_attacks(a)
		points = mini(MAX_POINTS, points + h.get("point_gain", 0))
		a.start_cooldown(action, h.get("cooldown", 0))
		if over or not h.get("free", false):
			break
		waiting_for_player = true
		refresh()
	actions.end_turn()


func _skill(a: Combatant, action: String) -> Dictionary:
	for h in a.skills(points):
		if h.action == action:
			return h
	return {}


func _enemy_turn(ini: Enemy) -> void:
	var vi: FighterVisual = _visuals[ini]
	var strike := ini.next_strike()
	var victim := ini.choose_target(allies_on_field())
	ini.count_action()
	if strike.heavy:
		hud.log_line("%s concentra energia para um %s!" % [BattleHud.fighter_name(ini), BattleHud.highlight("Golpe Pesado", UIStyle.EFFECT_TYPE_COLORS.alert)])
		vi.flash(Color(2.5, 0.8, 1.6))
		CombatEffects.ring(world, vi.position + Vector2(0, -vi.height * 0.5), UIStyle.EFFECT_TYPE_COLORS.alert, vi.height * 0.7)
		await wait(0.5)
	else:
		hud.log_line("%s utilizou %s em %s." % [BattleHud.fighter_name(ini), strike.name, BattleHud.fighter_name(victim)])
	var origin := vi.position
	var va: FighterVisual = _visuals[victim]
	await vi.move_to(Vector2(va.position.x + 110, origin.y), 0.25)
	CombatEffects.impact(world, va.position + Vector2(10, -va.height * 0.5),
		UIStyle.EFFECT_TYPE_COLORS.alert if strike.heavy else CHARGE_COLOR, 1.4 if strike.heavy else 1.0)
	await apply_damage(ini, victim, strike.mult, strike.type)
	victim.gain_energy(victim.energy_on_hit)
	if strike.heavy:
		shake(8.0)
	await wait(0.15)
	await vi.move_to(origin, 0.3)


## `attack_type` é o tipo de dano (Types); "" = o tipo do atacante.
## Um golpe: tipo, efetividade (com fraquezas), crítico e escudo. Depois,
## se não for `extra`, os estados de acerto e os golpes adicionais do
## atacante (cada adicional entra aqui com extra = true: não se encadeia).
func apply_damage(attacker: Combatant, victim: Combatant, mult: float, attack_type := "", extra := false) -> void:
	if not victim.is_alive():
		return
	if attack_type == "":
		attack_type = attacker.type
	var critical := not extra and randf() < attacker.crit_chance()
	var damage := Combatant.calculate_damage(attacker, victim, mult, randf(), attack_type, critical)
	var effectiveness := victim.effectiveness_against(attack_type)
	var absorbed := victim.absorb(damage)
	victim.take_damage(damage - absorbed)
	if attacker.ally and not victim.ally and not extra and _first_hit == null:
		_first_hit = victim
	var v: FighterVisual = _visuals[victim]
	var type := "taken" if victim.ally else ("damage" if mult >= 1.0 else "weak")
	if (effectiveness > 1.0 or critical) and not victim.ally:
		type = "critical"
	if extra:
		CombatEffects.impact(world, v.position + Vector2(0, -v.height * 0.5), Types.color(attack_type), 0.8)
	if absorbed > 0:
		CombatEffects.number(world, v.top() + Vector2(0, 20), "(%d)" % absorbed, "shield")
	if damage > absorbed:
		CombatEffects.number(world, v.top(), str(damage - absorbed) + ("!" if critical else ""), type)
	var notice := ""
	if effectiveness > 1.0:
		notice = " " + BattleHud.highlight("Super efetivo!", UIStyle.CRITICAL_DAMAGE)
		CombatEffects.number(world, v.top() + Vector2(0, -26), "SUPER EFETIVO", "effective")
	elif effectiveness < 1.0:
		notice = " " + BattleHud.highlight("Pouco efetivo...", UIStyle.DIM_TEXT)
		CombatEffects.number(world, v.top() + Vector2(0, -26), "pouco efetivo", "not_very_effective")
	if critical:
		notice += " " + BattleHud.highlight("Crítico!", UIStyle.CRITICAL_DAMAGE)
	if absorbed > 0:
		notice += " O escudo absorveu %s." % BattleHud.highlight(str(absorbed), CombatEffects.NUMBERS.shield[0])
	hud.log_line("%s recebeu %s de dano %s.%s" % [BattleHud.fighter_name(victim),
		BattleHud.highlight(str(damage - absorbed), CombatEffects.NUMBERS[type][0]),
		BattleHud.highlight(Types.name(attack_type), Types.color(attack_type)), notice])
	if victim.is_alive():
		v.take_hit()
	else:
		await _fall(victim)
	target = clampi(target, 0, maxi(0, living_enemies().size() - 1))
	refresh()
	if victim is Enemy:
		await _last_resort(victim as Enemy)
	if extra or not victim.is_alive():
		return
	for e in attacker.on_hit_statuses():
		victim.apply_status(e)
		hud.log_line("%s ficou %s." % [BattleHud.fighter_name(victim), BattleHud.highlight(e.name, UIStyle.effect_color(e.description()))])
	for g in attacker.extra_strikes(mult):
		await wait(0.08)
		hud.log_line("%s: dano extra de %s." % [g.source, BattleHud.highlight(Types.name(g.type), Types.color(g.type))])
		await apply_damage(attacker, victim, g.mult, g.type, true)


## Último recurso do inimigo (Enemy.last_resort), se o golpe o deixou
## abaixo da fração: anúncio no meio da tela e o escudo nele.
func _last_resort(ini: Enemy) -> void:
	var e := ini.activate_last_resort()
	if e == null:
		return
	ini.apply_status(e)
	var vi: FighterVisual = _visuals[ini]
	hud.announce("%s ativado" % e.name, Enemy.LAST_RESORT_COLOR, 34)
	vi.flash(Color(2.0, 2.1, 2.6))
	CombatEffects.ring(world, vi.position + Vector2(0, -vi.height * 0.5), Enemy.LAST_RESORT_COLOR, maxf(50.0, vi.height * 0.6))
	CombatEffects.number(world, vi.top() + Vector2(0, -10), "+%d" % e.shield, "shield")
	hud.log_line("%s ativou %s: escudo de %s." % [BattleHud.fighter_name(ini), BattleHud.highlight(e.name, Enemy.LAST_RESORT_COLOR),
		BattleHud.highlight(str(e.shield), CombatEffects.NUMBERS.shield[0])])
	refresh()
	await wait(0.35)


## Ataque em conjunto (Combatant.follow_up): a ação de `actor` acertou um
## inimigo, e quem da equipe tiver como ataca junto o primeiro atingido. Se
## ele já caiu, ninguém ataca.
func _follow_up_attacks(actor: Combatant) -> void:
	var hit_enemy := _first_hit
	_first_hit = null
	if hit_enemy == null:
		return
	for c in living_allies():
		if over or not hit_enemy.is_alive():
			return
		var g := c.follow_up(actor, hit_enemy)
		if not g.is_empty():
			await (_actions[c] as CharacterActions).follow_up(hit_enemy, g)


## Fim do turno de `c`: os estados genéricos perdem um turno.
func _pass_turn(c: Combatant) -> void:
	for e in c.pass_turn():
		hud.log_line("%s de %s acabou." % [e.name, BattleHud.fighter_name(c)])


func current_ally() -> Combatant:
	var alive := allies_on_field()
	return alive[clampi(ally_target, 0, alive.size() - 1)] if not alive.is_empty() else null


## Quem a ação `action` do aliado da vez tem como alvo principal.
func action_target(action: String) -> Combatant:
	match target_type(action):
		"ally": return current_ally()
		"self": return active
	var alive := living_enemies()
	return alive[target] if not alive.is_empty() else null


func _fall(c: Combatant) -> void:
	hud.log_line("%s foi derrotado." % BattleHud.fighter_name(c) if not c.ally else "%s caiu." % BattleHud.fighter_name(c))
	if c is Summon:
		await last_act(c as Summon)
		remove_summon(c as Summon)
		return
	_visuals[c].die()
	if not c.ally:
		for a in living_allies():
			var gain := a.on_enemy_fallen()
			if gain != "":
				hud.log_line("%s absorve %s." % [BattleHud.fighter_name(a), gain])
	else:
		# quem invocou leva as invocações junto
		for inv in summons.duplicate():
			if inv.summoner == c:
				hud.log_line("%s se desfaz." % BattleHud.fighter_name(inv))
				remove_summon(inv)
	if c == active and not living_allies().is_empty():
		active = living_allies()[0]
	_check_end()


func _check_end() -> void:
	if over:
		return
	if living_enemies().is_empty():
		_finish(true, "Andar %d concluído!" % floor_number)
	elif living_allies().is_empty():
		_finish(false, "%s caiu..." % team[0].name if team.size() == 1 else "A equipe caiu...")


func _finish(victory: bool, text: String) -> void:
	over = true
	waiting_for_player = false
	if victory:
		_reward()
	var extras: Array[String] = []
	if not completion.is_empty():
		if completion.unlocked_floor > 0:
			extras.append("Andar %d liberado: %s" % [completion.unlocked_floor, Floors.data(completion.unlocked_floor).name])
			if completion.limit_after > completion.limit_before:
				extras.append("Limite de nível: %d → %d" % [completion.limit_before, completion.limit_after])
		elif completion.first and floor_number == Floors.total():
			extras.append("Você chegou ao topo da Torre, por enquanto.")
		for e: Dictionary in completion.events:
			var line := StoryEvents.summary(e)
			if line != "":
				extras.append(line)
	hud.show_end(victory, text, rewards, extras)
	refresh()


## XP da vitória para toda a equipe que lutou (inclusive quem caiu). Uma vez
## por batalha: chamadas repetidas não dão de novo.
func _reward() -> void:
	if _rewarded:
		return
	_rewarded = true
	# XP antes do andar: quem chega pela história entra no nível já com a XP desta luta
	rewards = Progression.reward_victory(team_ids, enemies)
	completion = Floors.complete(floor_number)
	for r in rewards:
		if not r.took_part:
			continue
		var c := team[team_ids.find(r.id)]
		hud.log_line("%s recebeu %s." % [BattleHud.fighter_name(c), BattleHud.highlight("%d XP" % r.xp_gained, UIStyle.XP)])
		if r.at_limit and r.level == r.level_before:
			hud.log_line("%s está no limite de nível da Torre (%d)." % [BattleHud.fighter_name(c), r.limit])
		if r.level > r.level_before:
			hud.log_line("%s subiu para o %s!" % [BattleHud.fighter_name(c), BattleHud.highlight("nível %d" % r.level, UIStyle.GOLD)])
			var v: FighterVisual = _visuals[c]
			v.flash(Color(2.2, 1.9, 0.9))
			CombatEffects.number(world, v.top() + Vector2(0, -10), "NÍVEL %d!" % r.level, "level")


# ------------------------------------------------------------- invocações
## Põe `inv` em campo, na primeira vaga livre, surgindo num círculo da cor dela.
func add_summon(inv: Summon) -> void:
	var slot := 0
	while _summon_slots.values().has(slot):
		slot += 1
	_summon_slots[inv] = slot
	var vi := FighterVisual.new()
	vi.setup_static(inv, inv.texture)
	vi.position = SUMMON_POSITIONS[mini(slot, SUMMON_POSITIONS.size() - 1)]
	vi.modulate.a = 0.0
	world.add_child(vi)
	_visuals[inv] = vi
	_portraits[inv] = vi.portrait()
	summons.append(inv)
	fighters.append(inv)
	var aura := CombatEffects.aura(vi, [Color(inv.color, 0.5), inv.color.lightened(0.3), inv.color.lightened(0.6)])
	aura.level = 1
	CombatEffects.charge(world, vi.position + Vector2(0, -vi.height * 0.5), [inv.color, Color.WHITE], 0.35, 90.0)
	await wait(0.3)
	CombatEffects.ring(world, vi.position + Vector2(0, -8), inv.color, maxf(50.0, vi.height * 0.6))
	vi.flash(Color(1.0 + inv.color.r, 1.0 + inv.color.g, 1.0 + inv.color.b))
	create_tween().tween_property(vi, "modulate:a", 1.0, 0.25)
	refresh()
	await wait(0.3)


## Tira `inv` de campo (tempo, queda, substituída): some da arena e da fila.
func remove_summon(inv: Summon) -> void:
	inv.on_field = false
	summons.erase(inv)
	fighters.erase(inv)
	_summon_slots.erase(inv)
	var vi: FighterVisual = _visuals.get(inv)
	if vi:
		_visuals.erase(inv)
		vi.die()
		get_tree().create_timer(0.7).timeout.connect(vi.queue_free)
	ally_target = clampi(ally_target, 0, maxi(0, allies_on_field().size() - 1))
	refresh()


## `inv` usa o golpe `g` (Summon.strike) a partir do inimigo marcado:
## avança ou atira e, se tiver, deixa o debuff no alvo principal.
func summon_strike(inv: Summon, g: Dictionary) -> void:
	var targets := inv.targets(g, living_enemies(), target)
	if targets.is_empty() or not _visuals.has(inv):
		return
	var vi: FighterVisual = _visuals[inv]
	var main: Combatant = targets[0][0]
	var debuffed: Array = targets.map(func(pair: Array) -> Combatant: return pair[0]) if g.get("debuff_all", false) else [main]
	hud.log_line("%s utilizou %s." % [BattleHud.fighter_name(inv), BattleHud.highlight(g.name, inv.color)])
	if g.get("style", "projectile") == "charge":
		# avança até cada alvo, do mais perto ao mais longe, e golpeia; o
		# corte acompanha o tamanho da invocação
		var origin := vi.position
		var in_order := targets.duplicate()
		in_order.sort_custom(func(x: Array, y: Array) -> bool: return _visuals[x[0]].position.x < _visuals[y[0]].position.x)
		var radius := maxf(46.0, vi.height * 0.45)
		for pair: Array in in_order:
			var va: FighterVisual = _visuals[pair[0]]
			await vi.move_to(Vector2(va.position.x - 110, origin.y), 0.22 if pair == in_order[0] else 0.14)
			CombatEffects.slash(world, va.position + Vector2(0, -va.height * 0.5), inv.color, radius, randf_range(-0.6, 0.6))
			CombatEffects.impact(world, va.position + Vector2(0, -va.height * 0.5), inv.color, 1.2 if radius > 46.0 else 0.8)
			if radius > 46.0:
				shake(3.0)
			await apply_damage(inv, pair[0], pair[1])
		await wait(0.1)
		await vi.move_to(origin, 0.25)
	else:
		vi.flash(Color(1.0 + inv.color.r, 1.0 + inv.color.g, 1.0 + inv.color.b))
		var from := vi.position + Vector2(18, -vi.height * 0.6)
		var flight := 0.0
		for pair: Array in targets:
			var va: FighterVisual = _visuals[pair[0]]
			flight = maxf(flight, CombatEffects.projectile(world, from, va.position + Vector2(0, -va.height * 0.5), inv.type, 1000.0, 1.1))
		await wait(flight)
		for pair: Array in targets:
			var va: FighterVisual = _visuals[pair[0]]
			CombatEffects.elemental_impact(world, va.position + Vector2(0, -va.height * 0.5), inv.type, 1.0)
			await apply_damage(inv, pair[0], pair[1])
	for victim: Combatant in debuffed:
		if not inv.debuff.is_valid() or not victim.is_alive():
			continue
		var e: StatusEffect = inv.debuff.call()
		victim.apply_status(e)
		CombatEffects.ring(world, _visuals[victim].position + Vector2(0, -_visuals[victim].height * 0.5), UIStyle.effect_color(e.description()), 40.0)
		hud.log_line("%s ficou %s." % [BattleHud.fighter_name(victim), BattleHud.highlight(e.name, UIStyle.effect_color(e.description()))])
	refresh()


## Último ato de `inv` (Summon.last_act). Chame antes de tirar de
## campo: o golpe sai do visual dela.
func last_act(inv: Summon) -> void:
	var g := inv.last_act
	if g.is_empty() or not _visuals.has(inv) or over:
		return
	if g.has("mult"):
		await summon_strike(inv, g)
	else:
		hud.log_line("%s utilizou %s." % [BattleHud.fighter_name(inv), BattleHud.highlight(g.name, inv.color)])
	if g.has("shield"):
		var receiver := inv.shield_target(allies_on_field())
		if receiver:
			var e := inv.last_act_shield(g)
			receiver.apply_status(e)
			var vq: FighterVisual = _visuals[receiver]
			CombatEffects.line(world, _visuals[inv].position + Vector2(0, -_visuals[inv].height * 0.5), vq.position + Vector2(0, -vq.height * 0.5), inv.color, 0.5)
			CombatEffects.ring(world, vq.position + Vector2(0, -vq.height * 0.5), inv.color, 50.0)
			vq.flash(Color(1.0 + inv.color.r, 1.0 + inv.color.g, 1.0 + inv.color.b))
			hud.log_line("%s recebe um escudo de %s." % [BattleHud.fighter_name(receiver), BattleHud.highlight(str(e.shield), CombatEffects.NUMBERS.shield[0])])
			refresh()
			await wait(0.4)


# ------------------------------------------------------------------ apoio
func visual(c: Combatant) -> FighterVisual:
	return _visuals[c]


func current_target() -> Enemy:
	return living_enemies()[target]


## Quem a ação `action` do aliado da vez atingiria, pelo tipo de alvo dela.
func _predicted(action: String) -> Array:
	var alive := living_enemies()
	var from_kit := active.predicted_targets(action, alive, target)
	if not from_kit.is_empty():
		return from_kit
	match target_type(action):
		"ally": return [current_ally()]
		"single": return [alive[target]]
		"neighbors": return alive.slice(maxi(0, target - 1), target + 2)
		"all": return alive
		"self": return [active]
	return []


func refresh() -> void:
	var alive := living_enemies()
	var on_ally := _aiming_at_ally()
	for i in enemies.size():
		_visuals[enemies[i]].marked = waiting_for_player and not on_ally and enemies[i].is_alive() and alive.find(enemies[i]) == target
	var aimed := current_ally() if waiting_for_player and on_ally else null
	for c in team:
		_visuals[c].marked = c == aimed
	for c in summons:
		_visuals[c].marked = c == aimed
	# prévia: quem a habilidade em foco (ou no seletor) atingiria
	var action := _choosing if _choosing != "" else _focus
	# lista sem tipo: _predicted pode devolver a de inimigos (tipada), e
	# perguntar por um aliado nela dá erro
	var hit_targets: Array = []
	if waiting_for_player and not alive.is_empty():
		hit_targets.append_array(_predicted(action))
	for c in fighters:
		_visuals[c].highlighted = c in hit_targets
	for c in team:
		_visuals[c].acting = c == _actor and team.size() > 1
	var queue := TurnQueue.forecast(fighters, QUEUE_SIZE)
	hud.refresh(active, team, points, MAX_POINTS, queue, _actor, waiting_for_player)
	hud.set_objective("Andar %d  ·  Derrote os guardiões  ·  %d/%d restantes" % [floor_number, alive.size(), enemies.size()])


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func shake(strength: float) -> void:
	var t := create_tween()
	for i in 6:
		t.tween_property(world, "position", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.04)
	t.tween_property(world, "position", Vector2.ZERO, 0.05)

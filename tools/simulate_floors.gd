extends SceneTree
## Simula os andares com a batalha de verdade (regras, fila, kits e
## inimigos reais) e um piloto automático no lugar do jogador. Serve para
## comparar a dificuldade entre andares e níveis; não substitui jogar.
## Rodar: godot --headless --path . -s tools/simulate_floors.gd -- [rodadas] [andar:nivel ...] [team=id,id]
## Sem cenários, roda cada andar no nível sem treino, no limite e 1 abaixo.
## Sem equipe, usa os primeiros liberados do Roster que o andar aceita; com
## ela, os dessa lista que já estiverem liberados no andar.
##
## O piloto joga razoavelmente bem, sem ser ótimo:
##  - foca o inimigo com menos HP;
##  - Shumi: entra no Kaioken x2 com HP acima de 60%; Bang! quando sai da
##    recarga, sem o Bang! ativo, com 2+ pontos e outro aliado em campo; Engo-ji com ponto sobrando e
##    2+ inimigos (ou no Kaioken); se não, Corte;
##  - Andri: lente mais efetiva no alvo; Protocolo: Escudo em quem estiver
##    abaixo de 50%; Análise (Fogo) quando nenhuma lente é super efetiva e o
##    alvo ainda tem muito HP; Sobrecarga com 2+ pontos; Arsenal: Freya em
##    quem estiver abaixo de 50%, se não Lança de Rá em quem bate mais;
##  - Askara: Lorde assim que der; se não, com ponto e vaga, Shivara (3
##    fragmentos) ou, sem nada em campo, Emissário (2); se não, Seta Vil.

const SPEED := 40.0  ## Engine.time_scale durante a simulação
const TIME_LIMIT := 600.0  ## segundos de jogo por batalha (com a escala)

var _rounds := 12
var _scenarios: Array[Vector2i] = []  ## (andar, nível)
var _scenario_i := 0
var _round_i := 0
var _battle: Battle
var _time := 0.0
var _turns := 0
var _results := {}  ## Vector2i -> [{"won", "turns", "hp"}]
var _teams := {}  ## Vector2i -> "shumi+andri"
var _requested_team: Array[String] = []  ## team=... na linha de comando


func _initialize() -> void:
	Progression.file = "user://simulacao_progresso.cfg"
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("team="):
			for id in a.trim_prefix("team=").split(","):
				_requested_team.append(id)
		elif a.is_valid_int():
			_rounds = a.to_int()
		elif ":" in a:
			var p := a.split(":")
			_scenarios.append(Vector2i(p[0].to_int(), p[1].to_int()))
	if _scenarios.is_empty():
		for n in range(1, Floors.total() + 1):
			for level in _test_levels(n):
				_scenarios.append(Vector2i(n, level))
	Engine.time_scale = SPEED
	_next()


## Monta a próxima batalha (ou encerra e imprime a tabela).
func _next() -> void:
	if _scenario_i >= _scenarios.size():
		_print()
		Progression.delete()
		quit()
		return
	var c := _scenarios[_scenario_i]
	_prepare_save(c.x, c.y)
	_teams[c] = "+".join(Roster.team().slice(0, Floors.max_team(c.x)))
	seed(1000 * c.x + 37 * c.y + _round_i)
	_battle = (load("res://combat/battle.tscn") as PackedScene).instantiate()
	root.add_child(_battle)
	current_scene = _battle
	_time = 0.0
	_turns = 0


func _process(delta: float) -> bool:
	if _battle == null:
		return false
	_time += delta
	if _battle.over or _time > TIME_LIMIT:
		_log_line()
		return false
	if _battle.waiting_for_player:
		_pilot()
	return false


func _log_line() -> void:
	var c := _scenarios[_scenario_i]
	var hp := 0.0
	var max_hp := 0.0
	for a in _battle.team:
		hp += a.hp
		max_hp += a.max_hp
	if not _results.has(c):
		_results[c] = []
	_results[c].append({"won": _battle.over and _battle.living_enemies().is_empty(),
		"turns": _turns, "hp": hp / max_hp})
	_battle.queue_free()
	_battle = null
	_round_i += 1
	if _round_i >= _rounds:
		_round_i = 0
		_scenario_i += 1
	_next.call_deferred()


# ---------------------------------------------------------------- piloto
func _pilot() -> void:
	var b := _battle
	var a := b.active
	var alive := b.living_enemies()
	if alive.is_empty():
		return
	# foco no inimigo com menos HP
	var focus := 0
	for i in alive.size():
		if alive[i].hp < alive[focus].hp:
			focus = i
	b.target = focus
	var target: Enemy = alive[focus]

	if b._choosing == "lens":
		var best := _best_lens(target)
		if best == (a as Andri).lens:
			b.cancel_choice()
		else:
			b.select_option(Andri.LENSES.find(best))
			b.confirm_choice()
		return
	if b._choosing != "":
		b.cancel_choice()
	if a is Shumi:
		var s := a as Shumi
		if s.can_use("ult", b.points) and not s.in_kaioken() and s.hp > s.max_hp * 0.6:
			b.request_action("ult")
			return
		_turns += 1
		if s.can_use("skill2", b.points) and b.points >= 2 and s.status("bang") == null and b.allies_on_field().size() > 1:
			b.request_action("skill2")
		elif b.points >= 1 and (alive.size() >= 2 or s.in_kaioken()):
			b.request_action("skill")
		else:
			b.request_action("basic")
	elif a is Askara:
		_turns += 1
		_pilot_askara(a as Askara, alive.size())
	elif a is Andri:
		var an := a as Andri
		_turns += 1
		if an.can_use("ult", b.points):
			_use_arsenal(an)
			return
		if _use_protocol(an):
			return
		var effective := target.effectiveness_against(_best_lens(target)) >= Types.SUPER or target.status("weakness") != null
		if not effective and b.points >= 1 and target.hp > target.max_hp * 0.4 and an.invalid_reason("skill", Types.FIRE, target) == "":
			b.request_action("skill")
			b.select_option(an.analysis_elements().find(Types.FIRE))
			if not b.confirm_choice():
				b.cancel_choice()
				b.request_action("basic")
			return
		if an.can_use("skill2", b.points) and b.points >= 2:
			b.request_action("skill2")
			b.select_option(0)  # Sobrecarga
			if b.confirm_choice():
				return
			b.cancel_choice()
		b.request_action("basic")
	else:
		_turns += 1
		b.request_action("basic")


func _pilot_askara(k: Askara, enemies: int) -> void:
	var b := _battle
	if k.can_use("ult", b.points):
		b.request_action("ult")
		return
	var id := ""
	if k.can_use("skill", b.points) and k.on_field().size() < Askara.MAX_SUMMONS:
		var has_shivara := k.on_field().any(func(i: Summon) -> bool: return i.id == "shivara")
		if k.fragments >= 3 and not has_shivara and enemies >= 2:
			id = "shivara"
		elif k.fragments >= 2 and k.on_field().is_empty():
			id = "emissary"
	if id == "":
		b.request_action("basic")
		return
	b.request_action("skill")
	var ids: Array = Askara.SUMMONS.map(func(x: Dictionary) -> String: return x.id)
	b.select_option(ids.find(id))
	if not b.confirm_choice():
		b.cancel_choice()
		b.request_action("basic")


## Escudo do Protocolo em quem da equipe estiver abaixo de 50%. Devolve se usou.
func _use_protocol(an: Andri) -> bool:
	var b := _battle
	if not an.can_use("skill2", b.points):
		return false
	var allies := b.living_allies()
	var worst := 0
	for i in allies.size():
		if float(allies[i].hp) / allies[i].max_hp < float(allies[worst].hp) / allies[worst].max_hp:
			worst = i
	if float(allies[worst].hp) / allies[worst].max_hp >= 0.5:
		return false
	b.ally_target = b.allies_on_field().find(allies[worst])
	b.request_action("skill2")
	b.select_option(1)  # Escudo
	if b.confirm_choice():
		return true
	b.cancel_choice()
	return false


func _use_arsenal(an: Andri) -> void:
	var b := _battle
	var allies := b.living_allies()
	var worst := 0
	for i in allies.size():
		if float(allies[i].hp) / allies[i].max_hp < float(allies[worst].hp) / allies[worst].max_hp:
			worst = i
	var id := "freya"
	var pick := worst
	if float(allies[worst].hp) / allies[worst].max_hp >= 0.5:
		id = "ra"
		pick = 0
		for i in allies.size():
			if allies[i].atk() > allies[pick].atk():
				pick = i
	b.ally_target = pick
	b.request_action("ult")
	var ids: Array = Andri.ARTIFACTS.map(func(x: Dictionary) -> String: return x.id)
	b.select_option(ids.find(id))
	if not b.confirm_choice():
		b.cancel_choice()
		b.request_action("basic")


# ---------------------------------------------------------------- tabela
func _print() -> void:
	print("\nandar  nível  equipe        vitórias   turnos (média)   HP restante (média / pior)")
	for c in _scenarios:
		var list: Array = _results.get(c, [])
		var v := list.filter(func(r: Dictionary) -> bool: return r.won)
		var turns := 0.0
		var hp := 0.0
		var worst := 1.0
		for r: Dictionary in v:
			turns += r.turns
			hp += r.hp
			worst = minf(worst, r.hp)
		var n := maxi(1, v.size())
		print("%5d  %5d  %-12s  %3d/%-3d   %8.1f          %5.0f%% / %3.0f%%" % [c.x, c.y, _teams.get(c, ""),
			v.size(), list.size(), turns / n, 100.0 * hp / n, 100.0 * worst if not v.is_empty() else 0.0])


# ---------------------------------------------------------------- apoio
## Níveis testados em cada andar: 1 abaixo do recomendado, o recomendado e
## o máximo que dá para ter ao entrar (o limite da Torre nesse ponto).
func _test_levels(n: int) -> Array[int]:
	var recommended: int = Floors.data(n).recommended_level
	var levels: Array[int] = []
	for level in [recommended - 1, recommended, Floors.floor_limit(n)]:
		if level >= 1 and level not in levels:
			levels.append(level)
	return levels


## Save da simulação: andares anteriores vencidos (com os eventos deles),
## todos os liberados no `level` e a equipe mais cheia que o andar aceita.
func _prepare_save(floor_number: int, level: int) -> void:
	Progression.delete()
	for n in range(1, floor_number):
		Progression.mark_floor_cleared(n)
		for e: Dictionary in Floors.data(n).get("on_win", []):
			StoryEvents.apply(e)
	for id in Roster.available():
		Progression._store(id, {"level": level, "xp": 0})
	Floors.choose(floor_number)
	var ids := Roster.available()
	if not _requested_team.is_empty():
		ids = _requested_team.filter(func(id: String) -> bool: return id in Roster.available())
	Roster.set_team(ids.slice(0, Floors.max_team(floor_number)))


## A lente do Andri que mais machuca `target` (fraquezas criadas contam).
func _best_lens(target: Combatant) -> String:
	var best := Andri.LENSES[0]
	for t in Andri.LENSES:
		if target.effectiveness_against(t) > target.effectiveness_against(best):
			best = t
	return best

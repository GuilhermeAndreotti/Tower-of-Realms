class_name Combatant
extends RefCounted
## Estado de um lutador durante a batalha: status, HP, energia e posição na
## fila de turnos. Não sabe nada de animação nem de interface.

## Distância que todo mundo percorre para agir; quem tem mais VEL chega antes.
const TURN_DISTANCE := 10000.0

var name: String
var ally: bool
## Nível do personagem (Progression); inimigos ficam no 1. Não confundir com
## níveis de forma de um kit (como o Kaioken da Shumi).
var character_level := 1
## HP máximo e atributos no nível atual, sem modificadores temporários (que
## entram em bonus() e nos estados). Quem muda o nível é apply_level().
var max_hp: int
var hp: int
var base_atk: float
var base_def: float
var base_spd: float
## Atributos com que o lutador foi definido (nível 1): {"hp", "atk", "def", "spd"}.
var _base_stats := {}
var max_energy: float = 0.0
var energy: float = 0.0
var energy_on_hit: float = 0.0  ## energia ganha ao receber um golpe
## Um tipo só (Types); é o que define o que o atinge melhor e, por padrão,
## o tipo dos ataques dele.
var type: String

## Quanto falta para este lutador agir ("action value" do HSR).
var av: float

## Multiplicadores temporários (somados): {"atk": 0.2, "spd": -0.1}.
## Personagens com mecânicas próprias (como o Kaioken) sobrescrevem bonus().
var _bonus_extra := {}

## Efeitos aplicados por habilidades (ver StatusEffect). Um por id.
var status_effects: Array[StatusEffect] = []

## Turnos que faltam para cada ação com "cooldown" poder ser usada de novo
## (acao -> turnos do portador; sem a chave = pronta).
var cooldowns := {}

## Devolve os aliados de pé deste lutador (Array[Combatant]); a batalha
## preenche. Um Callable, e não a lista, para não criar ciclo de referência.
var living_allies := Callable()

const CRITICAL_DAMAGE := 1.5  ## multiplicador do acerto crítico


func _init(p_name: String, p_ally: bool, p_hp: int, p_atk: float, p_def: float, p_spd: float, p_type := Types.PHYSICAL) -> void:
	name = p_name
	type = p_type
	ally = p_ally
	max_hp = p_hp
	hp = p_hp
	base_atk = p_atk
	base_def = p_def
	base_spd = p_spd
	_base_stats = {"hp": p_hp, "atk": p_atk, "def": p_def, "spd": p_spd}
	av = TURN_DISTANCE / base_spd


func level_1_stats() -> Dictionary:
	return _base_stats.duplicate()


## Põe o lutador em `p_level` com os `stats` desse nível (Progression.stats).
## Troca só a base: a vida extra dos estados continua por cima, o HP atual
## ganha o que o máximo ganhou (sem passar dele) e quem caiu continua caído.
func apply_level(p_level: int, stats: Dictionary) -> void:
	var spd_before := spd()
	var max_hp_before := max_hp
	var extra_life := 0
	for e in status_effects:
		extra_life += e.extra_life
	character_level = p_level
	max_hp = int(stats.hp) + extra_life
	if hp > 0:
		hp = clampi(hp + maxi(0, max_hp - max_hp_before), 1, max_hp)
	base_atk = stats.atk
	base_def = stats.def
	base_spd = stats.spd
	adjust_av(spd_before)


func is_alive() -> bool:
	return hp > 0


func bonus(stat: String) -> float:
	var total: float = _bonus_extra.get(stat, 0.0)
	for e in status_effects:
		total += e.mods.get(stat, 0.0)
	return total


func atk() -> float:
	return base_atk * (1.0 + bonus("atk"))


func defense() -> float:
	return base_def * (1.0 + bonus("def"))


func spd() -> float:
	return maxf(1.0, base_spd * (1.0 + bonus("spd")))


## Chame depois de qualquer mudança de VEL: o que falta para agir é
## reescalado, como no HSR (ficar mais rápido no meio do caminho adianta o turno).
func adjust_av(spd_before: float) -> void:
	av = av * spd_before / spd()


func reset_av() -> void:
	av = TURN_DISTANCE / spd()


func gain_energy(amount: float) -> void:
	energy = minf(max_energy, energy + amount)


## Dano de `attacker` com multiplicador `mult` sobre `target`, com um ataque
## do tipo `attack_type` ("" = o tipo do atacante).
## `variance` (0..1) e `critical` são sorteados fora para os testes poderem
## fixar o valor. Escudos não entram aqui (ver absorb()).
static func calculate_damage(attacker: Combatant, target: Combatant, mult: float, variance := 0.5, attack_type := "", critical := false) -> int:
	var strike_type := attack_type if attack_type != "" else attacker.type
	var raw := attacker.atk() * mult * target.effectiveness_against(strike_type) * 100.0 / (100.0 + target.defense())
	raw *= 1.0 - target.damage_reduction()
	if critical:
		raw *= CRITICAL_DAMAGE
	return maxi(1, roundi(raw * lerpf(0.95, 1.05, variance)))


## Tira HP direto, sem passar pelo escudo (custos próprios, como o Kaioken).
## Golpes passam antes por absorb().
func take_damage(amount: int) -> int:
	var real := mini(amount, hp)
	hp -= real
	return real


func heal(amount: int) -> int:
	var real := mini(amount, max_hp - hp)
	hp += real
	return real


## Multiplicador de um golpe do tipo `strike_type` neste lutador: a tabela de
## Types, a não ser que um estado tenha criado fraqueza a esse tipo.
func effectiveness_against(strike_type: String) -> float:
	for e in status_effects:
		if e.weakness == strike_type:
			return Types.SUPER
	return Types.effectiveness(strike_type, type)


func crit_chance() -> float:
	return clampf(bonus("crit"), 0.0, 1.0)


## Fração cortada de todo golpe recebido (resistências dos estados).
func damage_reduction() -> float:
	var total := 0.0
	for e in status_effects:
		total += e.damage_reduction
	return clampf(total, 0.0, 0.9)


## Peso deste lutador no sorteio de alvo dos inimigos (1 + provocações).
func target_weight() -> float:
	var total := 1.0
	for e in status_effects:
		total += e.taunt
	return total


## Outro aliado (`attacker`, da equipe ou invocação) acabou de acertar o
## inimigo `target`, que segue de pé. Devolve o golpe com que este lutador
## ataca junto ({"name", "mult", "type"?}; {} = nenhum), que a batalha faz
## como golpe adicional: sem crítico, sem estados de acerto e sem encadear.
## Quem ataca junto no kit sobrescreve.
func follow_up(_attacker: Combatant, _target: Combatant) -> Dictionary:
	return {}


## Um inimigo caiu (chamado nos aliados de pé). Devolve o que este lutador
## ganhou com isso, para o registro da luta ("" = nada).
func on_enemy_fallen() -> String:
	return ""


# --------------------------------------------------------------- estados
func state(id: String) -> StatusEffect:
	for e in status_effects:
		if e.id == id:
			return e
	return null


## Aplica `e` (substitui o de mesmo id, renovando).
func apply_status(e: StatusEffect) -> void:
	var spd_before := spd()
	var hp_before := hp
	var old := state(e.id)
	remove_status(e.id)
	status_effects.append(e)
	# vida extra: o HP atual sobe só o que o máximo ganhou de novo (renovar
	# não cura)
	max_hp += e.extra_life
	hp = mini(hp_before + maxi(0, e.extra_life - (old.extra_life if old else 0)), max_hp)
	adjust_av(spd_before)
	if old == null and e.delay > 0:
		av += e.delay * TURN_DISTANCE / spd()


## Tira o estado `id`, desfazendo o que ele mudou (VEL, HP máximo).
func remove_status(id: String) -> void:
	var spd_before := spd()
	for i in range(status_effects.size() - 1, -1, -1):
		if status_effects[i].id == id:
			max_hp -= status_effects[i].extra_life
			hp = mini(hp, max_hp)
			status_effects.remove_at(i)
	adjust_av(spd_before)


## Fim de um turno do portador: desconta a duração dos estados e as
## recargas. Devolve os estados que acabaram.
func pass_turn() -> Array[StatusEffect]:
	for action: String in cooldowns.keys():
		cooldowns[action] -= 1
		if cooldowns[action] <= 0:
			cooldowns.erase(action)
	var ended: Array[StatusEffect] = []
	for e in status_effects:
		if e.turns > 0:
			e.turns -= 1
			if e.turns == 0:
				ended.append(e)
	for e in ended:
		remove_status(e.id)
	return ended


## Remove os debuffs (os estados genéricos; custos de kit, como a exaustão
## do Kaioken, não são estados e ficam). Devolve quantos saíram.
func clear_debuffs() -> int:
	var before := status_effects.size()
	for e in status_effects.duplicate():
		if e.type == "debuff":
			remove_status(e.id)
	return before - status_effects.size()


func has_debuff() -> bool:
	for e in status_effects:
		if e.type == "debuff":
			return true
	return false


func shield() -> int:
	var total := 0
	for e in status_effects:
		total += e.shield
	return total


## Escudos absorvem o golpe primeiro. Devolve quanto foi absorvido.
func absorb(damage: int) -> int:
	var absorbed := 0
	for e in status_effects.duplicate():
		if e.shield <= 0 or absorbed >= damage:
			continue
		var part := mini(e.shield, damage - absorbed)
		e.shield -= part
		absorbed += part
		if e.shield == 0:
			remove_status(e.id)
	return absorbed


## Golpes adicionais que um golpe de multiplicador `mult` do portador
## dispara (ex.: dano elétrico extra). Os que se consomem acabam aqui.
## Golpes adicionais não chamam isto de novo: não há encadeamento.
func extra_strikes(mult: float) -> Array[Dictionary]:
	var extras: Array[Dictionary] = []
	for e in status_effects.duplicate():
		if e.extra_strike.is_empty():
			continue
		var g: Dictionary = e.extra_strike
		extras.append({"type": g.type, "mult": g.mult * mult if g.get("proportional", false) else g.mult, "source": e.name})
		if g.get("consumes", false):
			remove_status(e.id)
	return extras


## Estados que o portador aplica em quem acerta (novos a cada acerto).
## Os que se consomem acabam aqui.
func on_hit_statuses() -> Array[StatusEffect]:
	var list: Array[StatusEffect] = []
	for e in status_effects.duplicate():
		if e.on_hit.is_valid():
			var candidate: StatusEffect = e.on_hit.call()
			list.append(candidate)
			if e.on_hit_consumes:
				remove_status(e.id)
	return list


# --------------------------------------------------------------- recarga
## Turnos que faltam para `action` poder ser usada de novo (0 = pronta).
func cooldown(action: String) -> int:
	return cooldowns.get(action, 0)


## `action` foi usada: só volta depois de `turns` turnos do portador, contando
## o turno em que foi usada (recarga 3 = uma vez a cada 3 turnos).
func start_cooldown(action: String, turns: int) -> void:
	if turns > 0:
		cooldowns[action] = turns


## Completa a descrição `h` de uma ação com "cooldown": em recarga, ela fica
## no estado "cooldown" com os turnos que faltam ("cooldown_remaining").
func with_cooldown(h: Dictionary) -> Dictionary:
	var missing_reason := cooldown(h.action)
	h.cooldown_remaining = missing_reason
	if missing_reason > 0:
		h.state = "cooldown"
		h.missing_reason = "Recarga: mais %d turno%s." % [missing_reason, "" if missing_reason == 1 else "s"]
	return h


# ------------------------------------------------- descrição para a interface
# A HUD só lê estes dados; quem tem kit ou estados próprios sobrescreve.

## Efeitos ativos: [{"id", "short", "name", "type" (buff/debuff/alerta),
## "turns" (-1 = sem contagem), "detail"?, "color"?}, ...].
## Quem sobrescreve deve incluir super() (os estados genéricos).
func effects() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for e in status_effects:
		list.append(e.description())
	return list


## Kit de ações do jogador, na ordem da barra (sempre básico, skill, skill 2,
## ult e a passiva; a skill 2 pode ser uma passiva, no mesmo lugar): [{"action", "name", "key",
## "icon", "state" (pronta/no_resource/bloqueada/recarga), "target" (unico/
## vizinhos/todos/proprio/aliado), "type"? (Types, só nas que causam dano),
## "point_cost"?, "energy_cost"?, "resource_cost"? (texto, para recursos
## do kit, como "6 fragmentos"), "point_gain"?, "options"? (escolha
## feita antes de confirmar: [{"id", "name", "description", "icon"?, "color"?,
## "target"? (quando a opção mira outro tipo de alvo que a ação)}],
## com "default_option"?), "cooldown"? (turnos entre usos; ver with_cooldown()),
## "passive"? (sem tecla; todo kit explica a sua),
## "on_turn_start"? (o seletor de opções abre sozinho no começo da vez),
## "selector"? ("radial": as opções abrem em anel no próprio lutador; opções
## podem ter "abbr" e "current"),
## "free"? (não gasta o turno), "badge"?, "highlight"?, "color"?,
## "missing_reason"? (por que não está pronta, quando o kit sabe dizer), "description"
## (resumo curto: custo, recarga e alvo já aparecem como etiquetas),
## "details"? (uma linha por item, no SkillCard: [{"label",
## "mark"?, "text"?, "values"? ([{"text", "current"?}], um por nível),
## "color"?, "current"?}])}, ...].
## A batalha cobra "point_cost" antes da ação e dá "point_gain" depois.
func skills(_points: int) -> Array[Dictionary]:
	return []


## Inimigos que `action` atingiria, quando a regra é do próprio kit (alvos que
## mudam com uma forma, por exemplo). Vazio = a batalha usa o "target" da ação.
func predicted_targets(_action: String, _enemies: Array, _target: int) -> Array:
	return []


## Por que `action` (com a `option` escolhida) não pode ser usada em `target`;
## "" = pode. A batalha impede a confirmação e a HUD mostra o motivo.
func invalid_reason(_action: String, _option: String, _target: Combatant) -> String:
	return ""


## Se `action` pode ser usada agora (com `points` de skill do time).
func can_use(_action: String, _points: int) -> bool:
	return false

class_name Shumi
extends Combatant
## Kit da Shumi.
##  Básico: corte de katana (gera 1 ponto de skill e um pouco de energia).
##  Skill: Engo-ji Beam, feixe que muda com o Kaioken: só o alvo, alvo + 1
##         (x2), alvo + vizinhos (x4), atravessa todos (x10) e Colapso (x20).
##  Skill 2: Bang!. Finger Beam no alvo e, pelos 2 turnos seguintes dela,
##           ataca junto: sempre que um aliado acerta um inimigo, ela dispara
##           um Finger Beam nele (mais forte a cada nível do Kaioken).
##  Ult: Kaioken. Entra na forma (x2) ou sobe um nível (x4, x10, x20).
##       Cada nível dá mais ATQ/VEL e drena mais HP no início do turno.
##       Quando acaba, ela fica exausta (VEL menor); depois do x20 perde um turno.
##  Passiva: Limite Humano. Se sobrevive ao dreno do Kaioken no início do
##           turno, recupera energia (mais nos níveis altos).

## Ajuste de balanceamento: tudo do Kaioken está aqui.
## A VEL sobe menos que o ATQ de propósito: a duração conta turnos dela, então
## VEL alta demais encurta a forma e quase tira a vez dos inimigos, que são
## o outro lado do risco.
const LEVELS := [
	{"name": "x2", "atk": 0.20, "spd": 0.20, "drain": 0.03, "limit": 15.0, "exhaustion_spd": -0.10},
	{"name": "x4", "atk": 0.40, "spd": 0.35, "drain": 0.05, "limit": 20.0, "exhaustion_spd": -0.20},
	{"name": "x10", "atk": 0.80, "spd": 0.55, "drain": 0.08, "limit": 25.0, "exhaustion_spd": -0.30},
	{"name": "x20", "atk": 1.50, "spd": 0.80, "drain": 0.12, "limit": 30.0, "exhaustion_spd": -0.40},
]
const ENTER_COST := 120.0
const LEVEL_UP_COST := 80.0
const DURATION := 3  ## turnos dela; subir de nível renova
const EXHAUSTION_DURATION := 2

const BASIC_ENERGY := 20.0
const SKILL_ENERGY := 30.0
const ENERGY_ON_HIT := 10.0

const BASIC_MULT := 1.0
## Engo-ji por nível (índice = nivel + 1). "reach" é também o tipo de alvo
## que a interface mostra: unico, dupla (alvo + o de trás), vizinhos, todos.
const ENGO_JI := [
	{"name": "Engo-ji Beam", "reach": "single", "mult": 1.8},
	{"name": "Engo-ji Beam Amplificado", "reach": "pair", "mult": 1.8},
	{"name": "Engo-ji Beam: Ruptura", "reach": "neighbors", "mult": 1.8},
	{"name": "Engo-ji Beam: Devastação", "reach": "all", "mult": 1.8},
	{"name": "Engo-ji Beam: Colapso", "reach": "all", "mult": 2.2},
]
const ENGO_JI_SECONDARY_MULT := 0.9  ## alvos extras do x2 e do x4

## Finger Beam do Bang! (o tiro ao usar e cada ataque junto), por nível
## (índice = nivel + 1). Fraco de propósito: dispara a cada ação de aliado
## que acerta, invocações inclusive.
const FINGER_BEAM_MULT := [0.4, 0.5, 0.65, 0.85, 1.1]
## Turnos dela, contando o da ação: o Bang! cobre os 2 turnos seguintes.
## A recarga conta do mesmo jeito; um turno a mais que a duração para ela
## sempre ficar pelo menos um turno sem ele (com as duas iguais, acabava e
## voltava no mesmo turno).
const BANG_DURATION := 3
const BANG_COOLDOWN := BANG_DURATION + 1
const FOLLOW_UP_ENERGY := 4.0  ## por ataque junto: a equipe atacando acelera o Kaioken

var level := -1  ## -1 = fora do Kaioken
var kaioken_turns := 0
var exhaustion_turns := 0
var exhaustion_spd := 0.0
var loses_next_turn := false
var _overload_this_turn := false  ## o dreno (e a passiva) já rodou neste turno


func _init() -> void:
	super("Shumi", true, 1200, 150.0, 50.0, 105.0, Types.PHYSICAL)
	max_energy = 120.0
	energy = 60.0
	energy_on_hit = ENERGY_ON_HIT


func in_kaioken() -> bool:
	return level >= 0


func level_name() -> String:
	return LEVELS[level].name if in_kaioken() else ""


func at_max_level() -> bool:
	return level == LEVELS.size() - 1


func ult_cost() -> float:
	return LEVEL_UP_COST if in_kaioken() else ENTER_COST


func can_use_ult() -> bool:
	return not at_max_level() and energy >= ult_cost()


func next_level_name() -> String:
	return LEVELS[mini(level + 1, LEVELS.size() - 1)].name


## Versão do Engo-ji para o nível atual (ver ENGO_JI).
func engo_ji() -> Dictionary:
	return ENGO_JI[level + 1]


func engo_ji_pierces() -> bool:
	return engo_ji().reach == "all"


func bonus(stat: String) -> float:
	var b := super(stat)
	if in_kaioken():
		b += LEVELS[level].get(stat, 0.0)
	if exhaustion_turns > 0 and stat == "spd":
		b += exhaustion_spd
	return b


func use_ult() -> void:
	var spd_before := spd()
	energy -= ult_cost()
	level += 1
	kaioken_turns = DURATION
	exhaustion_turns = 0
	adjust_av(spd_before)


## Sobrecarga do Kaioken no início do turno dela: queima HP direto (sem
## defesa) e, se ela sobreviver, a passiva Limite Humano devolve energia.
## Roda no máximo uma vez por turno. Devolve {"damage": int, "energy": float}.
func turn_start_overload() -> Dictionary:
	var r := {"damage": 0, "energy": 0.0}
	if not in_kaioken() or _overload_this_turn:
		return r
	_overload_this_turn = true
	r.damage = take_damage(ceili(max_hp * LEVELS[level].drain))
	if is_alive():
		var before := energy
		gain_energy(LEVELS[level].limit)
		r.energy = energy - before
	return r


## Fim do turno dela. Devolve o nível que acabou ("" se o Kaioken continua).
func end_turn() -> String:
	_overload_this_turn = false
	if exhaustion_turns > 0:
		exhaustion_turns -= 1
	if not in_kaioken():
		return ""
	kaioken_turns -= 1
	if kaioken_turns > 0:
		return ""
	var over: Dictionary = LEVELS[level]
	exhaustion_spd = over.exhaustion_spd
	exhaustion_turns = EXHAUSTION_DURATION
	loses_next_turn = at_max_level()
	level = -1
	return over.name


## Alvos do Engo-ji: [[inimigo, multiplicador], ...], na ordem em que o
## feixe passa. `enemies` só com os vivos, em ordem.
func engo_ji_targets(enemies: Array, target: int) -> Array:
	var e := engo_ji()
	var extras := []
	match e.reach:
		"pair": extras = [target + 1 if target + 1 < enemies.size() else target - 1]
		"neighbors": extras = [target - 1, target + 1]
	var targets := []
	for i in enemies.size():
		if e.reach == "all" or i == target:
			targets.append([enemies[i], e.mult])
		elif i in extras:
			targets.append([enemies[i], ENGO_JI_SECONDARY_MULT])
	return targets


# ----------------------------------------------------------------- Bang!
func mult_finger_beam() -> float:
	return FINGER_BEAM_MULT[level + 1]


## Bang! ativo: enquanto durar, follow_up() acompanha os aliados.
static func bang_status() -> StatusEffect:
	var e := StatusEffect.new("bang", "Bang!", "BNG", "buff", BANG_DURATION)
	e.color = KAIOKEN_COLOR
	e.detail = "ataca junto com Finger Beam"
	return e


func follow_up(attacker: Combatant, _target: Combatant) -> Dictionary:
	if attacker == self or state("bang") == null:
		return {}
	gain_energy(FOLLOW_UP_ENERGY)
	return {"name": "Finger Beam", "mult": mult_finger_beam(), "type": type}


func predicted_targets(action: String, enemies: Array, target: int) -> Array:
	if action == "skill":
		return engo_ji_targets(enemies, target).map(func(pair: Array) -> Combatant: return pair[0])
	return super(action, enemies, target)


# ------------------------------------------------- descrição para a interface
const KAIOKEN_COLOR := Color(1.0, 0.25, 0.2)
const SLASH_ICON := "res://characters/shumi/basic-attack-melee.png"
const ENGO_JI_ICON := "res://characters/shumi/engo-ji-beam-icon.png"
const KAIOKEN_ICON := "res://characters/shumi/kaiokenn-shumi.png"
const BANG_ICON := "res://characters/shumi/icon_bang.png"
const HUMAN_LIMIT_ICON := "res://characters/shumi/icon_human_limit.png"


func can_use(action: String, points: int) -> bool:
	match action:
		"basic": return true
		"skill": return points > 0
		"skill2": return points > 0 and cooldown("skill2") == 0
		"ult": return can_use_ult()
	return false


const ENGO_JI_DESCRIPTIONS := {
	"single": "Feixe concentrado no alvo.",
	"pair": "Feixe mais forte: acerta o alvo e o inimigo logo atrás.",
	"neighbors": "Feixe roxo e vermelho: alvo + vizinhos (dano menor nos vizinhos).",
	"all": "O feixe atravessa todos os inimigos.",
}


func skills(points: int) -> Array[Dictionary]:
	var e := engo_ji()
	var ult := {
		"action": "ult", "name": "Kaioken", "key": "R", "icon": KAIOKEN_ICON,
		"target": "self", "color": KAIOKEN_COLOR, "highlight": true, "free": true,
	}
	var levels: Array[Dictionary] = []
	for i in LEVELS.size():
		var n: Dictionary = LEVELS[i]
		levels.append({"label": "Kaioken " + n.name, "color": KAIOKEN_COLOR, "current": i == level,
			"mark": "current" if i == level else ("próximo" if i == level + 1 else ""),
			"text": "ATQ +%d%% · VEL +%d%% · queima %d%% do HP por turno" % [
				roundi(n.atk * 100), roundi(n.spd * 100), roundi(n.drain * 100)]})
	ult.details = levels
	if at_max_level():
		ult.merge({"state": "blocked", "badge": "MÁX",
			"description": "Já está no x20. Quando acabar, perde um turno."})
	else:
		var next: Dictionary = LEVELS[level + 1]
		ult.merge({
			"state": "ready" if can_use_ult() else "no_resource",
			"energy_cost": roundi(ult_cost()),
			"badge": next.name,
			"description": "%s %s. Cada nível dura %d turnos dela (subir renova); quando acaba, ela fica exausta, e depois do x20 perde um turno." % [
				"Sobe para o" if in_kaioken() else "Entra no", next.name, DURATION],
		})
	var engo: Array[Dictionary] = []
	for i in ENGO_JI.size():
		var g: Dictionary = ENGO_JI[i]
		engo.append({"label": _level_name(i - 1), "mark": g.name, "color": KAIOKEN_COLOR, "current": i == level + 1,
			"text": "Colapso: energia extrema contra todos os inimigos." if i == ENGO_JI.size() - 1 else ENGO_JI_DESCRIPTIONS[g.reach]})
	return [
		{
			"action": "basic", "name": "Corte", "key": "Q", "icon": SLASH_ICON,
			"state": "ready", "target": "single", "type": type, "point_gain": 1,
			"description": "Corte de katana no alvo. Gera 1 ponto de skill e %d de energia." % roundi(BASIC_ENERGY),
		},
		{
			"action": "skill", "name": e.name, "key": "E", "icon": ENGO_JI_ICON,
			"state": "ready" if points > 0 else "no_resource",
			"target": e.reach, "type": type, "point_cost": 1,
			"badge": level_name(), "color": KAIOKEN_COLOR,
			"description": "Feixe de energia que cresce com o Kaioken: cada nível aumenta o alcance.",
			"details": engo,
		},
		with_cooldown({
			"action": "skill2", "name": "Bang!", "key": "W", "icon": BANG_ICON,
			"state": "ready" if points > 0 else "no_resource",
			"target": "single", "type": type, "point_cost": 1, "cooldown": BANG_COOLDOWN,
			"badge": level_name(), "color": KAIOKEN_COLOR,
			"description": "Dispara uma rajada de energia de seus dedos em um alvo e, pelos %d turnos seguintes dela, ataca junto com a equipe." % (BANG_DURATION - 1),
			"details": [
				{"label": "Ataca junto", "color": KAIOKEN_COLOR,
					"text": "Quando um aliado ou invocação acerta um inimigo, ela dispara um Finger Beam nele (uma vez por ação) e ganha %d de energia." % roundi(FOLLOW_UP_ENERGY)},
				{"label": "Dano do Finger Beam", "color": KAIOKEN_COLOR,
					"values": _per_level(FINGER_BEAM_MULT.map(func(m: float) -> String: return str(m).replace(".", ",") + "x"))},
			],
		}),
		ult,
		{
			"action": "human_limit", "name": "Limite Humano", "key": "", "icon": HUMAN_LIMIT_ICON,
			"state": "ready", "target": "self", "passive": true, "color": KAIOKEN_COLOR,
			"description": "Se sobrevive ao dreno do Kaioken no começo do turno, recupera energia.",
			"details": [{"label": "Energia por nível", "color": KAIOKEN_COLOR,
				"values": _per_level(LEVELS.map(func(n: Dictionary) -> String: return "+%d" % roundi(n.limit)), false)}],
		},
	]


## Nome do nível `i` do Kaioken (-1 = fora dele).
static func _level_name(i: int) -> String:
	return "Base" if i < 0 else LEVELS[i].name


## Um valor por nível ("Base 0,4x", "x2 0,5x"...), marcando o atual, para os
## "values" dos detalhes. `values` começa no Base; sem `with_base`, no x2.
func _per_level(values: Array, with_base := true) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for i in values.size():
		var n := i - 1 if with_base else i
		list.append({"text": "%s %s" % [_level_name(n), values[i]], "current": n == level})
	return list


func effects() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if in_kaioken():
		var n: Dictionary = LEVELS[level]
		list.append({"id": "kaioken", "short": n.name, "name": "Kaioken " + n.name, "type": "buff",
			"color": KAIOKEN_COLOR, "turns": kaioken_turns,
			"detail": "ATQ +%d%% · VEL +%d%% · -%d%% HP/turno · +%d energia" % [
				roundi(n.atk * 100), roundi(n.spd * 100), roundi(n.drain * 100), roundi(n.limit)]})
	if exhaustion_turns > 0:
		list.append({"id": "exhaustion", "short": "EXA", "name": "Exausta", "type": "debuff",
			"turns": exhaustion_turns, "detail": "VEL %d%%" % roundi(exhaustion_spd * 100)})
	if loses_next_turn:
		list.append({"id": "loses_turn", "short": "Zz", "name": "Perde o próximo turno",
			"type": "debuff", "turns": -1})
	list.append_array(super())
	return list

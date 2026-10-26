class_name Clairin
extends Combatant
## Kit do Clairin, portador da Chama Frenética (tipo Fogo, de Azeroth). Bate
## em área e paga com o próprio HP.
##  Passiva: Chama Frenética. Uma barra de 0 a 100 que sobe com os ataques
##           dele e aumenta o ATQ (até +60% cheia). Se chega a 100, estoura:
##           ele perde 20% do HP máximo (nunca cai por isso) e a barra zera.
##  Básico: Bola de Fogo. Um alvo só; gera 1 ponto de skill e Frenesi.
##  Skill: Onda Frenética. Todos os inimigos; gera mais Frenesi.
##  Skill 2: Descarga. Gasta todo o Frenesi num golpe no alvo e nos vizinhos,
##           mais forte quanto mais cheia a barra, e zera sem estourar.
##  Ult: Cabeça Flamejante. Por 3 turnos dele, a Bola de Fogo atinge todos e
##       o estouro da barra queima também os inimigos. Não gasta o turno.

## Ajuste de balanceamento: tudo da Chama Frenética está aqui.
const FRENZY_MAX := 100
const FRENZY_ATK := 0.6  ## bônus de ATQ com a barra cheia (proporcional)
const FRENZY_BASIC := 20
const FRENZY_WAVE := 30
const FRENZY_HEAD := 30  ## ao entrar na Cabeça Flamejante
const OVERFLOW_DAMAGE := 0.20  ## do HP máximo dele, sem passar por escudo
## Estouro na Cabeça Flamejante, em todos os inimigos. Sai depois de a barra
## zerar (sem o bônus), por isso o multiplicador já é alto.
const BURST_MULT := 2.0

const BASIC_MULT := 0.9
const HEAD_BASIC_MULT := 0.7  ## a Bola de Fogo em todos, na Cabeça Flamejante
const WAVE_MULT := 0.7
## Descarga: do multiplicador com a barra vazia até o com ela cheia; os
## vizinhos levam uma fração.
const DISCHARGE_MIN := 0.5
const DISCHARGE_MAX := 2.0
const DISCHARGE_NEIGHBORS := 0.6
const DISCHARGE_COOLDOWN := 3

const ENERGY_BASIC := 20.0
const ENERGY_SKILL := 30.0
const ENERGY_ON_HIT := 10.0
const ULT_COST := 120.0
const HEAD_DURATION := 3  ## turnos dele

const FOLDER := "res://characters/clairin/"
const FRENZY_COLOR := Color(1.0, 0.82, 0.2)

var frenzy := 0
var head_turns := 0  ## turnos que faltam da Cabeça Flamejante (0 = fora)


func _init() -> void:
	super("Clairin", true, 1080, 140.0, 50.0, 104.0, Types.FIRE)
	max_energy = 120.0
	energy = 60.0
	energy_on_hit = ENERGY_ON_HIT


# ------------------------------------------------------- Chama Frenética
func in_flaming_head() -> bool:
	return head_turns > 0


func frenzy_bonus() -> float:
	return FRENZY_ATK * frenzy / FRENZY_MAX


func bonus(stat: String) -> float:
	var b := super(stat)
	if stat == "atk":
		b += frenzy_bonus()
	return b


func gain_frenzy(amount: int) -> void:
	frenzy = mini(FRENZY_MAX, frenzy + amount)


## Se a barra encheu, estoura: a barra zera e ele perde HP (fica com 1, no
## mínimo). Devolve {"damage", "burst" (true na Cabeça Flamejante: a batalha
## queima também os inimigos)}; {} se não estourou.
func overflow() -> Dictionary:
	if frenzy < FRENZY_MAX:
		return {}
	frenzy = 0
	var damage := take_damage(mini(ceili(max_hp * OVERFLOW_DAMAGE), hp - 1))
	return {"damage": damage, "burst": in_flaming_head()}


## Multiplicador da Descarga no alvo com o Frenesi atual.
func discharge_mult() -> float:
	return lerpf(DISCHARGE_MIN, DISCHARGE_MAX, float(frenzy) / FRENZY_MAX)


## Gasta a barra na Descarga. Devolve o multiplicador do alvo principal.
func discharge() -> float:
	var mult := discharge_mult()
	frenzy = 0
	return mult


func basic_mult() -> float:
	return HEAD_BASIC_MULT if in_flaming_head() else BASIC_MULT


func use_ult() -> void:
	energy -= ULT_COST
	head_turns = HEAD_DURATION
	gain_frenzy(FRENZY_HEAD)


## Fim do turno dele. Devolve true se a Cabeça Flamejante acabou agora.
func end_turn() -> bool:
	if head_turns <= 0:
		return false
	head_turns -= 1
	return head_turns == 0


# ------------------------------------------------- descrição para a interface
func can_use(action: String, points: int) -> bool:
	match action:
		"basic": return true
		"skill": return points > 0
		"skill2": return points > 0 and cooldown("skill2") == 0
		"ult": return energy >= ULT_COST and not in_flaming_head()
	return false


func kit_bar() -> Dictionary:
	return {"label": "FR", "value": frenzy, "max": FRENZY_MAX, "color": FRENZY_COLOR, "marks": 4}


func skills(points: int) -> Array[Dictionary]:
	var head := in_flaming_head()
	var ult := {
		"action": "ult", "name": "Cabeça Flamejante", "key": "R", "icon": FOLDER + "icon_flaming_head.png",
		"target": "self", "energy_cost": roundi(ULT_COST), "highlight": true, "free": true, "color": FRENZY_COLOR,
		"description": "A cabeça vira chama por %d turnos dele: a Bola de Fogo atinge todos e o estouro da barra queima também os inimigos. Entra com +%d de Frenesi." % [
			HEAD_DURATION, FRENZY_HEAD],
		"details": [
			{"label": "Bola de Fogo", "text": "Atinge todos os inimigos (%sx)." % _mult_text(HEAD_BASIC_MULT)},
			{"label": "Estouro", "color": FRENZY_COLOR,
				"text": "Além de ferir o Clairin, queima todos os inimigos (%sx)." % _mult_text(BURST_MULT)},
		],
	}
	if head:
		ult.merge({"state": "blocked", "badge": str(head_turns), "missing_reason": "A Cabeça Flamejante já está acesa."})
	else:
		ult.state = "ready" if energy >= ULT_COST else "no_resource"
	return [
		{
			"action": "basic", "name": "Bola de Fogo", "key": "Q", "icon": FOLDER + "icon_fireball.png",
			"state": "ready", "target": "all" if head else "single", "type": type, "point_gain": 1,
			"badge": "TODOS" if head else "", "color": FRENZY_COLOR if head else Types.color(type),
			"description": "Bola de fogo no alvo (na Cabeça Flamejante, em todos). Gera 1 ponto de skill e +%d de Frenesi." % FRENZY_BASIC,
		},
		{
			"action": "skill", "name": "Onda Frenética", "key": "E", "icon": FOLDER + "icon_wave.png",
			"state": "ready" if points > 0 else "no_resource", "target": "all", "type": type, "point_cost": 1,
			"color": FRENZY_COLOR,
			"description": "Uma onda de fogo atinge todos os inimigos (%sx). Gera +%d de Frenesi." % [_mult_text(WAVE_MULT), FRENZY_WAVE],
		},
		with_cooldown({
			"action": "skill2", "name": "Descarga", "key": "W", "icon": FOLDER + "icon_discharge.png",
			"state": "ready" if points > 0 else "no_resource", "target": "neighbors", "type": type, "point_cost": 1,
			"cooldown": DISCHARGE_COOLDOWN, "badge": "%sx" % _mult_text(discharge_mult()), "color": FRENZY_COLOR,
			"description": "Gasta todo o Frenesi num golpe no alvo e nos vizinhos, sem estourar. Quanto mais cheia a barra, mais forte.",
			"details": [
				{"label": "No alvo", "text": "de %sx (barra vazia) a %sx (cheia); agora, %sx." % [
					_mult_text(DISCHARGE_MIN), _mult_text(DISCHARGE_MAX), _mult_text(discharge_mult())]},
				{"label": "Nos vizinhos", "text": "%d%% do golpe no alvo." % roundi(DISCHARGE_NEIGHBORS * 100)},
			],
		}),
		ult,
		{
			"action": "frenzied_flame", "name": "Chama Frenética", "key": "", "icon": FOLDER + "icon_frenzied_flame.png",
			"state": "ready", "target": "self", "passive": true, "color": FRENZY_COLOR,
			"description": "A barra sobe com os ataques dele e aumenta o ATQ, até +%d%% cheia. Se chega a %d, estoura: ele perde %d%% do HP máximo (nunca cai por isso) e a barra zera." % [
				roundi(FRENZY_ATK * 100), FRENZY_MAX, roundi(OVERFLOW_DAMAGE * 100)],
			"details": [
				{"label": "Bola de Fogo", "mark": "+%d" % FRENZY_BASIC},
				{"label": "Onda Frenética", "mark": "+%d" % FRENZY_WAVE},
				{"label": "Cabeça Flamejante", "mark": "+%d" % FRENZY_HEAD},
				{"label": "Descarga", "mark": "zera"},
			],
		},
	]


static func _mult_text(m: float) -> String:
	return str(m).replace(".", ",")


func effects() -> Array[Dictionary]:
	var list: Array[Dictionary] = [{"id": "frenzy", "short": str(frenzy), "name": "Frenesi %d/%d" % [frenzy, FRENZY_MAX],
		"type": "buff", "turns": -1, "color": FRENZY_COLOR, "detail": "Chama Frenética: ATQ +%d%%" % roundi(frenzy_bonus() * 100)}]
	if in_flaming_head():
		list.append({"id": "flaming_head", "short": "CAB", "name": "Cabeça Flamejante", "type": "buff",
			"turns": head_turns, "color": FRENZY_COLOR, "detail": "Bola de Fogo em todos · o estouro queima os inimigos"})
	list.append_array(super())
	return list

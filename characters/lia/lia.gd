class_name Lia
extends Combatant
## Kit da Lia Moonlight, a Escolhida de Elune (tipo Luz, de Azeroth). Cura
## a equipe e a protege; quem luta por ela é o Espadito, a espada viva.
##  Passiva: Bênção Lunar. Quando ela cura outro aliado, recupera para si uma
##           parte do que curou (curar a si mesma não conta).
##  Básico: Espadito. A espada viva sai da mão dela, golpeia o alvo e volta;
##          gera 1 ponto de skill.
##  Skill: Curar Ferimentos. Cura forte num aliado (ou invocação).
##  Skill 2: Nova Sagrada. Cura todos os aliados em campo e fere todos os
##           inimigos com Luz; tem recarga.
##  Ult: Lord Azeroth. Ergue o escudo sobre todos os aliados em campo: o
##       próximo golpe que cada um receber perde 80% do dano. A proteção de
##       cada um acaba nesse golpe ou depois de alguns turnos dele; usar de
##       novo só renova, não soma.

## Ajuste de balanceamento: as curas são frações do HP máximo de quem recebe,
## para valerem o mesmo no mais resistente e na mais frágil.
const BLADE_MULT := 0.8
## Na simulação, com 30% e 12% (e a Bênção em 25%) ela vencia o andar 5 no
## nível 7 com 69% do HP da equipe; com 20% e 8%, a dupla dela no andar 4
## fica perto das outras (ver o CHANGELOG).
const HEAL_FRACTION := 0.20  ## Curar Ferimentos
const NOVA_HEAL := 0.08  ## Nova Sagrada, em cada aliado
const NOVA_MULT := 0.4  ## Nova Sagrada, em cada inimigo
const NOVA_COOLDOWN := 3
const BLESSING := 0.20  ## do que curou nos outros
const LORD_REDUCTION := 0.8
const LORD_TURNS := 3  ## turnos de cada protegido

const ENERGY_BASIC := 20.0
const ENERGY_SKILL := 30.0
const ENERGY_ON_HIT := 10.0
const ULT_COST := 120.0

const FOLDER := "res://characters/lia/"
## Todos os efeitos dela são azuis, a luz da lua de Elune.
const MOON_COLOR := Color(0.45, 0.65, 1.0)
const HOLY_COLOR := Color(0.7, 0.9, 1.0)  ## o azul claro das curas


func _init() -> void:
	super("Lia Moonlight", true, 1100, 110.0, 60.0, 100.0, Types.LIGHT)
	max_energy = 120.0
	energy = 60.0
	energy_on_hit = ENERGY_ON_HIT


# ------------------------------------------------------------------ curas
## Cura `target` em `fraction` do HP máximo dele. Quem caiu não volta.
## Devolve quanto curou de fato (sem o que passaria do máximo).
func heal_target(target: Combatant, fraction: float) -> int:
	if not target.is_alive():
		return 0
	return target.heal(roundi(target.max_hp * fraction * healing_mult()))


## Bênção Lunar: recupera parte do que ela curou nos outros. Devolve quanto.
func lunar_blessing(healed_others: int) -> int:
	if healed_others <= 0 or not is_alive():
		return 0
	return heal(roundi(healed_others * BLESSING))


## Proteção do Lord Azeroth: um estado por aliado, com o mesmo id, então usar
## de novo renova a duração em vez de somar.
static func lord_azeroth() -> StatusEffect:
	var e := StatusEffect.new("lord_azeroth", "Lord Azeroth", "LA", "buff", LORD_TURNS)
	e.damage_reduction = LORD_REDUCTION
	e.consumed_by_hit = true
	e.color = MOON_COLOR
	e.detail = "-%d%% no próximo golpe" % roundi(LORD_REDUCTION * 100)
	return e


func use_ult() -> void:
	energy -= ULT_COST


# ------------------------------------------------- descrição para a interface
func can_use(action: String, points: int) -> bool:
	match action:
		"basic": return true
		"skill": return points > 0
		"skill2": return points > 0 and cooldown("skill2") == 0
		"ult": return energy >= ULT_COST
	return false


func skills(points: int) -> Array[Dictionary]:
	return [
		{
			"action": "basic", "name": "Espadito", "key": "Q", "icon": FOLDER + "icon_blade.png",
			"state": "ready", "target": "single", "type": type, "point_gain": 1, "color": MOON_COLOR,
			"description": "O Espadito, a espada viva dela, voa até o alvo, golpeia (%sx) e volta. Gera 1 ponto de skill." % _mult_text(BLADE_MULT),
		},
		{
			"action": "skill", "name": "Curar Ferimentos", "key": "E", "icon": FOLDER + "icon_heal.png",
			"state": "ready" if points > 0 else "no_resource", "target": "ally", "point_cost": 1, "color": HOLY_COLOR,
			"description": "Cura %d%% do HP máximo de um aliado (ou invocação)." % roundi(HEAL_FRACTION * 100),
		},
		with_cooldown({
			"action": "skill2", "name": "Nova Sagrada", "key": "W", "icon": FOLDER + "icon_nova.png",
			"state": "ready" if points > 0 else "no_resource", "target": "all", "type": type, "point_cost": 1,
			"cooldown": NOVA_COOLDOWN, "color": HOLY_COLOR,
			"description": "Uma explosão de luz sagrada cura a equipe e fere os inimigos.",
			"details": [
				{"label": "Aliados", "text": "Cura %d%% do HP máximo de cada um em campo, invocações incluídas." % roundi(NOVA_HEAL * 100)},
				{"label": "Inimigos", "text": "Dano de Luz em todos (%sx)." % _mult_text(NOVA_MULT)},
			],
		}),
		{
			"action": "ult", "name": "Lord Azeroth", "key": "R", "icon": FOLDER + "icon_lord_azeroth.png",
			"state": "ready" if energy >= ULT_COST else "no_resource", "target": "self",
			"energy_cost": roundi(ULT_COST), "highlight": true, "color": MOON_COLOR,
			"description": "Ergue o escudo sobre todos os aliados em campo, invocações incluídas: o próximo golpe que cada um receber perde %d%% do dano. A proteção acaba nesse golpe ou depois de %d turnos de quem a tem; usar de novo renova, não soma." % [
				roundi(LORD_REDUCTION * 100), LORD_TURNS],
		},
		{
			"action": "lunar_blessing", "name": "Bênção Lunar", "key": "", "icon": FOLDER + "icon_lunar_blessing.png",
			"state": "ready", "target": "self", "passive": true, "color": MOON_COLOR,
			"description": "Quando ela cura outro aliado, recupera %d%% do que curou. Curar a si mesma não conta." % roundi(BLESSING * 100),
		},
	]


static func _mult_text(m: float) -> String:
	return str(m).replace(".", ",")

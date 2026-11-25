class_name Daimon
extends Combatant
## Kit do Daimon, usuário da Stand Cold (tipo Gelo, de Deep Bizarre Adventures
## Part 3). A Cold é um rifle de precisão: ele é o dano em alvo único.
##  Passiva: Holy Grail Powered Cold. Os tiros dele deixam Geada no alvo (até
##           3); cada Geada tira uma parte da DEF do alvo contra os ataques
##           dele. Com 3, o alvo fica Lento e ele ganha crítico garantido por
##           2 turnos dele. Enquanto isso os tiros não deixam Geada (senão o
##           crítico nunca acabaria); quando acaba, a Geada máxima zera.
##           Em alvo com Geada, os tiros dele nunca são pouco efetivos.
##  Básico: Disparo. Um tiro e 1 Geada; gera 1 ponto de skill.
##  Skill: Bala Congelante. Tiro mais forte e 2 Geadas.
##  Skill 2: Mira Fria. Trava a mira num alvo e segura o tiro por até 3
##           turnos: cada turno segurando deixa o tiro mais forte e 1 Geada no
##           alvo. Golpe Pesado nele derruba um nível; Q, E ou R baixam a mira.
##  Ult: Zero Absoluto. Tiro enorme no alvo, mais forte por Geada nele.

## Ajuste de balanceamento: tudo da Geada e do crítico garantido está aqui.
const FROST_MAX := 3
const FROST_DEF := 0.15  ## da DEF do alvo, por Geada, só contra ele
const COLD_DURATION := 2  ## turnos dele com crítico garantido
const SLOW_SPD := -0.3
const SLOW_DURATION := 2
const BASIC_FROST := 1
const BULLET_FROST := 2
const AIM_FROST := 1  ## por turno mirando (ao travar e a cada vez que segura)

const BASIC_MULT := 0.9
const BULLET_MULT := 1.4
## Mira Fria, por nível: soltar no turno seguinte ao de travar é o nível 1.
## Segurar até o fim custa 4 turnos sem outro tiro; o nível 3 com o crítico
## garantido (a mira cheia abre a janela) compensa isso.
const AIM_MULTS: Array[float] = [1.8, 2.8, 4.2]
const AIM_COOLDOWN := 4
const ZERO_MULT := 2.5
const ZERO_PER_FROST := 0.2

const ENERGY_BASIC := 20.0
const ENERGY_SKILL := 30.0
const ENERGY_AIM := 10.0  ## ao travar e a cada vez que segura
const ENERGY_RELEASE := 30.0
const ENERGY_ON_HIT := 10.0
const ULT_COST := 120.0

const FOLDER := "res://characters/daimon/"
const COLD_COLOR := Color(0.6, 0.9, 1.0)
const FROST_ID := "frost"

var cold_turns := 0  ## turnos que faltam de crítico garantido (0 = fora)
## A janela abriu neste turno: o fim dele não conta, para valerem 2 turnos
## inteiros depois do tiro que a abriu.
var _cold_fresh := false
var aim_level := 0  ## nível da Mira Fria (0 = sem mira)
var aim_target: Combatant  ## em quem a mira está travada


func _init() -> void:
	super("Daimon", true, 1000, 140.0, 42.0, 110.0, Types.ICE)
	max_energy = 120.0
	energy = 60.0
	energy_on_hit = ENERGY_ON_HIT


# ------------------------------------------------- Geada e crítico garantido
func in_cold() -> bool:
	return cold_turns > 0


func crit_chance() -> float:
	return 1.0 if in_cold() else super()


## Geadas do Daimon em `target`.
static func frost(target: Combatant) -> int:
	var e := target.status(FROST_ID)
	return e.stacks if e else 0


func defense_ignored(target: Combatant) -> float:
	return FROST_DEF * frost(target)


## A Geada congela a resistência: em alvo com Geada, o Gelo dele não é
## pouco efetivo. Sem isso, inimigos de Fogo (2x nele e 0,5x dos tiros
## dele) apagavam o kit inteiro (ver docs/jogo/personagens.md).
func resistance_ignored(target: Combatant) -> bool:
	return frost(target) > 0


static func frost_status(stacks: int) -> StatusEffect:
	var e := StatusEffect.new(FROST_ID, "Geada %d/%d" % [stacks, FROST_MAX], "G%d" % stacks, "debuff", -1)
	e.stacks = stacks
	e.color = COLD_COLOR
	e.detail = "DEF -%d%% contra o Daimon" % roundi(FROST_DEF * stacks * 100)
	return e


static func slow() -> StatusEffect:
	var e := StatusEffect.new("slow", "Lento", "LEN", "debuff", SLOW_DURATION)
	e.mods = {"spd": SLOW_SPD}
	e.color = COLD_COLOR
	e.detail = "VEL %d%%" % roundi(SLOW_SPD * 100)
	return e


## Deixa `amount` de Geada em `target`. Na janela de crítico não deixa nada.
## Ao chegar no máximo, o alvo fica Lento e a janela abre.
## Devolve {"added", "stacks", "cold" (a janela abriu agora)}.
func add_frost(target: Combatant, amount: int) -> Dictionary:
	var before := frost(target)
	if in_cold() or amount <= 0 or not target.is_alive() or before >= FROST_MAX:
		return {"added": 0, "stacks": before, "cold": false}
	var stacks := mini(FROST_MAX, before + amount)
	target.apply_status(frost_status(stacks))
	var opened := stacks >= FROST_MAX
	if opened:
		cold_turns = COLD_DURATION
		_cold_fresh = true
		target.apply_status(slow())
	return {"added": stacks - before, "stacks": stacks, "cold": opened}


## Fim do turno dele. Devolve true se o crítico garantido acabou agora.
func end_turn() -> bool:
	if cold_turns <= 0:
		return false
	if _cold_fresh:
		_cold_fresh = false
		return false
	cold_turns -= 1
	return cold_turns == 0


## O crítico garantido acabou: a Geada máxima zera nos `enemies`.
## Devolve em quem zerou.
func clear_full_frost(enemies: Array) -> Array:
	var cleared := []
	for e: Combatant in enemies:
		if frost(e) >= FROST_MAX:
			e.remove_status(FROST_ID)
			cleared.append(e)
	return cleared


# --------------------------------------------------------------- Mira Fria
func aiming() -> bool:
	return aim_level > 0


func start_aim(target: Combatant) -> void:
	aim_level = 1
	aim_target = target


func hold_aim() -> void:
	aim_level = mini(AIM_MULTS.size(), aim_level + 1)


func aim_mult() -> float:
	return AIM_MULTS[clampi(aim_level, 1, AIM_MULTS.size()) - 1]


## Solta o tiro: devolve o multiplicador e baixa a mira.
func release_aim() -> float:
	var mult := aim_mult()
	cancel_aim()
	return mult


## Baixa a mira sem atirar. Devolve se estava mirando.
func cancel_aim() -> bool:
	var was := aiming()
	aim_level = 0
	aim_target = null
	return was


func on_heavy_strike(hp_lost: int) -> Dictionary:
	if aim_level <= 1 or hp_lost <= 0:
		return {}
	aim_level -= 1
	return {"notice": "MIRA ABALADA", "log": "O golpe abala %s: a %s cai para o nível %d." % [
		UIStyle.fighter_name(self), UIStyle.highlight("Mira Fria", COLD_COLOR), aim_level]}


func zero_mult(target: Combatant) -> float:
	return ZERO_MULT + ZERO_PER_FROST * frost(target)


func use_ult() -> void:
	energy -= ULT_COST


# ------------------------------------------------- descrição para a interface
func can_use(action: String, points: int) -> bool:
	match action:
		"basic": return true
		"skill": return points > 0
		"skill2": return aiming() or (points > 0 and cooldown("skill2") == 0)
		"ult": return energy >= ULT_COST
	return false


func invalid_reason(action: String, option: String, _target: Combatant) -> String:
	if action == "skill2" and option == "hold" and aim_level >= AIM_MULTS.size():
		return "A mira já está no máximo: dispare."
	return ""


func predicted_targets(action: String, enemies: Array, _target: int) -> Array:
	if action == "skill2" and aiming() and aim_target in enemies:
		return [aim_target]
	return []


func skills(points: int) -> Array[Dictionary]:
	var aim := {
		"action": "skill2", "name": "Mira Fria", "key": "W", "icon": FOLDER + "icon_aim.png",
		"target": "single", "type": type, "cooldown": AIM_COOLDOWN, "color": COLD_COLOR,
		"description": "Ele trava a mira no alvo e segura o tiro por até %d turnos. A cada turno segurando, o tiro fica mais forte e deixa %d Geada no alvo." % [
			AIM_MULTS.size(), AIM_FROST],
		"details": [
			{"label": "Nível 1", "mark": "%sx" % _mult_text(AIM_MULTS[0]), "text": "Soltar no turno seguinte ao de travar.", "current": aim_level == 1},
			{"label": "Nível 2", "mark": "%sx" % _mult_text(AIM_MULTS[1]), "text": "Segurou mais 1 turno.", "current": aim_level == 2},
			{"label": "Nível 3", "mark": "%sx" % _mult_text(AIM_MULTS[2]), "text": "O máximo: só resta disparar.", "current": aim_level == 3},
			{"label": "Golpe Pesado", "text": "Se ele levar um mirando, a mira cai 1 nível."},
			{"label": "Q, E ou R", "text": "Baixam a mira sem atirar."},
		],
	}
	if aiming():
		# mirando: o W segura ou dispara, sem custo; o seletor abre sozinho
		# no começo da vez, e usar outra ação baixa a mira
		aim.merge({"state": "ready", "on_turn_start": true, "badge": "N%d" % aim_level, "cooldown_remaining": 0,
			"default_option": "hold" if aim_level < AIM_MULTS.size() else "fire",
			"options": [
				{"id": "hold", "name": "Segurar", "color": COLD_COLOR,
					"description": "Segura mais um turno: o tiro passa a %sx e deixa %d Geada no alvo." % [
						_mult_text(AIM_MULTS[mini(aim_level, AIM_MULTS.size() - 1)]), AIM_FROST]},
				{"id": "fire", "name": "Disparar", "color": Color.WHITE,
					"description": "Solta o tiro (%sx) no alvo travado." % _mult_text(aim_mult())},
			]})
	else:
		aim.merge({"state": "ready" if points > 0 else "no_resource", "point_cost": 1})
		aim = with_cooldown(aim)
	return [
		{
			"action": "basic", "name": "Disparo", "key": "Q", "icon": FOLDER + "icon_shot.png",
			"state": "ready", "target": "single", "type": type, "point_gain": 1,
			"description": "Tiro da Cold no alvo (%sx). Deixa %d Geada e gera 1 ponto de skill." % [_mult_text(BASIC_MULT), BASIC_FROST],
		},
		{
			"action": "skill", "name": "Bala Congelante", "key": "E", "icon": FOLDER + "icon_bullet.png",
			"state": "ready" if points > 0 else "no_resource", "target": "single", "type": type, "point_cost": 1,
			"color": COLD_COLOR,
			"description": "Bala de gelo concentrado no alvo (%sx). Deixa %d Geadas." % [_mult_text(BULLET_MULT), BULLET_FROST],
		},
		aim,
		{
			"action": "ult", "name": "Zero Absoluto", "key": "R", "icon": FOLDER + "icon_zero.png",
			"state": "ready" if energy >= ULT_COST else "no_resource", "target": "single", "type": type,
			"energy_cost": roundi(ULT_COST), "highlight": true, "color": COLD_COLOR,
			"description": "A Cold dispara o tiro decisivo no alvo (%sx), mais forte com Geada." % _mult_text(ZERO_MULT),
			"details": [
				{"label": "Por Geada no alvo", "mark": "+%sx" % _mult_text(ZERO_PER_FROST)},
				{"label": "Com %d Geadas" % FROST_MAX, "mark": "%sx" % _mult_text(ZERO_MULT + ZERO_PER_FROST * FROST_MAX)},
			],
		},
		{
			"action": "cold", "name": "Holy Grail Powered Cold", "key": "", "icon": FOLDER + "icon_cold.png",
			"state": "ready", "target": "self", "passive": true, "color": COLD_COLOR,
			"description": "Os tiros dele deixam Geada no alvo (até %d). Cada Geada tira %d%% da DEF do alvo contra os ataques dele. Com %d, o alvo fica Lento e o Daimon ganha crítico garantido por %d turnos dele; enquanto isso, os tiros não deixam Geada." % [
				FROST_MAX, roundi(FROST_DEF * 100), FROST_MAX, COLD_DURATION],
			"details": [
				{"label": "Disparo", "mark": "+%d" % BASIC_FROST},
				{"label": "Bala Congelante", "mark": "+%d" % BULLET_FROST},
				{"label": "Mira Fria", "mark": "+%d por turno mirando" % AIM_FROST},
				{"label": "Lento", "text": "VEL %d%% por %d turnos do alvo." % [roundi(SLOW_SPD * 100), SLOW_DURATION]},
				{"label": "Gelo que não cede", "text": "Em alvo com Geada, os tiros dele nunca são pouco efetivos."},
			],
		},
	]


static func _mult_text(m: float) -> String:
	return str(m).replace(".", ",")


func effects() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if aiming():
		list.append({"id": "aim", "short": "MF%d" % aim_level, "name": "Mira Fria: nível %d" % aim_level, "type": "buff",
			"turns": -1, "color": COLD_COLOR, "detail": "tiro de %sx pronto" % _mult_text(aim_mult())})
	if in_cold():
		list.append({"id": "cold", "short": "CLD", "name": "Cold: crítico garantido", "type": "buff",
			"turns": cold_turns, "color": COLD_COLOR, "detail": "todo golpe dele é crítico"})
	list.append_array(super())
	return list

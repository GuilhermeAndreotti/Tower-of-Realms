class_name Andri
extends Combatant
## Kit do Andri Findavil, inventor (tipo Fogo).
##  Passiva: Lente Elemental. No início de cada turno dele, o seletor da
##           lente abre para escolher o elemento (ou manter). O Disparo usa
##           esse elemento, e o MOMC, o robô assistente, ataca junto o mesmo
##           alvo com o mesmo elemento (golpe separado). Os artefatos que
##           causam dano também usam o elemento da lente na hora da entrega.
##  Básico: Disparo Elemental (gera 1 ponto de skill).
##  Skill: Análise de Vulnerabilidade. Cria no inimigo uma fraqueza ao
##         elemento de alguém da equipe: ele passa a ser super efetivo ali
##         por alguns turnos.
##  Skill 2: Protocolo MOMC. O robô dá um escudo pequeno a um aliado ou
##           dispara forte num inimigo, no elemento da lente.
##  Ult: Arsenal Titânico. Entrega um artefato a um aliado (ou a si mesmo).

const LENSES: Array[String] = [Types.FIRE, Types.WATER, Types.ICE, Types.ELECTRICITY,
	Types.NATURE, Types.POISON, Types.ACID]

## Ajuste de balanceamento. Disparo + MOMC somam 1,15x o ATQ, perto do
## Corte da Shumi (1,0x com ATQ maior).
const SHOT_MULT := 0.8
const MOMC_MULT := 0.35
const BASIC_ENERGY := 20.0
const SKILL_ENERGY := 30.0
const ENERGY_ON_HIT := 10.0
const ULT_COST := 120.0
const WEAKNESS_DURATION := 2  ## turnos do inimigo
const ARTIFACT_DURATION := 3  ## turnos do portador

const FREYA_HEAL := 0.30  ## do HP máximo do alvo
const TYR_SHIELD := 0.25  ## do HP máximo do alvo
const ODYN_CRIT := 0.5
const SLOW_SPD := -0.30  ## Manto de Hodir, no inimigo
const SLOW_DURATION := 2  ## turnos do inimigo
const THORIM_MULT := 0.30  ## proporcional ao golpe
const ARCHAEDAS_LIFE := 0.30  ## do HP máximo do alvo
const RA_MULT := 1.5
const LOKEN_DURATION := 2
const DECEIVED_ATK := -0.25
const DECEIVED_DELAY := 0.15

## Protocolo MOMC. O escudo é bem menor que o da Mão de Tyr, para não
## competir com a ult.
const MOMC_SHIELD := 0.10  ## do HP máximo do alvo
const MOMC_SHIELD_DURATION := 2  ## turnos do portador
const OVERLOAD_MULT := 0.9
const PROTOCOL_COOLDOWN := 3
const MOMC_COLOR := Color(0.55, 0.8, 1.0)

const FOLDER := "res://characters/andri/"
const ANDRI_COLOR := Color(1.0, 0.78, 0.3)

## Artefatos do Arsenal Titânico, na ordem do seletor. "{lente}" vira o
## elemento atual da lente.
const ARTIFACTS := [
	{"id": "odyn", "name": "Olho de Odyn", "color": Color(1.0, 0.8, 0.3),
		"description": "Precisão: +50% de chance de crítico por 3 turnos."},
	{"id": "tyr", "name": "Mão de Tyr", "color": Color(0.86, 0.9, 0.98),
		"description": "Proteção: escudo de 25% do HP máximo do alvo por 3 turnos."},
	{"id": "loken", "name": "Sussurro de Loken", "color": Color(0.66, 0.38, 0.95),
		"description": "Controle: por 2 turnos, quem o alvo acertar fica Enganado (ATQ -25% e a vez atrasa)."},
	{"id": "freya", "name": "Raiz de Freya", "color": Color(0.45, 0.85, 0.4),
		"description": "Restauração: cura 30% do HP máximo e remove os efeitos negativos."},
	{"id": "hodir", "name": "Manto de Hodir", "color": Color(0.7, 0.9, 1.0),
		"description": "Frio: o próximo inimigo que o alvo acertar fica Lento (VEL -30% por 2 turnos)."},
	{"id": "thorim", "name": "Braço de Thorim", "color": Color(0.35, 0.72, 1.0),
		"description": "Poder elemental: cada golpe causa +30% de dano extra de {lente} por 3 turnos."},
	{"id": "archaedas", "name": "Cinturão de Archaedas", "color": Color(0.9, 0.66, 0.3),
		"description": "Resistência: HP máximo +30% por 3 turnos."},
	{"id": "ra", "name": "Lança de Rá", "color": Color(1.0, 0.65, 0.25),
		"description": "Poder destrutivo: o próximo golpe do alvo causa +150% de dano extra de {lente}."},
]

var lens := Types.FIRE


func _init() -> void:
	super("Andri", true, 1000, 130.0, 45.0, 112.0, Types.FIRE)
	max_energy = 120.0
	energy = 60.0
	energy_on_hit = ENERGY_ON_HIT


# ----------------------------------------------------------------- lente
func switch_lens(element: String) -> bool:
	if element not in LENSES or element == lens:
		return false
	lens = element
	return true


## Golpes de um Disparo, na ordem: o do Andri e o do MOMC. Cada um é um
## golpe próprio (dano, efetividade e crítico calculados à parte). O do
## MOMC é marcado "extra": não dispara golpes adicionais nem estados de
## acerto, para nada se encadear a partir dele.
func shot_strikes() -> Array[Dictionary]:
	return [
		{"source": "andri", "type": lens, "mult": SHOT_MULT, "extra": false},
		{"source": "momc", "type": lens, "mult": MOMC_MULT, "extra": true},
	]


## Golpe da Sobrecarga do Protocolo: do MOMC, no elemento da lente. Marcado
## "extra" como o do Disparo, para nada se encadear a partir dele.
func overload_strike() -> Dictionary:
	return {"source": "momc", "type": lens, "mult": OVERLOAD_MULT, "extra": true}


static func momc_shield(target: Combatant) -> StatusEffect:
	var e := StatusEffect.new("momc_shield", "Escudo do MOMC", "MOM", "buff", MOMC_SHIELD_DURATION)
	e.shield = roundi(target.max_hp * MOMC_SHIELD)
	e.color = MOMC_COLOR
	return e


# -------------------------------------------------------------- análise
static func weakness(element: String) -> StatusEffect:
	var e := StatusEffect.new("weakness", "Fraqueza: " + Types.name(element), Types.abbr(element), "debuff", WEAKNESS_DURATION)
	e.weakness = element
	e.color = Types.color(element)
	e.detail = "%s é super efetivo" % Types.name(element)
	return e


## Elementos que a Análise pode expor: os tipos de quem da equipe está de
## pé, sem repetir, na ordem da equipe (sem batalha ou sem ninguém de pé,
## só o do próprio Andri).
func analysis_elements() -> Array[String]:
	var time: Array = living_allies.call() if living_allies.is_valid() else [self]
	var list: Array[String] = []
	for c: Combatant in time:
		if c.type not in list:
			list.append(c.type)
	if list.is_empty():  # a equipe caiu (a HUD ainda lê o kit no fim)
		list.append(type)
	return list


# -------------------------------------------------------------- arsenal
static func artifact(id: String) -> Dictionary:
	for a: Dictionary in ARTIFACTS:
		if a.id == id:
			return a
	return {}


## Estado que o artefato deixa no portador (null nos de efeito imediato).
## Escudo e vida extra dependem do HP máximo do `target`; o dano extra é do
## `element` (o da lente na hora da entrega).
static func artifact_status(id: String, target: Combatant, element: String) -> StatusEffect:
	var a := artifact(id)
	var e := StatusEffect.new("artifact_" + id, a.name, "", "buff", ARTIFACT_DURATION)
	e.color = a.color
	match id:
		"odyn":
			e.short = "ODN"
			e.mods = {"crit": ODYN_CRIT}
			e.detail = "+%d%% crítico" % roundi(ODYN_CRIT * 100)
		"tyr":
			e.short = "TYR"
			e.shield = roundi(target.max_hp * TYR_SHIELD)
		"loken":
			e.short = "LOK"
			e.turns = LOKEN_DURATION
			e.detail = "golpes enganam"
			e.on_hit = deceived
		"hodir":
			e.short = "HOD"
			e.on_hit = slow
			e.on_hit_consumes = true
			e.detail = "próximo golpe deixa Lento"
		"thorim":
			e.short = "THO"
			e.extra_strike = {"type": element, "mult": THORIM_MULT, "proportional": true}
			e.detail = "+%d%% %s" % [roundi(THORIM_MULT * 100), Types.name(element)]
		"archaedas":
			e.short = "ARC"
			# sobre o HP máximo sem um Cinturão anterior (que este substitui)
			var previous := target.state(e.id)
			var base := target.max_hp - (previous.extra_life if previous else 0)
			e.extra_life = roundi(base * ARCHAEDAS_LIFE)
			e.detail = "HP máx. +%d" % e.extra_life
		"ra":
			e.short = "RÁ"
			e.extra_strike = {"type": element, "mult": RA_MULT, "consumes": true}
			e.detail = "próximo golpe: +%s" % Types.name(element)
		_:
			return null
	return e


## Debuff que o Sussurro de Loken aplica em quem o portador acerta.
static func deceived() -> StatusEffect:
	var e := StatusEffect.new("deceived", "Enganado", "ENG", "debuff", LOKEN_DURATION)
	e.mods = {"atk": DECEIVED_ATK}
	e.delay = DECEIVED_DELAY
	e.detail = "ATQ %d%%" % roundi(DECEIVED_ATK * 100)
	return e


## Debuff que o Manto de Hodir aplica no próximo inimigo que o portador acertar.
static func slow() -> StatusEffect:
	var e := StatusEffect.new("slow", "Lento", "LEN", "debuff", SLOW_DURATION)
	e.mods = {"spd": SLOW_SPD}
	e.color = Color(0.7, 0.9, 1.0)
	e.detail = "VEL %d%%" % roundi(SLOW_SPD * 100)
	return e


## Usa o Arsenal: gasta a energia e aplica o artefato em `target`.
## Devolve {"state": StatusEffect ou null, "heal": int, "cleared": int}.
func use_artifact(id: String, target: Combatant) -> Dictionary:
	var r := {"state": null, "heal": 0, "cleared": 0}
	energy -= ULT_COST
	if id == "freya":
		r.heal = target.heal(roundi(target.max_hp * FREYA_HEAL))
		r.cleared = target.clear_debuffs()
		return r
	var e := artifact_status(id, target, lens)
	if e:
		target.apply_status(e)
		r.state = e
	return r


# ------------------------------------------------------ regras de uso
func invalid_reason(action: String, option: String, target: Combatant) -> String:
	match action:
		"skill":
			if option not in analysis_elements():
				return "Ninguém de pé na equipe é de %s." % Types.name(option)
			if target == null or target.ally:
				return "Escolha um inimigo."
			if target.type == Types.ARCANE:
				return "%s é Arcano: já recebe dano dobrado de tudo." % target.name
			if Types.effectiveness(option, target.type) >= Types.SUPER:
				return "%s já é fraco a %s." % [target.name, Types.name(option)]
		"skill2":
			match option:
				"shield":
					if target == null or not target.ally or not target.is_alive():
						return "Escolha um aliado de pé."
				"overload":
					if target == null or target.ally:
						return "Escolha um inimigo."
				_:
					return "Escolha um protocolo."
		"ult":
			var a := artifact(option)
			if a.is_empty():
				return "Escolha um artefato."
			if target == null or not target.ally or not target.is_alive():
				return "Escolha um aliado de pé."
			if option == "freya" and target.hp == target.max_hp and not target.has_debuff():
				return "%s está com HP cheio e sem efeitos negativos." % target.name
	return ""


# ------------------------------------------------- descrição para a interface
func can_use(action: String, points: int) -> bool:
	match action:
		"basic", "lens": return true
		"skill": return points > 0
		"skill2": return points > 0 and cooldown("skill2") == 0
		"ult": return energy >= ULT_COST
	return false


func skills(points: int) -> Array[Dictionary]:
	var lens_color := Types.color(lens)
	var lenses: Array[Dictionary] = []
	for t in LENSES:
		lenses.append({"id": t, "name": Types.name(t), "abbr": Types.abbr(t), "current": t == lens, "color": Types.color(t),
			"description": ("Mantém %s." if t == lens else "Disparo, MOMC e artefatos passam a causar dano de %s.") % Types.name(t)})
	var elements := analysis_elements()
	var analyses: Array[Dictionary] = []
	for t in elements:
		analyses.append({"id": t, "name": Types.name(t), "color": Types.color(t),
			"description": "%s passa a ser super efetivo no alvo por %d turnos." % [Types.name(t), WEAKNESS_DURATION]})
	var artifacts: Array[Dictionary] = []
	for a: Dictionary in ARTIFACTS:
		artifacts.append({"id": a.id, "name": a.name, "color": a.color,
			"description": (a.description as String).replace("{lente}", Types.name(lens)),
			"icon": FOLDER + "icon_%s.png" % a.id})
	var protocol: Array[Dictionary] = [
		{"id": "overload", "name": "Sobrecarga", "target": "single", "color": lens_color,
			"description": "O MOMC dispara forte no inimigo (%sx de %s)." % [str(OVERLOAD_MULT).replace(".", ","), Types.name(lens)]},
		{"id": "shield", "name": "Escudo", "target": "ally", "color": MOMC_COLOR,
			"description": "O MOMC protege um aliado: escudo de %d%% do HP máximo por %d turnos." % [roundi(MOMC_SHIELD * 100), MOMC_SHIELD_DURATION]},
	]
	return [
		{
			"action": "basic", "name": "Disparo", "key": "Q", "icon": FOLDER + "icon_shot.png",
			"state": "ready", "target": "single", "type": lens, "point_gain": 1,
			"badge": Types.abbr(lens), "color": lens_color,
			"description": "Disparo Elemental de %s no alvo; o MOMC ataca junto. Gera 1 ponto de skill." % Types.name(lens),
		},
		{
			"action": "skill", "name": "Análise", "key": "E", "icon": FOLDER + "icon_analysis.png",
			"state": "ready" if points > 0 else "no_resource", "target": "single", "point_cost": 1,
			"options": analyses, "default_option": elements[0],
			"description": "Análise de Vulnerabilidade: o alvo fica fraco ao elemento de alguém da equipe por %d turnos." % WEAKNESS_DURATION,
		},
		with_cooldown({
			"action": "skill2", "name": "Protocolo", "key": "W", "icon": FOLDER + "icon_protocol.png",
			"state": "ready" if points > 0 else "no_resource", "target": "single", "point_cost": 1,
			"cooldown": PROTOCOL_COOLDOWN, "badge": Types.abbr(lens), "color": lens_color,
			"options": protocol, "default_option": "overload",
			"description": "Protocolo MOMC: o robô protege um aliado ou dispara forte num inimigo. Escolha ao usar:",
			"details": _options_as_details(protocol),
		}),
		{
			"action": "ult", "name": "Arsenal", "key": "R", "icon": FOLDER + "icon_arsenal.png",
			"state": "ready" if energy >= ULT_COST else "no_resource", "target": "ally",
			"energy_cost": roundi(ULT_COST), "highlight": true, "color": ANDRI_COLOR,
			"options": artifacts,
			"description": "Arsenal Titânico: entrega um artefato a um aliado ou a si mesmo. Os efeitos duram %d turnos do portador, salvo quando o artefato diz outra coisa." % ARTIFACT_DURATION,
			"details": _options_as_details(artifacts),
		},
		{
			"action": "lens", "name": "Lente Elemental", "key": "", "icon": FOLDER + "icon_lens.png",
			"state": "ready", "target": "self", "free": true, "passive": true, "on_turn_start": true, "selector": "radial",
			"badge": Types.abbr(lens), "color": lens_color, "options": lenses, "default_option": lens,
			"description": "No início de cada turno, escolhe o elemento do Disparo, do MOMC e dos artefatos de dano.",
		},
	]


## Opções da ação no formato dos "details" (uma linha por opção). As
## descrições dos artefatos começam com o papel ("Proteção: ..."), que vira
## a marca ao lado do nome.
static func _options_as_details(options: Array[Dictionary]) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for o in options:
		var parts := (o.description as String).split(": ", true, 1)
		var role := parts[0] if parts.size() == 2 and parts[0].length() < 20 else ""
		var text: String = parts[1].left(1).to_upper() + parts[1].substr(1) if role != "" else o.description
		list.append({"label": o.name, "mark": role, "text": text,
			"color": o.get("color", ANDRI_COLOR)})
	return list


func effects() -> Array[Dictionary]:
	var list: Array[Dictionary] = [{"id": "lens", "short": Types.abbr(lens), "name": "Lente: " + Types.name(lens),
		"type": "buff", "turns": -1, "color": Types.color(lens), "detail": "Lente Elemental: " + Types.name(lens)}]
	list.append_array(super())
	return list

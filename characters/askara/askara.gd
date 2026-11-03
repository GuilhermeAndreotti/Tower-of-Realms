class_name Askara
extends Combatant
## Kit da Àskara, invocadora (tipo Trevas). Não usa energia: tudo gira em
## torno dos Fragmentos d'Alma.
##  Passiva: Fragmento d'Alma. Ganha 1 a cada Seta Vil e 1 sempre que um
##           inimigo cai; paga as invocações e o Lorde.
##  Básico: Seta Vil. Pouco dano; gera 1 ponto de skill e 1 fragmento.
##  Skill: Invocação. Chama um demônio por fragmentos (Diabrete, Emissário do
##         Caos, Lilith ou Shivara). Até 2 em campo, por algumas vezes cada.
##  Passiva: Último Ato. Cada demônio, ao sair por tempo ou cair, faz o
##           último ato dele. Fica no lugar da skill 2 (W): a força dela está
##           em deixar os demônios cumprirem o tempo.
##  Ult: Lorde Demônio. Custa fragmentos, 1 a menos por invocação em campo,
##       que ele apaga ao chegar; entra atacando todos. Com 15% de chance vem o
##       Lorde da Luz. Enquanto um Lorde está em campo, o E fica bloqueado.

## Ajuste de balanceamento. Seta Vil abaixo do Disparo do Andri (0,8x + 0,35x
## do MOMC): o dano baixo é o preço de ser a fonte de fragmentos.
const ARROW_MULT := 0.6
const MAX_FRAGMENTS := 8
const STARTING_FRAGMENTS := 2
const ARROW_FRAGMENTS := 1
const KILL_FRAGMENTS := 1  ## quando um inimigo cai
const SUMMON_FRAGMENTS := 1  ## na primeira ação de cada demônio (não do Lorde)
const MAX_SUMMONS := 2
const LORD_COST := 6
const DISCOUNT_PER_SUMMON := 1  ## cada invocação apagada pelo Lorde
const LIGHT_LORD_CHANCE := 0.15

const CHARM_ATK := -0.20
const CHARM_DEF := -0.20
const CHARM_DURATION := 2  ## turnos do inimigo
const EMISSARY_TAUNT := 2.0  ## 3x a chance de um aliado comum
## O Lorde tem um pouco de cada demônio: provoca menos que o Emissário (2x a
## chance) e enfraquece menos que a Lilith (o Encanto do Abismo, em todos).
const LORD_TAUNT := 1.0
const ABYSS_CHARM_ATK := -0.10
const ABYSS_CHARM_DEF := -0.10
const LIGHT_LORD_REDUCTION := 0.5

const FOLDER := "res://characters/askara/"
const ASKARA_COLOR := Color(0.72, 0.4, 0.95)
const VILE_COLOR := Color(0.5, 0.9, 0.3)

## Invocações, na ordem do seletor. Atributos em fração dos da Askara na
## hora da invocação ("hp", "atk", "def", "spd"); "turns" = vezes que age.
## O formato de "strike" está em Summon.strike; o de "last_act", em
## Summon.last_act.
const SUMMONS := [
	{"id": "imp", "name": "Diabrete", "abbr": "DIA", "fragments": 1, "turns": 3,
		"hp": 0.25, "atk": 1.0, "def": 0.8, "spd": 1.25, "color": Color(0.95, 0.6, 0.35),
		"strike": {"name": "Bola de Fogo Vil", "mult": 0.5, "reach": "single", "style": "projectile"},
		"last_act": {"name": "Explosão Vil", "mult": 0.5, "reach": "pair", "style": "dive"},
		"description": "Barato e rápido: Bola de Fogo Vil (0,5x) no alvo.",
		"act_description": "Mergulha no alvo e explode nele e no inimigo ao lado (0,5x)."},
	{"id": "emissary", "name": "Emissário do Caos", "abbr": "EMI", "fragments": 2, "turns": 3,
		"hp": 0.7, "atk": 1.0, "def": 1.5, "spd": 0.9, "color": Color(0.35, 0.5, 1.0), "taunt": EMISSARY_TAUNT,
		"strike": {"name": "Golpe do Caos", "mult": 0.4, "reach": "single", "style": "charge"},
		"last_act": {"name": "Muralha do Caos", "shield": 0.08},
		"description": "Tanque: provoca (os inimigos miram mais nele) e golpeia o alvo (0,4x).",
		"act_description": "Ergue uma muralha na frente do aliado com menos HP: escudo de 8% do HP máximo dele."},
	{"id": "lilith", "name": "Lilith", "abbr": "LIL", "fragments": 2, "turns": 3,
		"hp": 0.35, "atk": 1.0, "def": 1.0, "spd": 1.0, "color": Color(0.95, 0.85, 0.95), "debuff": "charm",
		"strike": {"name": "Encanto de Lilith", "mult": 0.3, "reach": "single", "aim": "strongest", "style": "projectile"},
		"last_act": {"name": "Beijo Final", "mult": 0.2, "reach": "all", "debuff_all": true, "style": "charge", "hit": "kiss"},
		"description": "Encanta o inimigo mais forte: ATQ e DEF -20% por 2 turnos (0,3x).",
		"act_description": "Voa até cada inimigo e encanta todos (0,2x)."},
	{"id": "shivara", "name": "Shivara", "abbr": "SHI", "fragments": 3, "turns": 3,
		"hp": 0.4, "atk": 1.0, "def": 1.0, "spd": 1.05, "color": Color(0.9, 0.45, 0.75),
		"strike": {"name": "Dança das Lâminas", "mult": 0.9, "reach": "neighbors", "neighbor_mult": 0.45, "style": "charge"},
		"last_act": {"name": "Última Dança", "mult": 0.4, "reach": "all", "style": "charge"},
		"description": "Dano: Dança das Lâminas no alvo (0,9x) e nos vizinhos (0,45x).",
		"act_description": "Golpeia todos os inimigos (0,4x)."},
]

## Os Lordes da ult, no mesmo formato, com o golpe de chegada em "entrance".
const LORDS := {
	"demon_lord": {"name": "Lorde Demônio", "turns": 3, "type": Types.DARKNESS,
		"hp": 0.8, "atk": 1.0, "def": 1.2, "spd": 1.0, "color": Color(1.0, 0.3, 0.25),
		"taunt": LORD_TAUNT, "debuff": "abyss_charm",
		"entrance": {"name": "Chegada do Lorde", "mult": 1.2, "reach": "all", "debuff_all": true, "style": "charge"},
		"strike": {"name": "Chama do Abismo", "mult": 0.8, "reach": "all", "debuff_all": true, "style": "charge"},
		"last_act": {"name": "Colapso do Abismo", "mult": 0.6, "reach": "all", "style": "dive"}},
	"light_lord": {"name": "Lorde da Luz", "turns": 3, "type": Types.LIGHT,
		"hp": 1.0, "atk": 1.0, "def": 1.2, "spd": 1.1, "color": Color(1.0, 0.95, 0.7), "reduction": LIGHT_LORD_REDUCTION,
		"taunt": LORD_TAUNT, "debuff": "abyss_charm",
		"entrance": {"name": "Julgamento", "mult": 2.0, "reach": "all", "debuff_all": true, "style": "charge"},
		"strike": {"name": "Lâmina Radiante", "mult": 1.2, "reach": "all", "debuff_all": true, "style": "charge"},
		"last_act": {"name": "Supernova", "mult": 0.9, "reach": "all", "style": "dive"}},
}

var fragments := STARTING_FRAGMENTS
## Todas as invocações desta luta; as que estão em campo têm in_play().
var summons: Array[Summon] = []


func _init() -> void:
	super("Àskara", true, 900, 125.0, 40.0, 108.0, Types.DARKNESS)


# ------------------------------------------------------------ fragmentos
## Soma fragmentos até o máximo. Devolve quantos entraram.
func gain_fragments(amount: int) -> int:
	var before := fragments
	fragments = mini(MAX_FRAGMENTS, fragments + amount)
	return fragments - before


func on_enemy_fallen() -> String:
	return "um Fragmento d'Alma" if gain_fragments(KILL_FRAGMENTS) > 0 else ""


## Só a primeira das vezes de cada demônio rende (renovar conta de novo);
## o Lorde não, para a ult não pagar a próxima.
func on_summon_acted(inv: Summon) -> String:
	if inv.id in LORDS or inv.turns < inv.max_turns:
		return ""
	return "um Fragmento d'Alma" if gain_fragments(SUMMON_FRAGMENTS) > 0 else ""


# ------------------------------------------------------------ invocações
static func summon_data(id: String) -> Dictionary:
	for d: Dictionary in SUMMONS:
		if d.id == id:
			return d
	return {}


func on_field() -> Array[Summon]:
	return summons.filter(func(i: Summon) -> bool: return i.in_play())


## O Lorde em campo (null se nenhum).
func lord() -> Summon:
	for i in on_field():
		if LORDS.has(i.id):
			return i
	return null


func lowest_cost() -> int:
	var lowest: int = SUMMONS[0].fragments
	for d: Dictionary in SUMMONS:
		lowest = mini(lowest, d.fragments)
	return lowest


func lord_cost() -> int:
	return maxi(0, LORD_COST - DISCOUNT_PER_SUMMON * on_field().size())


## Debuff que a Lilith deixa no inimigo mais forte.
static func charm() -> StatusEffect:
	var e := StatusEffect.new("charm", "Encantado", "ENC", "debuff", CHARM_DURATION)
	e.mods = {"atk": CHARM_ATK, "def": CHARM_DEF}
	e.color = Color(0.95, 0.6, 0.85)
	e.detail = "ATQ %d%% • DEF %d%%" % [roundi(CHARM_ATK * 100), roundi(CHARM_DEF * 100)]
	return e


## Debuff dos Lordes em todos que eles atingem: o encanto da Lilith, mais fraco.
## Id próprio, para não trocar o encanto dela, mais forte, se os dois pegarem.
static func abyss_charm() -> StatusEffect:
	var e := StatusEffect.new("abyss_charm", "Encanto do Abismo", "ABI", "debuff", CHARM_DURATION)
	e.mods = {"atk": ABYSS_CHARM_ATK, "def": ABYSS_CHARM_DEF}
	e.color = Color(0.85, 0.45, 0.6)
	e.detail = "ATQ %d%% • DEF %d%%" % [roundi(ABYSS_CHARM_ATK * 100), roundi(ABYSS_CHARM_DEF * 100)]
	return e


## Monta a invocação `id` com os dados `d`, a partir dos atributos de nível
## da Askara (sem os temporários, como a vida extra de um artefato).
func _create(id: String, d: Dictionary) -> Summon:
	var hp_base := max_hp - statuses.extra_life()
	var inv := Summon.new(id, d.name, self, maxi(1, roundi(hp_base * d.hp)), base_atk * d.atk,
		base_def * d.def, base_spd * d.spd, d.get("type", type), d.turns)
	inv.texture = FOLDER + id + ".png"
	inv.color = d.color
	inv.strike = d.strike
	inv.entrance_strike = d.get("entrance", {})
	inv.last_act = d.get("last_act", {})
	match d.get("debuff", ""):
		"charm": inv.debuff = charm
		"abyss_charm": inv.debuff = abyss_charm
	if d.has("taunt"):
		var p := StatusEffect.new("taunt", "Provocação", "PRV", "buff", -1)
		p.taunt = d.taunt
		p.detail = "os inimigos miram mais nele"
		inv.apply_status(p)
	if d.has("reduction"):
		var r := StatusEffect.new("resistance", "Resistência", "RES", "buff", -1)
		r.damage_reduction = d.reduction
		r.detail = "-%d%% de todo dano" % roundi(d.reduction * 100)
		inv.apply_status(r)
	summons.append(inv)
	return inv


## Invoca `id` pagando os fragmentos. A mesma já em campo é renovada; sem
## vaga, a mais antiga sai. Devolve {"summon", "is_new" (false = renovada),
## "replaced" (Summon que saiu para abrir vaga, ou null)}.
func summon(id: String) -> Dictionary:
	var d := summon_data(id)
	fragments -= d.fragments
	var field := on_field()
	for inv in field:
		if inv.id == id:
			inv.renew()
			return {"summon": inv, "is_new": false, "replaced": null}
	var replaced: Summon = null
	if field.size() >= MAX_SUMMONS:
		replaced = field[0]
		replaced.on_field = false
	return {"summon": _create(id, d), "is_new": true, "replaced": replaced}


## Chama o Lorde: paga (com o desconto), apaga as invocações em campo e
## sorteia qual vem (`roll` de 0 a 1, de fora para os testes fixarem).
## Devolve {"summon", "dismissed": Array[Summon], "rare": bool}.
func summon_lord(roll: float) -> Dictionary:
	fragments -= lord_cost()
	var dismissed := on_field()
	for inv in dismissed:
		inv.on_field = false
	var id := "light_lord" if roll < LIGHT_LORD_CHANCE else "demon_lord"
	return {"summon": _create(id, LORDS[id]), "dismissed": dismissed, "rare": id == "light_lord"}


# ------------------------------------------------------ regras de uso
func invalid_reason(action: String, option: String, _target: Combatant) -> String:
	match action:
		"skill":
			var d := summon_data(option)
			if d.is_empty():
				return "Escolha uma invocação."
			if lord():
				return "O %s não divide o campo." % lord().name
			if fragments < d.fragments:
				return "Faltam Fragmentos d'Alma: %d/%d." % [fragments, d.fragments]
	return ""


func can_use(action: String, points: int) -> bool:
	match action:
		"basic": return true
		"skill": return points > 0 and lord() == null and fragments >= lowest_cost()
		"ult": return lord() == null and fragments >= lord_cost()
	return false


# ------------------------------------------------- descrição para a interface
func skills(points: int) -> Array[Dictionary]:
	var field := on_field()
	var options: Array[Dictionary] = []
	var demons: Array[Dictionary] = []
	var acts: Array[Dictionary] = []
	for d: Dictionary in SUMMONS:
		var already := field.any(func(i: Summon) -> bool: return i.id == d.id)
		var cost := "%d fragmento%s" % [d.fragments, "" if d.fragments == 1 else "s"]
		options.append({"id": d.id, "name": "%s (%d)" % [d.name, d.fragments], "abbr": d.abbr, "color": d.color, "current": already,
			"description": "%s Último ato (%s): %s Custa %s; age %d vezes.%s" % [d.description, d.last_act.name,
				d.act_description, cost, d.turns, " Já em campo: renova." if already else ""]})
		demons.append({"label": d.name, "mark": cost + (" • em campo" if already else ""), "text": d.description,
			"color": d.color, "current": already})
		acts.append({"label": "%s • %s" % [d.name, d.last_act.name], "text": d.act_description, "color": d.color})
	var skill := {
		"action": "skill", "name": "Invocação", "key": "E", "icon": FOLDER + "icon_summon.png",
		"target": "self", "point_cost": 1, "selector": "radial", "color": ASKARA_COLOR,
		"options": options, "default_option": SUMMONS[0].id,
		"description": "Invoca um demônio com Fragmentos d'Alma. Cada um age %d vezes; até %d em campo (sem vaga, o mais antigo sai)." % [
			SUMMONS[0].turns, MAX_SUMMONS],
		"details": demons,
	}
	if lord():
		skill.merge({"state": "blocked", "missing_reason": "O %s não divide o campo." % lord().name})
	elif points > 0 and fragments >= lowest_cost():
		skill.state = "ready"
	else:
		skill.state = "no_resource"
		if points > 0:
			skill.missing_reason = "Faltam Fragmentos d'Alma: %d/%d." % [fragments, lowest_cost()]
	var cost := lord_cost()
	var ult := {
		"action": "ult", "name": "Lorde Demônio", "key": "R", "icon": FOLDER + "icon_lord.png",
		"target": "all", "type": type, "highlight": true, "color": LORDS.demon_lord.color, "badge": "%d FRA" % cost,
		"resource_cost": "%d fragmentos" % cost,
		"description": "Apaga as invocações em campo (cada uma desconta %d fragmento do custo), chega atacando todos os inimigos e fica %d vezes. Enquanto ele está em campo, não dá para invocar." % [
			DISCOUNT_PER_SUMMON, LORDS.demon_lord.turns],
		"details": [
			{"label": LORDS.demon_lord.name, "mark": "%d%%" % roundi((1 - LIGHT_LORD_CHANCE) * 100), "color": LORDS.demon_lord.color,
				"text": _lord_text(LORDS.demon_lord)},
			{"label": LORDS.light_lord.name, "mark": "%d%% • Luz" % roundi(LIGHT_LORD_CHANCE * 100), "color": LORDS.light_lord.color,
				"text": _lord_text(LORDS.light_lord) + " Recebe %d%% menos dano." % roundi(LIGHT_LORD_REDUCTION * 100)},
		],
	}
	if lord():
		ult.merge({"state": "blocked", "badge": "", "missing_reason": "O %s já está em campo." % lord().name})
	elif fragments >= cost:
		ult.state = "ready"
	else:
		ult.merge({"state": "no_resource", "missing_reason": "Faltam Fragmentos d'Alma: %d/%d." % [fragments, cost]})
	return [
		{
			"action": "basic", "name": "Seta Vil", "key": "Q", "icon": FOLDER + "icon_arrow.png",
			"state": "ready", "target": "single", "type": type, "point_gain": 1,
			"description": "Seta de energia vil no alvo, com pouco dano. Gera %d Fragmento d'Alma." % ARROW_FRAGMENTS,
		},
		skill,
		{
			"action": "last_act", "name": "Último Ato", "key": "", "icon": FOLDER + "icon_last_act.png",
			"state": "ready", "target": "self", "passive": true, "color": ASKARA_COLOR,
			"description": "Cada demônio, ao ir embora por tempo ou ao cair, faz um último ato. Não vale ao sair para abrir vaga, ao ser apagado pelo Lorde nem se a Àskara cair.",
			"details": acts,
		},
		ult,
		{
			"action": "fragments", "name": "Fragmento d'Alma", "key": "", "icon": FOLDER + "icon_fragment.png",
			"state": "ready", "target": "self", "passive": true, "color": ASKARA_COLOR,
			"description": "Pagam as invocações e o Lorde. Começa a luta com %d, máximo de %d." % [STARTING_FRAGMENTS, MAX_FRAGMENTS],
			"details": [
				{"label": "Seta Vil", "mark": "+%d" % ARROW_FRAGMENTS},
				{"label": "Inimigo derrotado", "mark": "+%d" % KILL_FRAGMENTS},
				{"label": "Primeira ação de cada demônio", "mark": "+%d" % SUMMON_FRAGMENTS},
			],
		},
	]


## Golpes do Lorde `l` (chegada e depois), para os detalhes da ult.
static func _lord_text(l: Dictionary) -> String:
	return "Chegada: %sx em todos. Depois: %sx em todos. Puxa os ataques, enfraquece quem acerta (ATQ e DEF %d%%) e, ao ir embora, explode em todos (%sx)." % [
		str(l.entrance.mult).replace(".", ","), str(l.strike.mult).replace(".", ","), roundi(ABYSS_CHARM_ATK * 100),
		str(l.last_act.mult).replace(".", ",")]


func effects() -> Array[Dictionary]:
	var list: Array[Dictionary] = [{"id": "fragments", "short": str(fragments), "name": "Fragmentos %d/%d" % [fragments, MAX_FRAGMENTS],
		"type": "buff", "turns": -1, "color": ASKARA_COLOR, "detail": "Fragmentos d'Alma: %d/%d" % [fragments, MAX_FRAGMENTS]}]
	list.append_array(super())
	return list

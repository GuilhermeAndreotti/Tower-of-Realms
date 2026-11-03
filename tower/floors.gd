class_name Floors
extends RefCounted
## Cadastro dos andares da Torre. Cada andar tem uma missão principal (o
## próprio andar: vencer libera o seguinte) e missões secundárias, opcionais,
## que abrem quando a principal é vencida. Cada ida à dungeon é uma missão:
## vence e volta ao saguão. Missões vencidas podem ser repetidas (dão XP de
## novo, mas os eventos de história só acontecem na primeira vitória). O que
## já foi vencido fica na Progression.
##
## Para pôr um andar novo: mais um item em LIST, na ordem. Nada mais muda.
## Missão secundária nova: mais um item no "side" do andar, com id novo.
##
## A escolha do andar só mostra nome, descrição, nível recomendado e tamanho
## da equipe; inimigos e XP aparecem depois da primeira vitória. Por isso a
## "description" é ambiente, não manual: nada de tipos, golpes ou cadência.
##
## Formato de cada andar (a missão principal):
## {
##     "name", "description",
##     "recommended_level": o nível de quem chega sem repetir nada (aviso
##         na escolha do andar; não bloqueia),
##     "level_limit": limite de nível da Torre enquanto este for o andar
##         mais alto liberado (ver level_limit()),
##     "max_team": quantos personagens podem entrar (até Roster.MAX_TEAM),
##     "background": cenário da batalha,
##     "enemies": [{"name", "texture", "hp", "atk", "def", "spd",
##                   "heavy_every"?, "type"? (Types), "xp"? (sem ela, a regra
##                   da Progression pelo HP), "last_resort"? (escudo quando
##                   está quase caindo; formato em Enemy.last_resort),
##                   "second_form"? (volta depois de derrotado; formato em
##                   Enemy.second_form)}],
##     "on_win"?: eventos da primeira vitória (formato em StoryEvents),
##     "side"?: [missões secundárias: {"id" (único na Torre; vai para o
##         save), "name", "description", "recommended_level", "enemies",
##         "max_team"?, "background"? (sem eles, os do andar), "on_win"?}],
## }
##
## Ritmo planejado (curva em Progression): a XP de cada andar leva quem não
## repete nada ao nível recomendado do seguinte (1 -> 2 -> 4 -> 6 -> 8 -> 10), e o
## limite deixa treinar só até 1 nível acima disso (uma repetição, mais ou
## menos). As secundárias do andar N abrem junto com o N+1 e são feitas para
## o recomendado dele: trocam a repetição da mesma luta por uma luta nova,
## sem passar do limite. Os tipos dos inimigos fazem a lente e a Análise do
## Andri serem escolhas, e não um x2 automático.

const DEFAULT_BACKGROUND := "res://tower/floor_background.png"
const FORGE_BACKGROUND := "res://tower/forge_background.png"
const SENTINEL := "res://enemies/sentinel.png"
const GUARDIAN := "res://enemies/guardian.png"
const GOLEM := "res://enemies/stone_golem.png"
const MOLTEN_GOLEM := "res://enemies/stone_golem_molten.png"
const FIRE_ELEMENTAL := "res://enemies/fire_elemental.png"
## Ferro Negro: abaixo de 30% do HP, um escudo de 25% do HP máximo por 3
## turnos, uma vez por luta (andar 5).
const BLACK_IRON := {"name": "Ferro Negro", "short": "FN", "below": 0.3, "shield": 0.25, "turns": 3}
## Golem Incandescente: derrotado, o Golem absorve os Elementais de pé e volta
## de Fogo, com HP e um laser em toda a equipe a cada 2 ações (andar 5).
const MOLTEN_CORE := {"name": "Golem Incandescente", "texture": MOLTEN_GOLEM, "type": Types.FIRE,
	"heal": 0.4, "heal_per_absorbed": 0.15, "beam": {"name": "Laser da Forja", "mult": 0.6, "every": 2}}

const LIST := [
	{
		# Shumi sozinha contra dois alvos simples: aprende Corte, Engo-ji e pontos.
		"name": "Vigia da Entrada",
		"description": "Na base da escada, olhos de pedra acendem quando alguém se aproxima. É aqui que a Torre mede quem chega.",
		"recommended_level": 1,
		"level_limit": 3,
		"max_team": 1,
		"background": DEFAULT_BACKGROUND,
		"enemies": [
			{"name": "Sentinela", "texture": SENTINEL, "hp": 420, "atk": 62.0, "def": 30.0, "spd": 92.0, "xp": 75},
			{"name": "Sentinela", "texture": SENTINEL, "hp": 420, "atk": 62.0, "def": 30.0, "spd": 100.0, "xp": 75},
		],
		"side": [
			{
				# três alvos fracos: o Engo-ji em área e a ordem dos alvos
				"id": "ronda",
				"name": "Ronda da Escada",
				"description": "Passos ecoam na escada mesmo com ela vazia. A Torre não gosta de ser deixada para trás.",
				"recommended_level": 2,
				"enemies": [
					{"name": "Sentinela", "texture": SENTINEL, "hp": 420, "atk": 66.0, "def": 30.0, "spd": 90.0, "xp": 60},
					{"name": "Sentinela", "texture": SENTINEL, "hp": 420, "atk": 66.0, "def": 30.0, "spd": 97.0, "xp": 60},
					{"name": "Sentinela", "texture": SENTINEL, "hp": 420, "atk": 66.0, "def": 30.0, "spd": 104.0, "xp": 60},
				],
			},
		],
	},
	{
		# o primeiro Golpe Pesado: pede o Kaioken na hora certa (o dreno pesa sozinha)
		"name": "Salão do Guardião",
		"description": "Um salão de teto alto e chão rachado. Algo grande dorme sob a poeira e acorda com passos.",
		"recommended_level": 2,
		"level_limit": 5,
		"max_team": 1,
		"background": DEFAULT_BACKGROUND,
		"enemies": [
			{"name": "Sentinela", "texture": SENTINEL, "hp": 560, "atk": 62.0, "def": 40.0, "spd": 98.0, "xp": 110},
			{"name": "Guardião", "texture": GUARDIAN, "hp": 1300, "atk": 74.0, "def": 55.0, "spd": 82.0, "heavy_every": 3, "xp": 240},
		],
		"on_win": [{"type": "unlock", "id": "andri"}],
		"side": [
			{
				# a primeira luta em dupla, para quem acabou de chegar: dois
				# Golpes Pesados que se alternam (velocidades diferentes)
				"id": "ecos",
				"name": "Ecos do Salão",
				"description": "Depois que o salão silenciou, a poeira voltou a se mexer. Desta vez, não está sozinha.",
				"recommended_level": 4,
				"max_team": 2,
				"enemies": [
					{"name": "Guardião", "texture": GUARDIAN, "hp": 1500, "atk": 210.0, "def": 55.0, "spd": 82.0, "heavy_every": 3, "xp": 200},
					{"name": "Guardião", "texture": GUARDIAN, "hp": 1500, "atk": 210.0, "def": 55.0, "spd": 94.0, "heavy_every": 3, "xp": 200},
				],
			},
		],
	},
	{
		# o Andri chega: as sentinelas Físicas caem rápido com a lente Ácido,
		# mas o Guardião de Veneno não é fraco a nenhuma lente (Análise ou
		# Engo-ji? os pontos de skill são da equipe) e a sentinela veloz age
		# quase duas vezes por rodada
		"name": "Guarnição",
		"description": "Os alojamentos da antiga guarda. As armas ainda estão nos suportes, e nem todos os vigias foram embora.",
		"recommended_level": 4,
		"level_limit": 7,
		"max_team": 2,
		"background": DEFAULT_BACKGROUND,
		"enemies": [
			{"name": "Sentinela", "texture": SENTINEL, "hp": 700, "atk": 175.0, "def": 45.0, "spd": 100.0, "xp": 150},
			{"name": "Guardião", "texture": GUARDIAN, "hp": 2000, "atk": 235.0, "def": 65.0, "spd": 84.0,
				"heavy_every": 3, "type": Types.POISON, "xp": 300},
			{"name": "Sentinela Veloz", "texture": SENTINEL, "hp": 560, "atk": 155.0, "def": 35.0, "spd": 128.0, "xp": 150},
		],
		"side": [
			{
				# três sentinelas velozes e frágeis: agem antes da equipe e
				# cobram dano em área ou foco rápido
				"id": "corredor",
				"name": "Corredor das Tochas",
				"description": "Um corredor estreito onde as tochas se apagam sozinhas. Quem passa por ali sente que está sendo seguido.",
				"recommended_level": 6,
				"enemies": [
					{"name": "Sentinela Veloz", "texture": SENTINEL, "hp": 800, "atk": 195.0, "def": 35.0, "spd": 124.0, "xp": 150},
					{"name": "Sentinela Veloz", "texture": SENTINEL, "hp": 800, "atk": 195.0, "def": 35.0, "spd": 130.0, "xp": 150},
					{"name": "Sentinela Veloz", "texture": SENTINEL, "hp": 800, "atk": 195.0, "def": 35.0, "spd": 136.0, "xp": 150},
				],
			},
			{
				# dois Guardiões de Veneno, sem lente super efetiva: a Análise
				# e os pontos de skill decidem a luta
				"id": "cisterna",
				"name": "Cisterna",
				"description": "Um poço fundo debaixo da guarnição, com um cheiro que arde no nariz. Alguém ainda cuida dele.",
				"recommended_level": 6,
				"enemies": [
					{"name": "Guardião", "texture": GUARDIAN, "hp": 1800, "atk": 195.0, "def": 65.0, "spd": 84.0,
						"heavy_every": 3, "type": Types.POISON, "xp": 250},
					{"name": "Guardião", "texture": GUARDIAN, "hp": 1800, "atk": 195.0, "def": 65.0, "spd": 90.0,
						"heavy_every": 3, "type": Types.POISON, "xp": 250},
				],
			},
		],
	},
	{
		# chefe de Trevas (nenhuma lente é super efetiva; Análise é o caminho)
		# com Golpe Pesado a cada 2 ações; a escolta castiga cada um: a de
		# Água é super efetiva no Andri (Fogo), a de Ácido na Shumi (Físico)
		"name": "Trono Sombrio",
		"description": "Um trono que nenhuma tocha ilumina. Quem se senta nele não gosta de visitas.",
		"recommended_level": 6,
		"level_limit": 9,
		"max_team": 2,
		"background": DEFAULT_BACKGROUND,
		"enemies": [
			{"name": "Sentinela de Água", "texture": SENTINEL, "hp": 720, "atk": 160.0, "def": 45.0, "spd": 106.0,
				"type": Types.WATER, "xp": 175},
			{"name": "Guardião Sombrio", "texture": GUARDIAN, "hp": 2700, "atk": 205.0, "def": 75.0, "spd": 90.0,
				"heavy_every": 2, "type": Types.DARKNESS, "xp": 550},
			{"name": "Sentinela de Ácido", "texture": SENTINEL, "hp": 720, "atk": 160.0, "def": 45.0, "spd": 116.0,
				"type": Types.ACID, "xp": 175},
		],
		"side": [
			{
				# Guardião de Água (2x no Andri) com escolta de Ácido (2x na
				# Shumi): cada um tem o seu problema
				"id": "capela",
				"name": "Capela Alagada",
				"description": "Uma capela submersa até os joelhos. O sino toca às vezes, e ninguém o puxa.",
				"recommended_level": 8,
				"enemies": [
					{"name": "Sentinela de Ácido", "texture": SENTINEL, "hp": 680, "atk": 150.0, "def": 45.0, "spd": 110.0,
						"type": Types.ACID, "xp": 175},
					{"name": "Guardião das Águas", "texture": GUARDIAN, "hp": 2100, "atk": 170.0, "def": 70.0, "spd": 88.0,
						"heavy_every": 3, "type": Types.WATER, "xp": 300},
					{"name": "Sentinela de Ácido", "texture": SENTINEL, "hp": 680, "atk": 150.0, "def": 45.0, "spd": 118.0,
						"type": Types.ACID, "xp": 175},
				],
			},
			{
				# dois Guardiões Sombrios com Golpe Pesado a cada 2 ações:
				# sem escolta, mas sem folga entre um golpe e outro
				"id": "vigilia",
				"name": "Vigília Sombria",
				"description": "Os servos do trono ainda montam guarda. Não sabem que o salão mudou de dono, ou não se importam.",
				"recommended_level": 8,
				"enemies": [
					{"name": "Guardião Sombrio", "texture": GUARDIAN, "hp": 1900, "atk": 185.0, "def": 75.0, "spd": 88.0,
						"heavy_every": 2, "type": Types.DARKNESS, "xp": 325},
					{"name": "Guardião Sombrio", "texture": GUARDIAN, "hp": 1900, "atk": 185.0, "def": 75.0, "spd": 96.0,
						"heavy_every": 2, "type": Types.DARKNESS, "xp": 325},
				],
			},
		],
	},
	{
		# a primeira luta a três: o Golem é Físico (a lente Ácido dobra nele)
		# e os elementais são de Fogo (a Água dobra neles), então o Andri
		# troca de lente conforme o alvo; o Ferro Negro dá escudo aos
		# elementais abaixo de 30%; derrotado, o Golem absorve quem sobrou e
		# volta incandescente (de Fogo), então derrubar os elementais antes
		# deixa a segunda forma mais fraca
		"name": "Forja de Pedra",
		"description": "O calor sobe pelos degraus antes da porta aparecer. Lá dentro, a pedra ainda está viva.",
		"recommended_level": 8,
		"level_limit": 11,
		"max_team": 3,
		"background": FORGE_BACKGROUND,
		"enemies": [
			{"name": "Elemental de Fogo", "texture": FIRE_ELEMENTAL, "hp": 1000, "atk": 360.0, "def": 45.0, "spd": 118.0,
				"type": Types.FIRE, "xp": 175, "last_resort": BLACK_IRON},
			{"name": "Golem de Pedra", "texture": GOLEM, "hp": 4800, "atk": 450.0, "def": 100.0, "spd": 82.0,
				"heavy_every": 3, "xp": 650, "second_form": MOLTEN_CORE},
			{"name": "Elemental de Fogo", "texture": FIRE_ELEMENTAL, "hp": 1000, "atk": 360.0, "def": 45.0, "spd": 124.0,
				"type": Types.FIRE, "xp": 175, "last_resort": BLACK_IRON},
		],
		"side": [
			{
				# três Elementais com o Ferro Negro: derrubar um de cada vez
				# ou espalhar o dano e enfrentar três escudos juntos
				"id": "fornalha",
				"name": "Fornalha",
				"description": "O coração da forja ainda pulsa. Cada brasa que salta parece ter vontade própria.",
				"recommended_level": 10,
				"enemies": [
					{"name": "Elemental de Fogo", "texture": FIRE_ELEMENTAL, "hp": 1250, "atk": 395.0, "def": 50.0, "spd": 116.0,
						"type": Types.FIRE, "xp": 200, "last_resort": BLACK_IRON},
					{"name": "Elemental de Fogo", "texture": FIRE_ELEMENTAL, "hp": 1250, "atk": 395.0, "def": 50.0, "spd": 122.0,
						"type": Types.FIRE, "xp": 200, "last_resort": BLACK_IRON},
					{"name": "Elemental de Fogo", "texture": FIRE_ELEMENTAL, "hp": 1250, "atk": 395.0, "def": 50.0, "spd": 128.0,
						"type": Types.FIRE, "xp": 200, "last_resort": BLACK_IRON},
				],
			},
			{
				# dois Golems Físicos, lentos e duros, sem segunda forma: uma
				# luta longa de resistência
				"id": "pedreira",
				"name": "Pedreira",
				"description": "De onde a Torre tirou a própria pedra. Algumas rochas ainda não aceitaram virar parede.",
				"recommended_level": 10,
				"background": DEFAULT_BACKGROUND,
				"enemies": [
					{"name": "Golem de Pedra", "texture": GOLEM, "hp": 3800, "atk": 400.0, "def": 100.0, "spd": 80.0, "heavy_every": 3, "xp": 450},
					{"name": "Golem de Pedra", "texture": GOLEM, "hp": 3800, "atk": 400.0, "def": 100.0, "spd": 88.0, "heavy_every": 3, "xp": 450},
				],
			},
		],
	},
]


static func total() -> int:
	return LIST.size()


## Dados do andar `number` (1 = o primeiro), que é também a missão principal.
static func data(number: int) -> Dictionary:
	if number < 1 or number > LIST.size():
		push_error("andar inexistente: %d" % number)
		return {}
	return LIST[number - 1]


## Missões secundárias do andar `number`, na ordem.
static func side_missions(number: int) -> Array:
	return data(number).get("side", [])


## Dados da missão `id` do andar `number` ("" = a principal). A secundária
## herda do andar o cenário e o tamanho da equipe quando não tem os seus.
static func mission(number: int, id := "") -> Dictionary:
	if id == "":
		return data(number)
	for s: Dictionary in side_missions(number):
		if s.id == id:
			var m := {"background": data(number).get("background", DEFAULT_BACKGROUND),
				"max_team": data(number).get("max_team", Roster.MAX_TEAM)}
			m.merge(s, true)
			return m
	push_error("missão inexistente: %d/%s" % [number, id])
	return {}


static func max_team(number: int, id := "") -> int:
	return clampi(mission(number, id).get("max_team", Roster.MAX_TEAM), 1, Roster.MAX_TEAM)


static func create_enemies(number: int, id := "") -> Array[Enemy]:
	var list: Array[Enemy] = []
	for d: Dictionary in mission(number, id).enemies:
		var foe := Enemy.new(d.name, d.texture, d.hp, d.atk, d.def, d.spd, d.get("heavy_every", 0), d.get("type", Types.PHYSICAL))
		foe.xp = d.get("xp", -1)
		foe.last_resort = d.get("last_resort", {})
		foe.second_form = d.get("second_form", {})
		list.append(foe)
	return list


# ------------------------------------------------------- estado (no save)
static func is_cleared(number: int) -> bool:
	return number in Progression.cleared_floors()


## Vencida ao menos uma vez ("" = a principal, o próprio andar).
static func is_mission_cleared(number: int, id := "") -> bool:
	return is_cleared(number) if id == "" else id in Progression.cleared_missions()


## Limite de nível da Torre agora: o do andar mais alto liberado (a única
## fonte desse limite; ver Progression). Repetir andares não o muda.
static func level_limit() -> int:
	return floor_limit(highest_unlocked())


## O limite enquanto `number` for o andar mais alto liberado.
static func floor_limit(number: int) -> int:
	return clampi(data(number).get("level_limit", Progression.MAX_LEVEL), 1, Progression.MAX_LEVEL)


## O 1 sempre; os outros, depois de vencer o anterior.
static func is_unlocked(number: int) -> bool:
	return number >= 1 and number <= total() and (number == 1 or is_cleared(number - 1))


## A principal junto com o andar; as secundárias depois da principal.
static func is_mission_unlocked(number: int, id := "") -> bool:
	if id == "":
		return is_unlocked(number)
	return is_unlocked(number) and is_cleared(number) and side_missions(number).any(
		func(s: Dictionary) -> bool: return s.id == id)


## O andar mais alto liberado.
static func highest_unlocked() -> int:
	var n := 1
	while n < total() and is_unlocked(n + 1):
		n += 1
	return n


## O andar escolhido para a próxima ida (um liberado; sem escolha, o mais alto).
static func current() -> int:
	var n := Progression.chosen_floor()
	return n if is_unlocked(n) else highest_unlocked()


## A missão escolhida no andar atual ("" = a principal, também quando a
## salva não existe mais ou não está liberada).
static func current_mission() -> String:
	var id := Progression.chosen_mission()
	return id if id != "" and is_mission_unlocked(current(), id) else ""


static func choose(number: int, id := "") -> void:
	if is_mission_unlocked(number, id):
		Progression.save_chosen_floor(number)
		Progression.save_chosen_mission(id)


## Registra a vitória na missão `id` do andar `number` ("" = a principal).
## Na primeira, aplica os eventos de "on_win" (StoryEvents.apply) e os deixa
## pendentes para o saguão apresentar. Devolve {"first", "events",
## "unlocked_floor" (o andar liberado agora, 0 se nenhum), "opened_side"
## (secundárias abertas agora), "limit_before", "limit_after" (limite de nível)}.
static func complete(number: int, id := "") -> Dictionary:
	var limit_before := level_limit()
	var first := not is_mission_cleared(number, id)
	var events: Array = mission(number, id).get("on_win", []).filter(StoryEvents.pending) if first else []
	if first:
		if id == "":
			Progression.mark_floor_cleared(number)
		else:
			Progression.mark_mission_cleared(id)
		for e: Dictionary in events:
			StoryEvents.apply(e)
		Progression.add_pending_events(events)
	var main_first := first and id == ""
	return {"first": first, "events": events, "unlocked_floor": number + 1 if main_first and number < total() else 0,
		"opened_side": side_missions(number).size() if main_first else 0,
		"limit_before": limit_before, "limit_after": level_limit()}

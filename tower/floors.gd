class_name Floors
extends RefCounted
## Cadastro dos andares da Torre. Cada ida à dungeon é um andar: vence e
## volta ao saguão. Vencer o andar N libera o N+1; andares vencidos podem
## ser repetidos (dão XP de novo, mas os eventos de história só acontecem
## na primeira vitória). O que já foi vencido fica na Progression.
##
## Para pôr um andar novo: mais um item em LIST, na ordem. Nada mais muda.
##
## Formato de cada andar:
## {
##     "name", "description",
##     "recommended_level": o nível de quem chega sem repetir andares (aviso
##         na escolha do andar; não bloqueia),
##     "level_limit": limite de nível da Torre enquanto este for o andar
##         mais alto liberado (ver level_limit()),
##     "max_team": quantos personagens podem entrar (até Roster.MAX_TEAM),
##     "background": cenário da batalha,
##     "enemies": [{"name", "texture", "hp", "atk", "def", "spd",
##                   "heavy_every"?, "type"? (Types), "xp"? (sem ela, a regra
##                   da Progression pelo HP), "last_resort"? (escudo quando
##                   está quase caindo; formato em Enemy.last_resort)}],
##     "on_win"?: eventos da primeira vitória (formato em StoryEvents),
## }
##
## Ritmo planejado (curva em Progression): a XP de cada andar leva quem não
## repete nada ao nível recomendado do seguinte (1 -> 2 -> 4 -> 6 -> 8 -> 10), e o
## limite deixa treinar só até 1 nível acima disso (uma repetição, mais ou
## menos). Os tipos dos inimigos fazem a lente e a Análise do Andri serem
## escolhas, e não um x2 automático.

const DEFAULT_BACKGROUND := "res://tower/floor_background.png"
const SENTINEL := "res://enemies/sentinel.png"
const GUARDIAN := "res://enemies/guardian.png"
const GOLEM := "res://enemies/stone_golem.png"
const FIRE_ELEMENTAL := "res://enemies/fire_elemental.png"
## Ferro Negro: abaixo de 30% do HP, um escudo de 25% do HP máximo por 3
## turnos, uma vez por luta (andar 5).
const BLACK_IRON := {"name": "Ferro Negro", "short": "FN", "below": 0.3, "shield": 0.25, "turns": 3}

const LIST := [
	{
		# Shumi sozinha contra dois alvos simples: aprende Corte, Engo-ji e pontos.
		"name": "Vigia da Entrada",
		"description": "Duas sentinelas guardam a escada. Um bom lugar para sentir a Torre.",
		"recommended_level": 1,
		"level_limit": 3,
		"max_team": 1,
		"background": DEFAULT_BACKGROUND,
		"enemies": [
			{"name": "Sentinela", "texture": SENTINEL, "hp": 420, "atk": 62.0, "def": 30.0, "spd": 92.0, "xp": 75},
			{"name": "Sentinela", "texture": SENTINEL, "hp": 420, "atk": 62.0, "def": 30.0, "spd": 100.0, "xp": 75},
		],
	},
	{
		# o primeiro Golpe Pesado: pede o Kaioken na hora certa (o dreno pesa sozinha)
		"name": "Salão do Guardião",
		"description": "Um Guardião vigia o salão. A cada três ações, ele solta um Golpe Pesado.",
		"recommended_level": 2,
		"level_limit": 5,
		"max_team": 1,
		"background": DEFAULT_BACKGROUND,
		"enemies": [
			{"name": "Sentinela", "texture": SENTINEL, "hp": 560, "atk": 62.0, "def": 40.0, "spd": 98.0, "xp": 110},
			{"name": "Guardião", "texture": GUARDIAN, "hp": 1300, "atk": 74.0, "def": 55.0, "spd": 82.0, "heavy_every": 3, "xp": 240},
		],
		"on_win": [{"type": "unlock", "id": "andri"}],
	},
	{
		# o Andri chega: as sentinelas Físicas caem rápido com a lente Ácido,
		# mas o Guardião de Veneno não é fraco a nenhuma lente (Análise ou
		# Engo-ji? os pontos de skill são da equipe) e a sentinela veloz age
		# quase duas vezes por rodada
		"name": "Guarnição",
		"description": "A guarda completa: duas sentinelas, uma delas veloz, e um Guardião de Veneno.",
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
	},
	{
		# chefe de Trevas (nenhuma lente é super efetiva; Análise é o caminho)
		# com Golpe Pesado a cada 2 ações; a escolta castiga cada um: a de
		# Água é super efetiva no Andri (Fogo), a de Ácido na Shumi (Físico)
		"name": "Trono Sombrio",
		"description": "O Guardião Sombrio, de Trevas, ataca pesado a cada duas ações. Sua escolta é de Água e de Ácido.",
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
	},
	{
		# a primeira luta a três: o Golem é Físico (a lente Ácido dobra nele)
		# e os elementais são de Fogo (a Água dobra neles), então o Andri
		# troca de lente conforme o alvo; o Ferro Negro dá escudo a quem
		# cai abaixo de 30%, e acabar com alguém pede guardar dano para depois
		"name": "Forja de Pedra",
		"description": "Um Golem de Pedra e dois Elementais de Fogo. Quase caindo, o Ferro Negro os cobre com um escudo.",
		"recommended_level": 8,
		"level_limit": 11,
		"max_team": 3,
		"background": DEFAULT_BACKGROUND,
		"enemies": [
			{"name": "Elemental de Fogo", "texture": FIRE_ELEMENTAL, "hp": 1000, "atk": 360.0, "def": 45.0, "spd": 118.0,
				"type": Types.FIRE, "xp": 175, "last_resort": BLACK_IRON},
			{"name": "Golem de Pedra", "texture": GOLEM, "hp": 4800, "atk": 450.0, "def": 100.0, "spd": 82.0,
				"heavy_every": 3, "xp": 650, "last_resort": BLACK_IRON},
			{"name": "Elemental de Fogo", "texture": FIRE_ELEMENTAL, "hp": 1000, "atk": 360.0, "def": 45.0, "spd": 124.0,
				"type": Types.FIRE, "xp": 175, "last_resort": BLACK_IRON},
		],
	},
]


static func total() -> int:
	return LIST.size()


## Dados do andar `number` (1 = o primeiro).
static func data(number: int) -> Dictionary:
	if number < 1 or number > LIST.size():
		push_error("andar inexistente: %d" % number)
		return {}
	return LIST[number - 1]


static func max_team(number: int) -> int:
	return clampi(data(number).get("max_team", Roster.MAX_TEAM), 1, Roster.MAX_TEAM)


static func create_enemies(number: int) -> Array[Enemy]:
	var list: Array[Enemy] = []
	for d: Dictionary in data(number).enemies:
		var foe := Enemy.new(d.name, d.texture, d.hp, d.atk, d.def, d.spd, d.get("heavy_every", 0), d.get("type", Types.PHYSICAL))
		foe.xp = d.get("xp", -1)
		foe.last_resort = d.get("last_resort", {})
		list.append(foe)
	return list


# ------------------------------------------------------- estado (no save)
static func is_cleared(number: int) -> bool:
	return number in Progression.cleared_floors()


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


static func choose(number: int) -> void:
	if is_unlocked(number):
		Progression.save_chosen_floor(number)


## Registra a vitória no andar `number`. Na primeira, aplica os eventos de
## "on_win" (StoryEvents.apply) e os deixa pendentes para o saguão
## apresentar. Devolve {"first", "events", "unlocked_floor" (o andar liberado
## agora, 0 se nenhum), "limit_before", "limit_after" (limite de nível)}.
static func complete(number: int) -> Dictionary:
	var limit_before := level_limit()
	var first := not is_cleared(number)
	var events: Array = data(number).get("on_win", []).filter(StoryEvents.pending) if first else []
	if first:
		Progression.mark_floor_cleared(number)
		for e: Dictionary in events:
			StoryEvents.apply(e)
		Progression.add_pending_events(events)
	return {"first": first, "events": events, "unlocked_floor": number + 1 if first and number < total() else 0,
		"limit_before": limit_before, "limit_after": level_limit()}

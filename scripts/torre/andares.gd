class_name Andares
extends RefCounted
## Cadastro dos andares da Torre. Cada ida à dungeon é um andar: vence e
## volta ao saguão. Vencer o andar N libera o N+1; andares vencidos podem
## ser repetidos (dão XP de novo, mas os eventos de história só acontecem
## na primeira vitória). O que já foi vencido fica na Progressao.
##
## Para pôr um andar novo: mais um item em LISTA, na ordem. Nada mais muda.
##
## Formato de cada andar:
## {
##     "nome", "descricao",
##     "nivel_recomendado": o nível de quem chega sem repetir andares (aviso
##         na escolha do andar; não bloqueia),
##     "limite_nivel": limite de nível da Torre enquanto este for o andar
##         mais alto liberado (ver limite_nivel()),
##     "max_equipe": quantos personagens podem entrar (até Elenco.MAX_EQUIPE),
##     "fundo": cenário da batalha,
##     "inimigos": [{"nome", "textura", "hp", "atq", "def", "vel",
##                   "pesado_a_cada"?, "tipo"? (Tipos), "xp"? (sem ela, a regra
##                   da Progressao pelo HP)}],
##     "ao_vencer"?: eventos da primeira vitória (formato em Eventos),
## }
##
## Ritmo planejado (curva em Progressao): a XP de cada andar leva quem não
## repete nada ao nível recomendado do seguinte (1 -> 2 -> 4 -> 6 -> 8), e o
## limite deixa treinar só até 1 nível acima disso (uma repetição, mais ou
## menos). Os tipos dos inimigos fazem a lente e a Análise do Andri serem
## escolhas, e não um x2 automático.

const FUNDO_PADRAO := "res://cenarios/torre_andar.png"
const SENTINELA := "res://inimigos/sentinela.png"
const GUARDIAO := "res://inimigos/guardiao.png"

const LISTA := [
	{
		# Shumi sozinha contra dois alvos simples: aprende Corte, Engo-ji e pontos.
		"nome": "Vigia da Entrada",
		"descricao": "Duas sentinelas guardam a escada. Um bom lugar para sentir a Torre.",
		"nivel_recomendado": 1,
		"limite_nivel": 3,
		"max_equipe": 1,
		"fundo": FUNDO_PADRAO,
		"inimigos": [
			{"nome": "Sentinela", "textura": SENTINELA, "hp": 420, "atq": 62.0, "def": 30.0, "vel": 92.0, "xp": 75},
			{"nome": "Sentinela", "textura": SENTINELA, "hp": 420, "atq": 62.0, "def": 30.0, "vel": 100.0, "xp": 75},
		],
	},
	{
		# o primeiro Golpe Pesado: pede o Kaioken na hora certa (o dreno pesa sozinha)
		"nome": "Salão do Guardião",
		"descricao": "Um Guardião vigia o salão. A cada três ações, ele solta um Golpe Pesado.",
		"nivel_recomendado": 2,
		"limite_nivel": 5,
		"max_equipe": 1,
		"fundo": FUNDO_PADRAO,
		"inimigos": [
			{"nome": "Sentinela", "textura": SENTINELA, "hp": 560, "atq": 62.0, "def": 40.0, "vel": 98.0, "xp": 110},
			{"nome": "Guardião", "textura": GUARDIAO, "hp": 1300, "atq": 74.0, "def": 55.0, "vel": 82.0, "pesado_a_cada": 3, "xp": 240},
		],
		"ao_vencer": [{"tipo": "desbloquear", "id": "andri"}],
	},
	{
		# o Andri chega: as sentinelas Físicas caem rápido com a lente Ácido,
		# mas o Guardião de Veneno não é fraco a nenhuma lente (Análise ou
		# Engo-ji? os pontos de skill são da equipe) e a sentinela veloz age
		# quase duas vezes por rodada
		"nome": "Guarnição",
		"descricao": "A guarda completa: duas sentinelas, uma delas veloz, e um Guardião de Veneno.",
		"nivel_recomendado": 4,
		"limite_nivel": 7,
		"max_equipe": 2,
		"fundo": FUNDO_PADRAO,
		"inimigos": [
			{"nome": "Sentinela", "textura": SENTINELA, "hp": 700, "atq": 175.0, "def": 45.0, "vel": 100.0, "xp": 150},
			{"nome": "Guardião", "textura": GUARDIAO, "hp": 2000, "atq": 235.0, "def": 65.0, "vel": 84.0,
				"pesado_a_cada": 3, "tipo": Tipos.VENENO, "xp": 300},
			{"nome": "Sentinela Veloz", "textura": SENTINELA, "hp": 560, "atq": 155.0, "def": 35.0, "vel": 128.0, "xp": 150},
		],
	},
	{
		# chefe de Trevas (nenhuma lente é super efetiva; Análise é o caminho)
		# com Golpe Pesado a cada 2 ações; a escolta castiga cada um: a de
		# Água é super efetiva no Andri (Fogo), a de Ácido na Shumi (Físico)
		"nome": "Trono Sombrio",
		"descricao": "O Guardião Sombrio, de Trevas, ataca pesado a cada duas ações. Sua escolta é de Água e de Ácido.",
		"nivel_recomendado": 6,
		"limite_nivel": 9,
		"max_equipe": 2,
		"fundo": FUNDO_PADRAO,
		"inimigos": [
			{"nome": "Sentinela de Água", "textura": SENTINELA, "hp": 720, "atq": 160.0, "def": 45.0, "vel": 106.0,
				"tipo": Tipos.AGUA, "xp": 175},
			{"nome": "Guardião Sombrio", "textura": GUARDIAO, "hp": 2700, "atq": 205.0, "def": 75.0, "vel": 90.0,
				"pesado_a_cada": 2, "tipo": Tipos.TREVAS, "xp": 550},
			{"nome": "Sentinela de Ácido", "textura": SENTINELA, "hp": 720, "atq": 160.0, "def": 45.0, "vel": 116.0,
				"tipo": Tipos.ACIDO, "xp": 175},
		],
	},
]


static func total() -> int:
	return LISTA.size()


## Dados do andar `numero` (1 = o primeiro).
static func dados(numero: int) -> Dictionary:
	if numero < 1 or numero > LISTA.size():
		push_error("andar inexistente: %d" % numero)
		return {}
	return LISTA[numero - 1]


static func max_equipe(numero: int) -> int:
	return clampi(dados(numero).get("max_equipe", Elenco.MAX_EQUIPE), 1, Elenco.MAX_EQUIPE)


static func criar_inimigos(numero: int) -> Array[Inimigo]:
	var lista: Array[Inimigo] = []
	for d: Dictionary in dados(numero).inimigos:
		var ini := Inimigo.new(d.nome, d.textura, d.hp, d.atq, d.def, d.vel, d.get("pesado_a_cada", 0), d.get("tipo", Tipos.FISICO))
		ini.xp = d.get("xp", -1)
		lista.append(ini)
	return lista


# ------------------------------------------------------- estado (no save)
static func vencido(numero: int) -> bool:
	return numero in Progressao.andares_vencidos()


## Limite de nível da Torre agora: o do andar mais alto liberado (a única
## fonte desse limite; ver Progressao). Repetir andares não o muda.
static func limite_nivel() -> int:
	return limite_do_andar(mais_alto_liberado())


## O limite enquanto `numero` for o andar mais alto liberado.
static func limite_do_andar(numero: int) -> int:
	return clampi(dados(numero).get("limite_nivel", Progressao.NIVEL_MAX), 1, Progressao.NIVEL_MAX)


## O 1 sempre; os outros, depois de vencer o anterior.
static func liberado(numero: int) -> bool:
	return numero >= 1 and numero <= total() and (numero == 1 or vencido(numero - 1))


## O andar mais alto liberado.
static func mais_alto_liberado() -> int:
	var n := 1
	while n < total() and liberado(n + 1):
		n += 1
	return n


## O andar escolhido para a próxima ida (um liberado; sem escolha, o mais alto).
static func atual() -> int:
	var n := Progressao.andar_escolhido()
	return n if liberado(n) else mais_alto_liberado()


static func escolher(numero: int) -> void:
	if liberado(numero):
		Progressao.salvar_andar_escolhido(numero)


## Registra a vitória no andar `numero`. Na primeira, aplica os eventos de
## "ao_vencer" (Eventos.aplicar) e os deixa pendentes para o saguão
## apresentar. Devolve {"primeira", "eventos", "liberou" (o andar liberado
## agora, 0 se nenhum), "limite_antes", "limite_depois" (limite de nível)}.
static func concluir(numero: int) -> Dictionary:
	var limite_antes := limite_nivel()
	var primeira := not vencido(numero)
	var eventos: Array = dados(numero).get("ao_vencer", []).filter(Eventos.pendente) if primeira else []
	if primeira:
		Progressao.marcar_andar_vencido(numero)
		for e: Dictionary in eventos:
			Eventos.aplicar(e)
		Progressao.adicionar_eventos_pendentes(eventos)
	return {"primeira": primeira, "eventos": eventos, "liberou": numero + 1 if primeira and numero < total() else 0,
		"limite_antes": limite_antes, "limite_depois": limite_nivel()}

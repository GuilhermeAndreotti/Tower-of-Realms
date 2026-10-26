class_name Askara
extends Combatente
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
const MULT_SETA := 0.6
const FRAGMENTOS_MAX := 8
const FRAGMENTOS_INICIAIS := 2
const FRAGMENTOS_SETA := 1
const FRAGMENTOS_ABATE := 1  ## quando um inimigo cai
const MAX_INVOCACOES := 2
const CUSTO_LORDE := 6
const DESCONTO_POR_INVOCACAO := 1  ## cada invocação apagada pelo Lorde
const CHANCE_LORDE_LUZ := 0.15

const ATQ_ENCANTO := -0.20
const DEF_ENCANTO := -0.20
const DURACAO_ENCANTO := 2  ## turnos do inimigo
const PROVOCACAO_EMISSARIO := 2.0  ## 3x a chance de um aliado comum
const REDUCAO_LORDE_LUZ := 0.5

const PASTA := "res://characters/askara/"
const COR_ASKARA := Color(0.72, 0.4, 0.95)
const COR_VIL := Color(0.5, 0.9, 0.3)

## Invocações, na ordem do seletor. Atributos em fração dos da Askara na
## hora da invocação ("hp", "atq", "def", "vel"); "turnos" = vezes que age.
## O formato de "golpe" está em Invocacao.golpe; o de "ultimo_ato", em
## Invocacao.ultimo_ato.
const INVOCACOES := [
	{"id": "diabrete", "nome": "Diabrete", "sigla": "DIA", "fragmentos": 1, "turnos": 3,
		"hp": 0.25, "atq": 1.0, "def": 0.8, "vel": 1.25, "cor": Color(0.95, 0.6, 0.35),
		"golpe": {"nome": "Bola de Fogo Vil", "mult": 0.5, "alcance": "unico", "estilo": "projetil"},
		"ultimo_ato": {"nome": "Explosão Vil", "mult": 0.5, "alcance": "dupla", "estilo": "projetil"},
		"descricao": "Barato e rápido: Bola de Fogo Vil (0,5x) no alvo.",
		"descricao_ato": "Explode no alvo e no inimigo ao lado (0,5x)."},
	{"id": "emissario", "nome": "Emissário do Caos", "sigla": "EMI", "fragmentos": 2, "turnos": 3,
		"hp": 0.7, "atq": 1.0, "def": 1.5, "vel": 0.9, "cor": Color(0.35, 0.5, 1.0), "provocacao": PROVOCACAO_EMISSARIO,
		"golpe": {"nome": "Golpe do Caos", "mult": 0.4, "alcance": "unico", "estilo": "investida"},
		"ultimo_ato": {"nome": "Muralha do Caos", "escudo": 0.08},
		"descricao": "Tanque: provoca (os inimigos miram mais nele) e golpeia o alvo (0,4x).",
		"descricao_ato": "Escudo de 8% do HP máximo dele no aliado com menos HP."},
	{"id": "lilith", "nome": "Lilith", "sigla": "LIL", "fragmentos": 2, "turnos": 3,
		"hp": 0.35, "atq": 1.0, "def": 1.0, "vel": 1.0, "cor": Color(0.95, 0.85, 0.95), "debuff": "encanto",
		"golpe": {"nome": "Encanto de Lilith", "mult": 0.3, "alcance": "unico", "mira": "mais_forte", "estilo": "projetil"},
		"ultimo_ato": {"nome": "Beijo Final", "mult": 0.2, "alcance": "todos", "debuff_em_todos": true, "estilo": "projetil"},
		"descricao": "Encanta o inimigo mais forte: ATQ e DEF -20% por 2 turnos (0,3x).",
		"descricao_ato": "Encanta todos os inimigos (0,2x)."},
	{"id": "shivara", "nome": "Shivara", "sigla": "SHI", "fragmentos": 3, "turnos": 3,
		"hp": 0.4, "atq": 1.0, "def": 1.0, "vel": 1.05, "cor": Color(0.9, 0.45, 0.75),
		"golpe": {"nome": "Dança das Lâminas", "mult": 0.9, "alcance": "vizinhos", "mult_vizinhos": 0.45, "estilo": "investida"},
		"ultimo_ato": {"nome": "Última Dança", "mult": 0.4, "alcance": "todos", "estilo": "investida"},
		"descricao": "Dano: Dança das Lâminas no alvo (0,9x) e nos vizinhos (0,45x).",
		"descricao_ato": "Golpeia todos os inimigos (0,4x)."},
]

## Os Lordes da ult, no mesmo formato, com o golpe de chegada em "entrada".
const LORDES := {
	"lorde_demonio": {"nome": "Lorde Demônio", "turnos": 3, "tipo": Tipos.TREVAS,
		"hp": 0.8, "atq": 1.0, "def": 1.2, "vel": 1.0, "cor": Color(1.0, 0.3, 0.25),
		"entrada": {"nome": "Chegada do Lorde", "mult": 1.2, "alcance": "todos", "estilo": "investida"},
		"golpe": {"nome": "Chama do Abismo", "mult": 0.8, "alcance": "todos", "estilo": "investida"}},
	"lorde_luz": {"nome": "Lorde da Luz", "turnos": 3, "tipo": Tipos.LUZ,
		"hp": 1.0, "atq": 1.0, "def": 1.2, "vel": 1.1, "cor": Color(1.0, 0.95, 0.7), "reducao": REDUCAO_LORDE_LUZ,
		"entrada": {"nome": "Julgamento", "mult": 2.0, "alcance": "todos", "estilo": "investida"},
		"golpe": {"nome": "Lâmina Radiante", "mult": 1.2, "alcance": "todos", "estilo": "investida"}},
}

var fragmentos := FRAGMENTOS_INICIAIS
## Todas as invocações desta luta; as que estão em campo têm em_jogo().
var invocacoes: Array[Invocacao] = []


func _init() -> void:
	super("Àskara", true, 950, 125.0, 40.0, 108.0, Tipos.TREVAS)


# ------------------------------------------------------------ fragmentos
## Soma fragmentos até o máximo. Devolve quantos entraram.
func ganhar_fragmentos(qtd: int) -> int:
	var antes := fragmentos
	fragmentos = mini(FRAGMENTOS_MAX, fragmentos + qtd)
	return fragmentos - antes


func ao_inimigo_cair() -> String:
	return "um Fragmento d'Alma" if ganhar_fragmentos(FRAGMENTOS_ABATE) > 0 else ""


# ------------------------------------------------------------ invocações
static func dados_invocacao(id: String) -> Dictionary:
	for d: Dictionary in INVOCACOES:
		if d.id == id:
			return d
	return {}


func em_campo() -> Array[Invocacao]:
	return invocacoes.filter(func(i: Invocacao) -> bool: return i.em_jogo())


## O Lorde em campo (null se nenhum).
func lorde() -> Invocacao:
	for i in em_campo():
		if LORDES.has(i.id):
			return i
	return null


func menor_custo() -> int:
	var menor: int = INVOCACOES[0].fragmentos
	for d: Dictionary in INVOCACOES:
		menor = mini(menor, d.fragmentos)
	return menor


func custo_lorde() -> int:
	return maxi(0, CUSTO_LORDE - DESCONTO_POR_INVOCACAO * em_campo().size())


## Debuff que a Lilith deixa no inimigo mais forte.
static func encanto() -> Estado:
	var e := Estado.new("encanto", "Encantado", "ENC", "debuff", DURACAO_ENCANTO)
	e.mods = {"atq": ATQ_ENCANTO, "def": DEF_ENCANTO}
	e.cor = Color(0.95, 0.6, 0.85)
	e.detalhe = "ATQ %d%% · DEF %d%%" % [roundi(ATQ_ENCANTO * 100), roundi(DEF_ENCANTO * 100)]
	return e


## Monta a invocação `id` com os dados `d`, a partir dos atributos de nível
## da Askara (sem os temporários, como a vida extra de um artefato).
func _criar(id: String, d: Dictionary) -> Invocacao:
	var hp_base := hp_max
	for e in estados:
		hp_base -= e.vida_extra
	var inv := Invocacao.new(id, d.nome, self, maxi(1, roundi(hp_base * d.hp)), atq_base * d.atq,
		def_base * d.def, vel_base * d.vel, d.get("tipo", tipo), d.turnos)
	inv.textura = PASTA + id + ".png"
	inv.cor = d.cor
	inv.golpe = d.golpe
	inv.golpe_entrada = d.get("entrada", {})
	inv.ultimo_ato = d.get("ultimo_ato", {})
	if d.get("debuff", "") == "encanto":
		inv.debuff = encanto
	if d.has("provocacao"):
		var p := Estado.new("provocacao", "Provocação", "PRV", "buff", -1)
		p.provocacao = d.provocacao
		p.detalhe = "os inimigos miram mais nele"
		inv.aplicar_estado(p)
	if d.has("reducao"):
		var r := Estado.new("resistencia", "Resistência", "RES", "buff", -1)
		r.reducao_dano = d.reducao
		r.detalhe = "-%d%% de todo dano" % roundi(d.reducao * 100)
		inv.aplicar_estado(r)
	invocacoes.append(inv)
	return inv


## Invoca `id` pagando os fragmentos. A mesma já em campo é renovada; sem
## vaga, a mais antiga sai. Devolve {"invocacao", "nova" (false = renovada),
## "sai" (Invocacao que saiu para abrir vaga, ou null)}.
func invocar(id: String) -> Dictionary:
	var d := dados_invocacao(id)
	fragmentos -= d.fragmentos
	var campo := em_campo()
	for inv in campo:
		if inv.id == id:
			inv.renovar()
			return {"invocacao": inv, "nova": false, "sai": null}
	var sai: Invocacao = null
	if campo.size() >= MAX_INVOCACOES:
		sai = campo[0]
		sai.em_campo = false
	return {"invocacao": _criar(id, d), "nova": true, "sai": sai}


## Chama o Lorde: paga (com o desconto), apaga as invocações em campo e
## sorteia qual vem (`sorteio` de 0 a 1, de fora para os testes fixarem).
## Devolve {"invocacao", "apagadas": Array[Invocacao], "raro": bool}.
func invocar_lorde(sorteio: float) -> Dictionary:
	fragmentos -= custo_lorde()
	var apagadas := em_campo()
	for inv in apagadas:
		inv.em_campo = false
	var id := "lorde_luz" if sorteio < CHANCE_LORDE_LUZ else "lorde_demonio"
	return {"invocacao": _criar(id, LORDES[id]), "apagadas": apagadas, "raro": id == "lorde_luz"}


# ------------------------------------------------------ regras de uso
func motivo_invalido(acao: String, opcao: String, _alvo: Combatente) -> String:
	match acao:
		"skill":
			var d := dados_invocacao(opcao)
			if d.is_empty():
				return "Escolha uma invocação."
			if lorde():
				return "O %s não divide o campo." % lorde().nome
			if fragmentos < d.fragmentos:
				return "Faltam Fragmentos d'Alma: %d/%d." % [fragmentos, d.fragmentos]
	return ""


func pode_usar(acao: String, pontos: int) -> bool:
	match acao:
		"basico": return true
		"skill": return pontos > 0 and lorde() == null and fragmentos >= menor_custo()
		"ult": return lorde() == null and fragmentos >= custo_lorde()
	return false


# ------------------------------------------------- descrição para a interface
func habilidades(pontos: int) -> Array[Dictionary]:
	var campo := em_campo()
	var opcoes: Array[Dictionary] = []
	var demonios: Array[Dictionary] = []
	var atos: Array[Dictionary] = []
	for d: Dictionary in INVOCACOES:
		var ja := campo.any(func(i: Invocacao) -> bool: return i.id == d.id)
		var custo := "%d fragmento%s" % [d.fragmentos, "" if d.fragmentos == 1 else "s"]
		opcoes.append({"id": d.id, "nome": "%s (%d)" % [d.nome, d.fragmentos], "sigla": d.sigla, "cor": d.cor, "atual": ja,
			"descricao": "%s Último ato (%s): %s Custa %s; age %d vezes.%s" % [d.descricao, d.ultimo_ato.nome,
				d.descricao_ato, custo, d.turnos, " Já em campo: renova." if ja else ""]})
		demonios.append({"rotulo": d.nome, "marca": custo + (" · em campo" if ja else ""), "texto": d.descricao,
			"cor": d.cor, "atual": ja})
		atos.append({"rotulo": "%s · %s" % [d.nome, d.ultimo_ato.nome], "texto": d.descricao_ato, "cor": d.cor})
	var skill := {
		"acao": "skill", "nome": "Invocação", "tecla": "E", "icone": PASTA + "icon_summon.png",
		"alvo": "proprio", "custo_pontos": 1, "seletor": "radial", "cor": COR_ASKARA,
		"opcoes": opcoes, "opcao_padrao": INVOCACOES[0].id,
		"descricao": "Invoca um demônio com Fragmentos d'Alma. Cada um age %d vezes; até %d em campo (sem vaga, o mais antigo sai)." % [
			INVOCACOES[0].turnos, MAX_INVOCACOES],
		"detalhes": demonios,
	}
	if lorde():
		skill.merge({"estado": "bloqueada", "falta": "O %s não divide o campo." % lorde().nome})
	elif pontos > 0 and fragmentos >= menor_custo():
		skill.estado = "pronta"
	else:
		skill.estado = "sem_recurso"
		if pontos > 0:
			skill.falta = "Faltam Fragmentos d'Alma: %d/%d." % [fragmentos, menor_custo()]
	var custo := custo_lorde()
	var ult := {
		"acao": "ult", "nome": "Lorde Demônio", "tecla": "R", "icone": PASTA + "icon_lord.png",
		"alvo": "todos", "tipo": tipo, "destaque": true, "cor": LORDES.lorde_demonio.cor, "selo": "%d FRA" % custo,
		"custo_recurso": "%d fragmentos" % custo,
		"descricao": "Apaga as invocações em campo (cada uma desconta %d fragmento do custo), chega atacando todos os inimigos e fica %d vezes. Enquanto ele está em campo, não dá para invocar." % [
			DESCONTO_POR_INVOCACAO, LORDES.lorde_demonio.turnos],
		"detalhes": [
			{"rotulo": LORDES.lorde_demonio.nome, "marca": "%d%%" % roundi((1 - CHANCE_LORDE_LUZ) * 100), "cor": LORDES.lorde_demonio.cor,
				"texto": _texto_lorde(LORDES.lorde_demonio)},
			{"rotulo": LORDES.lorde_luz.nome, "marca": "%d%% · Luz" % roundi(CHANCE_LORDE_LUZ * 100), "cor": LORDES.lorde_luz.cor,
				"texto": _texto_lorde(LORDES.lorde_luz) + " Recebe %d%% menos dano." % roundi(REDUCAO_LORDE_LUZ * 100)},
		],
	}
	if lorde():
		ult.merge({"estado": "bloqueada", "selo": "", "falta": "O %s já está em campo." % lorde().nome})
	elif fragmentos >= custo:
		ult.estado = "pronta"
	else:
		ult.merge({"estado": "sem_recurso", "falta": "Faltam Fragmentos d'Alma: %d/%d." % [fragmentos, custo]})
	return [
		{
			"acao": "basico", "nome": "Seta Vil", "tecla": "Q", "icone": PASTA + "icon_arrow.png",
			"estado": "pronta", "alvo": "unico", "tipo": tipo, "ganho_pontos": 1,
			"descricao": "Seta de energia vil no alvo, com pouco dano. Gera %d Fragmento d'Alma." % FRAGMENTOS_SETA,
		},
		skill,
		{
			"acao": "ultimo_ato", "nome": "Último Ato", "tecla": "", "icone": PASTA + "icon_last_act.png",
			"estado": "pronta", "alvo": "proprio", "passiva": true, "cor": COR_ASKARA,
			"descricao": "Cada demônio, ao ir embora por tempo ou ao cair, faz um último ato. Não vale ao sair para abrir vaga, ao ser apagado pelo Lorde nem se a Àskara cair.",
			"detalhes": atos,
		},
		ult,
		{
			"acao": "fragmentos", "nome": "Fragmento d'Alma", "tecla": "", "icone": PASTA + "icon_fragment.png",
			"estado": "pronta", "alvo": "proprio", "passiva": true, "cor": COR_ASKARA,
			"descricao": "Pagam as invocações e o Lorde. Começa a luta com %d, máximo de %d." % [FRAGMENTOS_INICIAIS, FRAGMENTOS_MAX],
			"detalhes": [
				{"rotulo": "Seta Vil", "marca": "+%d" % FRAGMENTOS_SETA},
				{"rotulo": "Inimigo derrotado", "marca": "+%d" % FRAGMENTOS_ABATE},
			],
		},
	]


## Golpes do Lorde `l` (chegada e depois), para os detalhes da ult.
static func _texto_lorde(l: Dictionary) -> String:
	return "Chegada: %sx em todos. Depois: %sx em todos." % [
		str(l.entrada.mult).replace(".", ","), str(l.golpe.mult).replace(".", ",")]


func efeitos() -> Array[Dictionary]:
	var lista: Array[Dictionary] = [{"id": "fragmentos", "curto": str(fragmentos), "nome": "Fragmentos %d/%d" % [fragmentos, FRAGMENTOS_MAX],
		"tipo": "buff", "turnos": -1, "cor": COR_ASKARA, "detalhe": "Fragmentos d'Alma: %d/%d" % [fragmentos, FRAGMENTOS_MAX]}]
	lista.append_array(super())
	return lista

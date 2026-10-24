class_name Andri
extends Combatente
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

const LENTES: Array[String] = [Tipos.FOGO, Tipos.AGUA, Tipos.GELO, Tipos.ELETRICIDADE,
	Tipos.NATUREZA, Tipos.VENENO, Tipos.ACIDO]

## Ajuste de balanceamento. Disparo + MOMC somam 1,15x o ATQ, perto do
## Corte da Shumi (1,0x com ATQ maior).
const MULT_DISPARO := 0.8
const MULT_MOMC := 0.35
const ENERGIA_BASICO := 20.0
const ENERGIA_SKILL := 30.0
const ENERGIA_AO_APANHAR := 10.0
const CUSTO_ULT := 120.0
const DURACAO_FRAQUEZA := 2  ## turnos do inimigo
const DURACAO_ARTEFATO := 3  ## turnos do portador

const CURA_FREYA := 0.30  ## do HP máximo do alvo
const ESCUDO_TYR := 0.25  ## do HP máximo do alvo
const CRIT_ODYN := 0.5
const VEL_LENTO := -0.30  ## Manto de Hodir, no inimigo
const DURACAO_LENTO := 2  ## turnos do inimigo
const MULT_THORIM := 0.30  ## proporcional ao golpe
const VIDA_ARCHAEDAS := 0.30  ## do HP máximo do alvo
const MULT_RA := 1.5
const DURACAO_LOKEN := 2
const ATQ_ENGANADO := -0.25
const ATRASO_ENGANADO := 0.15

## Protocolo MOMC. O escudo é bem menor que o da Mão de Tyr, para não
## competir com a ult.
const ESCUDO_MOMC := 0.10  ## do HP máximo do alvo
const DURACAO_ESCUDO_MOMC := 2  ## turnos do portador
const MULT_SOBRECARGA := 0.9
const RECARGA_PROTOCOLO := 3
const COR_MOMC := Color(0.55, 0.8, 1.0)

const PASTA := "res://personagens/andri/"
const COR_ANDRI := Color(1.0, 0.78, 0.3)

## Artefatos do Arsenal Titânico, na ordem do seletor. "{lente}" vira o
## elemento atual da lente.
const ARTEFATOS := [
	{"id": "odyn", "nome": "Olho de Odyn", "cor": Color(1.0, 0.8, 0.3),
		"descricao": "Precisão: +50% de chance de crítico por 3 turnos."},
	{"id": "tyr", "nome": "Mão de Tyr", "cor": Color(0.86, 0.9, 0.98),
		"descricao": "Proteção: escudo de 25% do HP máximo do alvo por 3 turnos."},
	{"id": "loken", "nome": "Sussurro de Loken", "cor": Color(0.66, 0.38, 0.95),
		"descricao": "Controle: por 2 turnos, quem o alvo acertar fica Enganado (ATQ -25% e a vez atrasa)."},
	{"id": "freya", "nome": "Raiz de Freya", "cor": Color(0.45, 0.85, 0.4),
		"descricao": "Restauração: cura 30% do HP máximo e remove os efeitos negativos."},
	{"id": "hodir", "nome": "Manto de Hodir", "cor": Color(0.7, 0.9, 1.0),
		"descricao": "Frio: o próximo inimigo que o alvo acertar fica Lento (VEL -30% por 2 turnos)."},
	{"id": "thorim", "nome": "Braço de Thorim", "cor": Color(0.35, 0.72, 1.0),
		"descricao": "Poder elemental: cada golpe causa +30% de dano extra de {lente} por 3 turnos."},
	{"id": "archaedas", "nome": "Cinturão de Archaedas", "cor": Color(0.9, 0.66, 0.3),
		"descricao": "Resistência: HP máximo +30% por 3 turnos."},
	{"id": "ra", "nome": "Lança de Rá", "cor": Color(1.0, 0.65, 0.25),
		"descricao": "Poder destrutivo: o próximo golpe do alvo causa +150% de dano extra de {lente}."},
]

var lente := Tipos.FOGO


func _init() -> void:
	super("Andri", true, 1000, 130.0, 45.0, 112.0, Tipos.FOGO)
	energia_max = 120.0
	energia = 60.0
	energia_ao_apanhar = ENERGIA_AO_APANHAR


# ----------------------------------------------------------------- lente
func trocar_lente(elemento: String) -> bool:
	if elemento not in LENTES or elemento == lente:
		return false
	lente = elemento
	return true


## Golpes de um Disparo, na ordem: o do Andri e o do MOMC. Cada um é um
## golpe próprio (dano, efetividade e crítico calculados à parte). O do
## MOMC é marcado "extra": não dispara golpes adicionais nem estados de
## acerto, para nada se encadear a partir dele.
func golpes_disparo() -> Array[Dictionary]:
	return [
		{"fonte": "andri", "tipo": lente, "mult": MULT_DISPARO, "extra": false},
		{"fonte": "momc", "tipo": lente, "mult": MULT_MOMC, "extra": true},
	]


## Golpe da Sobrecarga do Protocolo: do MOMC, no elemento da lente. Marcado
## "extra" como o do Disparo, para nada se encadear a partir dele.
func golpe_sobrecarga() -> Dictionary:
	return {"fonte": "momc", "tipo": lente, "mult": MULT_SOBRECARGA, "extra": true}


static func escudo_momc(alvo: Combatente) -> Estado:
	var e := Estado.new("escudo_momc", "Escudo do MOMC", "MOM", "buff", DURACAO_ESCUDO_MOMC)
	e.escudo = roundi(alvo.hp_max * ESCUDO_MOMC)
	e.cor = COR_MOMC
	return e


# -------------------------------------------------------------- análise
static func fraqueza(elemento: String) -> Estado:
	var e := Estado.new("fraqueza", "Fraqueza: " + Tipos.nome(elemento), Tipos.sigla(elemento), "debuff", DURACAO_FRAQUEZA)
	e.fraqueza = elemento
	e.cor = Tipos.cor(elemento)
	e.detalhe = "%s é super efetivo" % Tipos.nome(elemento)
	return e


## Elementos que a Análise pode expor: os tipos de quem da equipe está de
## pé, sem repetir, na ordem da equipe (sem batalha ou sem ninguém de pé,
## só o do próprio Andri).
func elementos_analise() -> Array[String]:
	var time: Array = aliados_vivos.call() if aliados_vivos.is_valid() else [self]
	var lista: Array[String] = []
	for c: Combatente in time:
		if c.tipo not in lista:
			lista.append(c.tipo)
	if lista.is_empty():  # a equipe caiu (a HUD ainda lê o kit no fim)
		lista.append(tipo)
	return lista


# -------------------------------------------------------------- arsenal
static func artefato(id: String) -> Dictionary:
	for a: Dictionary in ARTEFATOS:
		if a.id == id:
			return a
	return {}


## Estado que o artefato deixa no portador (null nos de efeito imediato).
## Escudo e vida extra dependem do HP máximo do `alvo`; o dano extra é do
## `elemento` (o da lente na hora da entrega).
static func estado_artefato(id: String, alvo: Combatente, elemento: String) -> Estado:
	var a := artefato(id)
	var e := Estado.new("artefato_" + id, a.nome, "", "buff", DURACAO_ARTEFATO)
	e.cor = a.cor
	match id:
		"odyn":
			e.curto = "ODN"
			e.mods = {"crit": CRIT_ODYN}
			e.detalhe = "+%d%% crítico" % roundi(CRIT_ODYN * 100)
		"tyr":
			e.curto = "TYR"
			e.escudo = roundi(alvo.hp_max * ESCUDO_TYR)
		"loken":
			e.curto = "LOK"
			e.turnos = DURACAO_LOKEN
			e.detalhe = "golpes enganam"
			e.ao_acertar = enganado
		"hodir":
			e.curto = "HOD"
			e.ao_acertar = lento
			e.ao_acertar_consome = true
			e.detalhe = "próximo golpe deixa Lento"
		"thorim":
			e.curto = "THO"
			e.golpe_extra = {"tipo": elemento, "mult": MULT_THORIM, "proporcional": true}
			e.detalhe = "+%d%% %s" % [roundi(MULT_THORIM * 100), Tipos.nome(elemento)]
		"archaedas":
			e.curto = "ARC"
			# sobre o HP máximo sem um Cinturão anterior (que este substitui)
			var anterior := alvo.estado(e.id)
			var base := alvo.hp_max - (anterior.vida_extra if anterior else 0)
			e.vida_extra = roundi(base * VIDA_ARCHAEDAS)
			e.detalhe = "HP máx. +%d" % e.vida_extra
		"ra":
			e.curto = "RÁ"
			e.golpe_extra = {"tipo": elemento, "mult": MULT_RA, "consome": true}
			e.detalhe = "próximo golpe: +%s" % Tipos.nome(elemento)
		_:
			return null
	return e


## Debuff que o Sussurro de Loken aplica em quem o portador acerta.
static func enganado() -> Estado:
	var e := Estado.new("enganado", "Enganado", "ENG", "debuff", DURACAO_LOKEN)
	e.mods = {"atq": ATQ_ENGANADO}
	e.atraso = ATRASO_ENGANADO
	e.detalhe = "ATQ %d%%" % roundi(ATQ_ENGANADO * 100)
	return e


## Debuff que o Manto de Hodir aplica no próximo inimigo que o portador acertar.
static func lento() -> Estado:
	var e := Estado.new("lento", "Lento", "LEN", "debuff", DURACAO_LENTO)
	e.mods = {"vel": VEL_LENTO}
	e.cor = Color(0.7, 0.9, 1.0)
	e.detalhe = "VEL %d%%" % roundi(VEL_LENTO * 100)
	return e


## Usa o Arsenal: gasta a energia e aplica o artefato em `alvo`.
## Devolve {"estado": Estado ou null, "cura": int, "limpos": int}.
func usar_artefato(id: String, alvo: Combatente) -> Dictionary:
	var r := {"estado": null, "cura": 0, "limpos": 0}
	energia -= CUSTO_ULT
	if id == "freya":
		r.cura = alvo.curar(roundi(alvo.hp_max * CURA_FREYA))
		r.limpos = alvo.limpar_debuffs()
		return r
	var e := estado_artefato(id, alvo, lente)
	if e:
		alvo.aplicar_estado(e)
		r.estado = e
	return r


# ------------------------------------------------------ regras de uso
func motivo_invalido(acao: String, opcao: String, alvo: Combatente) -> String:
	match acao:
		"skill":
			if opcao not in elementos_analise():
				return "Ninguém de pé na equipe é de %s." % Tipos.nome(opcao)
			if alvo == null or alvo.aliado:
				return "Escolha um inimigo."
			if alvo.tipo == Tipos.ARCANO:
				return "%s é Arcano: já recebe dano dobrado de tudo." % alvo.nome
			if Tipos.efetividade(opcao, alvo.tipo) >= Tipos.SUPER:
				return "%s já é fraco a %s." % [alvo.nome, Tipos.nome(opcao)]
		"skill2":
			match opcao:
				"escudo":
					if alvo == null or not alvo.aliado or not alvo.vivo():
						return "Escolha um aliado de pé."
				"sobrecarga":
					if alvo == null or alvo.aliado:
						return "Escolha um inimigo."
				_:
					return "Escolha um protocolo."
		"ult":
			var a := artefato(opcao)
			if a.is_empty():
				return "Escolha um artefato."
			if alvo == null or not alvo.aliado or not alvo.vivo():
				return "Escolha um aliado de pé."
			if opcao == "freya" and alvo.hp == alvo.hp_max and not alvo.tem_debuff():
				return "%s está com HP cheio e sem efeitos negativos." % alvo.nome
	return ""


# ------------------------------------------------- descrição para a interface
func pode_usar(acao: String, pontos: int) -> bool:
	match acao:
		"basico", "lente": return true
		"skill": return pontos > 0
		"skill2": return pontos > 0 and recarga("skill2") == 0
		"ult": return energia >= CUSTO_ULT
	return false


func habilidades(pontos: int) -> Array[Dictionary]:
	var cor_lente := Tipos.cor(lente)
	var lentes: Array[Dictionary] = []
	for t in LENTES:
		lentes.append({"id": t, "nome": Tipos.nome(t), "sigla": Tipos.sigla(t), "atual": t == lente, "cor": Tipos.cor(t),
			"descricao": ("Mantém %s." if t == lente else "Disparo, MOMC e artefatos passam a causar dano de %s.") % Tipos.nome(t)})
	var elementos := elementos_analise()
	var analises: Array[Dictionary] = []
	for t in elementos:
		analises.append({"id": t, "nome": Tipos.nome(t), "cor": Tipos.cor(t),
			"descricao": "%s passa a ser super efetivo no alvo por %d turnos." % [Tipos.nome(t), DURACAO_FRAQUEZA]})
	var artefatos: Array[Dictionary] = []
	for a: Dictionary in ARTEFATOS:
		artefatos.append({"id": a.id, "nome": a.nome, "cor": a.cor,
			"descricao": (a.descricao as String).replace("{lente}", Tipos.nome(lente)),
			"icone": PASTA + "icone_%s.png" % a.id})
	return [
		{
			"acao": "basico", "nome": "Disparo", "tecla": "Q", "icone": PASTA + "icone_disparo.png",
			"estado": "pronta", "alvo": "unico", "tipo": lente, "ganho_pontos": 1,
			"selo": Tipos.sigla(lente), "cor": cor_lente,
			"descricao": "Disparo Elemental de %s no alvo; o MOMC ataca junto. Gera 1 ponto de skill." % Tipos.nome(lente),
		},
		{
			"acao": "skill", "nome": "Análise", "tecla": "E", "icone": PASTA + "icone_analise.png",
			"estado": "pronta" if pontos > 0 else "sem_recurso", "alvo": "unico", "custo_pontos": 1,
			"opcoes": analises, "opcao_padrao": elementos[0],
			"descricao": "Análise de Vulnerabilidade: o alvo fica fraco ao elemento de alguém da equipe por %d turnos." % DURACAO_FRAQUEZA,
		},
		com_recarga({
			"acao": "skill2", "nome": "Protocolo", "tecla": "W", "icone": PASTA + "icone_protocolo.png",
			"estado": "pronta" if pontos > 0 else "sem_recurso", "alvo": "unico", "custo_pontos": 1,
			"recarga": RECARGA_PROTOCOLO, "selo": Tipos.sigla(lente), "cor": cor_lente,
			"opcoes": [
				{"id": "sobrecarga", "nome": "Sobrecarga", "alvo": "unico", "cor": cor_lente,
					"descricao": "O MOMC dispara forte no inimigo (%sx de %s)." % [str(MULT_SOBRECARGA).replace(".", ","), Tipos.nome(lente)]},
				{"id": "escudo", "nome": "Escudo", "alvo": "aliado", "cor": COR_MOMC,
					"descricao": "O MOMC protege um aliado: escudo de %d%% do HP máximo por %d turnos." % [roundi(ESCUDO_MOMC * 100), DURACAO_ESCUDO_MOMC]},
			],
			"opcao_padrao": "sobrecarga",
			"descricao": "Protocolo MOMC: o robô dá um escudo pequeno a um aliado ou dispara forte num inimigo com o elemento da lente. Recarga de %d turnos." % RECARGA_PROTOCOLO,
		}),
		{
			"acao": "ult", "nome": "Arsenal", "tecla": "R", "icone": PASTA + "icone_arsenal.png",
			"estado": "pronta" if energia >= CUSTO_ULT else "sem_recurso", "alvo": "aliado",
			"custo_energia": roundi(CUSTO_ULT), "destaque": true, "cor": COR_ANDRI,
			"opcoes": artefatos,
			"descricao": "Arsenal Titânico: entrega um artefato a um aliado ou a si mesmo.",
		},
		{
			"acao": "lente", "nome": "Lente Elemental", "tecla": "", "icone": PASTA + "icone_lente.png",
			"estado": "pronta", "alvo": "proprio", "livre": true, "passiva": true, "ao_iniciar_turno": true, "seletor": "radial",
			"selo": Tipos.sigla(lente), "cor": cor_lente, "opcoes": lentes, "opcao_padrao": lente,
			"descricao": "Passiva: no início de cada turno, escolhe o elemento do Disparo, do MOMC e dos artefatos de dano.",
		},
	]


func efeitos() -> Array[Dictionary]:
	var lista: Array[Dictionary] = [{"id": "lente", "curto": Tipos.sigla(lente), "nome": "Lente: " + Tipos.nome(lente),
		"tipo": "buff", "turnos": -1, "cor": Tipos.cor(lente), "detalhe": "Lente Elemental: " + Tipos.nome(lente)}]
	lista.append_array(super())
	return lista

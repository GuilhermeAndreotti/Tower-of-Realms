class_name Shumi
extends Combatente
## Kit da Shumi.
##  Básico: corte de katana (gera 1 ponto de skill e um pouco de energia).
##  Skill: Engo-ji Beam, feixe que muda com o Kaioken: só o alvo, alvo + 1
##         (x2), alvo + vizinhos (x4), atravessa todos (x10) e Colapso (x20).
##  Ult: Kaioken. Entra na forma (x2) ou sobe um nível (x4, x10, x20).
##       Cada nível dá mais ATQ/VEL e drena mais HP no início do turno.
##       Quando acaba, ela fica exausta (VEL menor); depois do x20 perde um turno.
##  Passiva: Limite Humano. Se sobrevive ao dreno do Kaioken no início do
##           turno, recupera energia (mais nos níveis altos).

## Ajuste de balanceamento: tudo do Kaioken está aqui.
## A VEL sobe menos que o ATQ de propósito: a duração conta turnos dela, então
## VEL alta demais encurta a forma e quase tira a vez dos inimigos, que são
## o outro lado do risco.
const NIVEIS := [
	{"nome": "x2", "atq": 0.20, "vel": 0.20, "dreno": 0.03, "limite": 15.0, "exaustao_vel": -0.10},
	{"nome": "x4", "atq": 0.40, "vel": 0.35, "dreno": 0.05, "limite": 20.0, "exaustao_vel": -0.20},
	{"nome": "x10", "atq": 0.80, "vel": 0.55, "dreno": 0.08, "limite": 25.0, "exaustao_vel": -0.30},
	{"nome": "x20", "atq": 1.50, "vel": 0.80, "dreno": 0.12, "limite": 30.0, "exaustao_vel": -0.40},
]
const CUSTO_ENTRAR := 120.0
const CUSTO_SUBIR := 80.0
const DURACAO := 3  ## turnos dela; subir de nível renova
const DURACAO_EXAUSTAO := 2

const ENERGIA_BASICO := 20.0
const ENERGIA_SKILL := 30.0
const ENERGIA_AO_APANHAR := 10.0

const MULT_BASICO := 1.0
## Engo-ji por nível (índice = nivel + 1). "alcance" é também o tipo de alvo
## que a interface mostra: unico, dupla (alvo + o de trás), vizinhos, todos.
const ENGO_JI := [
	{"nome": "Engo-ji Beam", "alcance": "unico", "mult": 1.8},
	{"nome": "Engo-ji Beam Amplificado", "alcance": "dupla", "mult": 1.8},
	{"nome": "Engo-ji Beam: Ruptura", "alcance": "vizinhos", "mult": 1.8},
	{"nome": "Engo-ji Beam: Devastação", "alcance": "todos", "mult": 1.8},
	{"nome": "Engo-ji Beam: Colapso", "alcance": "todos", "mult": 2.2},
]
const MULT_ENGO_JI_SECUNDARIO := 0.9  ## alvos extras do x2 e do x4

var nivel := -1  ## -1 = fora do Kaioken
var turnos_kaioken := 0
var turnos_exaustao := 0
var exaustao_vel := 0.0
var perde_proximo_turno := false
var _sobrecarga_no_turno := false  ## o dreno (e a passiva) já rodou neste turno


func _init() -> void:
	super("Shumi", true, 1200, 150.0, 50.0, 105.0, Tipos.FISICO)
	energia_max = 120.0
	energia = 60.0
	energia_ao_apanhar = ENERGIA_AO_APANHAR


func em_kaioken() -> bool:
	return nivel >= 0


func nome_nivel() -> String:
	return NIVEIS[nivel].nome if em_kaioken() else ""


func nivel_maximo() -> bool:
	return nivel == NIVEIS.size() - 1


func custo_ult() -> float:
	return CUSTO_SUBIR if em_kaioken() else CUSTO_ENTRAR


func pode_ultar() -> bool:
	return not nivel_maximo() and energia >= custo_ult()


func proximo_nivel_nome() -> String:
	return NIVEIS[mini(nivel + 1, NIVEIS.size() - 1)].nome


## Versão do Engo-ji para o nível atual (ver ENGO_JI).
func engo_ji() -> Dictionary:
	return ENGO_JI[nivel + 1]


func engo_ji_atravessa() -> bool:
	return engo_ji().alcance == "todos"


func bonus(stat: String) -> float:
	var b := super(stat)
	if em_kaioken():
		b += NIVEIS[nivel].get(stat, 0.0)
	if turnos_exaustao > 0 and stat == "vel":
		b += exaustao_vel
	return b


func ultar() -> void:
	var vel_antes := vel()
	energia -= custo_ult()
	nivel += 1
	turnos_kaioken = DURACAO
	turnos_exaustao = 0
	ajustar_av(vel_antes)


## Sobrecarga do Kaioken no início do turno dela: queima HP direto (sem
## defesa) e, se ela sobreviver, a passiva Limite Humano devolve energia.
## Roda no máximo uma vez por turno. Devolve {"dano": int, "energia": float}.
func sobrecarga_inicio_turno() -> Dictionary:
	var r := {"dano": 0, "energia": 0.0}
	if not em_kaioken() or _sobrecarga_no_turno:
		return r
	_sobrecarga_no_turno = true
	r.dano = receber_dano(ceili(hp_max * NIVEIS[nivel].dreno))
	if vivo():
		var antes := energia
		ganhar_energia(NIVEIS[nivel].limite)
		r.energia = energia - antes
	return r


## Fim do turno dela. Devolve o nível que acabou ("" se o Kaioken continua).
func fim_turno() -> String:
	_sobrecarga_no_turno = false
	if turnos_exaustao > 0:
		turnos_exaustao -= 1
	if not em_kaioken():
		return ""
	turnos_kaioken -= 1
	if turnos_kaioken > 0:
		return ""
	var acabou: Dictionary = NIVEIS[nivel]
	exaustao_vel = acabou.exaustao_vel
	turnos_exaustao = DURACAO_EXAUSTAO
	perde_proximo_turno = nivel_maximo()
	nivel = -1
	return acabou.nome


## Alvos do Engo-ji: [[inimigo, multiplicador], ...], na ordem em que o
## feixe passa. `inimigos` só com os vivos, em ordem.
func alvos_engo_ji(inimigos: Array, alvo: int) -> Array:
	var e := engo_ji()
	var extras := []
	match e.alcance:
		"dupla": extras = [alvo + 1 if alvo + 1 < inimigos.size() else alvo - 1]
		"vizinhos": extras = [alvo - 1, alvo + 1]
	var alvos := []
	for i in inimigos.size():
		if e.alcance == "todos" or i == alvo:
			alvos.append([inimigos[i], e.mult])
		elif i in extras:
			alvos.append([inimigos[i], MULT_ENGO_JI_SECUNDARIO])
	return alvos


func alvos_previstos(acao: String, inimigos: Array, alvo: int) -> Array:
	if acao == "skill":
		return alvos_engo_ji(inimigos, alvo).map(func(par: Array) -> Combatente: return par[0])
	return super(acao, inimigos, alvo)


# ------------------------------------------------- descrição para a interface
const COR_KAIOKEN := Color(1.0, 0.25, 0.2)
const ICONE_CORTE := "res://personagens/shumi/basic-attack-melee.png"
const ICONE_ENGO_JI := "res://personagens/shumi/engo-ji-beam-icon.png"
const ICONE_KAIOKEN := "res://personagens/shumi/kaiokenn-shumi.png"


func pode_usar(acao: String, pontos: int) -> bool:
	match acao:
		"basico": return true
		"skill": return pontos > 0
		"ult": return pode_ultar()
	return false


const DESCRICAO_ENGO_JI := {
	"unico": "Feixe concentrado no alvo.",
	"dupla": "Feixe mais forte: acerta o alvo e o inimigo logo atrás.",
	"vizinhos": "Feixe roxo e vermelho: alvo + vizinhos (dano menor nos vizinhos).",
	"todos": "O feixe atravessa todos os inimigos.",
}


func habilidades(pontos: int) -> Array[Dictionary]:
	var e := engo_ji()
	var ult := {
		"acao": "ult", "nome": "Kaioken", "tecla": "R", "icone": ICONE_KAIOKEN,
		"alvo": "proprio", "cor": COR_KAIOKEN, "destaque": true, "livre": true,
	}
	if nivel_maximo():
		ult.merge({"estado": "bloqueada", "selo": "MÁX",
			"descricao": "Já está no x20. Quando acabar, perde um turno."})
	else:
		var prox: Dictionary = NIVEIS[nivel + 1]
		ult.merge({
			"estado": "pronta" if pode_ultar() else "sem_recurso",
			"custo_energia": roundi(custo_ult()),
			"selo": prox.nome,
			"descricao": "%s %s: ATQ +%d%%, VEL +%d%%, queima %d%% do HP por turno (Limite Humano: +%d de energia se sobreviver)." % [
				"Sobe para" if em_kaioken() else "Entra no", prox.nome,
				roundi(prox.atq * 100), roundi(prox.vel * 100), roundi(prox.dreno * 100), roundi(prox.limite)],
		})
	return [
		{
			"acao": "basico", "nome": "Corte", "tecla": "Q", "icone": ICONE_CORTE,
			"estado": "pronta", "alvo": "unico", "tipo": tipo, "ganho_pontos": 1,
			"descricao": "Corte de katana no alvo. Gera 1 ponto de skill e %d de energia." % roundi(ENERGIA_BASICO),
		},
		{
			"acao": "skill", "nome": e.nome, "tecla": "E", "icone": ICONE_ENGO_JI,
			"estado": "pronta" if pontos > 0 else "sem_recurso",
			"alvo": e.alcance, "tipo": tipo, "custo_pontos": 1,
			"selo": nome_nivel(), "cor": COR_KAIOKEN,
			"descricao": ("Colapso: energia extrema contra todos os inimigos, com dano massivo."
				if nivel_maximo() else DESCRICAO_ENGO_JI[e.alcance])
				+ ("" if em_kaioken() else " Muda a cada nível do Kaioken."),
		},
		ult,
	]


func efeitos() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	if em_kaioken():
		var n: Dictionary = NIVEIS[nivel]
		lista.append({"id": "kaioken", "curto": n.nome, "nome": "Kaioken " + n.nome, "tipo": "buff",
			"cor": COR_KAIOKEN, "turnos": turnos_kaioken,
			"detalhe": "ATQ +%d%% · VEL +%d%% · -%d%% HP/turno · +%d energia" % [
				roundi(n.atq * 100), roundi(n.vel * 100), roundi(n.dreno * 100), roundi(n.limite)]})
	if turnos_exaustao > 0:
		lista.append({"id": "exaustao", "curto": "EXA", "nome": "Exausta", "tipo": "debuff",
			"turnos": turnos_exaustao, "detalhe": "VEL %d%%" % roundi(exaustao_vel * 100)})
	if perde_proximo_turno:
		lista.append({"id": "perde_turno", "curto": "Zz", "nome": "Perde o próximo turno",
			"tipo": "debuff", "turnos": -1})
	lista.append_array(super())
	return lista

class_name Invocacao
extends Combatente
## Criatura chamada por um aliado (como os demônios da Askara). Luta do lado
## dele, com vez própria na fila, HP e estados, mas não é da equipe: não
## ganha XP, não conta para a derrota e não é salva. Age sozinha: em cada vez
## usa o `golpe` (e o `debuff`, se tiver). Vai embora quando as vezes acabam,
## quando cai ou quando quem a invocou cai; quem tira de campo é a batalha.
## Ao sair por tempo ou ao cair, faz o `ultimo_ato`, se tiver.

const DURACAO_ESCUDO := 2  ## turnos de quem recebe o escudo do último ato

var id: String
## Quem a chamou. Referência fraca: o kit guarda as invocações, e as duas
## pontas fortes formariam um ciclo que nunca é liberado.
var invocador: Combatente:
	get: return _invocador.get_ref() as Combatente
var textura: String
var cor := Color.WHITE  ## cor da aura e do nome no registro
var turnos := 0  ## vezes que ainda vai agir; ao chegar a 0, vai embora
var turnos_max := 0
var em_campo := true  ## false = saiu (tempo, queda, substituída)

## Golpe de cada vez: {"nome", "mult", "alcance" (unico/dupla/vizinhos/todos;
## dupla = o alvo e o de trás), "mult_vizinhos"?, "mira"? (alvo/mais_forte),
## "estilo"? (projetil/investida), "debuff_em_todos"? (o debuff vai em todos
## os atingidos, não só no principal)}. O dano é do tipo da invocação.
var golpe := {}
## Golpe na chegada, na hora da invocação, no mesmo formato ({} = nenhum).
var golpe_entrada := {}
## Último ato, quando sai por tempo ou cai: golpe no mesmo formato, com
## "mult" opcional, e "escudo"?
## (fração do HP máximo dela que vira escudo no aliado com menos HP).
## Substituição e a queda de quem invocou não disparam. {} = nenhum.
var ultimo_ato := {}
## Fábrica (Callable sem argumentos que devolve um Estado novo) do debuff
## que o golpe deixa no alvo principal; vazio = nenhum.
var debuff := Callable()

var _invocador: WeakRef


func _init(p_id: String, p_nome: String, p_invocador: Combatente, p_hp: int, p_atq: float, p_def: float, p_vel: float, p_tipo: String, p_turnos: int) -> void:
	super(p_nome, true, p_hp, p_atq, p_def, p_vel, p_tipo)
	id = p_id
	_invocador = weakref(p_invocador)
	turnos = p_turnos
	turnos_max = p_turnos


func em_jogo() -> bool:
	return em_campo and vivo()


## Volta ao começo: HP cheio e todas as vezes (invocar de novo a mesma).
func renovar() -> void:
	hp = hp_max
	turnos = turnos_max


## Fim de uma vez dela. Devolve true se acabou o tempo (a batalha a tira).
func passar_vez() -> bool:
	turnos -= 1
	return turnos <= 0


## Alvos de `g` entre `inimigos` (vivos, em ordem), a partir do inimigo
## que o jogador marcou (`alvo`): [[inimigo, mult], ...], o principal primeiro.
func alvos(g: Dictionary, inimigos: Array, alvo: int) -> Array:
	if inimigos.is_empty() or g.is_empty():
		return []
	var i := clampi(alvo, 0, inimigos.size() - 1)
	if g.get("mira", "alvo") == "mais_forte":
		for k in inimigos.size():
			if (inimigos[k] as Combatente).atq() > (inimigos[i] as Combatente).atq():
				i = k
	var lista := [[inimigos[i], g.mult]]
	var de_tras := i + 1 if i + 1 < inimigos.size() else i - 1
	for k in inimigos.size():
		if k == i:
			continue
		match g.get("alcance", "unico"):
			"todos": lista.append([inimigos[k], g.mult])
			"dupla":
				if k == de_tras:
					lista.append([inimigos[k], g.get("mult_vizinhos", g.mult)])
			"vizinhos":
				if absi(k - i) == 1:
					lista.append([inimigos[k], g.get("mult_vizinhos", g.mult)])
	return lista


## Quem recebe o escudo do último ato: o aliado de pé (fora ela) com a menor
## fração de HP. `aliados` = os aliados em campo; null se não houver.
func alvo_escudo(aliados: Array) -> Combatente:
	var melhor: Combatente = null
	for c: Combatente in aliados:
		if c == self or not c.vivo():
			continue
		if melhor == null or float(c.hp) / c.hp_max < float(melhor.hp) / melhor.hp_max:
			melhor = c
	return melhor


## Escudo do último ato `g`, sobre o HP máximo dela.
func escudo_ultimo_ato(g: Dictionary) -> Estado:
	var e := Estado.new("escudo_" + id, g.nome, "ESC", "buff", DURACAO_ESCUDO)
	e.escudo = roundi(hp_max * g.escudo)
	e.cor = cor
	return e


func efeitos() -> Array[Dictionary]:
	var lista: Array[Dictionary] = [{"id": "invocacao", "curto": str(turnos), "nome": "Invocação", "tipo": "buff",
		"turnos": turnos, "cor": cor, "detalhe": "vai embora em %d vez%s" % [turnos, "" if turnos == 1 else "es"]}]
	lista.append_array(super())
	return lista

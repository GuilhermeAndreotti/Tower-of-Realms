class_name Inimigo
extends Combatente
## Inimigo simples: ataca um aliado vivo qualquer e, se tiver golpe pesado,
## usa a cada `golpe_pesado_a_cada` ações. Com `ultimo_recurso`, ganha um
## escudo uma vez por luta quando o HP cai abaixo de uma fração.

const MULT_GOLPE := 1.0
const MULT_GOLPE_PESADO := 1.8
const COR_ULTIMO_RECURSO := Color(0.66, 0.7, 0.84)  ## aço frio, para o anúncio e o efeito

var textura: String
var golpe_pesado_a_cada := 0
var xp := -1  ## XP que dá ao ser vencido; -1 = a regra da Progressao (pelo HP)
## Escudo de quem está quase caindo (o Ferro Negro do andar 5): {"nome",
## "curto" (rótulo do efeito), "abaixo_de" (fração do HP máximo), "escudo"
## (fração do HP máximo), "turnos"}. {} = nenhum. Dispara uma vez por luta.
var ultimo_recurso := {}
var _acoes := 0
var _recurso_usado := false


func _init(p_nome: String, p_textura: String, p_hp: int, p_atq: float, p_def: float, p_vel: float, p_pesado_a_cada := 0, p_tipo := Tipos.FISICO) -> void:
	super(p_nome, false, p_hp, p_atq, p_def, p_vel, p_tipo)
	textura = p_textura
	golpe_pesado_a_cada = p_pesado_a_cada


## Golpe que vai usar na próxima ação: {"nome", "mult", "pesado", "tipo"}.
func proximo_golpe() -> Dictionary:
	var pesado := golpe_pesado_a_cada > 0 and (_acoes + 1) % golpe_pesado_a_cada == 0
	if pesado:
		return {"nome": "Golpe Pesado", "mult": MULT_GOLPE_PESADO, "pesado": true, "tipo": tipo}
	return {"nome": "Investida", "mult": MULT_GOLPE, "pesado": false, "tipo": tipo}


## Alvo da próxima ação entre os aliados vivos, sorteado pelo peso de cada
## um (provocação pesa mais). `sorteio` (0..1) vem de fora para os testes
## poderem fixar o valor.
func escolher_alvo(aliados: Array, sorteio := randf()) -> Combatente:
	var vivos := aliados.filter(func(c: Combatente) -> bool: return c.vivo())
	if vivos.is_empty():
		return null
	var total := 0.0
	for c: Combatente in vivos:
		total += c.peso_alvo()
	var ponto := sorteio * total
	for c: Combatente in vivos:
		ponto -= c.peso_alvo()
		if ponto < 0.0:
			return c
	return vivos[-1]


## Se o HP acabou de cair abaixo de `ultimo_recurso.abaixo_de` (e o
## inimigo segue de pé), gasta o último recurso e devolve o escudo para a
## batalha aplicar; null = nada a fazer.
func ativar_ultimo_recurso() -> Estado:
	if ultimo_recurso.is_empty() or _recurso_usado or not vivo() or hp >= hp_max * float(ultimo_recurso.abaixo_de):
		return null
	_recurso_usado = true
	var e := Estado.new("ultimo_recurso", ultimo_recurso.nome, ultimo_recurso.get("curto", "UR"), "buff", ultimo_recurso.get("turnos", 3))
	e.escudo = roundi(hp_max * float(ultimo_recurso.escudo))
	e.cor = COR_ULTIMO_RECURSO
	return e


func registrar_acao() -> void:
	_acoes += 1


func efeitos() -> Array[Dictionary]:
	var lista := super()
	if proximo_golpe().pesado:
		lista.append({"id": "carregando", "curto": "!", "nome": "Golpe Pesado", "tipo": "alerta",
			"turnos": -1, "detalhe": "na próxima ação"})
	return lista

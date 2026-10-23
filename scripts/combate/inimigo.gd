class_name Inimigo
extends Combatente
## Inimigo simples: ataca um aliado vivo qualquer e, se tiver golpe pesado,
## usa a cada `golpe_pesado_a_cada` ações.

const MULT_GOLPE := 1.0
const MULT_GOLPE_PESADO := 1.8

var textura: String
var golpe_pesado_a_cada := 0
var xp := -1  ## XP que dá ao ser vencido; -1 = a regra da Progressao (pelo HP)
var _acoes := 0


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


## Alvo da próxima ação entre os aliados vivos. `sorteio` (0..1) vem de
## fora para os testes poderem fixar o valor.
func escolher_alvo(aliados: Array, sorteio := randf()) -> Combatente:
	var vivos := aliados.filter(func(c: Combatente) -> bool: return c.vivo())
	if vivos.is_empty():
		return null
	return vivos[mini(floori(sorteio * vivos.size()), vivos.size() - 1)]


func registrar_acao() -> void:
	_acoes += 1


func efeitos() -> Array[Dictionary]:
	var lista := super()
	if proximo_golpe().pesado:
		lista.append({"id": "carregando", "curto": "!", "nome": "Golpe Pesado", "tipo": "alerta",
			"turnos": -1, "detalhe": "na próxima ação"})
	return lista

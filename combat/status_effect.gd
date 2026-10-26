class_name Estado
extends RefCounted
## Efeito temporário genérico num lutador (buff, debuff, escudo, fraqueza...).
## Mora em Combatente.estados; a batalha desconta a duração no fim de cada
## turno do portador. Mecânicas próprias de um kit (como o Kaioken) podem
## continuar no próprio personagem; este é o caminho comum para efeitos que
## um lutador aplica em outro.

var id: String  ## um estado por id: aplicar de novo substitui (renova)
var nome: String
var curto: String  ## rótulo de 1-3 letras para as barras da arena
var tipo := "buff"  ## buff / debuff (debuffs podem ser limpos)
var turnos := 2  ## turnos do portador; -1 = sem contagem
var cor := Color.TRANSPARENT  ## TRANSPARENT = cor do tipo (buff/debuff)
var detalhe := ""

## Somados em Combatente.bonus(stat): "atq", "def", "vel", "crit".
var mods := {}
var fraqueza := ""  ## tipo de dano que passa a ser super efetivo no portador
var escudo := 0  ## absorve dano de golpes; o estado acaba quando zera
var vida_extra := 0  ## soma ao HP máximo (e ao atual) enquanto durar
var atraso := 0.0  ## ao ser aplicado, empurra a vez (fração da distância do turno)
## Peso extra no sorteio de alvo dos inimigos (0 = normal; 2 = três vezes
## mais chance de ser o alvo que um aliado sem provocação).
var provocacao := 0.0
var reducao_dano := 0.0  ## fração cortada de todo golpe recebido (0..1)

## Dano adicional nos golpes do portador: {"tipo", "mult", "proporcional"
## (mult relativo ao do golpe), "consome" (o estado acaba ao disparar)}.
var golpe_extra := {}
## Fábrica (Callable sem argumentos que devolve um Estado novo) do estado
## aplicado em quem o portador acerta. Fábrica, e não um Estado modelo,
## porque um script que referencia a própria classe fica preso no Godot.
var ao_acertar := Callable()
var ao_acertar_consome := false  ## o estado acaba no primeiro acerto


func _init(p_id: String, p_nome: String, p_curto: String, p_tipo := "buff", p_turnos := 2) -> void:
	id = p_id
	nome = p_nome
	curto = p_curto
	tipo = p_tipo
	turnos = p_turnos


## Descrição no formato de Combatente.efeitos().
func descricao() -> Dictionary:
	var d := {"id": id, "curto": curto, "nome": nome, "tipo": tipo, "turnos": turnos}
	var texto := detalhe
	if escudo > 0:
		texto = ("%s · " % texto if texto != "" else "") + "escudo %d" % escudo
	if texto != "":
		d.detalhe = texto
	if cor != Color.TRANSPARENT:
		d.cor = cor
	return d

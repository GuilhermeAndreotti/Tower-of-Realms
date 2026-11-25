class_name StatusEffect
extends RefCounted
## Efeito temporário genérico num lutador (buff, debuff, escudo, fraqueza...).
## Mora em Combatant.status_effects; a batalha desconta a duração no fim de cada
## turno do portador. Mecânicas próprias de um kit (como o Kaioken) podem
## continuar no próprio personagem; este é o caminho comum para efeitos que
## um lutador aplica em outro.

var id: String  ## um estado por id: aplicar de novo substitui (renova)
var name: String
var short: String  ## rótulo de 1-3 letras para as barras da arena
var type := "buff"  ## buff / debuff (debuffs podem ser limpos)
var turns := 2  ## turnos do portador; -1 = sem contagem
var color := Color.TRANSPARENT  ## TRANSPARENT = cor do tipo (buff/debuff)
var detail := ""

## Somados em Combatant.bonus(stat): "atk", "def", "spd", "crit", "damage"
## (multiplica o dano que o portador causa) e "healing" (multiplica as curas
## que o portador faz; ver Combatant.healing_mult()).
var mods := {}
var weakness := ""  ## tipo de dano que passa a ser super efetivo no portador
var shield := 0  ## absorve dano de golpes; o estado acaba quando zera
var extra_life := 0  ## soma ao HP máximo (e ao atual) enquanto durar
var delay := 0.0  ## ao ser aplicado, empurra a vez (fração da distância do turno)
## Peso extra no sorteio de alvo dos inimigos (0 = normal; 2 = três vezes
## mais chance de ser o alvo que um aliado sem provocação).
var taunt := 0.0
var damage_reduction := 0.0  ## fração cortada de todo golpe recebido (0..1)
## O estado acaba no primeiro golpe que o portador recebe (depois de valer
## nele), como a proteção do Lord Azeroth da Lia.
var consumed_by_hit := false
## Contador do kit que aplicou o estado (as Geadas do Daimon). A regra fica
## no kit; aqui só fica guardado no alvo, junto do nome e do rótulo.
var stacks := 0

## Dano adicional nos golpes do portador: {"type", "mult", "proportional"
## (mult relativo ao do golpe), "consumes" (o estado acaba ao disparar)}.
var extra_strike := {}
## Fábrica (Callable sem argumentos que devolve um StatusEffect novo) do estado
## aplicado em quem o portador acerta. Fábrica, e não um StatusEffect modelo,
## porque um script que referencia a própria classe fica preso no Godot.
var on_hit := Callable()
var on_hit_consumes := false  ## o estado acaba no primeiro acerto


func _init(p_id: String, p_name: String, p_short: String, p_type := "buff", p_turns := 2) -> void:
	id = p_id
	name = p_name
	short = p_short
	type = p_type
	turns = p_turns


## Descrição no formato de Combatant.effects().
func description() -> Dictionary:
	var d := {"id": id, "short": short, "name": name, "type": type, "turns": turns}
	var text := detail
	if shield > 0:
		text = ("%s • " % text if text != "" else "") + "escudo %d" % shield
	if text != "":
		d.detail = text
	if color != Color.TRANSPARENT:
		d.color = color
	return d

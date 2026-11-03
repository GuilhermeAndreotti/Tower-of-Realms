class_name Enemy
extends Combatant
## Inimigo simples: ataca um aliado vivo qualquer e, se tiver golpe pesado,
## usa a cada `heavy_strike_every` ações. Com `last_resort`, ganha um
## escudo uma vez por luta quando o HP cai abaixo de uma fração. Com
## `second_form`, volta uma vez depois de derrotado, em outra forma.

const STRIKE_MULT := 1.0
const HEAVY_STRIKE_MULT := 1.8
const LAST_RESORT_COLOR := Color(0.66, 0.7, 0.84)  ## aço frio, para o anúncio e o efeito

var texture: String
var heavy_strike_every := 0
var xp := -1  ## XP que dá ao ser vencido; -1 = a regra da Progression (pelo HP)
## Escudo de quem está quase caindo (o Ferro Negro do andar 5): {"name",
## "short" (rótulo do efeito), "below" (fração do HP máximo), "shield"
## (fração do HP máximo), "turns"}. {} = nenhum. Dispara uma vez por luta.
var last_resort := {}
## Forma de quem volta depois de derrotado (o Golem do andar 5): {"name",
## "texture", "type", "heal" (fração do HP máximo recuperada),
## "heal_per_absorbed" (mais isso por inimigo absorvido), "beam": {"name",
## "mult", "every"} (a cada N ações, um golpe em toda a equipe)}. {} =
## nenhuma. Uma vez por luta.
var second_form := {}
var awakened := false  ## já voltou na segunda forma
var _actions := 0
var _last_resort_used := false


func _init(p_name: String, p_texture: String, p_hp: int, p_atk: float, p_def: float, p_spd: float, p_heavy_every := 0, p_type := Types.PHYSICAL) -> void:
	super(p_name, false, p_hp, p_atk, p_def, p_spd, p_type)
	texture = p_texture
	heavy_strike_every = p_heavy_every


## Golpe que vai usar na próxima ação: {"name", "mult", "heavy", "type",
## "all"? (toda a equipe)}.
func next_strike() -> Dictionary:
	var beam: Dictionary = second_form.get("beam", {}) if awakened else {}
	if not beam.is_empty() and (_actions + 1) % int(beam.every) == 0:
		return {"name": beam.name, "mult": float(beam.mult), "heavy": false, "all": true, "type": type}
	var heavy := heavy_strike_every > 0 and (_actions + 1) % heavy_strike_every == 0
	if heavy:
		return {"name": "Golpe Pesado", "mult": HEAVY_STRIKE_MULT, "heavy": true, "type": type}
	return {"name": "Investida", "mult": STRIKE_MULT, "heavy": false, "type": type}


## Alvo da próxima ação entre os aliados vivos, sorteado pelo peso de cada
## um (provocação pesa mais). `roll` (0..1) vem de fora para os testes
## poderem fixar o valor.
func choose_target(allies: Array, roll := randf()) -> Combatant:
	var alive := allies.filter(func(c: Combatant) -> bool: return c.is_alive())
	if alive.is_empty():
		return null
	var total := 0.0
	for c: Combatant in alive:
		total += c.target_weight()
	var point := roll * total
	for c: Combatant in alive:
		point -= c.target_weight()
		if point < 0.0:
			return c
	return alive[-1]


## Se o HP acabou de cair abaixo de `last_resort.below` (e o
## inimigo segue de pé), gasta o último recurso e devolve o escudo para a
## batalha aplicar; null = nada a fazer.
func activate_last_resort() -> StatusEffect:
	if last_resort.is_empty() or _last_resort_used or not is_alive() or hp >= max_hp * float(last_resort.below):
		return null
	_last_resort_used = true
	var e := StatusEffect.new("last_resort", last_resort.name, last_resort.get("short", "UR"), "buff", last_resort.get("turns", 3))
	e.shield = roundi(max_hp * float(last_resort.shield))
	e.color = LAST_RESORT_COLOR
	return e


## Derrotado, mas com segunda forma ainda não usada: a batalha chama
## awaken() em vez de dar a queda.
func can_awaken() -> bool:
	return not second_form.is_empty() and not awakened and not is_alive()


## Volta na segunda forma depois de absorver `absorbed` inimigos: troca nome,
## arte e tipo, perde os estados e o Golpe Pesado (o golpe em toda a equipe
## entra no lugar) e recupera HP. Devolve quanto recuperou.
func awaken(absorbed: int) -> int:
	awakened = true
	name = second_form.name
	texture = second_form.texture
	type = second_form.get("type", type)
	heavy_strike_every = 0
	_actions = 0
	for e in status_effects.duplicate():
		remove_status(e.id)
	var fraction := float(second_form.get("heal", 0.0)) + float(second_form.get("heal_per_absorbed", 0.0)) * absorbed
	return heal(roundi(max_hp * minf(1.0, fraction)))


func count_action() -> void:
	_actions += 1


func effects() -> Array[Dictionary]:
	var list := super()
	var strike := next_strike()
	if strike.heavy:
		list.append({"id": "charging", "short": "!", "name": "Golpe Pesado", "type": "alert",
			"turns": -1, "detail": "na próxima ação"})
	elif strike.get("all", false):
		list.append({"id": "charging", "short": "!", "name": strike.name, "type": "alert",
			"turns": -1, "detail": "na próxima ação, em toda a equipe"})
	return list

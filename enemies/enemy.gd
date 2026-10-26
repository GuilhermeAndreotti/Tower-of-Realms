class_name Enemy
extends Combatant
## Inimigo simples: ataca um aliado vivo qualquer e, se tiver golpe pesado,
## usa a cada `heavy_strike_every` ações. Com `last_resort`, ganha um
## escudo uma vez por luta quando o HP cai abaixo de uma fração.

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
var _actions := 0
var _last_resort_used := false


func _init(p_name: String, p_texture: String, p_hp: int, p_atk: float, p_def: float, p_spd: float, p_heavy_every := 0, p_type := Types.PHYSICAL) -> void:
	super(p_name, false, p_hp, p_atk, p_def, p_spd, p_type)
	texture = p_texture
	heavy_strike_every = p_heavy_every


## Golpe que vai usar na próxima ação: {"name", "mult", "heavy", "type"}.
func next_strike() -> Dictionary:
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


func count_action() -> void:
	_actions += 1


func effects() -> Array[Dictionary]:
	var list := super()
	if next_strike().heavy:
		list.append({"id": "charging", "short": "!", "name": "Golpe Pesado", "type": "alert",
			"turns": -1, "detail": "na próxima ação"})
	return list

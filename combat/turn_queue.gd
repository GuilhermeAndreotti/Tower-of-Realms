class_name TurnQueue
extends RefCounted
## Ordem de ação por velocidade, no estilo do HSR: cada lutador tem um "av"
## (quanto falta para agir). Quem tem o menor av age; o tempo que passou é
## descontado de todos e o lutador que agiu volta para o fim da fila.


static func next(fighters: Array) -> Combatant:
	var best: Combatant = null
	for c: Combatant in fighters:
		if c.is_alive() and (best == null or c.av < best.av):
			best = c
	return best


## Faz o tempo passar até `actor` poder agir.
static func advance_to(fighters: Array, actor: Combatant) -> void:
	var passed := actor.av
	for c: Combatant in fighters:
		if c.is_alive():
			c.av = maxf(0.0, c.av - passed)


## Próximas `n` ações previstas (sem contar mudanças de VEL que ainda vão acontecer).
static func forecast(fighters: Array, n: int) -> Array[Combatant]:
	var avs := {}
	for c: Combatant in fighters:
		if c.is_alive():
			avs[c] = c.av
	var order: Array[Combatant] = []
	while order.size() < n and not avs.is_empty():
		var best: Combatant = null
		for c: Combatant in avs:
			if best == null or avs[c] < avs[best]:
				best = c
		order.append(best)
		avs[best] += Combatant.TURN_DISTANCE / best.spd()
	return order

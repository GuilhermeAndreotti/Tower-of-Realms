class_name FilaTurnos
extends RefCounted
## Ordem de ação por velocidade, no estilo do HSR: cada lutador tem um "av"
## (quanto falta para agir). Quem tem o menor av age; o tempo que passou é
## descontado de todos e o lutador que agiu volta para o fim da fila.


static func proximo(lutadores: Array) -> Combatente:
	var melhor: Combatente = null
	for c: Combatente in lutadores:
		if c.vivo() and (melhor == null or c.av < melhor.av):
			melhor = c
	return melhor


## Faz o tempo passar até `ator` poder agir.
static func avancar_ate(lutadores: Array, ator: Combatente) -> void:
	var passou := ator.av
	for c: Combatente in lutadores:
		if c.vivo():
			c.av = maxf(0.0, c.av - passou)


## Próximas `n` ações previstas (sem contar mudanças de VEL que ainda vão acontecer).
static func previsao(lutadores: Array, n: int) -> Array[Combatente]:
	var avs := {}
	for c: Combatente in lutadores:
		if c.vivo():
			avs[c] = c.av
	var ordem: Array[Combatente] = []
	while ordem.size() < n and not avs.is_empty():
		var melhor: Combatente = null
		for c: Combatente in avs:
			if melhor == null or avs[c] < avs[melhor]:
				melhor = c
		ordem.append(melhor)
		avs[melhor] += Combatente.DISTANCIA_TURNO / melhor.vel()
	return ordem

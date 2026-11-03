class_name StatusEffects
extends RefCounted
## Os estados (StatusEffect) de um lutador e o que eles somam: modificadores,
## escudo, fraqueza, provocação, redução de dano. Só guarda e soma; o que um
## estado muda no dono ao entrar ou sair (HP máximo, a vez) é o Combatant que
## aplica, porque depende do resto dele.

var list: Array[StatusEffect] = []


func find(id: String) -> StatusEffect:
	for e in list:
		if e.id == id:
			return e
	return null


func add(e: StatusEffect) -> void:
	list.append(e)


## Tira o estado `id` e o devolve (null se não havia).
func take_out(id: String) -> StatusEffect:
	for i in range(list.size() - 1, -1, -1):
		if list[i].id == id:
			var e := list[i]
			list.remove_at(i)
			return e
	return null


## Soma dos modificadores de `stat` ("atk", "def", "spd", "crit", "damage", "healing").
func bonus(stat: String) -> float:
	var total := 0.0
	for e in list:
		total += e.mods.get(stat, 0.0)
	return total


func extra_life() -> int:
	var total := 0
	for e in list:
		total += e.extra_life
	return total


func shield() -> int:
	var total := 0
	for e in list:
		total += e.shield
	return total


## Se algum estado deixou o dono fraco a golpes do tipo `type`.
func weak_to(type: String) -> bool:
	return list.any(func(e: StatusEffect) -> bool: return e.weakness == type)


## Fração cortada de todo golpe recebido, no máximo 90%.
func damage_reduction() -> float:
	var total := 0.0
	for e in list:
		total += e.damage_reduction
	return clampf(total, 0.0, 0.9)


func taunt() -> float:
	var total := 0.0
	for e in list:
		total += e.taunt
	return total


## Ids dos estados que acabam no primeiro golpe recebido.
func consumed_by_hit() -> Array[String]:
	var ids: Array[String] = []
	for e in list:
		if e.consumed_by_hit:
			ids.append(e.id)
	return ids


func ids_of_type(type: String) -> Array[String]:
	var ids: Array[String] = []
	for e in list:
		if e.type == type:
			ids.append(e.id)
	return ids


## Escudos absorvem `damage` na ordem em que entraram. Devolve quanto foi
## absorvido; os escudos zerados ficam em `emptied` para o dono tirar.
func absorb(damage: int, emptied: Array[String]) -> int:
	var absorbed := 0
	for e in list:
		if e.shield <= 0 or absorbed >= damage:
			continue
		var part := mini(e.shield, damage - absorbed)
		e.shield -= part
		absorbed += part
		if e.shield == 0:
			emptied.append(e.id)
	return absorbed


## Fim de um turno do dono: desconta a duração. Devolve os que acabaram
## (ainda na lista; quem tira é o dono).
func tick() -> Array[StatusEffect]:
	var ended: Array[StatusEffect] = []
	for e in list:
		if e.turns > 0:
			e.turns -= 1
			if e.turns == 0:
				ended.append(e)
	return ended

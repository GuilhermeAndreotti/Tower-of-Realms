class_name Health
extends RefCounted
## HP de um lutador: o atual e o máximo. Só números, com sinais para quem
## mostra (a barra na arena) não precisar perguntar a cada quadro. Quanto de
## um golpe chega aqui (escudos, resistências) é o Combatant que decide.

signal changed(current: int, maximum: int)
## O HP chegou a 0 (de novo só depois de voltar a subir).
signal depleted

## Baixar o máximo puxa o atual junto; subir não cura.
var maximum := 1:
	set(v):
		maximum = maxi(1, v)
		if current > maximum:
			current = maximum
		else:
			changed.emit(current, maximum)
var current := 1:
	set(v):
		var before := current
		current = clampi(v, 0, maximum)
		if current != before:
			changed.emit(current, maximum)
			if current == 0:
				depleted.emit()


func _init(p_maximum: int) -> void:
	maximum = p_maximum
	current = p_maximum


func is_depleted() -> bool:
	return current <= 0


func fraction() -> float:
	return float(current) / maximum


## Tira até `amount`, sem passar de 0. Devolve quanto tirou.
func take(amount: int) -> int:
	var real := mini(amount, current)
	current -= real
	return real


## Cura até `amount`, sem passar do máximo. Devolve quanto curou.
func heal(amount: int) -> int:
	var real := mini(amount, maximum - current)
	current += real
	return real

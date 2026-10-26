class_name Cooldowns
extends RefCounted
## Recargas das ações de um lutador: quantos turnos do dono faltam para cada
## ação poder ser usada de novo.

var _turns := {}  ## action -> turnos; sem a chave = pronta


## Turnos que faltam para `action` (0 = pronta).
func remaining(action: String) -> int:
	return _turns.get(action, 0)


## `action` foi usada: só volta depois de `turns` turnos do dono, contando o
## turno em que foi usada (recarga 3 = uma vez a cada 3 turnos).
func start(action: String, turns: int) -> void:
	if turns > 0:
		_turns[action] = turns


## Fim de um turno do dono.
func tick() -> void:
	for action: String in _turns.keys():
		_turns[action] -= 1
		if _turns[action] <= 0:
			_turns.erase(action)

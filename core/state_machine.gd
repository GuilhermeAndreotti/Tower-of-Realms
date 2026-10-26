class_name StateMachine
extends RefCounted
## Máquina de estados finita: um estado por vez (um valor do enum de quem
## usa), as trocas permitidas declaradas de antemão e um sinal a cada troca.
## O que cada estado faz (teclas, animação, o que trava) fica com quem usa;
## a máquina só garante que a troca é válida e avisa quem escuta.

signal changed(from: int, to: int)

var state: int:
	get: return _state

var _state: int
var _allowed: Dictionary  ## estado -> [estados para onde pode ir]
var _names: Array  ## nomes dos estados (as chaves do enum), para as mensagens


## `allowed`: {estado: [destinos]}. `names`: as chaves do enum, na ordem.
func _init(initial: int, allowed: Dictionary, names: Array = []) -> void:
	_state = initial
	_allowed = allowed
	_names = names


func is_in(states: Array) -> bool:
	return _state in states


func can_go(to: int) -> bool:
	return to == _state or to in _allowed.get(_state, [])


## Vai para `to`. Ficar no mesmo estado não é troca; uma troca não declarada
## é erro de programação: avisa e não troca.
func go(to: int) -> bool:
	if to == _state:
		return true
	if not can_go(to):
		push_error("troca de estado não permitida: %s -> %s" % [_name(_state), _name(to)])
		return false
	var from := _state
	_state = to
	changed.emit(from, to)
	return true


func _name(s: int) -> String:
	return _names[s] if s >= 0 and s < _names.size() else str(s)

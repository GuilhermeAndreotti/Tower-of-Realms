class_name Flame
extends Node2D
## Chama em pixels (a mesma grade de 3px dos sprites), tremulando sozinha.
## A origem fica na base do fogo. Junto vem um brilho em degraus no
## chão/parede em volta, que pulsa com ela.

const PIXEL := 3.0
const COLORS := [Color(0.75, 0.2, 0.1), Color(1.0, 0.45, 0.12), Color(1.0, 0.75, 0.25), Color(1.0, 0.95, 0.7)]
const INTERVAL := 0.09

var width := 2  ## colunas para cada lado do centro
var height := 5.0  ## em pixels de sprite

var _columns: Array[float] = []
var _wait := 0.0
var _glow: Sprite2D
var _glow_strength := 0.0


## `glow_radius` em pixels de sprite (0 = sem brilho). Construtor, e não
## uma fábrica estática, porque um script que referencia a própria classe
## fica preso no Godot.
func _init(pos: Vector2, p_width: int, p_height: float, glow_radius := 0, strength := 0.5) -> void:
	position = pos
	width = p_width
	height = p_height
	if glow_radius > 0:
		_glow = Glow.create(glow_radius, Color(1.0, 0.6, 0.3), strength)
		_glow.position = Vector2(0, -p_height * PIXEL * 0.5)
		_glow_strength = strength
		add_child(_glow)


func _ready() -> void:
	_roll()


func _process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0:
		_wait = INTERVAL * randf_range(0.7, 1.3)
		_roll()
		queue_redraw()
		if _glow:
			_glow.modulate.a = _glow_strength * randf_range(0.85, 1.0)


func _roll() -> void:
	_columns.clear()
	for i in range(-width, width + 1):
		var fall := 1.0 - absf(i) / (width + 1.0)
		_columns.append(maxf(1.0, roundf(height * fall * randf_range(0.6, 1.05))))


func _draw() -> void:
	for k in _columns.size():
		var i := k - width
		var h := int(_columns[k])
		for j in h:
			# de baixo para cima: o miolo é claro, as pontas e as bordas escuras
			var t := 1.0 - float(j) / maxf(1.0, height)
			var border := absf(i) == width or j == h - 1
			var level := clampi(int(t * 3.2) - (1 if border else 0), 0, 3)
			draw_rect(Rect2((i - 0.5) * PIXEL, -(j + 1) * PIXEL, PIXEL, PIXEL), COLORS[level])

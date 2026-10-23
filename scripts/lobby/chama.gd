class_name Chama
extends Node2D
## Chama em pixels (a mesma grade de 3px dos sprites), tremulando sozinha.
## A origem fica na base do fogo. Junto vem um brilho em degraus no
## chão/parede em volta, que pulsa com ela.

const PIXEL := 3.0
const CORES := [Color(0.75, 0.2, 0.1), Color(1.0, 0.45, 0.12), Color(1.0, 0.75, 0.25), Color(1.0, 0.95, 0.7)]
const INTERVALO := 0.09

var largura := 2  ## colunas para cada lado do centro
var altura := 5.0  ## em pixels de sprite

var _colunas: Array[float] = []
var _espera := 0.0
var _brilho: Sprite2D
var _forca_brilho := 0.0


## `raio_brilho` em pixels de sprite (0 = sem brilho). Construtor, e não
## uma fábrica estática, porque um script que referencia a própria classe
## fica preso no Godot.
func _init(pos: Vector2, p_largura: int, p_altura: float, raio_brilho := 0, forca := 0.5) -> void:
	position = pos
	largura = p_largura
	altura = p_altura
	if raio_brilho > 0:
		_brilho = Brilho.criar(raio_brilho, Color(1.0, 0.6, 0.3), forca)
		_brilho.position = Vector2(0, -p_altura * PIXEL * 0.5)
		_forca_brilho = forca
		add_child(_brilho)


func _ready() -> void:
	_sortear()


func _process(delta: float) -> void:
	_espera -= delta
	if _espera <= 0:
		_espera = INTERVALO * randf_range(0.7, 1.3)
		_sortear()
		queue_redraw()
		if _brilho:
			_brilho.modulate.a = _forca_brilho * randf_range(0.85, 1.0)


func _sortear() -> void:
	_colunas.clear()
	for i in range(-largura, largura + 1):
		var queda := 1.0 - absf(i) / (largura + 1.0)
		_colunas.append(maxf(1.0, roundf(altura * queda * randf_range(0.6, 1.05))))


func _draw() -> void:
	for k in _colunas.size():
		var i := k - largura
		var h := int(_colunas[k])
		for j in h:
			# de baixo para cima: o miolo é claro, as pontas e as bordas escuras
			var t := 1.0 - float(j) / maxf(1.0, altura)
			var borda := absf(i) == largura or j == h - 1
			var nivel := clampi(int(t * 3.2) - (1 if borda else 0), 0, 3)
			draw_rect(Rect2((i - 0.5) * PIXEL, -(j + 1) * PIXEL, PIXEL, PIXEL), CORES[nivel])

class_name PixelBar
extends Control
## Barra de recurso (HP, energia...) desenhada à mão. O valor desliza até o
## novo número; quando cai, um "rastro" claro fica para trás e some depois,
## para dar para ler quanto se perdeu. Com `shield`, ganha contorno azul e
## uma faixa embaixo do tamanho do escudo (na mesma escala do máximo).

var color := UIStyle.HP
var low_color := Color()  ## se definida, vira essa cor abaixo de 30%
var marks := 10  ## divisões finas na barra (0 = nenhuma)
var shield := 0.0:  ## escudo por cima do valor (HP), na escala de `maximum`
	set(v):
		if not is_equal_approx(v, shield):
			shield = v
			queue_redraw()

var maximum := 1.0
var _shown := 1.0  ## valor exibido (anima)
var _trail := 1.0  ## valor do rastro que fica para trás
var _tween: Tween
var _trail_tween: Tween
var _started := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 10)


func set_values(value: float, p_maximum: float, animate := true) -> void:
	maximum = maxf(1.0, p_maximum)
	if not animate or not _started:
		_started = true
		_shown = value
		_trail = value
		queue_redraw()
		return
	if is_equal_approx(value, _shown):
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_shown, _shown, value, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _trail_tween:
		_trail_tween.kill()
	if value < _trail:
		_trail_tween = create_tween()
		_trail_tween.tween_interval(0.45)
		_trail_tween.tween_method(_set_trail, _trail, value, 0.35).set_trans(Tween.TRANS_QUAD)
	else:
		_trail = value


func _set_shown(v: float) -> void:
	_shown = v
	queue_redraw()


func _set_trail(v: float) -> void:
	_trail = v
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color.BLACK)
	var inside := r.grow(-1)
	draw_rect(inside, Color(0.08, 0.07, 0.12))
	var frac := clampf(_shown / maximum, 0, 1)
	var trail_frac := clampf(_trail / maximum, 0, 1)
	if trail_frac > frac:
		draw_rect(Rect2(inside.position, Vector2(inside.size.x * trail_frac, inside.size.y)), Color(1, 0.95, 0.85, 0.85))
	var c := low_color if low_color != Color() and frac < 0.3 else color
	var full := Rect2(inside.position, Vector2(roundf(inside.size.x * frac), inside.size.y))
	draw_rect(full, c)
	# brilho de cima e sombra de baixo: volume em 2 pixels
	draw_rect(Rect2(full.position, Vector2(full.size.x, 2)), c.lightened(0.35))
	draw_rect(Rect2(full.position + Vector2(0, full.size.y - 2), Vector2(full.size.x, 2)), c.darkened(0.3))
	if marks > 1:
		for i in range(1, marks):
			var x := inside.position.x + roundf(inside.size.x * i / marks)
			draw_rect(Rect2(x, inside.position.y, 1, inside.size.y), Color(0, 0, 0, 0.35))
	if shield > 0:
		UIStyle.shield_outline(self, r, shield / maximum)

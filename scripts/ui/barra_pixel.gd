class_name BarraPixel
extends Control
## Barra de recurso (HP, energia...) desenhada à mão. O valor desliza até o
## novo número; quando cai, um "rastro" claro fica para trás e some depois,
## para dar para ler quanto se perdeu. Com `escudo`, ganha contorno azul e
## uma faixa embaixo do tamanho do escudo (na mesma escala do máximo).

var cor := EstiloUI.HP
var cor_baixa := Color()  ## se definida, vira essa cor abaixo de 30%
var marcas := 10  ## divisões finas na barra (0 = nenhuma)
var escudo := 0.0:  ## escudo por cima do valor (HP), na escala de `maximo`
	set(v):
		if not is_equal_approx(v, escudo):
			escudo = v
			queue_redraw()

var maximo := 1.0
var _mostrado := 1.0  ## valor exibido (anima)
var _rastro := 1.0  ## valor do rastro que fica para trás
var _tween: Tween
var _tween_rastro: Tween
var _iniciada := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 10)


func definir(valor: float, p_maximo: float, animar := true) -> void:
	maximo = maxf(1.0, p_maximo)
	if not animar or not _iniciada:
		_iniciada = true
		_mostrado = valor
		_rastro = valor
		queue_redraw()
		return
	if is_equal_approx(valor, _mostrado):
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_mostrado, _mostrado, valor, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _tween_rastro:
		_tween_rastro.kill()
	if valor < _rastro:
		_tween_rastro = create_tween()
		_tween_rastro.tween_interval(0.45)
		_tween_rastro.tween_method(_set_rastro, _rastro, valor, 0.35).set_trans(Tween.TRANS_QUAD)
	else:
		_rastro = valor


func _set_mostrado(v: float) -> void:
	_mostrado = v
	queue_redraw()


func _set_rastro(v: float) -> void:
	_rastro = v
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color.BLACK)
	var dentro := r.grow(-1)
	draw_rect(dentro, Color(0.08, 0.07, 0.12))
	var frac := clampf(_mostrado / maximo, 0, 1)
	var frac_rastro := clampf(_rastro / maximo, 0, 1)
	if frac_rastro > frac:
		draw_rect(Rect2(dentro.position, Vector2(dentro.size.x * frac_rastro, dentro.size.y)), Color(1, 0.95, 0.85, 0.85))
	var c := cor_baixa if cor_baixa != Color() and frac < 0.3 else cor
	var cheio := Rect2(dentro.position, Vector2(roundf(dentro.size.x * frac), dentro.size.y))
	draw_rect(cheio, c)
	# brilho de cima e sombra de baixo: volume em 2 pixels
	draw_rect(Rect2(cheio.position, Vector2(cheio.size.x, 2)), c.lightened(0.35))
	draw_rect(Rect2(cheio.position + Vector2(0, cheio.size.y - 2), Vector2(cheio.size.x, 2)), c.darkened(0.3))
	if marcas > 1:
		for i in range(1, marcas):
			var x := dentro.position.x + roundf(dentro.size.x * i / marcas)
			draw_rect(Rect2(x, dentro.position.y, 1, dentro.size.y), Color(0, 0, 0, 0.35))
	if escudo > 0:
		EstiloUI.contorno_escudo(self, r, escudo / maximo)

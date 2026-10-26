class_name RadialSelector
extends Node2D
## Seletor de opções em anel em volta de um lutador: faz parte do personagem
## na arena (é filho do visual dele), não da HUD. O anel gira como um tambor
## e a opção em foco fica sempre no topo. A batalha diz as opções, qual está
## em foco e o motivo de cada uma não servir; o mouse volta por sinais.

signal option_focused(index: int)
signal option_clicked(index: int)

const RADIUS := 57.0
const SIDE := 21.0  ## gema de cada opção, na grade de 3 px
const PIXEL := CombatEffects.PIXEL

var _options: Array = []
var _index := 0
var _reasons: Array[String] = []
var _opening := 0.0  ## 0 = recolhido na âncora, 1 = anel aberto
var _spin := 0.0  ## ângulo do tambor, animado até deixar a opção em foco no topo
var _time := 0.0


func _ready() -> void:
	z_index = 10  # por cima dos lutadores vizinhos
	create_tween().tween_property(self, "_opening", 1.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func display(options: Array, index: int, reasons: Array[String]) -> void:
	var first := _options.is_empty()
	_options = options
	_index = index
	_reasons = reasons
	if first:
		_spin = _target_spin()


## Recolhe as gemas para a âncora e some.
func close() -> void:
	set_process_unhandled_input(false)
	var t := create_tween()
	t.tween_property(self, "_opening", 0.0, 0.14).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)


func _target_spin() -> float:
	return TAU * _index / maxf(1, _options.size())


func _position(i: int) -> Vector2:
	var angle := -PI / 2 + TAU * i / _options.size() - _spin
	return (Vector2.from_angle(angle) * RADIUS * _opening / PIXEL).round() * PIXEL


func _process(delta: float) -> void:
	_time += delta
	_spin = lerp_angle(_spin, _target_spin(), minf(1.0, delta * 14.0))
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _options.is_empty() or _opening < 0.9:
		return
	var under := _option_under(get_local_mouse_position())
	if under < 0:
		return
	if event is InputEventMouseMotion and under != _index:
		option_focused.emit(under)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		option_clicked.emit(under)


func _option_under(point: Vector2) -> int:
	for i in _options.size():
		if point.distance_to(_position(i)) < SIDE * 0.7:
			return i
	return -1


func _draw() -> void:
	if _options.is_empty():
		return
	var a := _opening
	var focus: Dictionary = _options[_index]
	var focus_color: Color = focus.get("color", UIStyle.GOLD)
	# disco escuro para dar leitura sobre o cenário, e o trilho do tambor
	draw_circle(Vector2.ZERO, (RADIUS + SIDE) * a, Color(0.03, 0.02, 0.06, 0.45 * a))
	draw_arc(Vector2.ZERO, RADIUS * a, 0, TAU, 24, Color(UIStyle.GOLD, 0.25 * a), 1.0)
	# feixe tracejado da lente até a gema em foco
	var top := _position(_index)
	var step := 9.0
	var d := fposmod(_time * 30.0, step)
	while d < top.length() - SIDE * 0.6:
		draw_line(top.normalized() * d, top.normalized() * (d + 4.0), Color(focus_color, 0.8 * a), 2.0)
		d += step
	# o miolo: a própria lente, na cor da opção em foco
	draw_arc(Vector2.ZERO, 7.0 * a, 0, TAU, 12, Color(focus_color, a), 2.0)
	draw_circle(Vector2.ZERO, 3.0 * a, Color(focus_color.lightened(0.4), a))

	for i in _options.size():
		if i != _index:
			_gem(i, false)
	_gem(_index, true)  # por último, por cima das outras

	if a < 0.9:
		return
	# nome e efeito acima da gema do topo; motivo em vermelho se não servir
	var f := UIStyle.source()
	var width := 230.0
	var y := top.y - SIDE * 0.9
	var reason := _reasons[_index] if _index < _reasons.size() else ""
	var text: String = reason if reason != "" else focus.get("description", "")
	var text_color := UIStyle.DAMAGE_TAKEN if reason != "" else UIStyle.TEXT
	var text_height := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, 9).y
	var text_y := y - text_height
	draw_multiline_string_outline(f, Vector2(-width / 2, text_y + 6), text, HORIZONTAL_ALIGNMENT_CENTER, width, 9, -1, 3, Color.BLACK)
	draw_multiline_string(f, Vector2(-width / 2, text_y + 6), text, HORIZONTAL_ALIGNMENT_CENTER, width, 9, -1, text_color)
	UIStyle.text(self, Vector2(-width / 2, text_y - 6), focus.name, 13, focus_color.lightened(0.3), width, HORIZONTAL_ALIGNMENT_CENTER)
	UIStyle.text(self, Vector2(-width / 2, RADIUS + SIDE + 6), "←→ girar · Enter escolher · Q/E/R agir", 9, UIStyle.DIM_TEXT, width, HORIZONTAL_ALIGNMENT_CENTER)


## Gema octogonal da opção `i`, com a sigla; a em foco é maior e tem
## contorno dourado; a atual leva um pontinho; as inválidas ficam apagadas.
func _gem(i: int, focused: bool) -> void:
	var o: Dictionary = _options[i]
	var valid := i >= _reasons.size() or _reasons[i] == ""
	var color: Color = o.get("color", UIStyle.TEXT)
	if not valid:
		color = color.darkened(0.55).lerp(Color(0.4, 0.4, 0.45), 0.5)
	var c := _position(i)
	var l := (SIDE + (PIXEL * 2 if focused else 0.0)) / 2.0 * _opening
	if focused:
		l += PIXEL * 0.5 * sin(_time * 6.0)
	var k := PIXEL
	if l < k * 2:
		# abrindo/recolhendo: pequena demais para o octógono, vira um ponto
		draw_rect(Rect2(c - Vector2(k, k), Vector2(k * 2, k * 2)), color)
		return
	var oct := func(m: float) -> PackedVector2Array:
		var r := l + m
		return PackedVector2Array([c + Vector2(-r + k, -r), c + Vector2(r - k, -r), c + Vector2(r, -r + k), c + Vector2(r, r - k),
			c + Vector2(r - k, r), c + Vector2(-r + k, r), c + Vector2(-r, r - k), c + Vector2(-r, -r + k)])
	if focused:
		draw_colored_polygon(oct.call(k + 2.0), UIStyle.GOLD)
	draw_colored_polygon(oct.call(2.0), Color.BLACK)
	draw_colored_polygon(oct.call(0.0), color.darkened(0.35))
	draw_colored_polygon(oct.call(-k), color)
	draw_rect(Rect2(c + Vector2(-l + k * 2, -l + k), Vector2(maxf(0, l * 2 - k * 4), k)), Color(1, 1, 1, 0.35))  # brilho
	if o.get("current", false):
		draw_rect(Rect2(c + Vector2(l - k, -l - k), Vector2(k * 2, k * 2)), Color.BLACK)
		draw_rect(Rect2(c + Vector2(l - k * 0.5, -l - k * 0.5), Vector2(k, k)), UIStyle.GOLD)
	if _opening > 0.6:
		var abbr: String = o.get("abbr", String(o.name).left(3).to_upper())
		UIStyle.text(self, c + Vector2(-l, 3), abbr, 8, Color.WHITE if valid else UIStyle.DIM_TEXT, l * 2, HORIZONTAL_ALIGNMENT_CENTER)

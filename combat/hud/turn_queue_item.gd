class_name TurnQueueItem
extends Control
## Uma linha da ordem de ação: número na sequência, retrato, nome e
## pontinhos dos efeitos ativos. A linha da vez é maior, tem filete dourado
## e uma seta que pulsa na calha da esquerda.

const HEIGHT := 20.0
const TURN_HEIGHT := 28.0
const GUTTER := 14.0  ## espaço à esquerda para o número / seta

var combatant: Combatant
var portrait: Texture2D
var index := 0
var turn := false
var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func display(c: Combatant, p_portrait: Texture2D, p_index: int, p_turn: bool) -> void:
	combatant = c
	portrait = p_portrait
	index = p_index
	turn = p_turn
	custom_minimum_size.y = TURN_HEIGHT if turn else HEIGHT
	set_process(turn)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if not combatant:
		return
	var h := size.y
	var color := UIStyle.side_color(combatant.ally)
	var box := Rect2(GUTTER, 0, size.x - GUTTER, h)

	if turn:
		var dx := roundf(sin(_time * 5.0) * 1.5)
		var cy := h / 2
		var arrow := PackedVector2Array([Vector2(2 + dx, cy - 5), Vector2(9 + dx, cy), Vector2(2 + dx, cy + 5)])
		draw_colored_polygon(arrow, UIStyle.GOLD)
		draw_rect(box.grow(1), Color.BLACK)
		draw_rect(box, color.darkened(0.72))
		draw_rect(box, UIStyle.GOLD, false, 1.0)
	else:
		UIStyle.text(self, Vector2(0, h - 6), str(index + 1), 9, UIStyle.DIM_TEXT, GUTTER - 3, HORIZONTAL_ALIGNMENT_RIGHT)
		draw_rect(box, Color(0, 0, 0, 0.42))
	# faixa do lado (aliado/inimigo)
	draw_rect(Rect2(box.position, Vector2(3, h)), color if turn else color.darkened(0.25))

	var portrait_side := 22.0 if turn else 16.0
	var pr := Rect2(box.position + Vector2(6, (h - portrait_side) / 2), Vector2(portrait_side, portrait_side))
	draw_rect(pr, Color(0.03, 0.03, 0.06))
	if portrait:
		draw_texture_rect(portrait, pr, false)
	draw_rect(pr, color.darkened(0.2) if not turn else UIStyle.GOLD.darkened(0.15), false, 1.0)

	var font_size := 13 if turn else 11
	var nx := pr.end.x + 5
	var name_color := UIStyle.TEXT if turn else Color(0.8, 0.79, 0.86)
	var effects := combatant.effects()
	var pip_spacing := effects.size() * 10.0
	UIStyle.text(self, Vector2(nx, h / 2 + font_size * 0.36), combatant.name, font_size, name_color,
		box.end.x - nx - pip_spacing - 4)

	# efeitos: quadradinhos com a cor do efeito, encostados à direita
	var x := box.end.x - 4
	for e: Dictionary in effects:
		x -= 10
		var r := Rect2(x, h / 2 - 4, 8, 8)
		draw_rect(r.grow(1), Color.BLACK)
		draw_rect(r, UIStyle.effect_color(e))
		if e.get("type") == "alert":
			draw_rect(Rect2(r.position + Vector2(3, 1), Vector2(2, 4)), Color.BLACK)
			draw_rect(Rect2(r.position + Vector2(3, 6), Vector2(2, 1)), Color.BLACK)

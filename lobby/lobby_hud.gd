class_name LobbyHud
extends CanvasLayer
## Interface do saguão: dica de controles, aviso curto, caixa de conversa e
## o véu preto das transições. Só mostra; quem decide é o Lobby.

const CONTROLS := [[["←", "↑", "→", "↓"], "andar"], [["Enter"], "interagir"], [["Esc"], "menu"]]

var dialog: DialogBox

var _root: Control
var _notice: PanelContainer
var _notice_text: Label
var _notice_tween: Tween
var _veil: ColorRect
var _announcement: Label


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var controls := PanelContainer.new()
	controls.add_theme_stylebox_override("panel", UIStyle.panel())
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var drawing := Control.new()
	drawing.custom_minimum_size = Vector2(_controls_width(), 15)
	drawing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawing.draw.connect(_draw_controls.bind(drawing))
	controls.add_child(drawing)
	_root.add_child(controls)
	_anchor(controls, Vector2(0, 1), Vector2(UIStyle.MARGIN, -UIStyle.MARGIN))

	_notice = PanelContainer.new()
	_notice.add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.BACKGROUND, UIStyle.LIGHT_BORDER))
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_text = UIStyle.label("", 12, UIStyle.DIM_TEXT)
	_notice.add_child(_notice_text)
	_root.add_child(_notice)
	_anchor(_notice, Vector2(0.5, 1), Vector2(0, -56))
	_notice.modulate.a = 0

	dialog = DialogBox.new()
	_root.add_child(dialog)
	_anchor(dialog, Vector2(0.5, 1), Vector2(0, -UIStyle.MARGIN - 30))

	_announcement = UIStyle.label("", 26, UIStyle.GOLD, 7)
	_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_announcement)
	_anchor(_announcement, Vector2(0.5, 0.22), Vector2.ZERO)
	_announcement.modulate.a = 0

	_veil = ColorRect.new()
	_veil.color = Color.BLACK
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_veil)


## Mensagem curta e discreta acima dos controles, que some sozinha.
func warn(text: String) -> void:
	_notice_text.text = text
	if _notice_tween:
		_notice_tween.kill()
	_notice.modulate.a = 1
	_notice_tween = create_tween()
	_notice_tween.tween_interval(1.6)
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, 0.4)


## Anúncio grande no alto da tela (chegada de alguém, por exemplo).
func announce(text: String) -> void:
	_announcement.text = text
	_announcement.pivot_offset = _announcement.size / 2
	_announcement.scale = Vector2(1.3, 1.3)
	var t := create_tween()
	t.tween_property(_announcement, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(_announcement, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	t.tween_interval(2.0)
	t.tween_property(_announcement, "modulate:a", 0.0, 0.5)


func announcement_text() -> String:
	return _announcement.text if _announcement.modulate.a > 0 else ""


func notice_text() -> String:
	return _notice_text.text if _notice.modulate.a > 0 else ""


## Escurece (alfa 1) ou clareia (alfa 0) a tela inteira.
func veil(alpha: float, duration: float) -> Tween:
	var t := create_tween()
	t.tween_property(_veil, "color:a", alpha, duration)
	return t


func _anchor(c: Control, corner: Vector2, shift: Vector2) -> void:
	c.anchor_left = corner.x
	c.anchor_right = corner.x
	c.anchor_top = corner.y
	c.anchor_bottom = corner.y
	var direction := func(v: float) -> int:
		return Control.GROW_DIRECTION_END if v == 0 else (Control.GROW_DIRECTION_BEGIN if v == 1 else Control.GROW_DIRECTION_BOTH)
	c.grow_horizontal = direction.call(corner.x)
	c.grow_vertical = direction.call(corner.y)
	c.offset_left = shift.x
	c.offset_right = shift.x
	c.offset_top = shift.y
	c.offset_bottom = shift.y


func _controls_width() -> float:
	var x := 0.0
	for item: Array in CONTROLS:
		for t: String in item[0]:
			x += maxf(13.0, 7.0 * t.length() + 6.0) + 4
		x += UIStyle.font().get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 14
	return x - 14


func _draw_controls(c: Control) -> void:
	var x := 0.0
	for item: Array in CONTROLS:
		for t: String in item[0]:
			UIStyle.key(c, Vector2(x + 1, 1), t)
			x += maxf(13.0, 7.0 * t.length() + 6.0) + 4
		UIStyle.text(c, Vector2(x, 11), item[1], 10, Color(0.82, 0.8, 0.88))
		x += UIStyle.font().get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 14

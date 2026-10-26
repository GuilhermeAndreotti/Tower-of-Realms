class_name SkillSlot
extends Control
## Um botão da barra de habilidades, montado a partir da descrição que o
## personagem dá (ver Combatant.skills()). Não sabe nada do kit:
## mostra ícone, tecla, custo, selo e o estado (pronta, sem recurso, bloqueada,
## em recarga, com os turnos que faltam no meio).
## Passivas aparecem sem tecla e com a marca "PASSIVA" (a do personagem no
## fim da barra; uma skill 2 passiva, no lugar dela); só
## respondem ao clique as que têm opções (como a lente do Andri).
## Todos os slots têm a mesma largura: nome que não cabe é cortado com
## reticências e, com o mouse em cima, corre para ser lido inteiro.

signal requested(action: String)
signal focus(action: String)  ## "" quando o mouse sai

const SIDE := 54.0
const WIDTH := 66.0  ## do slot com o nome; a barra não cresce com nomes longos
const NAME_SIZE := 10
const ICON_SCALE := 3.0  ## ícones de 15px viram 45px, como os sprites da arena

var data := {}
var turn := false  ## é a vez do dono? fora da vez tudo fica apagado

var _over := false
var _time := 0.0
var _flash := 0.0
var _icon: Texture2D
var _name: _Name


func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, SIDE + 14)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_name = _Name.new()
	add_child(_name)
	resized.connect(func() -> void:
		_name.position = Vector2(0, SIDE + 1)
		_name.size = Vector2(size.x, 16))
	mouse_entered.connect(func() -> void:
		_over = true
		_name.running = true
		focus.emit(data.get("action", ""))
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_over = false
		_name.running = false
		focus.emit("")
		queue_redraw())


func display(p_data: Dictionary, p_turn: bool) -> void:
	if p_data.get("icon", "") != data.get("icon", ""):
		_icon = load(p_data.icon) if p_data.get("icon", "") != "" else null
	data = p_data
	turn = p_turn
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive() else Control.CURSOR_ARROW
	set_process(_animated())
	queue_redraw()


func is_ready() -> bool:
	return turn and data.get("state") == "ready" and interactive()


func passive() -> bool:
	return data.get("passive", false)


## Passivas sem opções só explicam; não são acionadas.
func interactive() -> bool:
	return not passive() or data.has("options")


## Clarão rápido quando a habilidade é usada (tecla ou clique).
func trigger() -> void:
	_flash = 1.0
	set_process(true)


func _animated() -> bool:
	return _flash > 0 or (is_ready() and data.get("highlight", false))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if interactive():
			requested.emit(data.get("action", ""))
		accept_event()


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(0, _flash - delta * 4)
	if not _animated():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if data.is_empty():
		return
	var state: String = data.get("state", "ready")
	var active := is_ready()
	var rises := -2.0 if active and _over else 0.0
	var r := Rect2(Vector2(roundf((size.x - SIDE) / 2), 2 + rises), Vector2(SIDE, SIDE))
	var erased := not turn

	# moldura
	draw_rect(r.grow(1), Color.BLACK)
	var background := UIStyle.LIGHT_BACKGROUND if active else UIStyle.BACKGROUND
	draw_rect(r, background)
	draw_rect(Rect2(r.position, Vector2(SIDE, 1)), Color(1, 1, 1, 0.08))
	var border_color := UIStyle.BORDER
	if active:
		border_color = UIStyle.GOLD if _over else UIStyle.LIGHT_BORDER
	elif passive():
		# moldura na cor do personagem: a passiva está sempre valendo
		var color_p: Color = data.get("color", UIStyle.LIGHT_BORDER)
		border_color = color_p.darkened(0.2 if turn else 0.55)
		if _over:
			border_color = UIStyle.GOLD
	draw_rect(r, border_color, false, 2.0 if active and _over else 1.0)
	if active and data.get("highlight", false):
		var a := 0.35 + 0.35 * sin(_time * 4.0)
		var color_d: Color = data.get("color", UIStyle.GOLD)
		draw_rect(r.grow(2), Color(color_d, a), false, 1.0)

	# "poço" do ícone, mais claro, para ícones escuros não sumirem no fundo
	var well := r.grow(-4)
	draw_rect(well, Color(0.2, 0.19, 0.29) if active else Color(0.13, 0.12, 0.18))
	draw_rect(Rect2(well.position, Vector2(well.size.x, 1)), Color(0, 0, 0, 0.5))

	# ícone
	if _icon:
		var icon_size := _icon.get_size() * ICON_SCALE
		var go := Rect2((r.get_center() - icon_size / 2).round(), icon_size)
		var mod := Color.WHITE
		if passive():
			pass  # sempre ativa: o ícone não apaga por estado
		elif state == "no_resource":
			mod = Color(0.5, 0.48, 0.55)
		elif state == "cooldown":
			mod = Color(0.35, 0.34, 0.4)
		elif state == "blocked":
			mod = Color(0.3, 0.3, 0.34)
		if erased:
			mod = mod.darkened(0.45)
		draw_texture_rect(_icon, go, false, mod)

	# cadeado das bloqueadas
	if state == "blocked":
		var c := r.get_center().round()
		draw_rect(Rect2(c + Vector2(-6, -1), Vector2(12, 9)), Color(0.75, 0.72, 0.8))
		draw_rect(Rect2(c + Vector2(-4, -6), Vector2(2, 5)), Color(0.75, 0.72, 0.8))
		draw_rect(Rect2(c + Vector2(2, -6), Vector2(2, 5)), Color(0.75, 0.72, 0.8))
		draw_rect(Rect2(c + Vector2(-2, -7), Vector2(4, 1)), Color(0.75, 0.72, 0.8))
		draw_rect(Rect2(c + Vector2(-1, 2), Vector2(2, 3)), Color.BLACK)

	# turnos que faltam da recarga, grandes, sobre o ícone apagado
	if state == "cooldown":
		UIStyle.text(self, Vector2(r.position.x, r.get_center().y + 8), str(data.get("cooldown_remaining", 0)), 22,
			UIStyle.TEXT if not erased else UIStyle.DIM_TEXT, SIDE, HORIZONTAL_ALIGNMENT_CENTER)

	# tecla no canto de cima (passivas não têm)
	if data.get("key", "") != "":
		UIStyle.key(self, r.position + Vector2(-3, -3), data.key, not erased)

	# selo no canto de cima à direita (nível, "ALL", "MÁX"...)
	var badge: String = data.get("badge", "")
	if badge != "":
		var f := UIStyle.source()
		var w := f.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 6
		var sr := Rect2(Vector2(r.end.x - w + 3, r.position.y - 3), Vector2(w, 12))
		var badge_color: Color = data.get("color", UIStyle.GOLD)
		draw_rect(sr.grow(1), Color.BLACK)
		draw_rect(sr, badge_color.darkened(0.35) if not erased else Color(0.3, 0.3, 0.35))
		draw_string(f, sr.position + Vector2(0, 9), badge, HORIZONTAL_ALIGNMENT_CENTER, w, 9, Color.WHITE)

	# custo no canto de baixo
	var missing_reason := state in ["no_resource", "cooldown"]
	var point_cost: int = data.get("point_cost", 0)
	var energy_cost: int = data.get("energy_cost", 0)
	var base := r.end + Vector2(-4, -4)
	if passive():
		var tag_color: Color = data.get("color", UIStyle.DIM_TEXT)
		UIStyle.text(self, Vector2(r.position.x, base.y), "PASSIVA", 8, tag_color.lightened(0.3) if not erased else UIStyle.DIM_TEXT,
			SIDE, HORIZONTAL_ALIGNMENT_CENTER)
	elif point_cost > 0:
		for i in point_cost:
			UIStyle.diamond(self, base + Vector2(-4 - 9 * i, -3), 4, not missing_reason and not erased)
	elif energy_cost > 0:
		var cost_color := UIStyle.DAMAGE_TAKEN if missing_reason else UIStyle.ENERGY
		if erased:
			cost_color = cost_color.darkened(0.4)
		UIStyle.text(self, Vector2(r.position.x, base.y), str(energy_cost), 10, cost_color, SIDE - 4, HORIZONTAL_ALIGNMENT_RIGHT)
	elif data.get("point_gain", 0) > 0:
		# habilidades que geram ponto mostram um "+◆" discreto
		UIStyle.text(self, Vector2(r.position.x, base.y), "+", 10, UIStyle.POINT, SIDE - 13, HORIZONTAL_ALIGNMENT_RIGHT)
		UIStyle.diamond(self, base + Vector2(-4, -3), 3.5, not erased)

	# nome embaixo (num filho que corta o que não cabe)
	var name_color := UIStyle.TEXT if active or (passive() and turn) else UIStyle.DIM_TEXT
	if active and _over:
		name_color = UIStyle.GOLD
	_name.display(data.get("name", ""), name_color)

	if _flash > 0:
		draw_rect(r, Color(1, 1, 1, _flash * 0.6))


## Nome embaixo do slot. Cabendo, fica centrado; se não, aparece cortado com
## reticências e, enquanto `running` (mouse em cima), desliza até o fim e
## volta, com uma pausa em cada ponta.
class _Name extends Control:
	const SPEED := 30.0  ## px por segundo
	const PAUSE := 0.6  ## segundos parado em cada ponta
	const SLACK := 2.0  ## margem de cada lado

	var running := false:
		set(v):
			if v == running:
				return
			running = v
			_time = 0.0
			set_process(running and _excess() > 0)
			queue_redraw()

	var _text := ""
	var _color := Color.WHITE
	var _time := 0.0

	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)

	func display(text: String, color: Color) -> void:
		if text == _text and color == _color:
			return
		_text = text
		_color = color
		queue_redraw()

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _width(t: String) -> float:
		return UIStyle.source().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x

	## Quanto o nome passa da largura disponível (0 = cabe).
	func _excess() -> float:
		return maxf(0.0, _width(_text) - (size.x - 2 * SLACK))

	## Deslocamento do texto no vaivém: pausa, ida, pausa, volta.
	func _shift() -> float:
		var excess := _excess()
		var outbound := excess / SPEED
		var t := fmod(_time, 2.0 * (outbound + PAUSE))
		if t < PAUSE:
			return 0.0
		t -= PAUSE
		if t < outbound:
			return t * SPEED
		t -= outbound
		if t < PAUSE:
			return excess
		return excess - (t - PAUSE) * SPEED

	## O nome cortado no último caractere que cabe junto com as reticências.
	func _cut() -> String:
		var t := _text
		while t.length() > 1 and _width(t + "…") > size.x - 2 * SLACK:
			t = t.left(-1)
		return t.strip_edges() + "…"

	func _draw() -> void:
		var base := 13.0
		if _excess() <= 0:
			UIStyle.text(self, Vector2(0, base), _text, NAME_SIZE, _color, size.x, HORIZONTAL_ALIGNMENT_CENTER)
		elif running:
			UIStyle.text(self, Vector2(SLACK - _shift(), base), _text, NAME_SIZE, _color)
		else:
			UIStyle.text(self, Vector2(SLACK, base), _cut(), NAME_SIZE, _color)

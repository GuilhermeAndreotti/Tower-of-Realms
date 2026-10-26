class_name MainMenu
extends Control
## Tela de abertura: a logo, NEW GAME, LOAD GAME e QUIT. Os dois primeiros
## abrem a lista de slots de save (Progression.SLOTS): no jogo novo, um slot
## ocupado pede confirmação para ser sobrescrito; no carregar, só os ocupados
## abrem. Em qualquer lista, um slot ocupado pode ser apagado (com confirmação).
## Só apresenta: quem cria, lê e apaga os saves é a Progression.
## Controles: ↑/↓ escolhe, Enter confirma, Del apaga, Esc volta.

const LOBBY_SCENE := "res://lobby/lobby.tscn"
const LOGO := "res://logo.png"
const EMBERS := 40

var mode := "start"  ## "start", "new" (escolher onde criar) ou "load"
var pending_confirm := ""  ## confirmação aberta: "", "overwrite" ou "delete"
var slot_requested := 0

var _start: VBoxContainer
var _list: VBoxContainer
var _list_title: Label
var _slots: Array[Button] = []
var _delete: Array[Button] = []
var _back: Button
var _load: Button
var _new: Button
var _notice: Label
var _logo_box: Control
var _logo: TextureRect
var _confirmation: ColorRect
var _confirmation_text: Label
var _confirm_button: Button
var _cancel_button: Button
var _veil: ColorRect
var _embers: Control
var _particles: Array[Dictionary] = []
var _time := 0.0
var _leaving := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	open("start")
	_veil.color.a = 1.0
	create_tween().tween_property(_veil, "color:a", 0.0, 0.5)


# ------------------------------------------------------------------ montagem
func _build() -> void:
	var background := TextureRect.new()
	background.texture = load(Floors.DEFAULT_BACKGROUND)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var dark := ColorRect.new()
	dark.color = Color(0.03, 0.02, 0.06, 0.78)
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dark)
	_embers = Control.new()
	_embers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_embers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_embers.draw.connect(_draw_embers)
	add_child(_embers)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	# a logo é 4x a arte; na lista ela encolhe para caber os slots. Fica numa
	# caixa para poder flutuar sem brigar com o container.
	_logo_box = Control.new()
	_logo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_logo_box)
	_logo = TextureRect.new()
	_logo.texture = load(LOGO)
	_logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_box.add_child(_logo)

	_start = VBoxContainer.new()
	_start.add_theme_constant_override("separation", 8)
	_start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_new = _button("NEW GAME", Vector2(240, 38), 16)
	_new.pressed.connect(open.bind("new"))
	_load = _button("LOAD GAME", Vector2(240, 38), 16)
	_load.pressed.connect(open.bind("load"))
	var leave := _button("QUIT", Vector2(240, 38), 16)
	leave.pressed.connect(func() -> void: get_tree().quit())
	for b in [_new, _load, leave]:
		_start.add_child(b)
	column.add_child(_start)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_list_title = UIStyle.label("", 14, UIStyle.GOLD, 4)
	_list_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(_list_title)
	for n in range(1, Progression.SLOTS + 1):
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var slot := _button("", Vector2(480, 60), 14)
		slot.draw.connect(_draw_slot.bind(slot, n))
		slot.pressed.connect(choose_slot.bind(n))
		var delete := _button("APAGAR", Vector2(90, 60), 11)
		delete.add_theme_color_override("font_color", UIStyle.DAMAGE_TAKEN)
		delete.pressed.connect(request_delete.bind(n))
		line.add_child(slot)
		line.add_child(delete)
		_slots.append(slot)
		_delete.append(delete)
		_list.add_child(line)
	var baseboard := HBoxContainer.new()
	baseboard.add_theme_constant_override("separation", 12)
	_back = _button("VOLTAR", Vector2(120, 30), 12)
	_back.pressed.connect(open.bind("start"))
	baseboard.add_child(_back)
	_notice = UIStyle.label("", 11, UIStyle.DAMAGE_TAKEN, 3)
	_notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	baseboard.add_child(_notice)
	var hints := Control.new()
	hints.custom_minimum_size = Vector2(210, 16)
	hints.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hints.draw.connect(_draw_hints.bind(hints))
	baseboard.add_child(hints)
	_list.add_child(baseboard)
	column.add_child(_list)

	var version := UIStyle.label("protótipo", 10, UIStyle.DIM_TEXT, 2)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	add_child(version)

	_build_confirmation()
	_veil = ColorRect.new()
	_veil.color = Color(0, 0, 0, 0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	for i in EMBERS:
		_particles.append(_new_ember(true))


func _build_confirmation() -> void:
	_confirmation = ColorRect.new()
	_confirmation.color = Color(0, 0, 0, 0.6)
	_confirmation.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirmation.visible = false
	add_child(_confirmation)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirmation.add_child(center)
	var panel := PanelContainer.new()
	var style := UIStyle.panel(UIStyle.LIGHT_BACKGROUND, UIStyle.GOLD.darkened(0.25), 2)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	_confirmation_text = UIStyle.label("", 13, UIStyle.TEXT, 3)
	_confirmation_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirmation_text.custom_minimum_size.x = 340
	_confirmation_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_confirmation_text)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	_cancel_button = _button("CANCELAR", Vector2(130, 32), 12)
	_cancel_button.pressed.connect(cancel)
	_confirm_button = _button("", Vector2(130, 32), 12)
	_confirm_button.add_theme_color_override("font_color", UIStyle.DAMAGE_TAKEN)
	_confirm_button.pressed.connect(confirm)
	buttons.add_child(_cancel_button)
	buttons.add_child(_confirm_button)
	box.add_child(buttons)
	# o foco não escapa para os botões de trás enquanto a pergunta está aberta
	for b: Button in [_cancel_button, _confirm_button]:
		var other := _confirm_button if b == _cancel_button else _cancel_button
		for side in [SIDE_LEFT, SIDE_RIGHT]:
			b.set_focus_neighbor(side, other.get_path())
		for side in [SIDE_TOP, SIDE_BOTTOM]:
			b.set_focus_neighbor(side, b.get_path())
		b.focus_next = other.get_path()
		b.focus_previous = other.get_path()


## Botão de pedra com filete dourado; o foco (teclado) tem o visual do hover.
func _button(text: String, min_size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", UIStyle.GOLD)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", UIStyle.DIM_TEXT)
	b.add_theme_stylebox_override("normal", UIStyle.panel(UIStyle.BACKGROUND, UIStyle.GOLD.darkened(0.45), 2))
	var highlight := UIStyle.panel(Color(0.2, 0.17, 0.1, 0.95), UIStyle.GOLD, 2)
	b.add_theme_stylebox_override("hover", highlight)
	b.add_theme_stylebox_override("focus", highlight)
	b.add_theme_stylebox_override("pressed", UIStyle.panel(Color(0.3, 0.24, 0.1), Color.WHITE, 2))
	b.add_theme_stylebox_override("disabled", UIStyle.panel(UIStyle.BACKGROUND, UIStyle.BORDER, 2))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled and b.is_visible_in_tree():
			b.grab_focus())
	return b


# --------------------------------------------------------------- telas
## Mostra a tela `m`: "start", "new" ou "load".
func open(m: String) -> void:
	mode = m
	_notice.text = ""
	var at_start := m == "start"
	_start.visible = at_start
	_list.visible = not at_start
	_logo_box.custom_minimum_size = Vector2(568, 248) if at_start else Vector2(284, 124)
	_logo.position.y = 0
	_load.disabled = not Progression.any_slot()
	if at_start:
		(_new if _load.disabled else _load).grab_focus()
		return
	_list_title.text = "NEW GAME — escolha onde salvar" if m == "new" else "LOAD GAME — escolha o save"
	_refresh_slots()
	_slots[_initial_slot() - 1].grab_focus()


func _refresh_slots() -> void:
	for i in _slots.size():
		var exists := Progression.slot_exists(i + 1)
		_delete[i].disabled = not exists
		_delete[i].modulate.a = 1.0 if exists else 0.35
		_slots[i].queue_redraw()


## Onde o cursor começa: no jogo novo, o primeiro vazio; no carregar, o salvo
## mais recentemente.
func _initial_slot() -> int:
	var best := 1
	var most_recent := -1
	for n in range(1, Progression.SLOTS + 1):
		var r := Progression.slot_summary(n)
		if mode == "new" and not r.exists:
			return n
		if mode == "load" and r.exists and int(r.saved_at) > most_recent:
			most_recent = r.saved_at
			best = n
	return best


## Clicar (ou Enter) num slot: cria, pede para sobrescrever ou carrega.
func choose_slot(n: int) -> void:
	if pending_confirm != "" or _leaving:
		return
	var exists := Progression.slot_exists(n)
	if mode == "new":
		if exists:
			_ask("overwrite", n, "Sobrescrever o slot %d?\nO progresso salvo nele será perdido." % n, "SOBRESCREVER")
		else:
			_enter(n, true)
	elif mode == "load":
		if exists:
			_enter(n, false)
		else:
			_notice.text = "O slot %d está vazio." % n


func request_delete(n: int) -> void:
	if pending_confirm != "" or _leaving or not Progression.slot_exists(n):
		return
	_ask("delete", n, "Apagar o slot %d?\nNão dá para desfazer." % n, "APAGAR")


func _ask(type: String, n: int, text: String, confirm_label: String) -> void:
	pending_confirm = type
	slot_requested = n
	_confirmation_text.text = text
	_confirm_button.text = confirm_label
	_confirmation.visible = true
	_cancel_button.grab_focus()  # o padrão é não perder nada


func confirm() -> void:
	var type := pending_confirm
	var n := slot_requested
	cancel()
	if type == "overwrite":
		_enter(n, true)
	elif type == "delete":
		Progression.delete_slot(n)
		_notice.text = "Slot %d apagado." % n
		_refresh_slots()
		_load.disabled = not Progression.any_slot()
		_slots[n - 1].grab_focus()


func cancel() -> void:
	if pending_confirm == "":
		return
	pending_confirm = ""
	_confirmation.visible = false
	if mode != "start":
		_slots[slot_requested - 1].grab_focus()


## Prepara o save do slot e vai para o saguão, entrando pelo começo.
func _enter(n: int, candidate: bool) -> void:
	_leaving = true
	if candidate:
		Progression.new_game(n)
	else:
		Progression.use_slot(n)
	Engine.set_meta(Lobby.ENTRANCE_META, "start")
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_veil, "color:a", 1.0, 0.5)
	t.tween_callback(func() -> void: get_tree().change_scene_to_file(LOBBY_SCENE))


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE:
			if pending_confirm != "":
				cancel()
			elif mode != "start":
				open("start")
			get_viewport().set_input_as_handled()
		KEY_DELETE, KEY_BACKSPACE:
			var i := _slots.find(get_viewport().gui_get_focus_owner())
			if pending_confirm == "" and i >= 0:
				request_delete(i + 1)
				get_viewport().set_input_as_handled()


# ------------------------------------------------------------- desenho
## Texto do resumo de um slot ocupado (também usado nos testes).
static func describe_slot(n: int) -> String:
	var r := Progression.slot_summary(n)
	if not r.exists:
		return "Vazio"
	var floors := "nenhum andar vencido" if r.floors == 0 else "%d de %d andares vencidos" % [r.floors, Floors.total()]
	return "Nv %d  ·  %d personagens  ·  %s" % [r.level, r.characters, floors]


static func save_date(unix: int) -> String:
	if unix <= 0:
		return ""
	var local := unix + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(local)
	return "%02d/%02d/%04d  %02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute]


func _draw_slot(b: Button, n: int) -> void:
	var r := Progression.slot_summary(n)
	var block := Rect2(6, 6, 48, b.size.y - 12)
	b.draw_rect(block, UIStyle.GOLD.darkened(0.55) if r.exists else UIStyle.BORDER.darkened(0.3))
	b.draw_rect(block, Color(1, 1, 1, 0.12), false, 1.0)
	UIStyle.text(b, Vector2(block.position.x, block.get_center().y + 9), str(n), 24,
		Color.WHITE if r.exists else UIStyle.DIM_TEXT, block.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var x := block.end.x + 12
	var w := b.size.x - x - 10
	if not r.exists:
		UIStyle.text(b, Vector2(x, 36), "— Vazio —", 14, UIStyle.DIM_TEXT, w)
		return
	UIStyle.text(b, Vector2(x, 24), "SLOT %d" % n, 14, UIStyle.GOLD, w)
	UIStyle.text(b, Vector2(x, 24), save_date(r.saved_at), 10, UIStyle.DIM_TEXT, w, HORIZONTAL_ALIGNMENT_RIGHT)
	UIStyle.text(b, Vector2(x, 44), describe_slot(n), 11, UIStyle.TEXT, w)


func _draw_hints(c: Control) -> void:
	var x := 0.0
	for item in [[["Del"], "apagar"], [["Esc"], "voltar"]]:
		for t: String in item[0]:
			UIStyle.key(c, Vector2(x + 1, 1), t)
			x += maxf(13.0, 7.0 * t.length() + 6.0) + 4
		UIStyle.text(c, Vector2(x, 11), item[1], 10, Color(0.82, 0.8, 0.88))
		x += UIStyle.font().get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 16


## Brasa subindo do pé da tela; `spread` sorteia a altura (início da tela).
func _new_ember(spread := false) -> Dictionary:
	var screen := get_viewport_rect().size
	return {"pos": Vector2(randf() * screen.x, randf() * screen.y if spread else screen.y + 4),
		"spd": randf_range(12.0, 34.0), "phase": randf() * TAU, "px_size": 2.0 if randf() < 0.3 else 1.0}


func _draw_embers() -> void:
	var screen := get_viewport_rect().size
	for p in _particles:
		var pos: Vector2 = p.pos
		var a := clampf(pos.y / screen.y, 0.0, 1.0)  # apagam ao subir
		var px_size: float = p.px_size * 2.0
		_embers.draw_rect(Rect2(pos.floor(), Vector2(px_size, px_size)), Color(1.0, 0.62 + 0.25 * a, 0.25, 0.75 * a))


func _process(delta: float) -> void:
	_time += delta
	for i in _particles.size():
		var p := _particles[i]
		p.pos += Vector2(sin(_time * 1.3 + p.phase) * 8.0, -float(p.spd)) * delta
		if p.pos.y < -4:
			_particles[i] = _new_ember()
	_embers.queue_redraw()
	if mode == "start":
		_logo.position.y = roundf(sin(_time * 1.6) * 3.0)  # flutua devagar

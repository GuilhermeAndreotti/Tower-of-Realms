class_name FloorSelect
extends Control
## Escolha do andar, entre a porta do saguão e a montagem da equipe. Os
## andares ficam empilhados como a Torre (o 1º embaixo). Vencidos podem ser
## repetidos; o seguinte ao último vencido está liberado; o resto, trancado.
## Lê tudo de Floors, então andares novos aparecem aqui sem mexer nesta tela.
## Controles: ↑/↓ escolhe, Enter sobe, Esc volta ao saguão.

const TEAM_SCENE := "res://tower/team_select.tscn"
const LOBBY_SCENE := "res://lobby/lobby.tscn"
const CLEARED_COLOR := Color(0.45, 0.9, 0.55)

var cursor := 1  ## número do andar sob o cursor

var _cards: Array[Control] = []  ## um por andar, do 1º ao último
var _detail: VBoxContainer
var _button: Button
var _notice: Label
var _time := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	cursor = Floors.highest_unlocked()
	_build()
	_refresh()


# ------------------------------------------------------------------ montagem
func _build() -> void:
	var background := TextureRect.new()
	background.texture = load(Floors.DEFAULT_BACKGROUND)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var veil := ColorRect.new()
	veil.color = Color(0.03, 0.02, 0.06, 0.7)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin" + side, 20)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.add_child(UIStyle.label("A TORRE", 22, UIStyle.GOLD, 5))
	titles.add_child(UIStyle.label("Escolha o andar. Os que você já venceu podem ser repetidos.", 11, UIStyle.DIM_TEXT))
	titles.add_child(UIStyle.label("Limite de nível atual: %d (sobe ao liberar andares novos)" % Floors.level_limit(), 11, UIStyle.GOLD, 3))
	column.add_child(titles)

	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 14)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(middle)

	# esquerda: os andares, o mais alto em cima
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	stack.alignment = BoxContainer.ALIGNMENT_END
	middle.add_child(stack)
	for n in range(1, Floors.total() + 1):
		var c := Control.new()
		c.custom_minimum_size = Vector2(330, 62)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		c.draw.connect(_draw_card.bind(c, n))
		c.mouse_entered.connect(func() -> void:
			cursor = n
			_refresh())
		c.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				cursor = n
				climb())
		_cards.append(c)
	for i in range(_cards.size() - 1, -1, -1):
		stack.add_child(_cards[i])

	# direita: detalhes do andar sob o cursor
	var sheet := PanelContainer.new()
	var ef := UIStyle.panel()
	ef.set_content_margin_all(12)
	sheet.add_theme_stylebox_override("panel", ef)
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 6)
	sheet.add_child(_detail)
	middle.add_child(sheet)

	var baseboard := HBoxContainer.new()
	baseboard.add_theme_constant_override("separation", 12)
	var hints := Control.new()
	hints.custom_minimum_size = Vector2(0, 16)
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hints.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hints.draw.connect(_draw_hints.bind(hints))
	hints.custom_minimum_size.x = 260
	baseboard.add_child(hints)
	_notice = UIStyle.label("", 11, UIStyle.DAMAGE_TAKEN, 3)
	_notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	baseboard.add_child(_notice)
	_button = Button.new()
	_button.text = "SUBIR  ▸"
	_button.focus_mode = Control.FOCUS_NONE
	_button.custom_minimum_size = Vector2(170, 40)
	_button.add_theme_font_size_override("font_size", 15)
	_button.add_theme_color_override("font_color", UIStyle.GOLD)
	_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_button.add_theme_color_override("font_disabled_color", UIStyle.DIM_TEXT)
	_button.add_theme_stylebox_override("normal", UIStyle.panel(UIStyle.LIGHT_BACKGROUND, UIStyle.GOLD.darkened(0.25), 2))
	_button.add_theme_stylebox_override("hover", UIStyle.panel(Color(0.2, 0.17, 0.1), UIStyle.GOLD, 2))
	_button.add_theme_stylebox_override("pressed", UIStyle.panel(Color(0.3, 0.24, 0.1), Color.WHITE, 2))
	_button.add_theme_stylebox_override("disabled", UIStyle.panel(UIStyle.BACKGROUND, UIStyle.BORDER, 2))
	_button.pressed.connect(climb)
	baseboard.add_child(_button)
	column.add_child(baseboard)


# ------------------------------------------------------------- desenho
## "cleared", "new" (liberado e nunca vencido) ou "locked".
static func situation(n: int) -> String:
	if Floors.is_cleared(n):
		return "cleared"
	return "new" if Floors.is_unlocked(n) else "locked"


func _draw_card(c: Control, n: int) -> void:
	var d := Floors.data(n)
	var sit := situation(n)
	var at_cursor := n == cursor
	var r := Rect2(Vector2.ZERO, c.size)
	var locked := sit == "locked"
	c.draw_rect(r.grow(1), Color.BLACK)
	c.draw_rect(r, UIStyle.LIGHT_BACKGROUND if at_cursor else UIStyle.BACKGROUND)
	# número do andar num bloco de pedra
	var block := Rect2(6, 6, 50, r.size.y - 12)
	var block_color := UIStyle.BORDER.darkened(0.3) if locked else (UIStyle.GOLD.darkened(0.55) if sit == "new" else UIStyle.ALLY.darkened(0.6))
	c.draw_rect(block, block_color)
	c.draw_rect(block, Color(1, 1, 1, 0.12), false, 1.0)
	UIStyle.text(c, Vector2(block.position.x, block.get_center().y + 10), str(n), 26,
		UIStyle.DIM_TEXT if locked else Color.WHITE, block.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var x := block.end.x + 10
	var w := r.size.x - x - 8
	UIStyle.text(c, Vector2(x, 22), "???" if locked else d.name, 14,
		UIStyle.DIM_TEXT if locked else (UIStyle.GOLD if at_cursor else UIStyle.TEXT), w)
	var state := {"cleared": ["✓ Vencido", CLEARED_COLOR], "new": ["✦ Novo", UIStyle.GOLD],
		"locked": ["Trancado: vença o andar %d" % (n - 1), UIStyle.DIM_TEXT]}
	UIStyle.text(c, Vector2(x, 40), state[sit][0], 10, state[sit][1], w)
	if not locked:
		var info := "Nv %d  ·  equipe %d" % [d.recommended_level, Floors.max_team(n)]
		UIStyle.text(c, Vector2(x, 40), info, 10, UIStyle.DIM_TEXT, w, HORIZONTAL_ALIGNMENT_RIGHT)
	var border := UIStyle.GOLD if at_cursor else UIStyle.BORDER
	if at_cursor:
		border = Color(border, 0.7 + 0.3 * sin(_time * 5.0))
	c.draw_rect(r, border, false, 2.0 if at_cursor else 1.0)


func _draw_hints(c: Control) -> void:
	var x := 0.0
	for item in [[["↑", "↓"], "escolher"], [["Enter"], "subir"], [["Esc"], "saguão"]]:
		for t: String in item[0]:
			UIStyle.key(c, Vector2(x + 1, 1), t)
			x += maxf(13.0, 7.0 * t.length() + 6.0) + 4
		UIStyle.text(c, Vector2(x, 11), item[1], 10, Color(0.82, 0.8, 0.88))
		x += UIStyle.source().get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 16


# ---------------------------------------------------------- ficha (detalhe)
func _build_sheet() -> void:
	for child in _detail.get_children():
		child.queue_free()
	var n := cursor
	var d := Floors.data(n)
	var sit := situation(n)
	_detail.add_child(UIStyle.label("ANDAR %d" % n, 10, UIStyle.DIM_TEXT, 2))
	if sit == "locked":
		_detail.add_child(UIStyle.label("???", 20, UIStyle.DIM_TEXT, 5))
		_detail.add_child(UIStyle.label("Vença o andar %d para liberar." % (n - 1), 12, UIStyle.DIM_TEXT))
		return
	_detail.add_child(UIStyle.label(d.name, 20, UIStyle.GOLD, 5))
	var desc := UIStyle.label(d.get("description", ""), 11, Color(0.82, 0.8, 0.88))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(desc)

	# nível recomendado contra o da equipe
	var levels: Array[int] = []
	for id in Progression.main_team():
		levels.append(Progression.level(id))
	var average := Progression.entry_level(levels)
	var rec: int = d.recommended_level
	var level_row := UIStyle.label("Nível recomendado: %d  (sua equipe: %d)" % [rec, average], 11,
		UIStyle.DAMAGE_TAKEN if average < rec else UIStyle.TEXT, 3)
	_detail.add_child(level_row)
	var maximum := Floors.max_team(n)
	_detail.add_child(UIStyle.label("Equipe: %s" % ("só 1 personagem" if maximum == 1 else "até %d personagens" % maximum), 11, UIStyle.TEXT, 3))

	_detail.add_child(UIStyle.label("INIMIGOS", 9, UIStyle.DIM_TEXT, 2))
	var enemies := Floors.create_enemies(n)
	var groups := {}  ## nome -> [quantidade, tipo]
	for ini in enemies:
		if not groups.has(ini.name):
			groups[ini.name] = [0, ini.type]
		groups[ini.name][0] += 1
	for enemy_name: String in groups:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var amount: int = groups[enemy_name][0]
		h.add_child(UIStyle.label(("%d× " % amount if amount > 1 else "") + enemy_name, 12, UIStyle.ENEMY.lightened(0.3), 3))
		h.add_child(UIStyle.type_tag(groups[enemy_name][1]))
		_detail.add_child(h)

	_detail.add_child(UIStyle.label("RECOMPENSA", 9, UIStyle.DIM_TEXT, 2))
	_detail.add_child(UIStyle.label("%d XP para cada personagem" % Progression.battle_xp(enemies), 12, UIStyle.XP, 3))
	if sit == "new":
		if not d.get("on_win", []).is_empty():
			_detail.add_child(UIStyle.label("✦ A primeira vitória muda algo na Torre...", 11, UIStyle.GOLD, 3))
		if n < Floors.total():
			var next := Floors.floor_limit(n + 1)
			var text := "Libera o andar %d" % (n + 1)
			if next > Floors.level_limit():
				text += " e o limite de nível sobe para %d" % next
			_detail.add_child(UIStyle.label(text + ".", 11, UIStyle.DIM_TEXT, 2))
	else:
		_detail.add_child(UIStyle.label("✓ Vencido. Repetir dá a XP de novo, até o limite de nível %d." % Floors.level_limit(), 11, CLEARED_COLOR, 3))


# --------------------------------------------------------------- estado
## Vai para a montagem da equipe no andar sob o cursor (se liberado).
func climb() -> void:
	if not Floors.is_unlocked(cursor):
		_notice.text = "Andar %d trancado: vença o andar %d primeiro." % [cursor, cursor - 1]
		return
	Floors.choose(cursor)
	get_tree().change_scene_to_file(TEAM_SCENE)


func _refresh() -> void:
	_notice.text = ""
	_button.disabled = not Floors.is_unlocked(cursor)
	for c in _cards:
		c.queue_redraw()
	if _detail.get_meta("floor", 0) != cursor:
		_detail.set_meta("floor", cursor)
		_build_sheet()


func _process(delta: float) -> void:
	_time += delta
	_cards[cursor - 1].queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_UP, KEY_W:
			cursor = mini(cursor + 1, Floors.total())
			_refresh()
		KEY_DOWN, KEY_S:
			cursor = maxi(cursor - 1, 1)
			_refresh()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			climb()
		KEY_ESCAPE:
			Engine.set_meta(Lobby.ENTRANCE_META, "door")
			get_tree().change_scene_to_file(LOBBY_SCENE)

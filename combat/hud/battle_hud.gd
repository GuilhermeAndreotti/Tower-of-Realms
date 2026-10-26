class_name BattleHud
extends CanvasLayer
## Interface da batalha. Só apresenta: lê o estado dos combatentes e as
## descrições que eles dão (effects(), skills()) e avisa a batalha do
## que o jogador pediu. Nenhuma regra de combate mora aqui.
##
##   ┌ordem──┐      ┌objetivo / controles┐       ┌registro──┐
##   │       │      └────────────────────┘       └──────────┘
##   └───────┘              (arena)
##   ┌personagem da vez┐┌resto da equipe┐  ┌barra de habilidades┐

signal action_requested(action: String)
signal skill_focused(action: String)  ## "" quando nenhuma
signal lobby_requested
signal option_clicked(index: int)

const MAX_LOG_LINES := 5
const HINT_WIDTH := 300.0  ## cartão da habilidade em foco, acima da barra
const PREFS_FILE := "user://hud.cfg"

var _root: Control
var _portraits := {}  ## Combatant -> Texture2D

# ordem de ação
var _queue_items: Array[TurnQueueItem] = []
var _queue_box: VBoxContainer

# objetivo e controles
var _objective: Label
var _controls_hint: Label
var _controls: Control
var _controls_open := true

# registro
var _log: RichTextLabel
var _log_lines: Array[String] = []

# personagem ativo
var _active: Combatant
var _points := 0
var _max_points := 0
var _panel_portrait: Control
var _name: Label
var _level: Label
var _type: Control  ## selo do elemento ao lado do nome
var _form: Label
var _hp_bar: PixelBar
var _hp_text: Label
var _shield_text: Label  ## "+N" ao lado do HP, quando há escudo
var _energy_bar: PixelBar
var _energy_text: Label
var _energy_row: Control
var _kit_row: Control  ## barra própria do kit (Combatant.kit_bar()), quando tem
var _kit_label: Label
var _kit_bar: PixelBar
var _kit_text: Label
var _points_drawing: Control
var _chips: HBoxContainer
var _character_panel: PanelContainer

# resto da equipe (cartõezinhos ao lado do painel)
var _team_panel: PanelContainer
var _team_box: HBoxContainer
var _cards: Array[Control] = []

# habilidades
var _bar_panel: PanelContainer
var _bar_title: Label
var _slot_box: HBoxContainer
var _slots := {}  ## acao -> SkillSlot
var _ids_slots: Array[String] = []
var _hint: PanelContainer
var _hint_card: SkillCard
var _focus := ""
var _players_turn := false

# seletor de opções (elemento, artefato...), acima da barra
var _options: PanelContainer
var _options_title: Label
var _option_list: VBoxContainer
var _option_reason: Label

# avisos
var _announcement: Label
var _end: Control
var _end_text: Label
var _end_rewards: VBoxContainer  ## XP e níveis ganhos na vitória
var _end_extras: VBoxContainer  ## andar liberado, história


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_order()
	_build_objective()
	_build_log()
	_build_character()
	_build_team()
	_build_skills()
	_build_options()
	_build_announcement()
	_build_end()
	_load_prefs()


# ------------------------------------------------------------------ montagem
## Prende `c` num canto da tela (`corner` em 0..1) e o faz crescer para dentro.
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


func _panel(corner: Vector2, shift: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.panel())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(p)
	_anchor(p, corner, shift)
	return p


func _vbox(separation := 2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _hbox(separation := 4) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


func _header(text: String) -> Label:
	return UIStyle.label(text, 9, UIStyle.DIM_TEXT, 2)


func _drawing(min_size: Vector2, on_draw: Callable) -> Control:
	var c := Control.new()
	c.custom_minimum_size = min_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(on_draw.bind(c))
	return c


func _build_order() -> void:
	var m := UIStyle.MARGIN
	var p := _panel(Vector2(0, 0), Vector2(m, m))
	p.custom_minimum_size.x = 158
	var v := _vbox(3)
	v.add_child(_header("ORDEM DE AÇÃO"))
	_queue_box = _vbox(2)
	v.add_child(_queue_box)
	p.add_child(v)


func _build_objective() -> void:
	var m := UIStyle.MARGIN
	var column := _vbox(0)
	_root.add_child(column)
	_anchor(column, Vector2(0.5, 0), Vector2(0, m))

	var p := PanelContainer.new()
	var style := UIStyle.panel()
	style.border_color = UIStyle.GOLD.darkened(0.45)
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			toggle_controls())
	var h := _hbox(8)
	h.add_child(UIStyle.label("OBJETIVO", 9, UIStyle.GOLD, 2))
	_objective = UIStyle.label("", 12)
	h.add_child(_objective)
	_controls_hint = UIStyle.label("", 9, UIStyle.DIM_TEXT, 2)
	h.add_child(_controls_hint)
	for child in h.get_children():
		child.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(h)
	column.add_child(p)

	# gaveta de controles, presa embaixo do objetivo
	var drawer := PanelContainer.new()
	var eg := UIStyle.panel(Color(UIStyle.BACKGROUND, 0.78))
	eg.set_corner_radius_all(0)
	eg.corner_radius_bottom_left = 4
	eg.corner_radius_bottom_right = 4
	eg.border_width_top = 0
	eg.content_margin_top = 4
	eg.content_margin_bottom = 4
	drawer.add_theme_stylebox_override("panel", eg)
	drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	drawer.add_child(_drawing(Vector2(0, 14), _draw_controls))
	column.add_child(drawer)
	_controls = drawer


## Linha de controles: [tecla] descrição · [tecla] descrição ...
const CONTROLS := [
	[["Q", "W", "E", "R"], "usar"],
	[["←", "→"], "alvo"],
	[["mouse"], "prévia do golpe"],
	[["H"], "ocultar"],
]


func _draw_controls(c: Control) -> void:
	var f := UIStyle.font()
	var x := 0.0
	for item: Array in CONTROLS:
		for t: String in item[0]:
			UIStyle.key(c, Vector2(x + 1, 1), t)
			x += maxf(13.0, 7.0 * t.length() + 6.0) + 4
		UIStyle.text(c, Vector2(x, 11), item[1], 10, Color(0.82, 0.8, 0.88))
		x += f.get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 14
	if not is_equal_approx(c.custom_minimum_size.x, x - 14):
		c.custom_minimum_size.x = x - 14


func _build_log() -> void:
	var m := UIStyle.MARGIN
	var p := _panel(Vector2(1, 0), Vector2(-m, m))
	p.add_theme_stylebox_override("panel", UIStyle.panel(Color(UIStyle.BACKGROUND, 0.72)))
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.fit_content = true
	_log.scroll_active = false
	_log.custom_minimum_size = Vector2(232, 0)
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_font_size_override("normal_font_size", 11)
	_log.add_theme_constant_override("outline_size", 3)
	_log.add_theme_color_override("font_outline_color", Color.BLACK)
	_log.add_theme_constant_override("line_separation", 1)
	p.add_child(_log)


func _build_character() -> void:
	var m := UIStyle.MARGIN
	var p := _panel(Vector2(0, 1), Vector2(m, -m))
	p.custom_minimum_size.x = 300
	_character_panel = p
	var h := _hbox(8)
	_panel_portrait = _drawing(Vector2(54, 54), _draw_portrait)
	_panel_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(_panel_portrait)

	var v := _vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := _hbox(6)
	_name = UIStyle.label("", 15, UIStyle.ALLY.lightened(0.35), 4)
	_form = UIStyle.label("", 10, UIStyle.DIM_TEXT, 3)
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_form.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_name)
	_level = UIStyle.label("", 10, UIStyle.GOLD, 3)
	_level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_level)
	_type = _hbox(0)
	_type.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_type)
	top.add_child(_form)
	v.add_child(top)

	var hp_row := _resource_row("HP", UIStyle.HP)
	_hp_bar = hp_row[1]
	_hp_bar.low_color = UIStyle.LOW_HP
	_hp_text = hp_row[2]
	# o escudo aparece junto do HP, na cor do contorno da barra
	_shield_text = UIStyle.label("", 10, UIStyle.SHIELD.lightened(0.25), 3)
	_shield_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_row[0].add_child(_shield_text)
	hp_row[0].move_child(_shield_text, 2)
	v.add_child(hp_row[0])
	var en_row := _resource_row("EN", UIStyle.ENERGY)
	_energy_row = en_row[0]
	_energy_bar = en_row[1]
	_energy_bar.marks = 6
	_energy_text = en_row[2]
	v.add_child(_energy_row)
	var kit_row := _resource_row("", UIStyle.ENERGY)
	_kit_row = kit_row[0]
	_kit_label = _kit_row.get_child(0)
	_kit_bar = kit_row[1]
	_kit_text = kit_row[2]
	v.add_child(_kit_row)

	var base := _hbox(6)
	_points_drawing = _drawing(Vector2(0, 12), _draw_points)
	base.add_child(_points_drawing)
	_chips = _hbox(3)
	_chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chips.alignment = BoxContainer.ALIGNMENT_END
	base.add_child(_chips)
	v.add_child(base)
	h.add_child(v)
	p.add_child(h)


## [linha, barra, texto do valor]
func _resource_row(label: String, color: Color) -> Array:
	var line := _hbox(5)
	var l := UIStyle.label(label, 9, color, 2)
	l.custom_minimum_size.x = 16
	var bar := PixelBar.new()
	bar.color = color
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value := UIStyle.label("", 11)
	value.custom_minimum_size.x = 64
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(l)
	line.add_child(bar)
	line.add_child(value)
	return [line, bar, value]


func _draw_portrait(c: Control) -> void:
	var r := Rect2(Vector2(3, 3), c.size - Vector2(6, 6))
	var color := UIStyle.side_color(_active.ally) if _active else UIStyle.BORDER
	c.draw_rect(r.grow(3), Color.BLACK)
	c.draw_rect(r.grow(2), color.darkened(0.3))
	c.draw_rect(r.grow(1), Color.BLACK)
	c.draw_rect(r, color.darkened(0.78))
	# luz de fundo atrás do rosto
	c.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.55), Vector2(r.size.x, r.size.y * 0.45)), color.darkened(0.6))
	var tex: Texture2D = _portraits.get(_active) if _active else null
	if tex:
		var side := floorf(r.size.x / tex.get_width()) * tex.get_width()
		var tex_size := Vector2(side, side * tex.get_height() / tex.get_width())
		c.draw_texture_rect(tex, Rect2(r.get_center() - tex_size / 2, tex_size), false)
	# o efeito mais forte tinge a moldura
	if _active:
		for e in _active.effects():
			if e.has("color"):
				c.draw_rect(r.grow(2), e.color, false, 1.0)
				break


func _draw_points(c: Control) -> void:
	if _max_points <= 0:
		c.custom_minimum_size.x = 0
		return
	UIStyle.text(c, Vector2(0, 10), "PONTOS", 9, UIStyle.DIM_TEXT)
	var x0 := 44.0
	for i in _max_points:
		UIStyle.diamond(c, Vector2(x0 + i * 13, 6), 4.5, i < _points)
	c.custom_minimum_size.x = x0 + _max_points * 13


func _build_team() -> void:
	_team_panel = _panel(Vector2(0, 1), Vector2(0, -UIStyle.MARGIN))
	_team_panel.add_theme_stylebox_override("panel", UIStyle.panel(Color(UIStyle.BACKGROUND, 0.8)))
	var v := _vbox(3)
	v.add_child(_header("EQUIPE"))
	_team_box = _hbox(4)
	v.add_child(_team_box)
	_team_panel.add_child(v)
	_team_panel.visible = false


## Cartão compacto de um aliado fora da vez: retrato, nome, HP e energia.
func _draw_card(c: Control) -> void:
	var a: Combatant = c.get_meta("combatant")
	var is_alive := a.is_alive()
	var color := UIStyle.side_color(true)
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(r, Color(0, 0, 0, 0.4))
	c.draw_rect(Rect2(0, 0, 2, r.size.y), color if is_alive else Color(0.3, 0.3, 0.35))
	var pr := Rect2(5, 4, 24, 24)
	c.draw_rect(pr.grow(1), Color.BLACK)
	c.draw_rect(pr, color.darkened(0.75))
	var tex: Texture2D = _portraits.get(a)
	if tex:
		c.draw_texture_rect(tex, Rect2(pr.position + Vector2(4, 4), Vector2(16, 16)), false,
			Color.WHITE if is_alive else Color(0.35, 0.35, 0.4))
	var x := pr.end.x + 4
	var w := r.size.x - x - 4
	var badge := UIStyle.type_badge_width(a.type, 8, true)
	UIStyle.text(c, Vector2(x, 12), a.name, 10, UIStyle.TEXT if is_alive else UIStyle.DIM_TEXT, w - badge - 3)
	UIStyle.type_badge(c, Vector2(r.size.x - 4 - badge, 3), a.type, 8, true)
	if not is_alive:
		UIStyle.text(c, Vector2(x, 26), "caiu", 9, UIStyle.DAMAGE_TAKEN, w)
		return
	var frac_hp := float(a.hp) / a.max_hp
	c.draw_rect(Rect2(x, 16, w, 5), Color.BLACK)
	c.draw_rect(Rect2(x, 16, roundf(w * frac_hp), 5), UIStyle.HP if frac_hp >= 0.3 else UIStyle.LOW_HP)
	if a.shield() > 0:
		UIStyle.shield_outline(c, Rect2(x, 16, w, 5), float(a.shield()) / a.max_hp)
	if a.max_energy > 0:
		c.draw_rect(Rect2(x, 23, w, 3), Color.BLACK)
		c.draw_rect(Rect2(x, 23, roundf(w * a.energy / a.max_energy), 3), UIStyle.ENERGY)
	# efeitos ativos em pontinhos
	var px := x
	for e in a.effects():
		c.draw_rect(Rect2(px, 28, 5, 3), UIStyle.effect_color(e))
		px += 7


func _refresh_team(team: Array[Combatant]) -> void:
	var others := team.filter(func(c: Combatant) -> bool: return c != _active)
	_team_panel.visible = not others.is_empty()
	if others.is_empty():
		return
	while _cards.size() < others.size():
		var card := _drawing(Vector2(104, 32), _draw_card)
		_team_box.add_child(card)
		_cards.append(card)
	for i in _cards.size():
		_cards[i].visible = i < others.size()
		if _cards[i].visible:
			_cards[i].set_meta("combatant", others[i])
			_cards[i].queue_redraw()
	# encosta no painel do personagem da vez, que pode mudar de largura
	var x := UIStyle.MARGIN + _character_panel.get_combined_minimum_size().x + 6
	_team_panel.offset_left = x
	_team_panel.offset_right = x


func _build_skills() -> void:
	var m := UIStyle.MARGIN
	var p := _panel(Vector2(1, 1), Vector2(-m, -m))
	_bar_panel = p
	var v := _vbox(6)
	_bar_title = _header("")
	v.add_child(_bar_title)
	_slot_box = _hbox(10)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_child(_slot_box)
	v.add_child(margin)
	p.add_child(v)

	# explicação da habilidade em foco, acima da barra; a posição y acompanha
	# a altura da barra
	_hint = _panel(Vector2(1, 1), Vector2(-m, -m))
	# quase opaco: fica por cima da arena e do registro
	var style := UIStyle.panel(Color(UIStyle.LIGHT_BACKGROUND, 0.98), UIStyle.GOLD.darkened(0.35))
	style.set_content_margin_all(8)
	_hint.add_theme_stylebox_override("panel", style)
	_hint_card = SkillCard.new()
	_hint_card.custom_minimum_size.x = HINT_WIDTH
	_hint.add_child(_hint_card)
	_hint.visible = false


func _build_options() -> void:
	_options = _panel(Vector2(1, 1), Vector2.ZERO)
	_options.add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.LIGHT_BACKGROUND, UIStyle.GOLD.darkened(0.35)))
	_options.custom_minimum_size.x = 300
	_options.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := _vbox(4)
	_options_title = UIStyle.label("", 11, UIStyle.GOLD, 3)
	v.add_child(_options_title)
	_option_list = _vbox(1)
	v.add_child(_option_list)
	_option_reason = UIStyle.label("", 10, UIStyle.DAMAGE_TAKEN, 3)
	_option_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_option_reason.custom_minimum_size.x = 288
	v.add_child(_option_reason)
	v.add_child(UIStyle.label("↑↓ ou 1-9 escolher · ←→ alvo · Enter confirmar · Esc cancelar", 9, UIStyle.DIM_TEXT, 2))
	_options.add_child(v)
	_options.visible = false


## Abre (ou atualiza) o seletor da habilidade `h` com a opção `index` em
## foco. `reasons[i]` != "" desabilita a opção i no alvo atual (`target_name`).
func show_options(h: Dictionary, index: int, reasons: Array[String], target_name: String) -> void:
	_options_title.text = h.name.to_upper() + ("  ·  alvo: %s" % target_name if target_name != "" else "")
	for child in _option_list.get_children():
		child.queue_free()
	var options: Array = h.options
	for i in options.size():
		_option_list.add_child(_option_row(options[i], i, i == index, reasons[i] == ""))
	_option_reason.text = reasons[index]
	_option_reason.visible = reasons[index] != ""
	_hint.visible = false
	_options.visible = true
	# fica logo acima da barra de habilidades
	var y := -UIStyle.MARGIN - _bar_panel.get_combined_minimum_size().y - 6
	_options.offset_top = y
	_options.offset_bottom = y
	_options.offset_left = -UIStyle.MARGIN
	_options.offset_right = -UIStyle.MARGIN


func close_options() -> void:
	_options.visible = false


func _option_row(o: Dictionary, i: int, focused: bool, valid: bool) -> Control:
	var color: Color = o.get("color", UIStyle.TEXT)
	var p := PanelContainer.new()
	var style := UIStyle.panel(color.darkened(0.7) if focused else Color(0, 0, 0, 0.25),
		UIStyle.GOLD if focused else Color(0, 0, 0, 0), 1)
	style.shadow_size = 0
	style.set_content_margin_all(2)
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			option_clicked.emit(i))
	var h := _hbox(6)
	h.add_child(UIStyle.label(str(i + 1) if i < 9 else "", 10, UIStyle.DIM_TEXT, 2))
	# a textura é carregada fora do desenho: dentro dele seria liberada
	# antes de a tela ser renderizada (e sairia branca)
	var icon: Texture2D = load(o.icon) if o.get("icon", "") != "" else null
	# só a opção em foco tem ícone grande e descrição, para o painel caber
	var side := 12.0
	if icon:
		side = 30.0 if focused else 15.0
	var mark := _drawing(Vector2(side, side), func(c: Control) -> void:
		var mod := Color.WHITE if valid else Color(0.4, 0.4, 0.45)
		if icon:
			c.draw_texture_rect(icon, Rect2(Vector2.ZERO, Vector2(side, side)), false, mod)
		else:
			c.draw_rect(Rect2(1, 1, 10, 10), Color.BLACK)
			c.draw_rect(Rect2(2, 2, 8, 8), color * mod))
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(mark)
	var texts := _vbox(0)
	var name_color := color.lightened(0.35) if valid else UIStyle.DIM_TEXT
	texts.add_child(UIStyle.label(o.name + ("  (atual)" if o.get("current", false) else ""), 11, name_color, 3))
	if focused:
		var d := UIStyle.label(o.get("description", ""), 9, UIStyle.TEXT if valid else UIStyle.DIM_TEXT, 2)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 230
		texts.add_child(d)
	h.add_child(texts)
	p.add_child(h)
	return p


## Recusa de uma ação (alvo inválido, opção indisponível): mostra o motivo.
func warn(text: String) -> void:
	log_line(UIStyle.highlight(text, UIStyle.DAMAGE_TAKEN))
	if _options.visible:
		_option_reason.text = text
		_option_reason.visible = true
		_option_reason.modulate = Color(2, 2, 2)
		create_tween().tween_property(_option_reason, "modulate", Color.WHITE, 0.3)


func _build_announcement() -> void:
	_announcement = UIStyle.label("", 40, UIStyle.GOLD, 10)
	_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announcement.custom_minimum_size = Vector2(600, 56)
	_root.add_child(_announcement)
	_anchor(_announcement, Vector2(0.5, 0.3), Vector2.ZERO)
	_announcement.modulate.a = 0


func _build_end() -> void:
	_end = ColorRect.new()
	(_end as ColorRect).color = Color(0, 0, 0, 0.62)
	_end.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end.visible = false
	_root.add_child(_end)
	var p := PanelContainer.new()
	var style := UIStyle.panel(UIStyle.LIGHT_BACKGROUND, UIStyle.GOLD.darkened(0.2), 2)
	style.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end.add_child(p)
	_anchor(p, Vector2(0.5, 0.45), Vector2.ZERO)
	var v := _vbox(10)
	_end_text = UIStyle.label("", 30, Color.WHITE, 8)
	_end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_end_text)
	_end_rewards = _vbox(6)
	v.add_child(_end_rewards)
	_end_extras = _vbox(2)
	v.add_child(_end_extras)
	var hint := UIStyle.label("Enter ou clique: voltar ao saguão", 13, UIStyle.DIM_TEXT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var back := Button.new()
	back.text = "Voltar ao saguão"
	back.focus_mode = Control.FOCUS_NONE
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_size_override("font_size", 12)
	back.add_theme_color_override("font_color", UIStyle.GOLD)
	back.add_theme_stylebox_override("normal", UIStyle.panel(UIStyle.BACKGROUND, UIStyle.GOLD.darkened(0.25)))
	back.add_theme_stylebox_override("hover", UIStyle.panel(UIStyle.LIGHT_BACKGROUND, UIStyle.GOLD))
	back.add_theme_stylebox_override("pressed", UIStyle.panel(UIStyle.LIGHT_BACKGROUND, UIStyle.GOLD))
	back.pressed.connect(func() -> void: lobby_requested.emit())
	v.add_child(back)
	p.add_child(v)
	_end.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			lobby_requested.emit())


# --------------------------------------------------------------- atualização
func set_portraits(portraits: Dictionary) -> void:
	_portraits = portraits


func set_objective(text: String) -> void:
	_objective.text = text


## `active`: aliado mostrado no painel e na barra (o da vez, ou o último que agiu).
func refresh(active: Combatant, team: Array[Combatant], points: int, points_max: int,
		queue: Array[Combatant], current_actor: Combatant, players_turn: bool) -> void:
	_active = active
	_points = points
	_max_points = points_max
	_players_turn = players_turn
	_refresh_character()
	_refresh_team(team)
	_refresh_skills(current_actor)
	_refresh_queue(queue)


func _refresh_character() -> void:
	_name.text = _active.name
	_name.label_settings.font_color = UIStyle.side_color(_active.ally).lightened(0.35)
	_level.text = "Nv %d" % _active.character_level
	if _type.get_meta("type", "") != _active.type:
		_type.set_meta("type", _active.type)
		for child in _type.get_children():
			child.queue_free()
		_type.add_child(UIStyle.type_tag(_active.type))
	_hp_bar.set_values(_active.hp, _active.max_hp)
	_hp_bar.shield = _active.shield()
	_hp_text.text = "%d/%d" % [_active.hp, _active.max_hp]
	_shield_text.visible = _active.shield() > 0
	_shield_text.text = "+%d" % _active.shield()
	_energy_row.visible = _active.max_energy > 0
	_energy_bar.set_values(_active.energy, _active.max_energy)
	_energy_text.text = "%d/%d" % [_active.energy, _active.max_energy]
	var kit := _active.kit_bar()
	_kit_row.visible = not kit.is_empty()
	if not kit.is_empty():
		_kit_label.text = kit.label
		_kit_label.label_settings.font_color = kit.color
		_kit_bar.color = kit.color
		_kit_bar.marks = kit.get("marks", 0)
		_kit_bar.set_values(kit.value, kit.max)
		_kit_text.text = "%d/%d" % [kit.value, kit.max]
	_panel_portrait.queue_redraw()
	_points_drawing.queue_redraw()

	var effects := _active.effects()
	# a forma/buff principal (o que tem cor própria) vira o subtítulo
	_form.text = ""
	for e in effects:
		if e.has("detail") and e.has("color"):
			_form.text = e.detail
			_form.label_settings.font_color = e.color.lightened(0.3)
			break
	for child in _chips.get_children():
		child.queue_free()
	for e in effects:
		_chips.add_child(_chip(e))


func _chip(e: Dictionary) -> Control:
	var color := UIStyle.effect_color(e)
	var p := PanelContainer.new()
	var s := UIStyle.panel(color.darkened(0.6), color, 1)
	s.shadow_size = 0
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.tooltip_text = e.name + ("\n" + e.detail if e.has("detail") else "")
	var text: String = e.name
	if e.get("turns", -1) > 0:
		text += " · %d" % e.turns
	p.add_child(UIStyle.label(text, 9, color.lightened(0.45), 2))
	return p


func _refresh_skills(current_actor: Combatant) -> void:
	# passivas entram também: a barra explica o kit inteiro, no mesmo padrão
	var list := _active.skills(_points)
	var ids: Array[String] = []
	for h in list:
		ids.append(h.action)
	if ids != _ids_slots:
		_rebuild_slots(ids)
	for h in list:
		(_slots[h.action] as SkillSlot).display(h, _players_turn)
	if _players_turn:
		_bar_title.text = "SUA VEZ · %s" % _active.name.to_upper()
		_bar_title.label_settings.font_color = UIStyle.GOLD
	elif current_actor == _active:
		_bar_title.text = "%s EM AÇÃO" % _active.name.to_upper()
		_bar_title.label_settings.font_color = UIStyle.DIM_TEXT
	else:
		_bar_title.text = "VEZ DE %s" % current_actor.name.to_upper() if current_actor else "PREPARANDO..."
		_bar_title.label_settings.font_color = UIStyle.DIM_TEXT
	_show_hint()


func _rebuild_slots(ids: Array[String]) -> void:
	for s in _slots.values():
		s.queue_free()
	_slots.clear()
	for id in ids:
		var s := SkillSlot.new()
		s.requested.connect(func(action: String) -> void: action_requested.emit(action))
		s.focus.connect(_on_focus)
		_slot_box.add_child(s)
		_slots[id] = s
	_ids_slots = ids


func _on_focus(action: String) -> void:
	_focus = action
	_show_hint()
	skill_focused.emit(action)


func _show_hint() -> void:
	var slot: SkillSlot = _slots.get(_focus)
	_hint.visible = slot != null and not _options.visible
	if not slot:
		return
	# logo acima da barra, como o seletor de opções: ao lado dela ficam os
	# painéis do personagem e da equipe
	var y := -UIStyle.MARGIN - _bar_panel.get_combined_minimum_size().y - 6
	_hint.offset_top = y
	_hint.offset_bottom = y
	var h := slot.data
	_hint_card.display(h, _unavailable_reason(h))


func _unavailable_reason(h: Dictionary) -> String:
	if h.get("passive", false):
		return ""
	if h.get("missing_reason", "") != "" and h.get("state") != "ready":
		return h.missing_reason
	match h.get("state"):
		"no_resource":
			if h.get("point_cost", 0) > _points:
				return "Sem pontos de skill. Use o Corte para gerar."
			if h.get("energy_cost", 0) > _active.energy:
				return "Energia insuficiente: %d/%d" % [_active.energy, h.energy_cost]
			return "Recursos insuficientes."
		"blocked":
			return "Indisponível agora."
	return ""


func _refresh_queue(queue: Array[Combatant]) -> void:
	while _queue_items.size() < queue.size():
		var item := TurnQueueItem.new()
		_queue_box.add_child(item)
		_queue_items.append(item)
	for i in _queue_items.size():
		var item := _queue_items[i]
		item.visible = i < queue.size()
		if item.visible:
			var c := queue[i]
			item.display(c, _portraits.get(c), i, i == 0)


## Clarão no slot da habilidade usada (para teclado e clique darem o mesmo retorno).
func trigger(action: String) -> void:
	if _slots.has(action):
		(_slots[action] as SkillSlot).trigger()


func log_line(text: String) -> void:
	_log_lines.append(text)
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	# as mais antigas vão apagando
	var parts: Array[String] = []
	for i in _log_lines.size():
		var age := _log_lines.size() - 1 - i
		var a := 1.0 if age == 0 else lerpf(0.75, 0.4, float(age - 1) / maxf(1, MAX_LOG_LINES - 2))
		parts.append("[color=#%s]%s[/color]" % [Color(UIStyle.TEXT, a).to_html(), _log_lines[i]])
	_log.text = "\n".join(parts)


func announce(text: String, color := UIStyle.GOLD, font_size := 40) -> void:
	_announcement.text = text
	_announcement.label_settings.font_color = color
	_announcement.label_settings.font_size = font_size
	_announcement.pivot_offset = _announcement.size / 2
	_announcement.modulate.a = 1
	_announcement.scale = Vector2(1.4, 1.4)
	var t := create_tween()
	t.tween_property(_announcement, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK)
	t.tween_interval(0.75)
	t.tween_property(_announcement, "modulate:a", 0.0, 0.25)


## `rewards`: resultados de Progression.grant_xp(), um por personagem.
## `extras`: linhas de destaque (andar liberado, quem chegou à Torre).
func show_end(victory: bool, text: String, rewards: Array[Dictionary] = [], extras: Array[String] = []) -> void:
	_end_text.text = text
	_end_text.label_settings.font_color = Color(0.6, 1, 0.7) if victory else Color(1, 0.45, 0.45)
	for child in _end_rewards.get_children():
		child.queue_free()
	for r in rewards:
		_end_rewards.add_child(_reward_row(r))
	_end_rewards.visible = not rewards.is_empty()
	for child in _end_extras.get_children():
		child.queue_free()
	for line in extras:
		var l := UIStyle.label("✦ " + line, 12, UIStyle.GOLD, 3)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_end_extras.add_child(l)
	_end_extras.visible = not extras.is_empty()
	_end.visible = true
	_hint.visible = false
	_options.visible = false


## Retrato, nome, XP ganha, nível (com destaque se subiu), barra de XP, o que
## falta para o próximo e os atributos ganhos.
func _reward_row(r: Dictionary) -> Control:
	var leveled_up: bool = r.level > r.level_before
	var line := _hbox(8)
	var portrait := TextureRect.new()
	portrait.texture = Roster.portrait(r.id)
	portrait.custom_minimum_size = Vector2(32, 32)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	line.add_child(portrait)
	var v := _vbox(2)
	v.custom_minimum_size.x = 280
	var top := _hbox(8)
	var name_label := UIStyle.label(Roster.data(r.id).name, 13, UIStyle.ALLY.lightened(0.35), 3)
	top.add_child(name_label)
	# quem ficou fora da luta também ganha (ver Progression.reward_victory)
	var reserve := UIStyle.label("" if r.get("took_part", true) else "reserva", 9, UIStyle.DIM_TEXT, 2)
	reserve.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reserve.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(reserve)
	top.add_child(UIStyle.label("+%d XP" % r.xp_gained, 11, UIStyle.XP, 3))
	var level := UIStyle.label("Nv %d → %d" % [r.level_before, r.level] if leveled_up else "Nv %d" % r.level, 11,
		UIStyle.GOLD if leveled_up else UIStyle.TEXT, 3)
	top.add_child(level)
	v.add_child(top)
	var bar := PixelBar.new()
	bar.color = UIStyle.GOLD.darkened(0.2) if r.at_limit else UIStyle.XP
	bar.marks = 0
	bar.custom_minimum_size = Vector2(0, 6)
	var maximum: int = r.next_xp
	var full: bool = maximum == 0 or r.at_limit
	bar.set_values(1.0 if full else 0.0, 1 if full else maximum, false)
	v.add_child(bar)
	if not full:
		# enche depois que o painel aparece
		bar.ready.connect(func() -> void: bar.set_values(r.current_xp, maximum))
	v.add_child(UIStyle.label(xp_text(r.level, r.current_xp, r.at_limit), 9,
		UIStyle.GOLD if r.at_limit else UIStyle.DIM_TEXT, 2))
	if leveled_up:
		var parts: Array[String] = []
		for a: String in r.gains:
			parts.append("%s +%d" % [Progression.STAT_NAMES[a], r.gains[a]])
		var notice := UIStyle.label("SUBIU DE NÍVEL!   " + "  ·  ".join(parts), 10, UIStyle.GOLD, 3)
		v.add_child(notice)
		notice.ready.connect(func() -> void:
			var t := notice.create_tween().set_loops()
			t.tween_property(notice, "modulate", Color(1.4, 1.3, 1.0), 0.45)
			t.tween_property(notice, "modulate", Color.WHITE, 0.45))
	line.add_child(v)
	return line


## Linha de XP de um personagem: quanto falta, ou o limite/máximo atingido.
static func xp_text(level: int, xp: int, at_limit: bool) -> String:
	if level >= Progression.MAX_LEVEL:
		return "Nível máximo"
	if at_limit:
		return "Limite da Torre (Nv %d) · vença um andar novo para subir mais" % level
	var maximum := Progression.xp_to_next(level)
	return "%d/%d XP · faltam %d para o nível %d" % [xp, maximum, maximum - xp, level + 1]


# ------------------------------------------------------- controles (H)
func toggle_controls() -> void:
	_set_controls(not _controls_open)
	var cfg := ConfigFile.new()
	cfg.load(PREFS_FILE)
	cfg.set_value("hud", "controles_abertos", _controls_open)
	cfg.save(PREFS_FILE)


func _set_controls(open: bool) -> void:
	_controls_open = open
	_controls.visible = open
	_controls_hint.text = "" if open else "[H] controles"
	_controls_hint.visible = not open


func _load_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PREFS_FILE)
	_set_controls(cfg.get_value("hud", "controles_abertos", true))


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		toggle_controls()
		get_viewport().set_input_as_handled()

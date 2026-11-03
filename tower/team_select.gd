class_name TeamSelect
extends Control
## Seletor de equipe antes do combate: até o limite da missão escolhida
## (Floors.max_team; as vagas acima dele aparecem trancadas).
## A ordem de escolha é a ordem na arena (o 1º fica na frente).
## Lê tudo do Roster e das descrições dos personagens (skills(), status),
## então personagens novos aparecem aqui sem mexer nesta tela.
## Controles: ←/→ escolhe, Espaço adiciona/remove, Enter começa, Esc volta ao mapa da Torre.

const BATTLE_SCENE := "res://combat/battle.tscn"
const FLOORS_SCENE := "res://tower/floor_select.tscn"
const ROSTER_CARDS := 6  ## completa com "em breve" até este número
## Referência para as barrinhas de atributo (valor que enche a barra).
const REF_STATUS := {"hp": 2000.0, "atk": 200.0, "def": 120.0, "spd": 150.0}

var team: Array[String] = []
var _cursor := 0
var _ids: Array[String] = []  ## os personagens liberados (Roster.available())
var _floor_number := 1
var _mission_id := ""  ## missão do andar ("" = a principal)
var _max := Roster.MAX_TEAM  ## vagas abertas nesta missão

var _summon_slots: Array[Control] = []
var _cards: Array[Control] = []
var _detail: VBoxContainer
var _button: Button
var _counter: Label
var _synergy: Label  ## bônus de equipe (Synergies): quanto falta ou que fechou
var _time := 0.0
var _samples := {}  ## id -> Combatant (para ler status e kit)
var _frames := {}  ## id -> SpriteFrames
var _icons := {}  ## caminho -> Texture2D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_ids = Roster.available()
	_floor_number = Floors.current()
	_mission_id = Floors.current_mission()
	_max = Floors.max_team(_floor_number, _mission_id)
	for id in _ids:
		_samples[id] = Roster.create(id)
		var sp: Dictionary = Roster.data(id).sprite
		_frames[id] = FighterVisual.load_frames(sp.png, sp.json)
	team = Roster.team().slice(0, _max)
	_build()
	_refresh()


# ------------------------------------------------------------------ montagem
func _build() -> void:
	var background := TextureRect.new()
	background.texture = load("res://tower/floor_background.png")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var veil := ColorRect.new()
	veil.color = Color(0.03, 0.02, 0.06, 0.62)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	# título
	var top := HBoxContainer.new()
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.add_child(UIStyle.heading("ANDAR %d • %s" % [_floor_number, Floors.mission(_floor_number, _mission_id).name.to_upper()], 8, UIStyle.DIM_TEXT, 3))
	titles.add_child(UIStyle.heading("MONTE SUA EQUIPE", 24, UIStyle.GOLD, 5))
	var rule := "Só 1 personagem nesta missão." if _max == 1 else "Até %d personagens nesta missão. O 1º escolhido fica na frente da arena." % _max
	titles.add_child(UIStyle.label(rule, 11, UIStyle.DIM_TEXT))
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(titles)
	_counter = UIStyle.label("", 14, UIStyle.TEXT, 4)
	_counter.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(_counter)
	column.add_child(top)

	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 14)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(middle)

	# esquerda: vagas da equipe + elenco
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	middle.add_child(left)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 10)
	for i in Roster.MAX_TEAM:
		var slot := _control(Vector2(150, 196), _draw_team_slot)
		slot.set_meta("index", i)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_slot_clicked.bind(i))
		slots.add_child(slot)
		_summon_slots.append(slot)
	left.add_child(slots)
	_synergy = UIStyle.label("", 11, UIStyle.DIM_TEXT, 3)
	left.add_child(_synergy)
	left.add_child(UIStyle.heading("PERSONAGENS"))
	var roster := HBoxContainer.new()
	roster.add_theme_constant_override("separation", 8)
	for i in maxi(ROSTER_CARDS, _ids.size()):
		var card := _control(Vector2(70, 88), _draw_card)
		card.set_meta("index", i)
		if i < _ids.size():
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			card.mouse_entered.connect(func() -> void:
				_cursor = i
				_refresh())
			card.gui_input.connect(_card_clicked.bind(i))
		roster.add_child(card)
		_cards.append(card)
	left.add_child(roster)

	# direita: ficha do personagem sob o cursor
	var sheet := PanelContainer.new()
	var ef := UIStyle.panel()
	ef.set_content_margin_all(12)
	sheet.add_theme_stylebox_override("panel", ef)
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 6)
	sheet.add_child(_detail)
	middle.add_child(sheet)

	# rodapé: controles + começar
	var baseboard := HBoxContainer.new()
	var hints := _control(Vector2(0, 16), _draw_hints)
	hints.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hints.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	baseboard.add_child(hints)
	_button = Button.new()
	_button.text = "COMEÇAR COMBATE  >"
	_button.focus_mode = Control.FOCUS_NONE
	_button.custom_minimum_size = Vector2(210, 40)
	UIStyle.button(_button, 16)
	_button.pressed.connect(start)
	baseboard.add_child(_button)
	column.add_child(baseboard)


func _control(min_size: Vector2, on_draw: Callable) -> Control:
	var c := Control.new()
	c.custom_minimum_size = min_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(on_draw.bind(c))
	return c


# ------------------------------------------------------------- desenho
func _draw_team_slot(c: Control) -> void:
	var i: int = c.get_meta("index")
	var r := Rect2(Vector2.ZERO, c.size)
	if i >= _max:
		# vaga fechada nesta missão: um cadeado
		c.draw_rect(r, Color(0, 0, 0, 0.55))
		c.draw_rect(r, Color(1, 1, 1, 0.06), false, 1.0)
		var middle := r.get_center()
		var color := Color(1, 1, 1, 0.18)
		c.draw_rect(Rect2(middle + Vector2(-10, -4), Vector2(20, 16)), color)
		c.draw_rect(Rect2(middle + Vector2(-7, -14), Vector2(3, 10)), color)
		c.draw_rect(Rect2(middle + Vector2(4, -14), Vector2(3, 10)), color)
		c.draw_rect(Rect2(middle + Vector2(-7, -16), Vector2(14, 3)), color)
		UIStyle.text(c, Vector2(0, middle.y + 34), "Fechada nesta missão", 10, Color(1, 1, 1, 0.3), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var id := team[i] if i < team.size() else ""
	if id == "":
		c.draw_rect(r, Color(0, 0, 0, 0.35))
		_dashed(c, r.grow(-1), UIStyle.BORDER)
		var middle := r.get_center()
		c.draw_rect(Rect2(middle + Vector2(-9, -2), Vector2(18, 4)), UIStyle.BORDER)
		c.draw_rect(Rect2(middle + Vector2(-2, -9), Vector2(4, 18)), UIStyle.BORDER)
		UIStyle.text(c, Vector2(0, middle.y + 30), "Vaga livre", 11, UIStyle.DIM_TEXT, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var color := UIStyle.ALLY
		c.draw_rect(r, color.darkened(0.82))
		# chão de luz onde o personagem pisa
		c.draw_rect(Rect2(0, r.size.y * 0.5, r.size.x, r.size.y * 0.5), color.darkened(0.7))
		var foot := Vector2(r.size.x / 2, 144)
		var frames: SpriteFrames = _frames[id]
		var n := frames.get_frame_count("idle")
		var frame := frames.get_frame_texture("idle", int(_time * frames.get_animation_speed("idle")) % n)
		var sp: Dictionary = Roster.data(id).sprite
		var zoom := 3.0
		c.draw_set_transform(foot - sp.foot * zoom, 0, Vector2(zoom, zoom))
		c.draw_texture(frame, Vector2.ZERO)
		c.draw_set_transform(Vector2.ZERO)
		c.draw_rect(Rect2(foot.x - 26, foot.y, 52, 3), Color(0, 0, 0, 0.35))
		UIStyle.text(c, Vector2(0, 162), Roster.data(id).name, 14, UIStyle.TEXT, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		UIStyle.text(c, Vector2(0, 175), Roster.data(id).origin, 9, UIStyle.DIM_TEXT, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		var type: String = _samples[id].type
		UIStyle.type_badge(c, Vector2(roundf((r.size.x - UIStyle.type_badge_width(type)) / 2), 180), type)
		c.draw_rect(r, color.darkened(0.2), false, 1.0)
	# número da posição
	var badge := Rect2(6, 6, 18, 18)
	c.draw_rect(badge.grow(1), Color.BLACK)
	c.draw_rect(badge, UIStyle.GOLD if id != "" else UIStyle.LIGHT_BACKGROUND)
	c.draw_string(UIStyle.font(), badge.position + Vector2(0, 14), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 18, 13,
		Color.BLACK if id != "" else UIStyle.DIM_TEXT)
	if id != "" and i == 0:
		UIStyle.text(c, Vector2(28, 19), "FRENTE", 9, UIStyle.GOLD)
	if id != "":
		UIStyle.text(c, Vector2(0, 19), "Nv %d" % _samples[id].character_level, 11, UIStyle.GOLD, c.size.x - 7, HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_card(c: Control) -> void:
	var i: int = c.get_meta("index")
	var r := Rect2(Vector2(0, 4), c.size - Vector2(0, 4))
	if i >= _ids.size():
		c.draw_rect(r, Color(0, 0, 0, 0.45))
		c.draw_rect(r, Color(1, 1, 1, 0.06), false, 1.0)
		UIStyle.text(c, Vector2(0, r.position.y + 44), "?", 26, Color(1, 1, 1, 0.15), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		UIStyle.text(c, Vector2(0, r.end.y - 8), "em breve", 9, Color(1, 1, 1, 0.25), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var id := _ids[i]
	var spot := team.find(id)
	var at_cursor := i == _cursor
	var rises := -3.0 if at_cursor else 0.0
	r.position.y += rises
	c.draw_rect(r.grow(1), Color.BLACK)
	c.draw_rect(r, UIStyle.LIGHT_BACKGROUND if at_cursor else UIStyle.BACKGROUND)
	var pr := Rect2(r.position + Vector2((r.size.x - 48) / 2, 8), Vector2(48, 48))
	c.draw_rect(pr, UIStyle.ALLY.darkened(0.75))
	c.draw_texture_rect(Roster.portrait(id), pr, false)
	UIStyle.text(c, r.position + Vector2(4, 14), str(_samples[id].character_level), 10, UIStyle.GOLD)
	UIStyle.text(c, Vector2(0, r.end.y - 9), Roster.data(id).name, 11,
		UIStyle.GOLD if at_cursor else UIStyle.TEXT, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var border := UIStyle.GOLD if at_cursor else (UIStyle.ALLY if spot >= 0 else UIStyle.BORDER)
	if at_cursor:
		border = Color(border, 0.7 + 0.3 * sin(_time * 5.0))
	c.draw_rect(r, border, false, 2.0 if at_cursor or spot >= 0 else 1.0)
	if spot >= 0:
		var badge := Rect2(r.end.x - 16, r.position.y - 4, 18, 16)
		c.draw_rect(badge.grow(1), Color.BLACK)
		c.draw_rect(badge, UIStyle.ALLY)
		c.draw_string(UIStyle.font(), badge.position + Vector2(0, 12), str(spot + 1), HORIZONTAL_ALIGNMENT_CENTER, 18, 11, Color.WHITE)


func _draw_hints(c: Control) -> void:
	var x := 0.0
	for item in [[["←", "→"], "escolher"], [["Espaço"], "adicionar / remover"], [["Enter"], "começar"], [["Esc"], "mapa"]]:
		for t: String in item[0]:
			UIStyle.key(c, Vector2(x + 1, 1), t)
			x += maxf(13.0, 7.0 * t.length() + 6.0) + 4
		UIStyle.text(c, Vector2(x, 11), item[1], 10, Color(0.82, 0.8, 0.88))
		x += UIStyle.font().get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 16


func _dashed(c: Control, r: Rect2, color: Color) -> void:
	var step := 8.0
	var x := r.position.x
	while x < r.end.x:
		var w := minf(4, r.end.x - x)
		c.draw_rect(Rect2(x, r.position.y, w, 1), color)
		c.draw_rect(Rect2(x, r.end.y - 1, w, 1), color)
		x += step
	var y := r.position.y
	while y < r.end.y:
		var h := minf(4, r.end.y - y)
		c.draw_rect(Rect2(r.position.x, y, 1, h), color)
		c.draw_rect(Rect2(r.end.x - 1, y, 1, h), color)
		y += step


# ---------------------------------------------------------- ficha (detalhe)
func _build_sheet() -> void:
	for child in _detail.get_children():
		child.queue_free()
	var id := _ids[_cursor]
	var data := Roster.data(id)
	var p: Combatant = _samples[id]

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var portrait := TextureRect.new()
	portrait.texture = Roster.portrait(id)
	portrait.custom_minimum_size = Vector2(48, 48)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top.add_child(portrait)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.add_child(UIStyle.heading(data.name, 16, UIStyle.ALLY.lightened(0.35), 5))
	var origin_line := HBoxContainer.new()
	origin_line.add_theme_constant_override("separation", 6)
	origin_line.add_child(UIStyle.label(data.origin, 11, UIStyle.DIM_TEXT))
	origin_line.add_child(UIStyle.type_tag(p.type))
	names.add_child(origin_line)
	names.add_child(UIStyle.label("de " + data.universe, 10, UIStyle.GOLD.darkened(0.15), 2))
	top.add_child(names)
	_detail.add_child(top)
	_detail.add_child(_level_row(id))

	# atributos
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 3)
	var growth: Dictionary = data.get("growth", {})
	var lines := [
		["HP", p.max_hp, REF_STATUS.hp, UIStyle.HP, growth.get("hp", 0.0)],
		["ATQ", p.base_atk, REF_STATUS.atk, UIStyle.DAMAGE_TAKEN, growth.get("atk", 0.0)],
		["DEF", p.base_def, REF_STATUS.def, UIStyle.ALLY, growth.get("def", 0.0)],
		["VEL", p.base_spd, REF_STATUS.spd, UIStyle.POINT, growth.get("spd", 0.0)],
	]
	if p.max_energy > 0:
		lines.append(["EN", p.max_energy, REF_STATUS.hp / 10, UIStyle.ENERGY, 0.0])
	for l in lines:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 5)
		var label := UIStyle.label(l[0], 9, l[3], 2)
		label.custom_minimum_size.x = 24
		h.add_child(label)
		var bar := PixelBar.new()
		bar.color = l[3]
		bar.marks = 5
		bar.custom_minimum_size = Vector2(90, 8)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.set_values(minf(l[1], l[2]), l[2], false)
		h.add_child(bar)
		var value := UIStyle.label(str(roundi(l[1])), 11)
		value.custom_minimum_size.x = 34
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(value)
		# quanto ganha por nível (a identidade do crescimento dele)
		var per_level := UIStyle.label("+%s/nv" % String.num(l[4], 1) if l[4] > 0 else "", 9, UIStyle.DIM_TEXT, 2)
		per_level.custom_minimum_size.x = 40
		h.add_child(per_level)
		grid.add_child(h)
	_detail.add_child(grid)

	_detail.add_child(UIStyle.heading("HABILIDADES"))
	# a lista ocupa o que sobra da ficha e rola: assim a ficha nunca empurra
	# o rodapé (e o botão de começar) para fora da tela
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for skill in p.skills(Battle.MAX_POINTS):
		list.add_child(_skill_row(skill))
	_detail.add_child(scroll)


## Nível, barra de XP e quanto falta para o próximo (ou o limite da Torre).
func _level_row(id: String) -> Control:
	var saved := Progression.progress(id)
	var next := Progression.xp_to_next(saved.level)
	var at_limit: bool = saved.level >= Floors.level_limit() and saved.level < Progression.MAX_LEVEL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.add_child(UIStyle.label("NÍVEL %d" % saved.level, 13, UIStyle.GOLD, 3))
	var text := UIStyle.label(BattleHud.xp_text(saved.level, saved.xp, at_limit), 10,
		UIStyle.GOLD if at_limit else UIStyle.DIM_TEXT, 2)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(text)
	v.add_child(top)
	var bar := PixelBar.new()
	bar.color = UIStyle.GOLD.darkened(0.2) if at_limit else UIStyle.XP
	bar.marks = 0
	bar.custom_minimum_size = Vector2(0, 6)
	var full: bool = next == 0 or at_limit
	bar.set_values(1.0 if full else saved.xp, 1 if full else next, false)
	v.add_child(bar)
	return v


func _skill_row(skill: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_PASS  # a roda do mouse chega à rolagem
	var path: String = skill.get("icon", "")
	if path != "" and not _icons.has(path):
		_icons[path] = load(path)
	var icon := _control(Vector2(34, 34), func(c: Control) -> void:
		var r := Rect2(Vector2(0, 2), Vector2(32, 32))
		c.draw_rect(r.grow(1), Color.BLACK)
		c.draw_rect(r, Color(0.2, 0.19, 0.29))
		if _icons.has(path):
			c.draw_texture_rect(_icons[path], Rect2(r.position + Vector2(1, 1), Vector2(30, 30)), false)
		if skill.get("key", "") != "":
			UIStyle.key(c, Vector2(-3, -1), skill.key))
	h.add_child(icon)
	var card := SkillCard.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.display(skill)
	h.add_child(card)
	return h


# --------------------------------------------------------------- estado
func toggle(id: String) -> void:
	if id in team:
		team.erase(id)
	elif team.size() < _max:
		team.append(id)
	_refresh()


func start() -> void:
	if team.is_empty():
		return
	Roster.set_team(team)
	get_tree().change_scene_to_file(BATTLE_SCENE)


func _refresh() -> void:
	_counter.text = "%d/%d" % [team.size(), _max]
	_refresh_synergy()
	_button.disabled = team.is_empty()
	for c in _summon_slots + _cards:
		c.queue_redraw()
	if _detail.get_meta("id", "") != _ids[_cursor]:
		_detail.set_meta("id", _ids[_cursor])
		_build_sheet()


## Mostra os bônus que a equipe já começou: dourado quando fecha, apagado
## com quanto falta enquanto não.
func _refresh_synergy() -> void:
	var parts: Array[String] = []
	var closed := false
	for s: Dictionary in Synergies.LIST:
		var n := Synergies.members(s, team)
		if n >= s.count:
			closed = true
			parts.append("%s  %s" % [s.name.to_upper(), s.description])
		elif n > 0:
			parts.append("%s  %d/%d de %s" % [s.name, n, s.count, s.universe])
	_synergy.text = "   •   ".join(parts)
	_synergy.add_theme_color_override("font_color", UIStyle.GOLD if closed else UIStyle.DIM_TEXT)


func _process(delta: float) -> void:
	_time += delta
	for c in _summon_slots:
		c.queue_redraw()
	_cards[_cursor].queue_redraw()


func _slot_clicked(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and i < team.size():
		team.remove_at(i)
		_refresh()


func _card_clicked(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_cursor = i
		toggle(_ids[i])


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_LEFT, KEY_A:
			_cursor = posmod(_cursor - 1, _ids.size())
			_refresh()
		KEY_RIGHT, KEY_D:
			_cursor = posmod(_cursor + 1, _ids.size())
			_refresh()
		KEY_SPACE:
			toggle(_ids[_cursor])
		KEY_BACKSPACE:
			if not team.is_empty():
				team.pop_back()
				_refresh()
		KEY_ENTER, KEY_KP_ENTER:
			start()
		KEY_ESCAPE:
			get_tree().change_scene_to_file(FLOORS_SCENE)

class_name FloorSelect
extends Control
## Mapa da Torre, entre a porta do saguão e a montagem da equipe. Cada andar
## é uma fileira de círculos subindo a Torre (o 1º embaixo): a missão
## principal no caminho que sobe, as secundárias num ramal ao lado. Clicar
## num círculo mostra a missão na ficha; clicar de novo (ou Enter, ou o
## botão) entra nela.
## A ficha não conta como a luta funciona: só nome, descrição, nível
## recomendado e tamanho da equipe. Os inimigos e a XP aparecem depois da
## primeira vitória, como lembrança do que já foi enfrentado.
## Lê tudo de Floors, então andares e missões novos aparecem aqui sem mexer
## nesta tela (o mapa rola quando passa da altura da Torre).
## Controles: ↑/↓ troca de andar, ←/→ troca de missão no andar, Enter entra,
## Esc volta ao saguão.

const TEAM_SCENE := "res://tower/team_select.tscn"
const LOBBY_SCENE := "res://lobby/lobby.tscn"
const BACKGROUND := "res://tower/map_background.png"
const NODES := "res://tower/map_nodes.png"
const CLEARED_COLOR := Color(0.45, 0.9, 0.55)
const SIDE_COLOR := Color(0.7, 0.82, 1.0)
## Quadros de map_nodes.png (gerado por tools/generate_tower_map.py).
const NODE_SIZE := 28
const NODE_SCALE := 2.0
enum Frame { LOCKED, MAIN_NEW, MAIN_CLEARED, SIDE_NEW, SIDE_CLEARED, RING }
## O fundo e as posições abaixo são do palco de 960x540 (ver stage_origin).
const STAGE := Vector2(960, 540)
const BACKGROUND_SCALE := 3.0
## Faixas do fundo (px da textura) que preenchem a sobra da tela: à direita,
## a partir de FILL_X, só céu e montanhas; em cima, o topo da Torre e as
## estrelas acima da lua.
const FILL_X := 205.0
const FILL_TOP := 12.0
## Eixo da Torre no fundo (3x o TOWER_X do gerador) e a fileira de cada andar.
const TOWER_AXIS := 312.0
const FIRST_ROW_Y := 428.0  ## o andar 1, logo acima da porta
const DOOR := Vector2(312, 462)
const ROW_HEIGHT := 80.0
const TOP_MARGIN := 70.0  ## a fileira mais alta não passa daqui
const MAIN_OFFSET := 40.0  ## a principal alterna para cada lado do eixo
const SIDE_STEP := 78.0  ## distância entre os círculos do ramal
const MAIN_RADIUS := 22.0  ## área de clique
const SIDE_RADIUS := 17.0

var cursor := 1  ## número do andar selecionado
var cursor_mission := ""  ## missão selecionada no andar ("" = a principal)

var _map: Control
var _nodes: Texture2D
var _hover := Vector2i(-1, -1)  ## (andar, índice da missão) sob o mouse
var _scroll := 0.0  ## quanto o mapa subiu (px), quando os andares não cabem
var _detail: VBoxContainer
var _button: Button
var _notice: Label
var _time := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_nodes = load(NODES)
	cursor = Floors.highest_unlocked()
	_build()
	_follow_cursor()
	_refresh()


# ------------------------------------------------------------------ montagem
func _build() -> void:
	# fundo em escala fixa, preso ao palco (ver stage_origin), para a Torre
	# ficar sob os círculos; a sobra da tela é preenchida em _draw_background
	var background := Control.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.draw.connect(_draw_background.bind(background, load(BACKGROUND) as Texture2D))
	background.resized.connect(background.queue_redraw)
	add_child(background)

	# o mapa ocupa a tela toda; a ficha fica por cima, à direita
	_map = Control.new()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	_map.draw.connect(_draw_map)
	_map.resized.connect(func() -> void:
		_follow_cursor()
		_map.queue_redraw())
	_map.gui_input.connect(_map_input)
	add_child(_map)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size.x = 320
	column.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(column)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.add_child(UIStyle.heading("A TORRE", 24, UIStyle.GOLD, 5))
	titles.add_child(UIStyle.label("Clique num círculo para ver a missão.", 11, UIStyle.DIM_TEXT))
	titles.add_child(UIStyle.label("Limite de nível atual: %d" % Floors.level_limit(), 11, UIStyle.GOLD, 3))
	column.add_child(titles)

	var sheet := PanelContainer.new()
	var ef := UIStyle.panel()
	ef.set_content_margin_all(12)
	sheet.add_theme_stylebox_override("panel", ef)
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 6)
	sheet.add_child(_detail)
	column.add_child(sheet)

	_notice = UIStyle.label("", 11, UIStyle.DAMAGE_TAKEN, 3)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_notice)
	_button = Button.new()
	_button.text = "ENTRAR  >"
	_button.focus_mode = Control.FOCUS_NONE
	_button.custom_minimum_size = Vector2(0, 40)
	UIStyle.button(_button, 16)
	_button.pressed.connect(climb)
	column.add_child(_button)

	var hints := Control.new()
	hints.custom_minimum_size = Vector2(380, 16)
	hints.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)  # acompanha o pé da tela
	hints.offset_left = 20
	hints.offset_top = -24
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hints.draw.connect(_draw_hints.bind(hints))
	add_child(hints)


# ------------------------------------------------------------- situação
## "cleared", "new" (liberada e nunca vencida) ou "locked", da missão `id`
## do andar `n` ("" = a principal).
static func situation(n: int, id := "") -> String:
	if Floors.is_mission_cleared(n, id) and Floors.is_mission_unlocked(n, id):
		return "cleared"
	return "new" if Floors.is_mission_unlocked(n, id) else "locked"


## As missões do andar `n` na ordem do mapa: a principal e o ramal.
static func missions(n: int) -> Array[String]:
	var list: Array[String] = [""]
	for s: Dictionary in Floors.side_missions(n):
		list.append(s.id)
	return list


## Centro do círculo da missão `index` (0 = a principal) do andar `n`, já
## com a rolagem. A principal alterna de lado a cada andar; o ramal sai para
## o lado oposto, então o caminho sobe em zigue-zague sem cruzar os ramais.
func node_position(n: int, index: int) -> Vector2:
	var side := -1.0 if n % 2 == 1 else 1.0
	var y := FIRST_ROW_Y - (n - 1) * ROW_HEIGHT + _scroll
	var main := stage_origin() + Vector2(TOWER_AXIS + side * MAIN_OFFSET, y)
	if index == 0:
		return main
	# o ramal desce e sobe um pouco, para os círculos não parecerem uma régua
	return main + Vector2(-side * SIDE_STEP * index, -10.0 if index % 2 == 1 else 8.0)


## Canto do palco na tela. Com a janela em outra proporção, a tela passa de
## 960x540 (modo expand): o palco fica à esquerda, com o chão e a porta
## embaixo, e a sobra de cima mostra mais da Torre.
func stage_origin() -> Vector2:
	return Vector2(0.0, maxf(0.0, size.y - STAGE.y))


## Altura (na tela) que a fileira mais alta não passa.
func _top_margin() -> float:
	return TOP_MARGIN - stage_origin().y


func _max_scroll() -> float:
	return maxf(0.0, (Floors.total() - 1) * ROW_HEIGHT - (FIRST_ROW_Y - _top_margin()))


## Rola o mapa o mínimo para o andar selecionado ficar à vista.
func _follow_cursor() -> void:
	var y := node_position(cursor, 0).y - stage_origin().y
	if y < _top_margin():
		_scroll += _top_margin() - y
	elif y > FIRST_ROW_Y:
		_scroll -= y - FIRST_ROW_Y
	_scroll = clampf(_scroll, 0.0, _max_scroll())


# ------------------------------------------------------------- desenho
## O fundo inteiro no palco e, na sobra, as faixas FILL_X e FILL_TOP
## espelhadas uma sim, outra não, para emendarem sem costura.
func _draw_background(c: Control, texture: Texture2D) -> void:
	var tile := texture.get_size()
	var origin := stage_origin()
	var fill := Vector2(tile.x - FILL_X, FILL_TOP) * BACKGROUND_SCALE
	var columns := 1 + ceili(maxf(0.0, c.size.x - origin.x - STAGE.x) / fill.x)
	var rows := 1 + ceili(origin.y / fill.y)
	for i in columns:
		for j in rows:
			var source := Rect2(0, 0, tile.x, tile.y)
			var target := Rect2(origin, STAGE)
			if i > 0:
				source.position.x = FILL_X
				source.size.x = tile.x - FILL_X
				target.position.x = origin.x + STAGE.x + (i - 1) * fill.x
				target.size.x = fill.x
			if j > 0:
				source.size.y = FILL_TOP
				target.position.y = origin.y - j * fill.y
				target.size.y = fill.y
			# espelha as ímpares: a borda de cada faixa fica colada à igual do vizinho
			var flip := Vector2(-1.0 if i % 2 == 1 else 1.0, -1.0 if j % 2 == 1 else 1.0)
			c.draw_set_transform(target.position + target.size * (Vector2.ONE - flip) / 2, 0.0, flip)
			c.draw_texture_rect_region(texture, Rect2(Vector2.ZERO, target.size), source)
	c.draw_set_transform(Vector2.ZERO)


func _draw_map() -> void:
	# caminho da porta até o andar mais alto: dourado onde já foi vencido
	var previous := stage_origin() + DOOR + Vector2(0, _scroll)
	for n in range(1, Floors.total() + 1):
		var p := node_position(n, 0)
		var walked := Floors.is_unlocked(n)
		_trail(previous, p, UIStyle.GOLD if walked else UIStyle.BORDER, walked)
		previous = p
	# ramais das secundárias
	for n in range(1, Floors.total() + 1):
		var list := missions(n)
		for i in range(1, list.size()):
			var open := Floors.is_mission_unlocked(n, list[i])
			_trail(node_position(n, i - 1), node_position(n, i), SIDE_COLOR if open else UIStyle.BORDER, open, 7.0)
	# círculos e o rótulo de cada andar
	for n in range(1, Floors.total() + 1):
		var list := missions(n)
		for i in list.size():
			_draw_node(n, i, list[i])
		# o rótulo vai do lado de fora da principal, onde não há ramal
		var main := node_position(n, 0)
		var outside := -1.0 if n % 2 == 1 else 1.0
		var locked := not Floors.is_unlocked(n)
		UIStyle.text(_map, main + Vector2(-110.0 - 32.0 if outside < 0 else 32.0, 4), "ANDAR %d" % n, 10,
			UIStyle.DIM_TEXT if locked else UIStyle.TEXT, 110,
			HORIZONTAL_ALIGNMENT_RIGHT if outside < 0 else HORIZONTAL_ALIGNMENT_LEFT)
	# nome da missão sob o mouse, num balão
	if _hover.x > 0:
		var id := missions(_hover.x)[_hover.y]
		var label: String = "???" if situation(_hover.x, id) == "locked" else Floors.mission(_hover.x, id).name
		var p := node_position(_hover.x, _hover.y) + Vector2(0, -34)
		var w := UIStyle.font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12
		var box := Rect2(p.x - w / 2, p.y - 13, w, 16)
		UIStyle.rounded_rect(_map, box.grow(1), Color.BLACK)
		UIStyle.rounded_rect(_map, box, UIStyle.LIGHT_BACKGROUND)
		UIStyle.text(_map, Vector2(box.position.x, box.position.y + 12), label, 11, UIStyle.GOLD, w, HORIZONTAL_ALIGNMENT_CENTER)


## Trilha de pedrinhas (pixel) entre dois círculos; `lit` acende o miolo.
func _trail(from: Vector2, to: Vector2, color: Color, lit: bool, step := 9.0) -> void:
	var length := from.distance_to(to)
	var count := int(length / step)
	for k in range(1, count):
		var p := from.lerp(to, float(k) / count).round()
		_map.draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color.BLACK)
		_map.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), color if lit else color.darkened(0.3))


func _draw_node(n: int, index: int, id: String) -> void:
	var c := node_position(n, index)
	if c.y < -NODE_SIZE or c.y > size.y + NODE_SIZE:
		return
	var floor_state := situation(n, id)
	var frame: Frame = Frame.LOCKED
	if floor_state != "locked":
		if index == 0:
			frame = Frame.MAIN_CLEARED if floor_state == "cleared" else Frame.MAIN_NEW
		else:
			frame = Frame.SIDE_CLEARED if floor_state == "cleared" else Frame.SIDE_NEW
	var selected := n == cursor and id == cursor_mission
	var bob := 0.0
	if floor_state == "new":  # as que nunca foram vencidas chamam atenção
		bob = roundf(sin(_time * 3.0 + n) * 1.5)
	var drawn := NODE_SIZE * NODE_SCALE
	var r := Rect2(c - Vector2(drawn, drawn) / 2 + Vector2(0, bob), Vector2(drawn, drawn))
	_map.draw_texture_rect_region(_nodes, r, Rect2(frame * NODE_SIZE, 0, NODE_SIZE, NODE_SIZE))
	if selected or _hover == Vector2i(n, index):
		var ring := r.grow(-8.0 if index > 0 else 0.0)
		var alpha := 0.65 + 0.35 * sin(_time * 5.0) if selected else 0.4
		_map.draw_texture_rect_region(_nodes, ring, Rect2(Frame.RING * NODE_SIZE, 0, NODE_SIZE, NODE_SIZE), Color(1, 1, 1, alpha))


func _draw_hints(c: Control) -> void:
	var x := 0.0
	for item in [[["↑", "↓"], "andar"], [["←", "→"], "missão"], [["Enter"], "entrar"], [["Esc"], "saguão"]]:
		for t: String in item[0]:
			UIStyle.key(c, Vector2(x + 1, 1), t)
			x += maxf(13.0, 7.0 * t.length() + 6.0) + 4
		UIStyle.text(c, Vector2(x, 11), item[1], 10, Color(0.82, 0.8, 0.88))
		x += UIStyle.font().get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 16


# ---------------------------------------------------------- ficha (detalhe)
func _build_sheet() -> void:
	for child in _detail.get_children():
		child.queue_free()
	var n := cursor
	var id := cursor_mission
	var floor_state := situation(n, id)
	var kind := "MISSÃO PRINCIPAL" if id == "" else "MISSÃO SECUNDÁRIA"
	_detail.add_child(UIStyle.heading("ANDAR %d  •  %s" % [n, kind], 8, UIStyle.DIM_GOLD if id == "" else SIDE_COLOR))
	if floor_state == "locked":
		_detail.add_child(UIStyle.heading("???", 16, UIStyle.DIM_TEXT, 5))
		var why := "Vença o andar %d para chegar aqui." % (n - 1) if id == "" else "Vença a missão principal deste andar para revelar."
		_detail.add_child(_wrapped(why, UIStyle.DIM_TEXT))
		return
	var d := Floors.mission(n, id)
	_detail.add_child(UIStyle.heading(d.name, 16, UIStyle.GOLD, 5))
	_detail.add_child(_wrapped(d.get("description", ""), Color(0.82, 0.8, 0.88)))

	# nível recomendado contra o da equipe
	var levels: Array[int] = []
	for member in Progression.main_team():
		levels.append(Progression.level(member))
	var average := Progression.entry_level(levels)
	var recommended: int = d.recommended_level
	_detail.add_child(_wrapped("Nível recomendado: %d  (sua equipe: %d)" % [recommended, average],
		UIStyle.DAMAGE_TAKEN if average < recommended else UIStyle.TEXT))
	var maximum := Floors.max_team(n, id)
	_detail.add_child(UIStyle.label("Equipe: %s" % ("só 1 personagem" if maximum == 1 else "até %d personagens" % maximum), 11, UIStyle.TEXT, 3))

	if floor_state == "new":
		# o que vem pela frente fica em segredo; só o que a vitória abre
		_detail.add_child(UIStyle.heading("✦ NUNCA VENCIDA", 8, UIStyle.GOLD))
		if id == "":
			var opens: Array[String] = []
			if n < Floors.total():
				opens.append("o caminho para o andar %d" % (n + 1))
			if not Floors.side_missions(n).is_empty():
				opens.append("outras missões neste andar")
			if not opens.is_empty():
				_detail.add_child(_wrapped("Vencer abre " + " e ".join(opens) + ".", UIStyle.DIM_TEXT))
		else:
			_detail.add_child(_wrapped("Opcional: não abre caminho, mas dá experiência para a subida.", UIStyle.DIM_TEXT))
		if not d.get("on_win", []).is_empty():
			_detail.add_child(_wrapped("A primeira vitória muda algo na Torre...", UIStyle.GOLD))
		return

	# vencida: lembrança do que já foi enfrentado
	_detail.add_child(UIStyle.heading("JÁ ENFRENTADOS"))
	var enemies := Floors.create_enemies(n, id)
	var groups := {}  ## nome -> [quantidade, tipo]
	for foe in enemies:
		if not groups.has(foe.name):
			groups[foe.name] = [0, foe.type]
		groups[foe.name][0] += 1
	for enemy_name: String in groups:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var amount: int = groups[enemy_name][0]
		h.add_child(UIStyle.label(("%d× " % amount if amount > 1 else "") + enemy_name, 12, UIStyle.ENEMY.lightened(0.3), 3))
		h.add_child(UIStyle.type_tag(groups[enemy_name][1]))
		_detail.add_child(h)
	_detail.add_child(_wrapped("✓ Vencida. Repetir dá %d XP de novo, até o limite de nível %d." % [
		Progression.battle_xp(enemies), Floors.level_limit()], CLEARED_COLOR))


## Texto que quebra linha: a ficha tem largura fixa, nada a empurra.
func _wrapped(text: String, color: Color) -> Label:
	var l := UIStyle.label(text, 11, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 280
	return l


# --------------------------------------------------------------- estado
## Seleciona a missão `id` do andar `n` (mostra a ficha e rola até ela).
func select(n: int, id := "") -> void:
	cursor = clampi(n, 1, Floors.total())
	cursor_mission = id if id in missions(cursor) else ""
	_follow_cursor()
	_refresh()


## Vai para a montagem da equipe na missão selecionada (se liberada).
func climb() -> void:
	if not Floors.is_mission_unlocked(cursor, cursor_mission):
		_notice.text = ("Andar %d trancado: vença o andar %d primeiro." % [cursor, cursor - 1] if cursor_mission == ""
			else "Missão trancada: vença a missão principal do andar %d primeiro." % cursor)
		return
	Floors.choose(cursor, cursor_mission)
	get_tree().change_scene_to_file(TEAM_SCENE)


func _refresh() -> void:
	_notice.text = ""
	_button.disabled = not Floors.is_mission_unlocked(cursor, cursor_mission)
	_map.queue_redraw()
	var key := "%d/%s" % [cursor, cursor_mission]
	if _detail.get_meta("mission", "") != key:
		_detail.set_meta("mission", key)
		_build_sheet()


## A missão sob `point` (coordenadas do mapa), como (andar, índice); (-1, -1)
## se nenhuma.
func _mission_at(point: Vector2) -> Vector2i:
	for n in range(1, Floors.total() + 1):
		var list := missions(n)
		for i in list.size():
			if point.distance_to(node_position(n, i)) <= (MAIN_RADIUS if i == 0 else SIDE_RADIUS):
				return Vector2i(n, i)
	return Vector2i(-1, -1)


func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hover := _mission_at(event.position)
		if hover != _hover:
			_hover = hover
			_map.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover.x > 0 else Control.CURSOR_ARROW
			_map.queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_scroll = clampf(_scroll + ROW_HEIGHT / 2, 0.0, _max_scroll())
				_map.queue_redraw()
			MOUSE_BUTTON_WHEEL_DOWN:
				_scroll = clampf(_scroll - ROW_HEIGHT / 2, 0.0, _max_scroll())
				_map.queue_redraw()
			MOUSE_BUTTON_LEFT:
				var hit := _mission_at(event.position)
				if hit.x < 0:
					return
				var id := missions(hit.x)[hit.y]
				# o primeiro clique mostra a missão; o segundo (ou o duplo) entra
				if (hit.x == cursor and id == cursor_mission) or event.double_click:
					select(hit.x, id)
					climb()
				else:
					select(hit.x, id)


func _process(delta: float) -> void:
	_time += delta
	_map.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var list := missions(cursor)
	match event.keycode:
		KEY_UP, KEY_W:
			select(cursor + 1)
		KEY_DOWN, KEY_S:
			select(cursor - 1)
		KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D:
			# ←/→ andam pelo mapa na direção da tela: o ramal sai para o lado
			# oposto ao da principal (ver node_position)
			var outward := (1 if cursor % 2 == 1 else -1) * (1 if event.keycode in [KEY_RIGHT, KEY_D] else -1)
			var i := clampi(list.find(cursor_mission) + outward, 0, list.size() - 1)
			select(cursor, list[i])
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			climb()
		KEY_ESCAPE:
			Engine.set_meta(Lobby.ENTRANCE_META, "door")
			get_tree().change_scene_to_file(LOBBY_SCENE)

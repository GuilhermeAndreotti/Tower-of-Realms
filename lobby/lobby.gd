class_name Lobby
extends Node2D
## Saguão da Torre: a zona segura de onde se sobe para a dungeon. O jogador
## anda livre com a Caoimhe (LobbyPlayer), aborda os personagens do Roster
## e a porta (Interactable) e entra na dungeon pela porta.
## As coordenadas das constantes estão em pixels do fundo (640x180, ×3 na
## tela), as mesmas de tools/generate_lobby.py, que gera a arte.
## Para pôr alguém novo no saguão: um lugar em SPOTS (sem lugar, ele usa
## um dos FREE_SPOTS) e, quando houver falas, a conversa em Conversations.
## Só aparece quem está liberado (Roster.available()). Ao chegar, o saguão
## apresenta os eventos de história pendentes (StoryEvents), na ordem: quem
## chegou à Torre surge com destaque e as conversas de história abrem.

## O que está acontecendo no saguão. O estado decide o que as teclas fazem
## e se o jogador anda (ver _on_mode_changed); as trocas possíveis estão em
## _mode.
##  EXPLORING: anda e aborda. TALKING: conversa aberta. PRESENTING: os
##  eventos de história pendentes estão sendo apresentados. LEAVING: a tela
##  escurece para a dungeon ou para o menu.
enum Mode { EXPLORING, TALKING, PRESENTING, LEAVING }

const SCALE := 3.0
const FOLDER := "res://lobby/art/"
## A porta leva à escolha do andar (depois, a equipe e a batalha).
const DUNGEON_SCENE := "res://tower/floor_select.tscn"
const MENU_SCENE := "res://menu/main_menu.tscn"
## De onde o jogador chega ("door" ao voltar da dungeon). Fica no Engine,
## como a equipe do Roster, para sobreviver à troca de cena.
const ENTRANCE_META := "tower_lobby_entrance"

const WIDTH := 640.0
const HEIGHT := 180.0
## Faixa onde os pés podem ficar: do rodapé da parede até a borda da tela.
const BACK_LIMIT := 112.0
const FRONT_LIMIT := 177.0
const SIDE_LIMIT := 8.0
const FEET := Vector2(24, 9)  ## colisão dos pés dos personagens, px de tela

## Móveis: [arquivo, base, pegada (largura, fundura)]. A pegada é o que
## bloqueia, na base do móvel.
const FURNITURE := [
	["barrel", Vector2(14, 113), Vector2(12, 4)],
	["barrel", Vector2(27, 116), Vector2(12, 4)],
	["crate", Vector2(15, 131), Vector2(16, 5)],
	["bench", Vector2(72, 127), Vector2(36, 3)],
	["table", Vector2(72, 141), Vector2(44, 7)],
	["bench", Vector2(72, 154), Vector2(36, 3)],
	["vase", Vector2(146, 111), Vector2(10, 3)],
	["stool", Vector2(183, 128), Vector2(8, 3)],
	["small_table", Vector2(200, 128), Vector2(28, 6)],
	["stool", Vector2(217, 128), Vector2(8, 3)],
	["brazier", Vector2(276, 116), Vector2(10, 3)],
	["brazier", Vector2(364, 116), Vector2(10, 3)],
	["bench", Vector2(440, 113), Vector2(36, 3)],
	["vase", Vector2(472, 111), Vector2(10, 3)],
	["crate", Vector2(629, 143), Vector2(16, 5)],
	["barrel", Vector2(630, 158), Vector2(12, 4)],
]
## Fogo em cada móvel com chama: deslocamento da base, colunas, altura,
## raio e força do brilho.
const FURNITURE_FIRE := {
	"brazier": [Vector2(0, -22), 2, 6.0, 26, 0.32],
	"table": [Vector2(-12, -22), 0, 2.0, 12, 0.22],
	"small_table": [Vector2(-4, -22), 0, 2.0, 12, 0.22],
}
const TORCHES := [Vector2(20, 58), Vector2(140, 58), Vector2(260, 58), Vector2(380, 58), Vector2(500, 58), Vector2(620, 58)]
const CANDLES := [Vector2(177, 48), Vector2(181, 48), Vector2(219, 48), Vector2(223, 48)]
const FIREPLACE := Vector2(200, 102)
const DOOR := Vector2(320, 107)  ## base do degrau, no centro da parede do fundo
const RUNE_COLOR := Color(0.5, 0.9, 1.0)

## Personagens do Roster: [onde ficam (os pés), se olham para a esquerda].
const SPOTS := {
	"andri": [Vector2(104, 142), true],
	"shumi": [Vector2(428, 130), true],
	"askara": [Vector2(505, 168), true],
	"clairin": [Vector2(562, 128), true],
	"lia": [Vector2(150, 168), false],
	"daimon": [Vector2(606, 168), true],  # no canto, junto dos barris, de olho no salão
}
const FREE_SPOTS := [Vector2(252, 160), Vector2(150, 168), Vector2(505, 168)]
## Onde a Caoimhe aparece: no começo, no centro do tapete, de frente para
## a porta (longe o bastante para ela não começar em foco); ao voltar, na porta.
const ENTRANCES := {
	"start": Vector2(320, 152),
	"door": Vector2(320, 130),
}
## A Caoimhe é quem anda pelo saguão. Ela não luta, então não está no
## Roster; os dados dela ficam aqui, no mesmo formato.
const CAOIMHE := {
	"name": "Caoimhe",
	"sprite": {
		"png": "res://characters/caoimhe/caoimhe_spritesheet.png",
		"json": "res://characters/caoimhe/caoimhe_spritesheet.json",
		"foot": Vector2(16, 38),
		"height": 34.0,
		"face": Rect2(8, 6, 16, 16),
	},
}

var player: LobbyPlayer
var camera: Camera2D
var hud: LobbyHud
var world: Node2D  ## móveis e personagens, ordenados pela altura dos pés
var interactables: Array[Interactable] = []
var focus: Interactable  ## o que está ao alcance agora
var mode: Mode:
	get: return _mode.state as Mode
## Uma interação está em andamento: o jogador não anda nem aborda ninguém.
var busy: bool:
	get: return _mode.state != Mode.EXPLORING

var _door: Interactable
var _runes: Sprite2D
var _door_glow: Sprite2D
var _rune_circle: Node2D
var _rune_light := 0.35
var _time := 0.0
var _visuals := {}  ## id do Roster -> FighterVisual no saguão
var _free_spots: Array = []
var _mode := StateMachine.new(Mode.EXPLORING, {
	Mode.EXPLORING: [Mode.TALKING, Mode.PRESENTING, Mode.LEAVING],
	Mode.TALKING: [Mode.EXPLORING],
	Mode.PRESENTING: [Mode.EXPLORING],
}, Mode.keys())


static func screen(p: Vector2) -> Vector2:
	return p * SCALE


func _ready() -> void:
	var background := Sprite2D.new()
	background.texture = load(FOLDER + "hall.png")
	background.centered = false
	background.scale = Vector2(SCALE, SCALE)
	background.z_index = -10
	add_child(background)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)

	_build_limits()
	_build_furniture()
	_build_lights()
	_build_door()
	_build_player()
	_mode.changed.connect(_on_mode_changed)
	_build_characters()
	_build_camera()

	hud = LobbyHud.new()
	add_child(hud)
	hud.dialog.finished.connect(_on_conversation_finished)
	hud.dialog.event.connect(_on_line_event)
	# quem vai ser apresentado agora começa escondido
	for e in Progression.pending_events():
		if e.get("type", "") == "unlock" and _visuals.has(e.get("id", "")):
			_visuals[e.id].modulate.a = 0.0
	if not Progression.pending_events().is_empty():
		_mode.go(Mode.PRESENTING)  # parado já durante o fade
	await hud.veil(0.0, 0.5).finished
	if _mode.state == Mode.PRESENTING:
		await _present_pending()


# ------------------------------------------------------------------ montagem
func _solid(center: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = center
	var form := RectangleShape2D.new()
	form.size = size
	var col := CollisionShape2D.new()
	col.shape = form
	body.add_child(col)
	add_child(body)
	return body


func _build_limits() -> void:
	var w := WIDTH * SCALE
	var background := BACK_LIMIT * SCALE
	var front := FRONT_LIMIT * SCALE
	var side := SIDE_LIMIT * SCALE
	_solid(Vector2(w / 2, (background - 200) / 2), Vector2(w + 400, background + 200))
	_solid(Vector2(w / 2, front + 100), Vector2(w + 400, 200))
	_solid(Vector2(side - 100, 270), Vector2(200, 1000))
	_solid(Vector2(w - side + 100, 270), Vector2(200, 1000))


## Sprite com a origem no meio da base (o ponto que ordena e colide).
func _object(file: String, base: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(FOLDER + file + ".png")
	s.centered = false
	s.offset = -Vector2(floorf(s.texture.get_width() / 2.0), s.texture.get_height())
	s.scale = Vector2(SCALE, SCALE)
	s.position = screen(base)
	return s


func _build_furniture() -> void:
	for m: Array in FURNITURE:
		var s := _object(m[0], m[1])
		world.add_child(s)
		var footprint: Vector2 = m[2] * SCALE
		_solid(s.position - Vector2(0, footprint.y / 2), footprint)
		if FURNITURE_FIRE.has(m[0]):
			var f: Array = FURNITURE_FIRE[m[0]]
			# filho do móvel: escala 1/3 para a chama seguir a grade de 3px da tela
			var flame := Flame.new(f[0], f[1], f[2], f[3], f[4])
			flame.scale = Vector2.ONE / SCALE
			s.add_child(flame)


func _build_lights() -> void:
	for t: Vector2 in TORCHES:
		var c := Flame.new(screen(t + Vector2(0.5, 0)), 1, 5.0, 34, 0.3)
		c.z_index = -7
		add_child(c)
	for v: Vector2 in CANDLES:
		var c := Flame.new(screen(v + Vector2(0.5, 0)), 0, 2.0, 8, 0.2)
		c.z_index = -7
		add_child(c)
	var fireplace := Flame.new(screen(FIREPLACE), 4, 10.0, 60, 0.4)
	fireplace.z_index = -7
	add_child(fireplace)
	# luz quente no centro, sobre o tapete diante da porta
	var highlight := Glow.create(36, Color(1.0, 0.85, 0.6), 0.16)
	highlight.position = screen(Vector2(320, 104))
	add_child(highlight)


func _build_door() -> void:
	var door := _object("dungeon_door", DOOR)
	door.z_index = -9
	add_child(door)
	_runes = _object("door_runes", DOOR)
	_runes.z_index = -8
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_runes.material = m
	add_child(_runes)
	_door_glow = Glow.create(44, RUNE_COLOR, 0.12)
	_door_glow.position = screen(DOOR + Vector2(0, -38))
	add_child(_door_glow)
	_rune_circle = Node2D.new()
	_rune_circle.position = screen(DOOR + Vector2(0, 8))
	_rune_circle.z_as_relative = false
	_rune_circle.z_index = -6
	_rune_circle.draw.connect(_draw_circle)
	add_child(_rune_circle)

	_door = Interactable.new()
	_door.id = "door"
	_door.action = "Entrar na dungeon"
	_door.color = RUNE_COLOR
	_door.position = screen(DOOR + Vector2(0, 6))
	_door.height = 64 * SCALE
	_door.radius = 96.0
	_door.base_width = 150.0
	_door.interacted.connect(enter_dungeon)
	add_child(_door)
	interactables.append(_door)


func _build_player() -> void:
	player = LobbyPlayer.new()
	player.setup("caoimhe", CAOIMHE)
	var entrance: Vector2 = ENTRANCES.get(Engine.get_meta(ENTRANCE_META, "start"), ENTRANCES.start)
	player.position = screen(entrance)
	player.reset_physics_interpolation.call_deferred()
	world.add_child(player)


func _build_characters() -> void:
	_free_spots = FREE_SPOTS.duplicate()
	for id in Roster.available():
		_build_character(id)


func _build_character(id: String) -> void:
	var spot: Array = SPOTS.get(id, [])
	if spot.is_empty():
		if _free_spots.is_empty():
			push_warning("saguão sem lugar livre para " + id)
			return
		spot = [_free_spots.pop_front(), false]
	var data := Roster.data(id)
	var sp: Dictionary = data.sprite
	var v := FighterVisual.new()
	v.setup_animated(null, sp.png, sp.json, sp.foot, sp.height, sp.get("face", Rect2()))
	v.position = screen(spot[0])
	v.set_facing_left(spot[1])
	world.add_child(v)
	_visuals[id] = v
	_solid(v.position - Vector2(0, FEET.y / 2), FEET)

	var it := Interactable.new()
	it.id = id
	it.title = data.name
	it.position = v.position
	it.height = v.height
	it.portrait = v.portrait()
	it.interacted.connect(_talk_to.bind(it))
	add_child(it)
	interactables.append(it)


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS  # exigido pela interpolação de física
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WIDTH * SCALE)
	camera.limit_bottom = int(HEIGHT * SCALE)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	# filha do jogador: segue o desenho interpolado, sem atraso de um passo
	player.add_child(camera)
	camera.reset_smoothing.call_deferred()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()


## Numa janela de outra proporção a tela passa de 960x540 (modo expand); a
## câmera aproxima o mínimo para a sala ainda cobrir a tela toda.
func _fit_camera() -> void:
	var view := get_viewport_rect().size
	var room := Vector2(WIDTH, HEIGHT) * SCALE
	var z := maxf(1.0, maxf(view.x / room.x, view.y / room.y))
	camera.zoom = Vector2(z, z)


# ---------------------------------------------------------------- interação
func _process(delta: float) -> void:
	_time += delta
	_refresh_focus()
	# as runas respiram devagar e acendem quando o jogador chega perto
	var target := 0.8 + 0.15 * sin(_time * 3.0) if focus == _door else 0.3 + 0.12 * sin(_time * 1.4)
	if not busy or focus == _door:
		_rune_light = move_toward(_rune_light, target, delta * 1.5)
	_runes.modulate.a = _rune_light
	_door_glow.modulate.a = 0.06 + 0.14 * _rune_light
	_rune_circle.queue_redraw()


## O interagível mais perto dos pés do jogador, dentro do raio dele. A
## distância de profundidade (y) pesa mais, como no chão em perspectiva.
func closest() -> Interactable:
	var best: Interactable = null
	var best_d := INF
	for it in interactables:
		var diff := it.position - player.position
		var d := Vector2(diff.x, diff.y * 1.6).length()
		if d <= it.radius and d < best_d:
			best = it
			best_d = d
	return best


func _refresh_focus() -> void:
	var candidate: Interactable = null if busy else closest()
	if candidate == focus:
		return
	if focus:
		focus.focused = false
	focus = candidate
	if focus:
		focus.focused = true


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match _mode.state:
		Mode.TALKING, Mode.PRESENTING:
			# a caixa de diálogo fica com as teclas enquanto estiver aberta
			if hud.dialog.is_open():
				hud.dialog.handle_key(event.keycode)
				get_viewport().set_input_as_handled()
		Mode.EXPLORING:
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				interact()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_ESCAPE:
				back_to_menu()
				get_viewport().set_input_as_handled()


## Interage com o que está em foco. Uma interação por vez: enquanto uma
## conversa ou a entrada na dungeon está em andamento, nada mais começa.
func interact() -> void:
	if busy or focus == null:
		return
	var it := focus
	var reason := it.interact()
	if reason != "":
		hud.warn(reason)


## Abre a conversa de quem foi abordado (ligado ao `interacted` de cada personagem).
func _talk_to(it: Interactable) -> void:
	var conversation := Conversations.from(it.id)
	if conversation.get("lines", []).is_empty():
		hud.warn("%s: interação ainda não disponível." % it.title)
		return
	_mode.go(Mode.TALKING)
	hud.dialog.open(conversation, it.title, it.portrait)


func _on_conversation_finished() -> void:
	if _mode.state != Mode.TALKING:
		return  # conversa de história: quem segue é _present_pending()
	_mode.go(Mode.EXPLORING)
	run_events()


## Fala com "event": "type:id" (ex.: "unlock:andri"). O efeito vale na
## hora; a apresentação entra na fila e roda quando a conversa acaba.
func _on_line_event(event_text: String) -> void:
	var e := StoryEvents.from_text(event_text)
	if e.is_empty() or not StoryEvents.pending(e):
		return
	StoryEvents.apply(e)
	Progression.add_pending_events([e])


# ------------------------------------------------------- eventos de história
## Apresenta os eventos pendentes, um de cada vez, com o jogador parado.
## Cada um sai da fila depois de apresentado (fechar o jogo no meio não perde
## o resto).
func run_events() -> void:
	if _mode.state != Mode.EXPLORING or Progression.pending_events().is_empty():
		return
	_mode.go(Mode.PRESENTING)
	await _present_pending()


func _present_pending() -> void:
	while not Progression.pending_events().is_empty():
		await _present(Progression.pending_events()[0])
		Progression.pop_pending_event()
	_mode.go(Mode.EXPLORING)


func _present(e: Dictionary) -> void:
	match e.get("type", ""):
		"unlock":
			await _present_arrival(e.get("id", ""))
		"conversation":
			var conversation := Conversations.from(e.get("id", ""))
			if conversation.get("lines", []).is_empty():
				return  # ainda sem falas escritas
			var speaker := _interactable(e.get("speaker", ""))
			hud.dialog.open(conversation, speaker.title if speaker else "", speaker.portrait if speaker else null)
			await hud.dialog.finished


## O personagem surge no lugar dele, com um anel de luz e um anúncio.
func _present_arrival(id: String) -> void:
	if id not in Roster.IDS:
		return
	if not _visuals.has(id):
		_build_character(id)  # liberado agora, durante a visita
		if not _visuals.has(id):
			return
		_visuals[id].modulate.a = 0.0
	var v: FighterVisual = _visuals[id]
	CombatEffects.ring(world, v.position + Vector2(0, -v.height * 0.5), UIStyle.GOLD, 90.0)
	var t := create_tween()
	t.tween_property(v, "modulate:a", 1.0, 0.7)
	hud.announce("%s chegou à Torre!" % Roster.data(id).name)
	await t.finished
	await get_tree().create_timer(1.6).timeout


func _interactable(id: String) -> Interactable:
	for it in interactables:
		if it.id == id:
			return it
	return null


## Fora de EXPLORING o jogador fica parado e nada fica em foco.
func _on_mode_changed(_from: int, to: int) -> void:
	player.locked = to != Mode.EXPLORING
	if to != Mode.EXPLORING and focus:
		focus.focused = false
		focus = null


func enter_dungeon() -> void:
	_mode.go(Mode.LEAVING)
	_rune_light = 1.6
	CombatEffects.ring(self, screen(DOOR + Vector2(0, -36)), RUNE_COLOR, 110.0)
	await hud.veil(1.0, 0.6).finished
	Engine.set_meta(ENTRANCE_META, "door")
	get_tree().change_scene_to_file(DUNGEON_SCENE)


## Volta ao menu inicial. O progresso já está salvo a cada mudança.
func back_to_menu() -> void:
	if busy:
		return
	_mode.go(Mode.LEAVING)
	await hud.veil(1.0, 0.4).finished
	get_tree().change_scene_to_file(MENU_SCENE)


# ------------------------------------------------------------------ desenho
## Círculo de runas no chão em frente à porta, em quadradinhos de 3px.
func _draw_circle() -> void:
	var a := clampf(_rune_light, 0.0, 1.0)
	var rx := 28.0
	var ry := 6.0
	for i in 48:
		var ang := TAU * i / 48
		var p := Vector2(cos(ang) * rx, sin(ang) * ry).snapped(Vector2.ONE) * SCALE
		var mark := i % 6 == 0
		var color := Color(RUNE_COLOR, (0.55 if mark else 0.3) * a)
		_rune_circle.draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), color)
		if mark:
			_rune_circle.draw_rect(Rect2(p + Vector2(-1.5, -4.5), Vector2(3, 3)), Color(RUNE_COLOR, 0.4 * a))

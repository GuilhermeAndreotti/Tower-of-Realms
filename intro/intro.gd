class_name Intro
extends Control
## Introdução de todo jogo novo, entre o NEW GAME e o saguão: a Caoimhe conta como
## foi parar na Torre, uma fala por vez, cada trecho com o seu cenário
## (SCENES). A última fala traz a Shumi, a primeira dos seres de outros
## mundos; depois a tela escurece e entra o saguão, pelo começo (o menu já
## deixou Lobby.ENTRANCE_META em "start"). Só apresenta: não lê nem grava save.
## Controles: Enter, Espaço ou clique completam a fala ou passam para a
## próxima; Esc pula a introdução. Sem tecla, cada fala passa sozinha.

## TYPING: a fala está sendo escrita. READING: escrita, esperando a próxima.
## LEAVING: a tela escurece para o saguão.
enum Phase { TYPING, READING, LEAVING }

const LOBBY_SCENE := "res://lobby/lobby.tscn"
const TOWER_BACKGROUND := "res://tower/map_background.png"
const HALL_BACKGROUND := "res://lobby/art/hall.png"
const CHARACTERS_PER_SECOND := 30.0
const READ_TIME := 2.8  ## s com a fala inteira antes de passar sozinha
const LAST_READ_TIME := 3.6  ## a última fica um pouco mais
const SCENE_PAUSE := 0.7  ## s de cenário antes da fala, quando o cenário troca
const ARRIVAL_PAUSE := 1.4  ## a chegada da Shumi pede mais tempo de tela
const SPRITE_SCALE := 2.0  ## sobre a escala do FighterVisual (3x): 6x a arte
const PARTICLES := 46
const SPEAKER := "CAOIMHE"
const SHUMI := "shumi"

## O roteiro: cada fala e a cena (chave de SCENES) em que ela aparece.
const LINES := [
	{"scene": "queen", "text": "Eu já fui uma renomada Rainha de Gryphia."},
	{"scene": "queen", "text": "Ao lado do Rei, eu era a Rainha de todas as criações de Caos."},
	{"scene": "war", "text": "Entretanto, a guerra trouxe grandes perdas: criações de Caos e Ordem se enfrentaram até a morte."},
	{"scene": "death", "text": "Nessa época, eu morri..."},
	{"scene": "tower", "text": "Ao abrir meus olhos novamente, estava nessa torre."},
	{"scene": "tower", "text": "Descobri que aqui era o pós-vida, e não o único lugar. Se eu quisesse, poderia seguir para fora dessa torre e reencarnar."},
	{"scene": "tower", "text": "Mas algo me manteve aqui."},
	{"scene": "hall", "text": "Novas almas chegaram. Algumas queriam subir a torre, pois, de acordo com a lenda,"},
	{"scene": "hall", "text": "a Torre dos Mortos permite aos vitoriosos reviverem, mesmo após séculos mortos."},
	{"scene": "hall", "text": "Entretanto, aqui, ninguém tem o poder de quando vivo..."},
	{"scene": "hall", "text": "Isso tudo mudou quando..."},
	{"scene": "arrival", "text": "Seres de outros mundos chegaram."},
]

## Como fica a tela em cada cena. "tower"/"hall": opacidade do fundo;
## "dark": escurecimento por cima do fundo; "glow": luz atrás da Caoimhe;
## "particles": cor e "rise" (velocidade) das brasas ou almas que sobem;
## "caoimhe"/"shumi": quem está à vista; "shake": tremor contínuo (px).
const SCENES := {
	"queen": {"glow": Color(1.0, 0.78, 0.3, 0.32), "particles": Color(1.0, 0.8, 0.35), "rise": 1.0, "caoimhe": true},
	"war": {"glow": Color(0.9, 0.18, 0.12, 0.45), "particles": Color(1.0, 0.36, 0.18), "rise": 2.6,
		"caoimhe": true, "shake": 2.0},
	"death": {"glow": Color(0.4, 0.4, 0.5, 0.0), "particles": Color(0.5, 0.5, 0.6, 0.0), "rise": 0.4},
	"tower": {"tower": 1.0, "dark": 0.45, "glow": Color(0.62, 0.75, 1.0, 0.16), "particles": Color(0.62, 0.78, 1.0),
		"rise": 0.6, "caoimhe": true},
	"hall": {"hall": 1.0, "dark": 0.55, "glow": Color(1.0, 0.7, 0.4, 0.14), "particles": Color(0.62, 0.78, 1.0, 0.7),
		"rise": 0.5, "caoimhe": true},
	"arrival": {"hall": 1.0, "dark": 0.4, "glow": Color(0.8, 0.9, 1.0, 0.3), "particles": Color(0.85, 0.92, 1.0),
		"rise": 1.4, "caoimhe": true, "shumi": true},
}

var line_index := -1  ## fala na tela
var scene := ""  ## cena atual (chave de SCENES)
var phase: int:
	get: return _phase.state

var _phase := StateMachine.new(Phase.TYPING, {
	Phase.TYPING: [Phase.READING, Phase.LEAVING],
	Phase.READING: [Phase.TYPING, Phase.LEAVING],
}, Phase.keys())
var _typed := 0.0  ## letras escritas (negativo: pausa antes da fala)
var _wait := 0.0  ## o que falta da leitura antes de passar sozinha
var _time := 0.0
var _shake := 0.0

var _tower: TextureRect
var _hall: TextureRect
var _dark: ColorRect
var _glow: Control
var _glow_color := Color(0, 0, 0, 0)
var _particles_layer: Control
var _particles: Array[Dictionary] = []
var _particle_color := Color(1, 1, 1, 0)
var _rise := 1.0
var _stage: Node2D
var _caoimhe: FighterVisual
var _shumi: FighterVisual
var _box: PanelContainer
var _text: Label
var _veil: ColorRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_veil.color.a = 1.0
	create_tween().tween_property(_veil, "color:a", 0.0, 1.0)
	_show(0)


# ------------------------------------------------------------------ montagem
func _build() -> void:
	var black := ColorRect.new()
	black.color = Color(0.02, 0.015, 0.04)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	_tower = _background(TOWER_BACKGROUND)
	_hall = _background(HALL_BACKGROUND)
	_dark = ColorRect.new()
	_dark.color = Color(0.02, 0.015, 0.04, 0.0)
	_dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dark)
	_glow = _layer(_draw_glow)
	_particles_layer = _layer(_draw_particles)

	# os personagens ficam de pé no meio da tela, acima da caixa de fala
	_stage = Node2D.new()
	add_child(_stage)
	_caoimhe = _character(Lobby.CAOIMHE.sprite)
	_shumi = _character(Roster.data(SHUMI).sprite)
	_shumi.position.x = 90
	_shumi.set_facing_left(true)

	_box = PanelContainer.new()
	var style := UIStyle.panel(UIStyle.BACKGROUND, UIStyle.GOLD.darkened(0.35), 2, UIStyle.DIM_GOLD)
	style.set_content_margin_all(14)
	_box.add_theme_stylebox_override("panel", style)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# largura fixa no meio do pé da tela, em qualquer proporção de janela
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_left = -360
	_box.offset_right = 360
	_box.offset_top = -126
	_box.offset_bottom = -30
	add_child(_box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(column)
	column.add_child(UIStyle.heading(SPEAKER, 16, UIStyle.GOLD, 3))
	_text = UIStyle.label("", 16, UIStyle.TEXT, 3)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_text)

	var hints := _layer(_draw_hints)
	hints.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hints.offset_left = -200
	hints.offset_top = -22
	hints.offset_right = -10
	hints.offset_bottom = -6

	_veil = ColorRect.new()
	_veil.color = Color(0, 0, 0, 0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)

	for i in PARTICLES:
		_particles.append(_new_particle(true))
	resized.connect(_place_stage)
	_place_stage()


func _background(path: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(path)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate.a = 0.0
	add_child(r)
	return r


func _layer(draw_func: Callable) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(draw_func.bind(c) if draw_func.get_argument_count() > 0 else draw_func)
	add_child(c)
	return c


## Personagem parado (sem Combatant), invisível até a cena pedir.
func _character(sprite: Dictionary) -> FighterVisual:
	var v := FighterVisual.new()
	v.setup_animated(null, sprite.png, sprite.json, sprite.foot, sprite.height, sprite.get("face", Rect2()))
	v.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	v.modulate.a = 0.0
	_stage.add_child(v)
	return v


## Os pés no meio da tela, um pouco acima da caixa de fala.
func _stage_home() -> Vector2:
	return Vector2(roundf(size.x / 2), size.y - 156)


func _place_stage() -> void:
	_stage.position = _stage_home()


# ------------------------------------------------------------------ roteiro
## Mostra a fala `i`, trocando o cenário se ela for de outra cena.
func _show(i: int) -> void:
	line_index = i
	var line: Dictionary = LINES[i]
	_text.text = line.text
	_text.visible_characters = 0
	_typed = 0.0
	if line.scene != scene:
		# o cenário aparece primeiro; a fala começa depois da pausa
		_typed = -(ARRIVAL_PAUSE if line.scene == "arrival" else SCENE_PAUSE) * CHARACTERS_PER_SECOND
		_set_scene(line.scene)
	_phase.go(Phase.TYPING)


## Enter, Espaço ou clique: completa a fala ou passa para a próxima.
func advance() -> void:
	match _phase.state:
		Phase.TYPING:
			_finish_typing()
		Phase.READING:
			_next()


## Esc: vai direto para o saguão.
func skip() -> void:
	_leave()


func _finish_typing() -> void:
	_typed = _text.text.length()
	_text.visible_characters = -1
	_wait = LAST_READ_TIME if line_index == LINES.size() - 1 else READ_TIME
	_phase.go(Phase.READING)


func _next() -> void:
	if line_index + 1 < LINES.size():
		_show(line_index + 1)
	else:
		_leave()


func _leave() -> void:
	if not _phase.go(Phase.LEAVING):
		return
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_veil, "color:a", 1.0, 0.8)
	t.tween_callback(func() -> void: get_tree().change_scene_to_file(LOBBY_SCENE))


func _set_scene(key: String) -> void:
	var previous := scene
	scene = key
	var s: Dictionary = SCENES[key]
	var t := create_tween().set_parallel()
	t.tween_property(_tower, "modulate:a", s.get("tower", 0.0), 1.2)
	t.tween_property(_hall, "modulate:a", s.get("hall", 0.0), 1.2)
	t.tween_property(_dark, "color:a", s.get("dark", 0.0), 1.2)
	t.tween_property(self, "_glow_color", s.glow, 1.0)
	t.tween_property(self, "_particle_color", s.particles, 1.0)
	t.tween_property(self, "_rise", s.rise, 1.0)
	_shake = s.get("shake", 0.0)

	if key == "death":
		# ela se desfaz em luz, como os lutadores que caem
		t.tween_property(_caoimhe, "modulate", Color(1.6, 1.4, 1.2, 0.0), 1.6)
		t.tween_property(_caoimhe, "scale", Vector2(SPRITE_SCALE * 1.15, SPRITE_SCALE * 0.7), 1.6)
	elif s.get("caoimhe", false):
		if previous == "death":  # desperta na Torre
			_caoimhe.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
			_caoimhe.modulate = Color(1, 1, 1, 0)
		t.tween_property(_caoimhe, "modulate", Color.WHITE, 1.2)
	if s.get("shumi", false):
		_arrival()


## A Shumi surge num clarão, e a Caoimhe dá espaço para ela.
func _arrival() -> void:
	var t := create_tween()
	t.tween_interval(0.5)
	t.tween_callback(func() -> void:
		_veil.color = Color(1, 1, 1, 0.85)
		_shumi.modulate = Color(2, 2, 2, 1)
		_caoimhe.position.x = -90
		_kick(8.0))
	t.tween_property(_veil, "color:a", 0.0, 0.6)
	t.parallel().tween_property(_shumi, "modulate", Color.WHITE, 0.8)


## Tremor curto da tela, por cima do contínuo da cena.
func _kick(strength: float) -> void:
	var t := create_tween()
	for i in 6:
		t.tween_property(_stage, "position:x", _stage_home().x + randf_range(-strength, strength), 0.04)
	t.tween_callback(_place_stage)


# ------------------------------------------------------------------ quadro
func _process(delta: float) -> void:
	_time += delta
	match _phase.state:
		Phase.TYPING:
			_typed += delta * CHARACTERS_PER_SECOND
			if _typed >= _text.text.length():
				_finish_typing()
			else:
				_text.visible_characters = maxi(0, int(_typed))
		Phase.READING:
			_wait -= delta
			if _wait <= 0.0:
				_next()
	if _shake > 0.0:
		_stage.position = _stage_home() + Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
	for i in _particles.size():
		var p: Dictionary = _particles[i]
		p.pos.y -= p.spd * _rise * delta
		p.pos.x += sin(_time * 1.5 + p.phase) * 8.0 * delta
		if p.pos.y < -4:
			_particles[i] = _new_particle()
	_particles_layer.queue_redraw()
	_glow.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _phase.state == Phase.LEAVING:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		match key.keycode:
			KEY_ESCAPE:
				skip()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				advance()
			_:
				return
		get_viewport().set_input_as_handled()
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		advance()
		get_viewport().set_input_as_handled()


## Brasa (ou alma) subindo do pé da tela; `spread` sorteia a altura.
func _new_particle(spread := false) -> Dictionary:
	return {"pos": Vector2(randf() * size.x, randf() * size.y if spread else size.y + 4),
		"spd": randf_range(14.0, 36.0), "phase": randf() * TAU, "px_size": 2.0 if randf() < 0.3 else 1.0}


func _draw_particles() -> void:
	if _particle_color.a <= 0.0:
		return
	for p in _particles:
		var pos: Vector2 = p.pos
		var a := clampf(pos.y / maxf(1.0, size.y), 0.0, 1.0)  # apagam ao subir
		var px_size: float = p.px_size * 2.0
		_particles_layer.draw_rect(Rect2(pos.floor(), Vector2(px_size, px_size)),
			Color(_particle_color, _particle_color.a * 0.8 * a))


## Luz atrás da Caoimhe: discos em degraus (pixel), pulsando devagar.
func _draw_glow() -> void:
	if _glow_color.a <= 0.0:
		return
	var center := _stage.position + Vector2(0, -110)
	var pulse := 1.0 + 0.04 * sin(_time * 1.8)
	for k in 5:
		var r := (70.0 + 38.0 * k) * pulse
		_glow.draw_circle(center.round(), roundf(r), Color(_glow_color, _glow_color.a * (0.5 - k * 0.09)))


func _draw_hints(c: Control) -> void:
	var x := 0.0
	for item in [[["Enter"], "avançar"], [["Esc"], "pular"]]:
		for t: String in item[0]:
			UIStyle.key(c, Vector2(x + 1, 1), t)
			x += maxf(13.0, 7.0 * t.length() + 6.0) + 4
		UIStyle.text(c, Vector2(x, 11), item[1], 10, Color(0.82, 0.8, 0.88))
		x += UIStyle.font().get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 16

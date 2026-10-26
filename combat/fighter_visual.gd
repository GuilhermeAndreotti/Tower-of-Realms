class_name FighterVisual
extends Node2D
## Desenho de um lutador na arena. A origem do nó fica nos pés do personagem.
## Personagens usam o sprite sheet (+ JSON gerado pelo script da Shumi);
## inimigos de teste usam uma imagem só, animada com tweens.

const SCALE := 3.0
const LOOPING_ANIMATIONS := ["idle", "walk", "kaioken"]

var combatant: Combatant
var height := 0.0  ## altura do personagem na tela, para barra e números
var show_bar := false
var marked := false:  ## alvo escolhido
	set(v):
		marked = v
		queue_redraw()
var highlighted := false:  ## seria atingido pela habilidade em foco
	set(v):
		highlighted = v
		queue_redraw()
var acting := false:  ## aliado que está agindo agora
	set(v):
		acting = v
		queue_redraw()

var _sprite: Node2D
var _animated: AnimatedSprite2D
var _idle_anim := "idle"
var _base_color := Color.WHITE
var _time := 0.0
var _shown_hp := -1.0
var _trail_hp := -1.0
var _portrait: Texture2D


## `foot` é onde ficam os pés dentro de cada quadro do sprite sheet;
## `face` é o recorte do primeiro quadro usado como retrato na HUD.
func setup_animated(c: Combatant, png: String, json: String, foot: Vector2, height_px: float, face := Rect2()) -> void:
	combatant = c
	var texture: Texture2D = load(png)
	var frames := load_frames(png, json)
	_animated = AnimatedSprite2D.new()
	_animated.sprite_frames = frames
	_animated.centered = false
	_animated.offset = -foot
	_animated.scale = Vector2(SCALE, SCALE)
	_animated.animation_finished.connect(func() -> void:
		_animated.speed_scale = 1.0
		_animated.play(_idle_anim))
	add_child(_animated)
	_sprite = _animated
	height = height_px * SCALE
	_animated.play(_idle_anim)
	if face.has_area():
		var r := AtlasTexture.new()
		r.atlas = texture
		r.region = face
		_portrait = r
	else:
		_portrait = frames.get_frame_texture(_idle_anim, 0)


func setup_static(c: Combatant, png: String) -> void:
	combatant = c
	var spr := Sprite2D.new()
	spr.texture = load(png)
	spr.centered = false
	spr.offset = -Vector2(spr.texture.get_width() / 2.0, spr.texture.get_height())
	spr.scale = Vector2(SCALE, SCALE)
	add_child(spr)
	_sprite = spr
	height = spr.texture.get_height() * SCALE
	_portrait = spr.texture
	show_bar = true
	# flutua de leve, cada um num ritmo
	var t := create_tween().set_loops()
	t.tween_property(spr, "position:y", -5.0, 0.9 + randf() * 0.3).set_trans(Tween.TRANS_SINE)
	t.tween_property(spr, "position:y", 0.0, 0.9 + randf() * 0.3).set_trans(Tween.TRANS_SINE)


## Animações de um sprite sheet + JSON (formato do gerar_spritesheet.py).
static func load_frames(png: String, json: String) -> SpriteFrames:
	var texture: Texture2D = load(png)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(json))
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim_name: String in data.animations:
		var anim: Dictionary = data.animations[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, anim_name in LOOPING_ANIMATIONS)
		frames.set_animation_speed(anim_name, 1000.0 / anim.frame_duration_ms)
		for f: Dictionary in anim.frames:
			var frame := AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2(f.x, f.y, f.w, f.h)
			frames.add_frame(anim_name, frame)
	return frames


## Animações em uso (para guardar e voltar depois de swap_frames()).
func frames() -> SpriteFrames:
	return _animated.sprite_frames if _animated else null


## Troca o visual (outra roupa ou forma, com as mesmas animações) sem
## interromper a animação nem o quadro em que está.
func swap_frames(new_frames: SpriteFrames) -> void:
	if not _animated or new_frames == null or new_frames == _animated.sprite_frames:
		return
	var anim := _animated.animation
	var frame := _animated.frame
	var progress := _animated.frame_progress
	_animated.sprite_frames = new_frames
	_animated.play(anim)
	_animated.set_frame_and_progress(frame, progress)


## Imagem pequena do lutador para a HUD (ordem de turnos, painel).
func portrait() -> Texture2D:
	return _portrait


func top() -> Vector2:
	return position + Vector2(0, -height)


## `speed` acelera só esta animação; volta ao normal quando ela acaba.
func play(anim: String, speed := 1.0) -> void:
	if _animated:
		_animated.speed_scale = speed
		_animated.play(anim)


## Animação usada quando não está fazendo nada (ex.: "kaioken" enquanto na forma).
func set_idle_anim(anim: String) -> void:
	_idle_anim = anim
	if _animated and _animated.animation in LOOPING_ANIMATIONS:
		_animated.play(anim)


## Olha para a esquerda (espelha em torno dos pés) ou volta para a direita.
func set_facing_left(facing_left: bool) -> void:
	_sprite.scale.x = -absf(_sprite.scale.x) if facing_left else absf(_sprite.scale.x)


func set_base_color(color: Color) -> void:
	_base_color = color
	_sprite.modulate = color


func move_to(destination: Vector2, duration: float) -> void:
	var t := create_tween()
	t.tween_property(self, "position", destination, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished


func take_hit() -> void:
	if _animated:
		_animated.play("hurt")
	_sprite.modulate = Color(4, 4, 4)
	var t := create_tween()
	t.tween_property(_sprite, "modulate", _base_color, 0.18)
	var x := _sprite.position.x
	var s := create_tween()
	for d in [8.0, -6.0, 4.0, 0.0]:
		s.tween_property(_sprite, "position:x", x + d, 0.04)


func flash(color: Color) -> void:
	_sprite.modulate = color
	create_tween().tween_property(_sprite, "modulate", _base_color, 0.4)


func die() -> void:
	marked = false
	highlighted = false
	acting = false
	show_bar = false
	queue_redraw()
	var t := create_tween().set_parallel()
	t.tween_property(_sprite, "modulate:a", 0.0, 0.6)
	t.tween_property(_sprite, "scale", _sprite.scale * Vector2(1.2, 0.6), 0.6)


func _process(delta: float) -> void:
	if not (marked or highlighted or acting or show_bar):
		return
	_time += delta
	if combatant and show_bar:
		# a barra desliza até o HP real; o rastro claro vai atrás, mais devagar
		var hp := float(combatant.hp)
		if _shown_hp < 0:
			_shown_hp = hp
			_trail_hp = hp
		_shown_hp = move_toward(_shown_hp, hp, maxf(1.0, absf(_shown_hp - hp)) * delta * 12.0)
		_trail_hp = hp if _trail_hp < hp else move_toward(_trail_hp, hp, combatant.max_hp * delta * 0.6)
	queue_redraw()


func _draw() -> void:
	if not combatant or not combatant.is_alive():
		return
	# elipse nos pés: dourada no alvo escolhido, clara nos outros atingidos
	if marked or highlighted:
		var pulso := 0.5 + 0.5 * sin(_time * 6.0)
		var color := UIStyle.GOLD if marked else Color(1, 0.95, 0.8)
		var width := clampf(height * 0.55, 40, 90)
		_ellipse(Vector2(0, -2), Vector2(width / 2, 7), Color(color, 0.18 + 0.12 * pulso), true)
		_ellipse(Vector2(0, -2), Vector2(width / 2, 7), Color(color, 0.55 + 0.35 * pulso), false)

	if acting:
		# losango dourado sobre a cabeça + base no chão
		var turn_width := clampf(height * 0.55, 40, 90)
		_ellipse(Vector2(0, -2), Vector2(turn_width / 2, 7), Color(UIStyle.GOLD, 0.5), false)
		var cy := -height - 14.0 + sin(_time * 5.0) * 2.0
		var los := PackedVector2Array([Vector2(0, cy - 6), Vector2(5, cy), Vector2(0, cy + 6), Vector2(-5, cy)])
		draw_colored_polygon(los, UIStyle.GOLD)
		draw_polyline(los + PackedVector2Array([los[0]]), Color.BLACK, 1.5)

	var y := -height - 16.0
	if show_bar:
		var width := 64.0
		var frac := clampf(_shown_hp / combatant.max_hp, 0, 1)
		var trail_frac := clampf(_trail_hp / combatant.max_hp, 0, 1)
		draw_rect(Rect2(-width / 2 - 1, y - 1, width + 2, 8), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(-width / 2, y, width, 6), Color(0.12, 0.08, 0.1))
		draw_rect(Rect2(-width / 2, y, roundf(width * trail_frac), 6), Color(1, 0.9, 0.8, 0.85))
		draw_rect(Rect2(-width / 2, y, roundf(width * frac), 6), Color(0.86, 0.22, 0.25))
		draw_rect(Rect2(-width / 2, y, roundf(width * frac), 2), Color(1, 0.5, 0.5))
		if combatant.shield() > 0:
			UIStyle.shield_outline(self, Rect2(-width / 2 - 1, y - 1, width + 2, 8), float(combatant.shield()) / combatant.max_hp)
		var name_color := UIStyle.GOLD if marked else UIStyle.TEXT
		UIStyle.text(self, Vector2(-width, y - 5), combatant.name, 12, name_color, width * 2, HORIZONTAL_ALIGNMENT_CENTER)
		# elemento à esquerda da barra (os efeitos ficam à direita)
		var badge_width := UIStyle.type_badge_width(combatant.type)
		UIStyle.type_badge(self, Vector2(-width / 2 - 5 - badge_width, y - 3), combatant.type)
		# efeitos ativos ao lado da barra
		var x := width / 2 + 4
		for e: Dictionary in combatant.effects():
			var effect_color := UIStyle.effect_color(e)
			var r := Rect2(x, y - 3, 11, 11)
			draw_rect(r.grow(1), Color.BLACK)
			draw_rect(r, effect_color)
			draw_string(UIStyle.source(), r.position + Vector2(0, 9), e.get("short", ""), HORIZONTAL_ALIGNMENT_CENTER, 11, 9, Color.BLACK)
			x += 14
	if marked:
		var my := y - 30.0 + sin(_time * 6.0) * 3.0
		var tri := PackedVector2Array([Vector2(-9, my), Vector2(9, my), Vector2(0, my + 11)])
		draw_colored_polygon(tri, UIStyle.GOLD)
		draw_polyline(tri + PackedVector2Array([tri[0]]), Color.BLACK, 2.0)


func _ellipse(center: Vector2, radii: Vector2, color: Color, full: bool) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	if full:
		draw_colored_polygon(pts, color)
	else:
		pts.append(pts[0])
		draw_polyline(pts, color, 2.0)

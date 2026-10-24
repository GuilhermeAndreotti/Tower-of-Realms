class_name VisualLutador
extends Node2D
## Desenho de um lutador na arena. A origem do nó fica nos pés do personagem.
## Personagens usam o sprite sheet (+ JSON gerado pelo script da Shumi);
## inimigos de teste usam uma imagem só, animada com tweens.

const ESCALA := 3.0
const ANIMACOES_EM_LOOP := ["idle", "walk", "kaioken"]

var combatente: Combatente
var altura := 0.0  ## altura do personagem na tela, para barra e números
var mostrar_barra := false
var marcado := false:  ## alvo escolhido
	set(v):
		marcado = v
		queue_redraw()
var realce := false:  ## seria atingido pela habilidade em foco
	set(v):
		realce = v
		queue_redraw()
var da_vez := false:  ## aliado que está agindo agora
	set(v):
		da_vez = v
		queue_redraw()

var _sprite: Node2D
var _animado: AnimatedSprite2D
var _anim_parado := "idle"
var _cor_base := Color.WHITE
var _tempo := 0.0
var _hp_mostrado := -1.0
var _hp_rastro := -1.0
var _retrato: Texture2D


## `pe` é onde ficam os pés dentro de cada quadro do sprite sheet;
## `rosto` é o recorte do primeiro quadro usado como retrato na HUD.
func iniciar_animado(c: Combatente, png: String, json: String, pe: Vector2, altura_px: float, rosto := Rect2()) -> void:
	combatente = c
	var textura: Texture2D = load(png)
	var frames := carregar_frames(png, json)
	_animado = AnimatedSprite2D.new()
	_animado.sprite_frames = frames
	_animado.centered = false
	_animado.offset = -pe
	_animado.scale = Vector2(ESCALA, ESCALA)
	_animado.animation_finished.connect(func() -> void:
		_animado.speed_scale = 1.0
		_animado.play(_anim_parado))
	add_child(_animado)
	_sprite = _animado
	altura = altura_px * ESCALA
	_animado.play(_anim_parado)
	if rosto.has_area():
		var r := AtlasTexture.new()
		r.atlas = textura
		r.region = rosto
		_retrato = r
	else:
		_retrato = frames.get_frame_texture(_anim_parado, 0)


func iniciar_estatico(c: Combatente, png: String) -> void:
	combatente = c
	var spr := Sprite2D.new()
	spr.texture = load(png)
	spr.centered = false
	spr.offset = -Vector2(spr.texture.get_width() / 2.0, spr.texture.get_height())
	spr.scale = Vector2(ESCALA, ESCALA)
	add_child(spr)
	_sprite = spr
	altura = spr.texture.get_height() * ESCALA
	_retrato = spr.texture
	mostrar_barra = true
	# flutua de leve, cada um num ritmo
	var t := create_tween().set_loops()
	t.tween_property(spr, "position:y", -5.0, 0.9 + randf() * 0.3).set_trans(Tween.TRANS_SINE)
	t.tween_property(spr, "position:y", 0.0, 0.9 + randf() * 0.3).set_trans(Tween.TRANS_SINE)


## Animações de um sprite sheet + JSON (formato do gerar_spritesheet.py).
static func carregar_frames(png: String, json: String) -> SpriteFrames:
	var textura: Texture2D = load(png)
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(json))
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for nome: String in dados.animations:
		var anim: Dictionary = dados.animations[nome]
		frames.add_animation(nome)
		frames.set_animation_loop(nome, nome in ANIMACOES_EM_LOOP)
		frames.set_animation_speed(nome, 1000.0 / anim.frame_duration_ms)
		for f: Dictionary in anim.frames:
			var quadro := AtlasTexture.new()
			quadro.atlas = textura
			quadro.region = Rect2(f.x, f.y, f.w, f.h)
			frames.add_frame(nome, quadro)
	return frames


## Animações em uso (para guardar e voltar depois de trocar_frames()).
func frames() -> SpriteFrames:
	return _animado.sprite_frames if _animado else null


## Troca o visual (outra roupa ou forma, com as mesmas animações) sem
## interromper a animação nem o quadro em que está.
func trocar_frames(novos: SpriteFrames) -> void:
	if not _animado or novos == null or novos == _animado.sprite_frames:
		return
	var anim := _animado.animation
	var quadro := _animado.frame
	var progresso := _animado.frame_progress
	_animado.sprite_frames = novos
	_animado.play(anim)
	_animado.set_frame_and_progress(quadro, progresso)


## Imagem pequena do lutador para a HUD (ordem de turnos, painel).
func retrato() -> Texture2D:
	return _retrato


func topo() -> Vector2:
	return position + Vector2(0, -altura)


## `velocidade` acelera só esta animação; volta ao normal quando ela acaba.
func tocar(anim: String, velocidade := 1.0) -> void:
	if _animado:
		_animado.speed_scale = velocidade
		_animado.play(anim)


## Animação usada quando não está fazendo nada (ex.: "kaioken" enquanto na forma).
func definir_parado(anim: String) -> void:
	_anim_parado = anim
	if _animado and _animado.animation in ANIMACOES_EM_LOOP:
		_animado.play(anim)


## Olha para a esquerda (espelha em torno dos pés) ou volta para a direita.
func virar(para_esquerda: bool) -> void:
	_sprite.scale.x = -absf(_sprite.scale.x) if para_esquerda else absf(_sprite.scale.x)


func definir_cor_base(cor: Color) -> void:
	_cor_base = cor
	_sprite.modulate = cor


func mover_para(destino: Vector2, duracao: float) -> void:
	var t := create_tween()
	t.tween_property(self, "position", destino, duracao).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished


func levar_golpe() -> void:
	if _animado:
		_animado.play("hurt")
	_sprite.modulate = Color(4, 4, 4)
	var t := create_tween()
	t.tween_property(_sprite, "modulate", _cor_base, 0.18)
	var x := _sprite.position.x
	var s := create_tween()
	for d in [8.0, -6.0, 4.0, 0.0]:
		s.tween_property(_sprite, "position:x", x + d, 0.04)


func piscar(cor: Color) -> void:
	_sprite.modulate = cor
	create_tween().tween_property(_sprite, "modulate", _cor_base, 0.4)


func morrer() -> void:
	marcado = false
	realce = false
	da_vez = false
	mostrar_barra = false
	queue_redraw()
	var t := create_tween().set_parallel()
	t.tween_property(_sprite, "modulate:a", 0.0, 0.6)
	t.tween_property(_sprite, "scale", _sprite.scale * Vector2(1.2, 0.6), 0.6)


func _process(delta: float) -> void:
	if not (marcado or realce or da_vez or mostrar_barra):
		return
	_tempo += delta
	if combatente and mostrar_barra:
		# a barra desliza até o HP real; o rastro claro vai atrás, mais devagar
		var hp := float(combatente.hp)
		if _hp_mostrado < 0:
			_hp_mostrado = hp
			_hp_rastro = hp
		_hp_mostrado = move_toward(_hp_mostrado, hp, maxf(1.0, absf(_hp_mostrado - hp)) * delta * 12.0)
		_hp_rastro = hp if _hp_rastro < hp else move_toward(_hp_rastro, hp, combatente.hp_max * delta * 0.6)
	queue_redraw()


func _draw() -> void:
	if not combatente or not combatente.vivo():
		return
	# elipse nos pés: dourada no alvo escolhido, clara nos outros atingidos
	if marcado or realce:
		var pulso := 0.5 + 0.5 * sin(_tempo * 6.0)
		var cor := EstiloUI.OURO if marcado else Color(1, 0.95, 0.8)
		var largura := clampf(altura * 0.55, 40, 90)
		_elipse(Vector2(0, -2), Vector2(largura / 2, 7), Color(cor, 0.18 + 0.12 * pulso), true)
		_elipse(Vector2(0, -2), Vector2(largura / 2, 7), Color(cor, 0.55 + 0.35 * pulso), false)

	if da_vez:
		# losango dourado sobre a cabeça + base no chão
		var largura_vez := clampf(altura * 0.55, 40, 90)
		_elipse(Vector2(0, -2), Vector2(largura_vez / 2, 7), Color(EstiloUI.OURO, 0.5), false)
		var cy := -altura - 14.0 + sin(_tempo * 5.0) * 2.0
		var los := PackedVector2Array([Vector2(0, cy - 6), Vector2(5, cy), Vector2(0, cy + 6), Vector2(-5, cy)])
		draw_colored_polygon(los, EstiloUI.OURO)
		draw_polyline(los + PackedVector2Array([los[0]]), Color.BLACK, 1.5)

	var y := -altura - 16.0
	if mostrar_barra:
		var largura := 64.0
		var frac := clampf(_hp_mostrado / combatente.hp_max, 0, 1)
		var frac_rastro := clampf(_hp_rastro / combatente.hp_max, 0, 1)
		draw_rect(Rect2(-largura / 2 - 1, y - 1, largura + 2, 8), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(-largura / 2, y, largura, 6), Color(0.12, 0.08, 0.1))
		draw_rect(Rect2(-largura / 2, y, roundf(largura * frac_rastro), 6), Color(1, 0.9, 0.8, 0.85))
		draw_rect(Rect2(-largura / 2, y, roundf(largura * frac), 6), Color(0.86, 0.22, 0.25))
		draw_rect(Rect2(-largura / 2, y, roundf(largura * frac), 2), Color(1, 0.5, 0.5))
		var cor_nome := EstiloUI.OURO if marcado else EstiloUI.TEXTO
		EstiloUI.texto(self, Vector2(-largura, y - 5), combatente.nome, 12, cor_nome, largura * 2, HORIZONTAL_ALIGNMENT_CENTER)
		# elemento à esquerda da barra (os efeitos ficam à direita)
		var largura_selo := EstiloUI.largura_selo_tipo(combatente.tipo)
		EstiloUI.selo_tipo(self, Vector2(-largura / 2 - 5 - largura_selo, y - 3), combatente.tipo)
		# efeitos ativos ao lado da barra
		var x := largura / 2 + 4
		for e: Dictionary in combatente.efeitos():
			var cor_e := EstiloUI.cor_efeito(e)
			var r := Rect2(x, y - 3, 11, 11)
			draw_rect(r.grow(1), Color.BLACK)
			draw_rect(r, cor_e)
			draw_string(EstiloUI.fonte(), r.position + Vector2(0, 9), e.get("curto", ""), HORIZONTAL_ALIGNMENT_CENTER, 11, 9, Color.BLACK)
			x += 14
	if marcado:
		var my := y - 30.0 + sin(_tempo * 6.0) * 3.0
		var tri := PackedVector2Array([Vector2(-9, my), Vector2(9, my), Vector2(0, my + 11)])
		draw_colored_polygon(tri, EstiloUI.OURO)
		draw_polyline(tri + PackedVector2Array([tri[0]]), Color.BLACK, 2.0)


func _elipse(centro: Vector2, raios: Vector2, cor: Color, cheia: bool) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20
		pts.append(centro + Vector2(cos(a) * raios.x, sin(a) * raios.y))
	if cheia:
		draw_colored_polygon(pts, cor)
	else:
		pts.append(pts[0])
		draw_polyline(pts, cor, 2.0)

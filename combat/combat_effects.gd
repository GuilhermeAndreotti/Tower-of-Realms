class_name CombatEffects
extends RefCounted
## Efeitos da arena: números flutuantes, rastro de corte, faíscas de impacto,
## anel de energia, feixe, carga, aura e véus de tela. Cada um é um nó leve
## que se desenha com _draw, anima por tween e se apaga sozinho (a aura fica
## até ser removida). Quem chama escolhe a cor/forma de cada golpe; aqui só
## ficam as peças. Tudo é desenhado numa grade de PIXEL px, a mesma escala
## dos sprites.

const PIXEL := 3.0
const SCREEN := Vector2(960, 540)

## Estilo de cada tipo de número: [cor, tamanho].
const NUMBERS := {
	"damage": [UIStyle.DAMAGE, 24],
	"weak": [UIStyle.WEAK_DAMAGE, 18],
	"critical": [UIStyle.CRITICAL_DAMAGE, 30],
	"taken": [UIStyle.DAMAGE_TAKEN, 24],
	"heal": [UIStyle.HEAL, 22],
	"drain": [UIStyle.DRAIN, 20],
	"energy": [UIStyle.ENERGY, 16],
	"effective": [UIStyle.CRITICAL_DAMAGE, 13],
	"not_very_effective": [UIStyle.DIM_TEXT, 12],
	"shield": [UIStyle.POINT, 16],
	"notice": [UIStyle.GOLD, 13],
	"level": [UIStyle.GOLD, 18],
}


static func number(parent: Node, pos: Vector2, text: String, type := "damage") -> void:
	var style: Array = NUMBERS.get(type, NUMBERS.damage)
	var l := UIStyle.label(text, style[1], style[0], 7)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(90, 36)
	l.pivot_offset = l.size / 2
	l.position = pos + Vector2(-45 + randf_range(-10, 10), -66)
	l.scale = Vector2(1.5, 1.5)
	parent.add_child(l)
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "position:y", l.position.y - 34, 0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(l, "modulate:a", 0.0, 0.25).set_delay(0.55)
	t.chain().tween_callback(l.queue_free)


## Rastro curvo de lâmina, de cima para baixo, passando por `pos`.
## `angle` gira o arco (golpes em sequência saem de direções diferentes).
static func slash(parent: Node, pos: Vector2, color := Color.WHITE, radius := 46.0, angle := 0.0) -> void:
	var fx := _Slash.new(color, radius)
	fx.rotation = angle
	_play(parent, fx, pos, 0.22)


## Faíscas quadradas saindo do ponto de impacto.
static func impact(parent: Node, pos: Vector2, color := Color.WHITE, strength := 1.0) -> void:
	var fx := _Impact.new(color, strength)
	_play(parent, fx, pos, 0.28)


## Anel que se expande (ativação de técnica, carga de golpe...).
static func ring(parent: Node, pos: Vector2, color: Color, radius := 70.0) -> void:
	_play(parent, _Ring.new(color, radius), pos, 0.45)


## Partículas que convergem para `pos` durante `duration` (carga de energia).
static func charge(parent: Node, pos: Vector2, colors: Array[Color], duration: float, radius := 140.0) -> void:
	_play(parent, _Charge.new(colors, radius), pos, duration)


## Feixe de energia saindo de `origin` na direção `angle`, com a ponta
## avançando a `speed` px/s até `reach`; segura `safe` s e some.
## Um alvo a d px da origem é alcançado em d / velocidade segundos.
## `style`: {"width", "colors": [brilho, borda, meio, nucleo], "sparks"
## (por segundo), "distortion" (0..1), "distortion_color"?, "tip" (Texture2D)?}.
static func beam(parent: Node, origin: Vector2, angle: float, reach: float, speed: float, style: Dictionary, safe := 0.15) -> Node2D:
	var fx := Beam.new(style)
	fx.position = origin
	fx.rotation = angle
	parent.add_child(fx)
	var t := fx.create_tween()
	t.tween_property(fx, "length", reach, reach / speed)
	t.tween_interval(safe)
	t.tween_property(fx, "fading", 1.0, 0.25).set_ease(Tween.EASE_IN)
	t.tween_callback(fx.queue_free)
	return fx


## Véu de tela inteira. `behind_everyone` põe o véu logo acima do cenário
## (escurece o fundo e deixa os lutadores à vista); senão cobre tudo (clarão).
## Some em `duration` s; com duracao <= 0 fica até `fade_veil`.
static func veil(world: Node2D, color: Color, duration: float, behind_everyone := false) -> Node2D:
	var fx := _Veil.new()
	fx.color = color
	world.add_child(fx)
	if behind_everyone:
		world.move_child(fx, 1)
	if duration > 0:
		fade_veil(fx, duration)
	return fx


static func fade_veil(fx: Node2D, duration: float) -> void:
	var t := fx.create_tween()
	t.tween_property(fx, "modulate:a", 0.0, duration)
	t.tween_callback(fx.queue_free)


## Aura persistente em volta de um lutador (fica atrás do sprite e o
## acompanha). Ajuste `level` (0..3) para a intensidade e chame `pulsar()`
## para um clarão curto. Some sozinha quando o lutador cai.
static func aura(visual: FighterVisual, colors: Array[Color], label := "") -> Aura:
	var fx := Aura.new(visual, colors)
	fx.label = label
	visual.add_child(fx)
	visual.move_child(fx, 0)
	return fx


## Projétil de `from` até `to` com a cara do elemento `type` (Types).
## Devolve a duração do voo, para quem chama saber quando aplicar o golpe.
static func projectile(parent: Node, from: Vector2, to: Vector2, type: String, speed := 900.0, size := 1.0) -> float:
	var fx := _Projectile.new(type, Types.color(type), size)
	fx.position = from
	fx.direction = (to - from).normalized()
	parent.add_child(fx)
	var duration := maxf(0.08, from.distance_to(to) / speed)
	var t := fx.create_tween()
	t.tween_property(fx, "position", to, duration)
	t.tween_callback(fx.queue_free)
	return duration


## Impacto com o detalhe do elemento (faíscas na cor + uma marca do tipo).
static func elemental_impact(parent: Node, pos: Vector2, type: String, strength := 1.0) -> void:
	var color := Types.color(type)
	impact(parent, pos, color, strength)
	match type:
		Types.WATER, Types.POISON, Types.ACID:
			ring(parent, pos, color, 28.0 * strength)
		Types.ICE:
			impact(parent, pos, Color.WHITE, 0.6 * strength)
		Types.ELECTRICITY:
			lightning(parent, pos + Vector2(randf_range(-10, 10), -40), pos, color)
		Types.FIRE:
			impact(parent, pos + Vector2(0, -6), Color(1, 0.85, 0.3), 0.7 * strength)
		Types.NATURE:
			slash(parent, pos, color, 18.0 * strength, 0.8)


## Colchetes que se fecham em volta de `pos` (alvo sendo analisado).
static func aim(parent: Node, pos: Vector2, radius: float, color: Color, duration := 0.6) -> void:
	_play(parent, _Reticle.new(color, radius), pos, duration)


## Linha tracejada de `from` até `to` que pisca e some (varredura, entrega).
static func line(parent: Node, from: Vector2, to: Vector2, color: Color, duration := 0.5) -> void:
	var fx := _Line.new(color, to - from)
	_play(parent, fx, from, duration)


## Raio em zigue-zague de `from` até `to`.
static func lightning(parent: Node, from: Vector2, to: Vector2, color: Color) -> void:
	var fx := _Line.new(color, to - from)
	fx.zigzag = true
	_play(parent, fx, from, 0.25)


static func _px(v: float) -> float:
	return roundf(v / PIXEL) * PIXEL


static func _square(ci: CanvasItem, center: Vector2, side: float, color: Color) -> void:
	var l := maxf(PIXEL, _px(side))
	ci.draw_rect(Rect2((center / PIXEL).round() * PIXEL - Vector2(l, l) / 2, Vector2(l, l)), color)


static func _play(parent: Node, fx: _Effect, pos: Vector2, duration: float) -> void:
	fx.position = pos
	parent.add_child(fx)
	var t := fx.create_tween()
	t.tween_property(fx, "progress", 1.0, duration)
	t.tween_callback(fx.queue_free)


class _Effect extends Node2D:
	var color: Color
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()


class _Slash extends _Effect:
	var radius: float

	func _init(p_color: Color, p_radius: float) -> void:
		color = p_color
		radius = p_radius

	func _draw() -> void:
		# o arco cresce rápido e depois some pelo começo
		var ini := lerpf(-1.1, 0.9, maxf(0, progress - 0.35) / 0.65)
		var end := lerpf(-1.1, 0.9, minf(1, progress / 0.45))
		if end <= ini:
			return
		var center := Vector2(-radius * 0.55, 0)
		var a := 1.0 - maxf(0, progress - 0.6) / 0.4
		draw_arc(center, radius, ini, end, 10, Color(color, a), 4.0)
		draw_arc(center, radius - 4, ini + 0.15, end, 8, Color(1, 1, 1, a), 2.0)


class _Impact extends _Effect:
	var strength: float
	var _dirs: Array[Vector2] = []

	func _init(p_color: Color, p_strength: float) -> void:
		color = p_color
		strength = p_strength
		for i in 7:
			_dirs.append(Vector2.from_angle(randf() * TAU) * randf_range(18, 36) * strength)

	func _draw() -> void:
		var a := 1.0 - progress
		var side := roundf(lerpf(5, 2, progress))
		for d in _dirs:
			var p := (d * ease(progress, 0.4)).round()
			draw_rect(Rect2(p - Vector2(side, side) / 2, Vector2(side, side)), Color(color, a))
		if progress < 0.3:
			var l := roundf(14 * strength * (1.0 - progress / 0.3))
			draw_rect(Rect2(-l / 2, -1, l, 2), Color(1, 1, 1, a))
			draw_rect(Rect2(-1, -l / 2, 2, l), Color(1, 1, 1, a))


class _Ring extends _Effect:
	var radius: float

	func _init(p_color: Color, p_radius: float) -> void:
		color = p_color
		radius = p_radius

	func _draw() -> void:
		var r := lerpf(radius * 0.3, radius, ease(progress, 0.5))
		# poucos segmentos = cara de pixel art
		draw_arc(Vector2.ZERO, r, 0, TAU, 16, Color(color, 1.0 - progress), lerpf(5, 1, progress))


class _Charge extends _Effect:
	var colors: Array[Color]
	var radius: float
	var _particles := []  ## [direção, atraso, cor]

	func _init(p_colors: Array[Color], p_radius: float) -> void:
		colors = p_colors
		radius = p_radius
		for i in 26:
			_particles.append([Vector2.from_angle(randf() * TAU), randf() * 0.6, colors[i % colors.size()]])

	func _draw() -> void:
		# cada partícula sai da borda e chega ao centro; anéis encolhem junto
		for p: Array in _particles:
			var f := clampf((progress - p[1]) / 0.4, 0, 1)
			if f <= 0 or f >= 1:
				continue
			var pos: Vector2 = p[0] * radius * (1.0 - ease(f, 1.8))
			var particle_color: Color = p[2]
			CombatEffects._square(self, pos, 3 + 3 * (1 - f), Color(particle_color, 0.4 + 0.6 * f))
		for k in 2:
			var f := fposmod(progress * 2.0 + k * 0.5, 1.0)
			draw_arc(Vector2.ZERO, radius * (1.0 - f) * 0.8, 0, TAU, 16, Color(colors[0], 0.6 * f), 2.0)
		var core := CombatEffects._px(4 + 14 * progress)
		draw_rect(Rect2(-Vector2(core, core) / 2, Vector2(core, core)), Color(1, 1, 1, 0.5 + 0.5 * progress))


class _Veil extends Node2D:
	var color: Color

	func _draw() -> void:
		# um pouco maior que a tela, para o tremor não mostrar a borda
		draw_rect(Rect2(-Vector2(40, 40), CombatEffects.SCREEN + Vector2(80, 80)), color)


class Beam extends Node2D:
	var length := 0.0:
		set(v):
			length = v
			queue_redraw()
	var fading := 0.0
	var width: float
	var colors: Array  ## [brilho, borda, meio, nucleo]
	var sparks: float
	var distortion: float
	var distortion_color: Color
	var tip: Texture2D
	var _time := 0.0
	var _accumulated := 0.0
	var _particles := []  ## [posição, velocidade, vida, cor]

	func _init(style: Dictionary) -> void:
		width = style.width
		colors = style.colors
		sparks = style.get("sparks", 0.0)
		distortion = style.get("distortion", 0.0)
		distortion_color = style.get("distortion_color", Color(1, 0.2, 0.2))
		tip = style.get("tip")

	func _process(delta: float) -> void:
		_time += delta
		_accumulated += sparks * delta * (1.0 - fading)
		while _accumulated >= 1.0 and length > 0:
			_accumulated -= 1.0
			var side := 1.0 if randf() < 0.5 else -1.0
			_particles.append([Vector2(randf() * length, side * width * 0.4),
				Vector2(randf_range(-40, 80), side * randf_range(40, 120)), randf_range(0.25, 0.5),
				colors[randi() % 4]])
		for p: Array in _particles:
			p[0] += p[1] * delta
			p[2] -= delta
		_particles = _particles.filter(func(p: Array) -> bool: return p[2] > 0)
		queue_redraw()

	func _draw() -> void:
		if length <= 0:
			return
		var vis := 1.0 - fading
		# a espessura tremula um pixel e afina ao sumir
		var l := width * vis * (1.0 + 0.08 * sin(_time * 40.0))
		var layers := [[1.9, Color(colors[0], 0.28)], [1.0, colors[1]], [0.6, colors[2]], [0.28, colors[3]]]
		for c: Array in layers:
			var h := CombatEffects._px(l * c[0])
			if h > 0:
				draw_rect(Rect2(0, -h / 2, CombatEffects._px(length), h), Color(c[1], c[1].a * vis))
		# distorção: lascas que escapam do feixe, sorteadas de novo a cada ~50 ms
		if distortion > 0:
			var r := RandomNumberGenerator.new()
			r.seed = int(_time * 20.0)
			for i in int(10 * distortion):
				var x := CombatEffects._px(r.randf() * length)
				var y := CombatEffects._px(r.randf_range(0.5, 1.2) * l * (1 if r.randf() < 0.5 else -1))
				draw_rect(Rect2(x, y, CombatEffects._px(r.randf_range(12, 48)), CombatEffects.PIXEL), Color(distortion_color, 0.8 * vis))
		for p: Array in _particles:
			CombatEffects._square(self, p[0], 3, Color(p[3], clampf(p[2] * 3.0, 0, 1)))
		# a lâmina na ponta, enquanto o feixe avança
		if tip and fading == 0:
			var esc := maxf(1.0, roundf(l * 1.4 / tip.get_height()))
			var tip_size := Vector2(tip.get_size()) * esc
			draw_texture_rect(tip, Rect2(Vector2(length - tip_size.x * 0.5, -tip_size.y / 2), tip_size), false)


class Aura extends Node2D:
	## 0 = x2 ... 3 = x20
	var level := 0
	var label := ""
	var colors: Array[Color]  ## [fora, dentro, faísca]
	var _visual: FighterVisual
	var _time := 0.0
	var _pulso := 0.0
	var _accumulated := 0.0
	var _particles := []  ## [posição, velocidade, vida, cor]
	var _radii := []  ## [pontos, vida]

	const SPARKS_PER_S := [0.0, 5.0, 11.0, 18.0]

	func _init(p_visual: FighterVisual, p_colors: Array[Color]) -> void:
		_visual = p_visual
		colors = p_colors

	func pulsar() -> void:
		_pulso = 1.0

	func _process(delta: float) -> void:
		if not _visual.combatant.is_alive():
			queue_free()
			return
		_time += delta
		_pulso = maxf(0.0, _pulso - delta * 2.5)
		var alt := _visual.height
		_accumulated += SPARKS_PER_S[level] * (1.0 + _pulso * 2.0) * delta
		while _accumulated >= 1.0:
			_accumulated -= 1.0
			var white := level >= 2 and randf() < 0.25
			_particles.append([Vector2(randf_range(-30, 30), -randf_range(0.1, 0.9) * alt),
				Vector2(randf_range(-12, 12), -randf_range(60, 120)), randf_range(0.35, 0.7),
				Color.WHITE if white else colors[2]])
		for p: Array in _particles:
			p[0] += p[1] * delta
			p[2] -= delta
		_particles = _particles.filter(func(p: Array) -> bool: return p[2] > 0)
		# x10+: estalos de energia em zigue-zague perto do corpo
		if level >= 2 and randf() < delta * (3.0 if level == 2 else 6.0):
			var ini := Vector2(randf_range(-28, 28), -randf_range(0.2, 0.9) * alt)
			var pts := PackedVector2Array([ini])
			for i in 3:
				pts.append(pts[-1] + Vector2(randf_range(-9, 9), randf_range(-12, -3)).snapped(Vector2(3, 3)))
			_radii.append([pts, 0.12])
		for r: Array in _radii:
			r[1] -= delta
		_radii = _radii.filter(func(r: Array) -> bool: return r[1] > 0)
		# x20: a aura treme, instável
		position.x = CombatEffects._px(randf_range(-1.5, 1.5)) if level >= 3 else 0.0
		queue_redraw()

	func _draw() -> void:
		var alt := _visual.height
		var n := float(level)
		var p := _pulso
		# chamas atrás do corpo: colunas de 3 px com o topo tremulando
		# fraca no x2, nunca opaca: o sprite precisa continuar legível
		_flames(26.0 + 5.0 * n + 8.0 * p, alt * (0.98 + 0.06 * n) + 12.0 * p, Color(colors[0], 0.1 + 0.05 * n + 0.2 * p), 0.0)
		_flames(20.0 + 3.0 * n, alt * (0.92 + 0.04 * n), Color(colors[1], 0.12 + 0.06 * n + 0.2 * p), 1.7)
		if level >= 3:
			_flames(14.0, alt * 0.85, Color(1, 0.92, 0.9, 0.22), 3.1)
			# linhas de distorção que cortam a aura de lado
			var r := RandomNumberGenerator.new()
			r.seed = int(_time * 12.0)
			for i in 3:
				var y := CombatEffects._px(-r.randf_range(0.1, 1.0) * alt)
				var w := CombatEffects._px(r.randf_range(40, 80))
				draw_rect(Rect2(-w / 2 + CombatEffects._px(r.randf_range(-9, 9)), y, w, 3), Color(colors[0], 0.45))
		for pt: Array in _particles:
			CombatEffects._square(self, pt[0], 3, Color(pt[3], clampf(pt[2] * 2.5, 0, 1)))
		for r: Array in _radii:
			draw_polyline(r[0], Color(1, 0.95, 0.95, r[1] / 0.12), 2.0)
		if label != "":
			UIStyle.text(self, Vector2(-60, -alt - 34), label, 12, colors[1].lightened(0.25), 120, HORIZONTAL_ALIGNMENT_CENTER)

	func _flames(half_width: float, height: float, color: Color, phase: float) -> void:
		var x := -CombatEffects._px(half_width)
		while x <= half_width:
			var nx := x / half_width
			var h := height * sqrt(maxf(0.0, 1.0 - nx * nx * nx * nx))
			h += 6.0 * sin(_time * 9.0 + x * 0.37 + phase) + 4.0 * sin(_time * 14.0 + x * 0.13 + phase)
			h = CombatEffects._px(h)
			if h > 0:
				draw_rect(Rect2(x, -h, 3, h + 3), color)
			x += 3.0


class _Projectile extends Node2D:
	var type: String
	var color: Color
	var size: float
	var direction := Vector2.RIGHT
	var _time := 0.0
	var _trail: Array[Vector2] = []  ## posições anteriores, em coordenadas do mundo

	func _init(p_type: String, p_color: Color, p_size: float) -> void:
		type = p_type
		color = p_color
		size = p_size

	func _process(delta: float) -> void:
		_time += delta
		_trail.push_front(global_position)
		if _trail.size() > 6:
			_trail.pop_back()
		queue_redraw()

	func _draw() -> void:
		var l := CombatEffects.PIXEL * roundf(2 * size)
		# rastro: o jeito muda com o elemento
		for i in range(1, _trail.size()):
			var p := _trail[i] - global_position
			var a := 1.0 - float(i) / _trail.size()
			match type:
				Types.FIRE:
					p += Vector2(0, -i * 2.0)  # brasas sobem
				Types.WATER, Types.ACID:
					p += Vector2(0, i * 2.0)  # gotas caem
				Types.ELECTRICITY:
					p += Vector2(0, 6.0 if i % 2 else -6.0)  # zigue-zague
				Types.NATURE:
					p += Vector2(0, sin(_time * 20.0 + i) * 6.0)  # folhas girando
				Types.POISON:
					p += Vector2(0, -i * 1.5)  # bolhas sobem
			CombatEffects._square(self, p, l * (0.4 + 0.5 * a), Color(color, a * 0.8))
		# núcleo: forma do elemento
		match type:
			Types.ICE:
				var d := PackedVector2Array([Vector2(0, -l * 1.2), Vector2(l, 0), Vector2(0, l * 1.2), Vector2(-l, 0)])
				draw_colored_polygon(d, color)
				draw_rect(Rect2(-1.5, -1.5, 3, 3), Color.WHITE)
			Types.WATER:
				draw_rect(Rect2(-l, -l / 2, l * 2, l), color)
				draw_rect(Rect2(-l / 2, -l, l, l * 2), color)
				draw_rect(Rect2(-1.5, -1.5, 3, 3), Color.WHITE)
			Types.POISON:
				draw_arc(Vector2.ZERO, l, 0, TAU, 8, color, 3.0)
			_:
				draw_rect(Rect2(-l, -l, l * 2, l * 2), color)
				draw_rect(Rect2(-l / 2, -l / 2, l, l), color.lightened(0.6))


class _Reticle extends _Effect:
	var radius: float

	func _init(p_color: Color, p_radius: float) -> void:
		color = p_color
		radius = p_radius

	func _draw() -> void:
		var r := CombatEffects._px(lerpf(radius * 1.6, radius, ease(minf(1.0, progress * 1.6), 0.4)))
		var a := 1.0 if progress < 0.75 else (1.0 - progress) / 0.25
		# pisca rápido no começo, como um scanner travando no alvo
		if progress < 0.4 and int(progress * 30) % 2 == 0:
			a *= 0.4
		var c := Color(color, a)
		var b := CombatEffects.PIXEL * 4
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var corner := Vector2(r * sx, r * sy)
				draw_rect(Rect2(corner + Vector2(-b if sx > 0 else 0, -1.5), Vector2(b, 3)), c)
				draw_rect(Rect2(corner + Vector2(-1.5, -b if sy > 0 else 0), Vector2(3, b)), c)


class _Line extends _Effect:
	var vector: Vector2
	var zigzag := false

	func _init(p_color: Color, p_vector: Vector2) -> void:
		color = p_color
		vector = p_vector

	func _draw() -> void:
		var a := 1.0 - progress
		if zigzag:
			var pts := PackedVector2Array([Vector2.ZERO])
			var n := 5
			var side := vector.orthogonal().normalized()
			for i in range(1, n):
				pts.append(vector * i / n + side * (8.0 if i % 2 else -8.0))
			pts.append(vector)
			draw_polyline(pts, Color(color, a), 3.0)
			draw_polyline(pts, Color(1, 1, 1, a), 1.0)
			return
		# tracejado que corre na direção do alvo
		var comp := vector.length()
		var dir := vector / comp
		var step := 12.0
		var x := fposmod(progress * 60.0, step)
		while x < comp:
			draw_line(dir * x, dir * minf(comp, x + 6.0), Color(color, a * 0.85), 2.0)
			x += step

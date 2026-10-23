class_name EfeitosCombate
extends RefCounted
## Efeitos da arena: números flutuantes, rastro de corte, faíscas de impacto,
## anel de energia, feixe, carga, aura e véus de tela. Cada um é um nó leve
## que se desenha com _draw, anima por tween e se apaga sozinho (a aura fica
## até ser removida). Quem chama escolhe a cor/forma de cada golpe; aqui só
## ficam as peças. Tudo é desenhado numa grade de PIXEL px, a mesma escala
## dos sprites.

const PIXEL := 3.0
const TELA := Vector2(960, 540)

## Estilo de cada tipo de número: [cor, tamanho].
const NUMEROS := {
	"dano": [EstiloUI.DANO, 24],
	"fraco": [EstiloUI.DANO_FRACO, 18],
	"critico": [EstiloUI.DANO_CRITICO, 30],
	"recebido": [EstiloUI.DANO_RECEBIDO, 24],
	"cura": [EstiloUI.CURA, 22],
	"dreno": [EstiloUI.DRENO, 20],
	"energia": [EstiloUI.ENERGIA, 16],
	"efetivo": [EstiloUI.DANO_CRITICO, 13],
	"pouco_efetivo": [EstiloUI.TEXTO_FRACO, 12],
	"escudo": [EstiloUI.PONTO, 16],
	"aviso": [EstiloUI.OURO, 13],
	"nivel": [EstiloUI.OURO, 18],
}


static func numero(pai: Node, pos: Vector2, texto: String, tipo := "dano") -> void:
	var estilo: Array = NUMEROS.get(tipo, NUMEROS.dano)
	var l := EstiloUI.label(texto, estilo[1], estilo[0], 7)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(90, 36)
	l.pivot_offset = l.size / 2
	l.position = pos + Vector2(-45 + randf_range(-10, 10), -66)
	l.scale = Vector2(1.5, 1.5)
	pai.add_child(l)
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "position:y", l.position.y - 34, 0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(l, "modulate:a", 0.0, 0.25).set_delay(0.55)
	t.chain().tween_callback(l.queue_free)


## Rastro curvo de lâmina, de cima para baixo, passando por `pos`.
## `angulo` gira o arco (golpes em sequência saem de direções diferentes).
static func corte(pai: Node, pos: Vector2, cor := Color.WHITE, raio := 46.0, angulo := 0.0) -> void:
	var fx := _Corte.new(cor, raio)
	fx.rotation = angulo
	_tocar(pai, fx, pos, 0.22)


## Faíscas quadradas saindo do ponto de impacto.
static func impacto(pai: Node, pos: Vector2, cor := Color.WHITE, forca := 1.0) -> void:
	var fx := _Impacto.new(cor, forca)
	_tocar(pai, fx, pos, 0.28)


## Anel que se expande (ativação de técnica, carga de golpe...).
static func anel(pai: Node, pos: Vector2, cor: Color, raio := 70.0) -> void:
	_tocar(pai, _Anel.new(cor, raio), pos, 0.45)


## Partículas que convergem para `pos` durante `duracao` (carga de energia).
static func carga(pai: Node, pos: Vector2, cores: Array[Color], duracao: float, raio := 140.0) -> void:
	_tocar(pai, _Carga.new(cores, raio), pos, duracao)


## Feixe de energia saindo de `origem` na direção `angulo`, com a ponta
## avançando a `velocidade` px/s até `alcance`; segura `segura` s e some.
## Um alvo a d px da origem é alcançado em d / velocidade segundos.
## `estilo`: {"largura", "cores": [brilho, borda, meio, nucleo], "faiscas"
## (por segundo), "distorcao" (0..1), "cor_distorcao"?, "ponta" (Texture2D)?}.
static func feixe(pai: Node, origem: Vector2, angulo: float, alcance: float, velocidade: float, estilo: Dictionary, segura := 0.15) -> Node2D:
	var fx := Feixe.new(estilo)
	fx.position = origem
	fx.rotation = angulo
	pai.add_child(fx)
	var t := fx.create_tween()
	t.tween_property(fx, "comprimento", alcance, alcance / velocidade)
	t.tween_interval(segura)
	t.tween_property(fx, "sumindo", 1.0, 0.25).set_ease(Tween.EASE_IN)
	t.tween_callback(fx.queue_free)
	return fx


## Véu de tela inteira. `atras_de_todos` põe o véu logo acima do cenário
## (escurece o fundo e deixa os lutadores à vista); senão cobre tudo (clarão).
## Some em `duracao` s; com duracao <= 0 fica até `sumir_veu`.
static func veu(mundo: Node2D, cor: Color, duracao: float, atras_de_todos := false) -> Node2D:
	var fx := _Veu.new()
	fx.cor = cor
	mundo.add_child(fx)
	if atras_de_todos:
		mundo.move_child(fx, 1)
	if duracao > 0:
		sumir_veu(fx, duracao)
	return fx


static func sumir_veu(fx: Node2D, duracao: float) -> void:
	var t := fx.create_tween()
	t.tween_property(fx, "modulate:a", 0.0, duracao)
	t.tween_callback(fx.queue_free)


## Aura persistente em volta de um lutador (fica atrás do sprite e o
## acompanha). Ajuste `nivel` (0..3) para a intensidade e chame `pulsar()`
## para um clarão curto. Some sozinha quando o lutador cai.
static func aura(visual: VisualLutador, cores: Array[Color], rotulo := "") -> Aura:
	var fx := Aura.new(visual, cores)
	fx.rotulo = rotulo
	visual.add_child(fx)
	visual.move_child(fx, 0)
	return fx


## Projétil de `de` até `ate` com a cara do elemento `tipo` (Tipos).
## Devolve a duração do voo, para quem chama saber quando aplicar o golpe.
static func projetil(pai: Node, de: Vector2, ate: Vector2, tipo: String, velocidade := 900.0, tamanho := 1.0) -> float:
	var fx := _Projetil.new(tipo, Tipos.cor(tipo), tamanho)
	fx.position = de
	fx.direcao = (ate - de).normalized()
	pai.add_child(fx)
	var duracao := maxf(0.08, de.distance_to(ate) / velocidade)
	var t := fx.create_tween()
	t.tween_property(fx, "position", ate, duracao)
	t.tween_callback(fx.queue_free)
	return duracao


## Impacto com o detalhe do elemento (faíscas na cor + uma marca do tipo).
static func impacto_elemental(pai: Node, pos: Vector2, tipo: String, forca := 1.0) -> void:
	var cor := Tipos.cor(tipo)
	impacto(pai, pos, cor, forca)
	match tipo:
		Tipos.AGUA, Tipos.VENENO, Tipos.ACIDO:
			anel(pai, pos, cor, 28.0 * forca)
		Tipos.GELO:
			impacto(pai, pos, Color.WHITE, 0.6 * forca)
		Tipos.ELETRICIDADE:
			relampago(pai, pos + Vector2(randf_range(-10, 10), -40), pos, cor)
		Tipos.FOGO:
			impacto(pai, pos + Vector2(0, -6), Color(1, 0.85, 0.3), 0.7 * forca)
		Tipos.NATUREZA:
			corte(pai, pos, cor, 18.0 * forca, 0.8)


## Colchetes que se fecham em volta de `pos` (alvo sendo analisado).
static func mira(pai: Node, pos: Vector2, raio: float, cor: Color, duracao := 0.6) -> void:
	_tocar(pai, _Mira.new(cor, raio), pos, duracao)


## Linha tracejada de `de` até `ate` que pisca e some (varredura, entrega).
static func linha(pai: Node, de: Vector2, ate: Vector2, cor: Color, duracao := 0.5) -> void:
	var fx := _Linha.new(cor, ate - de)
	_tocar(pai, fx, de, duracao)


## Raio em zigue-zague de `de` até `ate`.
static func relampago(pai: Node, de: Vector2, ate: Vector2, cor: Color) -> void:
	var fx := _Linha.new(cor, ate - de)
	fx.zigue = true
	_tocar(pai, fx, de, 0.25)


static func _px(v: float) -> float:
	return roundf(v / PIXEL) * PIXEL


static func _quadrado(ci: CanvasItem, centro: Vector2, lado: float, cor: Color) -> void:
	var l := maxf(PIXEL, _px(lado))
	ci.draw_rect(Rect2((centro / PIXEL).round() * PIXEL - Vector2(l, l) / 2, Vector2(l, l)), cor)


static func _tocar(pai: Node, fx: _Efeito, pos: Vector2, duracao: float) -> void:
	fx.position = pos
	pai.add_child(fx)
	var t := fx.create_tween()
	t.tween_property(fx, "progresso", 1.0, duracao)
	t.tween_callback(fx.queue_free)


class _Efeito extends Node2D:
	var cor: Color
	var progresso := 0.0:
		set(v):
			progresso = v
			queue_redraw()


class _Corte extends _Efeito:
	var raio: float

	func _init(p_cor: Color, p_raio: float) -> void:
		cor = p_cor
		raio = p_raio

	func _draw() -> void:
		# o arco cresce rápido e depois some pelo começo
		var ini := lerpf(-1.1, 0.9, maxf(0, progresso - 0.35) / 0.65)
		var fim := lerpf(-1.1, 0.9, minf(1, progresso / 0.45))
		if fim <= ini:
			return
		var centro := Vector2(-raio * 0.55, 0)
		var a := 1.0 - maxf(0, progresso - 0.6) / 0.4
		draw_arc(centro, raio, ini, fim, 10, Color(cor, a), 4.0)
		draw_arc(centro, raio - 4, ini + 0.15, fim, 8, Color(1, 1, 1, a), 2.0)


class _Impacto extends _Efeito:
	var forca: float
	var _dirs: Array[Vector2] = []

	func _init(p_cor: Color, p_forca: float) -> void:
		cor = p_cor
		forca = p_forca
		for i in 7:
			_dirs.append(Vector2.from_angle(randf() * TAU) * randf_range(18, 36) * forca)

	func _draw() -> void:
		var a := 1.0 - progresso
		var lado := roundf(lerpf(5, 2, progresso))
		for d in _dirs:
			var p := (d * ease(progresso, 0.4)).round()
			draw_rect(Rect2(p - Vector2(lado, lado) / 2, Vector2(lado, lado)), Color(cor, a))
		if progresso < 0.3:
			var l := roundf(14 * forca * (1.0 - progresso / 0.3))
			draw_rect(Rect2(-l / 2, -1, l, 2), Color(1, 1, 1, a))
			draw_rect(Rect2(-1, -l / 2, 2, l), Color(1, 1, 1, a))


class _Anel extends _Efeito:
	var raio: float

	func _init(p_cor: Color, p_raio: float) -> void:
		cor = p_cor
		raio = p_raio

	func _draw() -> void:
		var r := lerpf(raio * 0.3, raio, ease(progresso, 0.5))
		# poucos segmentos = cara de pixel art
		draw_arc(Vector2.ZERO, r, 0, TAU, 16, Color(cor, 1.0 - progresso), lerpf(5, 1, progresso))


class _Carga extends _Efeito:
	var cores: Array[Color]
	var raio: float
	var _particulas := []  ## [direção, atraso, cor]

	func _init(p_cores: Array[Color], p_raio: float) -> void:
		cores = p_cores
		raio = p_raio
		for i in 26:
			_particulas.append([Vector2.from_angle(randf() * TAU), randf() * 0.6, cores[i % cores.size()]])

	func _draw() -> void:
		# cada partícula sai da borda e chega ao centro; anéis encolhem junto
		for p: Array in _particulas:
			var f := clampf((progresso - p[1]) / 0.4, 0, 1)
			if f <= 0 or f >= 1:
				continue
			var pos: Vector2 = p[0] * raio * (1.0 - ease(f, 1.8))
			var cor: Color = p[2]
			EfeitosCombate._quadrado(self, pos, 3 + 3 * (1 - f), Color(cor, 0.4 + 0.6 * f))
		for k in 2:
			var f := fposmod(progresso * 2.0 + k * 0.5, 1.0)
			draw_arc(Vector2.ZERO, raio * (1.0 - f) * 0.8, 0, TAU, 16, Color(cores[0], 0.6 * f), 2.0)
		var nucleo := EfeitosCombate._px(4 + 14 * progresso)
		draw_rect(Rect2(-Vector2(nucleo, nucleo) / 2, Vector2(nucleo, nucleo)), Color(1, 1, 1, 0.5 + 0.5 * progresso))


class _Veu extends Node2D:
	var cor: Color

	func _draw() -> void:
		# um pouco maior que a tela, para o tremor não mostrar a borda
		draw_rect(Rect2(-Vector2(40, 40), EfeitosCombate.TELA + Vector2(80, 80)), cor)


class Feixe extends Node2D:
	var comprimento := 0.0:
		set(v):
			comprimento = v
			queue_redraw()
	var sumindo := 0.0
	var largura: float
	var cores: Array  ## [brilho, borda, meio, nucleo]
	var faiscas: float
	var distorcao: float
	var cor_distorcao: Color
	var ponta: Texture2D
	var _tempo := 0.0
	var _acumulado := 0.0
	var _particulas := []  ## [posição, velocidade, vida, cor]

	func _init(estilo: Dictionary) -> void:
		largura = estilo.largura
		cores = estilo.cores
		faiscas = estilo.get("faiscas", 0.0)
		distorcao = estilo.get("distorcao", 0.0)
		cor_distorcao = estilo.get("cor_distorcao", Color(1, 0.2, 0.2))
		ponta = estilo.get("ponta")

	func _process(delta: float) -> void:
		_tempo += delta
		_acumulado += faiscas * delta * (1.0 - sumindo)
		while _acumulado >= 1.0 and comprimento > 0:
			_acumulado -= 1.0
			var lado := 1.0 if randf() < 0.5 else -1.0
			_particulas.append([Vector2(randf() * comprimento, lado * largura * 0.4),
				Vector2(randf_range(-40, 80), lado * randf_range(40, 120)), randf_range(0.25, 0.5),
				cores[randi() % 4]])
		for p: Array in _particulas:
			p[0] += p[1] * delta
			p[2] -= delta
		_particulas = _particulas.filter(func(p: Array) -> bool: return p[2] > 0)
		queue_redraw()

	func _draw() -> void:
		if comprimento <= 0:
			return
		var vis := 1.0 - sumindo
		# a espessura tremula um pixel e afina ao sumir
		var l := largura * vis * (1.0 + 0.08 * sin(_tempo * 40.0))
		var camadas := [[1.9, Color(cores[0], 0.28)], [1.0, cores[1]], [0.6, cores[2]], [0.28, cores[3]]]
		for c: Array in camadas:
			var h := EfeitosCombate._px(l * c[0])
			if h > 0:
				draw_rect(Rect2(0, -h / 2, EfeitosCombate._px(comprimento), h), Color(c[1], c[1].a * vis))
		# distorção: lascas que escapam do feixe, sorteadas de novo a cada ~50 ms
		if distorcao > 0:
			var r := RandomNumberGenerator.new()
			r.seed = int(_tempo * 20.0)
			for i in int(10 * distorcao):
				var x := EfeitosCombate._px(r.randf() * comprimento)
				var y := EfeitosCombate._px(r.randf_range(0.5, 1.2) * l * (1 if r.randf() < 0.5 else -1))
				draw_rect(Rect2(x, y, EfeitosCombate._px(r.randf_range(12, 48)), EfeitosCombate.PIXEL), Color(cor_distorcao, 0.8 * vis))
		for p: Array in _particulas:
			EfeitosCombate._quadrado(self, p[0], 3, Color(p[3], clampf(p[2] * 3.0, 0, 1)))
		# a lâmina na ponta, enquanto o feixe avança
		if ponta and sumindo == 0:
			var esc := maxf(1.0, roundf(l * 1.4 / ponta.get_height()))
			var tam := Vector2(ponta.get_size()) * esc
			draw_texture_rect(ponta, Rect2(Vector2(comprimento - tam.x * 0.5, -tam.y / 2), tam), false)


class Aura extends Node2D:
	## 0 = x2 ... 3 = x20
	var nivel := 0
	var rotulo := ""
	var cores: Array[Color]  ## [fora, dentro, faísca]
	var _visual: VisualLutador
	var _tempo := 0.0
	var _pulso := 0.0
	var _acumulado := 0.0
	var _particulas := []  ## [posição, velocidade, vida, cor]
	var _raios := []  ## [pontos, vida]

	const FAISCAS_POR_S := [0.0, 5.0, 11.0, 18.0]

	func _init(p_visual: VisualLutador, p_cores: Array[Color]) -> void:
		_visual = p_visual
		cores = p_cores

	func pulsar() -> void:
		_pulso = 1.0

	func _process(delta: float) -> void:
		if not _visual.combatente.vivo():
			queue_free()
			return
		_tempo += delta
		_pulso = maxf(0.0, _pulso - delta * 2.5)
		var alt := _visual.altura
		_acumulado += FAISCAS_POR_S[nivel] * (1.0 + _pulso * 2.0) * delta
		while _acumulado >= 1.0:
			_acumulado -= 1.0
			var branca := nivel >= 2 and randf() < 0.25
			_particulas.append([Vector2(randf_range(-30, 30), -randf_range(0.1, 0.9) * alt),
				Vector2(randf_range(-12, 12), -randf_range(60, 120)), randf_range(0.35, 0.7),
				Color.WHITE if branca else cores[2]])
		for p: Array in _particulas:
			p[0] += p[1] * delta
			p[2] -= delta
		_particulas = _particulas.filter(func(p: Array) -> bool: return p[2] > 0)
		# x10+: estalos de energia em zigue-zague perto do corpo
		if nivel >= 2 and randf() < delta * (3.0 if nivel == 2 else 6.0):
			var ini := Vector2(randf_range(-28, 28), -randf_range(0.2, 0.9) * alt)
			var pts := PackedVector2Array([ini])
			for i in 3:
				pts.append(pts[-1] + Vector2(randf_range(-9, 9), randf_range(-12, -3)).snapped(Vector2(3, 3)))
			_raios.append([pts, 0.12])
		for r: Array in _raios:
			r[1] -= delta
		_raios = _raios.filter(func(r: Array) -> bool: return r[1] > 0)
		# x20: a aura treme, instável
		position.x = EfeitosCombate._px(randf_range(-1.5, 1.5)) if nivel >= 3 else 0.0
		queue_redraw()

	func _draw() -> void:
		var alt := _visual.altura
		var n := float(nivel)
		var p := _pulso
		# chamas atrás do corpo: colunas de 3 px com o topo tremulando
		# fraca no x2, nunca opaca: o sprite precisa continuar legível
		_chamas(26.0 + 5.0 * n + 8.0 * p, alt * (0.98 + 0.06 * n) + 12.0 * p, Color(cores[0], 0.1 + 0.05 * n + 0.2 * p), 0.0)
		_chamas(20.0 + 3.0 * n, alt * (0.92 + 0.04 * n), Color(cores[1], 0.12 + 0.06 * n + 0.2 * p), 1.7)
		if nivel >= 3:
			_chamas(14.0, alt * 0.85, Color(1, 0.92, 0.9, 0.22), 3.1)
			# linhas de distorção que cortam a aura de lado
			var r := RandomNumberGenerator.new()
			r.seed = int(_tempo * 12.0)
			for i in 3:
				var y := EfeitosCombate._px(-r.randf_range(0.1, 1.0) * alt)
				var w := EfeitosCombate._px(r.randf_range(40, 80))
				draw_rect(Rect2(-w / 2 + EfeitosCombate._px(r.randf_range(-9, 9)), y, w, 3), Color(cores[0], 0.45))
		for pt: Array in _particulas:
			EfeitosCombate._quadrado(self, pt[0], 3, Color(pt[3], clampf(pt[2] * 2.5, 0, 1)))
		for r: Array in _raios:
			draw_polyline(r[0], Color(1, 0.95, 0.95, r[1] / 0.12), 2.0)
		if rotulo != "":
			EstiloUI.texto(self, Vector2(-60, -alt - 34), rotulo, 12, cores[1].lightened(0.25), 120, HORIZONTAL_ALIGNMENT_CENTER)

	func _chamas(meia_largura: float, altura: float, cor: Color, fase: float) -> void:
		var x := -EfeitosCombate._px(meia_largura)
		while x <= meia_largura:
			var nx := x / meia_largura
			var h := altura * sqrt(maxf(0.0, 1.0 - nx * nx * nx * nx))
			h += 6.0 * sin(_tempo * 9.0 + x * 0.37 + fase) + 4.0 * sin(_tempo * 14.0 + x * 0.13 + fase)
			h = EfeitosCombate._px(h)
			if h > 0:
				draw_rect(Rect2(x, -h, 3, h + 3), cor)
			x += 3.0


class _Projetil extends Node2D:
	var tipo: String
	var cor: Color
	var tamanho: float
	var direcao := Vector2.RIGHT
	var _tempo := 0.0
	var _rastro: Array[Vector2] = []  ## posições anteriores, em coordenadas do mundo

	func _init(p_tipo: String, p_cor: Color, p_tamanho: float) -> void:
		tipo = p_tipo
		cor = p_cor
		tamanho = p_tamanho

	func _process(delta: float) -> void:
		_tempo += delta
		_rastro.push_front(global_position)
		if _rastro.size() > 6:
			_rastro.pop_back()
		queue_redraw()

	func _draw() -> void:
		var l := EfeitosCombate.PIXEL * roundf(2 * tamanho)
		# rastro: o jeito muda com o elemento
		for i in range(1, _rastro.size()):
			var p := _rastro[i] - global_position
			var a := 1.0 - float(i) / _rastro.size()
			match tipo:
				Tipos.FOGO:
					p += Vector2(0, -i * 2.0)  # brasas sobem
				Tipos.AGUA, Tipos.ACIDO:
					p += Vector2(0, i * 2.0)  # gotas caem
				Tipos.ELETRICIDADE:
					p += Vector2(0, 6.0 if i % 2 else -6.0)  # zigue-zague
				Tipos.NATUREZA:
					p += Vector2(0, sin(_tempo * 20.0 + i) * 6.0)  # folhas girando
				Tipos.VENENO:
					p += Vector2(0, -i * 1.5)  # bolhas sobem
			EfeitosCombate._quadrado(self, p, l * (0.4 + 0.5 * a), Color(cor, a * 0.8))
		# núcleo: forma do elemento
		match tipo:
			Tipos.GELO:
				var d := PackedVector2Array([Vector2(0, -l * 1.2), Vector2(l, 0), Vector2(0, l * 1.2), Vector2(-l, 0)])
				draw_colored_polygon(d, cor)
				draw_rect(Rect2(-1.5, -1.5, 3, 3), Color.WHITE)
			Tipos.AGUA:
				draw_rect(Rect2(-l, -l / 2, l * 2, l), cor)
				draw_rect(Rect2(-l / 2, -l, l, l * 2), cor)
				draw_rect(Rect2(-1.5, -1.5, 3, 3), Color.WHITE)
			Tipos.VENENO:
				draw_arc(Vector2.ZERO, l, 0, TAU, 8, cor, 3.0)
			_:
				draw_rect(Rect2(-l, -l, l * 2, l * 2), cor)
				draw_rect(Rect2(-l / 2, -l / 2, l, l), cor.lightened(0.6))


class _Mira extends _Efeito:
	var raio: float

	func _init(p_cor: Color, p_raio: float) -> void:
		cor = p_cor
		raio = p_raio

	func _draw() -> void:
		var r := EfeitosCombate._px(lerpf(raio * 1.6, raio, ease(minf(1.0, progresso * 1.6), 0.4)))
		var a := 1.0 if progresso < 0.75 else (1.0 - progresso) / 0.25
		# pisca rápido no começo, como um scanner travando no alvo
		if progresso < 0.4 and int(progresso * 30) % 2 == 0:
			a *= 0.4
		var c := Color(cor, a)
		var b := EfeitosCombate.PIXEL * 4
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var canto := Vector2(r * sx, r * sy)
				draw_rect(Rect2(canto + Vector2(-b if sx > 0 else 0, -1.5), Vector2(b, 3)), c)
				draw_rect(Rect2(canto + Vector2(-1.5, -b if sy > 0 else 0), Vector2(3, b)), c)


class _Linha extends _Efeito:
	var vetor: Vector2
	var zigue := false

	func _init(p_cor: Color, p_vetor: Vector2) -> void:
		cor = p_cor
		vetor = p_vetor

	func _draw() -> void:
		var a := 1.0 - progresso
		if zigue:
			var pts := PackedVector2Array([Vector2.ZERO])
			var n := 5
			var lado := vetor.orthogonal().normalized()
			for i in range(1, n):
				pts.append(vetor * i / n + lado * (8.0 if i % 2 else -8.0))
			pts.append(vetor)
			draw_polyline(pts, Color(cor, a), 3.0)
			draw_polyline(pts, Color(1, 1, 1, a), 1.0)
			return
		# tracejado que corre na direção do alvo
		var comp := vetor.length()
		var dir := vetor / comp
		var passo := 12.0
		var x := fposmod(progresso * 60.0, passo)
		while x < comp:
			draw_line(dir * x, dir * minf(comp, x + 6.0), Color(cor, a * 0.85), 2.0)
			x += passo

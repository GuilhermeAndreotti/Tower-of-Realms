class_name SeletorRadial
extends Node2D
## Seletor de opções em anel em volta de um lutador: faz parte do personagem
## na arena (é filho do visual dele), não da HUD. O anel gira como um tambor
## e a opção em foco fica sempre no topo. A batalha diz as opções, qual está
## em foco e o motivo de cada uma não servir; o mouse volta por sinais.

signal opcao_focada(indice: int)
signal opcao_clicada(indice: int)

const RAIO := 57.0
const LADO := 21.0  ## gema de cada opção, na grade de 3 px
const PIXEL := EfeitosCombate.PIXEL

var _opcoes: Array = []
var _indice := 0
var _motivos: Array[String] = []
var _abertura := 0.0  ## 0 = recolhido na âncora, 1 = anel aberto
var _giro := 0.0  ## ângulo do tambor, animado até deixar a opção em foco no topo
var _tempo := 0.0


func _ready() -> void:
	z_index = 10  # por cima dos lutadores vizinhos
	create_tween().tween_property(self, "_abertura", 1.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func mostrar(opcoes: Array, indice: int, motivos: Array[String]) -> void:
	var primeira := _opcoes.is_empty()
	_opcoes = opcoes
	_indice = indice
	_motivos = motivos
	if primeira:
		_giro = _giro_alvo()


## Recolhe as gemas para a âncora e some.
func fechar() -> void:
	set_process_unhandled_input(false)
	var t := create_tween()
	t.tween_property(self, "_abertura", 0.0, 0.14).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)


func _giro_alvo() -> float:
	return TAU * _indice / maxf(1, _opcoes.size())


func _posicao(i: int) -> Vector2:
	var angulo := -PI / 2 + TAU * i / _opcoes.size() - _giro
	return (Vector2.from_angle(angulo) * RAIO * _abertura / PIXEL).round() * PIXEL


func _process(delta: float) -> void:
	_tempo += delta
	_giro = lerp_angle(_giro, _giro_alvo(), minf(1.0, delta * 14.0))
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _opcoes.is_empty() or _abertura < 0.9:
		return
	var sob := _opcao_sob(get_local_mouse_position())
	if sob < 0:
		return
	if event is InputEventMouseMotion and sob != _indice:
		opcao_focada.emit(sob)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		opcao_clicada.emit(sob)


func _opcao_sob(ponto: Vector2) -> int:
	for i in _opcoes.size():
		if ponto.distance_to(_posicao(i)) < LADO * 0.7:
			return i
	return -1


func _draw() -> void:
	if _opcoes.is_empty():
		return
	var a := _abertura
	var foco: Dictionary = _opcoes[_indice]
	var cor_foco: Color = foco.get("cor", EstiloUI.OURO)
	# disco escuro para dar leitura sobre o cenário, e o trilho do tambor
	draw_circle(Vector2.ZERO, (RAIO + LADO) * a, Color(0.03, 0.02, 0.06, 0.45 * a))
	draw_arc(Vector2.ZERO, RAIO * a, 0, TAU, 24, Color(EstiloUI.OURO, 0.25 * a), 1.0)
	# feixe tracejado da lente até a gema em foco
	var topo := _posicao(_indice)
	var passo := 9.0
	var d := fposmod(_tempo * 30.0, passo)
	while d < topo.length() - LADO * 0.6:
		draw_line(topo.normalized() * d, topo.normalized() * (d + 4.0), Color(cor_foco, 0.8 * a), 2.0)
		d += passo
	# o miolo: a própria lente, na cor da opção em foco
	draw_arc(Vector2.ZERO, 7.0 * a, 0, TAU, 12, Color(cor_foco, a), 2.0)
	draw_circle(Vector2.ZERO, 3.0 * a, Color(cor_foco.lightened(0.4), a))

	for i in _opcoes.size():
		if i != _indice:
			_gema(i, false)
	_gema(_indice, true)  # por último, por cima das outras

	if a < 0.9:
		return
	# nome e efeito acima da gema do topo; motivo em vermelho se não servir
	var f := EstiloUI.fonte()
	var largura := 230.0
	var y := topo.y - LADO * 0.9
	var motivo := _motivos[_indice] if _indice < _motivos.size() else ""
	var texto: String = motivo if motivo != "" else foco.get("descricao", "")
	var cor_texto := EstiloUI.DANO_RECEBIDO if motivo != "" else EstiloUI.TEXTO
	var altura_texto := f.get_multiline_string_size(texto, HORIZONTAL_ALIGNMENT_CENTER, largura, 9).y
	var y_texto := y - altura_texto
	draw_multiline_string_outline(f, Vector2(-largura / 2, y_texto + 6), texto, HORIZONTAL_ALIGNMENT_CENTER, largura, 9, -1, 3, Color.BLACK)
	draw_multiline_string(f, Vector2(-largura / 2, y_texto + 6), texto, HORIZONTAL_ALIGNMENT_CENTER, largura, 9, -1, cor_texto)
	EstiloUI.texto(self, Vector2(-largura / 2, y_texto - 6), foco.nome, 13, cor_foco.lightened(0.3), largura, HORIZONTAL_ALIGNMENT_CENTER)
	EstiloUI.texto(self, Vector2(-largura / 2, RAIO + LADO + 6), "←→ girar · Enter escolher · Q/E/R agir", 9, EstiloUI.TEXTO_FRACO, largura, HORIZONTAL_ALIGNMENT_CENTER)


## Gema octogonal da opção `i`, com a sigla; a em foco é maior e tem
## contorno dourado; a atual leva um pontinho; as inválidas ficam apagadas.
func _gema(i: int, em_foco: bool) -> void:
	var o: Dictionary = _opcoes[i]
	var valida := i >= _motivos.size() or _motivos[i] == ""
	var cor: Color = o.get("cor", EstiloUI.TEXTO)
	if not valida:
		cor = cor.darkened(0.55).lerp(Color(0.4, 0.4, 0.45), 0.5)
	var c := _posicao(i)
	var l := (LADO + (PIXEL * 2 if em_foco else 0.0)) / 2.0 * _abertura
	if em_foco:
		l += PIXEL * 0.5 * sin(_tempo * 6.0)
	var k := PIXEL
	if l < k * 2:
		# abrindo/recolhendo: pequena demais para o octógono, vira um ponto
		draw_rect(Rect2(c - Vector2(k, k), Vector2(k * 2, k * 2)), cor)
		return
	var oct := func(m: float) -> PackedVector2Array:
		var r := l + m
		return PackedVector2Array([c + Vector2(-r + k, -r), c + Vector2(r - k, -r), c + Vector2(r, -r + k), c + Vector2(r, r - k),
			c + Vector2(r - k, r), c + Vector2(-r + k, r), c + Vector2(-r, r - k), c + Vector2(-r, -r + k)])
	if em_foco:
		draw_colored_polygon(oct.call(k + 2.0), EstiloUI.OURO)
	draw_colored_polygon(oct.call(2.0), Color.BLACK)
	draw_colored_polygon(oct.call(0.0), cor.darkened(0.35))
	draw_colored_polygon(oct.call(-k), cor)
	draw_rect(Rect2(c + Vector2(-l + k * 2, -l + k), Vector2(maxf(0, l * 2 - k * 4), k)), Color(1, 1, 1, 0.35))  # brilho
	if o.get("atual", false):
		draw_rect(Rect2(c + Vector2(l - k, -l - k), Vector2(k * 2, k * 2)), Color.BLACK)
		draw_rect(Rect2(c + Vector2(l - k * 0.5, -l - k * 0.5), Vector2(k, k)), EstiloUI.OURO)
	if _abertura > 0.6:
		var sigla: String = o.get("sigla", String(o.nome).left(3).to_upper())
		EstiloUI.texto(self, c + Vector2(-l, 3), sigla, 8, Color.WHITE if valida else EstiloUI.TEXTO_FRACO, l * 2, HORIZONTAL_ALIGNMENT_CENTER)

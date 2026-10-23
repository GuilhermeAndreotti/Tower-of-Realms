class_name HudLobby
extends CanvasLayer
## Interface do saguão: dica de controles, aviso curto, caixa de conversa e
## o véu preto das transições. Só mostra; quem decide é o Lobby.

const CONTROLES := [[["←", "↑", "→", "↓"], "andar"], [["Enter"], "interagir"]]

var dialogo: CaixaDialogo

var _raiz: Control
var _aviso: PanelContainer
var _texto_aviso: Label
var _tween_aviso: Tween
var _veu: ColorRect
var _anuncio: Label


func _ready() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	var controles := PanelContainer.new()
	controles.add_theme_stylebox_override("panel", EstiloUI.painel())
	controles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var desenho := Control.new()
	desenho.custom_minimum_size = Vector2(_largura_controles(), 15)
	desenho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desenho.draw.connect(_desenhar_controles.bind(desenho))
	controles.add_child(desenho)
	_raiz.add_child(controles)
	_ancorar(controles, Vector2(0, 1), Vector2(EstiloUI.MARGEM, -EstiloUI.MARGEM))

	_aviso = PanelContainer.new()
	_aviso.add_theme_stylebox_override("panel", EstiloUI.painel(EstiloUI.FUNDO, EstiloUI.BORDA_CLARA))
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto_aviso = EstiloUI.label("", 12, EstiloUI.TEXTO_FRACO)
	_aviso.add_child(_texto_aviso)
	_raiz.add_child(_aviso)
	_ancorar(_aviso, Vector2(0.5, 1), Vector2(0, -56))
	_aviso.modulate.a = 0

	dialogo = CaixaDialogo.new()
	_raiz.add_child(dialogo)
	_ancorar(dialogo, Vector2(0.5, 1), Vector2(0, -EstiloUI.MARGEM - 30))

	_anuncio = EstiloUI.label("", 26, EstiloUI.OURO, 7)
	_anuncio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_raiz.add_child(_anuncio)
	_ancorar(_anuncio, Vector2(0.5, 0.22), Vector2.ZERO)
	_anuncio.modulate.a = 0

	_veu = ColorRect.new()
	_veu.color = Color.BLACK
	_veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_veu)


## Mensagem curta e discreta acima dos controles, que some sozinha.
func avisar(texto: String) -> void:
	_texto_aviso.text = texto
	if _tween_aviso:
		_tween_aviso.kill()
	_aviso.modulate.a = 1
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(1.6)
	_tween_aviso.tween_property(_aviso, "modulate:a", 0.0, 0.4)


## Anúncio grande no alto da tela (chegada de alguém, por exemplo).
func anunciar(texto: String) -> void:
	_anuncio.text = texto
	_anuncio.pivot_offset = _anuncio.size / 2
	_anuncio.scale = Vector2(1.3, 1.3)
	var t := create_tween()
	t.tween_property(_anuncio, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(_anuncio, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	t.tween_interval(2.0)
	t.tween_property(_anuncio, "modulate:a", 0.0, 0.5)


func texto_anuncio() -> String:
	return _anuncio.text if _anuncio.modulate.a > 0 else ""


func texto_aviso() -> String:
	return _texto_aviso.text if _aviso.modulate.a > 0 else ""


## Escurece (alfa 1) ou clareia (alfa 0) a tela inteira.
func veu(alfa: float, duracao: float) -> Tween:
	var t := create_tween()
	t.tween_property(_veu, "color:a", alfa, duracao)
	return t


func _ancorar(c: Control, canto: Vector2, deslocamento: Vector2) -> void:
	c.anchor_left = canto.x
	c.anchor_right = canto.x
	c.anchor_top = canto.y
	c.anchor_bottom = canto.y
	var direcao := func(v: float) -> int:
		return Control.GROW_DIRECTION_END if v == 0 else (Control.GROW_DIRECTION_BEGIN if v == 1 else Control.GROW_DIRECTION_BOTH)
	c.grow_horizontal = direcao.call(canto.x)
	c.grow_vertical = direcao.call(canto.y)
	c.offset_left = deslocamento.x
	c.offset_right = deslocamento.x
	c.offset_top = deslocamento.y
	c.offset_bottom = deslocamento.y


func _largura_controles() -> float:
	var x := 0.0
	for item: Array in CONTROLES:
		for t: String in item[0]:
			x += maxf(13.0, 7.0 * t.length() + 6.0) + 4
		x += EstiloUI.fonte().get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 14
	return x - 14


func _desenhar_controles(c: Control) -> void:
	var x := 0.0
	for item: Array in CONTROLES:
		for t: String in item[0]:
			EstiloUI.tecla(c, Vector2(x + 1, 1), t)
			x += maxf(13.0, 7.0 * t.length() + 6.0) + 4
		EstiloUI.texto(c, Vector2(x, 11), item[1], 10, Color(0.82, 0.8, 0.88))
		x += EstiloUI.fonte().get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 14

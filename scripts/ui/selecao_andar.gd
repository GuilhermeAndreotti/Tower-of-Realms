class_name SelecaoAndar
extends Control
## Escolha do andar, entre a porta do saguão e a montagem da equipe. Os
## andares ficam empilhados como a Torre (o 1º embaixo). Vencidos podem ser
## repetidos; o seguinte ao último vencido está liberado; o resto, trancado.
## Lê tudo de Andares, então andares novos aparecem aqui sem mexer nesta tela.
## Controles: ↑/↓ escolhe, Enter sobe, Esc volta ao saguão.

const CENA_EQUIPE := "res://scenes/selecao_equipe.tscn"
const CENA_SAGUAO := "res://scenes/lobby.tscn"
const COR_VENCIDO := Color(0.45, 0.9, 0.55)

var cursor := 1  ## número do andar sob o cursor

var _cartoes: Array[Control] = []  ## um por andar, do 1º ao último
var _detalhe: VBoxContainer
var _botao: Button
var _aviso: Label
var _tempo := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	cursor = Andares.mais_alto_liberado()
	_montar()
	_atualizar()


# ------------------------------------------------------------------ montagem
func _montar() -> void:
	var fundo := TextureRect.new()
	fundo.texture = load(Andares.FUNDO_PADRAO)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var veu := ColorRect.new()
	veu.color = Color(0.03, 0.02, 0.06, 0.7)
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veu)

	var margem := MarginContainer.new()
	margem.set_anchors_preset(Control.PRESET_FULL_RECT)
	margem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 20)
	add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 12)
	margem.add_child(coluna)

	var titulos := VBoxContainer.new()
	titulos.add_theme_constant_override("separation", 0)
	titulos.add_child(EstiloUI.label("A TORRE", 22, EstiloUI.OURO, 5))
	titulos.add_child(EstiloUI.label("Escolha o andar. Os que você já venceu podem ser repetidos.", 11, EstiloUI.TEXTO_FRACO))
	titulos.add_child(EstiloUI.label("Limite de nível atual: %d (sobe ao liberar andares novos)" % Andares.limite_nivel(), 11, EstiloUI.OURO, 3))
	coluna.add_child(titulos)

	var meio := HBoxContainer.new()
	meio.add_theme_constant_override("separation", 14)
	meio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(meio)

	# esquerda: os andares, o mais alto em cima
	var pilha := VBoxContainer.new()
	pilha.add_theme_constant_override("separation", 6)
	pilha.alignment = BoxContainer.ALIGNMENT_END
	meio.add_child(pilha)
	for n in range(1, Andares.total() + 1):
		var c := Control.new()
		c.custom_minimum_size = Vector2(330, 62)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		c.draw.connect(_desenhar_cartao.bind(c, n))
		c.mouse_entered.connect(func() -> void:
			cursor = n
			_atualizar())
		c.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				cursor = n
				subir())
		_cartoes.append(c)
	for i in range(_cartoes.size() - 1, -1, -1):
		pilha.add_child(_cartoes[i])

	# direita: detalhes do andar sob o cursor
	var ficha := PanelContainer.new()
	var ef := EstiloUI.painel()
	ef.set_content_margin_all(12)
	ficha.add_theme_stylebox_override("panel", ef)
	ficha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detalhe = VBoxContainer.new()
	_detalhe.add_theme_constant_override("separation", 6)
	ficha.add_child(_detalhe)
	meio.add_child(ficha)

	var rodape := HBoxContainer.new()
	rodape.add_theme_constant_override("separation", 12)
	var dicas := Control.new()
	dicas.custom_minimum_size = Vector2(0, 16)
	dicas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dicas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dicas.draw.connect(_desenhar_dicas.bind(dicas))
	dicas.custom_minimum_size.x = 260
	rodape.add_child(dicas)
	_aviso = EstiloUI.label("", 11, EstiloUI.DANO_RECEBIDO, 3)
	_aviso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aviso.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rodape.add_child(_aviso)
	_botao = Button.new()
	_botao.text = "SUBIR  ▸"
	_botao.focus_mode = Control.FOCUS_NONE
	_botao.custom_minimum_size = Vector2(170, 40)
	_botao.add_theme_font_size_override("font_size", 15)
	_botao.add_theme_color_override("font_color", EstiloUI.OURO)
	_botao.add_theme_color_override("font_hover_color", Color.WHITE)
	_botao.add_theme_color_override("font_disabled_color", EstiloUI.TEXTO_FRACO)
	_botao.add_theme_stylebox_override("normal", EstiloUI.painel(EstiloUI.FUNDO_CLARO, EstiloUI.OURO.darkened(0.25), 2))
	_botao.add_theme_stylebox_override("hover", EstiloUI.painel(Color(0.2, 0.17, 0.1), EstiloUI.OURO, 2))
	_botao.add_theme_stylebox_override("pressed", EstiloUI.painel(Color(0.3, 0.24, 0.1), Color.WHITE, 2))
	_botao.add_theme_stylebox_override("disabled", EstiloUI.painel(EstiloUI.FUNDO, EstiloUI.BORDA, 2))
	_botao.pressed.connect(subir)
	rodape.add_child(_botao)
	coluna.add_child(rodape)


# ------------------------------------------------------------- desenho
## "vencido", "novo" (liberado e nunca vencido) ou "trancado".
static func situacao(n: int) -> String:
	if Andares.vencido(n):
		return "vencido"
	return "novo" if Andares.liberado(n) else "trancado"


func _desenhar_cartao(c: Control, n: int) -> void:
	var d := Andares.dados(n)
	var sit := situacao(n)
	var no_cursor := n == cursor
	var r := Rect2(Vector2.ZERO, c.size)
	var trancado := sit == "trancado"
	c.draw_rect(r.grow(1), Color.BLACK)
	c.draw_rect(r, EstiloUI.FUNDO_CLARO if no_cursor else EstiloUI.FUNDO)
	# número do andar num bloco de pedra
	var bloco := Rect2(6, 6, 50, r.size.y - 12)
	var cor_bloco := EstiloUI.BORDA.darkened(0.3) if trancado else (EstiloUI.OURO.darkened(0.55) if sit == "novo" else EstiloUI.ALIADO.darkened(0.6))
	c.draw_rect(bloco, cor_bloco)
	c.draw_rect(bloco, Color(1, 1, 1, 0.12), false, 1.0)
	EstiloUI.texto(c, Vector2(bloco.position.x, bloco.get_center().y + 10), str(n), 26,
		EstiloUI.TEXTO_FRACO if trancado else Color.WHITE, bloco.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var x := bloco.end.x + 10
	var w := r.size.x - x - 8
	EstiloUI.texto(c, Vector2(x, 22), "???" if trancado else d.nome, 14,
		EstiloUI.TEXTO_FRACO if trancado else (EstiloUI.OURO if no_cursor else EstiloUI.TEXTO), w)
	var estado := {"vencido": ["✓ Vencido", COR_VENCIDO], "novo": ["✦ Novo", EstiloUI.OURO],
		"trancado": ["Trancado: vença o andar %d" % (n - 1), EstiloUI.TEXTO_FRACO]}
	EstiloUI.texto(c, Vector2(x, 40), estado[sit][0], 10, estado[sit][1], w)
	if not trancado:
		var info := "Nv %d  ·  equipe %d" % [d.nivel_recomendado, Andares.max_equipe(n)]
		EstiloUI.texto(c, Vector2(x, 40), info, 10, EstiloUI.TEXTO_FRACO, w, HORIZONTAL_ALIGNMENT_RIGHT)
	var borda := EstiloUI.OURO if no_cursor else EstiloUI.BORDA
	if no_cursor:
		borda = Color(borda, 0.7 + 0.3 * sin(_tempo * 5.0))
	c.draw_rect(r, borda, false, 2.0 if no_cursor else 1.0)


func _desenhar_dicas(c: Control) -> void:
	var x := 0.0
	for item in [[["↑", "↓"], "escolher"], [["Enter"], "subir"], [["Esc"], "saguão"]]:
		for t: String in item[0]:
			EstiloUI.tecla(c, Vector2(x + 1, 1), t)
			x += maxf(13.0, 7.0 * t.length() + 6.0) + 4
		EstiloUI.texto(c, Vector2(x, 11), item[1], 10, Color(0.82, 0.8, 0.88))
		x += EstiloUI.fonte().get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 16


# ---------------------------------------------------------- ficha (detalhe)
func _montar_ficha() -> void:
	for filho in _detalhe.get_children():
		filho.queue_free()
	var n := cursor
	var d := Andares.dados(n)
	var sit := situacao(n)
	_detalhe.add_child(EstiloUI.label("ANDAR %d" % n, 10, EstiloUI.TEXTO_FRACO, 2))
	if sit == "trancado":
		_detalhe.add_child(EstiloUI.label("???", 20, EstiloUI.TEXTO_FRACO, 5))
		_detalhe.add_child(EstiloUI.label("Vença o andar %d para liberar." % (n - 1), 12, EstiloUI.TEXTO_FRACO))
		return
	_detalhe.add_child(EstiloUI.label(d.nome, 20, EstiloUI.OURO, 5))
	var desc := EstiloUI.label(d.get("descricao", ""), 11, Color(0.82, 0.8, 0.88))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detalhe.add_child(desc)

	# nível recomendado contra o da equipe
	var niveis: Array[int] = []
	for id in Progressao.equipe_principal():
		niveis.append(Progressao.nivel(id))
	var media := Progressao.nivel_de_entrada(niveis)
	var rec: int = d.nivel_recomendado
	var linha_nivel := EstiloUI.label("Nível recomendado: %d  (sua equipe: %d)" % [rec, media], 11,
		EstiloUI.DANO_RECEBIDO if media < rec else EstiloUI.TEXTO, 3)
	_detalhe.add_child(linha_nivel)
	var maximo := Andares.max_equipe(n)
	_detalhe.add_child(EstiloUI.label("Equipe: %s" % ("só 1 personagem" if maximo == 1 else "até %d personagens" % maximo), 11, EstiloUI.TEXTO, 3))

	_detalhe.add_child(EstiloUI.label("INIMIGOS", 9, EstiloUI.TEXTO_FRACO, 2))
	var inimigos := Andares.criar_inimigos(n)
	var grupos := {}  ## nome -> [quantidade, tipo]
	for ini in inimigos:
		if not grupos.has(ini.nome):
			grupos[ini.nome] = [0, ini.tipo]
		grupos[ini.nome][0] += 1
	for nome: String in grupos:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var qtd: int = grupos[nome][0]
		h.add_child(EstiloUI.label(("%d× " % qtd if qtd > 1 else "") + nome, 12, EstiloUI.INIMIGO.lightened(0.3), 3))
		h.add_child(EstiloUI.etiqueta_tipo(grupos[nome][1]))
		_detalhe.add_child(h)

	_detalhe.add_child(EstiloUI.label("RECOMPENSA", 9, EstiloUI.TEXTO_FRACO, 2))
	_detalhe.add_child(EstiloUI.label("%d XP para cada personagem" % Progressao.xp_da_batalha(inimigos), 12, EstiloUI.XP, 3))
	if sit == "novo":
		if not d.get("ao_vencer", []).is_empty():
			_detalhe.add_child(EstiloUI.label("✦ A primeira vitória muda algo na Torre...", 11, EstiloUI.OURO, 3))
		if n < Andares.total():
			var proximo := Andares.limite_do_andar(n + 1)
			var texto := "Libera o andar %d" % (n + 1)
			if proximo > Andares.limite_nivel():
				texto += " e o limite de nível sobe para %d" % proximo
			_detalhe.add_child(EstiloUI.label(texto + ".", 11, EstiloUI.TEXTO_FRACO, 2))
	else:
		_detalhe.add_child(EstiloUI.label("✓ Vencido. Repetir dá a XP de novo, até o limite de nível %d." % Andares.limite_nivel(), 11, COR_VENCIDO, 3))


# --------------------------------------------------------------- estado
## Vai para a montagem da equipe no andar sob o cursor (se liberado).
func subir() -> void:
	if not Andares.liberado(cursor):
		_aviso.text = "Andar %d trancado: vença o andar %d primeiro." % [cursor, cursor - 1]
		return
	Andares.escolher(cursor)
	get_tree().change_scene_to_file(CENA_EQUIPE)


func _atualizar() -> void:
	_aviso.text = ""
	_botao.disabled = not Andares.liberado(cursor)
	for c in _cartoes:
		c.queue_redraw()
	if _detalhe.get_meta("andar", 0) != cursor:
		_detalhe.set_meta("andar", cursor)
		_montar_ficha()


func _process(delta: float) -> void:
	_tempo += delta
	_cartoes[cursor - 1].queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_UP, KEY_W:
			cursor = mini(cursor + 1, Andares.total())
			_atualizar()
		KEY_DOWN, KEY_S:
			cursor = maxi(cursor - 1, 1)
			_atualizar()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			subir()
		KEY_ESCAPE:
			Engine.set_meta(Lobby.META_ENTRADA, "porta")
			get_tree().change_scene_to_file(CENA_SAGUAO)

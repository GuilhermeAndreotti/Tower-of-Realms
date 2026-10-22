class_name SelecaoEquipe
extends Control
## Seletor de equipe antes do combate: até Elenco.MAX_EQUIPE personagens.
## A ordem de escolha é a ordem na arena (o 1º fica na frente).
## Lê tudo do Elenco e das descrições dos personagens (habilidades(), status),
## então personagens novos aparecem aqui sem mexer nesta tela.
## Controles: ←/→ escolhe, Espaço adiciona/remove, Enter começa.

const CENA_BATALHA := "res://scenes/batalha.tscn"
const CARTOES_NO_ELENCO := 6  ## completa com "em breve" até este número
## Referência para as barrinhas de atributo (valor que enche a barra).
const REF_STATUS := {"hp": 2000.0, "atq": 200.0, "def": 120.0, "vel": 150.0}

var equipe: Array[String] = []
var _cursor := 0

var _vagas: Array[Control] = []
var _cartoes: Array[Control] = []
var _detalhe: VBoxContainer
var _botao: Button
var _contador: Label
var _tempo := 0.0
var _amostras := {}  ## id -> Combatente (para ler status e kit)
var _frames := {}  ## id -> SpriteFrames
var _icones := {}  ## caminho -> Texture2D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for id in Elenco.IDS:
		_amostras[id] = Elenco.criar(id)
		var sp: Dictionary = Elenco.dados(id).sprite
		_frames[id] = VisualLutador.carregar_frames(sp.png, sp.json)
	equipe = Elenco.equipe()
	_montar()
	_atualizar()


# ------------------------------------------------------------------ montagem
func _montar() -> void:
	var fundo := TextureRect.new()
	fundo.texture = load("res://cenarios/torre_andar.png")
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var veu := ColorRect.new()
	veu.color = Color(0.03, 0.02, 0.06, 0.62)
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

	# título
	var topo := HBoxContainer.new()
	var titulos := VBoxContainer.new()
	titulos.add_theme_constant_override("separation", 0)
	titulos.add_child(EstiloUI.label("MONTE SUA EQUIPE", 22, EstiloUI.OURO, 5))
	titulos.add_child(EstiloUI.label("Até %d personagens. O 1º escolhido fica na frente da arena." % Elenco.MAX_EQUIPE, 11, EstiloUI.TEXTO_FRACO))
	titulos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(titulos)
	_contador = EstiloUI.label("", 14, EstiloUI.TEXTO, 4)
	_contador.size_flags_vertical = Control.SIZE_SHRINK_END
	topo.add_child(_contador)
	coluna.add_child(topo)

	var meio := HBoxContainer.new()
	meio.add_theme_constant_override("separation", 14)
	meio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(meio)

	# esquerda: vagas da equipe + elenco
	var esquerda := VBoxContainer.new()
	esquerda.add_theme_constant_override("separation", 8)
	meio.add_child(esquerda)
	var vagas := HBoxContainer.new()
	vagas.add_theme_constant_override("separation", 10)
	for i in Elenco.MAX_EQUIPE:
		var vaga := _controle(Vector2(150, 196), _desenhar_vaga)
		vaga.set_meta("indice", i)
		vaga.mouse_filter = Control.MOUSE_FILTER_STOP
		vaga.gui_input.connect(_clique_vaga.bind(i))
		vagas.add_child(vaga)
		_vagas.append(vaga)
	esquerda.add_child(vagas)
	esquerda.add_child(EstiloUI.label("PERSONAGENS", 9, EstiloUI.TEXTO_FRACO, 2))
	var elenco := HBoxContainer.new()
	elenco.add_theme_constant_override("separation", 8)
	for i in maxi(CARTOES_NO_ELENCO, Elenco.IDS.size()):
		var cartao := _controle(Vector2(70, 88), _desenhar_cartao)
		cartao.set_meta("indice", i)
		if i < Elenco.IDS.size():
			cartao.mouse_filter = Control.MOUSE_FILTER_STOP
			cartao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			cartao.mouse_entered.connect(func() -> void:
				_cursor = i
				_atualizar())
			cartao.gui_input.connect(_clique_cartao.bind(i))
		elenco.add_child(cartao)
		_cartoes.append(cartao)
	esquerda.add_child(elenco)

	# direita: ficha do personagem sob o cursor
	var ficha := PanelContainer.new()
	var ef := EstiloUI.painel()
	ef.set_content_margin_all(12)
	ficha.add_theme_stylebox_override("panel", ef)
	ficha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detalhe = VBoxContainer.new()
	_detalhe.add_theme_constant_override("separation", 6)
	ficha.add_child(_detalhe)
	meio.add_child(ficha)

	# rodapé: controles + começar
	var rodape := HBoxContainer.new()
	var dicas := _controle(Vector2(0, 16), _desenhar_dicas)
	dicas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dicas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rodape.add_child(dicas)
	_botao = Button.new()
	_botao.text = "COMEÇAR COMBATE  ▸"
	_botao.focus_mode = Control.FOCUS_NONE
	_botao.custom_minimum_size = Vector2(210, 40)
	_botao.add_theme_font_size_override("font_size", 15)
	_botao.add_theme_color_override("font_color", EstiloUI.OURO)
	_botao.add_theme_color_override("font_hover_color", Color.WHITE)
	_botao.add_theme_color_override("font_disabled_color", EstiloUI.TEXTO_FRACO)
	_botao.add_theme_stylebox_override("normal", EstiloUI.painel(EstiloUI.FUNDO_CLARO, EstiloUI.OURO.darkened(0.25), 2))
	_botao.add_theme_stylebox_override("hover", EstiloUI.painel(Color(0.2, 0.17, 0.1), EstiloUI.OURO, 2))
	_botao.add_theme_stylebox_override("pressed", EstiloUI.painel(Color(0.3, 0.24, 0.1), Color.WHITE, 2))
	_botao.add_theme_stylebox_override("disabled", EstiloUI.painel(EstiloUI.FUNDO, EstiloUI.BORDA, 2))
	_botao.pressed.connect(comecar)
	rodape.add_child(_botao)
	coluna.add_child(rodape)


func _controle(tamanho: Vector2, ao_desenhar: Callable) -> Control:
	var c := Control.new()
	c.custom_minimum_size = tamanho
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(ao_desenhar.bind(c))
	return c


# ------------------------------------------------------------- desenho
func _desenhar_vaga(c: Control) -> void:
	var i: int = c.get_meta("indice")
	var r := Rect2(Vector2.ZERO, c.size)
	var id := equipe[i] if i < equipe.size() else ""
	if id == "":
		c.draw_rect(r, Color(0, 0, 0, 0.35))
		_tracejado(c, r.grow(-1), EstiloUI.BORDA)
		var meio := r.get_center()
		c.draw_rect(Rect2(meio + Vector2(-9, -2), Vector2(18, 4)), EstiloUI.BORDA)
		c.draw_rect(Rect2(meio + Vector2(-2, -9), Vector2(4, 18)), EstiloUI.BORDA)
		EstiloUI.texto(c, Vector2(0, meio.y + 30), "Vaga livre", 11, EstiloUI.TEXTO_FRACO, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var cor := EstiloUI.ALIADO
		c.draw_rect(r, cor.darkened(0.82))
		# chão de luz onde o personagem pisa
		c.draw_rect(Rect2(0, r.size.y * 0.5, r.size.x, r.size.y * 0.5), cor.darkened(0.7))
		var pe := Vector2(r.size.x / 2, 144)
		var frames: SpriteFrames = _frames[id]
		var n := frames.get_frame_count("idle")
		var quadro := frames.get_frame_texture("idle", int(_tempo * frames.get_animation_speed("idle")) % n)
		var sp: Dictionary = Elenco.dados(id).sprite
		var escala := 3.0
		c.draw_set_transform(pe - sp.pe * escala, 0, Vector2(escala, escala))
		c.draw_texture(quadro, Vector2.ZERO)
		c.draw_set_transform(Vector2.ZERO)
		c.draw_rect(Rect2(pe.x - 26, pe.y, 52, 3), Color(0, 0, 0, 0.35))
		EstiloUI.texto(c, Vector2(0, 162), Elenco.dados(id).nome, 14, EstiloUI.TEXTO, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		EstiloUI.texto(c, Vector2(0, 175), Elenco.dados(id).origem, 9, EstiloUI.TEXTO_FRACO, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		var tipo: String = _amostras[id].tipo
		EstiloUI.selo_tipo(c, Vector2(roundf((r.size.x - EstiloUI.largura_selo_tipo(tipo)) / 2), 180), tipo)
		c.draw_rect(r, cor.darkened(0.2), false, 1.0)
	# número da posição
	var selo := Rect2(6, 6, 18, 18)
	c.draw_rect(selo.grow(1), Color.BLACK)
	c.draw_rect(selo, EstiloUI.OURO if id != "" else EstiloUI.FUNDO_CLARO)
	c.draw_string(EstiloUI.fonte(), selo.position + Vector2(0, 14), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 18, 13,
		Color.BLACK if id != "" else EstiloUI.TEXTO_FRACO)
	if id != "" and i == 0:
		EstiloUI.texto(c, Vector2(28, 19), "FRENTE", 9, EstiloUI.OURO)


func _desenhar_cartao(c: Control) -> void:
	var i: int = c.get_meta("indice")
	var r := Rect2(Vector2(0, 4), c.size - Vector2(0, 4))
	if i >= Elenco.IDS.size():
		c.draw_rect(r, Color(0, 0, 0, 0.45))
		c.draw_rect(r, Color(1, 1, 1, 0.06), false, 1.0)
		EstiloUI.texto(c, Vector2(0, r.position.y + 44), "?", 26, Color(1, 1, 1, 0.15), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		EstiloUI.texto(c, Vector2(0, r.end.y - 8), "em breve", 9, Color(1, 1, 1, 0.25), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var id := Elenco.IDS[i]
	var posicao := equipe.find(id)
	var no_cursor := i == _cursor
	var sobe := -3.0 if no_cursor else 0.0
	r.position.y += sobe
	c.draw_rect(r.grow(1), Color.BLACK)
	c.draw_rect(r, EstiloUI.FUNDO_CLARO if no_cursor else EstiloUI.FUNDO)
	var pr := Rect2(r.position + Vector2((r.size.x - 48) / 2, 8), Vector2(48, 48))
	c.draw_rect(pr, EstiloUI.ALIADO.darkened(0.75))
	c.draw_texture_rect(Elenco.retrato(id), pr, false)
	EstiloUI.texto(c, Vector2(0, r.end.y - 9), Elenco.dados(id).nome, 11,
		EstiloUI.OURO if no_cursor else EstiloUI.TEXTO, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var borda := EstiloUI.OURO if no_cursor else (EstiloUI.ALIADO if posicao >= 0 else EstiloUI.BORDA)
	if no_cursor:
		borda = Color(borda, 0.7 + 0.3 * sin(_tempo * 5.0))
	c.draw_rect(r, borda, false, 2.0 if no_cursor or posicao >= 0 else 1.0)
	if posicao >= 0:
		var selo := Rect2(r.end.x - 16, r.position.y - 4, 18, 16)
		c.draw_rect(selo.grow(1), Color.BLACK)
		c.draw_rect(selo, EstiloUI.ALIADO)
		c.draw_string(EstiloUI.fonte(), selo.position + Vector2(0, 12), str(posicao + 1), HORIZONTAL_ALIGNMENT_CENTER, 18, 11, Color.WHITE)


func _desenhar_dicas(c: Control) -> void:
	var x := 0.0
	for item in [[["←", "→"], "escolher"], [["Espaço"], "adicionar / remover"], [["Enter"], "começar"]]:
		for t: String in item[0]:
			EstiloUI.tecla(c, Vector2(x + 1, 1), t)
			x += maxf(13.0, 7.0 * t.length() + 6.0) + 4
		EstiloUI.texto(c, Vector2(x, 11), item[1], 10, Color(0.82, 0.8, 0.88))
		x += EstiloUI.fonte().get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 16


func _tracejado(c: Control, r: Rect2, cor: Color) -> void:
	var passo := 8.0
	var x := r.position.x
	while x < r.end.x:
		var w := minf(4, r.end.x - x)
		c.draw_rect(Rect2(x, r.position.y, w, 1), cor)
		c.draw_rect(Rect2(x, r.end.y - 1, w, 1), cor)
		x += passo
	var y := r.position.y
	while y < r.end.y:
		var h := minf(4, r.end.y - y)
		c.draw_rect(Rect2(r.position.x, y, 1, h), cor)
		c.draw_rect(Rect2(r.end.x - 1, y, 1, h), cor)
		y += passo


# ---------------------------------------------------------- ficha (detalhe)
func _montar_ficha() -> void:
	for filho in _detalhe.get_children():
		filho.queue_free()
	var id := Elenco.IDS[_cursor]
	var dados := Elenco.dados(id)
	var p: Combatente = _amostras[id]

	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 10)
	var retrato := TextureRect.new()
	retrato.texture = Elenco.retrato(id)
	retrato.custom_minimum_size = Vector2(48, 48)
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	topo.add_child(retrato)
	var nomes := VBoxContainer.new()
	nomes.add_theme_constant_override("separation", 0)
	nomes.add_child(EstiloUI.label(dados.nome, 20, EstiloUI.ALIADO.lightened(0.35), 5))
	var linha_origem := HBoxContainer.new()
	linha_origem.add_theme_constant_override("separation", 6)
	linha_origem.add_child(EstiloUI.label(dados.origem, 11, EstiloUI.TEXTO_FRACO))
	linha_origem.add_child(EstiloUI.etiqueta_tipo(p.tipo))
	nomes.add_child(linha_origem)
	nomes.add_child(EstiloUI.label("de " + dados.universo, 10, EstiloUI.OURO.darkened(0.15), 2))
	topo.add_child(nomes)
	_detalhe.add_child(topo)

	# atributos
	var grade := GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 14)
	grade.add_theme_constant_override("v_separation", 3)
	var linhas := [
		["HP", p.hp_max, REF_STATUS.hp, EstiloUI.HP],
		["ATQ", p.atq_base, REF_STATUS.atq, EstiloUI.DANO_RECEBIDO],
		["DEF", p.def_base, REF_STATUS.def, EstiloUI.ALIADO],
		["VEL", p.vel_base, REF_STATUS.vel, EstiloUI.PONTO],
	]
	if p.energia_max > 0:
		linhas.append(["EN", p.energia_max, REF_STATUS.hp / 10, EstiloUI.ENERGIA])
	for l in linhas:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 5)
		var rotulo := EstiloUI.label(l[0], 9, l[3], 2)
		rotulo.custom_minimum_size.x = 24
		h.add_child(rotulo)
		var barra := BarraPixel.new()
		barra.cor = l[3]
		barra.marcas = 5
		barra.custom_minimum_size = Vector2(90, 8)
		barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		barra.definir(minf(l[1], l[2]), l[2], false)
		h.add_child(barra)
		var valor := EstiloUI.label(str(roundi(l[1])), 11)
		valor.custom_minimum_size.x = 34
		valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(valor)
		grade.add_child(h)
	_detalhe.add_child(grade)

	_detalhe.add_child(EstiloUI.label("HABILIDADES", 9, EstiloUI.TEXTO_FRACO, 2))
	for hab in p.habilidades(Batalha.PONTOS_MAX):
		_detalhe.add_child(_linha_habilidade(hab))


func _linha_habilidade(hab: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var caminho: String = hab.get("icone", "")
	if caminho != "" and not _icones.has(caminho):
		_icones[caminho] = load(caminho)
	var icone := _controle(Vector2(34, 34), func(c: Control) -> void:
		var r := Rect2(Vector2(0, 2), Vector2(32, 32))
		c.draw_rect(r.grow(1), Color.BLACK)
		c.draw_rect(r, Color(0.2, 0.19, 0.29))
		if _icones.has(caminho):
			c.draw_texture_rect(_icones[caminho], Rect2(r.position + Vector2(1, 1), Vector2(30, 30)), false)
		if hab.get("tecla", "") != "":
			EstiloUI.tecla(c, Vector2(-3, -1), hab.tecla))
	h.add_child(icone)
	var texto := RichTextLabel.new()
	texto.bbcode_enabled = true
	texto.fit_content = true
	texto.scroll_active = false
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texto.add_theme_font_size_override("normal_font_size", 10)
	texto.add_theme_font_size_override("bold_font_size", 12)
	texto.add_theme_constant_override("outline_size", 3)
	texto.add_theme_color_override("font_outline_color", Color.BLACK)
	var custo := ""
	if hab.get("passiva", false):
		custo = "  [color=#%s]passiva[/color]" % EstiloUI.TEXTO_FRACO.to_html(false)
	elif hab.get("custo_pontos", 0) > 0:
		custo = "  [color=#%s]%d ponto%s[/color]" % [EstiloUI.PONTO.to_html(false), hab.custo_pontos, "" if hab.custo_pontos == 1 else "s"]
	elif hab.get("custo_energia", 0) > 0:
		custo = "  [color=#%s]%d energia[/color]" % [EstiloUI.ENERGIA.to_html(false), hab.custo_energia]
	texto.text = "[b]%s[/b]%s\n[color=#%s]%s[/color]" % [hab.nome, custo, Color(0.82, 0.8, 0.88).to_html(false), hab.get("descricao", "")]
	h.add_child(texto)
	return h


# --------------------------------------------------------------- estado
func alternar(id: String) -> void:
	if id in equipe:
		equipe.erase(id)
	elif equipe.size() < Elenco.MAX_EQUIPE:
		equipe.append(id)
	_atualizar()


func comecar() -> void:
	if equipe.is_empty():
		return
	Elenco.definir_equipe(equipe)
	get_tree().change_scene_to_file(CENA_BATALHA)


func _atualizar() -> void:
	_contador.text = "%d/%d" % [equipe.size(), Elenco.MAX_EQUIPE]
	_botao.disabled = equipe.is_empty()
	for c in _vagas + _cartoes:
		c.queue_redraw()
	if _detalhe.get_meta("id", "") != Elenco.IDS[_cursor]:
		_detalhe.set_meta("id", Elenco.IDS[_cursor])
		_montar_ficha()


func _process(delta: float) -> void:
	_tempo += delta
	for c in _vagas:
		c.queue_redraw()
	_cartoes[_cursor].queue_redraw()


func _clique_vaga(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and i < equipe.size():
		equipe.remove_at(i)
		_atualizar()


func _clique_cartao(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_cursor = i
		alternar(Elenco.IDS[i])


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_LEFT, KEY_A:
			_cursor = posmod(_cursor - 1, Elenco.IDS.size())
			_atualizar()
		KEY_RIGHT, KEY_D:
			_cursor = posmod(_cursor + 1, Elenco.IDS.size())
			_atualizar()
		KEY_SPACE:
			alternar(Elenco.IDS[_cursor])
		KEY_BACKSPACE:
			if not equipe.is_empty():
				equipe.pop_back()
				_atualizar()
		KEY_ENTER, KEY_KP_ENTER:
			comecar()

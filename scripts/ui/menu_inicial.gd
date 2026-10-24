class_name MenuInicial
extends Control
## Tela de abertura: a logo, NEW GAME, LOAD GAME e QUIT. Os dois primeiros
## abrem a lista de slots de save (Progressao.SLOTS): no jogo novo, um slot
## ocupado pede confirmação para ser sobrescrito; no carregar, só os ocupados
## abrem. Em qualquer lista, um slot ocupado pode ser apagado (com confirmação).
## Só apresenta: quem cria, lê e apaga os saves é a Progressao.
## Controles: ↑/↓ escolhe, Enter confirma, Del apaga, Esc volta.

const CENA_SAGUAO := "res://scenes/lobby.tscn"
const LOGO := "res://logo.png"
const BRASAS := 40

var modo := "inicio"  ## "inicio", "novo" (escolher onde criar) ou "carregar"
var pedido := ""  ## confirmação aberta: "", "sobrescrever" ou "apagar"
var slot_pedido := 0

var _inicio: VBoxContainer
var _lista: VBoxContainer
var _titulo_lista: Label
var _slots: Array[Button] = []
var _apagar: Array[Button] = []
var _voltar: Button
var _carregar: Button
var _novo: Button
var _aviso: Label
var _logo_caixa: Control
var _logo: TextureRect
var _confirmacao: ColorRect
var _texto_confirmacao: Label
var _sim: Button
var _nao: Button
var _veu: ColorRect
var _brasas: Control
var _particulas: Array[Dictionary] = []
var _tempo := 0.0
var _saindo := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_montar()
	abrir("inicio")
	_veu.color.a = 1.0
	create_tween().tween_property(_veu, "color:a", 0.0, 0.5)


# ------------------------------------------------------------------ montagem
func _montar() -> void:
	var fundo := TextureRect.new()
	fundo.texture = load(Andares.FUNDO_PADRAO)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var escuro := ColorRect.new()
	escuro.color = Color(0.03, 0.02, 0.06, 0.78)
	escuro.set_anchors_preset(Control.PRESET_FULL_RECT)
	escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(escuro)
	_brasas = Control.new()
	_brasas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_brasas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brasas.draw.connect(_desenhar_brasas)
	add_child(_brasas)

	var coluna := VBoxContainer.new()
	coluna.set_anchors_preset(Control.PRESET_FULL_RECT)
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	coluna.add_theme_constant_override("separation", 14)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(coluna)

	# a logo é 4x a arte; na lista ela encolhe para caber os slots. Fica numa
	# caixa para poder flutuar sem brigar com o container.
	_logo_caixa = Control.new()
	_logo_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(_logo_caixa)
	_logo = TextureRect.new()
	_logo.texture = load(LOGO)
	_logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_caixa.add_child(_logo)

	_inicio = VBoxContainer.new()
	_inicio.add_theme_constant_override("separation", 8)
	_inicio.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_novo = _botao("NEW GAME", Vector2(240, 38), 16)
	_novo.pressed.connect(abrir.bind("novo"))
	_carregar = _botao("LOAD GAME", Vector2(240, 38), 16)
	_carregar.pressed.connect(abrir.bind("carregar"))
	var sair := _botao("QUIT", Vector2(240, 38), 16)
	sair.pressed.connect(func() -> void: get_tree().quit())
	for b in [_novo, _carregar, sair]:
		_inicio.add_child(b)
	coluna.add_child(_inicio)

	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 8)
	_lista.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_titulo_lista = EstiloUI.label("", 14, EstiloUI.OURO, 4)
	_titulo_lista.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lista.add_child(_titulo_lista)
	for n in range(1, Progressao.SLOTS + 1):
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 8)
		var slot := _botao("", Vector2(480, 60), 14)
		slot.draw.connect(_desenhar_slot.bind(slot, n))
		slot.pressed.connect(escolher_slot.bind(n))
		var apagar := _botao("APAGAR", Vector2(90, 60), 11)
		apagar.add_theme_color_override("font_color", EstiloUI.DANO_RECEBIDO)
		apagar.pressed.connect(pedir_apagar.bind(n))
		linha.add_child(slot)
		linha.add_child(apagar)
		_slots.append(slot)
		_apagar.append(apagar)
		_lista.add_child(linha)
	var rodape := HBoxContainer.new()
	rodape.add_theme_constant_override("separation", 12)
	_voltar = _botao("VOLTAR", Vector2(120, 30), 12)
	_voltar.pressed.connect(abrir.bind("inicio"))
	rodape.add_child(_voltar)
	_aviso = EstiloUI.label("", 11, EstiloUI.DANO_RECEBIDO, 3)
	_aviso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aviso.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rodape.add_child(_aviso)
	var dicas := Control.new()
	dicas.custom_minimum_size = Vector2(210, 16)
	dicas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dicas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dicas.draw.connect(_desenhar_dicas.bind(dicas))
	rodape.add_child(dicas)
	_lista.add_child(rodape)
	coluna.add_child(_lista)

	var versao := EstiloUI.label("protótipo", 10, EstiloUI.TEXTO_FRACO, 2)
	versao.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	add_child(versao)

	_montar_confirmacao()
	_veu = ColorRect.new()
	_veu.color = Color(0, 0, 0, 0)
	_veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veu)
	for i in BRASAS:
		_particulas.append(_nova_brasa(true))


func _montar_confirmacao() -> void:
	_confirmacao = ColorRect.new()
	_confirmacao.color = Color(0, 0, 0, 0.6)
	_confirmacao.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirmacao.visible = false
	add_child(_confirmacao)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirmacao.add_child(centro)
	var painel := PanelContainer.new()
	var estilo := EstiloUI.painel(EstiloUI.FUNDO_CLARO, EstiloUI.OURO.darkened(0.25), 2)
	estilo.set_content_margin_all(16)
	painel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(painel)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 14)
	painel.add_child(caixa)
	_texto_confirmacao = EstiloUI.label("", 13, EstiloUI.TEXTO, 3)
	_texto_confirmacao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto_confirmacao.custom_minimum_size.x = 340
	_texto_confirmacao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caixa.add_child(_texto_confirmacao)
	var botoes := HBoxContainer.new()
	botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	botoes.add_theme_constant_override("separation", 12)
	_nao = _botao("CANCELAR", Vector2(130, 32), 12)
	_nao.pressed.connect(cancelar)
	_sim = _botao("", Vector2(130, 32), 12)
	_sim.add_theme_color_override("font_color", EstiloUI.DANO_RECEBIDO)
	_sim.pressed.connect(confirmar)
	botoes.add_child(_nao)
	botoes.add_child(_sim)
	caixa.add_child(botoes)
	# o foco não escapa para os botões de trás enquanto a pergunta está aberta
	for b: Button in [_nao, _sim]:
		var outro := _sim if b == _nao else _nao
		for lado in [SIDE_LEFT, SIDE_RIGHT]:
			b.set_focus_neighbor(lado, outro.get_path())
		for lado in [SIDE_TOP, SIDE_BOTTOM]:
			b.set_focus_neighbor(lado, b.get_path())
		b.focus_next = outro.get_path()
		b.focus_previous = outro.get_path()


## Botão de pedra com filete dourado; o foco (teclado) tem o visual do hover.
func _botao(texto: String, tamanho: Vector2, fonte: int) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = tamanho
	b.add_theme_font_size_override("font_size", fonte)
	b.add_theme_color_override("font_color", EstiloUI.OURO)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", EstiloUI.TEXTO_FRACO)
	b.add_theme_stylebox_override("normal", EstiloUI.painel(EstiloUI.FUNDO, EstiloUI.OURO.darkened(0.45), 2))
	var destaque := EstiloUI.painel(Color(0.2, 0.17, 0.1, 0.95), EstiloUI.OURO, 2)
	b.add_theme_stylebox_override("hover", destaque)
	b.add_theme_stylebox_override("focus", destaque)
	b.add_theme_stylebox_override("pressed", EstiloUI.painel(Color(0.3, 0.24, 0.1), Color.WHITE, 2))
	b.add_theme_stylebox_override("disabled", EstiloUI.painel(EstiloUI.FUNDO, EstiloUI.BORDA, 2))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled and b.is_visible_in_tree():
			b.grab_focus())
	return b


# --------------------------------------------------------------- telas
## Mostra a tela `m`: "inicio", "novo" ou "carregar".
func abrir(m: String) -> void:
	modo = m
	_aviso.text = ""
	var no_inicio := m == "inicio"
	_inicio.visible = no_inicio
	_lista.visible = not no_inicio
	_logo_caixa.custom_minimum_size = Vector2(568, 248) if no_inicio else Vector2(284, 124)
	_logo.position.y = 0
	_carregar.disabled = not Progressao.algum_slot()
	if no_inicio:
		(_novo if _carregar.disabled else _carregar).grab_focus()
		return
	_titulo_lista.text = "NEW GAME — escolha onde salvar" if m == "novo" else "LOAD GAME — escolha o save"
	_atualizar_slots()
	_slots[_slot_inicial() - 1].grab_focus()


func _atualizar_slots() -> void:
	for i in _slots.size():
		var existe := Progressao.slot_existe(i + 1)
		_apagar[i].disabled = not existe
		_apagar[i].modulate.a = 1.0 if existe else 0.35
		_slots[i].queue_redraw()


## Onde o cursor começa: no jogo novo, o primeiro vazio; no carregar, o salvo
## mais recentemente.
func _slot_inicial() -> int:
	var melhor := 1
	var mais_recente := -1
	for n in range(1, Progressao.SLOTS + 1):
		var r := Progressao.resumo_slot(n)
		if modo == "novo" and not r.existe:
			return n
		if modo == "carregar" and r.existe and int(r.salvo_em) > mais_recente:
			mais_recente = r.salvo_em
			melhor = n
	return melhor


## Clicar (ou Enter) num slot: cria, pede para sobrescrever ou carrega.
func escolher_slot(n: int) -> void:
	if pedido != "" or _saindo:
		return
	var existe := Progressao.slot_existe(n)
	if modo == "novo":
		if existe:
			_perguntar("sobrescrever", n, "Sobrescrever o slot %d?\nO progresso salvo nele será perdido." % n, "SOBRESCREVER")
		else:
			_entrar(n, true)
	elif modo == "carregar":
		if existe:
			_entrar(n, false)
		else:
			_aviso.text = "O slot %d está vazio." % n


func pedir_apagar(n: int) -> void:
	if pedido != "" or _saindo or not Progressao.slot_existe(n):
		return
	_perguntar("apagar", n, "Apagar o slot %d?\nNão dá para desfazer." % n, "APAGAR")


func _perguntar(tipo: String, n: int, texto: String, sim: String) -> void:
	pedido = tipo
	slot_pedido = n
	_texto_confirmacao.text = texto
	_sim.text = sim
	_confirmacao.visible = true
	_nao.grab_focus()  # o padrão é não perder nada


func confirmar() -> void:
	var tipo := pedido
	var n := slot_pedido
	cancelar()
	if tipo == "sobrescrever":
		_entrar(n, true)
	elif tipo == "apagar":
		Progressao.apagar_slot(n)
		_aviso.text = "Slot %d apagado." % n
		_atualizar_slots()
		_carregar.disabled = not Progressao.algum_slot()
		_slots[n - 1].grab_focus()


func cancelar() -> void:
	if pedido == "":
		return
	pedido = ""
	_confirmacao.visible = false
	if modo != "inicio":
		_slots[slot_pedido - 1].grab_focus()


## Prepara o save do slot e vai para o saguão, entrando pelo começo.
func _entrar(n: int, novo: bool) -> void:
	_saindo = true
	if novo:
		Progressao.novo_jogo(n)
	else:
		Progressao.usar_slot(n)
	Engine.set_meta(Lobby.META_ENTRADA, "inicio")
	_veu.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_veu, "color:a", 1.0, 0.5)
	t.tween_callback(func() -> void: get_tree().change_scene_to_file(CENA_SAGUAO))


func _unhandled_input(event: InputEvent) -> void:
	if _saindo or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE:
			if pedido != "":
				cancelar()
			elif modo != "inicio":
				abrir("inicio")
			get_viewport().set_input_as_handled()
		KEY_DELETE, KEY_BACKSPACE:
			var i := _slots.find(get_viewport().gui_get_focus_owner())
			if pedido == "" and i >= 0:
				pedir_apagar(i + 1)
				get_viewport().set_input_as_handled()


# ------------------------------------------------------------- desenho
## Texto do resumo de um slot ocupado (também usado nos testes).
static func descrever_slot(n: int) -> String:
	var r := Progressao.resumo_slot(n)
	if not r.existe:
		return "Vazio"
	var andares := "nenhum andar vencido" if r.andares == 0 else "%d de %d andares vencidos" % [r.andares, Andares.total()]
	return "Nv %d  ·  %d personagens  ·  %s" % [r.nivel, r.personagens, andares]


static func data_do_save(unix: int) -> String:
	if unix <= 0:
		return ""
	var local := unix + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(local)
	return "%02d/%02d/%04d  %02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute]


func _desenhar_slot(b: Button, n: int) -> void:
	var r := Progressao.resumo_slot(n)
	var bloco := Rect2(6, 6, 48, b.size.y - 12)
	b.draw_rect(bloco, EstiloUI.OURO.darkened(0.55) if r.existe else EstiloUI.BORDA.darkened(0.3))
	b.draw_rect(bloco, Color(1, 1, 1, 0.12), false, 1.0)
	EstiloUI.texto(b, Vector2(bloco.position.x, bloco.get_center().y + 9), str(n), 24,
		Color.WHITE if r.existe else EstiloUI.TEXTO_FRACO, bloco.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var x := bloco.end.x + 12
	var w := b.size.x - x - 10
	if not r.existe:
		EstiloUI.texto(b, Vector2(x, 36), "— Vazio —", 14, EstiloUI.TEXTO_FRACO, w)
		return
	EstiloUI.texto(b, Vector2(x, 24), "SLOT %d" % n, 14, EstiloUI.OURO, w)
	EstiloUI.texto(b, Vector2(x, 24), data_do_save(r.salvo_em), 10, EstiloUI.TEXTO_FRACO, w, HORIZONTAL_ALIGNMENT_RIGHT)
	EstiloUI.texto(b, Vector2(x, 44), descrever_slot(n), 11, EstiloUI.TEXTO, w)


func _desenhar_dicas(c: Control) -> void:
	var x := 0.0
	for item in [[["Del"], "apagar"], [["Esc"], "voltar"]]:
		for t: String in item[0]:
			EstiloUI.tecla(c, Vector2(x + 1, 1), t)
			x += maxf(13.0, 7.0 * t.length() + 6.0) + 4
		EstiloUI.texto(c, Vector2(x, 11), item[1], 10, Color(0.82, 0.8, 0.88))
		x += EstiloUI.fonte().get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 16


## Brasa subindo do pé da tela; `espalhada` sorteia a altura (início da tela).
func _nova_brasa(espalhada := false) -> Dictionary:
	var tela := get_viewport_rect().size
	return {"pos": Vector2(randf() * tela.x, randf() * tela.y if espalhada else tela.y + 4),
		"vel": randf_range(12.0, 34.0), "fase": randf() * TAU, "tam": 2.0 if randf() < 0.3 else 1.0}


func _desenhar_brasas() -> void:
	var tela := get_viewport_rect().size
	for p in _particulas:
		var pos: Vector2 = p.pos
		var a := clampf(pos.y / tela.y, 0.0, 1.0)  # apagam ao subir
		var tam: float = p.tam * 2.0
		_brasas.draw_rect(Rect2(pos.floor(), Vector2(tam, tam)), Color(1.0, 0.62 + 0.25 * a, 0.25, 0.75 * a))


func _process(delta: float) -> void:
	_tempo += delta
	for i in _particulas.size():
		var p := _particulas[i]
		p.pos += Vector2(sin(_tempo * 1.3 + p.fase) * 8.0, -float(p.vel)) * delta
		if p.pos.y < -4:
			_particulas[i] = _nova_brasa()
	_brasas.queue_redraw()
	if modo == "inicio":
		_logo.position.y = roundf(sin(_tempo * 1.6) * 3.0)  # flutua devagar

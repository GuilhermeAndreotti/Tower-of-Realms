class_name HudBatalha
extends CanvasLayer
## Interface da batalha. Só apresenta: lê o estado dos combatentes e as
## descrições que eles dão (efeitos(), habilidades()) e avisa a batalha do
## que o jogador pediu. Nenhuma regra de combate mora aqui.
##
##   ┌ordem──┐      ┌objetivo / controles┐       ┌registro──┐
##   │       │      └────────────────────┘       └──────────┘
##   └───────┘              (arena)
##   ┌personagem da vez┐┌resto da equipe┐  ┌barra de habilidades┐

signal acao_pedida(acao: String)
signal foco_habilidade(acao: String)  ## "" quando nenhuma
signal reiniciar_pedido
signal trocar_equipe_pedido
signal opcao_clicada(indice: int)

const MAX_LINHAS_LOG := 5
const ARQUIVO_PREFS := "user://hud.cfg"
const TEXTO_ALVO := {
	"unico": "Alvo único",
	"dupla": "Alvo + 1 atrás",
	"vizinhos": "Alvo + vizinhos",
	"todos": "Todos os inimigos",
	"proprio": "Em si",
	"aliado": "Aliado ou em si",
}

var _raiz: Control
var _retratos := {}  ## Combatente -> Texture2D

# ordem de ação
var _itens_fila: Array[ItemFila] = []
var _caixa_fila: VBoxContainer

# objetivo e controles
var _objetivo: Label
var _dica_controles: Label
var _controles: Control
var _controles_abertos := true

# registro
var _log: RichTextLabel
var _linhas_log: Array[String] = []

# personagem ativo
var _ativo: Combatente
var _pontos := 0
var _pontos_max := 0
var _retrato_painel: Control
var _nome: Label
var _tipo: Control  ## selo do elemento ao lado do nome
var _forma: Label
var _barra_hp: BarraPixel
var _texto_hp: Label
var _barra_energia: BarraPixel
var _texto_energia: Label
var _linha_energia: Control
var _pontos_desenho: Control
var _chips: HBoxContainer
var _painel_personagem: PanelContainer

# resto da equipe (cartõezinhos ao lado do painel)
var _painel_equipe: PanelContainer
var _caixa_equipe: HBoxContainer
var _cartoes: Array[Control] = []

# habilidades
var _painel_barra: PanelContainer
var _titulo_barra: Label
var _caixa_slots: HBoxContainer
var _slots := {}  ## acao -> SlotHabilidade
var _ids_slots: Array[String] = []
var _dica: PanelContainer
var _dica_texto: RichTextLabel
var _foco := ""
var _vez := false

# seletor de opções (elemento, artefato...), acima da barra
var _opcoes: PanelContainer
var _titulo_opcoes: Label
var _lista_opcoes: VBoxContainer
var _motivo_opcao: Label

# avisos
var _anuncio: Label
var _fim: Control
var _fim_texto: Label


func _ready() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_montar_ordem()
	_montar_objetivo()
	_montar_log()
	_montar_personagem()
	_montar_equipe()
	_montar_habilidades()
	_montar_opcoes()
	_montar_anuncio()
	_montar_fim()
	_carregar_prefs()


# ------------------------------------------------------------------ montagem
## Prende `c` num canto da tela (`canto` em 0..1) e o faz crescer para dentro.
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


func _painel(canto: Vector2, deslocamento: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", EstiloUI.painel())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(p)
	_ancorar(p, canto, deslocamento)
	return p


func _vbox(separacao := 2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separacao)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _hbox(separacao := 4) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separacao)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


func _cabecalho(texto: String) -> Label:
	return EstiloUI.label(texto, 9, EstiloUI.TEXTO_FRACO, 2)


func _desenho(tamanho: Vector2, ao_desenhar: Callable) -> Control:
	var c := Control.new()
	c.custom_minimum_size = tamanho
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(ao_desenhar.bind(c))
	return c


func _montar_ordem() -> void:
	var m := EstiloUI.MARGEM
	var p := _painel(Vector2(0, 0), Vector2(m, m))
	p.custom_minimum_size.x = 158
	var v := _vbox(3)
	v.add_child(_cabecalho("ORDEM DE AÇÃO"))
	_caixa_fila = _vbox(2)
	v.add_child(_caixa_fila)
	p.add_child(v)


func _montar_objetivo() -> void:
	var m := EstiloUI.MARGEM
	var coluna := _vbox(0)
	_raiz.add_child(coluna)
	_ancorar(coluna, Vector2(0.5, 0), Vector2(0, m))

	var p := PanelContainer.new()
	var estilo := EstiloUI.painel()
	estilo.border_color = EstiloUI.OURO.darkened(0.45)
	p.add_theme_stylebox_override("panel", estilo)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			alternar_controles())
	var h := _hbox(8)
	h.add_child(EstiloUI.label("OBJETIVO", 9, EstiloUI.OURO, 2))
	_objetivo = EstiloUI.label("", 12)
	h.add_child(_objetivo)
	_dica_controles = EstiloUI.label("", 9, EstiloUI.TEXTO_FRACO, 2)
	h.add_child(_dica_controles)
	for filho in h.get_children():
		filho.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(h)
	coluna.add_child(p)

	# gaveta de controles, presa embaixo do objetivo
	var gaveta := PanelContainer.new()
	var eg := EstiloUI.painel(Color(EstiloUI.FUNDO, 0.78))
	eg.set_corner_radius_all(0)
	eg.corner_radius_bottom_left = 4
	eg.corner_radius_bottom_right = 4
	eg.border_width_top = 0
	eg.content_margin_top = 4
	eg.content_margin_bottom = 4
	gaveta.add_theme_stylebox_override("panel", eg)
	gaveta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gaveta.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	gaveta.add_child(_desenho(Vector2(0, 14), _desenhar_controles))
	coluna.add_child(gaveta)
	_controles = gaveta


## Linha de controles: [tecla] descrição · [tecla] descrição ...
const CONTROLES := [
	[["Q", "E", "R"], "usar"],
	[["←", "→"], "alvo"],
	[["mouse"], "prévia do golpe"],
	[["H"], "ocultar"],
]


func _desenhar_controles(c: Control) -> void:
	var f := EstiloUI.fonte()
	var x := 0.0
	for item: Array in CONTROLES:
		for t: String in item[0]:
			EstiloUI.tecla(c, Vector2(x + 1, 1), t)
			x += maxf(13.0, 7.0 * t.length() + 6.0) + 4
		EstiloUI.texto(c, Vector2(x, 11), item[1], 10, Color(0.82, 0.8, 0.88))
		x += f.get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 14
	if not is_equal_approx(c.custom_minimum_size.x, x - 14):
		c.custom_minimum_size.x = x - 14


func _montar_log() -> void:
	var m := EstiloUI.MARGEM
	var p := _painel(Vector2(1, 0), Vector2(-m, m))
	p.add_theme_stylebox_override("panel", EstiloUI.painel(Color(EstiloUI.FUNDO, 0.72)))
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.fit_content = true
	_log.scroll_active = false
	_log.custom_minimum_size = Vector2(232, 0)
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_font_size_override("normal_font_size", 11)
	_log.add_theme_constant_override("outline_size", 3)
	_log.add_theme_color_override("font_outline_color", Color.BLACK)
	_log.add_theme_constant_override("line_separation", 1)
	p.add_child(_log)


func _montar_personagem() -> void:
	var m := EstiloUI.MARGEM
	var p := _painel(Vector2(0, 1), Vector2(m, -m))
	p.custom_minimum_size.x = 300
	_painel_personagem = p
	var h := _hbox(8)
	_retrato_painel = _desenho(Vector2(54, 54), _desenhar_retrato)
	_retrato_painel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(_retrato_painel)

	var v := _vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var topo := _hbox(6)
	_nome = EstiloUI.label("", 15, EstiloUI.ALIADO.lightened(0.35), 4)
	_forma = EstiloUI.label("", 10, EstiloUI.TEXTO_FRACO, 3)
	_forma.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_forma.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_forma.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	topo.add_child(_nome)
	_tipo = _hbox(0)
	_tipo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	topo.add_child(_tipo)
	topo.add_child(_forma)
	v.add_child(topo)

	var linha_hp := _linha_recurso("HP", EstiloUI.HP)
	_barra_hp = linha_hp[1]
	_barra_hp.cor_baixa = EstiloUI.HP_BAIXO
	_texto_hp = linha_hp[2]
	v.add_child(linha_hp[0])
	var linha_en := _linha_recurso("EN", EstiloUI.ENERGIA)
	_linha_energia = linha_en[0]
	_barra_energia = linha_en[1]
	_barra_energia.marcas = 6
	_texto_energia = linha_en[2]
	v.add_child(_linha_energia)

	var base := _hbox(6)
	_pontos_desenho = _desenho(Vector2(0, 12), _desenhar_pontos)
	base.add_child(_pontos_desenho)
	_chips = _hbox(3)
	_chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chips.alignment = BoxContainer.ALIGNMENT_END
	base.add_child(_chips)
	v.add_child(base)
	h.add_child(v)
	p.add_child(h)


## [linha, barra, texto do valor]
func _linha_recurso(rotulo: String, cor: Color) -> Array:
	var linha := _hbox(5)
	var l := EstiloUI.label(rotulo, 9, cor, 2)
	l.custom_minimum_size.x = 16
	var barra := BarraPixel.new()
	barra.cor = cor
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var valor := EstiloUI.label("", 11)
	valor.custom_minimum_size.x = 64
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	linha.add_child(l)
	linha.add_child(barra)
	linha.add_child(valor)
	return [linha, barra, valor]


func _desenhar_retrato(c: Control) -> void:
	var r := Rect2(Vector2(3, 3), c.size - Vector2(6, 6))
	var cor := EstiloUI.cor_lado(_ativo.aliado) if _ativo else EstiloUI.BORDA
	c.draw_rect(r.grow(3), Color.BLACK)
	c.draw_rect(r.grow(2), cor.darkened(0.3))
	c.draw_rect(r.grow(1), Color.BLACK)
	c.draw_rect(r, cor.darkened(0.78))
	# luz de fundo atrás do rosto
	c.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.55), Vector2(r.size.x, r.size.y * 0.45)), cor.darkened(0.6))
	var tex: Texture2D = _retratos.get(_ativo) if _ativo else null
	if tex:
		var lado := floorf(r.size.x / tex.get_width()) * tex.get_width()
		var tam := Vector2(lado, lado * tex.get_height() / tex.get_width())
		c.draw_texture_rect(tex, Rect2(r.get_center() - tam / 2, tam), false)
	# o efeito mais forte tinge a moldura
	if _ativo:
		for e in _ativo.efeitos():
			if e.has("cor"):
				c.draw_rect(r.grow(2), e.cor, false, 1.0)
				break


func _desenhar_pontos(c: Control) -> void:
	if _pontos_max <= 0:
		c.custom_minimum_size.x = 0
		return
	EstiloUI.texto(c, Vector2(0, 10), "PONTOS", 9, EstiloUI.TEXTO_FRACO)
	var x0 := 44.0
	for i in _pontos_max:
		EstiloUI.losango(c, Vector2(x0 + i * 13, 6), 4.5, i < _pontos)
	c.custom_minimum_size.x = x0 + _pontos_max * 13


func _montar_equipe() -> void:
	_painel_equipe = _painel(Vector2(0, 1), Vector2(0, -EstiloUI.MARGEM))
	_painel_equipe.add_theme_stylebox_override("panel", EstiloUI.painel(Color(EstiloUI.FUNDO, 0.8)))
	var v := _vbox(3)
	v.add_child(_cabecalho("EQUIPE"))
	_caixa_equipe = _hbox(4)
	v.add_child(_caixa_equipe)
	_painel_equipe.add_child(v)
	_painel_equipe.visible = false


## Cartão compacto de um aliado fora da vez: retrato, nome, HP e energia.
func _desenhar_cartao(c: Control) -> void:
	var a: Combatente = c.get_meta("combatente")
	var vivo := a.vivo()
	var cor := EstiloUI.cor_lado(true)
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(r, Color(0, 0, 0, 0.4))
	c.draw_rect(Rect2(0, 0, 2, r.size.y), cor if vivo else Color(0.3, 0.3, 0.35))
	var pr := Rect2(5, 4, 24, 24)
	c.draw_rect(pr.grow(1), Color.BLACK)
	c.draw_rect(pr, cor.darkened(0.75))
	var tex: Texture2D = _retratos.get(a)
	if tex:
		c.draw_texture_rect(tex, Rect2(pr.position + Vector2(4, 4), Vector2(16, 16)), false,
			Color.WHITE if vivo else Color(0.35, 0.35, 0.4))
	var x := pr.end.x + 4
	var w := r.size.x - x - 4
	var selo := EstiloUI.largura_selo_tipo(a.tipo, 8, true)
	EstiloUI.texto(c, Vector2(x, 12), a.nome, 10, EstiloUI.TEXTO if vivo else EstiloUI.TEXTO_FRACO, w - selo - 3)
	EstiloUI.selo_tipo(c, Vector2(r.size.x - 4 - selo, 3), a.tipo, 8, true)
	if not vivo:
		EstiloUI.texto(c, Vector2(x, 26), "caiu", 9, EstiloUI.DANO_RECEBIDO, w)
		return
	var frac_hp := float(a.hp) / a.hp_max
	c.draw_rect(Rect2(x, 16, w, 5), Color.BLACK)
	c.draw_rect(Rect2(x, 16, roundf(w * frac_hp), 5), EstiloUI.HP if frac_hp >= 0.3 else EstiloUI.HP_BAIXO)
	if a.energia_max > 0:
		c.draw_rect(Rect2(x, 23, w, 3), Color.BLACK)
		c.draw_rect(Rect2(x, 23, roundf(w * a.energia / a.energia_max), 3), EstiloUI.ENERGIA)
	# efeitos ativos em pontinhos
	var px := x
	for e in a.efeitos():
		c.draw_rect(Rect2(px, 28, 5, 3), EstiloUI.cor_efeito(e))
		px += 7


func _atualizar_equipe(equipe: Array[Combatente]) -> void:
	var outros := equipe.filter(func(c: Combatente) -> bool: return c != _ativo)
	_painel_equipe.visible = not outros.is_empty()
	if outros.is_empty():
		return
	while _cartoes.size() < outros.size():
		var cartao := _desenho(Vector2(92, 32), _desenhar_cartao)
		_caixa_equipe.add_child(cartao)
		_cartoes.append(cartao)
	for i in _cartoes.size():
		_cartoes[i].visible = i < outros.size()
		if _cartoes[i].visible:
			_cartoes[i].set_meta("combatente", outros[i])
			_cartoes[i].queue_redraw()
	# encosta no painel do personagem da vez, que pode mudar de largura
	var x := EstiloUI.MARGEM + _painel_personagem.get_combined_minimum_size().x + 6
	_painel_equipe.offset_left = x
	_painel_equipe.offset_right = x


func _montar_habilidades() -> void:
	var m := EstiloUI.MARGEM
	var p := _painel(Vector2(1, 1), Vector2(-m, -m))
	_painel_barra = p
	var v := _vbox(6)
	_titulo_barra = _cabecalho("")
	v.add_child(_titulo_barra)
	_caixa_slots = _hbox(10)
	var margem := MarginContainer.new()
	margem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margem.add_theme_constant_override("margin_left", 4)
	margem.add_theme_constant_override("margin_top", 2)
	margem.add_child(_caixa_slots)
	v.add_child(margem)
	p.add_child(v)

	# explicação da habilidade em foco, à esquerda da barra (sobre o chão,
	# longe dos inimigos); a posição x acompanha a largura da barra
	_dica = _painel(Vector2(1, 1), Vector2(-m, -m))
	_dica.custom_minimum_size.x = 220
	_dica.add_theme_stylebox_override("panel", EstiloUI.painel(EstiloUI.FUNDO_CLARO, EstiloUI.OURO.darkened(0.35)))
	_dica_texto = RichTextLabel.new()
	_dica_texto.bbcode_enabled = true
	_dica_texto.fit_content = true
	_dica_texto.scroll_active = false
	_dica_texto.custom_minimum_size.x = 208
	_dica_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dica_texto.add_theme_font_size_override("normal_font_size", 11)
	_dica_texto.add_theme_font_size_override("bold_font_size", 12)
	_dica_texto.add_theme_constant_override("outline_size", 3)
	_dica_texto.add_theme_color_override("font_outline_color", Color.BLACK)
	_dica.add_child(_dica_texto)
	_dica.visible = false


func _montar_opcoes() -> void:
	_opcoes = _painel(Vector2(1, 1), Vector2.ZERO)
	_opcoes.add_theme_stylebox_override("panel", EstiloUI.painel(EstiloUI.FUNDO_CLARO, EstiloUI.OURO.darkened(0.35)))
	_opcoes.custom_minimum_size.x = 300
	_opcoes.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := _vbox(4)
	_titulo_opcoes = EstiloUI.label("", 11, EstiloUI.OURO, 3)
	v.add_child(_titulo_opcoes)
	_lista_opcoes = _vbox(1)
	v.add_child(_lista_opcoes)
	_motivo_opcao = EstiloUI.label("", 10, EstiloUI.DANO_RECEBIDO, 3)
	_motivo_opcao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_motivo_opcao.custom_minimum_size.x = 288
	v.add_child(_motivo_opcao)
	v.add_child(EstiloUI.label("↑↓ ou 1-9 escolher · ←→ alvo · Enter confirmar · Esc cancelar", 9, EstiloUI.TEXTO_FRACO, 2))
	_opcoes.add_child(v)
	_opcoes.visible = false


## Abre (ou atualiza) o seletor da habilidade `h` com a opção `indice` em
## foco. `motivos[i]` != "" desabilita a opção i no alvo atual (`alvo_nome`).
func mostrar_opcoes(h: Dictionary, indice: int, motivos: Array[String], alvo_nome: String) -> void:
	_titulo_opcoes.text = h.nome.to_upper() + ("  ·  alvo: %s" % alvo_nome if alvo_nome != "" else "")
	for filho in _lista_opcoes.get_children():
		filho.queue_free()
	var opcoes: Array = h.opcoes
	for i in opcoes.size():
		_lista_opcoes.add_child(_linha_opcao(opcoes[i], i, i == indice, motivos[i] == ""))
	_motivo_opcao.text = motivos[indice]
	_motivo_opcao.visible = motivos[indice] != ""
	_dica.visible = false
	_opcoes.visible = true
	# fica logo acima da barra de habilidades
	var y := -EstiloUI.MARGEM - _painel_barra.get_combined_minimum_size().y - 6
	_opcoes.offset_top = y
	_opcoes.offset_bottom = y
	_opcoes.offset_left = -EstiloUI.MARGEM
	_opcoes.offset_right = -EstiloUI.MARGEM


func fechar_opcoes() -> void:
	_opcoes.visible = false


func _linha_opcao(o: Dictionary, i: int, em_foco: bool, valida: bool) -> Control:
	var cor: Color = o.get("cor", EstiloUI.TEXTO)
	var p := PanelContainer.new()
	var estilo := EstiloUI.painel(cor.darkened(0.7) if em_foco else Color(0, 0, 0, 0.25),
		EstiloUI.OURO if em_foco else Color(0, 0, 0, 0), 1)
	estilo.shadow_size = 0
	estilo.set_content_margin_all(2)
	p.add_theme_stylebox_override("panel", estilo)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			opcao_clicada.emit(i))
	var h := _hbox(6)
	h.add_child(EstiloUI.label(str(i + 1) if i < 9 else "", 10, EstiloUI.TEXTO_FRACO, 2))
	# a textura é carregada fora do desenho: dentro dele seria liberada
	# antes de a tela ser renderizada (e sairia branca)
	var icone: Texture2D = load(o.icone) if o.get("icone", "") != "" else null
	# só a opção em foco tem ícone grande e descrição, para o painel caber
	var lado := 12.0
	if icone:
		lado = 30.0 if em_foco else 15.0
	var marca := _desenho(Vector2(lado, lado), func(c: Control) -> void:
		var mod := Color.WHITE if valida else Color(0.4, 0.4, 0.45)
		if icone:
			c.draw_texture_rect(icone, Rect2(Vector2.ZERO, Vector2(lado, lado)), false, mod)
		else:
			c.draw_rect(Rect2(1, 1, 10, 10), Color.BLACK)
			c.draw_rect(Rect2(2, 2, 8, 8), cor * mod))
	marca.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(marca)
	var textos := _vbox(0)
	var cor_nome := cor.lightened(0.35) if valida else EstiloUI.TEXTO_FRACO
	textos.add_child(EstiloUI.label(o.nome + ("  (atual)" if o.get("atual", false) else ""), 11, cor_nome, 3))
	if em_foco:
		var d := EstiloUI.label(o.get("descricao", ""), 9, EstiloUI.TEXTO if valida else EstiloUI.TEXTO_FRACO, 2)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 230
		textos.add_child(d)
	h.add_child(textos)
	p.add_child(h)
	return p


## Recusa de uma ação (alvo inválido, opção indisponível): mostra o motivo.
func avisar(texto: String) -> void:
	registrar(destaque(texto, EstiloUI.DANO_RECEBIDO))
	if _opcoes.visible:
		_motivo_opcao.text = texto
		_motivo_opcao.visible = true
		_motivo_opcao.modulate = Color(2, 2, 2)
		create_tween().tween_property(_motivo_opcao, "modulate", Color.WHITE, 0.3)


func _montar_anuncio() -> void:
	_anuncio = EstiloUI.label("", 40, EstiloUI.OURO, 10)
	_anuncio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anuncio.custom_minimum_size = Vector2(600, 56)
	_raiz.add_child(_anuncio)
	_ancorar(_anuncio, Vector2(0.5, 0.3), Vector2.ZERO)
	_anuncio.modulate.a = 0


func _montar_fim() -> void:
	_fim = ColorRect.new()
	(_fim as ColorRect).color = Color(0, 0, 0, 0.62)
	_fim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fim.visible = false
	_raiz.add_child(_fim)
	var p := PanelContainer.new()
	var estilo := EstiloUI.painel(EstiloUI.FUNDO_CLARO, EstiloUI.OURO.darkened(0.2), 2)
	estilo.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", estilo)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fim.add_child(p)
	_ancorar(p, Vector2(0.5, 0.45), Vector2.ZERO)
	var v := _vbox(10)
	_fim_texto = EstiloUI.label("", 30, Color.WHITE, 8)
	_fim_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_fim_texto)
	var dica := EstiloUI.label("Enter ou clique: jogar de novo  ·  Esc: trocar equipe", 13, EstiloUI.TEXTO_FRACO)
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(dica)
	var trocar := Button.new()
	trocar.text = "Trocar equipe"
	trocar.focus_mode = Control.FOCUS_NONE
	trocar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	trocar.add_theme_font_size_override("font_size", 12)
	trocar.add_theme_stylebox_override("normal", EstiloUI.painel(EstiloUI.FUNDO, EstiloUI.BORDA_CLARA))
	trocar.add_theme_stylebox_override("hover", EstiloUI.painel(EstiloUI.FUNDO_CLARO, EstiloUI.OURO))
	trocar.add_theme_stylebox_override("pressed", EstiloUI.painel(EstiloUI.FUNDO_CLARO, EstiloUI.OURO))
	trocar.pressed.connect(func() -> void: trocar_equipe_pedido.emit())
	v.add_child(trocar)
	p.add_child(v)
	_fim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			reiniciar_pedido.emit())


# --------------------------------------------------------------- atualização
func definir_retratos(retratos: Dictionary) -> void:
	_retratos = retratos


func definir_objetivo(texto: String) -> void:
	_objetivo.text = texto


## `ativo`: aliado mostrado no painel e na barra (o da vez, ou o último que agiu).
func atualizar(ativo: Combatente, equipe: Array[Combatente], pontos: int, pontos_max: int,
		fila: Array[Combatente], ator_atual: Combatente, vez_do_jogador: bool) -> void:
	_ativo = ativo
	_pontos = pontos
	_pontos_max = pontos_max
	_vez = vez_do_jogador
	_atualizar_personagem()
	_atualizar_equipe(equipe)
	_atualizar_habilidades(ator_atual)
	_atualizar_fila(fila)


func _atualizar_personagem() -> void:
	_nome.text = _ativo.nome
	_nome.label_settings.font_color = EstiloUI.cor_lado(_ativo.aliado).lightened(0.35)
	if _tipo.get_meta("tipo", "") != _ativo.tipo:
		_tipo.set_meta("tipo", _ativo.tipo)
		for filho in _tipo.get_children():
			filho.queue_free()
		_tipo.add_child(EstiloUI.etiqueta_tipo(_ativo.tipo))
	_barra_hp.definir(_ativo.hp, _ativo.hp_max)
	_texto_hp.text = "%d/%d" % [_ativo.hp, _ativo.hp_max]
	_linha_energia.visible = _ativo.energia_max > 0
	_barra_energia.definir(_ativo.energia, _ativo.energia_max)
	_texto_energia.text = "%d/%d" % [_ativo.energia, _ativo.energia_max]
	_retrato_painel.queue_redraw()
	_pontos_desenho.queue_redraw()

	var efeitos := _ativo.efeitos()
	# a forma/buff principal (o que tem cor própria) vira o subtítulo
	_forma.text = ""
	for e in efeitos:
		if e.has("detalhe") and e.has("cor"):
			_forma.text = e.detalhe
			_forma.label_settings.font_color = e.cor.lightened(0.3)
			break
	for filho in _chips.get_children():
		filho.queue_free()
	for e in efeitos:
		_chips.add_child(_chip(e))


func _chip(e: Dictionary) -> Control:
	var cor := EstiloUI.cor_efeito(e)
	var p := PanelContainer.new()
	var s := EstiloUI.painel(cor.darkened(0.6), cor, 1)
	s.shadow_size = 0
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.tooltip_text = e.nome + ("\n" + e.detalhe if e.has("detalhe") else "")
	var texto: String = e.nome
	if e.get("turnos", -1) > 0:
		texto += " · %d" % e.turnos
	p.add_child(EstiloUI.label(texto, 9, cor.lightened(0.45), 2))
	return p


func _atualizar_habilidades(ator_atual: Combatente) -> void:
	var lista := _ativo.habilidades(_pontos).filter(func(h: Dictionary) -> bool: return not h.get("passiva", false))
	var ids: Array[String] = []
	for h in lista:
		ids.append(h.acao)
	if ids != _ids_slots:
		_refazer_slots(ids)
	for h in lista:
		(_slots[h.acao] as SlotHabilidade).mostrar(h, _vez)
	if _vez:
		_titulo_barra.text = "SUA VEZ · %s" % _ativo.nome.to_upper()
		_titulo_barra.label_settings.font_color = EstiloUI.OURO
	elif ator_atual == _ativo:
		_titulo_barra.text = "%s EM AÇÃO" % _ativo.nome.to_upper()
		_titulo_barra.label_settings.font_color = EstiloUI.TEXTO_FRACO
	else:
		_titulo_barra.text = "VEZ DE %s" % ator_atual.nome.to_upper() if ator_atual else "PREPARANDO..."
		_titulo_barra.label_settings.font_color = EstiloUI.TEXTO_FRACO
	_mostrar_dica()


func _refazer_slots(ids: Array[String]) -> void:
	for s in _slots.values():
		s.queue_free()
	_slots.clear()
	for id in ids:
		var s := SlotHabilidade.new()
		s.pedido.connect(func(acao: String) -> void: acao_pedida.emit(acao))
		s.foco.connect(_ao_focar)
		_caixa_slots.add_child(s)
		_slots[id] = s
	_ids_slots = ids


func _ao_focar(acao: String) -> void:
	_foco = acao
	_mostrar_dica()
	foco_habilidade.emit(acao)


func _mostrar_dica() -> void:
	var slot: SlotHabilidade = _slots.get(_foco)
	_dica.visible = slot != null and not _opcoes.visible
	if not slot:
		return
	var x := -EstiloUI.MARGEM - _painel_barra.get_combined_minimum_size().x - 6
	_dica.offset_left = x
	_dica.offset_right = x
	var h := slot.dados
	var linhas := ["[b][color=#%s]%s[/color][/b]  [color=#%s]%s[/color]" % [
		EstiloUI.OURO.to_html(false), h.nome, EstiloUI.TEXTO_FRACO.to_html(false), TEXTO_ALVO.get(h.get("alvo"), "")]]
	if h.has("tipo"):
		linhas[0] += "  " + destaque(Tipos.nome(h.tipo), Tipos.cor(h.tipo))
	linhas.append(h.get("descricao", ""))
	var falta := _motivo_indisponivel(h)
	if falta != "":
		linhas.append("[color=#%s]%s[/color]" % [EstiloUI.DANO_RECEBIDO.to_html(false), falta])
	_dica_texto.text = "\n".join(linhas)


func _motivo_indisponivel(h: Dictionary) -> String:
	match h.get("estado"):
		"sem_recurso":
			if h.get("custo_pontos", 0) > _pontos:
				return "Sem pontos de skill. Use o Corte para gerar."
			if h.get("custo_energia", 0) > _ativo.energia:
				return "Energia insuficiente: %d/%d" % [_ativo.energia, h.custo_energia]
			return "Recursos insuficientes."
		"bloqueada":
			return "Indisponível agora."
	return ""


func _atualizar_fila(fila: Array[Combatente]) -> void:
	while _itens_fila.size() < fila.size():
		var item := ItemFila.new()
		_caixa_fila.add_child(item)
		_itens_fila.append(item)
	for i in _itens_fila.size():
		var item := _itens_fila[i]
		item.visible = i < fila.size()
		if item.visible:
			var c := fila[i]
			item.mostrar(c, _retratos.get(c), i, i == 0)


## Clarão no slot da habilidade usada (para teclado e clique darem o mesmo retorno).
func acionar(acao: String) -> void:
	if _slots.has(acao):
		(_slots[acao] as SlotHabilidade).acionar()


func registrar(texto: String) -> void:
	_linhas_log.append(texto)
	while _linhas_log.size() > MAX_LINHAS_LOG:
		_linhas_log.pop_front()
	# as mais antigas vão apagando
	var partes: Array[String] = []
	for i in _linhas_log.size():
		var idade := _linhas_log.size() - 1 - i
		var a := 1.0 if idade == 0 else lerpf(0.75, 0.4, float(idade - 1) / maxf(1, MAX_LINHAS_LOG - 2))
		partes.append("[color=#%s]%s[/color]" % [Color(EstiloUI.TEXTO, a).to_html(), _linhas_log[i]])
	_log.text = "\n".join(partes)


## Destaca um nome no registro com a cor do lado dele.
static func nome(c: Combatente) -> String:
	return "[color=#%s]%s[/color]" % [EstiloUI.cor_lado(c.aliado).lightened(0.3).to_html(false), c.nome]


static func destaque(texto: String, cor: Color) -> String:
	return "[color=#%s]%s[/color]" % [cor.to_html(false), texto]


func anunciar(texto: String, cor := EstiloUI.OURO, tamanho := 40) -> void:
	_anuncio.text = texto
	_anuncio.label_settings.font_color = cor
	_anuncio.label_settings.font_size = tamanho
	_anuncio.pivot_offset = _anuncio.size / 2
	_anuncio.modulate.a = 1
	_anuncio.scale = Vector2(1.4, 1.4)
	var t := create_tween()
	t.tween_property(_anuncio, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK)
	t.tween_interval(0.75)
	t.tween_property(_anuncio, "modulate:a", 0.0, 0.25)


func mostrar_fim(vitoria: bool, texto: String) -> void:
	_fim_texto.text = texto
	_fim_texto.label_settings.font_color = Color(0.6, 1, 0.7) if vitoria else Color(1, 0.45, 0.45)
	_fim.visible = true
	_dica.visible = false
	_opcoes.visible = false


# ------------------------------------------------------- controles (H)
func alternar_controles() -> void:
	_definir_controles(not _controles_abertos)
	var cfg := ConfigFile.new()
	cfg.load(ARQUIVO_PREFS)
	cfg.set_value("hud", "controles_abertos", _controles_abertos)
	cfg.save(ARQUIVO_PREFS)


func _definir_controles(abertos: bool) -> void:
	_controles_abertos = abertos
	_controles.visible = abertos
	_dica_controles.text = "" if abertos else "[H] controles"
	_dica_controles.visible = not abertos


func _carregar_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.load(ARQUIVO_PREFS)
	_definir_controles(cfg.get_value("hud", "controles_abertos", true))


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		alternar_controles()
		get_viewport().set_input_as_handled()

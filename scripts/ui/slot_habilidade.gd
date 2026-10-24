class_name SlotHabilidade
extends Control
## Um botão da barra de habilidades, montado a partir da descrição que o
## personagem dá (ver Combatente.habilidades()). Não sabe nada do kit:
## mostra ícone, tecla, custo, selo e o estado (pronta, sem recurso, bloqueada,
## em recarga, com os turnos que faltam no meio).
## Passivas aparecem sem tecla e com a marca "PASSIVA" (a do personagem no
## fim da barra; uma skill 2 passiva, no lugar dela); só
## respondem ao clique as que têm opções (como a lente do Andri).
## Todos os slots têm a mesma largura: nome que não cabe é cortado com
## reticências e, com o mouse em cima, corre para ser lido inteiro.

signal pedido(acao: String)
signal foco(acao: String)  ## "" quando o mouse sai

const LADO := 54.0
const LARGURA := 66.0  ## do slot com o nome; a barra não cresce com nomes longos
const TAMANHO_NOME := 10
const ESCALA_ICONE := 3.0  ## ícones de 15px viram 45px, como os sprites da arena

var dados := {}
var vez := false  ## é a vez do dono? fora da vez tudo fica apagado

var _sobre := false
var _tempo := 0.0
var _clarao := 0.0
var _icone: Texture2D
var _nome: _Nome


func _init() -> void:
	custom_minimum_size = Vector2(LARGURA, LADO + 14)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_nome = _Nome.new()
	add_child(_nome)
	resized.connect(func() -> void:
		_nome.position = Vector2(0, LADO + 1)
		_nome.size = Vector2(size.x, 16))
	mouse_entered.connect(func() -> void:
		_sobre = true
		_nome.correndo = true
		foco.emit(dados.get("acao", ""))
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_sobre = false
		_nome.correndo = false
		foco.emit("")
		queue_redraw())


func mostrar(p_dados: Dictionary, p_vez: bool) -> void:
	if p_dados.get("icone", "") != dados.get("icone", ""):
		_icone = load(p_dados.icone) if p_dados.get("icone", "") != "" else null
	dados = p_dados
	vez = p_vez
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interativa() else Control.CURSOR_ARROW
	set_process(_animado())
	queue_redraw()


func pronta() -> bool:
	return vez and dados.get("estado") == "pronta" and interativa()


func passiva() -> bool:
	return dados.get("passiva", false)


## Passivas sem opções só explicam; não são acionadas.
func interativa() -> bool:
	return not passiva() or dados.has("opcoes")


## Clarão rápido quando a habilidade é usada (tecla ou clique).
func acionar() -> void:
	_clarao = 1.0
	set_process(true)


func _animado() -> bool:
	return _clarao > 0 or (pronta() and dados.get("destaque", false))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if interativa():
			pedido.emit(dados.get("acao", ""))
		accept_event()


func _process(delta: float) -> void:
	_tempo += delta
	_clarao = maxf(0, _clarao - delta * 4)
	if not _animado():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if dados.is_empty():
		return
	var estado: String = dados.get("estado", "pronta")
	var ativa := pronta()
	var sobe := -2.0 if ativa and _sobre else 0.0
	var r := Rect2(Vector2(roundf((size.x - LADO) / 2), 2 + sobe), Vector2(LADO, LADO))
	var apagado := not vez

	# moldura
	draw_rect(r.grow(1), Color.BLACK)
	var fundo := EstiloUI.FUNDO_CLARO if ativa else EstiloUI.FUNDO
	draw_rect(r, fundo)
	draw_rect(Rect2(r.position, Vector2(LADO, 1)), Color(1, 1, 1, 0.08))
	var cor_borda := EstiloUI.BORDA
	if ativa:
		cor_borda = EstiloUI.OURO if _sobre else EstiloUI.BORDA_CLARA
	elif passiva():
		# moldura na cor do personagem: a passiva está sempre valendo
		var cor_p: Color = dados.get("cor", EstiloUI.BORDA_CLARA)
		cor_borda = cor_p.darkened(0.2 if vez else 0.55)
		if _sobre:
			cor_borda = EstiloUI.OURO
	draw_rect(r, cor_borda, false, 2.0 if ativa and _sobre else 1.0)
	if ativa and dados.get("destaque", false):
		var a := 0.35 + 0.35 * sin(_tempo * 4.0)
		var cor_d: Color = dados.get("cor", EstiloUI.OURO)
		draw_rect(r.grow(2), Color(cor_d, a), false, 1.0)

	# "poço" do ícone, mais claro, para ícones escuros não sumirem no fundo
	var poco := r.grow(-4)
	draw_rect(poco, Color(0.2, 0.19, 0.29) if ativa else Color(0.13, 0.12, 0.18))
	draw_rect(Rect2(poco.position, Vector2(poco.size.x, 1)), Color(0, 0, 0, 0.5))

	# ícone
	if _icone:
		var tam := _icone.get_size() * ESCALA_ICONE
		var ir := Rect2((r.get_center() - tam / 2).round(), tam)
		var mod := Color.WHITE
		if passiva():
			pass  # sempre ativa: o ícone não apaga por estado
		elif estado == "sem_recurso":
			mod = Color(0.5, 0.48, 0.55)
		elif estado == "recarga":
			mod = Color(0.35, 0.34, 0.4)
		elif estado == "bloqueada":
			mod = Color(0.3, 0.3, 0.34)
		if apagado:
			mod = mod.darkened(0.45)
		draw_texture_rect(_icone, ir, false, mod)

	# cadeado das bloqueadas
	if estado == "bloqueada":
		var c := r.get_center().round()
		draw_rect(Rect2(c + Vector2(-6, -1), Vector2(12, 9)), Color(0.75, 0.72, 0.8))
		draw_rect(Rect2(c + Vector2(-4, -6), Vector2(2, 5)), Color(0.75, 0.72, 0.8))
		draw_rect(Rect2(c + Vector2(2, -6), Vector2(2, 5)), Color(0.75, 0.72, 0.8))
		draw_rect(Rect2(c + Vector2(-2, -7), Vector2(4, 1)), Color(0.75, 0.72, 0.8))
		draw_rect(Rect2(c + Vector2(-1, 2), Vector2(2, 3)), Color.BLACK)

	# turnos que faltam da recarga, grandes, sobre o ícone apagado
	if estado == "recarga":
		EstiloUI.texto(self, Vector2(r.position.x, r.get_center().y + 8), str(dados.get("recarga_restante", 0)), 22,
			EstiloUI.TEXTO if not apagado else EstiloUI.TEXTO_FRACO, LADO, HORIZONTAL_ALIGNMENT_CENTER)

	# tecla no canto de cima (passivas não têm)
	if dados.get("tecla", "") != "":
		EstiloUI.tecla(self, r.position + Vector2(-3, -3), dados.tecla, not apagado)

	# selo no canto de cima à direita (nível, "TODOS", "MÁX"...)
	var selo: String = dados.get("selo", "")
	if selo != "":
		var f := EstiloUI.fonte()
		var w := f.get_string_size(selo, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 6
		var sr := Rect2(Vector2(r.end.x - w + 3, r.position.y - 3), Vector2(w, 12))
		var cor_selo: Color = dados.get("cor", EstiloUI.OURO)
		draw_rect(sr.grow(1), Color.BLACK)
		draw_rect(sr, cor_selo.darkened(0.35) if not apagado else Color(0.3, 0.3, 0.35))
		draw_string(f, sr.position + Vector2(0, 9), selo, HORIZONTAL_ALIGNMENT_CENTER, w, 9, Color.WHITE)

	# custo no canto de baixo
	var falta := estado in ["sem_recurso", "recarga"]
	var custo_pontos: int = dados.get("custo_pontos", 0)
	var custo_energia: int = dados.get("custo_energia", 0)
	var base := r.end + Vector2(-4, -4)
	if passiva():
		var cor_tag: Color = dados.get("cor", EstiloUI.TEXTO_FRACO)
		EstiloUI.texto(self, Vector2(r.position.x, base.y), "PASSIVA", 8, cor_tag.lightened(0.3) if not apagado else EstiloUI.TEXTO_FRACO,
			LADO, HORIZONTAL_ALIGNMENT_CENTER)
	elif custo_pontos > 0:
		for i in custo_pontos:
			EstiloUI.losango(self, base + Vector2(-4 - 9 * i, -3), 4, not falta and not apagado)
	elif custo_energia > 0:
		var cor_custo := EstiloUI.DANO_RECEBIDO if falta else EstiloUI.ENERGIA
		if apagado:
			cor_custo = cor_custo.darkened(0.4)
		EstiloUI.texto(self, Vector2(r.position.x, base.y), str(custo_energia), 10, cor_custo, LADO - 4, HORIZONTAL_ALIGNMENT_RIGHT)
	elif dados.get("ganho_pontos", 0) > 0:
		# habilidades que geram ponto mostram um "+◆" discreto
		EstiloUI.texto(self, Vector2(r.position.x, base.y), "+", 10, EstiloUI.PONTO, LADO - 13, HORIZONTAL_ALIGNMENT_RIGHT)
		EstiloUI.losango(self, base + Vector2(-4, -3), 3.5, not apagado)

	# nome embaixo (num filho que corta o que não cabe)
	var cor_nome := EstiloUI.TEXTO if ativa or (passiva() and vez) else EstiloUI.TEXTO_FRACO
	if ativa and _sobre:
		cor_nome = EstiloUI.OURO
	_nome.mostrar(dados.get("nome", ""), cor_nome)

	if _clarao > 0:
		draw_rect(r, Color(1, 1, 1, _clarao * 0.6))


## Nome embaixo do slot. Cabendo, fica centrado; se não, aparece cortado com
## reticências e, enquanto `correndo` (mouse em cima), desliza até o fim e
## volta, com uma pausa em cada ponta.
class _Nome extends Control:
	const VELOCIDADE := 30.0  ## px por segundo
	const PAUSA := 0.6  ## segundos parado em cada ponta
	const FOLGA := 2.0  ## margem de cada lado

	var correndo := false:
		set(v):
			if v == correndo:
				return
			correndo = v
			_tempo = 0.0
			set_process(correndo and _excesso() > 0)
			queue_redraw()

	var _texto := ""
	var _cor := Color.WHITE
	var _tempo := 0.0

	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)

	func mostrar(texto: String, cor: Color) -> void:
		if texto == _texto and cor == _cor:
			return
		_texto = texto
		_cor = cor
		queue_redraw()

	func _process(delta: float) -> void:
		_tempo += delta
		queue_redraw()

	func _largura(t: String) -> float:
		return EstiloUI.fonte().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANHO_NOME).x

	## Quanto o nome passa da largura disponível (0 = cabe).
	func _excesso() -> float:
		return maxf(0.0, _largura(_texto) - (size.x - 2 * FOLGA))

	## Deslocamento do texto no vaivém: pausa, ida, pausa, volta.
	func _deslocamento() -> float:
		var excesso := _excesso()
		var ida := excesso / VELOCIDADE
		var t := fmod(_tempo, 2.0 * (ida + PAUSA))
		if t < PAUSA:
			return 0.0
		t -= PAUSA
		if t < ida:
			return t * VELOCIDADE
		t -= ida
		if t < PAUSA:
			return excesso
		return excesso - (t - PAUSA) * VELOCIDADE

	## O nome cortado no último caractere que cabe junto com as reticências.
	func _cortado() -> String:
		var t := _texto
		while t.length() > 1 and _largura(t + "…") > size.x - 2 * FOLGA:
			t = t.left(-1)
		return t.strip_edges() + "…"

	func _draw() -> void:
		var base := 13.0
		if _excesso() <= 0:
			EstiloUI.texto(self, Vector2(0, base), _texto, TAMANHO_NOME, _cor, size.x, HORIZONTAL_ALIGNMENT_CENTER)
		elif correndo:
			EstiloUI.texto(self, Vector2(FOLGA - _deslocamento(), base), _texto, TAMANHO_NOME, _cor)
		else:
			EstiloUI.texto(self, Vector2(FOLGA, base), _cortado(), TAMANHO_NOME, _cor)

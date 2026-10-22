class_name SlotHabilidade
extends Control
## Um botão da barra de habilidades, montado a partir da descrição que o
## personagem dá (ver Combatente.habilidades()). Não sabe nada do kit:
## mostra ícone, tecla, custo, selo e o estado (pronta, sem recurso, bloqueada).

signal pedido(acao: String)
signal foco(acao: String)  ## "" quando o mouse sai

const LADO := 54.0
const ESCALA_ICONE := 3.0  ## ícones de 15px viram 45px, como os sprites da arena

var dados := {}
var vez := false  ## é a vez do dono? fora da vez tudo fica apagado

var _sobre := false
var _tempo := 0.0
var _clarao := 0.0
var _icone: Texture2D


func _init() -> void:
	custom_minimum_size = Vector2(LADO, LADO + 14)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void:
		_sobre = true
		foco.emit(dados.get("acao", ""))
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_sobre = false
		foco.emit("")
		queue_redraw())


func mostrar(p_dados: Dictionary, p_vez: bool) -> void:
	if p_dados.get("icone", "") != dados.get("icone", ""):
		_icone = load(p_dados.icone) if p_dados.get("icone", "") != "" else null
	dados = p_dados
	vez = p_vez
	set_process(_animado())
	queue_redraw()


func pronta() -> bool:
	return vez and dados.get("estado") == "pronta"


## Clarão rápido quando a habilidade é usada (tecla ou clique).
func acionar() -> void:
	_clarao = 1.0
	set_process(true)


func _animado() -> bool:
	return _clarao > 0 or (pronta() and dados.get("destaque", false))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
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
	var r := Rect2(Vector2(0, 2 + sobe), Vector2(LADO, LADO))
	var apagado := not vez

	# moldura
	draw_rect(r.grow(1), Color.BLACK)
	var fundo := EstiloUI.FUNDO_CLARO if ativa else EstiloUI.FUNDO
	draw_rect(r, fundo)
	draw_rect(Rect2(r.position, Vector2(LADO, 1)), Color(1, 1, 1, 0.08))
	var cor_borda := EstiloUI.BORDA
	if ativa:
		cor_borda = EstiloUI.OURO if _sobre else EstiloUI.BORDA_CLARA
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
		if estado == "sem_recurso":
			mod = Color(0.5, 0.48, 0.55)
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

	# tecla no canto de cima
	EstiloUI.tecla(self, r.position + Vector2(-3, -3), dados.get("tecla", ""), not apagado)

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
	var falta := estado == "sem_recurso"
	var custo_pontos: int = dados.get("custo_pontos", 0)
	var custo_energia: int = dados.get("custo_energia", 0)
	var base := r.end + Vector2(-4, -4)
	if custo_pontos > 0:
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

	# nome embaixo
	var cor_nome := EstiloUI.TEXTO if ativa else EstiloUI.TEXTO_FRACO
	if ativa and _sobre:
		cor_nome = EstiloUI.OURO
	EstiloUI.texto(self, Vector2(-8, LADO + 14), dados.get("nome", ""), 10, cor_nome, LADO + 16, HORIZONTAL_ALIGNMENT_CENTER)

	if _clarao > 0:
		draw_rect(r, Color(1, 1, 1, _clarao * 0.6))

class_name Interagivel
extends Node2D
## Algo do saguão que o jogador pode abordar: um personagem ou a porta.
## A origem fica nos pés (ou na base). O Lobby liga `em_foco` no mais
## próximo dentro do `raio`, e este nó desenha a dica: elipse no chão, nome
## e a tecla com a ação. O que acontece ao interagir fica com o Lobby:
## `ao_interagir` (a porta) ou a conversa de Conversas.de(id).

var id := ""
var nome := ""
var acao := "Falar"  ## texto ao lado da tecla
var raio := 78.0  ## distância (px de tela) para poder interagir
var altura := 100.0  ## a dica fica acima disto
var largura_base := 54.0  ## largura da elipse no chão
var cor := EstiloUI.OURO
## Opcional: () -> String. O motivo de ainda não dar para interagir ("" = liberado).
var requisito := Callable()
## Opcional: () -> void. Ação própria; sem ela, o Lobby abre a conversa.
var ao_interagir := Callable()
## Retrato para a caixa de diálogo.
var retrato: Texture2D

var em_foco := false:
	set(v):
		if v != em_foco:
			em_foco = v
			_tempo = 0.0
			queue_redraw()
			_chao.queue_redraw()

var _tempo := 0.0
var _chao := Node2D.new()  ## elipse, desenhada embaixo de todos


func _init() -> void:
	z_as_relative = false
	z_index = 20  # a dica fica por cima dos móveis e personagens
	_chao.z_as_relative = false
	_chao.z_index = -5
	_chao.draw.connect(_desenhar_chao)
	add_child(_chao)


func motivo_bloqueio() -> String:
	return requisito.call() if requisito.is_valid() else ""


func _process(delta: float) -> void:
	if em_foco:
		_tempo += delta
		queue_redraw()
		_chao.queue_redraw()


func _desenhar_chao() -> void:
	if not em_foco:
		return
	var pulso := 0.5 + 0.5 * sin(_tempo * 5.0)
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24
		pts.append(Vector2(cos(a) * largura_base / 2, -2 + sin(a) * 7))
	_chao.draw_colored_polygon(pts, Color(cor, 0.14 + 0.1 * pulso))
	pts.append(pts[0])
	_chao.draw_polyline(pts, Color(cor, 0.5 + 0.35 * pulso), 2.0)


func _draw() -> void:
	if not em_foco:
		return
	var f := EstiloUI.fonte()
	var y := -altura - 10.0 + sin(_tempo * 4.0) * 2.0
	if nome != "":
		EstiloUI.texto(self, Vector2(-100, y - 18), nome, 13, cor, 200, HORIZONTAL_ALIGNMENT_CENTER)
	var tecla := "Enter"
	var largura_tecla := maxf(13.0, 7.0 * tecla.length() + 6.0)
	var largura := largura_tecla + 5 + f.get_string_size(acao, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var x := -largura / 2
	EstiloUI.tecla(self, Vector2(x, y - 10), tecla)
	EstiloUI.texto(self, Vector2(x + largura_tecla + 5, y), acao, 11, EstiloUI.TEXTO)

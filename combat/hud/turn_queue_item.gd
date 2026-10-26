class_name ItemFila
extends Control
## Uma linha da ordem de ação: número na sequência, retrato, nome e
## pontinhos dos efeitos ativos. A linha da vez é maior, tem filete dourado
## e uma seta que pulsa na calha da esquerda.

const ALTURA := 20.0
const ALTURA_VEZ := 28.0
const CALHA := 14.0  ## espaço à esquerda para o número / seta

var combatente: Combatente
var retrato: Texture2D
var indice := 0
var vez := false
var _tempo := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func mostrar(c: Combatente, p_retrato: Texture2D, p_indice: int, p_vez: bool) -> void:
	combatente = c
	retrato = p_retrato
	indice = p_indice
	vez = p_vez
	custom_minimum_size.y = ALTURA_VEZ if vez else ALTURA
	set_process(vez)
	queue_redraw()


func _process(delta: float) -> void:
	_tempo += delta
	queue_redraw()


func _draw() -> void:
	if not combatente:
		return
	var h := size.y
	var cor := EstiloUI.cor_lado(combatente.aliado)
	var caixa := Rect2(CALHA, 0, size.x - CALHA, h)

	if vez:
		var dx := roundf(sin(_tempo * 5.0) * 1.5)
		var cy := h / 2
		var seta := PackedVector2Array([Vector2(2 + dx, cy - 5), Vector2(9 + dx, cy), Vector2(2 + dx, cy + 5)])
		draw_colored_polygon(seta, EstiloUI.OURO)
		draw_rect(caixa.grow(1), Color.BLACK)
		draw_rect(caixa, cor.darkened(0.72))
		draw_rect(caixa, EstiloUI.OURO, false, 1.0)
	else:
		EstiloUI.texto(self, Vector2(0, h - 6), str(indice + 1), 9, EstiloUI.TEXTO_FRACO, CALHA - 3, HORIZONTAL_ALIGNMENT_RIGHT)
		draw_rect(caixa, Color(0, 0, 0, 0.42))
	# faixa do lado (aliado/inimigo)
	draw_rect(Rect2(caixa.position, Vector2(3, h)), cor if vez else cor.darkened(0.25))

	var lado_retrato := 22.0 if vez else 16.0
	var pr := Rect2(caixa.position + Vector2(6, (h - lado_retrato) / 2), Vector2(lado_retrato, lado_retrato))
	draw_rect(pr, Color(0.03, 0.03, 0.06))
	if retrato:
		draw_texture_rect(retrato, pr, false)
	draw_rect(pr, cor.darkened(0.2) if not vez else EstiloUI.OURO.darkened(0.15), false, 1.0)

	var tamanho := 13 if vez else 11
	var nx := pr.end.x + 5
	var cor_nome := EstiloUI.TEXTO if vez else Color(0.8, 0.79, 0.86)
	var efeitos := combatente.efeitos()
	var espaco_pips := efeitos.size() * 10.0
	EstiloUI.texto(self, Vector2(nx, h / 2 + tamanho * 0.36), combatente.nome, tamanho, cor_nome,
		caixa.end.x - nx - espaco_pips - 4)

	# efeitos: quadradinhos com a cor do efeito, encostados à direita
	var x := caixa.end.x - 4
	for e: Dictionary in efeitos:
		x -= 10
		var r := Rect2(x, h / 2 - 4, 8, 8)
		draw_rect(r.grow(1), Color.BLACK)
		draw_rect(r, EstiloUI.cor_efeito(e))
		if e.get("tipo") == "alerta":
			draw_rect(Rect2(r.position + Vector2(3, 1), Vector2(2, 4)), Color.BLACK)
			draw_rect(Rect2(r.position + Vector2(3, 6), Vector2(2, 1)), Color.BLACK)

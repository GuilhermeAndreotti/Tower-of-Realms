class_name PixelFrame
extends StyleBox
## Moldura de pedra desenhada em pixels: contorno preto com os cantos
## cortados, filete na cor da borda (claro em cima, escuro embaixo, como pedra
## talhada), um segundo filete fino por dentro (janela dupla), rebites nos
## cantos e sombra dura, sem desfoque. Feita à mão porque o StyleBoxFlat só dá
## cantos arredondados e sombra borrada, que não combinam com a arte em pixel.

var bg_color := UIStyle.BACKGROUND
var border_color := UIStyle.BORDER
var border_width := 1
var shadow_size := 2  ## deslocamento da sombra para baixo (0 = sem sombra)
var studs := Color(0, 0, 0, 0)  ## rebites 2x2 nos cantos (alfa 0 = na cor da borda)
var open_top := false  ## sem borda em cima: encaixa embaixo de outro painel

const LARGE := 24.0  ## abaixo disso (etiquetas, linhas de opção) a moldura é simples


func _draw(ci: RID, rect: Rect2) -> void:
	var r := Rect2(rect.position.round(), rect.size.round())
	var top := 0.0 if open_top else 1.0
	if shadow_size > 0:
		_notched(ci, Rect2(r.position + Vector2(0, shadow_size), r.size), Color(UIStyle.SHADOW, UIStyle.SHADOW.a * bg_color.a))
	# contorno preto, só onde há borda (opções sem foco vêm com borda transparente)
	_notched(ci, r, Color(0, 0, 0, maxf(border_color.a, bg_color.a * 0.6)))
	var ring := Rect2(r.position + Vector2(1, top), r.size - Vector2(2, top + 1))
	var w := float(border_width)
	var inside := Rect2(ring.position + Vector2(w, w * top), ring.size - Vector2(w * 2, w * (top + 1)))
	RenderingServer.canvas_item_add_rect(ci, inside, bg_color)
	# filete: topo claro, base e laterais de baixo escuras
	if w > 0:
		if not open_top:
			RenderingServer.canvas_item_add_rect(ci, Rect2(ring.position, Vector2(ring.size.x, w)), border_color.lightened(0.2))
		RenderingServer.canvas_item_add_rect(ci, Rect2(ring.position.x, ring.end.y - w, ring.size.x, w), border_color.darkened(0.35))
		RenderingServer.canvas_item_add_rect(ci, Rect2(ring.position.x, inside.position.y, w, inside.size.y), border_color)
		RenderingServer.canvas_item_add_rect(ci, Rect2(ring.end.x - w, inside.position.y, w, inside.size.y), border_color.darkened(0.15))
	# brilho na primeira linha do fundo: dá volume sem gradiente
	RenderingServer.canvas_item_add_rect(ci, Rect2(inside.position, Vector2(inside.size.x, 1)), Color(1, 1, 1, 0.06 * bg_color.a))
	# painéis de verdade (não etiquetas) ganham o filete de dentro e os rebites
	if r.size.y < LARGE or r.size.x < LARGE:
		return
	if w > 0:
		var line := Color(border_color, border_color.a * 0.45)
		var l := inside.grow(-2)
		if open_top:
			l = Rect2(l.position.x, inside.position.y, l.size.x, l.end.y - inside.position.y)
		else:
			RenderingServer.canvas_item_add_rect(ci, Rect2(l.position, Vector2(l.size.x, 1)), line)
		RenderingServer.canvas_item_add_rect(ci, Rect2(l.position.x, l.end.y - 1, l.size.x, 1), line)
		RenderingServer.canvas_item_add_rect(ci, Rect2(l.position.x, l.position.y + 1, 1, l.size.y - 2), line)
		RenderingServer.canvas_item_add_rect(ci, Rect2(l.end.x - 1, l.position.y + 1, 1, l.size.y - 2), line)
	var stud := studs if studs.a > 0 else border_color.lightened(0.25)
	if stud.a > 0:
		var corners := [ring.position, Vector2(ring.end.x - 2, ring.position.y), Vector2(ring.position.x, ring.end.y - 2), ring.end - Vector2(2, 2)]
		for i in corners.size():
			if open_top and i < 2:
				continue
			RenderingServer.canvas_item_add_rect(ci, Rect2(corners[i] - Vector2.ONE, Vector2(4, 4)), Color.BLACK)
			RenderingServer.canvas_item_add_rect(ci, Rect2(corners[i], Vector2(2, 2)), stud)
			RenderingServer.canvas_item_add_rect(ci, Rect2(corners[i], Vector2(1, 1)), stud.lightened(0.5))


## Retângulo com os quatro cantos de 1 pixel cortados (os de cima ficam se
## `open_top`).
func _notched(ci: RID, r: Rect2, color: Color) -> void:
	if color.a <= 0:
		return
	if open_top:
		RenderingServer.canvas_item_add_rect(ci, Rect2(r.position, Vector2(r.size.x, r.size.y - 1)), color)
	else:
		RenderingServer.canvas_item_add_rect(ci, Rect2(r.position.x, r.position.y + 1, r.size.x, r.size.y - 2), color)
		RenderingServer.canvas_item_add_rect(ci, Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), color)
	RenderingServer.canvas_item_add_rect(ci, Rect2(r.position.x + 1, r.end.y - 1, r.size.x - 2, 1), color)

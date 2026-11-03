class_name UIStyle
extends RefCounted
## Paleta e peças de estilo da interface da Torre. Tudo que é cor, borda ou
## texto da HUD passa por aqui, para os componentes falarem a mesma língua.
## Identidade: pedra escura da torre + filete dourado de "vez/seleção";
## os personagens trazem as cores deles (aliado frio, inimigo quente).
## Painéis são molduras de pixel (PixelFrame) e o texto usa fonte pixelada,
## para a interface falar a mesma língua da arte.

const BODY_FONT := preload("res://ui/fonts/monogram.ttf")  ## a fonte do tema do projeto
const TITLE_FONT := preload("res://ui/fonts/silkscreen.ttf")  ## títulos e cabeçalhos

const BACKGROUND := Color(0.07, 0.06, 0.09, 0.92)
const LIGHT_BACKGROUND := Color(0.13, 0.11, 0.15, 0.96)
const BORDER := Color(0.36, 0.33, 0.43)
const LIGHT_BORDER := Color(0.58, 0.54, 0.66)
const SHADOW := Color(0, 0, 0, 0.55)
const TEXT := Color(0.93, 0.92, 0.96)
const DIM_TEXT := Color(0.6, 0.58, 0.7)
const GOLD := Color(1.0, 0.8, 0.32)
const DIM_GOLD := Color(0.78, 0.6, 0.3)  ## cabeçalhos de painel
const WARM_BACKGROUND := Color(0.21, 0.16, 0.09, 0.96)  ## botão em foco

const ALLY := Color(0.38, 0.62, 1.0)
const ENEMY := Color(0.95, 0.36, 0.38)

const HP := Color(0.33, 0.86, 0.47)
const LOW_HP := Color(0.95, 0.42, 0.3)
const ENERGY := Color(1.0, 0.78, 0.25)
const POINT := Color(0.55, 0.88, 1.0)
const SHIELD := Color(0.35, 0.68, 1.0)  ## contorno e faixa de escudo nas barras de HP
const XP := Color(0.62, 0.5, 1.0)

## Cores dos números e mensagens de combate, por tipo de evento.
const DAMAGE := Color(1, 0.95, 0.85)
const WEAK_DAMAGE := Color(0.85, 0.82, 0.78)
const CRITICAL_DAMAGE := Color(1.0, 0.85, 0.2)
const DAMAGE_TAKEN := Color(1, 0.4, 0.4)
const HEAL := Color(0.45, 1.0, 0.55)
const DRAIN := Color(1, 0.55, 0.2)

## Cor padrão de cada tipo de efeito de status (o efeito pode trazer a sua).
const EFFECT_TYPE_COLORS := {
	"buff": Color(0.45, 0.9, 0.55),
	"debuff": Color(0.62, 0.6, 0.75),
	"alert": Color(1.0, 0.55, 0.25),
}

const MARGIN := 8.0  ## distância dos painéis até a borda da tela


## Fontes pixeladas só ficam nítidas na grade em que foram desenhadas: a
## monogram em 16 e a Silkscreen em 8. Fixando o tamanho com escala inteira,
## qualquer font_size pedido cai na grade (até 23 sai em 16, de 24 em diante
## em 32...) e a tela amplia o texto como amplia os sprites. Feito ao carregar
## a classe, antes de qualquer tela desenhar; o recurso é o mesmo do tema.
static var _fonts_ready := _pixel_fonts()


static func _pixel_fonts() -> bool:
	for pair: Array in [[BODY_FONT, 16], [TITLE_FONT, 8]]:
		var f: FontFile = pair[0]
		f.fixed_size = pair[1]
		f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	return true


static func side_color(ally: bool) -> Color:
	return ALLY if ally else ENEMY


static func effect_color(effect: Dictionary) -> Color:
	return effect.get("color", EFFECT_TYPE_COLORS.get(effect.get("type", ""), TEXT))


static func font() -> Font:
	return BODY_FONT


## Painel de pedra com moldura de pixel. `studs`: rebites nos cantos, para os
## painéis que pedem destaque (diálogo, confirmação, fim da batalha).
static func panel(background := BACKGROUND, border := BORDER, border_width := 1, studs := Color(0, 0, 0, 0)) -> PixelFrame:
	var s := PixelFrame.new()
	s.bg_color = background
	s.border_color = border
	s.border_width = border_width
	s.studs = studs
	s.set_content_margin_all(6)
	return s


## Botão de pedra com filete dourado: em foco esquenta e acende, apertado
## afunda 1 pixel (sem sombra). Usado no menu, nas telas da Torre e no fim da
## batalha.
static func button(b: Button, font_size := 16) -> void:
	b.add_theme_font_override("font", TITLE_FONT)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", GOLD)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", DIM_TEXT)
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_theme_constant_override("outline_size", 3)
	b.add_theme_stylebox_override("normal", panel(LIGHT_BACKGROUND, GOLD.darkened(0.45), 2, GOLD.darkened(0.3)))
	var highlight := panel(WARM_BACKGROUND, GOLD, 2, Color.WHITE)
	b.add_theme_stylebox_override("hover", highlight)
	b.add_theme_stylebox_override("focus", highlight)
	var pressed := panel(WARM_BACKGROUND.darkened(0.3), GOLD.lightened(0.3), 2, Color.WHITE)
	pressed.shadow_size = 0
	pressed.content_margin_top += 2
	pressed.content_margin_bottom -= 2
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", panel(BACKGROUND, BORDER, 2))


static func label(text := "", font_size := 12, color := TEXT, outline := 3) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font_size = font_size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = Color.BLACK
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Cabeçalho de painel ("ORDEM DE AÇÃO", "INIMIGOS"...) e títulos de tela, na
## fonte de título. Tamanhos múltiplos de 8 saem com o pixel mais limpo.
static func heading(text := "", font_size := 8, color := DIM_GOLD, outline := 2) -> Label:
	var l := label(text, font_size, color, outline)
	l.label_settings.font = TITLE_FONT
	return l


## Selo do elemento (Types) desenhado direto num CanvasItem, com o canto
## esquerdo de cima em `pos`. `short` usa a sigla. Devolve a largura.
static func type_badge(ci: CanvasItem, pos: Vector2, type: String, font_size := 9, short := false) -> float:
	var t := Types.abbr(type) if short else Types.name(type)
	var color := Types.color(type)
	var width := type_badge_width(type, font_size, short)
	var r := Rect2(pos, Vector2(width, font_size + 3))
	ci.draw_rect(r.grow(1), Color.BLACK)
	ci.draw_rect(r, color.darkened(0.65))
	ci.draw_rect(r, color, false, 1.0)
	ci.draw_string(font(), pos + Vector2(3, font_size), t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color.lightened(0.4))
	return width


static func type_badge_width(type: String, font_size := 9, short := false) -> float:
	var t := Types.abbr(type) if short else Types.name(type)
	return ceilf(font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) + 6


## O mesmo selo como Control, para painéis montados com containers.
static func type_tag(type: String, font_size := 9) -> PanelContainer:
	var p := tag(Types.name(type), Types.color(type), font_size)
	p.tooltip_text = "Elemento: " + Types.name(type)
	return p


## Etiqueta curta na cor `color` (custo, recarga, alvo...), no formato do
## selo de elemento.
static func tag(text: String, color: Color, font_size := 9) -> PanelContainer:
	var p := PanelContainer.new()
	var s := panel(color.darkened(0.65), color, 1)
	s.shadow_size = 1
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(label(text, font_size, color.lightened(0.4), 2))
	return p


## Texto com contorno desenhado direto num CanvasItem (componentes com _draw).
static func text(ci: CanvasItem, pos: Vector2, t: String, font_size: int, color: Color,
		width := -1.0, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := font()
	ci.draw_string_outline(f, pos, t, alignment, width, font_size, 3, Color.BLACK)
	ci.draw_string(f, pos, t, alignment, width, font_size, color)


## Losango de ponto de skill, cheio ou vazio, centrado em `c`.
static func diamond(ci: CanvasItem, c: Vector2, r: float, full: bool) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	ci.draw_colored_polygon(pts, POINT if full else Color(0.1, 0.1, 0.16))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color.WHITE if full else Color(0.35, 0.35, 0.47), 1.0)


## Retângulo de cantos levemente arredondados, em degraus de pixel (raio 2:
## um degrau de 2 e um de 1). Cheio, ou só o contorno com `width` 1 ou 2.
static func rounded_rect(ci: CanvasItem, r: Rect2, color: Color, radius := 2, filled := true, width := 1) -> void:
	r = Rect2(r.position.round(), r.size.round())
	if not filled:
		_rounded_outline(ci, r, color, radius)
		if width > 1:
			_rounded_outline(ci, r.grow(-1), color, maxi(radius - 1, 1))
		return
	for i in radius:
		var inset := radius - i
		ci.draw_rect(Rect2(r.position.x + inset, r.position.y + i, r.size.x - inset * 2, 1), color)
		ci.draw_rect(Rect2(r.position.x + inset, r.end.y - 1 - i, r.size.x - inset * 2, 1), color)
	ci.draw_rect(Rect2(r.position.x, r.position.y + radius, r.size.x, r.size.y - radius * 2), color)


static func _rounded_outline(ci: CanvasItem, r: Rect2, color: Color, radius: int) -> void:
	ci.draw_rect(Rect2(r.position.x + radius, r.position.y, r.size.x - radius * 2, 1), color)
	ci.draw_rect(Rect2(r.position.x + radius, r.end.y - 1, r.size.x - radius * 2, 1), color)
	ci.draw_rect(Rect2(r.position.x, r.position.y + radius, 1, r.size.y - radius * 2), color)
	ci.draw_rect(Rect2(r.end.x - 1, r.position.y + radius, 1, r.size.y - radius * 2), color)
	# degraus da curva, nos quatro cantos
	for k in range(1, radius):
		for corner: Vector2 in [r.position + Vector2(radius - k, k), Vector2(r.end.x - 1 - radius + k, r.position.y + k),
				Vector2(r.position.x + radius - k, r.end.y - 1 - k), r.end - Vector2.ONE - Vector2(radius - k, k)]:
			ci.draw_rect(Rect2(corner, Vector2.ONE), color)


## Selo de tecla (ex.: "Q"): quadradinho claro com a letra escura.
static func key(ci: CanvasItem, pos: Vector2, letter: String, active := true) -> void:
	var w := maxf(13.0, 7.0 * letter.length() + 6.0)
	var r := Rect2(pos, Vector2(w, 13))
	rounded_rect(ci, r.grow(1), Color.BLACK, 2)
	rounded_rect(ci, r, Color(0.9, 0.88, 0.95) if active else Color(0.4, 0.4, 0.46), 1)
	ci.draw_rect(Rect2(r.position + Vector2(1, r.size.y - 2), Vector2(w - 2, 1)), Color(0.55, 0.52, 0.65) if active else Color(0.28, 0.28, 0.33))
	ci.draw_rect(Rect2(r.position + Vector2(2, r.size.y - 1), Vector2(w - 4, 1)), Color(0.55, 0.52, 0.65) if active else Color(0.28, 0.28, 0.33))
	var ink := Color(0.08, 0.07, 0.12)
	if ARROWS.has(letter):
		_arrow(ci, r.position + Vector2(roundf(w / 2), 5), ARROWS[letter], ink)
		return
	ci.draw_string(font(), pos + Vector2(0, 10), letter, HORIZONTAL_ALIGNMENT_CENTER, w, 10, ink)


## As setas da monogram são miúdas demais para a tecla: são desenhadas.
const ARROWS := {"←": Vector2.LEFT, "→": Vector2.RIGHT, "↑": Vector2.UP, "↓": Vector2.DOWN}


## Seta de pixel (ponta de 3 degraus + haste) centrada em `c`.
static func _arrow(ci: CanvasItem, c: Vector2, direction: Vector2, color: Color) -> void:
	var side := Vector2(-direction.y, direction.x)
	for i in 3:
		var tip := c + direction * (2 - i)
		for j in range(-i, i + 1):
			ci.draw_rect(Rect2(tip + side * j, Vector2.ONE), color)
	for i in range(1, 4):
		ci.draw_rect(Rect2(c - direction * i, Vector2.ONE), color)


## Escudo numa barra de HP de retângulo `r` (borda incluída): contorno azul
## em volta e, embaixo, uma faixa com `fraction` do comprimento (escudo / HP
## máximo, cortada na barra cheia). Mesmo desenho na HUD e na arena.
static func shield_outline(ci: CanvasItem, r: Rect2, fraction: float) -> void:
	var inside := r.grow(-1)
	var height := maxf(2.0, roundf(inside.size.y * 0.4))
	var band := Rect2(inside.position.x, inside.end.y - height, roundf(inside.size.x * clampf(fraction, 0.0, 1.0)), height)
	ci.draw_rect(band, SHIELD)
	ci.draw_rect(Rect2(band.position, Vector2(band.size.x, 1)), SHIELD.lightened(0.5))
	ci.draw_rect(r.grow(1), Color.BLACK, false, 1.0)
	ci.draw_rect(r, SHIELD.lightened(0.15), false, 1.0)


# ------------------------------------------------- registro da batalha (BBCode)
## Destaca um nome no registro com a cor do lado dele.
static func fighter_name(c: Combatant) -> String:
	return "[color=#%s]%s[/color]" % [side_color(c.ally).lightened(0.3).to_html(false), c.name]


static func highlight(text: String, color: Color) -> String:
	return "[color=#%s]%s[/color]" % [color.to_html(false), text]

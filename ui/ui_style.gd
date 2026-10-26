class_name UIStyle
extends RefCounted
## Paleta e peças de estilo da interface da Torre. Tudo que é cor, borda ou
## texto da HUD passa por aqui, para os componentes falarem a mesma língua.
## Identidade: pedra escura da torre + filete dourado de "vez/seleção";
## os personagens trazem as cores deles (aliado frio, inimigo quente).

const BACKGROUND := Color(0.055, 0.05, 0.09, 0.9)
const LIGHT_BACKGROUND := Color(0.11, 0.1, 0.17, 0.94)
const BORDER := Color(0.3, 0.27, 0.42)
const LIGHT_BORDER := Color(0.52, 0.48, 0.68)
const SHADOW := Color(0, 0, 0, 0.55)
const TEXT := Color(0.93, 0.92, 0.96)
const DIM_TEXT := Color(0.6, 0.58, 0.7)
const GOLD := Color(1.0, 0.8, 0.32)

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


static func side_color(ally: bool) -> Color:
	return ALLY if ally else ENEMY


static func effect_color(effect: Dictionary) -> Color:
	return effect.get("color", EFFECT_TYPE_COLORS.get(effect.get("type", ""), TEXT))


static func source() -> Font:
	return ThemeDB.fallback_font


## Painel de pedra com cantos chanfrados (corner_detail 1 = corte reto).
static func panel(background := BACKGROUND, border := BORDER, border_width := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = background
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(4)
	s.corner_detail = 1
	s.shadow_color = SHADOW
	s.shadow_size = 2
	s.shadow_offset = Vector2(0, 2)
	s.set_content_margin_all(6)
	return s


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
	ci.draw_string(source(), pos + Vector2(3, font_size), t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color.lightened(0.4))
	return width


static func type_badge_width(type: String, font_size := 9, short := false) -> float:
	var t := Types.abbr(type) if short else Types.name(type)
	return ceilf(source().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) + 6


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
	s.shadow_size = 0
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
	var f := source()
	ci.draw_string_outline(f, pos, t, alignment, width, font_size, 3, Color.BLACK)
	ci.draw_string(f, pos, t, alignment, width, font_size, color)


## Losango de ponto de skill, cheio ou vazio, centrado em `c`.
static func diamond(ci: CanvasItem, c: Vector2, r: float, full: bool) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	ci.draw_colored_polygon(pts, POINT if full else Color(0.1, 0.1, 0.16))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color.WHITE if full else Color(0.35, 0.35, 0.47), 1.0)


## Selo de tecla (ex.: "Q"): quadradinho claro com a letra escura.
static func key(ci: CanvasItem, pos: Vector2, letter: String, active := true) -> void:
	var w := maxf(13.0, 7.0 * letter.length() + 6.0)
	var r := Rect2(pos, Vector2(w, 13))
	ci.draw_rect(r.grow(1), Color.BLACK)
	ci.draw_rect(r, Color(0.9, 0.88, 0.95) if active else Color(0.4, 0.4, 0.46))
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(w, 2)), Color(0.55, 0.52, 0.65) if active else Color(0.28, 0.28, 0.33))
	ci.draw_string(source(), pos + Vector2(0, 10), letter, HORIZONTAL_ALIGNMENT_CENTER, w, 10, Color(0.08, 0.07, 0.12))


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

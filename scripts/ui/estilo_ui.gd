class_name EstiloUI
extends RefCounted
## Paleta e peças de estilo da interface da Torre. Tudo que é cor, borda ou
## texto da HUD passa por aqui, para os componentes falarem a mesma língua.
## Identidade: pedra escura da torre + filete dourado de "vez/seleção";
## os personagens trazem as cores deles (aliado frio, inimigo quente).

const FUNDO := Color(0.055, 0.05, 0.09, 0.9)
const FUNDO_CLARO := Color(0.11, 0.1, 0.17, 0.94)
const BORDA := Color(0.3, 0.27, 0.42)
const BORDA_CLARA := Color(0.52, 0.48, 0.68)
const SOMBRA := Color(0, 0, 0, 0.55)
const TEXTO := Color(0.93, 0.92, 0.96)
const TEXTO_FRACO := Color(0.6, 0.58, 0.7)
const OURO := Color(1.0, 0.8, 0.32)

const ALIADO := Color(0.38, 0.62, 1.0)
const INIMIGO := Color(0.95, 0.36, 0.38)

const HP := Color(0.33, 0.86, 0.47)
const HP_BAIXO := Color(0.95, 0.42, 0.3)
const ENERGIA := Color(1.0, 0.78, 0.25)
const PONTO := Color(0.55, 0.88, 1.0)
const XP := Color(0.62, 0.5, 1.0)

## Cores dos números e mensagens de combate, por tipo de evento.
const DANO := Color(1, 0.95, 0.85)
const DANO_FRACO := Color(0.85, 0.82, 0.78)
const DANO_CRITICO := Color(1.0, 0.85, 0.2)
const DANO_RECEBIDO := Color(1, 0.4, 0.4)
const CURA := Color(0.45, 1.0, 0.55)
const DRENO := Color(1, 0.55, 0.2)

## Cor padrão de cada tipo de efeito de status (o efeito pode trazer a sua).
const COR_TIPO_EFEITO := {
	"buff": Color(0.45, 0.9, 0.55),
	"debuff": Color(0.62, 0.6, 0.75),
	"alerta": Color(1.0, 0.55, 0.25),
}

const MARGEM := 8.0  ## distância dos painéis até a borda da tela


static func cor_lado(aliado: bool) -> Color:
	return ALIADO if aliado else INIMIGO


static func cor_efeito(efeito: Dictionary) -> Color:
	return efeito.get("cor", COR_TIPO_EFEITO.get(efeito.get("tipo", ""), TEXTO))


static func fonte() -> Font:
	return ThemeDB.fallback_font


## Painel de pedra com cantos chanfrados (corner_detail 1 = corte reto).
static func painel(fundo := FUNDO, borda := BORDA, largura_borda := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo
	s.border_color = borda
	s.set_border_width_all(largura_borda)
	s.set_corner_radius_all(4)
	s.corner_detail = 1
	s.shadow_color = SOMBRA
	s.shadow_size = 2
	s.shadow_offset = Vector2(0, 2)
	s.set_content_margin_all(6)
	return s


static func label(texto := "", tamanho := 12, cor := TEXTO, contorno := 3) -> Label:
	var l := Label.new()
	l.text = texto
	var ls := LabelSettings.new()
	ls.font_size = tamanho
	ls.font_color = cor
	ls.outline_size = contorno
	ls.outline_color = Color.BLACK
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Selo do elemento (Tipos) desenhado direto num CanvasItem, com o canto
## esquerdo de cima em `pos`. `curto` usa a sigla. Devolve a largura.
static func selo_tipo(ci: CanvasItem, pos: Vector2, tipo: String, tamanho := 9, curto := false) -> float:
	var t := Tipos.sigla(tipo) if curto else Tipos.nome(tipo)
	var cor := Tipos.cor(tipo)
	var largura := largura_selo_tipo(tipo, tamanho, curto)
	var r := Rect2(pos, Vector2(largura, tamanho + 3))
	ci.draw_rect(r.grow(1), Color.BLACK)
	ci.draw_rect(r, cor.darkened(0.65))
	ci.draw_rect(r, cor, false, 1.0)
	ci.draw_string(fonte(), pos + Vector2(3, tamanho), t, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor.lightened(0.4))
	return largura


static func largura_selo_tipo(tipo: String, tamanho := 9, curto := false) -> float:
	var t := Tipos.sigla(tipo) if curto else Tipos.nome(tipo)
	return ceilf(fonte().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x) + 6


## O mesmo selo como Control, para painéis montados com containers.
static func etiqueta_tipo(tipo: String, tamanho := 9) -> PanelContainer:
	var p := etiqueta(Tipos.nome(tipo), Tipos.cor(tipo), tamanho)
	p.tooltip_text = "Elemento: " + Tipos.nome(tipo)
	return p


## Etiqueta curta na cor `cor` (custo, recarga, alvo...), no formato do
## selo de elemento.
static func etiqueta(texto: String, cor: Color, tamanho := 9) -> PanelContainer:
	var p := PanelContainer.new()
	var s := painel(cor.darkened(0.65), cor, 1)
	s.shadow_size = 0
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(label(texto, tamanho, cor.lightened(0.4), 2))
	return p


## Texto com contorno desenhado direto num CanvasItem (componentes com _draw).
static func texto(ci: CanvasItem, pos: Vector2, t: String, tamanho: int, cor: Color,
		largura := -1.0, alinhamento := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := fonte()
	ci.draw_string_outline(f, pos, t, alinhamento, largura, tamanho, 3, Color.BLACK)
	ci.draw_string(f, pos, t, alinhamento, largura, tamanho, cor)


## Losango de ponto de skill, cheio ou vazio, centrado em `c`.
static func losango(ci: CanvasItem, c: Vector2, r: float, cheio: bool) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	ci.draw_colored_polygon(pts, PONTO if cheio else Color(0.1, 0.1, 0.16))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color.WHITE if cheio else Color(0.35, 0.35, 0.47), 1.0)


## Selo de tecla (ex.: "Q"): quadradinho claro com a letra escura.
static func tecla(ci: CanvasItem, pos: Vector2, letra: String, ativo := true) -> void:
	var w := maxf(13.0, 7.0 * letra.length() + 6.0)
	var r := Rect2(pos, Vector2(w, 13))
	ci.draw_rect(r.grow(1), Color.BLACK)
	ci.draw_rect(r, Color(0.9, 0.88, 0.95) if ativo else Color(0.4, 0.4, 0.46))
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(w, 2)), Color(0.55, 0.52, 0.65) if ativo else Color(0.28, 0.28, 0.33))
	ci.draw_string(fonte(), pos + Vector2(0, 10), letra, HORIZONTAL_ALIGNMENT_CENTER, w, 10, Color(0.08, 0.07, 0.12))

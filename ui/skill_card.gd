class_name SkillCard
extends VBoxContainer
## Explicação de uma habilidade, montada a partir da descrição que o
## personagem dá (ver Combatant.skills()): nome, etiquetas (passiva,
## custo, recarga, alvo, elemento), o resumo e, quando o kit manda
## "details", uma linha por item (um demônio, uma opção, um nível...), para
## o jogador não ter de garimpar um parágrafo. Usado na dica da barra da
## batalha e na ficha da montagem da equipe.

const TARGET_TEXT := {
	"single": "Alvo único",
	"pair": "Alvo + 1 atrás",
	"neighbors": "Alvo + vizinhos",
	"all": "Todos os inimigos",
	"self": "Em si",
	"ally": "Aliado ou em si",
}
const SUMMARY_COLOR := Color(0.84, 0.82, 0.9)

var _name := true  ## false: quem usa já mostra o nome (a ficha da equipe)
var _shown := []  ## [h, falta] da última montagem: a HUD pede de novo a cada atualização


## `with_name`: false quando o nome já aparece ao lado (e só as etiquetas
## vão na primeira linha).
func _init(with_name := true) -> void:
	_name = with_name
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Remonta o cartão para `h`. `missing_reason`: por que não dá para usar agora
## (só na batalha; vazio esconde).
func display(h: Dictionary, missing_reason := "") -> void:
	if _shown == [h, missing_reason]:
		return
	_shown = [h.duplicate(true), missing_reason]
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if _name:
		add_child(UIStyle.label(h.name, 13, UIStyle.GOLD, 3))
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 4)
	tags.add_theme_constant_override("v_separation", 3)
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for e in _tags(h):
		tags.add_child(e)
	add_child(tags)
	if h.get("description", "") != "":
		add_child(_text(h.description, 10, SUMMARY_COLOR))
	var details: Array = h.get("details", [])
	if not details.is_empty():
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 3)
		list.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for d: Dictionary in details:
			list.add_child(_line(d, h.get("color", UIStyle.LIGHT_BORDER)))
		add_child(list)
	if missing_reason != "":
		add_child(_text(missing_reason, 10, UIStyle.DAMAGE_TAKEN))


func _tags(h: Dictionary) -> Array[Control]:
	var list: Array[Control] = []
	for e in tags(h):
		list.append(UIStyle.type_tag(e.type) if e.has("type") else UIStyle.tag(e.text, e.color))
	return list


## Textos das etiquetas de `h`, na ordem do cartão: [{"text", "color"}], e o
## elemento como {"text", "type"}. Público para o README dos personagens
## (tools/generate_character_readmes.gd) usar as mesmas palavras.
static func tags(h: Dictionary) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var color: Color = h.get("color", UIStyle.LIGHT_BORDER)
	var passive: bool = h.get("passive", false)
	if passive:
		list.append({"text": "PASSIVA", "color": color})
	if h.get("point_cost", 0) > 0:
		list.append({"text": "%d ponto%s" % [h.point_cost, "" if h.point_cost == 1 else "s"], "color": UIStyle.POINT})
	if h.get("energy_cost", 0) > 0:
		list.append({"text": "%d energia" % h.energy_cost, "color": UIStyle.ENERGY})
	if h.get("resource_cost", "") != "":
		list.append({"text": h.resource_cost, "color": color})
	if h.get("point_gain", 0) > 0:
		list.append({"text": "gera %d ponto" % h.point_gain, "color": UIStyle.POINT})
	if h.get("cooldown", 0) > 0:
		list.append({"text": "recarga %d turnos" % h.cooldown, "color": UIStyle.LIGHT_BORDER})
	if h.get("free", false) and not passive:
		list.append({"text": "não gasta o turno", "color": UIStyle.HP})
	if not passive and TARGET_TEXT.has(h.get("target", "")):
		list.append({"text": TARGET_TEXT[h.target], "color": UIStyle.DIM_TEXT})
	if h.has("type"):
		list.append({"text": Types.name(h.type), "type": h.type})
	return list


## Um item dos detalhes: filete na cor dele, rótulo (com a "mark" ao lado)
## e embaixo o texto e/ou os "values" (um por nível, o atual em dourado).
## O "current" (o nível em que ela está, o demônio em campo...) ganha fundo.
func _line(d: Dictionary, default_color: Color) -> Control:
	var color: Color = d.get("color", default_color)
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.16) if d.get("current", false) else Color(0, 0, 0, 0.22)
	style.border_color = color
	style.border_width_left = 2
	style.content_margin_left = 6
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := HBoxContainer.new()
	label.add_theme_constant_override("separation", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_child(UIStyle.label(d.label, 10, color.lightened(0.3), 2))
	if d.get("mark", "") != "":
		var mark := UIStyle.label(d.mark, 9, UIStyle.DIM_TEXT, 2)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.add_child(mark)
	v.add_child(label)
	if d.get("text", "") != "":
		v.add_child(_text(d.text, 9, UIStyle.TEXT))
	var values: Array = d.get("values", [])
	if not values.is_empty():
		var band := HFlowContainer.new()
		band.add_theme_constant_override("h_separation", 3)
		band.add_theme_constant_override("v_separation", 2)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for value: Dictionary in values:
			band.add_child(UIStyle.tag(value.text, UIStyle.GOLD if value.get("current", false) else UIStyle.LIGHT_BORDER))
		v.add_child(band)
	p.add_child(v)
	return p


func _text(t: String, font_size: int, color: Color) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", font_size)
	r.add_theme_font_size_override("bold_font_size", font_size)
	r.add_theme_constant_override("outline_size", 3)
	r.add_theme_color_override("font_outline_color", Color.BLACK)
	r.add_theme_color_override("default_color", color)
	r.text = t
	return r

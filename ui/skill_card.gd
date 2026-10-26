class_name CartaoHabilidade
extends VBoxContainer
## Explicação de uma habilidade, montada a partir da descrição que o
## personagem dá (ver Combatente.habilidades()): nome, etiquetas (passiva,
## custo, recarga, alvo, elemento), o resumo e, quando o kit manda
## "detalhes", uma linha por item (um demônio, uma opção, um nível...), para
## o jogador não ter de garimpar um parágrafo. Usado na dica da barra da
## batalha e na ficha da montagem da equipe.

const TEXTO_ALVO := {
	"unico": "Alvo único",
	"dupla": "Alvo + 1 atrás",
	"vizinhos": "Alvo + vizinhos",
	"todos": "Todos os inimigos",
	"proprio": "Em si",
	"aliado": "Aliado ou em si",
}
const COR_RESUMO := Color(0.84, 0.82, 0.9)

var _nome := true  ## false: quem usa já mostra o nome (a ficha da equipe)
var _mostrado := []  ## [h, falta] da última montagem: a HUD pede de novo a cada atualização


## `com_nome`: false quando o nome já aparece ao lado (e só as etiquetas
## vão na primeira linha).
func _init(com_nome := true) -> void:
	_nome = com_nome
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Remonta o cartão para `h`. `falta`: por que não dá para usar agora
## (só na batalha; vazio esconde).
func mostrar(h: Dictionary, falta := "") -> void:
	if _mostrado == [h, falta]:
		return
	_mostrado = [h.duplicate(true), falta]
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	if _nome:
		add_child(EstiloUI.label(h.nome, 13, EstiloUI.OURO, 3))
	var etiquetas := HFlowContainer.new()
	etiquetas.add_theme_constant_override("h_separation", 4)
	etiquetas.add_theme_constant_override("v_separation", 3)
	etiquetas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for e in _etiquetas(h):
		etiquetas.add_child(e)
	add_child(etiquetas)
	if h.get("descricao", "") != "":
		add_child(_texto(h.descricao, 10, COR_RESUMO))
	var detalhes: Array = h.get("detalhes", [])
	if not detalhes.is_empty():
		var lista := VBoxContainer.new()
		lista.add_theme_constant_override("separation", 3)
		lista.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for d: Dictionary in detalhes:
			lista.add_child(_linha(d, h.get("cor", EstiloUI.BORDA_CLARA)))
		add_child(lista)
	if falta != "":
		add_child(_texto(falta, 10, EstiloUI.DANO_RECEBIDO))


func _etiquetas(h: Dictionary) -> Array[Control]:
	var lista: Array[Control] = []
	for e in etiquetas(h):
		lista.append(EstiloUI.etiqueta_tipo(e.tipo) if e.has("tipo") else EstiloUI.etiqueta(e.texto, e.cor))
	return lista


## Textos das etiquetas de `h`, na ordem do cartão: [{"texto", "cor"}], e o
## elemento como {"texto", "tipo"}. Público para o README dos personagens
## (tools/generate_character_readmes.gd) usar as mesmas palavras.
static func etiquetas(h: Dictionary) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var cor: Color = h.get("cor", EstiloUI.BORDA_CLARA)
	var passiva: bool = h.get("passiva", false)
	if passiva:
		lista.append({"texto": "PASSIVA", "cor": cor})
	if h.get("custo_pontos", 0) > 0:
		lista.append({"texto": "%d ponto%s" % [h.custo_pontos, "" if h.custo_pontos == 1 else "s"], "cor": EstiloUI.PONTO})
	if h.get("custo_energia", 0) > 0:
		lista.append({"texto": "%d energia" % h.custo_energia, "cor": EstiloUI.ENERGIA})
	if h.get("custo_recurso", "") != "":
		lista.append({"texto": h.custo_recurso, "cor": cor})
	if h.get("ganho_pontos", 0) > 0:
		lista.append({"texto": "gera %d ponto" % h.ganho_pontos, "cor": EstiloUI.PONTO})
	if h.get("recarga", 0) > 0:
		lista.append({"texto": "recarga %d turnos" % h.recarga, "cor": EstiloUI.BORDA_CLARA})
	if h.get("livre", false) and not passiva:
		lista.append({"texto": "não gasta o turno", "cor": EstiloUI.HP})
	if not passiva and TEXTO_ALVO.has(h.get("alvo", "")):
		lista.append({"texto": TEXTO_ALVO[h.alvo], "cor": EstiloUI.TEXTO_FRACO})
	if h.has("tipo"):
		lista.append({"texto": Tipos.nome(h.tipo), "tipo": h.tipo})
	return lista


## Um item dos detalhes: filete na cor dele, rótulo (com a "marca" ao lado)
## e embaixo o texto e/ou os "valores" (um por nível, o atual em dourado).
## O "atual" (o nível em que ela está, o demônio em campo...) ganha fundo.
func _linha(d: Dictionary, cor_padrao: Color) -> Control:
	var cor: Color = d.get("cor", cor_padrao)
	var p := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(cor, 0.16) if d.get("atual", false) else Color(0, 0, 0, 0.22)
	estilo.border_color = cor
	estilo.border_width_left = 2
	estilo.content_margin_left = 6
	estilo.content_margin_right = 4
	estilo.content_margin_top = 2
	estilo.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", estilo)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rotulo := HBoxContainer.new()
	rotulo.add_theme_constant_override("separation", 6)
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.add_child(EstiloUI.label(d.rotulo, 10, cor.lightened(0.3), 2))
	if d.get("marca", "") != "":
		var marca := EstiloUI.label(d.marca, 9, EstiloUI.TEXTO_FRACO, 2)
		marca.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rotulo.add_child(marca)
	v.add_child(rotulo)
	if d.get("texto", "") != "":
		v.add_child(_texto(d.texto, 9, EstiloUI.TEXTO))
	var valores: Array = d.get("valores", [])
	if not valores.is_empty():
		var faixa := HFlowContainer.new()
		faixa.add_theme_constant_override("h_separation", 3)
		faixa.add_theme_constant_override("v_separation", 2)
		faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for valor: Dictionary in valores:
			faixa.add_child(EstiloUI.etiqueta(valor.texto, EstiloUI.OURO if valor.get("atual", false) else EstiloUI.BORDA_CLARA))
		v.add_child(faixa)
	p.add_child(v)
	return p


func _texto(t: String, tamanho: int, cor: Color) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", tamanho)
	r.add_theme_font_size_override("bold_font_size", tamanho)
	r.add_theme_constant_override("outline_size", 3)
	r.add_theme_color_override("font_outline_color", Color.BLACK)
	r.add_theme_color_override("default_color", cor)
	r.text = t
	return r

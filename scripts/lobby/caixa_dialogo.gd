class_name CaixaDialogo
extends PanelContainer
## Caixa de conversa do saguão: retrato, nome, texto e respostas. Lê o
## formato de Conversas. Enter/Espaço avança ou confirma a resposta,
## ↑/↓ escolhem, Esc encerra. Quem abre repassa as teclas para teclar().

signal evento(nome: String)
signal terminou

var _conversa: Dictionary
var _nome := ""
var _indice := 0
var _opcao := 0

var _retrato: TextureRect
var _rotulo_nome: Label
var _texto: Label
var _opcoes: VBoxContainer
var _dica: Label


func _ready() -> void:
	add_theme_stylebox_override("panel", EstiloUI.painel(EstiloUI.FUNDO_CLARO, EstiloUI.OURO.darkened(0.25), 2))
	custom_minimum_size = Vector2(620, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	add_child(h)
	_retrato = TextureRect.new()
	_retrato.custom_minimum_size = Vector2(64, 64)
	_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_retrato.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(_retrato)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_rotulo_nome = EstiloUI.label("", 14, EstiloUI.OURO, 4)
	v.add_child(_rotulo_nome)
	_texto = EstiloUI.label("", 13, EstiloUI.TEXTO)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_texto)
	_opcoes = VBoxContainer.new()
	_opcoes.add_theme_constant_override("separation", 1)
	v.add_child(_opcoes)
	_dica = EstiloUI.label("", 10, EstiloUI.TEXTO_FRACO, 2)
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_dica)
	visible = false


func aberta() -> bool:
	return visible


func abrir(conversa: Dictionary, nome: String, retrato: Texture2D) -> void:
	_conversa = conversa
	_nome = nome
	_retrato.texture = retrato
	visible = true
	_mostrar(0)


func _falas() -> Array:
	return _conversa.get("falas", [])


func _mostrar(i: int) -> void:
	if i < 0 or i >= _falas().size():
		fechar()
		return
	_indice = i
	_opcao = 0
	var fala: Dictionary = _falas()[i]
	_rotulo_nome.text = fala.get("nome", _nome)
	_texto.text = fala.get("texto", "")
	if fala.has("evento"):
		evento.emit(fala.evento)
	_atualizar_opcoes()


func _atualizar_opcoes() -> void:
	for c in _opcoes.get_children():
		c.queue_free()
	var opcoes: Array = _falas()[_indice].get("opcoes", [])
	for j in opcoes.size():
		var foco := j == _opcao
		_opcoes.add_child(EstiloUI.label(("▸ " if foco else "   ") + str(opcoes[j].get("texto", "")), 12,
			EstiloUI.OURO if foco else EstiloUI.TEXTO_FRACO, 3))
	_dica.text = "↑/↓ escolher · Enter confirmar" if opcoes else "Enter continuar · Esc sair"


func teclar(keycode: int) -> void:
	var opcoes: Array = _falas()[_indice].get("opcoes", [])
	match keycode:
		KEY_UP, KEY_W:
			if opcoes:
				_opcao = posmod(_opcao - 1, opcoes.size())
				_atualizar_opcoes()
		KEY_DOWN, KEY_S:
			if opcoes:
				_opcao = posmod(_opcao + 1, opcoes.size())
				_atualizar_opcoes()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			var proxima := _indice + 1
			if opcoes:
				var o: Dictionary = opcoes[_opcao]
				if o.has("evento"):
					evento.emit(o.evento)
				proxima = o.get("ir_para", proxima)
			_mostrar(proxima)
		KEY_ESCAPE:
			fechar()


func fechar() -> void:
	if not visible:
		return
	visible = false
	terminou.emit()

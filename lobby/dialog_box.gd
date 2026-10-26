class_name DialogBox
extends PanelContainer
## Caixa de conversa do saguão: retrato, nome, texto e respostas. Lê o
## formato de Conversations. Enter/Espaço avança ou confirma a resposta,
## ↑/↓ escolhem, Esc encerra. Quem abre repassa as teclas para handle_key().

signal event(event_text: String)
signal finished

var _conversation: Dictionary
var _name := ""
var _index := 0
var _option := 0

var _portrait: TextureRect
var _name_label: Label
var _text: Label
var _options: VBoxContainer
var _hint: Label


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.LIGHT_BACKGROUND, UIStyle.GOLD.darkened(0.25), 2))
	custom_minimum_size = Vector2(620, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	add_child(h)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(64, 64)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(_portrait)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_name_label = UIStyle.label("", 14, UIStyle.GOLD, 4)
	v.add_child(_name_label)
	_text = UIStyle.label("", 13, UIStyle.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_text)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 1)
	v.add_child(_options)
	_hint = UIStyle.label("", 10, UIStyle.DIM_TEXT, 2)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_hint)
	visible = false


func is_open() -> bool:
	return visible


func open(conversation: Dictionary, speaker_name: String, portrait: Texture2D) -> void:
	_conversation = conversation
	_name = speaker_name
	_portrait.texture = portrait
	visible = true
	_display(0)


func _lines() -> Array:
	return _conversation.get("lines", [])


func _display(i: int) -> void:
	if i < 0 or i >= _lines().size():
		close()
		return
	_index = i
	_option = 0
	var line: Dictionary = _lines()[i]
	_name_label.text = line.get("name", _name)
	_text.text = line.get("text", "")
	if line.has("event"):
		event.emit(line.event)
	_refresh_options()


func _refresh_options() -> void:
	for c in _options.get_children():
		c.queue_free()
	var options: Array = _lines()[_index].get("options", [])
	for j in options.size():
		var focus := j == _option
		_options.add_child(UIStyle.label(("▸ " if focus else "   ") + str(options[j].get("text", "")), 12,
			UIStyle.GOLD if focus else UIStyle.DIM_TEXT, 3))
	_hint.text = "↑/↓ escolher · Enter confirmar" if options else "Enter continuar · Esc sair"


func handle_key(keycode: int) -> void:
	var options: Array = _lines()[_index].get("options", [])
	match keycode:
		KEY_UP, KEY_W:
			if options:
				_option = posmod(_option - 1, options.size())
				_refresh_options()
		KEY_DOWN, KEY_S:
			if options:
				_option = posmod(_option + 1, options.size())
				_refresh_options()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			var next := _index + 1
			if options:
				var o: Dictionary = options[_option]
				if o.has("event"):
					event.emit(o.event)
				next = o.get("go_to", next)
			_display(next)
		KEY_ESCAPE:
			close()


func close() -> void:
	if not visible:
		return
	visible = false
	finished.emit()

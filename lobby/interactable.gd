class_name Interactable
extends Node2D
## Algo do saguão que o jogador pode abordar: um personagem ou a porta.
## A origem fica nos pés (ou na base). O Lobby liga `focused` no mais
## próximo dentro do `radius`, e este nó desenha a dica: elipse no chão, nome
## e a tecla com a ação. O que acontece ao interagir fica com quem escuta
## `interacted`: o Lobby liga a porta à entrada na dungeon e cada personagem
## à conversa dele (Conversations.from(id)).

## O jogador interagiu e o `requirement` deixou.
signal interacted

var id := ""
var title := ""
var action := "Falar"  ## texto ao lado da tecla
var radius := 78.0  ## distância (px de tela) para poder interagir
var height := 100.0  ## a dica fica acima disto
var base_width := 54.0  ## largura da elipse no chão
var color := UIStyle.GOLD
## Opcional: () -> String. O motivo de ainda não dar para interagir ("" = liberado).
var requirement := Callable()
## Retrato para a caixa de diálogo.
var portrait: Texture2D

var focused := false:
	set(v):
		if v != focused:
			focused = v
			_time = 0.0
			queue_redraw()
			_ground.queue_redraw()

var _time := 0.0
var _ground := Node2D.new()  ## elipse, desenhada embaixo de todos


func _init() -> void:
	z_as_relative = false
	z_index = 20  # a dica fica por cima dos móveis e personagens
	_ground.z_as_relative = false
	_ground.z_index = -5
	_ground.draw.connect(_draw_ground)
	add_child(_ground)


func block_reason() -> String:
	return requirement.call() if requirement.is_valid() else ""


## Interage, se o requisito deixar. Devolve o motivo de não poder ("" = foi).
func interact() -> String:
	var reason := block_reason()
	if reason == "":
		interacted.emit()
	return reason


func _process(delta: float) -> void:
	if focused:
		_time += delta
		queue_redraw()
		_ground.queue_redraw()


func _draw_ground() -> void:
	if not focused:
		return
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24
		pts.append(Vector2(cos(a) * base_width / 2, -2 + sin(a) * 7))
	_ground.draw_colored_polygon(pts, Color(color, 0.14 + 0.1 * pulse))
	pts.append(pts[0])
	_ground.draw_polyline(pts, Color(color, 0.5 + 0.35 * pulse), 2.0)


func _draw() -> void:
	if not focused:
		return
	var f := UIStyle.font()
	var y := -height - 10.0 + sin(_time * 4.0) * 2.0
	if title != "":
		UIStyle.text(self, Vector2(-100, y - 18), title, 13, color, 200, HORIZONTAL_ALIGNMENT_CENTER)
	var key := "Enter"
	var key_width := maxf(13.0, 7.0 * key.length() + 6.0)
	var width := key_width + 5 + f.get_string_size(action, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var x := -width / 2
	UIStyle.key(self, Vector2(x, y - 10), key)
	UIStyle.text(self, Vector2(x + key_width + 5, y), action, 11, UIStyle.TEXT)

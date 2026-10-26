class_name FighterBar
extends Node2D
## Barra sobre um lutador na arena (inimigos e invocações): nome, elemento,
## HP com rastro, escudo e os efeitos ativos. Componente do FighterVisual,
## que a põe acima da cabeça; a origem fica no canto esquerdo da barra de HP,
## no meio da largura. Escuta o Health do lutador para o rastro acompanhar
## curas na hora.

const WIDTH := 64.0

var combatant: Combatant
var marked := false  ## nome dourado no alvo escolhido

var _shown_hp := 0.0
var _trail_hp := 0.0


func _init(c: Combatant) -> void:
	combatant = c
	_shown_hp = c.hp
	_trail_hp = c.hp
	c.health.changed.connect(_on_health_changed)


## Curar puxa o rastro junto; dano o deixa para trás, descendo devagar.
func _on_health_changed(current: int, _maximum: int) -> void:
	_trail_hp = maxf(_trail_hp, current)


func _process(delta: float) -> void:
	# a barra desliza até o HP real; o rastro claro vai atrás, mais devagar
	var hp := float(combatant.hp)
	_shown_hp = move_toward(_shown_hp, hp, maxf(1.0, absf(_shown_hp - hp)) * delta * 12.0)
	_trail_hp = move_toward(_trail_hp, hp, combatant.max_hp * delta * 0.6)
	queue_redraw()


func _draw() -> void:
	if not combatant.is_alive():
		return
	var frac := clampf(_shown_hp / combatant.max_hp, 0, 1)
	var trail_frac := clampf(_trail_hp / combatant.max_hp, 0, 1)
	draw_rect(Rect2(-WIDTH / 2 - 1, -1, WIDTH + 2, 8), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(-WIDTH / 2, 0, WIDTH, 6), Color(0.12, 0.08, 0.1))
	draw_rect(Rect2(-WIDTH / 2, 0, roundf(WIDTH * trail_frac), 6), Color(1, 0.9, 0.8, 0.85))
	draw_rect(Rect2(-WIDTH / 2, 0, roundf(WIDTH * frac), 6), Color(0.86, 0.22, 0.25))
	draw_rect(Rect2(-WIDTH / 2, 0, roundf(WIDTH * frac), 2), Color(1, 0.5, 0.5))
	if combatant.shield() > 0:
		UIStyle.shield_outline(self, Rect2(-WIDTH / 2 - 1, -1, WIDTH + 2, 8), float(combatant.shield()) / combatant.max_hp)
	var name_color := UIStyle.GOLD if marked else UIStyle.TEXT
	UIStyle.text(self, Vector2(-WIDTH, -5), combatant.name, 12, name_color, WIDTH * 2, HORIZONTAL_ALIGNMENT_CENTER)
	# elemento à esquerda da barra (os efeitos ficam à direita)
	var badge_width := UIStyle.type_badge_width(combatant.type)
	UIStyle.type_badge(self, Vector2(-WIDTH / 2 - 5 - badge_width, -3), combatant.type)
	# efeitos ativos ao lado da barra
	var x := WIDTH / 2 + 4
	for e: Dictionary in combatant.effects():
		var r := Rect2(x, -3, 11, 11)
		draw_rect(r.grow(1), Color.BLACK)
		draw_rect(r, UIStyle.effect_color(e))
		draw_string(UIStyle.font(), r.position + Vector2(0, 9), e.get("short", ""), HORIZONTAL_ALIGNMENT_CENTER, 11, 9, Color.BLACK)
		x += 14

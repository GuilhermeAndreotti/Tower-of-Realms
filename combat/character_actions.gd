class_name CharacterActions
extends RefCounted
## Como um personagem age na arena: animações e efeitos de cada ação do kit.
## As regras (dano, energia, estados) ficam na classe Combatant dele; a
## batalha cuida da vez, dos pontos de skill do time e do alvo escolhido.
## Cada personagem novo estende esta classe (ver ShumiActions).

var b: Battle
var p: Combatant
var v: FighterVisual


func _init(p_battle: Battle, p_character: Combatant, p_visual: FighterVisual) -> void:
	b = p_battle
	p = p_character
	v = p_visual


## Começo do turno, antes do jogador escolher. Devolve false se o
## personagem não vai agir (perdeu o turno, caiu...).
func start_turn() -> bool:
	return true


## Faz a ação `action` (uma das de p.skills()). Custos de pontos de skill
## já foram cobrados pela batalha; o resto do efeito é daqui.
func execute(_action: String) -> void:
	pass


func end_turn() -> void:
	pass


## Ataque junto com um aliado em `target`, com o `strike` que a regra devolveu
## (Combatant.follow_up). Quem ataca junto no kit sobrescreve para dar a
## animação própria.
func follow_up(target: Combatant, strike: Dictionary) -> void:
	await b.apply_damage(p, target, strike.mult, strike.get("type", ""), true)


# --------------------------------------------------------- apoio comum
## Vai até perto do alvo, chama `strike` no meio do caminho e volta.
## `duration` é o tempo de cada trecho (ida e volta).
func charge_at(target: Combatant, strike: Callable, distance := 120.0, duration := 0.22) -> void:
	var va := b.visual(target)
	var origin := v.position
	await v.move_to(Vector2(va.position.x - distance, origin.y), duration)
	await strike.call()
	await v.move_to(origin, duration)


## Onde o seletor em anel da ação `action` fica preso, a partir dos pés.
func selector_anchor(_action: String) -> Vector2:
	return Vector2(0, -v.height * 0.55)


func center(c: Combatant) -> Vector2:
	var vc := b.visual(c)
	return vc.position + Vector2(0, -vc.height * 0.5)

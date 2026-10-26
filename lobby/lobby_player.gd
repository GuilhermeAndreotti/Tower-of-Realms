class_name LobbyPlayer
extends CharacterBody2D
## O personagem que o jogador conduz fora de combate (a Caoimhe). Anda com ←↑→↓ ou
## WASD (as mesmas teclas de navegação do resto do jogo), usando as
## animações "walk" e "idle" do sprite sheet. A colisão é só a dos pés.
## Anda no passo da física; a interpolação de física (project.godot) suaviza
## o desenho entre os passos, e a câmera vai junto como filha, para o
## sprite não tremer contra o fundo em monitores acima de 60 Hz.
## O movimento é uma máquina de estados (Motion): parada, andando ou travada
## pelo saguão; a animação acompanha a troca de estado.

## IDLE: parada. WALKING: andando. LOCKED: o saguão travou (conversa,
## apresentação, saída) e as teclas de andar não valem.
enum Motion { IDLE, WALKING, LOCKED }

const SPEED := 170.0  ## px de tela por segundo
const DEPTH_FACTOR := 0.75  ## andar para o fundo é um pouco mais lento (perspectiva)
const FEET := Vector2(24, 9)

var id := ""
var visual: FighterVisual
var locked: bool:
	get: return _motion.state == Motion.LOCKED
	set(v): _motion.go(Motion.LOCKED if v else Motion.IDLE)

var _motion := StateMachine.new(Motion.IDLE, {
	Motion.IDLE: [Motion.WALKING, Motion.LOCKED],
	Motion.WALKING: [Motion.IDLE, Motion.LOCKED],
	Motion.LOCKED: [Motion.IDLE],
}, Motion.keys())


## `data` no formato do Roster: {"name", "sprite": {"png", "json", "foot", "height", "face"?}}.
func setup(p_id: String, data: Dictionary) -> void:
	id = p_id
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := RectangleShape2D.new()
	shape.size = FEET
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -FEET.y / 2)
	add_child(col)
	var sp: Dictionary = data.sprite
	visual = FighterVisual.new()
	visual.setup_animated(null, sp.png, sp.json, sp.foot, sp.height, sp.get("face", Rect2()))
	add_child(visual)
	_motion.changed.connect(_on_motion_changed)


func height() -> float:
	return visual.height


func direction() -> Vector2:
	if locked:
		return Vector2.ZERO
	var d := Vector2(
		_key(KEY_RIGHT, KEY_D) - _key(KEY_LEFT, KEY_A),
		_key(KEY_DOWN, KEY_S) - _key(KEY_UP, KEY_W))
	return d.normalized()


func _key(a: Key, b: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b) else 0.0


func _physics_process(_delta: float) -> void:
	var d := direction()
	velocity = d * SPEED * Vector2(1.0, DEPTH_FACTOR)
	move_and_slide()
	if not locked:
		_motion.go(Motion.IDLE if d.is_zero_approx() else Motion.WALKING)
	if d.x != 0:
		visual.set_facing_left(d.x < 0)


func _on_motion_changed(_from: int, to: int) -> void:
	visual.set_idle_anim("walk" if to == Motion.WALKING else "idle")

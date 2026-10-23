class_name JogadorLobby
extends CharacterBody2D
## O personagem que o jogador conduz fora de combate (a Caoimhe). Anda com ←↑→↓ ou
## WASD (as mesmas teclas de navegação do resto do jogo), usando as
## animações "walk" e "idle" do sprite sheet. A colisão é só a dos pés.
## Anda no passo da física; a interpolação de física (project.godot) suaviza
## o desenho entre os passos, e a câmera vai junto como filha, para o
## sprite não tremer contra o fundo em monitores acima de 60 Hz.

const VELOCIDADE := 170.0  ## px de tela por segundo
const FATOR_FUNDO := 0.75  ## andar para o fundo é um pouco mais lento (perspectiva)
const PES := Vector2(24, 9)

var id := ""
var visual: VisualLutador
var travado := false  ## conversa aberta ou entrando na dungeon

var _andando := false


## `dados` no formato do Elenco: {"nome", "sprite": {"png", "json", "pe", "altura", "rosto"?}}.
func iniciar(p_id: String, dados: Dictionary) -> void:
	id = p_id
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var forma := RectangleShape2D.new()
	forma.size = PES
	var col := CollisionShape2D.new()
	col.shape = forma
	col.position = Vector2(0, -PES.y / 2)
	add_child(col)
	var sp: Dictionary = dados.sprite
	visual = VisualLutador.new()
	visual.iniciar_animado(null, sp.png, sp.json, sp.pe, sp.altura, sp.get("rosto", Rect2()))
	add_child(visual)


func altura() -> float:
	return visual.altura


func direcao() -> Vector2:
	if travado:
		return Vector2.ZERO
	var d := Vector2(
		_tecla(KEY_RIGHT, KEY_D) - _tecla(KEY_LEFT, KEY_A),
		_tecla(KEY_DOWN, KEY_S) - _tecla(KEY_UP, KEY_W))
	return d.normalized()


func _tecla(a: Key, b: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b) else 0.0


func _physics_process(_delta: float) -> void:
	var d := direcao()
	velocity = d * VELOCIDADE * Vector2(1.0, FATOR_FUNDO)
	move_and_slide()
	var andando := not d.is_zero_approx()
	if andando != _andando:
		_andando = andando
		visual.definir_parado("walk" if andando else "idle")
	if d.x != 0:
		visual.virar(d.x < 0)

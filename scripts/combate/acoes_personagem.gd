class_name AcoesPersonagem
extends RefCounted
## Como um personagem age na arena: animações e efeitos de cada ação do kit.
## As regras (dano, energia, estados) ficam na classe Combatente dele; a
## batalha cuida da vez, dos pontos de skill do time e do alvo escolhido.
## Cada personagem novo estende esta classe (ver AcoesShumi).

var b: Batalha
var p: Combatente
var v: VisualLutador


func _init(p_batalha: Batalha, p_personagem: Combatente, p_visual: VisualLutador) -> void:
	b = p_batalha
	p = p_personagem
	v = p_visual


## Começo do turno, antes do jogador escolher. Devolve false se o
## personagem não vai agir (perdeu o turno, caiu...).
func inicio_turno() -> bool:
	return true


## Faz a ação `acao` (uma das de p.habilidades()). Custos de pontos de skill
## já foram cobrados pela batalha; o resto do efeito é daqui.
func executar(_acao: String) -> void:
	pass


func fim_turno() -> void:
	pass


## Ataque junto com um aliado em `alvo`, com o `golpe` que a regra devolveu
## (Combatente.atacar_junto). Quem ataca junto no kit sobrescreve para dar a
## animação própria.
func atacar_junto(alvo: Combatente, golpe: Dictionary) -> void:
	await b.aplicar_dano(p, alvo, golpe.mult, golpe.get("tipo", ""), true)


# --------------------------------------------------------- apoio comum
## Vai até perto do alvo, chama `golpe` no meio do caminho e volta.
## `duracao` é o tempo de cada trecho (ida e volta).
func investir(alvo: Combatente, golpe: Callable, distancia := 120.0, duracao := 0.22) -> void:
	var va := b.visual(alvo)
	var origem := v.position
	await v.mover_para(Vector2(va.position.x - distancia, origem.y), duracao)
	await golpe.call()
	await v.mover_para(origem, duracao)


## Onde o seletor em anel da ação `acao` fica preso, a partir dos pés.
func ancora_seletor(_acao: String) -> Vector2:
	return Vector2(0, -v.altura * 0.55)


func centro(c: Combatente) -> Vector2:
	var vc := b.visual(c)
	return vc.position + Vector2(0, -vc.altura * 0.5)

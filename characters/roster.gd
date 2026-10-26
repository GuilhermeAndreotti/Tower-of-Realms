class_name Elenco
extends RefCounted
## Cadastro dos personagens jogáveis e a equipe escolhida no seletor.
## Para adicionar alguém: crie a classe de regras (extends Combatente, com os
## atributos de nível 1 no _init), a de animações (extends AcoesPersonagem),
## ponha o id em IDS e os dados em dados(), com o "crescimento" por nível.
## Nem a batalha, nem a HUD, nem a Progressao precisam mudar.

const MAX_EQUIPE := 3
const IDS: Array[String] = ["shumi", "andri", "askara"]

## Por enquanto, todos começam liberados, mesmo quem tem "inicial": false
## (que continua no cadastro para a história voltar a valer). Os testes da
## história desligam isto.
static var todos_liberados := true


## {"nome", "origem" (título), "universo" (de onde o personagem vem),
##  "classe" (Combatente), "acoes" (AcoesPersonagem),
##  "sprite": {"png", "json", "pe", "altura", "rosto"},
##  "crescimento": quanto ganha por nível {"hp", "atq", "def", "vel"},
##  "inicial"? (false = começa bloqueado; entra com Progressao.desbloquear())}
static func dados(id: String) -> Dictionary:
	match id:
		"shumi":
			return {
				"nome": "Shumi",
				"origem": "Espadachim do Kaioken",
				"universo": "Dragon Ball New Age",
				"classe": Shumi,
				"acoes": AcoesShumi,
				# ofensiva: o ATQ é o que mais cresce; HP alto para aguentar o
				# dreno do Kaioken; a VEL quase não sobe (o Kaioken já acelera)
				"crescimento": {"hp": 60, "atq": 8.0, "def": 2.0, "vel": 0.5},
				"sprite": {
					"png": "res://characters/shumi/shumi_spritesheet.png",
					"json": "res://characters/shumi/shumi_spritesheet.json",
					"pe": Vector2(24, 38),
					"altura": 36.0,
					"rosto": Rect2(15, 5, 16, 16),
				},
			}
		"andri":
			return {
				"nome": "Andri Findavil",
				"origem": "Inventor e artífice",
				"universo": "Tales of Azeroth",
				"classe": Andri,
				"acoes": AcoesAndri,
				"inicial": false,  # chega na primeira vitória do andar 2 (Andares)
				# suporte: ATQ cresce menos; ganha VEL e DEF para agir cedo e
				# sobreviver para entregar os artefatos
				"crescimento": {"hp": 50, "atq": 5.5, "def": 3.0, "vel": 1.0},
				"sprite": {
					"png": "res://characters/andri/andri_spritesheet.png",
					"json": "res://characters/andri/andri_spritesheet.json",
					"pe": Vector2(16, 37),
					"altura": 32.0,
					"rosto": Rect2(10, 4, 16, 16),
				},
			}
		"askara":
			return {
				"nome": "Àskara",
				"origem": "Invocadora do Abismo",
				"universo": "Nariagari",
				"classe": Askara,
				"acoes": AcoesAskara,
				# invocadora: frágil e com pouco ATQ próprio; as invocações copiam
				# os atributos dela, então crescem junto
				"crescimento": {"hp": 45, "atq": 6.0, "def": 2.0, "vel": 1.0},
				"sprite": {
					"png": "res://characters/askara/askara_spritesheet.png",
					"json": "res://characters/askara/askara_spritesheet.json",
					"pe": Vector2(16, 38),
					"altura": 34.0,
					"rosto": Rect2(8, 5, 16, 16),
				},
			}
	push_error("personagem desconhecido: " + id)
	return {}


## Se `id` começa liberado (sem precisar de evento de história).
static func inicial(id: String) -> bool:
	return todos_liberados or dados(id).get("inicial", true)


## Lutador de `id` no nível salvo (ou em `nivel`, se > 0), com os
## atributos dele nesse nível.
static func criar(id: String, nivel := 0) -> Combatente:
	var c: Combatente = dados(id).classe.new()
	var n := nivel if nivel > 0 else Progressao.nivel(id)
	c.aplicar_nivel(n, Progressao.atributos(c.atributos_nv1(), dados(id).get("crescimento", {}), n))
	return c


## Atributos de nível 1 de `id` (os do _init da classe dele).
static func atributos_nv1(id: String) -> Dictionary:
	var c: Combatente = dados(id).classe.new()
	return c.atributos_nv1()


## Os personagens liberados, na ordem de IDS.
static func disponiveis() -> Array[String]:
	return IDS.filter(func(id: String) -> bool: return Progressao.desbloqueado(id))


static func retrato(id: String) -> Texture2D:
	var s: Dictionary = dados(id).sprite
	var r := AtlasTexture.new()
	r.atlas = load(s.png)
	r.region = s.rosto
	return r


# A equipe passa do seletor para a batalha pelo progresso salvo, que
# sobrevive à troca de cena, ao "jogar de novo" e a fechar o jogo.
static func equipe() -> Array[String]:
	var ids := Progressao.equipe_salva().slice(0, MAX_EQUIPE)
	if ids.is_empty():
		ids.append(disponiveis()[0] if not disponiveis().is_empty() else IDS[0])
	return ids


static func definir_equipe(ids: Array[String]) -> void:
	var validos: Array[String] = []
	for id in ids:
		if id in IDS and Progressao.desbloqueado(id) and id not in validos and validos.size() < MAX_EQUIPE:
			validos.append(id)
	Progressao.salvar_equipe(validos)

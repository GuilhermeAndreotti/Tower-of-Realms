class_name Roster
extends RefCounted
## Cadastro dos personagens jogáveis e a equipe escolhida no seletor.
## Para adicionar alguém: crie a classe de regras (extends Combatant, com os
## atributos de nível 1 no _init), a de animações (extends CharacterActions),
## ponha o id em IDS e os dados em data(), com o "growth" por nível.
## Nem a batalha, nem a HUD, nem a Progression precisam mudar.

const MAX_TEAM := 3
const IDS: Array[String] = ["shumi", "andri", "askara"]

## Por enquanto, todos começam liberados, mesmo quem tem "starts_unlocked": false
## (que continua no cadastro para a história voltar a valer). Os testes da
## história desligam isto.
static var all_unlocked := true


## {"name", "origin" (título), "universe" (de onde o personagem vem),
##  "rules" (Combatant), "actions" (CharacterActions),
##  "sprite": {"png", "json", "foot", "height", "face"},
##  "growth": quanto ganha por nível {"hp", "atk", "def", "spd"},
##  "starts_unlocked"? (false = começa bloqueado; entra com Progression.unlock())}
static func data(id: String) -> Dictionary:
	match id:
		"shumi":
			return {
				"name": "Shumi",
				"origin": "Espadachim do Kaioken",
				"universe": "Dragon Ball New Age",
				"rules": Shumi,
				"actions": ShumiActions,
				# ofensiva: o ATQ é o que mais cresce; HP alto para aguentar o
				# dreno do Kaioken; a VEL quase não sobe (o Kaioken já acelera)
				"growth": {"hp": 60, "atk": 8.0, "def": 2.0, "spd": 0.5},
				"sprite": {
					"png": "res://characters/shumi/shumi_spritesheet.png",
					"json": "res://characters/shumi/shumi_spritesheet.json",
					"foot": Vector2(24, 38),
					"height": 36.0,
					"face": Rect2(15, 5, 16, 16),
				},
			}
		"andri":
			return {
				"name": "Andri Findavil",
				"origin": "Inventor e artífice",
				"universe": "Tales of Azeroth",
				"rules": Andri,
				"actions": AndriActions,
				"starts_unlocked": false,  # chega na primeira vitória do andar 2 (Floors)
				# suporte: ATQ cresce menos; ganha VEL e DEF para agir cedo e
				# sobreviver para entregar os artefatos
				"growth": {"hp": 50, "atk": 5.5, "def": 3.0, "spd": 1.0},
				"sprite": {
					"png": "res://characters/andri/andri_spritesheet.png",
					"json": "res://characters/andri/andri_spritesheet.json",
					"foot": Vector2(16, 37),
					"height": 32.0,
					"face": Rect2(10, 4, 16, 16),
				},
			}
		"askara":
			return {
				"name": "Àskara",
				"origin": "Invocadora do Abismo",
				"universe": "Nariagari",
				"rules": Askara,
				"actions": AskaraActions,
				# invocadora: frágil e com pouco ATQ próprio; as invocações copiam
				# os atributos dela, então crescem junto
				"growth": {"hp": 45, "atk": 6.0, "def": 2.0, "spd": 1.0},
				"sprite": {
					"png": "res://characters/askara/askara_spritesheet.png",
					"json": "res://characters/askara/askara_spritesheet.json",
					"foot": Vector2(16, 38),
					"height": 34.0,
					"face": Rect2(8, 5, 16, 16),
				},
			}
	push_error("personagem desconhecido: " + id)
	return {}


## Se `id` começa liberado (sem precisar de evento de história).
static func starts_unlocked(id: String) -> bool:
	return all_unlocked or data(id).get("starts_unlocked", true)


## Lutador de `id` no nível salvo (ou em `level`, se > 0), com os
## atributos dele nesse nível.
static func create(id: String, level := 0) -> Combatant:
	var c: Combatant = data(id).rules.new()
	var n := level if level > 0 else Progression.level(id)
	c.apply_level(n, Progression.stats(c.level_1_stats(), data(id).get("growth", {}), n))
	return c


## Atributos de nível 1 de `id` (os do _init da classe dele).
static func level_1_stats(id: String) -> Dictionary:
	var c: Combatant = data(id).rules.new()
	return c.level_1_stats()


## Os personagens liberados, na ordem de IDS.
static func available() -> Array[String]:
	return IDS.filter(func(id: String) -> bool: return Progression.is_unlocked(id))


static func portrait(id: String) -> Texture2D:
	var s: Dictionary = data(id).sprite
	var r := AtlasTexture.new()
	r.atlas = load(s.png)
	r.region = s.face
	return r


# A equipe passa do seletor para a batalha pelo progresso salvo, que
# sobrevive à troca de cena, ao "jogar de novo" e a fechar o jogo.
static func team() -> Array[String]:
	var ids := Progression.saved_team().slice(0, MAX_TEAM)
	if ids.is_empty():
		ids.append(available()[0] if not available().is_empty() else IDS[0])
	return ids


static func set_team(ids: Array[String]) -> void:
	var valid: Array[String] = []
	for id in ids:
		if id in IDS and Progression.is_unlocked(id) and id not in valid and valid.size() < MAX_TEAM:
			valid.append(id)
	Progression.save_team(valid)

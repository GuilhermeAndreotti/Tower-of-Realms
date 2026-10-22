class_name Elenco
extends RefCounted
## Cadastro dos personagens jogáveis e a equipe escolhida no seletor.
## Para adicionar alguém: crie a classe de regras (extends Combatente), a de
## animações (extends AcoesPersonagem), ponha o id em IDS e os dados em dados().
## Nem a batalha nem a HUD precisam mudar.

const MAX_EQUIPE := 3
const IDS: Array[String] = ["shumi", "andri"]


## {"nome", "origem" (título), "universo" (de onde o personagem vem),
##  "classe" (Combatente), "acoes" (AcoesPersonagem),
##  "sprite": {"png", "json", "pe", "altura", "rosto"}}
static func dados(id: String) -> Dictionary:
	match id:
		"shumi":
			return {
				"nome": "Shumi",
				"origem": "Espadachim do Kaioken",
				"universo": "Dragon Ball New Age",
				"classe": Shumi,
				"acoes": AcoesShumi,
				"sprite": {
					"png": "res://personagens/shumi/shumi_spritesheet.png",
					"json": "res://personagens/shumi/shumi_spritesheet.json",
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
				"sprite": {
					"png": "res://personagens/andri/andri_spritesheet.png",
					"json": "res://personagens/andri/andri_spritesheet.json",
					"pe": Vector2(16, 37),
					"altura": 32.0,
					"rosto": Rect2(10, 4, 16, 16),
				},
			}
	push_error("personagem desconhecido: " + id)
	return {}


static func criar(id: String) -> Combatente:
	return dados(id).classe.new()


static func retrato(id: String) -> Texture2D:
	var s: Dictionary = dados(id).sprite
	var r := AtlasTexture.new()
	r.atlas = load(s.png)
	r.region = s.rosto
	return r


# A equipe passa do seletor para a batalha guardada no Engine, que sobrevive
# à troca de cena (e ao "jogar de novo").
static func equipe() -> Array[String]:
	var ids: Array[String] = []
	for id: String in Engine.get_meta("torre_equipe", []):
		if id in IDS:
			ids.append(id)
	if ids.is_empty():
		ids.append(IDS[0])
	return ids


static func definir_equipe(ids: Array[String]) -> void:
	Engine.set_meta("torre_equipe", ids.filter(func(id: String) -> bool: return id in IDS).slice(0, MAX_EQUIPE))

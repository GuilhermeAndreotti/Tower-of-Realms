class_name Synergies
extends RefCounted
## Bônus de equipe: quando a equipe fecha `count` membros do mesmo universo
## (Roster.data().universe), todos da equipe ganham o bônus durante a luta,
## como um estado sem contagem. A batalha aplica no começo; a montagem da
## equipe mostra quanto falta para fechar.
##
## Para pôr outro: mais um item em LIST. Os "mods" são somados como os de
## qualquer estado (ver StatusEffect.mods), então nada mais muda.

const LIST := [
	{
		"id": "for_azeroth", "name": "Por Azeroth!", "short": "AZ", "universe": "Tales of Azeroth", "count": 3,
		"mods": {"damage": 0.10, "healing": 0.10}, "color": Color(0.95, 0.75, 0.3),
		"description": "+10% de dano e de cura para toda a equipe.",
	},
]


## Quantos de `ids` são do universo do bônus `s`.
static func members(s: Dictionary, ids: Array[String]) -> int:
	return ids.filter(func(id: String) -> bool: return Roster.data(id).universe == s.universe).size()


## Os bônus que a equipe `ids` fecha.
static func active(ids: Array[String]) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for s: Dictionary in LIST:
		if members(s, ids) >= s.count:
			list.append(s)
	return list


## O estado que o bônus `s` põe em cada um da equipe (dura a luta toda).
static func status(s: Dictionary) -> StatusEffect:
	var e := StatusEffect.new("synergy_" + s.id, s.name, s.short, "buff", -1)
	e.mods = s.mods
	e.color = s.color
	e.detail = s.description
	return e

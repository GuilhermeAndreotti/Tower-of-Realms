class_name Types
extends RefCounted
## Tipos de dano e efetividade, no estilo de Pokémon. Cada lutador tem um
## tipo só (Combatant.type) e, por padrão, ataca com ele; o multiplicador
## depende do tipo do ataque e do tipo do alvo.

const PHYSICAL := "physical"
const FIRE := "fire"
const WATER := "water"
const ICE := "ice"
const ELECTRICITY := "electricity"
const NATURE := "nature"
const POISON := "poison"
const ACID := "acid"
const LIGHT := "light"
const DARKNESS := "darkness"
const ARCANE := "arcane"

const ALL: Array[String] = [PHYSICAL, FIRE, WATER, ICE, ELECTRICITY, NATURE, POISON, ACID, LIGHT, DARKNESS, ARCANE]

## Os únicos multiplicadores de tipo do jogo: toda relação forte usa SUPER,
## toda fraca usa NOT_VERY e o resto é x1. Ajuste aqui para rebalancear tudo.
const SUPER := 2.0
const NOT_VERY := 0.5

## Tipo do ataque -> [super efetivo contra, pouco efetivo contra].
## O Arcano não está aqui: tem regra própria em effectiveness().
const TABLE := {
	PHYSICAL: [[ARCANE], [NATURE]],
	FIRE: [[ICE], [WATER]],
	WATER: [[FIRE], [ELECTRICITY]],
	ICE: [[NATURE], [FIRE]],
	ELECTRICITY: [[WATER], [NATURE]],
	NATURE: [[ELECTRICITY], [FIRE]],
	POISON: [[NATURE], [ACID]],
	ACID: [[PHYSICAL], [WATER]],
	# Luz e Trevas se batem: cada uma causa x2 na outra e recebe x2 dela.
	# Nenhuma das duas tem relação fraca.
	LIGHT: [[DARKNESS], []],
	DARKNESS: [[LIGHT], []],
}

const NAMES := {
	PHYSICAL: "Físico", FIRE: "Fogo", WATER: "Água", ICE: "Gelo", ELECTRICITY: "Eletricidade",
	NATURE: "Natureza", POISON: "Veneno", ACID: "Ácido", LIGHT: "Luz", DARKNESS: "Trevas", ARCANE: "Arcano",
}

## Versão curta, para espaços apertados (cartões da equipe).
const ABBRS := {
	PHYSICAL: "FÍS", FIRE: "FOG", WATER: "ÁGU", ICE: "GEL", ELECTRICITY: "ELE",
	NATURE: "NAT", POISON: "VEN", ACID: "ÁCI", LIGHT: "LUZ", DARKNESS: "TRE", ARCANE: "ARC",
}

const COLORS := {
	PHYSICAL: Color(0.85, 0.82, 0.75), FIRE: Color(1.0, 0.45, 0.2), WATER: Color(0.3, 0.6, 1.0),
	ICE: Color(0.6, 0.9, 1.0), ELECTRICITY: Color(1.0, 0.9, 0.25), NATURE: Color(0.4, 0.85, 0.35),
	POISON: Color(0.7, 0.4, 0.9), ACID: Color(0.75, 0.95, 0.2), LIGHT: Color(1.0, 0.95, 0.7),
	DARKNESS: Color(0.55, 0.4, 0.7), ARCANE: Color(0.95, 0.45, 0.95),
}


## Multiplicador de um ataque do tipo `attack` num alvo do tipo `target`.
## Alvo Arcano recebe x2 de qualquer tipo (inclusive Arcano). Essa regra
## substitui a tabela, não multiplica: Físico contra Arcano continua x2.
static func effectiveness(attack: String, target: String) -> float:
	if target == ARCANE:
		return SUPER
	if attack == ARCANE:
		return NOT_VERY if target == PHYSICAL else SUPER
	var rel: Array = TABLE.get(attack, [[], []])
	if target in rel[0]:
		return SUPER
	if target in rel[1]:
		return NOT_VERY
	return 1.0


static func name(type: String) -> String:
	return NAMES.get(type, type)


static func abbr(type: String) -> String:
	return ABBRS.get(type, type)


static func color(type: String) -> Color:
	return COLORS.get(type, UIStyle.TEXT)

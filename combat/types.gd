class_name Tipos
extends RefCounted
## Tipos de dano e efetividade, no estilo de Pokémon. Cada lutador tem um
## tipo só (Combatente.tipo) e, por padrão, ataca com ele; o multiplicador
## depende do tipo do ataque e do tipo do alvo.

const FISICO := "fisico"
const FOGO := "fogo"
const AGUA := "agua"
const GELO := "gelo"
const ELETRICIDADE := "eletricidade"
const NATUREZA := "natureza"
const VENENO := "veneno"
const ACIDO := "acido"
const LUZ := "luz"
const TREVAS := "trevas"
const ARCANO := "arcano"

const TODOS: Array[String] = [FISICO, FOGO, AGUA, GELO, ELETRICIDADE, NATUREZA, VENENO, ACIDO, LUZ, TREVAS, ARCANO]

## Os únicos multiplicadores de tipo do jogo: toda relação forte usa SUPER,
## toda fraca usa POUCO e o resto é x1. Ajuste aqui para rebalancear tudo.
const SUPER := 2.0
const POUCO := 0.5

## Tipo do ataque -> [super efetivo contra, pouco efetivo contra].
## O Arcano não está aqui: tem regra própria em efetividade().
const TABELA := {
	FISICO: [[ARCANO], [NATUREZA]],
	FOGO: [[GELO], [AGUA]],
	AGUA: [[FOGO], [ELETRICIDADE]],
	GELO: [[NATUREZA], [FOGO]],
	ELETRICIDADE: [[AGUA], [NATUREZA]],
	NATUREZA: [[ELETRICIDADE], [FOGO]],
	VENENO: [[NATUREZA], [ACIDO]],
	ACIDO: [[FISICO], [AGUA]],
	# Luz e Trevas se batem: cada uma causa x2 na outra e recebe x2 dela.
	# Nenhuma das duas tem relação fraca.
	LUZ: [[TREVAS], []],
	TREVAS: [[LUZ], []],
}

const NOMES := {
	FISICO: "Físico", FOGO: "Fogo", AGUA: "Água", GELO: "Gelo", ELETRICIDADE: "Eletricidade",
	NATUREZA: "Natureza", VENENO: "Veneno", ACIDO: "Ácido", LUZ: "Luz", TREVAS: "Trevas", ARCANO: "Arcano",
}

## Versão curta, para espaços apertados (cartões da equipe).
const SIGLAS := {
	FISICO: "FÍS", FOGO: "FOG", AGUA: "ÁGU", GELO: "GEL", ELETRICIDADE: "ELE",
	NATUREZA: "NAT", VENENO: "VEN", ACIDO: "ÁCI", LUZ: "LUZ", TREVAS: "TRE", ARCANO: "ARC",
}

const CORES := {
	FISICO: Color(0.85, 0.82, 0.75), FOGO: Color(1.0, 0.45, 0.2), AGUA: Color(0.3, 0.6, 1.0),
	GELO: Color(0.6, 0.9, 1.0), ELETRICIDADE: Color(1.0, 0.9, 0.25), NATUREZA: Color(0.4, 0.85, 0.35),
	VENENO: Color(0.7, 0.4, 0.9), ACIDO: Color(0.75, 0.95, 0.2), LUZ: Color(1.0, 0.95, 0.7),
	TREVAS: Color(0.55, 0.4, 0.7), ARCANO: Color(0.95, 0.45, 0.95),
}


## Multiplicador de um ataque do tipo `ataque` num alvo do tipo `alvo`.
## Alvo Arcano recebe x2 de qualquer tipo (inclusive Arcano). Essa regra
## substitui a tabela, não multiplica: Físico contra Arcano continua x2.
static func efetividade(ataque: String, alvo: String) -> float:
	if alvo == ARCANO:
		return SUPER
	if ataque == ARCANO:
		return POUCO if alvo == FISICO else SUPER
	var rel: Array = TABELA.get(ataque, [[], []])
	if alvo in rel[0]:
		return SUPER
	if alvo in rel[1]:
		return POUCO
	return 1.0


static func nome(tipo: String) -> String:
	return NOMES.get(tipo, tipo)


static func sigla(tipo: String) -> String:
	return SIGLAS.get(tipo, tipo)


static func cor(tipo: String) -> Color:
	return CORES.get(tipo, EstiloUI.TEXTO)

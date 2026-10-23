class_name Combatente
extends RefCounted
## Estado de um lutador durante a batalha: status, HP, energia e posição na
## fila de turnos. Não sabe nada de animação nem de interface.

## Distância que todo mundo percorre para agir; quem tem mais VEL chega antes.
const DISTANCIA_TURNO := 10000.0

var nome: String
var aliado: bool
## Nível do personagem (Progressao); inimigos ficam no 1. Não confundir com
## níveis de forma de um kit (como o Kaioken da Shumi).
var nivel_personagem := 1
## HP máximo e atributos no nível atual, sem modificadores temporários (que
## entram em bonus() e nos estados). Quem muda o nível é aplicar_nivel().
var hp_max: int
var hp: int
var atq_base: float
var def_base: float
var vel_base: float
## Atributos com que o lutador foi definido (nível 1): {"hp", "atq", "def", "vel"}.
var _nv1 := {}
var energia_max: float = 0.0
var energia: float = 0.0
var energia_ao_apanhar: float = 0.0  ## energia ganha ao receber um golpe
## Um tipo só (Tipos); é o que define o que o atinge melhor e, por padrão,
## o tipo dos ataques dele.
var tipo: String

## Quanto falta para este lutador agir ("action value" do HSR).
var av: float

## Multiplicadores temporários (somados): {"atq": 0.2, "vel": -0.1}.
## Personagens com mecânicas próprias (como o Kaioken) sobrescrevem bonus().
var _bonus_extra := {}

## Efeitos aplicados por habilidades (ver Estado). Um por id.
var estados: Array[Estado] = []

## Devolve os aliados de pé deste lutador (Array[Combatente]); a batalha
## preenche. Um Callable, e não a lista, para não criar ciclo de referência.
var aliados_vivos := Callable()

const DANO_CRITICO := 1.5  ## multiplicador do acerto crítico


func _init(p_nome: String, p_aliado: bool, p_hp: int, p_atq: float, p_def: float, p_vel: float, p_tipo := Tipos.FISICO) -> void:
	nome = p_nome
	tipo = p_tipo
	aliado = p_aliado
	hp_max = p_hp
	hp = p_hp
	atq_base = p_atq
	def_base = p_def
	vel_base = p_vel
	_nv1 = {"hp": p_hp, "atq": p_atq, "def": p_def, "vel": p_vel}
	av = DISTANCIA_TURNO / vel_base


func atributos_nv1() -> Dictionary:
	return _nv1.duplicate()


## Põe o lutador em `p_nivel` com os `atributos` desse nível (Progressao.atributos).
## Troca só a base: a vida extra dos estados continua por cima, o HP atual
## ganha o que o máximo ganhou (sem passar dele) e quem caiu continua caído.
func aplicar_nivel(p_nivel: int, atributos: Dictionary) -> void:
	var vel_antes := vel()
	var hp_max_antes := hp_max
	var vida_extra := 0
	for e in estados:
		vida_extra += e.vida_extra
	nivel_personagem = p_nivel
	hp_max = int(atributos.hp) + vida_extra
	if hp > 0:
		hp = clampi(hp + maxi(0, hp_max - hp_max_antes), 1, hp_max)
	atq_base = atributos.atq
	def_base = atributos.def
	vel_base = atributos.vel
	ajustar_av(vel_antes)


func vivo() -> bool:
	return hp > 0


func bonus(stat: String) -> float:
	var total: float = _bonus_extra.get(stat, 0.0)
	for e in estados:
		total += e.mods.get(stat, 0.0)
	return total


func atq() -> float:
	return atq_base * (1.0 + bonus("atq"))


func defesa() -> float:
	return def_base * (1.0 + bonus("def"))


func vel() -> float:
	return maxf(1.0, vel_base * (1.0 + bonus("vel")))


## Chame depois de qualquer mudança de VEL: o que falta para agir é
## reescalado, como no HSR (ficar mais rápido no meio do caminho adianta o turno).
func ajustar_av(vel_antes: float) -> void:
	av = av * vel_antes / vel()


func reiniciar_av() -> void:
	av = DISTANCIA_TURNO / vel()


func ganhar_energia(qtd: float) -> void:
	energia = minf(energia_max, energia + qtd)


## Dano de `atacante` com multiplicador `mult` sobre `alvo`, com um ataque
## do tipo `tipo_ataque` ("" = o tipo do atacante).
## `variacao` (0..1) e `critico` são sorteados fora para os testes poderem
## fixar o valor. Escudos não entram aqui (ver absorver()).
static func calcular_dano(atacante: Combatente, alvo: Combatente, mult: float, variacao := 0.5, tipo_ataque := "", critico := false) -> int:
	var tipo_golpe := tipo_ataque if tipo_ataque != "" else atacante.tipo
	var bruto := atacante.atq() * mult * alvo.efetividade_contra(tipo_golpe) * 100.0 / (100.0 + alvo.defesa())
	if critico:
		bruto *= DANO_CRITICO
	return maxi(1, roundi(bruto * lerpf(0.95, 1.05, variacao)))


## Tira HP direto, sem passar pelo escudo (custos próprios, como o Kaioken).
## Golpes passam antes por absorver().
func receber_dano(qtd: int) -> int:
	var real := mini(qtd, hp)
	hp -= real
	return real


func curar(qtd: int) -> int:
	var real := mini(qtd, hp_max - hp)
	hp += real
	return real


## Multiplicador de um golpe do tipo `tipo_golpe` neste lutador: a tabela de
## Tipos, a não ser que um estado tenha criado fraqueza a esse tipo.
func efetividade_contra(tipo_golpe: String) -> float:
	for e in estados:
		if e.fraqueza == tipo_golpe:
			return Tipos.SUPER
	return Tipos.efetividade(tipo_golpe, tipo)


func chance_critico() -> float:
	return clampf(bonus("crit"), 0.0, 1.0)


# --------------------------------------------------------------- estados
func estado(id: String) -> Estado:
	for e in estados:
		if e.id == id:
			return e
	return null


## Aplica `e` (substitui o de mesmo id, renovando).
func aplicar_estado(e: Estado) -> void:
	var vel_antes := vel()
	var hp_antes := hp
	var antigo := estado(e.id)
	remover_estado(e.id)
	estados.append(e)
	# vida extra: o HP atual sobe só o que o máximo ganhou de novo (renovar
	# não cura)
	hp_max += e.vida_extra
	hp = mini(hp_antes + maxi(0, e.vida_extra - (antigo.vida_extra if antigo else 0)), hp_max)
	ajustar_av(vel_antes)
	if antigo == null and e.atraso > 0:
		av += e.atraso * DISTANCIA_TURNO / vel()


## Tira o estado `id`, desfazendo o que ele mudou (VEL, HP máximo).
func remover_estado(id: String) -> void:
	var vel_antes := vel()
	for i in range(estados.size() - 1, -1, -1):
		if estados[i].id == id:
			hp_max -= estados[i].vida_extra
			hp = mini(hp, hp_max)
			estados.remove_at(i)
	ajustar_av(vel_antes)


## Fim de um turno do portador: desconta a duração. Devolve os que acabaram.
func passar_turno() -> Array[Estado]:
	var acabaram: Array[Estado] = []
	for e in estados:
		if e.turnos > 0:
			e.turnos -= 1
			if e.turnos == 0:
				acabaram.append(e)
	for e in acabaram:
		remover_estado(e.id)
	return acabaram


## Remove os debuffs (os estados genéricos; custos de kit, como a exaustão
## do Kaioken, não são estados e ficam). Devolve quantos saíram.
func limpar_debuffs() -> int:
	var antes := estados.size()
	for e in estados.duplicate():
		if e.tipo == "debuff":
			remover_estado(e.id)
	return antes - estados.size()


func tem_debuff() -> bool:
	for e in estados:
		if e.tipo == "debuff":
			return true
	return false


func escudo() -> int:
	var total := 0
	for e in estados:
		total += e.escudo
	return total


## Escudos absorvem o golpe primeiro. Devolve quanto foi absorvido.
func absorver(dano: int) -> int:
	var absorvido := 0
	for e in estados.duplicate():
		if e.escudo <= 0 or absorvido >= dano:
			continue
		var parte := mini(e.escudo, dano - absorvido)
		e.escudo -= parte
		absorvido += parte
		if e.escudo == 0:
			remover_estado(e.id)
	return absorvido


## Golpes adicionais que um golpe de multiplicador `mult` do portador
## dispara (ex.: dano elétrico extra). Os que se consomem acabam aqui.
## Golpes adicionais não chamam isto de novo: não há encadeamento.
func golpes_extras(mult: float) -> Array[Dictionary]:
	var extras: Array[Dictionary] = []
	for e in estados.duplicate():
		if e.golpe_extra.is_empty():
			continue
		var g: Dictionary = e.golpe_extra
		extras.append({"tipo": g.tipo, "mult": g.mult * mult if g.get("proporcional", false) else g.mult, "fonte": e.nome})
		if g.get("consome", false):
			remover_estado(e.id)
	return extras


## Estados que o portador aplica em quem acerta (novos a cada acerto).
## Os que se consomem acabam aqui.
func estados_ao_acertar() -> Array[Estado]:
	var lista: Array[Estado] = []
	for e in estados.duplicate():
		if e.ao_acertar.is_valid():
			var novo: Estado = e.ao_acertar.call()
			lista.append(novo)
			if e.ao_acertar_consome:
				remover_estado(e.id)
	return lista


# ------------------------------------------------- descrição para a interface
# A HUD só lê estes dados; quem tem kit ou estados próprios sobrescreve.

## Efeitos ativos: [{"id", "curto", "nome", "tipo" (buff/debuff/alerta),
## "turnos" (-1 = sem contagem), "detalhe"?, "cor"?}, ...].
## Quem sobrescreve deve incluir super() (os estados genéricos).
func efeitos() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for e in estados:
		lista.append(e.descricao())
	return lista


## Kit de ações do jogador, na ordem da barra: [{"acao", "nome", "tecla",
## "icone", "estado" (pronta/sem_recurso/bloqueada), "alvo" (unico/vizinhos/
## todos/proprio/aliado), "tipo"? (Tipos, só nas que causam dano),
## "custo_pontos"?, "custo_energia"?, "ganho_pontos"?, "opcoes"? (escolha
## feita antes de confirmar: [{"id", "nome", "descricao", "icone"?, "cor"?}],
## com "opcao_padrao"?), "passiva"? (fora da barra, sem tecla),
## "ao_iniciar_turno"? (o seletor de opções abre sozinho no começo da vez),
## "seletor"? ("radial": as opções abrem em anel no próprio lutador; opções
## podem ter "sigla" e "atual"),
## "livre"? (não gasta o turno), "selo"?, "destaque"?, "cor"?, "descricao"}, ...].
## A batalha cobra "custo_pontos" antes da ação e dá "ganho_pontos" depois.
func habilidades(_pontos: int) -> Array[Dictionary]:
	return []


## Inimigos que `acao` atingiria, quando a regra é do próprio kit (alvos que
## mudam com uma forma, por exemplo). Vazio = a batalha usa o "alvo" da ação.
func alvos_previstos(_acao: String, _inimigos: Array, _alvo: int) -> Array:
	return []


## Por que `acao` (com a `opcao` escolhida) não pode ser usada em `alvo`;
## "" = pode. A batalha impede a confirmação e a HUD mostra o motivo.
func motivo_invalido(_acao: String, _opcao: String, _alvo: Combatente) -> String:
	return ""


## Se `acao` pode ser usada agora (com `pontos` de skill do time).
func pode_usar(_acao: String, _pontos: int) -> bool:
	return false

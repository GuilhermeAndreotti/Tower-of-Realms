class_name Progressao
extends RefCounted
## Níveis e experiência dos personagens jogáveis: as regras (curva de XP,
## crescimento de atributos, XP das batalhas, nível de entrada de quem é
## desbloqueado) e o progresso salvo. Todas as fórmulas moram aqui; o
## crescimento de cada um fica no Elenco ("crescimento" em dados()).
## O save também guarda a equipe e a subida da Torre (andares vencidos,
## andar escolhido, eventos de história ainda não apresentados).
##
## O XP guardado é o acumulado dentro do nível atual (0 até xp_para_subir()).
##
## Dois tetos, que não se confundem:
##  - NIVEL_MAX, o máximo do jogo;
##  - o limite da Torre (Andares.limite_nivel()), que sobe com os andares
##    liberados e impede repetir um andar até trivializar os seguintes.
## No teto que valer, o XP fica em 0 e o que sobra se perde: ao subir o
## limite, ninguém ganha vários níveis de uma vez com XP guardado.
## Quem já está acima do limite (save antigo) não perde nível; só não ganha XP.

const NIVEL_MAX := 20

## Curva: subir do nível n para o n+1 custa XP_BASE + XP_POR_NIVEL * (n - 1)
## (100, 150, 200, 250... 1000 no 19 -> 20). Do 1 ao 9 são 2.200; as
## primeiras vitórias dos andares levam do 1 ao 2, 4, 6 e 8 (ver Andares).
const XP_BASE := 100
const XP_POR_NIVEL := 50

## XP de um inimigo sem valor próprio (Inimigo.xp < 0): proporcional ao HP
## dele. Sentinela (550) = 66, Guardião (1400) = 168: o andar 1 dá 300.
const XP_POR_HP_INIMIGO := 0.12

## Atributos que crescem com o nível (os de Combatente.atributos_nv1()).
const ATRIBUTOS: Array[String] = ["hp", "atq", "def", "vel"]
const NOMES_ATRIBUTOS := {"hp": "HP", "atq": "ATQ", "def": "DEF", "vel": "VEL"}

const VERSAO_SAVE := 1

## Trocável nos testes e nas ferramentas, para não mexer no save do jogador.
static var arquivo := "user://progresso.cfg"
static var _save: ConfigFile


# ------------------------------------------------------------------ regras
## XP para sair de `nivel` e ir ao próximo (0 no nível máximo).
static func xp_para_subir(nivel: int) -> int:
	if nivel >= NIVEL_MAX:
		return 0
	return XP_BASE + XP_POR_NIVEL * (maxi(1, nivel) - 1)


## Soma `ganho` ao progresso {"nivel", "xp"} e sobe quantos níveis couberem
## até `limite` (o da Torre; nunca acima de NIVEL_MAX). No teto, XP 0.
## Devolve o novo {"nivel", "xp"}.
static func somar_xp(nivel: int, xp: int, ganho: int, limite := NIVEL_MAX) -> Dictionary:
	var teto := clampi(limite, 1, NIVEL_MAX)
	nivel = clampi(nivel, 1, NIVEL_MAX)
	if nivel >= teto:
		return {"nivel": nivel, "xp": 0}
	xp += maxi(0, ganho)
	while nivel < teto and xp >= xp_para_subir(nivel):
		xp -= xp_para_subir(nivel)
		nivel += 1
	if nivel >= teto:
		xp = 0
	return {"nivel": nivel, "xp": xp}


## XP total de quem está em `nivel` com `xp` (desde o nível 1).
static func xp_acumulada(nivel: int, xp: int) -> int:
	var total := xp
	for n in range(1, clampi(nivel, 1, NIVEL_MAX)):
		total += xp_para_subir(n)
	return total


## Atributos no `nivel`: os de nível 1 mais o crescimento por nível. Sempre
## a partir do nível 1, então recalcular não acumula bônus.
static func atributos(nv1: Dictionary, crescimento: Dictionary, nivel: int) -> Dictionary:
	var niveis_ganhos := clampi(nivel, 1, NIVEL_MAX) - 1
	var r := {}
	for a in ATRIBUTOS:
		r[a] = float(nv1[a]) + float(crescimento.get(a, 0.0)) * niveis_ganhos
	r.hp = roundi(r.hp)
	return r


## Nível de quem entra na equipe: a média dos `niveis` arredondada (x,5
## para cima), entre 1 e `limite` (o da Torre, até NIVEL_MAX). Sem ninguém, 1.
static func nivel_de_entrada(niveis: Array[int], limite := NIVEL_MAX) -> int:
	if niveis.is_empty():
		return 1
	var soma := 0
	for n in niveis:
		soma += n
	return clampi(roundi(float(soma) / niveis.size()), 1, clampi(limite, 1, NIVEL_MAX))


static func xp_inimigo(ini: Inimigo) -> int:
	if ini.xp >= 0:
		return ini.xp
	return roundi(ini.atributos_nv1().hp * XP_POR_HP_INIMIGO)


## XP que cada participante ganha ao vencer: a soma da dos inimigos.
static func xp_da_batalha(inimigos: Array[Inimigo]) -> int:
	var total := 0
	for ini in inimigos:
		total += xp_inimigo(ini)
	return total


# ------------------------------------------------------- progresso salvo
static func _dados() -> ConfigFile:
	if _save == null:
		_save = ConfigFile.new()
		_save.load(arquivo)  # sem arquivo (primeira vez): tudo no padrão
	return _save


static func salvar() -> void:
	var cfg := _dados()
	cfg.set_value("jogo", "versao", VERSAO_SAVE)
	var erro := cfg.save(arquivo)
	if erro != OK:
		push_error("não deu para salvar o progresso em %s (erro %d)" % [arquivo, erro])


## Esquece o que está em memória: a próxima leitura vem do arquivo (como ao
## abrir o jogo de novo).
static func recarregar() -> void:
	_save = null


## Apaga o progresso (testes).
static func apagar() -> void:
	_save = null
	if FileAccess.file_exists(arquivo):
		DirAccess.remove_absolute(arquivo)


static func _secao(id: String) -> String:
	return "personagem_" + id


## Quem está liberado: os do elenco inicial e os já desbloqueados.
static func desbloqueado(id: String) -> bool:
	return _dados().has_section(_secao(id)) or Elenco.dados(id).get("inicial", true)


## {"nivel", "xp"} salvos de `id`. Quem ainda não tem registro (save antigo,
## personagem do elenco inicial) está no nível 1. Valores fora da regra são
## corrigidos.
static func progresso(id: String) -> Dictionary:
	var cfg := _dados()
	var nivel := clampi(int(cfg.get_value(_secao(id), "nivel", 1)), 1, NIVEL_MAX)
	var xp := clampi(int(cfg.get_value(_secao(id), "xp", 0)), 0, maxi(0, xp_para_subir(nivel) - 1))
	return {"nivel": nivel, "xp": xp}


static func nivel(id: String) -> int:
	return progresso(id).nivel


static func _guardar(id: String, p: Dictionary) -> void:
	_dados().set_value(_secao(id), "nivel", p.nivel)
	_dados().set_value(_secao(id), "xp", p.xp)


## A última equipe montada no seletor (só ids conhecidos e liberados).
static func equipe_salva() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _dados().get_value("jogador", "equipe", []):
		if id in Elenco.IDS and desbloqueado(id) and id not in ids:
			ids.append(id)
	return ids


static func salvar_equipe(ids: Array[String]) -> void:
	_dados().set_value("jogador", "equipe", ids)
	salvar()


## A equipe principal, que serve de referência para quem chega: a salva;
## sem uma (jogo novo), todos os liberados.
static func equipe_principal() -> Array[String]:
	var ids := equipe_salva()
	return ids if not ids.is_empty() else Elenco.disponiveis()


## Libera `id` no nível médio da equipe principal (sem contar ele mesmo),
## limitado ao limite atual da Torre, com 0 de XP. Os atributos saem do próprio personagem nesse nível (ver
## Elenco.criar). Quem já está liberado fica como está. Devolve o progresso.
static func desbloquear(id: String) -> Dictionary:
	if _dados().has_section(_secao(id)):
		return progresso(id)
	var niveis: Array[int] = []
	for outro in equipe_principal():
		if outro != id:
			niveis.append(nivel(outro))
	var p := {"nivel": nivel_de_entrada(niveis, Andares.limite_nivel()), "xp": 0}
	_guardar(id, p)
	salvar()
	return p


## Dá `qtd` de XP a `id`, até o limite da Torre, e salva. Devolve {"id",
## "xp" (a recompensa), "xp_aproveitada" (o que contou, menor no limite),
## "nivel_antes", "nivel", "xp_atual", "xp_proximo", "limite", "no_limite"
## (parou no limite da Torre), "ganhos" ({atributo: aumento}, vazio se não subiu)}.
static func conceder_xp(id: String, qtd: int) -> Dictionary:
	var r := _somar(id, qtd)
	salvar()
	return r


static func _somar(id: String, qtd: int) -> Dictionary:
	var antes := progresso(id)
	var limite := Andares.limite_nivel()
	var depois := somar_xp(antes.nivel, antes.xp, qtd, limite)
	_guardar(id, depois)
	var ganhos := {}
	if depois.nivel > antes.nivel:
		var nv1 := Elenco.atributos_nv1(id)
		var cresc: Dictionary = Elenco.dados(id).get("crescimento", {})
		var a := atributos(nv1, cresc, antes.nivel)
		var b := atributos(nv1, cresc, depois.nivel)
		for k in ATRIBUTOS:
			# como a interface mostra: diferença dos valores arredondados
			var dif := roundi(b[k]) - roundi(a[k])
			if dif != 0:
				ganhos[k] = dif
	var aproveitada := maxi(0, xp_acumulada(depois.nivel, depois.xp) - xp_acumulada(antes.nivel, antes.xp))
	return {"id": id, "xp": qtd, "xp_aproveitada": aproveitada, "nivel_antes": antes.nivel, "nivel": depois.nivel,
		"xp_atual": depois.xp, "xp_proximo": xp_para_subir(depois.nivel), "limite": limite,
		"no_limite": depois.nivel >= limite and depois.nivel < NIVEL_MAX, "ganhos": ganhos}


## Recompensa de uma vitória: a XP dos `inimigos`, inteira, para quem lutou
## (`participantes`, inclusive quem caiu) e também para os liberados que
## ficaram de fora, para trocar de equipe não custar níveis. O valor não
## depende do tamanho do elenco. Quem não foi liberado não ganha. Salva uma
## vez só no fim. Devolve um resultado de conceder_xp() por personagem, com
## "participou"; quem lutou vem primeiro, na ordem da equipe.
static func recompensar_vitoria(participantes: Array[String], inimigos: Array[Inimigo]) -> Array[Dictionary]:
	var xp := xp_da_batalha(inimigos)
	var lista: Array[Dictionary] = []
	var ids: Array[String] = participantes.filter(func(id: String) -> bool: return desbloqueado(id))
	for id in Elenco.disponiveis():
		if id not in ids:
			ids.append(id)
	for id in ids:
		var r := _somar(id, xp)
		r.participou = id in participantes
		lista.append(r)
	salvar()
	return lista


# ------------------------------------------------------------- a Torre
## Andares vencidos ao menos uma vez (números, ver Andares).
static func andares_vencidos() -> Array[int]:
	var lista: Array[int] = []
	for n: Variant in _dados().get_value("torre", "vencidos", []):
		if (n is int or n is float) and int(n) not in lista:
			lista.append(int(n))
	return lista


static func marcar_andar_vencido(numero: int) -> void:
	var lista := andares_vencidos()
	if numero not in lista:
		lista.append(numero)
		lista.sort()
		_dados().set_value("torre", "vencidos", lista)
		salvar()


static func andar_escolhido() -> int:
	return int(_dados().get_value("torre", "andar", 1))


static func salvar_andar_escolhido(numero: int) -> void:
	_dados().set_value("torre", "andar", numero)
	salvar()


## Eventos de história já aplicados que o saguão ainda não apresentou
## (formato em Eventos), na ordem.
static func eventos_pendentes() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for e: Variant in _dados().get_value("torre", "eventos_pendentes", []):
		if e is Dictionary:
			lista.append(e)
	return lista


static func adicionar_eventos_pendentes(eventos: Array) -> void:
	if eventos.is_empty():
		return
	var lista := eventos_pendentes()
	for e: Dictionary in eventos:
		lista.append(e)
	_dados().set_value("torre", "eventos_pendentes", lista)
	salvar()


## Tira o primeiro pendente (depois de apresentado).
static func tirar_evento_pendente() -> void:
	var lista := eventos_pendentes()
	if not lista.is_empty():
		lista.pop_front()
		_dados().set_value("torre", "eventos_pendentes", lista)
		salvar()

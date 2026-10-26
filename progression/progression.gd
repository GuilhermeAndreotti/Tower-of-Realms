class_name Progression
extends RefCounted
## Níveis e experiência dos personagens jogáveis: as regras (curva de XP,
## crescimento de atributos, XP das batalhas, nível de entrada de quem é
## desbloqueado) e o progresso salvo. Todas as fórmulas moram aqui; o
## crescimento de cada um fica no Roster ("growth" em data()).
## O save também guarda a equipe e a subida da Torre (andares vencidos,
## andar escolhido, eventos de história ainda não apresentados).
##
## O XP guardado é o acumulado dentro do nível atual (0 até xp_to_next()).
##
## Dois tetos, que não se confundem:
##  - MAX_LEVEL, o máximo do jogo;
##  - o limite da Torre (Floors.level_limit()), que sobe com os andares
##    liberados e impede repetir um andar até trivializar os seguintes.
## No teto que valer, o XP fica em 0 e o que sobra se perde: ao subir o
## limite, ninguém ganha vários níveis de uma vez com XP guardado.
## Quem já está acima do limite (save antigo) não perde nível; só não ganha XP.

const MAX_LEVEL := 20

## Curva: subir do nível n para o n+1 custa XP_BASE + XP_PER_LEVEL * (n - 1)
## (100, 150, 200, 250... 1000 no 19 -> 20). Do 1 ao 9 são 2.200; as
## primeiras vitórias dos andares levam do 1 ao 2, 4, 6 e 8 (ver Floors).
const XP_BASE := 100
const XP_PER_LEVEL := 50

## XP de um inimigo sem valor próprio (Enemy.xp < 0): proporcional ao HP
## dele. Sentinela (550) = 66, Guardião (1400) = 168: o andar 1 dá 300.
const XP_PER_ENEMY_HP := 0.12

## Atributos que crescem com o nível (os de Combatant.level_1_stats()).
const STATS: Array[String] = ["hp", "atk", "def", "spd"]
const STAT_NAMES := {"hp": "HP", "atk": "ATQ", "def": "DEF", "spd": "VEL"}

const SAVE_VERSION := 1

## Espaços de save do menu inicial. O 1 é o `progress.cfg` de sempre, então
## o save de antes do menu aparece nele sem conversão.
const SLOTS := 3

## Trocável nos testes e nas ferramentas, para não mexer no save do jogador.
static var file := "user://progresso.cfg"
## Começo do nome dos arquivos dos slots (também trocável nos testes).
static var slots_prefix := "user://progresso"
static var _save: ConfigFile


# ------------------------------------------------------------------ regras
## XP para sair de `level` e ir ao próximo (0 no nível máximo).
static func xp_to_next(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	return XP_BASE + XP_PER_LEVEL * (maxi(1, level) - 1)


## Soma `gain` ao progresso {"level", "xp"} e sobe quantos níveis couberem
## até `limit` (o da Torre; nunca acima de MAX_LEVEL). No teto, XP 0.
## Devolve o novo {"level", "xp"}.
static func add_xp(level: int, xp: int, gain: int, limit := MAX_LEVEL) -> Dictionary:
	var cap := clampi(limit, 1, MAX_LEVEL)
	level = clampi(level, 1, MAX_LEVEL)
	if level >= cap:
		return {"level": level, "xp": 0}
	xp += maxi(0, gain)
	while level < cap and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
	if level >= cap:
		xp = 0
	return {"level": level, "xp": xp}


## XP total de quem está em `level` com `xp` (desde o nível 1).
static func total_xp(level: int, xp: int) -> int:
	var total := xp
	for n in range(1, clampi(level, 1, MAX_LEVEL)):
		total += xp_to_next(n)
	return total


## Atributos no `level`: os de nível 1 mais o crescimento por nível. Sempre
## a partir do nível 1, então recalcular não acumula bônus.
static func stats(base_stats: Dictionary, growth: Dictionary, level: int) -> Dictionary:
	var levels_gained := clampi(level, 1, MAX_LEVEL) - 1
	var r := {}
	for a in STATS:
		r[a] = float(base_stats[a]) + float(growth.get(a, 0.0)) * levels_gained
	r.hp = roundi(r.hp)
	return r


## Nível de quem entra na equipe: a média dos `levels` arredondada (x,5
## para cima), entre 1 e `limit` (o da Torre, até MAX_LEVEL). Sem ninguém, 1.
static func entry_level(levels: Array[int], limit := MAX_LEVEL) -> int:
	if levels.is_empty():
		return 1
	var sum := 0
	for n in levels:
		sum += n
	return clampi(roundi(float(sum) / levels.size()), 1, clampi(limit, 1, MAX_LEVEL))


static func enemy_xp(ini: Enemy) -> int:
	if ini.xp >= 0:
		return ini.xp
	return roundi(ini.level_1_stats().hp * XP_PER_ENEMY_HP)


## XP que cada participante ganha ao vencer: a soma da dos inimigos.
static func battle_xp(enemies: Array[Enemy]) -> int:
	var total := 0
	for ini in enemies:
		total += enemy_xp(ini)
	return total


# ------------------------------------------------------- progresso salvo
static func _data() -> ConfigFile:
	if _save == null:
		_save = ConfigFile.new()
		_save.load(file)  # sem arquivo (primeira vez): tudo no padrão
	return _save


static func save() -> void:
	var cfg := _data()
	cfg.set_value("jogo", "versao", SAVE_VERSION)
	cfg.set_value("jogo", "salvo_em", int(Time.get_unix_time_from_system()))
	var error := cfg.save(file)
	if error != OK:
		push_error("não deu para salvar o progresso em %s (erro %d)" % [file, error])


## Esquece o que está em memória: a próxima leitura vem do arquivo (como ao
## abrir o jogo de novo).
static func reload_save() -> void:
	_save = null


## Apaga o progresso (testes).
static func delete() -> void:
	_save = null
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)


# ------------------------------------------------------------------ slots
static func slot_file(n: int) -> String:
	return slots_prefix + (".cfg" if n == 1 else "_%d.cfg" % n)


static func slot_exists(n: int) -> bool:
	return FileAccess.file_exists(slot_file(n))


static func any_slot() -> bool:
	for n in range(1, SLOTS + 1):
		if slot_exists(n):
			return true
	return false


## Passa a ler e salvar no slot `n` (o progresso em memória é descartado).
static func use_slot(n: int) -> void:
	file = slot_file(n)
	_save = null


## Jogo novo no slot `n`: apaga o que houver lá e já cria o arquivo, para o
## slot aparecer ocupado mesmo antes da primeira vitória.
static func new_game(n: int) -> void:
	use_slot(n)
	delete()
	save()


static func delete_slot(n: int) -> void:
	var path := slot_file(n)
	if path == file:
		_save = null
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## O que o menu mostra de um slot, lido à parte (não mexe no save em uso):
## {"exists", "floors" (vencidos), "level" (o mais alto), "characters"
## (liberados), "salvo_em" (unix, 0 se não souber)}.
static func slot_summary(n: int) -> Dictionary:
	var r := {"exists": slot_exists(n), "floors": 0, "level": 1, "characters": 0, "salvo_em": 0}
	if not r.exists:
		return r
	var cfg := ConfigFile.new()
	cfg.load(slot_file(n))
	var cleared: Variant = cfg.get_value("torre", "vencidos", [])
	r.floors = cleared.size() if cleared is Array else 0
	for id in Roster.IDS:
		if cfg.has_section(_section(id)) or Roster.starts_unlocked(id):
			r.characters += 1
			r.level = maxi(r.level, clampi(int(cfg.get_value(_section(id), "nivel", 1)), 1, MAX_LEVEL))
	r.saved_at = int(cfg.get_value("jogo", "salvo_em", 0))
	return r


static func _section(id: String) -> String:
	return "personagem_" + id


## Quem está liberado: os do elenco inicial e os já desbloqueados.
static func is_unlocked(id: String) -> bool:
	return _data().has_section(_section(id)) or Roster.starts_unlocked(id)


## {"level", "xp"} salvos de `id`. Quem ainda não tem registro (save antigo,
## personagem do elenco inicial) está no nível 1. Valores fora da regra são
## corrigidos.
static func progress(id: String) -> Dictionary:
	var cfg := _data()
	var level := clampi(int(cfg.get_value(_section(id), "nivel", 1)), 1, MAX_LEVEL)
	var xp := clampi(int(cfg.get_value(_section(id), "xp", 0)), 0, maxi(0, xp_to_next(level) - 1))
	return {"level": level, "xp": xp}


static func level(id: String) -> int:
	return progress(id).level


static func _store(id: String, p: Dictionary) -> void:
	_data().set_value(_section(id), "nivel", p.level)
	_data().set_value(_section(id), "xp", p.xp)


## A última equipe montada no seletor (só ids conhecidos e liberados).
static func saved_team() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _data().get_value("jogador", "equipe", []):
		if id in Roster.IDS and is_unlocked(id) and id not in ids:
			ids.append(id)
	return ids


static func save_team(ids: Array[String]) -> void:
	_data().set_value("jogador", "equipe", ids)
	save()


## A equipe principal, que serve de referência para quem chega: a salva;
## sem uma (jogo novo), todos os liberados.
static func main_team() -> Array[String]:
	var ids := saved_team()
	return ids if not ids.is_empty() else Roster.available()


## Libera `id` no nível médio da equipe principal (sem contar ele mesmo),
## limitado ao limite atual da Torre, com 0 de XP. Os atributos saem do próprio personagem nesse nível (ver
## Roster.create). Quem já está liberado fica como está. Devolve o progresso.
static func unlock(id: String) -> Dictionary:
	if _data().has_section(_section(id)):
		return progress(id)
	var levels: Array[int] = []
	for other in main_team():
		if other != id:
			levels.append(level(other))
	var p := {"level": entry_level(levels, Floors.level_limit()), "xp": 0}
	_store(id, p)
	save()
	return p


## Dá `amount` de XP a `id`, até o limite da Torre, e salva. Devolve {"id",
## "xp" (a recompensa), "xp_gained" (o que contou, menor no limite),
## "level_before", "level", "current_xp", "next_xp", "limit", "at_limit"
## (parou no limite da Torre), "gains" ({atributo: aumento}, vazio se não subiu)}.
static func grant_xp(id: String, amount: int) -> Dictionary:
	var r := _add_xp(id, amount)
	save()
	return r


static func _add_xp(id: String, amount: int) -> Dictionary:
	var before := progress(id)
	var limit := Floors.level_limit()
	var after := add_xp(before.level, before.xp, amount, limit)
	_store(id, after)
	var gains := {}
	if after.level > before.level:
		var base_stats := Roster.level_1_stats(id)
		var growth: Dictionary = Roster.data(id).get("growth", {})
		var a := stats(base_stats, growth, before.level)
		var b := stats(base_stats, growth, after.level)
		for k in STATS:
			# como a interface mostra: diferença dos valores arredondados
			var diff := roundi(b[k]) - roundi(a[k])
			if diff != 0:
				gains[k] = diff
	var gained := maxi(0, total_xp(after.level, after.xp) - total_xp(before.level, before.xp))
	return {"id": id, "xp": amount, "xp_gained": gained, "level_before": before.level, "level": after.level,
		"current_xp": after.xp, "next_xp": xp_to_next(after.level), "limit": limit,
		"at_limit": after.level >= limit and after.level < MAX_LEVEL, "gains": gains}


## Recompensa de uma vitória: a XP dos `enemies`, inteira, para quem lutou
## (`participants`, inclusive quem caiu) e também para os liberados que
## ficaram de fora, para trocar de equipe não custar níveis. O valor não
## depende do tamanho do elenco. Quem não foi liberado não ganha. Salva uma
## vez só no fim. Devolve um resultado de grant_xp() por personagem, com
## "took_part"; quem lutou vem primeiro, na ordem da equipe.
static func reward_victory(participants: Array[String], enemies: Array[Enemy]) -> Array[Dictionary]:
	var xp := battle_xp(enemies)
	var list: Array[Dictionary] = []
	var ids: Array[String] = participants.filter(func(id: String) -> bool: return is_unlocked(id))
	for id in Roster.available():
		if id not in ids:
			ids.append(id)
	for id in ids:
		var r := _add_xp(id, xp)
		r.took_part = id in participants
		list.append(r)
	save()
	return list


# ------------------------------------------------------------- a Torre
## Andares vencidos ao menos uma vez (números, ver Floors).
static func cleared_floors() -> Array[int]:
	var list: Array[int] = []
	for n: Variant in _data().get_value("torre", "vencidos", []):
		if (n is int or n is float) and int(n) not in list:
			list.append(int(n))
	return list


static func mark_floor_cleared(number: int) -> void:
	var list := cleared_floors()
	if number not in list:
		list.append(number)
		list.sort()
		_data().set_value("torre", "vencidos", list)
		save()


static func chosen_floor() -> int:
	return int(_data().get_value("torre", "andar", 1))


static func save_chosen_floor(number: int) -> void:
	_data().set_value("torre", "andar", number)
	save()


## Eventos de história já aplicados que o saguão ainda não apresentou
## (formato em StoryEvents), na ordem.
static func pending_events() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for e: Variant in _data().get_value("torre", "eventos_pendentes", []):
		if e is Dictionary:
			list.append(_event_from_save(e))
	return list


## Evento salvo antes do código passar para o inglês ({"tipo": "desbloquear",
## "id", "quem"?}) no formato atual; o que já está no formato atual passa igual.
static func _event_from_save(e: Dictionary) -> Dictionary:
	if not e.has("tipo"):
		return e
	var types := {"desbloquear": "unlock", "conversa": "conversation"}
	var event := {"type": types.get(e.tipo, e.tipo), "id": e.get("id", "")}
	if e.has("quem"):
		event.speaker = e.quem
	return event


static func add_pending_events(events: Array) -> void:
	if events.is_empty():
		return
	var list := pending_events()
	for e: Dictionary in events:
		list.append(e)
	_data().set_value("torre", "eventos_pendentes", list)
	save()


## Tira o primeiro pendente (depois de apresentado).
static func pop_pending_event() -> void:
	var list := pending_events()
	if not list.is_empty():
		list.pop_front()
		_data().set_value("torre", "eventos_pendentes", list)
		save()

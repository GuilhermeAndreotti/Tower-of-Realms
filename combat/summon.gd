class_name Summon
extends Combatant
## Criatura chamada por um aliado (como os demônios da Askara). Luta do lado
## dele, com vez própria na fila, HP e estados, mas não é da equipe: não
## ganha XP, não conta para a derrota e não é salva. Age sozinha: em cada vez
## usa o `strike` (e o `debuff`, se tiver). Vai embora quando as vezes acabam,
## quando cai ou quando quem a invocou cai; quem tira de campo é a batalha.
## Ao sair por tempo ou ao cair, faz o `last_act`, se tiver.

const SHIELD_DURATION := 2  ## turnos de quem recebe o escudo do último ato

var id: String
## Quem a chamou. Referência fraca: o kit guarda as invocações, e as duas
## pontas fortes formariam um ciclo que nunca é liberado.
var summoner: Combatant:
	get: return _summoner.get_ref() as Combatant
var texture: String
var color := Color.WHITE  ## cor da aura e do nome no registro
var turns := 0  ## vezes que ainda vai agir; ao chegar a 0, vai embora
var max_turns := 0
var on_field := true  ## false = saiu (tempo, queda, substituída)

## Golpe de cada vez: {"name", "mult", "reach" (unico/dupla/vizinhos/todos;
## dupla = o alvo e o de trás), "neighbor_mult"?, "aim"? (alvo/strongest),
## "style"? ("projectile", "charge": avança até cada alvo, ou "dive":
## mergulha no principal e explode em todos de uma vez, sem voltar; para
## últimos atos), "hit"? (no "charge": "slash", o padrão, ou "kiss"),
## "debuff_all"? (o debuff vai em todos os atingidos, não só no
## principal)}. O dano é do tipo da invocação.
var strike := {}
## Golpe na chegada, na hora da invocação, no mesmo formato ({} = nenhum).
var entrance_strike := {}
## Último ato, quando sai por tempo ou cai: golpe no mesmo formato, com
## "mult" opcional, e "shield"?
## (fração do HP máximo dela que vira escudo no aliado com menos HP).
## Substituição e a queda de quem invocou não disparam. {} = nenhum.
var last_act := {}
## Fábrica (Callable sem argumentos que devolve um StatusEffect novo) do debuff
## que o golpe deixa no alvo principal; vazio = nenhum.
var debuff := Callable()

var _summoner: WeakRef


func _init(p_id: String, p_name: String, p_summoner: Combatant, p_hp: int, p_atk: float, p_def: float, p_spd: float, p_type: String, p_turns: int) -> void:
	super(p_name, true, p_hp, p_atk, p_def, p_spd, p_type)
	id = p_id
	_summoner = weakref(p_summoner)
	turns = p_turns
	max_turns = p_turns


func in_play() -> bool:
	return on_field and is_alive()


## Volta ao começo: HP cheio e todas as vezes (invocar de novo a mesma).
func renew() -> void:
	hp = max_hp
	turns = max_turns


## Fim de uma vez dela. Devolve true se acabou o tempo (a batalha a tira).
func consume_turn() -> bool:
	turns -= 1
	return turns <= 0


## Alvos de `g` entre `enemies` (vivos, em ordem), a partir do inimigo
## que o jogador marcou (`target`): [[inimigo, mult], ...], o principal primeiro.
func targets(g: Dictionary, enemies: Array, target: int) -> Array:
	if enemies.is_empty() or g.is_empty():
		return []
	var i := clampi(target, 0, enemies.size() - 1)
	if g.get("aim", "target") == "strongest":
		for k in enemies.size():
			if (enemies[k] as Combatant).atk() > (enemies[i] as Combatant).atk():
				i = k
	var list := [[enemies[i], g.mult]]
	var behind := i + 1 if i + 1 < enemies.size() else i - 1
	for k in enemies.size():
		if k == i:
			continue
		match g.get("reach", "single"):
			"all": list.append([enemies[k], g.mult])
			"pair":
				if k == behind:
					list.append([enemies[k], g.get("neighbor_mult", g.mult)])
			"neighbors":
				if absi(k - i) == 1:
					list.append([enemies[k], g.get("neighbor_mult", g.mult)])
	return list


## Quem recebe o escudo do último ato: o aliado de pé (fora ela) com a menor
## fração de HP. `allies` = os aliados em campo; null se não houver.
func shield_target(allies: Array) -> Combatant:
	var best: Combatant = null
	for c: Combatant in allies:
		if c == self or not c.is_alive():
			continue
		if best == null or float(c.hp) / c.max_hp < float(best.hp) / best.max_hp:
			best = c
	return best


## Escudo do último ato `g`, sobre o HP máximo dela.
func last_act_shield(g: Dictionary) -> StatusEffect:
	var e := StatusEffect.new("shield_" + id, g.name, "ESC", "buff", SHIELD_DURATION)
	e.shield = roundi(max_hp * g.shield)
	e.color = color
	return e


func effects() -> Array[Dictionary]:
	var list: Array[Dictionary] = [{"id": "summon", "short": str(turns), "name": "Invocação", "type": "buff",
		"turns": turns, "color": color, "detail": "vai embora em %d vez%s" % [turns, "" if turns == 1 else "es"]}]
	list.append_array(super())
	return list

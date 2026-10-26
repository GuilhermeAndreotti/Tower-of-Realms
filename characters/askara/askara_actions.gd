class_name AskaraActions
extends CharacterActions
## Animações e efeitos do kit da Àskara (regras em Askara). As invocações
## entram, agem e saem pela batalha (Battle.add_summon e
## summon_strike); aqui fica só o que ela mesma faz.

## Orbe vil ao lado dela no quadro "cast", a partir dos pés (em pixels
## da tela; ver tools/generate_askara.py).
const ORB := Vector2(33, -54)

var k: Askara:
	get: return p as Askara


func execute(action: String) -> void:
	match action:
		"basic": await _vile_arrow()
		"skill": await _summon()
		"ult": await _lord()


func _cast() -> void:
	v.play("cast")
	await b.wait(0.27)


# ------------------------------------------------------------- seta vil
func _vile_arrow() -> void:
	var target := b.current_target()
	b.hud.log_line("%s utilizou %s!" % [BattleHud.fighter_name(k), BattleHud.highlight("Seta Vil", Askara.VILE_COLOR)])
	await _cast()
	var flight := CombatEffects.projectile(b.world, v.position + ORB, center(target), k.type, 1100.0, 1.0)
	await b.wait(flight)
	CombatEffects.elemental_impact(b.world, center(target), k.type, 0.9)
	CombatEffects.impact(b.world, center(target), Askara.VILE_COLOR, 0.6)
	await b.apply_damage(k, target, Askara.ARROW_MULT)
	_on_fragments_gained(k.gain_fragments(Askara.ARROW_FRAGMENTS))
	await b.wait(0.2)


func _on_fragments_gained(amount: int) -> void:
	if amount <= 0:
		return
	CombatEffects.number(b.world, v.top() + Vector2(0, -6), "+%d FRAGMENTO" % amount, "notice")
	CombatEffects.ring(b.world, v.position + ORB, Askara.ASKARA_COLOR, 18.0)
	b.hud.log_line("%s ganha %s (%d/%d)." % [BattleHud.fighter_name(k),
		BattleHud.highlight("Fragmento d'Alma", Askara.ASKARA_COLOR), k.fragments, Askara.MAX_FRAGMENTS])
	b.refresh()


# ------------------------------------------------------------ invocação
func _summon() -> void:
	var d := Askara.summon_data(b.option)
	await _cast()
	var r := k.summon(b.option)
	var inv: Summon = r.summon
	b.hud.log_line("%s gasta %d %s e invoca %s!" % [BattleHud.fighter_name(k), d.fragments,
		"fragment" if d.fragments == 1 else "fragments", BattleHud.highlight(d.name, d.color)])
	var replaced: Summon = r.replaced
	if replaced:
		b.hud.log_line("%s volta ao abismo para abrir espaço." % BattleHud.fighter_name(replaced))
		b.remove_summon(replaced)
	if r.is_new:
		await b.add_summon(inv)
	else:
		var vi := b.visual(inv)
		vi.flash(Color(1.0 + inv.color.r, 1.0 + inv.color.g, 1.0 + inv.color.b))
		CombatEffects.ring(b.world, center(inv), inv.color, 50.0)
		b.hud.log_line("%s é renovado: HP cheio e mais %d vezes." % [BattleHud.fighter_name(inv), inv.turns])
		b.refresh()
	await b.wait(0.2)


# ---------------------------------------------------------------- lorde
func _lord() -> void:
	var cost := k.lord_cost()
	await _cast()
	var r := k.summon_lord(randf())
	var inv: Summon = r.summon
	var dismissed: Array = r.dismissed
	for x: Summon in dismissed:
		b.remove_summon(x)
	b.hud.log_line("%s gasta %d fragmentos%s e abre o portal!" % [BattleHud.fighter_name(k), cost,
		"" if dismissed.is_empty() else " (as invocações em campo alimentam o portal)"])
	var veil := CombatEffects.veil(b.world, Color(inv.color.darkened(0.8), 0.55), 0.0, true)
	if r.rare:
		b.hud.announce("%d%%  ·  %s" % [roundi(Askara.LIGHT_LORD_CHANCE * 100), inv.name.to_upper()], inv.color, 30)
		b.hud.log_line("Algo diferente atende ao chamado: o %s!" % BattleHud.highlight(inv.name, inv.color))
	else:
		b.hud.announce(inv.name.to_upper(), inv.color, 30)
	await b.add_summon(inv)
	b.shake(6.0)
	await b.summon_strike(inv, inv.entrance_strike)
	CombatEffects.fade_veil(veil, 0.4)
	await b.wait(0.3)

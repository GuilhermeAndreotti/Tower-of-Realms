class_name LiaActions
extends CharacterActions
## Animações e efeitos do kit da Lia Moonlight (regras em Lia). Tudo é azul,
## a luz da lua: as curas sobem em quem recebe e a Bênção Lunar volta para
## ela como uma linha. No básico, o Espadito (a espada viva) sai da mão dela
## e golpeia sozinho. A folha e o Espadito são gerados por tools/generate_lia.py.

## Onde o Espadito fica na mão dela, a partir dos pés (em pixels da tela).
const SWORD_HAND := Vector2(27, -24)

var l: Lia:
	get: return p as Lia


func execute(action: String) -> void:
	match action:
		"basic": await _blade()
		"skill": await _heal()
		"skill2": await _nova()
		"ult": await _lord_azeroth()


func _cast() -> void:
	v.play("cast")
	await b.wait(0.26)


## Cura `amount` em `target` com a luz subindo nele.
func _show_heal(target: Combatant, amount: int, strength := 1.0) -> void:
	var at := center(target)
	CombatEffects.ring(b.world, at, Lia.HOLY_COLOR, 40.0 * strength)
	CombatEffects.impact(b.world, at + Vector2(0, -10), Lia.HOLY_COLOR, 0.8 * strength)
	b.visual(target).flash(Color(1.3, 1.5, 2.0))
	if amount > 0:
		CombatEffects.number(b.world, b.visual(target).top(), "+%d" % amount, "heal")


## Bênção Lunar: parte do que curou nos outros volta para ela.
func _blessing(healed_others: int, from: Array) -> void:
	var back := l.lunar_blessing(healed_others)
	if back <= 0:
		return
	for c: Combatant in from:
		CombatEffects.line(b.world, center(c), center(l), Lia.MOON_COLOR, 0.4)
	CombatEffects.number(b.world, v.top() + Vector2(0, -12), "+%d" % back, "heal")
	v.flash(Color(1.3, 1.5, 2.0))
	b.log_line("%s recupera %s de HP (%s)." % [UIStyle.fighter_name(l), UIStyle.highlight(str(back), UIStyle.HEAL),
		UIStyle.highlight("Bênção Lunar", Lia.MOON_COLOR)])


# --------------------------------------------------------------- Espadito
## A espada viva sai da mão dela num arco, corta o alvo duas vezes e volta.
## Ela fica sem a espada ("send") enquanto ele está fora.
func _blade() -> void:
	var target := b.current_target()
	b.log_line("%s manda o %s em %s." % [UIStyle.fighter_name(l), UIStyle.highlight("Espadito", Lia.MOON_COLOR),
		UIStyle.fighter_name(target)])
	var start := v.position + SWORD_HAND
	var blade := Sprite2D.new()
	blade.texture = load(Lia.FOLDER + "espadito.png")
	blade.scale = Vector2(FighterVisual.SCALE, FighterVisual.SCALE)
	blade.position = start
	b.world.add_child(blade)
	v.play("send")
	CombatEffects.ring(b.world, start, Lia.MOON_COLOR, 26.0)
	var at := center(target)
	var near := at + Vector2(-46, 0)
	await _fly(blade, start, near, 0.3, 50.0)
	for i in 2:
		var t := blade.create_tween()
		t.tween_property(blade, "position", at + Vector2(12, 0), 0.07)
		t.tween_property(blade, "position", near, 0.1)
		await b.wait(0.07)
		CombatEffects.slash(b.world, at, Lia.MOON_COLOR, 40.0, -1.2 if i == 0 else 1.2)
		CombatEffects.impact(b.world, at, Lia.HOLY_COLOR, 0.8)
		if i == 1:
			await b.apply_damage(l, target, Lia.BLADE_MULT)
		await b.wait(0.1)
	await _fly(blade, blade.position, start, 0.28, 40.0)
	blade.queue_free()
	v.play("idle")
	l.gain_energy(Lia.ENERGY_BASIC)
	b.refresh()


## Voo do Espadito de `from` a `to`, num arco de `height` px, deixando brilho.
func _fly(blade: Sprite2D, from: Vector2, to: Vector2, duration: float, height: float) -> void:
	blade.flip_h = to.x < from.x
	var step := func(k: float) -> void:
		blade.position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * height)
		if randf() < 0.35:
			CombatEffects.impact(b.world, blade.position, Lia.MOON_COLOR, 0.35)
	var t := blade.create_tween()
	t.tween_method(step, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE)
	await t.finished
	blade.flip_h = false


# -------------------------------------------------------- Curar Ferimentos
func _heal() -> void:
	var target := b.current_ally()
	b.log_line("%s utilizou %s em %s." % [UIStyle.fighter_name(l), UIStyle.highlight("Curar Ferimentos", Lia.HOLY_COLOR),
		UIStyle.fighter_name(target)])
	await _cast()
	CombatEffects.charge(b.world, center(target), [Lia.HOLY_COLOR, Color.WHITE, Lia.MOON_COLOR], 0.35, 70.0)
	await b.wait(0.35)
	var healed := l.heal_target(target, Lia.HEAL_FRACTION)
	_show_heal(target, healed, 1.4)
	b.log_line("%s recupera %s de HP." % [UIStyle.fighter_name(target), UIStyle.highlight(str(healed), UIStyle.HEAL)])
	if target != l:
		await b.wait(0.2)
		_blessing(healed, [target])
	l.gain_energy(Lia.ENERGY_SKILL)
	b.refresh()
	await b.wait(0.3)


# ----------------------------------------------------------- Nova Sagrada
## A luz estoura nela e corre pelo campo: cura os aliados e fere os inimigos.
func _nova() -> void:
	b.log_line("%s utilizou %s!" % [UIStyle.fighter_name(l), UIStyle.highlight("Nova Sagrada", Lia.HOLY_COLOR)])
	await _cast()
	var at := center(l)
	CombatEffects.ring(b.world, at, Lia.HOLY_COLOR, 160.0)
	CombatEffects.ring(b.world, at, Color.WHITE, 100.0)
	CombatEffects.veil(b.world, Color(0.6, 0.8, 1.0, 0.3), 0.35)
	b.shake(2.5)
	await b.wait(0.2)
	var others := 0
	var healed_others: Array = []
	for ally in b.allies_on_field():
		var healed := l.heal_target(ally, Lia.NOVA_HEAL)
		_show_heal(ally, healed)
		if ally != l and healed > 0:
			others += healed
			healed_others.append(ally)
	b.log_line("A luz cura a equipe em %s do HP máximo." % UIStyle.highlight("%d%%" % roundi(Lia.NOVA_HEAL * 100), UIStyle.HEAL))
	await b.wait(0.15)
	for target in b.living_enemies():
		CombatEffects.impact(b.world, center(target), Lia.MOON_COLOR, 1.1)
		CombatEffects.ring(b.world, center(target), Lia.HOLY_COLOR, 34.0)
		await b.apply_damage(l, target, Lia.NOVA_MULT)
	_blessing(others, healed_others)
	l.gain_energy(Lia.ENERGY_SKILL)
	b.refresh()
	await b.wait(0.3)


# ----------------------------------------------------------- Lord Azeroth
## Ela ergue o escudo; uma muralha de luz sobe na frente de cada aliado.
func _lord_azeroth() -> void:
	l.use_ult()
	b.announce("LORD AZEROTH", Lia.MOON_COLOR, 32)
	b.log_line("%s ergue o escudo: %s protege a equipe." % [UIStyle.fighter_name(l), UIStyle.highlight("Lord Azeroth", Lia.MOON_COLOR)])
	v.play("cast")
	CombatEffects.charge(b.world, center(l), [Lia.MOON_COLOR, Color.WHITE, Lia.HOLY_COLOR], 0.45, 110.0)
	await b.wait(0.45)
	v.flash(Color(1.8, 2.0, 2.6))
	CombatEffects.ring(b.world, center(l), Lia.MOON_COLOR, 120.0)
	for ally in b.allies_on_field():
		ally.apply_status(Lia.lord_azeroth())
		var va := b.visual(ally)
		CombatEffects.wall(b.world, va.position + Vector2(50, 4), Lia.MOON_COLOR, va.height * 0.9)
		va.flash(Color(1.4, 1.6, 2.2))
	b.shake(3.0)
	b.refresh()
	await b.wait(0.8)

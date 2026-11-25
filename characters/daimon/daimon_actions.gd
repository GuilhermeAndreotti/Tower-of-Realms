class_name DaimonActions
extends CharacterActions
## Animações e efeitos do kit do Daimon (regras em Daimon). Todo tiro sai da
## Cold, o rifle desenhado por tools/generate_daimon.py: ele ergue o rifle
## ("shot"), o traçante gelado cruza a arena e o gelo estoura no alvo.
## Mirando, ele fica parado com o rifle no ombro ("aim"). Enquanto a passiva
## garante o crítico, o inimigo que encheu a Geada leva a marca da Cold (o
## Santo Graal) sobre a cabeça.

## Boca do cano com o rifle no ombro, a partir dos pés (em pixels da tela;
## o gerador imprime a ponta no quadro).
const MUZZLE := Vector2(82, -53)
const TRACER_SPEED := 4200.0
const ICE_COLORS: Array[Color] = [Color(0.35, 0.65, 0.95), Color(0.6, 0.9, 1.0), Color(0.92, 0.98, 1.0)]
const COLD_MARK := preload("res://characters/daimon/icon_cold.png")

var _marks: Array[Node2D] = []  ## marcas da Cold nos inimigos, até a janela acabar

var d: Daimon:
	get: return p as Daimon


func execute(action: String) -> void:
	if action != "skill2":
		_lower_aim()
	match action:
		"basic": await _basic()
		"skill": await _bullet()
		"skill2": await _cold_aim()
		"ult": await _absolute_zero()


func end_turn() -> void:
	if not d.end_turn():
		return
	var cleared := d.clear_full_frost(b.living_enemies())
	_clear_marks()
	b.log_line("A %s se acalma: acaba o crítico garantido%s." % [UIStyle.highlight("Cold", Daimon.COLD_COLOR),
		" e a Geada se desfaz" if not cleared.is_empty() else ""])
	b.refresh()


func _muzzle() -> Vector2:
	return v.position + MUZZLE


# ----------------------------------------------------------------- o tiro
## Ergue a Cold e atira em `target`: o traçante cruza a arena e o gelo
## estoura nele. `size` engrossa o traçante e o impacto (tiros fortes).
func _fire(target: Combatant, mult: float, size := 1.0) -> void:
	v.play("shot")
	await b.wait(0.08)
	var from := _muzzle()
	var to := center(target)
	CombatEffects.impact(b.world, from, Color.WHITE, 0.5 * size)
	CombatEffects.beam(b.world, from, (to - from).angle(), from.distance_to(to), TRACER_SPEED, {
		"width": 3.0 * size, "sparks": 30.0 * size,
		"colors": [ICE_COLORS[0], ICE_COLORS[1], ICE_COLORS[2], Color.WHITE]}, 0.05)
	await b.wait(from.distance_to(to) / TRACER_SPEED)
	CombatEffects.elemental_impact(b.world, to, d.type, 1.1 * size)
	if size > 1.0:
		CombatEffects.ring(b.world, to, Daimon.COLD_COLOR, 36.0 * size)
		b.shake(2.0 * size)
	await b.apply_damage(d, target, mult)


## Deixa Geada em `target` e mostra; se a Geada encheu, abre a janela da Cold.
func _frost(target: Combatant, amount: int) -> void:
	var r := d.add_frost(target, amount)
	if r.added <= 0:
		return
	var vt := b.visual(target)
	CombatEffects.ring(b.world, center(target), Daimon.COLD_COLOR, 26.0 + 8.0 * r.stacks)
	vt.flash(Color(1.4, 1.8, 2.2))
	b.log_line("%s fica com %s." % [UIStyle.fighter_name(target),
		UIStyle.highlight("Geada %d/%d" % [r.stacks, Daimon.FROST_MAX], Daimon.COLD_COLOR)])
	if r.cold:
		await _cold_awakens(target)
	b.refresh()


## A Geada chegou ao máximo: o alvo fica Lento e a Cold garante o crítico.
func _cold_awakens(target: Combatant) -> void:
	v.flash(Color(1.8, 2.3, 2.8))
	CombatEffects.ring(b.world, center(d), Daimon.COLD_COLOR, 70.0)
	CombatEffects.impact(b.world, center(target), ICE_COLORS[2], 1.6)
	CombatEffects.veil(b.world, Color(0.6, 0.9, 1.0, 0.18), 0.3)
	b.announce("COLD", Daimon.COLD_COLOR, 32)
	_mark(target)
	b.log_line("%s fica %s, e a %s garante o crítico de %s por %d turnos." % [UIStyle.fighter_name(target),
		UIStyle.highlight("Lento", Daimon.COLD_COLOR), UIStyle.highlight("Cold", Daimon.COLD_COLOR),
		UIStyle.fighter_name(d), Daimon.COLD_DURATION])
	await b.wait(0.35)


# ------------------------------------------------------- Disparo e Bala
func _basic() -> void:
	var target := b.current_target()
	b.log_line("%s utilizou %s!" % [UIStyle.fighter_name(d), UIStyle.highlight("Disparo", Daimon.COLD_COLOR)])
	await _fire(target, Daimon.BASIC_MULT)
	await _frost(target, Daimon.BASIC_FROST)
	d.gain_energy(Daimon.ENERGY_BASIC)
	b.refresh()
	await b.wait(0.2)


func _bullet() -> void:
	var target := b.current_target()
	b.log_line("%s utilizou %s!" % [UIStyle.fighter_name(d), UIStyle.highlight("Bala Congelante", Daimon.COLD_COLOR)])
	v.play("aim")
	CombatEffects.charge(b.world, _muzzle(), ICE_COLORS, 0.25, 34.0)
	await b.wait(0.25)
	await _fire(target, Daimon.BULLET_MULT, 1.4)
	await _frost(target, Daimon.BULLET_FROST)
	d.gain_energy(Daimon.ENERGY_SKILL)
	b.refresh()
	await b.wait(0.2)


# -------------------------------------------------------------- Mira Fria
## Sem mira, trava no alvo marcado. Mirando, a opção escolhida segura (mais
## um nível) ou dispara no alvo travado (se ele caiu, a mira passa para o
## marcado, com o mesmo nível).
func _cold_aim() -> void:
	if not d.aiming():
		var target := b.current_target()
		d.start_aim(target)
		b.log_line("%s trava a %s em %s." % [UIStyle.fighter_name(d), UIStyle.highlight("Mira Fria", Daimon.COLD_COLOR),
			UIStyle.fighter_name(target)])
		await _take_aim(target)
		return
	if d.aim_target == null or not d.aim_target.is_alive():
		d.aim_target = b.current_target()
	var target := d.aim_target
	if b.option == "fire":
		var level := d.aim_level
		var mult := d.release_aim()
		v.set_idle_anim("idle")
		b.log_line("%s solta a %s (nível %d)!" % [UIStyle.fighter_name(d), UIStyle.highlight("Mira Fria", Daimon.COLD_COLOR), level])
		CombatEffects.aim(b.world, center(target), 22.0, Color.WHITE, 0.3)
		CombatEffects.charge(b.world, _muzzle(), ICE_COLORS, 0.3, 30.0 + 20.0 * level)
		await b.wait(0.3)
		await _fire(target, mult, 1.0 + 0.5 * level)
		d.gain_energy(Daimon.ENERGY_RELEASE)
		b.refresh()
		await b.wait(0.3)
		return
	d.hold_aim()
	b.log_line("%s segura a %s: nível %d." % [UIStyle.fighter_name(d), UIStyle.highlight("Mira Fria", Daimon.COLD_COLOR), d.aim_level])
	await _take_aim(target)


## Ergue o rifle e fecha a retícula em `target` (mais apertada a cada nível);
## a mira gela o alvo.
func _take_aim(target: Combatant) -> void:
	v.set_idle_anim("aim")
	v.play("aim")
	CombatEffects.aim(b.world, center(target), 48.0 - 8.0 * d.aim_level, Daimon.COLD_COLOR, 0.7)
	CombatEffects.line(b.world, _muzzle(), center(target), Daimon.COLD_COLOR, 0.5)
	await b.wait(0.5)
	await _frost(target, Daimon.AIM_FROST)
	d.gain_energy(Daimon.ENERGY_AIM)
	b.refresh()
	await b.wait(0.2)


## Outra ação com a mira travada: ele baixa o rifle sem atirar.
func _lower_aim() -> void:
	if not d.cancel_aim():
		return
	v.set_idle_anim("idle")
	b.log_line("%s baixa a %s." % [UIStyle.fighter_name(d), UIStyle.highlight("Mira Fria", Daimon.COLD_COLOR)])
	b.refresh()


# ---------------------------------------------------------- Zero Absoluto
func _absolute_zero() -> void:
	var target := b.current_target()
	var mult := d.zero_mult(target)
	d.use_ult()
	b.log_line("%s utilizou %s!" % [UIStyle.fighter_name(d), UIStyle.highlight("Zero Absoluto", Daimon.COLD_COLOR)])
	v.play("aim")
	CombatEffects.veil(b.world, Color(0.55, 0.85, 1.0, 0.25), 0.6)
	CombatEffects.aim(b.world, center(target), 30.0, Color.WHITE, 0.6)
	CombatEffects.charge(b.world, _muzzle(), ICE_COLORS, 0.6, 110.0)
	b.announce("ZERO ABSOLUTO", Daimon.COLD_COLOR, 30)
	await b.wait(0.6)
	await _fire(target, mult, 2.6)
	CombatEffects.ring(b.world, center(target), ICE_COLORS[2], 90.0)
	b.shake(7.0)
	b.refresh()
	await b.wait(0.5)


# ---------------------------------------------------------- marca da Cold
## Põe a marca da Cold sobre `target` (filha do visual dele, então acompanha
## quando ele se mexe).
func _mark(target: Combatant) -> void:
	var mark := _ColdMark.new()
	mark.visual = b.visual(target)
	mark.visual.add_child(mark)
	_marks.append(mark)


func _clear_marks() -> void:
	for mark in _marks:
		if is_instance_valid(mark):
			mark.fade()
	_marks.clear()


## O Santo Graal flutuando acima da seta de alvo, com um anel gelado que
## pulsa atrás. Some sozinho se o inimigo cair.
class _ColdMark extends Node2D:
	const RISE := 62.0  ## acima da barra de HP (a seta de alvo fica entre as duas)
	var visual: FighterVisual
	var _time := 0.0
	var _icon: Sprite2D

	func _ready() -> void:
		z_index = 5
		_icon = Sprite2D.new()
		_icon.texture = COLD_MARK
		_icon.scale = Vector2(FighterVisual.SCALE, FighterVisual.SCALE)
		add_child(_icon)
		position = Vector2(0, -visual.height - 16.0 - RISE)
		scale = Vector2(0.2, 0.2)
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _process(delta: float) -> void:
		if visual.combatant == null or not visual.combatant.is_alive():
			fade()
			set_process(false)
			return
		_time += delta
		position = Vector2(0, -visual.height - 16.0 - RISE + roundf(sin(_time * 3.0) * 2.0) * CombatEffects.PIXEL)
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(_time * 5.0)
		var radius := 24.0 + 4.0 * pulse
		draw_circle(Vector2.ZERO, radius, Color(Daimon.COLD_COLOR, 0.12 + 0.1 * pulse))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(Daimon.COLD_COLOR, 0.5 + 0.4 * pulse), CombatEffects.PIXEL)

	func fade() -> void:
		var t := create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.3)
		t.tween_callback(queue_free)

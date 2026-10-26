class_name AndriActions
extends CharacterActions
## Animações e efeitos do kit do Andri e do MOMC (regras em Andri).

const MOMC_TEXTURE := preload("res://characters/andri/momc.png")
const POS_MOMC := Vector2(-30, 0)  ## à esquerda dos pés, como no sprite original
## Ponta do dispositivo com o braço estendido e a lente no olho, a partir
## dos pés (em pixels da tela; ver tools/generate_andri.py).
const DEVICE_TIP := Vector2(30, -60)
const LENS := Vector2(-9, -78)

var a: Andri:
	get: return p as Andri

var _momc: Sprite2D


func _init(p_battle: Battle, p_character: Combatant, p_visual: FighterVisual) -> void:
	super(p_battle, p_character, p_visual)
	_momc = Sprite2D.new()
	_momc.texture = MOMC_TEXTURE
	_momc.centered = false
	_momc.offset = -Vector2(MOMC_TEXTURE.get_width() / 2.0, MOMC_TEXTURE.get_height())
	_momc.scale = Vector2(FighterVisual.SCALE, FighterVisual.SCALE)
	_momc.position = POS_MOMC
	v.add_child(_momc)
	# flutua de leve, fora do ritmo do Andri
	var t := _momc.create_tween().set_loops()
	t.tween_property(_momc, "position:y", POS_MOMC.y - 6, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(_momc, "position:y", POS_MOMC.y, 0.7).set_trans(Tween.TRANS_SINE)
	var lens := _Lens.new()
	lens.andri = a
	lens.position = LENS
	v.add_child(lens)


func execute(action: String) -> void:
	match action:
		"basic": await _shot()
		"skill": await _analysis()
		"skill2": await _protocol()
		"ult": await _arsenal()
		"lens": await _switch_lens()


## A torre de lentes sai do monóculo.
func selector_anchor(action: String) -> Vector2:
	if action == "lens":
		return LENS + Vector2(1.5, 1.5)
	return super(action)


# --------------------------------------------------------------- disparo
func _shot() -> void:
	var target := b.current_target()
	var strikes := a.shot_strikes()
	b.log_line("%s utilizou %s de %s!" % [UIStyle.fighter_name(a), UIStyle.highlight("Disparo Elemental", UIStyle.GOLD),
		UIStyle.highlight(Types.name(a.lens), Types.color(a.lens))])
	v.play("shot")
	await b.wait(0.1)
	var flight := CombatEffects.projectile(b.world, v.position + DEVICE_TIP, center(target), a.lens, 1000.0, 1.2)
	await b.wait(flight)
	CombatEffects.elemental_impact(b.world, center(target), a.lens, 1.1)
	await b.apply_damage(a, target, strikes[0].mult, strikes[0].type, strikes[0].extra)
	if target.is_alive():
		await _momc_attack(target, strikes[1])
	a.gain_energy(Andri.BASIC_ENERGY)
	await b.wait(0.2)


## O MOMC sobe, os olhos acendem e ele dispara um projétil menor.
func _momc_attack(target: Combatant, strike: Dictionary, size := 0.7, notice := "O %s ataca junto!") -> void:
	var base := _momc.position
	var t := _momc.create_tween()
	t.tween_property(_momc, "position", base + Vector2(8, -22), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished
	_momc.modulate = Color(1.6, 1.6, 2.4)
	# lado direito do robô (o MOMC tem ~21 px de largura, com a origem nos pés)
	var muzzle := v.position + _momc.position + Vector2(9, -12)
	CombatEffects.ring(b.world, muzzle, Types.color(strike.type), 14.0)
	var flight := CombatEffects.projectile(b.world, muzzle, center(target), strike.type, 1200.0, size)
	var back := _momc.create_tween()
	back.tween_property(_momc, "position", base + Vector2(-4, -16), 0.06)
	back.tween_property(_momc, "position", base, 0.2).set_trans(Tween.TRANS_QUAD)
	back.parallel().tween_property(_momc, "modulate", Color.WHITE, 0.25)
	await b.wait(flight)
	CombatEffects.elemental_impact(b.world, center(target) + Vector2(6, 8), strike.type, size)
	b.log_line(notice % UIStyle.highlight("MOMC", Andri.MOMC_COLOR))
	await b.apply_damage(a, target, strike.mult, strike.type, strike.extra)


# ------------------------------------------------------ protocolo MOMC
func _protocol() -> void:
	b.log_line("%s ativa o %s: %s." % [UIStyle.fighter_name(a), UIStyle.highlight("Protocolo MOMC", UIStyle.GOLD),
		"Escudo" if b.option == "shield" else "Sobrecarga"])
	v.play("analysis")
	if b.option == "shield":
		await _momc_shield(b.current_ally())
	else:
		_momc.modulate = Color(2.0, 2.0, 2.6)
		CombatEffects.charge(b.world, v.position + _momc.position + Vector2(0, -12), [Color.WHITE, Types.color(a.lens)], 0.35, 50.0)
		await b.wait(0.35)
		await _momc_attack(b.current_target(), a.overload_strike(), 1.3, "O %s dispara em sobrecarga!")
	a.gain_energy(Andri.SKILL_ENERGY)
	b.refresh()
	await b.wait(0.3)


## O MOMC voa até o aliado, fecha o escudo em volta dele e volta.
func _momc_shield(target: Combatant) -> void:
	var base := _momc.position
	var va := b.visual(target)
	var fly_out := _momc.create_tween()
	fly_out.tween_property(_momc, "position", va.position - v.position + Vector2(-26, -va.height * 0.6), 0.3).set_trans(Tween.TRANS_SINE)
	await fly_out.finished
	var e := Andri.momc_shield(target)
	target.apply_status(e)
	CombatEffects.ring(b.world, center(target), Andri.MOMC_COLOR, 46.0)
	CombatEffects.impact(b.world, center(target), Color.WHITE, 0.9)
	va.flash(Color(1.55, 1.8, 2.0))
	CombatEffects.number(b.world, va.top(), "(%d)" % e.shield, "shield")
	b.log_line("O %s protege %s: escudo de %s." % [UIStyle.highlight("MOMC", Andri.MOMC_COLOR), UIStyle.fighter_name(target),
		UIStyle.highlight(str(e.shield), CombatEffects.NUMBERS.shield[0])])
	b.refresh()
	var back := _momc.create_tween()
	back.tween_property(_momc, "position", base, 0.3).set_trans(Tween.TRANS_SINE)
	await back.finished


# --------------------------------------------------------------- análise
func _analysis() -> void:
	var target := b.current_target()
	var element := b.option
	var color := Types.color(element)
	b.log_line("%s utilizou %s em %s." % [UIStyle.fighter_name(a), UIStyle.highlight("Análise de Vulnerabilidade", UIStyle.GOLD), UIStyle.fighter_name(target)])
	v.play("analysis")
	var c := center(target)
	var radius := maxf(30.0, b.visual(target).height * 0.55)
	CombatEffects.line(b.world, v.position + DEVICE_TIP, c, Color(0.35, 0.9, 1.0), 0.7)
	CombatEffects.aim(b.world, c, radius, Color(0.35, 0.9, 1.0), 0.7)
	await b.wait(0.55)
	target.apply_status(Andri.weakness(element))
	CombatEffects.aim(b.world, c, radius * 0.8, color, 0.5)
	CombatEffects.ring(b.world, c, color, radius * 1.3)
	CombatEffects.number(b.world, b.visual(target).top() + Vector2(0, -10), "FRACO A %s" % Types.name(element).to_upper(), "notice")
	b.visual(target).flash(Color(color.r * 2.0, color.g * 2.0, color.b * 2.0))
	b.log_line("%s fica fraco a %s por %d turnos." % [UIStyle.fighter_name(target),
		UIStyle.highlight(Types.name(element), color), Andri.WEAKNESS_DURATION])
	a.gain_energy(Andri.SKILL_ENERGY)
	b.refresh()
	await b.wait(0.5)


# ------------------------------------------------------- arsenal titânico
func _arsenal() -> void:
	var id := b.option
	var target := b.current_ally()
	var art := Andri.artifact(id)
	b.announce(art.name.to_upper(), art.color, 26)
	v.play("analysis")
	# o artefato surge acima do Andri, brilha e voa até o alvo
	var item := Sprite2D.new()
	item.texture = load(Andri.FOLDER + "artifact_%s.png" % id)
	item.scale = Vector2(3, 3)
	item.position = v.top() + Vector2(0, -10)
	b.world.add_child(item)
	CombatEffects.ring(b.world, item.position, art.color, 40.0)
	var rise := item.create_tween()
	rise.tween_property(item, "position:y", item.position.y - 24, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await rise.finished
	var from := item.position
	var to := center(target)
	var height := 60.0 if target != a else 20.0
	var flight := item.create_tween()
	flight.tween_method(func(t: float) -> void:
		item.position = from.lerp(to, t) + Vector2(0, -sin(t * PI) * height), 0.0, 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	await flight.finished
	item.queue_free()

	var r := a.use_artifact(id, target)
	_artifact_effect(id, target, art.color)
	if r.heal > 0:
		CombatEffects.number(b.world, b.visual(target).top(), "+%d" % r.heal, "heal")
	var extra := ""
	if r.heal > 0:
		extra += " Recupera %s de HP." % UIStyle.highlight(str(r.heal), UIStyle.HEAL)
	if r.cleared > 0:
		extra += " Remove %d efeito%s negativo%s." % [r.cleared, "" if r.cleared == 1 else "s", "" if r.cleared == 1 else "s"]
	if r.state:
		var e: StatusEffect = r.state
		extra += " " + art.description.split(":")[0] + (" (escudo %d)." % e.shield if e.shield > 0 else ".")
	b.log_line("%s entrega %s a %s.%s" % [UIStyle.fighter_name(a), UIStyle.highlight(art.name, art.color), UIStyle.fighter_name(target), extra])
	b.refresh()
	await b.wait(0.5)


func _artifact_effect(id: String, target: Combatant, color: Color) -> void:
	var c := center(target)
	var va := b.visual(target)
	va.flash(Color(1.0 + color.r, 1.0 + color.g, 1.0 + color.b))
	CombatEffects.ring(b.world, c, color, 60.0)
	match id:
		"odyn":
			# o olho dourado observa: energia converge e um anel de ouro
			CombatEffects.charge(b.world, c, [Color(1, 0.95, 0.6), color], 0.45, 80.0)
		"tyr":
			# aura prateada que fecha em volta do alvo
			CombatEffects.ring(b.world, c, Color.WHITE, 46.0)
			CombatEffects.impact(b.world, c, color, 1.4)
		"loken":
			# estrela escura que suga a luz, com linhas violetas
			CombatEffects.charge(b.world, c, [Color(0.12, 0.1, 0.18), color], 0.45, 70.0)
		"freya":
			# partículas verdes e douradas subindo das raízes
			for i in 3:
				var point := va.position + Vector2(randf_range(-20, 20), -20 - 30 * i)
				CombatEffects.impact(b.world, point, color if i % 2 == 0 else Color(1, 0.85, 0.4), 0.7)
		"hodir":
			# névoa fria e cristais de gelo
			CombatEffects.impact(b.world, c, Color(0.85, 0.95, 1.0), 1.2)
			CombatEffects.ring(b.world, c, Color.WHITE, 40.0)
		"thorim":
			# descarga azul do bracelete, carregada com o elemento da lente
			CombatEffects.lightning(b.world, c + Vector2(0, -120), c, color)
			CombatEffects.impact(b.world, c, Types.color(a.lens), 1.2)
		"archaedas":
			# fragmentos de rocha e brilho âmbar
			CombatEffects.impact(b.world, va.position + Vector2(0, -6), Color(0.6, 0.6, 0.65), 1.6)
			CombatEffects.impact(b.world, c, color, 0.8)
			b.shake(3.0)
		"ra":
			# a lança desce com o brilho do elemento da lente
			var lens_color := Types.color(a.lens)
			CombatEffects.beam(b.world, c + Vector2(0, -220), PI / 2, 220.0, 1400.0,
				{"width": 9.0, "colors": [lens_color, color, lens_color.lightened(0.5), Color.WHITE]}, 0.1)


# ----------------------------------------------------------------- lente
func _switch_lens() -> void:
	if not a.switch_lens(b.option):
		return  # manteve o elemento
	var color := Types.color(a.lens)
	CombatEffects.ring(b.world, v.position + LENS, color, 22.0)
	CombatEffects.impact(b.world, v.position + LENS, color, 0.5)
	b.log_line("%s ajusta a %s: %s." % [UIStyle.fighter_name(a), UIStyle.highlight("Lente Elemental", UIStyle.GOLD),
		UIStyle.highlight(Types.name(a.lens), color)])
	b.refresh()
	await b.wait(0.3)


## O brilho da lente no olho do Andri, na cor do elemento atual.
class _Lens extends Node2D:
	var andri: Andri
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		visible = andri.is_alive()
		queue_redraw()

	func _draw() -> void:
		var color := Types.color(andri.lens)
		draw_rect(Rect2(-1.5, -1.5, 6, 6), Color(color, 0.25 + 0.15 * sin(_time * 4.0)))
		draw_rect(Rect2(0, 0, 3, 3), color.lightened(0.2))

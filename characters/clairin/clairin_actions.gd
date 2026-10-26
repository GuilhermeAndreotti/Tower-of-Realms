class_name ClairinActions
extends CharacterActions
## Animações e efeitos do kit do Clairin (regras em Clairin). Na Cabeça
## Flamejante ele troca para a folha da cabeça em chamas (gerada por
## tools/generate_clairin.py), como a Shumi troca para o visual Kokoro, para o
## fogo não sumir quando ele apanha ou conjura. Toda ação termina conferindo
## se a Chama Frenética estourou.

## Mão erguida, de onde sai o fogo, a partir dos pés (em pixels da tela).
const HAND := Vector2(21, -72)
const FRENZY_SHEET := "res://characters/clairin/clairin_frenzy_spritesheet.png"
const FRENZY_JSON := "res://characters/clairin/clairin_frenzy_spritesheet.json"
const FIRE_COLORS: Array[Color] = [Color(1.0, 0.55, 0.1), Color(1.0, 0.82, 0.2), Color(1.0, 0.97, 0.75)]

var c: Clairin:
	get: return p as Clairin

var _frames_normal: SpriteFrames
var _frames_frenzy: SpriteFrames


func _init(p_battle: Battle, p_character: Combatant, p_visual: FighterVisual) -> void:
	super(p_battle, p_character, p_visual)
	_frames_normal = v.frames()
	_frames_frenzy = FighterVisual.load_frames(FRENZY_SHEET, FRENZY_JSON)


func execute(action: String) -> void:
	match action:
		"basic": await _fireball()
		"skill": await _wave()
		"skill2": await _discharge()
		"ult": await _flaming_head()
	await _check_overflow()


func end_turn() -> void:
	if c.end_turn():
		v.swap_frames(_frames_normal)
		v.flash(Color(1.6, 1.4, 1.1))
		b.log_line("%s deixa de ser o %s." % [UIStyle.fighter_name(c), UIStyle.highlight("Lorde da Chama Frenética", Clairin.FRENZY_COLOR)])


func _cast() -> void:
	v.play("cast")
	await b.wait(0.22)


func _hand() -> Vector2:
	return v.position + HAND


# ----------------------------------------------------------- Bola de Fogo
## Uma bola no alvo; como Lorde da Chama Frenética, uma em cada inimigo.
func _fireball() -> void:
	var targets: Array = b.living_enemies() if c.in_flaming_head() else [b.current_target()]
	b.log_line("%s utilizou %s!" % [UIStyle.fighter_name(c), UIStyle.highlight("Bola de Fogo", Clairin.FRENZY_COLOR)])
	await _cast()
	var mult := c.basic_mult()
	var flight := 0.0
	for target: Combatant in targets:
		flight = maxf(flight, CombatEffects.projectile(b.world, _hand(), center(target), c.type, 1000.0, 1.3))
	await b.wait(flight)
	for target: Combatant in targets:
		CombatEffects.elemental_impact(b.world, center(target), c.type, 1.2)
		await b.apply_damage(c, target, mult)
	c.gain_frenzy(Clairin.FRENZY_BASIC)
	c.gain_energy(Clairin.ENERGY_BASIC)
	b.refresh()
	await b.wait(0.2)


# --------------------------------------------------------- Onda Frenética
## A onda corre da frente dele até o último inimigo, queimando um de cada vez.
func _wave() -> void:
	b.log_line("%s utilizou %s!" % [UIStyle.fighter_name(c), UIStyle.highlight("Onda Frenética", Clairin.FRENZY_COLOR)])
	await _cast()
	CombatEffects.charge(b.world, _hand(), FIRE_COLORS, 0.3, 60.0)
	await b.wait(0.3)
	var targets := b.living_enemies()
	targets.sort_custom(func(x: Combatant, y: Combatant) -> bool: return b.visual(x).position.x < b.visual(y).position.x)
	for target: Combatant in targets:
		var at := center(target)
		CombatEffects.ring(b.world, at, FIRE_COLORS[1], 54.0)
		CombatEffects.elemental_impact(b.world, at, c.type, 1.3)
		CombatEffects.impact(b.world, at + Vector2(0, 14), FIRE_COLORS[0], 0.9)
		b.shake(2.5)
		await b.apply_damage(c, target, Clairin.WAVE_MULT)
		await b.wait(0.1)
	c.gain_frenzy(Clairin.FRENZY_WAVE)
	c.gain_energy(Clairin.ENERGY_SKILL)
	b.refresh()
	await b.wait(0.25)


# --------------------------------------------------------------- Descarga
## Junta a chama nas mãos (maior quanto mais cheia a barra) e solta no alvo;
## o estouro pega os vizinhos.
func _discharge() -> void:
	var fill := float(c.frenzy) / Clairin.FRENZY_MAX
	var alive := b.living_enemies()
	var i := clampi(b.target, 0, alive.size() - 1)
	var main: Combatant = alive[i]
	var neighbors: Array = alive.slice(maxi(0, i - 1), i + 2).filter(func(e: Combatant) -> bool: return e != main)
	var mult := c.discharge()
	b.log_line("%s solta a %s (%d%% da Chama Frenética)." % [UIStyle.fighter_name(c),
		UIStyle.highlight("Descarga", Clairin.FRENZY_COLOR), roundi(fill * 100)])
	v.play("cast")
	CombatEffects.charge(b.world, _hand(), FIRE_COLORS, 0.4, 50.0 + 90.0 * fill)
	await b.wait(0.4)
	b.refresh()
	var size := 1.0 + 1.2 * fill
	await b.wait(CombatEffects.projectile(b.world, _hand(), center(main), c.type, 900.0, size))
	var at := center(main)
	CombatEffects.elemental_impact(b.world, at, c.type, size)
	CombatEffects.ring(b.world, at, FIRE_COLORS[2], 50.0 + 70.0 * fill)
	CombatEffects.ring(b.world, at, FIRE_COLORS[0], 30.0 + 50.0 * fill)
	b.shake(2.0 + 6.0 * fill)
	await b.apply_damage(c, main, mult)
	for n: Combatant in neighbors:
		CombatEffects.elemental_impact(b.world, center(n), c.type, size * 0.7)
		await b.apply_damage(c, n, mult * Clairin.DISCHARGE_NEIGHBORS)
	c.gain_energy(Clairin.ENERGY_SKILL)
	b.refresh()
	await b.wait(0.3)


# ----------------------------------------------------- Lorde da Chama Frenética
func _flaming_head() -> void:
	c.use_ult()
	v.play("ignite")
	CombatEffects.charge(b.world, center(c) + Vector2(0, -20), FIRE_COLORS, 0.45, 90.0)
	await b.wait(0.45)
	# a folha em chamas não tem "ignite": volta ao parado antes de trocar
	v.play("idle")
	v.swap_frames(_frames_frenzy)
	v.flash(Color(2.6, 2.2, 1.2))
	var head := center(c) + Vector2(0, -24)
	CombatEffects.ring(b.world, head, Clairin.FRENZY_COLOR, 80.0)
	CombatEffects.impact(b.world, head, FIRE_COLORS[2], 1.6)
	CombatEffects.veil(b.world, Color(1.0, 0.75, 0.2, 0.25), 0.35)
	b.announce("LORDE DA CHAMA FRENÉTICA", Clairin.FRENZY_COLOR, 30)
	b.log_line("%s desperta como %s por %d turnos." % [UIStyle.fighter_name(c),
		UIStyle.highlight("Lorde da Chama Frenética", Clairin.FRENZY_COLOR), Clairin.HEAD_DURATION])
	b.shake(5.0)
	b.refresh()
	await b.wait(0.7)


# --------------------------------------------------------------- estouro
## A Chama Frenética encheu: estoura nele e, como Lorde da Chama Frenética, também
## em todos os inimigos.
func _check_overflow() -> void:
	var r := c.overflow()
	if r.is_empty():
		return
	var at := center(c)
	v.flash(Color(2.8, 1.6, 0.6))
	CombatEffects.impact(b.world, at, FIRE_COLORS[0], 2.0)
	CombatEffects.ring(b.world, at, Clairin.FRENZY_COLOR, 90.0)
	if r.damage > 0:
		CombatEffects.number(b.world, v.top(), "-%d" % r.damage, "drain")
	b.announce("CHAMA FRENÉTICA!", Clairin.FRENZY_COLOR, 30)
	b.log_line("A %s estoura: %s perde %s de HP." % [UIStyle.highlight("Chama Frenética", Clairin.FRENZY_COLOR),
		UIStyle.fighter_name(c), UIStyle.highlight(str(r.damage), UIStyle.DRAIN)])
	b.shake(7.0)
	b.refresh()
	await b.wait(0.4)
	if not r.burst:
		return
	b.log_line("A explosão alcança os inimigos!")
	for target: Combatant in b.living_enemies():
		CombatEffects.elemental_impact(b.world, center(target), c.type, 1.6)
		CombatEffects.ring(b.world, center(target), FIRE_COLORS[1], 60.0)
		await b.apply_damage(c, target, Clairin.BURST_MULT, "", true)
	await b.wait(0.3)

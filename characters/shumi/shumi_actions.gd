class_name ShumiActions
extends CharacterActions
## Animações e efeitos do kit da Shumi (regras em Shumi).
## Tudo que muda com o Kaioken é indexado por `s.level + 1` (0 = normal).
## Cada Finger Beam (o do Bang! e os ataques junto) é dado no visual Kokoro
## (gerado pelo mesmo script do sprite sheet, a partir de kokoro.png); depois
## do tiro ela volta ao visual normal.

const STEEL_COLOR := Color(0.85, 0.92, 1.0)  ## lâmina do Corte
const WAVE_COLOR := Color(0.78, 0.5, 1.0)  ## faíscas do Engo-ji, no tom da onda
const WHITE_COLOR := Color(1, 0.96, 1)
const AURA_COLORS: Array[Color] = [Color(0.85, 0.08, 0.1), Color(1.0, 0.35, 0.25), Color(1.0, 0.6, 0.35)]
const WAVE_TIP := preload("res://characters/shumi/engo_ji_wave.png")
const KOKORO_SHEET := "res://characters/shumi/shumi_kokoro_spritesheet.png"
const JSON_KOKORO := "res://characters/shumi/shumi_kokoro_spritesheet.json"

## Corte por nível: [duração de cada trecho da investida, velocidade da animação].
const SLASH := [[0.22, 1.0], [0.17, 1.3], [0.15, 1.5], [0.12, 2.0], [0.08, 2.6]]

## Feixe do Engo-ji por nível (ver CombatEffects.beam).
const BEAMS := [
	{"width": 12.0, "speed": 1500.0, "sparks": 0.0,
		"colors": [Color(0.55, 0.25, 0.85), Color(0.62, 0.33, 0.88), Color(0.85, 0.65, 1.0), Color(0.97, 0.92, 1.0)]},
	{"width": 18.0, "speed": 1700.0, "sparks": 14.0,
		"colors": [Color(0.7, 0.35, 1.0), Color(0.72, 0.42, 1.0), Color(0.92, 0.75, 1.0), Color.WHITE]},
	{"width": 21.0, "speed": 1800.0, "sparks": 22.0, "distortion": 0.3,
		"colors": [Color(0.95, 0.2, 0.3), Color(0.68, 0.3, 0.95), Color(1.0, 0.45, 0.55), Color.WHITE]},
	{"width": 27.0, "speed": 2100.0, "sparks": 34.0, "distortion": 0.6,
		"colors": [Color(1.0, 0.15, 0.2), Color(0.7, 0.3, 1.0), Color(1.0, 0.65, 0.75), Color.WHITE]},
	{"width": 45.0, "speed": 2600.0, "sparks": 60.0, "distortion": 1.0,
		"colors": [Color(1.0, 0.1, 0.15), Color(0.66, 0.28, 1.0), Color(0.95, 0.8, 1.0), Color.WHITE]},
]

var s: Shumi:
	get: return p as Shumi

var _aura: CombatEffects.Aura
var _frames_normal: SpriteFrames
var _frames_kokoro: SpriteFrames


func _init(p_battle: Battle, p_character: Combatant, p_visual: FighterVisual) -> void:
	super(p_battle, p_character, p_visual)
	_frames_normal = v.frames()
	_frames_kokoro = FighterVisual.load_frames(KOKORO_SHEET, JSON_KOKORO)


func start_turn() -> bool:
	if s.loses_next_turn:
		s.loses_next_turn = false
		b.log_line("%s está exausta depois do x20 e perde o turno." % UIStyle.fighter_name(s))
		v.flash(Color(0.5, 0.5, 0.6))
		await b.wait(0.9)
		s.end_turn()
		return false

	var level_before := s.level_name()
	var overload := s.turn_start_overload()
	if overload.damage > 0:
		CombatEffects.number(b.world, v.top(), "-%d" % overload.damage, "drain")
		CombatEffects.impact(b.world, center(s), AURA_COLORS[1], 0.8)
		v.flash(Color(2.5, 0.6, 0.4))
		if is_instance_valid(_aura):
			_aura.pulsar()
		b.log_line("O Kaioken %s queima %s de HP de %s." % [
			level_before, UIStyle.highlight(str(overload.damage), UIStyle.DRAIN), UIStyle.fighter_name(s)])
		b.refresh()
		await b.wait(0.5)
		if not s.is_alive():
			b.log_line("O Kaioken consumiu %s..." % UIStyle.fighter_name(s))
			return false
	if overload.energy > 0:
		CombatEffects.number(b.world, v.top() + Vector2(0, 24), "+%d EN" % roundi(overload.energy), "energy")
		b.log_line("%s: %s recupera %s de energia." % [
			UIStyle.highlight("Limite Humano", UIStyle.ENERGY), UIStyle.fighter_name(s),
			UIStyle.highlight(str(roundi(overload.energy)), UIStyle.ENERGY)])
		b.refresh()
		await b.wait(0.35)
	return true


func execute(action: String) -> void:
	match action:
		"basic": await _slash()
		"skill": await _engo_ji()
		"skill2": await _bang()
		"ult": await _kaioken()


func end_turn() -> void:
	var ended_level := s.end_turn()
	if ended_level != "":
		v.set_idle_anim("idle")
		v.set_base_color(Color.WHITE)
		_remove_aura()
		var extra := " e vai perder o próximo turno" if s.loses_next_turn else ""
		b.log_line("O Kaioken %s acabou. %s está exausta%s." % [ended_level, UIStyle.fighter_name(s), extra])


# ----------------------------------------------------------------- Corte
func _slash() -> void:
	var target := b.current_target()
	var n := s.level + 1
	b.log_line("%s utilizou %s!" % [UIStyle.fighter_name(s), UIStyle.highlight("Corte", UIStyle.GOLD)])
	await charge_at(target, func() -> void:
		v.play("attack_melee", SLASH[n][1])
		await b.wait(0.12 / SLASH[n][1])
		var middle := center(target)
		var radius := maxf(34.0, b.visual(target).height * 0.45)
		match n:
			0:
				CombatEffects.slash(b.world, middle, STEEL_COLOR, radius)
			1, 2:
				# rastro avermelhado atrás da lâmina
				CombatEffects.slash(b.world, middle + Vector2(-6, 0), Shumi.KAIOKEN_COLOR, radius + 6)
				CombatEffects.slash(b.world, middle, STEEL_COLOR, radius)
			3:
				# sequência rápida: três cortes de ângulos diferentes
				for ang in [-0.5, 0.6, 0.0]:
					CombatEffects.slash(b.world, middle, Shumi.KAIOKEN_COLOR, radius + 4, ang)
					CombatEffects.impact(b.world, middle + Vector2(randf_range(-12, 12), randf_range(-12, 12)), AURA_COLORS[2], 0.7)
					await b.wait(0.06)
			4:
				CombatEffects.veil(b.world, Color(1, 0.9, 0.9, 0.35), 0.15)
				CombatEffects.slash(b.world, middle, Shumi.KAIOKEN_COLOR, radius * 1.6)
				CombatEffects.slash(b.world, middle, WHITE_COLOR, radius * 1.3)
		await b.wait(0.08 / SLASH[n][1])
		var impact_color := STEEL_COLOR if n == 0 else AURA_COLORS[2]
		CombatEffects.impact(b.world, middle, impact_color, [1.0, 1.1, 1.5, 1.4, 2.2][n])
		if n >= 2:
			CombatEffects.ring(b.world, middle, Shumi.KAIOKEN_COLOR, 30.0 + 12.0 * n)
			b.shake([0, 0, 3.0, 4.0, 8.0][n])
		await b.apply_damage(s, target, Shumi.BASIC_MULT, s.type)
		# x20: uma pausa curta no impacto pesa o golpe
		await b.wait(0.25 if n < 4 else 0.32), 120.0, SLASH[n][0])
	s.gain_energy(Shumi.BASIC_ENERGY)


# --------------------------------------------------------------- Engo-ji
func _engo_ji() -> void:
	var targets := s.engo_ji_targets(b.living_enemies(), b.target)
	var form := s.engo_ji()
	b.log_line("%s utilizou %s!" % [UIStyle.fighter_name(s), UIStyle.highlight(form.name, WAVE_COLOR)])
	if s.at_max_level():
		await _collapse(targets)
	else:
		await _fire(targets, BEAMS[s.level + 1])
	s.gain_energy(Shumi.SKILL_ENERGY)
	await b.wait(0.2)


## Corte que solta o feixe: a ponta corre da espada até depois do último
## alvo e cada um leva o dano quando ela passa.
func _fire(targets: Array, style: Dictionary, windup := 0.36) -> void:
	var n := s.level + 1
	v.play("engo_ji_beam")
	await b.wait(windup)
	var origin := v.position + Vector2(36, -45)
	# mira na altura média dos alvos; o feixe continua até a borda da tela
	var aim := 0.0
	for pair in targets:
		aim += center(pair[0]).y
	aim /= targets.size()
	var last_x: float = b.visual(targets[-1][0]).position.x
	var dir := (Vector2(last_x, aim) - origin).normalized()
	var reach: float = (CombatEffects.SCREEN.x + 40 - origin.x) / dir.x if s.engo_ji_pierces() \
		else (last_x + 50 - origin.x) / dir.x
	var st := style.duplicate()
	st.tip = WAVE_TIP
	CombatEffects.beam(b.world, origin, dir.angle(), reach, style.speed, st, 0.12 + 0.06 * n)

	var elapsed := 0.0
	for pair in targets:
		var target: Enemy = pair[0]
		var arrives: float = (b.visual(target).position.x - origin.x) / dir.x / style.speed
		if arrives > elapsed:
			await b.wait(arrives - elapsed)
			elapsed = arrives
		var main: bool = pair[1] > Shumi.ENGO_JI_SECONDARY_MULT
		var c := center(target)
		CombatEffects.impact(b.world, c, style.colors[2], (1.0 + 0.25 * n) * (1.0 if main else 0.7))
		if n >= 1:
			CombatEffects.impact(b.world, c, style.colors[0], 0.6 + 0.2 * n)
		if n >= 2 and main:
			# onda de energia no impacto
			CombatEffects.ring(b.world, c, style.colors[0], 40.0 + 14.0 * n)
		if n >= 3:
			CombatEffects.ring(b.world, c, WHITE_COLOR, 34.0)
		await b.apply_damage(s, target, pair[1], s.type)
	b.shake([0.0, 2.0, 3.0, 6.0, 0.0][n])
	await b.wait(0.3 + 0.06 * n)


## x20: concentra (tela escurece, energia converge), dispara um feixe que
## cobre a arena e fica um instante sem fôlego.
func _collapse(targets: Array) -> void:
	var shadow := CombatEffects.veil(b.world, Color(0.04, 0.0, 0.06, 0.55), 0.0, true)
	shadow.modulate.a = 0.0
	shadow.create_tween().tween_property(shadow, "modulate:a", 1.0, 0.3)
	b.announce("ENGO-JI BEAM: COLAPSO", Shumi.KAIOKEN_COLOR, 28)
	v.play("kaioken")
	var chest := center(s)
	CombatEffects.charge(b.world, chest, [Color.WHITE, WAVE_COLOR, Shumi.KAIOKEN_COLOR], 1.1, 170.0)
	for i in 4:
		if is_instance_valid(_aura):
			_aura.pulsar()
		b.shake(1.5 + i)
		await b.wait(0.26)

	CombatEffects.veil(b.world, Color(1, 0.95, 1, 0.8), 0.35)
	b.shake(14.0)
	await _fire(targets, BEAMS[4], 0.3)
	b.shake(10.0)
	CombatEffects.fade_veil(shadow, 0.4)

	if s.is_alive():
		v.play("hurt", 0.6)
		v.flash(Color(0.55, 0.5, 0.65))
		b.log_line("%s ofega depois de liberar tanta energia." % UIStyle.fighter_name(s))
		await b.wait(0.45)


# ----------------------------------------------------------------- Bang!
func _bang() -> void:
	var target := b.current_target()
	b.log_line("%s: %s" % [UIStyle.fighter_name(s), UIStyle.highlight("Bang!", Shumi.KAIOKEN_COLOR)])
	await _finger_beam(target, s.mult_finger_beam())
	s.apply_status(Shumi.bang_status())
	CombatEffects.ring(b.world, center(s), Shumi.KAIOKEN_COLOR, 44.0)
	b.log_line("%s aponta o dedo: vai atacar junto com a equipe." % UIStyle.fighter_name(s))
	s.gain_energy(Shumi.SKILL_ENERGY)
	b.refresh()
	await b.wait(0.25)


func follow_up(target: Combatant, strike: Dictionary) -> void:
	b.log_line("%s ataca junto: %s!" % [UIStyle.fighter_name(s), UIStyle.highlight(strike.name, Shumi.KAIOKEN_COLOR)])
	await _finger_beam(target, strike.mult, true)
	CombatEffects.number(b.world, v.top() + Vector2(0, 24), "+%d EN" % roundi(Shumi.FOLLOW_UP_ENERGY), "energy")


## Tiro de ki do dedo: uma bolinha de energia, como os disparos do Andri,
## maior a cada nível do Kaioken. O ataque junto é golpe adicional (`extra`).
func _finger_beam(target: Combatant, mult: float, extra := false) -> void:
	var n := s.level + 1
	v.swap_frames(_frames_kokoro)
	v.flash(Color(2.2, 1.6, 1.6))
	v.play("engo_ji_beam", 2.0)
	await b.wait(0.12)
	var origin := v.position + Vector2(36, -45)
	var c := center(target)
	var size := 0.8 + 0.15 * n
	CombatEffects.ring(b.world, origin, Shumi.KAIOKEN_COLOR if n > 0 else WAVE_COLOR, 14.0)
	await b.wait(CombatEffects.projectile(b.world, origin, c, s.type, 1200.0, size))
	CombatEffects.elemental_impact(b.world, c, s.type, size)
	await b.apply_damage(s, target, mult, s.type, extra)
	await b.wait(0.15)
	v.swap_frames(_frames_normal)


# --------------------------------------------------------------- Kaioken
func _kaioken() -> void:
	s.use_ult()
	var intensity := s.level + 1
	v.set_idle_anim("kaioken")
	v.play("kaioken")
	v.set_base_color(Color(1.0 + 0.05 * intensity, 1.0, 1.0 - 0.02 * intensity))
	v.flash(Color(3.0, 1.6, 1.4))
	if not is_instance_valid(_aura):
		_aura = CombatEffects.aura(v, AURA_COLORS)
	_aura.level = s.level
	_aura.label = "KAIOKEN " + s.level_name()
	_aura.pulsar()
	var c := center(s)
	CombatEffects.ring(b.world, c, Shumi.KAIOKEN_COLOR, 60.0 + 12.0 * intensity)
	CombatEffects.impact(b.world, c, AURA_COLORS[2], 1.0 + 0.4 * intensity)
	b.get_tree().create_timer(0.12).timeout.connect(func() -> void:
		CombatEffects.ring(b.world, c, Color(1, 0.7, 0.5), 40.0 + 10.0 * intensity))
	if s.at_max_level():
		CombatEffects.veil(b.world, Color(1, 0.3, 0.25, 0.3), 0.4)
		b.get_tree().create_timer(0.24).timeout.connect(func() -> void:
			CombatEffects.ring(b.world, c, WHITE_COLOR, 140.0))
	b.announce("KAIOKEN %s!" % s.level_name(), Shumi.KAIOKEN_COLOR)
	var n: Dictionary = Shumi.LEVELS[s.level]
	b.log_line("%s ativado! ATQ +%d%%, VEL +%d%%, perde %d%% do HP por turno." % [
		UIStyle.highlight("Kaioken " + s.level_name(), Shumi.KAIOKEN_COLOR),
		roundi(n.atk * 100), roundi(n.spd * 100), roundi(n.drain * 100)])
	b.shake(4.0 + 3.0 * intensity)
	b.refresh()
	await b.wait(0.9)


func _remove_aura() -> void:
	if is_instance_valid(_aura):
		var t := _aura.create_tween()
		t.tween_property(_aura, "modulate:a", 0.0, 0.3)
		t.tween_callback(_aura.queue_free)
	_aura = null

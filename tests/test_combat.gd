extends SceneTree
## Testes da lógica de combate, sem interface.
## Rodar: godot --headless --path . -s tests/test_combat.gd

var _failures := 0


func _init() -> void:
	# a equipe é salva no progresso: os testes usam um arquivo só deles
	Progression.file = "user://teste_combate_progresso.cfg"
	# a história (quem chega depois) é testada com a chave temporária de
	# todos liberados desligada
	Roster.all_unlocked = false
	Progression.delete()
	_test_queue()
	_test_speed_rescales_av()
	_test_kaioken_enter_and_level_up()
	_test_kaioken_end_and_exhaustion()
	_test_kaioken_x20()
	_test_kaioken_energy()
	_test_engo_ji()
	_test_damage()
	_test_types()
	_test_status_effects()
	_test_components()
	_test_andri_lens_and_shot()
	_test_andri_analysis()
	_test_andri_arsenal()
	_test_interface_description()
	_test_team()
	_test_askara_fragments()
	_test_askara_summon()
	_test_askara_lord()
	_test_summon_targets_and_taunt()
	_test_cooldown()
	_test_shumi_bang()
	_test_andri_protocol()
	_test_askara_last_act()
	_test_last_resort()
	_test_clairin_frenzy()


## Os testes com a batalha de verdade precisam da árvore de cenas.
func _initialize() -> void:
	await _test_askara_in_battle()
	await _test_bang_in_battle()
	await _test_black_iron_in_battle()
	await _test_battle_phases()
	await _test_clairin_in_battle()
	Progression.delete()
	print("\n%s (%d falha%s)" % ["TUDO OK" if _failures == 0 else "FALHOU", _failures, "" if _failures == 1 else "s"])
	quit(1 if _failures else 0)


## A habilidade `action` do kit de `c` (pela ação, não pela posição na barra).
func _skill_data(c: Combatant, action: String, points := 1) -> Dictionary:
	return _skill_at(c.skills(points), action)


func _skill_at(kit: Array[Dictionary], action: String) -> Dictionary:
	for h in kit:
		if h.action == action:
			return h
	return {}


func check(condition: bool, description: String) -> void:
	if condition:
		print("  ok   ", description)
	else:
		_failures += 1
		printerr("  FALHOU ", description)


func _test_queue() -> void:
	print("fila de turnos")
	var slow := Combatant.new("Lento", true, 100, 10, 0, 100)
	var fast := Combatant.new("Rápido", false, 100, 10, 0, 250)
	var all: Array = [slow, fast]
	var order := TurnQueue.forecast(all, 4)
	check(Array(order) == [fast, fast, slow, fast], "VEL 250 age 2x antes do VEL 100")
	var actor := TurnQueue.next(all)
	check(actor == fast, "o mais rápido age primeiro")
	TurnQueue.advance_to(all, actor)
	check(is_equal_approx(slow.av, 60.0), "tempo passado é descontado dos outros (100 - 40 = 60)")
	slow.hp = 0
	check(TurnQueue.forecast(all, 3).count(slow) == 0, "derrotados saem da fila")


func _test_speed_rescales_av() -> void:
	print("mudança de velocidade")
	var c := Combatant.new("C", true, 100, 10, 0, 100)
	c.av = 50.0
	var before := c.spd()
	c._bonus_extra["spd"] = 1.0
	c.adjust_av(before)
	check(is_equal_approx(c.av, 25.0), "dobrar a VEL no meio do caminho corta o que falta pela metade")


func _test_kaioken_enter_and_level_up() -> void:
	print("kaioken: entrar e subir")
	var s := Shumi.new()
	check(not s.can_use_ult(), "começa sem energia suficiente (60/120)")
	s.energy = 120
	check(s.can_use_ult(), "com 120 de energia pode entrar")
	s.use_ult()
	check(s.level_name() == "x2" and s.energy == 0.0, "entra no x2 e gasta 120")
	check(is_equal_approx(s.atk(), 180.0), "x2 dá +20% ATQ (150 -> 180)")
	check(is_equal_approx(s.spd(), 126.0), "x2 dá +20% VEL (105 -> 126)")
	s.energy = 80
	check(s.can_use_ult() and s.ult_cost() == 80.0, "subir de nível custa 80")
	s.kaioken_turns = 1
	s.use_ult()
	check(s.level_name() == "x4" and s.kaioken_turns == Shumi.DURATION, "sobe para x4 e renova a duração")
	check(is_equal_approx(s.bonus("atk"), 0.40), "subir troca o bônus em vez de somar (x4 = +40%, não +60%)")
	var r := s.turn_start_overload()
	check(r.damage == 60 and s.hp == 1140, "x4 queima 5% do HP (60)")
	check(s.turn_start_overload().damage == 0 and s.hp == 1140, "a sobrecarga roda uma vez só por turno")
	s.end_turn()
	check(s.turn_start_overload().damage == 60, "no turno seguinte queima de novo")


func _test_kaioken_end_and_exhaustion() -> void:
	print("kaioken: fim e exaustão")
	var s := Shumi.new()
	s.energy = 120
	s.use_ult()
	s.energy = 80
	s.use_ult()
	check(s.end_turn() == "" and s.end_turn() == "", "dura 3 turnos")
	check(s.end_turn() == "x4", "no 3º turno acaba e avisa o nível")
	check(not s.in_kaioken(), "saiu da forma")
	check(is_equal_approx(s.spd(), 84.0), "exaustão do x4: VEL -20% (105 -> 84)")
	check(not s.loses_next_turn, "fora do x20 não perde turno")
	s.end_turn()
	check(is_equal_approx(s.spd(), 84.0), "exaustão continua no 1º turno seguinte")
	s.end_turn()
	check(is_equal_approx(s.spd(), 105.0), "exaustão acaba depois de 2 turnos")


func _test_kaioken_x20() -> void:
	print("kaioken: x20")
	var s := Shumi.new()
	for i in 4:
		s.energy = 120
		s.use_ult()
	check(s.level_name() == "x20" and s.at_max_level(), "4 ults chegam no x20")
	check(not s.can_use_ult(), "não sobe além do x20")
	check(is_equal_approx(s.atk(), 375.0), "x20 dá +150% ATQ (150 -> 375)")
	check(s.turn_start_overload().damage == 144, "x20 queima 12% do HP (144)")
	for i in 3:
		s.end_turn()
	check(s.loses_next_turn, "depois do x20 perde o próximo turno")
	s.hp = 100
	s.energy = 120
	s.use_ult()
	s.level = 3
	s.energy = 0
	var r := s.turn_start_overload()
	check(r.damage == 100 and not s.is_alive(), "o dreno pode matar a Shumi")
	check(r.energy == 0.0 and s.energy == 0.0, "Limite Humano não ativa se ela cai")


func _test_kaioken_energy() -> void:
	print("energia e Limite Humano")
	var s := Shumi.new()
	s.energy = 0
	check(s.turn_start_overload() == {"damage": 0, "energy": 0.0}, "fora do Kaioken: sem dreno e sem passiva")
	s.energy = 120
	s.use_ult()
	var r := s.turn_start_overload()
	check(r.damage == 36 and r.energy == 15.0 and s.energy == 15.0, "x2: perde 36 de HP e recupera 15 de energia")
	s.end_turn()
	s.energy = 80
	s.use_ult()
	s.energy = 0
	check(s.turn_start_overload().energy == 20.0, "x4 recupera mais (20)")
	s.end_turn()
	check(Shumi.LEVELS.all(func(n: Dictionary) -> bool: return n.limit < Shumi.LEVEL_UP_COST),
		"a passiva nunca paga sozinha a subida de nível")
	s.energy = 110
	check(s.turn_start_overload().energy == 10.0 and s.energy == 120.0, "a passiva respeita o máximo de energia")


func _test_engo_ji() -> void:
	print("engo-ji")
	var s := Shumi.new()
	var a := Enemy.new("A", "", 100, 1, 0, 100)
	var b := Enemy.new("B", "", 100, 1, 0, 100)
	var c := Enemy.new("C", "", 100, 1, 0, 100)
	var list := [a, b, c]
	check(s.engo_ji_targets(list, 1) == [[b, 1.8]], "normal: só o alvo")
	s.level = 0
	check(s.engo_ji_targets(list, 1) == [[b, 1.8], [c, 0.9]], "x2: alvo + o de trás, com dano menor")
	check(s.engo_ji_targets(list, 2) == [[b, 0.9], [c, 1.8]], "x2 no último: o segundo é o da frente")
	check(s.engo_ji_targets([a], 0) == [[a, 1.8]], "x2 com um inimigo só: só ele")
	s.level = 1
	check(s.engo_ji_targets(list, 0) == [[a, 1.8], [b, 0.9]], "x4 na ponta: alvo + 1 vizinho")
	check(s.engo_ji_targets(list, 1) == [[a, 0.9], [b, 1.8], [c, 0.9]], "x4 no meio: até 3 alinhados")
	s.level = 2
	check(s.engo_ji_targets(list, 0) == [[a, 1.8], [b, 1.8], [c, 1.8]], "x10 atravessa todos com dano cheio")
	s.level = 3
	check(s.engo_ji_targets(list, 0) == [[a, 2.2], [b, 2.2], [c, 2.2]], "x20 (Colapso) acerta todos com dano massivo")
	check(s.predicted_targets("skill", list, 0) == [a, b, c] and s.predicted_targets("basic", list, 0).is_empty(),
		"a prévia de alvos usa a mesma regra do Engo-ji")


func _test_damage() -> void:
	print("dano")
	var s := Shumi.new()
	var sentinel := Enemy.new("Sentinela", "", 550, 60, 40, 95)
	check(Combatant.calculate_damage(s, sentinel, 1.0) == 107, "corte na Sentinela: 150 * 100/140 = 107")
	check(Combatant.calculate_damage(sentinel, s, 1.0) == 40, "Sentinela na Shumi: 60 * 100/150 = 40")


func _test_types() -> void:
	print("tipos de dano")
	var e := Types.effectiveness
	var pairs := [
		[Types.PHYSICAL, Types.ARCANE, Types.SUPER], [Types.PHYSICAL, Types.NATURE, Types.NOT_VERY],
		[Types.FIRE, Types.ICE, Types.SUPER], [Types.FIRE, Types.WATER, Types.NOT_VERY],
		[Types.WATER, Types.FIRE, Types.SUPER], [Types.WATER, Types.ELECTRICITY, Types.NOT_VERY],
		[Types.ICE, Types.NATURE, Types.SUPER], [Types.ICE, Types.FIRE, Types.NOT_VERY],
		[Types.ELECTRICITY, Types.WATER, Types.SUPER], [Types.ELECTRICITY, Types.NATURE, Types.NOT_VERY],
		[Types.NATURE, Types.ELECTRICITY, Types.SUPER], [Types.NATURE, Types.FIRE, Types.NOT_VERY],
		[Types.POISON, Types.NATURE, Types.SUPER], [Types.POISON, Types.ACID, Types.NOT_VERY],
		[Types.ACID, Types.PHYSICAL, Types.SUPER], [Types.ACID, Types.WATER, Types.NOT_VERY],
		[Types.LIGHT, Types.DARKNESS, Types.SUPER], [Types.DARKNESS, Types.LIGHT, Types.SUPER],
	]
	var errors := pairs.filter(func(p: Array) -> bool: return e.call(p[0], p[1]) != p[2])
	check(errors.is_empty(), "tabela de efetividade (%d relações) %s" % [pairs.size(), errors])
	check(e.call(Types.PHYSICAL, Types.PHYSICAL) == 1.0 and e.call(Types.FIRE, Types.LIGHT) == 1.0, "sem relação definida: x1")
	var arcane_ok := Types.ALL.all(func(t: String) -> bool:
		return e.call(Types.ARCANE, t) == (Types.NOT_VERY if t == Types.PHYSICAL else Types.SUPER))
	check(arcane_ok, "Arcano: x2 contra todos, menos Físico (x0,5)")
	check(Types.ALL.all(func(t: String) -> bool: return e.call(t, Types.ARCANE) == Types.SUPER),
		"alvo Arcano recebe x2 de todos os tipos, inclusive Arcano (sem acumular)")
	check(e.call(Types.NATURE, Types.PHYSICAL) == 1.0 and e.call(Types.FIRE, Types.POISON) == 1.0,
		"Arcano atacando não deixa ninguém vulnerável a outros tipos")

	var s := Shumi.new()
	check(s.type == Types.PHYSICAL, "a Shumi é do tipo Físico")
	check(s.skills(1).filter(func(h: Dictionary) -> bool: return h.action in ["basic", "skill"]).all(
		func(h: Dictionary) -> bool: return h.type == Types.PHYSICAL), "Corte e Engo-ji causam dano Físico")
	check(not _skill_data(s, "ult", 1).has("type"), "o Kaioken (sem dano) não tem tipo")
	var neutral := Enemy.new("N", "", 550, 60, 40, 95)
	var arcane := Enemy.new("A", "", 550, 60, 40, 95, 0, Types.ARCANE)
	var plant := Enemy.new("P", "", 550, 60, 40, 95, 0, Types.NATURE)
	# dano base da Shumi numa Sentinela: 150 * 100/140
	var base := 150.0 * 100.0 / 140.0
	check(Combatant.calculate_damage(s, neutral, 1.0) == roundi(base), "Físico em Físico: dano normal")
	check(Combatant.calculate_damage(s, arcane, 1.0) == roundi(base * Types.SUPER), "Físico em Arcano: forte")
	check(Combatant.calculate_damage(s, plant, 1.0) == roundi(base * Types.NOT_VERY), "Físico em Natureza: fraco")
	check(Combatant.calculate_damage(s, neutral, 1.0, 0.5, Types.ACID) == roundi(base * Types.SUPER), "o ataque pode ter outro tipo que o do atacante")
	check(Combatant.calculate_damage(arcane, s, 1.0) == roundi(60.0 * Types.NOT_VERY * 100.0 / 150.0), "Arcano na Shumi (Físico): fraco")
	check(neutral.next_strike().type == neutral.type, "golpe do inimigo usa o tipo dele")


func _test_status_effects() -> void:
	print("estados (buffs, debuffs, escudo)")
	var c := Combatant.new("C", true, 1000, 100, 0, 100)
	var e := StatusEffect.new("test", "Teste", "T", "buff", 2)
	e.mods = {"atk": 0.3}
	c.apply_status(e)
	var equal := StatusEffect.new("test", "Teste", "T", "buff", 2)
	equal.mods = {"atk": 0.3}
	c.apply_status(equal)
	check(c.status_effects.size() == 1 and is_equal_approx(c.atk(), 130.0), "o mesmo estado renova em vez de acumular (ATQ +30%, não +60%)")
	check(c.pass_turn().is_empty() and c.pass_turn().size() == 1 and c.status_effects.is_empty(), "dura 2 turnos do portador e some")
	check(is_equal_approx(c.atk(), 100.0), "o bônus sai junto")
	var esc := StatusEffect.new("shield", "Escudo", "E", "buff", 3)
	esc.shield = 100
	c.apply_status(esc)
	check(c.absorb(60) == 60 and c.shield() == 40, "o escudo absorve o golpe primeiro")
	check(c.absorb(70) == 40 and c.status("shield") == null, "o escudo quebra e o resto passa")
	var target := Combatant.new("A", false, 1000, 100, 0, 100)
	check(Combatant.calculate_damage(c, target, 1.0, 0.5, "", true) == 150, "crítico causa x1,5")


func _test_components() -> void:
	print("componentes (Health, StatusEffects, Cooldowns, FighterBar)")
	var c := Combatant.new("C", true, 1000, 100, 0, 100)
	var seen: Array = []
	c.health.changed.connect(func(current: int, maximum: int) -> void: seen.append([current, maximum]))
	var depleted := [0]
	c.health.depleted.connect(func() -> void: depleted[0] += 1)
	check(c.take_damage(300) == 300 and c.hp == 700 and seen.back() == [700, 1000], "dano passa pelo Health e avisa a mudança")
	check(c.heal(500) == 300 and c.hp == 1000, "cura não passa do máximo")
	var life := StatusEffect.new("life", "Vida", "V", "buff", 1)
	life.extra_life = 200
	c.apply_status(life)
	check(c.max_hp == 1200 and c.hp == 1200 and c.statuses.extra_life() == 200, "vida extra sobe o máximo pelo componente")
	c.pass_turn()
	check(c.max_hp == 1000 and c.hp == 1000, "ao sair, o máximo baixa e puxa o HP junto")
	check(c.take_damage(5000) == 1000 and not c.is_alive() and depleted[0] == 1, "zerar o HP avisa uma vez (depleted)")
	c.take_damage(10)
	check(depleted[0] == 1, "dano em quem já caiu não avisa de novo")

	var list := StatusEffects.new()
	var weak := StatusEffect.new("w", "Fraqueza", "F", "debuff", 2)
	weak.weakness = Types.ICE
	weak.taunt = 1.0
	weak.damage_reduction = 0.6
	var guard := StatusEffect.new("g", "Guarda", "G", "buff", 1)
	guard.damage_reduction = 0.6
	list.add(weak)
	list.add(guard)
	check(list.weak_to(Types.ICE) and not list.weak_to(Types.FIRE) and list.taunt() == 1.0, "StatusEffects soma fraqueza e provocação")
	check(is_equal_approx(list.damage_reduction(), 0.9) and list.ids_of_type("debuff") == ["w"], "a redução para em 90%")
	check(list.tick() == [guard] and list.find("g") == guard and list.take_out("g") == guard and list.find("g") == null,
		"tick devolve quem acabou, e quem tira é o dono")

	var cd := Cooldowns.new()
	cd.start("skill2", 2)
	cd.start("ult", 0)
	check(cd.remaining("skill2") == 2 and cd.remaining("ult") == 0, "Cooldowns guarda só recargas de verdade")
	cd.tick()
	cd.tick()
	check(cd.remaining("skill2") == 0, "a recarga acaba com os turnos do dono")

	var enemy := Enemy.new("E", "res://enemies/sentinel.png", 1000, 50.0, 10.0, 100.0)
	var bar := FighterBar.new(enemy)
	enemy.take_damage(400)
	bar._process(10.0)
	check(is_equal_approx(bar._shown_hp, 600.0) and is_equal_approx(bar._trail_hp, 600.0), "a barra desce até o HP")
	enemy.heal(300)
	check(is_equal_approx(bar._trail_hp, 900.0), "uma cura puxa o rastro na hora, pelo sinal do Health")
	bar.free()


func _test_andri_lens_and_shot() -> void:
	print("andri: lente elemental e disparo")
	var a := Andri.new()
	check(a.type == Types.FIRE and a.lens == Types.FIRE, "Andri é Fogo e começa com a lente em Fogo")
	check(a.switch_lens(Types.WATER) and a.lens == Types.WATER, "troca a lente para Água")
	check(not a.switch_lens(Types.WATER) and not a.switch_lens(Types.ARCANE) and not a.switch_lens(Types.PHYSICAL),
		"não troca para o mesmo elemento nem para Arcano/Físico")
	check(a.invalid_reason("lens", Types.WATER, a) == "", "manter a lente atual é uma escolha válida")
	var kit := a.skills(1)
	check(kit[0].type == Types.WATER and kit[0].badge == "ÁGU", "o Disparo usa e mostra o elemento da lente")
	check(_skill_at(kit, "lens").action == "lens" and _skill_at(kit, "lens").free and _skill_at(kit, "lens").options.size() == Andri.LENSES.size(), "escolher a lente não gasta o turno e tem os 7 elementos")
	check(_skill_at(kit, "lens").passive and _skill_at(kit, "lens").key == "" and _skill_at(kit, "lens").on_turn_start and _skill_at(kit, "lens").default_option == Types.WATER,
		"a lente é passiva: fora da barra, abre sozinha no começo do turno e já sugere a atual")
	check(_skill_at(kit, "lens").selector == "radial" and _skill_at(kit, "lens").options.filter(func(o: Dictionary) -> bool: return o.current).size() == 1
		and _skill_at(kit, "lens").options[1].abbr == "ÁGU", "a lente abre em anel no personagem, com siglas e a atual marcada")
	check(a.effects()[0].id == "lens" and a.effects()[0].name == "Lente: Água", "a lente aparece nos efeitos")

	var strikes := a.shot_strikes()
	check(strikes.size() == 2 and strikes[0].source == "andri" and strikes[1].source == "momc", "cada Disparo tem o golpe do Andri e o do MOMC")
	check(strikes.all(func(g: Dictionary) -> bool: return g.type == Types.WATER), "os dois usam o elemento da lente")
	check(not strikes[0].extra and strikes[1].extra, "o golpe do MOMC é adicional: não dispara outros golpes nem efeitos de acerto")
	var fire := Enemy.new("F", "", 550, 60, 40, 95, 0, Types.FIRE)
	var base := 130.0 * 100.0 / 140.0
	check(Combatant.calculate_damage(a, fire, strikes[0].mult, 0.5, strikes[0].type) == roundi(base * Andri.SHOT_MULT * Types.SUPER),
		"Disparo de Água num inimigo de Fogo é super efetivo")
	check(Combatant.calculate_damage(a, fire, strikes[1].mult, 0.5, strikes[1].type) == roundi(base * Andri.MOMC_MULT * Types.SUPER),
		"o MOMC calcula o dano dele à parte, com a mesma tabela")
	# Thorim no Andri: o golpe dele ganha o extra elétrico; o do MOMC (extra) não pede extras
	a.apply_status(Andri.artifact_status("thorim", a, a.lens))
	var extras := a.extra_strikes(strikes[0].mult)
	check(extras.size() == 1 and extras[0].type == Types.WATER and is_equal_approx(extras[0].mult, Andri.SHOT_MULT * Andri.THORIM_MULT),
		"Braço de Thorim: +30% do golpe no elemento da lente (Água)")
	check(a.extra_strikes(strikes[0].mult).size() == 1, "o extra do Thorim não se consome")


func _test_andri_analysis() -> void:
	print("andri: análise de vulnerabilidade")
	var a := Andri.new()
	var stone := Enemy.new("Pedra", "", 550, 60, 40, 95)
	var water := Enemy.new("Água", "", 550, 60, 40, 95, 0, Types.WATER)
	var arcane := Enemy.new("Arc", "", 550, 60, 40, 95, 0, Types.ARCANE)
	check(a.invalid_reason("skill", Types.FIRE, stone) == "", "pode expor Fogo num inimigo Físico")
	check(a.invalid_reason("skill", Types.ACID, stone) != "", "não aplica fraqueza a um elemento que já é super efetivo (Ácido em Físico)")
	check(a.invalid_reason("skill", Types.FIRE, arcane) != "", "não aplica em Arcano, que já recebe x2 de tudo")
	check(a.invalid_reason("skill", Types.FIRE, a) != "", "não aplica em aliado")
	check(a.analysis_elements() == [Types.FIRE], "sem equipe, só o elemento do próprio Andri")
	var s := Shumi.new()
	var shadow := Combatant.new("Sombra", true, 1000, 100, 0, 100, Types.DARKNESS)
	var other_fire := Combatant.new("Chama", true, 1000, 100, 0, 100, Types.FIRE)
	var time: Array[Combatant] = [s, a, shadow, other_fire]
	a.living_allies = func() -> Array: return time.filter(func(c: Combatant) -> bool: return c.is_alive())
	check(a.analysis_elements() == [Types.PHYSICAL, Types.FIRE, Types.DARKNESS], "com Shumi e um aliado de Trevas: Físico, Fogo e Trevas, sem repetir")
	check(_skill_data(a, "skill", 1).options.map(func(o: Dictionary) -> String: return o.id) == [Types.PHYSICAL, Types.FIRE, Types.DARKNESS],
		"o seletor da Análise mostra só esses elementos")
	check(a.invalid_reason("skill", Types.ICE, stone) != "", "não aplica elemento que ninguém da equipe tem")
	check(a.invalid_reason("skill", Types.DARKNESS, stone) == "", "aplica o elemento de um aliado (Trevas)")
	shadow.hp = 0
	check(Types.DARKNESS not in a.analysis_elements(), "aliado caído não conta")
	for c in time:
		c.hp = 0
	check(a.analysis_elements() == [Types.FIRE], "com a equipe toda caída, a lista nunca fica vazia")
	for c in time:
		c.hp = c.max_hp

	var before := Combatant.calculate_damage(a, stone, 1.0, 0.5, Types.FIRE)
	stone.apply_status(Andri.weakness(Types.FIRE))
	check(stone.effectiveness_against(Types.FIRE) == Types.SUPER, "com a fraqueza, Fogo passa a ser super efetivo")
	check(Combatant.calculate_damage(a, stone, 1.0, 0.5, Types.FIRE) == roundi(before * Types.SUPER), "e o dano usa o multiplicador da tabela")
	check(stone.effectiveness_against(Types.WATER) == 1.0, "outros elementos não mudam")
	water.apply_status(Andri.weakness(Types.FIRE))
	check(water.effectiveness_against(Types.FIRE) == Types.SUPER, "a fraqueza vence uma resistência (Fogo em Água: x0,5 -> x2)")
	stone.apply_status(Andri.weakness(Types.ICE))
	check(stone.status_effects.size() == 1 and stone.effectiveness_against(Types.ICE) == Types.SUPER and stone.effectiveness_against(Types.FIRE) == 1.0,
		"uma fraqueza por vez: a nova substitui a antiga e renova a duração")
	check(stone.effects()[0].type == "debuff" and stone.effects()[0].turns == Andri.WEAKNESS_DURATION and stone.effects()[0].short == "GEL",
		"aparece como debuff com elemento e turnos")
	stone.pass_turn()
	check(stone.effectiveness_against(Types.ICE) == Types.SUPER, "ainda ativa depois de 1 turno do inimigo")
	stone.pass_turn()
	check(stone.status_effects.is_empty() and stone.effectiveness_against(Types.ICE) == 1.0, "expira depois de %d turnos do inimigo" % Andri.WEAKNESS_DURATION)
	var kit := a.skills(1)
	check(_skill_at(kit, "skill").point_cost == 1 and _skill_at(kit, "skill").default_option == Types.PHYSICAL, "a Análise custa 1 ponto e começa no primeiro elemento da equipe")
	a.living_allies = Callable()  # a lambda guarda o time, que contém o próprio Andri


func _test_andri_arsenal() -> void:
	print("andri: arsenal titânico")
	var a := Andri.new()
	var s := Shumi.new()
	var foe := Enemy.new("I", "", 550, 60, 40, 95)
	var kit := a.skills(1)
	check(_skill_at(kit, "ult").target == "ally" and _skill_at(kit, "ult").options.size() == Andri.ARTIFACTS.size() and _skill_at(kit, "ult").options.size() == 8, "a ult mira aliados e oferece os 8 artefatos")
	check(_skill_at(kit, "ult").options.all(func(o: Dictionary) -> bool: return o.has("icon") and o.description != ""), "cada artefato tem ícone e descrição")
	check(not a.can_use("ult", 1), "começa sem energia para a ult (60/120)")
	a.energy = 120
	check(a.can_use("ult", 1), "com 120 de energia pode usar")
	check(a.invalid_reason("ult", "odyn", foe) != "", "artefatos não vão para inimigos")
	check(a.invalid_reason("ult", "freya", s) != "", "Raiz de Freya recusa alvo com HP cheio e sem efeitos negativos")
	check(a.invalid_reason("ult", "nothing", s) != "", "artefato desconhecido é recusado")

	a.use_artifact("odyn", s)
	check(a.energy == 0.0 and is_equal_approx(s.crit_chance(), Andri.ODYN_CRIT), "Olho de Odyn: gasta a energia e dá +50% de crítico")
	for i in Andri.ARTIFACT_DURATION:
		s.pass_turn()
	check(s.crit_chance() == 0.0, "e expira depois de %d turnos do portador" % Andri.ARTIFACT_DURATION)

	a.use_artifact("tyr", s)
	check(s.shield() == roundi(s.max_hp * Andri.TYR_SHIELD), "Mão de Tyr: escudo de 25% do HP máximo")
	s.energy = 120
	s.use_ult()
	s.turn_start_overload()
	check(s.hp == s.max_hp - 36 and s.shield() == 300, "o dreno do Kaioken ignora o escudo (é custo, não golpe)")

	var cold := Combatant.new("Frio", true, 1000, 100, 0, 100)
	a.use_artifact("hodir", cold)
	var slow_enemy := Enemy.new("L", "", 550, 60, 40, 100)
	var av_before_slow := slow_enemy.av
	var slow := cold.on_hit_statuses()
	check(slow.size() == 1 and slow[0].id == "slow", "Manto de Hodir: o próximo golpe do portador aplica Lento")
	slow_enemy.apply_status(slow[0])
	check(is_equal_approx(slow_enemy.spd(), 100.0 * (1.0 + Andri.SLOW_SPD)) and slow_enemy.av > av_before_slow,
		"Lento: VEL -30%, e a vez do inimigo demora mais")
	check(cold.status_effects.is_empty() and cold.on_hit_statuses().is_empty(), "o Manto se consome nesse golpe")
	for i in Andri.SLOW_DURATION:
		slow_enemy.pass_turn()
	check(is_equal_approx(slow_enemy.spd(), 100.0), "Lento expira depois de %d turnos do inimigo" % Andri.SLOW_DURATION)

	var victim := Enemy.new("V", "", 550, 60, 40, 100)
	var bearer := Combatant.new("P", true, 1000, 100, 0, 100)
	a.use_artifact("loken", bearer)
	var applied := bearer.on_hit_statuses()
	check(applied.size() == 1 and applied[0].id == "deceived", "Sussurro de Loken: os golpes do portador aplicam Enganado")
	var av_before := victim.av
	victim.apply_status(applied[0])
	check(is_equal_approx(victim.atk(), 60.0 * (1.0 + Andri.DECEIVED_ATK)) and victim.av > av_before, "Enganado: ATQ -25% e a vez atrasa")
	var av_after := victim.av
	victim.apply_status(bearer.on_hit_statuses()[0])
	check(is_equal_approx(victim.av, av_after), "renovar o Enganado não atrasa de novo")

	var robust := Combatant.new("Rob", true, 1000, 100, 50, 100)
	robust.hp = 800
	a.use_artifact("archaedas", robust)
	check(robust.max_hp == 1300 and robust.hp == 1100, "Cinturão de Archaedas: HP máximo +30% (e o HP atual sobe junto)")
	a.use_artifact("archaedas", robust)
	check(robust.max_hp == 1300 and robust.hp == 1100, "renovar o Cinturão não acumula")
	robust.take_damage(50)
	for i in Andri.ARTIFACT_DURATION:
		robust.pass_turn()
	check(robust.max_hp == 1000 and robust.hp == 1000, "ao acabar, o HP máximo volta e o excedente é cortado")

	var r_bearer := Combatant.new("R", true, 1000, 100, 0, 100)
	a.switch_lens(Types.ICE)
	a.use_artifact("ra", r_bearer)
	a.switch_lens(Types.FIRE)
	var ra := r_bearer.extra_strikes(1.0)
	check(ra.size() == 1 and ra[0].type == Types.ICE and ra[0].mult == Andri.RA_MULT,
		"Lança de Rá: o próximo golpe ganha dano do elemento da lente na hora da entrega (Gelo)")
	check(_skill_data(a, "ult", 1).options[7].description.contains("Fogo"), "a descrição dos artefatos de dano mostra o elemento atual da lente")
	check(r_bearer.extra_strikes(1.0).is_empty() and r_bearer.status_effects.is_empty(), "a Lança se consome no primeiro golpe")

	var wounded := Shumi.new()
	wounded.hp = 500
	wounded.apply_status(Andri.weakness(Types.FIRE))
	wounded.exhaustion_turns = 2
	check(a.invalid_reason("ult", "freya", wounded) == "", "Raiz de Freya aceita aliado ferido")
	var r := a.use_artifact("freya", wounded)
	check(r.heal == 360 and wounded.hp == 860, "Raiz de Freya: cura 30% do HP máximo")
	check(r.cleared == 1 and wounded.status_effects.is_empty(), "e remove os debuffs")
	check(wounded.exhaustion_turns == 2, "a exaustão do Kaioken é custo do kit, não debuff: continua")
	var full := Shumi.new()
	check(a.use_artifact("freya", full).heal == 0, "a cura não passa do HP máximo")


func _test_interface_description() -> void:
	print("descrição para a interface")
	var s := Shumi.new()
	var status_effects := func(points: int) -> Array:
		return s.skills(points).map(func(h: Dictionary) -> String: return h.state)
	check(s.skills(0).map(func(h: Dictionary) -> String: return h.key) == ["Q", "E", "W", "R", ""], "barra na ordem básico, skill, skill 2, ult e a passiva por último")
	check(status_effects.call(0) == ["ready", "no_resource", "no_resource", "no_resource", "ready"], "sem pontos e sem energia: só o Corte (e a passiva)")
	check(not s.can_use("skill", 0) and s.can_use("skill", 1), "Engo-ji precisa de 1 ponto")
	s.energy = 120
	check(status_effects.call(1) == ["ready", "ready", "ready", "ready", "ready"], "com ponto e energia: tudo pronto")
	check(_skill_data(s, "ult", 1).energy_cost == 120 and _skill_data(s, "ult", 1).badge == "x2", "Kaioken mostra custo 120 e próximo nível x2")
	check(s.effects().is_empty(), "sem efeitos fora do Kaioken")
	s.use_ult()
	check(s.effects()[0].id == "kaioken" and s.effects()[0].turns == Shumi.DURATION, "Kaioken aparece como efeito com os turnos")
	check(_skill_data(s, "ult", 1).energy_cost == 80, "subir de nível custa 80")
	s.level = 2
	check(_skill_data(s, "skill", 1).target == "all" and _skill_data(s, "skill", 1).name == "Engo-ji Beam: Devastação", "Engo-ji no x10 vira Devastação e atravessa todos")
	s.level = 3
	s.energy = 120
	check(_skill_data(s, "ult", 1).state == "blocked" and not s.can_use("ult", 1), "no x20 o Kaioken fica bloqueado")
	s.kaioken_turns = 1
	s.end_turn()
	var ids: Array = s.effects().map(func(e: Dictionary) -> String: return e.id)
	check(ids == ["exhaustion", "loses_turn"], "depois do x20: exausta e perde o turno")
	var g := Enemy.new("G", "", 100, 1, 0, 100, 2)
	check(g.effects().is_empty(), "Guardião sem aviso antes da hora")
	g.count_action()
	check(g.effects()[0].type == "alert", "aviso de Golpe Pesado na ação anterior a ele")


func _test_team() -> void:
	print("equipe")
	Roster.set_team([])
	check(Roster.team() == ["shumi"], "sem escolha, a equipe padrão é a Shumi")
	Roster.set_team(["andri"])
	check(Roster.team() == ["shumi"], "quem ainda não chegou à Torre não entra na equipe")
	Progression.unlock("andri")
	Roster.set_team(["shumi", "nobody", "shumi", "andri", "andri"])
	check(Roster.team() == ["shumi", "andri"], "repetidos e desconhecidos saem da equipe")
	Roster.set_team(["nobody"])
	check(Roster.team() == ["shumi"], "ids desconhecidos são ignorados")
	Roster.set_team([])
	for id in Roster.IDS:
		var d := Roster.data(id)
		check(Roster.create(id).ally and d.actions != null and d.sprite.has("png") and d.get("universe", "") != "", "%s cadastrado completo" % id)
		var passives := Roster.create(id).skills(1).filter(func(h: Dictionary) -> bool: return h.get("passive", false))
		check(not passives.is_empty() and passives.all(func(h: Dictionary) -> bool:
				return h.key == "" and h.get("icon", "") != "" and h.description != ""),
			"%s explica as passivas na barra, no mesmo padrão dos outros" % id)
		var kit := Roster.create(id).skills(1)
		check(kit.size() == 5 and kit[0].action == "basic" and kit[1].action == "skill" and kit[3].action == "ult" and kit[4].get("passive", false)
			and (kit[2].action == "skill2" or kit[2].get("passive", false)), "%s segue a ordem: básico, skill, skill 2, ult e passiva" % id)
	var generator: GDScript = load("res://tools/generate_character_readmes.gd")
	for id in Roster.IDS:
		var readme := FileAccess.get_file_as_string(generator.file(id))
		check(readme != "" and readme == generator.with_snippet(readme, generator.leg(id)),
			"README de %s em dia com o kit (rode tools/generate_character_readmes.gd)" % id)
	check(Roster.data("shumi").universe == "Dragon Ball New Age" and Roster.data("andri").universe == "Tales of Azeroth",
		"cada personagem diz de onde vem")
	var a := Combatant.new("A", true, 100, 1, 0, 100)
	var b := Combatant.new("B", true, 100, 1, 0, 100)
	var foe := Enemy.new("I", "", 100, 1, 0, 100)
	check(foe.choose_target([a, b], 0.0) == a and foe.choose_target([a, b], 0.99) == b, "inimigo sorteia entre os aliados")
	a.hp = 0
	check(foe.choose_target([a, b], 0.0) == b, "inimigo não ataca quem já caiu")
	b.hp = 0
	check(foe.choose_target([a, b], 0.5) == null, "sem aliados vivos, sem alvo")
	var s := Shumi.new()
	var free := s.skills(1).filter(func(h: Dictionary) -> bool: return h.get("free", false))
	check(free.size() == 1 and free[0].action == "ult", "só o Kaioken não gasta o turno")
	check(Roster.team() == ["shumi"] and "andri" in Roster.IDS, "Andri está no elenco")


func _test_askara_fragments() -> void:
	print("askara: fragmentos d'alma")
	var a := Askara.new()
	check(a.fragments == Askara.STARTING_FRAGMENTS and a.max_energy == 0.0, "começa com 2 fragmentos e sem energia")
	check(a.gain_fragments(10) == Askara.MAX_FRAGMENTS - 2 and a.fragments == Askara.MAX_FRAGMENTS, "fragmentos param no máximo (8)")
	check(a.on_enemy_fallen() == "", "no máximo, um inimigo caído não dá nada")
	a.fragments = 3
	check(a.on_enemy_fallen() != "" and a.fragments == 4, "inimigo caído dá 1 fragmento")
	var foe := Enemy.new("I", "", 1000, 100, 0, 100)
	var damage := Combatant.calculate_damage(a, foe, Askara.ARROW_MULT, 0.5)
	check(damage == roundi(125 * 0.6), "Seta Vil: 0,6x do ATQ (75)")
	check(a.skills(0).map(func(h: Dictionary) -> String: return h.key) == ["Q", "E", "", "R", ""], "barra na mesma ordem, com o Último Ato (passiva) no lugar da skill 2")
	check(a.skills(0)[0].point_gain == 1, "Seta Vil gera ponto de skill")
	check(a.effects()[0].id == "fragments" and a.effects()[0].short == "4", "fragmentos aparecem nos efeitos")


func _test_askara_summon() -> void:
	print("askara: invocação")
	var a := Askara.new()
	a.apply_level(5, Progression.stats(a.level_1_stats(), Roster.data("askara").growth, 5))
	a.fragments = 0
	check(not a.can_use("skill", 3), "sem fragmentos, sem invocação")
	check(_skill_data(a, "skill", 3).state == "no_resource" and _skill_data(a, "skill", 3).missing_reason.begins_with("Faltam"), "a barra explica o que falta")
	a.fragments = 1
	check(not a.can_use("skill", 0) and a.can_use("skill", 1), "invocar custa 1 ponto de skill")
	check(a.invalid_reason("skill", "shivara", a) != "" and a.invalid_reason("skill", "imp", a) == "", "cada invocação tem seu custo")
	var r := a.summon("imp")
	var day: Summon = r.summon
	check(r.is_new and a.fragments == 0 and a.on_field() == [day], "Diabrete custa 1 e entra em campo")
	check(day.ally and day.summoner == a and day.type == Types.DARKNESS, "invocação é aliada, de Trevas, e sabe quem a chamou")
	check(day.max_hp == roundi(a.max_hp * 0.25) and is_equal_approx(day.base_spd, a.base_spd * 1.25),
		"atributos em fração dos da Askara no nível atual")
	day.hp = 1
	day.turns = 1
	a.fragments = 8
	r = a.summon("imp")
	check(not r.is_new and r.summon == day and day.hp == day.max_hp and day.turns == day.max_turns and a.fragments == 7,
		"invocar a mesma renova HP e vezes (e cobra)")
	var emissary: Summon = a.summon("emissary").summon
	r = a.summon("shivara")
	check(r.replaced == day and not day.on_field and a.on_field() == [emissary, r.summon], "sem vaga, a mais antiga sai")
	check(emissary.target_weight() == 1.0 + Askara.EMISSARY_TAUNT, "Emissário do Caos provoca")
	check(not emissary.consume_turn() and not emissary.consume_turn() and emissary.consume_turn(), "vai embora depois de 3 vezes")
	var lilith: Summon = Askara.new().summon("lilith").summon
	var e: StatusEffect = lilith.debuff.call()
	check(e.type == "debuff" and is_equal_approx(e.mods.atk, -0.2) and is_equal_approx(e.mods.def, -0.2), "Lilith encanta: ATQ e DEF -20%")


func _test_askara_lord() -> void:
	print("askara: lorde demônio")
	var a := Askara.new()
	a.fragments = 5
	check(a.lord_cost() == 6 and not a.can_use("ult", 0), "o Lorde custa 6 fragmentos")
	a.fragments = 8
	a.summon("imp")
	a.summon("emissary")
	check(a.lord_cost() == 4 and _skill_data(a, "ult", 1).badge == "4 FRA", "cada invocação em campo desconta 1")
	a.fragments = 4
	var r := a.summon_lord(0.5)
	var lord: Summon = r.summon
	check(r.dismissed.size() == 2 and a.on_field() == [lord] and a.fragments == 0, "o Lorde apaga as invocações e fica sozinho")
	check(lord.id == "demon_lord" and not r.rare and lord.entrance_strike.reach == "all", "Lorde Demônio, com golpe de chegada em todos")
	a.fragments = 8
	check(not a.can_use("skill", 3) and a.invalid_reason("skill", "imp", a).begins_with("O Lorde"), "com o Lorde em campo, o E fica bloqueado")
	check(_skill_data(a, "skill", 3).state == "blocked" and not a.can_use("ult", 3), "e não dá para chamar outro Lorde")
	lord.on_field = false
	check(a.can_use("skill", 3), "quando ele vai embora, o E volta")
	r = a.summon_lord(0.005)
	var light: Summon = r.summon
	check(r.rare and light.id == "light_lord" and light.type == Types.LIGHT, "sorteio abaixo da chance (15%): vem o Lorde da Luz")
	var foe := Enemy.new("I", "", 1000, 100, 0, 100)
	var common := Combatant.new("C", true, 1000, 1, 0, 100)
	check(Combatant.calculate_damage(foe, light, 1.0) == roundi(Combatant.calculate_damage(foe, common, 1.0) * 0.5 * 100.0 / (100.0 + light.defense())),
		"Lorde da Luz resiste a todo dano (-50%)")


func _test_summon_targets_and_taunt() -> void:
	print("invocação: alvos e provocação")
	var a := Askara.new()
	var inv := Summon.new("x", "X", a, 100, 10, 0, 100, Types.DARKNESS, 3)
	var i1 := Enemy.new("A", "", 100, 10, 0, 100)
	var i2 := Enemy.new("B", "", 100, 50, 0, 100)
	var i3 := Enemy.new("C", "", 100, 20, 0, 100)
	var foe := [i1, i2, i3]
	var targets := inv.targets({"mult": 0.9, "reach": "neighbors", "neighbor_mult": 0.45}, foe, 0)
	check(targets == [[i1, 0.9], [i2, 0.45]], "vizinhos: o marcado e o do lado")
	targets = inv.targets({"mult": 0.3, "aim": "strongest"}, foe, 0)
	check(targets == [[i2, 0.3]], "mira no mais forte (maior ATQ)")
	check(inv.targets({"mult": 1.0, "reach": "all"}, foe, 2).size() == 3, "all")
	var c := Combatant.new("C", true, 100, 1, 0, 100)
	var p := StatusEffect.new("taunt", "P", "P", "buff", -1)
	p.taunt = 2.0
	inv.apply_status(p)
	# pesos 1 + 3: o sorteio abaixo de 1/4 cai no comum, o resto no provocador
	check(i1.choose_target([c, inv], 0.2) == c and i1.choose_target([c, inv], 0.3) == inv, "provocação pesa no sorteio do inimigo")


## Askara numa batalha de verdade (andar 3): invocações entram na fila e no
## lado aliado, saem quando caem, o Lorde ataca todos e as invocações não
## seguram a derrota. Os inimigos não agem (a vez deles fica longe).
func _test_askara_in_battle() -> void:
	print("askara na batalha")
	Progression.delete()
	for n in range(1, 3):
		Progression.mark_floor_cleared(n)
	Floors.choose(3)
	Roster.set_team(["askara"])
	var b: Battle = (load("res://combat/battle.tscn") as PackedScene).instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	for foe in b.enemies:
		foe.av = 1e9
	var a := b.team[0] as Askara
	check(a != null, "a Askara entra na batalha pelo Elenco")
	a.fragments = 8
	var emissary: Summon = a.summon("emissary").summon
	await b.add_summon(emissary)
	check(emissary in b.fighters and b.allies_on_field() == [a, emissary] and b.living_allies() == [a],
		"a invocação entra na fila e no campo, mas não na equipe")
	check(b.enemies[0].choose_target(b.allies_on_field(), 0.5) == emissary, "os inimigos podem mirar nela (e o Emissário provoca)")
	var foe: Enemy = b.living_enemies()[0]
	var hp_before := foe.hp
	await b.summon_strike(emissary, emissary.strike)
	check(foe.hp < hp_before, "o golpe da invocação machuca o inimigo marcado")
	emissary.hp = 1
	await b.apply_damage(foe, emissary, 5.0)
	check(not emissary.on_field and emissary not in b.fighters and b.summons.is_empty() and not b.over, "invocação que cai sai de campo; a luta segue")
	check(a.status("shield_emissary") != null and a.shield() == roundi(emissary.max_hp * 0.08),
		"ao cair, o Emissário deixa a Muralha do Caos em quem tem menos HP")
	var day: Summon = a.summon("imp").summon
	await b.add_summon(day)
	var lilith: Summon = a.summon("lilith").summon
	await b.add_summon(lilith)
	check(b.summons.size() == 2 and b.visual(day).position != b.visual(lilith).position, "duas invocações, em vagas diferentes")
	b.target = 0
	var hp_values_before := b.living_enemies().map(func(i: Enemy) -> int: return i.hp)
	day.hp = 1
	await b.apply_damage(b.living_enemies()[0], day, 5.0)
	var after := b.enemies.map(func(i: Enemy) -> int: return i.hp)
	check(not day.on_field and day not in b.fighters and b.summons == [lilith], "o Diabrete caiu e saiu de campo")
	check(after[0] < hp_values_before[0] and (hp_values_before.size() < 2 or after[1] < hp_values_before[1]),
		"ao cair, a Explosão Vil acerta o alvo e o inimigo ao lado")
	day = a.summon("imp").summon
	await b.add_summon(day)
	a.fragments = 8
	var r := a.summon_lord(0.5)
	for x: Summon in r.dismissed:
		b.remove_summon(x)
	var lord: Summon = r.summon
	await b.add_summon(lord)
	var hp_values := b.living_enemies().map(func(i: Enemy) -> int: return i.hp)
	await b.summon_strike(lord, lord.entrance_strike)
	var alive := b.living_enemies()
	var all_took := true
	for i in alive.size():
		all_took = all_took and alive[i].hp < hp_values[i]
	check(b.summons == [lord] and all_took, "o Lorde apaga as outras e acerta todos ao chegar")
	var frag := a.fragments
	var target: Enemy = b.living_enemies()[0]
	target.hp = 1
	await b.apply_damage(a, target, 1.0)
	check(a.fragments == frag + 1, "inimigo caído dá fragmento à Askara")
	a.hp = 1
	await b.apply_damage(b.living_enemies()[0], a, 50.0)
	check(b.over and b.summons.is_empty(), "a Askara caiu: as invocações somem e a luta acaba (elas não seguram a derrota)")
	b.queue_free()
	await process_frame


func _test_cooldown() -> void:
	print("recarga")
	var s := Shumi.new()
	check(s.cooldown("skill2") == 0 and s.can_use("skill2", 1), "sem uso, a skill 2 está pronta")
	s.start_cooldown("skill2", 3)
	var h := _skill_data(s, "skill2")
	check(not s.can_use("skill2", 1) and h.state == "cooldown" and h.cooldown_remaining == 3 and h.missing_reason.begins_with("Recarga"),
		"usada, entra em recarga e a barra mostra quanto falta")
	s.pass_turn()
	s.pass_turn()
	check(s.cooldown("skill2") == 1 and not s.can_use("skill2", 1), "a recarga conta os turnos do dono")
	s.pass_turn()
	check(s.can_use("skill2", 1) and _skill_data(s, "skill2").state == "ready", "recarga 3: volta 3 turnos depois do uso")


func _test_shumi_bang() -> void:
	print("shumi: bang!")
	var s := Shumi.new()
	var foe := Enemy.new("Alvo", "", 1000, 10, 0, 100)
	var h := _skill_data(s, "skill2")
	check(h.key == "W" and h.point_cost == 1 and h.cooldown == Shumi.BANG_COOLDOWN and h.target == "single", "Bang! na tecla W, custa 1 ponto e tem recarga")
	var andri := Andri.new()
	check(s.follow_up(andri, foe).is_empty(), "sem o Bang!, não ataca junto")
	s.apply_status(Shumi.bang_status())
	check(s.follow_up(s, foe).is_empty(), "o próprio ataque dela não puxa outro")
	var before := s.energy
	var g := s.follow_up(andri, foe)
	check(g.name == "Finger Beam" and is_equal_approx(g.mult, 0.4) and s.energy == before + Shumi.FOLLOW_UP_ENERGY,
		"com o Bang!: Finger Beam de 0,4x e +4 de energia por ataque junto")
	s.level = 3
	check(is_equal_approx(s.follow_up(andri, foe).mult, 1.1), "no x20 o Finger Beam vai a 1,1x")
	s.level = -1
	s.start_cooldown("skill2", Shumi.BANG_COOLDOWN)
	for i in Shumi.BANG_DURATION:
		s.pass_turn()
	check(s.status("bang") == null and s.follow_up(andri, foe).is_empty(), "o Bang! acaba depois da duração")
	check(not s.can_use("skill2", 1), "quando o Bang! acaba, a recarga ainda segura um turno sem ele")
	s.pass_turn()
	check(s.can_use("skill2", 1), "e no turno seguinte ele volta")

func _test_andri_protocol() -> void:
	print("andri: protocolo MOMC")
	var a := Andri.new()
	var foe := Enemy.new("Alvo", "", 1000, 10, 0, 100)
	var h := _skill_data(a, "skill2")
	check(h.key == "W" and h.options.map(func(o: Dictionary) -> String: return o.id) == ["overload", "shield"]
		and h.options[1].target == "ally" and h.options[0].target == "single", "duas ordens, cada uma com o próprio alvo")
	check(a.invalid_reason("skill2", "shield", a) == "" and a.invalid_reason("skill2", "shield", foe) != "", "o Escudo vai num aliado")
	check(a.invalid_reason("skill2", "overload", foe) == "" and a.invalid_reason("skill2", "overload", a) != "", "a Sobrecarga vai num inimigo")
	check(Andri.momc_shield(a).shield == roundi(a.max_hp * Andri.MOMC_SHIELD) and Andri.MOMC_SHIELD < Andri.TYR_SHIELD,
		"o escudo do MOMC é menor que o da Mão de Tyr")
	a.switch_lens(Types.ICE)
	var g := a.overload_strike()
	check(g.type == Types.ICE and g.extra, "a Sobrecarga usa a lente e não encadeia")


func _test_askara_last_act() -> void:
	print("askara: último ato")
	var a := Askara.new()
	var passives := a.skills(1).filter(func(h: Dictionary) -> bool: return h.get("passive", false))
	check(passives.map(func(h: Dictionary) -> String: return h.action) == ["last_act", "fragments"] and not a.can_use("skill2", 3),
		"o Último Ato é passiva (sem W)")
	a.fragments = 8
	var day: Summon = a.summon("imp").summon
	check(day.last_act.name == "Explosão Vil" and Askara.SUMMONS.all(func(d: Dictionary) -> bool: return d.has("last_act")),
		"cada demônio tem último ato")
	var enemies: Array = [Enemy.new("A", "", 100, 1, 0, 100), Enemy.new("B", "", 100, 1, 0, 100), Enemy.new("C", "", 100, 1, 0, 100)]
	var pair := func(target: int) -> Array:
		return day.targets(day.last_act, enemies, target).map(func(pair: Array) -> Combatant: return pair[0])
	check(pair.call(0) == [enemies[0], enemies[1]] and pair.call(2) == [enemies[2], enemies[1]], "a Explosão Vil pega o alvo e o de trás (ou o da frente, no último)")
	var emissary: Summon = a.summon("emissary").summon
	var shumi := Shumi.new()
	shumi.hp = 100
	check(emissary.shield_target([a, emissary, shumi]) == shumi, "a Muralha do Caos vai em quem tem a menor fração de HP")
	a.fragments = 8
	var lord: Summon = a.summon_lord(0.5).summon
	check(lord.last_act.is_empty(), "os Lordes não têm último ato")


func _test_bang_in_battle() -> void:
	print("bang! na batalha")
	Progression.delete()
	Floors.choose(1)
	for n in range(1, 3):
		Progression.mark_floor_cleared(n)
	Progression.unlock("andri")
	Floors.choose(3)
	Roster.set_team(["shumi", "andri"])
	var b: Battle = (load("res://combat/battle.tscn") as PackedScene).instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	for foe in b.enemies:
		foe.av = 1e9
	var s := b.team[0] as Shumi
	var andri := b.team[1]
	s.apply_status(Shumi.bang_status())
	var foe: Enemy = b.living_enemies()[0]
	var energy_before := s.energy
	b._first_hit = null
	await b.apply_damage(andri, foe, 0.1)
	var hp_before := foe.hp
	await b._follow_up_attacks(andri)
	check(foe.hp < hp_before and is_equal_approx(s.energy, minf(s.max_energy, energy_before + Shumi.FOLLOW_UP_ENERGY)),
		"o Andri acerta e a Shumi ataca junto o mesmo inimigo (+4 de energia)")
	b._first_hit = null
	await b.apply_damage(s, foe, 0.1)
	hp_before = foe.hp
	await b._follow_up_attacks(s)
	check(foe.hp == hp_before, "o ataque dela mesma não puxa um ataque junto")
	b._first_hit = null
	await b.apply_damage(foe, s, 0.1)
	await b._follow_up_attacks(foe)
	check(b._first_hit == null, "golpe de inimigo não conta")
	var actions := b._actions[s] as ShumiActions
	var normal := b.visual(s).frames()
	s.remove_status("bang")
	actions.execute("skill2")  # sem await: confere o visual no meio do tiro
	await process_frame
	check(b.visual(s).frames() != normal, "o Finger Beam do Bang! sai no visual Kokoro")
	for i in 600:
		if s.status("bang"):
			break
		await process_frame
	check(s.status("bang") != null and b.visual(s).frames() == normal, "depois do tiro, volta ao visual normal (o Bang! continua)")
	b.queue_free()
	await process_frame


func _test_last_resort() -> void:
	print("último recurso dos inimigos (Ferro Negro)")
	var foe := Enemy.new("G", "", 1000, 100, 0, 100)
	foe.last_resort = Floors.BLACK_IRON
	foe.hp = 400
	check(foe.activate_last_resort() == null, "acima de 30% do HP, nada")
	foe.hp = 290
	var e := foe.activate_last_resort()
	check(e != null and e.name == "Ferro Negro" and e.shield == 250 and e.turns == 3, "abaixo de 30%: escudo de 25% do HP máximo por 3 turnos")
	foe.apply_status(e)
	check(foe.shield() == 250 and foe.effects().any(func(d: Dictionary) -> bool: return d.short == "FN"), "o escudo aparece nos efeitos")
	foe.hp = 100
	check(foe.activate_last_resort() == null, "uma vez por luta")
	var fallen := Enemy.new("G", "", 1000, 100, 0, 100)
	fallen.last_resort = Floors.BLACK_IRON
	fallen.hp = 0
	check(fallen.activate_last_resort() == null, "quem já caiu não ativa")
	var common := Enemy.new("S", "", 1000, 100, 0, 100)
	common.hp = 10
	check(common.activate_last_resort() == null, "inimigo sem último recurso nunca ativa")


func _test_black_iron_in_battle() -> void:
	print("ferro negro na batalha")
	Progression.delete()
	for n in range(1, 5):
		Progression.mark_floor_cleared(n)
	Progression.unlock("andri")
	Progression.unlock("askara")
	Floors.choose(5)
	Roster.set_team(["shumi", "andri", "askara"])
	var b: Battle = (load("res://combat/battle.tscn") as PackedScene).instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	for c in b.fighters:
		c.av = 1e9
	check(b.floor_number == 5 and b.team.size() == 3 and b.enemies[1].name == "Golem de Pedra", "andar 5: a equipe de três contra o Golem e os elementais")
	var golem: Enemy = b.enemies[1]
	var s := b.team[0]
	golem.hp = ceili(golem.max_hp * 0.3) + 1  # qualquer golpe o deixa abaixo de 30%
	await b.apply_damage(s, golem, 0.6)
	check(golem.is_alive() and golem.shield() == roundi(golem.max_hp * 0.25), "o golpe que deixa o Golem abaixo de 30% ativa o Ferro Negro")
	check(b.hud._announcement.text == "Ferro Negro ativado", "o anúncio \"Ferro Negro ativado\" aparece na tela")
	var shield := golem.shield()
	var hp := golem.hp
	await b.apply_damage(s, golem, 0.3)
	check(golem.hp == hp and golem.shield() < shield, "o escudo absorve os golpes seguintes")
	# escudo de aliado na HUD: contorno na barra e o valor ao lado do HP
	var esc := StatusEffect.new("shield", "Escudo", "E", "buff", 2)
	esc.shield = 150
	s.apply_status(esc)
	b.active = s
	b.refresh()
	check(is_equal_approx(b.hud._hp_bar.shield, 150.0) and b.hud._shield_text.visible and b.hud._shield_text.text == "+150",
		"o escudo do aliado aparece na barra de HP e ao lado do valor")
	s.remove_status("shield")
	b.refresh()
	check(is_zero_approx(b.hud._hp_bar.shield) and not b.hud._shield_text.visible, "sem escudo, a barra volta ao normal")
	b.queue_free()
	await process_frame


func _test_battle_phases() -> void:
	print("fases da batalha (máquina de estados)")
	Progression.delete()
	for n in range(1, 3):
		Progression.mark_floor_cleared(n)
	Progression.unlock("andri")
	Floors.choose(3)
	Roster.set_team(["andri", "shumi"])
	var b: Battle = (load("res://combat/battle.tscn") as PackedScene).instantiate()
	root.add_child(b)
	current_scene = b
	var seen: Array = []
	b._phase.changed.connect(func(_from: int, to: int) -> void: seen.append(to))
	await process_frame
	check(b.phase == Battle.Phase.STARTING and not b.waiting_for_player and not b.over, "a luta começa montando a arena")
	for foe in b.enemies:
		foe.av = 1e9
	b.team[1].av = 1e9  # o Andri age primeiro
	while not b.waiting_for_player:
		await process_frame
	# a lente do Andri abre sozinha no começo da vez
	check(b.phase == Battle.Phase.CHOOSING_OPTION and b._choosing == "lens" and b.waiting_for_player,
		"a vez do Andri abre o seletor da lente (CHOOSING_OPTION)")
	check(seen.slice(0, 3) == [Battle.Phase.ACTING, Battle.Phase.PLAYER_TURN, Battle.Phase.CHOOSING_OPTION],
		"STARTING -> ACTING -> PLAYER_TURN -> CHOOSING_OPTION")
	b.cancel_choice()
	check(b.phase == Battle.Phase.PLAYER_TURN and b.waiting_for_player, "Esc fecha o seletor e a vez continua (PLAYER_TURN)")
	b.request_action("basic")
	check(b.phase == Battle.Phase.ACTING and not b.waiting_for_player, "escolhida a ação, a fase é ACTING")
	check(not b._phase.can_go(Battle.Phase.STARTING) and b._phase.can_go(Battle.Phase.PLAYER_TURN),
		"só as trocas declaradas valem (ACTING não volta a STARTING)")
	for foe in b.enemies:
		foe.hp = 0
	b._check_end()
	check(b.phase == Battle.Phase.OVER and b.over, "inimigos no chão: OVER")
	b.queue_free()
	await process_frame


func _test_clairin_frenzy() -> void:
	print("clairin: chama frenética, descarga e cabeça flamejante")
	var c := Clairin.new()
	check(c.type == Types.FIRE and c.frenzy == 0 and is_equal_approx(c.atk(), c.base_atk), "Clairin é Fogo e começa com a barra vazia")
	c.gain_frenzy(50)
	check(is_equal_approx(c.atk(), c.base_atk * 1.4), "metade da barra: ATQ +40%")
	check(c.kit_bar().value == 50 and c.kit_bar().max == Clairin.FRENZY_MAX, "a barra do kit vai para a HUD")
	check(c.overflow().is_empty() and c.frenzy == 50, "sem encher, não estoura")
	c.gain_frenzy(60)
	check(c.frenzy == Clairin.FRENZY_MAX, "a barra para no máximo")
	var r := c.overflow()
	check(r.damage == ceili(c.max_hp * Clairin.OVERFLOW_DAMAGE) and c.hp == c.max_hp - r.damage and c.frenzy == 0 and not r.burst,
		"cheia, estoura: 20% do HP máximo nele e a barra zera")
	c.hp = 50
	c.gain_frenzy(100)
	check(c.overflow().damage == 49 and c.hp == 1 and c.is_alive(), "o estouro nunca derruba: fica com 1 de HP")
	c.hp = c.max_hp
	check(is_equal_approx(c.discharge_mult(), Clairin.DISCHARGE_MIN), "Descarga com a barra vazia: 0,5x")
	c.gain_frenzy(100)
	check(is_equal_approx(c.discharge(), Clairin.DISCHARGE_MAX) and c.frenzy == 0, "Descarga com a barra cheia: 2x, e zera sem estourar")
	check(c.can_use("skill2", 1) and not c.can_use("skill2", 0), "a Descarga custa ponto")
	c.start_cooldown("skill2", Clairin.DISCHARGE_COOLDOWN)
	check(not c.can_use("skill2", 1), "e tem recarga")
	c.energy = c.max_energy
	check(c.can_use("ult", 0) and _skill_data(c, "basic", 1).target == "single", "fora da ult, a Bola de Fogo é num alvo só")
	c.use_ult()
	check(c.in_flaming_head() and c.frenzy == Clairin.FRENZY_HEAD and c.energy == 0.0 and not c.can_use("ult", 0),
		"Lorde da Chama Frenética: entra com +30 de Frenesi")
	check(_skill_data(c, "basic", 1).target == "all" and _skill_data(c, "ult", 1).get("free", false),
		"como Lorde da Chama Frenética, a Bola de Fogo atinge todos; a ult não gasta o turno")
	c.gain_frenzy(100)
	check(c.overflow().burst, "como Lorde da Chama Frenética, o estouro queima também os inimigos")
	check(not c.end_turn() and not c.end_turn() and c.end_turn() and not c.in_flaming_head(), "dura 3 turnos dele")
	check(c.effects()[0].id == "frenzy", "o Frenesi aparece nos efeitos")


func _test_clairin_in_battle() -> void:
	print("clairin na batalha")
	Progression.delete()
	for n in range(1, 5):
		Progression.mark_floor_cleared(n)
	Floors.choose(5)
	Roster.set_team(["clairin"])
	var b: Battle = (load("res://combat/battle.tscn") as PackedScene).instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	for foe in b.enemies:
		foe.av = 1e9
	var c := b.team[0] as Clairin
	var normal := b.visual(c).frames()
	await _until(func() -> bool: return b.waiting_for_player)
	var hps: Array = b.enemies.map(func(e: Enemy) -> int: return e.hp)
	b.request_action("skill")
	await _until(func() -> bool: return b.waiting_for_player)
	check(range(3).all(func(i: int) -> bool: return b.enemies[i].hp < hps[i]) and c.frenzy == Clairin.FRENZY_WAVE,
		"a Onda Frenética atinge os três inimigos e enche a barra")
	c.frenzy = 90
	var hp_before := c.hp
	b.request_action("basic")
	await _until(func() -> bool: return b.waiting_for_player)
	check(c.frenzy == 0 and c.hp < hp_before, "a Bola de Fogo enche a barra, que estoura nele")
	c.energy = c.max_energy
	b.request_action("ult")
	await _until(func() -> bool: return b.waiting_for_player)
	check(c.in_flaming_head() and b.visual(c).frames() != normal, "a ult acende a cabeça (troca para a folha em chamas) e a vez continua")
	c.frenzy = 90
	hps = b.enemies.map(func(e: Enemy) -> int: return e.hp)
	b.request_action("basic")
	await _until(func() -> bool: return b.waiting_for_player or b.over)
	check(range(3).all(func(i: int) -> bool: return b.enemies[i].hp < hps[i] or not b.enemies[i].is_alive())
		and b.hud._log_lines.any(func(l: String) -> bool: return "alcança os inimigos" in l),
		"como Lorde da Chama Frenética, a Bola de Fogo pega todos e o estouro queima os inimigos")
	b.queue_free()
	await process_frame


## Espera `condition` ficar verdadeira (até 20 s de jogo).
func _until(condition: Callable) -> void:
	var t := 0.0
	while not condition.call() and t < 20.0:
		await process_frame
		t += 1.0 / 60.0


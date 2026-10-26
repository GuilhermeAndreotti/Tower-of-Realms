extends SceneTree
## Testes de níveis e experiência: regras da Progression, atributos por
## nível, desbloqueio, recompensa de batalha (com a cena de verdade) e save.
## Rodar: godot --headless --path . -s tests/test_progression.gd

var _failures := 0


func _initialize() -> void:
	_run()


func check(condition: bool, description: String) -> void:
	if condition:
		print("  ok   ", description)
	else:
		_failures += 1
		printerr("  FALHOU ", description)


func _run() -> void:
	Progression.file = "user://teste_progressao.cfg"
	# a história (quem chega depois) é testada com a chave temporária de
	# todos liberados desligada
	Roster.all_unlocked = false
	Progression.delete()

	_test_start()
	_test_curve()
	_test_level_up()
	_test_several_levels()
	_test_individual_growth()
	_test_hp_on_level_up()
	_test_max_level()
	_test_entry_level()
	_test_tower_limit()
	_test_unlock()
	_test_persistence()
	_test_old_save()
	await _test_battle_victory()
	await _test_battle_defeat()
	await _test_shared_xp()

	Progression.delete()
	print("\n%s (%d falha%s)" % ["TUDO OK" if _failures == 0 else "FALHOU", _failures, "" if _failures == 1 else "s"])
	quit(1 if _failures else 0)


func _clear() -> void:
	Progression.delete()


## Todos os andares vencidos: o limite da Torre fica no mais alto (9).
func _unlock_tower() -> void:
	for n in range(1, Floors.total()):
		Progression.mark_floor_cleared(n)


# ------------------------------------------------------------------ testes
func _test_start() -> void:
	print("início")
	_clear()
	check(Progression.progress("shumi") == {"level": 1, "xp": 0}, "sem save, começa no nível 1 com 0 XP")
	var s := Roster.create("shumi")
	check(s.character_level == 1 and s.max_hp == 1200 and s.hp == 1200, "Shumi nível 1: HP 1200 (o do kit)")
	check(is_equal_approx(s.base_atk, 150.0) and is_equal_approx(s.base_def, 50.0) and is_equal_approx(s.base_spd, 105.0),
		"Shumi nível 1: ATQ 150, DEF 50, VEL 105")
	var a := Roster.create("andri")
	check(a.max_hp == 1000 and is_equal_approx(a.base_atk, 130.0) and is_equal_approx(a.base_spd, 112.0),
		"Andri nível 1: HP 1000, ATQ 130, VEL 112")
	check(a.energy == 60.0 and a.max_energy == 120.0, "o nível não mexe na energia")


func _test_curve() -> void:
	print("curva de experiência")
	check(Progression.xp_to_next(1) == 100 and Progression.xp_to_next(2) == 150 and Progression.xp_to_next(3) == 200
		and Progression.xp_to_next(19) == 1000, "100, 150, 200... 1000 para ir do 19 ao 20")
	check(Progression.total_xp(9, 0) == 2200 and Progression.total_xp(2, 30) == 130, "XP total: 2200 até o nível 9")
	var growing := true
	for n in range(1, Progression.MAX_LEVEL - 1):
		growing = growing and Progression.xp_to_next(n + 1) > Progression.xp_to_next(n)
	check(growing, "cada nível custa mais que o anterior")
	check(Progression.xp_to_next(Progression.MAX_LEVEL) == 0, "no nível máximo não há próximo")
	var foe: Array[Enemy] = [Enemy.new("S", "", 550, 1, 0, 100), Enemy.new("G", "", 1400, 1, 0, 100)]
	check(Progression.battle_xp(foe) == 66 + 168, "XP pelo HP dos inimigos (66 + 168)")
	foe[0].xp = 10
	check(Progression.battle_xp(foe) == 10 + 168, "inimigo com XP própria usa a dele")
	foe[1].take_damage(500)
	check(Progression.enemy_xp(foe[1]) == 168, "a XP vem do HP de definição, não do atual")


func _test_level_up() -> void:
	print("subir de nível")
	_clear()
	var r := Progression.grant_xp("shumi", 60)
	check(r.level == 1 and r.current_xp == 60 and r.gains.is_empty(), "60 XP: continua no 1 com 60/100")
	r = Progression.grant_xp("shumi", 50)
	check(r.level_before == 1 and r.level == 2 and r.current_xp == 10, "mais 50: sobe para o 2 e sobram 10")
	check(Roster.create("shumi").character_level == 2, "o lutador criado depois já vem no nível 2")


func _test_several_levels() -> void:
	print("vários níveis de uma vez")
	check(Progression.add_xp(1, 0, 100 + 150 + 200 + 5) == {"level": 4, "xp": 5}, "455 XP no nível 1: vai ao 4 com 5 de sobra")
	_clear()
	_unlock_tower()
	var r := Progression.grant_xp("andri", 900)
	# 100 + 150 + 200 + 250 = 700; sobram 200 dos 300 do 5 -> 6
	check(r.level_before == 1 and r.level == 5 and r.current_xp == 200, "900 XP: nível 5 com 200/300")
	check(r.gains.hp == 4 * 50 and r.gains.atk == 22 and r.gains.spd == 4, "ganhos somam os 4 níveis (HP +200, ATQ +22, VEL +4)")


func _test_individual_growth() -> void:
	print("crescimento individual")
	var s := Roster.create("shumi", 10)
	var a := Roster.create("andri", 10)
	check(s.max_hp == 1200 + 9 * 60 and is_equal_approx(s.base_atk, 150 + 9 * 8.0), "Shumi nível 10: HP 1740, ATQ 222")
	check(a.max_hp == 1000 + 9 * 50 and is_equal_approx(a.base_atk, 130 + 9 * 5.5), "Andri nível 10: HP 1450, ATQ 179,5")
	var cs: Dictionary = Roster.data("shumi").growth
	var ca: Dictionary = Roster.data("andri").growth
	check(cs.atk > ca.atk and ca.spd > cs.spd and ca.def > cs.def, "Shumi cresce mais em ATQ; Andri em VEL e DEF")
	check(is_equal_approx(s.atk(), s.base_atk), "fora de combate, ATQ efetivo = base do nível (sem bônus)")
	s._bonus_extra["atk"] = 0.5
	check(is_equal_approx(s.atk(), 222.0 * 1.5), "bônus temporário multiplica a base do nível")
	s.apply_level(10, Progression.stats(s.level_1_stats(), cs, 10))
	s.apply_level(10, Progression.stats(s.level_1_stats(), cs, 10))
	check(s.max_hp == 1740 and is_equal_approx(s.base_atk, 222.0) and is_equal_approx(s.atk(), 333.0),
		"reaplicar o mesmo nível não acumula nada")


func _test_hp_on_level_up() -> void:
	print("HP ao subir de nível")
	var cs: Dictionary = Roster.data("shumi").growth
	var s := Roster.create("shumi", 1)
	s.apply_level(3, Progression.stats(s.level_1_stats(), cs, 3))
	check(s.max_hp == 1320 and s.hp == 1320, "com HP cheio, continua cheio (1320/1320)")
	s = Roster.create("shumi", 1)
	s.hp = 500
	s.apply_level(2, Progression.stats(s.level_1_stats(), cs, 2))
	check(s.max_hp == 1260 and s.hp == 560, "ferida, ganha só o que o máximo ganhou (500 -> 560)")
	s.apply_level(1, Progression.stats(s.level_1_stats(), cs, 1))
	check(s.max_hp == 1200 and s.hp == 560, "voltar o nível não cura nem passa do máximo")
	s.hp = 1200
	s.apply_level(1, Progression.stats(s.level_1_stats(), cs, 1))
	var e := Andri.artifact_status("archaedas", s, Types.FIRE)
	s.apply_status(e)
	s.apply_level(2, Progression.stats(s.level_1_stats(), cs, 2))
	check(s.max_hp == 1260 + e.extra_life and s.hp <= s.max_hp, "vida extra de estado continua por cima do nível")
	s.remove_status(e.id)
	check(s.max_hp == 1260, "ao sair o estado, sobra o HP máximo do nível")
	s.hp = 0
	s.apply_level(3, Progression.stats(s.level_1_stats(), cs, 3))
	check(s.hp == 0, "quem caiu não levanta por subir de nível")


func _test_max_level() -> void:
	print("nível máximo")
	check(Progression.add_xp(1, 0, 999999) == {"level": Progression.MAX_LEVEL, "xp": 0}, "sem limite da Torre, muita XP para no 20 com 0 XP")
	check(Progression.add_xp(20, 0, 5000) == {"level": 20, "xp": 0}, "no 20, XP nova não sobe nem acumula")
	check(Progression.add_xp(5, 0, 999999, 40).level == 20, "um limite acima do máximo vale como 20")
	check(Roster.create("shumi", 25).max_hp == 1200 + 19 * 60, "atributos param no nível 20")
	check(Progression.add_xp(25, 0, 10).level == 20, "nível acima do máximo é corrigido")


func _test_entry_level() -> void:
	print("nível de entrada")
	check(Progression.entry_level([8, 9, 10, 11]) == 10, "8, 9, 10, 11 (média 9,5) -> 10")
	check(Progression.entry_level([3, 4, 4, 5]) == 4, "3, 4, 4, 5 -> 4")
	check(Progression.entry_level([1, 2]) == 2, "1,5 arredonda para cima -> 2")
	check(Progression.entry_level([]) == 1, "sem equipe -> 1")
	check(Progression.entry_level([20, 20, 20]) == 20 and Progression.entry_level([0, -3]) == 1, "fica entre 1 e 20")


func _test_tower_limit() -> void:
	print("limite da Torre")
	_clear()
	var limits: Array = range(1, Floors.total() + 1).map(func(n: int) -> int: return Floors.floor_limit(n))
	check(limits == [3, 5, 7, 9, 11], "limites por andar mais alto liberado: 3, 5, 7, 9, 11")
	check(Floors.level_limit() == 3, "jogo novo: limite 3")
	var r := Progression.grant_xp("shumi", 999)
	check(r.level == 3 and r.current_xp == 0 and r.at_limit and r.xp_gained == 250, "muita XP: para no 3, XP 0, só 250 contam")
	r = Progression.grant_xp("shumi", 999)
	check(r.level == 3 and r.current_xp == 0 and r.xp_gained == 0 and r.gains.is_empty(), "repetir no limite não dá nada")
	Floors.complete(1)
	check(Floors.level_limit() == 5, "liberar o andar 2 sobe o limite para 5")
	check(Progression.progress("shumi") == {"level": 3, "xp": 0}, "subir o limite não dá níveis guardados")
	r = Progression.grant_xp("shumi", 120)
	check(r.level == 3 and r.current_xp == 120 and not r.at_limit, "a XP volta a contar normalmente (120/200)")
	Floors.complete(1)
	check(Floors.level_limit() == 5, "repetir um andar não sobe o limite")
	# save antigo acima do limite: não perde nível, só não ganha XP
	_clear()
	Progression._store("shumi", {"level": 8, "xp": 0})
	r = Progression.grant_xp("shumi", 500)
	check(r.level == 8 and r.xp_gained == 0 and Roster.create("shumi").character_level == 8,
		"acima do limite (save antigo): fica no 8, sem ganhar XP")


func _test_unlock() -> void:
	print("personagem desbloqueado")
	_clear()
	_unlock_tower()
	# Shumi no 7 (100+150+200+250+300+350 = 1350) e como equipe principal
	Progression.grant_xp("shumi", 1350)
	Roster.set_team(["shumi"])
	check(Progression.level("shumi") == 7 and Progression.main_team() == ["shumi"], "equipe principal: Shumi no 7")
	var p := Progression.unlock("andri")
	check(p == {"level": 7, "xp": 0}, "Andri entra no nível médio da equipe (7) com 0 XP")
	var a := Roster.create("andri")
	check(a.character_level == 7 and a.max_hp == 1000 + 6 * 50 and is_equal_approx(a.base_atk, 130 + 6 * 5.5),
		"atributos do próprio Andri no 7 (HP 1300, ATQ 163)")
	var s := Roster.create("shumi")
	check(a.max_hp != s.max_hp and a.base_atk != s.base_atk and a.type != s.type, "não copia nada da Shumi")
	Progression.grant_xp("shumi", 5000)
	check(Progression.unlock("andri") == {"level": 7, "xp": 0}, "desbloquear de novo não muda o nível")
	_clear()
	Progression.grant_xp("shumi", 250)
	Progression.grant_xp("askara", 250)
	Progression.grant_xp("clairin", 250)
	check(Progression.saved_team().is_empty() and Progression.unlock("andri").level == 3,
		"sem equipe salva: média dos liberados (Shumi, Askara e Clairin no 3)")
	_clear()
	Progression._store("shumi", {"level": 8, "xp": 0})
	Roster.set_team(["shumi"])
	check(Progression.unlock("andri").level == 3, "média acima do limite (Shumi no 8, limite 3): entra no 3")
	check(Roster.available() == Roster.IDS.filter(func(id: String) -> bool: return Roster.data(id).get("starts_unlocked", true) or id == "andri"),
		"liberados: os iniciais e os desbloqueados")


func _test_persistence() -> void:
	print("persistência")
	_clear()
	Progression.unlock("andri")
	Progression.grant_xp("shumi", 300)
	Roster.set_team(["andri", "shumi"])
	var before := Progression.progress("shumi")
	Progression.reload_save()  # como abrir o jogo de novo
	check(Progression.progress("shumi") == before and before.level == 3, "nível e XP voltam do arquivo (nível 3)")
	check(Roster.team() == ["andri", "shumi"], "a equipe principal também volta do arquivo")
	check(Progression.progress("andri") == {"level": 1, "xp": 0}, "quem não lutou continua no 1")
	Roster.set_team(["shumi"])
	check(Progression.level("andri") == 1 and Progression.level("shumi") == 3, "trocar a equipe não mexe no progresso")


func _test_old_save() -> void:
	print("save antigo ou estranho")
	_clear()
	var cfg := ConfigFile.new()
	cfg.set_value("jogador", "equipe", ["shumi", "fantasma"])
	cfg.set_value("personagem_shumi", "nivel", 99)
	cfg.set_value("personagem_shumi", "xp", 777)
	cfg.set_value("personagem_andri", "xp", 5000)
	cfg.save(Progression.file)
	Progression.reload_save()
	check(Progression.progress("shumi") == {"level": 20, "xp": 0}, "nível acima do máximo vira 20 (e XP 0)")
	check(Progression.progress("andri") == {"level": 1, "xp": 99}, "sem nível: 1, com a XP limitada ao nível")
	check(Roster.team() == ["shumi"], "ids que não existem mais saem da equipe")
	cfg.set_value("torre", "eventos_pendentes", [{"tipo": "desbloquear", "id": "andri"},
		{"tipo": "conversa", "id": "x", "quem": "shumi"}, {"type": "unlock", "id": "askara"}])
	cfg.save(Progression.file)
	Progression.reload_save()
	check(Progression.pending_events() == [{"type": "unlock", "id": "andri"},
		{"type": "conversation", "id": "x", "speaker": "shumi"}, {"type": "unlock", "id": "askara"}],
		"eventos pendentes salvos no formato antigo abrem no atual")
	_clear()
	cfg = ConfigFile.new()
	cfg.set_value("hud", "qualquer", true)  # arquivo sem nada de progresso
	cfg.save(Progression.file)
	Progression.reload_save()
	check(Progression.progress("andri") == {"level": 1, "xp": 0} and Roster.team() == ["shumi"], "save sem progresso: padrões")


# --------------------------------------------- batalha (cena de verdade)
## Batalha no `floor_number` (os anteriores contam como vencidos), com o Andri liberado.
func _open_battle(ids: Array[String], floor_number := 3) -> Battle:
	Progression.unlock("andri")
	for n in range(1, floor_number):
		Progression.mark_floor_cleared(n)
	Floors.choose(floor_number)
	Roster.set_team(ids)
	var b: Battle = (load("res://combat/battle.tscn") as PackedScene).instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	return b


func _close(b: Battle) -> void:
	b.queue_free()
	await process_frame


func _test_battle_victory() -> void:
	print("vitória")
	_clear()
	var b := await _open_battle(["shumi", "andri"])
	var xp := Progression.battle_xp(b.enemies)
	check(xp == 600, "o andar 3 vale 600 XP")
	b.team[1].hp = 0  # quem caiu na luta também ganha
	for foe in b.enemies:
		foe.hp = 0
	b._check_end()
	check(b.over and b.rewards.size() == Roster.available().size()
		and b.rewards.filter(func(r: Dictionary) -> bool: return r.took_part).size() == 2,
		"a vitória gera uma recompensa por personagem (quem lutou e quem ficou de fora)")
	# 100 + 150 + 200 = 450: nível 4 com 150 (limite 7)
	check(Progression.progress("shumi") == {"level": 4, "xp": 150} and Progression.progress("andri") == {"level": 4, "xp": 150},
		"600 XP: os dois vão do 1 ao 4 (sobram 150)")
	check(b.rewards[0].level_before == 1 and b.rewards[0].gains.hp == 180, "a recompensa diz quem subiu e quanto ganhou")
	b._check_end()
	b._finish(true, "de novo")
	b._reward()
	check(Progression.progress("shumi") == {"level": 4, "xp": 150}, "fim repetido na mesma batalha não dá XP de novo")
	Progression.reload_save()
	check(Progression.progress("andri") == {"level": 4, "xp": 150}, "a XP da vitória já está no arquivo")
	await _close(b)
	b = await _open_battle(["shumi"])
	check(b.team[0].character_level == 4 and b.team[0].max_hp == 1380, "a batalha seguinte já começa no nível 4")
	await _close(b)


func _test_shared_xp() -> void:
	print("XP de quem ficou de fora")
	_clear()
	var b := await _open_battle(["shumi"])
	for foe in b.enemies:
		foe.hp = 0
	b._check_end()
	var by_id := {}
	for r in b.rewards:
		by_id[r.id] = r
	check(by_id.size() == Roster.IDS.size() and by_id.shumi.took_part
		and Roster.IDS.all(func(id: String) -> bool: return id == "shumi" or not by_id[id].took_part),
		"quem ficou na reserva (Andri, Askara, Clairin) entra na recompensa")
	check(by_id.andri.xp == by_id.shumi.xp and Progression.progress("andri") == Progression.progress("shumi"),
		"e ganha a mesma XP de quem lutou")
	await _close(b)
	# bloqueado não ganha (nem é liberado pela recompensa)
	_clear()
	Floors.choose(1)
	Roster.set_team(["shumi"])
	b = (load("res://combat/battle.tscn") as PackedScene).instantiate()
	root.add_child(b)
	await process_frame
	for foe in b.enemies:
		foe.hp = 0
	b._check_end()
	check(not b.rewards.any(func(r: Dictionary) -> bool: return r.id == "andri") and not Progression.is_unlocked("andri")
		and Progression.progress("andri").xp == 0,
		"quem ainda não chegou à Torre não ganha XP")
	await _close(b)


func _test_battle_defeat() -> void:
	print("derrota")
	_clear()
	var b := await _open_battle(["shumi"])
	for c in b.team:
		c.hp = 0
	b._check_end()
	check(b.over and b.rewards.is_empty(), "derrota não gera recompensa")
	check(Progression.progress("shumi") == {"level": 1, "xp": 0}, "derrota não dá XP")
	await _close(b)

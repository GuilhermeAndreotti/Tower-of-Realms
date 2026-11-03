extends SceneTree
## Testes da subida da Torre: andares, missões secundárias, liberação,
## repetição, eventos de história (Andri no fim do andar 2), o mapa da Torre
## e a apresentação no saguão. Monta as cenas de verdade.
## Rodar: godot --headless --path . -s tests/test_tower.gd

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
	Progression.file = "user://teste_torre.cfg"
	# a história (quem chega depois) é testada com a chave temporária de
	# todos liberados desligada
	Roster.all_unlocked = false
	Progression.delete()

	_test_registry()
	_test_side_missions()
	_test_unlocking()
	_test_complete()
	_test_complete_side()
	_test_events()
	_test_all_unlocked()
	await _test_battle_floor_1()
	await _test_battle_floor_2()
	await _test_repeat_floor_2()
	await _test_battle_side()
	await _test_defeat_goes_back()
	await _test_floor_select()
	await _test_team_select()
	await _test_lobby_presents()
	await _test_lobby_line_event()

	Progression.delete()
	print("\n%s (%d falha%s)" % ["TUDO OK" if _failures == 0 else "FALHOU", _failures, "" if _failures == 1 else "s"])
	quit(1 if _failures else 0)


func _open(scene: String) -> Node:
	var n: Node = (load(scene) as PackedScene).instantiate()
	root.add_child(n)
	current_scene = n
	await process_frame
	return n


func _close(n: Node) -> void:
	n.queue_free()
	await process_frame


## Aperta `key` na tela de fim e confere que a batalha virou o saguão.
func _confirm_back(b: Battle, key: Key, description: String) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.pressed = true
	b._unhandled_input(ev)
	b._unhandled_input(ev)  # repetido: não troca de cena duas vezes
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.scene_file_path == Battle.LOBBY_SCENE
		and Engine.get_meta(Lobby.ENTRANCE_META, "") == "door", description)
	if current_scene:
		await _close(current_scene)


func _win(b: Battle) -> void:
	for foe in b.enemies:
		foe.hp = 0
	b._check_end()


# ------------------------------------------------------------------ regras
func _test_registry() -> void:
	print("cadastro dos andares")
	check(Floors.total() == 5, "5 andares")
	var ok := true
	for n in range(1, Floors.total() + 1):
		var d := Floors.data(n)
		ok = ok and d.name != "" and d.enemies.size() >= 1 and d.enemies.size() <= Battle.ENEMY_POSITIONS.size()
		ok = ok and Floors.create_enemies(n).size() == d.enemies.size()
		for e: Dictionary in d.get("on_win", []):
			ok = ok and e.type in ["unlock", "conversation"]
	check(ok, "todo andar tem nome, de 1 a 3 inimigos e eventos válidos")
	check(Floors.max_team(1) == 1 and Floors.max_team(2) == 1 and Floors.max_team(3) == 2 and Floors.max_team(4) == 2
		and Floors.max_team(5) == 3, "equipe: 1, 1, 2, 2, 3")
	var xp_values: Array = range(1, 6).map(func(n: int) -> int: return Progression.battle_xp(Floors.create_enemies(n)))
	check(xp_values == [150, 350, 600, 900, 1000], "XP por andar: 150, 350, 600, 900, 1000")
	var boss := Floors.create_enemies(4)[1]
	check(boss.name == "Guardião Sombrio" and boss.type == Types.DARKNESS and boss.heavy_strike_every == 2, "andar 4 tem o chefe de Trevas")
	var forge := Floors.create_enemies(5)
	check(forge[1].name == "Golem de Pedra" and forge[1].max_hp > forge[0].max_hp * 3 and forge[0].type == Types.FIRE and forge[2].type == Types.FIRE,
		"andar 5: Golem de Pedra como chefe e dois Elementais de Fogo")
	check(forge[0].last_resort.get("name", "") == "Ferro Negro" and forge[2].last_resort.get("name", "") == "Ferro Negro"
		and forge[1].last_resort.is_empty(), "no andar 5, os Elementais têm o Ferro Negro e o Golem não")
	check(forge[1].second_form.get("name", "") == "Golem Incandescente" and forge[0].second_form.is_empty() and forge[2].second_form.is_empty(),
		"só o Golem volta numa segunda forma")
	check(range(1, 5).all(func(n: int) -> bool: return Floors.create_enemies(n).all(func(i: Enemy) -> bool: return i.last_resort.is_empty())),
		"os andares 1 a 4 não têm último recurso")
	# ritmo: sem repetir nada, as primeiras vitórias levam ao recomendado do andar seguinte
	var total := 0
	var pace := true
	for n in range(1, Floors.total()):
		total += xp_values[n - 1]
		var p := Progression.add_xp(1, 0, total)
		pace = pace and p.level == Floors.data(n + 1).recommended_level
	check(pace, "sem repetir andares, chega-se a cada andar no nível recomendado")
	var slack := true
	for n in range(1, Floors.total() + 1):
		slack = slack and Floors.floor_limit(n) > Floors.data(n).recommended_level
	check(slack, "o limite de cada andar fica acima do recomendado (há espaço para treinar)")
	# os tipos tiram o x2 automático do Andri onde importa
	var without_x2 := func(foe: Enemy) -> bool:
		return Andri.LENSES.all(func(t: String) -> bool: return Types.effectiveness(t, foe.type) < Types.SUPER)
	check(without_x2.call(Floors.create_enemies(3)[1]) and without_x2.call(boss), "o Guardião do 3 e o chefe não são fracos a nenhuma lente")
	check(Floors.data(2).on_win == [{"type": "unlock", "id": "andri"}], "o Andri chega no fim do andar 2")


func _test_side_missions() -> void:
	print("missões secundárias")
	var ids: Array[String] = []
	var ok := true
	var pace := true
	for n in range(1, Floors.total() + 1):
		for s: Dictionary in Floors.side_missions(n):
			ids.append(s.id)
			var m := Floors.mission(n, s.id)
			ok = ok and m.name != "" and m.description != "" and m.enemies.size() >= 1
			ok = ok and m.enemies.size() <= Battle.ENEMY_POSITIONS.size() and m.has("background")
			ok = ok and Floors.create_enemies(n, s.id).size() == m.enemies.size()
			# abrem junto com o andar seguinte e são feitas para o recomendado dele
			var next_level: int = Floors.data(n + 1).recommended_level if n < Floors.total() else Floors.floor_limit(n) - 1
			pace = pace and m.recommended_level == next_level
	check(ok, "toda secundária tem nome, descrição, cenário e de 1 a 3 inimigos")
	check(ids.size() == 8 and ids.size() == range(ids.size()).filter(func(i: int) -> bool: return ids.find(ids[i]) == i).size(),
		"8 secundárias, com ids únicos (vão para o save)")
	check(range(1, Floors.total() + 1).all(func(n: int) -> bool: return not Floors.side_missions(n).is_empty()), "todo andar tem secundária")
	check(pace, "a secundária do andar N pede o nível recomendado do N+1")
	check(Floors.max_team(1, "ronda") == 1 and Floors.max_team(2, "ecos") == 2 and Floors.max_team(5, "fornalha") == 3,
		"a secundária herda o tamanho da equipe do andar, salvo quando tem o seu")
	check(Floors.mission(5, "fornalha").background == Floors.FORGE_BACKGROUND and Floors.mission(5, "pedreira").background == Floors.DEFAULT_BACKGROUND,
		"e o cenário também")
	check(Floors.mission(3) == Floors.data(3), "a missão principal é o próprio andar")
	# a escolha do andar não revela a luta: a descrição não cita tipos nem golpes
	var words: Array = ["Golpe Pesado", "Veneno", "Trevas", "Água", "Ácido", "Fogo", "a cada", "absorve", "escudo"]
	var silent := true
	for n in range(1, Floors.total() + 1):
		for id in FloorSelect.missions(n):
			var text: String = Floors.mission(n, id).description
			silent = silent and words.all(func(w: String) -> bool: return w not in text)
	check(silent, "nenhuma descrição conta tipos, golpes ou mecânicas")

func _test_unlocking() -> void:
	print("liberação")
	Progression.delete()
	check(Floors.is_unlocked(1) and not Floors.is_unlocked(2) and not Floors.is_unlocked(5) and not Floors.is_unlocked(0), "jogo novo: só o andar 1")
	check(Floors.current() == 1 and Floors.highest_unlocked() == 1, "o andar atual é o 1")
	Floors.choose(3)
	check(Floors.current() == 1, "não dá para escolher andar trancado")
	Progression.mark_floor_cleared(1)
	check(Floors.is_unlocked(2) and not Floors.is_unlocked(3) and Floors.highest_unlocked() == 2, "vencer o 1 libera o 2")
	Floors.choose(2)
	check(Floors.current() == 2, "o andar escolhido fica salvo")
	Floors.choose(1)
	check(Floors.current() == 1, "dá para voltar a um andar vencido")
	check("andri" not in Roster.available() and "askara" in Roster.available(), "o Andri ainda não está na Torre; a Askara já")


func _test_complete() -> void:
	print("concluir andar")
	Progression.delete()
	var c := Floors.complete(1)
	check(c.first and c.unlocked_floor == 2 and c.events.is_empty(), "andar 1: primeira vitória, libera o 2, sem história")
	c = Floors.complete(1)
	check(not c.first and c.unlocked_floor == 0, "repetir o 1: nada novo")
	Progression.grant_xp("shumi", 260)  # Shumi no 3
	Roster.set_team(["shumi"])
	c = Floors.complete(2)
	check(c.first and c.events.size() == 1 and "andri" in Roster.available(), "andar 2: o Andri chega")
	check(Progression.level("andri") == 3 and Progression.progress("andri").xp == 0, "ele entra no nível da equipe (3) com 0 XP")
	check(Progression.pending_events() == [{"type": "unlock", "id": "andri"}], "a chegada fica pendente para o saguão")
	c = Floors.complete(2)
	check(not c.first and c.events.is_empty() and Progression.pending_events().size() == 1, "repetir o 2 não repete a história")
	Floors.complete(3)
	c = Floors.complete(4)
	check(c.first and c.unlocked_floor == 5 and c.limit_after == 11, "vencer o 4 libera o 5 (limite 11)")
	c = Floors.complete(5)
	check(c.first and c.unlocked_floor == 0, "o andar 5 é o último")
	Progression.reload_save()
	check(Progression.cleared_floors() == [1, 2, 3, 4, 5] and Progression.pending_events().size() == 1, "andares e pendências voltam do arquivo")


func _test_complete_side() -> void:
	print("concluir missão secundária")
	Progression.delete()
	check(not Floors.is_mission_unlocked(1, "ronda") and not Floors.is_mission_unlocked(1, "nada"), "jogo novo: secundárias trancadas")
	Floors.choose(1, "ronda")
	check(Floors.current_mission() == "", "não dá para escolher secundária trancada")
	var c := Floors.complete(1)
	check(c.opened_side == 1 and Floors.is_mission_unlocked(1, "ronda") and not Floors.is_mission_unlocked(2, "ecos"),
		"vencer a principal abre as secundárias daquele andar")
	Floors.choose(1, "ronda")
	check(Floors.current() == 1 and Floors.current_mission() == "ronda", "a missão escolhida fica salva")
	c = Floors.complete(1, "ronda")
	check(c.first and c.unlocked_floor == 0 and c.opened_side == 0 and c.limit_after == c.limit_before,
		"a secundária não libera andar nem muda o limite")
	check(Floors.is_mission_cleared(1, "ronda") and FloorSelect.situation(1, "ronda") == "cleared", "e fica vencida")
	c = Floors.complete(1, "ronda")
	check(not c.first, "repetir a secundária: nada novo")
	Floors.choose(2)
	check(Floors.current() == 2 and Floors.current_mission() == "", "escolher só o andar volta à principal")
	Progression.reload_save()
	check(Progression.cleared_missions() == ["ronda"] and Progression.cleared_floors() == [1], "secundárias vencidas voltam do arquivo")
	# save antigo ou mexido: missão que não existe mais vale a principal
	Progression._data().set_value("torre", "missao", "sumiu")
	Progression._data().set_value("torre", "missoes_vencidas", ["ronda", 3, ""])
	check(Floors.current_mission() == "" and Progression.cleared_missions() == ["ronda"], "valores inválidos são ignorados na leitura")

func _test_events() -> void:
	print("eventos")
	check(StoryEvents.from_text("unlock:andri") == {"type": "unlock", "id": "andri"}, "fala com \"unlock:andri\" vira evento")
	check(StoryEvents.from_text("conversation:arrival") == {"type": "conversation", "id": "arrival"}, "fala com \"conversation:id\" vira evento")
	check(StoryEvents.from_text("flash").is_empty() and StoryEvents.from_text("outra:coisa").is_empty(), "outros textos não são eventos")
	check(StoryEvents.summary({"type": "unlock", "id": "andri"}).begins_with("Andri Findavil chegou"), "resumo da chegada para a tela de vitória")
	check(StoryEvents.summary({"type": "conversation", "id": "x"}) == "", "conversa não aparece na tela de vitória")
	Progression.delete()
	Progression.add_pending_events([{"type": "conversation", "id": "a"}, {"type": "conversation", "id": "b"}])
	Progression.pop_pending_event()
	check(Progression.pending_events() == [{"type": "conversation", "id": "b"}], "pendentes saem na ordem")


# ---------------------------------------------------------------- batalha
func _test_battle_floor_1() -> void:
	print("batalha: andar 1")
	Progression.delete()
	Roster.set_team(["shumi"])
	var b: Battle = await _open("res://combat/battle.tscn")
	check(b.floor_number == 1 and b.enemies.size() == 2 and b.enemies[0].max_hp == 420, "o andar 1 traz as duas sentinelas dele")
	check("Shumi[/color] encontra os guardiões" in b.hud._log_lines[0], "o registro abre em pt-BR: \"%s\"" % b.hud._log_lines[0])
	await _win(b)
	check(b.completion.first and b.completion.unlocked_floor == 2, "vencer libera o andar 2")
	check(Progression.progress("shumi") == {"level": 2, "xp": 50}, "Shumi: 150 XP, nível 2")
	check(b.completion.limit_before == 3 and b.completion.limit_after == 5 and "Limite de nível: 3 → 5" in b.hud._end_extras.get_child(1).text,
		"a tela de vitória avisa que o limite subiu")
	check(not b.hud._end_extras.get_child(0).text.is_empty() and "Andar 2" in b.hud._end_extras.get_child(0).text,
		"a tela de vitória avisa o andar liberado")
	await _confirm_back(b, KEY_ENTER, "depois da vitória, Enter volta ao saguão")


func _test_battle_floor_2() -> void:
	print("batalha: andar 2 (o Andri chega)")
	Floors.choose(2)
	Roster.set_team(["shumi"])
	var b: Battle = await _open("res://combat/battle.tscn")
	check(b.floor_number == 2 and b.team.size() == 1, "andar 2, só com a Shumi")
	await _win(b)
	# 150 + 350 = 500: nível 4 (450) com 50
	check(Progression.progress("shumi") == {"level": 4, "xp": 50}, "Shumi: nível 4")
	check("andri" in Roster.available() and Progression.level("andri") == 4, "o Andri chega no nível que a Shumi tem depois da luta (4)")
	var texts: Array = b.hud._end_extras.get_children().map(func(l: Label) -> String: return l.text)
	check(texts.size() == 4 and "Nova missão no mapa do andar 2" in texts[2] and "Andri Findavil chegou" in texts[3],
		"a tela de vitória avisa a missão nova e anuncia a chegada")
	await _close(b)


func _test_defeat_goes_back() -> void:
	print("derrota")
	Floors.choose(1)
	var b: Battle = await _open("res://combat/battle.tscn")
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.pressed = true
	b._unhandled_input(ev)
	await process_frame
	check(current_scene == b, "durante a luta, Enter não sai da batalha")
	for c in b.team:
		c.hp = 0
	b._check_end()
	check(b.over and not b.hud._end_extras.visible, "derrota: sem andar liberado nem história")
	await _confirm_back(b, KEY_ESCAPE, "depois da derrota, Esc também volta ao saguão")


func _test_repeat_floor_2() -> void:
	print("repetir andar")
	Floors.choose(2)
	Roster.set_team(["shumi", "andri"])
	var b: Battle = await _open("res://combat/battle.tscn")
	check(b.team.size() == 1, "a batalha respeita o limite do andar mesmo com equipe maior salva")
	var pending := Progression.pending_events().size()
	await _win(b)
	check(not b.completion.first and b.rewards[0].took_part and b.rewards[0].xp == 350, "repetir dá a XP de novo")
	check(b.rewards.size() == Roster.available().size() and not b.rewards[1].took_part,
		"o Andri, de fora (o andar só aceita 1), também ganha")
	check(Progression.pending_events().size() == pending and b.hud._end_extras.get_child_count() == 0, "e não repete a história")
	await _close(b)


func _test_battle_side() -> void:
	print("batalha: missão secundária")
	Progression.delete()
	Progression.mark_floor_cleared(1)
	Progression.mark_floor_cleared(2)
	Progression.unlock("andri")
	Roster.set_team(["shumi", "andri"])
	Floors.choose(2, "ecos")
	var b: Battle = await _open("res://combat/battle.tscn")
	check(b.mission_id == "ecos" and b.team.size() == 2 and b.enemies.size() == 2 and b.enemies[1].name == "Guardião",
		"a batalha monta a secundária, com o tamanho de equipe dela")
	check("Ecos do Salão" in b.hud._log_lines[0], "o registro abre com o nome da missão")
	await _win(b)
	check(b.completion.first and b.completion.unlocked_floor == 0 and Floors.is_mission_cleared(2, "ecos"), "vencer marca a secundária")
	check(b.rewards[0].xp == 400, "e dá a XP dos inimigos dela")
	check(b.hud._end_extras.get_child_count() == 0, "sem andar liberado nem história na tela de vitória")
	await _close(b)

# ------------------------------------------------------------------ telas
func _test_floor_select() -> void:
	print("mapa da Torre")
	Progression.delete()
	Progression.mark_floor_cleared(1)
	var t: FloorSelect = await _open("res://tower/floor_select.tscn")
	check(t.cursor == 2 and t.cursor_mission == "", "o cursor começa na principal do andar mais alto liberado")
	check(FloorSelect.situation(1) == "cleared" and FloorSelect.situation(2) == "new" and FloorSelect.situation(3) == "locked",
		"andares vencido, novo e trancado")
	check(FloorSelect.situation(1, "ronda") == "new" and FloorSelect.situation(2, "ecos") == "locked", "secundárias nova e trancada")
	var sheet := _texts(t._detail)
	check("Salão do Guardião" in sheet and "Nível recomendado: 2" in sheet and "só 1 personagem" in sheet, "a ficha mostra nome, nível e equipe")
	check("XP" not in sheet and "JÁ ENFRENTADOS" not in sheet and "Sentinela" not in sheet, "e não revela inimigos nem XP de missão nunca vencida")
	# clique no círculo: o primeiro seleciona, o segundo entra
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = t.node_position(1, 0)
	t._map_input(click)
	await process_frame
	check(t.cursor == 1 and t.cursor_mission == "" and current_scene == t, "clicar num círculo seleciona a missão")
	sheet = _texts(t._detail)
	check("JÁ ENFRENTADOS" in sheet and "Sentinela" in sheet and "150 XP" in sheet, "missão vencida lembra os inimigos e a XP")
	click.position = t.node_position(2, 1)
	t._map_input(click)
	check(t.cursor == 2 and t.cursor_mission == "ecos" and t._button.disabled, "a secundária trancada é selecionável, com o botão desligado")
	t._map_input(click)
	check(current_scene == t and "trancada" in t._notice.text, "clicar de novo num trancado só avisa")
	t.cursor = 3
	t.cursor_mission = ""
	t._refresh()
	check(t._button.disabled and "???" in _texts(t._detail), "andar trancado: botão desligado e nome escondido")
	t.select(1)
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	t._unhandled_input(key)
	check(t.cursor == 1 and t.cursor_mission == "ronda", "→ vai da principal para o ramal do andar 1")
	click.position = t.node_position(1, 1)
	t._map_input(click)
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.scene_file_path == FloorSelect.TEAM_SCENE, "o segundo clique leva à montagem da equipe")
	check(Progression.chosen_floor() == 1 and Progression.chosen_mission() == "ronda", "e salva a missão escolhida")
	await _close(current_scene)


## Todo o texto das Labels dentro de `node`, uma por linha.
func _texts(node: Node) -> String:
	var lines: Array[String] = []
	for child in node.find_children("*", "Label", true, false):
		if not child.is_queued_for_deletion():
			lines.append((child as Label).text)
	return "\n".join(lines) + "\n"


func _test_team_select() -> void:
	print("montagem da equipe")
	Progression.delete()
	Progression.unlock("andri")
	Roster.set_team(["shumi", "andri"])
	var s: TeamSelect = await _open("res://tower/team_select.tscn")
	check(s._max == 1 and s.team == ["shumi"], "andar 1: uma vaga; a equipe salva é cortada")
	s.toggle("andri")
	check(s.team == ["shumi"], "não passa do limite do andar")
	await _close(s)
	for n in [1, 2]:
		Progression.mark_floor_cleared(n)
	Floors.choose(3)
	s = await _open("res://tower/team_select.tscn")
	check(s._max == 2 and s.team == ["shumi", "andri"], "andar 3: duas vagas, a equipe salva volta inteira")
	await _close(s)
	Floors.choose(1, "ronda")
	s = await _open("res://tower/team_select.tscn")
	check(s._max == 1 and s._mission_id == "ronda", "a montagem usa o limite da missão escolhida")
	await _close(s)


func _test_lobby_presents() -> void:
	print("saguão apresenta a chegada")
	Progression.delete()
	Roster.set_team(["shumi"])
	Progression.mark_floor_cleared(1)
	Floors.complete(2)
	var l: Lobby = await _open("res://lobby/lobby.tscn")
	check(l._visuals.has("andri") and l._visuals.andri.modulate.a == 0.0, "o Andri começa escondido")
	check(l.mode == Lobby.Mode.PRESENTING and l.player.locked, "o jogador fica parado durante a apresentação (PRESENTING)")
	await create_timer(1.0).timeout
	check(l._visuals.andri.modulate.a > 0.0 and "Andri Findavil chegou" in l.hud.announcement_text(), "ele surge com o anúncio")
	await create_timer(2.5).timeout
	check(Progression.pending_events().is_empty() and not l.busy, "acabada a apresentação, sai da fila e libera o jogador")
	await _close(l)
	l = await _open("res://lobby/lobby.tscn")
	await create_timer(0.7).timeout
	check(l._visuals.andri.modulate.a == 1.0 and not l.busy, "na volta seguinte, ele já está lá, sem repetir")
	await _close(l)


func _test_lobby_line_event() -> void:
	print("evento numa fala")
	Progression.delete()
	var l: Lobby = await _open("res://lobby/lobby.tscn")
	await create_timer(0.7).timeout
	check(not l._visuals.has("andri"), "jogo novo: o Andri não está no saguão")
	var conversation := {"lines": [{"text": "Chegou alguém.", "event": "unlock:andri"}, {"text": "Fim."}]}
	l._mode.go(Lobby.Mode.TALKING)
	l.hud.dialog.open(conversation, "Teste", null)
	check("andri" in Roster.available(), "a fala com evento libera na hora")
	l.hud.dialog.handle_key(KEY_ENTER)
	l.hud.dialog.handle_key(KEY_ENTER)
	await process_frame
	check(l._visuals.has("andri"), "ao fim da conversa, ele surge no saguão")
	await create_timer(2.6).timeout
	check(Progression.pending_events().is_empty() and not l.busy, "e o jogador volta a andar")
	await _close(l)


func _test_all_unlocked() -> void:
	print("todos liberados (chave temporária)")
	Progression.delete()
	Roster.all_unlocked = true
	check(Roster.available() == Roster.IDS, "com a chave ligada, todos começam liberados")
	Progression.mark_floor_cleared(1)
	var c := Floors.complete(2)
	check(c.first and c.events.is_empty() and Progression.pending_events().is_empty(),
		"a chegada de quem já está liberado não vira evento nem apresentação")
	Roster.all_unlocked = false
	Progression.delete()

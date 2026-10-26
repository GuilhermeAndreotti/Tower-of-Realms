extends SceneTree
## Testes do saguão: monta a cena de verdade, anda com teclas simuladas e
## confere colisão, alcance, interações e a porta.
## Rodar: godot --headless --path . -s tests/test_lobby.gd

var _failures := 0
var lobby: Lobby


func _initialize() -> void:
	_run()


func check(condition: bool, description: String) -> void:
	if condition:
		print("  ok   ", description)
	else:
		_failures += 1
		print("  FALHA ", description)


func _run() -> void:
	Progression.file = "user://teste_lobby_progresso.cfg"
	# a história (quem chega depois) é testada com a chave temporária de
	# todos liberados desligada
	Roster.all_unlocked = false
	Progression.delete()
	Progression.unlock("andri")  # o saguão completo (a chegada é testada em teste_torre)
	Engine.remove_meta(Lobby.ENTRANCE_META) if Engine.has_meta(Lobby.ENTRANCE_META) else null
	lobby = (load("res://lobby/lobby.tscn") as PackedScene).instantiate()
	root.add_child(lobby)
	current_scene = lobby
	await _frames(3)

	_test_assembly()
	await _test_walls()
	await _test_furniture()
	_test_paths()
	await _test_approach_and_interaction()
	await _test_dialog()
	await _test_door()
	Progression.delete()

	print("\n%s (%d falha%s)" % ["TUDO OK" if _failures == 0 else "FALHOU", _failures, "" if _failures == 1 else "s"])
	quit(1 if _failures else 0)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
	await process_frame


func _hold(key: Key, seconds: float) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = key
	e.keycode = key
	e.pressed = true
	Input.parse_input_event(e)
	await create_timer(seconds).timeout
	var s := e.duplicate()
	s.pressed = false
	Input.parse_input_event(s)
	await _frames(2)


func _by(p_screen: Vector2) -> void:
	lobby.player.position = p_screen
	lobby.player.reset_physics_interpolation()
	await _frames(2)


func _interactable(id: String) -> Interactable:
	for it in lobby.interactables:
		if it.id == id:
			return it
	return null


# ------------------------------------------------------------------ testes
func _test_assembly() -> void:
	print("Montagem")
	check(lobby.player.id == "caoimhe", "quem anda pelo saguão é a Caoimhe")
	check(lobby.player.position == Lobby.screen(Lobby.ENTRANCES.start), "ela começa no centro do tapete")
	var ids := lobby.interactables.map(func(it: Interactable) -> String: return it.id)
	for id in Roster.IDS:
		check(id in ids, "%s está no saguão" % Roster.data(id).name)
	check("caoimhe" not in ids, "a Caoimhe não aparece de novo como personagem parada")
	check("door" in ids, "a porta da dungeon é interagível")
	check(_interactable("shumi").title == "Shumi" and _interactable("shumi").portrait != null, "personagens têm nome e retrato")
	# o quadro parado dela é o sprite original, sem mudanças
	var frames := FighterVisual.load_frames(Lobby.CAOIMHE.sprite.png, Lobby.CAOIMHE.sprite.json)
	var q: AtlasTexture = frames.get_frame_texture("idle", 0)
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(Lobby.CAOIMHE.sprite.png))
	var frame := sheet.get_region(Rect2i(q.region)).get_region(Rect2i(2, 3, 26, 36))
	var original := Image.load_from_file(ProjectSettings.globalize_path("res://characters/caoimhe/caoimhe.png"))
	original.convert(frame.get_format())
	check(frame.get_data() == original.get_data(), "o quadro parado da Caoimhe é idêntico ao sprite original")
	# personagens espalhados, não em fila nem amontoados
	var pos := lobby.interactables.filter(func(it: Interactable) -> bool: return it.id != "door").map(func(it: Interactable) -> Vector2: return it.position)
	var ok := true
	for i in pos.size():
		for j in range(i + 1, pos.size()):
			if pos[i].distance_to(pos[j]) < 150:
				ok = false
	check(ok, "personagens a mais de 150px uns dos outros")


func _test_walls() -> void:
	print("Paredes")
	await _by(Lobby.screen(Vector2(240, 140)))
	await _hold(KEY_UP, 1.5)
	var y := lobby.player.position.y
	check(y >= Lobby.BACK_LIMIT * Lobby.SCALE - 1, "não atravessa a parede do fundo (y=%d)" % y)
	check(y <= Lobby.BACK_LIMIT * Lobby.SCALE + 15, "chega até a parede do fundo")
	await _hold(KEY_DOWN, 2.0)
	check(lobby.player.position.y <= Lobby.FRONT_LIMIT * Lobby.SCALE + 1, "não sai pela frente da tela")
	await _by(Lobby.screen(Vector2(40, 170)))
	await _hold(KEY_A, 1.0)
	check(lobby.player.position.x >= Lobby.SIDE_LIMIT * Lobby.SCALE - 1, "não sai pela esquerda (WASD também anda)")
	check(lobby.player.visual.get_child(0).scale.x < 0, "vira o sprite ao andar para a esquerda")
	await _hold(KEY_D, 0.3)
	check(lobby.player.visual.get_child(0).scale.x > 0, "e desvira ao andar para a direita")


func _test_furniture() -> void:
	print("Móveis")
	# à esquerda da mesa grande, na altura da base dela, andando para a direita
	var table := Lobby.screen(Vector2(72, 141))
	await _by(table + Vector2(-110, -6))
	await _hold(KEY_RIGHT, 1.2)
	var border := table.x - 22 * Lobby.SCALE - Lobby.FEET.x / 2
	check(lobby.player.position.x <= border + 1, "a mesa bloqueia (x=%d, borda=%d)" % [lobby.player.position.x, border])
	# e não trava o jogador: dá para contornar por baixo
	await _hold(KEY_DOWN, 0.6)
	await _hold(KEY_RIGHT, 1.2)
	check(lobby.player.position.x > table.x + 40, "contorna a mesa pela frente")


## Busca em largura numa grade de 6px pelos lugares onde os pés cabem,
## a partir da entrada: cada interagível precisa ter um ponto alcançável
## dentro do raio dele.
func _test_paths() -> void:
	print("Caminhos")
	var space := lobby.get_world_2d().direct_space_state
	var form := RectangleShape2D.new()
	form.size = LobbyPlayer.FEET
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = form
	consulta.exclude = [lobby.player.get_rid()]
	var free := func(p: Vector2) -> bool:
		consulta.transform = Transform2D(0, p + Vector2(0, -form.size.y / 2))
		return space.intersect_shape(consulta, 1).is_empty()
	var step := 6.0
	var start := Lobby.screen(Lobby.ENTRANCES.start).snapped(Vector2(step, step))
	var seen := {start: true}
	var queue := [start]
	while not queue.is_empty():
		var p: Vector2 = queue.pop_front()
		for d in [Vector2(step, 0), Vector2(-step, 0), Vector2(0, step), Vector2(0, -step)]:
			var n: Vector2 = p + d
			if not seen.has(n) and n.x > 0 and n.x < 1920 and n.y > 0 and n.y < 540 and free.call(n):
				seen[n] = true
				queue.append(n)
	check(seen.size() > 2000, "a área livre é grande (%d pontos)" % seen.size())
	check(free.call(start), "o ponto de início está livre")
	check(free.call(Lobby.screen(Lobby.ENTRANCES.door)), "o ponto de volta pela porta está livre")
	for it in lobby.interactables:
		var reachable := false
		for p: Vector2 in seen:
			var diff := it.position - p
			if Vector2(diff.x, diff.y * 1.6).length() <= it.radius * 0.85:
				reachable = true
				break
		check(reachable, "dá para chegar até %s" % it.id)
	# a porta fica no centro: uma faixa livre de um lado ao outro, em frente a ela
	var band := true
	for x in range(int(Lobby.screen(Vector2(240, 0)).x), int(Lobby.screen(Vector2(400, 0)).x), 6):
		var found := false
		for y in range(400, 530, 6):
			if seen.has(Vector2(x, y).snapped(Vector2(step, step))):
				found = true
				break
		band = band and found
	check(band, "há passagem pelo centro, em frente à porta")
	check(absf(Lobby.DOOR.x - Lobby.WIDTH / 2) < 1, "a porta está no centro do saguão")
	var door := _interactable("door")
	var diff := door.position - Lobby.screen(Lobby.ENTRANCES.start)
	check(Vector2(diff.x, diff.y * 1.6).length() > door.radius, "no começo, a porta não está em foco")


func _test_approach_and_interaction() -> void:
	print("Aproximação e interação")
	await _by(Lobby.screen(Vector2(240, 165)))
	check(lobby.focus == null, "longe de todos: nada em foco")
	lobby.interact()
	check(not lobby.busy, "interagir sem foco não faz nada")
	var shumi := _interactable("shumi")
	await _by(shumi.position + Vector2(0, 45))
	check(lobby.focus == shumi and shumi.focused, "perto da Shumi, ela fica em foco")
	lobby.interact()
	check(not lobby.busy, "sem falas, nenhuma conversa abre")
	check(not lobby.hud.dialog.is_open(), "a caixa de diálogo fica fechada")
	check("ainda não disponível" in lobby.hud.notice_text(), "aviso discreto: \"%s\"" % lobby.hud.notice_text())
	lobby.interact()
	lobby.interact()
	check(not lobby.busy, "repetir a interação não dá erro nem trava")
	var andri := _interactable("andri")
	await _by(andri.position + Vector2(0, 40))
	check(lobby.focus == andri, "perto do Andri, o foco passa para ele")
	check(not shumi.focused, "e sai da Shumi")
	# Enter de verdade, pela entrada do jogo
	var e := InputEventKey.new()
	e.keycode = KEY_ENTER
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	check("Andri" in lobby.hud.notice_text(), "Enter interage com quem está em foco")
	# requisito bloqueia com o motivo
	andri.requirement = func() -> String: return "Ainda não."
	lobby.interact()
	check(lobby.hud.notice_text() == "Ainda não.", "requisito não cumprido mostra o motivo")
	andri.requirement = Callable()


func _test_dialog() -> void:
	print("Caixa de diálogo (conteúdo de teste, fora do jogo)")
	var events: Array[String] = []
	var d := lobby.hud.dialog
	d.event.connect(func(n: String) -> void: events.append(n))
	var conversation := {"lines": [
		{"text": "um", "event": "opened"},
		{"text": "dois", "options": [{"text": "a", "event": "esc_a", "go_to": 3}, {"text": "b", "event": "esc_b"}]},
		{"text": "três"},
		{"text": "quatro"},
	]}
	lobby._occupy(true)
	d.open(conversation, "Teste", null)
	check(d.is_open() and events == ["opened"], "abre na primeira fala e avisa o evento")
	await _by(lobby.player.position)
	var before := lobby.player.position
	await _hold(KEY_RIGHT, 0.3)
	check(lobby.player.position == before, "com a conversa aberta o jogador não anda")
	d.handle_key(KEY_ENTER)
	d.handle_key(KEY_DOWN)
	d.handle_key(KEY_ENTER)
	check(events.back() == "esc_b", "resposta escolhida com ↓ e Enter")
	check(d.is_open(), "sem ir_para, segue para a fala seguinte")
	d.handle_key(KEY_ENTER)
	d.handle_key(KEY_ENTER)
	check(not d.is_open() and not lobby.busy, "a última fala encerra e libera o jogador")


func _test_door() -> void:
	print("Porta")
	var door := _interactable("door")
	await _by(Lobby.screen(Lobby.DOOR + Vector2(0, 17)))
	check(lobby.focus == door, "em frente à porta, ela fica em foco")
	var light := lobby._rune_light
	await create_timer(0.6).timeout
	check(lobby._rune_light > light, "as runas acendem com o jogador perto")
	lobby.interact()
	check(lobby.busy and lobby.player.locked, "ativar a porta trava o jogador")
	lobby.interact()
	check(lobby.focus == null, "nada mais pode ser ativado durante a entrada")
	await create_timer(1.0).timeout
	check(current_scene != null and current_scene.scene_file_path == Lobby.DUNGEON_SCENE, "a porta leva à entrada da dungeon (%s)" % (current_scene.scene_file_path if current_scene else "nothing"))
	check(Engine.get_meta(Lobby.ENTRANCE_META, "") == "door", "ao voltar, o jogador aparece na porta")

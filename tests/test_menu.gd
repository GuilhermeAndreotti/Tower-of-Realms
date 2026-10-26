extends SceneTree
## Testes do menu inicial e dos slots de save: criar, sobrescrever, carregar,
## apagar e o resumo de cada slot. Usa slots próprios (slots_prefix).
## Rodar: godot --headless --path . -s tests/test_menu.gd

var _failures := 0


func _initialize() -> void:
	_run()


func check(condition: bool, description: String) -> void:
	if condition:
		print("  ok   ", description)
	else:
		_failures += 1
		print("  FALHA ", description)


func _clear() -> void:
	for n in range(1, Progression.SLOTS + 1):
		Progression.delete_slot(n)


func _run() -> void:
	Progression.slots_prefix = "user://teste_menu"
	Progression.file = "user://teste_menu_fora.cfg"
	# a história (quem chega depois) é testada com a chave temporária de
	# todos liberados desligada
	Roster.all_unlocked = false
	_clear()

	_test_slots()
	await _test_empty_menu()
	await _test_new_game()
	await _test_overwrite()
	await _test_load()
	await _test_delete()

	_clear()
	Progression.delete()
	print("\n", "TUDO OK (0 falhas)" if _failures == 0 else "%d FALHA(S)" % _failures)
	quit(1 if _failures else 0)


func _menu() -> MainMenu:
	var m: MainMenu = (load("res://menu/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await process_frame
	return m


func _close(m: MainMenu) -> void:
	m.queue_free()
	await process_frame


func _test_slots() -> void:
	print("slots")
	check(Progression.slot_file(1) == "user://teste_menu.cfg", "slot 1 é o arquivo de sempre (save antigo abre nele)")
	check(Progression.slot_file(3) == "user://teste_menu_3.cfg", "os outros slots têm número")
	check(not Progression.any_slot(), "começa sem nenhum slot")
	var r := Progression.slot_summary(2)
	check(not r.exists, "resumo de slot vazio")

	Progression.new_game(2)
	check(Progression.slot_exists(2), "jogo novo já cria o arquivo")
	check(Progression.file == Progression.slot_file(2), "o jogo passa a salvar no slot escolhido")
	Progression.grant_xp("shumi", 250)  # nível 3
	Progression.mark_floor_cleared(1)
	Progression.unlock("andri")
	r = Progression.slot_summary(2)
	check(r.exists and r.floors == 1 and r.level == 3 and r.characters == Roster.IDS.size(), "resumo: andares, maior nível e personagens (todos, com o Andri liberado)")
	check(r.saved_at > 0, "resumo traz quando foi salvo")
	check(MainMenu.describe_slot(2).contains("Nv 3"), "texto do slot mostra o nível")

	Progression.use_slot(1)
	check(Progression.level("shumi") == 1, "trocar de slot não carrega o progresso do outro")
	Progression.use_slot(2)
	check(Progression.level("shumi") == 3 and Progression.is_unlocked("andri"), "voltar ao slot lê o progresso dele")

	Progression.new_game(2)
	check(Progression.level("shumi") == 1 and not Progression.is_unlocked("andri"), "jogo novo por cima zera o slot")
	Progression.delete_slot(2)
	check(not Progression.slot_exists(2), "apagar o slot remove o arquivo")
	check(Progression.cleared_floors().is_empty(), "apagar o slot em uso esquece o que estava em memória")


func _test_empty_menu() -> void:
	print("menu sem saves")
	var m := await _menu()
	check(m.mode == "start", "abre na tela inicial")
	check(m._load.disabled, "LOAD GAME desligado sem nenhum save")
	check(m._new.has_focus(), "foco no NEW GAME")
	m.open("load")
	m.choose_slot(1)
	check(not m._leaving and m._notice.text.contains("vazio"), "carregar slot vazio só avisa")
	await _close(m)


func _test_new_game() -> void:
	print("new game")
	var m := await _menu()
	m.open("new")
	check(m._slots[0].has_focus(), "cursor no primeiro slot vazio")
	m.choose_slot(1)
	check(m._leaving and Progression.slot_exists(1), "slot vazio: cria o jogo direto")
	check(Engine.get_meta(Lobby.ENTRANCE_META, "") == "start", "entra no saguão pelo começo")
	await _close(m)


func _test_overwrite() -> void:
	print("sobrescrever")
	Progression.use_slot(1)
	Progression.grant_xp("shumi", 100)
	var m := await _menu()
	m.open("new")
	check(m._slots[1].has_focus(), "cursor pula o slot ocupado")
	m.choose_slot(1)
	check(m.pending_confirm == "overwrite" and m._confirmation.visible, "slot ocupado pede confirmação")
	check(m._cancel_button.has_focus(), "o padrão da pergunta é cancelar")
	m.cancel()
	check(not m._leaving and Progression.slot_summary(1).level == 2, "cancelar não mexe no save")
	m.choose_slot(1)
	m.confirm()
	check(m._leaving, "confirmar começa o jogo")
	check(Progression.slot_summary(1).level == 1, "o slot foi zerado")
	await _close(m)


func _test_load() -> void:
	print("load game")
	# o slot 1 fica mais antigo (os dois seriam salvos no mesmo segundo)
	var cfg := ConfigFile.new()
	cfg.load(Progression.slot_file(1))
	cfg.set_value("jogo", "salvo_em", 1000)
	cfg.save(Progression.slot_file(1))
	Progression.new_game(3)
	Progression.grant_xp("shumi", 100)
	Progression.use_slot(2)  # outro arquivo em uso, como depois de jogar em outro slot
	var m := await _menu()
	check(not m._load.disabled, "LOAD GAME ligado com save")
	m.open("load")
	check(m._slots[2].has_focus(), "cursor no save mais recente")
	m.choose_slot(3)
	check(m._leaving and Progression.file == Progression.slot_file(3), "carregar passa a usar o slot")
	check(Progression.level("shumi") == 2, "o progresso do slot é lido")
	await _close(m)


func _test_delete() -> void:
	print("apagar")
	var m := await _menu()
	m.open("load")
	m.request_delete(2)
	check(m.pending_confirm == "", "slot vazio não pede para apagar")
	m.request_delete(3)
	check(m.pending_confirm == "delete", "slot ocupado pede confirmação para apagar")
	m.cancel()
	check(Progression.slot_exists(3), "cancelar mantém o save")
	m.request_delete(3)
	m.confirm()
	check(not Progression.slot_exists(3) and not m._leaving, "confirmar apaga e fica no menu")
	m.request_delete(1)
	m.confirm()
	check(not Progression.any_slot(), "todos apagados")
	m.open("start")
	check(m._load.disabled, "LOAD GAME desliga quando não sobra save")
	await _close(m)

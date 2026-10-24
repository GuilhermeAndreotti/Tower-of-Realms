extends SceneTree
## Testes do menu inicial e dos slots de save: criar, sobrescrever, carregar,
## apagar e o resumo de cada slot. Usa slots próprios (prefixo_slots).
## Rodar: godot --headless --path . -s testes/teste_menu.gd

var _falhas := 0


func _initialize() -> void:
	_rodar()


func checar(condicao: bool, descricao: String) -> void:
	if condicao:
		print("  ok   ", descricao)
	else:
		_falhas += 1
		print("  FALHA ", descricao)


func _limpar() -> void:
	for n in range(1, Progressao.SLOTS + 1):
		Progressao.apagar_slot(n)


func _rodar() -> void:
	Progressao.prefixo_slots = "user://teste_menu"
	Progressao.arquivo = "user://teste_menu_fora.cfg"
	# a história (quem chega depois) é testada com a chave temporária de
	# todos liberados desligada
	Elenco.todos_liberados = false
	_limpar()

	_teste_slots()
	await _teste_menu_vazio()
	await _teste_novo_jogo()
	await _teste_sobrescrever()
	await _teste_carregar()
	await _teste_apagar()

	_limpar()
	Progressao.apagar()
	print("\n", "TUDO OK (0 falhas)" if _falhas == 0 else "%d FALHA(S)" % _falhas)
	quit(1 if _falhas else 0)


func _menu() -> MenuInicial:
	var m: MenuInicial = (load("res://scenes/menu_inicial.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await process_frame
	return m


func _fechar(m: MenuInicial) -> void:
	m.queue_free()
	await process_frame


func _teste_slots() -> void:
	print("slots")
	checar(Progressao.arquivo_do_slot(1) == "user://teste_menu.cfg", "slot 1 é o arquivo de sempre (save antigo abre nele)")
	checar(Progressao.arquivo_do_slot(3) == "user://teste_menu_3.cfg", "os outros slots têm número")
	checar(not Progressao.algum_slot(), "começa sem nenhum slot")
	var r := Progressao.resumo_slot(2)
	checar(not r.existe, "resumo de slot vazio")

	Progressao.novo_jogo(2)
	checar(Progressao.slot_existe(2), "jogo novo já cria o arquivo")
	checar(Progressao.arquivo == Progressao.arquivo_do_slot(2), "o jogo passa a salvar no slot escolhido")
	Progressao.conceder_xp("shumi", 250)  # nível 3
	Progressao.marcar_andar_vencido(1)
	Progressao.desbloquear("andri")
	r = Progressao.resumo_slot(2)
	checar(r.existe and r.andares == 1 and r.nivel == 3 and r.personagens == 3, "resumo: andares, maior nível e personagens")
	checar(r.salvo_em > 0, "resumo traz quando foi salvo")
	checar(MenuInicial.descrever_slot(2).contains("Nv 3"), "texto do slot mostra o nível")

	Progressao.usar_slot(1)
	checar(Progressao.nivel("shumi") == 1, "trocar de slot não carrega o progresso do outro")
	Progressao.usar_slot(2)
	checar(Progressao.nivel("shumi") == 3 and Progressao.desbloqueado("andri"), "voltar ao slot lê o progresso dele")

	Progressao.novo_jogo(2)
	checar(Progressao.nivel("shumi") == 1 and not Progressao.desbloqueado("andri"), "jogo novo por cima zera o slot")
	Progressao.apagar_slot(2)
	checar(not Progressao.slot_existe(2), "apagar o slot remove o arquivo")
	checar(Progressao.andares_vencidos().is_empty(), "apagar o slot em uso esquece o que estava em memória")


func _teste_menu_vazio() -> void:
	print("menu sem saves")
	var m := await _menu()
	checar(m.modo == "inicio", "abre na tela inicial")
	checar(m._carregar.disabled, "LOAD GAME desligado sem nenhum save")
	checar(m._novo.has_focus(), "foco no NEW GAME")
	m.abrir("carregar")
	m.escolher_slot(1)
	checar(not m._saindo and m._aviso.text.contains("vazio"), "carregar slot vazio só avisa")
	await _fechar(m)


func _teste_novo_jogo() -> void:
	print("new game")
	var m := await _menu()
	m.abrir("novo")
	checar(m._slots[0].has_focus(), "cursor no primeiro slot vazio")
	m.escolher_slot(1)
	checar(m._saindo and Progressao.slot_existe(1), "slot vazio: cria o jogo direto")
	checar(Engine.get_meta(Lobby.META_ENTRADA, "") == "inicio", "entra no saguão pelo começo")
	await _fechar(m)


func _teste_sobrescrever() -> void:
	print("sobrescrever")
	Progressao.usar_slot(1)
	Progressao.conceder_xp("shumi", 100)
	var m := await _menu()
	m.abrir("novo")
	checar(m._slots[1].has_focus(), "cursor pula o slot ocupado")
	m.escolher_slot(1)
	checar(m.pedido == "sobrescrever" and m._confirmacao.visible, "slot ocupado pede confirmação")
	checar(m._nao.has_focus(), "o padrão da pergunta é cancelar")
	m.cancelar()
	checar(not m._saindo and Progressao.resumo_slot(1).nivel == 2, "cancelar não mexe no save")
	m.escolher_slot(1)
	m.confirmar()
	checar(m._saindo, "confirmar começa o jogo")
	checar(Progressao.resumo_slot(1).nivel == 1, "o slot foi zerado")
	await _fechar(m)


func _teste_carregar() -> void:
	print("load game")
	# o slot 1 fica mais antigo (os dois seriam salvos no mesmo segundo)
	var cfg := ConfigFile.new()
	cfg.load(Progressao.arquivo_do_slot(1))
	cfg.set_value("jogo", "salvo_em", 1000)
	cfg.save(Progressao.arquivo_do_slot(1))
	Progressao.novo_jogo(3)
	Progressao.conceder_xp("shumi", 100)
	Progressao.usar_slot(2)  # outro arquivo em uso, como depois de jogar em outro slot
	var m := await _menu()
	checar(not m._carregar.disabled, "LOAD GAME ligado com save")
	m.abrir("carregar")
	checar(m._slots[2].has_focus(), "cursor no save mais recente")
	m.escolher_slot(3)
	checar(m._saindo and Progressao.arquivo == Progressao.arquivo_do_slot(3), "carregar passa a usar o slot")
	checar(Progressao.nivel("shumi") == 2, "o progresso do slot é lido")
	await _fechar(m)


func _teste_apagar() -> void:
	print("apagar")
	var m := await _menu()
	m.abrir("carregar")
	m.pedir_apagar(2)
	checar(m.pedido == "", "slot vazio não pede para apagar")
	m.pedir_apagar(3)
	checar(m.pedido == "apagar", "slot ocupado pede confirmação para apagar")
	m.cancelar()
	checar(Progressao.slot_existe(3), "cancelar mantém o save")
	m.pedir_apagar(3)
	m.confirmar()
	checar(not Progressao.slot_existe(3) and not m._saindo, "confirmar apaga e fica no menu")
	m.pedir_apagar(1)
	m.confirmar()
	checar(not Progressao.algum_slot(), "todos apagados")
	m.abrir("inicio")
	checar(m._carregar.disabled, "LOAD GAME desliga quando não sobra save")
	await _fechar(m)

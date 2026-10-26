extends SceneTree
## Testes da subida da Torre: andares, liberação, repetição, eventos de
## história (Andri no fim do andar 2), escolha do andar e a apresentação no
## saguão. Monta as cenas de verdade.
## Rodar: godot --headless --path . -s testes/teste_torre.gd

var _falhas := 0


func _initialize() -> void:
	_rodar()


func checar(condicao: bool, descricao: String) -> void:
	if condicao:
		print("  ok   ", descricao)
	else:
		_falhas += 1
		printerr("  FALHOU ", descricao)


func _rodar() -> void:
	Progressao.arquivo = "user://teste_torre.cfg"
	# a história (quem chega depois) é testada com a chave temporária de
	# todos liberados desligada
	Elenco.todos_liberados = false
	Progressao.apagar()

	_teste_cadastro()
	_teste_liberacao()
	_teste_concluir()
	_teste_eventos()
	_teste_todos_liberados()
	await _teste_batalha_andar_1()
	await _teste_batalha_andar_2()
	await _teste_repetir_andar_2()
	await _teste_derrota_volta()
	await _teste_selecao_andar()
	await _teste_selecao_equipe()
	await _teste_saguao_apresenta()
	await _teste_saguao_evento_de_fala()

	Progressao.apagar()
	print("\n%s (%d falha%s)" % ["TUDO OK" if _falhas == 0 else "FALHOU", _falhas, "" if _falhas == 1 else "s"])
	quit(1 if _falhas else 0)


func _abrir(cena: String) -> Node:
	var n: Node = (load(cena) as PackedScene).instantiate()
	root.add_child(n)
	current_scene = n
	await process_frame
	return n


func _fechar(n: Node) -> void:
	n.queue_free()
	await process_frame


## Aperta `tecla` na tela de fim e confere que a batalha virou o saguão.
func _confirmar_volta(b: Batalha, tecla: Key, descricao: String) -> void:
	var ev := InputEventKey.new()
	ev.keycode = tecla
	ev.pressed = true
	b._unhandled_input(ev)
	b._unhandled_input(ev)  # repetido: não troca de cena duas vezes
	await process_frame
	await process_frame
	checar(current_scene != null and current_scene.scene_file_path == Batalha.CENA_SAGUAO
		and Engine.get_meta(Lobby.META_ENTRADA, "") == "porta", descricao)
	if current_scene:
		await _fechar(current_scene)


func _vencer(b: Batalha) -> void:
	for ini in b.inimigos:
		ini.hp = 0
	b._verificar_fim()


# ------------------------------------------------------------------ regras
func _teste_cadastro() -> void:
	print("cadastro dos andares")
	checar(Andares.total() == 5, "5 andares")
	var ok := true
	for n in range(1, Andares.total() + 1):
		var d := Andares.dados(n)
		ok = ok and d.nome != "" and d.inimigos.size() >= 1 and d.inimigos.size() <= Batalha.POSICOES_INIMIGOS.size()
		ok = ok and Andares.criar_inimigos(n).size() == d.inimigos.size()
		for e: Dictionary in d.get("ao_vencer", []):
			ok = ok and e.tipo in ["desbloquear", "conversa"]
	checar(ok, "todo andar tem nome, de 1 a 3 inimigos e eventos válidos")
	checar(Andares.max_equipe(1) == 1 and Andares.max_equipe(2) == 1 and Andares.max_equipe(3) == 2 and Andares.max_equipe(4) == 2
		and Andares.max_equipe(5) == 3, "equipe: 1, 1, 2, 2, 3")
	var xps: Array = range(1, 6).map(func(n: int) -> int: return Progressao.xp_da_batalha(Andares.criar_inimigos(n)))
	checar(xps == [150, 350, 600, 900, 1000], "XP por andar: 150, 350, 600, 900, 1000")
	var chefe := Andares.criar_inimigos(4)[1]
	checar(chefe.nome == "Guardião Sombrio" and chefe.tipo == Tipos.TREVAS and chefe.golpe_pesado_a_cada == 2, "andar 4 tem o chefe de Trevas")
	var forja := Andares.criar_inimigos(5)
	checar(forja[1].nome == "Golem de Pedra" and forja[1].hp_max > forja[0].hp_max * 3 and forja[0].tipo == Tipos.FOGO and forja[2].tipo == Tipos.FOGO,
		"andar 5: Golem de Pedra como chefe e dois Elementais de Fogo")
	checar(forja.all(func(i: Inimigo) -> bool: return i.ultimo_recurso.get("nome", "") == "Ferro Negro"), "todos do andar 5 têm o Ferro Negro")
	checar(range(1, 5).all(func(n: int) -> bool: return Andares.criar_inimigos(n).all(func(i: Inimigo) -> bool: return i.ultimo_recurso.is_empty())),
		"os andares 1 a 4 não têm último recurso")
	# ritmo: sem repetir nada, as primeiras vitórias levam ao recomendado do andar seguinte
	var total := 0
	var ritmo := true
	for n in range(1, Andares.total()):
		total += xps[n - 1]
		var p := Progressao.somar_xp(1, 0, total)
		ritmo = ritmo and p.nivel == Andares.dados(n + 1).nivel_recomendado
	checar(ritmo, "sem repetir andares, chega-se a cada andar no nível recomendado")
	var folga := true
	for n in range(1, Andares.total() + 1):
		folga = folga and Andares.limite_do_andar(n) > Andares.dados(n).nivel_recomendado
	checar(folga, "o limite de cada andar fica acima do recomendado (há espaço para treinar)")
	# os tipos tiram o x2 automático do Andri onde importa
	var sem_x2 := func(ini: Inimigo) -> bool:
		return Andri.LENTES.all(func(t: String) -> bool: return Tipos.efetividade(t, ini.tipo) < Tipos.SUPER)
	checar(sem_x2.call(Andares.criar_inimigos(3)[1]) and sem_x2.call(chefe), "o Guardião do 3 e o chefe não são fracos a nenhuma lente")
	checar(Andares.dados(2).ao_vencer == [{"tipo": "desbloquear", "id": "andri"}], "o Andri chega no fim do andar 2")


func _teste_liberacao() -> void:
	print("liberação")
	Progressao.apagar()
	checar(Andares.liberado(1) and not Andares.liberado(2) and not Andares.liberado(5) and not Andares.liberado(0), "jogo novo: só o andar 1")
	checar(Andares.atual() == 1 and Andares.mais_alto_liberado() == 1, "o andar atual é o 1")
	Andares.escolher(3)
	checar(Andares.atual() == 1, "não dá para escolher andar trancado")
	Progressao.marcar_andar_vencido(1)
	checar(Andares.liberado(2) and not Andares.liberado(3) and Andares.mais_alto_liberado() == 2, "vencer o 1 libera o 2")
	Andares.escolher(2)
	checar(Andares.atual() == 2, "o andar escolhido fica salvo")
	Andares.escolher(1)
	checar(Andares.atual() == 1, "dá para voltar a um andar vencido")
	checar("andri" not in Elenco.disponiveis() and "askara" in Elenco.disponiveis(), "o Andri ainda não está na Torre; a Askara já")


func _teste_concluir() -> void:
	print("concluir andar")
	Progressao.apagar()
	var c := Andares.concluir(1)
	checar(c.primeira and c.liberou == 2 and c.eventos.is_empty(), "andar 1: primeira vitória, libera o 2, sem história")
	c = Andares.concluir(1)
	checar(not c.primeira and c.liberou == 0, "repetir o 1: nada novo")
	Progressao.conceder_xp("shumi", 260)  # Shumi no 3
	Elenco.definir_equipe(["shumi"])
	c = Andares.concluir(2)
	checar(c.primeira and c.eventos.size() == 1 and "andri" in Elenco.disponiveis(), "andar 2: o Andri chega")
	checar(Progressao.nivel("andri") == 3 and Progressao.progresso("andri").xp == 0, "ele entra no nível da equipe (3) com 0 XP")
	checar(Progressao.eventos_pendentes() == [{"tipo": "desbloquear", "id": "andri"}], "a chegada fica pendente para o saguão")
	c = Andares.concluir(2)
	checar(not c.primeira and c.eventos.is_empty() and Progressao.eventos_pendentes().size() == 1, "repetir o 2 não repete a história")
	Andares.concluir(3)
	c = Andares.concluir(4)
	checar(c.primeira and c.liberou == 5 and c.limite_depois == 11, "vencer o 4 libera o 5 (limite 11)")
	c = Andares.concluir(5)
	checar(c.primeira and c.liberou == 0, "o andar 5 é o último")
	Progressao.recarregar()
	checar(Progressao.andares_vencidos() == [1, 2, 3, 4, 5] and Progressao.eventos_pendentes().size() == 1, "andares e pendências voltam do arquivo")


func _teste_eventos() -> void:
	print("eventos")
	checar(Eventos.de_texto("desbloquear:andri") == {"tipo": "desbloquear", "id": "andri"}, "fala com \"desbloquear:andri\" vira evento")
	checar(Eventos.de_texto("conversa:chegada") == {"tipo": "conversa", "id": "chegada"}, "fala com \"conversa:id\" vira evento")
	checar(Eventos.de_texto("piscar").is_empty() and Eventos.de_texto("outra:coisa").is_empty(), "outros textos não são eventos")
	checar(Eventos.resumo({"tipo": "desbloquear", "id": "andri"}).begins_with("Andri Findavil chegou"), "resumo da chegada para a tela de vitória")
	checar(Eventos.resumo({"tipo": "conversa", "id": "x"}) == "", "conversa não aparece na tela de vitória")
	Progressao.apagar()
	Progressao.adicionar_eventos_pendentes([{"tipo": "conversa", "id": "a"}, {"tipo": "conversa", "id": "b"}])
	Progressao.tirar_evento_pendente()
	checar(Progressao.eventos_pendentes() == [{"tipo": "conversa", "id": "b"}], "pendentes saem na ordem")


# ---------------------------------------------------------------- batalha
func _teste_batalha_andar_1() -> void:
	print("batalha: andar 1")
	Progressao.apagar()
	Elenco.definir_equipe(["shumi"])
	var b: Batalha = await _abrir("res://scenes/batalha.tscn")
	checar(b.andar == 1 and b.inimigos.size() == 2 and b.inimigos[0].hp_max == 420, "o andar 1 traz as duas sentinelas dele")
	await _vencer(b)
	checar(b.conclusao.primeira and b.conclusao.liberou == 2, "vencer libera o andar 2")
	checar(Progressao.progresso("shumi") == {"nivel": 2, "xp": 50}, "Shumi: 150 XP, nível 2")
	checar(b.conclusao.limite_antes == 3 and b.conclusao.limite_depois == 5 and "Limite de nível: 3 → 5" in b.hud._fim_extras.get_child(1).text,
		"a tela de vitória avisa que o limite subiu")
	checar(not b.hud._fim_extras.get_child(0).text.is_empty() and "Andar 2" in b.hud._fim_extras.get_child(0).text,
		"a tela de vitória avisa o andar liberado")
	await _confirmar_volta(b, KEY_ENTER, "depois da vitória, Enter volta ao saguão")


func _teste_batalha_andar_2() -> void:
	print("batalha: andar 2 (o Andri chega)")
	Andares.escolher(2)
	Elenco.definir_equipe(["shumi"])
	var b: Batalha = await _abrir("res://scenes/batalha.tscn")
	checar(b.andar == 2 and b.equipe.size() == 1, "andar 2, só com a Shumi")
	await _vencer(b)
	# 150 + 350 = 500: nível 4 (450) com 50
	checar(Progressao.progresso("shumi") == {"nivel": 4, "xp": 50}, "Shumi: nível 4")
	checar("andri" in Elenco.disponiveis() and Progressao.nivel("andri") == 4, "o Andri chega no nível que a Shumi tem depois da luta (4)")
	var textos: Array = b.hud._fim_extras.get_children().map(func(l: Label) -> String: return l.text)
	checar(textos.size() == 3 and "Andri Findavil chegou" in textos[2], "a tela de vitória anuncia a chegada")
	await _fechar(b)


func _teste_derrota_volta() -> void:
	print("derrota")
	Andares.escolher(1)
	var b: Batalha = await _abrir("res://scenes/batalha.tscn")
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.pressed = true
	b._unhandled_input(ev)
	await process_frame
	checar(current_scene == b, "durante a luta, Enter não sai da batalha")
	for c in b.equipe:
		c.hp = 0
	b._verificar_fim()
	checar(b.acabou and not b.hud._fim_extras.visible, "derrota: sem andar liberado nem história")
	await _confirmar_volta(b, KEY_ESCAPE, "depois da derrota, Esc também volta ao saguão")


func _teste_repetir_andar_2() -> void:
	print("repetir andar")
	Andares.escolher(2)
	Elenco.definir_equipe(["shumi", "andri"])
	var b: Batalha = await _abrir("res://scenes/batalha.tscn")
	checar(b.equipe.size() == 1, "a batalha respeita o limite do andar mesmo com equipe maior salva")
	var pendentes := Progressao.eventos_pendentes().size()
	await _vencer(b)
	checar(not b.conclusao.primeira and b.recompensas[0].participou and b.recompensas[0].xp == 350, "repetir dá a XP de novo")
	checar(b.recompensas.size() == Elenco.disponiveis().size() and not b.recompensas[1].participou,
		"o Andri, de fora (o andar só aceita 1), também ganha")
	checar(Progressao.eventos_pendentes().size() == pendentes and b.hud._fim_extras.get_child_count() == 0, "e não repete a história")
	await _fechar(b)


# ------------------------------------------------------------------ telas
func _teste_selecao_andar() -> void:
	print("escolha do andar")
	Progressao.apagar()
	Progressao.marcar_andar_vencido(1)
	var t: SelecaoAndar = await _abrir("res://scenes/selecao_andar.tscn")
	checar(t.cursor == 2, "o cursor começa no andar mais alto liberado")
	checar(SelecaoAndar.situacao(1) == "vencido" and SelecaoAndar.situacao(2) == "novo" and SelecaoAndar.situacao(3) == "trancado",
		"andares vencido, novo e trancado")
	t.cursor = 3
	t._atualizar()
	checar(t._botao.disabled, "trancado: botão desligado")
	t.subir()
	checar(current_scene == t and "trancado" in t._aviso.text, "Enter num trancado só avisa")
	t.cursor = 1
	t._atualizar()
	t.subir()
	await process_frame
	await process_frame
	checar(current_scene != null and current_scene.scene_file_path == SelecaoAndar.CENA_EQUIPE, "subir leva à montagem da equipe")
	checar(Progressao.andar_escolhido() == 1, "e salva o andar escolhido")
	await _fechar(current_scene)


func _teste_selecao_equipe() -> void:
	print("montagem da equipe")
	Progressao.apagar()
	Progressao.desbloquear("andri")
	Elenco.definir_equipe(["shumi", "andri"])
	var s: SelecaoEquipe = await _abrir("res://scenes/selecao_equipe.tscn")
	checar(s._max == 1 and s.equipe == ["shumi"], "andar 1: uma vaga; a equipe salva é cortada")
	s.alternar("andri")
	checar(s.equipe == ["shumi"], "não passa do limite do andar")
	await _fechar(s)
	for n in [1, 2]:
		Progressao.marcar_andar_vencido(n)
	Andares.escolher(3)
	s = await _abrir("res://scenes/selecao_equipe.tscn")
	checar(s._max == 2 and s.equipe == ["shumi", "andri"], "andar 3: duas vagas, a equipe salva volta inteira")
	await _fechar(s)


func _teste_saguao_apresenta() -> void:
	print("saguão apresenta a chegada")
	Progressao.apagar()
	Elenco.definir_equipe(["shumi"])
	Progressao.marcar_andar_vencido(1)
	Andares.concluir(2)
	var l: Lobby = await _abrir("res://scenes/lobby.tscn")
	checar(l._visuais.has("andri") and l._visuais.andri.modulate.a == 0.0, "o Andri começa escondido")
	checar(l.ocupado and l.jogador.travado, "o jogador fica parado durante a apresentação")
	await create_timer(1.0).timeout
	checar(l._visuais.andri.modulate.a > 0.0 and "Andri Findavil chegou" in l.hud.texto_anuncio(), "ele surge com o anúncio")
	await create_timer(2.5).timeout
	checar(Progressao.eventos_pendentes().is_empty() and not l.ocupado, "acabada a apresentação, sai da fila e libera o jogador")
	await _fechar(l)
	l = await _abrir("res://scenes/lobby.tscn")
	await create_timer(0.7).timeout
	checar(l._visuais.andri.modulate.a == 1.0 and not l.ocupado, "na volta seguinte, ele já está lá, sem repetir")
	await _fechar(l)


func _teste_saguao_evento_de_fala() -> void:
	print("evento numa fala")
	Progressao.apagar()
	var l: Lobby = await _abrir("res://scenes/lobby.tscn")
	await create_timer(0.7).timeout
	checar(not l._visuais.has("andri"), "jogo novo: o Andri não está no saguão")
	var conversa := {"falas": [{"texto": "Chegou alguém.", "evento": "desbloquear:andri"}, {"texto": "Fim."}]}
	l._ocupar(true)
	l.hud.dialogo.abrir(conversa, "Teste", null)
	checar("andri" in Elenco.disponiveis(), "a fala com evento libera na hora")
	l.hud.dialogo.teclar(KEY_ENTER)
	l.hud.dialogo.teclar(KEY_ENTER)
	await process_frame
	checar(l._visuais.has("andri"), "ao fim da conversa, ele surge no saguão")
	await create_timer(2.6).timeout
	checar(Progressao.eventos_pendentes().is_empty() and not l.ocupado, "e o jogador volta a andar")
	await _fechar(l)


func _teste_todos_liberados() -> void:
	print("todos liberados (chave temporária)")
	Progressao.apagar()
	Elenco.todos_liberados = true
	checar(Elenco.disponiveis() == Elenco.IDS, "com a chave ligada, todos começam liberados")
	Progressao.marcar_andar_vencido(1)
	var c := Andares.concluir(2)
	checar(c.primeira and c.eventos.is_empty() and Progressao.eventos_pendentes().is_empty(),
		"a chegada de quem já está liberado não vira evento nem apresentação")
	Elenco.todos_liberados = false
	Progressao.apagar()

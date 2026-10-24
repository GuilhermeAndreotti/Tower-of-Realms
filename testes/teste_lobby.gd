extends SceneTree
## Testes do saguão: monta a cena de verdade, anda com teclas simuladas e
## confere colisão, alcance, interações e a porta.
## Rodar: godot --headless --path . -s testes/teste_lobby.gd

var _falhas := 0
var lobby: Lobby


func _initialize() -> void:
	_rodar()


func checar(condicao: bool, descricao: String) -> void:
	if condicao:
		print("  ok   ", descricao)
	else:
		_falhas += 1
		print("  FALHA ", descricao)


func _rodar() -> void:
	Progressao.arquivo = "user://teste_lobby_progresso.cfg"
	# a história (quem chega depois) é testada com a chave temporária de
	# todos liberados desligada
	Elenco.todos_liberados = false
	Progressao.apagar()
	Progressao.desbloquear("andri")  # o saguão completo (a chegada é testada em teste_torre)
	Engine.remove_meta(Lobby.META_ENTRADA) if Engine.has_meta(Lobby.META_ENTRADA) else null
	lobby = (load("res://scenes/lobby.tscn") as PackedScene).instantiate()
	root.add_child(lobby)
	current_scene = lobby
	await _quadros(3)

	_teste_montagem()
	await _teste_paredes()
	await _teste_moveis()
	_teste_caminhos()
	await _teste_aproximacao_e_interacao()
	await _teste_dialogo()
	await _teste_porta()
	Progressao.apagar()

	print("\n%s (%d falha%s)" % ["TUDO OK" if _falhas == 0 else "FALHOU", _falhas, "" if _falhas == 1 else "s"])
	quit(1 if _falhas else 0)


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame
	await process_frame


func _segurar(tecla: Key, segundos: float) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = tecla
	e.keycode = tecla
	e.pressed = true
	Input.parse_input_event(e)
	await create_timer(segundos).timeout
	var s := e.duplicate()
	s.pressed = false
	Input.parse_input_event(s)
	await _quadros(2)


func _por(p_tela: Vector2) -> void:
	lobby.jogador.position = p_tela
	lobby.jogador.reset_physics_interpolation()
	await _quadros(2)


func _interagivel(id: String) -> Interagivel:
	for it in lobby.interagiveis:
		if it.id == id:
			return it
	return null


# ------------------------------------------------------------------ testes
func _teste_montagem() -> void:
	print("Montagem")
	checar(lobby.jogador.id == "caoimhe", "quem anda pelo saguão é a Caoimhe")
	checar(lobby.jogador.position == Lobby.tela(Lobby.ENTRADAS.inicio), "ela começa no centro do tapete")
	var ids := lobby.interagiveis.map(func(it: Interagivel) -> String: return it.id)
	for id in Elenco.IDS:
		checar(id in ids, "%s está no saguão" % Elenco.dados(id).nome)
	checar("caoimhe" not in ids, "a Caoimhe não aparece de novo como personagem parada")
	checar("porta" in ids, "a porta da dungeon é interagível")
	checar(_interagivel("shumi").nome == "Shumi" and _interagivel("shumi").retrato != null, "personagens têm nome e retrato")
	# o quadro parado dela é o sprite original, sem mudanças
	var frames := VisualLutador.carregar_frames(Lobby.CAOIMHE.sprite.png, Lobby.CAOIMHE.sprite.json)
	var q: AtlasTexture = frames.get_frame_texture("idle", 0)
	var folha := Image.load_from_file(ProjectSettings.globalize_path(Lobby.CAOIMHE.sprite.png))
	var quadro := folha.get_region(Rect2i(q.region)).get_region(Rect2i(2, 3, 26, 36))
	var original := Image.load_from_file(ProjectSettings.globalize_path("res://personagens/caoimhe/caoimhe.png"))
	original.convert(quadro.get_format())
	checar(quadro.get_data() == original.get_data(), "o quadro parado da Caoimhe é idêntico ao sprite original")
	# personagens espalhados, não em fila nem amontoados
	var pos := lobby.interagiveis.filter(func(it: Interagivel) -> bool: return it.id != "porta").map(func(it: Interagivel) -> Vector2: return it.position)
	var ok := true
	for i in pos.size():
		for j in range(i + 1, pos.size()):
			if pos[i].distance_to(pos[j]) < 150:
				ok = false
	checar(ok, "personagens a mais de 150px uns dos outros")


func _teste_paredes() -> void:
	print("Paredes")
	await _por(Lobby.tela(Vector2(240, 140)))
	await _segurar(KEY_UP, 1.5)
	var y := lobby.jogador.position.y
	checar(y >= Lobby.LIMITE_FUNDO * Lobby.ESCALA - 1, "não atravessa a parede do fundo (y=%d)" % y)
	checar(y <= Lobby.LIMITE_FUNDO * Lobby.ESCALA + 15, "chega até a parede do fundo")
	await _segurar(KEY_DOWN, 2.0)
	checar(lobby.jogador.position.y <= Lobby.LIMITE_FRENTE * Lobby.ESCALA + 1, "não sai pela frente da tela")
	await _por(Lobby.tela(Vector2(40, 170)))
	await _segurar(KEY_A, 1.0)
	checar(lobby.jogador.position.x >= Lobby.LIMITE_LADOS * Lobby.ESCALA - 1, "não sai pela esquerda (WASD também anda)")
	checar(lobby.jogador.visual.get_child(0).scale.x < 0, "vira o sprite ao andar para a esquerda")
	await _segurar(KEY_D, 0.3)
	checar(lobby.jogador.visual.get_child(0).scale.x > 0, "e desvira ao andar para a direita")


func _teste_moveis() -> void:
	print("Móveis")
	# à esquerda da mesa grande, na altura da base dela, andando para a direita
	var mesa := Lobby.tela(Vector2(72, 141))
	await _por(mesa + Vector2(-110, -6))
	await _segurar(KEY_RIGHT, 1.2)
	var borda := mesa.x - 22 * Lobby.ESCALA - Lobby.PES.x / 2
	checar(lobby.jogador.position.x <= borda + 1, "a mesa bloqueia (x=%d, borda=%d)" % [lobby.jogador.position.x, borda])
	# e não trava o jogador: dá para contornar por baixo
	await _segurar(KEY_DOWN, 0.6)
	await _segurar(KEY_RIGHT, 1.2)
	checar(lobby.jogador.position.x > mesa.x + 40, "contorna a mesa pela frente")


## Busca em largura numa grade de 6px pelos lugares onde os pés cabem,
## a partir da entrada: cada interagível precisa ter um ponto alcançável
## dentro do raio dele.
func _teste_caminhos() -> void:
	print("Caminhos")
	var espaco := lobby.get_world_2d().direct_space_state
	var forma := RectangleShape2D.new()
	forma.size = JogadorLobby.PES
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.exclude = [lobby.jogador.get_rid()]
	var livre := func(p: Vector2) -> bool:
		consulta.transform = Transform2D(0, p + Vector2(0, -forma.size.y / 2))
		return espaco.intersect_shape(consulta, 1).is_empty()
	var passo := 6.0
	var inicio := Lobby.tela(Lobby.ENTRADAS.inicio).snapped(Vector2(passo, passo))
	var visto := {inicio: true}
	var fila := [inicio]
	while not fila.is_empty():
		var p: Vector2 = fila.pop_front()
		for d in [Vector2(passo, 0), Vector2(-passo, 0), Vector2(0, passo), Vector2(0, -passo)]:
			var n: Vector2 = p + d
			if not visto.has(n) and n.x > 0 and n.x < 1920 and n.y > 0 and n.y < 540 and livre.call(n):
				visto[n] = true
				fila.append(n)
	checar(visto.size() > 2000, "a área livre é grande (%d pontos)" % visto.size())
	checar(livre.call(inicio), "o ponto de início está livre")
	checar(livre.call(Lobby.tela(Lobby.ENTRADAS.porta)), "o ponto de volta pela porta está livre")
	for it in lobby.interagiveis:
		var alcancavel := false
		for p: Vector2 in visto:
			var dif := it.position - p
			if Vector2(dif.x, dif.y * 1.6).length() <= it.raio * 0.85:
				alcancavel = true
				break
		checar(alcancavel, "dá para chegar até %s" % it.id)
	# a porta fica no centro: uma faixa livre de um lado ao outro, em frente a ela
	var faixa := true
	for x in range(int(Lobby.tela(Vector2(240, 0)).x), int(Lobby.tela(Vector2(400, 0)).x), 6):
		var achou := false
		for y in range(400, 530, 6):
			if visto.has(Vector2(x, y).snapped(Vector2(passo, passo))):
				achou = true
				break
		faixa = faixa and achou
	checar(faixa, "há passagem pelo centro, em frente à porta")
	checar(absf(Lobby.PORTA.x - Lobby.LARGURA / 2) < 1, "a porta está no centro do saguão")
	var porta := _interagivel("porta")
	var dif := porta.position - Lobby.tela(Lobby.ENTRADAS.inicio)
	checar(Vector2(dif.x, dif.y * 1.6).length() > porta.raio, "no começo, a porta não está em foco")


func _teste_aproximacao_e_interacao() -> void:
	print("Aproximação e interação")
	await _por(Lobby.tela(Vector2(240, 165)))
	checar(lobby.foco == null, "longe de todos: nada em foco")
	lobby.interagir()
	checar(not lobby.ocupado, "interagir sem foco não faz nada")
	var shumi := _interagivel("shumi")
	await _por(shumi.position + Vector2(0, 45))
	checar(lobby.foco == shumi and shumi.em_foco, "perto da Shumi, ela fica em foco")
	lobby.interagir()
	checar(not lobby.ocupado, "sem falas, nenhuma conversa abre")
	checar(not lobby.hud.dialogo.aberta(), "a caixa de diálogo fica fechada")
	checar("ainda não disponível" in lobby.hud.texto_aviso(), "aviso discreto: \"%s\"" % lobby.hud.texto_aviso())
	lobby.interagir()
	lobby.interagir()
	checar(not lobby.ocupado, "repetir a interação não dá erro nem trava")
	var andri := _interagivel("andri")
	await _por(andri.position + Vector2(0, 40))
	checar(lobby.foco == andri, "perto do Andri, o foco passa para ele")
	checar(not shumi.em_foco, "e sai da Shumi")
	# Enter de verdade, pela entrada do jogo
	var e := InputEventKey.new()
	e.keycode = KEY_ENTER
	e.pressed = true
	Input.parse_input_event(e)
	await _quadros(2)
	checar("Andri" in lobby.hud.texto_aviso(), "Enter interage com quem está em foco")
	# requisito bloqueia com o motivo
	andri.requisito = func() -> String: return "Ainda não."
	lobby.interagir()
	checar(lobby.hud.texto_aviso() == "Ainda não.", "requisito não cumprido mostra o motivo")
	andri.requisito = Callable()


func _teste_dialogo() -> void:
	print("Caixa de diálogo (conteúdo de teste, fora do jogo)")
	var eventos: Array[String] = []
	var d := lobby.hud.dialogo
	d.evento.connect(func(n: String) -> void: eventos.append(n))
	var conversa := {"falas": [
		{"texto": "um", "evento": "abriu"},
		{"texto": "dois", "opcoes": [{"texto": "a", "evento": "esc_a", "ir_para": 3}, {"texto": "b", "evento": "esc_b"}]},
		{"texto": "três"},
		{"texto": "quatro"},
	]}
	lobby._ocupar(true)
	d.abrir(conversa, "Teste", null)
	checar(d.aberta() and eventos == ["abriu"], "abre na primeira fala e avisa o evento")
	await _por(lobby.jogador.position)
	var antes := lobby.jogador.position
	await _segurar(KEY_RIGHT, 0.3)
	checar(lobby.jogador.position == antes, "com a conversa aberta o jogador não anda")
	d.teclar(KEY_ENTER)
	d.teclar(KEY_DOWN)
	d.teclar(KEY_ENTER)
	checar(eventos.back() == "esc_b", "resposta escolhida com ↓ e Enter")
	checar(d.aberta(), "sem ir_para, segue para a fala seguinte")
	d.teclar(KEY_ENTER)
	d.teclar(KEY_ENTER)
	checar(not d.aberta() and not lobby.ocupado, "a última fala encerra e libera o jogador")


func _teste_porta() -> void:
	print("Porta")
	var porta := _interagivel("porta")
	await _por(Lobby.tela(Lobby.PORTA + Vector2(0, 17)))
	checar(lobby.foco == porta, "em frente à porta, ela fica em foco")
	var luz := lobby._luz_runas
	await create_timer(0.6).timeout
	checar(lobby._luz_runas > luz, "as runas acendem com o jogador perto")
	lobby.interagir()
	checar(lobby.ocupado and lobby.jogador.travado, "ativar a porta trava o jogador")
	lobby.interagir()
	checar(lobby.foco == null, "nada mais pode ser ativado durante a entrada")
	await create_timer(1.0).timeout
	checar(current_scene != null and current_scene.scene_file_path == Lobby.CENA_DUNGEON, "a porta leva à entrada da dungeon (%s)" % (current_scene.scene_file_path if current_scene else "nada"))
	checar(Engine.get_meta(Lobby.META_ENTRADA, "") == "porta", "ao voltar, o jogador aparece na porta")

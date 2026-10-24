class_name Lobby
extends Node2D
## Saguão da Torre: a zona segura de onde se sobe para a dungeon. O jogador
## anda livre com a Caoimhe (JogadorLobby), aborda os personagens do Elenco
## e a porta (Interagivel) e entra na dungeon pela porta.
## As coordenadas das constantes estão em pixels do fundo (640x180, ×3 na
## tela), as mesmas de ferramentas/gerar_lobby.py, que gera a arte.
## Para pôr alguém novo no saguão: um lugar em LUGARES (sem lugar, ele usa
## um dos LUGARES_LIVRES) e, quando houver falas, a conversa em Conversas.
## Só aparece quem está liberado (Elenco.disponiveis()). Ao chegar, o saguão
## apresenta os eventos de história pendentes (Eventos), na ordem: quem
## chegou à Torre surge com destaque e as conversas de história abrem.

const ESCALA := 3.0
const PASTA := "res://cenarios/lobby/"
## A porta leva à escolha do andar (depois, a equipe e a batalha).
const CENA_DUNGEON := "res://scenes/selecao_andar.tscn"
const CENA_MENU := "res://scenes/menu_inicial.tscn"
## De onde o jogador chega ("porta" ao voltar da dungeon). Fica no Engine,
## como a equipe do Elenco, para sobreviver à troca de cena.
const META_ENTRADA := "torre_saguao_entrada"

const LARGURA := 640.0
const ALTURA := 180.0
## Faixa onde os pés podem ficar: do rodapé da parede até a borda da tela.
const LIMITE_FUNDO := 112.0
const LIMITE_FRENTE := 177.0
const LIMITE_LADOS := 8.0
const PES := Vector2(24, 9)  ## colisão dos pés dos personagens, px de tela

## Móveis: [arquivo, base, pegada (largura, fundura)]. A pegada é o que
## bloqueia, na base do móvel.
const MOVEIS := [
	["barril", Vector2(14, 113), Vector2(12, 4)],
	["barril", Vector2(27, 116), Vector2(12, 4)],
	["caixote", Vector2(15, 131), Vector2(16, 5)],
	["banco", Vector2(72, 127), Vector2(36, 3)],
	["mesa", Vector2(72, 141), Vector2(44, 7)],
	["banco", Vector2(72, 154), Vector2(36, 3)],
	["vaso", Vector2(146, 111), Vector2(10, 3)],
	["banquinho", Vector2(183, 128), Vector2(8, 3)],
	["mesa_pequena", Vector2(200, 128), Vector2(28, 6)],
	["banquinho", Vector2(217, 128), Vector2(8, 3)],
	["braseiro", Vector2(276, 116), Vector2(10, 3)],
	["braseiro", Vector2(364, 116), Vector2(10, 3)],
	["banco", Vector2(440, 113), Vector2(36, 3)],
	["vaso", Vector2(472, 111), Vector2(10, 3)],
	["caixote", Vector2(629, 143), Vector2(16, 5)],
	["barril", Vector2(630, 158), Vector2(12, 4)],
]
## Fogo em cada móvel com chama: deslocamento da base, colunas, altura,
## raio e força do brilho.
const FOGO_MOVEL := {
	"braseiro": [Vector2(0, -22), 2, 6.0, 26, 0.32],
	"mesa": [Vector2(-12, -22), 0, 2.0, 12, 0.22],
	"mesa_pequena": [Vector2(-4, -22), 0, 2.0, 12, 0.22],
}
const TOCHAS := [Vector2(20, 58), Vector2(140, 58), Vector2(260, 58), Vector2(380, 58), Vector2(500, 58), Vector2(620, 58)]
const VELAS := [Vector2(177, 48), Vector2(181, 48), Vector2(219, 48), Vector2(223, 48)]
const LAREIRA := Vector2(200, 102)
const PORTA := Vector2(320, 107)  ## base do degrau, no centro da parede do fundo
const COR_RUNA := Color(0.5, 0.9, 1.0)

## Personagens do Elenco: [onde ficam (os pés), se olham para a esquerda].
const LUGARES := {
	"andri": [Vector2(104, 142), true],
	"shumi": [Vector2(428, 130), true],
	"askara": [Vector2(505, 168), true],
}
const LUGARES_LIVRES := [Vector2(252, 160), Vector2(150, 168), Vector2(505, 168)]
## Onde a Caoimhe aparece: no começo, no centro do tapete, de frente para
## a porta (longe o bastante para ela não começar em foco); ao voltar, na porta.
const ENTRADAS := {
	"inicio": Vector2(320, 152),
	"porta": Vector2(320, 130),
}
## A Caoimhe é quem anda pelo saguão. Ela não luta, então não está no
## Elenco; os dados dela ficam aqui, no mesmo formato.
const CAOIMHE := {
	"nome": "Caoimhe",
	"sprite": {
		"png": "res://personagens/caoimhe/caoimhe_spritesheet.png",
		"json": "res://personagens/caoimhe/caoimhe_spritesheet.json",
		"pe": Vector2(16, 38),
		"altura": 34.0,
		"rosto": Rect2(8, 6, 16, 16),
	},
}

var jogador: JogadorLobby
var camera: Camera2D
var hud: HudLobby
var mundo: Node2D  ## móveis e personagens, ordenados pela altura dos pés
var interagiveis: Array[Interagivel] = []
var foco: Interagivel  ## o que está ao alcance agora
var ocupado := false  ## conversa aberta ou entrando na dungeon

var _porta: Interagivel
var _runas: Sprite2D
var _brilho_porta: Sprite2D
var _circulo: Node2D
var _luz_runas := 0.35
var _tempo := 0.0
var _visuais := {}  ## id do Elenco -> VisualLutador no saguão
var _lugares_livres: Array = []
var _rodando_eventos := false


static func tela(p: Vector2) -> Vector2:
	return p * ESCALA


func _ready() -> void:
	var fundo := Sprite2D.new()
	fundo.texture = load(PASTA + "saguao.png")
	fundo.centered = false
	fundo.scale = Vector2(ESCALA, ESCALA)
	fundo.z_index = -10
	add_child(fundo)
	mundo = Node2D.new()
	mundo.y_sort_enabled = true
	add_child(mundo)

	_montar_limites()
	_montar_moveis()
	_montar_luzes()
	_montar_porta()
	_montar_jogador()
	_montar_personagens()
	_montar_camera()

	hud = HudLobby.new()
	add_child(hud)
	hud.dialogo.terminou.connect(_fim_da_conversa)
	hud.dialogo.evento.connect(_evento_da_fala)
	# quem vai ser apresentado agora começa escondido
	for e in Progressao.eventos_pendentes():
		if e.get("tipo", "") == "desbloquear" and _visuais.has(e.get("id", "")):
			_visuais[e.id].modulate.a = 0.0
	if not Progressao.eventos_pendentes().is_empty():
		_ocupar(true)
	await hud.veu(0.0, 0.5).finished
	rodar_eventos()


# ------------------------------------------------------------------ montagem
func _solido(centro: Vector2, tamanho: Vector2) -> StaticBody2D:
	var corpo := StaticBody2D.new()
	corpo.position = centro
	var forma := RectangleShape2D.new()
	forma.size = tamanho
	var col := CollisionShape2D.new()
	col.shape = forma
	corpo.add_child(col)
	add_child(corpo)
	return corpo


func _montar_limites() -> void:
	var w := LARGURA * ESCALA
	var fundo := LIMITE_FUNDO * ESCALA
	var frente := LIMITE_FRENTE * ESCALA
	var lado := LIMITE_LADOS * ESCALA
	_solido(Vector2(w / 2, (fundo - 200) / 2), Vector2(w + 400, fundo + 200))
	_solido(Vector2(w / 2, frente + 100), Vector2(w + 400, 200))
	_solido(Vector2(lado - 100, 270), Vector2(200, 1000))
	_solido(Vector2(w - lado + 100, 270), Vector2(200, 1000))


## Sprite com a origem no meio da base (o ponto que ordena e colide).
func _objeto(arquivo: String, base: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(PASTA + arquivo + ".png")
	s.centered = false
	s.offset = -Vector2(floorf(s.texture.get_width() / 2.0), s.texture.get_height())
	s.scale = Vector2(ESCALA, ESCALA)
	s.position = tela(base)
	return s


func _montar_moveis() -> void:
	for m: Array in MOVEIS:
		var s := _objeto(m[0], m[1])
		mundo.add_child(s)
		var pegada: Vector2 = m[2] * ESCALA
		_solido(s.position - Vector2(0, pegada.y / 2), pegada)
		if FOGO_MOVEL.has(m[0]):
			var f: Array = FOGO_MOVEL[m[0]]
			# filho do móvel: escala 1/3 para a chama seguir a grade de 3px da tela
			var chama := Chama.new(f[0], f[1], f[2], f[3], f[4])
			chama.scale = Vector2.ONE / ESCALA
			s.add_child(chama)


func _montar_luzes() -> void:
	for t: Vector2 in TOCHAS:
		var c := Chama.new(tela(t + Vector2(0.5, 0)), 1, 5.0, 34, 0.3)
		c.z_index = -7
		add_child(c)
	for v: Vector2 in VELAS:
		var c := Chama.new(tela(v + Vector2(0.5, 0)), 0, 2.0, 8, 0.2)
		c.z_index = -7
		add_child(c)
	var lareira := Chama.new(tela(LAREIRA), 4, 10.0, 60, 0.4)
	lareira.z_index = -7
	add_child(lareira)
	# luz quente no centro, sobre o tapete diante da porta
	var destaque := Brilho.criar(36, Color(1.0, 0.85, 0.6), 0.16)
	destaque.position = tela(Vector2(320, 104))
	add_child(destaque)


func _montar_porta() -> void:
	var porta := _objeto("porta_dungeon", PORTA)
	porta.z_index = -9
	add_child(porta)
	_runas = _objeto("porta_runas", PORTA)
	_runas.z_index = -8
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_runas.material = m
	add_child(_runas)
	_brilho_porta = Brilho.criar(44, COR_RUNA, 0.12)
	_brilho_porta.position = tela(PORTA + Vector2(0, -38))
	add_child(_brilho_porta)
	_circulo = Node2D.new()
	_circulo.position = tela(PORTA + Vector2(0, 8))
	_circulo.z_as_relative = false
	_circulo.z_index = -6
	_circulo.draw.connect(_desenhar_circulo)
	add_child(_circulo)

	_porta = Interagivel.new()
	_porta.id = "porta"
	_porta.acao = "Entrar na dungeon"
	_porta.cor = COR_RUNA
	_porta.position = tela(PORTA + Vector2(0, 6))
	_porta.altura = 64 * ESCALA
	_porta.raio = 96.0
	_porta.largura_base = 150.0
	_porta.ao_interagir = entrar_na_dungeon
	add_child(_porta)
	interagiveis.append(_porta)


func _montar_jogador() -> void:
	jogador = JogadorLobby.new()
	jogador.iniciar("caoimhe", CAOIMHE)
	var entrada: Vector2 = ENTRADAS.get(Engine.get_meta(META_ENTRADA, "inicio"), ENTRADAS.inicio)
	jogador.position = tela(entrada)
	jogador.reset_physics_interpolation.call_deferred()
	mundo.add_child(jogador)


func _montar_personagens() -> void:
	_lugares_livres = LUGARES_LIVRES.duplicate()
	for id in Elenco.disponiveis():
		_montar_personagem(id)


func _montar_personagem(id: String) -> void:
	var lugar: Array = LUGARES.get(id, [])
	if lugar.is_empty():
		if _lugares_livres.is_empty():
			push_warning("saguão sem lugar livre para " + id)
			return
		lugar = [_lugares_livres.pop_front(), false]
	var dados := Elenco.dados(id)
	var sp: Dictionary = dados.sprite
	var v := VisualLutador.new()
	v.iniciar_animado(null, sp.png, sp.json, sp.pe, sp.altura, sp.get("rosto", Rect2()))
	v.position = tela(lugar[0])
	v.virar(lugar[1])
	mundo.add_child(v)
	_visuais[id] = v
	_solido(v.position - Vector2(0, PES.y / 2), PES)

	var it := Interagivel.new()
	it.id = id
	it.nome = dados.nome
	it.position = v.position
	it.altura = v.altura
	it.retrato = v.retrato()
	add_child(it)
	interagiveis.append(it)


func _montar_camera() -> void:
	camera = Camera2D.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS  # exigido pela interpolação de física
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(LARGURA * ESCALA)
	camera.limit_bottom = int(ALTURA * ESCALA)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	# filha do jogador: segue o desenho interpolado, sem atraso de um passo
	jogador.add_child(camera)
	camera.reset_smoothing.call_deferred()


# ---------------------------------------------------------------- interação
func _process(delta: float) -> void:
	_tempo += delta
	_atualizar_foco()
	# as runas respiram devagar e acendem quando o jogador chega perto
	var alvo := 0.8 + 0.15 * sin(_tempo * 3.0) if foco == _porta else 0.3 + 0.12 * sin(_tempo * 1.4)
	if not ocupado or foco == _porta:
		_luz_runas = move_toward(_luz_runas, alvo, delta * 1.5)
	_runas.modulate.a = _luz_runas
	_brilho_porta.modulate.a = 0.06 + 0.14 * _luz_runas
	_circulo.queue_redraw()


## O interagível mais perto dos pés do jogador, dentro do raio dele. A
## distância de profundidade (y) pesa mais, como no chão em perspectiva.
func mais_proximo() -> Interagivel:
	var melhor: Interagivel = null
	var melhor_d := INF
	for it in interagiveis:
		var dif := it.position - jogador.position
		var d := Vector2(dif.x, dif.y * 1.6).length()
		if d <= it.raio and d < melhor_d:
			melhor = it
			melhor_d = d
	return melhor


func _atualizar_foco() -> void:
	var novo: Interagivel = null if ocupado else mais_proximo()
	if novo == foco:
		return
	if foco:
		foco.em_foco = false
	foco = novo
	if foco:
		foco.em_foco = true


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if hud.dialogo.aberta():
		hud.dialogo.teclar(event.keycode)
		get_viewport().set_input_as_handled()
		return
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		interagir()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		voltar_ao_menu()
		get_viewport().set_input_as_handled()


## Interage com o que está em foco. Uma interação por vez: enquanto uma
## conversa ou a entrada na dungeon está em andamento, nada mais começa.
func interagir() -> void:
	if ocupado or foco == null:
		return
	var it := foco
	var motivo := it.motivo_bloqueio()
	if motivo != "":
		hud.avisar(motivo)
	elif it.ao_interagir.is_valid():
		it.ao_interagir.call()
	else:
		var conversa := Conversas.de(it.id)
		if conversa.get("falas", []).is_empty():
			hud.avisar("%s: interação ainda não disponível." % it.nome)
			return
		_ocupar(true)
		hud.dialogo.abrir(conversa, it.nome, it.retrato)


func _fim_da_conversa() -> void:
	if _rodando_eventos:
		return  # quem segue é rodar_eventos()
	_ocupar(false)
	rodar_eventos()


## Fala com "evento": "tipo:id" (ex.: "desbloquear:andri"). O efeito vale na
## hora; a apresentação entra na fila e roda quando a conversa acaba.
func _evento_da_fala(nome: String) -> void:
	var e := Eventos.de_texto(nome)
	if e.is_empty() or not Eventos.pendente(e):
		return
	Eventos.aplicar(e)
	Progressao.adicionar_eventos_pendentes([e])


# ------------------------------------------------------- eventos de história
## Apresenta os eventos pendentes, um de cada vez, com o jogador parado.
## Cada um sai da fila depois de apresentado (fechar o jogo no meio não perde
## o resto).
func rodar_eventos() -> void:
	if _rodando_eventos or Progressao.eventos_pendentes().is_empty():
		return
	_rodando_eventos = true
	_ocupar(true)
	while not Progressao.eventos_pendentes().is_empty():
		await _apresentar(Progressao.eventos_pendentes()[0])
		Progressao.tirar_evento_pendente()
	_rodando_eventos = false
	_ocupar(false)


func _apresentar(e: Dictionary) -> void:
	match e.get("tipo", ""):
		"desbloquear":
			await _apresentar_chegada(e.get("id", ""))
		"conversa":
			var conversa := Conversas.de(e.get("id", ""))
			if conversa.get("falas", []).is_empty():
				return  # ainda sem falas escritas
			var quem := _interagivel(e.get("quem", ""))
			hud.dialogo.abrir(conversa, quem.nome if quem else "", quem.retrato if quem else null)
			await hud.dialogo.terminou


## O personagem surge no lugar dele, com um anel de luz e um anúncio.
func _apresentar_chegada(id: String) -> void:
	if id not in Elenco.IDS:
		return
	if not _visuais.has(id):
		_montar_personagem(id)  # liberado agora, durante a visita
		if not _visuais.has(id):
			return
		_visuais[id].modulate.a = 0.0
	var v: VisualLutador = _visuais[id]
	EfeitosCombate.anel(mundo, v.position + Vector2(0, -v.altura * 0.5), EstiloUI.OURO, 90.0)
	var t := create_tween()
	t.tween_property(v, "modulate:a", 1.0, 0.7)
	hud.anunciar("%s chegou à Torre!" % Elenco.dados(id).nome)
	await t.finished
	await get_tree().create_timer(1.6).timeout


func _interagivel(id: String) -> Interagivel:
	for it in interagiveis:
		if it.id == id:
			return it
	return null


func _ocupar(sim: bool) -> void:
	ocupado = sim
	jogador.travado = sim
	if sim and foco:
		foco.em_foco = false
		foco = null


func entrar_na_dungeon() -> void:
	_ocupar(true)
	_luz_runas = 1.6
	EfeitosCombate.anel(self, tela(PORTA + Vector2(0, -36)), COR_RUNA, 110.0)
	await hud.veu(1.0, 0.6).finished
	Engine.set_meta(META_ENTRADA, "porta")
	get_tree().change_scene_to_file(CENA_DUNGEON)


## Volta ao menu inicial. O progresso já está salvo a cada mudança.
func voltar_ao_menu() -> void:
	if ocupado:
		return
	_ocupar(true)
	await hud.veu(1.0, 0.4).finished
	get_tree().change_scene_to_file(CENA_MENU)


# ------------------------------------------------------------------ desenho
## Círculo de runas no chão em frente à porta, em quadradinhos de 3px.
func _desenhar_circulo() -> void:
	var a := clampf(_luz_runas, 0.0, 1.0)
	var rx := 28.0
	var ry := 6.0
	for i in 48:
		var ang := TAU * i / 48
		var p := Vector2(cos(ang) * rx, sin(ang) * ry).snapped(Vector2.ONE) * ESCALA
		var marca := i % 6 == 0
		var cor := Color(COR_RUNA, (0.55 if marca else 0.3) * a)
		_circulo.draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), cor)
		if marca:
			_circulo.draw_rect(Rect2(p + Vector2(-1.5, -4.5), Vector2(3, 3)), Color(COR_RUNA, 0.4 * a))

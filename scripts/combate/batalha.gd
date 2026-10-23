class_name Batalha
extends Node2D
## Batalha de um andar (Andares.atual()): a equipe escolhida no seletor
## contra os inimigos do andar. Controles: as teclas da barra (Q/E/R...),
## ←/→ ou clique troca o alvo. Terminado o andar (vitória ou derrota), o
## resultado aparece e Enter, Esc ou clique voltam ao saguão. Ações com "opcoes" abrem um seletor
## (lista na HUD ou, com "seletor": "radial", um anel no próprio lutador):
## ↑/↓ ou 1-9 escolhem (no anel, ←/→ também giram), ←/→ trocam o alvo,
## Enter (ou a tecla da ação) confirma e Esc cancela.
## A vez, os pontos de skill do time e o alvo ficam aqui; o que cada ação faz
## na arena fica nas AcoesPersonagem de cada um; a HUD só mostra.

signal acao_escolhida(acao: String)

const PONTOS_MAX := 5
const PONTOS_INICIAIS := 3
const TAMANHO_FILA := 7
const CENA_SAGUAO := "res://scenes/lobby.tscn"

## Onde ficam os aliados, por tamanho da equipe (o primeiro vai na frente).
const POSICOES_ALIADOS := [
	[Vector2(220, 430)],
	[Vector2(250, 432), Vector2(160, 410)],
	[Vector2(265, 434), Vector2(175, 410), Vector2(110, 436)],
]
## Onde ficam os inimigos, por quantidade (o do meio um pouco à frente).
const POSICOES_INIMIGOS := [
	[Vector2(720, 430)],
	[Vector2(650, 420), Vector2(800, 420)],
	[Vector2(590, 410), Vector2(720, 430), Vector2(850, 410)],
]
const COR_INVESTIDA := Color(0.75, 0.65, 1.0)

var equipe: Array[Combatente] = []
var inimigos: Array[Inimigo] = []
var lutadores: Array[Combatente] = []
var pontos := PONTOS_INICIAIS
var esperando_jogador := false
var acabou := false
var ativo: Combatente  ## aliado da vez (ou o último que agiu)
var alvo := 0  ## índice entre os inimigos vivos
var aliado_alvo := 0  ## índice entre os aliados vivos (ações com alvo "aliado")
var opcao := ""  ## opção escolhida para a ação em execução (elemento, artefato...)
var andar := 1  ## número do andar (Andares)
var ids_equipe: Array[String] = []  ## ids do Elenco da equipe, na ordem de `equipe`
## Resultado da vitória (Progressao.recompensar_vitoria), dado uma vez só.
var recompensas: Array[Dictionary] = []
## Andares.concluir() da vitória ({} até lá).
var conclusao := {}
var _recompensada := false
var _saindo := false  ## já pediu a volta ao saguão (tecla e clique juntos)

var mundo: Node2D
var hud: HudBatalha

var _visuais := {}  ## Combatente -> VisualLutador
var _acoes := {}  ## aliado -> AcoesPersonagem
var _foco := ""  ## habilidade com o mouse em cima (prévia de alvos)
var _ator: Combatente
var _escolhendo := ""  ## ação com o seletor de opções aberto
var _indice_opcao := 0
var _radial: SeletorRadial  ## o seletor em anel, quando a ação pede


func _ready() -> void:
	mundo = Node2D.new()
	add_child(mundo)
	var fundo := Sprite2D.new()
	andar = Andares.atual()
	var dados_andar := Andares.dados(andar)
	fundo.texture = load(dados_andar.get("fundo", Andares.FUNDO_PADRAO))
	fundo.centered = false
	fundo.scale = Vector2(3, 3)
	mundo.add_child(fundo)

	ids_equipe = Elenco.equipe().slice(0, Andares.max_equipe(andar))
	var ids := ids_equipe
	var posicoes: Array = POSICOES_ALIADOS[ids.size() - 1]
	# quem está mais ao fundo (y menor) é desenhado antes
	var ordem := range(ids.size())
	ordem.sort_custom(func(a: int, b: int) -> bool: return posicoes[a].y < posicoes[b].y)
	var visuais_aliados := []
	for i in ids.size():
		var dados := Elenco.dados(ids[i])
		var c := Elenco.criar(ids[i])
		var vs := VisualLutador.new()
		var sp: Dictionary = dados.sprite
		vs.iniciar_animado(c, sp.png, sp.json, sp.pe, sp.altura, sp.rosto)
		vs.position = posicoes[i]
		equipe.append(c)
		c.aliados_vivos = aliados_vivos
		visuais_aliados.append(vs)
		_visuais[c] = vs
		_acoes[c] = (dados.acoes as GDScript).new(self, c, vs)
	for i in ordem:
		mundo.add_child(visuais_aliados[i])
	ativo = equipe[0]

	inimigos = Andares.criar_inimigos(andar)
	var pos_inimigos: Array = POSICOES_INIMIGOS[clampi(inimigos.size(), 1, POSICOES_INIMIGOS.size()) - 1]
	for i in inimigos.size():
		var vi := VisualLutador.new()
		vi.iniciar_estatico(inimigos[i], inimigos[i].textura)
		vi.position = pos_inimigos[i]
		mundo.add_child(vi)
		_visuais[inimigos[i]] = vi

	lutadores.append_array(equipe)
	lutadores.append_array(inimigos)

	hud = HudBatalha.new()
	add_child(hud)
	hud.acao_pedida.connect(pedir_acao)
	hud.foco_habilidade.connect(func(acao: String) -> void:
		_foco = acao
		atualizar())
	hud.saguao_pedido.connect(_voltar_ao_saguao)
	hud.opcao_clicada.connect(func(i: int) -> void:
		if i == _indice_opcao:
			confirmar_escolha()
		else:
			selecionar_opcao(i))
	var retratos := {}
	for c in _visuais:
		retratos[c] = _visuais[c].retrato()
	hud.definir_retratos(retratos)
	var nomes := ", ".join(equipe.map(func(c: Combatente) -> String: return HudBatalha.nome(c)))
	hud.registrar("Andar %d, %s: %s %s os guardiões da Torre." % [andar, dados_andar.nome, nomes, "encontra" if equipe.size() == 1 else "encontram"])
	atualizar()
	_rodar.call_deferred()


# ---------------------------------------------------------------- entrada
func pedir_acao(acao: String) -> void:
	if not esperando_jogador:
		return
	if _escolhendo != "":
		if acao == _escolhendo:
			confirmar_escolha()
			return
		cancelar_escolha()
	var h := _habilidade(ativo, acao)
	if h.has("opcoes") and ativo.pode_usar(acao, pontos):
		_escolhendo = acao
		var ids: Array = h.opcoes.map(func(o: Dictionary) -> String: return o.id)
		_indice_opcao = maxi(0, ids.find(h.get("opcao_padrao", "")))
		if h.get("seletor", "") == "radial":
			_abrir_radial(acao)
		_atualizar_escolha()
		atualizar()
		return
	_confirmar(acao, "")


## Manda a ação para o turno, se a regra do kit permitir. Devolve se foi.
func _confirmar(acao: String, op: String) -> bool:
	if ativo.pode_usar(acao, pontos):
		var motivo := ativo.motivo_invalido(acao, op, alvo_da_acao(acao))
		if motivo != "":
			hud.avisar(motivo)
			return false
		hud.acionar(acao)
	opcao = op
	acao_escolhida.emit(acao)
	return true


func selecionar_opcao(i: int) -> void:
	var opcoes: Array = _habilidade(ativo, _escolhendo).get("opcoes", [])
	if i >= 0 and i < opcoes.size():
		_indice_opcao = i
		_atualizar_escolha()


func confirmar_escolha() -> bool:
	var acao := _escolhendo
	var opcoes: Array = _habilidade(ativo, acao).get("opcoes", [])
	if acao == "" or opcoes.is_empty():
		return false
	if not _confirmar(acao, opcoes[_indice_opcao].id):
		return false
	_fechar_escolha()
	return true


func cancelar_escolha() -> void:
	if _escolhendo != "":
		_fechar_escolha()
		atualizar()


func _fechar_escolha() -> void:
	_escolhendo = ""
	hud.fechar_opcoes()
	if is_instance_valid(_radial):
		_radial.fechar()
	_radial = null


## Anel de opções preso ao lutador da vez, no ponto que as ações dele indicam.
func _abrir_radial(acao: String) -> void:
	_radial = SeletorRadial.new()
	_radial.position = (_acoes[ativo] as AcoesPersonagem).ancora_seletor(acao)
	_radial.opcao_focada.connect(selecionar_opcao)
	_radial.opcao_clicada.connect(func(i: int) -> void:
		selecionar_opcao(i)
		confirmar_escolha())
	_visuais[ativo].add_child(_radial)


## Mostra o seletor com o motivo de cada opção não servir no alvo atual.
func _atualizar_escolha() -> void:
	var h := _habilidade(ativo, _escolhendo)
	var quem := alvo_da_acao(_escolhendo)
	var motivos: Array[String] = []
	for o: Dictionary in h.opcoes:
		motivos.append(ativo.motivo_invalido(_escolhendo, o.id, quem))
	# escolha sobre si mesmo (a lente, por exemplo) não precisa mostrar alvo
	var nome_alvo := quem.nome if quem and h.get("alvo", "") != "proprio" else ""
	if is_instance_valid(_radial):
		_radial.mostrar(h.opcoes, _indice_opcao, motivos)
	else:
		hud.mostrar_opcoes(h, _indice_opcao, motivos, nome_alvo)


func _unhandled_input(event: InputEvent) -> void:
	if acabou:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
				_voltar_ao_saguao()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if _escolhendo != "":
			var n: int = _habilidade(ativo, _escolhendo).get("opcoes", []).size()
			var passo := 0
			match event.keycode:
				KEY_UP, KEY_W: passo = -1
				KEY_DOWN, KEY_S: passo = 1
				KEY_LEFT, KEY_A: passo = -1 if is_instance_valid(_radial) else 0
				KEY_RIGHT, KEY_D: passo = 1 if is_instance_valid(_radial) else 0
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: confirmar_escolha()
				KEY_ESCAPE: cancelar_escolha()
			if passo != 0:
				# no anel, ←/→ giram o tambor em vez de trocar o alvo
				selecionar_opcao(posmod(_indice_opcao + passo, n))
				return
			if event.keycode >= KEY_1 and event.keycode <= KEY_9:
				selecionar_opcao(event.keycode - KEY_1)
		match event.keycode:
			KEY_LEFT, KEY_A: _mudar_alvo(-1)
			KEY_RIGHT, KEY_D: _mudar_alvo(1)
			_:
				# teclas das habilidades vêm do kit de quem está na vez
				var tecla := OS.get_keycode_string(event.keycode)
				for h in ativo.habilidades(pontos):
					if h.tecla == tecla:
						pedir_acao(h.acao)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var em_aliado := _mirando_aliado()
		var vivos: Array = aliados_vivos() if em_aliado else inimigos_vivos()
		for i in vivos.size():
			var v: VisualLutador = _visuais[vivos[i]]
			var area := Rect2(v.position.x - 60, v.position.y - v.altura - 20, 120, v.altura + 30)
			if area.has_point(get_global_mouse_position()):
				if em_aliado:
					aliado_alvo = i
				else:
					alvo = i
				_mudou_alvo()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		cancelar_escolha()


## A ação em foco (ou no seletor) mira um aliado?
func _mirando_aliado() -> bool:
	var acao := _escolhendo if _escolhendo != "" else _foco
	return _habilidade(ativo, acao).get("alvo", "") == "aliado"


func _mudar_alvo(direcao: int) -> void:
	if _mirando_aliado():
		var n := aliados_vivos().size()
		if n > 0:
			aliado_alvo = posmod(aliado_alvo + direcao, n)
	else:
		var n := inimigos_vivos().size()
		if n > 0:
			alvo = posmod(alvo + direcao, n)
	_mudou_alvo()


func _mudou_alvo() -> void:
	if _escolhendo != "":
		_atualizar_escolha()
	atualizar()


## Volta ao saguão pela porta, onde os eventos de história pendentes rodam.
func _voltar_ao_saguao() -> void:
	if not acabou or _saindo:
		return
	_saindo = true
	Engine.set_meta(Lobby.META_ENTRADA, "porta")
	get_tree().change_scene_to_file(CENA_SAGUAO)


# ------------------------------------------------------------ fluxo da luta
func inimigos_vivos() -> Array[Inimigo]:
	return inimigos.filter(func(i: Inimigo) -> bool: return i.vivo())


func aliados_vivos() -> Array[Combatente]:
	return equipe.filter(func(c: Combatente) -> bool: return c.vivo())


func _rodar() -> void:
	await esperar(0.6)
	while not acabou:
		_ator = FilaTurnos.proximo(lutadores)
		FilaTurnos.avancar_ate(lutadores, _ator)
		if _ator.aliado:
			ativo = _ator
		atualizar()
		if _ator.aliado:
			await _turno_aliado(_ator)
		else:
			await _turno_inimigo(_ator as Inimigo)
		_ator.reiniciar_av()
		if _ator.vivo():
			_passar_turno(_ator)
		_verificar_fim()
		atualizar()
		await esperar(0.25)


func _turno_aliado(a: Combatente) -> void:
	var acoes: AcoesPersonagem = _acoes[a]
	if not await acoes.inicio_turno():
		if not a.vivo():
			_cair(a)
		return

	aliado_alvo = maxi(0, aliados_vivos().find(a))  # o próprio, por padrão
	esperando_jogador = true
	atualizar()
	# escolhas de começo de turno (ex.: a lente do Andri) abrem sozinhas;
	# usar outra ação direto fecha o seletor e mantém a escolha anterior
	for h in a.habilidades(pontos):
		if h.get("ao_iniciar_turno", false) and a.pode_usar(h.acao, pontos):
			pedir_acao(h.acao)
			break
	while true:
		var acao: String = await acao_escolhida
		if not a.pode_usar(acao, pontos):
			continue
		var h := _habilidade(a, acao)
		esperando_jogador = false
		_foco = ""
		pontos -= h.get("custo_pontos", 0)
		atualizar()
		await acoes.executar(acao)
		pontos = mini(PONTOS_MAX, pontos + h.get("ganho_pontos", 0))
		if acabou or not h.get("livre", false):
			break
		esperando_jogador = true
		atualizar()
	acoes.fim_turno()


func _habilidade(a: Combatente, acao: String) -> Dictionary:
	for h in a.habilidades(pontos):
		if h.acao == acao:
			return h
	return {}


func _turno_inimigo(ini: Inimigo) -> void:
	var vi: VisualLutador = _visuais[ini]
	var golpe := ini.proximo_golpe()
	var vitima := ini.escolher_alvo(equipe)
	ini.registrar_acao()
	if golpe.pesado:
		hud.registrar("%s concentra energia para um %s!" % [HudBatalha.nome(ini), HudBatalha.destaque("Golpe Pesado", EstiloUI.COR_TIPO_EFEITO.alerta)])
		vi.piscar(Color(2.5, 0.8, 1.6))
		EfeitosCombate.anel(mundo, vi.position + Vector2(0, -vi.altura * 0.5), EstiloUI.COR_TIPO_EFEITO.alerta, vi.altura * 0.7)
		await esperar(0.5)
	else:
		hud.registrar("%s utilizou %s em %s." % [HudBatalha.nome(ini), golpe.nome, HudBatalha.nome(vitima)])
	var origem := vi.position
	var va: VisualLutador = _visuais[vitima]
	await vi.mover_para(Vector2(va.position.x + 110, origem.y), 0.25)
	EfeitosCombate.impacto(mundo, va.position + Vector2(10, -va.altura * 0.5),
		EstiloUI.COR_TIPO_EFEITO.alerta if golpe.pesado else COR_INVESTIDA, 1.4 if golpe.pesado else 1.0)
	await aplicar_dano(ini, vitima, golpe.mult, golpe.tipo)
	vitima.ganhar_energia(vitima.energia_ao_apanhar)
	if golpe.pesado:
		tremer(8.0)
	await esperar(0.15)
	await vi.mover_para(origem, 0.3)


## `tipo_ataque` é o tipo de dano (Tipos); "" = o tipo do atacante.
## Um golpe: tipo, efetividade (com fraquezas), crítico e escudo. Depois,
## se não for `extra`, os estados de acerto e os golpes adicionais do
## atacante (cada adicional entra aqui com extra = true: não se encadeia).
func aplicar_dano(atacante: Combatente, vitima: Combatente, mult: float, tipo_ataque := "", extra := false) -> void:
	if not vitima.vivo():
		return
	if tipo_ataque == "":
		tipo_ataque = atacante.tipo
	var critico := not extra and randf() < atacante.chance_critico()
	var dano := Combatente.calcular_dano(atacante, vitima, mult, randf(), tipo_ataque, critico)
	var efetividade := vitima.efetividade_contra(tipo_ataque)
	var absorvido := vitima.absorver(dano)
	vitima.receber_dano(dano - absorvido)
	var v: VisualLutador = _visuais[vitima]
	var tipo := "recebido" if vitima.aliado else ("dano" if mult >= 1.0 else "fraco")
	if (efetividade > 1.0 or critico) and not vitima.aliado:
		tipo = "critico"
	if extra:
		EfeitosCombate.impacto(mundo, v.position + Vector2(0, -v.altura * 0.5), Tipos.cor(tipo_ataque), 0.8)
	if absorvido > 0:
		EfeitosCombate.numero(mundo, v.topo() + Vector2(0, 20), "(%d)" % absorvido, "escudo")
	if dano > absorvido:
		EfeitosCombate.numero(mundo, v.topo(), str(dano - absorvido) + ("!" if critico else ""), tipo)
	var aviso := ""
	if efetividade > 1.0:
		aviso = " " + HudBatalha.destaque("Super efetivo!", EstiloUI.DANO_CRITICO)
		EfeitosCombate.numero(mundo, v.topo() + Vector2(0, -26), "SUPER EFETIVO", "efetivo")
	elif efetividade < 1.0:
		aviso = " " + HudBatalha.destaque("Pouco efetivo...", EstiloUI.TEXTO_FRACO)
		EfeitosCombate.numero(mundo, v.topo() + Vector2(0, -26), "pouco efetivo", "pouco_efetivo")
	if critico:
		aviso += " " + HudBatalha.destaque("Crítico!", EstiloUI.DANO_CRITICO)
	if absorvido > 0:
		aviso += " O escudo absorveu %s." % HudBatalha.destaque(str(absorvido), EfeitosCombate.NUMEROS.escudo[0])
	hud.registrar("%s recebeu %s de dano %s.%s" % [HudBatalha.nome(vitima),
		HudBatalha.destaque(str(dano - absorvido), EfeitosCombate.NUMEROS[tipo][0]),
		HudBatalha.destaque(Tipos.nome(tipo_ataque), Tipos.cor(tipo_ataque)), aviso])
	if vitima.vivo():
		v.levar_golpe()
	else:
		_cair(vitima)
	alvo = clampi(alvo, 0, maxi(0, inimigos_vivos().size() - 1))
	atualizar()
	if extra or not vitima.vivo():
		return
	for e in atacante.estados_ao_acertar():
		vitima.aplicar_estado(e)
		hud.registrar("%s ficou %s." % [HudBatalha.nome(vitima), HudBatalha.destaque(e.nome, EstiloUI.cor_efeito(e.descricao()))])
	for g in atacante.golpes_extras(mult):
		await esperar(0.08)
		hud.registrar("%s: dano extra de %s." % [g.fonte, HudBatalha.destaque(Tipos.nome(g.tipo), Tipos.cor(g.tipo))])
		await aplicar_dano(atacante, vitima, g.mult, g.tipo, true)


## Fim do turno de `c`: os estados genéricos perdem um turno.
func _passar_turno(c: Combatente) -> void:
	for e in c.passar_turno():
		hud.registrar("%s de %s acabou." % [e.nome, HudBatalha.nome(c)])


func aliado_atual() -> Combatente:
	var vivos := aliados_vivos()
	return vivos[clampi(aliado_alvo, 0, vivos.size() - 1)] if not vivos.is_empty() else null


## Quem a ação `acao` do aliado da vez tem como alvo principal.
func alvo_da_acao(acao: String) -> Combatente:
	match _habilidade(ativo, acao).get("alvo", ""):
		"aliado": return aliado_atual()
		"proprio": return ativo
	var vivos := inimigos_vivos()
	return vivos[alvo] if not vivos.is_empty() else null


func _cair(c: Combatente) -> void:
	_visuais[c].morrer()
	hud.registrar("%s foi derrotado." % HudBatalha.nome(c) if not c.aliado else "%s caiu." % HudBatalha.nome(c))
	if c == ativo and not aliados_vivos().is_empty():
		ativo = aliados_vivos()[0]
	_verificar_fim()


func _verificar_fim() -> void:
	if acabou:
		return
	if inimigos_vivos().is_empty():
		_terminar(true, "Andar %d concluído!" % andar)
	elif aliados_vivos().is_empty():
		_terminar(false, "%s caiu..." % equipe[0].nome if equipe.size() == 1 else "A equipe caiu...")


func _terminar(vitoria: bool, texto: String) -> void:
	acabou = true
	esperando_jogador = false
	if vitoria:
		_recompensar()
	var extras: Array[String] = []
	if not conclusao.is_empty():
		if conclusao.liberou > 0:
			extras.append("Andar %d liberado: %s" % [conclusao.liberou, Andares.dados(conclusao.liberou).nome])
			if conclusao.limite_depois > conclusao.limite_antes:
				extras.append("Limite de nível: %d → %d" % [conclusao.limite_antes, conclusao.limite_depois])
		elif conclusao.primeira and andar == Andares.total():
			extras.append("Você chegou ao topo da Torre, por enquanto.")
		for e: Dictionary in conclusao.eventos:
			var linha := Eventos.resumo(e)
			if linha != "":
				extras.append(linha)
	hud.mostrar_fim(vitoria, texto, recompensas, extras)
	atualizar()


## XP da vitória para toda a equipe que lutou (inclusive quem caiu). Uma vez
## por batalha: chamadas repetidas não dão de novo.
func _recompensar() -> void:
	if _recompensada:
		return
	_recompensada = true
	# XP antes do andar: quem chega pela história entra no nível já com a XP desta luta
	recompensas = Progressao.recompensar_vitoria(ids_equipe, inimigos)
	conclusao = Andares.concluir(andar)
	for r in recompensas:
		if not r.participou:
			continue
		var c := equipe[ids_equipe.find(r.id)]
		hud.registrar("%s recebeu %s." % [HudBatalha.nome(c), HudBatalha.destaque("%d XP" % r.xp_aproveitada, EstiloUI.XP)])
		if r.no_limite and r.nivel == r.nivel_antes:
			hud.registrar("%s está no limite de nível da Torre (%d)." % [HudBatalha.nome(c), r.limite])
		if r.nivel > r.nivel_antes:
			hud.registrar("%s subiu para o %s!" % [HudBatalha.nome(c), HudBatalha.destaque("nível %d" % r.nivel, EstiloUI.OURO)])
			var v: VisualLutador = _visuais[c]
			v.piscar(Color(2.2, 1.9, 0.9))
			EfeitosCombate.numero(mundo, v.topo() + Vector2(0, -10), "NÍVEL %d!" % r.nivel, "nivel")


# ------------------------------------------------------------------ apoio
func visual(c: Combatente) -> VisualLutador:
	return _visuais[c]


func alvo_atual() -> Inimigo:
	return inimigos_vivos()[alvo]


## Quem a ação `acao` do aliado da vez atingiria, pelo tipo de alvo dela.
func _previstos(acao: String) -> Array:
	var vivos := inimigos_vivos()
	var do_kit := ativo.alvos_previstos(acao, vivos, alvo)
	if not do_kit.is_empty():
		return do_kit
	var h := _habilidade(ativo, acao)
	match h.get("alvo", ""):
		"aliado": return [aliado_atual()]
		"unico": return [vivos[alvo]]
		"vizinhos": return vivos.slice(maxi(0, alvo - 1), alvo + 2)
		"todos": return vivos
		"proprio": return [ativo]
	return []


func atualizar() -> void:
	var vivos := inimigos_vivos()
	var em_aliado := _mirando_aliado()
	for i in inimigos.size():
		_visuais[inimigos[i]].marcado = esperando_jogador and not em_aliado and inimigos[i].vivo() and vivos.find(inimigos[i]) == alvo
	var mirado := aliado_atual() if esperando_jogador and em_aliado else null
	for c in equipe:
		_visuais[c].marcado = c == mirado
	# prévia: quem a habilidade em foco (ou no seletor) atingiria
	var acao := _escolhendo if _escolhendo != "" else _foco
	var atingidos := _previstos(acao) if esperando_jogador and not vivos.is_empty() else []
	for c in lutadores:
		_visuais[c].realce = c in atingidos
	for c in equipe:
		_visuais[c].da_vez = c == _ator and equipe.size() > 1
	var fila := FilaTurnos.previsao(lutadores, TAMANHO_FILA)
	hud.atualizar(ativo, equipe, pontos, PONTOS_MAX, fila, _ator, esperando_jogador)
	hud.definir_objetivo("Andar %d  ·  Derrote os guardiões  ·  %d/%d restantes" % [andar, vivos.size(), inimigos.size()])


func esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


func tremer(forca: float) -> void:
	var t := create_tween()
	for i in 6:
		t.tween_property(mundo, "position", Vector2(randf_range(-forca, forca), randf_range(-forca, forca)), 0.04)
	t.tween_property(mundo, "position", Vector2.ZERO, 0.05)

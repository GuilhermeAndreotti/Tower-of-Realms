extends SceneTree
## Simula os andares com a batalha de verdade (regras, fila, kits e
## inimigos reais) e um piloto automático no lugar do jogador. Serve para
## comparar a dificuldade entre andares e níveis; não substitui jogar.
## Rodar: godot --headless --path . -s ferramentas/simular_andares.gd -- [rodadas] [andar:nivel ...] [equipe=id,id]
## Sem cenários, roda cada andar no nível sem treino, no limite e 1 abaixo.
## Sem equipe, usa os primeiros liberados do Elenco que o andar aceita; com
## ela, os dessa lista que já estiverem liberados no andar.
##
## O piloto joga razoavelmente bem, sem ser ótimo:
##  - foca o inimigo com menos HP;
##  - Shumi: entra no Kaioken x2 com HP acima de 60%; Bang! quando sai da
##    recarga, fora da guarda e com 2+ pontos; Engo-ji com ponto sobrando e
##    2+ inimigos (ou no Kaioken); se não, Corte;
##  - Andri: lente mais efetiva no alvo; Protocolo: Escudo em quem estiver
##    abaixo de 50%; Análise (Fogo) quando nenhuma lente é super efetiva e o
##    alvo ainda tem muito HP; Sobrecarga com 2+ pontos; Arsenal: Freya em
##    quem estiver abaixo de 50%, se não Lança de Rá em quem bate mais;
##  - Askara: Lorde assim que der; se não, com ponto e vaga, Shivara (3
##    fragmentos) ou, sem nada em campo, Emissário (2); se não, Seta Vil.

const VELOCIDADE := 40.0  ## Engine.time_scale durante a simulação
const LIMITE_TEMPO := 600.0  ## segundos de jogo por batalha (com a escala)

var _rodadas := 12
var _cenarios: Array[Vector2i] = []  ## (andar, nível)
var _i_cenario := 0
var _i_rodada := 0
var _batalha: Batalha
var _tempo := 0.0
var _turnos := 0
var _resultados := {}  ## Vector2i -> [{"venceu", "turnos", "hp"}]
var _equipes := {}  ## Vector2i -> "shumi+andri"
var _equipe_pedida: Array[String] = []  ## equipe=... na linha de comando


func _initialize() -> void:
	Progressao.arquivo = "user://simulacao_progresso.cfg"
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("equipe="):
			for id in a.trim_prefix("equipe=").split(","):
				_equipe_pedida.append(id)
		elif a.is_valid_int():
			_rodadas = a.to_int()
		elif ":" in a:
			var p := a.split(":")
			_cenarios.append(Vector2i(p[0].to_int(), p[1].to_int()))
	if _cenarios.is_empty():
		for n in range(1, Andares.total() + 1):
			for nivel in _niveis_de_teste(n):
				_cenarios.append(Vector2i(n, nivel))
	Engine.time_scale = VELOCIDADE
	_proxima()


## Monta a próxima batalha (ou encerra e imprime a tabela).
func _proxima() -> void:
	if _i_cenario >= _cenarios.size():
		_imprimir()
		Progressao.apagar()
		quit()
		return
	var c := _cenarios[_i_cenario]
	_preparar_save(c.x, c.y)
	_equipes[c] = "+".join(Elenco.equipe().slice(0, Andares.max_equipe(c.x)))
	seed(1000 * c.x + 37 * c.y + _i_rodada)
	_batalha = (load("res://scenes/batalha.tscn") as PackedScene).instantiate()
	root.add_child(_batalha)
	current_scene = _batalha
	_tempo = 0.0
	_turnos = 0


func _process(delta: float) -> bool:
	if _batalha == null:
		return false
	_tempo += delta
	if _batalha.acabou or _tempo > LIMITE_TEMPO:
		_registrar()
		return false
	if _batalha.esperando_jogador:
		_pilotar()
	return false


func _registrar() -> void:
	var c := _cenarios[_i_cenario]
	var hp := 0.0
	var hp_max := 0.0
	for a in _batalha.equipe:
		hp += a.hp
		hp_max += a.hp_max
	if not _resultados.has(c):
		_resultados[c] = []
	_resultados[c].append({"venceu": _batalha.acabou and _batalha.inimigos_vivos().is_empty(),
		"turnos": _turnos, "hp": hp / hp_max})
	_batalha.queue_free()
	_batalha = null
	_i_rodada += 1
	if _i_rodada >= _rodadas:
		_i_rodada = 0
		_i_cenario += 1
	_proxima.call_deferred()


# ---------------------------------------------------------------- piloto
func _pilotar() -> void:
	var b := _batalha
	var a := b.ativo
	var vivos := b.inimigos_vivos()
	if vivos.is_empty():
		return
	# foco no inimigo com menos HP
	var foco := 0
	for i in vivos.size():
		if vivos[i].hp < vivos[foco].hp:
			foco = i
	b.alvo = foco
	var alvo: Inimigo = vivos[foco]

	if b._escolhendo == "lente":
		var melhor := _melhor_lente(alvo)
		if melhor == (a as Andri).lente:
			b.cancelar_escolha()
		else:
			b.selecionar_opcao(Andri.LENTES.find(melhor))
			b.confirmar_escolha()
		return
	if b._escolhendo != "":
		b.cancelar_escolha()
	if a is Shumi:
		var s := a as Shumi
		if s.pode_usar("ult", b.pontos) and not s.em_kaioken() and s.hp > s.hp_max * 0.6:
			b.pedir_acao("ult")
			return
		_turnos += 1
		if s.pode_usar("skill2", b.pontos) and b.pontos >= 2 and s.estado("bang") == null:
			b.pedir_acao("skill2")
		elif b.pontos >= 1 and (vivos.size() >= 2 or s.em_kaioken()):
			b.pedir_acao("skill")
		else:
			b.pedir_acao("basico")
	elif a is Askara:
		_turnos += 1
		_pilotar_askara(a as Askara, vivos.size())
	elif a is Andri:
		var an := a as Andri
		_turnos += 1
		if an.pode_usar("ult", b.pontos):
			_usar_arsenal(an)
			return
		if _usar_protocolo(an):
			return
		var eficaz := alvo.efetividade_contra(_melhor_lente(alvo)) >= Tipos.SUPER or alvo.estado("fraqueza") != null
		if not eficaz and b.pontos >= 1 and alvo.hp > alvo.hp_max * 0.4 and an.motivo_invalido("skill", Tipos.FOGO, alvo) == "":
			b.pedir_acao("skill")
			b.selecionar_opcao(an.elementos_analise().find(Tipos.FOGO))
			if not b.confirmar_escolha():
				b.cancelar_escolha()
				b.pedir_acao("basico")
			return
		if an.pode_usar("skill2", b.pontos) and b.pontos >= 2:
			b.pedir_acao("skill2")
			b.selecionar_opcao(0)  # Sobrecarga
			if b.confirmar_escolha():
				return
			b.cancelar_escolha()
		b.pedir_acao("basico")
	else:
		_turnos += 1
		b.pedir_acao("basico")


func _pilotar_askara(k: Askara, inimigos: int) -> void:
	var b := _batalha
	if k.pode_usar("ult", b.pontos):
		b.pedir_acao("ult")
		return
	var id := ""
	if k.pode_usar("skill", b.pontos) and k.em_campo().size() < Askara.MAX_INVOCACOES:
		var tem_shivara := k.em_campo().any(func(i: Invocacao) -> bool: return i.id == "shivara")
		if k.fragmentos >= 3 and not tem_shivara and inimigos >= 2:
			id = "shivara"
		elif k.fragmentos >= 2 and k.em_campo().is_empty():
			id = "emissario"
	if id == "":
		b.pedir_acao("basico")
		return
	b.pedir_acao("skill")
	var ids: Array = Askara.INVOCACOES.map(func(x: Dictionary) -> String: return x.id)
	b.selecionar_opcao(ids.find(id))
	if not b.confirmar_escolha():
		b.cancelar_escolha()
		b.pedir_acao("basico")


## Escudo do Protocolo em quem da equipe estiver abaixo de 50%. Devolve se usou.
func _usar_protocolo(an: Andri) -> bool:
	var b := _batalha
	if not an.pode_usar("skill2", b.pontos):
		return false
	var aliados := b.aliados_vivos()
	var pior := 0
	for i in aliados.size():
		if float(aliados[i].hp) / aliados[i].hp_max < float(aliados[pior].hp) / aliados[pior].hp_max:
			pior = i
	if float(aliados[pior].hp) / aliados[pior].hp_max >= 0.5:
		return false
	b.aliado_alvo = b.aliados_em_campo().find(aliados[pior])
	b.pedir_acao("skill2")
	b.selecionar_opcao(1)  # Escudo
	if b.confirmar_escolha():
		return true
	b.cancelar_escolha()
	return false


func _usar_arsenal(an: Andri) -> void:
	var b := _batalha
	var aliados := b.aliados_vivos()
	var pior := 0
	for i in aliados.size():
		if float(aliados[i].hp) / aliados[i].hp_max < float(aliados[pior].hp) / aliados[pior].hp_max:
			pior = i
	var id := "freya"
	var quem := pior
	if float(aliados[pior].hp) / aliados[pior].hp_max >= 0.5:
		id = "ra"
		quem = 0
		for i in aliados.size():
			if aliados[i].atq() > aliados[quem].atq():
				quem = i
	b.aliado_alvo = quem
	b.pedir_acao("ult")
	var ids: Array = Andri.ARTEFATOS.map(func(x: Dictionary) -> String: return x.id)
	b.selecionar_opcao(ids.find(id))
	if not b.confirmar_escolha():
		b.cancelar_escolha()
		b.pedir_acao("basico")


# ---------------------------------------------------------------- tabela
func _imprimir() -> void:
	print("\nandar  nível  equipe        vitórias   turnos (média)   HP restante (média / pior)")
	for c in _cenarios:
		var lista: Array = _resultados.get(c, [])
		var v := lista.filter(func(r: Dictionary) -> bool: return r.venceu)
		var turnos := 0.0
		var hp := 0.0
		var pior := 1.0
		for r: Dictionary in v:
			turnos += r.turnos
			hp += r.hp
			pior = minf(pior, r.hp)
		var n := maxi(1, v.size())
		print("%5d  %5d  %-12s  %3d/%-3d   %8.1f          %5.0f%% / %3.0f%%" % [c.x, c.y, _equipes.get(c, ""),
			v.size(), lista.size(), turnos / n, 100.0 * hp / n, 100.0 * pior if not v.is_empty() else 0.0])


# ---------------------------------------------------------------- apoio
## Níveis testados em cada andar: 1 abaixo do recomendado, o recomendado e
## o máximo que dá para ter ao entrar (o limite da Torre nesse ponto).
func _niveis_de_teste(n: int) -> Array[int]:
	var rec: int = Andares.dados(n).nivel_recomendado
	var niveis: Array[int] = []
	for nivel in [rec - 1, rec, Andares.limite_do_andar(n)]:
		if nivel >= 1 and nivel not in niveis:
			niveis.append(nivel)
	return niveis


## Save da simulação: andares anteriores vencidos (com os eventos deles),
## todos os liberados no `nivel` e a equipe mais cheia que o andar aceita.
func _preparar_save(andar: int, nivel: int) -> void:
	Progressao.apagar()
	for n in range(1, andar):
		Progressao.marcar_andar_vencido(n)
		for e: Dictionary in Andares.dados(n).get("ao_vencer", []):
			Eventos.aplicar(e)
	for id in Elenco.disponiveis():
		Progressao._guardar(id, {"nivel": nivel, "xp": 0})
	Andares.escolher(andar)
	var ids := Elenco.disponiveis()
	if not _equipe_pedida.is_empty():
		ids = _equipe_pedida.filter(func(id: String) -> bool: return id in Elenco.disponiveis())
	Elenco.definir_equipe(ids.slice(0, Andares.max_equipe(andar)))


## A lente do Andri que mais machuca `alvo` (fraquezas criadas contam).
func _melhor_lente(alvo: Combatente) -> String:
	var melhor := Andri.LENTES[0]
	for t in Andri.LENTES:
		if alvo.efetividade_contra(t) > alvo.efetividade_contra(melhor):
			melhor = t
	return melhor

extends SceneTree
## Testes da lógica de combate, sem interface.
## Rodar: godot --headless --path . -s testes/teste_combate.gd

var _falhas := 0


func _init() -> void:
	# a equipe é salva no progresso: os testes usam um arquivo só deles
	Progressao.arquivo = "user://teste_combate_progresso.cfg"
	# a história (quem chega depois) é testada com a chave temporária de
	# todos liberados desligada
	Elenco.todos_liberados = false
	Progressao.apagar()
	_teste_fila()
	_teste_velocidade_reescala_av()
	_teste_kaioken_entrar_e_subir()
	_teste_kaioken_fim_e_exaustao()
	_teste_kaioken_x20()
	_teste_energia_em_kaioken()
	_teste_engo_ji()
	_teste_dano()
	_teste_tipos()
	_teste_estados()
	_teste_andri_lente_e_disparo()
	_teste_andri_analise()
	_teste_andri_arsenal()
	_teste_descricao_interface()
	_teste_equipe()
	_teste_askara_fragmentos()
	_teste_askara_invocacao()
	_teste_askara_lorde()
	_teste_invocacao_alvos_e_provocacao()
	_teste_recarga()
	_teste_shumi_bang()
	_teste_andri_protocolo()
	_teste_askara_ultimo_ato()


## Os testes com a batalha de verdade precisam da árvore de cenas.
func _initialize() -> void:
	await _teste_askara_na_batalha()
	await _teste_bang_na_batalha()
	Progressao.apagar()
	print("\n%s (%d falha%s)" % ["TUDO OK" if _falhas == 0 else "FALHOU", _falhas, "" if _falhas == 1 else "s"])
	quit(1 if _falhas else 0)


## A habilidade `acao` do kit de `c` (pela ação, não pela posição na barra).
func _hab(c: Combatente, acao: String, pontos := 1) -> Dictionary:
	return _hab_em(c.habilidades(pontos), acao)


func _hab_em(kit: Array[Dictionary], acao: String) -> Dictionary:
	for h in kit:
		if h.acao == acao:
			return h
	return {}


func checar(condicao: bool, descricao: String) -> void:
	if condicao:
		print("  ok   ", descricao)
	else:
		_falhas += 1
		printerr("  FALHOU ", descricao)


func _teste_fila() -> void:
	print("fila de turnos")
	var lento := Combatente.new("Lento", true, 100, 10, 0, 100)
	var rapido := Combatente.new("Rápido", false, 100, 10, 0, 250)
	var todos: Array = [lento, rapido]
	var ordem := FilaTurnos.previsao(todos, 4)
	checar(Array(ordem) == [rapido, rapido, lento, rapido], "VEL 250 age 2x antes do VEL 100")
	var ator := FilaTurnos.proximo(todos)
	checar(ator == rapido, "o mais rápido age primeiro")
	FilaTurnos.avancar_ate(todos, ator)
	checar(is_equal_approx(lento.av, 60.0), "tempo passado é descontado dos outros (100 - 40 = 60)")
	lento.hp = 0
	checar(FilaTurnos.previsao(todos, 3).count(lento) == 0, "derrotados saem da fila")


func _teste_velocidade_reescala_av() -> void:
	print("mudança de velocidade")
	var c := Combatente.new("C", true, 100, 10, 0, 100)
	c.av = 50.0
	var antes := c.vel()
	c._bonus_extra["vel"] = 1.0
	c.ajustar_av(antes)
	checar(is_equal_approx(c.av, 25.0), "dobrar a VEL no meio do caminho corta o que falta pela metade")


func _teste_kaioken_entrar_e_subir() -> void:
	print("kaioken: entrar e subir")
	var s := Shumi.new()
	checar(not s.pode_ultar(), "começa sem energia suficiente (60/120)")
	s.energia = 120
	checar(s.pode_ultar(), "com 120 de energia pode entrar")
	s.ultar()
	checar(s.nome_nivel() == "x2" and s.energia == 0.0, "entra no x2 e gasta 120")
	checar(is_equal_approx(s.atq(), 180.0), "x2 dá +20% ATQ (150 -> 180)")
	checar(is_equal_approx(s.vel(), 126.0), "x2 dá +20% VEL (105 -> 126)")
	s.energia = 80
	checar(s.pode_ultar() and s.custo_ult() == 80.0, "subir de nível custa 80")
	s.turnos_kaioken = 1
	s.ultar()
	checar(s.nome_nivel() == "x4" and s.turnos_kaioken == Shumi.DURACAO, "sobe para x4 e renova a duração")
	checar(is_equal_approx(s.bonus("atq"), 0.40), "subir troca o bônus em vez de somar (x4 = +40%, não +60%)")
	var r := s.sobrecarga_inicio_turno()
	checar(r.dano == 60 and s.hp == 1140, "x4 queima 5% do HP (60)")
	checar(s.sobrecarga_inicio_turno().dano == 0 and s.hp == 1140, "a sobrecarga roda uma vez só por turno")
	s.fim_turno()
	checar(s.sobrecarga_inicio_turno().dano == 60, "no turno seguinte queima de novo")


func _teste_kaioken_fim_e_exaustao() -> void:
	print("kaioken: fim e exaustão")
	var s := Shumi.new()
	s.energia = 120
	s.ultar()
	s.energia = 80
	s.ultar()
	checar(s.fim_turno() == "" and s.fim_turno() == "", "dura 3 turnos")
	checar(s.fim_turno() == "x4", "no 3º turno acaba e avisa o nível")
	checar(not s.em_kaioken(), "saiu da forma")
	checar(is_equal_approx(s.vel(), 84.0), "exaustão do x4: VEL -20% (105 -> 84)")
	checar(not s.perde_proximo_turno, "fora do x20 não perde turno")
	s.fim_turno()
	checar(is_equal_approx(s.vel(), 84.0), "exaustão continua no 1º turno seguinte")
	s.fim_turno()
	checar(is_equal_approx(s.vel(), 105.0), "exaustão acaba depois de 2 turnos")


func _teste_kaioken_x20() -> void:
	print("kaioken: x20")
	var s := Shumi.new()
	for i in 4:
		s.energia = 120
		s.ultar()
	checar(s.nome_nivel() == "x20" and s.nivel_maximo(), "4 ults chegam no x20")
	checar(not s.pode_ultar(), "não sobe além do x20")
	checar(is_equal_approx(s.atq(), 375.0), "x20 dá +150% ATQ (150 -> 375)")
	checar(s.sobrecarga_inicio_turno().dano == 144, "x20 queima 12% do HP (144)")
	for i in 3:
		s.fim_turno()
	checar(s.perde_proximo_turno, "depois do x20 perde o próximo turno")
	s.hp = 100
	s.energia = 120
	s.ultar()
	s.nivel = 3
	s.energia = 0
	var r := s.sobrecarga_inicio_turno()
	checar(r.dano == 100 and not s.vivo(), "o dreno pode matar a Shumi")
	checar(r.energia == 0.0 and s.energia == 0.0, "Limite Humano não ativa se ela cai")


func _teste_energia_em_kaioken() -> void:
	print("energia e Limite Humano")
	var s := Shumi.new()
	s.energia = 0
	checar(s.sobrecarga_inicio_turno() == {"dano": 0, "energia": 0.0}, "fora do Kaioken: sem dreno e sem passiva")
	s.energia = 120
	s.ultar()
	var r := s.sobrecarga_inicio_turno()
	checar(r.dano == 36 and r.energia == 15.0 and s.energia == 15.0, "x2: perde 36 de HP e recupera 15 de energia")
	s.fim_turno()
	s.energia = 80
	s.ultar()
	s.energia = 0
	checar(s.sobrecarga_inicio_turno().energia == 20.0, "x4 recupera mais (20)")
	s.fim_turno()
	checar(Shumi.NIVEIS.all(func(n: Dictionary) -> bool: return n.limite < Shumi.CUSTO_SUBIR),
		"a passiva nunca paga sozinha a subida de nível")
	s.energia = 110
	checar(s.sobrecarga_inicio_turno().energia == 10.0 and s.energia == 120.0, "a passiva respeita o máximo de energia")


func _teste_engo_ji() -> void:
	print("engo-ji")
	var s := Shumi.new()
	var a := Inimigo.new("A", "", 100, 1, 0, 100)
	var b := Inimigo.new("B", "", 100, 1, 0, 100)
	var c := Inimigo.new("C", "", 100, 1, 0, 100)
	var lista := [a, b, c]
	checar(s.alvos_engo_ji(lista, 1) == [[b, 1.8]], "normal: só o alvo")
	s.nivel = 0
	checar(s.alvos_engo_ji(lista, 1) == [[b, 1.8], [c, 0.9]], "x2: alvo + o de trás, com dano menor")
	checar(s.alvos_engo_ji(lista, 2) == [[b, 0.9], [c, 1.8]], "x2 no último: o segundo é o da frente")
	checar(s.alvos_engo_ji([a], 0) == [[a, 1.8]], "x2 com um inimigo só: só ele")
	s.nivel = 1
	checar(s.alvos_engo_ji(lista, 0) == [[a, 1.8], [b, 0.9]], "x4 na ponta: alvo + 1 vizinho")
	checar(s.alvos_engo_ji(lista, 1) == [[a, 0.9], [b, 1.8], [c, 0.9]], "x4 no meio: até 3 alinhados")
	s.nivel = 2
	checar(s.alvos_engo_ji(lista, 0) == [[a, 1.8], [b, 1.8], [c, 1.8]], "x10 atravessa todos com dano cheio")
	s.nivel = 3
	checar(s.alvos_engo_ji(lista, 0) == [[a, 2.2], [b, 2.2], [c, 2.2]], "x20 (Colapso) acerta todos com dano massivo")
	checar(s.alvos_previstos("skill", lista, 0) == [a, b, c] and s.alvos_previstos("basico", lista, 0).is_empty(),
		"a prévia de alvos usa a mesma regra do Engo-ji")


func _teste_dano() -> void:
	print("dano")
	var s := Shumi.new()
	var sentinela := Inimigo.new("Sentinela", "", 550, 60, 40, 95)
	checar(Combatente.calcular_dano(s, sentinela, 1.0) == 107, "corte na Sentinela: 150 * 100/140 = 107")
	checar(Combatente.calcular_dano(sentinela, s, 1.0) == 40, "Sentinela na Shumi: 60 * 100/150 = 40")


func _teste_tipos() -> void:
	print("tipos de dano")
	var e := Tipos.efetividade
	var pares := [
		[Tipos.FISICO, Tipos.ARCANO, Tipos.SUPER], [Tipos.FISICO, Tipos.NATUREZA, Tipos.POUCO],
		[Tipos.FOGO, Tipos.GELO, Tipos.SUPER], [Tipos.FOGO, Tipos.AGUA, Tipos.POUCO],
		[Tipos.AGUA, Tipos.FOGO, Tipos.SUPER], [Tipos.AGUA, Tipos.ELETRICIDADE, Tipos.POUCO],
		[Tipos.GELO, Tipos.NATUREZA, Tipos.SUPER], [Tipos.GELO, Tipos.FOGO, Tipos.POUCO],
		[Tipos.ELETRICIDADE, Tipos.AGUA, Tipos.SUPER], [Tipos.ELETRICIDADE, Tipos.NATUREZA, Tipos.POUCO],
		[Tipos.NATUREZA, Tipos.ELETRICIDADE, Tipos.SUPER], [Tipos.NATUREZA, Tipos.FOGO, Tipos.POUCO],
		[Tipos.VENENO, Tipos.NATUREZA, Tipos.SUPER], [Tipos.VENENO, Tipos.ACIDO, Tipos.POUCO],
		[Tipos.ACIDO, Tipos.FISICO, Tipos.SUPER], [Tipos.ACIDO, Tipos.AGUA, Tipos.POUCO],
		[Tipos.LUZ, Tipos.TREVAS, Tipos.SUPER], [Tipos.TREVAS, Tipos.LUZ, Tipos.SUPER],
	]
	var erros := pares.filter(func(p: Array) -> bool: return e.call(p[0], p[1]) != p[2])
	checar(erros.is_empty(), "tabela de efetividade (%d relações) %s" % [pares.size(), erros])
	checar(e.call(Tipos.FISICO, Tipos.FISICO) == 1.0 and e.call(Tipos.FOGO, Tipos.LUZ) == 1.0, "sem relação definida: x1")
	var arcano_ok := Tipos.TODOS.all(func(t: String) -> bool:
		return e.call(Tipos.ARCANO, t) == (Tipos.POUCO if t == Tipos.FISICO else Tipos.SUPER))
	checar(arcano_ok, "Arcano: x2 contra todos, menos Físico (x0,5)")
	checar(Tipos.TODOS.all(func(t: String) -> bool: return e.call(t, Tipos.ARCANO) == Tipos.SUPER),
		"alvo Arcano recebe x2 de todos os tipos, inclusive Arcano (sem acumular)")
	checar(e.call(Tipos.NATUREZA, Tipos.FISICO) == 1.0 and e.call(Tipos.FOGO, Tipos.VENENO) == 1.0,
		"Arcano atacando não deixa ninguém vulnerável a outros tipos")

	var s := Shumi.new()
	checar(s.tipo == Tipos.FISICO, "a Shumi é do tipo Físico")
	checar(s.habilidades(1).filter(func(h: Dictionary) -> bool: return h.acao in ["basico", "skill"]).all(
		func(h: Dictionary) -> bool: return h.tipo == Tipos.FISICO), "Corte e Engo-ji causam dano Físico")
	checar(not _hab(s, "ult", 1).has("tipo"), "o Kaioken (sem dano) não tem tipo")
	var neutro := Inimigo.new("N", "", 550, 60, 40, 95)
	var arcano := Inimigo.new("A", "", 550, 60, 40, 95, 0, Tipos.ARCANO)
	var planta := Inimigo.new("P", "", 550, 60, 40, 95, 0, Tipos.NATUREZA)
	# dano base da Shumi numa Sentinela: 150 * 100/140
	var base := 150.0 * 100.0 / 140.0
	checar(Combatente.calcular_dano(s, neutro, 1.0) == roundi(base), "Físico em Físico: dano normal")
	checar(Combatente.calcular_dano(s, arcano, 1.0) == roundi(base * Tipos.SUPER), "Físico em Arcano: forte")
	checar(Combatente.calcular_dano(s, planta, 1.0) == roundi(base * Tipos.POUCO), "Físico em Natureza: fraco")
	checar(Combatente.calcular_dano(s, neutro, 1.0, 0.5, Tipos.ACIDO) == roundi(base * Tipos.SUPER), "o ataque pode ter outro tipo que o do atacante")
	checar(Combatente.calcular_dano(arcano, s, 1.0) == roundi(60.0 * Tipos.POUCO * 100.0 / 150.0), "Arcano na Shumi (Físico): fraco")
	checar(neutro.proximo_golpe().tipo == neutro.tipo, "golpe do inimigo usa o tipo dele")


func _teste_estados() -> void:
	print("estados (buffs, debuffs, escudo)")
	var c := Combatente.new("C", true, 1000, 100, 0, 100)
	var e := Estado.new("teste", "Teste", "T", "buff", 2)
	e.mods = {"atq": 0.3}
	c.aplicar_estado(e)
	var igual := Estado.new("teste", "Teste", "T", "buff", 2)
	igual.mods = {"atq": 0.3}
	c.aplicar_estado(igual)
	checar(c.estados.size() == 1 and is_equal_approx(c.atq(), 130.0), "o mesmo estado renova em vez de acumular (ATQ +30%, não +60%)")
	checar(c.passar_turno().is_empty() and c.passar_turno().size() == 1 and c.estados.is_empty(), "dura 2 turnos do portador e some")
	checar(is_equal_approx(c.atq(), 100.0), "o bônus sai junto")
	var esc := Estado.new("escudo", "Escudo", "E", "buff", 3)
	esc.escudo = 100
	c.aplicar_estado(esc)
	checar(c.absorver(60) == 60 and c.escudo() == 40, "o escudo absorve o golpe primeiro")
	checar(c.absorver(70) == 40 and c.estado("escudo") == null, "o escudo quebra e o resto passa")
	var alvo := Combatente.new("A", false, 1000, 100, 0, 100)
	checar(Combatente.calcular_dano(c, alvo, 1.0, 0.5, "", true) == 150, "crítico causa x1,5")


func _teste_andri_lente_e_disparo() -> void:
	print("andri: lente elemental e disparo")
	var a := Andri.new()
	checar(a.tipo == Tipos.FOGO and a.lente == Tipos.FOGO, "Andri é Fogo e começa com a lente em Fogo")
	checar(a.trocar_lente(Tipos.AGUA) and a.lente == Tipos.AGUA, "troca a lente para Água")
	checar(not a.trocar_lente(Tipos.AGUA) and not a.trocar_lente(Tipos.ARCANO) and not a.trocar_lente(Tipos.FISICO),
		"não troca para o mesmo elemento nem para Arcano/Físico")
	checar(a.motivo_invalido("lente", Tipos.AGUA, a) == "", "manter a lente atual é uma escolha válida")
	var kit := a.habilidades(1)
	checar(kit[0].tipo == Tipos.AGUA and kit[0].selo == "ÁGU", "o Disparo usa e mostra o elemento da lente")
	checar(_hab_em(kit, "lente").acao == "lente" and _hab_em(kit, "lente").livre and _hab_em(kit, "lente").opcoes.size() == Andri.LENTES.size(), "escolher a lente não gasta o turno e tem os 7 elementos")
	checar(_hab_em(kit, "lente").passiva and _hab_em(kit, "lente").tecla == "" and _hab_em(kit, "lente").ao_iniciar_turno and _hab_em(kit, "lente").opcao_padrao == Tipos.AGUA,
		"a lente é passiva: fora da barra, abre sozinha no começo do turno e já sugere a atual")
	checar(_hab_em(kit, "lente").seletor == "radial" and _hab_em(kit, "lente").opcoes.filter(func(o: Dictionary) -> bool: return o.atual).size() == 1
		and _hab_em(kit, "lente").opcoes[1].sigla == "ÁGU", "a lente abre em anel no personagem, com siglas e a atual marcada")
	checar(a.efeitos()[0].id == "lente" and a.efeitos()[0].nome == "Lente: Água", "a lente aparece nos efeitos")

	var golpes := a.golpes_disparo()
	checar(golpes.size() == 2 and golpes[0].fonte == "andri" and golpes[1].fonte == "momc", "cada Disparo tem o golpe do Andri e o do MOMC")
	checar(golpes.all(func(g: Dictionary) -> bool: return g.tipo == Tipos.AGUA), "os dois usam o elemento da lente")
	checar(not golpes[0].extra and golpes[1].extra, "o golpe do MOMC é adicional: não dispara outros golpes nem efeitos de acerto")
	var fogo := Inimigo.new("F", "", 550, 60, 40, 95, 0, Tipos.FOGO)
	var base := 130.0 * 100.0 / 140.0
	checar(Combatente.calcular_dano(a, fogo, golpes[0].mult, 0.5, golpes[0].tipo) == roundi(base * Andri.MULT_DISPARO * Tipos.SUPER),
		"Disparo de Água num inimigo de Fogo é super efetivo")
	checar(Combatente.calcular_dano(a, fogo, golpes[1].mult, 0.5, golpes[1].tipo) == roundi(base * Andri.MULT_MOMC * Tipos.SUPER),
		"o MOMC calcula o dano dele à parte, com a mesma tabela")
	# Thorim no Andri: o golpe dele ganha o extra elétrico; o do MOMC (extra) não pede extras
	a.aplicar_estado(Andri.estado_artefato("thorim", a, a.lente))
	var extras := a.golpes_extras(golpes[0].mult)
	checar(extras.size() == 1 and extras[0].tipo == Tipos.AGUA and is_equal_approx(extras[0].mult, Andri.MULT_DISPARO * Andri.MULT_THORIM),
		"Braço de Thorim: +30% do golpe no elemento da lente (Água)")
	checar(a.golpes_extras(golpes[0].mult).size() == 1, "o extra do Thorim não se consome")


func _teste_andri_analise() -> void:
	print("andri: análise de vulnerabilidade")
	var a := Andri.new()
	var pedra := Inimigo.new("Pedra", "", 550, 60, 40, 95)
	var agua := Inimigo.new("Água", "", 550, 60, 40, 95, 0, Tipos.AGUA)
	var arcano := Inimigo.new("Arc", "", 550, 60, 40, 95, 0, Tipos.ARCANO)
	checar(a.motivo_invalido("skill", Tipos.FOGO, pedra) == "", "pode expor Fogo num inimigo Físico")
	checar(a.motivo_invalido("skill", Tipos.ACIDO, pedra) != "", "não aplica fraqueza a um elemento que já é super efetivo (Ácido em Físico)")
	checar(a.motivo_invalido("skill", Tipos.FOGO, arcano) != "", "não aplica em Arcano, que já recebe x2 de tudo")
	checar(a.motivo_invalido("skill", Tipos.FOGO, a) != "", "não aplica em aliado")
	checar(a.elementos_analise() == [Tipos.FOGO], "sem equipe, só o elemento do próprio Andri")
	var s := Shumi.new()
	var sombra := Combatente.new("Sombra", true, 1000, 100, 0, 100, Tipos.TREVAS)
	var outro_fogo := Combatente.new("Chama", true, 1000, 100, 0, 100, Tipos.FOGO)
	var time: Array[Combatente] = [s, a, sombra, outro_fogo]
	a.aliados_vivos = func() -> Array: return time.filter(func(c: Combatente) -> bool: return c.vivo())
	checar(a.elementos_analise() == [Tipos.FISICO, Tipos.FOGO, Tipos.TREVAS], "com Shumi e um aliado de Trevas: Físico, Fogo e Trevas, sem repetir")
	checar(_hab(a, "skill", 1).opcoes.map(func(o: Dictionary) -> String: return o.id) == [Tipos.FISICO, Tipos.FOGO, Tipos.TREVAS],
		"o seletor da Análise mostra só esses elementos")
	checar(a.motivo_invalido("skill", Tipos.GELO, pedra) != "", "não aplica elemento que ninguém da equipe tem")
	checar(a.motivo_invalido("skill", Tipos.TREVAS, pedra) == "", "aplica o elemento de um aliado (Trevas)")
	sombra.hp = 0
	checar(Tipos.TREVAS not in a.elementos_analise(), "aliado caído não conta")
	for c in time:
		c.hp = 0
	checar(a.elementos_analise() == [Tipos.FOGO], "com a equipe toda caída, a lista nunca fica vazia")
	for c in time:
		c.hp = c.hp_max

	var antes := Combatente.calcular_dano(a, pedra, 1.0, 0.5, Tipos.FOGO)
	pedra.aplicar_estado(Andri.fraqueza(Tipos.FOGO))
	checar(pedra.efetividade_contra(Tipos.FOGO) == Tipos.SUPER, "com a fraqueza, Fogo passa a ser super efetivo")
	checar(Combatente.calcular_dano(a, pedra, 1.0, 0.5, Tipos.FOGO) == roundi(antes * Tipos.SUPER), "e o dano usa o multiplicador da tabela")
	checar(pedra.efetividade_contra(Tipos.AGUA) == 1.0, "outros elementos não mudam")
	agua.aplicar_estado(Andri.fraqueza(Tipos.FOGO))
	checar(agua.efetividade_contra(Tipos.FOGO) == Tipos.SUPER, "a fraqueza vence uma resistência (Fogo em Água: x0,5 -> x2)")
	pedra.aplicar_estado(Andri.fraqueza(Tipos.GELO))
	checar(pedra.estados.size() == 1 and pedra.efetividade_contra(Tipos.GELO) == Tipos.SUPER and pedra.efetividade_contra(Tipos.FOGO) == 1.0,
		"uma fraqueza por vez: a nova substitui a antiga e renova a duração")
	checar(pedra.efeitos()[0].tipo == "debuff" and pedra.efeitos()[0].turnos == Andri.DURACAO_FRAQUEZA and pedra.efeitos()[0].curto == "GEL",
		"aparece como debuff com elemento e turnos")
	pedra.passar_turno()
	checar(pedra.efetividade_contra(Tipos.GELO) == Tipos.SUPER, "ainda ativa depois de 1 turno do inimigo")
	pedra.passar_turno()
	checar(pedra.estados.is_empty() and pedra.efetividade_contra(Tipos.GELO) == 1.0, "expira depois de %d turnos do inimigo" % Andri.DURACAO_FRAQUEZA)
	var kit := a.habilidades(1)
	checar(_hab_em(kit, "skill").custo_pontos == 1 and _hab_em(kit, "skill").opcao_padrao == Tipos.FISICO, "a Análise custa 1 ponto e começa no primeiro elemento da equipe")
	a.aliados_vivos = Callable()  # a lambda guarda o time, que contém o próprio Andri


func _teste_andri_arsenal() -> void:
	print("andri: arsenal titânico")
	var a := Andri.new()
	var s := Shumi.new()
	var ini := Inimigo.new("I", "", 550, 60, 40, 95)
	var kit := a.habilidades(1)
	checar(_hab_em(kit, "ult").alvo == "aliado" and _hab_em(kit, "ult").opcoes.size() == Andri.ARTEFATOS.size() and _hab_em(kit, "ult").opcoes.size() == 8, "a ult mira aliados e oferece os 8 artefatos")
	checar(_hab_em(kit, "ult").opcoes.all(func(o: Dictionary) -> bool: return o.has("icone") and o.descricao != ""), "cada artefato tem ícone e descrição")
	checar(not a.pode_usar("ult", 1), "começa sem energia para a ult (60/120)")
	a.energia = 120
	checar(a.pode_usar("ult", 1), "com 120 de energia pode usar")
	checar(a.motivo_invalido("ult", "odyn", ini) != "", "artefatos não vão para inimigos")
	checar(a.motivo_invalido("ult", "freya", s) != "", "Raiz de Freya recusa alvo com HP cheio e sem efeitos negativos")
	checar(a.motivo_invalido("ult", "nada", s) != "", "artefato desconhecido é recusado")

	a.usar_artefato("odyn", s)
	checar(a.energia == 0.0 and is_equal_approx(s.chance_critico(), Andri.CRIT_ODYN), "Olho de Odyn: gasta a energia e dá +50% de crítico")
	for i in Andri.DURACAO_ARTEFATO:
		s.passar_turno()
	checar(s.chance_critico() == 0.0, "e expira depois de %d turnos do portador" % Andri.DURACAO_ARTEFATO)

	a.usar_artefato("tyr", s)
	checar(s.escudo() == roundi(s.hp_max * Andri.ESCUDO_TYR), "Mão de Tyr: escudo de 25% do HP máximo")
	s.energia = 120
	s.ultar()
	s.sobrecarga_inicio_turno()
	checar(s.hp == s.hp_max - 36 and s.escudo() == 300, "o dreno do Kaioken ignora o escudo (é custo, não golpe)")

	var frio := Combatente.new("Frio", true, 1000, 100, 0, 100)
	a.usar_artefato("hodir", frio)
	var inimigo_lento := Inimigo.new("L", "", 550, 60, 40, 100)
	var av_antes_lento := inimigo_lento.av
	var lentos := frio.estados_ao_acertar()
	checar(lentos.size() == 1 and lentos[0].id == "lento", "Manto de Hodir: o próximo golpe do portador aplica Lento")
	inimigo_lento.aplicar_estado(lentos[0])
	checar(is_equal_approx(inimigo_lento.vel(), 100.0 * (1.0 + Andri.VEL_LENTO)) and inimigo_lento.av > av_antes_lento,
		"Lento: VEL -30%, e a vez do inimigo demora mais")
	checar(frio.estados.is_empty() and frio.estados_ao_acertar().is_empty(), "o Manto se consome nesse golpe")
	for i in Andri.DURACAO_LENTO:
		inimigo_lento.passar_turno()
	checar(is_equal_approx(inimigo_lento.vel(), 100.0), "Lento expira depois de %d turnos do inimigo" % Andri.DURACAO_LENTO)

	var vitima := Inimigo.new("V", "", 550, 60, 40, 100)
	var portador := Combatente.new("P", true, 1000, 100, 0, 100)
	a.usar_artefato("loken", portador)
	var aplicados := portador.estados_ao_acertar()
	checar(aplicados.size() == 1 and aplicados[0].id == "enganado", "Sussurro de Loken: os golpes do portador aplicam Enganado")
	var av_antes := vitima.av
	vitima.aplicar_estado(aplicados[0])
	checar(is_equal_approx(vitima.atq(), 60.0 * (1.0 + Andri.ATQ_ENGANADO)) and vitima.av > av_antes, "Enganado: ATQ -25% e a vez atrasa")
	var av_depois := vitima.av
	vitima.aplicar_estado(portador.estados_ao_acertar()[0])
	checar(is_equal_approx(vitima.av, av_depois), "renovar o Enganado não atrasa de novo")

	var robusto := Combatente.new("Rob", true, 1000, 100, 50, 100)
	robusto.hp = 800
	a.usar_artefato("archaedas", robusto)
	checar(robusto.hp_max == 1300 and robusto.hp == 1100, "Cinturão de Archaedas: HP máximo +30% (e o HP atual sobe junto)")
	a.usar_artefato("archaedas", robusto)
	checar(robusto.hp_max == 1300 and robusto.hp == 1100, "renovar o Cinturão não acumula")
	robusto.receber_dano(50)
	for i in Andri.DURACAO_ARTEFATO:
		robusto.passar_turno()
	checar(robusto.hp_max == 1000 and robusto.hp == 1000, "ao acabar, o HP máximo volta e o excedente é cortado")

	var r_portador := Combatente.new("R", true, 1000, 100, 0, 100)
	a.trocar_lente(Tipos.GELO)
	a.usar_artefato("ra", r_portador)
	a.trocar_lente(Tipos.FOGO)
	var ra := r_portador.golpes_extras(1.0)
	checar(ra.size() == 1 and ra[0].tipo == Tipos.GELO and ra[0].mult == Andri.MULT_RA,
		"Lança de Rá: o próximo golpe ganha dano do elemento da lente na hora da entrega (Gelo)")
	checar(_hab(a, "ult", 1).opcoes[7].descricao.contains("Fogo"), "a descrição dos artefatos de dano mostra o elemento atual da lente")
	checar(r_portador.golpes_extras(1.0).is_empty() and r_portador.estados.is_empty(), "a Lança se consome no primeiro golpe")

	var ferido := Shumi.new()
	ferido.hp = 500
	ferido.aplicar_estado(Andri.fraqueza(Tipos.FOGO))
	ferido.turnos_exaustao = 2
	checar(a.motivo_invalido("ult", "freya", ferido) == "", "Raiz de Freya aceita aliado ferido")
	var r := a.usar_artefato("freya", ferido)
	checar(r.cura == 360 and ferido.hp == 860, "Raiz de Freya: cura 30% do HP máximo")
	checar(r.limpos == 1 and ferido.estados.is_empty(), "e remove os debuffs")
	checar(ferido.turnos_exaustao == 2, "a exaustão do Kaioken é custo do kit, não debuff: continua")
	var cheio := Shumi.new()
	checar(a.usar_artefato("freya", cheio).cura == 0, "a cura não passa do HP máximo")


func _teste_descricao_interface() -> void:
	print("descrição para a interface")
	var s := Shumi.new()
	var estados := func(pontos: int) -> Array:
		return s.habilidades(pontos).map(func(h: Dictionary) -> String: return h.estado)
	checar(s.habilidades(0).map(func(h: Dictionary) -> String: return h.tecla) == ["Q", "E", "W", "R", ""], "barra na ordem básico, skill, skill 2, ult e a passiva por último")
	checar(estados.call(0) == ["pronta", "sem_recurso", "sem_recurso", "sem_recurso", "pronta"], "sem pontos e sem energia: só o Corte (e a passiva)")
	checar(not s.pode_usar("skill", 0) and s.pode_usar("skill", 1), "Engo-ji precisa de 1 ponto")
	s.energia = 120
	checar(estados.call(1) == ["pronta", "pronta", "pronta", "pronta", "pronta"], "com ponto e energia: tudo pronto")
	checar(_hab(s, "ult", 1).custo_energia == 120 and _hab(s, "ult", 1).selo == "x2", "Kaioken mostra custo 120 e próximo nível x2")
	checar(s.efeitos().is_empty(), "sem efeitos fora do Kaioken")
	s.ultar()
	checar(s.efeitos()[0].id == "kaioken" and s.efeitos()[0].turnos == Shumi.DURACAO, "Kaioken aparece como efeito com os turnos")
	checar(_hab(s, "ult", 1).custo_energia == 80, "subir de nível custa 80")
	s.nivel = 2
	checar(_hab(s, "skill", 1).alvo == "todos" and _hab(s, "skill", 1).nome == "Engo-ji Beam: Devastação", "Engo-ji no x10 vira Devastação e atravessa todos")
	s.nivel = 3
	s.energia = 120
	checar(_hab(s, "ult", 1).estado == "bloqueada" and not s.pode_usar("ult", 1), "no x20 o Kaioken fica bloqueado")
	s.turnos_kaioken = 1
	s.fim_turno()
	var ids: Array = s.efeitos().map(func(e: Dictionary) -> String: return e.id)
	checar(ids == ["exaustao", "perde_turno"], "depois do x20: exausta e perde o turno")
	var g := Inimigo.new("G", "", 100, 1, 0, 100, 2)
	checar(g.efeitos().is_empty(), "Guardião sem aviso antes da hora")
	g.registrar_acao()
	checar(g.efeitos()[0].tipo == "alerta", "aviso de Golpe Pesado na ação anterior a ele")


func _teste_equipe() -> void:
	print("equipe")
	Elenco.definir_equipe([])
	checar(Elenco.equipe() == ["shumi"], "sem escolha, a equipe padrão é a Shumi")
	Elenco.definir_equipe(["andri"])
	checar(Elenco.equipe() == ["shumi"], "quem ainda não chegou à Torre não entra na equipe")
	Progressao.desbloquear("andri")
	Elenco.definir_equipe(["shumi", "ninguem", "shumi", "andri", "andri"])
	checar(Elenco.equipe() == ["shumi", "andri"], "repetidos e desconhecidos saem da equipe")
	Elenco.definir_equipe(["ninguem"])
	checar(Elenco.equipe() == ["shumi"], "ids desconhecidos são ignorados")
	Elenco.definir_equipe([])
	for id in Elenco.IDS:
		var d := Elenco.dados(id)
		checar(Elenco.criar(id).aliado and d.acoes != null and d.sprite.has("png") and d.get("universo", "") != "", "%s cadastrado completo" % id)
		var passivas := Elenco.criar(id).habilidades(1).filter(func(h: Dictionary) -> bool: return h.get("passiva", false))
		checar(not passivas.is_empty() and passivas.all(func(h: Dictionary) -> bool:
				return h.tecla == "" and h.get("icone", "") != "" and h.descricao != ""),
			"%s explica as passivas na barra, no mesmo padrão dos outros" % id)
		var kit := Elenco.criar(id).habilidades(1)
		checar(kit.size() == 5 and kit[0].acao == "basico" and kit[1].acao == "skill" and kit[3].acao == "ult" and kit[4].get("passiva", false)
			and (kit[2].acao == "skill2" or kit[2].get("passiva", false)), "%s segue a ordem: básico, skill, skill 2, ult e passiva" % id)
	var gerador: GDScript = load("res://ferramentas/gerar_readme_personagens.gd")
	for id in Elenco.IDS:
		var readme := FileAccess.get_file_as_string(gerador.arquivo(id))
		checar(readme == gerador.com_trecho(readme, gerador.trecho(id)),
			"README de %s em dia com o kit (rode ferramentas/gerar_readme_personagens.gd)" % id)
	checar(Elenco.dados("shumi").universo == "Dragon Ball New Age" and Elenco.dados("andri").universo == "Tales of Azeroth",
		"cada personagem diz de onde vem")
	var a := Combatente.new("A", true, 100, 1, 0, 100)
	var b := Combatente.new("B", true, 100, 1, 0, 100)
	var ini := Inimigo.new("I", "", 100, 1, 0, 100)
	checar(ini.escolher_alvo([a, b], 0.0) == a and ini.escolher_alvo([a, b], 0.99) == b, "inimigo sorteia entre os aliados")
	a.hp = 0
	checar(ini.escolher_alvo([a, b], 0.0) == b, "inimigo não ataca quem já caiu")
	b.hp = 0
	checar(ini.escolher_alvo([a, b], 0.5) == null, "sem aliados vivos, sem alvo")
	var s := Shumi.new()
	var livres := s.habilidades(1).filter(func(h: Dictionary) -> bool: return h.get("livre", false))
	checar(livres.size() == 1 and livres[0].acao == "ult", "só o Kaioken não gasta o turno")
	checar(Elenco.equipe() == ["shumi"] and "andri" in Elenco.IDS, "Andri está no elenco")


func _teste_askara_fragmentos() -> void:
	print("askara: fragmentos d'alma")
	var a := Askara.new()
	checar(a.fragmentos == Askara.FRAGMENTOS_INICIAIS and a.energia_max == 0.0, "começa com 2 fragmentos e sem energia")
	checar(a.ganhar_fragmentos(10) == Askara.FRAGMENTOS_MAX - 2 and a.fragmentos == Askara.FRAGMENTOS_MAX, "fragmentos param no máximo (8)")
	checar(a.ao_inimigo_cair() == "", "no máximo, um inimigo caído não dá nada")
	a.fragmentos = 3
	checar(a.ao_inimigo_cair() != "" and a.fragmentos == 4, "inimigo caído dá 1 fragmento")
	var ini := Inimigo.new("I", "", 1000, 100, 0, 100)
	var dano := Combatente.calcular_dano(a, ini, Askara.MULT_SETA, 0.5)
	checar(dano == roundi(125 * 0.6), "Seta Vil: 0,6x do ATQ (75)")
	checar(a.habilidades(0).map(func(h: Dictionary) -> String: return h.tecla) == ["Q", "E", "", "R", ""], "barra na mesma ordem, com o Último Ato (passiva) no lugar da skill 2")
	checar(a.habilidades(0)[0].ganho_pontos == 1, "Seta Vil gera ponto de skill")
	checar(a.efeitos()[0].id == "fragmentos" and a.efeitos()[0].curto == "4", "fragmentos aparecem nos efeitos")


func _teste_askara_invocacao() -> void:
	print("askara: invocação")
	var a := Askara.new()
	a.aplicar_nivel(5, Progressao.atributos(a.atributos_nv1(), Elenco.dados("askara").crescimento, 5))
	a.fragmentos = 0
	checar(not a.pode_usar("skill", 3), "sem fragmentos, sem invocação")
	checar(_hab(a, "skill", 3).estado == "sem_recurso" and _hab(a, "skill", 3).falta.begins_with("Faltam"), "a barra explica o que falta")
	a.fragmentos = 1
	checar(not a.pode_usar("skill", 0) and a.pode_usar("skill", 1), "invocar custa 1 ponto de skill")
	checar(a.motivo_invalido("skill", "shivara", a) != "" and a.motivo_invalido("skill", "diabrete", a) == "", "cada invocação tem seu custo")
	var r := a.invocar("diabrete")
	var dia: Invocacao = r.invocacao
	checar(r.nova and a.fragmentos == 0 and a.em_campo() == [dia], "Diabrete custa 1 e entra em campo")
	checar(dia.aliado and dia.invocador == a and dia.tipo == Tipos.TREVAS, "invocação é aliada, de Trevas, e sabe quem a chamou")
	checar(dia.hp_max == roundi(a.hp_max * 0.25) and is_equal_approx(dia.vel_base, a.vel_base * 1.25),
		"atributos em fração dos da Askara no nível atual")
	dia.hp = 1
	dia.turnos = 1
	a.fragmentos = 8
	r = a.invocar("diabrete")
	checar(not r.nova and r.invocacao == dia and dia.hp == dia.hp_max and dia.turnos == dia.turnos_max and a.fragmentos == 7,
		"invocar a mesma renova HP e vezes (e cobra)")
	var emi: Invocacao = a.invocar("emissario").invocacao
	r = a.invocar("shivara")
	checar(r.sai == dia and not dia.em_campo and a.em_campo() == [emi, r.invocacao], "sem vaga, a mais antiga sai")
	checar(emi.peso_alvo() == 1.0 + Askara.PROVOCACAO_EMISSARIO, "Emissário do Caos provoca")
	checar(not emi.passar_vez() and not emi.passar_vez() and emi.passar_vez(), "vai embora depois de 3 vezes")
	var lil: Invocacao = Askara.new().invocar("lilith").invocacao
	var e: Estado = lil.debuff.call()
	checar(e.tipo == "debuff" and is_equal_approx(e.mods.atq, -0.2) and is_equal_approx(e.mods.def, -0.2), "Lilith encanta: ATQ e DEF -20%")


func _teste_askara_lorde() -> void:
	print("askara: lorde demônio")
	var a := Askara.new()
	a.fragmentos = 5
	checar(a.custo_lorde() == 6 and not a.pode_usar("ult", 0), "o Lorde custa 6 fragmentos")
	a.fragmentos = 8
	a.invocar("diabrete")
	a.invocar("emissario")
	checar(a.custo_lorde() == 4 and _hab(a, "ult", 1).selo == "4 FRA", "cada invocação em campo desconta 1")
	a.fragmentos = 4
	var r := a.invocar_lorde(0.5)
	var lorde: Invocacao = r.invocacao
	checar(r.apagadas.size() == 2 and a.em_campo() == [lorde] and a.fragmentos == 0, "o Lorde apaga as invocações e fica sozinho")
	checar(lorde.id == "lorde_demonio" and not r.raro and lorde.golpe_entrada.alcance == "todos", "Lorde Demônio, com golpe de chegada em todos")
	a.fragmentos = 8
	checar(not a.pode_usar("skill", 3) and a.motivo_invalido("skill", "diabrete", a).begins_with("O Lorde"), "com o Lorde em campo, o E fica bloqueado")
	checar(_hab(a, "skill", 3).estado == "bloqueada" and not a.pode_usar("ult", 3), "e não dá para chamar outro Lorde")
	lorde.em_campo = false
	checar(a.pode_usar("skill", 3), "quando ele vai embora, o E volta")
	r = a.invocar_lorde(0.005)
	var luz: Invocacao = r.invocacao
	checar(r.raro and luz.id == "lorde_luz" and luz.tipo == Tipos.LUZ, "sorteio abaixo da chance (15%): vem o Lorde da Luz")
	var ini := Inimigo.new("I", "", 1000, 100, 0, 100)
	var comum := Combatente.new("C", true, 1000, 1, 0, 100)
	checar(Combatente.calcular_dano(ini, luz, 1.0) == roundi(Combatente.calcular_dano(ini, comum, 1.0) * 0.5 * 100.0 / (100.0 + luz.defesa())),
		"Lorde da Luz resiste a todo dano (-50%)")


func _teste_invocacao_alvos_e_provocacao() -> void:
	print("invocação: alvos e provocação")
	var a := Askara.new()
	var inv := Invocacao.new("x", "X", a, 100, 10, 0, 100, Tipos.TREVAS, 3)
	var i1 := Inimigo.new("A", "", 100, 10, 0, 100)
	var i2 := Inimigo.new("B", "", 100, 50, 0, 100)
	var i3 := Inimigo.new("C", "", 100, 20, 0, 100)
	var ini := [i1, i2, i3]
	var alvos := inv.alvos({"mult": 0.9, "alcance": "vizinhos", "mult_vizinhos": 0.45}, ini, 0)
	checar(alvos == [[i1, 0.9], [i2, 0.45]], "vizinhos: o marcado e o do lado")
	alvos = inv.alvos({"mult": 0.3, "mira": "mais_forte"}, ini, 0)
	checar(alvos == [[i2, 0.3]], "mira no mais forte (maior ATQ)")
	checar(inv.alvos({"mult": 1.0, "alcance": "todos"}, ini, 2).size() == 3, "todos")
	var c := Combatente.new("C", true, 100, 1, 0, 100)
	var p := Estado.new("provocacao", "P", "P", "buff", -1)
	p.provocacao = 2.0
	inv.aplicar_estado(p)
	# pesos 1 + 3: o sorteio abaixo de 1/4 cai no comum, o resto no provocador
	checar(i1.escolher_alvo([c, inv], 0.2) == c and i1.escolher_alvo([c, inv], 0.3) == inv, "provocação pesa no sorteio do inimigo")


## Askara numa batalha de verdade (andar 3): invocações entram na fila e no
## lado aliado, saem quando caem, o Lorde ataca todos e as invocações não
## seguram a derrota. Os inimigos não agem (a vez deles fica longe).
func _teste_askara_na_batalha() -> void:
	print("askara na batalha")
	Progressao.apagar()
	for n in range(1, 3):
		Progressao.marcar_andar_vencido(n)
	Andares.escolher(3)
	Elenco.definir_equipe(["askara"])
	var b: Batalha = (load("res://scenes/batalha.tscn") as PackedScene).instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	for ini in b.inimigos:
		ini.av = 1e9
	var a := b.equipe[0] as Askara
	checar(a != null, "a Askara entra na batalha pelo Elenco")
	a.fragmentos = 8
	var emi: Invocacao = a.invocar("emissario").invocacao
	await b.adicionar_invocacao(emi)
	checar(emi in b.lutadores and b.aliados_em_campo() == [a, emi] and b.aliados_vivos() == [a],
		"a invocação entra na fila e no campo, mas não na equipe")
	checar(b.inimigos[0].escolher_alvo(b.aliados_em_campo(), 0.5) == emi, "os inimigos podem mirar nela (e o Emissário provoca)")
	var ini: Inimigo = b.inimigos_vivos()[0]
	var hp_antes := ini.hp
	await b.golpe_invocacao(emi, emi.golpe)
	checar(ini.hp < hp_antes, "o golpe da invocação machuca o inimigo marcado")
	emi.hp = 1
	await b.aplicar_dano(ini, emi, 5.0)
	checar(not emi.em_campo and emi not in b.lutadores and b.invocacoes.is_empty() and not b.acabou, "invocação que cai sai de campo; a luta segue")
	checar(a.estado("escudo_emissario") != null and a.escudo() == roundi(emi.hp_max * 0.08),
		"ao cair, o Emissário deixa a Muralha do Caos em quem tem menos HP")
	var dia: Invocacao = a.invocar("diabrete").invocacao
	await b.adicionar_invocacao(dia)
	var lil: Invocacao = a.invocar("lilith").invocacao
	await b.adicionar_invocacao(lil)
	checar(b.invocacoes.size() == 2 and b.visual(dia).position != b.visual(lil).position, "duas invocações, em vagas diferentes")
	b.alvo = 0
	var hps_antes := b.inimigos_vivos().map(func(i: Inimigo) -> int: return i.hp)
	dia.hp = 1
	await b.aplicar_dano(b.inimigos_vivos()[0], dia, 5.0)
	var depois := b.inimigos.map(func(i: Inimigo) -> int: return i.hp)
	checar(not dia.em_campo and dia not in b.lutadores and b.invocacoes == [lil], "o Diabrete caiu e saiu de campo")
	checar(depois[0] < hps_antes[0] and (hps_antes.size() < 2 or depois[1] < hps_antes[1]),
		"ao cair, a Explosão Vil acerta o alvo e o inimigo ao lado")
	dia = a.invocar("diabrete").invocacao
	await b.adicionar_invocacao(dia)
	a.fragmentos = 8
	var r := a.invocar_lorde(0.5)
	for x: Invocacao in r.apagadas:
		b.remover_invocacao(x)
	var lorde: Invocacao = r.invocacao
	await b.adicionar_invocacao(lorde)
	var hps := b.inimigos_vivos().map(func(i: Inimigo) -> int: return i.hp)
	await b.golpe_invocacao(lorde, lorde.golpe_entrada)
	var vivos := b.inimigos_vivos()
	var todos_levaram := true
	for i in vivos.size():
		todos_levaram = todos_levaram and vivos[i].hp < hps[i]
	checar(b.invocacoes == [lorde] and todos_levaram, "o Lorde apaga as outras e acerta todos ao chegar")
	var frag := a.fragmentos
	var alvo: Inimigo = b.inimigos_vivos()[0]
	alvo.hp = 1
	await b.aplicar_dano(a, alvo, 1.0)
	checar(a.fragmentos == frag + 1, "inimigo caído dá fragmento à Askara")
	a.hp = 1
	await b.aplicar_dano(b.inimigos_vivos()[0], a, 50.0)
	checar(b.acabou and b.invocacoes.is_empty(), "a Askara caiu: as invocações somem e a luta acaba (elas não seguram a derrota)")
	b.queue_free()
	await process_frame


func _teste_recarga() -> void:
	print("recarga")
	var s := Shumi.new()
	checar(s.recarga("skill2") == 0 and s.pode_usar("skill2", 1), "sem uso, a skill 2 está pronta")
	s.iniciar_recarga("skill2", 3)
	var h := _hab(s, "skill2")
	checar(not s.pode_usar("skill2", 1) and h.estado == "recarga" and h.recarga_restante == 3 and h.falta.begins_with("Recarga"),
		"usada, entra em recarga e a barra mostra quanto falta")
	s.passar_turno()
	s.passar_turno()
	checar(s.recarga("skill2") == 1 and not s.pode_usar("skill2", 1), "a recarga conta os turnos do dono")
	s.passar_turno()
	checar(s.pode_usar("skill2", 1) and _hab(s, "skill2").estado == "pronta", "recarga 3: volta 3 turnos depois do uso")


func _teste_shumi_bang() -> void:
	print("shumi: bang!")
	var s := Shumi.new()
	var ini := Inimigo.new("Alvo", "", 1000, 10, 0, 100)
	var h := _hab(s, "skill2")
	checar(h.tecla == "W" and h.custo_pontos == 1 and h.recarga == Shumi.RECARGA_BANG and h.alvo == "unico", "Bang! na tecla W, custa 1 ponto e tem recarga")
	var andri := Andri.new()
	checar(s.atacar_junto(andri, ini).is_empty(), "sem o Bang!, não ataca junto")
	s.aplicar_estado(Shumi.estado_bang())
	checar(s.atacar_junto(s, ini).is_empty(), "o próprio ataque dela não puxa outro")
	var antes := s.energia
	var g := s.atacar_junto(andri, ini)
	checar(g.nome == "Finger Beam" and is_equal_approx(g.mult, 0.4) and s.energia == antes + Shumi.ENERGIA_JUNTO,
		"com o Bang!: Finger Beam de 0,4x e +4 de energia por ataque junto")
	s.nivel = 3
	checar(is_equal_approx(s.atacar_junto(andri, ini).mult, 1.1), "no x20 o Finger Beam vai a 1,1x")
	s.nivel = -1
	s.iniciar_recarga("skill2", Shumi.RECARGA_BANG)
	for i in Shumi.DURACAO_BANG:
		s.passar_turno()
	checar(s.estado("bang") == null and s.atacar_junto(andri, ini).is_empty(), "o Bang! acaba depois da duração")
	checar(not s.pode_usar("skill2", 1), "quando o Bang! acaba, a recarga ainda segura um turno sem ele")
	s.passar_turno()
	checar(s.pode_usar("skill2", 1), "e no turno seguinte ele volta")

func _teste_andri_protocolo() -> void:
	print("andri: protocolo MOMC")
	var a := Andri.new()
	var ini := Inimigo.new("Alvo", "", 1000, 10, 0, 100)
	var h := _hab(a, "skill2")
	checar(h.tecla == "W" and h.opcoes.map(func(o: Dictionary) -> String: return o.id) == ["sobrecarga", "escudo"]
		and h.opcoes[1].alvo == "aliado" and h.opcoes[0].alvo == "unico", "duas ordens, cada uma com o próprio alvo")
	checar(a.motivo_invalido("skill2", "escudo", a) == "" and a.motivo_invalido("skill2", "escudo", ini) != "", "o Escudo vai num aliado")
	checar(a.motivo_invalido("skill2", "sobrecarga", ini) == "" and a.motivo_invalido("skill2", "sobrecarga", a) != "", "a Sobrecarga vai num inimigo")
	checar(Andri.escudo_momc(a).escudo == roundi(a.hp_max * Andri.ESCUDO_MOMC) and Andri.ESCUDO_MOMC < Andri.ESCUDO_TYR,
		"o escudo do MOMC é menor que o da Mão de Tyr")
	a.trocar_lente(Tipos.GELO)
	var g := a.golpe_sobrecarga()
	checar(g.tipo == Tipos.GELO and g.extra, "a Sobrecarga usa a lente e não encadeia")


func _teste_askara_ultimo_ato() -> void:
	print("askara: último ato")
	var a := Askara.new()
	var passivas := a.habilidades(1).filter(func(h: Dictionary) -> bool: return h.get("passiva", false))
	checar(passivas.map(func(h: Dictionary) -> String: return h.acao) == ["ultimo_ato", "fragmentos"] and not a.pode_usar("skill2", 3),
		"o Último Ato é passiva (sem W)")
	a.fragmentos = 8
	var dia: Invocacao = a.invocar("diabrete").invocacao
	checar(dia.ultimo_ato.nome == "Explosão Vil" and Askara.INVOCACOES.all(func(d: Dictionary) -> bool: return d.has("ultimo_ato")),
		"cada demônio tem último ato")
	var inimigos: Array = [Inimigo.new("A", "", 100, 1, 0, 100), Inimigo.new("B", "", 100, 1, 0, 100), Inimigo.new("C", "", 100, 1, 0, 100)]
	var dupla := func(alvo: int) -> Array:
		return dia.alvos(dia.ultimo_ato, inimigos, alvo).map(func(par: Array) -> Combatente: return par[0])
	checar(dupla.call(0) == [inimigos[0], inimigos[1]] and dupla.call(2) == [inimigos[2], inimigos[1]], "a Explosão Vil pega o alvo e o de trás (ou o da frente, no último)")
	var emi: Invocacao = a.invocar("emissario").invocacao
	var shumi := Shumi.new()
	shumi.hp = 100
	checar(emi.alvo_escudo([a, emi, shumi]) == shumi, "a Muralha do Caos vai em quem tem a menor fração de HP")
	a.fragmentos = 8
	var lorde: Invocacao = a.invocar_lorde(0.5).invocacao
	checar(lorde.ultimo_ato.is_empty(), "os Lordes não têm último ato")


func _teste_bang_na_batalha() -> void:
	print("bang! na batalha")
	Progressao.apagar()
	Andares.escolher(1)
	for n in range(1, 3):
		Progressao.marcar_andar_vencido(n)
	Progressao.desbloquear("andri")
	Andares.escolher(3)
	Elenco.definir_equipe(["shumi", "andri"])
	var b: Batalha = (load("res://scenes/batalha.tscn") as PackedScene).instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	for ini in b.inimigos:
		ini.av = 1e9
	var s := b.equipe[0] as Shumi
	var andri := b.equipe[1]
	s.aplicar_estado(Shumi.estado_bang())
	var ini: Inimigo = b.inimigos_vivos()[0]
	var energia_antes := s.energia
	b._primeiro_atingido = null
	await b.aplicar_dano(andri, ini, 0.1)
	var hp_antes := ini.hp
	await b._ataques_em_conjunto(andri)
	checar(ini.hp < hp_antes and is_equal_approx(s.energia, minf(s.energia_max, energia_antes + Shumi.ENERGIA_JUNTO)),
		"o Andri acerta e a Shumi ataca junto o mesmo inimigo (+4 de energia)")
	b._primeiro_atingido = null
	await b.aplicar_dano(s, ini, 0.1)
	hp_antes = ini.hp
	await b._ataques_em_conjunto(s)
	checar(ini.hp == hp_antes, "o ataque dela mesma não puxa um ataque junto")
	b._primeiro_atingido = null
	await b.aplicar_dano(ini, s, 0.1)
	await b._ataques_em_conjunto(ini)
	checar(b._primeiro_atingido == null, "golpe de inimigo não conta")
	var acoes := b._acoes[s] as AcoesShumi
	var normal := b.visual(s).frames()
	s.remover_estado("bang")
	acoes.executar("skill2")  # sem await: confere o visual no meio do tiro
	await process_frame
	checar(b.visual(s).frames() != normal, "o Finger Beam do Bang! sai no visual Kokoro")
	for i in 600:
		if s.estado("bang"):
			break
		await process_frame
	checar(s.estado("bang") != null and b.visual(s).frames() == normal, "depois do tiro, volta ao visual normal (o Bang! continua)")
	b.queue_free()
	await process_frame

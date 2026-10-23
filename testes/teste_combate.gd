extends SceneTree
## Testes da lógica de combate, sem interface.
## Rodar: godot --headless --path . -s testes/teste_combate.gd

var _falhas := 0


func _init() -> void:
	# a equipe é salva no progresso: os testes usam um arquivo só deles
	Progressao.arquivo = "user://teste_combate_progresso.cfg"
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
	Progressao.apagar()
	print("\n%s (%d falha%s)" % ["TUDO OK" if _falhas == 0 else "FALHOU", _falhas, "" if _falhas == 1 else "s"])
	quit(1 if _falhas else 0)


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
	checar(s.habilidades(1).filter(func(h: Dictionary) -> bool: return h.acao != "ult").all(
		func(h: Dictionary) -> bool: return h.tipo == Tipos.FISICO), "Corte e Engo-ji causam dano Físico")
	checar(not s.habilidades(1)[2].has("tipo"), "o Kaioken (sem dano) não tem tipo")
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
	checar(kit[3].acao == "lente" and kit[3].livre and kit[3].opcoes.size() == Andri.LENTES.size(), "escolher a lente não gasta o turno e tem os 7 elementos")
	checar(kit[3].passiva and kit[3].tecla == "" and kit[3].ao_iniciar_turno and kit[3].opcao_padrao == Tipos.AGUA,
		"a lente é passiva: fora da barra, abre sozinha no começo do turno e já sugere a atual")
	checar(kit[3].seletor == "radial" and kit[3].opcoes.filter(func(o: Dictionary) -> bool: return o.atual).size() == 1
		and kit[3].opcoes[1].sigla == "ÁGU", "a lente abre em anel no personagem, com siglas e a atual marcada")
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
	checar(a.habilidades(1)[1].opcoes.map(func(o: Dictionary) -> String: return o.id) == [Tipos.FISICO, Tipos.FOGO, Tipos.TREVAS],
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
	checar(kit[1].custo_pontos == 1 and kit[1].opcao_padrao == Tipos.FISICO, "a Análise custa 1 ponto e começa no primeiro elemento da equipe")
	a.aliados_vivos = Callable()  # a lambda guarda o time, que contém o próprio Andri


func _teste_andri_arsenal() -> void:
	print("andri: arsenal titânico")
	var a := Andri.new()
	var s := Shumi.new()
	var ini := Inimigo.new("I", "", 550, 60, 40, 95)
	var kit := a.habilidades(1)
	checar(kit[2].alvo == "aliado" and kit[2].opcoes.size() == Andri.ARTEFATOS.size() and kit[2].opcoes.size() == 8, "a ult mira aliados e oferece os 8 artefatos")
	checar(kit[2].opcoes.all(func(o: Dictionary) -> bool: return o.has("icone") and o.descricao != ""), "cada artefato tem ícone e descrição")
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
	checar(a.habilidades(1)[2].opcoes[7].descricao.contains("Fogo"), "a descrição dos artefatos de dano mostra o elemento atual da lente")
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
	checar(s.habilidades(0).map(func(h: Dictionary) -> String: return h.tecla) == ["Q", "E", "R"], "barra na ordem Q, E, R")
	checar(estados.call(0) == ["pronta", "sem_recurso", "sem_recurso"], "sem pontos e sem energia: só o Corte")
	checar(not s.pode_usar("skill", 0) and s.pode_usar("skill", 1), "Engo-ji precisa de 1 ponto")
	s.energia = 120
	checar(estados.call(1) == ["pronta", "pronta", "pronta"], "com ponto e energia: tudo pronto")
	checar(s.habilidades(1)[2].custo_energia == 120 and s.habilidades(1)[2].selo == "x2", "Kaioken mostra custo 120 e próximo nível x2")
	checar(s.efeitos().is_empty(), "sem efeitos fora do Kaioken")
	s.ultar()
	checar(s.efeitos()[0].id == "kaioken" and s.efeitos()[0].turnos == Shumi.DURACAO, "Kaioken aparece como efeito com os turnos")
	checar(s.habilidades(1)[2].custo_energia == 80, "subir de nível custa 80")
	s.nivel = 2
	checar(s.habilidades(1)[1].alvo == "todos" and s.habilidades(1)[1].nome == "Engo-ji Beam: Devastação", "Engo-ji no x10 vira Devastação e atravessa todos")
	s.nivel = 3
	s.energia = 120
	checar(s.habilidades(1)[2].estado == "bloqueada" and not s.pode_usar("ult", 1), "no x20 o Kaioken fica bloqueado")
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

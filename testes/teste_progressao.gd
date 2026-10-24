extends SceneTree
## Testes de níveis e experiência: regras da Progressao, atributos por
## nível, desbloqueio, recompensa de batalha (com a cena de verdade) e save.
## Rodar: godot --headless --path . -s testes/teste_progressao.gd

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
	Progressao.arquivo = "user://teste_progressao.cfg"
	# a história (quem chega depois) é testada com a chave temporária de
	# todos liberados desligada
	Elenco.todos_liberados = false
	Progressao.apagar()

	_teste_inicio()
	_teste_curva()
	_teste_subir()
	_teste_varios_niveis()
	_teste_crescimento_individual()
	_teste_hp_ao_subir()
	_teste_nivel_maximo()
	_teste_nivel_de_entrada()
	_teste_limite_da_torre()
	_teste_desbloqueio()
	_teste_persistencia()
	_teste_save_antigo()
	await _teste_batalha_vitoria()
	await _teste_batalha_derrota()
	await _teste_xp_compartilhada()

	Progressao.apagar()
	print("\n%s (%d falha%s)" % ["TUDO OK" if _falhas == 0 else "FALHOU", _falhas, "" if _falhas == 1 else "s"])
	quit(1 if _falhas else 0)


func _limpar() -> void:
	Progressao.apagar()


## Todos os andares vencidos: o limite da Torre fica no mais alto (9).
func _liberar_torre() -> void:
	for n in range(1, Andares.total()):
		Progressao.marcar_andar_vencido(n)


# ------------------------------------------------------------------ testes
func _teste_inicio() -> void:
	print("início")
	_limpar()
	checar(Progressao.progresso("shumi") == {"nivel": 1, "xp": 0}, "sem save, começa no nível 1 com 0 XP")
	var s := Elenco.criar("shumi")
	checar(s.nivel_personagem == 1 and s.hp_max == 1200 and s.hp == 1200, "Shumi nível 1: HP 1200 (o do kit)")
	checar(is_equal_approx(s.atq_base, 150.0) and is_equal_approx(s.def_base, 50.0) and is_equal_approx(s.vel_base, 105.0),
		"Shumi nível 1: ATQ 150, DEF 50, VEL 105")
	var a := Elenco.criar("andri")
	checar(a.hp_max == 1000 and is_equal_approx(a.atq_base, 130.0) and is_equal_approx(a.vel_base, 112.0),
		"Andri nível 1: HP 1000, ATQ 130, VEL 112")
	checar(a.energia == 60.0 and a.energia_max == 120.0, "o nível não mexe na energia")


func _teste_curva() -> void:
	print("curva de experiência")
	checar(Progressao.xp_para_subir(1) == 100 and Progressao.xp_para_subir(2) == 150 and Progressao.xp_para_subir(3) == 200
		and Progressao.xp_para_subir(19) == 1000, "100, 150, 200... 1000 para ir do 19 ao 20")
	checar(Progressao.xp_acumulada(9, 0) == 2200 and Progressao.xp_acumulada(2, 30) == 130, "XP total: 2200 até o nível 9")
	var crescente := true
	for n in range(1, Progressao.NIVEL_MAX - 1):
		crescente = crescente and Progressao.xp_para_subir(n + 1) > Progressao.xp_para_subir(n)
	checar(crescente, "cada nível custa mais que o anterior")
	checar(Progressao.xp_para_subir(Progressao.NIVEL_MAX) == 0, "no nível máximo não há próximo")
	var ini: Array[Inimigo] = [Inimigo.new("S", "", 550, 1, 0, 100), Inimigo.new("G", "", 1400, 1, 0, 100)]
	checar(Progressao.xp_da_batalha(ini) == 66 + 168, "XP pelo HP dos inimigos (66 + 168)")
	ini[0].xp = 10
	checar(Progressao.xp_da_batalha(ini) == 10 + 168, "inimigo com XP própria usa a dele")
	ini[1].receber_dano(500)
	checar(Progressao.xp_inimigo(ini[1]) == 168, "a XP vem do HP de definição, não do atual")


func _teste_subir() -> void:
	print("subir de nível")
	_limpar()
	var r := Progressao.conceder_xp("shumi", 60)
	checar(r.nivel == 1 and r.xp_atual == 60 and r.ganhos.is_empty(), "60 XP: continua no 1 com 60/100")
	r = Progressao.conceder_xp("shumi", 50)
	checar(r.nivel_antes == 1 and r.nivel == 2 and r.xp_atual == 10, "mais 50: sobe para o 2 e sobram 10")
	checar(Elenco.criar("shumi").nivel_personagem == 2, "o lutador criado depois já vem no nível 2")


func _teste_varios_niveis() -> void:
	print("vários níveis de uma vez")
	checar(Progressao.somar_xp(1, 0, 100 + 150 + 200 + 5) == {"nivel": 4, "xp": 5}, "455 XP no nível 1: vai ao 4 com 5 de sobra")
	_limpar()
	_liberar_torre()
	var r := Progressao.conceder_xp("andri", 900)
	# 100 + 150 + 200 + 250 = 700; sobram 200 dos 300 do 5 -> 6
	checar(r.nivel_antes == 1 and r.nivel == 5 and r.xp_atual == 200, "900 XP: nível 5 com 200/300")
	checar(r.ganhos.hp == 4 * 50 and r.ganhos.atq == 22 and r.ganhos.vel == 4, "ganhos somam os 4 níveis (HP +200, ATQ +22, VEL +4)")


func _teste_crescimento_individual() -> void:
	print("crescimento individual")
	var s := Elenco.criar("shumi", 10)
	var a := Elenco.criar("andri", 10)
	checar(s.hp_max == 1200 + 9 * 60 and is_equal_approx(s.atq_base, 150 + 9 * 8.0), "Shumi nível 10: HP 1740, ATQ 222")
	checar(a.hp_max == 1000 + 9 * 50 and is_equal_approx(a.atq_base, 130 + 9 * 5.5), "Andri nível 10: HP 1450, ATQ 179,5")
	var cs: Dictionary = Elenco.dados("shumi").crescimento
	var ca: Dictionary = Elenco.dados("andri").crescimento
	checar(cs.atq > ca.atq and ca.vel > cs.vel and ca.def > cs.def, "Shumi cresce mais em ATQ; Andri em VEL e DEF")
	checar(is_equal_approx(s.atq(), s.atq_base), "fora de combate, ATQ efetivo = base do nível (sem bônus)")
	s._bonus_extra["atq"] = 0.5
	checar(is_equal_approx(s.atq(), 222.0 * 1.5), "bônus temporário multiplica a base do nível")
	s.aplicar_nivel(10, Progressao.atributos(s.atributos_nv1(), cs, 10))
	s.aplicar_nivel(10, Progressao.atributos(s.atributos_nv1(), cs, 10))
	checar(s.hp_max == 1740 and is_equal_approx(s.atq_base, 222.0) and is_equal_approx(s.atq(), 333.0),
		"reaplicar o mesmo nível não acumula nada")


func _teste_hp_ao_subir() -> void:
	print("HP ao subir de nível")
	var cs: Dictionary = Elenco.dados("shumi").crescimento
	var s := Elenco.criar("shumi", 1)
	s.aplicar_nivel(3, Progressao.atributos(s.atributos_nv1(), cs, 3))
	checar(s.hp_max == 1320 and s.hp == 1320, "com HP cheio, continua cheio (1320/1320)")
	s = Elenco.criar("shumi", 1)
	s.hp = 500
	s.aplicar_nivel(2, Progressao.atributos(s.atributos_nv1(), cs, 2))
	checar(s.hp_max == 1260 and s.hp == 560, "ferida, ganha só o que o máximo ganhou (500 -> 560)")
	s.aplicar_nivel(1, Progressao.atributos(s.atributos_nv1(), cs, 1))
	checar(s.hp_max == 1200 and s.hp == 560, "voltar o nível não cura nem passa do máximo")
	s.hp = 1200
	s.aplicar_nivel(1, Progressao.atributos(s.atributos_nv1(), cs, 1))
	var e := Andri.estado_artefato("archaedas", s, Tipos.FOGO)
	s.aplicar_estado(e)
	s.aplicar_nivel(2, Progressao.atributos(s.atributos_nv1(), cs, 2))
	checar(s.hp_max == 1260 + e.vida_extra and s.hp <= s.hp_max, "vida extra de estado continua por cima do nível")
	s.remover_estado(e.id)
	checar(s.hp_max == 1260, "ao sair o estado, sobra o HP máximo do nível")
	s.hp = 0
	s.aplicar_nivel(3, Progressao.atributos(s.atributos_nv1(), cs, 3))
	checar(s.hp == 0, "quem caiu não levanta por subir de nível")


func _teste_nivel_maximo() -> void:
	print("nível máximo")
	checar(Progressao.somar_xp(1, 0, 999999) == {"nivel": Progressao.NIVEL_MAX, "xp": 0}, "sem limite da Torre, muita XP para no 20 com 0 XP")
	checar(Progressao.somar_xp(20, 0, 5000) == {"nivel": 20, "xp": 0}, "no 20, XP nova não sobe nem acumula")
	checar(Progressao.somar_xp(5, 0, 999999, 40).nivel == 20, "um limite acima do máximo vale como 20")
	checar(Elenco.criar("shumi", 25).hp_max == 1200 + 19 * 60, "atributos param no nível 20")
	checar(Progressao.somar_xp(25, 0, 10).nivel == 20, "nível acima do máximo é corrigido")


func _teste_nivel_de_entrada() -> void:
	print("nível de entrada")
	checar(Progressao.nivel_de_entrada([8, 9, 10, 11]) == 10, "8, 9, 10, 11 (média 9,5) -> 10")
	checar(Progressao.nivel_de_entrada([3, 4, 4, 5]) == 4, "3, 4, 4, 5 -> 4")
	checar(Progressao.nivel_de_entrada([1, 2]) == 2, "1,5 arredonda para cima -> 2")
	checar(Progressao.nivel_de_entrada([]) == 1, "sem equipe -> 1")
	checar(Progressao.nivel_de_entrada([20, 20, 20]) == 20 and Progressao.nivel_de_entrada([0, -3]) == 1, "fica entre 1 e 20")


func _teste_limite_da_torre() -> void:
	print("limite da Torre")
	_limpar()
	var limites: Array = range(1, Andares.total() + 1).map(func(n: int) -> int: return Andares.limite_do_andar(n))
	checar(limites == [3, 5, 7, 9], "limites por andar mais alto liberado: 3, 5, 7, 9")
	checar(Andares.limite_nivel() == 3, "jogo novo: limite 3")
	var r := Progressao.conceder_xp("shumi", 999)
	checar(r.nivel == 3 and r.xp_atual == 0 and r.no_limite and r.xp_aproveitada == 250, "muita XP: para no 3, XP 0, só 250 contam")
	r = Progressao.conceder_xp("shumi", 999)
	checar(r.nivel == 3 and r.xp_atual == 0 and r.xp_aproveitada == 0 and r.ganhos.is_empty(), "repetir no limite não dá nada")
	Andares.concluir(1)
	checar(Andares.limite_nivel() == 5, "liberar o andar 2 sobe o limite para 5")
	checar(Progressao.progresso("shumi") == {"nivel": 3, "xp": 0}, "subir o limite não dá níveis guardados")
	r = Progressao.conceder_xp("shumi", 120)
	checar(r.nivel == 3 and r.xp_atual == 120 and not r.no_limite, "a XP volta a contar normalmente (120/200)")
	Andares.concluir(1)
	checar(Andares.limite_nivel() == 5, "repetir um andar não sobe o limite")
	# save antigo acima do limite: não perde nível, só não ganha XP
	_limpar()
	Progressao._guardar("shumi", {"nivel": 8, "xp": 0})
	r = Progressao.conceder_xp("shumi", 500)
	checar(r.nivel == 8 and r.xp_aproveitada == 0 and Elenco.criar("shumi").nivel_personagem == 8,
		"acima do limite (save antigo): fica no 8, sem ganhar XP")


func _teste_desbloqueio() -> void:
	print("personagem desbloqueado")
	_limpar()
	_liberar_torre()
	# Shumi no 7 (100+150+200+250+300+350 = 1350) e como equipe principal
	Progressao.conceder_xp("shumi", 1350)
	Elenco.definir_equipe(["shumi"])
	checar(Progressao.nivel("shumi") == 7 and Progressao.equipe_principal() == ["shumi"], "equipe principal: Shumi no 7")
	var p := Progressao.desbloquear("andri")
	checar(p == {"nivel": 7, "xp": 0}, "Andri entra no nível médio da equipe (7) com 0 XP")
	var a := Elenco.criar("andri")
	checar(a.nivel_personagem == 7 and a.hp_max == 1000 + 6 * 50 and is_equal_approx(a.atq_base, 130 + 6 * 5.5),
		"atributos do próprio Andri no 7 (HP 1300, ATQ 163)")
	var s := Elenco.criar("shumi")
	checar(a.hp_max != s.hp_max and a.atq_base != s.atq_base and a.tipo != s.tipo, "não copia nada da Shumi")
	Progressao.conceder_xp("shumi", 5000)
	checar(Progressao.desbloquear("andri") == {"nivel": 7, "xp": 0}, "desbloquear de novo não muda o nível")
	_limpar()
	Progressao.conceder_xp("shumi", 250)
	Progressao.conceder_xp("askara", 250)
	checar(Progressao.equipe_salva().is_empty() and Progressao.desbloquear("andri").nivel == 3,
		"sem equipe salva: média dos liberados (Shumi e Askara no 3)")
	_limpar()
	Progressao._guardar("shumi", {"nivel": 8, "xp": 0})
	Elenco.definir_equipe(["shumi"])
	checar(Progressao.desbloquear("andri").nivel == 3, "média acima do limite (Shumi no 8, limite 3): entra no 3")
	checar(Elenco.disponiveis() == Elenco.IDS.filter(func(id: String) -> bool: return Elenco.dados(id).get("inicial", true) or id == "andri"),
		"liberados: os iniciais e os desbloqueados")


func _teste_persistencia() -> void:
	print("persistência")
	_limpar()
	Progressao.desbloquear("andri")
	Progressao.conceder_xp("shumi", 300)
	Elenco.definir_equipe(["andri", "shumi"])
	var antes := Progressao.progresso("shumi")
	Progressao.recarregar()  # como abrir o jogo de novo
	checar(Progressao.progresso("shumi") == antes and antes.nivel == 3, "nível e XP voltam do arquivo (nível 3)")
	checar(Elenco.equipe() == ["andri", "shumi"], "a equipe principal também volta do arquivo")
	checar(Progressao.progresso("andri") == {"nivel": 1, "xp": 0}, "quem não lutou continua no 1")
	Elenco.definir_equipe(["shumi"])
	checar(Progressao.nivel("andri") == 1 and Progressao.nivel("shumi") == 3, "trocar a equipe não mexe no progresso")


func _teste_save_antigo() -> void:
	print("save antigo ou estranho")
	_limpar()
	var cfg := ConfigFile.new()
	cfg.set_value("jogador", "equipe", ["shumi", "fantasma"])
	cfg.set_value("personagem_shumi", "nivel", 99)
	cfg.set_value("personagem_shumi", "xp", 777)
	cfg.set_value("personagem_andri", "xp", 5000)
	cfg.save(Progressao.arquivo)
	Progressao.recarregar()
	checar(Progressao.progresso("shumi") == {"nivel": 20, "xp": 0}, "nível acima do máximo vira 20 (e XP 0)")
	checar(Progressao.progresso("andri") == {"nivel": 1, "xp": 99}, "sem nível: 1, com a XP limitada ao nível")
	checar(Elenco.equipe() == ["shumi"], "ids que não existem mais saem da equipe")
	_limpar()
	cfg = ConfigFile.new()
	cfg.set_value("hud", "qualquer", true)  # arquivo sem nada de progresso
	cfg.save(Progressao.arquivo)
	Progressao.recarregar()
	checar(Progressao.progresso("andri") == {"nivel": 1, "xp": 0} and Elenco.equipe() == ["shumi"], "save sem progresso: padrões")


# --------------------------------------------- batalha (cena de verdade)
## Batalha no `andar` (os anteriores contam como vencidos), com o Andri liberado.
func _abrir_batalha(ids: Array[String], andar := 3) -> Batalha:
	Progressao.desbloquear("andri")
	for n in range(1, andar):
		Progressao.marcar_andar_vencido(n)
	Andares.escolher(andar)
	Elenco.definir_equipe(ids)
	var b: Batalha = (load("res://scenes/batalha.tscn") as PackedScene).instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	return b


func _fechar(b: Batalha) -> void:
	b.queue_free()
	await process_frame


func _teste_batalha_vitoria() -> void:
	print("vitória")
	_limpar()
	var b := await _abrir_batalha(["shumi", "andri"])
	var xp := Progressao.xp_da_batalha(b.inimigos)
	checar(xp == 600, "o andar 3 vale 600 XP")
	b.equipe[1].hp = 0  # quem caiu na luta também ganha
	for ini in b.inimigos:
		ini.hp = 0
	b._verificar_fim()
	checar(b.acabou and b.recompensas.size() == Elenco.disponiveis().size()
		and b.recompensas.filter(func(r: Dictionary) -> bool: return r.participou).size() == 2,
		"a vitória gera uma recompensa por personagem (quem lutou e quem ficou de fora)")
	# 100 + 150 + 200 = 450: nível 4 com 150 (limite 7)
	checar(Progressao.progresso("shumi") == {"nivel": 4, "xp": 150} and Progressao.progresso("andri") == {"nivel": 4, "xp": 150},
		"600 XP: os dois vão do 1 ao 4 (sobram 150)")
	checar(b.recompensas[0].nivel_antes == 1 and b.recompensas[0].ganhos.hp == 180, "a recompensa diz quem subiu e quanto ganhou")
	b._verificar_fim()
	b._terminar(true, "de novo")
	b._recompensar()
	checar(Progressao.progresso("shumi") == {"nivel": 4, "xp": 150}, "fim repetido na mesma batalha não dá XP de novo")
	Progressao.recarregar()
	checar(Progressao.progresso("andri") == {"nivel": 4, "xp": 150}, "a XP da vitória já está no arquivo")
	await _fechar(b)
	b = await _abrir_batalha(["shumi"])
	checar(b.equipe[0].nivel_personagem == 4 and b.equipe[0].hp_max == 1380, "a batalha seguinte já começa no nível 4")
	await _fechar(b)


func _teste_xp_compartilhada() -> void:
	print("XP de quem ficou de fora")
	_limpar()
	var b := await _abrir_batalha(["shumi"])
	for ini in b.inimigos:
		ini.hp = 0
	b._verificar_fim()
	var por_id := {}
	for r in b.recompensas:
		por_id[r.id] = r
	checar(por_id.size() == 3 and por_id.shumi.participou and not por_id.andri.participou and not por_id.askara.participou,
		"o Andri e a Askara, na reserva, entram na recompensa")
	checar(por_id.andri.xp == por_id.shumi.xp and Progressao.progresso("andri") == Progressao.progresso("shumi"),
		"e ganha a mesma XP de quem lutou")
	await _fechar(b)
	# bloqueado não ganha (nem é liberado pela recompensa)
	_limpar()
	Andares.escolher(1)
	Elenco.definir_equipe(["shumi"])
	b = (load("res://scenes/batalha.tscn") as PackedScene).instantiate()
	root.add_child(b)
	await process_frame
	for ini in b.inimigos:
		ini.hp = 0
	b._verificar_fim()
	checar(not b.recompensas.any(func(r: Dictionary) -> bool: return r.id == "andri") and not Progressao.desbloqueado("andri")
		and Progressao.progresso("andri").xp == 0,
		"quem ainda não chegou à Torre não ganha XP")
	await _fechar(b)


func _teste_batalha_derrota() -> void:
	print("derrota")
	_limpar()
	var b := await _abrir_batalha(["shumi"])
	for c in b.equipe:
		c.hp = 0
	b._verificar_fim()
	checar(b.acabou and b.recompensas.is_empty(), "derrota não gera recompensa")
	checar(Progressao.progresso("shumi") == {"nivel": 1, "xp": 0}, "derrota não dá XP")
	await _fechar(b)

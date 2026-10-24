class_name AcoesAskara
extends AcoesPersonagem
## Animações e efeitos do kit da Àskara (regras em Askara). As invocações
## entram, agem e saem pela batalha (Batalha.adicionar_invocacao e
## golpe_invocacao); aqui fica só o que ela mesma faz.

## Orbe vil ao lado dela no quadro "conjurar", a partir dos pés (em pixels
## da tela; ver ferramentas/gerar_askara.py).
const ORBE := Vector2(33, -54)

var k: Askara:
	get: return p as Askara


func executar(acao: String) -> void:
	match acao:
		"basico": await _seta_vil()
		"skill": await _invocar()
		"ult": await _lorde()


func _conjurar() -> void:
	v.tocar("conjurar")
	await b.esperar(0.27)


# ------------------------------------------------------------- seta vil
func _seta_vil() -> void:
	var alvo := b.alvo_atual()
	b.hud.registrar("%s utilizou %s!" % [HudBatalha.nome(k), HudBatalha.destaque("Seta Vil", Askara.COR_VIL)])
	await _conjurar()
	var voo := EfeitosCombate.projetil(b.mundo, v.position + ORBE, centro(alvo), k.tipo, 1100.0, 1.0)
	await b.esperar(voo)
	EfeitosCombate.impacto_elemental(b.mundo, centro(alvo), k.tipo, 0.9)
	EfeitosCombate.impacto(b.mundo, centro(alvo), Askara.COR_VIL, 0.6)
	await b.aplicar_dano(k, alvo, Askara.MULT_SETA)
	_ganhou_fragmentos(k.ganhar_fragmentos(Askara.FRAGMENTOS_SETA))
	await b.esperar(0.2)


func _ganhou_fragmentos(qtd: int) -> void:
	if qtd <= 0:
		return
	EfeitosCombate.numero(b.mundo, v.topo() + Vector2(0, -6), "+%d FRAGMENTO" % qtd, "aviso")
	EfeitosCombate.anel(b.mundo, v.position + ORBE, Askara.COR_ASKARA, 18.0)
	b.hud.registrar("%s ganha %s (%d/%d)." % [HudBatalha.nome(k),
		HudBatalha.destaque("Fragmento d'Alma", Askara.COR_ASKARA), k.fragmentos, Askara.FRAGMENTOS_MAX])
	b.atualizar()


# ------------------------------------------------------------ invocação
func _invocar() -> void:
	var d := Askara.dados_invocacao(b.opcao)
	await _conjurar()
	var r := k.invocar(b.opcao)
	var inv: Invocacao = r.invocacao
	b.hud.registrar("%s gasta %d %s e invoca %s!" % [HudBatalha.nome(k), d.fragmentos,
		"fragmento" if d.fragmentos == 1 else "fragmentos", HudBatalha.destaque(d.nome, d.cor)])
	var sai: Invocacao = r.sai
	if sai:
		b.hud.registrar("%s volta ao abismo para abrir espaço." % HudBatalha.nome(sai))
		b.remover_invocacao(sai)
	if r.nova:
		await b.adicionar_invocacao(inv)
	else:
		var vi := b.visual(inv)
		vi.piscar(Color(1.0 + inv.cor.r, 1.0 + inv.cor.g, 1.0 + inv.cor.b))
		EfeitosCombate.anel(b.mundo, centro(inv), inv.cor, 50.0)
		b.hud.registrar("%s é renovado: HP cheio e mais %d vezes." % [HudBatalha.nome(inv), inv.turnos])
		b.atualizar()
	await b.esperar(0.2)


# ---------------------------------------------------------------- lorde
func _lorde() -> void:
	var custo := k.custo_lorde()
	await _conjurar()
	var r := k.invocar_lorde(randf())
	var inv: Invocacao = r.invocacao
	var apagadas: Array = r.apagadas
	for x: Invocacao in apagadas:
		b.remover_invocacao(x)
	b.hud.registrar("%s gasta %d fragmentos%s e abre o portal!" % [HudBatalha.nome(k), custo,
		"" if apagadas.is_empty() else " (as invocações em campo alimentam o portal)"])
	var veu := EfeitosCombate.veu(b.mundo, Color(inv.cor.darkened(0.8), 0.55), 0.0, true)
	if r.raro:
		b.hud.anunciar("%d%%  ·  %s" % [roundi(Askara.CHANCE_LORDE_LUZ * 100), inv.nome.to_upper()], inv.cor, 30)
		b.hud.registrar("Algo diferente atende ao chamado: o %s!" % HudBatalha.destaque(inv.nome, inv.cor))
	else:
		b.hud.anunciar(inv.nome.to_upper(), inv.cor, 30)
	await b.adicionar_invocacao(inv)
	b.tremer(6.0)
	await b.golpe_invocacao(inv, inv.golpe_entrada)
	EfeitosCombate.sumir_veu(veu, 0.4)
	await b.esperar(0.3)

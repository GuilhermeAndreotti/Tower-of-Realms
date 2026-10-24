class_name AcoesAndri
extends AcoesPersonagem
## Animações e efeitos do kit do Andri e do MOMC (regras em Andri).

const TEXTURA_MOMC := preload("res://personagens/andri/momc.png")
const POS_MOMC := Vector2(-30, 0)  ## à esquerda dos pés, como no sprite original
## Ponta do dispositivo com o braço estendido e a lente no olho, a partir
## dos pés (em pixels da tela; ver ferramentas/gerar_andri.py).
const PONTA_DISPOSITIVO := Vector2(30, -60)
const LENTE := Vector2(-9, -78)

var a: Andri:
	get: return p as Andri

var _momc: Sprite2D


func _init(p_batalha: Batalha, p_personagem: Combatente, p_visual: VisualLutador) -> void:
	super(p_batalha, p_personagem, p_visual)
	_momc = Sprite2D.new()
	_momc.texture = TEXTURA_MOMC
	_momc.centered = false
	_momc.offset = -Vector2(TEXTURA_MOMC.get_width() / 2.0, TEXTURA_MOMC.get_height())
	_momc.scale = Vector2(VisualLutador.ESCALA, VisualLutador.ESCALA)
	_momc.position = POS_MOMC
	v.add_child(_momc)
	# flutua de leve, fora do ritmo do Andri
	var t := _momc.create_tween().set_loops()
	t.tween_property(_momc, "position:y", POS_MOMC.y - 6, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(_momc, "position:y", POS_MOMC.y, 0.7).set_trans(Tween.TRANS_SINE)
	var lente := _Lente.new()
	lente.andri = a
	lente.position = LENTE
	v.add_child(lente)


func executar(acao: String) -> void:
	match acao:
		"basico": await _disparo()
		"skill": await _analise()
		"skill2": await _protocolo()
		"ult": await _arsenal()
		"lente": await _trocar_lente()


## A torre de lentes sai do monóculo.
func ancora_seletor(acao: String) -> Vector2:
	if acao == "lente":
		return LENTE + Vector2(1.5, 1.5)
	return super(acao)


# --------------------------------------------------------------- disparo
func _disparo() -> void:
	var alvo := b.alvo_atual()
	var golpes := a.golpes_disparo()
	b.hud.registrar("%s utilizou %s de %s!" % [HudBatalha.nome(a), HudBatalha.destaque("Disparo Elemental", EstiloUI.OURO),
		HudBatalha.destaque(Tipos.nome(a.lente), Tipos.cor(a.lente))])
	v.tocar("disparo")
	await b.esperar(0.1)
	var voo := EfeitosCombate.projetil(b.mundo, v.position + PONTA_DISPOSITIVO, centro(alvo), a.lente, 1000.0, 1.2)
	await b.esperar(voo)
	EfeitosCombate.impacto_elemental(b.mundo, centro(alvo), a.lente, 1.1)
	await b.aplicar_dano(a, alvo, golpes[0].mult, golpes[0].tipo, golpes[0].extra)
	if alvo.vivo():
		await _ataque_momc(alvo, golpes[1])
	a.ganhar_energia(Andri.ENERGIA_BASICO)
	await b.esperar(0.2)


## O MOMC sobe, os olhos acendem e ele dispara um projétil menor.
func _ataque_momc(alvo: Combatente, golpe: Dictionary, tamanho := 0.7, aviso := "O %s ataca junto!") -> void:
	var base := _momc.position
	var t := _momc.create_tween()
	t.tween_property(_momc, "position", base + Vector2(8, -22), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished
	_momc.modulate = Color(1.6, 1.6, 2.4)
	# lado direito do robô (o MOMC tem ~21 px de largura, com a origem nos pés)
	var boca := v.position + _momc.position + Vector2(9, -12)
	EfeitosCombate.anel(b.mundo, boca, Tipos.cor(golpe.tipo), 14.0)
	var voo := EfeitosCombate.projetil(b.mundo, boca, centro(alvo), golpe.tipo, 1200.0, tamanho)
	var volta := _momc.create_tween()
	volta.tween_property(_momc, "position", base + Vector2(-4, -16), 0.06)
	volta.tween_property(_momc, "position", base, 0.2).set_trans(Tween.TRANS_QUAD)
	volta.parallel().tween_property(_momc, "modulate", Color.WHITE, 0.25)
	await b.esperar(voo)
	EfeitosCombate.impacto_elemental(b.mundo, centro(alvo) + Vector2(6, 8), golpe.tipo, tamanho)
	b.hud.registrar(aviso % HudBatalha.destaque("MOMC", Andri.COR_MOMC))
	await b.aplicar_dano(a, alvo, golpe.mult, golpe.tipo, golpe.extra)


# ------------------------------------------------------ protocolo MOMC
func _protocolo() -> void:
	b.hud.registrar("%s ativa o %s: %s." % [HudBatalha.nome(a), HudBatalha.destaque("Protocolo MOMC", EstiloUI.OURO),
		"Escudo" if b.opcao == "escudo" else "Sobrecarga"])
	v.tocar("analise")
	if b.opcao == "escudo":
		await _escudo_momc(b.aliado_atual())
	else:
		_momc.modulate = Color(2.0, 2.0, 2.6)
		EfeitosCombate.carga(b.mundo, v.position + _momc.position + Vector2(0, -12), [Color.WHITE, Tipos.cor(a.lente)], 0.35, 50.0)
		await b.esperar(0.35)
		await _ataque_momc(b.alvo_atual(), a.golpe_sobrecarga(), 1.3, "O %s dispara em sobrecarga!")
	a.ganhar_energia(Andri.ENERGIA_SKILL)
	b.atualizar()
	await b.esperar(0.3)


## O MOMC voa até o aliado, fecha o escudo em volta dele e volta.
func _escudo_momc(alvo: Combatente) -> void:
	var base := _momc.position
	var va := b.visual(alvo)
	var ida := _momc.create_tween()
	ida.tween_property(_momc, "position", va.position - v.position + Vector2(-26, -va.altura * 0.6), 0.3).set_trans(Tween.TRANS_SINE)
	await ida.finished
	var e := Andri.escudo_momc(alvo)
	alvo.aplicar_estado(e)
	EfeitosCombate.anel(b.mundo, centro(alvo), Andri.COR_MOMC, 46.0)
	EfeitosCombate.impacto(b.mundo, centro(alvo), Color.WHITE, 0.9)
	va.piscar(Color(1.55, 1.8, 2.0))
	EfeitosCombate.numero(b.mundo, va.topo(), "(%d)" % e.escudo, "escudo")
	b.hud.registrar("O %s protege %s: escudo de %s." % [HudBatalha.destaque("MOMC", Andri.COR_MOMC), HudBatalha.nome(alvo),
		HudBatalha.destaque(str(e.escudo), EfeitosCombate.NUMEROS.escudo[0])])
	b.atualizar()
	var volta := _momc.create_tween()
	volta.tween_property(_momc, "position", base, 0.3).set_trans(Tween.TRANS_SINE)
	await volta.finished


# --------------------------------------------------------------- análise
func _analise() -> void:
	var alvo := b.alvo_atual()
	var elemento := b.opcao
	var cor := Tipos.cor(elemento)
	b.hud.registrar("%s utilizou %s em %s." % [HudBatalha.nome(a), HudBatalha.destaque("Análise de Vulnerabilidade", EstiloUI.OURO), HudBatalha.nome(alvo)])
	v.tocar("analise")
	var c := centro(alvo)
	var raio := maxf(30.0, b.visual(alvo).altura * 0.55)
	EfeitosCombate.linha(b.mundo, v.position + PONTA_DISPOSITIVO, c, Color(0.35, 0.9, 1.0), 0.7)
	EfeitosCombate.mira(b.mundo, c, raio, Color(0.35, 0.9, 1.0), 0.7)
	await b.esperar(0.55)
	alvo.aplicar_estado(Andri.fraqueza(elemento))
	EfeitosCombate.mira(b.mundo, c, raio * 0.8, cor, 0.5)
	EfeitosCombate.anel(b.mundo, c, cor, raio * 1.3)
	EfeitosCombate.numero(b.mundo, b.visual(alvo).topo() + Vector2(0, -10), "FRACO A %s" % Tipos.nome(elemento).to_upper(), "aviso")
	b.visual(alvo).piscar(Color(cor.r * 2.0, cor.g * 2.0, cor.b * 2.0))
	b.hud.registrar("%s fica fraco a %s por %d turnos." % [HudBatalha.nome(alvo),
		HudBatalha.destaque(Tipos.nome(elemento), cor), Andri.DURACAO_FRAQUEZA])
	a.ganhar_energia(Andri.ENERGIA_SKILL)
	b.atualizar()
	await b.esperar(0.5)


# ------------------------------------------------------- arsenal titânico
func _arsenal() -> void:
	var id := b.opcao
	var alvo := b.aliado_atual()
	var art := Andri.artefato(id)
	b.hud.anunciar(art.nome.to_upper(), art.cor, 26)
	v.tocar("analise")
	# o artefato surge acima do Andri, brilha e voa até o alvo
	var item := Sprite2D.new()
	item.texture = load(Andri.PASTA + "artefato_%s.png" % id)
	item.scale = Vector2(3, 3)
	item.position = v.topo() + Vector2(0, -10)
	b.mundo.add_child(item)
	EfeitosCombate.anel(b.mundo, item.position, art.cor, 40.0)
	var sobe := item.create_tween()
	sobe.tween_property(item, "position:y", item.position.y - 24, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await sobe.finished
	var de := item.position
	var ate := centro(alvo)
	var altura := 60.0 if alvo != a else 20.0
	var voo := item.create_tween()
	voo.tween_method(func(t: float) -> void:
		item.position = de.lerp(ate, t) + Vector2(0, -sin(t * PI) * altura), 0.0, 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	await voo.finished
	item.queue_free()

	var r := a.usar_artefato(id, alvo)
	_efeito_artefato(id, alvo, art.cor)
	if r.cura > 0:
		EfeitosCombate.numero(b.mundo, b.visual(alvo).topo(), "+%d" % r.cura, "cura")
	var extra := ""
	if r.cura > 0:
		extra += " Recupera %s de HP." % HudBatalha.destaque(str(r.cura), EstiloUI.CURA)
	if r.limpos > 0:
		extra += " Remove %d efeito%s negativo%s." % [r.limpos, "" if r.limpos == 1 else "s", "" if r.limpos == 1 else "s"]
	if r.estado:
		var e: Estado = r.estado
		extra += " " + art.descricao.split(":")[0] + (" (escudo %d)." % e.escudo if e.escudo > 0 else ".")
	b.hud.registrar("%s entrega %s a %s.%s" % [HudBatalha.nome(a), HudBatalha.destaque(art.nome, art.cor), HudBatalha.nome(alvo), extra])
	b.atualizar()
	await b.esperar(0.5)


func _efeito_artefato(id: String, alvo: Combatente, cor: Color) -> void:
	var c := centro(alvo)
	var va := b.visual(alvo)
	va.piscar(Color(1.0 + cor.r, 1.0 + cor.g, 1.0 + cor.b))
	EfeitosCombate.anel(b.mundo, c, cor, 60.0)
	match id:
		"odyn":
			# o olho dourado observa: energia converge e um anel de ouro
			EfeitosCombate.carga(b.mundo, c, [Color(1, 0.95, 0.6), cor], 0.45, 80.0)
		"tyr":
			# aura prateada que fecha em volta do alvo
			EfeitosCombate.anel(b.mundo, c, Color.WHITE, 46.0)
			EfeitosCombate.impacto(b.mundo, c, cor, 1.4)
		"loken":
			# estrela escura que suga a luz, com linhas violetas
			EfeitosCombate.carga(b.mundo, c, [Color(0.12, 0.1, 0.18), cor], 0.45, 70.0)
		"freya":
			# partículas verdes e douradas subindo das raízes
			for i in 3:
				var ponto := va.position + Vector2(randf_range(-20, 20), -20 - 30 * i)
				EfeitosCombate.impacto(b.mundo, ponto, cor if i % 2 == 0 else Color(1, 0.85, 0.4), 0.7)
		"hodir":
			# névoa fria e cristais de gelo
			EfeitosCombate.impacto(b.mundo, c, Color(0.85, 0.95, 1.0), 1.2)
			EfeitosCombate.anel(b.mundo, c, Color.WHITE, 40.0)
		"thorim":
			# descarga azul do bracelete, carregada com o elemento da lente
			EfeitosCombate.relampago(b.mundo, c + Vector2(0, -120), c, cor)
			EfeitosCombate.impacto(b.mundo, c, Tipos.cor(a.lente), 1.2)
		"archaedas":
			# fragmentos de rocha e brilho âmbar
			EfeitosCombate.impacto(b.mundo, va.position + Vector2(0, -6), Color(0.6, 0.6, 0.65), 1.6)
			EfeitosCombate.impacto(b.mundo, c, cor, 0.8)
			b.tremer(3.0)
		"ra":
			# a lança desce com o brilho do elemento da lente
			var cor_lente := Tipos.cor(a.lente)
			EfeitosCombate.feixe(b.mundo, c + Vector2(0, -220), PI / 2, 220.0, 1400.0,
				{"largura": 9.0, "cores": [cor_lente, cor, cor_lente.lightened(0.5), Color.WHITE]}, 0.1)


# ----------------------------------------------------------------- lente
func _trocar_lente() -> void:
	if not a.trocar_lente(b.opcao):
		return  # manteve o elemento
	var cor := Tipos.cor(a.lente)
	EfeitosCombate.anel(b.mundo, v.position + LENTE, cor, 22.0)
	EfeitosCombate.impacto(b.mundo, v.position + LENTE, cor, 0.5)
	b.hud.registrar("%s ajusta a %s: %s." % [HudBatalha.nome(a), HudBatalha.destaque("Lente Elemental", EstiloUI.OURO),
		HudBatalha.destaque(Tipos.nome(a.lente), cor)])
	b.atualizar()
	await b.esperar(0.3)


## O brilho da lente no olho do Andri, na cor do elemento atual.
class _Lente extends Node2D:
	var andri: Andri
	var _tempo := 0.0

	func _process(delta: float) -> void:
		_tempo += delta
		visible = andri.vivo()
		queue_redraw()

	func _draw() -> void:
		var cor := Tipos.cor(andri.lente)
		draw_rect(Rect2(-1.5, -1.5, 6, 6), Color(cor, 0.25 + 0.15 * sin(_tempo * 4.0)))
		draw_rect(Rect2(0, 0, 3, 3), cor.lightened(0.2))

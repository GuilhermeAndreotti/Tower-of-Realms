class_name AcoesShumi
extends AcoesPersonagem
## Animações e efeitos do kit da Shumi (regras em Shumi).
## Tudo que muda com o Kaioken é indexado por `s.nivel + 1` (0 = normal).
## Cada Finger Beam (o do Bang! e os contra-ataques) é dado no visual Kokoro
## (gerado pelo mesmo script do sprite sheet, a partir de kokoro.png); depois
## do tiro ela volta ao visual normal.

const COR_ACO := Color(0.85, 0.92, 1.0)  ## lâmina do Corte
const COR_ONDA := Color(0.78, 0.5, 1.0)  ## faíscas do Engo-ji, no tom da onda
const COR_BRANCA := Color(1, 0.96, 1)
const CORES_AURA: Array[Color] = [Color(0.85, 0.08, 0.1), Color(1.0, 0.35, 0.25), Color(1.0, 0.6, 0.35)]
const PONTA_ONDA := preload("res://efeitos/onda_engo_ji.png")
const FOLHA_KOKORO := "res://personagens/shumi/shumi_kokoro_spritesheet.png"
const JSON_KOKORO := "res://personagens/shumi/shumi_kokoro_spritesheet.json"

## Corte por nível: [duração de cada trecho da investida, velocidade da animação].
const CORTE := [[0.22, 1.0], [0.17, 1.3], [0.15, 1.5], [0.12, 2.0], [0.08, 2.6]]

## Feixe do Engo-ji por nível (ver EfeitosCombate.feixe).
const FEIXES := [
	{"largura": 12.0, "velocidade": 1500.0, "faiscas": 0.0,
		"cores": [Color(0.55, 0.25, 0.85), Color(0.62, 0.33, 0.88), Color(0.85, 0.65, 1.0), Color(0.97, 0.92, 1.0)]},
	{"largura": 18.0, "velocidade": 1700.0, "faiscas": 14.0,
		"cores": [Color(0.7, 0.35, 1.0), Color(0.72, 0.42, 1.0), Color(0.92, 0.75, 1.0), Color.WHITE]},
	{"largura": 21.0, "velocidade": 1800.0, "faiscas": 22.0, "distorcao": 0.3,
		"cores": [Color(0.95, 0.2, 0.3), Color(0.68, 0.3, 0.95), Color(1.0, 0.45, 0.55), Color.WHITE]},
	{"largura": 27.0, "velocidade": 2100.0, "faiscas": 34.0, "distorcao": 0.6,
		"cores": [Color(1.0, 0.15, 0.2), Color(0.7, 0.3, 1.0), Color(1.0, 0.65, 0.75), Color.WHITE]},
	{"largura": 45.0, "velocidade": 2600.0, "faiscas": 60.0, "distorcao": 1.0,
		"cores": [Color(1.0, 0.1, 0.15), Color(0.66, 0.28, 1.0), Color(0.95, 0.8, 1.0), Color.WHITE]},
]

var s: Shumi:
	get: return p as Shumi

var _aura: EfeitosCombate.Aura
var _frames_normal: SpriteFrames
var _frames_kokoro: SpriteFrames


func _init(p_batalha: Batalha, p_personagem: Combatente, p_visual: VisualLutador) -> void:
	super(p_batalha, p_personagem, p_visual)
	_frames_normal = v.frames()
	_frames_kokoro = VisualLutador.carregar_frames(FOLHA_KOKORO, JSON_KOKORO)


func inicio_turno() -> bool:
	if s.perde_proximo_turno:
		s.perde_proximo_turno = false
		b.hud.registrar("%s está exausta depois do x20 e perde o turno." % HudBatalha.nome(s))
		v.piscar(Color(0.5, 0.5, 0.6))
		await b.esperar(0.9)
		s.fim_turno()
		return false

	var nivel_antes := s.nome_nivel()
	var sobrecarga := s.sobrecarga_inicio_turno()
	if sobrecarga.dano > 0:
		EfeitosCombate.numero(b.mundo, v.topo(), "-%d" % sobrecarga.dano, "dreno")
		EfeitosCombate.impacto(b.mundo, centro(s), CORES_AURA[1], 0.8)
		v.piscar(Color(2.5, 0.6, 0.4))
		if is_instance_valid(_aura):
			_aura.pulsar()
		b.hud.registrar("O Kaioken %s queima %s de HP de %s." % [
			nivel_antes, HudBatalha.destaque(str(sobrecarga.dano), EstiloUI.DRENO), HudBatalha.nome(s)])
		b.atualizar()
		await b.esperar(0.5)
		if not s.vivo():
			b.hud.registrar("O Kaioken consumiu %s..." % HudBatalha.nome(s))
			return false
	if sobrecarga.energia > 0:
		EfeitosCombate.numero(b.mundo, v.topo() + Vector2(0, 24), "+%d EN" % roundi(sobrecarga.energia), "energia")
		b.hud.registrar("%s: %s recupera %s de energia." % [
			HudBatalha.destaque("Limite Humano", EstiloUI.ENERGIA), HudBatalha.nome(s),
			HudBatalha.destaque(str(roundi(sobrecarga.energia)), EstiloUI.ENERGIA)])
		b.atualizar()
		await b.esperar(0.35)
	return true


func executar(acao: String) -> void:
	match acao:
		"basico": await _corte()
		"skill": await _engo_ji()
		"skill2": await _bang()
		"ult": await _kaioken()


func fim_turno() -> void:
	var acabou_nivel := s.fim_turno()
	if acabou_nivel != "":
		v.definir_parado("idle")
		v.definir_cor_base(Color.WHITE)
		_remover_aura()
		var extra := " e vai perder o próximo turno" if s.perde_proximo_turno else ""
		b.hud.registrar("O Kaioken %s acabou. %s está exausta%s." % [acabou_nivel, HudBatalha.nome(s), extra])


# ----------------------------------------------------------------- Corte
func _corte() -> void:
	var alvo := b.alvo_atual()
	var n := s.nivel + 1
	b.hud.registrar("%s utilizou %s!" % [HudBatalha.nome(s), HudBatalha.destaque("Corte", EstiloUI.OURO)])
	await investir(alvo, func() -> void:
		v.tocar("attack_melee", CORTE[n][1])
		await b.esperar(0.12 / CORTE[n][1])
		var meio := centro(alvo)
		var raio := maxf(34.0, b.visual(alvo).altura * 0.45)
		match n:
			0:
				EfeitosCombate.corte(b.mundo, meio, COR_ACO, raio)
			1, 2:
				# rastro avermelhado atrás da lâmina
				EfeitosCombate.corte(b.mundo, meio + Vector2(-6, 0), Shumi.COR_KAIOKEN, raio + 6)
				EfeitosCombate.corte(b.mundo, meio, COR_ACO, raio)
			3:
				# sequência rápida: três cortes de ângulos diferentes
				for ang in [-0.5, 0.6, 0.0]:
					EfeitosCombate.corte(b.mundo, meio, Shumi.COR_KAIOKEN, raio + 4, ang)
					EfeitosCombate.impacto(b.mundo, meio + Vector2(randf_range(-12, 12), randf_range(-12, 12)), CORES_AURA[2], 0.7)
					await b.esperar(0.06)
			4:
				EfeitosCombate.veu(b.mundo, Color(1, 0.9, 0.9, 0.35), 0.15)
				EfeitosCombate.corte(b.mundo, meio, Shumi.COR_KAIOKEN, raio * 1.6)
				EfeitosCombate.corte(b.mundo, meio, COR_BRANCA, raio * 1.3)
		await b.esperar(0.08 / CORTE[n][1])
		var cor_impacto := COR_ACO if n == 0 else CORES_AURA[2]
		EfeitosCombate.impacto(b.mundo, meio, cor_impacto, [1.0, 1.1, 1.5, 1.4, 2.2][n])
		if n >= 2:
			EfeitosCombate.anel(b.mundo, meio, Shumi.COR_KAIOKEN, 30.0 + 12.0 * n)
			b.tremer([0, 0, 3.0, 4.0, 8.0][n])
		await b.aplicar_dano(s, alvo, Shumi.MULT_BASICO, s.tipo)
		# x20: uma pausa curta no impacto pesa o golpe
		await b.esperar(0.25 if n < 4 else 0.32), 120.0, CORTE[n][0])
	s.ganhar_energia(Shumi.ENERGIA_BASICO)


# --------------------------------------------------------------- Engo-ji
func _engo_ji() -> void:
	var alvos := s.alvos_engo_ji(b.inimigos_vivos(), b.alvo)
	var forma := s.engo_ji()
	b.hud.registrar("%s utilizou %s!" % [HudBatalha.nome(s), HudBatalha.destaque(forma.nome, COR_ONDA)])
	if s.nivel_maximo():
		await _colapso(alvos)
	else:
		await _disparar(alvos, FEIXES[s.nivel + 1])
	s.ganhar_energia(Shumi.ENERGIA_SKILL)
	await b.esperar(0.2)


## Corte que solta o feixe: a ponta corre da espada até depois do último
## alvo e cada um leva o dano quando ela passa.
func _disparar(alvos: Array, estilo: Dictionary, preparo := 0.36) -> void:
	var n := s.nivel + 1
	v.tocar("engo_ji_beam")
	await b.esperar(preparo)
	var origem := v.position + Vector2(36, -45)
	# mira na altura média dos alvos; o feixe continua até a borda da tela
	var mira := 0.0
	for par in alvos:
		mira += centro(par[0]).y
	mira /= alvos.size()
	var ultimo_x: float = b.visual(alvos[-1][0]).position.x
	var dir := (Vector2(ultimo_x, mira) - origem).normalized()
	var alcance: float = (EfeitosCombate.TELA.x + 40 - origem.x) / dir.x if s.engo_ji_atravessa() \
		else (ultimo_x + 50 - origem.x) / dir.x
	var est := estilo.duplicate()
	est.ponta = PONTA_ONDA
	EfeitosCombate.feixe(b.mundo, origem, dir.angle(), alcance, estilo.velocidade, est, 0.12 + 0.06 * n)

	var decorrido := 0.0
	for par in alvos:
		var alvo: Inimigo = par[0]
		var chega: float = (b.visual(alvo).position.x - origem.x) / dir.x / estilo.velocidade
		if chega > decorrido:
			await b.esperar(chega - decorrido)
			decorrido = chega
		var principal: bool = par[1] > Shumi.MULT_ENGO_JI_SECUNDARIO
		var c := centro(alvo)
		EfeitosCombate.impacto(b.mundo, c, estilo.cores[2], (1.0 + 0.25 * n) * (1.0 if principal else 0.7))
		if n >= 1:
			EfeitosCombate.impacto(b.mundo, c, estilo.cores[0], 0.6 + 0.2 * n)
		if n >= 2 and principal:
			# onda de energia no impacto
			EfeitosCombate.anel(b.mundo, c, estilo.cores[0], 40.0 + 14.0 * n)
		if n >= 3:
			EfeitosCombate.anel(b.mundo, c, COR_BRANCA, 34.0)
		await b.aplicar_dano(s, alvo, par[1], s.tipo)
	b.tremer([0.0, 2.0, 3.0, 6.0, 0.0][n])
	await b.esperar(0.3 + 0.06 * n)


## x20: concentra (tela escurece, energia converge), dispara um feixe que
## cobre a arena e fica um instante sem fôlego.
func _colapso(alvos: Array) -> void:
	var sombra := EfeitosCombate.veu(b.mundo, Color(0.04, 0.0, 0.06, 0.55), 0.0, true)
	sombra.modulate.a = 0.0
	sombra.create_tween().tween_property(sombra, "modulate:a", 1.0, 0.3)
	b.hud.anunciar("ENGO-JI BEAM: COLAPSO", Shumi.COR_KAIOKEN, 28)
	v.tocar("kaioken")
	var peito := centro(s)
	EfeitosCombate.carga(b.mundo, peito, [Color.WHITE, COR_ONDA, Shumi.COR_KAIOKEN], 1.1, 170.0)
	for i in 4:
		if is_instance_valid(_aura):
			_aura.pulsar()
		b.tremer(1.5 + i)
		await b.esperar(0.26)

	EfeitosCombate.veu(b.mundo, Color(1, 0.95, 1, 0.8), 0.35)
	b.tremer(14.0)
	await _disparar(alvos, FEIXES[4], 0.3)
	b.tremer(10.0)
	EfeitosCombate.sumir_veu(sombra, 0.4)

	if s.vivo():
		v.tocar("hurt", 0.6)
		v.piscar(Color(0.55, 0.5, 0.65))
		b.hud.registrar("%s ofega depois de liberar tanta energia." % HudBatalha.nome(s))
		await b.esperar(0.45)


# ----------------------------------------------------------------- Bang!
func _bang() -> void:
	var alvo := b.alvo_atual()
	b.hud.registrar("%s: %s" % [HudBatalha.nome(s), HudBatalha.destaque("Bang!", Shumi.COR_KAIOKEN)])
	await _finger_beam(alvo, s.mult_finger_beam())
	s.aplicar_estado(Shumi.guarda_bang())
	EfeitosCombate.anel(b.mundo, centro(s), Shumi.COR_KAIOKEN, 44.0)
	b.hud.registrar("%s fica em guarda: quem a acertar leva um Finger Beam de volta." % HudBatalha.nome(s))
	s.ganhar_energia(Shumi.ENERGIA_SKILL)
	b.atualizar()
	await b.esperar(0.25)


func contra_atacar(alvo: Combatente, golpe: Dictionary) -> void:
	b.hud.registrar("%s responde com %s!" % [HudBatalha.nome(s), HudBatalha.destaque(golpe.nome, Shumi.COR_KAIOKEN)])
	await _finger_beam(alvo, golpe.mult, true)
	EfeitosCombate.numero(b.mundo, v.topo() + Vector2(0, 24), "+%d EN" % roundi(Shumi.ENERGIA_CONTRA), "energia")


## Tiro de ki do dedo: um feixe fino e rápido, mais grosso e vermelho a cada
## nível do Kaioken. O contra-ataque é golpe adicional (`extra`).
func _finger_beam(alvo: Combatente, mult: float, extra := false) -> void:
	var n := s.nivel + 1
	v.trocar_frames(_frames_kokoro)
	v.piscar(Color(2.2, 1.6, 1.6))
	v.tocar("engo_ji_beam", 2.0)
	await b.esperar(0.12)
	var origem := v.position + Vector2(36, -45)
	var c := centro(alvo)
	var dir := (c - origem).normalized()
	var estilo := {"largura": 4.0 + 1.5 * n, "velocidade": 2600.0,
		"cores": [Shumi.COR_KAIOKEN if n > 0 else COR_ONDA, COR_ONDA, COR_BRANCA, Color.WHITE]}
	EfeitosCombate.feixe(b.mundo, origem, dir.angle(), origem.distance_to(c) + 10.0, estilo.velocidade, estilo, 0.06)
	await b.esperar(origem.distance_to(c) / estilo.velocidade)
	EfeitosCombate.impacto(b.mundo, c, COR_BRANCA, 0.6 + 0.15 * n)
	await b.aplicar_dano(s, alvo, mult, s.tipo, extra)
	await b.esperar(0.15)
	v.trocar_frames(_frames_normal)


# --------------------------------------------------------------- Kaioken
func _kaioken() -> void:
	s.ultar()
	var intensidade := s.nivel + 1
	v.definir_parado("kaioken")
	v.tocar("kaioken")
	v.definir_cor_base(Color(1.0 + 0.05 * intensidade, 1.0, 1.0 - 0.02 * intensidade))
	v.piscar(Color(3.0, 1.6, 1.4))
	if not is_instance_valid(_aura):
		_aura = EfeitosCombate.aura(v, CORES_AURA)
	_aura.nivel = s.nivel
	_aura.rotulo = "KAIOKEN " + s.nome_nivel()
	_aura.pulsar()
	var c := centro(s)
	EfeitosCombate.anel(b.mundo, c, Shumi.COR_KAIOKEN, 60.0 + 12.0 * intensidade)
	EfeitosCombate.impacto(b.mundo, c, CORES_AURA[2], 1.0 + 0.4 * intensidade)
	b.get_tree().create_timer(0.12).timeout.connect(func() -> void:
		EfeitosCombate.anel(b.mundo, c, Color(1, 0.7, 0.5), 40.0 + 10.0 * intensidade))
	if s.nivel_maximo():
		EfeitosCombate.veu(b.mundo, Color(1, 0.3, 0.25, 0.3), 0.4)
		b.get_tree().create_timer(0.24).timeout.connect(func() -> void:
			EfeitosCombate.anel(b.mundo, c, COR_BRANCA, 140.0))
	b.hud.anunciar("KAIOKEN %s!" % s.nome_nivel(), Shumi.COR_KAIOKEN)
	var n: Dictionary = Shumi.NIVEIS[s.nivel]
	b.hud.registrar("%s ativado! ATQ +%d%%, VEL +%d%%, perde %d%% do HP por turno." % [
		HudBatalha.destaque("Kaioken " + s.nome_nivel(), Shumi.COR_KAIOKEN),
		roundi(n.atq * 100), roundi(n.vel * 100), roundi(n.dreno * 100)])
	b.tremer(4.0 + 3.0 * intensidade)
	b.atualizar()
	await b.esperar(0.9)


func _remover_aura() -> void:
	if is_instance_valid(_aura):
		var t := _aura.create_tween()
		t.tween_property(_aura, "modulate:a", 0.0, 0.3)
		t.tween_callback(_aura.queue_free)
	_aura = null

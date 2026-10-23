extends SceneTree
## Joga a batalha sozinho e salva capturas de tela, para conferir o visual.
## Rodar: godot --path . -s ferramentas/demo_captura.gd -- <pasta_saida> [ids da equipe...]
## (ex.: ... -- /tmp/capturas shumi shumi shumi para testar a arena com 3)
## Estratégia: usa a última habilidade pronta do kit (ult > skill > básico).
## Em ações com opções, começa de uma opção sorteada e confirma a primeira
## válida. Ações livres com opções (a lente do Andri) só às vezes.

const INTERVALO := 0.7
const LIMITE := 90.0

var _batalha: Node
var _saida: String
var _tempo := 0.0
var _proxima_captura := 0.5
var _n := 0
var _fim_em := -1.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_saida = args[0] if args.size() > 0 else "user://capturas"
	# a demo não mexe no progresso do jogador: save próprio, todos liberados,
	# no andar 3 (a guarnição completa)
	Progressao.arquivo = "user://demo_progresso.cfg"
	Progressao.apagar()
	for id in Elenco.IDS:
		Progressao.desbloquear(id)
	for n in [1, 2]:
		Progressao.marcar_andar_vencido(n)
	Andares.escolher(3)
	if args.size() > 1:
		var ids: Array[String] = []
		ids.assign(args.slice(1))
		Elenco.definir_equipe(ids)
	DirAccess.make_dir_recursive_absolute(_saida)
	_batalha = load("res://scenes/batalha.tscn").instantiate()
	root.add_child(_batalha)
	current_scene = _batalha


func _process(delta: float) -> bool:
	_tempo += delta
	if _batalha.esperando_jogador:
		var kit: Array[Dictionary] = _batalha.ativo.habilidades(_batalha.pontos)
		for i in range(kit.size() - 1, -1, -1):
			var h := kit[i]
			if not _batalha.ativo.pode_usar(h.acao, _batalha.pontos):
				continue
			if h.get("livre", false) and h.has("opcoes") and randf() > 0.3:
				continue
			_batalha.pedir_acao(h.acao)
			if h.has("opcoes") and not _escolher(h.opcoes.size()):
				continue
			break
	if _tempo >= _proxima_captura:
		_proxima_captura += INTERVALO
		_capturar()
	if _batalha.acabou and _fim_em < 0:
		_fim_em = _tempo + 1.0
	if (_fim_em > 0 and _tempo > _fim_em) or _tempo > LIMITE:
		_capturar()
		print("capturas: %d em %s | resultado: %s" % [_n, _saida, "fim" if _batalha.acabou else "tempo esgotado"])
		return true
	return false


## Confirma a primeira opção válida a partir de uma sorteada.
func _escolher(n: int) -> bool:
	var inicio := randi() % n
	for k in n:
		_batalha.selecionar_opcao((inicio + k) % n)
		if _batalha.confirmar_escolha():
			return true
	_batalha.cancelar_escolha()
	return false


func _capturar() -> void:
	var img := root.get_texture().get_image()
	img.save_png("%s/%03d.png" % [_saida, _n])
	_n += 1

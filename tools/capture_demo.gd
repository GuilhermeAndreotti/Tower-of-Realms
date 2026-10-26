extends SceneTree
## Joga a batalha sozinho e salva capturas de tela, para conferir o visual.
## Rodar: godot --path . -s tools/capture_demo.gd -- <pasta_saida> [ids da equipe...]
## (ex.: ... -- /tmp/capturas shumi shumi shumi para testar a arena com 3)
## Estratégia: usa a última habilidade pronta do kit (ult > skill > básico).
## Em ações com opções, começa de uma opção sorteada e confirma a primeira
## válida. Ações livres com opções (a lente do Andri) só às vezes.

const INTERVAL := 0.7
const LIMIT := 90.0

var _battle: Node
var _output: String
var _time := 0.0
var _next_capture := 0.5
var _n := 0
var _ends_at := -1.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_output = args[0] if args.size() > 0 else "user://capturas"
	# a demo não mexe no progresso do jogador: save próprio, todos liberados,
	# no andar 3 (a guarnição completa)
	Progression.file = "user://demo_progresso.cfg"
	Progression.delete()
	for id in Roster.IDS:
		Progression.unlock(id)
	for n in [1, 2]:
		Progression.mark_floor_cleared(n)
	Floors.choose(3)
	if args.size() > 1:
		var ids: Array[String] = []
		ids.assign(args.slice(1))
		Roster.set_team(ids)
	DirAccess.make_dir_recursive_absolute(_output)
	_battle = load("res://combat/battle.tscn").instantiate()
	root.add_child(_battle)
	current_scene = _battle


func _process(delta: float) -> bool:
	_time += delta
	if _battle.waiting_for_player:
		var kit: Array[Dictionary] = _battle.active.skills(_battle.points)
		for i in range(kit.size() - 1, -1, -1):
			var h := kit[i]
			if not _battle.active.can_use(h.action, _battle.points):
				continue
			if h.get("free", false) and h.has("options") and randf() > 0.3:
				continue
			_battle.request_action(h.action)
			if h.has("options") and not _choose(h.options.size()):
				continue
			break
	if _time >= _next_capture:
		_next_capture += INTERVAL
		_capture()
	if _battle.over and _ends_at < 0:
		_ends_at = _time + 1.0
	if (_ends_at > 0 and _time > _ends_at) or _time > LIMIT:
		_capture()
		print("capturas: %d em %s | resultado: %s" % [_n, _output, "fim" if _battle.over else "tempo esgotado"])
		return true
	return false


## Confirma a primeira opção válida a partir de uma sorteada.
func _choose(n: int) -> bool:
	var start := randi() % n
	for k in n:
		_battle.select_option((start + k) % n)
		if _battle.confirm_choice():
			return true
	_battle.cancel_choice()
	return false


func _capture() -> void:
	var img := root.get_texture().get_image()
	img.save_png("%s/%03d.png" % [_output, _n])
	_n += 1

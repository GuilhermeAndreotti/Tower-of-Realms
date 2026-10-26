extends SceneTree
## Escreve, no README de cada personagem (characters/<id>/README.md), os
## atributos e as habilidades com o mesmo texto do jogo: lê o kit de
## Combatant.skills() e as etiquetas do SkillCard, no estado da
## montagem da equipe (nível 1, pontos cheios, sem forma ativa).
## Só troca o trecho entre START_MARKER e END_MARKER; o resto do arquivo é
## escrito à mão (apresentação, tabelas extras, dicas).
## Rodar: godot --headless --path . -s tools/generate_character_readmes.gd
## O test_combat.gd confere que os READMEs estão em dia com o kit.

const START_MARKER := "<!-- gerado: tools/generate_character_readmes.gd -->"
const END_MARKER := "<!-- fim do trecho gerado -->"
## Papel de cada posição da barra (ver o padrão em Combatant.skills()).
const POSITIONS := ["Básico", "Skill", "Skill 2", "Ultimate", "Passiva"]


func _initialize() -> void:
	# a ferramenta não mexe no progresso do jogador (Roster.create lê o save
	# quando não recebe nível)
	Progression.file = "user://readme_progresso.cfg"
	var failed := false
	for id in Roster.IDS:
		var path := file(id)
		var current := FileAccess.get_file_as_string(path)
		var candidate := with_snippet(current, leg(id))
		if candidate == "":
			printerr("%s: faltam as marcas do trecho gerado" % path)
			failed = true
			continue
		if candidate != current:
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(candidate)
			f.close()
			print("atualizado: ", path)
		else:
			print("em dia: ", path)
	quit(1 if failed else 0)


static func file(id: String) -> String:
	return "res://characters/%s/README.md" % id


## `text` com o trecho entre as marcas trocado por `content` ("" se faltam
## as marcas).
static func with_snippet(text: String, content: String) -> String:
	var i := text.find(START_MARKER)
	var j := text.find(END_MARKER)
	if i < 0 or j < i:
		return ""
	return text.left(i + START_MARKER.length()) + "\n" + content + text.substr(j)


## O trecho gerado de `id`: atributos de nível 1, crescimento e habilidades.
static func leg(id: String) -> String:
	var data := Roster.data(id)
	var p := Roster.create(id, 1)
	var growth: Dictionary = data.get("growth", {})
	var lines: Array[String] = []
	var head := "| | HP | ATQ | DEF | VEL |"
	var sep := "|---|---|---|---|---|"
	var base_stats := "| Nível 1 | %d | %d | %d | %d |" % [p.max_hp, roundi(p.base_atk), roundi(p.base_def), roundi(p.base_spd)]
	var per_level := "| Por nível | +%s | +%s | +%s | +%s |" % [_num(growth.get("hp", 0)), _num(growth.get("atk", 0)),
		_num(growth.get("def", 0)), _num(growth.get("spd", 0))]
	if p.max_energy > 0:
		head += " Energia |"
		sep += "---|"
		base_stats += " %d |" % roundi(p.max_energy)
		per_level += " — |"
	lines.append_array(["## Atributos", "", head, sep, base_stats, per_level, "",
		"## Habilidades", "",
		"> Texto igual ao do jogo, como aparece na montagem da equipe (nível 1, fora de qualquer forma).", ""])
	var kit := p.skills(Battle.MAX_POINTS)
	for i in kit.size():
		lines.append_array(_skill(id, kit[i], i))
	return "\n".join(lines) + "\n"


static func _skill(id: String, h: Dictionary, placement: int) -> Array[String]:
	var lines: Array[String] = []
	var icon: String = h.get("icon", "")
	var img := ('<img src="%s" width="24"> ' % _relative(id, icon)) if icon != "" else ""
	lines.append("### %s%s" % [img, h.name])
	var role: String = POSITIONS[placement] if placement < POSITIONS.size() else ""
	if h.get("key", "") != "":
		role += " (%s)" % h.key
	var parts: Array[String] = ["**%s**" % role]
	for e in SkillCard.tags(h):
		# a 5ª posição já diz "Passiva"
		if e.text == "PASSIVA" and role == "Passiva":
			continue
		parts.append("`%s`" % e.text)
	lines.append_array([" · ".join(parts), ""])
	if h.get("description", "") != "":
		lines.append_array([h.description, ""])
	var details: Array = h.get("details", [])
	for d: Dictionary in details:
		var line := "- **%s**" % d.label
		if d.get("mark", "") != "":
			line += " · *%s*" % d.mark
		var text: String = d.get("text", "")
		var values: Array = d.get("values", [])
		if not values.is_empty():
			text = " · ".join(values.map(func(v: Dictionary) -> String: return v.text))
		if text != "":
			line += ": " + text
		lines.append(line)
	if not details.is_empty():
		lines.append("")
	return lines


## Caminho do ícone a partir da pasta do README do personagem.
static func _relative(id: String, path: String) -> String:
	var folder := "res://characters/%s/" % id
	if path.begins_with(folder):
		return path.substr(folder.length())
	return "../../" + path.trim_prefix("res://")


static func _num(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else String.num(v, 1).replace(".", ",")

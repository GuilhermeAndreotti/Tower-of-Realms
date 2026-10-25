extends SceneTree
## Escreve, no README de cada personagem (personagens/<id>/README.md), os
## atributos e as habilidades com o mesmo texto do jogo: lê o kit de
## Combatente.habilidades() e as etiquetas do CartaoHabilidade, no estado da
## montagem da equipe (nível 1, pontos cheios, sem forma ativa).
## Só troca o trecho entre MARCA_INICIO e MARCA_FIM; o resto do arquivo é
## escrito à mão (apresentação, tabelas extras, dicas).
## Rodar: godot --headless --path . -s ferramentas/gerar_readme_personagens.gd
## O teste_combate.gd confere que os READMEs estão em dia com o kit.

const MARCA_INICIO := "<!-- gerado: ferramentas/gerar_readme_personagens.gd -->"
const MARCA_FIM := "<!-- fim do trecho gerado -->"
## Papel de cada posição da barra (ver o padrão em Combatente.habilidades()).
const POSICOES := ["Básico", "Skill", "Skill 2", "Ultimate", "Passiva"]


func _initialize() -> void:
	# a ferramenta não mexe no progresso do jogador (Elenco.criar lê o save
	# quando não recebe nível)
	Progressao.arquivo = "user://readme_progresso.cfg"
	var falhou := false
	for id in Elenco.IDS:
		var caminho := arquivo(id)
		var atual := FileAccess.get_file_as_string(caminho)
		var novo := com_trecho(atual, trecho(id))
		if novo == "":
			printerr("%s: faltam as marcas do trecho gerado" % caminho)
			falhou = true
			continue
		if novo != atual:
			var f := FileAccess.open(caminho, FileAccess.WRITE)
			f.store_string(novo)
			f.close()
			print("atualizado: ", caminho)
		else:
			print("em dia: ", caminho)
	quit(1 if falhou else 0)


static func arquivo(id: String) -> String:
	return "res://personagens/%s/README.md" % id


## `texto` com o trecho entre as marcas trocado por `conteudo` ("" se faltam
## as marcas).
static func com_trecho(texto: String, conteudo: String) -> String:
	var i := texto.find(MARCA_INICIO)
	var j := texto.find(MARCA_FIM)
	if i < 0 or j < i:
		return ""
	return texto.left(i + MARCA_INICIO.length()) + "\n" + conteudo + texto.substr(j)


## O trecho gerado de `id`: atributos de nível 1, crescimento e habilidades.
static func trecho(id: String) -> String:
	var dados := Elenco.dados(id)
	var p := Elenco.criar(id, 1)
	var cresc: Dictionary = dados.get("crescimento", {})
	var linhas: Array[String] = []
	var cab := "| | HP | ATQ | DEF | VEL |"
	var sep := "|---|---|---|---|---|"
	var nv1 := "| Nível 1 | %d | %d | %d | %d |" % [p.hp_max, roundi(p.atq_base), roundi(p.def_base), roundi(p.vel_base)]
	var por_nivel := "| Por nível | +%s | +%s | +%s | +%s |" % [_num(cresc.get("hp", 0)), _num(cresc.get("atq", 0)),
		_num(cresc.get("def", 0)), _num(cresc.get("vel", 0))]
	if p.energia_max > 0:
		cab += " Energia |"
		sep += "---|"
		nv1 += " %d |" % roundi(p.energia_max)
		por_nivel += " — |"
	linhas.append_array(["## Atributos", "", cab, sep, nv1, por_nivel, "",
		"## Habilidades", "",
		"> Texto igual ao do jogo, como aparece na montagem da equipe (nível 1, fora de qualquer forma).", ""])
	var kit := p.habilidades(Batalha.PONTOS_MAX)
	for i in kit.size():
		linhas.append_array(_habilidade(id, kit[i], i))
	return "\n".join(linhas) + "\n"


static func _habilidade(id: String, h: Dictionary, posicao: int) -> Array[String]:
	var linhas: Array[String] = []
	var icone: String = h.get("icone", "")
	var img := ('<img src="%s" width="24"> ' % _relativo(id, icone)) if icone != "" else ""
	linhas.append("### %s%s" % [img, h.nome])
	var papel: String = POSICOES[posicao] if posicao < POSICOES.size() else ""
	if h.get("tecla", "") != "":
		papel += " (%s)" % h.tecla
	var partes: Array[String] = ["**%s**" % papel]
	for e in CartaoHabilidade.etiquetas(h):
		# a 5ª posição já diz "Passiva"
		if e.texto == "PASSIVA" and papel == "Passiva":
			continue
		partes.append("`%s`" % e.texto)
	linhas.append_array([" · ".join(partes), ""])
	if h.get("descricao", "") != "":
		linhas.append_array([h.descricao, ""])
	var detalhes: Array = h.get("detalhes", [])
	for d: Dictionary in detalhes:
		var linha := "- **%s**" % d.rotulo
		if d.get("marca", "") != "":
			linha += " · *%s*" % d.marca
		var texto: String = d.get("texto", "")
		var valores: Array = d.get("valores", [])
		if not valores.is_empty():
			texto = " · ".join(valores.map(func(v: Dictionary) -> String: return v.texto))
		if texto != "":
			linha += ": " + texto
		linhas.append(linha)
	if not detalhes.is_empty():
		linhas.append("")
	return linhas


## Caminho do ícone a partir da pasta do README do personagem.
static func _relativo(id: String, caminho: String) -> String:
	var pasta := "res://personagens/%s/" % id
	if caminho.begins_with(pasta):
		return caminho.substr(pasta.length())
	return "../../" + caminho.trim_prefix("res://")


static func _num(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else String.num(v, 1).replace(".", ",")

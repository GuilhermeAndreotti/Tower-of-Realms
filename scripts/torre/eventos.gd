class_name Eventos
extends RefCounted
## Eventos de história. Um evento tem efeito (aplicado na hora, e salvo) e
## apresentação (mostrada no saguão, na ordem, quando o jogador volta).
## Vêm de dois lugares:
##  - "ao_vencer" de um andar (Andares), na primeira vitória;
##  - falas de uma conversa (Conversas): "evento": "tipo:id", ex.
##    "desbloquear:andri".
##
## Tipos:
##  {"tipo": "desbloquear", "id": <id do Elenco>}
##      efeito: libera o personagem (Progressao.desbloquear, no nível médio
##      da equipe). Saguão: ele aparece com destaque e um anúncio.
##  {"tipo": "conversa", "id": <id em Conversas>, "quem"?: <id de quem fala>}
##      sem efeito. Saguão: abre a conversa (se ela já tiver falas).
##
## Tipo novo: o efeito aqui em aplicar(), a apresentação em
## Lobby._apresentar() e o texto do fim da batalha em resumo().


static func aplicar(e: Dictionary) -> void:
	match e.get("tipo", ""):
		"desbloquear":
			if e.get("id", "") in Elenco.IDS:
				Progressao.desbloquear(e.id)
			else:
				push_error("evento desbloquear com id desconhecido: %s" % e)
		"conversa":
			pass
		_:
			push_error("tipo de evento desconhecido: %s" % e)


## Lê o evento de uma fala ("tipo:id"). Vazio se o texto não for um evento
## de história (falas podem avisar outras coisas).
static func de_texto(texto: String) -> Dictionary:
	var partes := texto.split(":", true, 1)
	if partes.size() != 2 or partes[0] not in ["desbloquear", "conversa"]:
		return {}
	return {"tipo": partes[0], "id": partes[1]}


## Linha para a tela de vitória ("" = nada a mostrar).
static func resumo(e: Dictionary) -> String:
	match e.get("tipo", ""):
		"desbloquear":
			return "%s chegou à Torre e espera no saguão." % Elenco.dados(e.id).nome
	return ""

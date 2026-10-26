class_name StoryEvents
extends RefCounted
## Eventos de história. Um evento tem efeito (aplicado na hora, e salvo) e
## apresentação (mostrada no saguão, na ordem, quando o jogador volta).
## Vêm de dois lugares:
##  - "on_win" de um andar (Floors), na primeira vitória;
##  - falas de uma conversa (Conversations): "event": "type:id", ex.
##    "unlock:andri".
##
## Tipos:
##  {"type": "unlock", "id": <id do Roster>}
##      efeito: libera o personagem (Progression.unlock, no nível médio
##      da equipe). Saguão: ele aparece com destaque e um anúncio.
##  {"type": "conversation", "id": <id em Conversations>, "speaker"?: <id de quem fala>}
##      sem efeito. Saguão: abre a conversa (se ela já tiver falas).
##
## Tipo novo: o efeito aqui em apply(), a apresentação em
## Lobby._present() e o texto do fim da batalha em summary().
##
## Evento que já não muda nada (desbloquear quem já está liberado) é
## descartado antes de aplicar: nem efeito, nem apresentação.


## Se `e` ainda muda alguma coisa.
static func pending(e: Dictionary) -> bool:
	if e.get("type", "") == "unlock":
		return not Progression.is_unlocked(e.get("id", ""))
	return true


static func apply(e: Dictionary) -> void:
	match e.get("type", ""):
		"unlock":
			if e.get("id", "") in Roster.IDS:
				Progression.unlock(e.id)
			else:
				push_error("evento desbloquear com id desconhecido: %s" % e)
		"conversation":
			pass
		_:
			push_error("tipo de evento desconhecido: %s" % e)


## Lê o evento de uma fala ("type:id"). Vazio se o texto não for um evento
## de história (falas podem avisar outras coisas).
static func from_text(text: String) -> Dictionary:
	var parts := text.split(":", true, 1)
	if parts.size() != 2 or parts[0] not in ["unlock", "conversation"]:
		return {}
	return {"type": parts[0], "id": parts[1]}


## Linha para a tela de vitória ("" = nada a mostrar).
static func summary(e: Dictionary) -> String:
	match e.get("type", ""):
		"unlock":
			return "%s chegou à Torre e espera no saguão." % Roster.data(e.id).name
	return ""

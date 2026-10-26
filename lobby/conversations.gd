class_name Conversations
extends RefCounted
## Conversas do saguão. Dois tipos de chave:
##  - id de um personagem (o mesmo do Roster): abre ao falar com ele.
##    Quem não tem conversa aqui mostra "interação ainda não disponível";
##  - outro id (ex.: "chegada_andri"): conversa de história, aberta por um
##    evento {"type": "conversation", "id": ..., "speaker": <id de quem fala>}
##    (ver StoryEvents; vem do "on_win" de um andar ou de outra fala).
## Ainda vazio: as falas não foram escritas.
##
## Formato (só "lines" é obrigatório):
## {
##     "lines": [
##         {
##             "text": "...",
##             "name": "...",          # opcional: quem fala (padrão: o dono da conversa)
##             "event": "...",        # opcional: avisado ao mostrar a fala;
##                                     # "unlock:<id>" e "conversation:<id>" viram eventos de história
##             "options": [             # opcional: respostas
##                 {"text": "...", "event": "...", "go_to": 3},  # "event" como acima
##             ],                      # "go_to": índice da próxima fala (padrão: a seguinte; -1 encerra)
##         },
##     ],
## }
## Requisitos para liberar uma conversa ficam no Interactable (requisito).

const CONVERSATIONS := {}


static func from(id: String) -> Dictionary:
	return CONVERSATIONS.get(id, {})

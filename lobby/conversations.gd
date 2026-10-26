class_name Conversas
extends RefCounted
## Conversas do saguão. Dois tipos de chave:
##  - id de um personagem (o mesmo do Elenco): abre ao falar com ele.
##    Quem não tem conversa aqui mostra "interação ainda não disponível";
##  - outro id (ex.: "chegada_andri"): conversa de história, aberta por um
##    evento {"tipo": "conversa", "id": ..., "quem": <id de quem fala>}
##    (ver Eventos; vem do "ao_vencer" de um andar ou de outra fala).
## Ainda vazio: as falas não foram escritas.
##
## Formato (só "falas" é obrigatório):
## {
##     "falas": [
##         {
##             "texto": "...",
##             "nome": "...",          # opcional: quem fala (padrão: o dono da conversa)
##             "evento": "...",        # opcional: avisado ao mostrar a fala;
##                                     # "desbloquear:<id>" e "conversa:<id>" viram eventos de história
##             "opcoes": [             # opcional: respostas
##                 {"texto": "...", "evento": "...", "ir_para": 3},  # "evento" como acima
##             ],                      # "ir_para": índice da próxima fala (padrão: a seguinte; -1 encerra)
##         },
##     ],
## }
## Requisitos para liberar uma conversa ficam no Interagivel (requisito).

const CONVERSAS := {}


static func de(id: String) -> Dictionary:
	return CONVERSAS.get(id, {})

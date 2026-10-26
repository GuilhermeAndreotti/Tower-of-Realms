# Saguão

O saguão (`Lobby`, [`lobby.gd`](../../lobby/lobby.gd)) é a zona segura: a Caoimhe anda livre, fala com os personagens e entra na dungeon pela porta, no centro da parede do fundo.

Chega-se nele pelo menu inicial (entrada "start") ou voltando da dungeon (entrada "door"). Esc, fora de conversa e de transição, volta ao [menu inicial](menu-inicial.md); não há nada a salvar, porque o progresso é salvo a cada mudança.

## Coordenadas e arte

O fundo tem 640×180 pixels, ampliado 3× na tela. As constantes do `Lobby` (móveis, tochas, porta, lugares) estão em pixels do fundo, os mesmos de `tools/generate_lobby.py`, que gera a arte. Mudou a posição de algo desenhado no fundo? Mude nos dois e gere de novo.

- Móveis bloqueiam só a pegada da base; o resto é desenho.
- Os personagens e móveis são ordenados pela altura dos pés (`y_sort`).
- Chamas, brilhos e runas acesas são desenhados no jogo, não na arte.

## Interação

- O `Interactable` mais perto dos pés, dentro do raio, fica em foco; Enter interage.
- Uma interação por vez: durante conversa, entrada na dungeon ou apresentação de eventos, o jogador fica parado (`busy`, ver [Estados](#estados)).
- Um `Interactable` pode ter `requirement` (motivo para ainda não liberar). Quando o jogador interage e o requisito deixa, ele emite `interacted`; quem decide o que acontece é quem escuta: o `Lobby` liga a porta à entrada na dungeon e cada personagem à conversa dele.

## Estados

O saguão é uma máquina de estados (`Lobby.Mode`, numa `StateMachine`); o estado decide o que as teclas fazem e se a Caoimhe anda:

| Estado       | O que acontece                                  | Teclas                         | Vai para                    |
| ------------ | ----------------------------------------------- | ------------------------------ | --------------------------- |
| `EXPLORING`  | anda, foco nos interagíveis                      | Enter interage, Esc vai ao menu | `TALKING`, `PRESENTING`, `LEAVING` |
| `TALKING`    | conversa aberta                                 | as da caixa de diálogo         | `EXPLORING`                 |
| `PRESENTING` | eventos de história pendentes sendo apresentados | as da caixa de diálogo, se abrir | `EXPLORING`               |
| `LEAVING`    | a tela escurece para a dungeon ou o menu        | nenhuma                        | (troca de cena)             |

Fora de `EXPLORING`, o `Lobby` trava a Caoimhe e tira o foco. A Caoimhe (`LobbyPlayer`) tem a própria máquina, `Motion`: `IDLE`, `WALKING` e `LOCKED`; a animação ("idle" ou "walk") acompanha a troca de estado.

## Conversas

As falas estão em `Conversations` ([`conversations.gd`](../../lobby/conversations.gd)), com o formato no comentário do arquivo. A chave é:

- o id de um personagem: abre ao falar com ele;
- outro id: conversa de história, aberta por um evento `conversation`.

Ainda não há falas escritas; quem não tem conversa mostra "interação ainda não disponível". `DialogBox` mostra a conversa: retrato, nome, texto, respostas com `go_to` e `event` por fala ou resposta.

## Eventos de história

Ao chegar (depois do fade), o saguão apresenta os eventos pendentes um de cada vez, com o jogador parado. Cada um sai da fila só depois de apresentado, então fechar o jogo no meio não perde o resto. Uma fala com `"event": "unlock:<id>"` aplica o efeito na hora e põe a apresentação na fila, que roda quando a conversa acaba.

O que é cada tipo de evento está em [Torre e andares](torre-e-andares.md#eventos-de-história).

## Quem aparece

Só os personagens liberados (`Roster.available()`). Quem vai ser apresentado agora começa invisível e surge na apresentação.

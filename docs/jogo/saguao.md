# Saguão

O saguão (`Lobby`, [`lobby.gd`](../../lobby/lobby.gd)) é a zona segura: a Caoimhe anda livre, fala com os personagens e entra na dungeon pela porta, no centro da parede do fundo.

Chega-se nele pelo menu inicial (entrada "inicio") ou voltando da dungeon (entrada "porta"). Esc, fora de conversa e de transição, volta ao [menu inicial](menu-inicial.md); não há nada a salvar, porque o progresso é salvo a cada mudança.

## Coordenadas e arte

O fundo tem 640×180 pixels, ampliado 3× na tela. As constantes do `Lobby` (móveis, tochas, porta, lugares) estão em pixels do fundo, os mesmos de `tools/generate_lobby.py`, que gera a arte. Mudou a posição de algo desenhado no fundo? Mude nos dois e gere de novo.

- Móveis bloqueiam só a pegada da base; o resto é desenho.
- Os personagens e móveis são ordenados pela altura dos pés (`y_sort`).
- Chamas, brilhos e runas acesas são desenhados no jogo, não na arte.

## Interação

- O `Interactable` mais perto dos pés, dentro do raio, fica em foco; Enter interage.
- Uma interação por vez: durante conversa, entrada na dungeon ou apresentação de eventos, o jogador fica parado (`busy`).
- Um `Interactable` pode ter `requirement` (motivo para ainda não liberar) e `on_interact` (ação própria, como a porta); sem ação própria, abre a conversa dele.

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

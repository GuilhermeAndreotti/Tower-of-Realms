# Menu inicial

O menu inicial (`MenuInicial`, [`menu_inicial.gd`](../../scripts/ui/menu_inicial.gd)) é a cena principal: mostra a logo e escolhe em qual slot de save o jogo vai rodar. Só apresenta; criar, ler e apagar saves é com `Progressao` ([Progressão](progressao.md#save)).

## Telas

- **Início**: NEW GAME, LOAD GAME e QUIT. LOAD GAME fica desligado sem nenhum save.
- **NEW GAME**: lista os slots. Slot vazio começa o jogo na hora (`Progressao.novo_jogo`, que já cria o arquivo). Slot ocupado pergunta antes de sobrescrever.
- **LOAD GAME**: a mesma lista; só slot ocupado abre (`Progressao.usar_slot`).

Nas duas listas, um slot ocupado pode ser apagado (Del ou o botão APAGAR), sempre com confirmação. Toda pergunta começa com o foco em CANCELAR, para Enter repetido não perder progresso.

O cursor começa no primeiro slot vazio (NEW GAME) ou no save mais recente (LOAD GAME). O resumo de cada slot vem de `Progressao.resumo_slot()`, que lê o arquivo à parte, sem trocar o save em uso.

## Ida e volta

- Escolhido o slot, o menu entra no saguão pelo começo (`Lobby.META_ENTRADA` = "inicio").
- Esc no saguão volta ao menu. Nada se perde: o progresso é salvo a cada mudança.
- O slot em uso é só `Progressao.arquivo`; abrir o jogo de novo sempre passa pelo menu.

## Controles

↑/↓ escolhe, Enter confirma, Del apaga o slot sob o cursor, Esc fecha a pergunta ou volta à tela anterior. Mouse: passar por cima foca, clicar confirma.

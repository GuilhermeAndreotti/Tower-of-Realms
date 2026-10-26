# Menu inicial

O menu inicial (`MainMenu`, [`main_menu.gd`](../../menu/main_menu.gd)) é a cena principal: mostra a logo e escolhe em qual slot de save o jogo vai rodar. Só apresenta; criar, ler e apagar saves é com `Progression` ([Progressão](progressao.md#save)).

## Telas

- **Início**: NEW GAME, LOAD GAME e QUIT. LOAD GAME fica desligado sem nenhum save.
- **NEW GAME**: lista os slots. Slot vazio começa o jogo na hora (`Progression.new_game`, que já cria o arquivo). Slot ocupado pergunta antes de sobrescrever.
- **LOAD GAME**: a mesma lista; só slot ocupado abre (`Progression.use_slot`).

Nas duas listas, um slot ocupado pode ser apagado (Del ou o botão APAGAR), sempre com confirmação. Toda pergunta começa com o foco em CANCELAR, para Enter repetido não perder progresso.

O cursor começa no primeiro slot vazio (NEW GAME) ou no save mais recente (LOAD GAME). O resumo de cada slot vem de `Progression.slot_summary()`, que lê o arquivo à parte, sem trocar o save em uso.

## Ida e volta

- Escolhido o slot, o menu entra no saguão pelo começo (`Lobby.ENTRANCE_META` = "start").
- Esc no saguão volta ao menu. Nada se perde: o progresso é salvo a cada mudança.
- O slot em uso é só `Progression.file`; abrir o jogo de novo sempre passa pelo menu.

## Controles

↑/↓ escolhe, Enter confirma, Del apaga o slot sob o cursor, Esc fecha a pergunta ou volta à tela anterior. Mouse: passar por cima foca, clicar confirma.

# Visão geral da arquitetura

*Tower of Realms* é um projeto Godot 4.7 em GDScript com tipagem estática, sem plugins nem autoloads. Tudo que é compartilhado entre telas mora em classes com `class_name` e funções `static`.

## Fluxo de cenas

```
main_menu.tscn ──NEW GAME / LOAD GAME (slot)──▶ lobby.tscn
        ▲                                               │ Esc
        └───────────────────────────────────────────────┘

lobby.tscn ──porta──▶ floor_select.tscn ──▶ team_select.tscn ──▶ battle.tscn
    ▲                        │ Esc                    │ Esc                │
    └────────────────────────┘◀───────────────────────┘                    │
    └──────────────── fim do andar (vitória ou derrota) ◀───────────────────┘
```

- A cena principal é o menu inicial ([Menu inicial](../jogo/menu-inicial.md)): ele escolhe o slot de save e leva ao saguão ([Saguão](../jogo/saguao.md)).
- Cada ida à dungeon é um andar: vence ou perde e volta ao saguão. Repetir é subir de novo pela porta ([Torre e andares](../jogo/torre-e-andares.md)).

## Camadas

O combate separa três coisas, e nenhuma invade a outra:

| Camada     | Classes                                       | Faz                                             | Não faz                     |
| ---------- | --------------------------------------------- | ----------------------------------------------- | --------------------------- |
| Regras     | `Combatant` e subclasses, `StatusEffect`, `Types`  | números, estados, quem pode o quê               | animação, interface         |
| Animações  | `CharacterActions` e subclasses                | o que cada ação faz na arena, com efeitos       | decidir regras de dano      |
| Interface  | `BattleHud`, `UIStyle`, `PixelBar`...     | mostrar o estado e avisar o que o jogador pediu | regra nenhuma               |

`Battle` coordena: a vez, os pontos de skill do time, o alvo e o fim da luta. A HUD só lê descrições (`skills()`, `effects()`) que as regras fornecem, por isso personagens novos aparecem sem mudar a HUD. Detalhes em [Combate](../jogo/combate.md).

A interface é avisada por sinais, nunca chamada pelas regras ou pelas animações: a batalha e as ações dos personagens contam o que aconteceu com `Battle.log_line()` e `Battle.announce()`, que emitem `message_logged` e `announced`; a HUD se liga a esses sinais quando a batalha monta a cena. Para o registro, a cor dos nomes e dos destaques vem de `UIStyle.fighter_name()` e `UIStyle.highlight()`, então as ações não dependem da HUD. No sentido contrário, a HUD avisa o que o jogador pediu pelos sinais dela (`action_requested`, `skill_focused`...).

Fora do combate, a mesma ideia: `Floors` e `StoryEvents` (dados e regras da Torre), `Progression` (regras e save), `Lobby` e as telas de seleção (só apresentam e chamam essas classes).

## Estado entre cenas

| Estado                                              | Onde vive                                  | Sobrevive a fechar o jogo |
| --------------------------------------------------- | ------------------------------------------ | ------------------------- |
| Níveis, XP, equipe, andares vencidos, andar escolhido, eventos pendentes | `Progression` (o arquivo do slot em uso) | sim |
| Qual slot está em uso                               | `Progression.file` (variável estática)   | não: o menu escolhe de novo |
| Onde a Caoimhe aparece ao voltar ao saguão          | `Engine` meta (`Lobby.ENTRANCE_META`)        | não                       |
| Preferência do painel de controles da batalha        | `user://hud.cfg`                           | sim                       |

O save é um `ConfigFile` lido uma vez e mantido em memória (`Progression._save`). Testes e ferramentas trocam `Progression.file` para não tocar no save do jogador. Formato e compatibilidade em [Progressão](../jogo/progressao.md#save).

## Pastas

```
combat/        a batalha: cena, regras (Combatant, StatusEffect, Types, fila, invocações), base das animações e efeitos
  hud/         interface da batalha: HUD, slots, ordem de ação, seletor radial
characters/    Roster e uma pasta por herói (regras, animações, arte, README)
enemies/       Enemy e a arte dos inimigos
progression/   Progression: níveis, XP e save
tower/         andares, eventos de história e as telas de andar e de equipe
lobby/         saguão: cena, jogador, interagíveis, conversas, diálogo e arte
menu/          menu inicial
ui/            estilo e componentes de interface comuns
tests/         testes headless
tools/         simulação, captura de tela e geradores de arte
docs/          esta documentação
```

Cada pasta é uma feature: a cena, o script e a arte dela ficam juntos, e o que só ela usa não sai de lá. O que várias telas usam (estilo, barras, cartão de habilidade) fica em `ui/`.

As cenas montam a interface por código no `_ready()`; os `.tscn` só apontam para o script e ficam na pasta da feature.

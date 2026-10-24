# Visão geral da arquitetura

*Tower of Realms* é um projeto Godot 4.7 em GDScript com tipagem estática, sem plugins nem autoloads. Tudo que é compartilhado entre telas mora em classes com `class_name` e funções `static`.

## Fluxo de cenas

```
menu_inicial.tscn ──NEW GAME / LOAD GAME (slot)──▶ lobby.tscn
        ▲                                               │ Esc
        └───────────────────────────────────────────────┘

lobby.tscn ──porta──▶ selecao_andar.tscn ──▶ selecao_equipe.tscn ──▶ batalha.tscn
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
| Regras     | `Combatente` e subclasses, `Estado`, `Tipos`  | números, estados, quem pode o quê               | animação, interface         |
| Animações  | `AcoesPersonagem` e subclasses                | o que cada ação faz na arena, com efeitos       | decidir regras de dano      |
| Interface  | `HudBatalha`, `EstiloUI`, `BarraPixel`...     | mostrar o estado e avisar o que o jogador pediu | regra nenhuma               |

`Batalha` coordena: a vez, os pontos de skill do time, o alvo e o fim da luta. A HUD só lê descrições (`habilidades()`, `efeitos()`) que as regras fornecem, por isso personagens novos aparecem sem mudar a HUD. Detalhes em [Combate](../jogo/combate.md).

Fora do combate, a mesma ideia: `Andares` e `Eventos` (dados e regras da Torre), `Progressao` (regras e save), `Lobby` e as telas de seleção (só apresentam e chamam essas classes).

## Estado entre cenas

| Estado                                              | Onde vive                                  | Sobrevive a fechar o jogo |
| --------------------------------------------------- | ------------------------------------------ | ------------------------- |
| Níveis, XP, equipe, andares vencidos, andar escolhido, eventos pendentes | `Progressao` (o arquivo do slot em uso) | sim |
| Qual slot está em uso                               | `Progressao.arquivo` (variável estática)   | não: o menu escolhe de novo |
| Onde a Caoimhe aparece ao voltar ao saguão          | `Engine` meta (`Lobby.META_ENTRADA`)        | não                       |
| Preferência do painel de controles da batalha        | `user://hud.cfg`                           | sim                       |

O save é um `ConfigFile` lido uma vez e mantido em memória (`Progressao._save`). Testes e ferramentas trocam `Progressao.arquivo` para não tocar no save do jogador. Formato e compatibilidade em [Progressão](../jogo/progressao.md#save).

## Pastas

```
scenes/              cenas (cada uma só com o nó raiz e o script)
scripts/combate/     regras do combate, fila, tipos, estados, inimigos, batalha
scripts/personagens/ elenco, progressão e o kit de cada herói (regras + animações)
scripts/torre/       andares e eventos de história
scripts/lobby/       saguão, jogador, interagíveis, conversas e diálogo
scripts/ui/          HUD, seleções, barras, seletor radial, efeitos visuais
personagens/ inimigos/ cenarios/ efeitos/   arte (pixel art, filtro nearest)
testes/              testes headless
ferramentas/         simulação, captura de tela e geradores de arte
docs/                esta documentação
```

As cenas montam a interface por código no `_ready()`; os `.tscn` só apontam para o script.

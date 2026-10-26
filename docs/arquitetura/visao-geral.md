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
combat/        a batalha: cena, regras (Combatente, Estado, Tipos, fila, invocações), base das animações e efeitos
  hud/         interface da batalha: HUD, slots, ordem de ação, seletor radial
characters/    Elenco e uma pasta por herói (regras, animações, arte, README)
enemies/       Inimigo e a arte dos inimigos
progression/   Progressao: níveis, XP e save
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

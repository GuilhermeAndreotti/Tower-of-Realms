# Combate

Combate por turnos com fila por velocidade (no estilo de *Honkai: Star Rail*) e efetividade por tipo (no estilo de *Pokémon*). A coordenação está em `combat/battle.gd`; as regras, em `Combatant` e nas classes dos personagens.

## Composição do lutador

`Combatant` é montado com componentes (em [`combat/components/`](../../combat/components)), e cada um cuida de uma coisa só:

| Componente      | Guarda                                    | Avisa                                         |
| --------------- | ----------------------------------------- | --------------------------------------------- |
| `Health`        | HP atual e máximo                         | `changed` a cada mudança, `depleted` ao zerar |
| `StatusEffects` | os estados e o que eles somam (bônus, escudo, fraqueza, provocação, redução) | — |
| `Cooldowns`     | turnos de recarga de cada ação            | —                                             |

`hp`, `max_hp` e `status_effects` continuam no `Combatant` como atalhos. O que um estado muda no dono ao entrar ou sair (HP máximo, a vez) é o `Combatant` que aplica, porque depende do resto dele; os componentes só guardam e somam. Na arena, a barra sobre inimigos e invocações é o nó `FighterBar`, filho do `FighterVisual`, que escuta o `Health` do lutador.

## Fila de turnos

Cada lutador precisa percorrer `Combatant.TURN_DISTANCE`; o que falta é o `av` ("action value"). Quem tem menor `av / speed` age primeiro (`TurnQueue`). Depois de agir, o `av` volta ao total.

- Mudou a VEL no meio do caminho? Chame `adjust_av(spd_before)`: o que falta é reescalado, então ficar mais rápido adianta a vez.
- Um `StatusEffect` com `delay` empurra a vez de quem o recebe.

## Dano

```
dano = ATQ × mult × efetividade × 100 / (100 + DEF)   × (1 − redução)   × 1,5 se crítico   × variação de 0,95 a 1,05
```

A redução vem dos estados do alvo (`damage_reduction`, como a resistência do Lorde da Luz), somada e limitada a 90%.

- Mínimo de 1. `calculate_damage()` recebe a variação e o crítico de fora, para os testes fixarem os valores.
- Escudos absorvem antes do HP (`absorb()`); custos próprios, como o dreno do Kaioken, tiram HP direto (`take_damage()`). Na interface, todo escudo aparece na barra de HP como contorno azul com uma faixa do tamanho dele (`UIStyle.shield_outline()`), na HUD e na arena.
- Golpes adicionais (de estados como o Braço de Thorim) entram como golpes separados e não se encadeiam.

## Tipos

Cada lutador tem um tipo e ataca com ele, a não ser que a ação diga outro. Multiplicadores: `Types.SUPER` (2) e `Types.NOT_VERY` (0,5), e nada mais. Arcano tem regra própria: recebe 2× de tudo e causa 2× em tudo, menos em Físico. A tabela completa está em [`types.gd`](../../combat/types.gd).

Os tipos dos inimigos são parte do desenho dos andares (ver [Torre e andares](torre-e-andares.md#encontros)).

## Recursos

- **Pontos de skill:** do time, começam em 3, máximo 5. O básico dá 1; cada skill (E e W) custa 1. A batalha cobra `point_cost` antes da ação e dá `point_gain` depois.
- **Recarga:** a skill 2 (W) também tem recarga, para não disputar os pontos com a E a cada turno. Recarga N = uma vez a cada N turnos do dono, contando o turno do uso. A batalha inicia a recarga depois da ação (`"cooldown"` na habilidade); `Combatant.pass_turn()` desconta e `with_cooldown()` põe a barra no estado `cooldown`, com os turnos que faltam.
- **Energia:** de cada personagem. Sobe com básico, skill e ao apanhar; paga a ultimate. Quem tem `max_energy = 0` não usa energia, e a HUD esconde a barra.
- **Recurso de kit:** um kit pode ter o próprio (os Fragmentos d'Alma da Àskara). Ele mora na classe do personagem, aparece em `effects()` e a barra explica o que falta pela chave `missing_reason` da habilidade. Para ganhar algo quando um inimigo cai, o kit sobrescreve `on_enemy_fallen()`.

## Estados

`StatusEffect` é o efeito temporário genérico: modificadores (`mods` de ATQ, DEF, VEL e crítico), fraqueza, escudo, vida extra, atraso, provocação, redução de dano, golpe extra e estado aplicado ao acertar. Um por id; aplicar de novo renova. A duração conta turnos do portador.

Invariante: modificadores temporários entram em `bonus()` e nos estados; os atributos de nível ficam em `base_atk`, `base_def`, `base_spd` e `max_hp` (ver [Progressão](progressao.md#atributos)). Nunca some bônus direto nesses campos.

## Kits

Um kit é uma subclasse de `Combatant` (regras) e uma de `CharacterActions` (animações). Todo kit tem básico (Q), skill (E), skill 2 (W), ult (R) e uma passiva, e a barra mostra as cinco sempre nessa ordem (ver [Personagens](personagens.md#padrão-do-kit)). Passivas ficam sem tecla e marcadas como PASSIVA (só reage ao clique se tiver opções, como a lente do Andri). O kit descreve as ações em `skills()` (tecla, ícone, custo, alvo, opções, se é livre ou passiva) e os efeitos ativos em `effects()`; a batalha e a HUD só leem isso. O formato completo está no comentário de `Combatant.skills()`.

Recursos que um kit pode usar sem mexer na batalha:

- `options` com seletor em lista ou radial (`"selector": "radial"`), abrindo sozinho no começo da vez com `on_turn_start`.
- `target`: `single`, `neighbors`, `all`, `self`, `ally`; ou `predicted_targets()` para regras próprias.
- `invalid_reason()` impede confirmar e explica o porquê.
- `free`: a ação não gasta o turno.
- `target` numa opção: a opção mira outro tipo de alvo que a ação (o Escudo do Protocolo MOMC mira um aliado; a Sobrecarga, um inimigo). A marcação, a prévia e o motivo inválido seguem a opção marcada (`Battle.target_type()`).
- `cooldown`: turnos entre usos (ver [Recursos](#recursos)).
- `details`: uma linha por item da habilidade (cada demônio, cada artefato, cada nível do Kaioken), com rótulo, marca, texto e/ou valores por nível, e o item atual em destaque. O `SkillCard` mostra nome, etiquetas (passiva, custo, recarga, alvo, elemento), a `description` como resumo e os detalhes, na dica da barra (acima dela) e na ficha da montagem da equipe. Assim a `description` fica curta e não repete o que as etiquetas já dizem.
- Ataque em conjunto: no fim de cada ação de outro aliado (da equipe ou invocação) que acertou um inimigo, a batalha pergunta a cada um da equipe `Combatant.follow_up()`; quem devolver um golpe ataca o primeiro inimigo atingido, se ele ainda estiver de pé (o Bang! da Shumi), com a animação de `CharacterActions.follow_up()`. Uma vez por ação, não por golpe, para ataques em área não multiplicarem o efeito. É golpe adicional: sem crítico, sem estados de acerto e sem encadear (golpes `extra` não contam como acerto da ação).

No seletor de opções, W e S não navegam (só ↑/↓): as teclas da barra têm prioridade, porque a lente do Andri abre sozinha no começo da vez e o W tem que continuar chamando a skill 2.

## Invocações

`Summon` (subclasse de `Combatant`) é uma criatura chamada por um aliado. Ela entra na fila, tem HP, estados e barra, e fica do lado aliado, mas não é da equipe:

- **Alvos:** `Battle.allies_on_field()` é a equipe de pé mais as invocações em campo. É quem os inimigos sorteiam e quem as ações com alvo `ally` podem mirar (o Andri pode entregar artefatos a elas).
- **Derrota e recompensa:** usam `living_allies()`, só a equipe. Invocação não segura a luta, não ganha XP e não é salva.
- **Vez:** age sozinha. A batalha usa o `strike` dela (alcance, mira e estilo, ver o comentário de `Summon.strike`) a partir do inimigo marcado e aplica o `debuff`, se houver. Os golpes passam por `apply_damage()` como qualquer outro, então estados de acerto e golpes extras do portador valem.
- **Saída:** depois de `turns` vezes, ao cair, quando quem a invocou cai ou quando o kit a tira (substituição, o Lorde). Quem tira de campo é `Battle.remove_summon()`; as regras só marcam `on_field = false`.
- **Último ato:** ao sair por tempo ou ao cair, a invocação faz o `last_act` dela (golpe no formato de `strike`, com escudo opcional para o aliado com menor fração de HP), por `Battle.last_act()`, antes de sumir. Substituição, o Lorde e a queda de quem invocou não disparam: cada uma já tem a própria troca, e o último ato fica sendo a recompensa de deixar a invocação cumprir o tempo. Como dispara sozinho em toda invocação, os valores são baixos (ver a passiva Último Ato da Àskara).
- **Entrada:** o kit cria a invocação (regras) e as ações chamam `Battle.add_summon()` (vaga, visual, aura) e, se quiserem, `summon_strike()` com o `entrance_strike`.

A batalha não sabe que invocações existem em cada kit: tudo vem da `Summon` que o kit entrega.

## Inimigos

`Enemy` sorteia o alvo entre os aliados em campo, pelo peso de cada um (`target_weight()`: 1 mais a provocação dos estados). Com `heavy_strike_every > 0`, a cada N ações solta um Golpe Pesado (1,8×), avisado uma ação antes. Os valores de cada inimigo vêm do andar (ver [Torre e andares](torre-e-andares.md)).

**Último recurso** (`last_resort`, como o Ferro Negro do andar 5): quando um golpe deixa o inimigo de pé abaixo da fração `below` do HP, ele ganha um escudo (um `StatusEffect`) uma vez por luta. A regra é `Enemy.activate_last_resort()`; a batalha chama depois de cada golpe (`apply_damage()`), aplica o escudo e anuncia no meio da tela ("Ferro Negro ativado"). Golpe que mata direto não ativa.

## Fim da luta

A luta acaba quando um dos lados cai (do lado aliado, a equipe; invocações não contam). Na vitória, a batalha dá a XP e registra o andar uma única vez (`_reward()`); depois, Enter, Esc ou clique voltam ao saguão. Não existe abandonar no meio.

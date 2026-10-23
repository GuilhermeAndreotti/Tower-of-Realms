# Combate

Combate por turnos com fila por velocidade (no estilo de *Honkai: Star Rail*) e efetividade por tipo (no estilo de *Pokémon*). A coordenação está em `scripts/combate/batalha.gd`; as regras, em `Combatente` e nas classes dos personagens.

## Fila de turnos

Cada lutador precisa percorrer `Combatente.DISTANCIA_TURNO`; o que falta é o `av` ("action value"). Quem tem menor `av / velocidade` age primeiro (`FilaTurnos`). Depois de agir, o `av` volta ao total.

- Mudou a VEL no meio do caminho? Chame `ajustar_av(vel_antes)`: o que falta é reescalado, então ficar mais rápido adianta a vez.
- Um `Estado` com `atraso` empurra a vez de quem o recebe.

## Dano

```
dano = ATQ × mult × efetividade × 100 / (100 + DEF)   × 1,5 se crítico   × variação de 0,95 a 1,05
```

- Mínimo de 1. `calcular_dano()` recebe a variação e o crítico de fora, para os testes fixarem os valores.
- Escudos absorvem antes do HP (`absorver()`); custos próprios, como o dreno do Kaioken, tiram HP direto (`receber_dano()`).
- Golpes adicionais (de estados como o Braço de Thorim) entram como golpes separados e não se encadeiam.

## Tipos

Cada lutador tem um tipo e ataca com ele, a não ser que a ação diga outro. Multiplicadores: `Tipos.SUPER` (2) e `Tipos.POUCO` (0,5), e nada mais. Arcano tem regra própria: recebe 2× de tudo e causa 2× em tudo, menos em Físico. A tabela completa está em [`tipos.gd`](../../scripts/combate/tipos.gd).

Os tipos dos inimigos são parte do desenho dos andares (ver [Torre e andares](torre-e-andares.md#encontros)).

## Recursos

- **Pontos de skill:** do time, começam em 3, máximo 5. O básico dá 1; a skill custa 1. A batalha cobra `custo_pontos` antes da ação e dá `ganho_pontos` depois.
- **Energia:** de cada personagem. Sobe com básico, skill e ao apanhar; paga a ultimate.

## Estados

`Estado` é o efeito temporário genérico: modificadores (`mods` de ATQ, DEF, VEL e crítico), fraqueza, escudo, vida extra, atraso, golpe extra e estado aplicado ao acertar. Um por id; aplicar de novo renova. A duração conta turnos do portador.

Invariante: modificadores temporários entram em `bonus()` e nos estados; os atributos de nível ficam em `atq_base`, `def_base`, `vel_base` e `hp_max` (ver [Progressão](progressao.md#atributos)). Nunca some bônus direto nesses campos.

## Kits

Um kit é uma subclasse de `Combatente` (regras) e uma de `AcoesPersonagem` (animações). O kit descreve as ações em `habilidades()` (tecla, ícone, custo, alvo, opções, se é livre ou passiva) e os efeitos ativos em `efeitos()`; a batalha e a HUD só leem isso. O formato completo está no comentário de `Combatente.habilidades()`.

Recursos que um kit pode usar sem mexer na batalha:

- `opcoes` com seletor em lista ou radial (`"seletor": "radial"`), abrindo sozinho no começo da vez com `ao_iniciar_turno`.
- `alvo`: `unico`, `vizinhos`, `todos`, `proprio`, `aliado`; ou `alvos_previstos()` para regras próprias.
- `motivo_invalido()` impede confirmar e explica o porquê.
- `livre`: a ação não gasta o turno.

## Inimigos

`Inimigo` ataca um aliado vivo sorteado. Com `golpe_pesado_a_cada > 0`, a cada N ações solta um Golpe Pesado (1,8×), avisado uma ação antes. Os valores de cada inimigo vêm do andar (ver [Torre e andares](torre-e-andares.md)).

## Fim da luta

A luta acaba quando um dos lados cai. Na vitória, a batalha dá a XP e registra o andar uma única vez (`_recompensar()`); depois, Enter, Esc ou clique voltam ao saguão. Não existe abandonar no meio.

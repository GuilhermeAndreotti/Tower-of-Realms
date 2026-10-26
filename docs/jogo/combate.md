# Combate

Combate por turnos com fila por velocidade (no estilo de *Honkai: Star Rail*) e efetividade por tipo (no estilo de *Pokémon*). A coordenação está em `scripts/combate/batalha.gd`; as regras, em `Combatente` e nas classes dos personagens.

## Fila de turnos

Cada lutador precisa percorrer `Combatente.DISTANCIA_TURNO`; o que falta é o `av` ("action value"). Quem tem menor `av / velocidade` age primeiro (`FilaTurnos`). Depois de agir, o `av` volta ao total.

- Mudou a VEL no meio do caminho? Chame `ajustar_av(vel_antes)`: o que falta é reescalado, então ficar mais rápido adianta a vez.
- Um `Estado` com `atraso` empurra a vez de quem o recebe.

## Dano

```
dano = ATQ × mult × efetividade × 100 / (100 + DEF)   × (1 − redução)   × 1,5 se crítico   × variação de 0,95 a 1,05
```

A redução vem dos estados do alvo (`reducao_dano`, como a resistência do Lorde da Luz), somada e limitada a 90%.

- Mínimo de 1. `calcular_dano()` recebe a variação e o crítico de fora, para os testes fixarem os valores.
- Escudos absorvem antes do HP (`absorver()`); custos próprios, como o dreno do Kaioken, tiram HP direto (`receber_dano()`). Na interface, todo escudo aparece na barra de HP como contorno azul com uma faixa do tamanho dele (`EstiloUI.contorno_escudo()`), na HUD e na arena.
- Golpes adicionais (de estados como o Braço de Thorim) entram como golpes separados e não se encadeiam.

## Tipos

Cada lutador tem um tipo e ataca com ele, a não ser que a ação diga outro. Multiplicadores: `Tipos.SUPER` (2) e `Tipos.POUCO` (0,5), e nada mais. Arcano tem regra própria: recebe 2× de tudo e causa 2× em tudo, menos em Físico. A tabela completa está em [`tipos.gd`](../../scripts/combate/tipos.gd).

Os tipos dos inimigos são parte do desenho dos andares (ver [Torre e andares](torre-e-andares.md#encontros)).

## Recursos

- **Pontos de skill:** do time, começam em 3, máximo 5. O básico dá 1; cada skill (E e W) custa 1. A batalha cobra `custo_pontos` antes da ação e dá `ganho_pontos` depois.
- **Recarga:** a skill 2 (W) também tem recarga, para não disputar os pontos com a E a cada turno. Recarga N = uma vez a cada N turnos do dono, contando o turno do uso. A batalha inicia a recarga depois da ação (`"recarga"` na habilidade); `Combatente.passar_turno()` desconta e `com_recarga()` põe a barra no estado `recarga`, com os turnos que faltam.
- **Energia:** de cada personagem. Sobe com básico, skill e ao apanhar; paga a ultimate. Quem tem `energia_max = 0` não usa energia, e a HUD esconde a barra.
- **Recurso de kit:** um kit pode ter o próprio (os Fragmentos d'Alma da Àskara). Ele mora na classe do personagem, aparece em `efeitos()` e a barra explica o que falta pela chave `falta` da habilidade. Para ganhar algo quando um inimigo cai, o kit sobrescreve `ao_inimigo_cair()`.

## Estados

`Estado` é o efeito temporário genérico: modificadores (`mods` de ATQ, DEF, VEL e crítico), fraqueza, escudo, vida extra, atraso, provocação, redução de dano, golpe extra e estado aplicado ao acertar. Um por id; aplicar de novo renova. A duração conta turnos do portador.

Invariante: modificadores temporários entram em `bonus()` e nos estados; os atributos de nível ficam em `atq_base`, `def_base`, `vel_base` e `hp_max` (ver [Progressão](progressao.md#atributos)). Nunca some bônus direto nesses campos.

## Kits

Um kit é uma subclasse de `Combatente` (regras) e uma de `AcoesPersonagem` (animações). Todo kit tem básico (Q), skill (E), skill 2 (W), ult (R) e uma passiva, e a barra mostra as cinco sempre nessa ordem (ver [Personagens](personagens.md#padrão-do-kit)). Passivas ficam sem tecla e marcadas como PASSIVA (só reage ao clique se tiver opções, como a lente do Andri). O kit descreve as ações em `habilidades()` (tecla, ícone, custo, alvo, opções, se é livre ou passiva) e os efeitos ativos em `efeitos()`; a batalha e a HUD só leem isso. O formato completo está no comentário de `Combatente.habilidades()`.

Recursos que um kit pode usar sem mexer na batalha:

- `opcoes` com seletor em lista ou radial (`"seletor": "radial"`), abrindo sozinho no começo da vez com `ao_iniciar_turno`.
- `alvo`: `unico`, `vizinhos`, `todos`, `proprio`, `aliado`; ou `alvos_previstos()` para regras próprias.
- `motivo_invalido()` impede confirmar e explica o porquê.
- `livre`: a ação não gasta o turno.
- `alvo` numa opção: a opção mira outro tipo de alvo que a ação (o Escudo do Protocolo MOMC mira um aliado; a Sobrecarga, um inimigo). A marcação, a prévia e o motivo inválido seguem a opção marcada (`Batalha.tipo_alvo()`).
- `recarga`: turnos entre usos (ver [Recursos](#recursos)).
- `detalhes`: uma linha por item da habilidade (cada demônio, cada artefato, cada nível do Kaioken), com rótulo, marca, texto e/ou valores por nível, e o item atual em destaque. O `CartaoHabilidade` mostra nome, etiquetas (passiva, custo, recarga, alvo, elemento), a `descricao` como resumo e os detalhes, na dica da barra (acima dela) e na ficha da montagem da equipe. Assim a `descricao` fica curta e não repete o que as etiquetas já dizem.
- Ataque em conjunto: no fim de cada ação de outro aliado (da equipe ou invocação) que acertou um inimigo, a batalha pergunta a cada um da equipe `Combatente.atacar_junto()`; quem devolver um golpe ataca o primeiro inimigo atingido, se ele ainda estiver de pé (o Bang! da Shumi), com a animação de `AcoesPersonagem.atacar_junto()`. Uma vez por ação, não por golpe, para ataques em área não multiplicarem o efeito. É golpe adicional: sem crítico, sem estados de acerto e sem encadear (golpes `extra` não contam como acerto da ação).

No seletor de opções, W e S não navegam (só ↑/↓): as teclas da barra têm prioridade, porque a lente do Andri abre sozinha no começo da vez e o W tem que continuar chamando a skill 2.

## Invocações

`Invocacao` (subclasse de `Combatente`) é uma criatura chamada por um aliado. Ela entra na fila, tem HP, estados e barra, e fica do lado aliado, mas não é da equipe:

- **Alvos:** `Batalha.aliados_em_campo()` é a equipe de pé mais as invocações em campo. É quem os inimigos sorteiam e quem as ações com alvo `aliado` podem mirar (o Andri pode entregar artefatos a elas).
- **Derrota e recompensa:** usam `aliados_vivos()`, só a equipe. Invocação não segura a luta, não ganha XP e não é salva.
- **Vez:** age sozinha. A batalha usa o `golpe` dela (alcance, mira e estilo, ver o comentário de `Invocacao.golpe`) a partir do inimigo marcado e aplica o `debuff`, se houver. Os golpes passam por `aplicar_dano()` como qualquer outro, então estados de acerto e golpes extras do portador valem.
- **Saída:** depois de `turnos` vezes, ao cair, quando quem a invocou cai ou quando o kit a tira (substituição, o Lorde). Quem tira de campo é `Batalha.remover_invocacao()`; as regras só marcam `em_campo = false`.
- **Último ato:** ao sair por tempo ou ao cair, a invocação faz o `ultimo_ato` dela (golpe no formato de `golpe`, com escudo opcional para o aliado com menor fração de HP), por `Batalha.ultimo_ato()`, antes de sumir. Substituição, o Lorde e a queda de quem invocou não disparam: cada uma já tem a própria troca, e o último ato fica sendo a recompensa de deixar a invocação cumprir o tempo. Como dispara sozinho em toda invocação, os valores são baixos (ver a passiva Último Ato da Àskara).
- **Entrada:** o kit cria a invocação (regras) e as ações chamam `Batalha.adicionar_invocacao()` (vaga, visual, aura) e, se quiserem, `golpe_invocacao()` com o `golpe_entrada`.

A batalha não sabe que invocações existem em cada kit: tudo vem da `Invocacao` que o kit entrega.

## Inimigos

`Inimigo` sorteia o alvo entre os aliados em campo, pelo peso de cada um (`peso_alvo()`: 1 mais a provocação dos estados). Com `golpe_pesado_a_cada > 0`, a cada N ações solta um Golpe Pesado (1,8×), avisado uma ação antes. Os valores de cada inimigo vêm do andar (ver [Torre e andares](torre-e-andares.md)).

**Último recurso** (`ultimo_recurso`, como o Ferro Negro do andar 5): quando um golpe deixa o inimigo de pé abaixo da fração `abaixo_de` do HP, ele ganha um escudo (um `Estado`) uma vez por luta. A regra é `Inimigo.ativar_ultimo_recurso()`; a batalha chama depois de cada golpe (`aplicar_dano()`), aplica o escudo e anuncia no meio da tela ("Ferro Negro ativado"). Golpe que mata direto não ativa.

## Fim da luta

A luta acaba quando um dos lados cai (do lado aliado, a equipe; invocações não contam). Na vitória, a batalha dá a XP e registra o andar uma única vez (`_recompensar()`); depois, Enter, Esc ou clique voltam ao saguão. Não existe abandonar no meio.

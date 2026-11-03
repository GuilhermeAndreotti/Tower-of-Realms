# Torre e andares

Os andares estão em `Floors.LIST` ([`floors.gd`](../../tower/floors.gd)); o formato de cada um está no comentário do arquivo. Andar novo é um item a mais na lista, nada mais muda.

## Missões

Cada andar tem uma **missão principal** (o próprio andar) e **missões secundárias** (`"side"` do andar). Cada ida à dungeon é uma missão. Uma missão se identifica pelo andar e pelo id (`""` é a principal); `Floors.mission()` devolve os dados, e a secundária herda do andar o cenário e o tamanho da equipe quando não tem os seus. O id da secundária vai para o save, então não pode mudar nem repetir.

## Regras

- O andar 1 está sempre liberado; vencer a principal do N libera o N+1.
- As secundárias do N abrem quando a principal do N é vencida. Não liberam andar nem mudam o limite de nível.
- Missões vencidas podem ser repetidas: dão a XP de novo, mas os eventos de história só acontecem na primeira vitória.
- `max_team` limita a seleção e a própria batalha (uma equipe salva maior é cortada).
- `recommended_level` só aparece como aviso; não bloqueia.
- `level_limit` é o limite da Torre enquanto aquele for o andar mais alto liberado (ver [Progressão](progressao.md#limite-da-torre)).

`Floors.complete(andar, id)` registra a vitória: marca a missão, aplica os eventos da primeira vez e devolve o que mudou (andar liberado, secundárias abertas, limite antes e depois), que a tela de vitória mostra.

## O mapa

A escolha da missão é um mapa ([`floor_select.gd`](../../tower/floor_select.gd)): os andares sobem a Torre em fileiras, a principal no caminho em zigue-zague que sai da porta e as secundárias num ramal para o lado oposto. Clicar num círculo mostra a ficha; clicar de novo, Enter ou o botão entra. O mapa rola quando os andares passam da altura da Torre.

O mapa **não revela como a luta funciona**. Antes da primeira vitória, a ficha mostra só nome, descrição, nível recomendado, tamanho da equipe e o que a vitória abre (o andar seguinte, as secundárias, um evento de história). Inimigos, tipos e XP aparecem depois de vencer, como lembrança. Por isso a `description` de cada missão é ambiente, não manual: nada de tipos, golpes, cadência ou segunda forma. O `test_tower.gd` procura essas palavras nas descrições.

## Ritmo planejado

A curva de XP e a XP de cada andar foram escolhidas juntas:

- Sem repetir nada, as primeiras vitórias das principais levam o grupo ao `recommended_level` do andar seguinte.
- O limite deixa treinar só cerca de um nível acima disso (mais ou menos uma repetição).
- Ninguém precisa repetir nem fazer secundárias para avançar; elas dão uma folga pequena, não uma vitória garantida.
- As secundárias do andar N abrem junto com o N+1 e pedem o `recommended_level` dele (as do último andar, um abaixo do limite). Trocam a repetição da mesma luta por uma luta nova, dentro do mesmo limite.

`test_tower.gd` confere essas regras com as contas da `Progression`. Mudou a XP de um andar, a curva ou um limite? Ajuste o resto junto e rode a simulação.

## Encontros

Cada andar ensina ou cobra uma coisa. Os inimigos só têm Investida, Golpe Pesado e, opcionalmente, um último recurso (escudo quando estão quase caindo) e uma segunda forma (voltam uma vez depois de derrotados; ver [Combate](combate.md#inimigos)); a variedade vem de tipos, velocidade, cadência do Golpe Pesado e composição:

| Andar | Equipe | O que cobra                                                                                     |
| ----- | ------ | ----------------------------------------------------------------------------------------------- |
| 1     | 1      | aprender Corte, Engo-ji e pontos de skill                                                       |
| 2     | 1      | o primeiro Golpe Pesado: quando entrar no Kaioken                                               |
| 3     | 2      | o Andri chega; as sentinelas Físicas caem com a lente Ácido, mas o Guardião de Veneno não é fraco a nenhuma lente (Análise ou Engo-ji? os pontos são do time), e a sentinela veloz age quase duas vezes por rodada |
| 4     | 2      | chefe de Trevas (nenhuma lente é super efetiva) com Golpe Pesado a cada 2 ações; escolta de Água (2× no Andri) e de Ácido (2× na Shumi) |
| 5     | 3      | a primeira luta a três: Golem de Pedra Físico (lente Ácido) e Elementais de Fogo (lente Água), então o Andri troca de lente conforme o alvo; o Ferro Negro dá escudo aos Elementais abaixo de 30%; derrotado, o Golem absorve os Elementais de pé e volta incandescente (de Fogo, com laser em toda a equipe a cada 2 ações), então derrubar os Elementais antes deixa a segunda forma mais fraca. A luta tem cenário próprio, a forja |

As secundárias reaproveitam os inimigos e cobram o que o andar ensinou, de outro jeito:

| Andar | Missão (id)                 | Equipe | O que cobra                                                                                 |
| ----- | --------------------------- | ------ | ------------------------------------------------------------------------------------------- |
| 1     | Ronda da Escada (`ronda`)    | 1      | três alvos: Engo-ji em área e ordem dos alvos                                                |
| 2     | Ecos do Salão (`ecos`)       | 2      | a primeira dupla: dois Guardiões com velocidades diferentes, então os Golpes Pesados se alternam |
| 3     | Corredor das Tochas (`corredor`) | 2  | três Sentinelas Velozes e frágeis, que agem antes da equipe: dano em área ou foco rápido    |
| 3     | Cisterna (`cisterna`)        | 2      | dois Guardiões de Veneno, sem lente super efetiva: Análise e pontos de skill                 |
| 4     | Capela Alagada (`capela`)    | 2      | Guardião de Água (2× no Andri) e Sentinelas de Ácido (2× na Shumi)                           |
| 4     | Vigília Sombria (`vigilia`)  | 2      | dois Guardiões Sombrios com Golpe Pesado a cada 2 ações, sem folga entre um e outro           |
| 5     | Fornalha (`fornalha`)        | 3      | três Elementais com o Ferro Negro: derrubar um de cada vez ou enfrentar três escudos juntos   |
| 5     | Pedreira (`pedreira`)        | 3      | dois Golems sem segunda forma: luta longa de resistência, no cenário comum                    |

Ao criar inimigos, confira a tabela de tipos contra o kit de quem estará na equipe: um tipo que deixa um personagem sempre em 2× apaga a decisão do kit.

## Equilíbrio

O equilíbrio é medido com a simulação (ver [Testes e ferramentas](../desenvolvimento/testes-e-ferramentas.md#simulação-dos-andares)), em três níveis por missão: um abaixo do recomendado, o recomendado e o limite. A meta no recomendado:

- a curva de risco sobe com os andares (HP restante cai, turnos sobem);
- o último andar é o maior desafio, ainda vencível no recomendado;
- o limite dá vantagem visível, sem deixar a luta trivial;
- a secundária do andar N fica entre a principal do N e a do N+1: vencível sempre no recomendado, com HP restante entre 35% e 60%.

A simulação usa um piloto simples. Ela compara andares e níveis entre si; não diz se a luta é divertida, e não substitui jogar.

## Eventos de história

`StoryEvents` ([`story_events.gd`](../../tower/story_events.gd)) tem dois lados:

- **Efeito**: aplicado na hora e salvo (`StoryEvents.apply()`).
- **Apresentação**: fica na fila `torre/eventos_pendentes` e roda no saguão, na volta (ver [Saguão](saguao.md#eventos-de-história)).

Vêm do `on_win` de uma missão (primeira vitória) ou de uma fala com `"event": "type:id"`. Um evento que já não muda nada (`unlock` de quem já está liberado) é descartado antes de aplicar, sem efeito nem apresentação (`StoryEvents.pending()`). Tipos:

| Tipo          | Efeito                                         | Apresentação no saguão                     |
| ------------- | ---------------------------------------------- | ------------------------------------------ |
| `unlock`      | libera o personagem (`Progression.unlock`)     | ele surge com anel de luz e anúncio        |
| `conversation` | nenhum                                         | abre a conversa, se ela tiver falas        |

Tipo novo: efeito em `StoryEvents.apply()`, apresentação em `Lobby._present()` e a linha da tela de vitória em `StoryEvents.summary()`.

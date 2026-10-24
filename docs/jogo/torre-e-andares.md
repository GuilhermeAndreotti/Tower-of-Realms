# Torre e andares

Os andares estão em `Andares.LISTA` ([`andares.gd`](../../scripts/torre/andares.gd)); o formato de cada um está no comentário do arquivo. Andar novo é um item a mais na lista, nada mais muda.

## Regras

- O andar 1 está sempre liberado; vencer o N libera o N+1.
- Andares vencidos podem ser repetidos: dão a XP de novo, mas os eventos de história só acontecem na primeira vitória.
- `max_equipe` limita a seleção e a própria batalha (uma equipe salva maior é cortada).
- `nivel_recomendado` só aparece como aviso; não bloqueia.
- `limite_nivel` é o limite da Torre enquanto aquele for o andar mais alto liberado (ver [Progressão](progressao.md#limite-da-torre)).

`Andares.concluir()` registra a vitória: marca o andar, aplica os eventos da primeira vez e devolve o que mudou (andar liberado, limite antes e depois), que a tela de vitória mostra.

## Ritmo planejado

A curva de XP e a XP de cada andar foram escolhidas juntas:

- Sem repetir nada, as primeiras vitórias levam o grupo ao `nivel_recomendado` do andar seguinte.
- O limite deixa treinar só cerca de um nível acima disso (mais ou menos uma repetição).
- Ninguém precisa repetir andares para avançar; repetir dá uma folga pequena, não uma vitória garantida.

`teste_torre.gd` confere as duas primeiras regras com as contas da `Progressao`. Mudou a XP de um andar, a curva ou um limite? Ajuste o resto junto e rode a simulação.

## Encontros

Cada andar ensina ou cobra uma coisa. Os inimigos só têm Investida e Golpe Pesado; a variedade vem de tipos, velocidade, cadência do Golpe Pesado e composição:

| Andar | Equipe | O que cobra                                                                                     |
| ----- | ------ | ----------------------------------------------------------------------------------------------- |
| 1     | 1      | aprender Corte, Engo-ji e pontos de skill                                                        |
| 2     | 1      | o primeiro Golpe Pesado: quando entrar no Kaioken                                               |
| 3     | 2      | o Andri chega; as sentinelas Físicas caem com a lente Ácido, mas o Guardião de Veneno não é fraco a nenhuma lente (Análise ou Engo-ji? os pontos são do time), e a sentinela veloz age quase duas vezes por rodada |
| 4     | 2      | chefe de Trevas (nenhuma lente é super efetiva) com Golpe Pesado a cada 2 ações; escolta de Água (2× no Andri) e de Ácido (2× na Shumi) |

Ao criar inimigos, confira a tabela de tipos contra o kit de quem estará na equipe: um tipo que deixa um personagem sempre em 2× apaga a decisão do kit.

## Equilíbrio

O equilíbrio é medido com a simulação (ver [Testes e ferramentas](../desenvolvimento/testes-e-ferramentas.md#simulação-dos-andares)), em três níveis por andar: um abaixo do recomendado, o recomendado e o limite. A meta no recomendado:

- a curva de risco sobe com os andares (HP restante cai, turnos sobem);
- o último andar é o maior desafio, ainda vencível no recomendado;
- o limite dá vantagem visível, sem deixar a luta trivial.

A simulação usa um piloto simples. Ela compara andares e níveis entre si; não diz se a luta é divertida, e não substitui jogar.

## Eventos de história

`Eventos` ([`eventos.gd`](../../scripts/torre/eventos.gd)) tem dois lados:

- **Efeito**: aplicado na hora e salvo (`Eventos.aplicar()`).
- **Apresentação**: fica na fila `torre/eventos_pendentes` e roda no saguão, na volta (ver [Saguão](saguao.md#eventos-de-história)).

Vêm do `ao_vencer` de um andar (primeira vitória) ou de uma fala com `"evento": "tipo:id"`. Um evento que já não muda nada (`desbloquear` de quem já está liberado) é descartado antes de aplicar, sem efeito nem apresentação (`Eventos.pendente()`). Tipos:

| Tipo          | Efeito                                         | Apresentação no saguão                     |
| ------------- | ---------------------------------------------- | ------------------------------------------ |
| `desbloquear` | libera o personagem (`Progressao.desbloquear`) | ele surge com anel de luz e anúncio        |
| `conversa`    | nenhum                                         | abre a conversa, se ela tiver falas        |

Tipo novo: efeito em `Eventos.aplicar()`, apresentação em `Lobby._apresentar()` e a linha da tela de vitória em `Eventos.resumo()`.

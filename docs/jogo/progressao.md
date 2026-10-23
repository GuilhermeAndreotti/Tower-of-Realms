# Progressão

Níveis, experiência, limite de nível e save. As regras e as fórmulas estão todas em `Progressao` ([`progressao.gd`](../../scripts/personagens/progressao.gd)); o limite de cada andar, em `Andares`. Nenhum outro lugar calcula XP ou nível.

## Experiência

- Cada personagem tem nível e XP próprios. O XP salvo é o acumulado dentro do nível atual.
- Para ir do nível *n* ao *n+1*: `XP_BASE + XP_POR_NIVEL × (n − 1)`.
- A XP que sobra ao subir conta para o próximo; uma recompensa grande sobe vários níveis de uma vez, até o teto.
- `NIVEL_MAX` é o máximo do jogo. No máximo, o XP fica em 0.

## Limite da Torre

O limite de nível vem do andar mais alto liberado (`limite_nivel` de cada andar). A única fonte é `Andares.limite_nivel()`; ele é calculado a partir dos andares vencidos, que estão no save.

- No limite, o XP fica em 0 e o excedente se perde. Quando o limite sobe, ninguém ganha vários níveis de uma vez com XP guardado.
- Repetir um andar não muda o limite; só liberar um andar novo muda.
- Quem já está acima do limite (save antigo) não perde nível: só não ganha XP.
- Limite da Torre e `NIVEL_MAX` são coisas diferentes: o primeiro acompanha a campanha, o segundo é o teto absoluto.

## Recompensa de vitória

`Progressao.recompensar_vitoria()`, chamada pela batalha uma vez por luta:

- Quem lutou recebe a XP inteira dos inimigos, inclusive quem caiu.
- Quem já foi liberado e ficou de fora recebe o mesmo valor: trocar de equipe não custa níveis.
- O valor não depende do tamanho do elenco nem da equipe.
- Quem não foi liberado não ganha nada, e a recompensa nunca libera ninguém.
- Derrota não dá nada.
- O resultado de cada personagem traz a XP que realmente contou (`xp_aproveitada`), se subiu, os atributos ganhos e se parou no limite; a tela de vitória mostra isso.

A batalha protege contra recompensa dupla (`_recompensada`); voltar ao saguão ou abrir a batalha de novo é outra luta.

## Atributos

Os atributos do `_init` de cada personagem valem para o nível 1 (`Combatente.atributos_nv1()`). Em cada nível:

```
atributo(nível) = atributo de nível 1 + crescimento × (nível − 1)
```

- `aplicar_nivel()` recalcula sempre a partir do nível 1: chamar de novo não acumula nada.
- A vida extra de estados continua por cima; o HP atual ganha o que o máximo ganhou, sem passar dele; quem caiu continua caído.
- Modificadores de combate ficam fora desses campos (ver [Combate](combate.md#estados)).
- A energia não cresce com o nível.

## Personagem novo

`Progressao.desbloquear(id)` libera o personagem:

1. Média dos níveis da equipe principal (a última montada na seleção), sem contar ele.
2. Sem equipe salva, a média de todos os liberados.
3. Arredonda (x,5 para cima), limita entre 1 e o limite atual da Torre.
4. Entra com 0 de XP e com os próprios atributos nesse nível.

Liberar de novo quem já está liberado não muda nada.

## Save

`user://progresso.cfg` (`ConfigFile`), seções:

| Seção / chave                      | Conteúdo                                  |
| ---------------------------------- | ----------------------------------------- |
| `jogo/versao`                      | versão do formato (`VERSAO_SAVE`)         |
| `jogador/equipe`                   | ids da última equipe                      |
| `personagem_<id>/nivel`, `xp`      | progresso; a seção existir = liberado     |
| `torre/vencidos`                   | andares vencidos                          |
| `torre/andar`                      | andar escolhido                           |
| `torre/eventos_pendentes`          | eventos ainda não apresentados no saguão  |

Compatibilidade: chaves que faltam valem o padrão (nível 1, XP 0, nada vencido); valores fora da regra são corrigidos na leitura; ids que não existem mais são ignorados. Mudou o formato de um jeito que não dá para ler o antigo? Suba `VERSAO_SAVE` e converta na leitura.

`Progressao.arquivo` é trocável: testes e ferramentas usam arquivos próprios e apagam no fim.

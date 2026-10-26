# Progressão

Níveis, experiência, limite de nível e save. As regras e as fórmulas estão todas em `Progression` ([`progression.gd`](../../progression/progression.gd)); o limite de cada andar, em `Floors`. Nenhum outro lugar calcula XP ou nível.

## Experiência

- Cada personagem tem nível e XP próprios. O XP salvo é o acumulado dentro do nível atual.
- Para ir do nível *n* ao *n+1*: `XP_BASE + XP_PER_LEVEL × (n − 1)`.
- A XP que sobra ao subir conta para o próximo; uma recompensa grande sobe vários níveis de uma vez, até o teto.
- `MAX_LEVEL` é o máximo do jogo. No máximo, o XP fica em 0.

## Limite da Torre

O limite de nível vem do andar mais alto liberado (`level_limit` de cada andar). A única fonte é `Floors.level_limit()`; ele é calculado a partir dos andares vencidos, que estão no save.

- No limite, o XP fica em 0 e o excedente se perde. Quando o limite sobe, ninguém ganha vários níveis de uma vez com XP guardado.
- Repetir um andar não muda o limite; só liberar um andar novo muda.
- Quem já está acima do limite (save antigo) não perde nível: só não ganha XP.
- Limite da Torre e `MAX_LEVEL` são coisas diferentes: o primeiro acompanha a campanha, o segundo é o teto absoluto.

## Recompensa de vitória

`Progression.reward_victory()`, chamada pela batalha uma vez por luta:

- Quem lutou recebe a XP inteira dos inimigos, inclusive quem caiu.
- Quem já foi liberado e ficou de fora recebe o mesmo valor: trocar de equipe não custa níveis.
- O valor não depende do tamanho do elenco nem da equipe.
- Quem não foi liberado não ganha nada, e a recompensa nunca libera ninguém.
- Derrota não dá nada.
- O resultado de cada personagem traz a XP que realmente contou (`xp_gained`), se subiu, os atributos ganhos e se parou no limite; a tela de vitória mostra isso.

A batalha protege contra recompensa dupla (`_rewarded`); voltar ao saguão ou abrir a batalha de novo é outra luta.

## Atributos

Os atributos do `_init` de cada personagem valem para o nível 1 (`Combatant.level_1_stats()`). Em cada nível:

```
atributo(nível) = atributo de nível 1 + crescimento × (nível − 1)
```

- `apply_level()` recalcula sempre a partir do nível 1: chamar de novo não acumula nada.
- A vida extra de estados continua por cima; o HP atual ganha o que o máximo ganhou, sem passar dele; quem caiu continua caído.
- Modificadores de combate ficam fora desses campos (ver [Combate](combate.md#estados)).
- A energia não cresce com o nível.

## Personagem novo

`Progression.unlock(id)` libera o personagem:

1. Média dos níveis da equipe principal (a última montada na seleção), sem contar ele.
2. Sem equipe salva, a média de todos os liberados.
3. Arredonda (x,5 para cima), limita entre 1 e o limite atual da Torre.
4. Entra com 0 de XP e com os próprios atributos nesse nível.

Liberar de novo quem já está liberado não muda nada.

## Save

Um `ConfigFile` por slot de save (`SLOTS`): o slot 1 é `user://progresso.cfg`, o mesmo arquivo de antes do menu existir, então um save antigo aparece nele sem conversão; os outros são `progresso_<n>.cfg`. O menu inicial escolhe o slot (`use_slot`, `new_game`, `delete_slot`; ver [Menu inicial](menu-inicial.md)). Seções:

| Seção / chave                      | Conteúdo                                  |
| ---------------------------------- | ----------------------------------------- |
| `jogo/versao`                      | versão do formato (`SAVE_VERSION`)        |
| `jogo/salvo_em`                    | último salvamento (unix), para o menu     |
| `jogador/equipe`                   | ids da última equipe                      |
| `personagem_<id>/nivel`, `xp`      | progresso; a seção existir = liberado     |
| `torre/vencidos`                   | andares vencidos                          |
| `torre/andar`                      | andar escolhido                           |
| `torre/eventos_pendentes`          | eventos ainda não apresentados no saguão  |

As seções e chaves do save ficam em português, mesmo com o código em inglês: são o formato do arquivo, e mudar o nome delas faria saves antigos abrirem vazios. Os eventos pendentes gravados antes do código em inglês (`{"tipo": "desbloquear", "id", "quem"?}`) são convertidos na leitura para o formato atual (`{"type": "unlock", "id", "speaker"?}`).

Compatibilidade: chaves que faltam valem o padrão (nível 1, XP 0, nada vencido); valores fora da regra são corrigidos na leitura; ids que não existem mais são ignorados. Mudou o formato de um jeito que não dá para ler o antigo? Suba `SAVE_VERSION` e converta na leitura.

`Progression.file` e `Progression.slots_prefix` são trocáveis: testes e ferramentas usam arquivos próprios e apagam no fim.

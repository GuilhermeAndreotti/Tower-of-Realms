# AGENTS.md

## Regras obrigatórias

- Documentação, comentários, mensagens de commit e textos do jogo em pt-BR. O código usa nomes em inglês: pastas, arquivos, classes, funções, variáveis, sinais e chaves de dicionário. A exceção são as seções e chaves do save (`ConfigFile`), que continuam em português para saves antigos abrirem.
- Pastas por feature: a cena, o script e a arte de uma feature ficam juntos na pasta dela; só o que várias telas usam vai para `ui/` ([visão geral](docs/arquitetura/visao-geral.md#pastas)).
- GDScript com tipagem estática: tipos explícitos ou inferidos (`:=`), sem desligar avisos de tipo para contornar erro.
- Siga o estilo do arquivo que estiver editando: comentários `##` curtos explicando o porquê, mesma densidade de comentários e os mesmos nomes de conceito.
- Não adicione plugins, autoloads nem dependências sem necessidade clara.
- Nunca leia, escreva ou apague os saves do jogador (`user://progresso*.cfg`) em testes e ferramentas; use um `Progression.file` (e, para slots, um `Progression.slots_prefix`) próprio.
- Mudança que o jogador percebe entra no [`CHANGELOG.md`](CHANGELOG.md) no mesmo commit ([regras](docs/entrega/changelog-e-commits.md)).

## Antes de alterar código

1. Leia [`docs/README.md`](docs/README.md).
2. Leia o documento canônico do assunto (combate, progressão, Torre, saguão, menu...).
3. Só então altere código, dados ou arte.

Não crie documento novo sem verificar se o assunto já tem um. Mudou uma regra? Atualize o documento canônico no mesmo commit.

## Invariantes essenciais

- Regras, animações e interface ficam separadas: `Combatant` e subclasses não tocam em nós de cena; `CharacterActions` não decide dano; a HUD não tem regra ([visão geral](docs/arquitetura/visao-geral.md#camadas)). Regras e animações falam com a interface por sinais (`Battle.log_line()`, `Battle.announce()`), nunca chamando a HUD.
- Fases de fluxo (a vez na batalha, o que acontece no saguão, o movimento da Caoimhe) ficam numa `StateMachine` com as trocas declaradas; não volte a controlar isso com flags soltas ([padrões](docs/arquitetura/visao-geral.md#padrões)).
- Batalha, HUD e progressão não têm condicionais por personagem: tudo vem de `Roster.data()` e do kit ([personagens](docs/jogo/personagens.md)).
- Fórmulas de XP e nível só em `Progression`; o limite de nível só em `Floors.level_limit()` ([progressão](docs/jogo/progressao.md)).
- Atributos de nível são sempre recalculados a partir do nível 1; modificadores temporários nunca são somados nos campos base.
- A recompensa de uma vitória é dada uma vez só, e só na vitória.
- Eventos de história: efeito aplicado e salvo na hora; apresentação na fila, removida só depois de apresentada ([Torre e andares](docs/jogo/torre-e-andares.md#eventos-de-história)).
- Save antigo continua abrindo: chave que falta vale o padrão, valor inválido é corrigido na leitura.
- Arte gerada por script é alterada no gerador em `tools/`, não no PNG.

## Validação

Rode os cinco testes antes de dar uma tarefa por concluída ([como rodar](docs/desenvolvimento/testes-e-ferramentas.md#testes)). Mudança de equilíbrio (inimigos, XP, crescimento, kits) pede também a simulação dos andares, antes e depois. Não afirme que algo foi testado jogando se só rodou testes ou simulação.

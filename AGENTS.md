# AGENTS.md

## Regras obrigatórias

- Documentação, mensagens de commit e textos do jogo em pt-BR. O código também usa nomes em português (classes, funções, variáveis), como o resto do projeto.
- GDScript com tipagem estática: tipos explícitos ou inferidos (`:=`), sem desligar avisos de tipo para contornar erro.
- Siga o estilo do arquivo que estiver editando: comentários `##` curtos explicando o porquê, mesma densidade de comentários e os mesmos nomes de conceito.
- Não adicione plugins, autoloads nem dependências sem necessidade clara.
- Nunca leia, escreva ou apague o save do jogador (`user://progresso.cfg`) em testes e ferramentas; use um `Progressao.arquivo` próprio.
- Mudança que o jogador percebe entra no [`CHANGELOG.md`](CHANGELOG.md) no mesmo commit ([regras](docs/entrega/changelog-e-commits.md)).

## Antes de alterar código

1. Leia [`docs/README.md`](docs/README.md).
2. Leia o documento canônico do assunto (combate, progressão, Torre, saguão...).
3. Só então altere código, dados ou arte.

Não crie documento novo sem verificar se o assunto já tem um. Mudou uma regra? Atualize o documento canônico no mesmo commit.

## Invariantes essenciais

- Regras, animações e interface ficam separadas: `Combatente` e subclasses não tocam em nós de cena; `AcoesPersonagem` não decide dano; a HUD não tem regra ([visão geral](docs/arquitetura/visao-geral.md#camadas)).
- Batalha, HUD e progressão não têm condicionais por personagem: tudo vem de `Elenco.dados()` e do kit ([personagens](docs/jogo/personagens.md)).
- Fórmulas de XP e nível só em `Progressao`; o limite de nível só em `Andares.limite_nivel()` ([progressão](docs/jogo/progressao.md)).
- Atributos de nível são sempre recalculados a partir do nível 1; modificadores temporários nunca são somados nos campos base.
- A recompensa de uma vitória é dada uma vez só, e só na vitória.
- Eventos de história: efeito aplicado e salvo na hora; apresentação na fila, removida só depois de apresentada ([Torre e andares](docs/jogo/torre-e-andares.md#eventos-de-história)).
- Save antigo continua abrindo: chave que falta vale o padrão, valor inválido é corrigido na leitura.
- Arte gerada por script é alterada no gerador em `ferramentas/`, não no PNG.

## Validação

Rode os quatro testes antes de dar uma tarefa por concluída ([como rodar](docs/desenvolvimento/testes-e-ferramentas.md#testes)). Mudança de equilíbrio (inimigos, XP, crescimento, kits) pede também a simulação dos andares, antes e depois. Não afirme que algo foi testado jogando se só rodou testes ou simulação.

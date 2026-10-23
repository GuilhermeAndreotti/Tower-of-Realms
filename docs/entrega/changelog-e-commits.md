# Changelog e commits

## Changelog

[`CHANGELOG.md`](../../CHANGELOG.md) segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e o [Versionamento Semântico](https://semver.org/lang/pt-BR/).

- Toda mudança que o jogador percebe, ou que muda como se trabalha no projeto, entra em `[Unreleased]` no mesmo commit.
- Seções, nesta ordem, só as que tiverem itens: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`.
- Escreva para quem joga ou mantém o jogo: o que mudou e o efeito, não o nome da função. Mudanças de equilíbrio dizem os números novos.
- Refatoração sem efeito visível e ajuste de teste não entram.

## Versão

Enquanto o jogo for protótipo, a versão fica em `0.y.z`:

- `y` sobe com conteúdo ou sistemas novos (andares, personagens, mecânicas) ou save que não abre mais em versão anterior;
- `z` sobe com correções e ajustes de equilíbrio.

Para fechar uma versão: renomeie `[Unreleased]` para `[0.y.z] - AAAA-MM-DD`, crie um `[Unreleased]` vazio acima, atualize os links de comparação no fim do arquivo e crie a tag `v0.y.z` no commit.

## Commits

- Mensagens em pt-BR, no presente e no imperativo da terceira pessoa ("Adiciona…", "Corrige…"), com a primeira linha curta.
- Um commit por assunto; código, testes, documentação e changelog do mesmo assunto vão juntos.
- Antes de commitar, rode os testes ([Testes e ferramentas](../desenvolvimento/testes-e-ferramentas.md#testes)).
- Não versione `.godot/`, saves nem capturas. Os `.import` e `.uid` gerados pelo Godot são versionados junto do arquivo a que pertencem.

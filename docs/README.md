# Documentação

Aqui fica o que não dá para descobrir só lendo o código: como as partes se encaixam, por que as regras são como são e o que não pode quebrar. Cada assunto tem um documento canônico; os outros apontam para ele por link, sem repetir a explicação.

## Onde encontrar cada assunto

| Preciso entender...                                   | Documento                                                             |
| ----------------------------------------------------- | --------------------------------------------------------------------- |
| Cenas, camadas e como o estado passa entre telas       | [Visão geral](arquitetura/visao-geral.md)                             |
| Fila de turnos, dano, tipos, estados e kits            | [Combate](jogo/combate.md)                                            |
| Como um personagem é definido e como adicionar outro  | [Personagens](jogo/personagens.md)                                    |
| Níveis, XP, limite da Torre e save                     | [Progressão](jogo/progressao.md)                                      |
| Andares, encontros, eventos de história e equilíbrio   | [Torre e andares](jogo/torre-e-andares.md)                            |
| Saguão, conversas e apresentação de eventos            | [Saguão](jogo/saguao.md)                                              |
| Testes, simulação e geradores de arte                  | [Testes e ferramentas](desenvolvimento/testes-e-ferramentas.md)       |
| Changelog e commits                                    | [Changelog e commits](entrega/changelog-e-commits.md)                 |

## Fontes canônicas

| Informação                               | Fonte canônica                                                      |
| ---------------------------------------- | ------------------------------------------------------------------- |
| Versão do Godot e configuração do projeto | [`project.godot`](../project.godot)                                 |
| Personagens jogáveis e crescimento        | [`scripts/personagens/elenco.gd`](../scripts/personagens/elenco.gd) |
| Curva de XP e regras de progressão        | [`scripts/personagens/progressao.gd`](../scripts/personagens/progressao.gd) |
| Andares, inimigos e limites de nível      | [`scripts/torre/andares.gd`](../scripts/torre/andares.gd)           |
| Tabela de tipos                           | [`scripts/combate/tipos.gd`](../scripts/combate/tipos.gd)           |
| Kits (números de cada habilidade)         | a classe de cada personagem em `scripts/personagens/`               |
| Mudanças notáveis                         | [`CHANGELOG.md`](../CHANGELOG.md)                                   |
| Descrição do jogo para quem joga          | [`README.md`](../README.md)                                         |

Os documentos explicam a intenção e os invariantes; os números ficam no código. Quando um documento cita um valor, é como exemplo: o código vale.

## Padrão editorial

- Tudo em pt-BR. Nomes de arquivo em ASCII, minúsculas e kebab-case; a exceção é este `README.md`.
- Um H1 por documento, na primeira linha.
- Links relativos. Não copie o que já está na fonte canônica: aponte para ela.
- Mudou uma regra? Atualize o documento canônico no mesmo commit.

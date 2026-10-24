# Personagens

Os personagens jogáveis estão cadastrados em `Elenco` ([`elenco.gd`](../../scripts/personagens/elenco.gd)). Nem a batalha, nem a HUD, nem a progressão têm condicionais por personagem: tudo vem do cadastro e do kit.

## O que define um personagem

| Parte                      | Onde                                         | Observação                                               |
| -------------------------- | -------------------------------------------- | -------------------------------------------------------- |
| Atributos de nível 1        | `super(...)` no `_init` da classe de regras | HP, ATQ, DEF, VEL e tipo                                 |
| Kit (regras)                | classe que estende `Combatente`              | ver [Combate](combate.md#kits)                           |
| Animações                   | classe que estende `AcoesPersonagem`         |                                                          |
| Nome, origem, universo, sprite | `Elenco.dados()`                          | `sprite`: png, json, pé, altura e retângulo do rosto     |
| Crescimento por nível       | `Elenco.dados().crescimento`                 | ver [Progressão](progressao.md#atributos)                |
| Começa bloqueado?           | `Elenco.dados().inicial = false`             | sem a chave, já começa liberado; por enquanto `Elenco.todos_liberados` libera todos (ver abaixo) |
| Lugar no saguão             | `Lobby.LUGARES` (opcional)                   | sem lugar, ele usa um dos `LUGARES_LIVRES`               |

## Adicionar um personagem

1. Crie a classe de regras em `scripts/personagens/` (`extends Combatente`), com os atributos de nível 1 no `_init`, e implemente `habilidades()`, `efeitos()`, `pode_usar()` e o que o kit precisar.
2. Crie a classe de animações (`extends AcoesPersonagem`) e implemente `executar()`.
3. Ponha o id em `Elenco.IDS` e os dados em `Elenco.dados()`, incluindo o `crescimento`.
4. Se ele chega pela história, use `"inicial": false` e libere com um evento `desbloquear` (ver [Torre e andares](torre-e-andares.md#eventos-de-história)).
5. Monte o kit no [padrão](#padrão-do-kit) e dê a ele uma passiva em `habilidades()` (`"passiva": true`, sem tecla, com ícone e descrição começando por "Passiva:"): a barra da batalha e a montagem da equipe explicam todos os kits no mesmo padrão. Os ícones seguem o padrão de [`ferramentas/icone_pixel.py`](../../ferramentas/icone_pixel.py): desenho 11x11 centrado num PNG 15x15, sem moldura, com a borda num tom escuro da própria cor.
6. Rode os testes; `teste_combate.gd` confere que todo personagem está cadastrado completo e explica a passiva.

## Padrão do kit

Todo personagem tem cinco entradas na barra, sempre nesta ordem:

| Ordem | Entrada | Tecla | Observação |
| ----- | ------- | ----- | ---------- |
| 1 | Ataque básico | Q | gera ponto de skill |
| 2 | Skill 1 | E | custa ponto de skill |
| 3 | Skill 2 | W | a mais livre: pode ser um ataque ou ação (com custo e `recarga`) ou uma passiva; passiva fica neste mesmo lugar, sem tecla |
| 4 | Ultimate | R | energia ou recurso do kit |
| 5 | Passiva | — | a identidade do personagem, sempre por último |

A ordem vale mesmo quando a skill 2 é passiva (a Àskara: Seta Vil, Invocação, Último Ato, Lorde Demônio, Fragmento d'Alma). As teclas são da ação, não da posição: a skill 1 é sempre E e a skill 2, quando é ativa, W. `teste_combate.gd` confere a ordem.

## Identidade e crescimento

O crescimento tem que refletir o papel do personagem, e não ser igual para todos. Hoje:

- **Shumi** (Físico, ofensiva): o ATQ é o que mais cresce; HP alto para aguentar o dreno do Kaioken; quase não ganha VEL, porque o Kaioken já acelera.
- **Andri** (Fogo, suporte): ATQ cresce menos; ganha VEL e DEF para agir cedo e sobreviver para entregar os artefatos.
- **Àskara** (Trevas, invocadora, de Nariagari): frágil, com HP e DEF baixos; as invocações copiam uma fração dos atributos dela na hora em que são chamadas, então o crescimento dela é também o delas. Não usa energia: a ult é paga em Fragmentos d'Alma (ver [Combate](combate.md#invocações)).

As skills 2 seguem o papel de cada um: a Shumi ganha um contra-ataque que escala com o Kaioken (Bang!, com o visual Kokoro em cada Finger Beam), o Andri usa o MOMC para proteger ou bater (Protocolo MOMC) e a Àskara tem uma passiva, o Último Ato dos demônios.

## Liberação temporária

Por enquanto, `Elenco.todos_liberados` é `true`: todos começam liberados, inclusive quem tem `"inicial": false`. O cadastro e os eventos de história continuam como estão, para a chegada pela história voltar a valer ao desligar a chave. Os testes desligam a chave para testar a história; `teste_torre.gd` confere também o modo ligado.

Mexer em crescimento muda o equilíbrio de todos os andares: rode a simulação antes e depois (ver [Testes e ferramentas](../desenvolvimento/testes-e-ferramentas.md#simulação-dos-andares)).

## Caoimhe

A Caoimhe é quem o jogador conduz no saguão. Ela não luta e não está no `Elenco`; os dados dela ficam em `Lobby.CAOIMHE`, no mesmo formato.

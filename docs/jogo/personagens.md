# Personagens

Os personagens jogáveis estão cadastrados em `Roster` ([`roster.gd`](../../characters/roster.gd)). Nem a batalha, nem a HUD, nem a progressão têm condicionais por personagem: tudo vem do cadastro e do kit.

## O que define um personagem

| Parte                      | Onde                                         | Observação                                               |
| -------------------------- | -------------------------------------------- | -------------------------------------------------------- |
| Atributos de nível 1       | `super(...)` no `_init` da classe de regras  | HP, ATQ, DEF, VEL e tipo                                 |
| Kit (regras)               | classe que estende `Combatant`               | ver [Combate](combate.md#kits)                           |
| Animações                  | classe que estende `CharacterActions`        |                                                          |
| Nome, origem, universo, sprite | `Roster.data()`                              | `sprite`: png, json, pé, altura e retângulo do rosto     |
| Crescimento por nível      | `Roster.data().growth`                       | ver [Progressão](progressao.md#atributos)                |
| Começa bloqueado?          | `Roster.data().starts_unlocked = false`      | sem a chave, já começa liberado; por enquanto `Roster.all_unlocked` libera todos (ver abaixo) |
| Lugar no saguão            | `Lobby.SPOTS` (opcional)                     | sem lugar, ele usa um dos `FREE_SPOTS`                   |

## Adicionar um personagem

1. Crie a classe de regras em `characters/` (`extends Combatant`), com os atributos de nível 1 no `_init`, e implemente `skills()`, `effects()`, `can_use()` e o que o kit precisar.
2. Crie a classe de animações (`extends CharacterActions`) e implemente `execute()`.
3. Ponha o id em `Roster.IDS` e os dados em `Roster.data()`, incluindo o `growth`.
4. Se ele chega pela história, use `"starts_unlocked": false` e libere com um evento `unlock` (ver [Torre e andares](torre-e-andares.md#eventos-de-história)).
5. Monte o kit no [padrão](#padrão-do-kit) e dê a ele uma passiva em `skills()` (`"passive": true`, sem tecla, com ícone e descrição; a etiqueta PASSIVA vem do cartão). Habilidades com vários itens (opções, níveis, invocações) listam cada um em `details`, em vez de um parágrafo: a barra da batalha e a montagem da equipe explicam todos os kits no mesmo padrão ([Combate](combate.md#kits)). Os ícones seguem o padrão de [`tools/pixel_icon.py`](../../tools/pixel_icon.py): desenho 11x11 centrado num PNG 15x15, sem moldura, com a borda num tom escuro da própria cor.
6. Crie `characters/<id>/README.md` com a apresentação e as marcas do trecho gerado (copie de um existente), rode `tools/generate_character_readmes.gd` e ponha o link na tabela de personagens do README principal. Sempre que mudar o texto de um kit, rode o gerador de novo.
7. Rode os testes; `test_combat.gd` confere que todo personagem está cadastrado completo, explica a passiva e tem o README em dia.

## Padrão do kit

Todo personagem tem cinco entradas na barra, sempre nesta ordem:

| Ordem | Entrada | Tecla | Observação |
| ----- | ------- | ----- | ---------- |
| 1     | Ataque básico | Q     | gera ponto de skill |
| 2     | Skill 1 | E     | custa ponto de skill |
| 3     | Skill 2 | W     | a mais livre: pode ser um ataque ou ação (com custo e `cooldown`) ou uma passiva; passiva fica neste mesmo lugar, sem tecla |
| 4     | Ultimate | R     | energia ou recurso do kit |
| 5     | Passiva | —     | a identidade do personagem, sempre por último |

A ordem vale mesmo quando a skill 2 é passiva (a Àskara: Seta Vil, Invocação, Último Ato, Lorde Demônio, Fragmento d'Alma). As teclas são da ação, não da posição: a skill 1 é sempre E e a skill 2, quando é ativa, W. `test_combat.gd` confere a ordem.

## Identidade e crescimento

O crescimento tem que refletir o papel do personagem, e não ser igual para todos. Hoje:

- **Shumi** (Físico, ofensiva): o ATQ é o que mais cresce; HP alto para aguentar o dreno do Kaioken; quase não ganha VEL, porque o Kaioken já acelera.
- **Andri** (Fogo, suporte): ATQ cresce menos; ganha VEL e DEF para agir cedo e sobreviver para entregar os artefatos.
- **Àskara** (Trevas, invocadora, de Nariagari): frágil, com HP e DEF baixos; as invocações copiam uma fração dos atributos dela na hora em que são chamadas, então o crescimento dela é também o delas. Não usa energia: a ult é paga em Fragmentos d'Alma (ver [Combate](combate.md#invocações)).
- **Clairin** (Fogo, área, de Tales of Azeroth): o ATQ é o que mais cresce, e a Chama Frenética soma até +80% em cima. HP e DEF ficam perto dos do Andri: com menos, ele caía antes de a barra render (a simulação mostrou isso com 950 de HP e 40 de DEF). A barra é um recurso de kit mostrado pela HUD com `kit_bar()` (ver [Combate](combate.md#recursos)).

As skills 2 seguem o papel de cada um: a Shumi ataca junto com a equipe, mais forte a cada nível do Kaioken (Bang!, com o visual Kokoro em cada Finger Beam), o Andri usa o MOMC para proteger ou bater (Protocolo MOMC), a Àskara tem uma passiva, o Último Ato dos demônios, e o Clairin descarrega a Chama Frenética antes de ela estourar (Descarga). Na ult do Clairin (Lorde da Chama Frenética), a ação troca para uma segunda folha, com a cabeça em chamas, como o visual Kokoro da Shumi.

## Liberação temporária

Por enquanto, `Roster.all_unlocked` é `true`: todos começam liberados, inclusive quem tem `"starts_unlocked": false`. O cadastro e os eventos de história continuam como estão, para a chegada pela história voltar a valer ao desligar a chave. Os testes desligam a chave para testar a história; `test_tower.gd` confere também o modo ligado.

Mexer em crescimento muda o equilíbrio de todos os andares: rode a simulação antes e depois (ver [Testes e ferramentas](../desenvolvimento/testes-e-ferramentas.md#simulação-dos-andares)).

## Caoimhe

A Caoimhe é quem o jogador conduz no saguão. Ela não luta e não está no `Roster`; os dados dela ficam em `Lobby.CAOIMHE`, no mesmo formato.

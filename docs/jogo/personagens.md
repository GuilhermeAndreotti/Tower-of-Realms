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
| Começa bloqueado?           | `Elenco.dados().inicial = false`             | sem a chave, já começa liberado                          |
| Lugar no saguão             | `Lobby.LUGARES` (opcional)                   | sem lugar, ele usa um dos `LUGARES_LIVRES`               |

## Adicionar um personagem

1. Crie a classe de regras em `scripts/personagens/` (`extends Combatente`), com os atributos de nível 1 no `_init`, e implemente `habilidades()`, `efeitos()`, `pode_usar()` e o que o kit precisar.
2. Crie a classe de animações (`extends AcoesPersonagem`) e implemente `executar()`.
3. Ponha o id em `Elenco.IDS` e os dados em `Elenco.dados()`, incluindo o `crescimento`.
4. Se ele chega pela história, use `"inicial": false` e libere com um evento `desbloquear` (ver [Torre e andares](torre-e-andares.md#eventos-de-história)).
5. Rode os testes; `teste_combate.gd` confere que todo personagem está cadastrado completo.

## Identidade e crescimento

O crescimento tem que refletir o papel do personagem, e não ser igual para todos. Hoje:

- **Shumi** (Físico, ofensiva): o ATQ é o que mais cresce; HP alto para aguentar o dreno do Kaioken; quase não ganha VEL, porque o Kaioken já acelera.
- **Andri** (Fogo, suporte): ATQ cresce menos; ganha VEL e DEF para agir cedo e sobreviver para entregar os artefatos.

Mexer em crescimento muda o equilíbrio de todos os andares: rode a simulação antes e depois (ver [Testes e ferramentas](../desenvolvimento/testes-e-ferramentas.md#simulação-dos-andares)).

## Caoimhe

A Caoimhe é quem o jogador conduz no saguão. Ela não luta e não está no `Elenco`; os dados dela ficam em `Lobby.CAOIMHE`, no mesmo formato.

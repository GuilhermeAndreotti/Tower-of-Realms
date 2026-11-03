# 🌙 Lia Moonlight, a Escolhida de Elune

*Universo: Tales of Azeroth* · Tipo: **Luz** · [← voltar ao README](../../README.md#-personagens)

A Lia é a curandeira da equipe: cura um aliado de cada vez ou todos de uma vez, e com o **Lord Azeroth** ergue o escudo sobre o grupo antes de um golpe forte. Luta pouco, com a espada, e se mantém de pé curando os outros, pela **Bênção Lunar**. A decisão de cada turno é curar agora ou gerar pontos para curar mais tarde.

<!-- gerado: tools/generate_character_readmes.gd -->
## Atributos

| | HP | ATQ | DEF | VEL | Energia |
|---|---|---|---|---|---|
| Nível 1 | 1100 | 110 | 60 | 100 | 120 |
| Por nível | +55 | +5 | +3 | +0,5 | — |

## Habilidades

> Texto igual ao do jogo, como aparece na montagem da equipe (nível 1, fora de qualquer forma).

### <img src="icon_blade.png" width="24"> Espadito
**Básico (Q)** · `gera 1 ponto` · `Alvo único` · `Luz`

O Espadito, a espada viva dela, voa até o alvo, golpeia (0,8x) e volta. Gera 1 ponto de skill.

### <img src="icon_heal.png" width="24"> Curar Ferimentos
**Skill (E)** · `1 ponto` · `Aliado ou em si`

Cura 20% do HP máximo de um aliado (ou invocação).

### <img src="icon_nova.png" width="24"> Nova Sagrada
**Skill 2 (W)** · `1 ponto` · `recarga 3 turnos` · `Todos os inimigos` · `Luz`

Uma explosão de luz sagrada cura a equipe e fere os inimigos.

- **Aliados**: Cura 8% do HP máximo de cada um em campo, invocações incluídas.
- **Inimigos**: Dano de Luz em todos (0,4x).

### <img src="icon_lord_azeroth.png" width="24"> Lord Azeroth
**Ultimate (R)** · `120 energia` · `Em si`

Ergue o escudo sobre todos os aliados em campo, invocações incluídas: o próximo golpe que cada um receber perde 80% do dano. A proteção acaba nesse golpe ou depois de 3 turnos de quem a tem; usar de novo renova, não soma.

### <img src="icon_lunar_blessing.png" width="24"> Bênção Lunar
**Passiva**

Quando ela cura outro aliado, recupera 20% do que curou. Curar a si mesma não conta.

<!-- fim do trecho gerado -->

## Mais detalhes

- **Espadito:** a espada viva dela. No básico, ele sai da mão da Lia, voa até o alvo, corta duas vezes e volta.
- **Curar Ferimentos:** o E abre a escolha do aliado (começa nela mesma). ←/→ ou um clique escolhem quem curar; Enter, ou o E de novo, confirma; Esc cancela.
- **Curas:** valem uma fração do HP máximo de quem recebe, então curam o mesmo tanto no mais resistente e na mais frágil. Não levantam quem caiu.
- **Bênção Lunar:** a parte que volta para ela é do que curou de fato (o que passaria do HP máximo não conta). Na Nova Sagrada, soma o que curou em todos os outros.
- **Lord Azeroth:** a proteção acaba no primeiro golpe que cada aliado recebe, mesmo que fraco, ou depois de 3 turnos dele. Vale também para as invocações da Àskara.

**Dica:** guarde o Lord Azeroth para quando um inimigo avisar o Golpe Pesado (o **!**) ou o laser do Golem Incandescente: o golpe que toda a equipe vai receber perde 80%.

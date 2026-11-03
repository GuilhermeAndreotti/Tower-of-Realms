# 🔴 Shumi, espadachim do Kaioken

*Universo: Dragon Ball New Age* · Tipo: **Físico** · [← voltar ao README](../../README.md#-personagens)

A Shumi é uma personagem de **risco e recompensa**. O Kaioken aumenta o poder dela a cada nível, mas também consome o próprio corpo. Quanto mais ela sobe, mais forte fica o Engo-ji Beam e mais perto ela chega do limite.

<!-- gerado: tools/generate_character_readmes.gd -->
## Atributos

| | HP | ATQ | DEF | VEL | Energia |
|---|---|---|---|---|---|
| Nível 1 | 1200 | 150 | 50 | 105 | 120 |
| Por nível | +60 | +8 | +2 | +0,5 | — |

## Habilidades

> Texto igual ao do jogo, como aparece na montagem da equipe (nível 1, fora de qualquer forma).

### <img src="basic-attack-melee.png" width="24"> Corte
**Básico (Q)** · `gera 1 ponto` · `Alvo único` · `Físico`

Corte de katana no alvo. Gera 1 ponto de skill e 20 de energia.

### <img src="engo-ji-beam-icon.png" width="24"> Engo-ji Beam
**Skill (E)** · `1 ponto` · `Alvo único` · `Físico`

Feixe de energia que cresce com o Kaioken: cada nível aumenta o alcance.

- **Base** · *Engo-ji Beam*: Feixe concentrado no alvo.
- **x2** · *Engo-ji Beam Amplificado*: Feixe mais forte: acerta o alvo e o inimigo logo atrás.
- **x4** · *Engo-ji Beam: Ruptura*: Feixe roxo e vermelho: alvo + vizinhos (dano menor nos vizinhos).
- **x10** · *Engo-ji Beam: Devastação*: O feixe atravessa todos os inimigos.
- **x20** · *Engo-ji Beam: Colapso*: Colapso: energia extrema contra todos os inimigos.

### <img src="icon_bang.png" width="24"> Bang!
**Skill 2 (W)** · `1 ponto` · `recarga 4 turnos` · `Alvo único` · `Físico`

Dispara uma rajada de energia de seus dedos em um alvo e, pelos 2 turnos seguintes dela, ataca junto com a equipe.

- **Ataca junto**: Quando um aliado ou invocação acerta um inimigo, ela dispara um Finger Beam nele (uma vez por ação) e ganha 4 de energia.
- **Dano do Finger Beam**: Base 0,4x · x2 0,5x · x4 0,65x · x10 0,85x · x20 1,1x

### <img src="kaiokenn-shumi.png" width="24"> Kaioken
**Ultimate (R)** · `120 energia` · `não gasta o turno` · `Em si`

Entra no x2. Cada nível dura 3 turnos dela (subir renova); quando acaba, ela fica exausta, e depois do x20 perde um turno.

- **Kaioken x2** · *próximo*: ATQ +20% • VEL +20% • queima 3% do HP por turno
- **Kaioken x4**: ATQ +40% • VEL +35% • queima 5% do HP por turno
- **Kaioken x10**: ATQ +80% • VEL +55% • queima 8% do HP por turno
- **Kaioken x20**: ATQ +150% • VEL +80% • queima 12% do HP por turno

### <img src="icon_human_limit.png" width="24"> Limite Humano
**Passiva**

Se sobrevive ao dreno do Kaioken no começo do turno, recupera energia.

- **Energia por nível**: x2 +15 · x4 +20 · x10 +25 · x20 +30

<!-- fim do trecho gerado -->

## Mais detalhes

- **Kaioken:** entrar custa 120 de energia, e subir um nível custa 80. O dreno tira HP direto e ignora defesa e escudo. Quando o Kaioken acaba, ela fica **Exausta** por 2 turnos, com a VEL reduzida conforme o nível em que estava: −10% (x2), −20% (x4), −30% (x10) ou −40% (x20). Depois do x20, ela também **perde o próximo turno**.
- **Engo-ji Beam:** no x2 e no x4, os alvos extras levam metade do dano (0,9×). No x10 e no x20 o feixe acerta todos com o dano cheio.
- **Bang!:** o Finger Beam é uma rajada de ki disparada do dedo. A recarga é um turno maior que o efeito, então sempre sobra um turno sem ele antes de poder usar de novo. Sozinha na luta, o Bang! é só o primeiro tiro. Cada Finger Beam sai no visual **Kokoro**, que volta ao normal depois do tiro.
- **Corte:** a animação fica mais rápida e intensa conforme o nível do Kaioken.

**Dica:** suba até o x10 para limpar a tela com a Devastação. O x20 causa um dano enorme, mas a Shumi perde um turno quando ele acaba, e os inimigos aproveitam.

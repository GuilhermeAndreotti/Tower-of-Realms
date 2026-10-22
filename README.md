# 🗼 Tower of Realms

> Heróis de mundos diferentes sobem uma torre e enfrentam os guardiões de cada andar.

**Tower of Realms** é um RPG de combate por turnos em pixel art feito em **Godot 4.7**. A fila de turnos depende da velocidade de cada lutador, no estilo de *Honkai: Star Rail*, e a efetividade dos golpes depende do elemento, como em *Pokémon*. A equipe pode ter até três personagens, e cada um vem de um universo diferente e tem mecânicas próprias.

![Shumi disparando o Engo-ji Beam](docs/capturas/engo-ji-beam.png)

> ⚠️ **Protótipo.** Por enquanto existe um andar jogável e dois personagens. Os inimigos, o cenário e alguns efeitos usam arte provisória.

---

## Sumário

- [Como jogar](#-como-jogar)
- [Sistema de combate](#️-sistema-de-combate)
- [Personagens](#-personagens)
  - [Shumi, espadachim do Kaioken](#-shumi--espadachim-do-kaioken)
  - [Andri Findavil, inventor e artífice](#-andri-findavil--inventor-e-artífice)
- [Inimigos](#-inimigos)
- [Rodando o projeto](#-rodando-o-projeto)
- [Estrutura do projeto](#-estrutura-do-projeto)
- [Adicionando um personagem](#-adicionando-um-personagem)

---

## 🎮 Como jogar

1. Na **seleção de equipe**, escolha até 3 heróis.
2. Na batalha, quando chega a vez de um aliado, escolha a ação:

| Tecla | Ação |
|---|---|
| **Q** | Ataque básico |
| **E** | Habilidade (skill) |
| **R** | Ultimate |
| **← / →** ou clique | Troca o alvo |
| **↑ / ↓** ou **1–9** | Escolhe uma opção nos seletores (elemento, artefato...) |
| **Enter** | Confirma |
| **Esc** | Cancela / volta ao seletor no fim da batalha |

Passe o mouse sobre uma habilidade para ver quais alvos ela vai acertar antes de usar.

**Objetivo:** derrotar todos os guardiões do andar antes que a equipe caia.

---

## ⚔️ Sistema de combate

### Fila de turnos por velocidade
Cada lutador tem um *action value* (AV), que é quanto falta para ele agir. Quem tem o menor AV age primeiro. Depois de agir, ele volta para o fim da fila, a uma distância proporcional a `10000 / VEL`. Por isso, quem tem mais **VEL** age mais vezes. A ordem das próximas 7 ações aparece no canto da tela.

### Recursos
- **Pontos de skill** são compartilhados pela equipe. O time começa com 3 e o máximo é 5. O ataque básico **gera** 1 ponto, e a skill **gasta** 1. Revezar entre básicos e skills faz parte da estratégia.
- **Energia** é individual. Ela enche ao atacar e ao receber golpes e paga a ultimate.

### Dano
```
dano = ATQ × multiplicador × efetividade × 100 / (100 + DEF)   (±5% de variação)
```
O crítico multiplica o dano por **1,5×**. Escudos absorvem o dano antes do HP.

### Elementos
Cada lutador tem **um** tipo. Um golpe pode ser **super efetivo (2×)**, **pouco efetivo (0,5×)** ou neutro.

| Ataque | Super efetivo contra | Pouco efetivo contra |
|---|---|---|
| Físico | Arcano | Natureza |
| 🔥 Fogo | Gelo | Água |
| 💧 Água | Fogo | Eletricidade |
| ❄️ Gelo | Natureza | Fogo |
| ⚡ Eletricidade | Água | Natureza |
| 🌿 Natureza | Eletricidade | Fogo |
| ☠️ Veneno | Natureza | Ácido |
| 🧪 Ácido | Físico | Água |
| ☀️ Luz | Trevas | — |
| 🌑 Trevas | Luz | — |

**Arcano** tem regra própria: um alvo Arcano recebe 2× de *qualquer* tipo, e um ataque Arcano causa 2× em tudo, menos em Físico (0,5×).

### Estados
Buffs e debuffs (escudo, fraqueza, lentidão etc.) aparecem como ícones com a contagem de turnos acima de cada lutador.

---

## 👥 Personagens

### 🔴 Shumi, espadachim do Kaioken
*Universo: Dragon Ball New Age* · Tipo: **Físico**

| HP | ATQ | DEF | VEL | Energia |
|---|---|---|---|---|
| 1200 | 150 | 50 | 105 | 120 |

A Shumi é uma personagem de **risco e recompensa**. O Kaioken aumenta o poder dela a cada nível, mas também consome o próprio corpo. Quanto mais ela sobe, mais forte fica o Engo-ji Beam e mais perto ela chega do limite.

<img src="personagens/shumi/basic-attack-melee.png" width="32"> **Corte** · Básico (Q)
> Corte de katana em um alvo, com 1,0× ATQ. Gera **1 ponto de skill** e 20 de energia. A animação fica mais rápida e intensa conforme o nível do Kaioken.

<img src="personagens/shumi/engo-ji-beam-icon.png" width="32"> **Engo-ji Beam** · Skill (E) · custa 1 ponto
> Um feixe de energia que **muda conforme o Kaioken**:

| Nível | Nome | Alcance | Dano |
|---|---|---|---|
| Normal | Engo-ji Beam | Só o alvo | 1,8× |
| x2 | Engo-ji Beam Amplificado | Alvo + o inimigo logo atrás | 1,8× / 0,9× |
| x4 | Engo-ji Beam: Ruptura | Alvo + vizinhos | 1,8× / 0,9× |
| x10 | Engo-ji Beam: Devastação | Atravessa todos | 1,8× em todos |
| x20 | **Engo-ji Beam: Colapso** | Todos | **2,2×** em todos |

<img src="personagens/shumi/kaiokenn-shumi.png" width="32"> **Kaioken** · Ultimate (R)
> Entra no Kaioken x2 (120 de energia) ou sobe um nível (80 de energia). Usar o Kaioken **não gasta o turno**. Cada nível dura 3 turnos dela, e subir de nível renova a duração.

| Nível | ATQ | VEL | Dreno de HP / turno | Energia do Limite Humano | Exaustão ao acabar |
|---|---|---|---|---|---|
| x2 | +20% | +20% | 3% | +15 | VEL −10% |
| x4 | +40% | +35% | 5% | +20 | VEL −20% |
| x10 | +80% | +55% | 8% | +25 | VEL −30% |
| x20 | +150% | +80% | 12% | +30 | VEL −40% **e perde o próximo turno** |

O dreno tira HP direto e ignora defesa e escudo. Quando o Kaioken acaba, ela fica **Exausta** por 2 turnos.

🛡️ **Limite Humano** · Passiva
> Se a Shumi sobrevive ao dreno do Kaioken no início do turno, ela recupera energia. Quanto mais alto o nível, mais energia ela ganha. Isso permite subir de nível em sequência... enquanto o HP aguentar.

**Dica:** suba até o x10 para limpar a tela com a Devastação. O x20 causa um dano enorme, mas a Shumi perde um turno quando ele acaba, e os inimigos aproveitam.

---

### 🟡 Andri Findavil, inventor e artífice
*Universo: Tales of Azeroth* · Tipo: **Fogo**

| HP | ATQ | DEF | VEL | Energia |
|---|---|---|---|---|
| 1000 | 130 | 45 | 112 | 120 |

O Andri é o **suporte tático** da equipe. Ele troca de elemento a cada turno, cria fraquezas nos inimigos e distribui artefatos titânicos para os aliados. Ele luta ao lado do **MOMC**, seu robô assistente.

<img src="personagens/andri/icone_lente.png" width="32"> **Lente Elemental** · Passiva
> No início de cada turno do Andri, um **seletor radial** se abre em volta dele para escolher o elemento da lente (ou manter o atual). Esse elemento define o dano do Disparo, do MOMC e dos artefatos de dano.
> Elementos disponíveis: 🔥 Fogo · 💧 Água · ❄️ Gelo · ⚡ Eletricidade · 🌿 Natureza · ☠️ Veneno · 🧪 Ácido.

<img src="personagens/andri/icone_disparo.png" width="32"> **Disparo Elemental** · Básico (Q)
> Disparo de 0,8× ATQ com o elemento da lente. O **MOMC ataca junto** o mesmo alvo com um golpe separado de 0,35×. Gera **1 ponto de skill** e 20 de energia.

<img src="personagens/andri/icone_analise.png" width="32"> **Análise de Vulnerabilidade** · Skill (E) · custa 1 ponto
> O inimigo fica **fraco** ao elemento de um aliado de pé, à escolha. Golpes desse elemento passam a ser super efetivos (2×) nele por 2 turnos. Não funciona em alvos Arcanos, que já recebem 2× de tudo.

![Análise de Vulnerabilidade](docs/capturas/analise-vulnerabilidade.png)

<img src="personagens/andri/icone_arsenal.png" width="32"> **Arsenal Titânico** · Ultimate (R) · 120 de energia
> Entrega **um artefato** a um aliado ou a si mesmo. Os efeitos duram 3 turnos do portador, exceto quando a descrição diz outra coisa.

| | Artefato | Efeito |
|---|---|---|
| <img src="personagens/andri/icone_odyn.png" width="24"> | **Olho de Odyn** | +50% de chance de crítico |
| <img src="personagens/andri/icone_tyr.png" width="24"> | **Mão de Tyr** | Escudo de 25% do HP máximo |
| <img src="personagens/andri/icone_loken.png" width="24"> | **Sussurro de Loken** | Por 2 turnos, quem o portador acerta fica *Enganado* (ATQ −25% e a vez atrasa) |
| <img src="personagens/andri/icone_freya.png" width="24"> | **Raiz de Freya** | Cura 30% do HP máximo e remove os efeitos negativos |
| <img src="personagens/andri/icone_hodir.png" width="24"> | **Manto de Hodir** | O próximo inimigo atingido fica *Lento* (VEL −30% por 2 turnos) |
| <img src="personagens/andri/icone_thorim.png" width="24"> | **Braço de Thorim** | Cada golpe causa +30% de dano extra do elemento da lente |
| <img src="personagens/andri/icone_archaedas.png" width="24"> | **Cinturão de Archaedas** | HP máximo +30% |
| <img src="personagens/andri/icone_ra.png" width="24"> | **Lança de Rá** | O próximo golpe causa +150% de dano extra do elemento da lente |

![Arsenal Titânico](docs/capturas/arsenal-titanico.png)

**Dica:** use a Análise com o elemento físico da Shumi e depois o Engo-ji em Devastação. Também funciona dar a Lança de Rá para ela antes de um Colapso.

---

## 👾 Inimigos

| Inimigo | HP | ATQ | DEF | VEL | Comportamento |
|---|---|---|---|---|---|
| **Sentinela** | 550 | 60 | 40 | 95 / 112 | Investida em um aliado aleatório |
| **Guardião** | 1400 | 85 | 60 | 80 | A cada 3 ações solta um **Golpe Pesado** (1,8×). O ícone **!** avisa quando ele vai vir |

---

## 🚀 Rodando o projeto

**Requisitos:** [Godot 4.7](https://godotengine.org/download) (renderizador *Compatibility*).

```bash
git clone https://github.com/GuilhermeAndreotti/Tower-of-Realms.git
cd Tower-of-Realms
godot --path .          # abre o jogo (ou importe o project.godot no editor)
```

### Testes
A lógica de combate tem testes que rodam sem interface:
```bash
godot --headless --path . -s testes/teste_combate.gd
```

### Ferramentas
| Script | O que faz |
|---|---|
| `ferramentas/demo_captura.gd` | Joga uma batalha sozinho e salva capturas de tela: `godot --path . -s ferramentas/demo_captura.gd -- <pasta> shumi andri` |
| `ferramentas/gerar_andri.py` | Gera a spritesheet, o MOMC e os ícones do Andri a partir do sprite original (precisa do Pillow) |
| `ferramentas/gerar_assets_teste.py` | Gera a arte provisória (inimigos, cenário, onda do Engo-ji) |

---

## 📁 Estrutura do projeto

```
scenes/              cenas: seleção de equipe e batalha
scripts/
  combate/           regras: combatente, fila de turnos, tipos, estados, inimigos, batalha
  personagens/       elenco + kit de cada herói (regras e animações separadas)
  ui/                HUD, barras, slots de habilidade, seletor radial, efeitos visuais
personagens/         sprites, spritesheets e ícones de cada herói
inimigos/ cenarios/ efeitos/   arte dos inimigos, do cenário e dos efeitos
testes/              testes headless da lógica
ferramentas/         scripts de captura e geração de assets
```

As **regras** (`Combatente`) ficam separadas das **animações** (`AcoesPersonagem`) e da **interface** (`HudBatalha`). Por isso a lógica pode ser testada sem abrir o jogo.

---

## ➕ Adicionando um personagem

1. Crie a classe de regras em `scripts/personagens/` (`extends Combatente`) e implemente `habilidades()` e `efeitos()`.
2. Crie a classe de animações (`extends AcoesPersonagem`).
3. Adicione o id em `Elenco.IDS` e os dados (nome, universo, sprite) em `Elenco.dados()`.

A batalha e a HUD se adaptam sozinhas ao novo kit.

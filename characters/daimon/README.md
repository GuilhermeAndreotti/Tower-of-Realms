# ❄️ Daimon, usuário da Stand Cold

*Universo: Deep Bizarre Adventures Part 3* · Tipo: **Gelo** · [← voltar ao README](../../README.md#-personagens)

O Daimon é o **dano em alvo único** da equipe. A Stand dele, a **Cold**, é um rifle de precisão: cada tiro deixa **Geada** no alvo, que enfraquece a defesa dele contra o Daimon, e com 3 Geadas a Cold garante o crítico por 2 turnos. O ritmo dele é preparar e depois atirar: juntar Geada, abrir a janela e gastar nela os tiros mais fortes.

<!-- gerado: tools/generate_character_readmes.gd -->
## Atributos

| | HP | ATQ | DEF | VEL | Energia |
|---|---|---|---|---|---|
| Nível 1 | 1000 | 140 | 42 | 110 | 120 |
| Por nível | +50 | +7 | +2 | +1 | — |

## Habilidades

> Texto igual ao do jogo, como aparece na montagem da equipe (nível 1, fora de qualquer forma).

### <img src="icon_shot.png" width="24"> Disparo
**Básico (Q)** · `gera 1 ponto` · `Alvo único` · `Gelo`

Tiro da Cold no alvo (0,9x). Deixa 1 Geada e gera 1 ponto de skill.

### <img src="icon_bullet.png" width="24"> Bala Congelante
**Skill (E)** · `1 ponto` · `Alvo único` · `Gelo`

Bala de gelo concentrado no alvo (1,4x). Deixa 2 Geadas.

### <img src="icon_aim.png" width="24"> Mira Fria
**Skill 2 (W)** · `1 ponto` · `recarga 4 turnos` · `Alvo único` · `Gelo`

Ele trava a mira no alvo e segura o tiro por até 3 turnos. A cada turno segurando, o tiro fica mais forte e deixa 1 Geada no alvo.

- **Nível 1** · *1,8x*: Soltar no turno seguinte ao de travar.
- **Nível 2** · *2,8x*: Segurou mais 1 turno.
- **Nível 3** · *4,2x*: O máximo: só resta disparar.
- **Golpe Pesado**: Se ele levar um mirando, a mira cai 1 nível.
- **Q, E ou R**: Baixam a mira sem atirar.

### <img src="icon_zero.png" width="24"> Zero Absoluto
**Ultimate (R)** · `120 energia` · `Alvo único` · `Gelo`

A Cold dispara o tiro decisivo no alvo (2,5x), mais forte com Geada.

- **Por Geada no alvo** · *+0,2x*
- **Com 3 Geadas** · *3,1x*

### <img src="icon_cold.png" width="24"> Holy Grail Powered Cold
**Passiva**

Os tiros dele deixam Geada no alvo (até 3). Cada Geada tira 15% da DEF do alvo contra os ataques dele. Com 3, o alvo fica Lento e o Daimon ganha crítico garantido por 2 turnos dele; enquanto isso, os tiros não deixam Geada.

- **Disparo** · *+1*
- **Bala Congelante** · *+2*
- **Mira Fria** · *+1 por turno mirando*
- **Lento**: VEL -30% por 2 turnos do alvo.
- **Gelo que não cede**: Em alvo com Geada, os tiros dele nunca são pouco efetivos.

<!-- fim do trecho gerado -->

## Mais detalhes

- **Geada:** fica em cada inimigo, aparece na barra dele (G1, G2, G3) e não acaba sozinha, então dá para deixar um alvo com 2 e terminar depois. Só os ataques do Daimon aproveitam a DEF reduzida.
- **Crítico garantido:** vale para qualquer alvo, não só o que encheu a Geada, e conta os 2 turnos seguintes ao do tiro que abriu a janela. Enquanto ela dura, os tiros não deixam Geada; quando acaba, a Geada máxima zera. Enquanto a janela dura, o inimigo que encheu a Geada leva a marca da Cold (o Santo Graal com um anel gelado) sobre a cabeça.
- **Mira Fria:** no turno em que trava, ele não atira. Nos turnos seguintes, o seletor abre sozinho com **Segurar** e **Disparar**; Q, E ou R baixam a mira. Se o alvo cair antes, a mira passa para o inimigo marcado, com o mesmo nível. Um Golpe Pesado (ou o laser do Golem) que tire HP dele derruba a mira um nível; um escudo que absorva o golpe inteiro protege a mira. A recarga conta a partir do último uso do W.
- **Segurar até o máximo:** travar e segurar duas vezes deixa 3 Geadas no alvo, então a janela da Cold abre bem na hora de soltar o tiro de nível 3, e ainda sobra um turno de crítico.
- **Zero Absoluto:** a Geada conta na hora do tiro; dentro da janela, ele também é crítico.

**Dica:** a Análise do Andri pode deixar o alvo fraco a Gelo, e um Zero Absoluto com 3 Geadas dentro da janela é o maior golpe único da equipe. Enquanto ele segura a mira, um escudo do Andri (Escudo do Protocolo ou Mão de Tyr) protege o tiro de um Golpe Pesado.

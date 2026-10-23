# Testes e ferramentas

Tudo roda headless com o executável do Godot 4.7 (abaixo, `godot`). Antes de rodar pela primeira vez, ou depois de criar arquivos novos, importe o projeto:

```bash
godot --headless --path . --import
```

## Testes

Cada arquivo é um `SceneTree` que roda, imprime `ok` ou `FALHOU` por verificação e sai com código 1 se algo falhou.

| Arquivo                     | Cobre                                                                                   |
| --------------------------- | --------------------------------------------------------------------------------------- |
| `testes/teste_combate.gd`   | fila, dano, tipos, estados, kits da Shumi e do Andri, descrição para a HUD, equipe     |
| `testes/teste_progressao.gd`| curva, limite da Torre, atributos por nível, desbloqueio, save, recompensa na batalha real |
| `testes/teste_torre.gd`     | andares, ritmo de XP, liberação, eventos, telas de andar e equipe, apresentação no saguão |
| `testes/teste_lobby.gd`     | saguão montado de verdade: colisão, caminhos, foco, diálogo, porta                      |

```bash
godot --headless --path . -s testes/teste_combate.gd
godot --headless --path . -s testes/teste_progressao.gd
godot --headless --path . -s testes/teste_torre.gd
godot --headless --path . -s testes/teste_lobby.gd
```

Regras para testes:

- Troque `Progressao.arquivo` para um arquivo próprio no começo e chame `Progressao.apagar()` no fim. Nunca leia nem escreva o save do jogador.
- Fixe sorteios por parâmetro (as regras recebem variação e crítico de fora) em vez de depender de `randf()`.
- Testes que montam cenas usam `_initialize()` e `await`; os de regra pura podem rodar direto no `_init()`.
- O aviso de objetos vazados ao sair do `teste_lobby.gd` vem da troca de cena no fim e não indica falha.

## Simulação dos andares

`ferramentas/simular_andares.gd` roda a batalha de verdade com um piloto automático e imprime, por andar e nível, vitórias, turnos dos aliados e HP restante.

```bash
godot --headless --path . -s ferramentas/simular_andares.gd -- [rodadas] [andar:nível ...]
```

Sem cenários, roda cada andar um nível abaixo do recomendado, no recomendado e no limite. Usa save próprio e acelera o tempo. O piloto é simples (descrito no topo do arquivo): use os números para comparar, não como prova de que um andar é divertido. Rode antes e depois de qualquer mudança de equilíbrio e registre os números no commit ou no changelog.

## Outras ferramentas

| Ferramenta                        | Uso                                                                              |
| --------------------------------- | -------------------------------------------------------------------------------- |
| `ferramentas/demo_captura.gd`     | joga uma batalha sozinho e salva capturas (precisa de janela, não roda headless) |
| `ferramentas/gerar_lobby.py`      | gera o fundo, os móveis e a porta do saguão                                       |
| `ferramentas/gerar_andri.py`      | gera a spritesheet, o MOMC e os ícones do Andri                                   |
| `ferramentas/gerar_caoimhe.py`    | gera a spritesheet da Caoimhe a partir do sprite parado                          |
| `ferramentas/gerar_logo.py`       | gera a logo do jogo (`logo.png`), usada no README                                 |
| `ferramentas/gerar_assets_teste.py` | gera a arte provisória (inimigos, cenário, onda do Engo-ji)                    |

Os geradores usam Python 3 com Pillow e rodam a partir da pasta do projeto (`python3 ferramentas/<nome>.py`). Arte gerada é editada no gerador, não no PNG: senão a próxima geração apaga a mudança.

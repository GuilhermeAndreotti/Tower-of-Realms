# Testes e ferramentas

Tudo roda headless com o executável do Godot 4.7 (abaixo, `godot`). Antes de rodar pela primeira vez, ou depois de criar arquivos novos, importe o projeto:

```bash
godot --headless --path . --import
```

## Testes

Cada arquivo é um `SceneTree` que roda, imprime `ok` ou `FALHOU` por verificação e sai com código 1 se algo falhou.

| Arquivo                     | Cobre                                                                                   |
| --------------------------- | --------------------------------------------------------------------------------------- |
| `tests/test_combat.gd`   | fila, dano, tipos, estados, kits da Shumi, do Andri e da Àskara (com as skills 2, a recarga e o ataque em conjunto), invocações e últimos atos (também numa batalha de verdade), último recurso dos inimigos e escudo na barra de HP (Ferro Negro no andar 5), descrição para a HUD, equipe, READMEs dos personagens em dia |
| `tests/test_progression.gd`| curva, limite da Torre, atributos por nível, desbloqueio, save, recompensa na batalha real |
| `tests/test_tower.gd`     | andares, ritmo de XP, liberação, eventos, telas de andar e equipe, apresentação no saguão |
| `tests/test_lobby.gd`     | saguão montado de verdade: colisão, caminhos, foco, diálogo, porta                      |
| `tests/test_menu.gd`      | slots de save e menu inicial: criar, sobrescrever, carregar, apagar, resumo do slot     |

```bash
godot --headless --path . -s tests/test_combat.gd
godot --headless --path . -s tests/test_progression.gd
godot --headless --path . -s tests/test_tower.gd
godot --headless --path . -s tests/test_lobby.gd
godot --headless --path . -s tests/test_menu.gd
```

Regras para testes:

- Troque `Progression.file` para um arquivo próprio no começo e chame `Progression.delete()` no fim. Quem mexe em slots troca também `Progression.slots_prefix` e apaga os slots no fim. Nunca leia nem escreva os saves do jogador.
- Fixe sorteios por parâmetro (as regras recebem variação e crítico de fora) em vez de depender de `randf()`.
- Testes que montam cenas usam `_initialize()` e `await`; os de regra pura podem rodar direto no `_init()`.
- O aviso de objetos vazados ao sair do `test_lobby.gd` vem da troca de cena no fim e não indica falha.

## Simulação dos andares

`tools/simulate_floors.gd` roda a batalha de verdade com um piloto automático e imprime, por andar e nível, vitórias, turnos dos aliados e HP restante.

```bash
godot --headless --path . -s tools/simulate_floors.gd -- [rodadas] [andar:nível ...] [team=id,id]
```

Sem cenários, roda cada andar um nível abaixo do recomendado, no recomendado e no limite. Sem `team=`, usa os primeiros liberados do Roster que cabem no andar (hoje, Shumi e Andri); para medir outro personagem, passe a equipe (por exemplo `team=askara,shumi`). Usa save próprio e acelera o tempo. O piloto é simples (descrito no topo do arquivo): use os números para comparar, não como prova de que um andar é divertido. Rode antes e depois de qualquer mudança de equilíbrio e registre os números no commit ou no changelog.

## Outras ferramentas

| Ferramenta                        | Uso                                                                              |
| --------------------------------- | -------------------------------------------------------------------------------- |
| `tools/capture_demo.gd`     | joga uma batalha sozinho e salva capturas (precisa de janela, não roda headless) |
| `tools/generate_character_readmes.gd` | reescreve o trecho gerado do `characters/<id>/README.md` (atributos e habilidades com o texto do jogo, via `skills()` e `SkillCard.tags()`); o resto do arquivo é escrito à mão. O `test_combat.gd` falha se algum README ficar desatualizado |
| `tools/generate_lobby.py`      | gera o fundo, os móveis e a porta do saguão                                       |
| `tools/generate_andri.py`      | gera a spritesheet, o MOMC e os ícones do Andri                                   |
| `tools/generate_caoimhe.py`    | gera a spritesheet da Caoimhe a partir do sprite parado                          |
| `tools/pixel_icon.py`      | padrão dos ícones de habilidade (15x15, desenho 11x11 centrado, sem moldura), usado pelos geradores |
| `tools/generate_askara.py`     | gera a spritesheet e os ícones da Àskara e reduz as invocações (originais em `characters/askara/originals/`) |
| `tools/generate_logo.py`       | gera a logo do jogo (`logo.png`), usada no menu inicial e no README               |
| `tools/generate_placeholder_art.py` | gera a arte provisória (inimigos, inclusive o Golem de Pedra e o Elemental de Fogo, cenário, onda do Engo-ji) e os ícones da passiva e do Bang! da Shumi |
| `../Shumi/gerar_spritesheet.py`   | fora do projeto: gera a spritesheet da Shumi a partir de `Shumi.png` e, com `kokoro.png shumi_kokoro`, a do visual Kokoro (usado no Bang!); copie o PNG e o JSON de `spritesheet/` para `characters/shumi/` |

Os geradores usam Python 3 com Pillow e rodam a partir da pasta do projeto (`python3 tools/<nome>.py`). Arte gerada é editada no gerador, não no PNG: senão a próxima geração apaga a mudança.

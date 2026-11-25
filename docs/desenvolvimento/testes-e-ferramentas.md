# Testes e ferramentas

Tudo roda headless com o executável do Godot 4.7 (abaixo, `godot`). Antes de rodar pela primeira vez, ou depois de criar arquivos novos, importe o projeto:

```bash
godot --headless --path . --import
```

## Testes

Cada arquivo é um `SceneTree` que roda, imprime `ok` ou `FALHOU` por verificação e sai com código 1 se algo falhou.

| Arquivo                     | Cobre                                                                                   |
| --------------------------- | --------------------------------------------------------------------------------------- |
| `tests/test_combat.gd`      | fila, dano, tipos, estados, componentes do lutador (`Health`, `StatusEffects`, `Cooldowns`, `FighterBar`), fases da batalha (`Battle.Phase`), kits da Shumi, do Andri, da Àskara, do Clairin, da Lia e do Daimon (com as skills 2, a recarga, o ataque em conjunto e a Mira Fria segurada por turnos, também numa batalha de verdade), invocações e últimos atos (também numa batalha de verdade), último recurso dos inimigos e escudo na barra de HP (Ferro Negro no andar 5), segunda forma (o Golem Incandescente: despertar, absorção e laser, também numa batalha de verdade), bônus de equipe (Por Azeroth!, também numa batalha de verdade), descrição para a HUD, equipe, READMEs dos personagens em dia |
| `tests/test_progression.gd` | curva, limite da Torre, atributos por nível, desbloqueio, save, recompensa na batalha real |
| `tests/test_tower.gd`       | andares e missões secundárias, ritmo de XP, liberação, eventos, descrições sem mecânica, mapa da Torre (clique nos círculos, ficha sem spoiler) e montagem da equipe, apresentação no saguão |
| `tests/test_lobby.gd`       | saguão montado de verdade: colisão, caminhos, foco, diálogo, porta, estados do saguão e da Caoimhe |
| `tests/test_menu.gd`        | introdução (só no jogo novo, Enter completa e passa, cenas na ordem, Esc pula para o saguão), slots de save e menu inicial: criar, sobrescrever, carregar, apagar, resumo do slot     |

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
godot --headless --path . -s tools/simulate_floors.gd -- [rodadas] [andar[/missão]:nível ...] [team=id,id] [side]
```

Sem cenários, roda cada andar um nível abaixo do recomendado, no recomendado e no limite. Com `side`, roda também cada missão secundária nesses três níveis (o limite dela é o do andar seguinte, que abre junto). Uma missão avulsa vai como `3/cisterna:6`. Sem `team=`, usa os primeiros liberados do Roster que cabem no andar (hoje, Shumi e Andri); para medir outro personagem, passe a equipe (por exemplo `team=askara,shumi`). Usa save próprio e acelera o tempo. O piloto é simples (descrito no topo do arquivo): use os números para comparar, não como prova de que um andar é divertido. Rode antes e depois de qualquer mudança de equilíbrio e registre os números no commit ou no changelog.

## Outras ferramentas

| Ferramenta                        | Uso                                                                              |
| --------------------------------- | -------------------------------------------------------------------------------- |
| `tools/capture_demo.gd`           | joga uma batalha sozinho e salva capturas (precisa de janela, não roda headless) |
| `tools/generate_character_readmes.gd` | reescreve o trecho gerado do `characters/<id>/README.md` (atributos e habilidades com o texto do jogo, via `skills()` e `SkillCard.tags()`); o resto do arquivo é escrito à mão. O `test_combat.gd` falha se algum README ficar desatualizado |
| `tools/generate_lobby.py`         | gera o fundo, os móveis e a porta do saguão                                      |
| `tools/generate_andri.py`         | gera a spritesheet, o MOMC e os ícones do Andri                                  |
| `tools/generate_caoimhe.py`       | gera a spritesheet da Caoimhe a partir do sprite parado                          |
| `tools/pixel_icon.py`             | padrão dos ícones de habilidade (15x15, desenho 11x11 centrado, sem moldura), usado pelos geradores |
| `tools/generate_askara.py`        | gera a spritesheet e os ícones da Àskara e reduz as invocações (originais em `characters/askara/originals/`) |
| `tools/generate_clairin.py`    | gera as duas spritesheets do Clairin (normal e Lorde da Chama Frenética) e os ícones, a partir de `characters/clairin/originals/` (a folha original tem um quadro deslocado; o gerador alinha pelos pés) |
| `tools/generate_logo.py`          | gera a logo do jogo (`logo.png`), usada no menu inicial e no README              |
| `tools/generate_lia.py`           | gera a spritesheet e os ícones da Lia a partir do quadro único em `characters/lia/originals/` (a espada é recortada e redesenhada erguida e deitada, para conjurar e para a estocada) |
| `tools/generate_daimon.py`        | gera a spritesheet e os ícones do Daimon a partir do sprite parado em `characters/daimon/originals/` (o rifle, a Stand Cold, é desenhado no gerador; ele imprime a ponta do cano, usada em `DaimonActions.MUZZLE`) |
| `tools/generate_tower_map.py`     | gera o fundo do mapa da Torre (céu, montanhas e a Torre em corte, sem andares marcados) e os círculos de missão; a tela desenha o caminho e os círculos por cima, com o eixo da Torre em `FloorSelect.TOWER_AXIS` |
| `tools/generate_placeholder_art.py` | gera a arte provisória (inimigos, inclusive o Golem de Pedra nas duas formas e o Elemental de Fogo, os cenários comum e da forja, onda do Engo-ji) e os ícones da passiva e do Bang! da Shumi |
| `../Shumi/gerar_spritesheet.py`   | fora do projeto: gera a spritesheet da Shumi a partir de `Shumi.png` e, com `kokoro.png shumi_kokoro`, a do visual Kokoro (usado no Bang!); copie o PNG e o JSON de `spritesheet/` para `characters/shumi/` |

Os geradores usam Python 3 com Pillow e rodam a partir da pasta do projeto (`python3 tools/<nome>.py`). Arte gerada é editada no gerador, não no PNG: senão a próxima geração apaga a mudança.

## Exportar para o navegador

O preset `Web` em `export_presets.cfg` gera a versão de navegador em `build/web/` (fora do Git). Ele usa a variante sem threads, que roda em qualquer hospedagem estática (itch.io, GitHub Pages) sem os cabeçalhos COOP/COEP. Precisa dos templates `web_nothreads_release.zip` e `web_nothreads_debug.zip` do Godot 4.7.2 em `~/.local/share/godot/export_templates/4.7.2.stable/`.

```sh
mkdir -p build/web && touch build/.gdignore   # o .gdignore impede o Godot de importar a própria exportação
godot --headless --path . --export-release "Web" build/web/index.html
python3 -m http.server -d build/web 8000   # abre em http://localhost:8000
```

Abrir o `index.html` direto do disco (`file://`) não funciona: o navegador bloqueia o carregamento do `.wasm`. No navegador, os saves (`user://`) ficam no armazenamento do próprio navegador (IndexedDB), separados por site.

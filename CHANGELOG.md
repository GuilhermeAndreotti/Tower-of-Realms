# Changelog

Todas as mudanças notáveis deste projeto ficam registradas neste arquivo.

O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
e o projeto adota o [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Added

- Saguão da Torre como tela inicial: a Caoimhe anda livre pela sala (setas ou WASD), com colisão nos móveis, câmera que a acompanha, tochas, lareira e braseiros acesos. Os personagens liberados ficam espalhados pela sala e mostram nome e "[Enter] Falar" quando ela se aproxima. A porta da dungeon fica no centro da parede do fundo, com runas que acendem de perto.
- Caixa de diálogo do saguão, com retrato, nome, falas, respostas e eventos por fala, pronta para receber conversas.
- Quatro andares na Torre, cada um com nome, descrição, inimigos, nível recomendado, limite de equipe e limite de nível: Vigia da Entrada, Salão do Guardião, Guarnição e Trono Sombrio (chefe: Guardião Sombrio, de Trevas). Vencer um andar libera o seguinte; andares vencidos podem ser repetidos.
- Tela de escolha do andar entre a porta e a montagem da equipe, com os andares empilhados como uma torre (vencido, novo ou trancado), inimigos, recompensa, nível recomendado e o limite de nível atual.
- Eventos de história: o Andri chega à Torre na primeira vitória do Salão do Guardião e surge no saguão com um anúncio. Andares e falas de conversa podem liberar personagens ou abrir conversas.
- Níveis e experiência (nível 1 a 20) para cada personagem, com crescimento próprio por nível (Shumi: HP +60, ATQ +8, DEF +2, VEL +0,5; Andri: HP +50, ATQ +5,5, DEF +3, VEL +1).
- Limite de nível da Torre, pelo andar mais alto liberado: 3, 5, 7 e 9. No limite, a XP para; liberar um andar novo volta a contar, sem dar vários níveis de uma vez.
- Personagens liberados que ficam de fora da luta ganham a mesma XP de quem lutou.
- Quem chega pela história entra no nível médio da equipe principal, dentro do limite da Torre.
- Nível e barra de XP na montagem da equipe; nível no painel da batalha; tela de vitória com a XP de cada um, quem subiu de nível e os atributos ganhos, quem estava na reserva, o andar liberado e o limite que subiu.
- Progresso salvo em `user://progresso.cfg`: níveis, XP, equipe, andares vencidos e eventos ainda não apresentados.
- Ferramenta de simulação dos andares com a batalha de verdade e um piloto automático (`ferramentas/simular_andares.gd`).
- Logo do jogo em pixel art, no topo do README (gerada por `ferramentas/gerar_logo.py`).
- Documentação do projeto em `docs/`, `AGENTS.md` e este changelog.

### Changed

- O jogo abre no saguão, não mais na montagem da equipe; a montagem respeita o limite de personagens do andar e o Esc volta à escolha do andar.
- Ao fim de um andar, vencendo ou perdendo, a tela de resultado leva de volta ao saguão (Enter, Esc ou clique), no lugar de "jogar de novo" e "trocar equipe".
- A batalha usa os inimigos e o cenário do andar escolhido, com até 3 inimigos.
- Encontros reequilibrados: inimigos dos andares 3 e 4 batem bem mais forte e têm tipos que tiram o dano dobrado automático da lente do Andri (Guardião de Veneno, chefe de Trevas, sentinelas de Água e de Ácido) e uma Sentinela Veloz.
- O Andri começa bloqueado e só chega pela história.
- A equipe escolhida fica salva entre sessões; um mesmo personagem não entra duas vezes na equipe.
- Novo ícone do Disparo do Andri: um raio de fogo.

# Changelog

Todas as mudanças notáveis deste projeto ficam registradas neste arquivo.

O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
e o projeto adota o [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Added

- Menu inicial com a logo do jogo, brasas subindo e os botões NEW GAME, LOAD GAME e QUIT.
- Três slots de save. NEW GAME cria o jogo num slot (um slot ocupado pede confirmação antes de ser sobrescrito); LOAD GAME continua um save, mostrando o maior nível, os personagens, os andares vencidos e a data em que foi salvo. Saves podem ser apagados (Del ou botão APAGAR), também com confirmação. O save que já existia aparece no slot 1.
- Esc no saguão volta ao menu inicial.
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
- Página de cada personagem (`personagens/<id>/README.md`), ligada ao README principal, com os atributos e as habilidades no mesmo texto do jogo, gerados por `ferramentas/gerar_readme_personagens.gd`.
- Documentação do projeto em `docs/`, `AGENTS.md` e este changelog.
- Nova personagem: Àskara, invocadora do abismo (Trevas), de Nariagari. Não usa energia: junta Fragmentos d'Alma (começa com 2, máximo 8; +1 por Seta Vil e +1 quando um inimigo cai) e os gasta em demônios.
  - Seta Vil (Q): 0,6× ATQ, gera 1 ponto de skill e 1 fragmento.
  - Invocação (E, 1 ponto + fragmentos, seletor radial): Diabrete (1; Bola de Fogo Vil 0,5×), Emissário do Caos (2; tanque que provoca, 0,4×), Lilith (2; ATQ e DEF −20% por 2 turnos no inimigo mais forte, 0,3×) e Shivara (3; 0,9× no alvo e 0,45× nos vizinhos). Até 2 em campo, 3 vezes cada; chamar de novo a mesma renova.
  - Lorde Demônio (R, 6 fragmentos, −1 por invocação em campo): apaga as outras invocações, avança golpeando todos os inimigos ao chegar (1,2×) e fica 3 vezes (0,8× em todos). Com 15% de chance vem o Lorde da Luz (Luz, 2,0× na chegada, 1,2× em todos por 3 vezes, −50% de todo dano recebido). Com um Lorde em campo, não dá para invocar outros.
  - Crescimento por nível: HP +45, ATQ +6, DEF +2, VEL +1. A arte das invocações é provisória.
- Invocações na batalha: entram na fila de turnos com HP e barra própria, agem sozinhas no inimigo marcado e podem ser atacadas pelos inimigos e receber artefatos do Andri. Não ganham XP e não seguram a luta: se a equipe cair, ela acaba.
- Provocação: os inimigos passam a sortear o alvo com peso, e quem provoca tem mais chance de ser atacado.
- Simulação dos andares aceita `equipe=id,id` para medir outra equipe.
- Segunda habilidade (W) para a Shumi e o Andri, e uma segunda passiva para a Àskara. A W custa 1 ponto de skill e tem recarga (3 turnos no Andri, 4 na Shumi; a barra mostra no ícone quantos turnos faltam).
  - Shumi, **Bang!**: Finger Beam no alvo e, pelos 2 turnos seguintes dela, ataca junto: sempre que um aliado (inclusive invocação) acerta um inimigo, ela dispara um Finger Beam nele e ganha +4 de energia. A recarga é um turno maior que o efeito, para sempre sobrar um turno sem ele. Cada Finger Beam é uma bolinha de ki disparada do dedo, no visual Kokoro. O tiro vai de 0,4× (fora do Kaioken) a 0,5×, 0,65×, 0,85× e 1,1× (x2 a x20).
  - Andri, **Protocolo MOMC**: Sobrecarga (o MOMC dispara 0,9× com o elemento da lente) ou Escudo (10% do HP máximo do aliado por 2 turnos).
  - Àskara, **Último Ato** (passiva): cada demônio, ao ir embora por tempo ou ao cair, faz um último ato: Explosão Vil do Diabrete (0,5× no alvo e no inimigo ao lado), Muralha do Caos do Emissário (escudo de 8% do HP máximo dele no aliado com menos HP), Beijo Final da Lilith (Encanto em todos os inimigos, 0,2×) e Última Dança da Shivara (0,4× em todos). Não dispara ao sair para abrir vaga, ao ser apagado pelo Lorde nem quando a Àskara cai.
- O nome de cada habilidade na barra da batalha tem largura fixa: nomes longos aparecem cortados com reticências e correm para ser lidos inteiros com o mouse em cima.
- A lista de habilidades na montagem da equipe ocupa o espaço que sobra na ficha e rola quando o kit não cabe.
- Explicação das habilidades em cartões, na barra da batalha e na montagem da equipe: nome, etiquetas (passiva, custo, recarga, alvo e elemento), um resumo curto e, quando a habilidade tem vários itens, uma linha para cada um, com o atual em destaque: os demônios da Invocação e do Último Ato, os Lordes, os artefatos do Arsenal, as opções do Protocolo, os níveis do Kaioken e do Engo-ji, e o dano do Finger Beam e a energia do Limite Humano por nível.
- A barra de habilidades da batalha mostra também a passiva de cada personagem, no fim, marcada como PASSIVA e explicada ao passar o mouse, no mesmo padrão das outras. A Shumi passa a ter a passiva Limite Humano explicada (com ícone novo), e a Àskara, o Fragmento d'Alma.

### Changed

- O jogo abre no menu inicial, que leva ao saguão (antes, abria direto na montagem da equipe); a montagem respeita o limite de personagens do andar e o Esc volta à escolha do andar.
- Ao fim de um andar, vencendo ou perdendo, a tela de resultado leva de volta ao saguão (Enter, Esc ou clique), no lugar de "jogar de novo" e "trocar equipe".
- A batalha usa os inimigos e o cenário do andar escolhido, com até 3 inimigos.
- Encontros reequilibrados: inimigos dos andares 3 e 4 batem bem mais forte e têm tipos que tiram o dano dobrado automático da lente do Andri (Guardião de Veneno, chefe de Trevas, sentinelas de Água e de Ácido) e uma Sentinela Veloz.
- Por enquanto, todos os personagens começam liberados. A chegada do Andri pela história continua no cadastro e volta a valer quando a liberação temporária for desligada; enquanto isso, a vitória no andar 2 não repete a chegada de quem já está no saguão.
- A equipe escolhida fica salva entre sessões; um mesmo personagem não entra duas vezes na equipe.
- Nos seletores de opção da batalha, W e S não navegam mais (só ↑/↓): o W passa a chamar a skill 2, mesmo com a lente do Andri aberta.
- O piloto da simulação dos andares usa as skills 2 (Bang! e Protocolo MOMC).
- Ícones de habilidade e de artefato padronizados no estilo dos da Shumi: mesmo tamanho (desenho de 11×11 centrado), sem moldura própria (o slot da barra já tem borda) e com a borda da figura num tom escuro da própria cor. Todos os do Andri e da Àskara foram redesenhados; o Disparo do Andri virou uma bola de fogo.

### Fixed

- O botão COMEÇAR COMBATE e as dicas de controle da montagem da equipe ficavam fora da tela quando a ficha do personagem era alta.
- A explicação da habilidade na batalha cobria o painel do personagem e o da equipe; agora fica acima da barra.
- Passar o mouse numa habilidade que atinge vários inimigos gerava erro no registro do Godot.
- O ícone da Mão de Tyr (artefato do Andri) tinha um dedo a mais; a luva agora tem quatro dedos e o polegar.

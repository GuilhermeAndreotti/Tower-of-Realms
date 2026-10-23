"""Gera os assets do Andri a partir do sprite original (andri-findavil.png):
folha de animações + JSON (mesmo formato da Shumi), o MOMC separado e os
ícones 15x15 das habilidades e dos artefatos.

Uso: python3 ferramentas/gerar_andri.py  (a partir da pasta Torre)
"""
import json
import os

from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PASTA = os.path.join(RAIZ, "personagens", "andri")
ORIGINAL = os.path.join(PASTA, "andri-findavil.png")

# No original o MOMC fica no canto de baixo, à esquerda dos pés do Andri.
MOMC_CAIXA = (2, 29, 7, 35)  # x0, y0, x1, y1 (x1/y1 exclusivos)

QUADRO = (32, 40)
DESLOCAMENTO = (5, 2)  # onde o original entra no quadro
DURACOES = {"idle": 250, "walk": 150, "disparo": 90, "analise": 140, "hurt": 150}

MANGA = (216, 216, 216, 255)
MANGA_CLARA = (232, 232, 232, 255)
PELE = (249, 207, 127, 255)
LUVA = (33, 27, 0, 255)
DISPOSITIVO = (22, 107, 122, 255)
DISPOSITIVO_ACESO = (90, 230, 255, 255)
CONTORNO = (20, 22, 34, 255)


def salvar(img, nome):
    destino = os.path.join(PASTA, nome)
    img.save(destino)
    print("ok:", destino)


def separar(original):
    corpo = original.copy()
    momc = Image.new("RGBA", (MOMC_CAIXA[2] - MOMC_CAIXA[0] + 2, MOMC_CAIXA[3] - MOMC_CAIXA[1] + 1), (0, 0, 0, 0))
    for y in range(MOMC_CAIXA[1], MOMC_CAIXA[3]):
        for x in range(MOMC_CAIXA[0], MOMC_CAIXA[2]):
            momc.putpixel((x - MOMC_CAIXA[0] + 1, y - MOMC_CAIXA[1]), original.getpixel((x, y)))
            corpo.putpixel((x, y), (0, 0, 0, 0))
    return corpo, momc


def no_quadro(corpo, dx=0, dy=0):
    q = Image.new("RGBA", QUADRO, (0, 0, 0, 0))
    q.alpha_composite(corpo, (DESLOCAMENTO[0] + dx, DESLOCAMENTO[1] + dy))
    return q


def respirando(corpo):
    """Tronco (linhas 12-21) desce 1px; a cabeça fica parada (a lente não mexe)."""
    c = corpo.copy()
    for y in range(21, 11, -1):
        for x in range(c.width):
            c.putpixel((x, y + 1), corpo.getpixel((x, y)))
    return c


def braco_estendido(corpo, aceso=False):
    """Braço direito (o da frente, à direita) apontando o dispositivo para a frente."""
    c = corpo.copy()
    for y in range(16, 22):
        for x in range(16, c.width):
            c.putpixel((x, y), (0, 0, 0, 0))
    for x in range(16, 20):
        c.putpixel((x, 15), MANGA_CLARA)
        c.putpixel((x, 16), MANGA)
    c.putpixel((20, 15), PELE)
    c.putpixel((20, 16), LUVA)
    disp = DISPOSITIVO_ACESO if aceso else DISPOSITIVO
    c.putpixel((21, 15), disp)
    c.putpixel((21, 16), disp)
    return c


def gerar_folha(corpo):
    estendido = braco_estendido(corpo)
    aceso = braco_estendido(corpo, True)
    anims = {
        "idle": [no_quadro(corpo), no_quadro(corpo), no_quadro(respirando(corpo)), no_quadro(respirando(corpo))],
        "walk": [no_quadro(corpo), no_quadro(corpo, dy=-1), no_quadro(corpo), no_quadro(corpo, dy=-1)],
        "disparo": [no_quadro(estendido), no_quadro(aceso), no_quadro(aceso, dx=-1), no_quadro(estendido)],
        "analise": [no_quadro(estendido), no_quadro(aceso), no_quadro(estendido), no_quadro(aceso)],
        "hurt": [no_quadro(corpo, dx=-1), no_quadro(corpo)],
    }
    colunas = max(len(f) for f in anims.values())
    folha = Image.new("RGBA", (QUADRO[0] * colunas, QUADRO[1] * len(anims)), (0, 0, 0, 0))
    dados = {"image": "andri_spritesheet.png", "frame_width": QUADRO[0], "frame_height": QUADRO[1], "animations": {}}
    for linha, (nome, quadros) in enumerate(anims.items()):
        lista = []
        for col, q in enumerate(quadros):
            folha.alpha_composite(q, (col * QUADRO[0], linha * QUADRO[1]))
            lista.append({"x": col * QUADRO[0], "y": linha * QUADRO[1], "w": QUADRO[0], "h": QUADRO[1]})
        dados["animations"][nome] = {"row": linha, "frame_duration_ms": DURACOES[nome], "frames": lista}
    salvar(folha, "andri_spritesheet.png")
    with open(os.path.join(PASTA, "andri_spritesheet.json"), "w") as f:
        json.dump(dados, f, indent=2)
    print("ok:", os.path.join(PASTA, "andri_spritesheet.json"))


# ------------------------------------------------------------------ ícones
# Mapas de 15x15 ('.' = transparente); cada ícone tem sua paleta.
ICONES = {
    # Raio de fogo: núcleo vermelho, borda laranja e ponta amarela.
    "disparo": ({"o": (255, 106, 0, 255), "r": (255, 0, 0, 255), "y": (255, 216, 0, 255)}, [
        "...............",
        "...............",
        "...............",
        "...............",
        "...............",
        "........oooo...",
        "...ooooorrryo..",
        ".oorrrrrrryyyo.",
        "...ooooorrryo..",
        "........oooo...",
        "...............",
        "...............",
        "...............",
        "...............",
        "...............",
    ]),
    "analise": ({"k": CONTORNO, "c": (90, 230, 255, 255), "l": (200, 250, 255, 255), "g": (110, 118, 140, 255), "r": (255, 90, 90, 255)}, [
        "...............",
        "....kkkkk......",
        "...kcccccck....",
        "..kcclllccck...",
        "..kclcccrcck...",
        "..kccccrrcck...",
        "..kcccccccck...",
        "..kcccccccck...",
        "...kcccccck....",
        "....kkkkkgg....",
        ".........ggk...",
        "..........ggk..",
        "...........ggk.",
        "............kk.",
        "...............",
    ]),
    "arsenal": ({"k": CONTORNO, "m": (120, 78, 40, 255), "d": (84, 52, 26, 255), "y": (255, 200, 60, 255), "w": (255, 245, 200, 255)}, [
        "...............",
        "......w........",
        "...w..y..w.....",
        "....y.y.y......",
        "...............",
        "..kkkkkkkkkkk..",
        ".kmmmmmmmmmmmk.",
        ".kyyyyyyyyyyyk.",
        ".kmmmmmykmmmmk.",
        ".kmmmmmyymmmmk.",
        ".kddddddddddk..",
        ".kmmmmmmmmmmmk.",
        ".kyyyyyyyyyyyk.",
        "..kkkkkkkkkkk..",
        "...............",
    ]),
    "lente": ({"k": CONTORNO, "y": (255, 220, 40, 255), "l": (255, 250, 200, 255), "r": (255, 120, 60, 255), "b": (80, 160, 255, 255), "g": (110, 220, 90, 255)}, [
        "...............",
        "....kkkkkk.....",
        "...kyyyyyyk....",
        "..kyrrllbbyk...",
        "..kyrlllbbyk...",
        "..kyrrggbbyk...",
        "..kyyggggyyk...",
        "...kyyyyyyk....",
        "....kkkkkky....",
        "..........y....",
        "...........y...",
        "...........y...",
        "..........y....",
        "...............",
        "...............",
    ]),
    # Olho de Odyn: amuleto de ouro envelhecido, gema oval com íris dourada e
    # filamentos de energia nas bordas.
    "odyn": ({"k": CONTORNO, "y": (230, 180, 60, 255), "d": (160, 110, 30, 255), "w": (240, 236, 220, 255),
              "o": (255, 215, 70, 255), "p": (60, 30, 10, 255), "l": (255, 240, 150, 255)}, [
        "...............",
        "....l.....l....",
        ".....l...l.....",
        "....kkkkkkk....",
        "..kkyyyyyyykk..",
        ".kyyywwwwwyyyk.",
        "kyydwooooowdyyk",
        "dyydwoopoowdyyd",
        "kyydwooooowdyyk",
        ".kyyywwwwwyyyk.",
        "..kkyyyyyyykk..",
        "....kkkkkkk....",
        ".....l...l.....",
        "....l.....l....",
        "...............",
    ]),
    # Mão de Tyr: manopla de prata em placas, cristal branco na palma, aura prateada.
    "tyr": ({"k": CONTORNO, "s": (190, 195, 210, 255), "S": (235, 238, 245, 255), "g": (120, 125, 145, 255),
             "c": (255, 255, 255, 255), "a": (220, 235, 255, 255)}, [
        "a..............",
        "....k.k.k.k....",
        "...kSkSkSkSk...",
        "...kskskskskk..",
        "...kskskskskSk.",
        "..akssssssskSk.",
        "...ksgsssgsksk.",
        ".kkksscccsssk..",
        "kSsksccccsgk..a",
        ".kssssccssk....",
        "..ksgssssgk....",
        "...kgggggk.....",
        "...kSSSSSk.....",
        "...kkkkkkk..a..",
        "...............",
    ]),
    # Sussurro de Loken: colar de seda negra com estrela espiralada escura e
    # linhas violetas.
    "loken": ({"k": (10, 8, 16, 255), "b": (35, 30, 45, 255), "h": (70, 62, 85, 255), "m": (55, 50, 70, 255),
               "v": (170, 90, 230, 255), "V": (210, 150, 255, 255)}, [
        "...............",
        "...............",
        "kk...........kk",
        "bhk.........khb",
        ".bhk.......khb.",
        "..bbkk...kkbb..",
        "....bbbbbbb....",
        "......kmk......",
        ".....kmvmk.....",
        "..v.kmvmvmk.v..",
        "..kmmvmVmvmmk..",
        "....kmvmvmk....",
        ".....kmvmk.....",
        "......kmk......",
        ".......v.......",
    ]),
    # Raiz de Freya: greva de couro com placas de madeira, raízes, folhas e flores.
    "freya": ({"k": CONTORNO, "l": (130, 85, 45, 255), "L": (90, 55, 30, 255), "w": (170, 125, 70, 255),
               "r": (100, 70, 40, 255), "g": (90, 200, 80, 255), "f": (255, 150, 190, 255), "o": (255, 220, 100, 255)}, [
        "...f.......o...",
        "..kkkkkkkkk....",
        ".kgllllllgk....",
        ".klwwlllwwlk...",
        "..klrlllrlk....",
        "..klllrlllk.o..",
        "..kgwwwwwgk....",
        "..klrllrllk....",
        "..klllllllk....",
        "..klwwrwwlk....",
        ".gklrllrlkg....",
        "..kllllllk.....",
        ".kLLLLLLLLk....",
        ".kLLLfLLLLLk...",
        ".kkkkkkkkkkk...",
    ]),
    # Manto de Hodir: capa pesada de pele branca e cinza, pontas de gelo e névoa fria.
    "hodir": ({"k": CONTORNO, "w": (235, 235, 240, 255), "g": (170, 172, 180, 255), "d": (120, 122, 135, 255),
               "i": (170, 220, 255, 255), "I": (220, 245, 255, 255), "m": (200, 230, 255, 255)}, [
        "......kkk......",
        "....kkwwwkk....",
        "...kwwgwgwwk...",
        "...kwgwwwgwk...",
        "..kwwwgwgwwwk..",
        "..kwgwwwwwgwk..",
        "..kwwwgwgwwwk..",
        ".kwgwwwdwwwgwk.",
        ".kwwgwwdwwgwwk.",
        ".kwwwwgdgwwwwk.",
        "kwgwwwwdwwwwgwk",
        "kwwwgwwdwwgwwwk",
        "kiIkiIkkkIikIik",
        ".i..I..i..I..i.",
        "m.....m.....m..",
    ]),
    # Braço de Thorim: bracelete de ferro escuro, runas e interior em azul elétrico,
    # descargas saltando.
    "thorim": ({"k": CONTORNO, "i": (60, 62, 72, 255), "I": (100, 104, 118, 255), "b": (60, 170, 255, 255),
                "B": (180, 230, 255, 255), "e": (150, 220, 255, 255)}, [
        "......e........",
        "...e..B..e.....",
        "....kkkkkkk..e.",
        "..kkIiiiiiIkk..",
        ".kIibibibibiIk.",
        "kIikkkkkkkkkiIk",
        "kikBBBBBBBBBkik",
        "kikBbBBBBBbBkik",
        "kIikkkkkkkkkiIk",
        ".kIibibibibiIk.",
        "..kkIiiiiiIkk..",
        "....kkkkkkk....",
        "..e....B....e..",
        "......e........",
        "...............",
    ]),
    # Cinturão de Archaedas: couro escuro, fivela de pedra com rosto titânico de
    # olhos âmbar, runas douradas e fragmentos de rocha flutuando.
    "archaedas": ({"k": CONTORNO, "L": (70, 45, 30, 255), "l": (100, 68, 45, 255), "s": (140, 140, 150, 255),
                   "S": (175, 175, 185, 255), "D": (95, 95, 105, 255), "a": (255, 170, 40, 255),
                   "o": (230, 190, 70, 255), "r": (120, 120, 130, 255)}, [
        "..r..........r.",
        "...............",
        "....kkkkkkk....",
        "...kSSSSSSSk...",
        "kkkkSDSSSDSkkkk",
        "lllkSaDsDaSklll",
        "LLLksssSssskLLL",
        "lllksoDDDosklll",
        "kkkkDsssssDkkkk",
        "....kDDDDDk....",
        "...o.kkkkk.o...",
        "...............",
        "....r.....r....",
        "...............",
        "...............",
    ]),
    "ra": ({"k": CONTORNO, "y": (255, 210, 60, 255), "l": (255, 250, 200, 255), "m": (150, 100, 40, 255), "o": (255, 150, 40, 255)}, [
        "..........o.o..",
        "...........y...",
        "..........yly..",
        "........o.yllyo",
        "..........kyyk.",
        ".........kyyk..",
        "........kmk....",
        ".......kmk.....",
        "......kmk......",
        ".....kmk.......",
        "....kmk........",
        "...kmk.........",
        "..kmk..........",
        ".kmk...........",
        "..k............",
    ]),
}


def gerar_icones():
    for nome, (paleta, mapa) in ICONES.items():
        img = Image.new("RGBA", (15, 15), (0, 0, 0, 0))
        for y, linha in enumerate(mapa):
            for x, ch in enumerate(linha):
                if ch != ".":
                    img.putpixel((x, y), paleta[ch])
        salvar(img, "icone_%s.png" % nome)


if __name__ == "__main__":
    original = Image.open(ORIGINAL).convert("RGBA")
    corpo, momc = separar(original)
    gerar_folha(corpo)
    salvar(momc, "momc.png")
    gerar_icones()

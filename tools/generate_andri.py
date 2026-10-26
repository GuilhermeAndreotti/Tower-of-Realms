"""Gera os assets do Andri a partir do sprite original (andri-findavil.png):
folha de animações + JSON (mesmo formato da Shumi), o MOMC separado, os
ícones das habilidades e dos artefatos (padrão de pixel_icon.py) e os
artefatos só com o desenho, que voam na arena.

Uso: python3 tools/generate_andri.py  (a partir da pasta Torre)
"""
import json
import os

from PIL import Image

from pixel_icon import drawing, icon

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDER = os.path.join(ROOT, "characters", "andri")
ORIGINAL = os.path.join(FOLDER, "andri-findavil.png")

# No original o MOMC fica no canto de baixo, à esquerda dos pés do Andri.
MOMC_BOX = (2, 29, 7, 35)  # x0, y0, x1, y1 (x1/y1 exclusivos)

FRAME = (32, 40)
OFFSET = (5, 2)  # onde o original entra no quadro
DURACOES = {"idle": 250, "walk": 150, "shot": 90, "analysis": 140, "hurt": 150}

MANGA = (216, 216, 216, 255)
MANGA_LIGHT = (232, 232, 232, 255)
PELE = (249, 207, 127, 255)
LUVA = (33, 27, 0, 255)
DEVICE = (22, 107, 122, 255)
DEVICE_ACESO = (90, 230, 255, 255)


def save(img, name):
    destination = os.path.join(FOLDER, name)
    img.save(destination)
    print("ok:", destination)


def separar(original):
    body = original.copy()
    momc = Image.new("RGBA", (MOMC_BOX[2] - MOMC_BOX[0] + 2, MOMC_BOX[3] - MOMC_BOX[1] + 1), (0, 0, 0, 0))
    for y in range(MOMC_BOX[1], MOMC_BOX[3]):
        for x in range(MOMC_BOX[0], MOMC_BOX[2]):
            momc.putpixel((x - MOMC_BOX[0] + 1, y - MOMC_BOX[1]), original.getpixel((x, y)))
            body.putpixel((x, y), (0, 0, 0, 0))
    return body, momc


def at_frame(body, dx=0, dy=0):
    q = Image.new("RGBA", FRAME, (0, 0, 0, 0))
    q.alpha_composite(body, (OFFSET[0] + dx, OFFSET[1] + dy))
    return q


def respirando(body):
    """Tronco (linhas 12-21) desce 1px; a cabeça fica parada (a lente não mexe)."""
    c = body.copy()
    for y in range(21, 11, -1):
        for x in range(c.width):
            c.putpixel((x, y + 1), body.getpixel((x, y)))
    return c


def braco_estendido(body, aceso=False):
    """Braço direito (o da frente, à direita) apontando o dispositivo para a frente."""
    c = body.copy()
    for y in range(16, 22):
        for x in range(16, c.width):
            c.putpixel((x, y), (0, 0, 0, 0))
    for x in range(16, 20):
        c.putpixel((x, 15), MANGA_LIGHT)
        c.putpixel((x, 16), MANGA)
    c.putpixel((20, 15), PELE)
    c.putpixel((20, 16), LUVA)
    disp = DEVICE_ACESO if aceso else DEVICE
    c.putpixel((21, 15), disp)
    c.putpixel((21, 16), disp)
    return c


def gerar_sheet(body):
    estendido = braco_estendido(body)
    aceso = braco_estendido(body, True)
    anims = {
        "idle": [at_frame(body), at_frame(body), at_frame(respirando(body)), at_frame(respirando(body))],
        "walk": [at_frame(body), at_frame(body, dy=-1), at_frame(body), at_frame(body, dy=-1)],
        "shot": [at_frame(estendido), at_frame(aceso), at_frame(aceso, dx=-1), at_frame(estendido)],
        "analysis": [at_frame(estendido), at_frame(aceso), at_frame(estendido), at_frame(aceso)],
        "hurt": [at_frame(body, dx=-1), at_frame(body)],
    }
    columns = max(len(f) for f in anims.values())
    sheet = Image.new("RGBA", (FRAME[0] * columns, FRAME[1] * len(anims)), (0, 0, 0, 0))
    data = {"image": "andri_spritesheet.png", "frame_width": FRAME[0], "frame_height": FRAME[1], "animations": {}}
    for line, (name, frames) in enumerate(anims.items()):
        list = []
        for col, q in enumerate(frames):
            sheet.alpha_composite(q, (col * FRAME[0], line * FRAME[1]))
            list.append({"x": col * FRAME[0], "y": line * FRAME[1], "w": FRAME[0], "h": FRAME[1]})
        data["animations"][name] = {"row": line, "frame_duration_ms": DURACOES[name], "frames": list}
    save(sheet, "andri_spritesheet.png")
    with open(os.path.join(FOLDER, "andri_spritesheet.json"), "w") as f:
        json.dump(data, f, indent=2)
    print("ok:", os.path.join(FOLDER, "andri_spritesheet.json"))


# ------------------------------------------------------------------ ícones
# Desenhos 11x11 no padrão de tools/pixel_icon.py (sem moldura,
# borda em tom escuro da própria cor); cada ícone tem sua paleta.
ICONS = {
    # Disparo: bola de fogo indo para a direita, núcleo claro na frente.
    "shot": ({"d": (180, 30, 0, 255), "o": (255, 106, 0, 255), "y": (255, 216, 0, 255), "w": (255, 250, 200, 255)}, [
        "...........",
        "...........",
        ".......dd..",
        "....ddoood.",
        ".ddooooyyod",
        "doooyyywwyd",
        ".ddooooyyod",
        "....ddoood.",
        ".......dd..",
        "...........",
        "...........",
    ]),
    # Análise: lupa com a mira vermelha no vidro.
    "analysis": ({"d": (20, 100, 125, 255), "c": (90, 230, 255, 255), "l": (200, 250, 255, 255), "r": (255, 90, 90, 255),
                 "g": (130, 136, 156, 255), "G": (80, 84, 102, 255)}, [
        "..ddddd....",
        ".dcllccd...",
        "dclcccccd..",
        "dcccrcccd..",
        "dccrrrccd..",
        "dcccrcccd..",
        "dcccccccd..",
        ".dcccccd...",
        "..dddddgg..",
        ".......ggG.",
        "........GG.",
    ]),
    # Protocolo MOMC: a cabeça do robô, com antena acesa e os olhos azuis.
    "protocol": ({"d": (40, 70, 120, 255), "b": (85, 140, 210, 255), "l": (150, 200, 255, 255), "w": (210, 245, 255, 255),
                   "y": (255, 200, 60, 255)}, [
        ".....y.....",
        ".....d.....",
        "..ddddddd..",
        ".dbbbbbbbd.",
        ".dbwwbwwbd.",
        ".dbwlblwbd.",
        ".dbbbbbbbd.",
        ".dbbllllbd.",
        "..ddddddd..",
        "..d.d.d.d..",
        "...........",
    ]),
    # Arsenal: baú de madeira com faixas e fecho de ouro, brilhando.
    "arsenal": ({"d": (84, 52, 26, 255), "m": (130, 85, 45, 255), "y": (255, 200, 60, 255), "w": (255, 245, 200, 255)}, [
        "...w...w...",
        ".....y.....",
        ".ddddddddd.",
        "dmmmmmmmmmd",
        "dmmmmmmmmmd",
        "dyyyyyyyyyd",
        "dmmmmwmmmmd",
        "dmmmmymmmmd",
        "dmmmmmmmmmd",
        "dyyyyyyyyyd",
        "ddddddddddd",
    ]),
    # Lente Elemental: monóculo de ouro com os elementos no vidro e a correntinha.
    "lens": ({"y": (200, 150, 20, 255), "Y": (255, 220, 40, 255), "l": (255, 250, 200, 255), "r": (255, 120, 60, 255),
               "b": (80, 160, 255, 255), "g": (110, 220, 90, 255)}, [
        "..yyyyyy...",
        ".yYYYYYYy..",
        "yYrrllbbYy.",
        "yYrlllbbYy.",
        "yYrrggbbYy.",
        "yYrggggbYy.",
        ".yYggggYy..",
        "..yYYYYYy..",
        "...yyyyyY..",
        "........Y..",
        ".......YY..",
    ]),
    # Olho de Odyn: olho dourado aberto, com brilhos nos cantos.
    "odyn": ({"d": (160, 110, 20, 255), "y": (255, 200, 60, 255), "w": (250, 246, 230, 255), "b": (70, 45, 10, 255),
              "l": (255, 240, 170, 255)}, [
        "l....y....l",
        "...........",
        "...ddddd...",
        ".ddyyyyydd.",
        "dyywwbwwyyd",
        "dywwbbbwwyd",
        "dyywwbwwyyd",
        ".ddyyyyydd.",
        "...ddddd...",
        "...........",
        "l.........l",
    ]),
    # Mão de Tyr: manopla prateada (quatro dedos e o polegar) com a palma acesa.
    "tyr": ({"d": (80, 86, 110, 255), "s": (190, 195, 210, 255), "S": (235, 238, 245, 255), "g": (130, 135, 155, 255),
             "c": (255, 255, 255, 255)}, [
        "..d.d.d.d..",
        ".dSdSdSdSd.",
        ".dsdsdsdsd.",
        ".dsdsdsdsd.",
        ".dsssssssd.",
        "dSdsscsssd.",
        "dssscccssd.",
        ".dsscccssd.",
        ".dsgsssgsd.",
        ".dgggggggd.",
        ".ddddddddd.",
    ]),
    # Sussurro de Loken: colar de seda escura com a estrela violeta.
    "loken": ({"m": (90, 80, 110, 255), "b": (45, 38, 60, 255), "v": (150, 85, 220, 255), "V": (210, 160, 255, 255),
               "k": (20, 16, 30, 255)}, [
        "m.........m",
        ".m.......m.",
        "..mm...mm..",
        "....mvm....",
        "...vbVbv...",
        "..vbbVbbv..",
        ".vVVVkVVVv.",
        "..vbbVbbv..",
        "...vbVbv...",
        "....vbv....",
        ".....v.....",
    ]),
    # Raiz de Freya: broto de duas folhas com raízes e um brilho dourado.
    "freya": ({"g": (40, 120, 40, 255), "G": (110, 210, 80, 255), "l": (190, 250, 150, 255), "r": (120, 75, 35, 255),
               "y": (255, 215, 90, 255)}, [
        ".....y.....",
        ".gg.....gg.",
        "gGGg...gGGg",
        "gGlGg.gGlGg",
        ".gGlGgGlGg.",
        "..ggGgGgg..",
        "....gGg....",
        ".....g.....",
        "..r..g..r..",
        "...rrgrr...",
        ".rr..r..rr.",
    ]),
    # Manto de Hodir: floco de gelo.
    "hodir": ({"d": (60, 130, 200, 255), "b": (150, 210, 255, 255), "w": (240, 250, 255, 255)}, [
        ".....w.....",
        "..b..w..b..",
        "...b.w.b...",
        "b...dwd...b",
        ".b.dbwbd.b.",
        "wwwbbwbbwww",
        ".b.dbwbd.b.",
        "b...dwd...b",
        "...b.w.b...",
        "..b..w..b..",
        ".....w.....",
    ]),
    # Braço de Thorim: bracelete de aço com runas azuis e o raio em cima.
    "thorim": ({"d": (70, 74, 92, 255), "s": (120, 128, 150, 255), "S": (200, 205, 220, 255), "b": (60, 170, 255, 255),
                "y": (255, 230, 90, 255)}, [
        ".....yy....",
        "....yy.....",
        "...yyyy....",
        ".....yy....",
        "....yy.....",
        "ddddddddddd",
        "dSSbSSSbSSd",
        "dsbbbsbbbsd",
        "dSSbSSSbSSd",
        "ddddddddddd",
        "...........",
    ]),
    # Cinturão de Archaedas: cinto de couro com a fivela de pedra e âmbar.
    "archaedas": ({"d": (90, 60, 30, 255), "m": (150, 100, 50, 255), "g": (110, 110, 122, 255), "G": (185, 185, 198, 255),
                   "a": (240, 160, 50, 255), "A": (255, 225, 150, 255)}, [
        "...........",
        "...........",
        "...ggggg...",
        "..gGGGGGg..",
        "mmgGaaaGgmm",
        "ddgGaAaGgdd",
        "mmgGaaaGgmm",
        "..gGGGGGg..",
        "...ggggg...",
        "...........",
        "...........",
    ]),
    # Lança de Rá: lança de madeira com a ponta de ouro em brasa.
    "ra": ({"d": (90, 55, 25, 255), "w": (160, 105, 50, 255), "y": (255, 200, 60, 255), "Y": (255, 245, 180, 255),
            "o": (255, 140, 40, 255)}, [
        ".........Y.",
        "........yYy",
        ".......yyy.",
        "......wyo..",
        ".....wd....",
        "....wd.....",
        "...wd......",
        "..wd.......",
        ".wd........",
        "wd.........",
        "...........",
    ]),
}

# Artefatos também voam na arena (Arsenal): esses saem também só com o
# desenho, sem a folga do ícone.
ARTIFACTS = ["odyn", "tyr", "loken", "freya", "hodir", "thorim", "archaedas", "ra"]


def gerar_icons():
    for name, (paleta, lines) in ICONS.items():
        save(icon(paleta, lines), "icon_%s.png" % name)
        if name in ARTIFACTS:
            save(drawing(paleta, lines), "artifact_%s.png" % name)


if __name__ == "__main__":
    original = Image.open(ORIGINAL).convert("RGBA")
    body, momc = separar(original)
    gerar_sheet(body)
    save(momc, "momc.png")
    gerar_icons()

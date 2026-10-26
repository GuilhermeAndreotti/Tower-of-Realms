"""Gera os assets da Àskara a partir dos originais em characters/askara/:
folha de animações + JSON (mesmo formato dos outros) a partir do sprite
parado (askara.png), as invocações reduzidas para a escala da arena (a partir
de originais/, artes provisórias) e os ícones das habilidades (padrão de
pixel_icon.py).

Uso: python3 tools/generate_askara.py  (a partir da pasta Torre)
"""
import json
import os

from PIL import Image

from pixel_icon import icon

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDER = os.path.join(ROOT, "characters", "askara")
ORIGINAL = os.path.join(FOLDER, "askara.png")
ORIGINAIS = os.path.join(FOLDER, "originals")

FRAME = (32, 40)
OFFSET = (3, 3)  # onde o original entra no quadro: pés em (16, 38)
CABECA = (2, 12)  # linhas da cabeça (chifres ao queixo) no original
DURACOES = {"idle": 280, "walk": 200, "cast": 90, "hurt": 150}

# Orbe vil que se forma ao lado dela ao conjurar (coordenadas do quadro).
ORB = (27, 20)
ORB_DARK = (120, 40, 180, 255)
ORB_MIDDLE = (200, 120, 255, 255)
ORB_LIGHT = (255, 230, 255, 255)
OUTLINE = (28, 16, 36, 255)

# Invocações: altura final em pixels de sprite (a arena multiplica por 3) e
# se a arte precisa ser espelhada para olhar para os inimigos (direita).
SUMMONS = {
    "imp": {"height": 26, "mirror": False},
    "emissary": {"height": 26, "mirror": False},
    "lilith": {"height": 40, "mirror": False},
    "shivara": {"height": 42, "mirror": False},
    "demon_lord": {"height": 48, "mirror": False},
    "light_lord": {"height": 50, "mirror": True},
}


def save(img, name):
    destination = os.path.join(FOLDER, name)
    img.save(destination)
    print("ok:", destination)


# ----------------------------------------------------------------- folha
def at_frame(body, dx=0, dy=0):
    q = Image.new("RGBA", FRAME, (0, 0, 0, 0))
    q.alpha_composite(body, (OFFSET[0] + dx, OFFSET[1] + dy))
    return q


def respirando(body):
    """A cabeça desce 1px sobre a gola; o manto fica parado."""
    c = body.copy()
    top, base = CABECA
    for y in range(base, top - 1, -1):
        for x in range(c.width):
            p = body.getpixel((x, y))
            if p[3] or y + 1 <= base:
                c.putpixel((x, y + 1), p)
    for x in range(c.width):
        c.putpixel((x, top), (0, 0, 0, 0))
    return c


def orb(frame, radius):
    """Losango de energia vil em ORBE, do tamanho `raio` (0 = um ponto)."""
    cx, cy = ORB
    for dy in range(-radius - 1, radius + 2):
        for dx in range(-radius - 1, radius + 2):
            d = abs(dx) + abs(dy)
            if d > radius + 1:
                continue
            color = ORB_LIGHT if d == 0 else ORB_MIDDLE if d <= radius else ORB_DARK
            x, y = cx + dx, cy + dy
            if 0 <= x < FRAME[0] and 0 <= y < FRAME[1]:
                frame.putpixel((x, y), color)
    return frame


def clarear(img, quanto):
    c = img.copy()
    px = c.load()
    for y in range(c.height):
        for x in range(c.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (min(255, r + quanto), min(255, g + quanto), min(255, b + quanto), a)
    return c


def gerar_sheet(body):
    anims = {
        "idle": [at_frame(body), at_frame(body), at_frame(respirando(body)), at_frame(respirando(body))],
        # o manto arrasta no chão: o corpo não pula, só a cabeça balança
        "walk": [at_frame(body), at_frame(respirando(body)), at_frame(body), at_frame(respirando(body))],
        # ela se ergue e a orbe cresce até estourar
        "cast": [orb(at_frame(body, dy=-1), 0), orb(at_frame(body, dy=-1), 1),
                     orb(at_frame(body, dy=-1), 2), at_frame(body)],
        "hurt": [at_frame(clarear(body, 60), dx=-1), at_frame(body)],
    }
    columns = max(len(f) for f in anims.values())
    sheet = Image.new("RGBA", (FRAME[0] * columns, FRAME[1] * len(anims)), (0, 0, 0, 0))
    data = {"image": "askara_spritesheet.png", "frame_width": FRAME[0], "frame_height": FRAME[1], "animations": {}}
    for line, (name, frames) in enumerate(anims.items()):
        list = []
        for col, q in enumerate(frames):
            sheet.alpha_composite(q, (col * FRAME[0], line * FRAME[1]))
            list.append({"x": col * FRAME[0], "y": line * FRAME[1], "w": FRAME[0], "h": FRAME[1]})
        data["animations"][name] = {"row": line, "frame_duration_ms": DURACOES[name], "frames": list}
    save(sheet, "askara_spritesheet.png")
    with open(os.path.join(FOLDER, "askara_spritesheet.json"), "w") as f:
        json.dump(data, f, indent=2)
    print("ok:", os.path.join(FOLDER, "askara_spritesheet.json"))


# ------------------------------------------------------------ invocações
def reduzir(name, height, espelhar):
    """Recorta a arte, reduz para `altura` px, deixa o alfa binário (pixel
    art) e contorna de escuro para a silhueta ler sobre o cenário."""
    img = Image.open(os.path.join(ORIGINAIS, name + ".png")).convert("RGBA")
    img = img.crop(img.getbbox())
    width = max(1, round(img.width * height / img.height))
    img = img.resize((width, height), Image.LANCZOS)
    if espelhar:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    # 1px de folga em volta para o contorno
    final = Image.new("RGBA", (width + 2, height + 2), (0, 0, 0, 0))
    px = img.load()
    for y in range(height):
        for x in range(width):
            r, g, b, a = px[x, y]
            if a >= 110:
                final.putpixel((x + 1, y + 1), (r, g, b, 255))
    opaco = [[final.getpixel((x, y))[3] > 0 for x in range(final.width)] for y in range(final.height)]
    for y in range(final.height):
        for x in range(final.width):
            if opaco[y][x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < final.width and 0 <= ny < final.height and opaco[ny][nx]:
                    final.putpixel((x, y), OUTLINE)
                    break
    save(final, name + ".png")


# ------------------------------------------------------------------ ícones
# Desenhos 11x11 no padrão de tools/pixel_icon.py (sem moldura,
# borda em tom escuro da própria cor); cada ícone tem sua paleta.
ICONS = {
    # Seta Vil: haste roxa com ponta e penas de fogo vil verde.
    "arrow": ({"d": (95, 40, 140, 255), "p": (150, 70, 210, 255), "l": (205, 150, 245, 255), "g": (90, 190, 50, 255),
              "y": (220, 255, 160, 255)}, [
        "........gyy",
        ".......gyyg",
        "......plgg.",
        ".....pld...",
        "....pld....",
        "...pld.....",
        "..pld......",
        "g.ld.......",
        ".gd........",
        "g.g........",
        "...........",
    ]),
    # Fragmento d'Alma: cristal roxo com uma chama de alma verde dentro.
    "fragment": ({"d": (95, 40, 140, 255), "p": (150, 70, 210, 255), "l": (220, 170, 255, 255), "g": (110, 220, 70, 255),
                   "y": (220, 255, 160, 255)}, [
        ".....d.....",
        "....dld....",
        "...dlppd...",
        "...dlppd...",
        "..dlpgppd..",
        "..dlgygpd..",
        "..dpgggpd..",
        "...dpgpd...",
        "...dpppd...",
        "....dpd....",
        ".....d.....",
    ]),
    # Invocação: círculo de invocação com o pentagrama e o centro aceso.
    "summon": ({"d": (110, 50, 160, 255), "l": (220, 170, 255, 255), "g": (110, 220, 70, 255)}, [
        "...........",
        "...ddddd...",
        ".dd..l..dd.",
        ".d..l.l..d.",
        "d.lllllll.d",
        "d..l.g.l..d",
        "d...lgl...d",
        "d..l.l.l..d",
        ".dl.l.l.ld.",
        ".dll...lld.",
        "...ddddd...",
    ]),
    # Último Ato: adaga ritual roxa, com gotas de alma verde caindo.
    "last_act": ({"d": (95, 40, 140, 255), "p": (150, 70, 210, 255), "l": (220, 170, 255, 255), "g": (110, 220, 70, 255),
               "y": (220, 255, 160, 255)}, [
        ".....l.....",
        "....dld....",
        "....dld....",
        "....dld....",
        "....dld....",
        ".ppppppppp.",
        "....dpd....",
        "....dpd....",
        "...g.d.g...",
        "..gyg.gyg..",
        "...g...g...",
    ]),
    # Lorde Demônio: rosto vermelho com chifres e olhos de fogo vil.
    "lord": ({"h": (235, 220, 190, 255), "H": (170, 150, 120, 255), "d": (120, 20, 35, 255), "r": (190, 40, 50, 255),
               "R": (235, 90, 90, 255), "g": (110, 220, 70, 255), "w": (245, 240, 230, 255)}, [
        "h.........h",
        "hH.......Hh",
        ".hHdddddHh.",
        "..drRrrrd..",
        ".drrrrrrrd.",
        ".dgggrgggd.",
        ".drdrrrdrd.",
        ".drrrdrrrd.",
        "..drwdwrd..",
        "...drrrd...",
        "....ddd....",
    ]),
}


def gerar_icons():
    for name, (paleta, lines) in ICONS.items():
        save(icon(paleta, lines), "icon_%s.png" % name)


if __name__ == "__main__":
    gerar_sheet(Image.open(ORIGINAL).convert("RGBA"))
    for name, cfg in SUMMONS.items():
        reduzir(name, cfg["height"], cfg["mirror"])
    gerar_icons()

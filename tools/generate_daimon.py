"""Gera os assets do Daimon a partir do sprite parado em
characters/daimon/originals/daimon.png (15x31, de frente): folha de animações +
JSON (mesmo formato dos outros) e os ícones das habilidades (padrão de
pixel_icon.py).

O rifle é a Stand Cold: um rifle de precisão claro, azul-gelo, com a luneta
acesa. Nas poses de tiro o braço direito some do lado do corpo e sobe para o
cabo; o esquerdo fica solto, como no sprite parado (cruzando o peito até o
guarda-mão, ele ficava comprido demais nessa escala).

Uso: python3 tools/generate_daimon.py  (a partir da pasta Torre)
"""
import json
import os

from PIL import Image

from pixel_icon import icon

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDER = os.path.join(ROOT, "characters", "daimon")
ORIGINAL = os.path.join(FOLDER, "originals", "daimon.png")

FRAME = (46, 40)  # largo para caber o rifle e o clarão do tiro
OFFSET = (4, 8)  # onde o original entra no quadro (os pés ficam na linha 38)
DURATIONS = {"idle": 280, "walk": 150, "aim": 260, "shot": 70, "hurt": 150}

SLEEVE = (28, 29, 33, 255)  # o casaco escuro
SLEEVE_EDGE = (12, 19, 46, 255)
SKIN = (249, 207, 127, 255)

# Rifle (a Cold), apontado para a direita. A coronha encosta no ombro direito
# dele; RIFLE_AT é onde o canto de cima à esquerda do desenho entra no corpo.
RIFLE_COLORS = {
    "K": (22, 44, 78, 255),  # contorno azul-escuro
    "B": (84, 146, 198, 255),  # aço azul
    "S": (176, 218, 242, 255),  # aço claro
    "W": (240, 250, 255, 255),  # brilho
    "C": (110, 238, 255, 255),  # lente acesa
}
RIFLE = [
    ".......KKKKKK.............",
    "......KSSSSBCK............",
    ".......K....K.............",
    "KKKKKKKKKKKKKKKKKKKKKKKKK.",
    "KSSSSSWWSSSSSSBBBBBBBBBBBKK",
    "KSSSSSSSSSSSKKKKKKKKKKKKK.",
    "KKK.KBBK.KBK..............",
    "....KKK..KBK..............",
    ".........KK...............",
]
RIFLE_AT = (8, 8)
# Ponta do cano no quadro, para a animação (ver DaimonActions.MUZZLE).
MUZZLE = (OFFSET[0] + RIFLE_AT[0] + 26, OFFSET[1] + RIFLE_AT[1] + 4)


def save(img, name):
    destination = os.path.join(FOLDER, name)
    img.save(destination)
    print("ok:", destination)


def at_frame(body, dx=0, dy=0):
    q = Image.new("RGBA", FRAME, (0, 0, 0, 0))
    q.alpha_composite(body, (OFFSET[0] + dx, OFFSET[1] + dy))
    return q


def breathing(body):
    """A cabeça (linhas 0-8) desce 1px sobre a gola; o casaco fica parado."""
    c = body.copy()
    for y in range(8, -1, -1):
        for x in range(c.width):
            c.putpixel((x, y + 1), body.getpixel((x, y)))
    for x in range(c.width):
        c.putpixel((x, 0), (0, 0, 0, 0))
    return c


def lighten(img, amount):
    c = img.copy()
    px = c.load()
    for y in range(c.height):
        for x in range(c.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (min(255, r + amount), min(255, g + amount), min(255, b + amount), a)
    return c


def rifle(glint=False, flash=False):
    """O desenho do rifle; `glint` acende a luneta, `flash` põe o clarão na boca."""
    width = max(len(line) for line in RIFLE) + (4 if flash else 0)
    img = Image.new("RGBA", (width, len(RIFLE) + 2), (0, 0, 0, 0))
    for y, line in enumerate(RIFLE):
        for x, ch in enumerate(line):
            if ch != ".":
                color = RIFLE_COLORS[ch]
                if glint and ch == "C":
                    color = RIFLE_COLORS["W"]
                img.putpixel((x, y + 1), color)
    if flash:
        tip = len(RIFLE[4])
        for x, y, ch in [(0, 4, "W"), (1, 4, "W"), (2, 4, "C"), (3, 4, "C"), (1, 3, "C"), (1, 5, "C"),
                         (0, 3, "W"), (0, 5, "W"), (2, 2, "C"), (2, 6, "C")]:
            img.putpixel((tip + x, y + 1), RIFLE_COLORS[ch])
    return img


def aiming(body, glint=False, flash=False, recoil=0):
    """O Daimon com a Cold no ombro, num quadro inteiro."""
    c = body.copy()
    # o braço direito sai do lado do corpo
    for y in range(13, 18):
        for x in range(12, 15):
            c.putpixel((x, y), (0, 0, 0, 0))
    q = at_frame(c, dx=recoil)
    ox, oy = OFFSET[0] + recoil, OFFSET[1]
    # braço direito: do ombro desce até o cabo do rifle
    for x, y in [(12, 13), (12, 14), (13, 14)]:
        q.putpixel((ox + x, oy + y), SLEEVE)
    q.putpixel((ox + 12, oy + 15), SLEEVE_EDGE)
    q.alpha_composite(rifle(glint, flash), (ox + RIFLE_AT[0], oy + RIFLE_AT[1] - 1))
    # mão direita no cabo (sobre o rifle)
    q.putpixel((ox + RIFLE_AT[0] + 5, oy + RIFLE_AT[1] + 6), SKIN)
    return q


def build_sheet(name, anims, durations):
    columns = max(len(f) for f in anims.values())
    sheet = Image.new("RGBA", (FRAME[0] * columns, FRAME[1] * len(anims)), (0, 0, 0, 0))
    data = {"image": name + ".png", "frame_width": FRAME[0], "frame_height": FRAME[1], "animations": {}}
    for line, (anim, frames) in enumerate(anims.items()):
        cells = []
        for col, q in enumerate(frames):
            sheet.alpha_composite(q, (col * FRAME[0], line * FRAME[1]))
            cells.append({"x": col * FRAME[0], "y": line * FRAME[1], "w": FRAME[0], "h": FRAME[1]})
        data["animations"][anim] = {"row": line, "frame_duration_ms": durations[anim], "frames": cells}
    save(sheet, name + ".png")
    with open(os.path.join(FOLDER, name + ".json"), "w") as f:
        json.dump(data, f, indent=2)
    print("ok:", os.path.join(FOLDER, name + ".json"))


def generate_sheet():
    body = Image.open(ORIGINAL).convert("RGBA")
    still = at_frame(body)
    breath = at_frame(breathing(body))
    build_sheet("daimon_spritesheet", {
        "idle": [still, still, breath, breath],
        "walk": [still, at_frame(body, dy=-1), still, at_frame(body, dy=-1)],
        # mirando (a Mira Fria segura nesta pose entre os turnos): a luneta pisca
        "aim": [aiming(body), aiming(body), aiming(body, glint=True), aiming(body)],
        # o tiro: clarão na boca do cano e o coice empurra 1px para trás
        "shot": [aiming(body), aiming(body, flash=True, recoil=-1), aiming(body, recoil=-1), aiming(body)],
        "hurt": [at_frame(lighten(body, 60), dx=-1), still],
    }, DURATIONS)


# ------------------------------------------------------------------ ícones
# Desenhos 11x11 no padrão de tools/pixel_icon.py. Tudo azul-gelo, a cor da
# Cold; a passiva tem o Santo Graal dourado.
ICE = {"d": (30, 70, 115, 255), "b": (90, 160, 220, 255), "c": (165, 228, 255, 255), "w": (240, 252, 255, 255)}
GRAIL = dict(ICE, o=(125, 82, 15, 255), g=(232, 190, 64, 255), y=(255, 240, 175, 255))
ICONS = {
    # Disparo: a bala voando, com o rastro.
    "shot": (ICE, [
        "...........",
        "...........",
        "...........",
        "......ddd..",
        ".b.b.dbccd.",
        "b.b.dbccwwd",
        ".b.b.dbccd.",
        "......ddd..",
        "...........",
        "...........",
        "...........",
    ]),
    # Bala Congelante: a bala presa num cristal de gelo.
    "bullet": (ICE, [
        ".....d.....",
        "....dcd....",
        "...dcwcd...",
        "..dccwccd..",
        "..dbcccbd..",
        "..dbcwcbd..",
        "..dbcccbd..",
        "..ddbbbdd..",
        "...dbbbd...",
        "....ddd....",
        "...........",
    ]),
    # Mira Fria: a retícula da luneta.
    "aim": (ICE, [
        "....ddd....",
        "..dd.c.dd..",
        ".d...c...d.",
        ".d...c...d.",
        "d....b....d",
        "dccb.w.bccd",
        "d....b....d",
        ".d...c...d.",
        ".d...c...d.",
        "..dd.c.dd..",
        "....ddd....",
    ]),
    # Zero Absoluto: um floco de neve.
    "zero": (ICE, [
        ".....w.....",
        "..c..c..c..",
        "...c.c.c...",
        "....bcb....",
        ".c..cwc..c.",
        "wccccwccccw",
        ".c..cwc..c.",
        "....bcb....",
        "...c.c.c...",
        "..c..c..c..",
        ".....w.....",
    ]),
    # Holy Grail Powered Cold: o Santo Graal, com geada na borda.
    "cold": (GRAIL, [
        "..c..w..c..",
        ".ooooooooo.",
        ".ogyygggco.",
        ".oggggggco.",
        "..oggggco..",
        "...ogggo...",
        "....ogo....",
        "....ogo....",
        "...ooooo...",
        "..oggyggo..",
        "..ooooooo..",
    ]),
}


def generate_icons():
    for name, (palette, lines) in ICONS.items():
        save(icon(palette, lines), "icon_%s.png" % name)


if __name__ == "__main__":
    generate_sheet()
    generate_icons()
    print("ponta do cano no quadro:", MUZZLE)

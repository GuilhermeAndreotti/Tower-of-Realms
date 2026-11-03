"""Gera os assets da Lia Moonlight a partir de characters/lia/originals/lia.png:
a folha de animações + JSON (mesmo formato dos outros) e os ícones das
habilidades (padrão de pixel_icon.py).

O original é um quadro só, de 23x32: ela de armadura, com o escudo à
esquerda e a espada de pé, à direita, separada do corpo. As animações saem
dele: a espada é recortada e redesenhada erguida (conjurar) ou sai do quadro
("send", ela sem a espada): é o Espadito, a espada viva do básico, que voa
sozinho até o alvo. O Espadito voando é um sprite à parte (espadito.png),
deitado com a ponta para a direita.

Uso: python3 tools/generate_lia.py  (a partir da pasta Torre)
"""
import json
import os

from PIL import Image

from pixel_icon import icon

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDER = os.path.join(ROOT, "characters", "lia")
ORIGINAL = os.path.join(FOLDER, "originals", "lia.png")

FRAME = (40, 40)  # largo para a estocada caber à frente
FEET = (16, 38)  # meio dos pés e a base, no quadro gerado
SOURCE_FEET_X = 10  # meio dos pés no original
HEAD = (0, 8)  # linhas do cabelo ao queixo no original
DURATIONS = {"idle": 320, "send": 2000, "cast": 130, "hurt": 150}


def save(img, name):
    destination = os.path.join(FOLDER, name)
    img.save(destination)
    print("ok:", destination)


def is_sword(x, y):
    """A espada no original: a lâmina (x >= 18, linhas 16 a 25) e, da guarda
    para baixo, tudo de x >= 16."""
    return (x >= 18 and 16 <= y <= 25) or (y >= 26 and x >= 16)


def split(original):
    """Separa o corpo e a espada (a espada recortada no próprio retângulo)."""
    body = original.copy()
    sword = Image.new("RGBA", (7, 16), (0, 0, 0, 0))
    for y in range(original.height):
        for x in range(original.width):
            if is_sword(x, y) and original.getpixel((x, y))[3]:
                sword.putpixel((x - 16, y - 16), original.getpixel((x, y)))
                body.putpixel((x, y), (0, 0, 0, 0))
    return body, sword


def breathing(body):
    """A cabeça desce 1px sobre a gola; o resto fica parado."""
    c = body.copy()
    top, base = HEAD
    for y in range(base, top - 1, -1):
        for x in range(c.width):
            p = body.getpixel((x, y))
            if p[3]:
                c.putpixel((x, y + 1), p)
    for x in range(c.width):
        c.putpixel((x, top), (0, 0, 0, 0))
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


def compose(body, sword=None, sword_at=(16, 16), dx=0):
    """Quadro com os pés em FEET; `sword_at` em coordenadas do original."""
    q = Image.new("RGBA", FRAME, (0, 0, 0, 0))
    ox = FEET[0] - SOURCE_FEET_X + dx
    oy = FEET[1] - (body.height - 1)
    q.alpha_composite(body, (ox, oy))
    if sword is not None:
        q.alpha_composite(sword, (ox + sword_at[0], oy + sword_at[1]))
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
    original = Image.open(ORIGINAL).convert("RGBA")
    assert original.size == (23, 32), "o original da Lia deveria ter 23x32 (tem %dx%d)" % original.size
    body, sword = split(original)
    still = compose(body, sword)
    raised = compose(body, sword, (16, 10))
    build_sheet("lia_spritesheet", {
        "idle": [still, still, compose(breathing(body), sword), compose(breathing(body), sword)],
        # o Espadito saiu: ela fica sem a espada até ele voltar (a ação volta ao parado)
        "send": [compose(body)],
        "cast": [raised, compose(lighten(body, 30), sword, (16, 9)), raised, still],
        "hurt": [compose(lighten(body, 60), sword, dx=-1), still],
    }, DURATIONS)
    # o Espadito em voo: deitado, a ponta (em cima no original) para a direita
    save(sword.transpose(Image.ROTATE_270), "espadito.png")


# ------------------------------------------------------------------ ícones
# Desenhos 11x11 no padrão de tools/pixel_icon.py (sem moldura, borda em tom
# escuro da própria cor). Tudo da Lia é azul: a luz das curas, mais clara, e a lua.
LIGHT = {"d": (50, 100, 170, 255), "o": (110, 170, 240, 255), "y": (185, 225, 255, 255), "w": (245, 250, 255, 255)}
MOON = {"d": (40, 80, 150, 255), "b": (90, 150, 230, 255), "l": (170, 210, 255, 255), "w": (240, 248, 255, 255)}
ICONS = {
    # Espadito: a espada viva dela, de lâmina clara e guarda dourada.
    "blade": (dict(MOON, g=(219, 179, 0, 255), h=(175, 120, 42, 255)), [
        ".........lw",
        "........lwl",
        ".......lwl.",
        "......lwl..",
        ".....lwl...",
        "..g.lwl....",
        "...gwl.....",
        "...hg......",
        "..h..g.....",
        ".h.........",
        "...........",
    ]),
    # Curar Ferimentos: cruz de luz com brilho no meio.
    "heal": (LIGHT, [
        "...........",
        "....ddd....",
        "....dyd....",
        "....dyd....",
        ".dddoyoddd.",
        ".dyyywyyyd.",
        ".dddoyoddd.",
        "....dyd....",
        "....dyd....",
        "....ddd....",
        "...........",
    ]),
    # Nova Sagrada: a luz estoura em anel para todos os lados.
    "nova": (LIGHT, [
        ".....y.....",
        "..o..y..o..",
        "...ddddd...",
        "..do...od..",
        "yydo.w.odyy",
        "..d.wyw.d..",
        "yydo.w.odyy",
        "..do...od..",
        "...ddddd...",
        "..o..y..o..",
        ".....y.....",
    ]),
    # Lord Azeroth: o escudo dela, com a joia azul e o brilho da proteção.
    "lord_azeroth": (dict(MOON, s=(104, 104, 104, 255), t=(158, 158, 158, 255), k=(53, 53, 53, 255)), [
        "...........",
        ".kkkkkkkkk.",
        ".kttttttsk.",
        ".ktttttssk.",
        ".kttbbtssk.",
        ".ktblwbssk.",
        ".kttbbtssk.",
        "..ktttssk..",
        "..kttsssk..",
        "...ktssk...",
        "....kkk....",
    ]),
    # Bênção Lunar: a lua crescente de Elune, com uma estrela.
    "lunar_blessing": (MOON, [
        "....dddd...",
        "..ddbbd....",
        ".dbbld.....",
        ".dbld....w.",
        "dbld....wlw",
        "dbld.....w.",
        "dbld.......",
        ".dbld......",
        ".dbblld....",
        "..ddbbbd...",
        "....dddd...",
    ]),
}


def generate_icons():
    for name, (palette, lines) in ICONS.items():
        save(icon(palette, lines), "icon_%s.png" % name)


if __name__ == "__main__":
    generate_sheet()
    generate_icons()

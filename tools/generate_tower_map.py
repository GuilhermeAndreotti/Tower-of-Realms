"""Gera a arte do mapa da Torre (tela de escolha de missão):

- tower/map_background.png (320x180, desenhado 3x na tela): céu noturno,
  montanhas e a Torre em corte, subindo até sumir nas nuvens. Os círculos e o
  caminho entre eles são desenhados pelo jogo por cima, então a Torre não tem
  andares marcados: o mapa pode crescer sem refazer o fundo.
- tower/map_nodes.png (6 quadros de 28x28, desenhados 2x): os círculos de
  missão, na ordem trancado, principal nova, principal vencida, secundária
  nova, secundária vencida e o anel de seleção.

Uso: python3 tools/generate_tower_map.py  (a partir da pasta Torre)
"""
import math
import os
import random

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

OUTLINE = (20, 22, 34, 255)
## Centro e largura da Torre no fundo (em pixels do PNG). A tela põe os
## círculos em volta deste eixo (FloorSelect.TOWER_AXIS = 3x isto).
TOWER_X = 104
TOWER_HALF = 58
NODE = 28


def save(img, *path):
    destination = os.path.join(ROOT, *path)
    img.save(destination)
    print("ok:", destination)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


# ------------------------------------------------------------------ fundo
def background(w=320, h=180):
    rnd = random.Random(11)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    top, bottom = (8, 6, 18), (44, 26, 62)
    for y in range(h):
        for x in range(w):
            img.putpixel((x, y), mix(top, bottom, (y / h) ** 1.4))
    # estrelas, mais densas no alto
    for _ in range(170):
        x, y = rnd.randrange(w), int(rnd.random() ** 1.8 * h * 0.8)
        v = rnd.choice((120, 160, 200, 240))
        img.putpixel((x, y), (v, v, min(255, v + 20), 255))
    for _ in range(9):  # algumas em cruz
        x, y = rnd.randrange(4, w - 4), rnd.randrange(4, 90)
        for i, j in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            img.putpixel((x + i, y + j), (230, 225, 255, 255) if (i, j) == (0, 0) else (140, 130, 190, 255))
    # lua minguante entre a Torre e a ficha (que cobre o terço direito)
    mx, my, r = 186, 24, 11
    for y in range(my - r - 1, my + r + 2):
        for x in range(mx - r - 1, mx + r + 2):
            inside = (x - mx) ** 2 + (y - my) ** 2 <= r * r
            bite = (x - mx + 5) ** 2 + (y - my - 2) ** 2 <= (r - 1) ** 2
            if inside and not bite:
                img.putpixel((x, y), (232, 226, 200, 255) if x - mx > 3 else (196, 188, 170, 255))
    # duas cadeias de montanhas
    for base, amp, freq, color, seed in ((128, 26, 0.035, (30, 22, 48), 1.3), (146, 16, 0.06, (20, 15, 33), 4.1)):
        for x in range(w):
            peak = base - amp * (0.6 * math.sin(x * freq + seed) + 0.4 * math.sin(x * freq * 2.7 + seed * 2)) - amp * 0.3
            for y in range(int(peak), h):
                img.putpixel((x, y), color + (255,))
    # nuvens baixas atravessando a Torre
    for cy, seed in ((52, 2), (100, 7)):
        cr = random.Random(seed)
        for _ in range(26):
            cx, rad = cr.randrange(-10, w + 10), cr.randrange(5, 12)
            for y in range(cy - rad, cy + rad // 2):
                for x in range(cx - rad * 2, cx + rad * 2):
                    if 0 <= x < w and 0 <= y < h and ((x - cx) / 2) ** 2 + (y - cy) ** 2 <= rad * rad:
                        old = img.getpixel((x, y))
                        img.putpixel((x, y), mix(old, (70, 56, 96), 0.35))
    tower(img, rnd)
    # chão de pedra e uma escada até a porta
    ground = 168
    for y in range(ground, h):
        for x in range(w):
            v = 26 + rnd.randint(-2, 2)
            img.putpixel((x, y), (v, v - 4, v + 10, 255) if y > ground else (60, 52, 78, 255))
    return img


def tower(img, rnd):
    """A Torre em corte: paredes de tijolo com ameias quebradas nas laterais,
    o interior escuro com janelas acesas, e o topo dissolvendo na névoa."""
    h = img.height
    left, right = TOWER_X - TOWER_HALF, TOWER_X + TOWER_HALF
    wall = 7
    for y in range(h):
        fade = max(0.0, min(1.0, (y - 4) / 40))  # o topo some na névoa
        for x in range(left, right + 1):
            on_wall = x < left + wall or x > right - wall
            row = y // 5
            offset = 4 if row % 2 else 0
            joint = y % 5 == 0 or (x + offset) % 8 == 0
            if on_wall:
                base = 70 + rnd.randint(-4, 4)
                color = (34, 32, 50) if joint else (base, base - 2, base + 18)
                # luz da lua pela direita
                if x > right - wall:
                    color = tuple(min(255, c + 14) for c in color)
            else:
                v = 22 + rnd.randint(-1, 1)
                color = (v - 4, v - 6, v + 6) if joint else (v, v - 2, v + 12)
            old = img.getpixel((x, y))
            img.putpixel((x, y), mix(old, color, fade))
    # contorno das paredes
    for y in range(40, h):
        for x in (left - 1, right + 1):
            img.putpixel((x, y), OUTLINE)
    # janelas estreitas nas paredes, acesas em âmbar
    for y0 in range(46, 160, 22):
        for x0 in (left + 2, right - 4):
            for y in range(y0, y0 + 7):
                for x in range(x0, x0 + 3):
                    glow = 1.0 - (y - y0) / 9
                    img.putpixel((x, y), mix((120, 70, 30), (255, 196, 96), glow))
    # contrafortes na base
    for x0, side in ((left - 10, 1), (right + 1, -1)):
        for y in range(132, 168):
            span = int((y - 132) / 36 * 10)
            for i in range(span):
                x = x0 + (10 - span + i if side == 1 else i)
                v = 58 + rnd.randint(-3, 3)
                img.putpixel((x, y), (v, v - 2, v + 16, 255))
    # porta na base
    door_w, door_top = 16, 150
    for y in range(door_top, 168):
        for x in range(TOWER_X - door_w // 2, TOWER_X + door_w // 2):
            arch = y >= door_top + 6 or (x - TOWER_X + 0.5) ** 2 + (y - door_top - 6) ** 2 <= 64
            if arch:
                t = (y - door_top) / 18
                img.putpixel((x, y), mix((255, 170, 70), (150, 70, 30), t))


# ---------------------------------------------------------------- círculos
def disc(img, ox, r, rim, fill, rim_light, shade=True):
    """Círculo de pedra com aro, luz de cima à esquerda e contorno."""
    c = NODE / 2 - 0.5
    for y in range(NODE):
        for x in range(NODE):
            d = math.hypot(x - c, y - c)
            if d > r + 0.5:
                continue
            if d > r - 0.6:
                color = OUTLINE
            elif d > r - 2.6:
                light = (c - x + c - y) / (2 * r)
                color = mix(rim, rim_light, max(0.0, light) * 1.4) if shade else rim
            else:
                light = (c - x) * 0.4 + (c - y) * 0.6
                color = mix(fill, (0, 0, 0), max(0.0, -light) / (r * 2.4))
            img.putpixel((ox + x, y), color)


def stamp(img, ox, rows, palette):
    """Ícone em texto (um caractere por pixel), centrado no quadro."""
    h, w = len(rows), len(rows[0])
    x0, y0 = ox + (NODE - w) // 2, (NODE - h) // 2
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch in palette:
                img.putpixel((x0 + i, y0 + j), palette[ch])


SWORDS = [
    "o.......o",
    "go.....og",
    ".go...og.",
    "..go.og..",
    "...gog...",
    "...ogo...",
    "..bo.ob..",
    ".bb...bb.",
    "b.......b",
]
CHECK = [
    "......gg",
    ".....gg.",
    "g...gg..",
    "gg.gg...",
    ".ggg....",
    "..g.....",
]
LOCK = [
    "..ggg..",
    ".g...g.",
    ".g...g.",
    "ggggggg",
    "ggg.ggg",
    "ggg.ggg",
    "ggggggg",
]
STAR = [
    "...g...",
    "...g...",
    "..ggg..",
    "ggg.ggg",
    "..ggg..",
    "...g...",
    "...g...",
]


def nodes():
    img = Image.new("RGBA", (NODE * 6, NODE), (0, 0, 0, 0))
    gold = (255, 206, 90, 255)
    dark_gold = (150, 102, 40, 255)
    # 0: trancado (pedra apagada com cadeado)
    disc(img, 0, 11, (62, 60, 78), (34, 32, 44), (90, 88, 108))
    stamp(img, 0, LOCK, {"g": (104, 100, 124, 255)})
    # 1: principal nova (pedra com aro dourado e espadas cruzadas)
    disc(img, NODE, 12, (176, 124, 48), (54, 34, 30), (255, 214, 120))
    stamp(img, NODE, SWORDS, {"g": (236, 236, 250, 255), "o": (120, 120, 140, 255), "b": gold})
    # 2: principal vencida (aro dourado, interior verde, visto)
    disc(img, NODE * 2, 12, (176, 124, 48), (28, 58, 40), (255, 214, 120))
    stamp(img, NODE * 2, CHECK, {"g": (120, 236, 140, 255)})
    # 3: secundária nova (menor, aro prateado-azulado, estrela)
    disc(img, NODE * 3, 9, (96, 128, 176), (30, 36, 60), (176, 210, 255))
    stamp(img, NODE * 3, STAR, {"g": (190, 220, 255, 255)})
    # 4: secundária vencida
    disc(img, NODE * 4, 9, (96, 128, 176), (26, 52, 44), (176, 210, 255))
    stamp(img, NODE * 4, CHECK[1:], {"g": (120, 236, 140, 255)})
    # 5: anel de seleção (fica por cima do círculo, pulsando no jogo)
    c = NODE / 2 - 0.5
    for y in range(NODE):
        for x in range(NODE):
            d = math.hypot(x - c, y - c)
            if 12.6 < d <= 13.9:
                img.putpixel((NODE * 5 + x, y), gold)
            elif 13.9 < d <= 14.6:
                img.putpixel((NODE * 5 + x, y), dark_gold)
    return img


if __name__ == "__main__":
    save(background(), "tower", "map_background.png")
    save(nodes(), "tower", "map_nodes.png")

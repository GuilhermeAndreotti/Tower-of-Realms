"""Gera a arte do saguão da Torre (lobby): fundo, móveis e a porta da dungeon.
Mesma paleta de pedra fria do cenário de combate, aquecida pela luz das tochas.
Chamas, brilhos e runas acesas são desenhados no jogo (scripts/lobby).

Uso: python3 tools/generate_lobby.py  (a partir da pasta Torre)
"""
import math
import os
import random

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDER = os.path.join(ROOT, "lobby", "art")

WIDTH, HEIGHT = 640, 180
PAREDE = 104  # linha onde a parede encontra o chão

OUTLINE = (20, 22, 34, 255)
JUNTA = (22, 22, 34)
MADEIRA_ESCURA = (62, 38, 28, 255)
MADEIRA = (96, 60, 38, 255)
MADEIRA_LIGHT = (128, 84, 52, 255)
IRON_DARK = (36, 38, 50, 255)
IRON = (62, 66, 84, 255)
IRON_LIGHT = (100, 106, 128, 255)
GOLD = (214, 172, 92, 255)
GOLD_DARK = (150, 110, 56, 255)
RUNE_APAGADA = (70, 96, 130, 255)
RUNE = (130, 230, 255, 255)

# Tudo que tem luz própria, em coordenadas do fundo: (x, y, raio, força).
# O jogo acende chamas nos mesmos pontos (Lobby.TORCHES etc.).
PILARES = (20, 140, 260, 380, 500, 620)
TORCHES = [(x, 58) for x in PILARES]
FIREPLACE = (200, 104)
JANELA = 440
ARCO = 320  # centro da sala: a porta da dungeon, sobre o tapete vermelho
DOOR = (ARCO, PAREDE)
LIGHTS = [(x, y, 70, 0.55) for x, y in TORCHES] + [(FIREPLACE[0], 96, 110, 0.75), (ARCO, 110, 90, 0.35)]
COLOR_LIGHT = (255, 150, 70)


def save(img, name):
    os.makedirs(FOLDER, exist_ok=True)
    destination = os.path.join(FOLDER, name)
    img.save(destination)
    print("ok:", destination)


def contornar(img):
    """Contorno de 1px em volta de tudo que não é transparente."""
    w, h = img.size
    out = img.copy()
    for y in range(h):
        for x in range(w):
            if img.getpixel((x, y))[3]:
                continue
            for i, j in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if 0 <= x + i < w and 0 <= y + j < h and img.getpixel((x + i, y + j))[3]:
                    out.putpixel((x, y), OUTLINE)
                    break
    return out


def ret(img, x0, y0, x1, y1, color):
    """Retângulo cheio, x1/y1 exclusivos, recortado na imagem."""
    for y in range(max(0, y0), min(img.height, y1)):
        for x in range(max(0, x0), min(img.width, x1)):
            img.putpixel((x, y), color)


def px(img, x, y, color):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), color)


def tom(color, f):
    return tuple(max(0, min(255, int(c * f))) for c in color[:3]) + (255,)


# --------------------------------------------------------------------- fundo
def tijolo(x, y, rnd, base=34):
    line = y // 8
    desloc = 8 if line % 2 else 0
    if y % 8 == 0 or (x + desloc) % 16 == 0:
        return JUNTA
    b = base + rnd.randint(-2, 2)
    return (b, b + 2, b + 16)


def parede(img, rnd):
    for y in range(PAREDE):
        f = 0.55 + 0.45 * (y / PAREDE)
        for x in range(WIDTH):
            img.putpixel((x, y), tom(tijolo(x, y, rnd), f))


def galeria(img, rnd):
    """Andar de cima: vão escuro com arcos distantes e um parapeito.
    Mostra que o saguão é só uma parte de uma torre bem maior."""
    for y in range(0, 22):
        for x in range(WIDTH):
            c = tijolo(x, y + 4, rnd, 22)
            img.putpixel((x, y), tom(c, 0.5))
    # arcos do andar de cima, recortados em escuro
    for ax in range(30, WIDTH, 60):
        for y in range(2, 22):
            for x in range(ax - 10, ax + 10):
                if y >= 10 or (x - ax) ** 2 + (y - 10) ** 2 <= 100:
                    px(img, x, y, (12, 10, 20, 255))
        if rnd.random() < 0.5:  # alguma luz lá em cima
            for y in range(14, 22):
                for x in range(ax - 3, ax + 3):
                    px(img, x, y, (60, 40, 30, 255) if (x + y) % 2 else (46, 32, 28, 255))
    # parapeito: corrimão, balaústres e a laje
    ret(img, 0, 17, WIDTH, 19, (78, 82, 108, 255))
    ret(img, 0, 19, WIDTH, 20, (52, 54, 74, 255))
    for x in range(2, WIDTH, 6):
        ret(img, x, 20, x + 2, 27, (66, 70, 94, 255))
        px(img, x, 20, (92, 98, 126, 255))
    ret(img, 0, 27, WIDTH, 30, (84, 90, 118, 255))
    ret(img, 0, 30, WIDTH, 32, (40, 42, 58, 255))
    for x in range(0, WIDTH, 2):
        px(img, x, 27, (110, 118, 150, 255))


def pilar(img, cx):
    for y in range(0, PAREDE):
        for x in range(cx - 6, cx + 6):
            s = x - (cx - 6)
            v = 50 + (12 - abs(s - 4) * 3)
            px(img, x, y, (v, v + 2, v + 14, 255))
    # capitel e base
    for y, w in ((32, 8), (33, 8), (34, 7), (PAREDE - 5, 7), (PAREDE - 4, 8), (PAREDE - 3, 8)):
        for x in range(cx - w, cx + w):
            v = 70 if y in (32, PAREDE - 5) else 58
            px(img, x, y, (v, v + 4, v + 20, 255))
    ret(img, cx - 8, 35, cx + 8, 36, (30, 32, 46, 255))


def estante(img, x0, x1, y0, rnd):
    ret(img, x0, y0, x1, PAREDE, MADEIRA_ESCURA)
    ret(img, x0 + 2, y0 + 2, x1 - 2, PAREDE - 2, (30, 20, 18, 255))
    colors = [(120, 40, 44), (40, 90, 96), (150, 110, 50), (80, 50, 110), (70, 90, 50), (140, 130, 110)]
    prateleira = y0 + 2
    while prateleira + 12 <= PAREDE - 2:
        x = x0 + 2
        while x < x1 - 3:
            w = rnd.choice((1, 2, 2, 3))
            h = rnd.randint(6, 10)
            if rnd.random() < 0.12:  # vão na prateleira
                x += w + 1
                continue
            c = rnd.choice(colors)
            ret(img, x, prateleira + 11 - h, min(x + w, x1 - 2), prateleira + 11, c + (255,))
            px(img, x, prateleira + 11 - h, tom(c + (255,), 1.3))
            x += w
        ret(img, x0 + 2, prateleira + 11, x1 - 2, prateleira + 12, MADEIRA)
        prateleira += 12
    ret(img, x0, y0, x1, y0 + 2, MADEIRA_LIGHT)
    ret(img, x0, y0, x0 + 1, PAREDE, MADEIRA)
    ret(img, x1 - 1, y0, x1, PAREDE, MADEIRA_ESCURA)


def fireplace(img, rnd):
    cx = FIREPLACE[0]
    # peito da chaminé, em pedra mais clara
    for y in range(36, 56):
        for x in range(cx - 20, cx + 20):
            c = tijolo(x, y, rnd, 44)
            px(img, x, y, tom(c, 0.85 + 0.15 * (y - 36) / 20))
    # quadro sobre a lareira: montanhas sob um céu roxo
    ret(img, cx - 12, 38, cx + 12, 52, GOLD_DARK)
    ret(img, cx - 11, 39, cx + 11, 51, (60, 40, 90, 255))
    for x in range(cx - 11, cx + 11):
        top = 47 - int(4 * abs(math.sin((x - cx) / 4)))
        ret(img, x, top, x + 1, 51, (34, 30, 52, 255))
    px(img, cx + 6, 41, (230, 220, 255, 255))
    # moldura de pedra, consolo e boca
    ret(img, cx - 26, 56, cx + 26, PAREDE, (70, 74, 96, 255))
    for y in range(56, PAREDE, 6):
        ret(img, cx - 26, y, cx + 26, y + 1, (52, 54, 72, 255))
    ret(img, cx - 29, 53, cx + 29, 57, (96, 102, 132, 255))
    ret(img, cx - 29, 53, cx + 29, 54, (124, 132, 166, 255))
    for y in range(66, PAREDE):
        for x in range(cx - 16, cx + 16):
            if y >= 74 or (x - cx + 0.5) ** 2 + (y - 74) ** 2 <= 256:
                prof = (y - 66) / (PAREDE - 66)
                px(img, x, y, (int(20 + 50 * prof), int(14 + 20 * prof), int(18 + 6 * prof), 255))
    # lenha
    for x0 in (cx - 10, cx - 2, cx + 4):
        ret(img, x0, PAREDE - 4, x0 + 7, PAREDE - 2, MADEIRA_ESCURA)
        ret(img, x0, PAREDE - 4, x0 + 7, PAREDE - 3, MADEIRA)
    # velas no consolo
    for vx in (cx - 22, cx - 18, cx + 18, cx + 22):
        ret(img, vx, 48, vx + 2, 53, (230, 220, 190, 255))


def estandarte(img, cx, y0):
    for y in range(y0, y0 + 40):
        bico = abs(cx - 0.5 - cx) if y < y0 + 34 else 0
        half = 7 if y < y0 + 34 else 7 - (y - (y0 + 34))
        for x in range(cx - 7, cx + 7):
            if abs(x - cx + 0.5) > half:
                continue
            border = x in (cx - 7, cx + 6) or y in (y0, y0 + 1)
            shadow = x >= cx + 4
            color = GOLD if border else ((58, 30, 80, 255) if shadow else (84, 44, 112, 255))
            px(img, x, y, color)
    # emblema: uma torre estilizada
    ret(img, cx - 2, y0 + 10, cx + 2, y0 + 24, GOLD)
    ret(img, cx - 3, y0 + 9, cx + 3, y0 + 11, GOLD)
    px(img, cx - 3, y0 + 8, GOLD); px(img, cx - 1, y0 + 8, GOLD); px(img, cx + 1, y0 + 8, GOLD); px(img, cx + 2, y0 + 8, GOLD)
    ret(img, cx - 1, y0 + 14, cx + 1, y0 + 17, (58, 30, 80, 255))
    ret(img, cx - 4, y0 + 24, cx + 4, y0 + 26, GOLD)
    ret(img, cx - 9, y0 - 2, cx + 9, y0, IRON)


def janela(img, rnd, jx):
    for y in range(36, 84):
        for x in range(jx - 12, jx + 12):
            if y >= 48 or (x - jx + 0.5) ** 2 + (y - 48) ** 2 <= 144:
                t = (y - 36) / 48
                color = (int(40 + 60 * t), int(20 + 20 * t), int(80 + 40 * t), 255)
                if rnd.random() < 0.03:
                    color = (230, 220, 255, 255)
                px(img, x, y, color)
    for y in range(36, 84):  # caixilho em cruz
        px(img, jx, y, (24, 24, 36, 255))
    ret(img, jx - 12, 60, jx + 12, 61, (24, 24, 36, 255))
    for y in range(35, 85):
        for x in (jx - 13, jx + 12):
            if y >= 48:
                px(img, x, y, (16, 16, 26, 255))
    ret(img, jx - 15, 84, jx + 15, 87, (96, 102, 132, 255))
    ret(img, jx - 15, 84, jx + 15, 85, (124, 132, 166, 255))


def suporte_tocha(img, x, y):
    ret(img, x - 1, y + 2, x + 2, y + 8, IRON_DARK)
    ret(img, x - 3, y, x + 4, y + 3, IRON)
    ret(img, x - 3, y, x + 4, y + 1, IRON_LIGHT)
    ret(img, x - 2, y + 7, x + 3, y + 9, IRON)


def floor(img, rnd):
    h = HEIGHT - PAREDE
    for y in range(PAREDE, HEIGHT):
        prof = (y - PAREDE + 1) / h
        scale_factor = 0.25 + prof
        for x in range(WIDTH):
            world_x = (x - WIDTH / 2) / scale_factor
            world_z = 1 / scale_factor
            junta = abs(world_x) % 40 < 1.2 / scale_factor or (world_z * 12) % 6 < 0.9
            v = int(40 + 30 * prof) + rnd.randint(-2, 2)
            color = (v - 12, v - 10, v + 4) if junta else (v, v + 2, v + 14)
            img.putpixel((x, y), color + (255,))
    for x in range(WIDTH):
        img.putpixel((x, PAREDE), (14, 14, 22, 255))
        img.putpixel((x, PAREDE + 1), (30, 30, 44, 255))


def tapete(img, cx, y0, y1, half_top, half_base, color, border, drawing):
    for y in range(y0, y1):
        t = (y - y0) / max(1, y1 - y0 - 1)
        half = half_top + (half_base - half_top) * t
        for x in range(int(cx - half), int(cx + half)):
            dx = abs(x - cx + 0.5)
            in_border = dx > half - 2 or y in (y0, y0 + 1, y1 - 2, y1 - 1)
            c = border if in_border else color
            if not in_border and dx > half - 5 and (x + y) % 3 == 0:
                c = drawing
            if not in_border and y in (y0 + 4, y1 - 5):
                c = drawing
            px(img, x, y, c)
        px(img, int(cx - half) - 1, y, tom(border, 0.6))
        px(img, int(cx + half), y, tom(border, 0.6))


def iluminar(img):
    """Luz quente das tochas e da lareira somada à pedra fria."""
    for y in range(img.height):
        for x in range(img.width):
            sum = 0.0
            for lx, ly, r, f in LIGHTS:
                d = math.hypot((x - lx) * 0.9, (y - ly) * 1.2)
                if d < r:
                    sum += f * (1 - d / r) ** 2
            # bordas da sala um pouco mais escuras
            border = min(x, WIDTH - 1 - x) / 60
            dark = 0.82 + 0.18 * min(1.0, border)
            if sum <= 0 and dark >= 1:
                continue
            c = img.getpixel((x, y))
            candidate = tuple(int(min(255, (c[i] + COLOR_LIGHT[i] * sum * 0.35) * (1 + sum * 0.25)) * dark) for i in range(3))
            img.putpixel((x, y), candidate + (255,))


def background():
    rnd = random.Random(7)
    img = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 255))
    parede(img, rnd)
    galeria(img, rnd)
    janela(img, rnd, JANELA)
    estante(img, 30, 72, 42, rnd)
    estante(img, 86, 128, 42, rnd)
    fireplace(img, rnd)
    for x in PILARES:
        pilar(img, x)
    estandarte(img, 276, 40)
    estandarte(img, 364, 40)
    for x, y in TORCHES:
        suporte_tocha(img, x, y)
    floor(img, rnd)
    # tapete vermelho até a porta da dungeon e o da lareira
    tapete(img, ARCO, PAREDE + 4, PAREDE + 40, 30, 40, (110, 30, 40, 255), GOLD, (150, 50, 56, 255))
    tapete(img, FIREPLACE[0], PAREDE + 4, PAREDE + 24, 24, 30, (110, 76, 40, 255), (70, 46, 26, 255), (140, 100, 56, 255))
    iluminar(img)
    return img


# --------------------------------------------------------------------- móveis
def table(w=44):
    img = Image.new("RGBA", (w + 2, 22), (0, 0, 0, 0))
    ret(img, 1, 2, w + 1, 7, MADEIRA_LIGHT)            # tampo visto de cima
    for x in range(1, w + 1, 9):
        ret(img, x, 2, x + 1, 7, MADEIRA)                # tábuas
    ret(img, 1, 7, w + 1, 10, MADEIRA)                 # borda da frente
    ret(img, 1, 9, w + 1, 10, MADEIRA_ESCURA)
    for x in (3, w - 3):
        ret(img, x, 10, x + 3, 21, MADEIRA_ESCURA)       # pernas
        ret(img, x, 10, x + 1, 21, MADEIRA)
    ret(img, 5, 16, w - 3, 17, MADEIRA_ESCURA)         # travessa
    # vela acesa, caneca e livro
    ret(img, 10, 0, 12, 4, (230, 220, 190, 255))
    ret(img, 9, 4, 13, 5, GOLD_DARK)
    ret(img, w - 12, 2, w - 8, 6, IRON_LIGHT)
    px(img, w - 8, 3, IRON_LIGHT)
    ret(img, w // 2 - 3, 4, w // 2 + 4, 6, (120, 40, 44, 255))
    ret(img, w // 2 - 3, 4, w // 2 + 4, 5, (230, 220, 200, 255))
    return contornar(img)


def bench(w=36):
    img = Image.new("RGBA", (w + 2, 11), (0, 0, 0, 0))
    ret(img, 1, 1, w + 1, 4, MADEIRA_LIGHT)
    ret(img, 1, 4, w + 1, 5, MADEIRA)
    for x in (3, w - 3):
        ret(img, x, 5, x + 3, 10, MADEIRA_ESCURA)
    return contornar(img)


def stool():
    img = Image.new("RGBA", (10, 10), (0, 0, 0, 0))
    ret(img, 1, 1, 9, 4, MADEIRA_LIGHT)
    ret(img, 1, 3, 9, 4, MADEIRA)
    ret(img, 2, 4, 4, 9, MADEIRA_ESCURA)
    ret(img, 6, 4, 8, 9, MADEIRA_ESCURA)
    return contornar(img)


def barrel():
    img = Image.new("RGBA", (14, 18), (0, 0, 0, 0))
    for y in range(1, 17):
        bojo = 1 if 4 <= y <= 13 else 0
        for x in range(2 - bojo, 12 + bojo):
            s = x - 1
            c = MADEIRA_LIGHT if s < 4 else MADEIRA if s < 8 else MADEIRA_ESCURA
            px(img, x, y, c)
    for y in (3, 13):
        ret(img, 1, y, 13, y + 1, IRON)
    ret(img, 2, 1, 12, 2, (150, 104, 66, 255))
    return contornar(img)


def crate():
    img = Image.new("RGBA", (18, 16), (0, 0, 0, 0))
    ret(img, 1, 1, 17, 15, MADEIRA)
    ret(img, 1, 1, 17, 3, MADEIRA_LIGHT)
    for x in (1, 16):
        ret(img, x, 1, x + 1, 15, MADEIRA_ESCURA)
    for i in range(12):  # tábua em diagonal
        px(img, 3 + i, 3 + i * 11 // 12, MADEIRA_ESCURA)
    ret(img, 1, 8, 17, 9, MADEIRA_ESCURA)
    return contornar(img)


def vase():
    img = Image.new("RGBA", (16, 24), (0, 0, 0, 0))
    rnd = random.Random(5)
    folhas = [(64, 120, 60, 255), (90, 150, 70, 255), (46, 90, 50, 255)]
    for _ in range(70):
        a = rnd.uniform(math.pi * 1.05, math.pi * 1.95)
        r = rnd.uniform(1, 8)
        x = int(8 + math.cos(a) * r * 0.9)
        y = int(12 + math.sin(a) * r * 1.2)
        px(img, x, y, rnd.choice(folhas))
    for y in range(13, 23):
        half = 4 if y < 15 else 3
        for x in range(8 - half, 8 + half):
            c = (170, 90, 60, 255) if x < 8 else (130, 66, 46, 255)
            px(img, x, y, c)
    ret(img, 3, 13, 13, 15, (190, 110, 76, 255))
    return contornar(img)


def brazier():
    img = Image.new("RGBA", (14, 24), (0, 0, 0, 0))
    ret(img, 1, 2, 13, 5, IRON)                       # bacia
    ret(img, 2, 5, 12, 7, IRON_DARK)
    ret(img, 1, 2, 13, 3, IRON_LIGHT)
    ret(img, 3, 1, 11, 2, (255, 170, 70, 255))         # brasa
    ret(img, 6, 7, 8, 21, IRON_DARK)                # haste
    ret(img, 6, 7, 7, 21, IRON)
    ret(img, 3, 21, 11, 23, IRON)                     # pé
    ret(img, 2, 23, 12, 24, IRON_DARK)
    return contornar(img)


# ---------------------------------------------------------------------- porta
RUNES = [
    ["x.x", ".x.", "x.x"], ["xxx", "x..", "xxx"], [".x.", "xxx", ".x."], ["x..", "xx.", "x.x"],
    ["xx.", "x.x", "xx."], ["x.x", "xxx", "x.x"], [".xx", "x..", ".xx"], ["xxx", ".x.", ".x."],
]


def door():
    """Arco de pedra antiga com portas de metal escuro e runas.
    Devolve (porta, runas): a segunda só com os pixels das runas, para o jogo
    acender por cima."""
    w, h = 60, 86
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    runes = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cx, top, r_in, r_out = w // 2, 34, 18, 27
    rnd = random.Random(11)
    # moldura em blocos de pedra
    for y in range(top - r_out, h - 4):
        for x in range(w):
            d = math.hypot(x - cx + 0.5, y - top) if y < top else abs(x - cx + 0.5)
            if r_in < d <= r_out:
                if y < top:
                    block = int((math.degrees(math.atan2(top - y, x - cx + 0.5)) + 3) // 18)
                else:
                    block = (y - top) // 9 + (0 if x < cx else 1)
                v = 78 + (8 if block % 2 else 0) + rnd.randint(-2, 2)
                color = (v, v + 4, v + 24, 255)
                if d > r_out - 1.2:
                    color = tom(color, 0.75)
                if d < r_in + 1.5:
                    color = tom(color, 1.2)
                px(img, x, y, color)
    # portas de metal escuro
    for y in range(top - r_in, h - 4):
        for x in range(w):
            d = math.hypot(x - cx + 0.5, y - top) if y < top else abs(x - cx + 0.5)
            if d <= r_in:
                band = (y - (top - r_in)) % 12 in (0, 1)
                color = IRON if band else IRON_DARK
                if x in (cx - 1, cx):
                    color = (18, 18, 26, 255)  # junção das duas folhas
                px(img, x, y, color)
                if band and (x - cx) % 5 == 2:
                    px(img, x, y, IRON_LIGHT)  # rebites
    # argolas
    for ax in (cx - 5, cx + 4):
        for a in range(0, 360, 30):
            px(img, ax + round(2.5 * math.cos(math.radians(a))), 60 + round(2.5 * math.sin(math.radians(a))), GOLD_DARK)
    # símbolo no alto das portas: um olho dentro de um anel
    for a in range(0, 360, 20):
        x = cx + round(6 * math.cos(math.radians(a))) - 1
        y = top - 6 + round(6 * math.sin(math.radians(a)))
        px(img, x, y, RUNE_APAGADA)
        px(runes, x, y, RUNE)
    for x in range(cx - 4, cx + 3):
        dy = 2 - abs(x - cx + 0.5) // 2
        for y in (top - 6 - int(dy), top - 6 + int(dy)):
            px(img, x, y, RUNE_APAGADA)
            px(runes, x, y, RUNE)
    px(img, cx - 1, top - 6, RUNE); px(img, cx, top - 6, RUNE)
    px(runes, cx - 1, top - 6, (255, 255, 255, 255)); px(runes, cx, top - 6, (255, 255, 255, 255))
    # runas entalhadas na moldura: descendo pelos dois lados
    i = 0
    for side in (cx - 23, cx + 20):
        for y in range(top + 2, h - 10, 6):
            for j, line in enumerate(RUNES[i % len(RUNES)]):
                for k, c in enumerate(line):
                    if c == "x":
                        px(img, side + k, y + j, RUNE_APAGADA)
                        px(runes, side + k, y + j, RUNE)
            i += 1
    # e pelo arco
    for ang in range(20, 170, 22):
        rx = cx + round(22.5 * math.cos(math.radians(ang))) - 1
        ry = top - round(22.5 * math.sin(math.radians(ang))) - 1
        for j, line in enumerate(RUNES[i % len(RUNES)]):
            for k, c in enumerate(line):
                if c == "x":
                    px(img, rx + k, ry + j, RUNE_APAGADA)
                    px(runes, rx + k, ry + j, RUNE)
        i += 1
    # degrau de pedra na frente
    ret(img, 2, h - 4, w - 2, h - 1, (96, 102, 132, 255))
    ret(img, 2, h - 4, w - 2, h - 3, (124, 132, 166, 255))
    return contornar(img), runes


if __name__ == "__main__":
    save(background(), "hall.png")
    save(table(), "table.png")
    save(table(28), "small_table.png")
    save(bench(), "bench.png")
    save(stool(), "stool.png")
    save(barrel(), "barrel.png")
    save(crate(), "crate.png")
    save(vase(), "vase.png")
    save(brazier(), "brazier.png")
    p, r = door()
    save(p, "dungeon_door.png")
    save(r, "door_runes.png")

"""Gera a arte provisória do protótipo: inimigos de teste (construtos, o golem
de pedra e o elemental de fogo), cenário, a onda do Engo-ji e o ícone da
passiva da Shumi (Limite Humano).

Uso: python3 tools/generate_placeholder_art.py  (a partir da pasta Torre)
"""
import math
import os
import random

from PIL import Image

from pixel_icon import icon

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

OUTLINE = (20, 22, 34, 255)
STONE_ESCURA = (58, 64, 88, 255)
STONE = (84, 92, 122, 255)
STONE_LIGHT = (118, 128, 160, 255)
RACHADURA = (36, 40, 58, 255)
BRANCO = (255, 255, 255, 255)
ROXO_DARK = (119, 71, 142, 255)
ROXO = (161, 96, 193, 255)
ROXO_LIGHT = (195, 117, 234, 255)


def save(img, *path):
    destination = os.path.join(ROOT, *path)
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


def construto(size, olho, olho_light, semente):
    """Construto de pedra flutuante, olhando para a esquerda."""
    rnd = random.Random(semente)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cx, cy = size / 2, size * 0.45
    rx, ry = size * 0.36, size * 0.34
    for y in range(size):
        for x in range(size):
            nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            d = nx * nx + ny * ny
            if d <= 1:
                light = -nx * 0.5 - ny * 0.7  # luz vindo de cima/esquerda
                color = STONE_LIGHT if light > 0.45 else STONE if light > -0.35 else STONE_ESCURA
                img.putpixel((x, y), color)
    # rachaduras
    for _ in range(2):
        x, y = int(cx + rnd.uniform(-rx * 0.3, rx * 0.5)), int(cy - ry * 0.7)
        for _ in range(int(size * 0.3)):
            if img.getpixel((x, y))[3]:
                img.putpixel((x, y), RACHADURA)
            x += rnd.choice((-1, 0, 1))
            y += 1
    # olho de cristal no lado esquerdo
    ox, oy = int(cx - rx * 0.45), int(cy - ry * 0.05)
    r = max(2, size // 12)
    for y in range(oy - r, oy + r + 1):
        for x in range(ox - r, ox + r + 1):
            if (x - ox) ** 2 + (y - oy) ** 2 <= r * r + 1:
                img.putpixel((x, y), olho)
    img.putpixel((ox - 1, oy - 1), olho_light)
    img.putpixel((ox, oy - 1), BRANCO)
    # fragmentos flutuando embaixo
    base_y = int(cy + ry + 2)
    for fx in (int(cx - rx * 0.5), int(cx + rx * 0.1), int(cx + rx * 0.6)):
        fy = base_y + rnd.randint(0, 2)
        for i in range(2):
            for j in range(2):
                if fy + j < size:
                    img.putpixel((fx + i, fy + j), STONE if (i + j) else STONE_LIGHT)
    return contornar(img)


def golem(size, semente):
    """Golem de pedra em blocos, olhando para a esquerda: tronco largo, braços
    pesados até o chão e placas de ferro negro (o Ferro Negro do andar 5)."""
    rnd = random.Random(semente)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    iron, iron_light = (34, 34, 44, 255), (70, 72, 88, 255)
    ember, ember_light = (255, 120, 40, 255), (255, 210, 120, 255)

    def block(x0, y0, x1, y1):
        for y in range(y0, y1):
            for x in range(x0, x1):
                # luz de cima/esquerda: borda clara em cima e à esquerda
                light = (y - y0) / max(1, y1 - y0) * 0.7 + (x - x0) / max(1, x1 - x0) * 0.3
                color = STONE_LIGHT if light < 0.22 else STONE if light < 0.7 else STONE_ESCURA
                img.putpixel((x, y), color)

    u = size / 56
    r = lambda v: int(round(v * u))
    block(r(16), r(22), r(40), r(42))  # tronco
    block(r(19), r(10), r(33), r(22))  # cabeça, puxada para a frente (esquerda)
    block(r(6), r(20), r(17), r(34))  # ombro e braço da frente
    block(r(4), r(34), r(16), r(46))  # punho da frente
    block(r(39), r(21), r(49), r(33))  # braço de trás
    block(r(40), r(33), r(50), r(43))  # punho de trás
    block(r(18), r(42), r(26), r(53))  # pernas
    block(r(30), r(42), r(38), r(53))
    # placas de ferro negro no peito e nos ombros
    for x0, y0, x1, y1 in ((r(20), r(25), r(36), r(29)), (r(7), r(20), r(16), r(23)), (r(40), r(21), r(48), r(24))):
        for y in range(y0, y1):
            for x in range(x0, x1):
                img.putpixel((x, y), iron_light if y == y0 else iron)
    # núcleo em brasa no peito e olhos acesos
    cx, cy = r(28), r(34)
    for y in range(cy - 2, cy + 3):
        for x in range(cx - 2, cx + 3):
            if abs(x - cx) + abs(y - cy) <= 2:
                img.putpixel((x, y), ember_light if abs(x - cx) + abs(y - cy) == 0 else ember)
    for ox in (r(21), r(26)):
        img.putpixel((ox, r(15)), ember_light)
        img.putpixel((ox + 1, r(15)), ember)
    # rachaduras
    for _ in range(4):
        x, y = rnd.randint(r(17), r(38)), rnd.randint(r(30), r(36))
        for _ in range(r(6)):
            if 0 <= x < size and 0 <= y < size and img.getpixel((x, y)) in (STONE, STONE_LIGHT, STONE_ESCURA):
                img.putpixel((x, y), RACHADURA)
            x += rnd.choice((-1, 0, 1))
            y += 1
    return contornar(img)


def elemental_fire(size, semente):
    """Chama viva com olhos, flutuando e olhando para a esquerda."""
    rnd = random.Random(semente)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    layers = ((180, 40, 20, 255), (240, 95, 30, 255), (255, 170, 50, 255), (255, 235, 150, 255))
    cx, base = size / 2, size * 0.82
    for y in range(size):
        for x in range(size):
            # gota: larga embaixo, afinando numa ponta que ondula para a direita
            t = (base - y) / (size * 0.72)  # 0 na base, 1 na ponta
            if t < -0.18 or t > 1:
                continue
            if t < 0:
                half = size * 0.3 * math.sqrt(max(0.0, 1 - (t / 0.18) ** 2))
            else:
                # labaredas: a largura ondula, mais forte perto da ponta
                half = size * 0.32 * (1 - t) ** 0.7 * (1 + 0.28 * t * math.sin(t * 11 + 1))
            center = cx + math.sin(t * 4.0) * size * 0.12 * t
            d = abs(x + 0.5 - center) / max(0.5, half)
            if d > 1:
                continue
            calor = (1 - d) * 0.75 + (1 - max(t, 0)) * 0.35 + rnd.uniform(-0.06, 0.06)
            i = 3 if calor > 0.85 else 2 if calor > 0.6 else 1 if calor > 0.35 else 0
            img.putpixel((x, y), layers[i])
    # brasas soltas acima da ponta
    for _ in range(3):
        x, y = int(cx + rnd.uniform(-size * 0.15, size * 0.2)), int(size * rnd.uniform(0.02, 0.12))
        img.putpixel((x, y), layers[2])
    # olhos escuros no lado esquerdo
    oy = int(base - size * 0.18)
    for ox in (int(cx - size * 0.17), int(cx - size * 0.02)):
        for i in range(2):
            for j in range(3):
                img.putpixel((ox + i, oy + j), OUTLINE)
        img.putpixel((ox, oy), BRANCO)
    return contornar(img)


def half_lua(r):
    size = r * 2 + 4
    img = Image.new("RGBA", (r + 4, size), (0, 0, 0, 0))
    cx, cy = 1, size // 2
    for camada, (color, ang) in enumerate(((ROXO_DARK, 70), (ROXO, 62), (ROXO_LIGHT, 50), (BRANCO, 35))):
        for a in range(-ang, ang + 1):
            rad = math.radians(a)
            x = round(cx + (r - camada) * math.cos(rad))
            y = round(cy + (r - camada) * math.sin(rad))
            if 0 <= x < img.width and 0 <= y < img.height:
                img.putpixel((x, y), color)
    return img


def scenario(w=320, h=180):
    """Interior da torre: parede de tijolos, janelas, pilares e piso."""
    rnd = random.Random(3)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    floor = 118
    for y in range(floor):
        for x in range(w):
            line_tij = y // 8
            desloc = 8 if line_tij % 2 else 0
            junta = y % 8 == 0 or (x + desloc) % 16 == 0
            base = 34 + rnd.randint(-2, 2)
            if junta:
                color = (22, 22, 34)
            else:
                color = (base, base + 2, base + 16)
            # escurece em direção ao topo
            f = 0.55 + 0.45 * (y / floor)
            img.putpixel((x, y), tuple(int(c * f) for c in color) + (255,))
    # janelas em arco com céu roxo
    for jx in (60, 160, 260):
        for y in range(20, 70):
            for x in range(jx - 12, jx + 12):
                inside = y >= 32 or (x - jx) ** 2 + (y - 32) ** 2 <= 144
                if inside:
                    t = (y - 20) / 50
                    color = (int(40 + 60 * t), int(20 + 20 * t), int(80 + 40 * t), 255)
                    if rnd.random() < 0.02:
                        color = (230, 220, 255, 255)
                    img.putpixel((x, y), color)
        for y in range(19, 71):
            for x in (jx - 13, jx + 12):
                if y >= 32:
                    img.putpixel((x, y), (16, 16, 26, 255))
        for x in range(jx - 13, jx + 13):
            img.putpixel((x, 70), (60, 58, 80, 255))
    # pilares
    for px in (10, 110, 210, 310):
        for y in range(floor):
            for x in range(px - 6, px + 6):
                if 0 <= x < w:
                    shadow = x - (px - 6)
                    v = 50 + (12 - abs(shadow - 4) * 3)
                    img.putpixel((x, y), (v, v + 2, v + 14, 255))
    # piso em placas com perspectiva simples (linhas convergindo para o centro)
    for y in range(floor, h):
        prof = (y - floor + 1) / (h - floor)
        scale_factor = 0.25 + prof
        for x in range(w):
            world_x = (x - w / 2) / scale_factor
            world_z = 1 / scale_factor
            junta = abs(world_x) % 40 < 1.2 / scale_factor or (world_z * 12) % 6 < 0.9
            v = int(40 + 30 * prof) + rnd.randint(-2, 2)
            color = (v - 12, v - 10, v + 4) if junta else (v, v + 2, v + 14)
            img.putpixel((x, y), color + (255,))
    for x in range(w):
        img.putpixel((x, floor), (14, 14, 22, 255))
    return img


# Limite Humano: coração vermelho com a faísca de energia que a passiva
# devolve (desenho 11x11 no padrão de pixel_icon.py, o dos ícones da Shumi).
HUMAN_LIMIT_ICON = ({"r": (150, 20, 30, 255), "R": (225, 45, 45, 255), "l": (255, 130, 120, 255),
                        "y": (255, 220, 60, 255), "w": (255, 250, 220, 255)}, [
    "...........",
    ".rrr...rrr.",
    "rRllr.rRRRr",
    "rRlRRrRRyRr",
    "rRRRRRRyyRr",
    "rRRRRRyywRr",
    ".rRRRyywyr.",
    "..rRRRyyr..",
    "...rRRyr...",
    "....rRr....",
    ".....r.....",
])

# Bang!: a mão em "arma de dedo" e a faísca de ki vermelha do Finger Beam.
BANG_ICON = ({"d": (150, 90, 60, 255), "s": (235, 185, 145, 255), "l": (255, 222, 192, 255),
               "r": (230, 50, 45, 255), "w": (255, 250, 230, 255)}, [
    "........r..",
    ".dd....rwr.",
    ".dld....r..",
    ".dsdddddd..",
    "dssllllllsd",
    "dssssssdd..",
    "dsssssd....",
    "dsssssd....",
    ".dssssd....",
    "..dddd.....",
    "...........",
])


if __name__ == "__main__":
    save(construto(32, (90, 220, 255, 255), (190, 245, 255, 255), 1), "enemies", "sentinel.png")
    save(construto(48, (230, 70, 160, 255), (255, 180, 220, 255), 2), "enemies", "guardian.png")
    save(golem(56, 4), "enemies", "stone_golem.png")
    save(elemental_fire(30, 5), "enemies", "fire_elemental.png")
    save(half_lua(14), "characters", "shumi", "engo_ji_wave.png")
    save(scenario(), "tower", "floor_background.png")
    save(icon(*HUMAN_LIMIT_ICON), "characters", "shumi", "icon_human_limit.png")
    save(icon(*BANG_ICON), "characters", "shumi", "icon_bang.png")

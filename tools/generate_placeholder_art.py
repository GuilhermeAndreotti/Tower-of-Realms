"""Gera a arte provisória do protótipo: inimigos de teste (construtos, o golem
de pedra nas duas formas e o elemental de fogo), cenários (o comum e a forja), a onda do Engo-ji e o ícone da
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


# Pedra do Golem: seis tons do mais escuro ao mais claro, e a lava da forma
# incandescente (do vermelho escuro ao quase branco).
GOLEM_STONE = ((30, 30, 38, 255), (48, 48, 58, 255), (68, 67, 76, 255), (92, 90, 96, 255),
               (120, 117, 118, 255), (152, 147, 142, 255))
LAVA = ((130, 34, 14, 255), (222, 84, 24, 255), (255, 160, 52, 255), (255, 232, 160, 255))
LIGHT = (-0.55, -0.65, 0.52)  # de cima, à esquerda e da frente


def golem(size, semente, molten=False):
    """Golem de pedras empilhadas, olhando para a esquerda: cada pedra é uma
    superelipse sombreada como um volume (luz de cima/esquerda, grão e sombra
    onde encosta na de trás), com braços pesados até o chão. Incandescente
    (depois de absorver os Elementais de Fogo), a pedra escurece, as
    rachaduras viram lava e saem brasas da cabeça e dos ombros."""
    rnd = random.Random(semente)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    u = size / 64
    norm = math.sqrt(sum(c * c for c in LIGHT))
    lx, ly, lz = (c / norm for c in LIGHT)
    grain = {}

    def rock(cx, cy, rx, ry, shade=0.0):
        cx, cy, rx, ry = cx * u, cy * u, rx * u, ry * u
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if not (0 <= x < size and 0 <= y < size):
                    continue
                nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                # superelipse: mais quadrada que um círculo, como pedra lascada
                d = abs(nx) ** 2.6 + abs(ny) ** 2.6
                if d > 1:
                    continue
                nz = math.sqrt(max(0.0, 1 - min(1.0, nx * nx + ny * ny)))
                light = max(0.0, nx * lx + ny * ly + nz * lz)
                v = 0.15 + 0.85 * light + grain.setdefault((x, y), rnd.uniform(-0.09, 0.09)) + shade
                if molten:
                    v -= 0.14
                # borda de uma pedra por cima de outra: sombra de contato
                if d > 0.78 and img.getpixel((x, y))[3]:
                    v -= 0.3
                img.putpixel((x, y), GOLEM_STONE[max(0, min(len(GOLEM_STONE) - 1, int(v * len(GOLEM_STONE))))])

    # de trás para a frente
    rock(47, 24, 8, 7, -0.12)  # ombro de trás
    rock(50, 35, 6, 8, -0.15)  # braço de trás
    rock(50, 46, 7, 6, -0.12)  # punho de trás
    rock(37, 53, 6, 8, -0.08)  # perna de trás
    rock(39, 59, 8, 4, -0.08)
    rock(24, 53, 6, 8)  # perna da frente
    rock(22, 59, 8, 4)
    rock(31, 44, 12, 6)  # quadril
    rock(32, 31, 15, 12)  # tronco
    rock(26, 23, 9, 5)  # peito alto, puxado para a frente
    rock(25, 14, 7, 6)  # cabeça, baixa e para a frente
    rock(14, 23, 9, 8)  # ombro da frente
    rock(12, 35, 7, 9)  # braço da frente
    rock(12, 48, 9, 7)  # punho da frente
    # lascas no ombro e nas costas quebram a silhueta
    rock(9, 17, 4, 3)
    rock(41, 19, 5, 4, -0.05)

    body = {(x, y) for y in range(size) for x in range(size) if img.getpixel((x, y))[3]}
    cells = sorted(body)
    # rachaduras: frestas escuras no Golem frio, lava no incandescente
    cracks = []
    for _ in range(15 if molten else 9):
        x, y = rnd.choice(cells)
        for _ in range(int(rnd.randint(5, 10) * u)):
            if (x, y) in body and y > 10 * u:
                cracks.append((x, y))
            x += rnd.choice((-1, 0, 1))
            y += rnd.choice((0, 1, 1))
    for x, y in cracks:
        if not molten:
            img.putpixel((x, y), GOLEM_STONE[0])
            continue
        img.putpixel((x, y), LAVA[2 if rnd.random() < 0.6 else 3])
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            p = (x + dx, y + dy)
            if p in body and p not in cracks and img.getpixel(p) in GOLEM_STONE[:3]:
                img.putpixel(p, LAVA[0])
    # núcleo no peito (uma brasa fraca, ou a fornalha acesa) e olhos
    cx, cy = int(29 * u), int(31 * u)
    reach = 3 if molten else 2
    for y in range(cy - reach, cy + reach + 1):
        for x in range(cx - reach, cx + reach + 1):
            d = abs(x - cx) + abs(y - cy)
            if d <= reach:
                img.putpixel((x, y), LAVA[3 - d] if molten else (GOLEM_STONE[1], LAVA[0], LAVA[1])[2 - d])
    for ox in (int(21 * u), int(25 * u)):
        img.putpixel((ox, int(14 * u)), LAVA[3] if molten else LAVA[2])
        img.putpixel((ox + 1, int(14 * u)), LAVA[1])
    img = contornar(img)
    if molten:
        # brasas subindo da cabeça e dos ombros
        for bx, by, h in ((24, 8, 4), (27, 7, 3), (10, 14, 3), (42, 15, 3), (46, 16, 2)):
            x, y = int(bx * u), int(by * u)
            for k in range(h):
                if 0 <= y - k < size:
                    img.putpixel((x + (k % 2 if k > 1 else 0), y - k), LAVA[3 - min(3, k + 1)] if k else LAVA[2])
        for _ in range(6):
            img.putpixel((rnd.randint(int(6 * u), int(50 * u)), rnd.randint(0, int(6 * u))), LAVA[rnd.choice((1, 2))])
    return img


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


def forge(w=320, h=180):
    """Forja de Pedra (andar 5): parede de blocos escuros iluminada de baixo
    pela fornalha no meio, um canal de lava no pé da parede, pilares com
    cintas de ferro, correntes e brasas no ar. Piso e altura do chão iguais
    aos do cenário comum, para os lutadores pisarem no mesmo lugar."""
    rnd = random.Random(5)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    floor = 118
    furnace_x, furnace_top, furnace_half = 160, 44, 34

    def glow(x, y):
        """Quanto a fornalha e o canal de lava iluminam o ponto (0..1)."""
        d = math.hypot((x - furnace_x) / 1.4, y - 95)
        return max(0.0, 1 - d / 150) * 0.8 + max(0.0, 1 - (floor - y) / 60) * 0.35

    # parede de blocos grandes, irregulares, esquentando perto do fogo
    for y in range(floor):
        for x in range(w):
            row = y // 12
            offset = (row * 11) % 24
            joint = y % 12 == 0 or (x + offset) % 24 == 0
            base = 26 + rnd.randint(-2, 2)
            g = glow(x, y)
            if joint:
                color = (14 + int(20 * g), 12 + int(6 * g), 14)
            else:
                color = (base + int(70 * g), base - 2 + int(26 * g), base + 4 - int(6 * g))
            img.putpixel((x, y), color + (255,))
    # fornalha: arco de tijolos com a boca em brasa e a coifa por cima
    for y in range(furnace_top - 26, floor):
        for x in range(furnace_x - furnace_half - 8, furnace_x + furnace_half + 8):
            dx = x - furnace_x
            arch = y >= furnace_top + 18 or dx * dx + (y - furnace_top - 18) ** 2 <= (furnace_half + 8) ** 2
            if y < furnace_top - 2 and abs(dx) <= furnace_half - 6 + (y - furnace_top + 26) // 2:
                v = 30 + rnd.randint(-2, 2)  # coifa de ferro
                img.putpixel((x, y), (v, v, v + 6, 255))
            elif arch:
                mouth = y >= furnace_top + 30 or dx * dx + (y - furnace_top - 30) ** 2 <= (furnace_half - 6) ** 2
                if mouth and abs(dx) < furnace_half - 6 and y < floor - 6:
                    t = (y - furnace_top) / (floor - furnace_top)
                    heat = 1 - abs(dx) / furnace_half * 0.6 + rnd.uniform(-0.12, 0.12)
                    i = 3 if heat * t > 0.8 else 2 if heat * t > 0.5 else 1 if heat > 0.75 else 0
                    img.putpixel((x, y), LAVA[i])
                else:
                    brick = (y // 5 + (x + (y // 5) * 3) // 7) % 2
                    v = 58 + 10 * brick + rnd.randint(-3, 3)
                    img.putpixel((x, y), (v + 30, v - 8, v - 18, 255))
    # pilares de pedra com cintas de ferro
    for px in (10, 90, 230, 310):
        for y in range(floor):
            for x in range(px - 7, px + 7):
                if 0 <= x < w:
                    v = 46 + (12 - abs(x - (px - 3)) * 3) + int(30 * glow(x, y))
                    band = y % 34 in (8, 9, 10)
                    img.putpixel((x, y), (24, 24, 30, 255) if band else (v + 6, v, v - 4, 255))
    # correntes penduradas
    for cx, length in ((52, 50), (128, 34), (196, 40), (272, 56)):
        for y in range(0, length):
            if y % 4 != 3:
                img.putpixel((cx + (y // 4) % 2, y), (70, 64, 62, 255))
        for x in range(cx - 3, cx + 5):
            img.putpixel((x, length), (90, 84, 80, 255))
            img.putpixel((x, length + 1), (40, 36, 36, 255))
    # canal de lava no pé da parede
    for y in range(floor - 6, floor):
        for x in range(w):
            t = (y - floor + 6) / 6
            wave = math.sin(x * 0.21 + y) * 0.2 + rnd.uniform(-0.15, 0.15)
            i = max(0, min(3, int((0.15 + wave + 0.45 * (1 - t)) * 4)))
            img.putpixel((x, y), LAVA[i])
    # piso de lajes, quente perto do canal (mesma perspectiva do cenário comum)
    for y in range(floor, h):
        depth = (y - floor + 1) / (h - floor)
        scale_factor = 0.25 + depth
        heat = max(0.0, 1 - depth * 2.2)
        for x in range(w):
            world_x = (x - w / 2) / scale_factor
            world_z = 1 / scale_factor
            joint = abs(world_x) % 40 < 1.2 / scale_factor or (world_z * 12) % 6 < 0.9
            v = int(34 + 26 * depth) + rnd.randint(-2, 2)
            if joint:
                color = (v - 10 + int(60 * heat), v - 14 + int(16 * heat), v - 14)
            else:
                color = (v + int(40 * heat), v - 2 + int(14 * heat), v - 2)
            img.putpixel((x, y), color + (255,))
    for x in range(w):
        img.putpixel((x, floor), (40, 16, 8, 255))
    # brasas no ar
    for _ in range(40):
        x, y = rnd.randint(0, w - 1), rnd.randint(4, floor - 8)
        img.putpixel((x, y), LAVA[rnd.choice((1, 2, 2, 3))])
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
    save(golem(64, 4), "enemies", "stone_golem.png")
    save(golem(64, 4, molten=True), "enemies", "stone_golem_molten.png")
    save(elemental_fire(30, 5), "enemies", "fire_elemental.png")
    save(half_lua(14), "characters", "shumi", "engo_ji_wave.png")
    save(scenario(), "tower", "floor_background.png")
    save(forge(), "tower", "forge_background.png")
    save(icon(*HUMAN_LIMIT_ICON), "characters", "shumi", "icon_human_limit.png")
    save(icon(*BANG_ICON), "characters", "shumi", "icon_bang.png")

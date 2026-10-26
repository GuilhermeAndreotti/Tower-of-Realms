"""Gera a arte provisória do protótipo: inimigos de teste (construtos, o golem
de pedra e o elemental de fogo), cenário, a onda do Engo-ji e o ícone da
passiva da Shumi (Limite Humano).

Uso: python3 tools/generate_placeholder_art.py  (a partir da pasta Torre)
"""
import math
import os
import random

from PIL import Image

from pixel_icon import icone

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CONTORNO = (20, 22, 34, 255)
PEDRA_ESCURA = (58, 64, 88, 255)
PEDRA = (84, 92, 122, 255)
PEDRA_CLARA = (118, 128, 160, 255)
RACHADURA = (36, 40, 58, 255)
BRANCO = (255, 255, 255, 255)
ROXO_ESCURO = (119, 71, 142, 255)
ROXO = (161, 96, 193, 255)
ROXO_CLARO = (195, 117, 234, 255)


def salvar(img, *caminho):
    destino = os.path.join(RAIZ, *caminho)
    img.save(destino)
    print("ok:", destino)


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
                    out.putpixel((x, y), CONTORNO)
                    break
    return out


def construto(tam, olho, olho_claro, semente):
    """Construto de pedra flutuante, olhando para a esquerda."""
    rnd = random.Random(semente)
    img = Image.new("RGBA", (tam, tam), (0, 0, 0, 0))
    cx, cy = tam / 2, tam * 0.45
    rx, ry = tam * 0.36, tam * 0.34
    for y in range(tam):
        for x in range(tam):
            nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            d = nx * nx + ny * ny
            if d <= 1:
                luz = -nx * 0.5 - ny * 0.7  # luz vindo de cima/esquerda
                cor = PEDRA_CLARA if luz > 0.45 else PEDRA if luz > -0.35 else PEDRA_ESCURA
                img.putpixel((x, y), cor)
    # rachaduras
    for _ in range(2):
        x, y = int(cx + rnd.uniform(-rx * 0.3, rx * 0.5)), int(cy - ry * 0.7)
        for _ in range(int(tam * 0.3)):
            if img.getpixel((x, y))[3]:
                img.putpixel((x, y), RACHADURA)
            x += rnd.choice((-1, 0, 1))
            y += 1
    # olho de cristal no lado esquerdo
    ox, oy = int(cx - rx * 0.45), int(cy - ry * 0.05)
    r = max(2, tam // 12)
    for y in range(oy - r, oy + r + 1):
        for x in range(ox - r, ox + r + 1):
            if (x - ox) ** 2 + (y - oy) ** 2 <= r * r + 1:
                img.putpixel((x, y), olho)
    img.putpixel((ox - 1, oy - 1), olho_claro)
    img.putpixel((ox, oy - 1), BRANCO)
    # fragmentos flutuando embaixo
    base_y = int(cy + ry + 2)
    for fx in (int(cx - rx * 0.5), int(cx + rx * 0.1), int(cx + rx * 0.6)):
        fy = base_y + rnd.randint(0, 2)
        for i in range(2):
            for j in range(2):
                if fy + j < tam:
                    img.putpixel((fx + i, fy + j), PEDRA if (i + j) else PEDRA_CLARA)
    return contornar(img)


def golem(tam, semente):
    """Golem de pedra em blocos, olhando para a esquerda: tronco largo, braços
    pesados até o chão e placas de ferro negro (o Ferro Negro do andar 5)."""
    rnd = random.Random(semente)
    img = Image.new("RGBA", (tam, tam), (0, 0, 0, 0))
    ferro, ferro_claro = (34, 34, 44, 255), (70, 72, 88, 255)
    brasa, brasa_clara = (255, 120, 40, 255), (255, 210, 120, 255)

    def bloco(x0, y0, x1, y1):
        for y in range(y0, y1):
            for x in range(x0, x1):
                # luz de cima/esquerda: borda clara em cima e à esquerda
                luz = (y - y0) / max(1, y1 - y0) * 0.7 + (x - x0) / max(1, x1 - x0) * 0.3
                cor = PEDRA_CLARA if luz < 0.22 else PEDRA if luz < 0.7 else PEDRA_ESCURA
                img.putpixel((x, y), cor)

    u = tam / 56
    r = lambda v: int(round(v * u))
    bloco(r(16), r(22), r(40), r(42))  # tronco
    bloco(r(19), r(10), r(33), r(22))  # cabeça, puxada para a frente (esquerda)
    bloco(r(6), r(20), r(17), r(34))  # ombro e braço da frente
    bloco(r(4), r(34), r(16), r(46))  # punho da frente
    bloco(r(39), r(21), r(49), r(33))  # braço de trás
    bloco(r(40), r(33), r(50), r(43))  # punho de trás
    bloco(r(18), r(42), r(26), r(53))  # pernas
    bloco(r(30), r(42), r(38), r(53))
    # placas de ferro negro no peito e nos ombros
    for x0, y0, x1, y1 in ((r(20), r(25), r(36), r(29)), (r(7), r(20), r(16), r(23)), (r(40), r(21), r(48), r(24))):
        for y in range(y0, y1):
            for x in range(x0, x1):
                img.putpixel((x, y), ferro_claro if y == y0 else ferro)
    # núcleo em brasa no peito e olhos acesos
    cx, cy = r(28), r(34)
    for y in range(cy - 2, cy + 3):
        for x in range(cx - 2, cx + 3):
            if abs(x - cx) + abs(y - cy) <= 2:
                img.putpixel((x, y), brasa_clara if abs(x - cx) + abs(y - cy) == 0 else brasa)
    for ox in (r(21), r(26)):
        img.putpixel((ox, r(15)), brasa_clara)
        img.putpixel((ox + 1, r(15)), brasa)
    # rachaduras
    for _ in range(4):
        x, y = rnd.randint(r(17), r(38)), rnd.randint(r(30), r(36))
        for _ in range(r(6)):
            if 0 <= x < tam and 0 <= y < tam and img.getpixel((x, y)) in (PEDRA, PEDRA_CLARA, PEDRA_ESCURA):
                img.putpixel((x, y), RACHADURA)
            x += rnd.choice((-1, 0, 1))
            y += 1
    return contornar(img)


def elemental_fogo(tam, semente):
    """Chama viva com olhos, flutuando e olhando para a esquerda."""
    rnd = random.Random(semente)
    img = Image.new("RGBA", (tam, tam), (0, 0, 0, 0))
    camadas = ((180, 40, 20, 255), (240, 95, 30, 255), (255, 170, 50, 255), (255, 235, 150, 255))
    cx, base = tam / 2, tam * 0.82
    for y in range(tam):
        for x in range(tam):
            # gota: larga embaixo, afinando numa ponta que ondula para a direita
            t = (base - y) / (tam * 0.72)  # 0 na base, 1 na ponta
            if t < -0.18 or t > 1:
                continue
            if t < 0:
                meia = tam * 0.3 * math.sqrt(max(0.0, 1 - (t / 0.18) ** 2))
            else:
                # labaredas: a largura ondula, mais forte perto da ponta
                meia = tam * 0.32 * (1 - t) ** 0.7 * (1 + 0.28 * t * math.sin(t * 11 + 1))
            centro = cx + math.sin(t * 4.0) * tam * 0.12 * t
            d = abs(x + 0.5 - centro) / max(0.5, meia)
            if d > 1:
                continue
            calor = (1 - d) * 0.75 + (1 - max(t, 0)) * 0.35 + rnd.uniform(-0.06, 0.06)
            i = 3 if calor > 0.85 else 2 if calor > 0.6 else 1 if calor > 0.35 else 0
            img.putpixel((x, y), camadas[i])
    # brasas soltas acima da ponta
    for _ in range(3):
        x, y = int(cx + rnd.uniform(-tam * 0.15, tam * 0.2)), int(tam * rnd.uniform(0.02, 0.12))
        img.putpixel((x, y), camadas[2])
    # olhos escuros no lado esquerdo
    oy = int(base - tam * 0.18)
    for ox in (int(cx - tam * 0.17), int(cx - tam * 0.02)):
        for i in range(2):
            for j in range(3):
                img.putpixel((ox + i, oy + j), CONTORNO)
        img.putpixel((ox, oy), BRANCO)
    return contornar(img)


def meia_lua(r):
    tam = r * 2 + 4
    img = Image.new("RGBA", (r + 4, tam), (0, 0, 0, 0))
    cx, cy = 1, tam // 2
    for camada, (cor, ang) in enumerate(((ROXO_ESCURO, 70), (ROXO, 62), (ROXO_CLARO, 50), (BRANCO, 35))):
        for a in range(-ang, ang + 1):
            rad = math.radians(a)
            x = round(cx + (r - camada) * math.cos(rad))
            y = round(cy + (r - camada) * math.sin(rad))
            if 0 <= x < img.width and 0 <= y < img.height:
                img.putpixel((x, y), cor)
    return img


def cenario(w=320, h=180):
    """Interior da torre: parede de tijolos, janelas, pilares e piso."""
    rnd = random.Random(3)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    chao = 118
    for y in range(chao):
        for x in range(w):
            linha_tij = y // 8
            desloc = 8 if linha_tij % 2 else 0
            junta = y % 8 == 0 or (x + desloc) % 16 == 0
            base = 34 + rnd.randint(-2, 2)
            if junta:
                cor = (22, 22, 34)
            else:
                cor = (base, base + 2, base + 16)
            # escurece em direção ao topo
            f = 0.55 + 0.45 * (y / chao)
            img.putpixel((x, y), tuple(int(c * f) for c in cor) + (255,))
    # janelas em arco com céu roxo
    for jx in (60, 160, 260):
        for y in range(20, 70):
            for x in range(jx - 12, jx + 12):
                dentro = y >= 32 or (x - jx) ** 2 + (y - 32) ** 2 <= 144
                if dentro:
                    t = (y - 20) / 50
                    cor = (int(40 + 60 * t), int(20 + 20 * t), int(80 + 40 * t), 255)
                    if rnd.random() < 0.02:
                        cor = (230, 220, 255, 255)
                    img.putpixel((x, y), cor)
        for y in range(19, 71):
            for x in (jx - 13, jx + 12):
                if y >= 32:
                    img.putpixel((x, y), (16, 16, 26, 255))
        for x in range(jx - 13, jx + 13):
            img.putpixel((x, 70), (60, 58, 80, 255))
    # pilares
    for px_ in (10, 110, 210, 310):
        for y in range(chao):
            for x in range(px_ - 6, px_ + 6):
                if 0 <= x < w:
                    sombra = x - (px_ - 6)
                    v = 50 + (12 - abs(sombra - 4) * 3)
                    img.putpixel((x, y), (v, v + 2, v + 14, 255))
    # piso em placas com perspectiva simples (linhas convergindo para o centro)
    for y in range(chao, h):
        prof = (y - chao + 1) / (h - chao)
        escala = 0.25 + prof
        for x in range(w):
            mundo_x = (x - w / 2) / escala
            mundo_z = 1 / escala
            junta = abs(mundo_x) % 40 < 1.2 / escala or (mundo_z * 12) % 6 < 0.9
            v = int(40 + 30 * prof) + rnd.randint(-2, 2)
            cor = (v - 12, v - 10, v + 4) if junta else (v, v + 2, v + 14)
            img.putpixel((x, y), cor + (255,))
    for x in range(w):
        img.putpixel((x, chao), (14, 14, 22, 255))
    return img


# Limite Humano: coração vermelho com a faísca de energia que a passiva
# devolve (desenho 11x11 no padrão de pixel_icon.py, o dos ícones da Shumi).
ICONE_LIMITE_HUMANO = ({"r": (150, 20, 30, 255), "R": (225, 45, 45, 255), "l": (255, 130, 120, 255),
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
ICONE_BANG = ({"d": (150, 90, 60, 255), "s": (235, 185, 145, 255), "l": (255, 222, 192, 255),
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
    salvar(construto(32, (90, 220, 255, 255), (190, 245, 255, 255), 1), "enemies", "sentinel.png")
    salvar(construto(48, (230, 70, 160, 255), (255, 180, 220, 255), 2), "enemies", "guardian.png")
    salvar(golem(56, 4), "enemies", "stone_golem.png")
    salvar(elemental_fogo(30, 5), "enemies", "fire_elemental.png")
    salvar(meia_lua(14), "characters", "shumi", "engo_ji_wave.png")
    salvar(cenario(), "tower", "floor_background.png")
    salvar(icone(*ICONE_LIMITE_HUMANO), "characters", "shumi", "icon_human_limit.png")
    salvar(icone(*ICONE_BANG), "characters", "shumi", "icon_bang.png")

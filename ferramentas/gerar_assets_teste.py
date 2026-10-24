"""Gera a arte provisória do protótipo: inimigos de teste, cenário, a onda do
Engo-ji e o ícone da passiva da Shumi (Limite Humano).

Uso: python3 ferramentas/gerar_assets_teste.py  (a partir da pasta Torre)
"""
import math
import os
import random

from PIL import Image

from icone_pixel import icone

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
# devolve (desenho 11x11 no padrão de icone_pixel.py, o dos ícones da Shumi).
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
    salvar(construto(32, (90, 220, 255, 255), (190, 245, 255, 255), 1), "inimigos", "sentinela.png")
    salvar(construto(48, (230, 70, 160, 255), (255, 180, 220, 255), 2), "inimigos", "guardiao.png")
    salvar(meia_lua(14), "efeitos", "onda_engo_ji.png")
    salvar(cenario(), "cenarios", "torre_andar.png")
    salvar(icone(*ICONE_LIMITE_HUMANO), "personagens", "shumi", "icone_limite_humano.png")
    salvar(icone(*ICONE_BANG), "personagens", "shumi", "icone_bang.png")

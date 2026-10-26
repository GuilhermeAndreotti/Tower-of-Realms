"""Gera a logo do jogo (logo.png, na raiz): a torre ao lado de "TOWER OF REALMS",
em pixel art com a paleta da Torre (pedra fria, ouro e runas). Fundo transparente,
com contorno escuro, para ler bem em fundo claro e escuro.

Uso: python3 tools/generate_logo.py  (a partir da pasta Torre)
"""
import os

from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESTINO = os.path.join(RAIZ, "logo.png")
AMPLIACAO = 4  # a imagem final é a base em pixels x4

CONTORNO = (20, 22, 34, 255)
SOMBRA = (58, 30, 80, 255)
OURO_CLARO = (255, 226, 140, 255)
OURO = (232, 182, 92, 255)
OURO_ESCURO = (170, 110, 48, 255)
PEDRA_CLARA = (120, 116, 150, 255)
PEDRA = (88, 84, 116, 255)
PEDRA_ESCURA = (60, 56, 84, 255)
JANELA = (255, 196, 90, 255)
RUNA = (130, 230, 255, 255)

# Letras 5x7 ('#' = cheio).
FONTE = {
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
}


def px(img, x, y, cor):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), cor)


def texto(img, x0, y0, palavra, escala, espaco):
    """Letras com degradê de ouro (claro em cima, escuro embaixo)."""
    altura = 7 * escala
    x = x0
    for letra in palavra:
        if letra == " ":
            x += 3 * escala + espaco
            continue
        for ly, linha in enumerate(FONTE[letra]):
            for lx, ch in enumerate(linha):
                if ch != "#":
                    continue
                for dy in range(escala):
                    for dx in range(escala):
                        y = y0 + ly * escala + dy
                        t = (y - y0) / max(1, altura - 1)
                        cor = OURO_CLARO if t < 0.3 else (OURO if t < 0.7 else OURO_ESCURO)
                        px(img, x + lx * escala + dx, y, cor)
        x += 5 * escala + espaco
    return x


def largura(palavra, escala, espaco):
    return sum((3 if c == " " else 5) * escala + espaco for c in palavra) - espaco


def torre(img, x0, y0):
    """Torre de pedra com ameias, janelas acesas e uma runa na porta."""
    w, h = 22, 44
    # corpo em blocos de pedra
    for y in range(y0 + 6, y0 + h):
        for x in range(x0 + 2, x0 + w - 2):
            fileira = (y - y0) // 4
            junta = (y - y0) % 4 == 0 or (x - x0 + (fileira % 2) * 3) % 6 == 0
            cor = PEDRA_ESCURA if junta else (PEDRA_CLARA if x < x0 + 8 else PEDRA)
            px(img, x, y, cor)
    # ameias
    for i in range(4):
        bx = x0 + i * 6
        for y in range(y0, y0 + 7):
            for x in range(bx, bx + 4):
                px(img, x, y, PEDRA_CLARA if x < bx + 2 else PEDRA)
    # janelas acesas
    for jy in (y0 + 12, y0 + 22):
        for y in range(jy, jy + 5):
            for x in range(x0 + 9, x0 + 13):
                px(img, x, y, JANELA)
        px(img, x0 + 10, jy - 1, JANELA)
        px(img, x0 + 11, jy - 1, JANELA)
    # porta em arco com runa
    for y in range(y0 + 33, y0 + h):
        for x in range(x0 + 7, x0 + 15):
            if y == y0 + 33 and x in (x0 + 7, x0 + 14):
                continue
            px(img, x, y, CONTORNO)
    for y in (y0 + 36, y0 + 37, y0 + 38):
        px(img, x0 + 10, y, RUNA)
        px(img, x0 + 11, y, RUNA)
    px(img, x0 + 9, y0 + 37, RUNA)
    px(img, x0 + 12, y0 + 37, RUNA)
    # bandeira dourada no alto
    for y in range(y0 - 9, y0):
        px(img, x0 + 10, y, CONTORNO)
    for y in range(y0 - 9, y0 - 5):
        for x in range(x0 + 11, x0 + 11 + (y0 - 5 - y)):
            px(img, x, y, OURO)


def contornar(img, cor):
    """Contorno de 1px em volta de tudo que não é transparente."""
    base = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            if base.getpixel((x, y))[3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < img.width and 0 <= ny < img.height and base.getpixel((nx, ny))[3]:
                    img.putpixel((x, y), cor)
                    break


def sombra(img, cor):
    """Sombra 1px para baixo e para a direita, atrás do desenho."""
    base = img.copy()
    for y in range(img.height - 1, 0, -1):
        for x in range(img.width - 1, 0, -1):
            if not base.getpixel((x, y))[3] and base.getpixel((x - 1, y - 1))[3]:
                img.putpixel((x, y), cor)


def logo():
    l1, e1, s1 = "TOWER", 3, 3
    l2, e2, s2 = "OF REALMS", 2, 2
    largura_texto = max(largura(l1, e1, s1), largura(l2, e2, s2))
    w = 4 + 22 + 10 + largura_texto + 4
    h = 62
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    torre(img, 4, 13)
    tx = 4 + 22 + 10
    texto(img, tx + (largura_texto - largura(l1, e1, s1)) // 2, 10, l1, e1, s1)
    texto(img, tx + (largura_texto - largura(l2, e2, s2)) // 2, 10 + 7 * e1 + 7, l2, e2, s2)
    contornar(img, CONTORNO)
    sombra(img, SOMBRA)
    return img.resize((w * AMPLIACAO, h * AMPLIACAO), Image.NEAREST)


if __name__ == "__main__":
    logo().save(DESTINO)
    print("ok:", DESTINO)

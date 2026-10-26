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

from pixel_icon import icone

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PASTA = os.path.join(RAIZ, "characters", "askara")
ORIGINAL = os.path.join(PASTA, "askara.png")
ORIGINAIS = os.path.join(PASTA, "originals")

QUADRO = (32, 40)
DESLOCAMENTO = (3, 3)  # onde o original entra no quadro: pés em (16, 38)
CABECA = (2, 12)  # linhas da cabeça (chifres ao queixo) no original
DURACOES = {"idle": 280, "walk": 200, "conjurar": 90, "hurt": 150}

# Orbe vil que se forma ao lado dela ao conjurar (coordenadas do quadro).
ORBE = (27, 20)
ORBE_ESCURO = (120, 40, 180, 255)
ORBE_MEIO = (200, 120, 255, 255)
ORBE_CLARO = (255, 230, 255, 255)
CONTORNO = (28, 16, 36, 255)

# Invocações: altura final em pixels de sprite (a arena multiplica por 3) e
# se a arte precisa ser espelhada para olhar para os inimigos (direita).
INVOCACOES = {
    "diabrete": {"altura": 26, "espelhar": False},
    "emissario": {"altura": 26, "espelhar": False},
    "lilith": {"altura": 40, "espelhar": False},
    "shivara": {"altura": 42, "espelhar": False},
    "lorde_demonio": {"altura": 48, "espelhar": False},
    "lorde_luz": {"altura": 50, "espelhar": True},
}


def salvar(img, nome):
    destino = os.path.join(PASTA, nome)
    img.save(destino)
    print("ok:", destino)


# ----------------------------------------------------------------- folha
def no_quadro(corpo, dx=0, dy=0):
    q = Image.new("RGBA", QUADRO, (0, 0, 0, 0))
    q.alpha_composite(corpo, (DESLOCAMENTO[0] + dx, DESLOCAMENTO[1] + dy))
    return q


def respirando(corpo):
    """A cabeça desce 1px sobre a gola; o manto fica parado."""
    c = corpo.copy()
    topo, base = CABECA
    for y in range(base, topo - 1, -1):
        for x in range(c.width):
            p = corpo.getpixel((x, y))
            if p[3] or y + 1 <= base:
                c.putpixel((x, y + 1), p)
    for x in range(c.width):
        c.putpixel((x, topo), (0, 0, 0, 0))
    return c


def orbe(quadro, raio):
    """Losango de energia vil em ORBE, do tamanho `raio` (0 = um ponto)."""
    cx, cy = ORBE
    for dy in range(-raio - 1, raio + 2):
        for dx in range(-raio - 1, raio + 2):
            d = abs(dx) + abs(dy)
            if d > raio + 1:
                continue
            cor = ORBE_CLARO if d == 0 else ORBE_MEIO if d <= raio else ORBE_ESCURO
            x, y = cx + dx, cy + dy
            if 0 <= x < QUADRO[0] and 0 <= y < QUADRO[1]:
                quadro.putpixel((x, y), cor)
    return quadro


def clarear(img, quanto):
    c = img.copy()
    px = c.load()
    for y in range(c.height):
        for x in range(c.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (min(255, r + quanto), min(255, g + quanto), min(255, b + quanto), a)
    return c


def gerar_folha(corpo):
    anims = {
        "idle": [no_quadro(corpo), no_quadro(corpo), no_quadro(respirando(corpo)), no_quadro(respirando(corpo))],
        # o manto arrasta no chão: o corpo não pula, só a cabeça balança
        "walk": [no_quadro(corpo), no_quadro(respirando(corpo)), no_quadro(corpo), no_quadro(respirando(corpo))],
        # ela se ergue e a orbe cresce até estourar
        "conjurar": [orbe(no_quadro(corpo, dy=-1), 0), orbe(no_quadro(corpo, dy=-1), 1),
                     orbe(no_quadro(corpo, dy=-1), 2), no_quadro(corpo)],
        "hurt": [no_quadro(clarear(corpo, 60), dx=-1), no_quadro(corpo)],
    }
    colunas = max(len(f) for f in anims.values())
    folha = Image.new("RGBA", (QUADRO[0] * colunas, QUADRO[1] * len(anims)), (0, 0, 0, 0))
    dados = {"image": "askara_spritesheet.png", "frame_width": QUADRO[0], "frame_height": QUADRO[1], "animations": {}}
    for linha, (nome, quadros) in enumerate(anims.items()):
        lista = []
        for col, q in enumerate(quadros):
            folha.alpha_composite(q, (col * QUADRO[0], linha * QUADRO[1]))
            lista.append({"x": col * QUADRO[0], "y": linha * QUADRO[1], "w": QUADRO[0], "h": QUADRO[1]})
        dados["animations"][nome] = {"row": linha, "frame_duration_ms": DURACOES[nome], "frames": lista}
    salvar(folha, "askara_spritesheet.png")
    with open(os.path.join(PASTA, "askara_spritesheet.json"), "w") as f:
        json.dump(dados, f, indent=2)
    print("ok:", os.path.join(PASTA, "askara_spritesheet.json"))


# ------------------------------------------------------------ invocações
def reduzir(nome, altura, espelhar):
    """Recorta a arte, reduz para `altura` px, deixa o alfa binário (pixel
    art) e contorna de escuro para a silhueta ler sobre o cenário."""
    img = Image.open(os.path.join(ORIGINAIS, nome + ".png")).convert("RGBA")
    img = img.crop(img.getbbox())
    largura = max(1, round(img.width * altura / img.height))
    img = img.resize((largura, altura), Image.LANCZOS)
    if espelhar:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    # 1px de folga em volta para o contorno
    final = Image.new("RGBA", (largura + 2, altura + 2), (0, 0, 0, 0))
    px = img.load()
    for y in range(altura):
        for x in range(largura):
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
                    final.putpixel((x, y), CONTORNO)
                    break
    salvar(final, nome + ".png")


# ------------------------------------------------------------------ ícones
# Desenhos 11x11 no padrão de tools/pixel_icon.py (sem moldura,
# borda em tom escuro da própria cor); cada ícone tem sua paleta.
ICONES = {
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


def gerar_icones():
    for nome, (paleta, linhas) in ICONES.items():
        salvar(icone(paleta, linhas), "icon_%s.png" % nome)


if __name__ == "__main__":
    gerar_folha(Image.open(ORIGINAL).convert("RGBA"))
    for nome, cfg in INVOCACOES.items():
        reduzir(nome, cfg["altura"], cfg["espelhar"])
    gerar_icones()

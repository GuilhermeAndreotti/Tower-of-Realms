"""Gera a folha de animações da Caoimhe a partir do sprite parado original
(characters/caoimhe/caoimhe.png), no mesmo formato JSON dos outros.
O primeiro quadro de cada animação é o sprite original, sem mudanças.

Uso: python3 tools/generate_caoimhe.py  (a partir da pasta Torre)
"""
import json
import os

from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PASTA = os.path.join(RAIZ, "characters", "caoimhe")
ORIGINAL = os.path.join(PASTA, "caoimhe.png")

QUADRO = (32, 40)
DESLOCAMENTO = (2, 3)  # onde o original entra no quadro: pés em (16, 38)
CABECA = (2, 12)  # linhas da cabeça (chifres ao queixo) no original
DURACOES = {"idle": 300, "walk": 220}


def salvar(img, nome):
    destino = os.path.join(PASTA, nome)
    img.save(destino)
    print("ok:", destino)


def no_quadro(corpo, dx=0, dy=0):
    q = Image.new("RGBA", QUADRO, (0, 0, 0, 0))
    q.alpha_composite(corpo, (DESLOCAMENTO[0] + dx, DESLOCAMENTO[1] + dy))
    return q


def respirando(corpo):
    """A cabeça desce 1px sobre a gola; o corpo (e o ouro das mangas) fica parado."""
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


def gerar_folha(corpo):
    anims = {
        "idle": [no_quadro(corpo), no_quadro(corpo), no_quadro(respirando(corpo)), no_quadro(respirando(corpo))],
        # o vestido desliza: o corpo não pula, só a cabeça balança a cada passo
        "walk": [no_quadro(corpo), no_quadro(respirando(corpo)), no_quadro(corpo), no_quadro(respirando(corpo))],
    }
    colunas = max(len(f) for f in anims.values())
    folha = Image.new("RGBA", (QUADRO[0] * colunas, QUADRO[1] * len(anims)), (0, 0, 0, 0))
    dados = {"image": "caoimhe_spritesheet.png", "frame_width": QUADRO[0], "frame_height": QUADRO[1], "animations": {}}
    for linha, (nome, quadros) in enumerate(anims.items()):
        lista = []
        for col, q in enumerate(quadros):
            folha.alpha_composite(q, (col * QUADRO[0], linha * QUADRO[1]))
            lista.append({"x": col * QUADRO[0], "y": linha * QUADRO[1], "w": QUADRO[0], "h": QUADRO[1]})
        dados["animations"][nome] = {"row": linha, "frame_duration_ms": DURACOES[nome], "frames": lista}
    salvar(folha, "caoimhe_spritesheet.png")
    with open(os.path.join(PASTA, "caoimhe_spritesheet.json"), "w") as f:
        json.dump(dados, f, indent=2)
    print("ok:", os.path.join(PASTA, "caoimhe_spritesheet.json"))


if __name__ == "__main__":
    gerar_folha(Image.open(ORIGINAL).convert("RGBA"))

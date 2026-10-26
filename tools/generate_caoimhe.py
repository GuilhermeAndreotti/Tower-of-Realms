"""Gera a folha de animações da Caoimhe a partir do sprite parado original
(characters/caoimhe/caoimhe.png), no mesmo formato JSON dos outros.
O primeiro quadro de cada animação é o sprite original, sem mudanças.

Uso: python3 tools/generate_caoimhe.py  (a partir da pasta Torre)
"""
import json
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDER = os.path.join(ROOT, "characters", "caoimhe")
ORIGINAL = os.path.join(FOLDER, "caoimhe.png")

FRAME = (32, 40)
OFFSET = (2, 3)  # onde o original entra no quadro: pés em (16, 38)
CABECA = (2, 12)  # linhas da cabeça (chifres ao queixo) no original
DURACOES = {"idle": 300, "walk": 220}


def save(img, name):
    destination = os.path.join(FOLDER, name)
    img.save(destination)
    print("ok:", destination)


def at_frame(body, dx=0, dy=0):
    q = Image.new("RGBA", FRAME, (0, 0, 0, 0))
    q.alpha_composite(body, (OFFSET[0] + dx, OFFSET[1] + dy))
    return q


def respirando(body):
    """A cabeça desce 1px sobre a gola; o corpo (e o ouro das mangas) fica parado."""
    c = body.copy()
    top, base = CABECA
    for y in range(base, top - 1, -1):
        for x in range(c.width):
            p = body.getpixel((x, y))
            if p[3] or y + 1 <= base:
                c.putpixel((x, y + 1), p)
    for x in range(c.width):
        c.putpixel((x, top), (0, 0, 0, 0))
    return c


def gerar_sheet(body):
    anims = {
        "idle": [at_frame(body), at_frame(body), at_frame(respirando(body)), at_frame(respirando(body))],
        # o vestido desliza: o corpo não pula, só a cabeça balança a cada passo
        "walk": [at_frame(body), at_frame(respirando(body)), at_frame(body), at_frame(respirando(body))],
    }
    columns = max(len(f) for f in anims.values())
    sheet = Image.new("RGBA", (FRAME[0] * columns, FRAME[1] * len(anims)), (0, 0, 0, 0))
    data = {"image": "caoimhe_spritesheet.png", "frame_width": FRAME[0], "frame_height": FRAME[1], "animations": {}}
    for line, (name, frames) in enumerate(anims.items()):
        list = []
        for col, q in enumerate(frames):
            sheet.alpha_composite(q, (col * FRAME[0], line * FRAME[1]))
            list.append({"x": col * FRAME[0], "y": line * FRAME[1], "w": FRAME[0], "h": FRAME[1]})
        data["animations"][name] = {"row": line, "frame_duration_ms": DURACOES[name], "frames": list}
    save(sheet, "caoimhe_spritesheet.png")
    with open(os.path.join(FOLDER, "caoimhe_spritesheet.json"), "w") as f:
        json.dump(data, f, indent=2)
    print("ok:", os.path.join(FOLDER, "caoimhe_spritesheet.json"))


if __name__ == "__main__":
    gerar_sheet(Image.open(ORIGINAL).convert("RGBA"))

"""Gera os assets do Clairin a partir dos originais em characters/clairin/originals/:
duas folhas de animações + JSON (mesmo formato dos outros), a normal e a da
Cabeça Flamejante (trocada na ult, como o visual Kokoro da Shumi), e os
ícones das habilidades (padrão de pixel_icon.py).

A folha original tem 8 quadros de 24x36: parado, dois de braços erguidos,
dois da cabeça pegando fogo e três da cabeça em chamas. O último está 4px à
direita dos outros, então cada quadro é alinhado pelos pés.

Uso: python3 tools/generate_clairin.py  (a partir da pasta Torre)
"""
import json
import os

from PIL import Image

from pixel_icon import icon

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDER = os.path.join(ROOT, "characters", "clairin")
SHEET = os.path.join(FOLDER, "originals", "clairin_sheet.png")

FRAME = (32, 40)
SOURCE = (24, 36)  # quadro da folha original
FEET = (16, 38)  # onde ficam os pés (o meio deles e a base) no quadro gerado
HEAD = (3, 13)  # linhas do cabelo ao queixo no quadro original
DURATIONS = {"idle": 300, "cast": 110, "ignite": 120, "hurt": 150}
FRENZY_DURATIONS = {"idle": 120, "cast": 110, "hurt": 150}


def save(img, name):
    destination = os.path.join(FOLDER, name)
    img.save(destination)
    print("ok:", destination)


def source_frames(sheet):
    """Os 8 quadros da folha, cada um recortado em volta dos pés."""
    alpha = sheet.split()[3]
    frames = []
    for row in range(2):
        y0 = row * SOURCE[1]
        for col in range(5):
            x0 = col * SOURCE[0]
            # base dos pés: a linha mais baixa com pixel na faixa do quadro
            # (o último quadro escapa 4px para o vizinho, então a busca vai além)
            xs = range(x0, min(sheet.width, x0 + SOURCE[0] + 4))
            ys = [y for y in range(y0, y0 + SOURCE[1]) for x in xs if alpha.getpixel((x, y))]
            if not ys or max(ys) - y0 < SOURCE[1] - 6:
                continue
            base = max(ys)
            feet = [x for x in xs if alpha.getpixel((x, base))]
            left = feet[0]
            # o recorte deixa o meio dos pés em x = 12
            crop = sheet.crop((left - 8, y0, left - 8 + SOURCE[0], base + 1))
            frames.append(crop)
    return frames


def at_frame(body, dx=0, dy=0):
    """`body` com os pés em FEET (o recorte tem a base dos pés na última linha)."""
    q = Image.new("RGBA", FRAME, (0, 0, 0, 0))
    q.alpha_composite(body, (FEET[0] - 12 + dx, FEET[1] - body.height + 1 + dy))
    return q


def breathing(body):
    """A cabeça desce 1px sobre a gola; o casaco fica parado."""
    c = body.copy()
    top, base = HEAD
    top += body.height - SOURCE[1]
    base += body.height - SOURCE[1]
    for y in range(base, top - 1, -1):
        for x in range(c.width):
            p = body.getpixel((x, y))
            if p[3] or y + 1 <= base:
                c.putpixel((x, y + 1), p)
    for x in range(c.width):
        c.putpixel((x, top), (0, 0, 0, 0))
    return c


def lighten(img, amount):
    c = img.copy()
    px = c.load()
    for y in range(c.height):
        for x in range(c.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (min(255, r + amount), min(255, g + amount), min(255, b + amount), a)
    return c


def build_sheet(name, anims, durations):
    columns = max(len(f) for f in anims.values())
    sheet = Image.new("RGBA", (FRAME[0] * columns, FRAME[1] * len(anims)), (0, 0, 0, 0))
    data = {"image": name + ".png", "frame_width": FRAME[0], "frame_height": FRAME[1], "animations": {}}
    for line, (anim, frames) in enumerate(anims.items()):
        cells = []
        for col, q in enumerate(frames):
            sheet.alpha_composite(q, (col * FRAME[0], line * FRAME[1]))
            cells.append({"x": col * FRAME[0], "y": line * FRAME[1], "w": FRAME[0], "h": FRAME[1]})
        data["animations"][anim] = {"row": line, "frame_duration_ms": durations[anim], "frames": cells}
    save(sheet, name + ".png")
    with open(os.path.join(FOLDER, name + ".json"), "w") as f:
        json.dump(data, f, indent=2)
    print("ok:", os.path.join(FOLDER, name + ".json"))


def generate_sheets():
    f = source_frames(Image.open(SHEET).convert("RGBA"))
    assert len(f) == 8, "a folha do Clairin deveria ter 8 quadros (achou %d)" % len(f)
    still, arms_a, arms_b, spark_a, spark_b, fire_a, fire_b, fire_c = f
    build_sheet("clairin_spritesheet", {
        "idle": [at_frame(still), at_frame(still), at_frame(breathing(still)), at_frame(breathing(still))],
        "cast": [at_frame(arms_a), at_frame(arms_b), at_frame(arms_b), at_frame(arms_a)],
        # a cabeça pega fogo; a ação troca para a folha da Cabeça Flamejante no fim
        "ignite": [at_frame(arms_a), at_frame(spark_a), at_frame(spark_b), at_frame(fire_a)],
        "hurt": [at_frame(lighten(still, 60), dx=-1), at_frame(still)],
    }, DURATIONS)
    # na Cabeça Flamejante os braços ficam erguidos e o fogo tremula sempre
    build_sheet("clairin_frenzy_spritesheet", {
        "idle": [at_frame(fire_a), at_frame(fire_b), at_frame(fire_c), at_frame(fire_b)],
        "cast": [at_frame(fire_b), at_frame(fire_c), at_frame(fire_c), at_frame(fire_a)],
        "hurt": [at_frame(lighten(fire_a, 60), dx=-1), at_frame(fire_a)],
    }, FRENZY_DURATIONS)


# ------------------------------------------------------------------ ícones
# Desenhos 11x11 no padrão de tools/pixel_icon.py (sem moldura, borda em tom
# escuro da própria cor). A Chama Frenética é amarela, mais clara que o fogo
# comum do Andri.
FLAME = {"d": (150, 55, 0, 255), "o": (255, 140, 0, 255), "y": (255, 220, 40, 255), "w": (255, 255, 210, 255)}
ICONS = {
    # Bola de Fogo: bola redonda com fagulhas atrás.
    "fireball": (FLAME, [
        "......ddd..",
        "....ddoood.",
        "...dooyyyod",
        "d.dooywwyod",
        ".doooywwyod",
        "d.dooyyyyod",
        "..ddooyyod.",
        ".d..dooodd.",
        "......ddd..",
        "..d........",
        "...........",
    ]),
    # Onda Frenética: três labaredas subindo de uma base de fogo.
    "wave": (FLAME, [
        "...........",
        ".....y.....",
        "..y..oy..y.",
        ".yo.yoy.yo.",
        ".oy.oyo.oy.",
        "doyoyywyoyd",
        "dooyywwyood",
        "dooooyyoood",
        ".ddooooodd.",
        "...ddddd...",
        "...........",
    ]),
    # Descarga: a chama juntada estoura para todos os lados.
    "discharge": (FLAME, [
        ".....d.....",
        ".d...o...d.",
        "..o..o..o..",
        "...oyyyo...",
        "....ywy....",
        "dooywwwyood",
        "....ywy....",
        "...oyyyo...",
        "..o..o..o..",
        ".d...o...d.",
        ".....d.....",
    ]),
    # Cabeça Flamejante: a cabeça vira chama, com o olho escuro no meio.
    "flaming_head": (dict(FLAME, k=(45, 20, 5, 255), c=(110, 85, 20, 255), s=(225, 225, 215, 255)), [
        "..y.y..y...",
        ".yoyoyyoy..",
        "yoyywwyyoy.",
        "oyywwwwyyoy",
        "yywwwkwwyyo",
        "oyywwwwyyoy",
        ".oyywwyyoo.",
        "..ooyyyoo..",
        "...ccscc...",
        "..ccssscc..",
        ".cccsssccc.",
    ]),
    # Chama Frenética: uma labareda só, que cresce até estourar.
    "frenzied_flame": (FLAME, [
        ".....d.....",
        "....dod....",
        "....doyd...",
        "...doyyod..",
        "..doyywyod.",
        "..doywwyod.",
        ".doyywwwyod",
        ".doyywwyyod",
        "..doyyyyod.",
        "...ddoodd..",
        "....ddd....",
    ]),
}


def generate_icons():
    for name, (palette, lines) in ICONS.items():
        save(icon(palette, lines), "icon_%s.png" % name)


if __name__ == "__main__":
    generate_sheets()
    generate_icons()

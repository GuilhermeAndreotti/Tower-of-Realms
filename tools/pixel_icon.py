"""Padrão dos ícones de habilidade, o mesmo dos ícones da Shumi:

- 15x15 e fundo transparente, sem moldura (a barra da batalha já desenha
  a borda de cada slot);
- o desenho tem 11x11 e fica centrado, com 2px de folga de cada lado;
- sem contorno preto na figura: a borda é um tom escuro da própria cor, com
  2 a 4 tons por ícone (mais um brilho, quando precisar).

Os geradores (generate_andri.py, generate_askara.py, generate_placeholder_art.py)
descrevem cada ícone como paleta + 11 linhas de 11 caracteres ('.' =
transparente) e usam icone() daqui. Rode-os a partir da pasta Torre.
"""
from PIL import Image

SIDE = 15
DRAWING = 11


def drawing(paleta, lines):
    """Só o desenho 11x11, sem a folga (para usar como sprite na arena)."""
    assert len(lines) == DRAWING and all(len(l) == DRAWING for l in lines), "ícone precisa de 11x11"
    img = Image.new("RGBA", (DRAWING, DRAWING), (0, 0, 0, 0))
    for y, line in enumerate(lines):
        for x, ch in enumerate(line):
            if ch != ".":
                img.putpixel((x, y), paleta[ch])
    return img


def icon(paleta, lines):
    """Ícone 15x15 no padrão: o desenho centrado no fundo transparente."""
    img = Image.new("RGBA", (SIDE, SIDE), (0, 0, 0, 0))
    img.alpha_composite(drawing(paleta, lines), (2, 2))
    return img

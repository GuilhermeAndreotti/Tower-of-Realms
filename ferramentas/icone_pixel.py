"""Padrão dos ícones de habilidade, o mesmo dos ícones da Shumi:

- 15x15 e fundo transparente, sem moldura (a barra da batalha já desenha
  a borda de cada slot);
- o desenho tem 11x11 e fica centrado, com 2px de folga de cada lado;
- sem contorno preto na figura: a borda é um tom escuro da própria cor, com
  2 a 4 tons por ícone (mais um brilho, quando precisar).

Os geradores (gerar_andri.py, gerar_askara.py, gerar_assets_teste.py)
descrevem cada ícone como paleta + 11 linhas de 11 caracteres ('.' =
transparente) e usam icone() daqui. Rode-os a partir da pasta Torre.
"""
from PIL import Image

LADO = 15
DESENHO = 11


def desenho(paleta, linhas):
    """Só o desenho 11x11, sem a folga (para usar como sprite na arena)."""
    assert len(linhas) == DESENHO and all(len(l) == DESENHO for l in linhas), "ícone precisa de 11x11"
    img = Image.new("RGBA", (DESENHO, DESENHO), (0, 0, 0, 0))
    for y, linha in enumerate(linhas):
        for x, ch in enumerate(linha):
            if ch != ".":
                img.putpixel((x, y), paleta[ch])
    return img


def icone(paleta, linhas):
    """Ícone 15x15 no padrão: o desenho centrado no fundo transparente."""
    img = Image.new("RGBA", (LADO, LADO), (0, 0, 0, 0))
    img.alpha_composite(desenho(paleta, linhas), (2, 2))
    return img

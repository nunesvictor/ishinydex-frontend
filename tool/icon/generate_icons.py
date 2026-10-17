"""Gera todos os ícones do app na identidade C · Clássico (#162): brilho
vermelho de 4 pontas e um ponto amarelo sobre o grafite.

Uso (na raiz do repositório; precisa do Pillow: `pip install pillow`):

    python3 tool/icon/generate_icons.py

Sobrescreve web/favicon.png, web/icons/*.png e os PNGs do
ios/Runner/Assets.xcassets/AppIcon.appiconset (tamanhos lidos do Contents.json).
O desenho é feito em 4096 px e reduzido (supersampling = bordas suaves).
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
S = 4096
GRAPHITE = (38, 35, 42)  # #26232A, o fundo do ícone
GRAPHITE_LIGHT = (58, 54, 64)  # #3A3640
RED = (229, 57, 53)  # #E53935
YELLOW = (255, 203, 5)  # #FFCB05

# O desenho do mock aprovado (viewBox 24×24, num ícone de 96 com 60 de
# desenho): o brilho em (12, 12) com raio 10 e o ponto em (19, 5), raio 1,8.
CONTENT = 60 / 96


def star(cx, cy, r, inner=0.31):
    """Estrela de 4 pontas com lados retos (o brilho do mock)."""
    d = r * inner / 2**0.5
    return [
        (cx, cy - r), (cx + d, cy - d), (cx + r, cy), (cx + d, cy + d),
        (cx, cy + r), (cx - d, cy + d), (cx - r, cy), (cx - d, cy - d),
    ]


def draw(scale=1.0, dot=True):
    """Desenha o ícone em S×S.

    scale < 1 encolhe o desenho (zona segura do ícone maskable); sem o ponto
    amarelo nos tamanhos em que ele sumiria (favicon).
    """
    image = Image.new("RGB", (S, S), GRAPHITE)
    # Luz radial suave no centro, para dar profundidade.
    glow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(glow).ellipse([S * 0.15, S * 0.12, S * 0.85, S * 0.82], fill=150)
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.12))
    image = Image.composite(Image.new("RGB", (S, S), GRAPHITE_LIGHT), image, glow)

    unit = S * CONTENT * scale / 24  # 1 unidade do viewBox, em px
    c = S / 2
    canvas = ImageDraw.Draw(image)
    canvas.polygon(star(c, c, 10 * unit), fill=RED)
    if dot:
        x, y, r = c + 7 * unit, c - 7 * unit, 1.8 * unit
        canvas.ellipse([x - r, y - r, x + r, y + r], fill=YELLOW)
    return image


def save(image, size, path):
    # RGB, sem transparência: a Apple recusa ícone de iOS com canal alfa.
    image.resize((size, size), Image.LANCZOS).save(path, optimize=True)
    print(f"{path.relative_to(ROOT)} ({size}px)")


def main():
    full = draw()
    maskable = draw(scale=0.8)  # conteúdo dentro do círculo de 80%
    favicon = draw(scale=1.4, dot=False)

    web = ROOT / "web"
    save(favicon, 16, web / "favicon.png")
    for size in (192, 512):
        save(full, size, web / "icons" / f"Icon-{size}.png")
        save(maskable, size, web / "icons" / f"Icon-maskable-{size}.png")

    ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    done = set()
    for entry in json.loads((ios / "Contents.json").read_text())["images"]:
        name = entry["filename"]
        if name in done:
            continue
        done.add(name)
        points = float(entry["size"].split("x")[0])
        save(full, round(points * int(entry["scale"].rstrip("x"))), ios / name)


if __name__ == "__main__":
    main()

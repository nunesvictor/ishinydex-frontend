"""Gera todos os ícones do app: brilho shiny dourado sobre o índigo do tema.

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
INDIGO = (63, 81, 181)  # #3F51B5, theme_color do manifest
INDIGO_LIGHT = (92, 107, 192)  # #5C6BC0
GOLD = (255, 202, 40)  # #FFCA28
GOLD_LIGHT = (255, 236, 179)  # #FFECB3


def sparkle(cx, cy, r, pinch=0.18, steps=64):
    """Estrela de 4 pontas com lados côncavos (curvas de Bézier quadráticas)."""
    tips = [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)]
    points = []
    for i in range(4):
        (x0, y0), (x2, y2) = tips[i], tips[(i + 1) % 4]
        # Controle perto do centro: quanto menor o pinch, mais fina a ponta.
        mx, my = (x0 + x2) / 2, (y0 + y2) / 2
        x1, y1 = cx + (mx - cx) * pinch, cy + (my - cy) * pinch
        for step in range(steps):
            t = step / steps
            a, b, c = (1 - t) ** 2, 2 * (1 - t) * t, t**2
            points.append((a * x0 + b * x1 + c * x2, a * y0 + b * y1 + c * y2))
    return points


def draw(scale=1.0, small_sparkles=True):
    """Desenha o ícone em S×S.

    scale < 1 encolhe o desenho (zona segura do ícone maskable); sem as
    estrelas pequenas para tamanhos em que elas sumiriam (favicon).
    """
    image = Image.new("RGB", (S, S), INDIGO)
    # Luz radial suave no centro, para dar profundidade.
    glow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(glow).ellipse([S * 0.15, S * 0.12, S * 0.85, S * 0.82], fill=150)
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.12))
    image = Image.composite(Image.new("RGB", (S, S), INDIGO_LIGHT), image, glow)

    c, k = S / 2, scale
    # (cx, cy, raio, cor): brilho grande + dois pequenos, como o ✨.
    shapes = [
        (c - S * 0.06 * k, c + S * 0.05 * k, S * 0.30 * k, GOLD),
        (c + S * 0.23 * k, c - S * 0.21 * k, S * 0.11 * k, GOLD_LIGHT),
        (c + S * 0.20 * k, c + S * 0.25 * k, S * 0.06 * k, GOLD_LIGHT),
    ]
    canvas = ImageDraw.Draw(image)
    for cx, cy, r, color in shapes if small_sparkles else shapes[:1]:
        canvas.polygon(sparkle(cx, cy, r), fill=color)
    # Núcleo claro no brilho principal.
    cx, cy, r, _ = shapes[0]
    canvas.polygon(sparkle(cx, cy, r * 0.42, pinch=0.3), fill=GOLD_LIGHT)
    return image


def save(image, size, path):
    # RGB, sem transparência: a Apple recusa ícone de iOS com canal alfa.
    image.resize((size, size), Image.LANCZOS).save(path, optimize=True)
    print(f"{path.relative_to(ROOT)} ({size}px)")


def main():
    full = draw()
    maskable = draw(scale=0.8)  # conteúdo dentro do círculo de 80%
    favicon = draw(scale=1.25, small_sparkles=False)

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

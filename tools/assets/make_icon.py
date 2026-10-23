#!/usr/bin/env python3
"""Renders the 1024×1024 app icon (opaque, as App Store Connect requires)."""
import sys
from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
TOP, BOTTOM = (255, 138, 92), (214, 48, 49)
FONT = "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf"


def main(out: str) -> None:
    img = Image.new("RGB", (SIZE, SIZE))
    draw = ImageDraw.Draw(img)
    for y in range(SIZE):
        t = y / (SIZE - 1)
        color = tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM))
        draw.line([(0, y), (SIZE, y)], fill=color)

    # Rising sun: "a new word every day".
    sun = (255, 214, 102)
    draw.ellipse([612, 120, 872, 380], fill=sun)
    for i in range(12):
        import math
        angle = math.radians(i * 30)
        cx, cy, r1, r2 = 742, 250, 160, 200
        draw.line([(cx + r1 * math.cos(angle), cy + r1 * math.sin(angle)),
                   (cx + r2 * math.cos(angle), cy + r2 * math.sin(angle))], fill=sun, width=22)

    # Speech bubble with the word.
    white = (255, 255, 255)
    draw.rounded_rectangle([150, 400, 874, 800], radius=110, fill=white)
    draw.polygon([(280, 780), (420, 780), (250, 910)], fill=white)
    font = ImageFont.truetype(FONT, 250)
    text = "Gün"
    box = draw.textbbox((0, 0), text, font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    draw.text(((SIZE - w) / 2 - box[0], 600 - h / 2 - box[1]), text, font=font, fill=BOTTOM)
    img.save(out, "PNG")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "AppIcon.png")

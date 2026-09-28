#!/usr/bin/env python3
"""Generate a native-style StudyFlow app icon without external network access."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ICONSET = ROOT / "Resources" / "AppIcon.iconset"
ICNS = ROOT / "Resources" / "AppIcon.icns"
ICON_FILES = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def render(size: int) -> Image.Image:
    scale = size / 1024
    base = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gradient = Image.new("RGBA", (size, size))
    px = gradient.load()
    top = (45, 108, 255, 255)
    bottom = (118, 76, 255, 255)
    for y in range(size):
        t = y / max(1, size - 1)
        px_color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(4))
        for x in range(size):
            px[x, y] = px_color
    base = Image.alpha_composite(base, gradient)
    draw = ImageDraw.Draw(base)

    # Rounded checklist card.
    card = (176 * scale, 174 * scale, 848 * scale, 824 * scale)
    draw.rounded_rectangle(card, radius=118 * scale, fill=(255, 255, 255, 242))

    line_x1, line_x2 = 328 * scale, 748 * scale
    centers = [344, 494, 644]
    for index, cy in enumerate(centers):
        y = cy * scale
        circle_r = 44 * scale
        circle_box = (
            244 * scale - circle_r,
            y - circle_r,
            244 * scale + circle_r,
            y + circle_r,
        )
        if index == 0:
            draw.ellipse(circle_box, fill=(48, 111, 255, 255))
            draw.line(
                (
                    220 * scale,
                    y + 2 * scale,
                    239 * scale,
                    y + 24 * scale,
                    272 * scale,
                    y - 24 * scale,
                ),
                fill="white",
                width=max(2, int(18 * scale)),
                joint="curve",
            )
        elif index == 1:
            draw.ellipse(circle_box, fill=(120, 92, 255, 255))
            draw.line(
                (
                    220 * scale,
                    y + 2 * scale,
                    239 * scale,
                    y + 24 * scale,
                    272 * scale,
                    y - 24 * scale,
                ),
                fill="white",
                width=max(2, int(18 * scale)),
                joint="curve",
            )
        else:
            draw.ellipse(
                circle_box,
                outline=(138, 148, 170, 255),
                width=max(2, int(15 * scale)),
            )
        draw.rounded_rectangle(
            (line_x1, y - 26 * scale, line_x2, y + 26 * scale),
            radius=26 * scale,
            fill=(91, 104, 128, 70) if index == 2 else (76, 88, 116, 150),
        )

    # Soft inner highlight.
    highlight = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    hdraw = ImageDraw.Draw(highlight)
    hdraw.rounded_rectangle(
        (20 * scale, 20 * scale, size - 20 * scale, size * 0.52),
        radius=150 * scale,
        fill=(255, 255, 255, 28),
    )
    base = Image.alpha_composite(base, highlight.filter(ImageFilter.GaussianBlur(45 * scale)))
    base.putalpha(rounded_mask(size, int(220 * scale)))
    return base


def main() -> None:
    ICONSET.parent.mkdir(parents=True, exist_ok=True)
    render(1024).save(ICNS, format="ICNS")
    print(ICNS)


if __name__ == "__main__":
    main()

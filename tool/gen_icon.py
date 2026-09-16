#!/usr/bin/env python3
"""Regenerate the app icons: assets/icon/app_icon.png (square, opaque)
and assets/icon/app_icon_fg.png (adaptive foreground, transparent).

Run: python3 tool/gen_icon.py
"""

from PIL import Image, ImageDraw, ImageFilter

S = 1024
OUT_SQUARE = "assets/icon/app_icon.png"
OUT_FG = "assets/icon/app_icon_fg.png"

FACE_TOP = (47, 51, 60)
FACE_BOT = (21, 23, 28)
LCD = (245, 243, 233)
LCD_EDGE = (12, 13, 15)
BLUE = (61, 109, 180)
GREEN = (63, 158, 77)
KEY = (54, 58, 66)
KEY_EDGE = (16, 17, 20)
CURVE = (38, 86, 168)
AXIS = (96, 96, 90)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def faceplate(size):
    """Full-bleed vertical-gradient faceplate with a soft top sheen."""
    lay = Image.new("RGBA", (size, size))
    gd = ImageDraw.Draw(lay)
    for y in range(size):
        gd.line([(0, y), (size, y)],
                fill=lerp(FACE_TOP, FACE_BOT, y / size))
    sheen = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(sheen).ellipse(
        [size * 0.05, -size * 0.18, size * 0.95, size * 0.30],
        fill=(255, 255, 255, 16))
    sheen = sheen.filter(ImageFilter.GaussianBlur(size * 0.04))
    lay.alpha_composite(sheen)
    return lay


def draw_lcd(base, x0, y0, x1, y1):
    d = ImageDraw.Draw(base)
    d.rounded_rectangle([x0, y0, x1, y1], radius=42,
                        fill=LCD, outline=LCD_EDGE, width=12)

    lcd = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(lcd)
    cx, cy = (x0 + x1) / 2, y0 + (y1 - y0) * 0.58
    pad = 52
    ld.line([(x0 + pad, cy), (x1 - pad, cy)], fill=AXIS, width=6)
    ld.line([(cx, y0 + pad), (cx, y1 - pad)], fill=AXIS, width=6)
    for t in (-0.66, -0.33, 0.33, 0.66):
        tx = x0 + pad + (x1 - x0 - 2 * pad) * (t + 1) / 2
        ld.line([(tx, cy - 11), (tx, cy + 11)], fill=AXIS, width=5)
    pts = []
    span = x1 - x0 - 2 * pad
    for i in range(241):
        u = i / 240
        x = x0 + pad + u * span
        tt = (u - 0.5) * 2.6
        y = cy - (tt * tt - 0.85) * (y1 - y0) * 0.30
        pts.append((x, y))
    ld.line(pts, fill=CURVE, width=16, joint="curve")
    # clip the drawing to the LCD interior
    mask = Image.new("L", base.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [x0 + 12, y0 + 12, x1 - 12, y1 - 12], radius=32, fill=255)
    blank = Image.new("RGBA", base.size, (0, 0, 0, 0))
    base.alpha_composite(Image.composite(lcd, blank, mask))

    # inner shading along the LCD top edge
    shade = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(shade).rounded_rectangle(
        [x0 + 10, y0 + 10, x1 - 10, y0 + 52], radius=30,
        fill=(226, 224, 215, 255))
    base.alpha_composite(Image.composite(shade, blank, mask))


def draw_keypad(d, x0, y0, x1, y1):
    """Blue 2nd / green alpha column, a 4x3 key grid, arrow pad circle."""
    rows, cols = 4, 4
    gx1 = x1 - (x1 - x0) * 0.31
    kw = (gx1 - x0) / cols
    kh = (y1 - y0) / rows
    for r in range(rows):
        for c in range(cols):
            kx0 = x0 + c * kw + kw * 0.09
            kx1 = x0 + (c + 1) * kw - kw * 0.09
            ky0 = y0 + r * kh + kh * 0.15
            ky1 = y0 + (r + 1) * kh - kh * 0.15
            fill = KEY
            if r == 0 and c == 0:
                fill = BLUE
            elif r == 1 and c == 0:
                fill = GREEN
            d.rounded_rectangle([kx0, ky0, kx1, ky1], radius=16,
                                fill=fill, outline=KEY_EDGE, width=5)
            d.line([(kx0 + 10, ky1 - 7), (kx1 - 10, ky1 - 7)],
                   fill=(10, 10, 12), width=4)
    ax = x1 - (x1 - x0) * 0.155
    ay = (y0 + y1) / 2
    ar = (y1 - y0) * 0.42
    d.ellipse([ax - ar, ay - ar, ax + ar, ay + ar],
              fill=KEY, outline=KEY_EDGE, width=7)
    d.ellipse([ax - ar * 0.32, ay - ar * 0.32, ax + ar * 0.32,
               ay + ar * 0.32], fill=FACE_BOT)
    d.polygon([(ax, ay - ar * 0.60), (ax - ar * 0.19, ay - ar * 0.30),
               (ax + ar * 0.19, ay - ar * 0.30)], fill=(214, 214, 218))


def build(size):
    img = faceplate(size)
    m = size * 0.085
    draw_lcd(img, m, size * 0.14, size - m, size * 0.62)
    d = ImageDraw.Draw(img)
    draw_keypad(d, m, size * 0.68, size - m, size * 0.94)
    return img


def main():
    square = build(S).convert("RGB")
    square.save(OUT_SQUARE)

    fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    art = build(int(S * 0.72))
    off = (S - art.width) // 2
    fg.alpha_composite(art, (off, off))
    fg.save(OUT_FG)
    print("wrote", OUT_SQUARE, "and", OUT_FG)


if __name__ == "__main__":
    main()

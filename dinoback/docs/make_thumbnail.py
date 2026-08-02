#!/usr/bin/env python3
"""Generates dinoback/art/game_screen_200.png, the game-chooser tile.

Draws three cards in a row — the middle one dimmed and the outer two matching — which is the
whole game in one picture: "is this the same as the one N back". Shapes, colors and the zig-ish
card frame mirror symbol_art.gd so the tile looks like the thing it links to.

Run from the repo root:  python3 dinoback/docs/make_thumbnail.py
"""
from PIL import Image, ImageDraw
import math
import os

S = 200
SS = 4                       # supersample, then downscale, for smooth edges
W = S * SS
BG = (60, 93, 62)            # 0x3C5D3E, main.gd's clear color
PLATE = (18, 20, 28)         # symbol_art.gd PLATE
FRAME = (255, 255, 255)

# symbol_art.gd COLORS, most distinct first
BLUE = (89, 158, 250)
YELLOW = (252, 209, 56)
RED = (240, 82, 74)

img = Image.new("RGB", (W, W), BG)
d = ImageDraw.Draw(img, "RGBA")


def ngon(cx, cy, r, sides, rot=-math.pi / 2):
    return [(cx + math.cos(rot + 2 * math.pi * i / sides) * r,
             cy + math.sin(rot + 2 * math.pi * i / sides) * r) for i in range(sides)]


def star(cx, cy, r_out, r_in):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + math.pi * i / 5
        rr = r_out if i % 2 == 0 else r_in
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return pts


def centered(pts, cx, cy):
    """Center a polygon's BOUNDING BOX, as symbol_art.gd does. Building a point-up triangle or
    star around its circumcenter leaves it sitting visibly high: the apex reaches a full radius
    up, the base only half a radius down."""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    dx = cx - (min(xs) + max(xs)) / 2
    dy = cy - (min(ys) + max(ys)) / 2
    return [(x + dx, y + dy) for x, y in pts]


def card(cx, cy, size, shape, color, alpha=255):
    """One square card: white frame, dark plate, one big symbol — as the game draws it."""
    h = size / 2
    inset = size * 0.075
    d.rounded_rectangle([cx - h, cy - h, cx + h, cy + h], radius=size * 0.09,
                        fill=FRAME + (alpha,))
    d.rounded_rectangle([cx - h + inset, cy - h + inset, cx + h - inset, cy + h - inset],
                        radius=size * 0.05, fill=PLATE + (alpha,))
    r = size * 0.32
    col = color + (alpha,)
    edge = tuple(int(c * 0.55) for c in color) + (alpha,)
    lw = max(1, int(r * 0.07))
    if shape == "circle":
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col, outline=edge, width=lw)
    elif shape == "square":
        q = r * 0.80
        d.rectangle([cx - q, cy - q, cx + q, cy + q], fill=col, outline=edge, width=lw)
    elif shape == "triangle":
        d.polygon(centered(ngon(cx, cy, r * 1.14, 3), cx, cy), fill=col, outline=edge, width=lw)
    elif shape == "star":
        d.polygon(centered(star(cx, cy, r * 1.12, r * 0.46), cx, cy), fill=col, outline=edge, width=lw)


# Three cards on a slight arc. The outer two are the SAME card (shape and color) with a different
# one between them: a 2-back match, which is what the game asks about.
CY = W * 0.46
SIZE = W * 0.40
card(W * 0.22, CY + W * 0.035, SIZE, "star", YELLOW)
card(W * 0.50, CY - W * 0.020, SIZE, "triangle", BLUE, alpha=150)
card(W * 0.78, CY + W * 0.035, SIZE, "star", YELLOW)

# the link between the two matching cards, drawn as an arc with arrowheads
ARC_Y = W * 0.80
d.arc([W * 0.20, ARC_Y - W * 0.22, W * 0.80, ARC_Y + W * 0.10], start=185, end=355,
      fill=(255, 255, 255, 190), width=int(W * 0.016))
for x in (W * 0.215, W * 0.785):
    d.ellipse([x - W * 0.022, ARC_Y - W * 0.078, x + W * 0.022, ARC_Y - W * 0.034],
              fill=(255, 255, 255, 210))

# "N" tucked into the arc, the one parameter the whole game turns on
try:
    from PIL import ImageFont
    f = None
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"):
        if os.path.exists(p):
            f = ImageFont.truetype(p, int(W * 0.13))
            break
    if f is not None:
        d.text((W * 0.50, ARC_Y - W * 0.015), "N", font=f, fill=(255, 255, 255, 235),
               anchor="mm")
except Exception:
    pass

out = os.path.join(os.path.dirname(__file__), "..", "art", "game_screen_200.png")
out = os.path.normpath(out)
os.makedirs(os.path.dirname(out), exist_ok=True)
img.resize((S, S), Image.LANCZOS).save(out)
print("wrote", out)

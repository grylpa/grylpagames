#!/usr/bin/env python3
"""Generates dinoback/art/game_screen_200.png, the game-chooser tile.

Three cards in a row: the OUTER TWO ARE THE SAME DINO, the middle one a different dino.
That is the whole game in one picture — "is this the same as the card N back" — and it uses the
real photographs from res://art/dinos, since the game is called Dino N-Back.

The two dinos are chosen by index below (any 1..48); the script prints which files it used.

Run from the repo root:  python3 dinoback/docs/make_thumbnail.py
"""
from PIL import Image, ImageDraw, ImageFont
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
DINOS = os.path.join(ROOT, "art", "dinos")

DINO_A = 5      # the repeated card (left and right)
DINO_B = 9      # the odd one in the middle

S = 200
SS = 4                       # supersample, then downscale, for smooth edges
W = S * SS
BG = (60, 93, 62)            # 0x3C5D3E, main.gd's clear color
FRAME = (255, 255, 255)      # dino cards carry the WHITE frame in game; drawn cards get yellow

CARD_W = int(W * 0.285)
CARD_H = int(CARD_W * 1.28)
CY = int(W * 0.42)
INSET = max(2, int(CARD_W * 0.075))

img = Image.new("RGB", (W, W), BG)
d = ImageDraw.Draw(img, "RGBA")


def load_dino(n):
    path = os.path.join(DINOS, "dino%d.jpg" % n)
    if not os.path.exists(path):
        raise SystemExit("no such image: %s" % path)
    return path, Image.open(path).convert("RGB")


def cover(im, w, h):
    """Scale-and-crop to exactly w x h, keeping the centre — the same read as the game's card."""
    sw, sh = im.size
    k = max(w / sw, h / sh)
    im = im.resize((max(1, int(sw * k)), max(1, int(sh * k))), Image.LANCZOS)
    left = (im.size[0] - w) // 2
    top = (im.size[1] - h) // 2
    return im.crop((left, top, left + w, top + h))


def card(cx, photo):
    """One card: white frame, photo cover-cropped inside it. All three are drawn at full
    strength — the middle one is not dimmed. Dimming it made the tile read as "this card is
    inactive" rather than "these two are the same one"."""
    x0, y0 = cx - CARD_W // 2, CY - CARD_H // 2
    d.rounded_rectangle([x0, y0, x0 + CARD_W, y0 + CARD_H],
                        radius=int(CARD_W * 0.09), fill=FRAME)
    iw, ih = CARD_W - INSET * 2, CARD_H - INSET * 2
    img.paste(cover(photo, iw, ih), (x0 + INSET, y0 + INSET))


path_a, dino_a = load_dino(DINO_A)
path_b, dino_b = load_dino(DINO_B)

card(int(W * 0.19), dino_a)
card(int(W * 0.50), dino_b)
card(int(W * 0.81), dino_a)

# The link between the two matching cards: an arc with a dot at each end, and the N it turns on.
ARC_Y = int(W * 0.80)
d.arc([W * 0.19, ARC_Y - W * 0.20, W * 0.81, ARC_Y + W * 0.10], start=185, end=355,
      fill=(255, 255, 255, 200), width=int(W * 0.016))
for x in (W * 0.205, W * 0.795):
    d.ellipse([x - W * 0.022, ARC_Y - W * 0.072, x + W * 0.022, ARC_Y - W * 0.028],
              fill=(255, 255, 255, 220))

f = None
for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
          "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"):
    if os.path.exists(p):
        f = ImageFont.truetype(p, int(W * 0.14))
        break
if f is not None:
    # a dark halo so the N holds up over whatever the sky colour is
    for ox, oy in ((-3, 0), (3, 0), (0, -3), (0, 3)):
        d.text((W * 0.50 + ox * SS, ARC_Y - W * 0.01 + oy * SS), "N", font=f,
               fill=(0, 0, 0, 190), anchor="mm")
    d.text((W * 0.50, ARC_Y - W * 0.01), "N", font=f, fill=(255, 255, 255, 240), anchor="mm")

out = os.path.normpath(os.path.join(HERE, "..", "art", "game_screen_200.png"))
os.makedirs(os.path.dirname(out), exist_ok=True)
img.resize((S, S), Image.LANCZOS).save(out)
print("used %s (repeated) and %s (middle)" % (os.path.basename(path_a), os.path.basename(path_b)))
print("wrote", out)

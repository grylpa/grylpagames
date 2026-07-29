from PIL import Image, ImageDraw
import math

S = 200
SS = 4                      # supersample for smooth edges
W = S * SS
img = Image.new("RGB", (W, W), (30, 58, 42))       # 0x1E3A2A, the game's clear color
d = ImageDraw.Draw(img, "RGBA")

def ell(cx, cy, rx, ry, fill=None, outline=None, width=1):
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=fill, outline=outline, width=width)

# faint field panel
d.rounded_rectangle([6*SS, 6*SS, W-6*SS, W-6*SS], radius=10*SS, fill=(255,255,255,9))

# --- one target area, drawn exactly like field.gd: outer disc, parking lane, inner disc ---
CX, CY = W*0.60, W*0.42
R_OUT, R_IN = W*0.33, W*0.155
ell(CX, CY, R_OUT, R_OUT, fill=(26, 51, 38, 140))                       # RING_BG
d.ellipse([CX-(R_OUT+R_IN)/2, CY-(R_OUT+R_IN)/2, CX+(R_OUT+R_IN)/2, CY+(R_OUT+R_IN)/2],
          outline=(255,255,255,18), width=int(W*0.085))                  # parking lane
ell(CX, CY, R_OUT, R_OUT, outline=(166, 230, 184, 150), width=3*SS)      # RING_LINE
ell(CX, CY, R_IN, R_IN, fill=(41, 87, 61, 200))                          # INNER_BG
ell(CX, CY, R_IN, R_IN, outline=(217, 255, 224, 200), width=3*SS)        # INNER_LINE

COLORS = [(71,143,242), (237,87,77), (92,199,107), (247,204,64), (179,117,230)]

def alien(cx, cy, r, cid, eyes, wide, ants, spots):
    col = COLORS[cid]
    dark = tuple(int(c*0.66) for c in col)
    lite = tuple(min(255, int(c*1.35)) for c in col)
    # body_extents() from alien.gd — ONE shape dimension, read as an aspect ratio
    rx, ry = (r*1.00, r*0.58) if wide else (r*0.58, r*1.00)
    ell(cx, cy + ry*0.98, rx*0.82, r*0.11, fill=(0,0,0,56))              # ground shadow
    if ants:                                                              # antennae
        xs = [0.0] if ants == 1 else [-rx*0.42, rx*0.42]
        for bx in xs:
            sgn = 1 if bx >= 0 else -1
            bp, tp = (cx+bx, cy-ry*0.72), (cx+bx+sgn*r*0.15, cy-ry*0.72-r*0.30)
            d.line([bp, tp], fill=dark, width=max(2, int(r*0.15)))
            ell(tp[0], tp[1], r*0.11, r*0.11, fill=lite)
    ell(cx, cy, rx, ry, fill=col, outline=dark, width=max(2, int(r*0.11)))
    ell(cx, cy + ry*0.28, rx*0.56, ry*0.44, fill=tuple(min(255,int(c*1.16)) for c in col))
    if spots:
        for ux, uy in [(-0.46,0.34), (0.42,0.24), (-0.12,0.62), (0.28,0.64)]:
            ell(cx+ux*rx, cy+uy*ry, r*0.105, r*0.105, fill=dark)
    # eyes: 1 = central, 2 = pair, 3 = triangle (three SHAPES, as in the game)
    units = {1: [(0,0)], 2: [(-1,0),(1,0)], 3: [(-1,-0.75),(1,-0.75),(0,0.95)]}[eyes]
    ex = max(abs(u[0]) for u in units); ey = max(abs(u[1]) for u in units)
    er = min((rx*1.34)*0.5/(ex*1.18+1), (ry*1.04)*0.5/(ey*1.18+1))
    er = max(r*0.15, min(r*0.34, er))
    for ux, uy in units:
        px, py = cx + ux*er*1.18, cy - ry*0.22 + uy*er*1.18
        ell(px, py, er, er, fill=(250,250,255), outline=dark, width=max(1,int(er*0.13)))
        ell(px, py+er*0.30, er*0.46, er*0.46, fill=(23,20,31))
        ell(px-er*0.26, py-er*0.28, er*0.17, er*0.17, fill=(255,255,255,215))

# parked on the lane (matching), one promoted inside, and a few roaming below
LANE = (R_OUT + R_IN) / 2
for ang, cid, eyes, wide, ants, spots in [
        (-150, 0, 3, False, 2, False),
        (-58,  0, 3, True,  0, True),
        (25,   1, 2, True,  2, False)]:
    a = math.radians(ang)
    alien(CX + math.cos(a)*LANE, CY + math.sin(a)*LANE, W*0.075, cid, eyes, wide, ants, spots)
alien(CX, CY, W*0.072, 0, 3, False, 2, False)                             # promoted, inner ring
alien(W*0.17, W*0.30, W*0.075, 2, 1, True,  1, True)
alien(W*0.15, W*0.74, W*0.078, 4, 2, False, 0, False)
alien(W*0.44, W*0.83, W*0.075, 3, 3, True,  2, True)
alien(W*0.78, W*0.82, W*0.072, 1, 1, False, 1, False)

img.resize((S, S), Image.LANCZOS).save("aliens/art/game_screen_200.png")
print("wrote aliens/art/game_screen_200.png")

"""Mother Snake chooser thumbnail — mirrors mother/scripts/level.gd.

Every constant below is copied from level.gd. Re-run after any visual change there:

    python3 mother/docs/make_thumbnail.py

It approximates Line2D as a run of overlapping discs, which is effectively what a round-jointed
Line2D is. Two details matter when doing that: the halo must be a SEPARATE pass under the body
(a per-disc outline beads the edge and makes the body read as rope), and the banding must be
sampled per disc from distance-along-the-body so it follows the tapering outline.
"""
from PIL import Image, ImageDraw, ImageFilter
import math

S, SS = 200, 4
W = S * SS

# --- palette ---
GROUND_TOP = (22, 17, 20)
GROUND_BOTTOM = (37, 28, 27)
GROUND_BANDS = 24
RIPPLE_LIGHT = (158, 128, 112)
RIPPLE_DARK = (10, 8, 10)
PEBBLE = (61, 48, 48, 191)
BUSH = (77, 59, 43, 204)
DUST_COL = (219, 199, 179)
MOTHER = (224, 161, 77)
CHILD = (245, 217, 158)

# --- body ---
TAIL_FRAC = 0.34
BAND_PX_OVER_W = 12.0 / 30.0        # BAND_PX / MOTHER_W
BAND_DARK = 0.82
TAIL_SOLID = 0.82
STRIPE_W = 0.28
STRIPE_LIGHT = 0.40
GLOW_MUL = 1.10
GLOW_ALPHA = 0.18
SHADOW_DY_OVER_W = 2.0 / 30.0

# --- head ---
HEAD_LEN_W = 1.30
HEAD_WIDE_W = 1.15
HEAD_JAW_AT = 0.28
HEAD_NOSE_W = 0.30
HEAD_NECK_W = 0.86
HEAD_EYE_AT = 0.34
HEAD_EYE_OUT = 0.56
HEAD_EYE_R = 0.17
HEAD_STRIPE_FROM = 0.42

# --- environment ---
DUNE_LAYERS = [
    (0.14, 0.055, 1.55, 0.22, (29, 22, 23)),
    (0.24, 0.045, 1.05, 0.40, (35, 27, 26)),
    (0.34, 0.036, 0.78, 0.62, (40, 30, 28)),
]
VIGNETTE_STEPS = 12
VIGNETTE_DEPTH = 0.16
VIGNETTE_MAX_A = 0.26


def lightened(c, amt):
    return tuple(int(v + (255 - v) * amt) for v in c)


def smoothstep(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def smootherstep(x):
    x = max(0.0, min(1.0, x))
    return x * x * x * (x * (6 * x - 15) + 10)


img = Image.new("RGB", (W, W), GROUND_TOP)
d = ImageDraw.Draw(img, "RGBA")

for i in range(GROUND_BANDS):
    t = i / (GROUND_BANDS - 1)
    col = tuple(int(GROUND_TOP[k] + (GROUND_BOTTOM[k] - GROUND_TOP[k]) * t) for k in range(3))
    d.rectangle([0, W * i / GROUND_BANDS, W, W * (i + 1) / GROUND_BANDS + 1], fill=col)

for (dy_f, amp_f, per_f, speed, col) in DUNE_LAYERS:
    dy, damp, dper = dy_f * W, amp_f * W, per_f * W
    doff = W * 0.35 * speed
    poly, x = [], 0.0
    while x <= W + 14:
        poly.append((x, dy + damp * math.sin((x + doff) * 2 * math.pi / dper)
                     + damp * 0.38 * math.sin((x + doff * 1.7) * 2 * math.pi / (dper * 0.41))))
        x += 14
    poly += [(W, W), (0, W)]
    d.polygon(poly, fill=col)

for y_frac, amp, period, phase, light in [
        (0.42, 0.010, 0.42, 0.4, True), (0.50, 0.008, 0.33, 2.1, False),
        (0.63, 0.013, 0.50, 1.2, True), (0.79, 0.010, 0.38, 3.4, True),
        (0.90, 0.012, 0.45, 0.9, False)]:
    pts = [(j, y_frac * W + amp * W * math.sin(j * 2 * math.pi / (period * W) + phase))
           for j in range(0, W + 8, 8)]
    d.line(pts, fill=(RIPPLE_LIGHT + (52,)) if light else (RIPPLE_DARK + (80,)),
           width=max(1, SS // 2), joint="curve")

for x, y, r in [(0.10, 0.52, 0.010), (0.44, 0.90, 0.008), (0.26, 0.70, 0.009),
                (0.88, 0.94, 0.008), (0.55, 0.60, 0.007), (0.80, 0.72, 0.008)]:
    d.ellipse([W * (x - r), W * (y - r * 0.7), W * (x + r), W * (y + r * 0.7)], fill=PEBBLE)
for bx, by, br in [(0.13, 0.955, 0.030), (0.93, 0.44, 0.020)]:
    cx, cy = W * bx, W * by
    for k in range(7):
        a = -math.pi / 2 + (k - 3) * 0.34
        rr = br * W * (0.62 + 0.38 * ((k * 7) % 5) / 5)
        d.line([cx, cy, cx + math.cos(a) * rr, cy + math.sin(a) * rr], fill=BUSH,
               width=max(1, SS - 1))
# dust: size and brightness rise together with depth, as in game
for i in range(26):
    depth = ((i * 37) % 100) / 100.0
    dx = ((i * 73) % 100) / 100.0 * W
    dy = (0.06 + depth * 0.92) * W
    r = (0.6 + (2.2 - 0.6) * depth) * SS * 0.9
    a = int(255 * (0.10 + (0.30 - 0.10) * depth))
    d.ellipse([dx - r, dy - r, dx + r, dy + r], fill=DUST_COL + (a,))


def body_width(t):
    """Line2D width_curve: 1.0 at the head, 0.90 at 0.62, TAIL_FRAC at the tail."""
    if t <= 0.62:
        return 1.0 + (0.90 - 1.0) * (t / 0.62)
    return 0.90 + (TAIL_FRAC - 0.90) * ((t - 0.62) / 0.38)


def band_shade(dist_px, w_head):
    """_band_shade(): triangle wave, base at distance 0, BAND_DARK at half a period."""
    period = BAND_PX_OVER_W * w_head
    return BAND_DARK + (1.0 - BAND_DARK) * abs(((dist_px / period) % 1.0) * 2.0 - 1.0)


def tail_alpha(t):
    return 1.0 if t <= TAIL_SOLID else max(0.0, 1.0 - (t - TAIL_SOLID) / (1.0 - TAIL_SOLID))


def breath_path(x0, x1, top, bot, cycle_px, phase_px, n=300):
    inh, ht, exh = 0.36, 0.14, 0.36
    pts = []
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n
        u = ((x - phase_px) % cycle_px) / cycle_px
        if u < inh:
            y = bot + (top - bot) * smootherstep(u / inh)
        elif u < inh + ht:
            y = top
        elif u < inh + ht + exh:
            y = top + (bot - top) * smootherstep((u - inh - ht) / exh)
        else:
            y = bot
        pts.append((x, y))
    return pts


def draw_body(pts, w_head, col):
    """Halo, banded fill, lighter spine — the same three passes in the same order as level.gd."""
    total = sum(math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1])
                for i in range(len(pts) - 1))

    def walk(scale, dy, cb):
        acc = 0.0
        for i in range(len(pts) - 1, -1, -1):       # tail <- head; the head is the LAST point
            if i < len(pts) - 1:
                acc += math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1])
            t = acc / total
            cb(pts[i][0], pts[i][1] + dy, w_head * body_width(t) * 0.5 * scale, acc, t)

    halo = col + (int(255 * GLOW_ALPHA),)
    walk(GLOW_MUL, w_head * SHADOW_DY_OVER_W,
         lambda x, y, r, dpx, t: d.ellipse([x - r, y - r, x + r, y + r], fill=halo))
    walk(1.0, 0.0, lambda x, y, r, dpx, t: d.ellipse(
        [x - r, y - r, x + r, y + r],
        fill=tuple(int(min(255, c * band_shade(dpx, w_head))) for c in col)
        + (int(255 * tail_alpha(t)),)))
    stripe = lightened(col, STRIPE_LIGHT)
    walk(STRIPE_W, 0.0, lambda x, y, r, dpx, t: d.ellipse(
        [x - r, y - r, x + r, y + r], fill=stripe + (int(255 * tail_alpha(t)),)))


def head_half_width(t, half):
    if t < HEAD_JAW_AT:
        return half * (HEAD_NOSE_W + (1.0 - HEAD_NOSE_W) * smoothstep(t / HEAD_JAW_AT))
    return half * (1.0 + (HEAD_NECK_W - 1.0) * smoothstep((t - HEAD_JAW_AT) / (1.0 - HEAD_JAW_AT)))


def draw_head(pts, w_head, col):
    """Same three ingredients as the body and NO dark outline — the body has none, and an outline
    on the head alone is what made it read as a separate object stuck on the front."""
    hx, hy = pts[-1]
    px, py = pts[-10]
    ang = math.atan2(hy - py, hx - px)
    ca, sa = math.cos(ang), math.sin(ang)
    ln = w_head * HEAD_LEN_W
    half = w_head * HEAD_WIDE_W * 0.5

    def tw(lx, ly):
        return (hx + ca * lx - sa * ly, hy + sa * lx + ca * ly)

    def outline(extra):
        up, lo = [], []
        for i in range(23):
            t = i / 22
            e = extra * (1.0 - smoothstep(max(0.0, (t - 0.45) / 0.55)))
            lx = ln * 0.5 - ln * t
            hw = head_half_width(t, half) + e
            up.append(tw(lx, -hw))
            lo.append(tw(lx, hw))
        hw1 = head_half_width(1.0, half)
        neck = [tw(-ln * 0.5 + math.cos(a) * hw1, math.sin(a) * hw1)
                for a in [-math.pi / 2 - k * math.pi / 9 for k in range(1, 9)]]
        hw0 = head_half_width(0.0, half) + extra
        nose = [tw(ln * 0.5 + math.cos(a) * hw0, math.sin(a) * hw0)
                for a in [math.pi / 2 - k * math.pi / 9 for k in range(1, 9)]]
        return up + neck + lo[::-1] + nose

    d.polygon(outline(w_head * (GLOW_MUL - 1.0) * 0.5), fill=col + (int(255 * GLOW_ALPHA),))
    for i in range(44):                              # banded fill, phase continuing the body's
        t0, t1 = i / 44, (i + 1) / 44
        lx0, lx1 = ln * 0.5 - ln * t0, ln * 0.5 - ln * t1
        h0, h1 = head_half_width(t0, half), head_half_width(t1, half)
        sh = band_shade(-(lx0 + lx1) * 0.5, w_head)
        d.polygon([tw(lx0, -h0), tw(lx1, -h1), tw(lx1, h1), tw(lx0, h0)],
                  fill=tuple(int(min(255, c * sh)) for c in col))
    d.line([tw(ln * 0.5 - ln * HEAD_STRIPE_FROM, 0.0), tw(-ln * 0.5, 0.0)],
           fill=lightened(col, STRIPE_LIGHT), width=max(1, int(w_head * STRIPE_W)))
    ex = ln * 0.5 - ln * HEAD_EYE_AT
    ey = head_half_width(HEAD_EYE_AT, half) * HEAD_EYE_OUT
    er = w_head * HEAD_EYE_R
    for sgn in (-1.0, 1.0):
        cx, cy = tw(ex, ey * sgn)
        d.ellipse([cx - er, cy - er, cx + er, cy + er], fill=(15, 13, 15, 255),
                  outline=lightened(col, 0.30) + (255,), width=max(1, int(w_head * 0.055)))


CYCLE, HEAD_X = W * 0.62, W * 0.84
MW, CW = W * 0.062, W * 0.052
m_pts = breath_path(-W * 0.10, HEAD_X, W * 0.30, W * 0.52, CYCLE, W * 0.10)
c_pts = breath_path(-W * 0.10, HEAD_X, W * 0.58, W * 0.80, CYCLE, W * 0.04)
draw_body(c_pts, CW, CHILD)
draw_head(c_pts, CW, CHILD)
draw_body(m_pts, MW, MOTHER)
draw_head(m_pts, MW, MOTHER)

depth = W * VIGNETTE_DEPTH
stepv = depth / VIGNETTE_STEPS
for i in range(VIGNETTE_STEPS):
    f = 1.0 - i / VIGNETTE_STEPS
    a = int(255 * VIGNETTE_MAX_A * f * f)
    o = i * stepv
    d.rectangle([0, o, W, o + stepv], fill=(0, 0, 0, a))
    d.rectangle([0, W - o - stepv, W, W - o], fill=(0, 0, 0, a))
    d.rectangle([o, 0, o + stepv, W], fill=(0, 0, 0, a))
    d.rectangle([W - o - stepv, 0, W - o, W], fill=(0, 0, 0, a))

img = img.resize((S, S), Image.LANCZOS).filter(ImageFilter.SHARPEN)
out = "/home/itamar/dev/grylpa/braingames/main/mother/art/game_screen_200.png"
img.save(out)
print("wrote", out, img.size)

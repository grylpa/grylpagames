"""Mother Snake chooser thumbnail — mirrors mother/scripts/level.gd's _do_draw.

Same palette constants and the same tapered-body construction, so the thumbnail cannot drift
from the game. Run after any palette or body-shape change.
"""
from PIL import Image, ImageDraw, ImageFilter
import math

S, SS = 200, 4
W = S * SS

GROUND_TOP = (22, 17, 20)
GROUND_BOTTOM = (37, 28, 27)
RIPPLE_LIGHT = (158, 128, 112)
RIPPLE_DARK = (10, 8, 10)
PEBBLE = (61, 48, 48, 191)
BUSH = (77, 59, 43, 204)
MOTHER = (224, 161, 77)
CHILD = (245, 217, 158)
SHADOW = (0, 0, 0, 71)

TAIL_FRAC = 0.58
STRIPE_W = 0.30
STRIPE_LIGHT = 0.55
EDGE_SOFT_MUL = 1.26
EDGE_SOFT_ALPHA = 0.26
EDGE_MUL = 1.20
HL_MUL = 0.34
HL_OFFSET = 0.22
SHADOW_DY = 7.0 / 200.0 * W


def darkened(c, amt):
    return tuple(int(v * (1.0 - amt)) for v in c)


def lightened(c, amt):
    return tuple(int(v + (255 - v) * amt) for v in c)


img = Image.new("RGB", (W, W), GROUND_TOP)
d = ImageDraw.Draw(img, "RGBA")

# --- ground: banded vertical gradient, cooler at the horizon ---
BANDS = 24
for i in range(BANDS):
    t = i / (BANDS - 1)
    col = tuple(int(GROUND_TOP[k] + (GROUND_BOTTOM[k] - GROUND_TOP[k]) * t) for k in range(3))
    d.rectangle([0, W * i / BANDS, W, W * (i + 1) / BANDS + 1], fill=col)

# --- sand ripples: light lines with a dark trough behind, as in the game ---
for y_frac, amp, period, phase, light in [
        (0.08, 0.009, 0.40, 1.7, True), (0.13, 0.010, 0.42, 0.4, False),
        (0.21, 0.008, 0.33, 2.1, True), (0.31, 0.011, 0.47, 4.0, False),
        (0.63, 0.013, 0.50, 1.2, True), (0.71, 0.009, 0.36, 2.6, False),
        (0.79, 0.010, 0.38, 3.4, True), (0.86, 0.012, 0.44, 1.0, False),
        (0.94, 0.012, 0.45, 0.9, True)]:
    pts = []
    for j in range(0, W + 8, 8):
        pts.append((j, y_frac * W + amp * W * math.sin(j * 2 * math.pi / (period * W) + phase)))
    col = RIPPLE_LIGHT + (56,) if light else RIPPLE_DARK + (85,)
    d.line(pts, fill=col, width=max(1, SS // 2), joint="curve")

# --- scattered ground detail ---
for x, y, r in [(0.10, 0.20, 0.010), (0.44, 0.90, 0.008), (0.72, 0.13, 0.007),
                (0.26, 0.44, 0.009), (0.88, 0.94, 0.008), (0.55, 0.35, 0.007),
                (0.34, 0.09, 0.006), (0.80, 0.42, 0.008)]:
    d.ellipse([W * (x - r), W * (y - r * 0.7), W * (x + r), W * (y + r * 0.7)], fill=PEBBLE)
# Dry bushes as UPWARD tufts sitting on the ground, not radial stars. The game draws them with
# spikes all round, which is fine at play size, but proportionally larger in a 200px thumbnail a
# full radial burst reads as a sparkle — and one placed high reads as a star in a sky.
for bx, by, br in [(0.13, 0.955, 0.030), (0.66, 0.055, 0.020), (0.93, 0.30, 0.022)]:
    cx, cy = W * bx, W * by
    for k in range(7):
        a = -math.pi / 2 + (k - 3) * 0.34
        rr = br * W * (0.62 + 0.38 * ((k * 7) % 5) / 5)
        d.line([cx, cy, cx + math.cos(a) * rr, cy + math.sin(a) * rr], fill=BUSH, width=max(1, SS - 1))


def smootherstep(x):
    x = max(0.0, min(1.0, x))
    return x * x * x * (x * (6 * x - 15) + 10)


def breath_path(x0, x1, top, bot, cycle_px, phase_px, n=260):
    """The mother's path: inhale up, hold, exhale down, hold — smootherstep eased (C2)."""
    inh, ht, exh = 0.36, 0.14, 0.36        # shares of the cycle; the rest is the bottom hold
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


def taper_poly(pts, w_head, w_scale, normal_shift, shift_xy):
    """Head is the LAST point (right-hand end), matching the guided mother path in level.gd."""
    n = len(pts)
    left, right = [], []
    for i, p in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(n - 1, i + 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        L = math.hypot(tx, ty) or 1.0
        nx, ny = -ty / L, tx / L
        t = 1.0 - i / (n - 1)                     # 0 at the head (last point), 1 at the tail
        hw = w_head * (1.0 + (TAIL_FRAC - 1.0) * t) * w_scale * 0.5
        cx = p[0] + shift_xy[0] + nx * normal_shift * w_head
        cy = p[1] + shift_xy[1] + ny * normal_shift * w_head
        left.append((cx + nx * hw, cy + ny * hw))
        right.append((cx - nx * hw, cy - ny * hw))
    return left + right[::-1]


# --- mirrors level.gd's constants -------------------------------------------------------------
BAND_PX_OVER_W = 15.0 / 18.0    # BAND_PX / MOTHER_W
BAND_DARK = 0.72
TAIL_SOLID = 0.82


def body_width(t):
    """Mirrors the Line2D width_curve: 1.0 at the head, 0.96 at 0.70, TAIL_FRAC at the tail."""
    if t <= 0.70:
        return 1.0 + (0.96 - 1.0) * (t / 0.70)
    return 0.96 + (TAIL_FRAC - 0.96) * ((t - 0.70) / 0.30)


def band_shade(dist_px, w_head):
    """Dark bands anchored in PIXELS from the head, as the game's Gradient now is."""
    period = BAND_PX_OVER_W * w_head
    phase = (dist_px / period) % 1.0
    # the gradient interpolates linearly between a light stop and a dark one
    tri = 1.0 - abs(phase * 2.0 - 1.0)
    return BAND_DARK + (1.0 - BAND_DARK) * tri


def draw_snake(pts, w_head, col):
    """Flat body colour + pixel-anchored dark bands + a dorsal stripe + a dissolving tail —
    the same four things the game draws, with no lattice and no cross-section texture (both were
    removed after they broke at the turns)."""
    total = sum(math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1])
                for i in range(len(pts) - 1))

    def walk(scale, dy, cb):
        acc = 0.0
        for i in range(len(pts) - 1, -1, -1):        # tail <- head; the head is the LAST point
            if i < len(pts) - 1:
                acc += math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1])
            t = acc / total
            r = w_head * body_width(t) * 0.5 * scale
            cb(pts[i][0], pts[i][1] + dy, r, acc, t)

    def tail_alpha(t):
        return 1.0 if t <= TAIL_SOLID else max(0.0, 1.0 - (t - TAIL_SOLID) / (1.0 - TAIL_SOLID))

    walk(0.92, SHADOW_DY, lambda x, y, r, d_px, t: d.ellipse(
        [x - r, y - r, x + r, y + r], fill=SHADOW))
    # soft edge: a wider, low-alpha pass in the body colour, so the silhouette feathers into the
    # ground instead of ending on a hard boundary
    halo = col + (int(255 * EDGE_SOFT_ALPHA),)
    walk(EDGE_SOFT_MUL, 0.0, lambda x, y, r, d_px, t: d.ellipse(
        [x - r, y - r, x + r, y + r], fill=halo))

    def body(x, y, r, d_px, t):
        sh = band_shade(d_px, w_head)
        a = int(255 * tail_alpha(t))
        c = tuple(int(min(255, cc * sh)) for cc in col)
        d.ellipse([x - r, y - r, x + r, y + r], fill=c + (a,))

    walk(1.0, 0.0, body)

    # The dorsal stripe is NOT banded: sharing the body's banding made it darker than the body's
    # lit regions in places, so the spine inverted along its length instead of reading as a line.
    stripe_col = lightened(col, STRIPE_LIGHT)

    def stripe(x, y, r, d_px, t):
        a = int(255 * tail_alpha(t))
        d.ellipse([x - r, y - r, x + r, y + r], fill=stripe_col + (a,))

    walk(STRIPE_W, 0.0, stripe)


def draw_head(pts, w_head, col):
    """Shaded like the body so it merges with it. The original thumbnail's heads were tiny white
    dots that vanished into the sand, which is much of why the paths read as a diagram."""
    hx, hy = pts[-1]
    px, py = pts[-8]
    ang = math.atan2(hy - py, hx - px)
    r = w_head * 0.66
    ca, sa = math.cos(ang), math.sin(ang)
    rim = darkened(col, 0.58)
    for pass_r, fill in ((r * 1.16, rim), (r, None)):
        steps = 26
        for k in range(steps):
            v = k / (steps - 1)
            off = (v - 0.5) * 2 * pass_r
            half = pass_r * math.sqrt(max(0.0, 1.0 - (off / pass_r) ** 2)) * 1.42
            x0 = hx - ca * half - sa * off
            y0 = hy - sa * half + ca * off
            x1 = hx + ca * half - sa * off
            y1 = hy + sa * half + ca * off
            c = fill if fill else tuple(int(min(255, cc * (0.86 + 0.14 * (1.0 - abs(v - 0.4) * 2)))) for cc in col)
            d.line([x0, y0, x1, y1], fill=c + (255,), width=max(2, int(2 * pass_r / steps) + SS))
    ex = hx + ca * r * 0.42 - sa * r * 0.34
    ey = hy + sa * r * 0.42 + ca * r * 0.34
    d.ellipse([ex - r * 0.20, ey - r * 0.20, ex + r * 0.20, ey + r * 0.20], fill=(16, 11, 9, 255))
    d.ellipse([ex - r * 0.07, ey - r * 0.11, ex + r * 0.03, ey - r * 0.01], fill=(255, 245, 230, 210))


CYCLE = W * 0.62
HEAD_X = W * 0.86
m_pts = breath_path(-W * 0.10, HEAD_X, W * 0.26, W * 0.50, CYCLE, W * 0.10)
c_pts = breath_path(-W * 0.10, HEAD_X, W * 0.52, W * 0.76, CYCLE, W * 0.04)

draw_snake(c_pts, W * 0.052, CHILD)
draw_head(c_pts, W * 0.052, CHILD)
draw_snake(m_pts, W * 0.075, MOTHER)
draw_head(m_pts, W * 0.075, MOTHER)

# vignette so the eye settles in the middle, same idea as aliens' field.gd
d = ImageDraw.Draw(img, "RGBA")
for i in range(14):
    a = int(34 * (1 - i / 14) ** 2)
    o = i * (W * 0.020)
    d.rectangle([0, o, W, o + W * 0.020], fill=(0, 0, 0, a))
    d.rectangle([0, W - o - W * 0.020, W, W - o], fill=(0, 0, 0, a))
    d.rectangle([o, 0, o + W * 0.020, W], fill=(0, 0, 0, a))
    d.rectangle([W - o - W * 0.020, 0, W - o, W], fill=(0, 0, 0, a))

img = img.resize((S, S), Image.LANCZOS).filter(ImageFilter.SHARPEN)
out = "/home/itamar/dev/grylpa/braingames/main/mother/art/game_screen_200.png"
img.save(out)
print("wrote", out, img.size)

class_name MosaicPicture
extends RefCounted

# The pictures Mosaic is played on, made on the CPU so a headless probe can make them too.
#
# Four kinds, chosen per level (MosaicLevelConfig "picture"), from most to least help to a player
# who would rather solve it as a jigsaw than remember it -- a continuous picture can be rebuilt by
# matching edges, so the kind is a difficulty dial for how much of the score is memory:
#   scenery  sky, sun, clouds, hills, trees and houses: coherent, memorable, edges help a lot
#   poster     a background and a few large flat shapes: fewer edge cues
#   quilt      every piece its own swatch, nothing crosses an edge: pure memory of where it was
#   dino       one of the shared dino cards (res://art/dinos): finite, so an occasional treat
#
# EVERY PIECE MUST LOOK DIFFERENT FROM EVERY OTHER. Two plain-sky squares are interchangeable, so a
# right answer could look wrong and a wrong one right. make() draws, cuts, compares each pair of
# pieces at low resolution, and draws again until they all differ -- and on a level with rotation,
# until no piece looks the same turned, since its correct orientation would be unknowable.
#
# Everything is drawn as horizontal spans with Image.fill_rect (fast, in C++); only the sky is
# computed per pixel, at a quarter of the resolution and scaled up.

# Every kind there is -- what an empty "picture" list in the level table means.
const KINDS: Array = ["scenery", "poster", "quilt", "dino"]
# The ones that can be rotated: everything but a dino card, which keeps its whole picture, so its
# pieces are not square. (Whether a quilt SHOULD be rotated is the level table's business.)
const ROTATABLE: Array = ["scenery", "poster", "quilt"]

const PIECE_PX: int = 128           # drawing resolution of one piece (shown at up to ~190 px)
const SIG_PX: int = 6               # pieces are compared at this size
const SAME_BELOW: float = 0.055     # mean channel difference under which two pieces are "the same"
# Turned, a piece only needs ONE visible difference for its right way up to be knowable -- a dot in
# a corner is enough to a person and hardly moves an average. So the rotation test looks at the
# most-changed quarter of the piece, not the whole of it.
const TURN_SAME_BELOW: float = 0.10
const TRIES: int = 40

static var _dino_paths: Array = []

static func make(kind: String, cols: int, rows: int, rotation_on: bool, rng: RandomNumberGenerator) -> Image:
	var best: Image = null
	var best_margin: float = -INF
	for _attempt in TRIES:
		var img: Image = draw(kind, cols, rows, rng, rotation_on)
		var m: float = margin(img, cols, rows, rotation_on)
		if m >= 1.0:
			return img
		if m > best_margin:
			best_margin = m
			best = img
	# Out of tries -- possible on the finest grids (measured at 5 x 6 with rotation: 3, 7 and 6
	# scenery pictures, posters and dino cards in 10 pass within 40 tries). Without rotation a quilt always
	# passes -- its squares are independent swatches, each with a shaded corner -- and the rule
	# matters more than the kind. With rotation the attempt that came closest stands instead: the level
	# table keeps quilts off rotation levels, and a fallback should not bring that combination back.
	if not rotation_on and kind != "quilt":
		return make("quilt", cols, rows, false, rng)
	return best

# How far a picture clears the rule, as a fraction of the threshold it is closest to failing:
# 1 or more passes. The pair test and (with rotation) the turn test both count.
static func margin(img: Image, cols: int, rows: int, rotation_on: bool) -> float:
	var sigs: Array = []
	for r in rows:
		for c in cols:
			sigs.append(signature(img, cols, rows, c, r))
	var worst: float = INF
	for i in sigs.size():
		for j in range(i + 1, sigs.size()):
			worst = minf(worst, difference(sigs[i], sigs[j]) / SAME_BELOW)
	if rotation_on:
		for r in rows:
			for c in cols:
				for t in range(1, 4):
					worst = minf(worst, peak_difference(sigs[r * cols + c], signature(img, cols, rows, c, r, t)) / TURN_SAME_BELOW)
	return worst

# `busy`: more, smaller things -- for a level with rotation, where every piece also needs a visible
# right way up and a big flat shape covering a whole piece has none.
static func draw(kind: String, cols: int, rows: int, rng: RandomNumberGenerator, busy: bool = false) -> Image:
	var w: int = cols * PIECE_PX
	var h: int = rows * PIECE_PX
	match kind:
		"poster":
			return _light(_poster(w, h, rng, busy), rng)
		"quilt":
			return _quilt(cols, rows, rng)
		"dino":
			var d: Image = _dino(w, rows, rng)
			if d != null:
				return d
			return _light(_scenery(w, h, rng, busy), rng)
	return _light(_scenery(w, h, rng, busy), rng)

# A soft light falloff across the whole picture, from one side to the other. A big flat shape can
# cover whole pieces in one colour -- identical to each other, and the same whichever way up -- and
# this gives every such piece a lighter and a darker side. Not the quilt (each square already has
# its shaded corner), and a dino card only on a level with rotation.
static func _light(img: Image, rng: RandomNumberGenerator) -> Image:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var dir: Vector2 = Vector2.from_angle(rng.randf() * TAU)
	var lay: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for gy in 16:
		for gx in 16:
			var t: float = clampf(0.5 + (Vector2(gx, gy) / 15.0 - Vector2(0.5, 0.5)).dot(dir), 0.0, 1.0)
			# light on one side, shade on the other, nothing in between
			if t < 0.5:
				lay.set_pixel(gx, gy, Color(1, 1, 1, (0.5 - t) * 0.50))
			else:
				lay.set_pixel(gx, gy, Color(0, 0, 0, (t - 0.5) * 0.50))
	lay.resize(w, h, Image.INTERPOLATE_BILINEAR)
	img.convert(Image.FORMAT_RGBA8)
	img.blend_rect(lay, Rect2i(0, 0, w, h), Vector2i.ZERO)
	img.convert(Image.FORMAT_RGB8)
	return img

# --- the rule: no two pieces alike ------------------------------------------------------------

# One piece's rectangle in the picture. Pieces are square except on a dino card, which keeps its
# whole picture and so its own proportions.
static func piece_rect(img: Image, cols: int, rows: int, col: int, row: int) -> Rect2i:
	var pw: int = int(img.get_width() / float(cols))
	var ph: int = int(img.get_height() / float(rows))
	return Rect2i(col * pw, row * ph, pw, ph)

static func signature(img: Image, cols: int, rows: int, col: int, row: int, turns: int = 0) -> Image:
	var piece: Image = img.get_region(piece_rect(img, cols, rows, col, row))
	piece.resize(SIG_PX, SIG_PX, Image.INTERPOLATE_BILINEAR)
	for _i in turns:
		piece.rotate_90(CLOCKWISE)
	return piece

static func difference(a: Image, b: Image) -> float:
	var total: float = 0.0
	for y in SIG_PX:
		for x in SIG_PX:
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			total += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
	return total / float(SIG_PX * SIG_PX * 3)

# The mean over the most different quarter of the pixels.
static func peak_difference(a: Image, b: Image) -> float:
	var diffs: Array = []
	for y in SIG_PX:
		for x in SIG_PX:
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			diffs.append((absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) / 3.0)
	diffs.sort()
	diffs.reverse()
	var n: int = maxi(1, int(diffs.size() * 0.25))
	var total: float = 0.0
	for i in n:
		total += float(diffs[i])
	return total / float(n)

static func pieces_distinct(img: Image, cols: int, rows: int, rotation_on: bool) -> bool:
	return margin(img, cols, rows, rotation_on) >= 1.0

# --- drawing primitives: spans ---------------------------------------------------------------

static func _span(img: Image, y: int, x0: float, x1: float, col: Color) -> void:
	if y < 0 or y >= img.get_height():
		return
	var a: int = clampi(int(roundf(x0)), 0, img.get_width())
	var b: int = clampi(int(roundf(x1)), 0, img.get_width())
	if b > a:
		img.fill_rect(Rect2i(a, y, b - a, 1), col)

static func _disc(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	for y in range(int(cy - r), int(cy + r) + 1):
		var dy: float = float(y) + 0.5 - cy
		if absf(dy) > r:
			continue
		var hw: float = sqrt(r * r - dy * dy)
		_span(img, y, cx - hw, cx + hw, col)

static func _ring(img: Image, cx: float, cy: float, r_out: float, r_in: float, col: Color) -> void:
	for y in range(int(cy - r_out), int(cy + r_out) + 1):
		var dy: float = float(y) + 0.5 - cy
		if absf(dy) > r_out:
			continue
		var ho: float = sqrt(r_out * r_out - dy * dy)
		if absf(dy) >= r_in:
			_span(img, y, cx - ho, cx + ho, col)
		else:
			var hi: float = sqrt(r_in * r_in - dy * dy)
			_span(img, y, cx - ho, cx - hi, col)
			_span(img, y, cx + hi, cx + ho, col)

# Any simple polygon, by scanline: the crossings of each row, sorted, filled in pairs.
static func _poly(img: Image, pts: PackedVector2Array, col: Color) -> void:
	var y0: float = INF
	var y1: float = -INF
	for p: Vector2 in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	for y in range(int(floorf(y0)), int(ceilf(y1)) + 1):
		var sy: float = float(y) + 0.5
		var xs: Array = []
		for i in pts.size():
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % pts.size()]
			if (a.y <= sy and b.y > sy) or (b.y <= sy and a.y > sy):
				xs.append(a.x + (sy - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		var k: int = 0
		while k + 1 < xs.size():
			_span(img, y, xs[k], xs[k + 1], col)
			k += 2

static func _rect(img: Image, x: float, y: float, w: float, h: float, col: Color) -> void:
	img.fill_rect(Rect2i(int(x), int(y), int(w), int(h)).intersection(Rect2i(0, 0, img.get_width(), img.get_height())), col)

static func _band(img: Image, cx: float, cy: float, length: float, width: float, ang: float, col: Color) -> void:
	var u: Vector2 = Vector2.from_angle(ang)
	var v: Vector2 = Vector2(-u.y, u.x)
	var c0: Vector2 = Vector2(cx, cy)
	_poly(img, PackedVector2Array([c0 - u * length - v * width, c0 + u * length - v * width,
		c0 + u * length + v * width, c0 - u * length + v * width]), col)

static func _hue(rng: RandomNumberGenerator, h: float, s: float, v: float) -> Color:
	return Color.from_hsv(fposmod(h + rng.randf_range(-0.03, 0.03), 1.0), clampf(s, 0.0, 1.0), clampf(v, 0.0, 1.0))

# --- scenery ---------------------------------------------------------------------------------

static func _scenery(w: int, h: int, rng: RandomNumberGenerator, busy: bool = false) -> Image:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
	var dusk: bool = rng.randf() < 0.4
	var top: Color = Color(0.20, 0.42, 0.78) if not dusk else Color(0.24, 0.20, 0.46)
	var low: Color = Color(0.72, 0.86, 0.96) if not dusk else Color(0.98, 0.62, 0.42)
	top = top.lerp(Color.from_hsv(rng.randf(), 0.5, 0.7), 0.15)
	var horizon: float = h * rng.randf_range(0.42, 0.55)
	var sun: Vector2 = Vector2(w * rng.randf_range(0.15, 0.85), horizon * rng.randf_range(0.25, 0.7))
	# the sky: a vertical gradient warmed and lightened round the sun, so no two sky pieces match
	var q: int = 4
	var sky: Image = Image.create(maxi(1, int(float(w) / q)), maxi(1, int(float(h) / q) + 1), false, Image.FORMAT_RGB8)
	var diag: float = Vector2(w, h).length()
	for y in sky.get_height():
		for x in sky.get_width():
			var t: float = float(y * q) / maxf(horizon, 1.0)
			var base: Color = top.lerp(low, clampf(t, 0.0, 1.0))
			var d: float = Vector2(x * q, y * q).distance_to(sun) / diag
			var glow: float = clampf(1.0 - d * 2.2, 0.0, 1.0)
			base = base.lerp(Color(1.0, 0.95, 0.80) if not dusk else Color(1.0, 0.80, 0.55), glow * glow * 0.75)
			base = base.lerp(Color(0.10, 0.12, 0.30), clampf(float(x * q) / float(w) - 0.5, 0.0, 0.5) * 0.25)
			sky.set_pixel(x, y, base)
	# over the WHOLE height: the hills dip below the horizon in places, and a sky that stopped at
	# the horizon left a black strip there
	sky.resize(w, h, Image.INTERPOLATE_BILINEAR)
	img.blit_rect(sky, Rect2i(0, 0, w, h), Vector2i.ZERO)
	_disc(img, sun.x, sun.y, h * rng.randf_range(0.05, 0.08), Color(1.0, 0.95, 0.70) if not dusk else Color(1.0, 0.85, 0.55))
	# clouds: a few clusters of discs
	for _k in (rng.randi_range(5, 7) if busy else rng.randi_range(2, 4)):
		var cx: float = rng.randf_range(0.0, w)
		var cy: float = rng.randf_range(horizon * 0.12, horizon * 0.75)
		var s: float = h * rng.randf_range(0.035, 0.06) * (0.75 if busy else 1.0)
		var cc: Color = Color(1, 1, 1) if not dusk else Color(1.0, 0.86, 0.80)
		for j in 5:
			_disc(img, cx + (j - 2) * s * 0.9, cy + absf(j - 2) * s * 0.25, s * (1.2 - absf(j - 2) * 0.2), cc)
	# birds -- a flock of small Vs -- so that pieces of open sky have something to show their right way up
	if busy:
		for _k in rng.randi_range(14, 20):
			var bx: float = rng.randf_range(0.0, w)
			var by: float = rng.randf_range(horizon * 0.1, horizon * 0.85)
			var bs: float = h * rng.randf_range(0.012, 0.02)
			var bc: Color = Color(0.15, 0.15, 0.22)
			_poly(img, PackedVector2Array([Vector2(bx - bs * 1.6, by - bs * 0.6), Vector2(bx, by + bs * 0.2), Vector2(bx + bs * 1.6, by - bs * 0.6),
				Vector2(bx + bs * 1.6, by - bs * 0.2), Vector2(bx, by + bs * 0.7), Vector2(bx - bs * 1.6, by - bs * 0.2)]), bc)
	# two ranges of hills, far and pale, near and darker
	var far_col: Color = _hue(rng, rng.randf_range(0.55, 0.75), 0.30, 0.55 if not dusk else 0.40)
	var near_col: Color = _hue(rng, rng.randf_range(0.22, 0.38), 0.55, 0.55 if not dusk else 0.35)
	for layer in 2:
		var col: Color = far_col if layer == 0 else near_col
		var base_y: float = horizon + (0.0 if layer == 0 else h * 0.12)
		var amp: float = h * (0.10 if layer == 0 else 0.07)
		var f1: float = rng.randf_range(1.0, 2.5)
		var f2: float = rng.randf_range(3.0, 6.0)
		var p1: float = rng.randf() * TAU
		var p2: float = rng.randf() * TAU
		for x in w:
			var t: float = float(x) / float(w) * TAU
			var top_y: float = base_y - amp * (0.6 * sin(f1 * t + p1) + 0.4 * sin(f2 * t + p2) + 0.5)
			img.fill_rect(Rect2i(x, int(top_y), 1, h - int(top_y)), col)
	# fields in the foreground: bands of green and gold, so the bottom rows have features too
	var ground_top: float = horizon + h * 0.16
	var nbands: int = rng.randi_range(3, 5)
	for b in nbands:
		var y0: float = ground_top + (h - ground_top) * float(b) / nbands
		var y1: float = ground_top + (h - ground_top) * float(b + 1) / nbands
		var tilt: float = rng.randf_range(-0.12, 0.12) * h
		var fc: Color = _hue(rng, rng.randf_range(0.12, 0.33), rng.randf_range(0.45, 0.7), rng.randf_range(0.45, 0.75) * (0.75 if dusk else 1.0))
		_poly(img, PackedVector2Array([Vector2(0, y0), Vector2(w, y0 + tilt), Vector2(w, y1 + tilt), Vector2(0, y1)]), fc)
	# flowers in the fields, on a rotation level: field pieces otherwise differ only by their bands
	if busy:
		for _k in rng.randi_range(40, 60):
			var fx: float = rng.randf_range(0.0, w)
			var fy: float = rng.randf_range(ground_top, h)
			var fr: float = h * rng.randf_range(0.006, 0.012)
			var fcol: Color = [Color(1, 1, 1), Color(1.0, 0.85, 0.2), Color(0.95, 0.4, 0.5), Color(0.6, 0.5, 0.95)][rng.randi_range(0, 3)]
			_disc(img, fx, fy, fr, fcol)
	# trees and houses along the near hills and the fields
	for _k in (rng.randi_range(9, 13) if busy else rng.randi_range(4, 7)):
		var tx: float = rng.randf_range(0.0, w)
		var ty: float = rng.randf_range(horizon + h * 0.10, h * 0.95)
		var s: float = h * rng.randf_range(0.03, 0.06) * (0.6 + 0.6 * (ty - horizon) / (h - horizon))
		if rng.randf() < 0.65:
			_rect(img, tx - s * 0.12, ty - s * 0.4, s * 0.24, s * 1.0, Color(0.30, 0.20, 0.12))
			_disc(img, tx, ty - s * 0.9, s * 0.75, _hue(rng, rng.randf_range(0.25, 0.38), 0.6, 0.35 if not dusk else 0.25))
		else:
			var wall: Color = _hue(rng, rng.randf_range(0.0, 1.0), 0.25, 0.9 if not dusk else 0.6)
			_rect(img, tx - s, ty - s, s * 2.0, s * 1.2, wall)
			_poly(img, PackedVector2Array([Vector2(tx - s * 1.2, ty - s), Vector2(tx, ty - s * 1.9), Vector2(tx + s * 1.2, ty - s)]),
				_hue(rng, rng.randf_range(0.0, 0.08), 0.65, 0.65))
			_rect(img, tx - s * 0.25, ty - s * 0.55, s * 0.5, s * 0.75, Color(0.25, 0.18, 0.14))
	return img

# --- poster ------------------------------------------------------------------------------------

static func _poster(w: int, h: int, rng: RandomNumberGenerator, busy: bool = false) -> Image:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
	var h0: float = rng.randf()
	var pal: Array = []
	for i in 5:
		pal.append(Color.from_hsv(fposmod(h0 + i * rng.randf_range(0.15, 0.25), 1.0), rng.randf_range(0.45, 0.85), rng.randf_range(0.55, 0.95)))
	# The ground is a gentle diagonal gradient, not one flat colour: a piece of bare background then
	# still shows which way up it goes, which a level with rotation needs.
	var g0: Color = Color.from_hsv(fposmod(h0 + 0.5, 1.0), 0.18, 0.95)
	var g1: Color = Color.from_hsv(fposmod(h0 + 0.62, 1.0), 0.35, 0.70)
	var gang: Vector2 = Vector2.from_angle(rng.randf() * TAU)
	var lo: Image = Image.create(16, 16, false, Image.FORMAT_RGB8)
	for gy in 16:
		for gx in 16:
			var t: float = clampf(0.5 + (Vector2(gx, gy) / 15.0 - Vector2(0.5, 0.5)).dot(gang) * 0.95, 0.0, 1.0)
			lo.set_pixel(gx, gy, g0.lerp(g1, t))
	lo.resize(w, h, Image.INTERPOLATE_BILINEAR)
	img.blit_rect(lo, Rect2i(0, 0, w, h), Vector2i.ZERO)
	# a diagonal two-tone split of the ground first
	var a: Vector2 = Vector2(rng.randf_range(0, w), 0)
	var b: Vector2 = Vector2(rng.randf_range(0, w), h)
	var split: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	_poly(split, PackedVector2Array([a, Vector2(w, 0), Vector2(w, h), b]), Color((pal[4] as Color).r, (pal[4] as Color).g, (pal[4] as Color).b, 0.45))
	img.convert(Image.FORMAT_RGBA8)
	img.blend_rect(split, Rect2i(0, 0, w, h), Vector2i.ZERO)
	img.convert(Image.FORMAT_RGB8)
	var big: float = minf(w, h)
	var scale_k: float = 0.55 if busy else 1.0
	for k in (rng.randi_range(10, 13) if busy else rng.randi_range(5, 7)):
		var col: Color = pal[k % 4]
		var cx: float = rng.randf_range(0.0, w)
		var cy: float = rng.randf_range(0.0, h)
		match rng.randi_range(0, 4):
			0:
				_disc(img, cx, cy, big * scale_k * rng.randf_range(0.14, 0.30), col)
			1:
				var ro: float = big * scale_k * rng.randf_range(0.16, 0.30)
				_ring(img, cx, cy, ro, ro * rng.randf_range(0.55, 0.75), col)
			2:
				_band(img, cx, cy, big * scale_k * rng.randf_range(0.4, 0.8), big * rng.randf_range(0.04, 0.08), rng.randf() * PI, col)
			3:
				var r: float = big * scale_k * rng.randf_range(0.18, 0.32)
				var t0: float = rng.randf() * TAU
				_poly(img, PackedVector2Array([Vector2(cx, cy) + Vector2.from_angle(t0) * r,
					Vector2(cx, cy) + Vector2.from_angle(t0 + TAU / 3.0) * r,
					Vector2(cx, cy) + Vector2.from_angle(t0 + 2.0 * TAU / 3.0) * r]), col)
			_:
				var r2: float = big * scale_k * rng.randf_range(0.15, 0.28)
				var pts: PackedVector2Array = PackedVector2Array()
				var st: float = rng.randf() * TAU
				for i in 13:
					pts.append(Vector2(cx, cy) + Vector2.from_angle(st + PI * float(i) / 12.0) * r2)
				_poly(img, pts, col)
	# a scatter of dots of several sizes, light and dark, so large flat areas carry detail too
	for _k in (rng.randi_range(60, 80) if busy else rng.randi_range(26, 40)):
		var dc: Color = (pal[0] as Color).darkened(0.35) if rng.randf() < 0.6 else (pal[3] as Color).lightened(0.45)
		_disc(img, rng.randf_range(0, w), rng.randf_range(0, h), big * rng.randf_range(0.010, 0.035), dc)
	return img

# --- quilt -------------------------------------------------------------------------------------

const PATTERNS: Array = ["hstripes", "vstripes", "diag", "dots", "checks", "rings", "chevron", "big_dot"]

static func _quilt(cols: int, rows: int, rng: RandomNumberGenerator) -> Image:
	var p: int = PIECE_PX
	var img: Image = Image.create(cols * p, rows * p, false, Image.FORMAT_RGB8)
	var combos: Array = []
	for pat in PATTERNS:
		for hi in 8:
			combos.append([pat, hi])
	combos.shuffle()
	var h0: float = rng.randf()
	for r in rows:
		for c in cols:
			var combo: Array = combos[(r * cols + c) % combos.size()]
			var hue: float = fposmod(h0 + float(combo[1]) / 8.0, 1.0)
			var base: Color = Color.from_hsv(hue, rng.randf_range(0.45, 0.7), rng.randf_range(0.70, 0.92))
			var ink: Color = Color.from_hsv(fposmod(hue + rng.randf_range(0.35, 0.6), 1.0), 0.6, rng.randf_range(0.25, 0.5))
			img.blit_rect(_swatch(p, str(combo[0]), base, ink, rng), Rect2i(0, 0, p, p), Vector2i(c * p, r * p))
	return img

# One square of the quilt. A shaded corner, at a random corner, makes every swatch look different
# turned -- stripes and dots alone look the same at 180 degrees, so their right way up would be
# unknowable on a level with rotation.
static func _swatch(p: int, pat: String, base: Color, ink: Color, rng: RandomNumberGenerator) -> Image:
	# Drawn on its own square and copied in, so nothing (the diagonal stripes) spills into a neighbour.
	var img: Image = Image.create(p, p, false, Image.FORMAT_RGB8)
	img.fill(base)
	var corner: int = rng.randi_range(0, 3)
	var s: float = float(p)
	var cx: float = 0.0 if corner % 2 == 0 else s
	var cy: float = 0.0 if corner < 2 else s
	_poly(img, PackedVector2Array([Vector2(cx, cy), Vector2(cx + (s * 0.7 if corner % 2 == 0 else -s * 0.7), cy),
		Vector2(cx, cy + (s * 0.7 if corner < 2 else -s * 0.7))]), base.darkened(0.45))
	match pat:
		"hstripes":
			for k in 4:
				_rect(img, 0, s * (0.08 + k * 0.25), s, s * 0.09, ink)
		"vstripes":
			for k in 4:
				_rect(img, s * (0.08 + k * 0.25), 0, s * 0.09, s, ink)
		"diag":
			for k in range(-2, 3):
				var o: float = k * s * 0.32
				_poly(img, PackedVector2Array([Vector2(o, s), Vector2(o + s * 0.1, s), Vector2(o + s * 1.1, 0), Vector2(o + s, 0)]), ink)
		"dots":
			for yy in 3:
				for xx in 3:
					_disc(img, s * (0.2 + xx * 0.3), s * (0.2 + yy * 0.3), s * 0.08, ink)
		"checks":
			for yy in 4:
				for xx in 4:
					if (xx + yy) % 2 == 0:
						_rect(img, s * xx * 0.25, s * yy * 0.25, s * 0.25, s * 0.25, ink)
		"rings":
			_ring(img, s * 0.5, s * 0.5, s * 0.40, s * 0.30, ink)
			_ring(img, s * 0.5, s * 0.5, s * 0.20, s * 0.11, ink)
		"chevron":
			for k in 3:
				var yy0: float = s * (0.15 + k * 0.28)
				_poly(img, PackedVector2Array([Vector2(0, yy0), Vector2(s * 0.5, yy0 + s * 0.18), Vector2(s, yy0),
					Vector2(s, yy0 + s * 0.09), Vector2(s * 0.5, yy0 + s * 0.27), Vector2(0, yy0 + s * 0.09)]), ink)
		_:
			_disc(img, s * 0.5, s * 0.5, s * 0.30, ink)
	return img

# --- dino --------------------------------------------------------------------------------------

# THE WHOLE CARD, never cropped: scaled to the board's width, its height following the card's own
# proportions (rounded to whole rows, a difference of under a percent). So the board takes the
# card's shape and its pieces are a little taller than wide -- which is why a dino card is never on a
# level with rotation (a quarter turn would not fit its cell back in).
static func _dino(w: int, rows: int, rng: RandomNumberGenerator) -> Image:
	if _dino_paths.is_empty():
		for i in range(1, 400):
			var path: String = "res://art/dinos/dino%d.jpg" % i
			if ResourceLoader.exists(path):
				_dino_paths.append(path)
	if _dino_paths.is_empty():
		return null
	var tex: Texture2D = load(_dino_paths[rng.randi_range(0, _dino_paths.size() - 1)]) as Texture2D
	if tex == null:
		return null
	var src: Image = tex.get_image()
	if src == null:
		return null
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGB8)
	var aspect: float = float(src.get_height()) / float(src.get_width())
	var ph: int = maxi(8, int(round(float(w) * aspect / float(rows))))
	src.resize(w, ph * rows, Image.INTERPOLATE_BILINEAR)
	return src

extends Node2D

# Draws everything behind the aliens: an alien night sky (gradient, a faint nebula, drifting stars,
# vignette), then the HALL -- the spaceport's deck, dark neutral plates with guide lights round its
# edge -- and each gate: a metal queue ring with its guide lights round a softly glowing boarding
# pad, plus a "GATE FULL" badge when an outer ring has no room. level.gd owns `areas` and calls
# queue_redraw() on state changes.
#
# THE HALL AND THE GATES ARE NEUTRAL (slate, silver, a white glow), never a hue. Color is one of the
# traits the player judges, and the old teal-green sky and green rings sat close to the green alien;
# a neutral ground lets all five colors stand out the same. Nothing back here is round except the
# gates themselves: every circle in this game means one.
#
# The sky is deliberately low-contrast and slow: the aliens are small, numerous and always moving,
# so anything back here that draws the eye competes with the thing the player must actually track.

var areas: Array = []                       # the level's area dictionaries (read-only here)
var field_rect: Rect2 = Rect2(0, 0, 10, 10)
var alien_radius: float = 33.0
var highlight_inner: int = -1               # area index whose inner ring is a legal drop target
var highlight_outer: int = -1               # area index whose outer ring is the drag origin

const RING_BG: Color = Color(0.135, 0.145, 0.170, 0.95)     # the queue ring's metal
const INNER_BG: Color = Color(0.235, 0.250, 0.290, 1.0)     # the boarding pad
const RING_LINE: Color = Color(0.66, 0.70, 0.78, 0.85)
const INNER_LINE: Color = Color(0.88, 0.91, 0.98, 0.90)
const GUIDE_LIGHT: Color = Color(0.80, 0.88, 1.0, 0.60)
const PAD_GLOW: Color = Color(0.86, 0.89, 1.0)
const DECK: Color = Color(0.105, 0.112, 0.130)
const FULL_COL: Color = Color(1.0, 0.45, 0.35, 0.95)

# --- sky ---
const SKY_TOP: Color = Color(0.025, 0.028, 0.055)     # near-black overhead
const SKY_BOTTOM: Color = Color(0.070, 0.060, 0.120)  # deep indigo low down (it was teal-green)
const SKY_BANDS: int = 40
const STAR_COUNT: int = 70
const STAR_DRIFT: float = 3.0                         # px/sec — slow enough to never read as an alien
const VIGNETTE_STEPS: int = 10
const VIGNETTE_DEPTH: float = 0.26                    # fraction of the short side that is darkened

var _stars: Array = []          # [{p: Vector2 (0..1 normalized), r: float, a: float}]
var _drift: float = 0.0
var _clock: float = 0.0
var _nebula: ImageTexture = null
var _sky_size: Vector2 = Vector2(680, 748)

func _ready() -> void:
	_sky_size = Vector2(MainGlobals.screen_size)
	_build_stars()
	set_process(true)

# The sky spans the whole screen, so it has to follow a relayout.
func set_sky_size(sz: Vector2) -> void:
	if sz.x > 1.0 and sz.y > 1.0:
		_sky_size = sz

func _process(delta: float) -> void:
	_drift += delta * STAR_DRIFT
	_clock += delta
	queue_redraw()

# A fresh scatter each level. Determinism matters for the SIMULATION (so tests are repeatable and
# behavior is reproducible), but the sky is pure decoration — nothing reads it, nothing compares
# it between runs, so pinning it only threw away free variety.
func rebuild_sky() -> void:
	_build_stars()
	queue_redraw()

func _build_stars() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	_build_nebula(rng.randi())
	_stars.clear()
	for _i in STAR_COUNT:
		var big: bool = rng.randf() < 0.16
		_stars.append({
			"p": Vector2(rng.randf(), rng.randf()),
			"r": rng.randf_range(1.6, 2.6) if big else rng.randf_range(0.7, 1.3),
			"a": rng.randf_range(0.55, 0.95) if big else rng.randf_range(0.20, 0.55),
		})

func _draw_sky() -> void:
	var w: float = _sky_size.x
	var h: float = _sky_size.y
	# vertical gradient, as bands (cheap and invisible at this contrast)
	var band_h: float = h / float(SKY_BANDS)
	for i in SKY_BANDS:
		var t: float = float(i) / float(SKY_BANDS - 1)
		draw_rect(Rect2(0.0, float(i) * band_h, w, band_h + 1.0), SKY_TOP.lerp(SKY_BOTTOM, t), true)

	# a faint nebula: soft wisps of violet and blue, no edges, no discs
	if _nebula != null:
		draw_texture_rect(_nebula, Rect2(Vector2.ZERO, _sky_size), false)

	# NO planets, moons or any other large disc back here: every circle in this game MEANS
	# something (outer ring, inner ring), so a big circle in the background gets read as a target
	# area. Stars are fine — they are far too small to be confused with anything.

	# stars, drifting slowly and wrapping
	for st in _stars:
		var pn: Vector2 = st["p"]
		var x: float = fposmod(pn.x * w + _drift * 0.35, w)
		var y: float = fposmod(pn.y * h + _drift, h)
		draw_circle(Vector2(x, y), float(st["r"]), Color(0.86, 0.92, 1.0, float(st["a"])))

	# vignette: darken the edges so the eye settles on the center of the board
	var depth: float = minf(w, h) * VIGNETTE_DEPTH
	var step: float = depth / float(VIGNETTE_STEPS)
	for i in VIGNETTE_STEPS:
		var f: float = 1.0 - float(i) / float(VIGNETTE_STEPS)
		var a: float = 0.30 * f * f
		var o: float = float(i) * step
		draw_rect(Rect2(0.0, o, w, step), Color(0, 0, 0, a), true)
		draw_rect(Rect2(0.0, h - o - step, w, step), Color(0, 0, 0, a), true)
		draw_rect(Rect2(o, 0.0, step, h), Color(0, 0, 0, a), true)
		draw_rect(Rect2(w - o - step, 0.0, step, h), Color(0, 0, 0, a), true)


# The nebula: one small image of two noise fields (violet and blue wisps), stretched over the sky
# with linear filtering. Low alpha, so it is a tint in the dark and never a shape.
func _build_nebula(seed_val: int) -> void:
	var w: int = 48
	var h: int = 56
	var n1: FastNoiseLite = FastNoiseLite.new()
	n1.seed = seed_val
	n1.frequency = 0.05
	n1.fractal_octaves = 3
	var n2: FastNoiseLite = FastNoiseLite.new()
	n2.seed = seed_val + 7
	n2.frequency = 0.07
	n2.fractal_octaves = 3
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var a: float = smoothstep(0.05, 0.6, n1.get_noise_2d(float(x), float(y)))
			var b: float = smoothstep(0.10, 0.6, n2.get_noise_2d(float(x), float(y)))
			var col: Color = Color(0.45, 0.25, 0.70).lerp(Color(0.20, 0.35, 0.75), b / maxf(a + b, 0.001))
			col.a = clampf(a * 0.16 + b * 0.12, 0.0, 0.22)
			img.set_pixel(x, y, col)
	_nebula = ImageTexture.create_from_image(img)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

# THE HALL: square deck plates, each a shade off its neighbours, with bevelled seams (a dark line and
# a pale one beside it), a rivet at each corner, a broad sheen from the top left, a darker inner edge
# and small guide lights along all four sides. Static: nothing in the hall moves but the aliens.
func _draw_hall() -> void:
	var fr: Rect2 = field_rect
	draw_rect(fr, DECK, true)
	var plate: float = maxf(60.0, alien_radius * 5.0)
	var cols: int = int(ceil(fr.size.x / plate))
	var rows: int = int(ceil(fr.size.y / plate))
	for j in rows:
		for i in cols:
			var h: float = fposmod(sin(float(i * 31 + j * 17) * 12.9898) * 43758.5453, 1.0)
			var rr: Rect2 = Rect2(fr.position + Vector2(float(i), float(j)) * plate, Vector2(plate, plate)).intersection(fr)
			draw_rect(rr, Color(1, 1, 1, 0.012 + 0.022 * h), true)
	for i2 in range(1, cols):
		var x: float = fr.position.x + float(i2) * plate
		draw_line(Vector2(x, fr.position.y), Vector2(x, fr.end.y), Color(0, 0, 0, 0.28), 1.5)
		draw_line(Vector2(x + 1.5, fr.position.y), Vector2(x + 1.5, fr.end.y), Color(1, 1, 1, 0.035), 1.0)
	for j2 in range(1, rows):
		var y: float = fr.position.y + float(j2) * plate
		draw_line(Vector2(fr.position.x, y), Vector2(fr.end.x, y), Color(0, 0, 0, 0.28), 1.5)
		draw_line(Vector2(fr.position.x, y + 1.5), Vector2(fr.end.x, y + 1.5), Color(1, 1, 1, 0.035), 1.0)
	for j3 in range(1, rows):
		for i3 in range(1, cols):
			var rv: Vector2 = fr.position + Vector2(float(i3), float(j3)) * plate
			for d: Vector2 in [Vector2(-5, -5), Vector2(5, -5), Vector2(-5, 5), Vector2(5, 5)]:
				draw_rect(Rect2(rv + d - Vector2.ONE, Vector2(2, 2)), Color(1, 1, 1, 0.05), true)
	# a broad sheen from the top left, fading out by the middle
	draw_polygon(PackedVector2Array([fr.position, Vector2(fr.end.x, fr.position.y), fr.end,
		Vector2(fr.position.x, fr.end.y)]), PackedColorArray([Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.015),
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.015)]))
	# a darker band just inside the edge, then the guide lights
	for k in 6:
		var f: float = 1.0 - float(k) / 6.0
		draw_rect(fr.grow(-float(k) * 2.0), Color(0, 0, 0, 0.10 * f), false, 2.0)
	var gap: float = 34.0
	var x2: float = fr.position.x + gap * 0.5
	while x2 < fr.end.x:
		for gy: float in [fr.position.y + 5.0, fr.end.y - 5.0]:
			draw_rect(Rect2(x2 - 2.0, gy - 1.0, 4.0, 2.0), GUIDE_LIGHT, true)
		x2 += gap
	var y2: float = fr.position.y + gap * 0.5
	while y2 < fr.end.y:
		for gx: float in [fr.position.x + 5.0, fr.end.x - 5.0]:
			draw_rect(Rect2(gx - 1.0, y2 - 2.0, 2.0, 4.0), GUIDE_LIGHT, true)
		y2 += gap

# A smooth radial falloff for the pad's glow: one texture, scaled, so there are no stepped rings.
static var _glow: ImageTexture = null

static func _glow_tex() -> Texture2D:
	if _glow == null:
		var n: int = 64
		var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
		var c: float = float(n) * 0.5
		for y in n:
			for x in n:
				var d: float = Vector2(float(x) + 0.5 - c, float(y) + 0.5 - c).length() / c
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 1.3))
		_glow = ImageTexture.create_from_image(img)
	return _glow

static var _font: Font = null

static func _badge_font() -> Font:
	if _font == null:
		var sf: SystemFont = SystemFont.new()
		sf.font_names = PackedStringArray(["Arial Black", "Open Sans Bold", "DejaVu Sans", "sans-serif"])
		sf.font_weight = 800
		_font = sf
	return _font

func _draw() -> void:
	_draw_sky()
	_draw_hall()

	var breathe: float = 0.85 + 0.15 * sin(_clock * 1.6)
	for i in areas.size():
		var ar: Dictionary = areas[i]
		var c: Vector2 = Vector2(ar["center"])
		var r_in: float = float(ar["r_in"])
		var r_out: float = float(ar["r_out"])

		# Rings are NOT tinted by polarity. A deny gate is carried by the word NOT in the caption
		# and nothing else — see docs/design.md "Polarity has no color".

		# the queue ring: a metal band set into the deck, its edge bevelled (lit top left, shaded
		# bottom right), with guide lights round it
		draw_circle(c + Vector2(2.0, 3.0), r_out + 2.0, Color(0, 0, 0, 0.35))
		draw_circle(c, r_out, RING_BG)
		var out_line: Color = RING_LINE
		var out_w: float = 3.0
		if highlight_outer == i:
			out_line = Color(1.0, 0.95, 0.55, 0.85)
			out_w = 4.0
		draw_arc(c, r_out, 0.0, TAU, 72, out_line, out_w, true)
		draw_arc(c, r_out - 3.0, PI * 0.95, PI * 1.55, 24, Color(1, 1, 1, 0.22), 2.0, true)
		draw_arc(c, r_out - 3.0, -0.05, PI * 0.55, 24, Color(0, 0, 0, 0.35), 2.0, true)
		var n_lights: int = 16
		for k in n_lights:
			var lp: Vector2 = c + Vector2.from_angle(TAU * float(k) / float(n_lights)) * (r_out - 8.0)
			draw_rect(Rect2(lp - Vector2(1.5, 1.5), Vector2(3, 3)), Color(GUIDE_LIGHT, GUIDE_LIGHT.a * breathe), true)

		# the boarding pad: raised a step (its own shadow on the ring), glowing softly from the
		# middle, the glow breathing slowly
		draw_circle(c + Vector2(1.5, 2.5), r_in + 1.0, Color(0, 0, 0, 0.40))
		draw_circle(c, r_in, INNER_BG)
		draw_texture_rect(_glow_tex(), Rect2(c - Vector2(r_in, r_in), Vector2(r_in, r_in) * 2.0), false,
			Color(PAD_GLOW, 0.30 * breathe))
		var in_line: Color = INNER_LINE
		var in_w: float = 3.0
		if highlight_inner == i:
			in_line = Color(0.45, 1.0, 0.60, 1.0)
			in_w = 5.0
		draw_arc(c, r_in, 0.0, TAU, 64, in_line, in_w, true)
		draw_arc(c, r_in - 3.5, PI * 0.95, PI * 1.55, 24, Color(1, 1, 1, 0.25), 1.5, true)

		# the outer ring has no fixed places: draw the parking LANE aliens pack along
		draw_arc(c, float(ar["s_out"]), 0.0, TAU, 64, Color(1, 1, 1, 0.07),
			alien_radius * 1.5, true)

		if int(ar.get("parked", 0)) >= int(ar.get("capacity", 99)):
			_draw_full_badge(c, r_out)

func _draw_full_badge(c: Vector2, r_out: float) -> void:
	var f: Font = _badge_font()
	var fs: int = maxi(12, int(alien_radius * 0.52))
	var txt: String = "GATE FULL"
	var ss: Vector2 = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos: Vector2 = Vector2(c.x - ss.x * 0.5, c.y + r_out + ss.y * 0.95)
	draw_rect(Rect2(pos.x - 8.0, pos.y - ss.y * 0.82, ss.x + 16.0, ss.y * 1.12),
		Color(0.25, 0.05, 0.03, 0.72), true)
	draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, FULL_COL)

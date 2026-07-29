extends Node2D

# Draws everything behind the aliens: an alien night sky (gradient, drifting stars, vignette),
# then the field panel and each target area's two rings, plus a "FULL" badge
# when an outer ring has no room. level.gd owns `areas` and calls queue_redraw() on state changes.
#
# The sky is deliberately low-contrast and slow: the aliens are small, numerous and always moving,
# so anything back here that draws the eye competes with the thing the player must actually track.

var areas: Array = []                       # the level's area dictionaries (read-only here)
var field_rect: Rect2 = Rect2(0, 0, 10, 10)
var alien_radius: float = 33.0
var highlight_inner: int = -1               # area index whose inner ring is a legal drop target
var highlight_outer: int = -1               # area index whose outer ring is the drag origin

const RING_BG: Color = Color(0.10, 0.20, 0.15, 0.55)
const INNER_BG: Color = Color(0.16, 0.34, 0.24, 0.75)
const RING_LINE: Color = Color(0.65, 0.90, 0.72, 0.55)
const INNER_LINE: Color = Color(0.85, 1.00, 0.88, 0.75)
const FULL_COL: Color = Color(1.0, 0.45, 0.35, 0.95)

# --- sky ---
const SKY_TOP: Color = Color(0.030, 0.045, 0.070)     # near-black overhead
const SKY_BOTTOM: Color = Color(0.075, 0.185, 0.150)  # deep teal-green at the horizon
const SKY_BANDS: int = 40
const STAR_COUNT: int = 70
const STAR_DRIFT: float = 3.0                         # px/sec — slow enough to never read as an alien
const VIGNETTE_STEPS: int = 10
const VIGNETTE_DEPTH: float = 0.26                    # fraction of the short side that is darkened

var _stars: Array = []          # [{p: Vector2 (0..1 normalised), r: float, a: float}]
var _drift: float = 0.0
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
	queue_redraw()

# A fresh scatter each level. Determinism matters for the SIMULATION (so tests are repeatable and
# behaviour is reproducible), but the sky is pure decoration — nothing reads it, nothing compares
# it between runs, so pinning it only threw away free variety.
func rebuild_sky() -> void:
	_build_stars()
	queue_redraw()

func _build_stars() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
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

	# NO planets, moons or any other large disc back here: every circle in this game MEANS
	# something (outer ring, inner ring), so a big circle in the background gets read as a target
	# area. Stars are fine — they are far too small to be confused with anything.

	# stars, drifting slowly and wrapping
	for st in _stars:
		var pn: Vector2 = st["p"]
		var x: float = fposmod(pn.x * w + _drift * 0.35, w)
		var y: float = fposmod(pn.y * h + _drift, h)
		draw_circle(Vector2(x, y), float(st["r"]), Color(0.86, 0.92, 1.0, float(st["a"])))

	# vignette: darken the edges so the eye settles on the middle of the board
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
	# field backdrop — a slightly lighter panel so the play area reads as a place
	draw_rect(field_rect, Color(1, 1, 1, 0.035), true)
	draw_rect(field_rect, Color(1, 1, 1, 0.10), false, 2.0)

	for i in areas.size():
		var ar: Dictionary = areas[i]
		var c: Vector2 = Vector2(ar["center"])
		var r_in: float = float(ar["r_in"])
		var r_out: float = float(ar["r_out"])

		# outer disc (the annulus reads as the band between the two outlines)
		draw_circle(c, r_out, RING_BG)
		var out_line: Color = RING_LINE
		var out_w: float = 3.0
		if highlight_outer == i:
			out_line = Color(1.0, 0.95, 0.55, 0.85)
			out_w = 4.0
		draw_arc(c, r_out, 0.0, TAU, 72, out_line, out_w, true)

		# inner disc
		draw_circle(c, r_in, INNER_BG)
		var in_line: Color = INNER_LINE
		var in_w: float = 3.0
		if highlight_inner == i:
			in_line = Color(0.45, 1.0, 0.60, 1.0)
			in_w = 5.0
		draw_arc(c, r_in, 0.0, TAU, 64, in_line, in_w, true)

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

extends Node2D

# A drawn coin (no real coin image): a metallic disc with a value label, positioned at its
# CENTER. Used by the Change game. The level moves the coin by setting its `position`; this
# node only draws and reports its `radius`/`value`.

var value: float = 0.05      # money value (e.g. 0.05 = five cents)
var radius: float = 40.0     # drawn radius in px

var _num: String = "5"     # big numeral on the coin face
var _sym: String = "¢"     # unit symbol, drawn smaller BELOW the numeral (coin convention)
var _in_tray: bool = false # draws a green halo when the coin currently counts as paid
var _face: Color = Color(0.80, 0.81, 0.85)
var _rim: Color = Color(0.62, 0.63, 0.68)
var _text_col: Color = Color(0.20, 0.17, 0.13, 1.0)

const COPPER: Color = Color(0.82, 0.53, 0.30)
const COPPER_RIM: Color = Color(0.60, 0.36, 0.18)
const SILVER: Color = Color(0.80, 0.81, 0.85)
const SILVER_RIM: Color = Color(0.60, 0.61, 0.66)
const GOLD: Color = Color(0.91, 0.73, 0.32)
const GOLD_RIM: Color = Color(0.70, 0.52, 0.18)

static var _font: Font = null

static func _label_font() -> Font:
	if _font == null:
		var sf: SystemFont = SystemFont.new()
		sf.font_names = PackedStringArray(["Arial Black", "Open Sans Bold", "DejaVu Sans", "Open Sans", "sans-serif"])
		sf.font_weight = 800
		_font = sf
	return _font

func setup(v: float, r: float) -> void:
	value = v
	radius = r
	_apply_denom()
	queue_redraw()

func set_radius(r: float) -> void:
	radius = r
	queue_redraw()

func set_in_tray(v: bool) -> void:
	if _in_tray != v:
		_in_tray = v
		queue_redraw()

func _apply_denom() -> void:
	var cents: int = int(round(value * 100.0))
	if cents >= 100:
		_num = "%d" % int(cents / 100)
		_sym = "$"
		_face = GOLD
		_rim = GOLD_RIM
		_text_col = Color(0.34, 0.24, 0.06, 1.0)
	elif cents <= 1:
		_num = "%d" % cents
		_sym = "¢"
		_face = COPPER
		_rim = COPPER_RIM
		_text_col = Color(0.32, 0.18, 0.08, 1.0)
	else:
		_num = "%d" % cents
		_sym = "¢"
		_face = SILVER
		_rim = SILVER_RIM
		_text_col = Color(0.24, 0.25, 0.30, 1.0)

# A MINTED COIN, lit from the top left: a soft shadow on the felt, the edge (reeded on silver and
# gold, smooth on copper, as real coins are), the face shaded toward the light, a raised rim that
# catches the light on its top-left side and drops into shade on the other, a sheen, and the value
# STRUCK INTO the metal -- its top-left edge in shade and its bottom-right edge catching the light,
# as an incuse letter is -- rather than printed on it. (It was flat concentric circles, flat text.)
func _draw() -> void:
	var r: float = radius
	# green halo when this coin currently counts as being in the tray
	if _in_tray:
		draw_circle(Vector2.ZERO, r * 1.18, Color(0.35, 1.0, 0.55, 0.55))
		draw_circle(Vector2.ZERO, r * 1.10, Color(0.35, 1.0, 0.55, 0.35))
	# soft shadow, two layers
	draw_circle(Vector2(r * 0.06, r * 0.12), r * 1.04, Color(0, 0, 0, 0.14))
	draw_circle(Vector2(r * 0.03, r * 0.07), r * 1.00, Color(0, 0, 0, 0.20))
	# the edge
	draw_circle(Vector2.ZERO, r, _rim.darkened(0.12))
	if _face != COPPER:
		var ticks: int = clampi(int(r * 1.6), 24, 90)
		for i in ticks:
			var a: Vector2 = Vector2.from_angle(TAU * float(i) / float(ticks))
			draw_line(a * r * 0.93, a * r * 0.995, _rim.lightened(0.18) if i % 2 == 0 else _rim.darkened(0.25),
				maxf(1.0, r * 0.035), true)
	# the face, shaded: many thin rings drifting toward the light, each a touch lighter, so the
	# shading is a smooth slope rather than visible steps
	draw_circle(Vector2.ZERO, r * 0.90, _face.darkened(0.10))
	for k in 16:
		var t: float = float(k + 1) / 16.0
		draw_circle(Vector2(-r, -r) * 0.05 * t, r * 0.90 * (1.0 - 0.28 * t), _face.darkened(0.10).lerp(_face.lightened(0.06), t))
	# the raised rim, its light turning continuously round the circle: brightest at the top left,
	# darkest at the bottom right. (Two half-arcs, one near white and one dark, met in a hard seam.)
	_draw_lit_ring(r * 0.82, maxf(1.0, r * 0.05), _face.lightened(0.22), _face.darkened(0.22))
	_draw_lit_ring(r * 0.90, maxf(1.0, r * 0.03), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.0))
	# a sheen and a glint
	draw_circle(Vector2(-r * 0.32, -r * 0.36), r * 0.34, Color(1, 1, 1, 0.10))
	draw_circle(Vector2(-r * 0.42, -r * 0.46), r * 0.10, Color(1, 1, 1, 0.30))
	# denomination: big numeral with the unit symbol on its own line below it (coin convention),
	# embossed
	var f: Font = _label_font()
	_draw_embossed(f, _num, maxi(8, int(r * 0.60)), -r * 0.16, r)
	_draw_embossed(f, _sym, maxi(6, int(r * 0.40)), r * 0.32, r)

# A ring whose color follows the angle to the light (top left): `lit` facing it, `shade` facing
# away, a smooth blend in between. One closed polyline with a color per vertex, so there is no seam.
func _draw_lit_ring(rad: float, width: float, lit: Color, shade: Color) -> void:
	var segs: int = 64
	var light_dir: float = PI * 1.25
	var pts: PackedVector2Array = PackedVector2Array()
	var cols: PackedColorArray = PackedColorArray()
	for i in segs + 1:
		var a: float = TAU * float(i) / float(segs)
		var facing: float = 0.5 + 0.5 * cos(a - light_dir)
		pts.append(Vector2.from_angle(a) * rad)
		cols.append(shade.lerp(lit, facing * facing * (3.0 - 2.0 * facing)))
	draw_polyline_colors(pts, cols, width, true)

func _draw_embossed(f: Font, text: String, fs: int, center_y: float, r: float) -> void:
	var o: float = maxf(0.8, r * 0.025)
	_draw_centered_line(f, text, fs, center_y, Vector2(o, o), Color(_face.lightened(0.55), 0.75))
	_draw_centered_line(f, text, fs, center_y, Vector2(-o, -o), Color(_rim.darkened(0.45), 0.55))
	_draw_centered_line(f, text, fs, center_y, Vector2.ZERO, _text_col)

func _draw_centered_line(f: Font, text: String, fs: int, center_y: float, off: Vector2 = Vector2.ZERO,
		col: Color = Color(0, 0, 0, 0)) -> void:
	var ss: Vector2 = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var asc: float = f.get_ascent(fs)
	var desc: float = f.get_descent(fs)
	draw_string(f, off + Vector2(-ss.x * 0.5, center_y + (asc - desc) * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _text_col if col.a == 0.0 else col)

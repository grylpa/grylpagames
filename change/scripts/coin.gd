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

func _draw() -> void:
	var r: float = radius
	# green halo when this coin currently counts as being in the tray
	if _in_tray:
		draw_circle(Vector2.ZERO, r * 1.18, Color(0.35, 1.0, 0.55, 0.55))
		draw_circle(Vector2.ZERO, r * 1.10, Color(0.35, 1.0, 0.55, 0.35))
	# soft drop shadow
	draw_circle(Vector2(0.0, r * 0.08), r * 1.02, Color(0, 0, 0, 0.20))
	# milled rim, then face, then a slightly lighter inner disc for depth
	draw_circle(Vector2.ZERO, r, _rim)
	draw_circle(Vector2.ZERO, r * 0.90, _face)
	draw_circle(Vector2.ZERO, r * 0.70, _face.lightened(0.14))
	draw_arc(Vector2.ZERO, r * 0.80, 0.0, TAU, 48, _rim.darkened(0.05), maxf(1.0, r * 0.045), true)
	# top-left sheen
	draw_circle(Vector2(-r * 0.30, -r * 0.32), r * 0.40, Color(1, 1, 1, 0.12))
	# denomination: big numeral with the unit symbol on its own line below it (coin convention)
	var f: Font = _label_font()
	_draw_centered_line(f, _num, maxi(8, int(r * 0.60)), -r * 0.16)
	_draw_centered_line(f, _sym, maxi(6, int(r * 0.40)), r * 0.32)

func _draw_centered_line(f: Font, text: String, fs: int, center_y: float) -> void:
	var ss: Vector2 = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var asc: float = f.get_ascent(fs)
	var desc: float = f.get_descent(fs)
	draw_string(f, Vector2(-ss.x * 0.5, center_y + (asc - desc) * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _text_col)

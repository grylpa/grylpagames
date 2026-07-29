extends Node2D

# Draws the static board behind the aliens: the field backdrop, each target area's two rings,
# a pip per parking slot (filled when taken), and a "FULL" badge when an outer ring has no room.
# level.gd owns `areas` and calls queue_redraw() whenever slot ownership changes.

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

static var _font: Font = null

static func _badge_font() -> Font:
	if _font == null:
		var sf: SystemFont = SystemFont.new()
		sf.font_names = PackedStringArray(["Arial Black", "Open Sans Bold", "DejaVu Sans", "sans-serif"])
		sf.font_weight = 800
		_font = sf
	return _font

func _draw() -> void:
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
	var txt: String = "FULL"
	var ss: Vector2 = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos: Vector2 = Vector2(c.x - ss.x * 0.5, c.y + r_out + ss.y * 0.95)
	draw_rect(Rect2(pos.x - 8.0, pos.y - ss.y * 0.82, ss.x + 16.0, ss.y * 1.12),
		Color(0.25, 0.05, 0.03, 0.72), true)
	draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, FULL_COL)

extends RefCounted
class_name Sleek

# The shared look for the three sorting games (sortingrobots, bucketmadness, monkeyc).
#
# All three drew their objects as FONT GLYPHS in a Label — "■" tinted Color.RED — which is why they
# looked flat: a glyph is a single flat silhouette at whatever weight the font happens to have, on
# a plain background, in the most saturated red a screen can produce. Nothing about it says
# "object".
#
# Everything here is drawn instead: a soft contact shadow, a vertical gradient, and a rim light
# along the top edge. That is the whole trick — the same three things a physical object does under
# a light — and it costs three draw calls per shape.
#
# Colors live here too. `Color.RED` is (1, 0, 0): it vibrates against dark backgrounds, has no
# shading room left above it, and looks like a debug placeholder. These are the same hues at a
# believable saturation, with headroom both ways so the gradient has somewhere to go.
#
# IMPORTANT: the games compare item colors for EQUALITY (`item["color"] == _color_values[word]` in
# the stroop test, `c == BLUE or c == RED` for colored shapes). Every game must therefore read its
# colors from THIS table and nowhere else — a raw `Color.BLUE` left behind anywhere silently stops
# matching, and the rule quietly becomes unsatisfiable.

const PALETTE: Dictionary = {
	"RED":    Color(0.878, 0.267, 0.271),
	"BLUE":   Color(0.259, 0.518, 0.882),
	"GREEN":  Color(0.243, 0.706, 0.400),
	"YELLOW": Color(0.914, 0.729, 0.212),
	"PURPLE": Color(0.612, 0.400, 0.925),
	"WHITE":  Color(0.937, 0.945, 0.965),
	"ORANGE": Color(0.949, 0.545, 0.235),
}

const NAMES: Array = ["RED", "BLUE", "GREEN", "YELLOW", "PURPLE"]

static func color_of(name: String) -> Color:
	return PALETTE.get(name, PALETTE["WHITE"])

# --- shapes -----------------------------------------------------------------------------------

# The eight glyphs the games use, filled and hollow.
const FILLED: Array = ["■", "●", "▲", "★"]
const HOLLOW: Array = ["□", "○", "△", "☆"]

static func is_shape(glyph: String) -> bool:
	return FILLED.has(glyph) or HOLLOW.has(glyph)

# Outline of a shape, inscribed in `box`. Points run clockwise from the top.
static func _points(glyph: String, box: Rect2) -> PackedVector2Array:
	var c: Vector2 = box.get_center()
	var r: float = minf(box.size.x, box.size.y) * 0.5
	var pts: PackedVector2Array = PackedVector2Array()
	match glyph:
		"■", "□":
			var s: float = r * 0.92
			pts.append(c + Vector2(-s, -s))
			pts.append(c + Vector2(s, -s))
			pts.append(c + Vector2(s, s))
			pts.append(c + Vector2(-s, s))
		"▲", "△":
			# Sat on its base rather than centered on the bounding box, which is what makes a
			# triangle look like it is standing on something instead of floating.
			var h: float = r * 1.72
			var w: float = r * 1.86
			pts.append(c + Vector2(0.0, -h * 0.56))
			pts.append(c + Vector2(w * 0.5, h * 0.44))
			pts.append(c + Vector2(-w * 0.5, h * 0.44))
		"★", "☆":
			var outer: float = r
			var inner: float = r * 0.42
			for i in range(10):
				var a: float = -PI * 0.5 + float(i) * PI / 5.0
				var rad: float = outer if i % 2 == 0 else inner
				pts.append(c + Vector2(cos(a), sin(a)) * rad)
		_:
			# circle, and the fallback for anything unrecognized
			var steps: int = 40
			for i in range(steps):
				var a: float = float(i) / float(steps) * TAU
				pts.append(c + Vector2(cos(a), sin(a)) * r * 0.94)
	return pts

# Per-vertex colors making a vertical gradient across the shape: lighter at the top, deeper at the
# bottom, as though lit from above.
static func _gradient(pts: PackedVector2Array, base: Color) -> PackedColorArray:
	var top: float = INF
	var bot: float = -INF
	for p in pts:
		top = minf(top, p.y)
		bot = maxf(bot, p.y)
	var span: float = maxf(bot - top, 0.001)
	var out: PackedColorArray = PackedColorArray()
	for p in pts:
		var t: float = (p.y - top) / span
		out.append(base.lightened(0.22 * (1.0 - t)).darkened(0.20 * t))
	return out

const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.28)

# Draw one object. `glyph` is one of FILLED/HOLLOW; anything else falls back to a disc.
static func draw_shape(canvas: CanvasItem, glyph: String, box: Rect2, base: Color) -> void:
	if canvas == null or box.size.x <= 1.0 or box.size.y <= 1.0:
		return
	var pts: PackedVector2Array = _points(glyph, box)
	if pts.size() < 3:
		return
	var drop: float = maxf(box.size.y * 0.055, 1.5)

	# 1. contact shadow, offset down
	var shadow_pts: PackedVector2Array = PackedVector2Array()
	for p in pts:
		shadow_pts.append(p + Vector2(0.0, drop))
	canvas.draw_colored_polygon(shadow_pts, SHADOW)

	if HOLLOW.has(glyph):
		# A ring, not a fill: the stroke carries the gradient so it still reads as lit.
		var w: float = maxf(minf(box.size.x, box.size.y) * 0.11, 2.0)
		var ring: PackedVector2Array = pts.duplicate()
		ring.append(pts[0])
		var cols: PackedColorArray = _gradient(pts, base)
		canvas.draw_polyline(ring, base.darkened(0.30), w + 2.0, true)
		canvas.draw_polyline(ring, cols[0].lightened(0.05), w, true)
		return

	# 2. the body, gradient-filled
	canvas.draw_polygon(pts, _gradient(pts, base))
	# 3. rim light along the top edge, and a darker line under the bottom, so the silhouette does
	#    not dissolve into a light background.
	var edge: PackedVector2Array = pts.duplicate()
	edge.append(pts[0])
	canvas.draw_polyline(edge, base.darkened(0.34), maxf(box.size.y * 0.02, 1.0), true)
	var c: Vector2 = box.get_center()
	var lit: PackedVector2Array = PackedVector2Array()
	for p in pts:
		if p.y <= c.y:
			lit.append(p)
	if lit.size() >= 2:
		canvas.draw_polyline(lit, base.lightened(0.55), maxf(box.size.y * 0.022, 1.0), true)

# --- the object tile --------------------------------------------------------------------------
#
# Shapes were only ever part of the problem. Six of the ten rules in these games produce DIGITS,
# LETTERS or WORDS — measured, 60% of all items — and no amount of shape drawing touches those: a
# bare "7" on a flat belt looks exactly as unfinished as a flat square did.
#
# So every object, text or shape, sits on the same card: rounded, slightly raised, with a soft
# shadow. That is what turns a character into an object, and it is the single change that makes
# text and shapes look like they belong to the same game.
#
# It goes on as a Label's "normal" stylebox, which draws BEHIND the text — a script's _draw() on a
# Label paints over it, which is right for the shape and useless for a backing card.

const TILE_FILL: Color = Color(0.161, 0.184, 0.243)
const TILE_EDGE: Color = Color(0.322, 0.365, 0.463)

static func tile() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = TILE_FILL
	sb.border_color = TILE_EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0.0, 3.0)
	# Breathing room inside the card so glyphs do not touch the border.
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	return sb

# Text on a tile: bright enough to read off the card, with an outline so it survives a light glyph
# on a light color (a YELLOW stroop word, for instance).
static func style_text(lbl: Label, color: Color = PALETTE["WHITE"]) -> void:
	lbl.add_theme_stylebox_override("normal", tile())
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.09, 0.85))
	lbl.add_theme_constant_override("outline_size", 5)

# --- chrome ------------------------------------------------------------------------------------
#
# The belts are the biggest thing on screen after the background, and they were the flattest: a
# PanelContainer with `bg_color = Color(0, 0.06, 0, 0.6)` and nothing else. No border, no corner
# radius, no shadow — two 140x420 slabs of flat dark green over a grass photo. Restyling the
# objects on them could never fix that, which is why the first two passes barely showed.

const BELT_FILL: Color = Color(0.086, 0.106, 0.149, 0.88)
const BELT_EDGE: Color = Color(0.365, 0.435, 0.545, 0.9)

# The machine a belt runs on: dark and slightly glassy, lifted off the background by a shadow, with
# a lit top edge so it reads as a surface catching the light rather than a hole cut in the scene.
static func belt() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = BELT_FILL
	sb.border_color = BELT_EDGE
	sb.border_width_top = 3
	sb.border_width_bottom = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0.0, 5.0)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb

# The rule written above a belt. It was bare yellow text with a 1px shadow, floating on grass; on a
# chip it belongs to the belt underneath it.
const HEADER_FILL: Color = Color(0.129, 0.153, 0.208, 0.92)
const HEADER_EDGE: Color = Color(0.914, 0.729, 0.212, 0.75)

static func header(lbl: Label) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = HEADER_FILL
	sb.border_color = HEADER_EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0.0, 2.0)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	lbl.add_theme_stylebox_override("normal", sb)
	# Prose, so the no-fallback face: the symbol font's line box is 2.09x the font size and these
	# rule labels wrap ("Shape is / blue or red?"), which made the gap between lines look broken.
	lbl.add_theme_font_override("font", MainGlobals.get_text_font())
	lbl.add_theme_color_override("font_color", Color(0.98, 0.94, 0.78))
	lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.07, 0.9))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

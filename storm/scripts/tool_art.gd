class_name StormToolArt
extends RefCounted

# THE FIVE TOOLS, DRAWN. They were 40 px PNGs tinted by a shader below a straight cut line, which
# gave one look to everything: the water rose as a flat band through whatever shape the sprite
# happened to have, and a saucer filled from the bottom of its picture like a glass would.
#
# Drawn instead, each one fills the way the real thing does, and it is sharp at every size -- the
# same code draws the inventory box and the tool standing on a tile.
#
#   bucket  steel pail, cut away: the water rises inside its tapered walls.
#   cup     enamel mug, cut away the same way.
#   plate   a saucer in three-quarter view. It is SHALLOW, so its water does not rise, it SPREADS:
#           a pool in the middle of the well that widens until it reaches the rim.
#   rag     a towel hanging over a rail. It soaks up rather than fills: the wet part darkens from
#           the hem up, and a soaked one drips.
#   fix     masking tape laid in an X, the patch over the hole. No level: tape does not hold water.
#
# `fill` is always 0..1 of THIS tool's capacity (level / overflow_level), never the raw level:
# a cup holds 0.55 and a saucer 0.225 of a bucket, and each should still read "full" when it is.
#
# No blue anywhere on the tools themselves: blue is the water, and a blue cup would read as a full
# one.

const WATER: Color = Color(0.231, 0.541, 0.949)
const WATER_TOP: Color = Color(0.557, 0.788, 1.0)
const INK: Color = Color(0.13, 0.11, 0.10)

const STEEL: Color = Color(0.706, 0.733, 0.757)
const STEEL_DARK: Color = Color(0.439, 0.471, 0.502)
const STEEL_LIT: Color = Color(0.878, 0.894, 0.910)
const HOLLOW: Color = Color(0.29, 0.30, 0.31)       # the inside of an empty pail

const MUG: Color = Color(0.816, 0.263, 0.212)
const MUG_DARK: Color = Color(0.557, 0.141, 0.110)
const MUG_INSIDE: Color = Color(0.953, 0.925, 0.867)

const CHINA: Color = Color(0.965, 0.953, 0.925)
const CHINA_SHADE: Color = Color(0.816, 0.800, 0.765)
const CHINA_RIM: Color = Color(0.741, 0.573, 0.235)  # a gilt line, not a blue one

const TOWEL: Color = Color(0.925, 0.525, 0.431)       # coral: a bath towel, and nowhere near blue
const TOWEL_BACK: Color = Color(0.745, 0.380, 0.310)
const TOWEL_LIT: Color = Color(0.965, 0.690, 0.612)
const TOWEL_STRIPE: Color = Color(0.980, 0.930, 0.840)
const TOWEL_WET: Color = Color(0.557, 0.263, 0.212)

const TAPE: Color = Color(0.918, 0.847, 0.667)
const TAPE_EDGE: Color = Color(0.702, 0.620, 0.439)

const NAMES: Array = ["bucket", "cup", "plate", "rag", "fix"]

static func draws(tool_name: String) -> bool:
	return NAMES.has(tool_name)

# The one entry point. `mid` is the center of a box `s` across.
static func draw_tool(ci: CanvasItem, tool_name: String, mid: Vector2, s: float, fill: float) -> void:
	var f: float = clampf(fill, 0.0, 1.0)
	match tool_name:
		"bucket":
			_bucket(ci, mid, s, f)
		"cup":
			_cup(ci, mid, s, f)
		"plate":
			_saucer(ci, mid, s, f)
		"rag":
			_towel(ci, mid, s, f)
		"fix":
			_tape(ci, mid, s)

# A DRAIN TILE: a metal plate over the WHOLE tile, with the round grate in the middle. It used to be
# a round grate drawn on the floor, so the floor showed round it, and the water -- which stops at the
# edge of a tile it cannot enter -- stopped short of it with a strip of floor between. Now the tile
# itself reads as "not floor", and the water meets it edge to edge. `s` is the tile's full size.
const PLATE: Color = Color(0.345, 0.365, 0.384)
const PLATE_LIT: Color = Color(0.478, 0.502, 0.525)
const PLATE_DARK: Color = Color(0.200, 0.212, 0.224)
const GRATE_HOLE: Color = Color(0.070, 0.078, 0.086)

static func draw_drain(ci: CanvasItem, mid: Vector2, s: float) -> void:
	var h: float = s * 0.5 + 0.3
	var r: Rect2 = Rect2(mid - Vector2(h, h), Vector2(h, h) * 2.0)
	ci.draw_rect(r, PLATE, true)
	# A bevel: lit along the top and left, dark along the bottom and right.
	var bw: float = maxf(1.5, s * 0.06)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, bw)), PLATE_LIT, true)
	ci.draw_rect(Rect2(r.position, Vector2(bw, r.size.y)), PLATE_LIT, true)
	ci.draw_rect(Rect2(Vector2(r.position.x, r.end.y - bw), Vector2(r.size.x, bw)), PLATE_DARK, true)
	ci.draw_rect(Rect2(Vector2(r.end.x - bw, r.position.y), Vector2(bw, r.size.y)), PLATE_DARK, true)
	# Four screws.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var at: Vector2 = mid + Vector2(sx, sy) * s * 0.34
			ci.draw_circle(at, maxf(1.2, s * 0.045), PLATE_DARK)
			ci.draw_line(at - Vector2(s * 0.03, 0.0), at + Vector2(s * 0.03, 0.0), PLATE_LIT, 1.0, true)
	# The grate: a dark round opening with bars across it and a rim.
	var gr: float = s * 0.28
	ci.draw_circle(mid, gr, GRATE_HOLE)
	for k in range(-2, 3):
		var y: float = mid.y + float(k) * gr * 0.36
		var half: float = sqrt(maxf(gr * gr - (y - mid.y) * (y - mid.y), 0.0))
		ci.draw_line(Vector2(mid.x - half, y), Vector2(mid.x + half, y), PLATE_LIT, maxf(1.2, s * 0.05), true)
	ci.draw_arc(mid, gr, 0.0, TAU, 28, PLATE_DARK, maxf(1.5, s * 0.06), true)

static func _line_w(s: float) -> float:
	return maxf(1.0, s * 0.04)

# A trapezoid from its top and bottom edges.
static func _trap(top_y: float, bot_y: float, top_half: float, bot_half: float, cx: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(cx - top_half, top_y), Vector2(cx + top_half, top_y),
		Vector2(cx + bot_half, bot_y), Vector2(cx - bot_half, bot_y)])

static func _outline(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float) -> void:
	var loop: PackedVector2Array = pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, col, w, true)

static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 28:
		var a: float = TAU * float(k) / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)

static func _ellipse_line(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 29:
		var a: float = TAU * float(k) / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_polyline(pts, col, w, true)

# Water standing in a cut-away vessel whose inner walls run from (top_y, top_half) down to
# (bot_y, bot_half). The surface is a lighter band, so a quarter-full vessel still shows a line.
static func _water_in(ci: CanvasItem, cx: float, top_y: float, bot_y: float, top_half: float,
		bot_half: float, f: float, s: float) -> void:
	if f <= 0.0:
		return
	var surf_y: float = lerpf(bot_y, top_y, f)
	var surf_half: float = lerpf(bot_half, top_half, f)
	ci.draw_colored_polygon(_trap(surf_y, bot_y, surf_half, bot_half, cx), WATER)
	ci.draw_line(Vector2(cx - surf_half, surf_y), Vector2(cx + surf_half, surf_y), WATER_TOP,
		maxf(1.0, s * 0.045), true)

static func _bucket(ci: CanvasItem, mid: Vector2, s: float, f: float) -> void:
	var cx: float = mid.x
	var top_y: float = mid.y - s * 0.20
	var bot_y: float = mid.y + s * 0.40
	var top_half: float = s * 0.38
	var bot_half: float = s * 0.28
	var lw: float = _line_w(s)
	# The handle first, so the rim covers where it meets.
	ci.draw_arc(Vector2(cx, top_y), top_half * 0.92, PI * 1.08, PI * 1.92, 18, STEEL_DARK,
		maxf(1.2, s * 0.05), true)
	var wall: float = s * 0.05
	ci.draw_colored_polygon(_trap(top_y, bot_y, top_half, bot_half, cx), STEEL)
	# The cut-away: the inside of the pail, and whatever water is in it.
	var in_top: float = top_y + wall
	var in_bot: float = bot_y - wall
	var in_th: float = top_half - wall
	var in_bh: float = bot_half - wall
	ci.draw_colored_polygon(_trap(in_top, in_bot, in_th, in_bh, cx), HOLLOW)
	_water_in(ci, cx, in_top, in_bot, in_th, in_bh, f, s)
	# Two pressed ribs, the thing that says "pail" rather than "flowerpot".
	for k in [0.36, 0.70]:
		var y: float = lerpf(top_y, bot_y, k)
		var hw: float = lerpf(top_half, bot_half, k)
		ci.draw_line(Vector2(cx - hw, y), Vector2(cx - hw + wall, y), STEEL_DARK, lw, true)
		ci.draw_line(Vector2(cx + hw - wall, y), Vector2(cx + hw, y), STEEL_DARK, lw, true)
	# A rolled rim, lit along its top.
	ci.draw_line(Vector2(cx - top_half - s * 0.02, top_y), Vector2(cx + top_half + s * 0.02, top_y),
		STEEL_LIT, maxf(1.5, s * 0.07), true)
	_outline(ci, _trap(top_y, bot_y, top_half, bot_half, cx), INK, lw)

static func _cup(ci: CanvasItem, mid: Vector2, s: float, f: float) -> void:
	var cx: float = mid.x - s * 0.07
	var top_y: float = mid.y - s * 0.24
	var bot_y: float = mid.y + s * 0.32
	var half: float = s * 0.26
	var lw: float = _line_w(s)
	# The handle, a thick loop on the right.
	ci.draw_arc(Vector2(cx + half, mid.y + s * 0.02), s * 0.14, -PI * 0.5, PI * 0.5, 16, MUG_DARK,
		maxf(2.0, s * 0.075), true)
	var body: PackedVector2Array = _trap(top_y, bot_y, half, half * 0.9, cx)
	ci.draw_colored_polygon(body, MUG)
	var wall: float = s * 0.055
	var in_top: float = top_y + wall
	var in_bot: float = bot_y - wall
	ci.draw_colored_polygon(_trap(in_top, in_bot, half - wall, half * 0.9 - wall, cx), MUG_INSIDE)
	_water_in(ci, cx, in_top, in_bot, half - wall, half * 0.9 - wall, f, s)
	# A white band at the lip: enamelware, and it keeps the rim visible over a red body.
	ci.draw_line(Vector2(cx - half, top_y + s * 0.012), Vector2(cx + half, top_y + s * 0.012),
		CHINA, maxf(1.5, s * 0.05), true)
	_outline(ci, body, INK, lw)

static func _saucer(ci: CanvasItem, mid: Vector2, s: float, f: float) -> void:
	var c: Vector2 = mid + Vector2(0.0, s * 0.04)
	var rx: float = s * 0.46
	var ry: float = s * 0.20
	var lw: float = _line_w(s)
	# The foot, a thickness under the dish so it reads as an object and not a drawn oval.
	_ellipse(ci, c + Vector2(0.0, s * 0.07), rx * 0.96, ry * 0.96, CHINA_SHADE)
	_ellipse_line(ci, c + Vector2(0.0, s * 0.07), rx * 0.96, ry * 0.96, INK, lw)
	_ellipse(ci, c, rx, ry, CHINA)
	_ellipse_line(ci, c, rx * 0.93, ry * 0.90, CHINA_RIM, maxf(1.0, s * 0.03))
	# The well, a touch darker, where the water collects.
	var wx: float = rx * 0.62
	var wy: float = ry * 0.58
	_ellipse(ci, c + Vector2(0.0, s * 0.01), wx, wy, CHINA_SHADE)
	# It spreads rather than rises: a pool from the middle out, by AREA, so half full looks half --
	# and FULL reaches the gilt line. It used to stop at the well, a ring of dry china short of the
	# rim, so a saucer that was full and spilling onto the tile still looked as if it had room.
	if f > 0.0:
		var k: float = sqrt(f)
		var pool_c: Vector2 = c + Vector2(0.0, s * 0.01 * (1.0 - k))
		_ellipse(ci, pool_c, rx * 0.93 * k, ry * 0.90 * k, WATER)
		_ellipse_line(ci, pool_c + Vector2(-rx * 0.12 * k, -ry * 0.18 * k), rx * k * 0.45, ry * k * 0.30,
			WATER_TOP, maxf(1.0, s * 0.03))
	_ellipse_line(ci, c, rx, ry, INK, lw)

# A towel hanging over a rail -- the one drawing of a towel everybody reads as a towel, the way a
# hotel sign draws it: the rail, the towel folded over it, the shorter front layer and the longer back
# layer peeking out below it, bands near the hem. Two earlier tries lay flat (a striped slab with a
# fringe, then a folded towel seen from above) and read as a rug and a book.
# It soaks up rather than fills: the wet part darkens from the hem up, the same way the cup and the
# bucket show their level, and a soaked one drips.
static func _towel(ci: CanvasItem, mid: Vector2, s: float, f: float) -> void:
	var lw: float = _line_w(s)
	var half: float = s * 0.27
	var rail_y: float = mid.y - s * 0.34
	var front_end: float = mid.y + s * 0.26
	var back_end: float = mid.y + s * 0.40
	var corner: float = s * 0.05
	# The rail, showing past the towel on both sides.
	ci.draw_line(Vector2(mid.x - s * 0.44, rail_y), Vector2(mid.x + s * 0.44, rail_y), STEEL_DARK,
		maxf(1.5, s * 0.06), true)
	for sx in [-1.0, 1.0]:
		ci.draw_circle(Vector2(mid.x + sx * s * 0.44, rail_y), s * 0.045, STEEL_DARK)
	# The back layer, longer, offset a little so it shows as a second layer.
	var back: Rect2 = Rect2(mid.x - half + s * 0.05, rail_y, half * 2.0, back_end - rail_y)
	var front: Rect2 = Rect2(mid.x - half, rail_y - s * 0.04, half * 2.0, front_end - rail_y + s * 0.04)
	for layer in [[back, TOWEL_BACK], [front, TOWEL]]:
		var r: Rect2 = layer[0]
		_round_rect(ci, r, corner, layer[1])
		# Soaked from the hem up.
		if f > 0.0:
			var wet_h: float = (r.size.y - s * 0.04) * f
			var wet: Color = TOWEL_WET if layer[1] == TOWEL else TOWEL_WET.darkened(0.2)
			_round_rect(ci, Rect2(r.position.x, r.end.y - wet_h, r.size.x, wet_h), corner, wet)
		# Two bands near the hem.
		for k in [0.20, 0.30]:
			var y: float = r.end.y - (front.size.y * k)
			if y > r.position.y + s * 0.06:
				ci.draw_line(Vector2(r.position.x + lw, y), Vector2(r.end.x - lw, y), TOWEL_STRIPE,
					maxf(1.2, s * 0.04), true)
		_round_rect_line(ci, r, corner, INK, lw)
	# Where it folds over the rail: a rounded top.
	ci.draw_line(Vector2(front.position.x + corner, front.position.y), Vector2(front.end.x - corner, front.position.y),
		TOWEL_LIT, maxf(1.2, s * 0.05), true)
	if f >= 0.999:
		for k2 in [0.3, 0.7]:
			ci.draw_circle(Vector2(back.position.x + back.size.x * k2, back_end + s * 0.07), s * 0.04, WATER)

# Masking tape laid in an X over the leak. The first drawing was a roll, which says "you have tape"
# and not what tape DOES here: the X is a patch over a hole, and stops the drip.
static func _tape(ci: CanvasItem, mid: Vector2, s: float) -> void:
	var lw: float = _line_w(s)
	var ln: float = s * 0.80
	var w: float = s * 0.20
	for ang in [PI * 0.25, -PI * 0.25]:
		var d: Vector2 = Vector2.from_angle(ang)
		var n: Vector2 = d.orthogonal()
		var a: Vector2 = mid - d * ln * 0.5
		var b: Vector2 = mid + d * ln * 0.5
		# Torn ends: a shallow zigzag across each end instead of a clean cut.
		var strip: PackedVector2Array = PackedVector2Array()
		strip.append(a + n * w * 0.5)
		strip.append(b + n * w * 0.5)
		for k in range(1, 4):
			var t: float = float(k) / 4.0
			strip.append(b + n * w * (0.5 - t) + d * (s * 0.03 if k % 2 == 1 else 0.0))
		strip.append(b - n * w * 0.5)
		strip.append(a - n * w * 0.5)
		for k in range(1, 4):
			var t2: float = float(k) / 4.0
			strip.append(a - n * w * (0.5 - t2) - d * (s * 0.03 if k % 2 == 1 else 0.0))
		ci.draw_colored_polygon(strip, TAPE)
		# The crinkle along the middle of a strip of paper tape.
		ci.draw_line(a + d * s * 0.06, b - d * s * 0.06, TAPE_EDGE, maxf(0.8, s * 0.02), true)
		_outline(ci, strip, INK, lw)

static func _round_rect(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(round(rad)))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)

static func _round_rect_line(ci: CanvasItem, r: Rect2, rad: float, col: Color, w: float) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.draw_center = false
	sb.border_color = col
	sb.set_border_width_all(maxi(1, int(round(w))))
	sb.set_corner_radius_all(int(round(rad)))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)

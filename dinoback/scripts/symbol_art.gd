extends Node2D

# The drawn face of a card for the LETTERS / DIGITS / SHAPES categories, in place of a photograph.
#
# It is added as a CHILD OF THE CARD (shared/scripts/card.gd is a Node2D), so it inherits the
# card's transform, modulate and rotation for free — the deal/swipe-out tweens animate it without
# knowing it exists. It draws in its own local space from (0,0) to `box`, which the level sets to
# the card's inner rect (inside the zig frame).
#
# The symbol is drawn LARGE on purpose: ~80% of the box. These cards have to be readable at a
# glance at "small" size while the player is holding an n-back chain in their head, so the face is
# one big high-contrast mark on a dark plate and nothing else.

const PLATE: Color = Color(0.07, 0.08, 0.11, 1.0)
const OUTLINE_DARKEN: float = 0.45
const SYMBOL_FRAC: float = 0.80          # shapes: of the box's short side
const GLYPH_FRAC: float = 0.76           # glyphs: of the box height, measured on the INK
const GLYPH_MAX_W_FRAC: float = 0.82     # a wide glyph shrinks rather than touching the frame

static var _glyph_font: Font = null

var kind: String = "shapes"      # "letters" | "digits" | "shapes"
var glyph: String = ""           # the character, for letters/digits
var shape_name: String = "circle"
var col: Color = Color(1, 1, 1, 1)
var box: Vector2 = Vector2(100.0, 100.0)

static func _font() -> Font:
	if _glyph_font == null:
		var sf: SystemFont = SystemFont.new()
		sf.font_names = PackedStringArray(["Open Sans Bold", "Open Sans SemiBold", "DejaVu Sans", "sans-serif"])
		sf.font_weight = 800
		_glyph_font = sf
	return _glyph_font

func setup(category: String, value: String, color: Color, inner: Vector2) -> void:
	kind = category
	col = color
	box = inner
	if category == "shapes":
		shape_name = value
	else:
		glyph = value
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, box), PLATE, true)
	if kind == "shapes":
		_draw_shape()
	else:
		_draw_glyph()

# --- glyphs -------------------------------------------------------------------------------------

# The glyph is sized and placed by its ACTUAL INK BOX, queried from the text server, not by font
# metrics. (ascent - descent) is only an approximation of cap height and it is wrong in different
# directions per face: on the face this resolves to here it measured 0.69 em against a real cap ink
# of 0.74 em, so glyphs came out 7% oversized AND sat ~2% of the card high. The ink box is exact,
# per glyph, and needs no per-font constant — which matters because this is a SystemFont and
# resolves to a different face on desktop and on a phone.
func _draw_glyph() -> void:
	if glyph == "":
		return
	var f: Font = _font()
	var c: Vector2 = box * 0.5
	var target_h: float = box.y * GLYPH_FRAC
	var max_w: float = box.x * GLYPH_MAX_W_FRAC

	var fs: int = maxi(8, int(target_h / 0.72))     # 0.72 em is a rough cap height, refined below
	var ink: Rect2 = _ink_rect(f, fs)
	if ink.size.y <= 0.0:
		_draw_glyph_by_metrics(f, c, target_h, max_w)
		return
	# Ink does not scale perfectly linearly with size (hinting), so converge instead of computing.
	for _pass in 4:
		var k: float = minf(target_h / ink.size.y, max_w / maxf(ink.size.x, 1.0))
		if absf(k - 1.0) < 0.02:
			break
		fs = clampi(int(round(float(fs) * k)), 8, 400)
		ink = _ink_rect(f, fs)
		if ink.size.y <= 0.0:
			_draw_glyph_by_metrics(f, c, target_h, max_w)
			return
	# The loop stops within 2% of the target, which can leave a glyph a hair OVER a cap. Step down
	# until it is inside both — a card must never have a symbol touching its frame.
	while fs > 8 and (ink.size.y > target_h or ink.size.x > max_w):
		fs -= 1
		var probe: Rect2 = _ink_rect(f, fs)
		if probe.size.y <= 0.0:
			break
		ink = probe
	# draw_string takes the PEN origin (baseline, left edge); place it so the ink box centers on c
	draw_string(f, c - ink.position - ink.size * 0.5, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

# The glyph's ink box relative to the pen origin, or an empty Rect2 if the text server cannot say.
func _ink_rect(f: Font, fs: int) -> Rect2:
	var rids: Array = f.get_rids()
	if rids.is_empty() or glyph.is_empty():
		return Rect2()
	var srv: TextServer = TextServerManager.get_primary_interface()
	var rid: RID = rids[0]
	var gi: int = srv.font_get_glyph_index(rid, fs, glyph.unicode_at(0), 0)
	if gi == 0:
		return Rect2()
	return Rect2(srv.font_get_glyph_offset(rid, Vector2i(fs, 0), gi),
		srv.font_get_glyph_size(rid, Vector2i(fs, 0), gi))

# Fallback for a face whose ink box cannot be queried: the old metric estimate. Slightly off in
# both size and vertical placement, but never blank.
func _draw_glyph_by_metrics(f: Font, c: Vector2, target_h: float, max_w: float) -> void:
	var unit: float = float(f.get_ascent(100) - f.get_descent(100)) / 100.0
	var fs: int = maxi(8, int(target_h / maxf(unit, 0.1)))
	while fs > 8 and f.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		fs -= 1
	var baseline: float = c.y + float(f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	draw_string(f, Vector2(0.0, baseline), glyph, HORIZONTAL_ALIGNMENT_CENTER, box.x, fs, col)

# --- shapes -------------------------------------------------------------------------------------

# The per-shape radius multipliers equalize PERCEIVED size: a triangle or a star inscribed in the
# same circle as a square looks much smaller, because so much of the circle is empty.
func _draw_shape() -> void:
	var c: Vector2 = box * 0.5
	var r: float = minf(box.x, box.y) * SYMBOL_FRAC * 0.5
	var edge: Color = col.darkened(OUTLINE_DARKEN)
	var lw: float = maxf(1.5, r * 0.07)
	if shape_name == "circle":
		draw_circle(c, r, col, true, -1.0, true)
		draw_arc(c, r, 0.0, TAU, 48, edge, lw, true)
		return
	var pts: PackedVector2Array
	match shape_name:
		"square":
			var h: float = r * 0.80
			pts = PackedVector2Array([
				c + Vector2(-h, -h), c + Vector2(h, -h), c + Vector2(h, h), c + Vector2(-h, h)])
		"triangle":
			pts = _ngon(c, r * 1.14, 3)
		"star":
			pts = _star(c, r * 1.12, r * 0.46)
		"plus":
			pts = _plus(c, r * 1.05, r * 0.34)
		"hexagon":
			pts = _ngon(c, r * 1.02, 6)
		"pentagon":
			pts = _ngon(c, r * 1.08, 5)
		_:
			pts = _ngon(c, r, 6)
	_poly(_centered(pts, c), col, edge, lw)

# Center a polygon's BOUNDING BOX on `c`. Building a shape around its circumcenter does NOT center
# it: a point-up triangle reaches a full radius up but only half a radius down, so it sits visibly
# high in the card, and a 5-point star and a pentagon do the same by ~0.1 radius. Symmetric shapes
# (square, plus, hexagon) are unaffected, so this runs for all of them and needs no special-casing.
func _centered(pts: PackedVector2Array, c: Vector2) -> PackedVector2Array:
	if pts.is_empty():
		return pts
	var lo: Vector2 = pts[0]
	var hi: Vector2 = pts[0]
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var d: Vector2 = c - (lo + hi) * 0.5
	var out: PackedVector2Array = PackedVector2Array()
	for p in pts:
		out.append(p + d)
	return out

func _poly(pts: PackedVector2Array, fill: Color, edge: Color, lw: float) -> void:
	draw_colored_polygon(pts, fill)
	var closed: PackedVector2Array = pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, edge, lw, true)

# Point-up regular polygon.
func _ngon(c: Vector2, r: float, sides: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in sides:
		var a: float = -PI * 0.5 + TAU * float(i) / float(sides)
		pts.append(c + Vector2(cos(a) * r, sin(a) * r))
	return pts

func _star(c: Vector2, r_out: float, r_in: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 10:
		var a: float = -PI * 0.5 + PI * float(i) / 5.0
		var rr: float = r_out if i % 2 == 0 else r_in
		pts.append(c + Vector2(cos(a) * rr, sin(a) * rr))
	return pts

# Greek cross: `arm` is the half-length of the cross, `t` the half-thickness.
func _plus(c: Vector2, arm: float, t: float) -> PackedVector2Array:
	return PackedVector2Array([
		c + Vector2(-t, -arm), c + Vector2(t, -arm), c + Vector2(t, -t), c + Vector2(arm, -t),
		c + Vector2(arm, t), c + Vector2(t, t), c + Vector2(t, arm), c + Vector2(-t, arm),
		c + Vector2(-t, t), c + Vector2(-arm, t), c + Vector2(-arm, -t), c + Vector2(-t, -t)])

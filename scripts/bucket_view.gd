extends Control
class_name BucketView

# A drawn bucket (or dumpster), replacing the illustrated PNGs.
#
# The rest of this game is drawn: the factory wall, the chute, the object tiles, the shapes. The
# three containers were photographic-looking sprites sitting among it, which made them
# read as pasted in from a different game — and because they were fixed images, they could not
# react to anything either.
#
# Drawn instead, they share the palette AND can open, which is what a bucket you are throwing
# things into should do.

const BODY_TOP: Color = Color(0.353, 0.400, 0.486)
const BODY_BOT: Color = Color(0.196, 0.227, 0.290)
const RIM: Color = Color(0.510, 0.565, 0.667)
const INNER: Color = Color(0.055, 0.067, 0.098)
const LID: Color = Color(0.290, 0.333, 0.416)
const LID_LIP: Color = Color(0.541, 0.596, 0.694)
const OUTLINE: Color = Color(0.043, 0.051, 0.071, 0.9)
const HOOP: Color = Color(0.161, 0.188, 0.239)
const HOOP_LIP: Color = Color(0.435, 0.482, 0.573)

# A dumpster is drawn as a different OBJECT, not a bigger bucket: a box seen from the corner, with
# ribs, wheels and one back-hinged lid, against the bucket's cylinder. The two used to differ only
# in width, which is not a difference a player can name.
@export var is_dumpster: bool = false

# 0 shut, 1 fully open. Drives the lid angle, so opening is a real movement rather than a swap
# between two unrelated pictures.
var open_amount: float = 0.0:
	set(v):
		open_amount = clampf(v, 0.0, 1.0)
		queue_redraw()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

# Where an item should be aimed to land IN this container, in global coordinates.
func mouth_global() -> Vector2:
	return global_position + Vector2(size.x * 0.5, size.y * 0.30)

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 8.0 or h < 8.0:
		return
	if is_dumpster:
		_draw_dumpster(w, h)
	else:
		_draw_bucket(w, h)

# A CYLINDER. The mouth is an ellipse because we look slightly down into it — so the BASE has to be
# an ellipse too. Drawing the bottom as a straight line was the giveaway that this was a flat
# trapezoid wearing a round lid.
# The outline as one closed loop: down the left wall, around the FRONT of the base, up the right
# wall, and back across the FRONT of the mouth. Public so it can be tested against directly — an
# earlier probe rebuilt this maths itself and happily confirmed a silhouette that self-intersected.
func bucket_silhouette(w: float, h: float) -> PackedVector2Array:
	var cx: float = w * 0.5
	var top_y: float = h * 0.26
	var bot_y: float = h * 0.93
	var half_top: float = w * 0.40
	var half_bot: float = half_top * 0.80
	var ry_top: float = h * 0.085
	var ry_bot: float = ry_top * 0.80
	var sil: PackedVector2Array = PackedVector2Array()
	sil.append(Vector2(cx - half_top, top_y))
	# t = PI is the LEFT of the ellipse, PI/2 its front, 0 its right — so walking t down from PI to
	# 0 goes left -> front -> right. Using `cx - cos(t)` instead ran it right-to-left and folded the
	# outline back over itself, which is why triangulation failed 618 times in one run.
	for i in range(17):
		var t: float = PI - float(i) / 16.0 * PI
		sil.append(Vector2(cx + cos(t) * half_bot, bot_y + sin(t) * ry_bot))
	sil.append(Vector2(cx + half_top, top_y))
	for i in range(17):
		var t2: float = float(i) / 16.0 * PI
		sil.append(Vector2(cx + cos(t2) * half_top, top_y + sin(t2) * ry_top))
	return sil

func _draw_bucket(w: float, h: float) -> void:
	var cx: float = w * 0.5
	var top_y: float = h * 0.26
	var bot_y: float = h * 0.93
	var half_top: float = w * 0.40
	var half_bot: float = half_top * 0.80
	var ry_top: float = h * 0.085
	var ry_bot: float = ry_top * 0.80
	var sil: PackedVector2Array = bucket_silhouette(w, h)

	_shadow_pts(sil)
	var cols: PackedColorArray = PackedColorArray()
	for p in sil:
		var t: float = clampf(((p as Vector2).y - top_y) / maxf(bot_y - top_y, 1.0), 0.0, 1.0)
		cols.append(BODY_TOP.lerp(BODY_BOT, t))
	draw_polygon(sil, cols)
	_wedge(Vector2(cx - half_top, top_y), Vector2(cx - half_bot, bot_y), w * 0.30, Color(1, 1, 1, 0.14))
	_wedge(Vector2(cx + half_top, top_y), Vector2(cx + half_bot, bot_y), -w * 0.22, Color(0, 0, 0, 0.22))
	draw_polyline(sil, OUTLINE, 4.0, true)

	# Hoops follow the curve of the wall rather than cutting straight across it.
	for fy in [0.50, 0.74]:
		var yy: float = lerpf(top_y, bot_y, fy)
		var hw: float = lerpf(half_top, half_bot, fy)
		var ry: float = lerpf(ry_top, ry_bot, fy)
		_arc_front(Vector2(cx, yy), hw, ry, HOOP, maxf(h * 0.035, 3.0))
		_arc_front(Vector2(cx, yy - 2.0), hw, ry, HOOP_LIP, 1.5)

	# The mouth, last, so the well sits over the wall it is cut into.
	# A bucket has no lid — it is an open-topped container. The two hinged flaps that used to swing
	# out of the rim were invented purely to have something to animate, and read as two diagonal
	# lines appearing from nowhere. "Ready to receive" is instead a lift in the rim and a little
	# light down the inside wall, which is what an open container catching the light would do.
	var lit: float = open_amount
	var inner: Color = INNER.lerp(INNER.lightened(0.30), lit)
	_ellipse(Vector2(cx, top_y), half_top, ry_top, inner)
	_ellipse_outline(Vector2(cx, top_y), half_top, ry_top, RIM.lerp(RIM.lightened(0.45), lit), 7.0)
	_ellipse_outline(Vector2(cx, top_y), half_top, ry_top, OUTLINE, 2.0)

# A BOX seen from the front and slightly above: a front face, a top face receding UP the screen
# (which is the opening), and one side face. No bucket is anywhere in it.
# The lid's two free corners at a given openness, in local coordinates. Public so the fold can be
# checked directly instead of by eye.
func lid_tips(w: float, h: float, amount: float) -> Array:
	var left: float = w * 0.12
	var right: float = w * 0.84
	var top_y: float = h * 0.36
	var dep: Vector2 = Vector2(w * 0.14, -h * 0.13)
	var hl: Vector2 = Vector2(left, top_y) + dep
	var hr: Vector2 = Vector2(right, top_y) + dep
	var span: Vector2 = Vector2(left, top_y) - hl
	var reach: float = span.length()
	var ang: float = lerpf(0.0, 1.45, clampf(amount, 0.0, 1.0))
	var folded: Vector2 = span * cos(ang) + Vector2(0.0, -reach * sin(ang))
	return [hl + folded, hr + folded, hl, hr]

func _draw_dumpster(w: float, h: float) -> void:
	var left: float = w * 0.12
	var right: float = w * 0.84
	var top_y: float = h * 0.36
	var bot_y: float = h * 0.88
	# Depth runs up and to the RIGHT: the far edge is higher on screen and offset sideways.
	var dep: Vector2 = Vector2(w * 0.14, -h * 0.13)

	var fl: Vector2 = Vector2(left, top_y)
	var fr: Vector2 = Vector2(right, top_y)
	var bl: Vector2 = Vector2(left + w * 0.03, bot_y)
	var br: Vector2 = Vector2(right - w * 0.03, bot_y)
	_shadow_pts(PackedVector2Array([fl, fr, br, bl]))

	# Side face first — it is behind the front one.
	draw_polygon(PackedVector2Array([fr, fr + dep, br + dep, br]),
		PackedColorArray([BODY_BOT, BODY_BOT.darkened(0.18), BODY_BOT.darkened(0.30), BODY_BOT.darkened(0.12)]))

	# Top face = the opening. Dark, and nothing is drawn below its far edge: that was what made this
	# look inside-out, a "far wall" polygon sitting inside the hole.
	#
	# It brightens as it receives, the same cue the bucket mouths use — the dumpster was the only
	# container that gave nothing back when something went into it.
	var lit_in: Color = INNER.lerp(INNER.lightened(0.34), open_amount)
	draw_polygon(PackedVector2Array([fl, fr, fr + dep, fl + dep]),
		PackedColorArray([lit_in, lit_in, lit_in.lightened(0.16), lit_in.lightened(0.16)]))

	# Front face, over both.
	draw_polygon(PackedVector2Array([fl, fr, br, bl]),
		PackedColorArray([BODY_TOP, BODY_TOP, BODY_BOT, BODY_BOT]))
	var ribs: int = 5
	for i in range(1, ribs):
		var t: float = float(i) / float(ribs)
		draw_line(Vector2(lerpf(fl.x, fr.x, t), top_y), Vector2(lerpf(bl.x, br.x, t), bot_y),
			Color(0, 0, 0, 0.20), 3.0)
	draw_polyline(PackedVector2Array([fl, fr, br, bl, fl]), OUTLINE, 4.0, true)
	draw_line(fl, fr, RIM.lerp(RIM.lightened(0.45), open_amount), 5.0, true)
	draw_polyline(PackedVector2Array([fl, fl + dep, fr + dep, fr]), OUTLINE, 3.0, true)
	draw_polyline(PackedVector2Array([fr + dep, br + dep, br]), OUTLINE, 3.0, true)

	var wr: float = maxf(h * 0.045, 4.0)
	for wx in [left + w * 0.12, right - w * 0.12]:
		draw_circle(Vector2(wx, bot_y + wr * 0.7), wr, OUTLINE)
		draw_circle(Vector2(wx, bot_y + wr * 0.7), wr * 0.5, HOOP_LIP)

	# One flat lid hinged along the FAR edge, folding back over the top.
	#
	# The hinge is a horizontal axis in the SCENE, so the lid has to foreshorten as it lifts: its
	# projected depth shrinks by cos(angle) while it rises by sin(angle). Rotating the span vector
	# in 2D instead (`span.rotated()`) swung it sideways across the screen, which is why the open
	# lid looked wrong while the shut one looked fine — shut, the two agree.
	var ang: float = lerpf(0.0, 1.45, open_amount)
	var hl: Vector2 = fl + dep
	var hr: Vector2 = fr + dep
	var span: Vector2 = fl - hl
	var reach: float = span.length()
	var folded: Vector2 = span * cos(ang) + Vector2(0.0, -reach * sin(ang))
	var ll: Vector2 = hl + folded
	var lr: Vector2 = hr + folded
	draw_polygon(PackedVector2Array([hl, hr, lr, ll]),
		PackedColorArray([LID_LIP, LID_LIP, LID, LID]))
	draw_polyline(PackedVector2Array([hl, hr, lr, ll, hl]), OUTLINE, 2.5, true)

# The near half of an ellipse — the part of a hoop that faces the viewer.
func _arc_front(c: Vector2, rx: float, ry: float, col: Color, wdt: float) -> void:
	if rx <= 1.0:
		return
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(17):
		var a: float = float(i) / 16.0 * PI
		pts.append(c + Vector2(cos(a) * -rx, sin(a) * ry))
	draw_polyline(pts, col, wdt, true)

func _shadow_pts(pts: PackedVector2Array) -> void:
	var sh: PackedVector2Array = PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(0.0, 7.0))
	if sh.size() > 2:
		draw_colored_polygon(sh, Color(0, 0, 0, 0.35))

# A soft band running down one edge, for roundness.
func _wedge(top: Vector2, bot: Vector2, width: float, col: Color) -> void:
	var clear: Color = Color(col.r, col.g, col.b, 0.0)
	draw_polygon(
		PackedVector2Array([top, top + Vector2(width, 0.0), bot + Vector2(width * 0.85, 0.0), bot]),
		PackedColorArray([col, clear, clear, col]))

func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts: PackedVector2Array = _ell_pts(c, rx, ry)
	if pts.size() > 2:
		draw_colored_polygon(pts, col)

func _ellipse_outline(c: Vector2, rx: float, ry: float, col: Color, wdt: float) -> void:
	var pts: PackedVector2Array = _ell_pts(c, rx, ry)
	if pts.size() > 2:
		pts.append(pts[0])
		draw_polyline(pts, col, wdt, true)

func _ell_pts(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	if rx <= 0.5 or ry <= 0.5:
		return pts
	for i in range(28):
		var a: float = float(i) / 28.0 * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

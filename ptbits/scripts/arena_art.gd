extends RefCounted
class_name PtbitsArt

# The look of Nudge: a lit chamber with machined parts in it.
#
# What it looked like before: one flat `draw_rect` of slate for the whole field, flat gray triangles
# for the deflectors, and each basket a flat colored trapezoid with the backdrop color punched out
# of it. Four fills, no light anywhere, so nothing in the arena had a top or a bottom — the tool
# read as a colored circle rather than a thing you could pick up and push with.
#
# Everything here is the same three ideas applied to each part: a vertical gradient so a surface
# has a lit side, a rim light on the edge that faces the light, and a shadow underneath so the part
# sits ON the backdrop instead of being painted into it. The light in this arena comes from the
# inlet at the top center, which is also where the balls come from, so "lit from above" is a fact
# about the scene and not just a convention.
#
# EVERY polygon drawn here is a convex quad or a triangle, on purpose. `draw_polygon` triangulates
# its input EVERY frame, and a concave outline re-triangulates differently frame to frame, which
# shows up as crawling edges (mother's dune crests did exactly that). Convex input has one
# triangulation, so it is stable — and per-vertex colors then give a true gradient in one call
# rather than a stack of banded strips.
#
# The geometry helpers (`basket_parts`, `bumper_shading`, `tool_parts`, `bg_at`) are pure and
# return what will be drawn, so the headless probe can measure contrast and convexity against the
# code that actually runs instead of against a copy of it.

# --- palette ------------------------------------------------------------------------------------

const BG_TOP: Color = Color(0.137, 0.165, 0.243)
const BG_BOT: Color = Color(0.051, 0.063, 0.102)
const SEAM: Color = Color(1.0, 1.0, 1.0, 0.030)
const VIGNETTE: Color = Color(0.008, 0.012, 0.024)
const FRAME_EDGE: Color = Color(0.353, 0.412, 0.541)
const STEEL_LIT: Color = Color(0.486, 0.545, 0.667)
const STEEL_MID: Color = Color(0.259, 0.306, 0.400)
const STEEL_DARK: Color = Color(0.129, 0.157, 0.227)
const COLLAR: float = 7.0   # how far a basket's rim overhangs its wall
const HAZARD: Color = Color(0.898, 0.361, 0.302)
const INLET_LIGHT: Color = Color(0.769, 0.855, 1.0)

# --- small helpers ------------------------------------------------------------------------------

# `_tr` and not `tr`: a parameter called `tr` shadows Object.tr(), which is SHADOWED_VARIABLE_BASE_
# CLASS. The project convention for that clash is the leading underscore.
static func quad(tl: Vector2, _tr: Vector2, br: Vector2, bl: Vector2) -> PackedVector2Array:
	return PackedVector2Array([tl, _tr, br, bl])

# A vertical gradient across one convex quad, in a single draw call.
static func vgrad(ci: CanvasItem, pts: PackedVector2Array, top_col: Color, bot_col: Color) -> void:
	ci.draw_polygon(pts, PackedColorArray([top_col, top_col, bot_col, bot_col]))

static func hgrad(ci: CanvasItem, pts: PackedVector2Array, left_col: Color, right_col: Color) -> void:
	ci.draw_polygon(pts, PackedColorArray([left_col, right_col, right_col, left_col]))

# The backdrop color at a height fraction — the one place that knows the gradient, so a contrast
# check can ask "what is behind a ball here?" and get the real answer.
static func bg_at(y_frac: float) -> Color:
	return BG_TOP.lerp(BG_BOT, clampf(y_frac, 0.0, 1.0))

# --- backdrop -----------------------------------------------------------------------------------

static func backdrop(ci: CanvasItem, area: Rect2, inlet_x0: float, inlet_x1: float, glow: Texture2D) -> void:
	var l: float = area.position.x
	var r: float = area.position.x + area.size.x
	var t: float = area.position.y
	var b: float = area.position.y + area.size.y
	vgrad(ci, quad(Vector2(l, t), Vector2(r, t), Vector2(r, b), Vector2(l, b)), BG_TOP, BG_BOT)

	# Panel seams. Faint enough to be felt rather than read: they give the eye a sense of scale as
	# a ball falls past them, which a single flat fill cannot.
	var y: float = t + 96.0
	while y < b:
		ci.draw_line(Vector2(l, y), Vector2(r, y), SEAM, 2.0)
		y += 96.0

	# Light spilling out of the inlet, widening as it falls. This is what makes the arena look lit
	# from a place rather than uniformly bright.
	var spread: float = 150.0
	var cone: PackedVector2Array = quad(
		Vector2(inlet_x0, t), Vector2(inlet_x1, t),
		Vector2(inlet_x1 + spread, b), Vector2(inlet_x0 - spread, b))
	ci.draw_polygon(cone, PackedColorArray([
		Color(INLET_LIGHT.r, INLET_LIGHT.g, INLET_LIGHT.b, 0.055),
		Color(INLET_LIGHT.r, INLET_LIGHT.g, INLET_LIGHT.b, 0.055),
		Color(INLET_LIGHT.r, INLET_LIGHT.g, INLET_LIGHT.b, 0.0),
		Color(INLET_LIGHT.r, INLET_LIGHT.g, INLET_LIGHT.b, 0.0)]))
	if glow != null:
		var gw: float = (inlet_x1 - inlet_x0) + 210.0
		ci.draw_texture_rect(glow, Rect2(Vector2((inlet_x0 + inlet_x1) * 0.5 - gw * 0.5, t - gw * 0.42),
			Vector2(gw, gw * 0.8)), false, Color(INLET_LIGHT.r, INLET_LIGHT.g, INLET_LIGHT.b, 0.16))

	_vignette(ci, area)

# Dust in the light. Fourteen specks drifting down and swaying, positions derived from the clock
# rather than stored, so it costs nothing to keep and cannot get out of step with anything. A still
# chamber reads as a screenshot; this is the cheapest thing that says the air is moving.
static func motes(ci: CanvasItem, area: Rect2, t: float) -> void:
	var l: float = area.position.x
	var w: float = area.size.x
	var top: float = area.position.y
	var h: float = area.size.y
	for i in 14:
		var seed_f: float = float(i) * 1.6180339
		var speed: float = 9.0 + fmod(seed_f * 37.0, 13.0)
		var y: float = top + fposmod(fmod(seed_f * 211.0, h) + t * speed, h)
		var sway: float = sin(t * (0.4 + fmod(seed_f, 0.5)) + seed_f * 6.0) * 26.0
		var x: float = l + fmod(seed_f * 397.0, w) + sway
		var r: float = 1.2 + fmod(seed_f * 7.0, 1.8)
		var a: float = 0.06 + 0.10 * (0.5 + 0.5 * sin(t * 0.7 + seed_f * 3.0))
		ci.draw_circle(Vector2(x, y), r, Color(INLET_LIGHT.r, INLET_LIGHT.g, INLET_LIGHT.b, a))

static func _vignette(ci: CanvasItem, area: Rect2) -> void:
	var l: float = area.position.x
	var r: float = area.position.x + area.size.x
	var t: float = area.position.y
	var b: float = area.position.y + area.size.y
	var w: float = 104.0
	var dark: Color = Color(VIGNETTE.r, VIGNETTE.g, VIGNETTE.b, 0.34)
	var clear: Color = Color(VIGNETTE.r, VIGNETTE.g, VIGNETTE.b, 0.0)
	hgrad(ci, quad(Vector2(l, t), Vector2(l + w, t), Vector2(l + w, b), Vector2(l, b)), dark, clear)
	hgrad(ci, quad(Vector2(r - w, t), Vector2(r, t), Vector2(r, b), Vector2(r - w, b)), clear, dark)
	vgrad(ci, quad(Vector2(l, b - w * 1.6), Vector2(r, b - w * 1.6), Vector2(r, b), Vector2(l, b)), clear, dark)

# The open bottom is where a ball is LOST, and nothing said so. A hazard wash plus a dashed line is
# the cheapest way to give the drop a meaning before the player learns it the expensive way.
static func loss_zone(ci: CanvasItem, area: Rect2, y: float) -> void:
	var l: float = area.position.x
	var r: float = area.position.x + area.size.x
	var b: float = area.position.y + area.size.y
	if y >= b:
		return
	vgrad(ci, quad(Vector2(l, y), Vector2(r, y), Vector2(r, b), Vector2(l, b)),
		Color(HAZARD.r, HAZARD.g, HAZARD.b, 0.0), Color(HAZARD.r, HAZARD.g, HAZARD.b, 0.13))
	var x: float = l + 6.0
	while x < r - 10.0:
		ci.draw_line(Vector2(x, y), Vector2(x + 14.0, y), Color(HAZARD.r, HAZARD.g, HAZARD.b, 0.32), 2.0)
		x += 26.0

# A moving ball smears. Drawn from the level (behind the balls, which are child nodes) so it
# trails the sphere instead of covering it.
static func ball_trail(ci: CanvasItem, at: Vector2, vel: Vector2, radius: float, col: Color) -> void:
	var speed: float = vel.length()
	if speed < 150.0:
		return
	var strength: float = clampf((speed - 150.0) / 270.0, 0.0, 1.0)
	var back: Vector2 = -vel.normalized()
	var side: Vector2 = back.rotated(PI * 0.5) * radius * 0.78
	var tip: Vector2 = at + back * (radius + 34.0 * strength)
	ci.draw_polygon(PackedVector2Array([at + side, at - side, tip]),
		PackedColorArray([
			Color(col.r, col.g, col.b, 0.30 * strength),
			Color(col.r, col.g, col.b, 0.30 * strength),
			Color(col.r, col.g, col.b, 0.0)]))

# --- frame --------------------------------------------------------------------------------------

static func frame(ci: CanvasItem, area: Rect2) -> void:
	var l: float = area.position.x
	var r: float = area.position.x + area.size.x
	var t: float = area.position.y
	var b: float = area.position.y + area.size.y
	var w: float = 16.0
	var dark: Color = Color(0.0, 0.0, 0.0, 0.42)
	var clear: Color = Color(0.0, 0.0, 0.0, 0.0)
	# An inner shadow on each wall, so the field looks recessed into the frame rather than printed
	# on it, with a hairline of lit metal at the very edge.
	hgrad(ci, quad(Vector2(l, t), Vector2(l + w, t), Vector2(l + w, b), Vector2(l, b)), dark, clear)
	hgrad(ci, quad(Vector2(r - w, t), Vector2(r, t), Vector2(r, b), Vector2(r - w, b)), clear, dark)
	vgrad(ci, quad(Vector2(l, t), Vector2(r, t), Vector2(r, t + w), Vector2(l, t + w)), dark, clear)
	ci.draw_line(Vector2(l + 1.0, t), Vector2(l + 1.0, b), Color(FRAME_EDGE.r, FRAME_EDGE.g, FRAME_EDGE.b, 0.55), 2.0)
	ci.draw_line(Vector2(r - 1.0, t), Vector2(r - 1.0, b), Color(FRAME_EDGE.r, FRAME_EDGE.g, FRAME_EDGE.b, 0.55), 2.0)
	ci.draw_line(Vector2(l, t + 1.0), Vector2(r, t + 1.0), Color(FRAME_EDGE.r, FRAME_EDGE.g, FRAME_EDGE.b, 0.70), 2.0)

# --- inlet --------------------------------------------------------------------------------------

# The hopper the balls drop out of. Two angled plates leave a gap exactly as wide as the spawn band,
# so "they come from up there, in the center" is visible before the first ball ever falls.
static func inlet(ci: CanvasItem, area: Rect2, x0: float, x1: float) -> void:
	var l: float = area.position.x
	var r: float = area.position.x + area.size.x
	var t: float = area.position.y
	var h: float = 26.0
	var lip: float = 13.0
	for side in 2:
		var on_left: bool = side == 0
		var outer_x: float = l if on_left else r
		var inner_x: float = x0 if on_left else x1
		var plate: PackedVector2Array = quad(
			Vector2(outer_x, t), Vector2(inner_x, t),
			Vector2(inner_x + (lip if on_left else -lip), t + h),
			Vector2(outer_x, t + h * 0.55))
		vgrad(ci, plate, STEEL_MID, STEEL_DARK)
		ci.draw_line(Vector2(inner_x, t), Vector2(inner_x + (lip if on_left else -lip), t + h), STEEL_LIT, 2.5, true)
		# bolts: the detail that reads as "machined" at a glance
		var bx: float = outer_x + (30.0 if on_left else -30.0)
		for i in 2:
			ci.draw_circle(Vector2(bx, t + 9.0 + float(i) * 9.0), 2.0, Color(0.0, 0.0, 0.0, 0.35))
			bx += (34.0 if on_left else -34.0)
	ci.draw_line(Vector2(x0, t + 1.0), Vector2(x1, t + 1.0), Color(0.0, 0.0, 0.0, 0.5), 4.0)

# --- bumpers ------------------------------------------------------------------------------------

# `tri` is [top-on-wall, inward apex, bottom-on-wall]. The top face catches the light and the bottom
# face is in shadow, which is also the honest reading of the shape: a ball falling from above slides
# off the lit face.
static func bumper_shading() -> PackedColorArray:
	return PackedColorArray([STEEL_LIT, STEEL_MID, STEEL_DARK])

static func bumper(ci: CanvasItem, tri: PackedVector2Array, glow: float, glow_tex: Texture2D) -> void:
	if tri.size() < 3:
		return
	var drop: PackedVector2Array = PackedVector2Array([
		tri[0] + Vector2(0.0, 5.0), tri[1] + Vector2(3.0, 6.0), tri[2] + Vector2(0.0, 6.0)])
	ci.draw_colored_polygon(drop, Color(0.0, 0.0, 0.0, 0.30))
	ci.draw_polygon(tri, bumper_shading())
	ci.draw_line(tri[0], tri[1], Color(0.706, 0.769, 0.878, 0.9), 3.0, true)
	ci.draw_line(tri[1], tri[2], Color(0.078, 0.094, 0.141, 0.75), 3.0, true)
	# A hairline inside the lit face reads as a chamfer on the edge.
	var inward: Vector2 = (tri[1] - tri[0]).normalized().rotated(PI * 0.5) * 5.0
	ci.draw_line(tri[0] + inward, tri[1] + inward, Color(1.0, 1.0, 1.0, 0.10), 2.0, true)
	if glow > 0.001:
		ci.draw_line(tri[0], tri[1], Color(1.0, 1.0, 1.0, glow * 0.85), 3.0, true)
		ci.draw_line(tri[1], tri[2], Color(1.0, 1.0, 1.0, glow * 0.85), 3.0, true)
		if glow_tex != null:
			var s: float = 90.0
			ci.draw_texture_rect(glow_tex, Rect2(tri[1] - Vector2(s, s) * 0.5, Vector2(s, s)), false,
				Color(1.0, 1.0, 1.0, glow * 0.35))

# --- baskets ------------------------------------------------------------------------------------

# The parts of one basket, in draw order. `p` is [TL, TR, BR, BL] of the INTERIOR and `hw` is half
# the wall thickness, exactly as the collision boxes are laid out, so what is drawn is what a ball
# actually hits.
static func basket_parts(p: PackedVector2Array, hw: float) -> Dictionary:
	var tl: Vector2 = p[0]
	var tr2: Vector2 = p[1]
	var br: Vector2 = p[2]
	var bl: Vector2 = p[3]
	return {
		"outer": quad(Vector2(tl.x - hw, tl.y), Vector2(tr2.x + hw, tr2.y),
			Vector2(br.x + hw, br.y + 2.0 * hw), Vector2(bl.x - hw, bl.y + 2.0 * hw)),
		# The cavity is carried 30px above the mouth so the cup is OPEN at the top.
		"cavity": quad(Vector2(tl.x + hw, tl.y - 30.0), Vector2(tr2.x - hw, tr2.y - 30.0),
			Vector2(br.x - hw, br.y), Vector2(bl.x + hw, bl.y)),
		# A rolled rim, projecting OUTWARD past the wall and bevelled underneath. Flat caps sitting
		# square on top of the two walls turned each basket into a horseshoe magnet: a U of colored
		# body with a bright tip on each prong is exactly how a magnet is drawn. Overhanging the
		# OUTSIDE is what a bucket rim does and a pole face never does.
		"lip_left": quad(Vector2(tl.x - hw - COLLAR, tl.y), Vector2(tl.x + hw, tl.y),
			Vector2(tl.x + hw, tl.y + 13.0), Vector2(tl.x - hw, tl.y + 13.0)),
		"lip_right": quad(Vector2(tr2.x - hw, tr2.y), Vector2(tr2.x + hw + COLLAR, tr2.y),
			Vector2(tr2.x + hw, tr2.y + 13.0), Vector2(tr2.x - hw, tr2.y + 13.0)),
		"mouth_left": Vector2(tl.x + hw, tl.y),
		"mouth_right": Vector2(tr2.x - hw, tr2.y),
	}

# A basket is drawn in TWO passes with the balls in between, because a ball is IN the basket, not
# in front of it. The balls are child nodes of the level and the level's own `_draw` runs before
# every one of them, so anything drawn there is behind the ball no matter what it is — a ball
# resting in a cup used to cover the near wall completely and read as sitting on top of it.
# `basket_front` is drawn again from a node above the balls, so the rim and the ribs pass in front
# of the ball and the eye puts it inside.
static func basket_back(ci: CanvasItem, p: PackedVector2Array, col: Color, hw: float,
		flash: float, pulse: float, glow_tex: Texture2D) -> void:
	if p.size() < 4:
		return
	var parts: Dictionary = basket_parts(p, hw)
	var outer: PackedVector2Array = parts["outer"]
	var top_y: float = p[0].y
	var bot_y: float = p[2].y + 2.0 * hw

	# A halo of its own color, breathing slowly. Baskets are the target of the whole game and were
	# the least eye-catching thing on the screen.
	if glow_tex != null:
		var gw: float = (outer[1].x - outer[0].x) + 120.0
		var gh: float = (bot_y - top_y) + 120.0
		ci.draw_texture_rect(glow_tex, Rect2(Vector2((outer[0].x + outer[1].x) * 0.5 - gw * 0.5, top_y - 60.0),
			Vector2(gw, gh)), false, Color(col.r, col.g, col.b, 0.10 + 0.05 * pulse + 0.30 * flash))

	# Contact shadow, so the basket is an object standing in the field.
	var shadow: PackedVector2Array = quad(outer[0] + Vector2(0.0, 8.0), outer[1] + Vector2(0.0, 8.0),
		outer[2] + Vector2(4.0, 9.0), outer[3] + Vector2(-4.0, 9.0))
	ci.draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.34))

	vgrad(ci, outer, col.lightened(0.12), col.darkened(0.46))
	# The cup interior: nearly black at the mouth, picking up its own color at the bottom, which is
	# what makes a resting ball read as being INSIDE rather than in front.
	vgrad(ci, parts["cavity"], Color(0.031, 0.039, 0.063), col.darkened(0.66))
	var mouth_l: Vector2 = parts["mouth_left"]
	var mouth_r: Vector2 = parts["mouth_right"]
	vgrad(ci, quad(mouth_l, mouth_r, Vector2(mouth_r.x, mouth_r.y + 22.0), Vector2(mouth_l.x, mouth_l.y + 22.0)),
		Color(0.0, 0.0, 0.0, 0.45), Color(0.0, 0.0, 0.0, 0.0))

static func basket_front(ci: CanvasItem, p: PackedVector2Array, col: Color, hw: float, flash: float) -> void:
	if p.size() < 4:
		return
	var parts: Dictionary = basket_parts(p, hw)
	var outer: PackedVector2Array = parts["outer"]
	var top_y: float = p[0].y
	var bot_y: float = p[2].y + 2.0 * hw

	# Ribs. A plain colored slab reads as a solid object; a container has bands around it, and two
	# of them break the silhouette that the magnet reading depends on.
	for frac in [0.34, 0.66]:
		var ly: float = lerpf(top_y, bot_y, frac)
		var lx: float = lerpf(outer[0].x, outer[3].x, frac)
		var rx: float = lerpf(outer[1].x, outer[2].x, frac)
		ci.draw_line(Vector2(lx, ly), Vector2(rx, ly), Color(0.0, 0.0, 0.0, 0.20), 4.0)
		ci.draw_line(Vector2(lx, ly + 3.0), Vector2(rx, ly + 3.0), col.lightened(0.22), 1.5)

	for key in ["lip_left", "lip_right"]:
		var lip: PackedVector2Array = parts[key]
		vgrad(ci, lip, col.lightened(0.20), col.darkened(0.22))
		# Muted, and NOT the near-white it was: a bright cap on a prong tip is a magnet pole.
		ci.draw_line(lip[0], lip[1], Color(col.lightened(0.34), 0.55), 2.0, true)
	# rim light down the outside of each wall
	ci.draw_line(outer[0], outer[3], col.lightened(0.30), 2.0, true)
	ci.draw_line(outer[1], outer[2], Color(0.0, 0.0, 0.0, 0.35), 2.0, true)

	if flash > 0.001:
		ci.draw_colored_polygon(outer, Color(1.0, 1.0, 1.0, flash * 0.45))
		var mid: Vector2 = (parts["mouth_left"] + parts["mouth_right"]) * 0.5
		var ring: float = (1.0 - flash) * 62.0 + 20.0
		ci.draw_arc(mid, ring, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, flash * 0.65), 3.0, true)

# --- tool ---------------------------------------------------------------------------------------

# Drawn in the tool's own space: the disc sits at the origin (which is also where its collision
# circle is) and the loop hangs `grab_off` below it.
static func tool_parts(disc_r: float, loop_r: float, grab_off: float) -> Dictionary:
	return {
		"disc_center": Vector2.ZERO,
		"disc_radius": disc_r,
		"loop_center": Vector2(0.0, grab_off),
		"loop_radius": loop_r,
		"hint_radius": loop_r + 9.0,
		"stem_top": Vector2(0.0, disc_r * 0.45),
		"stem_bottom": Vector2(0.0, grab_off - loop_r),
	}

static func tool(ci: CanvasItem, col: Color, disc_r: float, loop_r: float, grab_off: float,
		held: bool, hint: float, pulse: float) -> void:
	var parts: Dictionary = tool_parts(disc_r, loop_r, grab_off)
	var loop_c: Vector2 = parts["loop_center"]
	var stem_w: float = maxf(9.0, disc_r * 0.42)
	var loop_w: float = maxf(5.0, disc_r * 0.22)

	# Everything casts down-right, one light, one direction.
	var off: Vector2 = Vector2(3.0, 7.0)
	ci.draw_circle(off, disc_r * 1.02, Color(0.0, 0.0, 0.0, 0.32))
	ci.draw_arc(loop_c + off, loop_r, 0.0, TAU, 24, Color(0.0, 0.0, 0.0, 0.28), loop_w, true)

	# The grab hint. The loop is the single least discoverable thing in this game — a player who
	# presses the disc gets nothing and concludes the tool is fixed — so until they grab one, the
	# handle pulses and the disc does not.
	if hint > 0.001:
		var hr: float = float(parts["hint_radius"]) + 4.0 * pulse
		ci.draw_arc(loop_c, hr, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, hint * (0.16 + 0.16 * pulse)), 3.0, true)
		ci.draw_arc(loop_c, hr + 7.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, hint * (0.07 + 0.09 * pulse)), 2.0, true)

	ci.draw_line(parts["stem_top"], parts["stem_bottom"], col.darkened(0.34), stem_w, true)
	ci.draw_line(parts["stem_top"] + Vector2(-stem_w * 0.22, 0.0), parts["stem_bottom"] + Vector2(-stem_w * 0.22, 0.0),
		col.lightened(0.22), stem_w * 0.30, true)

	ci.draw_arc(loop_c, loop_r, 0.0, TAU, 26, col.darkened(0.24), loop_w, true)
	ci.draw_arc(loop_c, loop_r, PI * 1.15, PI * 1.9, 16, col.lightened(0.45), loop_w * 0.5, true)

	# disc: dark base, colored face inset upward, one broad highlight and one specular dot
	ci.draw_circle(Vector2.ZERO, disc_r, col.darkened(0.52))
	ci.draw_circle(Vector2(0.0, -1.0), disc_r * 0.94, col)
	ci.draw_circle(Vector2(-disc_r * 0.24, -disc_r * 0.28), disc_r * 0.60, Color(col.lightened(0.30), 0.55))
	ci.draw_circle(Vector2(-disc_r * 0.32, -disc_r * 0.38), disc_r * 0.17, Color(1.0, 1.0, 1.0, 0.55))
	ci.draw_arc(Vector2.ZERO, disc_r - 1.5, 0.0, TAU, 34, col.darkened(0.45), 3.0, true)
	ci.draw_arc(Vector2.ZERO, disc_r - 2.5, PI * 1.05, PI * 1.95, 20, col.lightened(0.62), 2.5, true)
	if held:
		ci.draw_arc(Vector2.ZERO, disc_r + 5.0, 0.0, TAU, 36, Color(1.0, 1.0, 1.0, 0.30), 2.5, true)
		ci.draw_arc(loop_c, loop_r + 5.0, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, 0.22), 2.0, true)

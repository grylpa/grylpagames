class_name AntsArt
extends RefCounted

# Everything in this game is DRAWN -- soil, nest, food, ants, trail -- and drawn in world space by
# level.gd's single _draw(). No sprite, no tile.
#
# The ground is the same principle as the eleven lawns (scripts/grass_field.gd): one continuous
# surface, never a repeated image. It differs in how it is produced, because a lawn covers a board
# of known size and this world may be 680x680 or 6800x6800. So the grain is generated on demand
# from a hash of its own cell coordinates -- deterministic, so it never crawls or flickers, and
# generated ONLY for the part of the world on screen, so the cost is the same at either size.

# LIGHT ground, and it has to be. The ant is near-black by design, and against the old dark soil
# it stood at a contrast ratio of 1.46:1 -- which is not dim, it is invisible, and on a phone it was
# unusable. This palette puts it at 5.19:1 (WCAG AA is 4.5), and the speckle at worst 3.01:1.
#
# Lightening the ground is not a one-line change: CRUMB, FOOD, STONE and the nest were all picked
# to read against something dark, and at mid luminance they came out within 1.2-1.6:1 of the new
# soil -- differing from it in hue alone, which is exactly what a colour-blind player, or a phone in
# sunlight, cannot use. Every one of them was re-picked for a LUMINANCE difference instead.
const SOIL: Color = Color(0.608, 0.518, 0.416)
const SOIL_DARK: Color = Color(0.533, 0.447, 0.353)
const SOIL_LIGHT: Color = Color(0.682, 0.596, 0.494)
const GRAIN_DARK: Color = Color(0.451, 0.369, 0.286, 0.55)
const GRAIN_LIGHT: Color = Color(0.757, 0.678, 0.573, 0.50)

const ANT_BODY: Color = Color(0.106, 0.070, 0.055)
const ANT_SHEEN: Color = Color(0.310, 0.192, 0.125)
const CRUMB: Color = Color(0.729, 0.902, 0.463)
const FOOD_BODY: Color = Color(0.639, 0.827, 0.353)
const FOOD_DARK: Color = Color(0.125, 0.259, 0.071)
const NEST_RIM: Color = Color(0.400, 0.302, 0.208)
const NEST_HOLE: Color = Color(0.094, 0.062, 0.043)
# THE TRAIL MUST NOT LOOK LIKE THE GROUND. It was 0.298/0.243/0.086 at up to 0.42 alpha, drawn as
# 4 px rects -- and the soil grain is 0.451/0.369/0.286 at 0.55 alpha in 2-5 px rects. Two scatters
# of small brown marks on brown soil: measured against the soil, the trail reached 1.5:1 and the
# grain sat at 1.3:1, so at a glance a road was indistinguishable from the speckle it lay on.
#
# Darker, more opaque, and larger, so marks overlap into a continuous band instead of reading as
# dots. It stays a warm near-black rather than taking a hue of its own: green would collide with
# the food and the crumbs, and blue is the spray's.
const TRAIL: Color = Color(0.180, 0.142, 0.092)

# The wall around the patch. THIN and LOUD, which is the combination that was wanted: a wide, faint
# band read as a smudge of darker ground, and ants walked over it besides. Near-black against the
# light soil is 5.4:1, and the pale lip on its inner face gives it a second edge so it still reads
# as a rim at a glance.
const WALL_W: float = 7.0
const WALL_DARK: Color = Color(0.106, 0.078, 0.059)
const WALL_LIP: Color = Color(0.878, 0.827, 0.729)

# Obstacles. Each reads by SILHOUETTE and value before colour, so they stay apart on dark soil and
# for a colour-blind player: the stone is pale and blocky, the twig is long and dark, the water is
# darker than the ground with a bright rim.
# Where each leg pair meets the thorax, and how far forward (+) or back (-) it reaches. Front pair
# forward, middle pair out, hind pair back: the X an ant makes when you look down on one.
const COXA: Array = [0.17, 0.01, -0.16]
const KNEE_SPLAY: Array = [0.46, 0.00, -0.52]
const FOOT_SPLAY: Array = [0.80, 0.04, -0.95]

const STONE_BODY: Color = Color(0.808, 0.800, 0.776)
const STONE_LIT: Color = Color(0.898, 0.890, 0.867)
const STONE_DARK: Color = Color(0.482, 0.475, 0.455)
const TWIG_BODY: Color = Color(0.298, 0.196, 0.114)
const TWIG_LIT: Color = Color(0.412, 0.286, 0.173)
const TWIG_DARK: Color = Color(0.161, 0.106, 0.063)
const WATER_BODY: Color = Color(0.129, 0.290, 0.376)
const WATER_LIT: Color = Color(0.451, 0.686, 0.765)

# A grain cell is chosen from a fixed ladder so it is ANCHORED IN THE WORLD: panning never shifts
# the grain, and the cell only changes size when the zoom does, which happens once at level start.
# A pile is never a disc. Its outline is a few harmonics on the radius, seeded per pile, so each
# one has its own lopsided shape and none of them reads as a circle of jam.
const PILE_LOBES: Array = [3.0, 5.0, 7.0]
const PILE_AMPS: Array = [0.20, 0.12, 0.07]
const MIN_PILE_R: float = 9.0         # the last few crumbs still have to be reachable

const CELL_LADDER: Array = [8.0, 16.0, 32.0, 64.0, 128.0, 256.0, 512.0]
const SCREEN_CELL: float = 44.0        # target cell size in SCREEN px -- keeps the grain count
									   # roughly constant whatever the zoom or the world size

static func _hash01(x: int, y: int, k: int, seed_val: int) -> float:
	var h: int = x * 374761393 + y * 668265263 + k * 2147483647 + seed_val * 1274126177
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(absi(h) % 100000) / 100000.0

static func cell_for_zoom(zoom: float) -> float:
	var want: float = SCREEN_CELL / maxf(zoom, 0.001)
	var best: float = CELL_LADDER[0]
	for c: float in CELL_LADDER:
		if absf(c - want) < absf(best - want):
			best = c
	return best

# The ground, drawn ONCE for the WHOLE WORLD -- not for the view.
#
# It used to be generated for the visible rect, which meant it had to be rebuilt whenever the camera
# moved far enough. On a phone that put all 4,795 of its draw calls into a single frame in the
# middle of a swipe: free frames, then a hitch, then free frames. The ants stayed smooth because
# their motion is dt-based, and the PANNING lurched, which is exactly backwards from what it looks
# like. Drawn for the whole world it is built once at level start -- 21,000 commands at the largest
# level, behind the briefing card -- and no camera movement can ever cost anything again.
#
# The grains are `draw_rect`, not `draw_circle`. A circle tessellates into a fan of triangles and
# there are twenty thousand of them; a rect is two. At one to two units across the difference is
# invisible, and it is the difference between 42,000 triangles a frame and several hundred thousand.
static func draw_ground(ci: CanvasItem, world: Rect2, zoom: float, seed_val: int) -> void:
	ci.draw_rect(world, SOIL, true)
	# Two scales of variation. The coarse one is what stops a large world from reading as a flat
	# brown sheet; the fine grain only appears once a grain would be more than a pixel across.
	_scatter(ci, world, 256.0, 2, seed_val, 1, 58.0, 96.0, SOIL_DARK, SOIL_LIGHT, 0.22, false)
	var cell: float = cell_for_zoom(zoom)
	if cell * zoom >= 10.0:
		_scatter(ci, world, cell, 5, seed_val, 7, 0.9, 2.4, GRAIN_DARK, GRAIN_LIGHT, 1.0, true)

static func _scatter(ci: CanvasItem, area: Rect2, cell: float, per_cell: int, seed_val: int,
		salt: int, r_lo: float, r_hi: float, col_a: Color, col_b: Color, alpha: float,
		as_rect: bool) -> void:
	var x0: int = floori(area.position.x / cell)
	var y0: int = floori(area.position.y / cell)
	var x1: int = floori((area.position.x + area.size.x) / cell)
	var y1: int = floori((area.position.y + area.size.y) / cell)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			for i in per_cell:
				var k: int = salt + i * 31
				var px: float = (float(cx) + _hash01(cx, cy, k, seed_val)) * cell
				var py: float = (float(cy) + _hash01(cx, cy, k + 1, seed_val)) * cell
				var rr: float = lerpf(r_lo, r_hi, _hash01(cx, cy, k + 2, seed_val))
				var col: Color = col_a if _hash01(cx, cy, k + 3, seed_val) < 0.5 else col_b
				col.a *= alpha
				if as_rect:
					ci.draw_rect(Rect2(px - rr, py - rr, rr * 2.0, rr * 2.0), col, true)
				else:
					ci.draw_circle(Vector2(px, py), rr, col)

# The trail, drawn as what it is: a scatter of scent points, each fading with its own strength.
# Deliberately faint -- it is the thing the whole level exists to show forming, but an ant is the
# subject and a bright trail would out-shout it.
static func draw_marks(ci: CanvasItem, pts: PackedFloat32Array, zoom: float) -> void:
	# CIRCLES. This was rects, on the reasoning that a circle is a fan of triangles where a rect is
	# two, and that at four pixels under 0.42 alpha nobody could tell. Both halves stopped being
	# true: the marks are larger and much more opaque now, so the corners show and a road reads as
	# a chain of little squares. probe_ants times level 5 -- 120 ants over a 3x3 world -- and the
	# cost of the change is visible there rather than argued about here.
	# Bigger than the grain on purpose: at 4 px these were the same size as the soil speckle and
	# sat in the gaps between it rather than covering it.
	var rr: float = maxf(3.4, 4.6 / maxf(zoom, 0.2))
	var i: int = 0
	while i < pts.size():
		var s: float = pts[i + 2]
		var col: Color = TRAIL
		col.a = clampf(s * 0.125, 0.0, 0.64)
		ci.draw_circle(Vector2(pts[i], pts[i + 1]), rr, col)
		i += 3

# The spray on the ground: a pale bloom, deliberately unlike the trail, which is a dark warm
# scatter. It is drawn under the ants on the same layer as the trail, and it thins as it fades, so
# a patch you laid a minute ago looks like one that is nearly gone.
const SPRAY_TINT: Color = Color(0.792, 0.886, 0.945)

static func draw_spray(ci: CanvasItem, pts: PackedFloat32Array, zoom: float) -> void:
	var rr: float = maxf(13.0, 15.0 / maxf(zoom, 0.2))
	var i: int = 0
	while i < pts.size():
		var v: float = pts[i + 2]
		var col: Color = SPRAY_TINT
		col.a = clampf(v * 0.055, 0.0, 0.30)
		ci.draw_circle(Vector2(pts[i], pts[i + 1]), rr, col)
		i += 3

# The can itself, for the menu swatch: a body with a window showing how much is left, and a puff.
static func draw_spray_can(ci: CanvasItem, mid: Vector2, h: float, left: float) -> void:
	var w: float = h * 0.52
	var body: Rect2 = Rect2(mid.x - w * 0.5, mid.y - h * 0.34, w, h * 0.72)
	ci.draw_rect(body, Color(0.647, 0.690, 0.729), true)
	# The nozzle was 0.28 grey on a 0.10 cell and simply could not be seen; the swatch looked like a
	# can with its top cut off.
	ci.draw_rect(Rect2(mid.x - w * 0.22, mid.y - h * 0.52, w * 0.44, h * 0.18),
		Color(0.529, 0.573, 0.612), true)
	# The level inside, filling from the bottom: the swatch IS the gauge.
	var inner: Rect2 = body.grow(-maxf(1.5, h * 0.05))
	var fill_h: float = inner.size.y * clampf(left, 0.0, 1.0)
	ci.draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y - fill_h,
		inner.size.x, fill_h), SPRAY_TINT, true)
	ci.draw_rect(body, Color(0.20, 0.23, 0.26), false, maxf(1.0, h * 0.045))
	for k in 3:
		var a: float = -0.9 + float(k) * 0.45
		var from: Vector2 = mid + Vector2(w * 0.32, -h * 0.5)
		ci.draw_line(from, from + Vector2.from_angle(a) * h * 0.24,
			Color(SPRAY_TINT.r, SPRAY_TINT.g, SPRAY_TINT.b, 0.8), maxf(1.0, h * 0.05), true)

# The water jug, and how much is left in it -- the same idea as the spray can above, for the same
# reason: water is the one other tool the player SPENDS rather than places and recovers, so the
# swatch should be the supply and not just a picture of a puddle. A pool swatch said nothing about
# how many more you could pour, and the count in the corner is easy to miss mid-game.
static func draw_water_jug(ci: CanvasItem, mid: Vector2, h: float, left: float) -> void:
	var w: float = h * 0.56
	var body: Rect2 = Rect2(mid.x - w * 0.5, mid.y - h * 0.26, w, h * 0.64)
	var clay: Color = Color(0.612, 0.545, 0.478)
	var clay_dk: Color = Color(0.26, 0.22, 0.19)
	# Handle first, so the body is drawn over where it meets.
	ci.draw_arc(Vector2(mid.x + w * 0.52, mid.y + h * 0.02), h * 0.20, -1.25, 1.25, 14,
		clay, maxf(2.0, h * 0.085), true)
	# Neck and a poured lip.
	ci.draw_rect(Rect2(mid.x - w * 0.20, mid.y - h * 0.46, w * 0.40, h * 0.22), clay, true)
	ci.draw_rect(Rect2(mid.x - w * 0.30, mid.y - h * 0.50, w * 0.60, h * 0.09), clay, true)
	ci.draw_rect(body, clay, true)
	# What is left, filling from the bottom: the swatch IS the gauge.
	var inner: Rect2 = body.grow(-maxf(1.5, h * 0.055))
	var fill_h: float = inner.size.y * clampf(left, 0.0, 1.0)
	ci.draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y - fill_h,
		inner.size.x, fill_h), WATER_LIT, true)
	ci.draw_rect(body, clay_dk, false, maxf(1.0, h * 0.05))
	ci.draw_rect(Rect2(mid.x - w * 0.30, mid.y - h * 0.50, w * 0.60, h * 0.09), clay_dk, false,
		maxf(1.0, h * 0.04))

# THE ERASER: a chunky block of pink rubber in a blue paper sleeve, drawn FLAT and side-on like every
# other swatch in the menu (the can, the jug), with its working corner worn to a slant and a few
# rubber crumbs beside it -- the crumbs are what say "rubbing out". Three versions were dropped: a bare
# slanted strip (a tag), a three-quarter-view block (the only 3-D thing in the ring, and its faces did
# not agree), and a slim one with a rounded end and a white band on the sleeve, which read as a
# LIPSTICK -- a round end and a band are exactly what a lipstick has. So: square-cut, stubby, no band.
# `left` is the share of rubs remaining, and the rubber WEARS DOWN with it while the sleeve stays.
const ERASER_PINK: Color = Color(0.945, 0.604, 0.659)
const ERASER_PINK_LIT: Color = Color(0.984, 0.780, 0.812)
const SLEEVE: Color = Color(0.180, 0.431, 0.780)
const SLEEVE_DARK: Color = Color(0.118, 0.310, 0.588)
const ERASER_INK: Color = Color(0.200, 0.090, 0.110)

static func draw_eraser(ci: CanvasItem, mid: Vector2, h: float, left: float) -> void:
	var thick: float = h * 0.44
	var sleeve_len: float = h * 0.38
	# Never shorter than a stub of rubber, so a nearly spent eraser still shows some.
	var rubber: float = h * lerpf(0.10, 0.38, clampf(left, 0.0, 1.0))
	var full_len: float = sleeve_len + h * 0.38
	var x1: float = full_len * 0.5
	var xs: float = x1 - sleeve_len
	var x0: float = xs - rubber
	var y0: float = -thick * 0.5
	var y1: float = thick * 0.5
	var lw: float = maxf(1.0, h * 0.035)
	var wear: float = minf(thick * 0.35, rubber * 0.8)   # the slanted, worn corner
	var ang: float = -0.5
	ci.draw_set_transform(mid, ang, Vector2.ONE)
	var rub: PackedVector2Array = PackedVector2Array([Vector2(x0, y0), Vector2(xs, y0),
		Vector2(xs, y1), Vector2(x0 + wear, y1), Vector2(x0, y1 - wear)])
	ci.draw_colored_polygon(rub, ERASER_PINK)
	ci.draw_line(Vector2(x0 + lw, y0 + thick * 0.16), Vector2(xs - lw, y0 + thick * 0.16),
		ERASER_PINK_LIT, maxf(1.0, thick * 0.14), true)
	var sleeve: PackedVector2Array = PackedVector2Array([Vector2(xs, y0 - thick * 0.05),
		Vector2(x1, y0 - thick * 0.05), Vector2(x1, y1 + thick * 0.05), Vector2(xs, y1 + thick * 0.05)])
	ci.draw_colored_polygon(sleeve, SLEEVE)
	# The sleeve's folded edge, a darker strip where it wraps round the rubber.
	ci.draw_line(Vector2(xs + lw * 1.5, y0 - thick * 0.05), Vector2(xs + lw * 1.5, y1 + thick * 0.05),
		SLEEVE_DARK, maxf(1.0, h * 0.05), true)
	for poly in [rub, sleeve]:
		var loop: PackedVector2Array = poly.duplicate()
		loop.append(poly[0])
		ci.draw_polyline(loop, ERASER_INK, lw, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Crumbs, below the worn end in screen space so they lie on the "ground" whatever the tilt.
	var tip: Vector2 = mid + Vector2(x0, y1).rotated(ang)
	for k in 3:
		var at: Vector2 = tip + Vector2(-h * 0.02 + float(k) * h * 0.09, h * (0.10 + 0.04 * float(k % 2)))
		ci.draw_circle(at, maxf(1.2, h * 0.035), ERASER_PINK)

# Rubbed ground: a pale patch, there for as long as the ground stays clean and fading out over its
# last seconds (`fade` 1 -> 0), with a few rubber crumbs just after the rub (`fresh`). Pale because
# the trail is dark, so the patch reads as "cleaned" rather than as a new mark.
static func draw_rub(ci: CanvasItem, at: Vector2, r: float, fade: float, fresh: bool) -> void:
	var f: float = clampf(fade, 0.0, 1.0)
	var pale: Color = SOIL_LIGHT
	pale.a = 0.45 * f
	ci.draw_circle(at, r, pale)
	var edge: Color = GRAIN_LIGHT
	edge.a = 0.8 * f
	ci.draw_arc(at, r, 0.0, TAU, 32, edge, 2.0, true)
	if not fresh:
		return
	var crumb: Color = ERASER_PINK
	crumb.a = f
	for k in 7:
		var a: float = float(k) * 2.39996
		var d: float = r * (0.35 + 0.08 * float(k))
		ci.draw_circle(at + Vector2.from_angle(a) * d, 2.2, crumb)

static func draw_nest(ci: CanvasItem, at: Vector2, r: float, tint: Color) -> void:
	ci.draw_circle(at, r * 1.55, Color(NEST_RIM.r, NEST_RIM.g, NEST_RIM.b, 0.45))
	ci.draw_circle(at, r * 1.15, NEST_RIM)
	ci.draw_circle(at, r * 0.62, NEST_HOLE)
	# A ring in the colony's own color, so two nests are told apart at a glance without labelling
	# either -- and so a trail can later be tinted to match.
	ci.draw_arc(at, r * 1.32, 0.0, TAU, 40, tint, 2.4, true)

# How big the pile is NOW. The pile shrinks as it is carried away -- it is the only readout of
# progress the world itself gives -- and this is the one place that decides by how much, so what an
# ant can reach and what the player can see cannot drift apart. They did: pickup was a fixed 30
# units while the drawing shrank, so a nearly-empty pile went on handing out crumbs from bare
# ground.
static func pile_radius(base: float, left_frac: float) -> float:
	return maxf(base * sqrt(clampf(left_frac, 0.0, 1.0)), MIN_PILE_R)

# The pile's edge at one bearing. Used to DRAW the outline and to decide whether an ant is standing
# on the food, so the irregular shape is the real shape and not a picture of one.
static func pile_edge(rr: float, ang: float, seed_val: int) -> float:
	var f: float = 1.0
	for i in PILE_LOBES.size():
		var phase: float = _hash01(seed_val, i, 23, seed_val) * TAU
		f += float(PILE_AMPS[i]) * sin(float(PILE_LOBES[i]) * ang + phase)
	return rr * f

static func draw_food(ci: CanvasItem, at: Vector2, r: float, left_frac: float, seed_val: int) -> void:
	var rr: float = pile_radius(r, left_frac)
	if left_frac <= 0.0:
		return
	var ring: PackedVector2Array = PackedVector2Array()
	var steps: int = 44
	for i in steps:
		var a: float = TAU * float(i) / float(steps)
		ring.append(at + Vector2.from_angle(a) * pile_edge(rr * 1.06, a, seed_val))
	ci.draw_colored_polygon(ring, Color(FOOD_DARK.r, FOOD_DARK.g, FOOD_DARK.b, 0.55))
	var n: int = maxi(5, int(rr * 0.9))
	for i in n:
		var a: float = _hash01(i, seed_val, 3, seed_val) * TAU
		# Placed against the lobed edge rather than a circle, so the crumbs fill the real outline
		# instead of a disc with a ragged skin painted round it.
		var d: float = pile_edge(rr, a, seed_val) * 0.80 * sqrt(_hash01(i, seed_val, 5, seed_val))
		var p: Vector2 = at + Vector2.from_angle(a) * d
		var cr: float = lerpf(rr * 0.16, rr * 0.30, _hash01(i, seed_val, 9, seed_val))
		ci.draw_circle(p, cr, FOOD_BODY if (i % 3) != 0 else FOOD_DARK)

# An ant is drawn at two levels of detail. Legs and antennae on a 3-px ant are a smear, and 200
# smears cost more than they show, so past a certain zoom the ant becomes the dash it looks like
# from that distance anyway.
# A dead ant, left where it died: drawn exactly like a living one, in red. Nothing else.
#
# Several cleverer versions came before this -- flattened bodies, straightened legs, one and two
# outlines, pale limbs on a red body -- each chasing contrast on every possible ground, and each
# looking worse than the last. An ant that is red is plainly a dead ant, and that is all this needs
# to say.
const DEAD_ANT: Color = Color(0.620, 0.100, 0.080)

static func draw_dead_ant(ci: CanvasItem, at: Vector2, heading: float) -> void:
	var fwd: Vector2 = Vector2.from_angle(heading)
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var body_len: float = Ant.body_len()
	var gaster: Vector2 = at - fwd * body_len * 0.34
	var thorax: Vector2 = at + fwd * body_len * 0.04
	var head: Vector2 = at + fwd * body_len * 0.36
	var lw: float = maxf(0.8, body_len * 0.075)
	for i in 3:
		var base: Vector2 = thorax + fwd * (body_len * COXA[i])
		for s in [-1.0, 1.0]:
			var ka: float = float(KNEE_SPLAY[i])
			var fa: float = float(FOOT_SPLAY[i])
			var knee: Vector2 = base + (side * s * cos(ka) + fwd * sin(ka)) * body_len * 0.34
			var foot: Vector2 = base + (side * s * cos(fa) + fwd * sin(fa)) * body_len * 0.60
			ci.draw_line(base, knee, DEAD_ANT, lw, true)
			ci.draw_line(knee, foot, DEAD_ANT, lw * 0.85, true)
	for s2 in [-1.0, 1.0]:
		var tip: Vector2 = head + fwd * body_len * 0.42 + side * s2 * body_len * 0.30
		ci.draw_line(head + fwd * body_len * 0.10, tip, DEAD_ANT, lw * 0.8, true)
	ci.draw_circle(gaster, body_len * 0.235, DEAD_ANT)
	ci.draw_circle(thorax, body_len * 0.150, DEAD_ANT)
	ci.draw_circle(head, body_len * 0.175, DEAD_ANT)

static func draw_ant(ci: CanvasItem, a: Ant, zoom: float) -> void:
	var fwd: Vector2 = Vector2.from_angle(a.heading)
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var body_len: float = Ant.body_len()
	if body_len * zoom < 5.0:
		ci.draw_line(a.pos - fwd * body_len * 0.4, a.pos + fwd * body_len * 0.4,
			ANT_BODY, maxf(1.0, 2.2 / maxf(zoom, 0.1)), false)
		if a.state == Ant.State.HOMING:
			ci.draw_circle(a.pos + fwd * body_len * 0.55, maxf(1.0, 1.6 / maxf(zoom, 0.1)),
				LURE_TINT if a.carrying_bait else CRUMB)
		return

	var gaster: Vector2 = a.pos - fwd * body_len * 0.34
	var thorax: Vector2 = a.pos + fwd * body_len * 0.04
	var head: Vector2 = a.pos + fwd * body_len * 0.36

	# Six legs, three a side, in a tripod gait: left-front moves with right-middle and left-rear.
	# It is what makes a moving dot read as an insect rather than as a slider.
	#
	# They are NOT parallel. A real ant's front pair reaches forward, the middle pair straight out,
	# and the hind pair sweeps back -- so seen from above the front and hind legs cross into an X
	# with the middle pair sticking out through it. Drawn as three parallel oars, which is what
	# this was, an ant reads like a woodlouse.
	var lw: float = maxf(0.8, body_len * 0.075)
	for i in 3:
		var base: Vector2 = thorax + fwd * (body_len * COXA[i])
		var swing: float = sin(a.gait + float(i) * 2.1) * 0.30
		for s in [-1.0, 1.0]:
			var ph: float = swing * (1.0 if ((i % 2) == 0) == (s > 0.0) else -1.0)
			# The knee splays less than the foot, which is what gives a leg its elbow rather than
			# making it a straight spoke.
			var ka: float = float(KNEE_SPLAY[i]) + ph
			var fa: float = float(FOOT_SPLAY[i]) + ph
			var out_k: Vector2 = side * s * cos(ka) + fwd * sin(ka)
			var out_f: Vector2 = side * s * cos(fa) + fwd * sin(fa)
			var knee: Vector2 = base + out_k * body_len * 0.34
			var foot: Vector2 = base + out_f * body_len * 0.60
			ci.draw_line(base, knee, ANT_BODY, lw, true)
			ci.draw_line(knee, foot, ANT_BODY, lw * 0.85, true)

	for s in [-1.0, 1.0]:
		var tip: Vector2 = head + fwd * body_len * 0.42 + side * s * body_len * 0.30 \
			+ side * s * sin(a.gait * 0.7) * body_len * 0.06
		ci.draw_line(head + fwd * body_len * 0.10, tip, ANT_BODY, lw * 0.8, true)

	ci.draw_circle(gaster, body_len * 0.235, ANT_BODY)
	ci.draw_circle(thorax, body_len * 0.150, ANT_BODY)
	ci.draw_circle(head, body_len * 0.175, ANT_BODY)
	# One highlight on the gaster: a chitin shine, and the thing that keeps a black ant from
	# disappearing into dark soil.
	ci.draw_circle(gaster - fwd * body_len * 0.05, body_len * 0.085,
		Color(ANT_SHEEN.r, ANT_SHEEN.g, ANT_SHEEN.b, 0.55))

	if a.state == Ant.State.HOMING:
		# What it is carrying, in the colour of where it came from -- so a stream of ants working
		# your bait is visibly a stream working your bait, and not a raid on the real pile.
		ci.draw_circle(head + fwd * body_len * 0.26, body_len * 0.20,
			LURE_TINT if a.carrying_bait else CRUMB)


# One obstacle, drawn from the SAME outline its collision uses (AntObstacle.outline), so what an
# ant cannot walk through and what the player sees are the same shape by construction.
static func draw_obstacle(ci: CanvasItem, o: AntObstacle) -> void:
	var ring: PackedVector2Array = o.outline(40)
	# A dropped shadow, so a stone sits ON the soil rather than being a hole cut in it.
	var shadow: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in ring:
		shadow.append(p + Vector2(2.5, 3.5))
	ci.draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.30))

	# The two that are not solid are drawn as air and light, with no filled body at all, so nothing
	# about them says "you cannot walk here" -- because you can.
	if o.kind == AntObstacle.Kind.LURE:
		_draw_lure(ci, o)
		return
	var body: Color = STONE_BODY
	var lit: Color = STONE_LIT
	var dark: Color = STONE_DARK
	if o.kind == AntObstacle.Kind.TWIG:
		body = TWIG_BODY
		lit = TWIG_LIT
		dark = TWIG_DARK
	elif o.kind == AntObstacle.Kind.WATER:
		body = WATER_BODY
		lit = WATER_LIT
		dark = WATER_BODY.darkened(0.35)
	ci.draw_colored_polygon(ring, body)

	# The lit face: the same outline shrunk toward the light, which gives a rounded body without a
	# gradient. The light in this world comes from the top left, as it does for the ants.
	var lift: Vector2 = Vector2(-0.18, -0.22)
	var inner: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in ring:
		inner.append(o.pos + (p - o.pos) * 0.62 + Vector2(o.half.x, o.half.y) * lift * 0.35)
	if o.kind == AntObstacle.Kind.WATER:
		# A puddle is a hole, not a lump: it gets a bright rim and a dark middle, the opposite of
		# the stone, which is what stops the two reading as the same object in two colours.
		ci.draw_polyline(_closed(ring), WATER_LIT, 2.0, true)
		ci.draw_colored_polygon(inner, dark)
	else:
		ci.draw_colored_polygon(inner, lit)
		ci.draw_polyline(_closed(ring), dark, 1.6, true)
	if o.kind == AntObstacle.Kind.TWIG:
		# Bark: a couple of lines along the length, so a twig is not just a dark lozenge.
		var along: Vector2 = Vector2.from_angle(o.angle)
		var side: Vector2 = Vector2(-along.y, along.x)
		for k in [-0.34, 0.30]:
			ci.draw_line(o.pos - along * o.half.x * 0.72 + side * o.half.y * k,
				o.pos + along * o.half.x * 0.72 + side * o.half.y * k, dark, 1.2, true)

# BAIT: a pile of food, drawn like the real one and dwindling like the real one, but in a colour the
# player can tell apart at a glance. The ants cannot, which is the point.
const LURE_TINT: Color = Color(0.949, 0.780, 0.353)
const LURE_DARK: Color = Color(0.588, 0.412, 0.098)

static func _draw_lure(ci: CanvasItem, o: AntObstacle) -> void:
	var left: float = float(o.crumbs) / maxf(float(o.crumbs_at_start), 1.0)
	var rr: float = maxf(o.half.x * sqrt(clampf(left, 0.0, 1.0)), 7.0)
	var ring: PackedVector2Array = PackedVector2Array()
	for i in 34:
		var a: float = TAU * float(i) / 34.0
		ring.append(o.pos + Vector2.from_angle(a) * pile_edge(rr * 1.06, a, o.seed_val))
	ci.draw_colored_polygon(ring, Color(LURE_DARK.r, LURE_DARK.g, LURE_DARK.b, 0.55))
	var n: int = maxi(5, int(rr * 0.9))
	for i in n:
		var a: float = _hash01(i, o.seed_val, 3, o.seed_val) * TAU
		var d: float = pile_edge(rr, a, o.seed_val) * 0.80 * sqrt(_hash01(i, o.seed_val, 5, o.seed_val))
		var p: Vector2 = o.pos + Vector2.from_angle(a) * d
		var cr: float = lerpf(rr * 0.16, rr * 0.30, _hash01(i, o.seed_val, 9, o.seed_val))
		ci.draw_circle(p, cr, LURE_TINT if (i % 3) != 0 else LURE_DARK)

static func _closed(ring: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = ring.duplicate()
	if out.size() > 0:
		out.append(out[0])
	return out


# The world's limits, drawn as something solid rather than as a shaded rule.
#
# The wall lies INSIDE the world rect, in the band between it and the walkable area, so it is
# visible wherever the camera can reach -- the camera is clamped to the world, so anything drawn
# outside it could never be seen at all, which is why the first version's border vanished the
# moment you panned to an edge. Ants are turned at the wall's inner face and never stand on it.
static func draw_border(ci: CanvasItem, world: Rect2, w: float) -> void:
	var p: Vector2 = world.position
	var sz: Vector2 = world.size
	ci.draw_rect(Rect2(p, Vector2(sz.x, w)), WALL_DARK, true)
	ci.draw_rect(Rect2(p + Vector2(0.0, sz.y - w), Vector2(sz.x, w)), WALL_DARK, true)
	ci.draw_rect(Rect2(p + Vector2(0.0, w), Vector2(w, sz.y - w * 2.0)), WALL_DARK, true)
	ci.draw_rect(Rect2(p + Vector2(sz.x - w, w), Vector2(w, sz.y - w * 2.0)), WALL_DARK, true)
	# The lip: a bright line on the inner face, so the wall has a hard edge against the ground
	# instead of fading into it.
	ci.draw_rect(Rect2(p + Vector2(w, w), sz - Vector2(w, w) * 2.0).grow(1.0), WALL_LIP, false, 2.0)

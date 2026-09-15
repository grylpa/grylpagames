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

const SOIL: Color = Color(0.262, 0.184, 0.129)
const SOIL_DARK: Color = Color(0.207, 0.141, 0.098)
const SOIL_LIGHT: Color = Color(0.320, 0.233, 0.164)
const GRAIN_DARK: Color = Color(0.170, 0.112, 0.076, 0.55)
const GRAIN_LIGHT: Color = Color(0.404, 0.309, 0.223, 0.50)

const ANT_BODY: Color = Color(0.106, 0.070, 0.055)
const ANT_SHEEN: Color = Color(0.310, 0.192, 0.125)
const CRUMB: Color = Color(0.564, 0.741, 0.310)
const FOOD_BODY: Color = Color(0.478, 0.674, 0.251)
const FOOD_DARK: Color = Color(0.325, 0.486, 0.164)
const NEST_RIM: Color = Color(0.372, 0.278, 0.196)
const NEST_HOLE: Color = Color(0.094, 0.062, 0.043)
const TRAIL: Color = Color(0.415, 0.360, 0.180)

# Obstacles. Each reads by SILHOUETTE and value before colour, so they stay apart on dark soil and
# for a colour-blind player: the stone is pale and blocky, the twig is long and dark, the water is
# darker than the ground with a bright rim.
# Where each leg pair meets the thorax, and how far forward (+) or back (-) it reaches. Front pair
# forward, middle pair out, hind pair back: the X an ant makes when you look down on one.
const COXA: Array = [0.17, 0.01, -0.16]
const KNEE_SPLAY: Array = [0.46, 0.00, -0.52]
const FOOT_SPLAY: Array = [0.80, 0.04, -0.95]

const STONE_BODY: Color = Color(0.560, 0.545, 0.514)
const STONE_LIT: Color = Color(0.701, 0.686, 0.650)
const STONE_DARK: Color = Color(0.352, 0.337, 0.317)
const TWIG_BODY: Color = Color(0.376, 0.254, 0.152)
const TWIG_LIT: Color = Color(0.501, 0.352, 0.215)
const TWIG_DARK: Color = Color(0.200, 0.129, 0.078)
const WATER_BODY: Color = Color(0.141, 0.286, 0.352)
const WATER_LIT: Color = Color(0.407, 0.639, 0.709)

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

static func draw_ground(ci: CanvasItem, vis: Rect2, world: Rect2, zoom: float, seed_val: int) -> void:
	var area: Rect2 = vis.intersection(world)
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	ci.draw_rect(area, SOIL, true)

	# Two scales of variation. The coarse one is always drawn -- it is what stops a large world from
	# reading as a flat brown sheet when zoomed out. The fine grain only appears once a grain would
	# be more than a pixel across; below that it is invisible anyway and merely costs frames.
	_scatter(ci, area, 256.0, 2, seed_val, 1, 58.0, 96.0, SOIL_DARK, SOIL_LIGHT, 0.22)
	var cell: float = cell_for_zoom(zoom)
	if cell * zoom >= 10.0:
		_scatter(ci, area, cell, 5, seed_val, 7, 0.9, 2.4, GRAIN_DARK, GRAIN_LIGHT, 1.0)

static func _scatter(ci: CanvasItem, area: Rect2, cell: float, per_cell: int, seed_val: int,
		salt: int, r_lo: float, r_hi: float, col_a: Color, col_b: Color, alpha: float) -> void:
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
				ci.draw_circle(Vector2(px, py), rr, col)

# The trail, drawn as what it is: a scatter of scent points, each fading with its own strength.
# Deliberately faint -- it is the thing the whole level exists to show forming, but an ant is the
# subject and a bright trail would out-shout it.
static func draw_marks(ci: CanvasItem, pts: PackedFloat32Array, zoom: float) -> void:
	var rr: float = maxf(2.2, 3.0 / maxf(zoom, 0.2))
	var i: int = 0
	while i < pts.size():
		var s: float = pts[i + 2]
		var col: Color = TRAIL
		col.a = clampf(s * 0.085, 0.0, 0.42)
		ci.draw_circle(Vector2(pts[i], pts[i + 1]), rr, col)
		i += 3

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
static func draw_ant(ci: CanvasItem, a: Ant, zoom: float) -> void:
	var fwd: Vector2 = Vector2.from_angle(a.heading)
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var body_len: float = Ant.LENGTH
	if body_len * zoom < 5.0:
		ci.draw_line(a.pos - fwd * body_len * 0.4, a.pos + fwd * body_len * 0.4,
			ANT_BODY, maxf(1.0, 2.2 / maxf(zoom, 0.1)), false)
		if a.state == Ant.State.HOMING:
			ci.draw_circle(a.pos + fwd * body_len * 0.55, maxf(1.0, 1.6 / maxf(zoom, 0.1)), CRUMB)
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
		ci.draw_circle(head + fwd * body_len * 0.26, body_len * 0.20, CRUMB)


# One obstacle, drawn from the SAME outline its collision uses (AntObstacle.outline), so what an
# ant cannot walk through and what the player sees are the same shape by construction.
static func draw_obstacle(ci: CanvasItem, o: AntObstacle) -> void:
	var ring: PackedVector2Array = o.outline(40)
	# A dropped shadow, so a stone sits ON the soil rather than being a hole cut in it.
	var shadow: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in ring:
		shadow.append(p + Vector2(2.5, 3.5))
	ci.draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.30))

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

static func _closed(ring: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = ring.duplicate()
	if out.size() > 0:
		out.append(out[0])
	return out

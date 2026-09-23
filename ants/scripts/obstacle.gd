class_name AntObstacle
extends RefCounted

# Something an ant cannot walk through.
#
# ONE shape serves all three kinds: an oriented ellipse whose radius is modulated by a few
# harmonics, seeded per obstacle. A stone is a fat lopsided one, a twig is a long thin one, a
# puddle is a wide irregular one -- so `contains()` and the drawing read the same geometry and
# cannot disagree about where the edge is. That lesson came from the food pile, where a fixed
# pickup radius and a shrinking drawn radius quietly parted company.

enum Kind { STONE, TWIG, WATER, LURE }

const KINDS: Array = [Kind.STONE, Kind.TWIG, Kind.WATER, Kind.LURE]
const NAMES: Dictionary = {Kind.STONE: "Stone", Kind.TWIG: "Twig", Kind.WATER: "Water",
	Kind.LURE: "Bait"}
# One line each, for the tooltip a long press opens.
const TIPS: Dictionary = {
	Kind.STONE: "A rock. They must walk around it.\nPick it up and move it as the trail shifts.",
	Kind.TWIG: "A long branch, laid ACROSS the trail\nwherever you drop it. A proper wall.",
	Kind.WATER: "A pool they will not cross. It dries\nas you watch, and you cannot take it back.",
	Kind.LURE: "Food you do not mind losing. They will\ncarry it home instead, and it costs you\nnothing. Runs out.",
}
# Bait is FOOD, and food is eaten. How many crumbs one holds -- every trip spent carrying these is a
# trip not spent on the pile you are defending.
const BAIT_CRUMBS: int = 45
# HOW LONG A POOL LASTS, in seconds, before it has dried to nothing.
#
# Water is the only tool that is neither permanent nor recoverable. A stone is forever until you
# move it; bait ends when it is eaten. A pool just goes -- it shrinks the whole time, so what it
# buys you is TIME rather than ground, and the decision it asks for is when to spend it rather
# than where. Against a 90-115 s level, 40 s is most of a phase of the game and not the whole of
# it.
const WATER_DRY_SEC: float = 40.0
# It stops being a wall before it stops being visible: the last of it is a damp mark.
const WATER_MIN_SCALE: float = 0.18
# SOLID things are walked around. Bait is not: an ant walks onto it, which is the whole idea.
#
# Every solid tool says "not through here". Bait says "here is something easier", and the colony
# answers it by itself -- finds it, recruits to it, and spends its trips carrying away food you were
# never defending. It is the only tool that works WITH the colony's own machinery rather than
# against it, and it needs no special pleading in the ant to do so.
const SOLID: Dictionary = {Kind.STONE: true, Kind.TWIG: true, Kind.WATER: true, Kind.LURE: false}
# A stone or a twig can be lifted and carried to wherever the trail has moved to -- that is the
# whole game. Water cannot: once it is poured it is poured, and mopping it up does not put it back
# in the bottle. So water is the decision you cannot take back, and it is priced by being scarce.
const REUSABLE: Dictionary = {Kind.STONE: true, Kind.TWIG: true, Kind.WATER: false,
	Kind.LURE: false}

static func is_reusable(k: int) -> bool:
	return bool(REUSABLE.get(k, true))

static func is_solid(k: int) -> bool:
	return bool(SOLID.get(k, true))

func solid() -> bool:
	return is_solid(kind)

# half extents (along, across), lobe amplitude
const SHAPE: Dictionary = {
	Kind.STONE: [Vector2(34.0, 27.0), 0.13],
	Kind.TWIG:  [Vector2(76.0, 9.0), 0.06],
	Kind.WATER: [Vector2(46.0, 36.0), 0.20],
	Kind.LURE:  [Vector2(30.0, 30.0), 0.16],
}
const LOBES: Array = [3.0, 5.0, 7.0]

var kind: int = Kind.STONE
var pos: Vector2 = Vector2.ZERO
var angle: float = 0.0
var half: Vector2 = Vector2(30.0, 24.0)
var amp: float = 0.13
var seed_val: int = 0
# Bait only: what is left of it. Nothing else uses this.
# 1 when freshly poured, 0 when gone. Only water uses it.
var wet: float = 1.0
var half_at_start: Vector2 = Vector2.ZERO
var crumbs: int = 0
var crumbs_at_start: int = 1

func _init(which: int, at: Vector2, rot: float, which_seed: int) -> void:
	kind = which
	pos = at
	angle = rot
	seed_val = which_seed
	half = SHAPE[which][0]
	amp = SHAPE[which][1]
	half_at_start = half
	if which == Kind.LURE:
		crumbs = BAIT_CRUMBS
		crumbs_at_start = BAIT_CRUMBS

func _h01(k: int) -> float:
	var h: int = seed_val * 374761393 + k * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(absi(h) % 100000) / 100000.0

# The edge, as a multiple of the unit radius, at one bearing in the shape's own frame.
func _edge(a: float) -> float:
	var f: float = 1.0
	for i in LOBES.size():
		f += amp * (0.6 if i > 0 else 1.0) * sin(float(LOBES[i]) * a + _h01(i * 7 + 3) * TAU)
	return f

# Local frame: rotated so the long axis is x, then scaled so the ellipse becomes a unit circle.
func _to_local(p: Vector2) -> Vector2:
	var r: Vector2 = (p - pos).rotated(-angle)
	return Vector2(r.x / half.x, r.y / half.y)

func contains(p: Vector2) -> bool:
	return contains_margin(p, 0.0)

# The same test against a shape grown by `m`, which is how an ant keeps its distance instead of
# scraping along the surface. Growing each half-extent is an approximation of a true offset curve
# -- exact along the axes, near enough between them for something an ant is only using to decide
# which way to lean.
func contains_margin(p: Vector2, m: float) -> bool:
	# Cheap reject first: every ant is tested against every obstacle, every tick.
	var hx: float = half.x + m
	var hy: float = half.y + m
	var far: float = maxf(hx, hy) * (1.0 + amp)
	if absf(p.x - pos.x) > far or absf(p.y - pos.y) > far:
		return false
	var r: Vector2 = (p - pos).rotated(-angle)
	var l: Vector2 = Vector2(r.x / hx, r.y / hy)
	var d: float = l.length()
	if d < 0.0001:
		return true
	return d <= _edge(l.angle())

# One tick of evaporation. Returns true once the pool is finished.
#
# It shrinks `half`, which is the same number contains(), outline() and the drawing all read -- so
# the pool an ant refuses to cross is exactly the pool the player can see, at every moment of its
# life. That is the lesson this file opens with, and drying is precisely the case that would have
# broken it if the drawn size and the collision size had been kept apart.
func dry(dt: float) -> bool:
	if kind != Kind.WATER:
		return false
	wet = maxf(wet - dt / WATER_DRY_SEC, 0.0)
	half = half_at_start * lerpf(WATER_MIN_SCALE, 1.0, wet)
	return wet <= 0.0

func bound_radius() -> float:
	return maxf(half.x, half.y) * (1.0 + amp)

# The nearest point OUTSIDE, for an ant that has clipped a corner -- which must never leave one
# walled in, and must never take the LONG way out.
#
# The obvious implementation takes the radial direction in the shape's own frame, and it is wrong
# for anything long: an ant just inside the middle of a twig (152 units by 18) would be sent 76
# units along it rather than 9 across it, and the per-tick cap then slid it lengthwise INSIDE the
# twig for dozens of ticks. Measured that way, one ant was 29.7 units deep in a twig it should
# never have been able to enter.
#
# So the exit is searched for instead: eight bearings in the shape's own frame, so the short axis
# is always among them, marched outwards, nearest wins.
func push_out(p: Vector2, margin: float) -> Vector2:
	var reach: float = bound_radius() * 1.3
	var step: float = 1.5
	var best: Vector2 = Vector2.ZERO
	var best_d: float = INF
	for i in 8:
		var local_dir: Vector2 = Vector2.from_angle(TAU * float(i) / 8.0)
		var dir: Vector2 = local_dir.rotated(angle)
		var d: float = step
		while d <= reach:
			if not contains(p + dir * d):
				break
			d += step
		if d <= reach and d < best_d:
			best_d = d
			best = dir
	if best_d == INF:
		# Nowhere out within reach, which should not happen: leave along the long axis rather than
		# returning the point itself, since returning it would leave the ant stuck forever.
		best = Vector2.RIGHT.rotated(angle)
		best_d = reach
	return p + best * (best_d + margin)

# Do two of these share any ground? Sampled rather than solved: both shapes are lobed ellipses at
# arbitrary angles, and an exact test is a page of algebra for a question a ring of points answers
# well enough. Centres are checked too, so a small one wholly inside a large one is caught even
# though none of its outline points would be.
func overlaps(other: AntObstacle) -> bool:
	var reach: float = bound_radius() + other.bound_radius()
	if pos.distance_squared_to(other.pos) > reach * reach:
		return false
	if other.contains(pos) or contains(other.pos):
		return true
	for p: Vector2 in outline(24):
		if other.contains(p):
			return true
	for p: Vector2 in other.outline(24):
		if contains(p):
			return true
	return false

# Outline for drawing, in world space.
func outline(steps: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i in steps:
		var a: float = TAU * float(i) / float(steps)
		var e: float = _edge(a)
		var l: Vector2 = Vector2.from_angle(a) * e
		out.append(pos + Vector2(l.x * half.x, l.y * half.y).rotated(angle))
	return out

class_name AntObstacle
extends RefCounted

# Something an ant cannot walk through.
#
# ONE shape serves all three kinds: an oriented ellipse whose radius is modulated by a few
# harmonics, seeded per obstacle. A stone is a fat lopsided one, a twig is a long thin one, a
# puddle is a wide irregular one -- so `contains()` and the drawing read the same geometry and
# cannot disagree about where the edge is. That lesson came from the food pile, where a fixed
# pickup radius and a shrinking drawn radius quietly parted company.

enum Kind { STONE, TWIG, WATER }

const KINDS: Array = [Kind.STONE, Kind.TWIG, Kind.WATER]
const NAMES: Dictionary = {Kind.STONE: "Stone", Kind.TWIG: "Twig", Kind.WATER: "Water"}

# half extents (along, across), lobe amplitude
const SHAPE: Dictionary = {
	Kind.STONE: [Vector2(34.0, 27.0), 0.13],
	Kind.TWIG:  [Vector2(76.0, 9.0), 0.06],
	Kind.WATER: [Vector2(46.0, 36.0), 0.20],
}
const LOBES: Array = [3.0, 5.0, 7.0]

var kind: int = Kind.STONE
var pos: Vector2 = Vector2.ZERO
var angle: float = 0.0
var half: Vector2 = Vector2(30.0, 24.0)
var amp: float = 0.13
var seed_val: int = 0

func _init(which: int, at: Vector2, rot: float, which_seed: int) -> void:
	kind = which
	pos = at
	angle = rot
	seed_val = which_seed
	half = SHAPE[which][0]
	amp = SHAPE[which][1]

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

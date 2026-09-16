class_name AntColony
extends RefCounted

# A nest and the ants that belong to it. Each colony carries its OWN scent field, so two colonies
# never recruit onto each other's trails -- which is also true of the real thing, and is the only
# reason the multi-colony levels will read as separate societies rather than one confused one.

# A colony does not turn out all at once. Every ant used to be created at t=0 inside an 18-unit
# disc around the nest, so the whole colony set off together and spread as one visible wavefront --
# a ring expanding out of every nest at the start of every level, which is not a thing ants do.
# They come out of the hole in a trickle instead, over this many seconds, and the nest is full for
# a while rather than empty.
const EMERGE_WINDOW: float = 20.0

const NEST_RADIUS: float = 26.0        # the mound
# A crumb is deposited DOWN THE HOLE, not on the doorstep. Arriving anywhere on the 26-unit mound
# used to be enough, so the crumb vanished a whole body length short of the entrance and the ant
# turned round in the open -- it read as the food evaporating rather than as the ant delivering it.
# This is inside the drawn hole (NEST_RADIUS * 0.62), so the ant is visibly in the entrance when
# the crumb goes, waits a moment, and comes back out.
const HOLE_FRAC: float = 0.50
const SPAWN_SPREAD: float = 18.0

var nest: Vector2 = Vector2.ZERO
var ants: Array[Ant] = []              # out and working
var pending: Array[Ant] = []           # still inside, waiting their turn
var marks: ScentMarks = ScentMarks.new()
var delivered: int = 0
# Ants lost to an obstacle being dropped on top of them. Kept per colony because that is the unit
# a cost would ever be charged against; nothing reads it yet.
var killed: int = 0
var tint: Color = Color(0.36, 0.22, 0.12)
var idx: int = 0

func _init(at: Vector2, which: int, col: Color) -> void:
	nest = at
	idx = which
	tint = col

func populate(how_many: int, speed_lo: float, speed_hi: float) -> void:
	ants.clear()
	pending.clear()
	killed = 0
	for _i in how_many:
		var dir: float = randf_range(-PI, PI)
		# Drawn ONCE, at spawn, and kept for the ant's life. Re-rolling it per tick would average
		# every ant to the same pace; keeping it is what makes a column look like individuals.
		var a: Ant = Ant.new(nest, dir, randf_range(speed_lo, speed_hi), idx, nest)
		# Uniform over the window rather than evenly spaced: an even spacing is its own pattern,
		# and a trickle is irregular.
		a.emerge_at = randf() * EMERGE_WINDOW
		pending.append(a)
	pending.sort_custom(func(x: Ant, y: Ant) -> bool: return x.emerge_at < y.emerge_at)

func population() -> int:
	return ants.size() + pending.size()

# Anyone whose turn has come, placed in the entrance and facing out. Returns how many came up, so
# the level knows whether its flat list of ants needs rebuilding.
func release_due(clock: float) -> int:
	var out: int = 0
	while not pending.is_empty() and pending[0].emerge_at <= clock:
		var a: Ant = pending.pop_front()
		var dir: float = randf_range(-PI, PI)
		a.pos = nest + Vector2.from_angle(dir) * (NEST_RADIUS * HOLE_FRAC * 0.8)
		a.heading = dir
		# It has just walked up out of the hole, so it knows exactly where home is.
		a.home_vec = nest - a.pos
		ants.append(a)
		out += 1
	return out

func is_home(p: Vector2) -> bool:
	return p.distance_squared_to(nest) <= NEST_RADIUS * NEST_RADIUS

# Close enough to be IN the entrance, which is what it takes to deliver.
func at_hole(p: Vector2) -> bool:
	var r: float = NEST_RADIUS * HOLE_FRAC
	return p.distance_squared_to(nest) <= r * r

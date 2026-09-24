class_name ScentMarks
extends RefCounted

# The trail, WITHOUT a grid.
#
# The usual way to do pheromone is a raster: an array of cells covering the world, each holding a
# concentration, with ants reading the four neighbours to get a gradient. That was rejected twice
# over. It quantises the field, so an ant crossing a cell boundary gets a step change in what it
# smells and steers in visible little jerks; and it allocates the whole WORLD, so a 10x10 world
# (6800x6800) would carry 722,500 cells that have to be evaporated every update whether one ant
# has walked there or not.
#
# So a mark is a POINT, dropped where the ant actually was, with a real position and a strength.
# Sensing sums the marks within SENSE_R of the sample point, weighted by distance -- a smooth
# scalar field with no cells in it, sampled at whatever arbitrary point an antenna happens to be.
# Cost scales with GROUND WALKED, not with world area, which is why the same code serves 1x1 and
# 10x10.
#
# The Dictionary below is a lookup accelerator and nothing else: it decides which handful of marks
# are worth measuring, and never rounds a position or a strength.

const SENSE_R: float = 26.0        # how far an antenna smells
const CELL: float = SENSE_R        # so a query is always a 3x3 block
# How coarsely the field is STORED -- not how it is sensed, which is SENSE_R and unchanged. Raising
# it from 6 thinned a formed trail from about 1,800 marks to 650 without altering its shape: a
# sensed value is the sum of everything within 26 units under a smooth falloff, so fewer, stronger
# marks describe the same field. The cost it removes is real and it arrives exactly when the game
# gets interesting -- with no trail a sense() call evaluates 2 marks, with one it evaluated 70, and
# the whole simulation tripled in cost the moment the ants found the food.
const MERGE_R: float = 10.0
const MAX_STRENGTH: float = 8.0    # saturation: a trail cannot outshout every alternative forever
const STRIDE: int = 3              # x, y, strength

# Vector2i -> PackedFloat32Array of triples. Packed, so a mark costs 12 bytes and no allocation.
var _cells: Dictionary = {}
var _count: int = 0

func _key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))

# Rubbed ground, where nothing sticks: Vector3(x, y, radius) each. Set by level.gd while an eraser
# rub is still fresh. Checked on every deposit, so it is kept to the handful actually live.
var clean_zones: Array = []

func deposit(p: Vector2, amount: float) -> void:
	if amount <= 0.0:
		return
	for z: Vector3 in clean_zones:
		if (p.x - z.x) * (p.x - z.x) + (p.y - z.y) * (p.y - z.y) <= z.z * z.z:
			return
	var k: Vector2i = _key(p)
	var arr: PackedFloat32Array = _cells.get(k, PackedFloat32Array())
	var mr2: float = MERGE_R * MERGE_R
	var i: int = 0
	while i < arr.size():
		var dx: float = arr[i] - p.x
		var dy: float = arr[i + 1] - p.y
		if dx * dx + dy * dy <= mr2:
			# Merging is what bounds the store. Without it a trail walked for ten minutes holds ten
			# minutes of marks; with it, a well-used trail holds a fixed number that simply grow
			# stronger -- which is also the behaviour wanted, since strength is the recruitment.
			arr[i + 2] = minf(arr[i + 2] + amount, MAX_STRENGTH)
			_cells[k] = arr
			return
		i += STRIDE
	arr.append(p.x)
	arr.append(p.y)
	arr.append(minf(amount, MAX_STRENGTH))
	_cells[k] = arr
	_count += 1

# The field at one point: a distance-weighted sum, so it varies continuously everywhere.
func sense(p: Vector2) -> float:
	var total: float = 0.0
	var k: Vector2i = _key(p)
	var r2: float = SENSE_R * SENSE_R
	for cy in range(k.y - 1, k.y + 2):
		for cx in range(k.x - 1, k.x + 2):
			var kk: Vector2i = Vector2i(cx, cy)
			if not _cells.has(kk):
				continue
			var arr: PackedFloat32Array = _cells[kk]
			var i: int = 0
			while i < arr.size():
				var dx: float = arr[i] - p.x
				var dy: float = arr[i + 1] - p.y
				var d2: float = dx * dx + dy * dy
				if d2 < r2:
					# Linear in distance, not in distance squared: a squared falloff makes the
					# field almost flat over most of the sensing disc, and a flat field carries no
					# gradient for the ant to read.
					total += arr[i + 2] * (1.0 - sqrt(d2) / SENSE_R)
				i += STRIDE
	return total

# Evaporation. Old marks fade and are dropped, so a route that stops being used stops existing --
# that is the half of the feedback loop that lets a SHORTER path win once both are known.
func evaporate(decay: float) -> void:
	var empties: Array = []
	for k: Vector2i in _cells:
		var arr: PackedFloat32Array = _cells[k]
		var kept: PackedFloat32Array = PackedFloat32Array()
		var i: int = 0
		while i < arr.size():
			var s: float = arr[i + 2] * decay
			if s > 0.02:
				kept.append(arr[i])
				kept.append(arr[i + 1])
				kept.append(s)
			else:
				_count -= 1
			i += STRIDE
		if kept.is_empty():
			empties.append(k)
		else:
			_cells[k] = kept
	for k: Vector2i in empties:
		_cells.erase(k)

# Drop every mark the predicate accepts. Used when an obstacle is dropped on a trail: the scent
# under a stone is under a stone, and leaving it there would have ants steering at a smell they
# can no longer reach.
func erase_if(pred: Callable) -> int:
	var gone: int = 0
	var empties: Array = []
	for k: Vector2i in _cells:
		var arr: PackedFloat32Array = _cells[k]
		var kept: PackedFloat32Array = PackedFloat32Array()
		var i: int = 0
		while i < arr.size():
			if pred.call(Vector2(arr[i], arr[i + 1])):
				gone += 1
				_count -= 1
			else:
				kept.append(arr[i])
				kept.append(arr[i + 1])
				kept.append(arr[i + 2])
			i += STRIDE
		if kept.is_empty():
			empties.append(k)
		else:
			_cells[k] = kept
	for k: Vector2i in empties:
		_cells.erase(k)
	return gone

# Read-only scan. Exists because the obvious way to ask this -- run erase_if with a predicate that
# sets a flag and returns false -- CANNOT WORK: a Godot lambda captures the value of a local, so
# the flag it sets is its own copy and the caller always reads false. Returning the answer instead
# of collecting it in a captured variable sidesteps the whole trap.
func any_where(pred: Callable) -> bool:
	for k: Vector2i in _cells:
		var arr: PackedFloat32Array = _cells[k]
		var i: int = 0
		while i < arr.size():
			if pred.call(Vector2(arr[i], arr[i + 1])):
				return true
			i += STRIDE
	return false

# Erase only where something is actually happening. erase_if walks EVERY cell of the field, which
# is right for a one-off (an obstacle dropped on a trail) and quite wrong ten times a second: a fan
# sitting on the board was rebuilding the colony's entire scent store at 10 Hz for the sake of the
# few cells under it.
func erase_near(centre: Vector2, radius: float, pred: Callable) -> int:
	var gone: int = 0
	var lo: Vector2i = _key(centre - Vector2.ONE * radius)
	var hi: Vector2i = _key(centre + Vector2.ONE * radius)
	var empties: Array = []
	for cy in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var k: Vector2i = Vector2i(cx, cy)
			if not _cells.has(k):
				continue
			var arr: PackedFloat32Array = _cells[k]
			var kept: PackedFloat32Array = PackedFloat32Array()
			var i: int = 0
			while i < arr.size():
				if pred.call(Vector2(arr[i], arr[i + 1])):
					gone += 1
					_count -= 1
				else:
					kept.append(arr[i])
					kept.append(arr[i + 1])
					kept.append(arr[i + 2])
				i += STRIDE
			if kept.is_empty():
				empties.append(k)
			else:
				_cells[k] = kept
	for k: Vector2i in empties:
		_cells.erase(k)
	return gone

# Weather over a patch of ground: everything here fades faster than elsewhere. Used by the fan,
# which used to ERASE what was under it outright -- and an outright erase cannot be argued with. A
# trail could never re-form through a fan however many ants walked it, because their deposits were
# wiped in the same tick they were laid, so the road was severed for as long as the thing sat there
# and the colony had no answer at all. Fading it fast leaves an answer: traffic. A road busy enough
# to be re-laid faster than it rots stays open, a thin one dies.
func scale_near(centre: Vector2, radius: float, factor: float, floor_at: float = 0.0) -> void:
	var lo: Vector2i = _key(centre - Vector2.ONE * radius)
	var hi: Vector2i = _key(centre + Vector2.ONE * radius)
	var r2: float = radius * radius
	var empties: Array = []
	for cy in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var k: Vector2i = Vector2i(cx, cy)
			if not _cells.has(k):
				continue
			var arr: PackedFloat32Array = _cells[k]
			var kept: PackedFloat32Array = PackedFloat32Array()
			var i: int = 0
			while i < arr.size():
				var v: float = arr[i + 2]
				var dx: float = arr[i] - centre.x
				var dy: float = arr[i + 1] - centre.y
				if dx * dx + dy * dy <= r2:
					# Thinned to a whisper, never rubbed out. A mark already below the floor is left
					# where it is; one above it is pushed down towards it and no further. That is
					# what makes a fan answerable: the road under it is always still faintly
					# followable, so the colony can work it back up, where an outright erase left it
					# nothing to work with at all.
					v = maxf(v * factor, minf(arr[i + 2], floor_at))
				if v > 0.02:
					kept.append(arr[i])
					kept.append(arr[i + 1])
					kept.append(v)
				else:
					_count -= 1
				i += STRIDE
			if kept.is_empty():
				empties.append(k)
			else:
				_cells[k] = kept
	for k: Vector2i in empties:
		_cells.erase(k)

func clear() -> void:
	_cells.clear()
	_count = 0

func count() -> int:
	return _count

# For drawing: every mark whose position falls inside `area`, as x, y, strength triples.
func marks_in(area: Rect2) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	var lo: Vector2i = _key(area.position)
	var hi: Vector2i = _key(area.position + area.size)
	for cy in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var kk: Vector2i = Vector2i(cx, cy)
			if _cells.has(kk):
				out.append_array(_cells[kk] as PackedFloat32Array)
	return out

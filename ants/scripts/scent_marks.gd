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
const MERGE_R: float = 6.0         # a new drop this close to an old one strengthens it instead
const MAX_STRENGTH: float = 8.0    # saturation: a trail cannot outshout every alternative forever
const STRIDE: int = 3              # x, y, strength

# Vector2i -> PackedFloat32Array of triples. Packed, so a mark costs 12 bytes and no allocation.
var _cells: Dictionary = {}
var _count: int = 0

func _key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))

func deposit(p: Vector2, amount: float) -> void:
	if amount <= 0.0:
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

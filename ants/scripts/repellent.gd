class_name Repellent
extends RefCounted

# The spray: ground the ants would rather not cross.
#
# Not an obstacle. An obstacle is a thing in a place, with an outline to feel your way around; this
# is a smell on the ground with no edge at all, and it FADES. An ant steers away from it in the same
# way it steers toward a trail -- by sampling ahead and turning down the gradient -- so a sprayed
# strip bends a column aside rather than stopping it, and stops bending it once the spray has gone.
#
# Same point-based store as ScentMarks and for the same reasons (see the note there): no grid, so
# nothing quantises, and the cost is what was actually sprayed rather than the size of the world.

const SENSE_R: float = 34.0            # a sprayed patch is smelled from further off than a trail
const CELL: float = SENSE_R
const MERGE_R: float = 12.0
const MAX_STRENGTH: float = 6.0
# ONE PRESS IS A PROPER SQUIRT. It began as a light puff meant to be pressed over and over, which
# needed a spray mode to be bearable; with the can back in the popup like every other tool, a press
# costs a trip through the menu and has to be worth one.
const PUFF: float = 11.0
const PUFF_SPREAD: float = 36.0
const PUFF_BLOBS: int = 9
const STRIDE: int = 3
# It goes off in about a minute and a half, which is long enough to matter for a while and short
# enough that spraying early is not the same as spraying at the right moment.
const DECAY: float = 0.9925            # per evaporation tick (10 Hz) -> about half gone in 90 s

var _cells: Dictionary = {}
var _count: int = 0

func _key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))

# One press of the can. A scatter rather than a dot, because a can sprays a patch.
func spray(at: Vector2) -> void:
	for i in PUFF_BLOBS:
		var a: float = randf_range(-PI, PI)
		var d: float = PUFF_SPREAD * sqrt(randf())
		_add(at + Vector2.from_angle(a) * d, PUFF)

func _add(p: Vector2, amount: float) -> void:
	var k: Vector2i = _key(p)
	var arr: PackedFloat32Array = _cells.get(k, PackedFloat32Array())
	var mr2: float = MERGE_R * MERGE_R
	var i: int = 0
	while i < arr.size():
		var dx: float = arr[i] - p.x
		var dy: float = arr[i + 1] - p.y
		if dx * dx + dy * dy <= mr2:
			arr[i + 2] = minf(arr[i + 2] + amount, MAX_STRENGTH)
			_cells[k] = arr
			return
		i += STRIDE
	arr.append(p.x)
	arr.append(p.y)
	arr.append(minf(amount, MAX_STRENGTH))
	_cells[k] = arr
	_count += 1

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
					total += arr[i + 2] * (1.0 - sqrt(d2) / SENSE_R)
				i += STRIDE
	return total

func fade() -> void:
	var empties: Array = []
	for k: Vector2i in _cells:
		var arr: PackedFloat32Array = _cells[k]
		var kept: PackedFloat32Array = PackedFloat32Array()
		var i: int = 0
		while i < arr.size():
			var v: float = arr[i + 2] * DECAY
			if v > 0.04:
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

func is_empty() -> bool:
	return _cells.is_empty()

func clear() -> void:
	_cells.clear()
	_count = 0

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

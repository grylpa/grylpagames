class_name AntGrid
extends RefCounted

# A uniform spatial hash over a SPARSE Dictionary, so the world may be 680x680 or 6800x6800 (or
# larger) at the same cost: what is stored is the ants, never the ground. An array-backed grid
# would have to allocate the whole world whether or not an ant ever walks there.
#
# It holds INDICES into the caller's own ant array, not the ants themselves. The caller rebuilds
# it once per tick -- every ant moves every tick, so incremental updates would cost more than the
# rebuild.

var cell: float = 12.0
var _cells: Dictionary = {}      # Vector2i -> PackedInt32Array of ant indices

func _init(cell_size: float) -> void:
	cell = cell_size

func key_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / cell), floori(p.y / cell))

func clear() -> void:
	_cells.clear()

func add(p: Vector2, idx: int) -> void:
	var k: Vector2i = key_of(p)
	# Packed arrays are copy-on-write values, not references: the fetched copy has to be assigned
	# back or the append is written to a temporary and lost.
	var arr: PackedInt32Array = _cells.get(k, PackedInt32Array())
	arr.append(idx)
	_cells[k] = arr

# Every index in the 3x3 block of cells around `p`. The caller still has to test real distance --
# a cell block is a square and the question is always about a circle.
func near(p: Vector2) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var k: Vector2i = key_of(p)
	for cy in range(k.y - 1, k.y + 2):
		for cx in range(k.x - 1, k.x + 2):
			var kk: Vector2i = Vector2i(cx, cy)
			if _cells.has(kk):
				out.append_array(_cells[kk] as PackedInt32Array)
	return out

func cell_count() -> int:
	return _cells.size()

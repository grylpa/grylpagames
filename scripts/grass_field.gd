extends RefCounted
class_name GrassField

# ONE lawn over the whole board — a real one, hundreds of thousands of blades, not a green fill with
# specks on it.
#
# What made the boards look tiled was never the background alone: every empty cell of the board
# carries its OWN 40x40 grass sprite, so the playfield is a mosaic of one image whatever the
# background does. The cells' sprites are hidden and this draws the field behind them in a single
# continuous pass — every blade positioned from its own place in the world, with no cell structure
# for the eye to find.
#
# **It is a MultiMesh, not `_draw` calls.** Grass has to be DENSE to read as grass: at one blade per
# 620 square units the field was 2% ink and looked like a flat green with a rash. A real lawn is
# ~60%, which is a quarter of a million blades on a board this size — far past what a canvas item's
# draw list will take, and one MultiMesh instance each is the only way to put them on screen. The
# whole field is one draw call.
#
# Four earlier attempts and why each failed, so none is tried again:
#
#   a drawn lawn on a SCREEN-sized layer   only visible before the board was built; the cells
#                                          covered it the moment they appeared
#   per-cell rotation and flips            the tile is SEAMLESS (its edges wrap), so turning cells
#                                          BREAKS the wrap and adds a grid of seams
#   per-cell brightness                    a lawn lit differently square by square
#   large soft patches                     read as blotches on a bare field, twice
#   small filled "tufts"                   the same mistake at a smaller size — a filled shape of a
#                                          different green is a patch whatever it is called, and a
#                                          thousand of them on a sparse field is a field of patches
#
# The only large-scale variation is a gradient stretched across the entire board, which is far too
# slow to show an edge on screen.

const DARK: Color = Color(0.0, 0.125, 0.047)
const MID: Color = Color(0.0, 0.208, 0.075)
const BLADE_LO: Color = Color(0.0, 0.267, 0.094)
const BLADE_HI: Color = Color(0.106, 0.514, 0.243)

# One blade per this many square units of board. 24 gives roughly 60% ink once the blades overlap,
# which is where a field stops reading as ground with grass on it and starts reading as grass.
const BLADE_AREA: float = 20.0
const MAX_BLADES: int = 320000
# Bigger blades rather than more of them: coverage is count x ink, and ink grows with the blade
# while the cost grows with the count. At 1.7 x 9 a quarter of a million blades still only inked
# 32% of the board and read as fuzz on green; at 2.2 x 12 the same count reaches ~66%, which is a
# lawn. A 12-unit blade against a 40-unit cell is about right for the scale the camera shows.
const BLADE_W: float = 2.2
const BLADE_LEN: float = 12.0

static func attach(parent: Node) -> Control:
	var bg: Control = parent.get_node_or_null("GrassField") as Control
	if bg == null:
		bg = Control.new()
		bg.name = "GrassField"
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_preset(Control.PRESET_TOP_LEFT)
		parent.add_child(bg)
		parent.move_child(bg, 0)
	return bg

# The ground under the blades. Drawn by the Control itself; the blades are a MultiMesh on top.
static func draw(bg: Control, _seed_i: int = 1) -> void:
	var w: float = bg.size.x
	var h: float = bg.size.y
	if w < 4.0 or h < 4.0:
		return
	bg.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([MID, MID.lerp(DARK, 0.4), DARK, MID.lerp(DARK, 0.55)]))

# Builds the blades. Call once, when the board's extent is known — it is the expensive part, and it
# belongs where the game already says "building board".
static func sow(bg: Control, seed_i: int = 1) -> void:
	var w: float = bg.size.x
	var h: float = bg.size.y
	if w < 4.0 or h < 4.0:
		return
	var mmi: MultiMeshInstance2D = bg.get_node_or_null("Blades") as MultiMeshInstance2D
	if mmi == null:
		mmi = MultiMeshInstance2D.new()
		mmi.name = "Blades"
		bg.add_child(mmi)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = _blade_mesh()
	var n: int = int(clampf(w * h / BLADE_AREA, 1000.0, float(MAX_BLADES)))
	mm.instance_count = n
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x9E3779B9 + seed_i * 2654435761
	for i in n:
		var p: Vector2 = Vector2(rng.randf() * w, rng.randf() * h)
		var lean: float = rng.randf_range(-0.5, 0.5)
		var s: float = rng.randf_range(0.55, 1.45)
		mm.set_instance_transform_2d(i, Transform2D(lean, Vector2(s, s), 0.0, p))
		# Darker at the root end of the range, brighter at the tip end, mixed per blade so the field
		# has depth rather than one flat green.
		mm.set_instance_color(i, BLADE_LO.lerp(BLADE_HI, rng.randf() * rng.randf()))
	mmi.multimesh = mm

# One blade: a taper from a base of BLADE_W to a point, with its origin AT THE BASE so an instance
# leans about the root rather than about its middle.
static func _blade_mesh() -> ArrayMesh:
	var verts: PackedVector2Array = PackedVector2Array([
		Vector2(-BLADE_W * 0.5, 0.0), Vector2(BLADE_W * 0.5, 0.0), Vector2(0.0, -BLADE_LEN)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

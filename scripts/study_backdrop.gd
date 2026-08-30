extends RefCounted
class_name StudyBackdrop

# The background for the four games that have no world in them: Witness (`ddooo`), Pinpoint
# (`didi`), Lineup (`ooo`) and Glimpse (`pop`). Nothing in these games stands on ground — a shape
# flashes and you answer — so they were showing a lawn for no reason at all.
#
# **The first rule here is UNIFORMITY, not decoration.** All four are perceptual tests, and two of
# them measure something that a background can quietly corrupt:
#
#   Pinpoint  flashes a dot toward one of EIGHT compass directions and asks which one it was. If the
#             background is brighter in some directions than others, the dot is easier to catch in
#             some directions than others, and the game is no longer measuring what it claims to.
#   Glimpse   is Lineup played at the edge of vision. Anything with structure out there competes
#             with the thing the player is trying to catch out there.
#
# So there is no vignette, no vertical gradient, no pattern, no motion, and nothing bright. What
# variation there is, is RADIALLY SYMMETRIC — identical in every direction from the board's centre —
# and small enough to measure: the centre lift is 5% alpha of a tone one step off the base, and the
# dust is 4-9% alpha. A shape at the same radius is equally visible whichever way it went.
#
# Not flat, though. A single flat fill is what these screens would look like with the lawn simply
# deleted, and it reads as a missing asset. The surface here is a deep base, a very shallow lift
# toward the centre, and a fine untiled dust of specks in two tones — a matte, papery ground rather
# than a colour. The dust is a MultiMesh for the same reason the lawn is (scripts/grass_field.gd):
# tens of thousands of specks, one draw call, no repeat anywhere in the field.

# One family, four hues, all deep and low-chroma so the games' own coloured shapes stay the
# brightest thing on the screen by a wide margin.
const WITNESS: Color = Color(0.086, 0.094, 0.180)
const PINPOINT: Color = Color(0.075, 0.114, 0.161)
const LINEUP: Color = Color(0.063, 0.133, 0.125)
const GLIMPSE: Color = Color(0.129, 0.082, 0.157)

# The centre lift, as alpha over the base. Radially symmetric and deliberately tiny — see above.
const LIFT_ALPHA: float = 0.05
const LIFT_STEPS: int = 48

# One speck per this many square units. This has to be DENSE to read as a surface: the same lesson
# the lawn taught (scripts/grass_field.gd), where one blade per 620 units came out 2% ink and looked
# like a flat green with a rash. At one speck per 12 units the field is ~25% ink, which at 4-9% alpha
# is fine grain — a matte, papery ground — rather than visible dots. Sparse dust is just a flat fill
# with a rash on it, and a flat fill is what these screens would look like with the lawn deleted.
const DUST_AREA: float = 12.0
const MAX_DUST: int = 200000
const DUST_SIZE: float = 1.6
const DUST_LO_ALPHA: float = 0.04
const DUST_HI_ALPHA: float = 0.09

# The whole installation, in the shape GrassField.fit() already established so the two read the
# same at the call site: hide the ground being replaced, attach behind everything, size to the
# board plus a margin merged with the full canvas, and populate — only when the rect changed.
static func fit(parent: Node, tiled_ground: CanvasItem, game, base: Color, seed_i: int = 1) -> Control:
	if game == null or parent == null:
		return null
	var f: Control = attach(parent)
	if f.draw.get_connections().is_empty():
		f.draw.connect(func() -> void: draw(f, base))
	var m: float = game.tile_size * 4.0
	var r: Rect2 = Rect2(game.board_to_px(Vector2i(0, 0)) - Vector2(m, m),
		game.board_to_px(game.board_size) - game.board_to_px(Vector2i(0, 0)) + Vector2(m, m) * 2.0)
	# These games' cameras ZOOM IN (`create_camera` at 1..2x), so the visible world is smaller than
	# the canvas — but the canvas is still the floor for how far the backdrop must reach, exactly as
	# the anchored TextureRect it replaces did.
	r = r.merge(Rect2(Vector2.ZERO, Vector2(MainGlobals.full_screen_size)))
	var tl: Vector2 = r.position
	var want: Vector2 = r.size
	# Called from _ready too, where the board may not be sized yet. Nothing to draw then, and the
	# ground being replaced has to stay up: hiding it and THEN bailing leaves a bare screen.
	if want.x < 4.0 or want.y < 4.0:
		return f
	if tiled_ground != null and is_instance_valid(tiled_ground):
		tiled_ground.hide()
	if f.position == tl and f.size == want:
		return f
	f.position = tl
	f.size = want
	f.queue_redraw()
	dust(f, base, seed_i)
	return f

static func attach(parent: Node) -> Control:
	var bg: Control = parent.get_node_or_null("StudyBackdrop") as Control
	if bg == null:
		bg = Control.new()
		bg.name = "StudyBackdrop"
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_preset(Control.PRESET_TOP_LEFT)
		parent.add_child(bg)
		parent.move_child(bg, 0)
	return bg

# The base and the centre lift. The lift is a triangle FAN — one mesh, colour interpolated from the
# centre outward — rather than concentric rings, which band visibly at this little contrast.
static func draw(bg: Control, base: Color) -> void:
	var w: float = bg.size.x
	var h: float = bg.size.y
	if w < 4.0 or h < 4.0:
		return
	bg.draw_rect(Rect2(0.0, 0.0, w, h), base)
	# The mesh is KEPT ALIVE on the node, not built inline into the draw call.
	#
	# draw_mesh() records the mesh in the canvas item's draw list, but the Ref lived only for the
	# duration of draw() — so the ArrayMesh was freed the moment the function returned while the
	# recorded command still pointed at it. On the GLES3 renderer that surfaced as
	# "mesh_get_surface_count: Parameter mesh is null" on a device; the headless renderer is a dummy
	# and never asks, which is why no probe here could have caught it.
	#
	# Stashing it also stops an ArrayMesh being rebuilt on every single redraw.
	var key: String = "%.1fx%.1f|%s" % [w, h, str(base)]
	if bg.get_meta("lift_key", "") != key:
		bg.set_meta("lift_mesh", _lift_mesh(Vector2(w, h), base))
		bg.set_meta("lift_key", key)
	var lift: ArrayMesh = bg.get_meta("lift_mesh") as ArrayMesh
	if lift != null:
		bg.draw_mesh(lift, null)

# A tone one step off the base, faded to nothing at the rim. Radius reaches the corners, so the fan
# covers the rect; the spill past the edges lands on nothing, since this is the bottom-most node.
static func _lift_mesh(size: Vector2, base: Color) -> ArrayMesh:
	var c: Vector2 = size * 0.5
	var radius: float = size.length() * 0.5
	var lift: Color = base.lerp(Color(0.75, 0.80, 0.95), 0.5)
	var inner: Color = Color(lift.r, lift.g, lift.b, LIFT_ALPHA)
	var outer: Color = Color(lift.r, lift.g, lift.b, 0.0)
	var verts: PackedVector2Array = PackedVector2Array()
	var cols: PackedColorArray = PackedColorArray()
	for i in LIFT_STEPS:
		var a0: float = TAU * float(i) / float(LIFT_STEPS)
		var a1: float = TAU * float(i + 1) / float(LIFT_STEPS)
		verts.append(c)
		cols.append(inner)
		verts.append(c + Vector2(cos(a0), sin(a0)) * radius)
		cols.append(outer)
		verts.append(c + Vector2(cos(a1), sin(a1)) * radius)
		cols.append(outer)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# The dust. Positions are drawn from the whole field at once, so there is no cell, tile or block
# anywhere in it — the mistake the lawn went through four times before it was fixed.
static func dust(bg: Control, base: Color, seed_i: int = 1) -> void:
	var w: float = bg.size.x
	var h: float = bg.size.y
	if w < 4.0 or h < 4.0:
		return
	var mmi: MultiMeshInstance2D = bg.get_node_or_null("Dust") as MultiMeshInstance2D
	if mmi == null:
		mmi = MultiMeshInstance2D.new()
		mmi.name = "Dust"
		bg.add_child(mmi)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = _speck_mesh()
	var n: int = int(clampf(w * h / DUST_AREA, 500.0, float(MAX_DUST)))
	mm.instance_count = n
	var lo: Color = base.darkened(0.45)
	var hi: Color = base.lerp(Color(0.85, 0.88, 1.0), 0.55)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 0x9E3779B9 + seed_i * 2654435761
	for i in n:
		var p: Vector2 = Vector2(rng.randf() * w, rng.randf() * h)
		var s: float = rng.randf_range(0.6, 1.5)
		mm.set_instance_transform_2d(i, Transform2D(rng.randf() * TAU, Vector2(s, s), 0.0, p))
		# Both tones, so the surface has grain rather than only sparkle.
		var up: bool = rng.randf() < 0.5
		var col: Color = hi if up else lo
		mm.set_instance_color(i, Color(col.r, col.g, col.b,
			rng.randf_range(DUST_LO_ALPHA, DUST_HI_ALPHA)))
	mmi.multimesh = mm

static func _speck_mesh() -> ArrayMesh:
	var d: float = DUST_SIZE * 0.5
	var verts: PackedVector2Array = PackedVector2Array([
		Vector2(-d, -d), Vector2(d, -d), Vector2(d, d),
		Vector2(-d, -d), Vector2(d, d), Vector2(-d, d)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

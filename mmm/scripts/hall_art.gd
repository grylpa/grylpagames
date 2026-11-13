extends RefCounted
class_name MmmHallArt

# THE GREAT HALL'S STANDING PIECES AS REAL 3-D (2026-11-12): a fluted marble COLUMN, a two-tier marble
# FOUNTAIN with water falling from the upper bowl, and a clipped TOPIARY (a leafy ball on a stem in a
# stone planter). Modelled here, lit like the hall (a warm key from the top left), seen from a high
# three-quarter angle -- straight from above a column is a circle and a tree a disc. (Their shadows on
# the floor are drawn in 2-D by hall_decor.gd.) Rendered ONCE (all three, at the first need) into textures; texture() is
# null until they exist, and the caller draws nothing that frame. Drawn flat code shapes were the first
# try: "very very sloppy".
#
# One world unit here is one board cell. Each texture is centered on the piece's GROUND point, so a
# sprite drawn centered at the footprint's middle stands where it should.

enum Kind { COLUMN, FOUNTAIN, TOPIARY }

const PX_PER_CELL: float = 96.0           # render resolution (the game draws a cell 40 units: sharp when zoomed in)
const PITCH_DEG: float = 58.0             # the camera's look down from the horizontal
# per kind: the camera's view in cells (width, height), around the ground point
const VIEW: Array = [Vector2(1.8, 7.0), Vector2(3.6, 5.0), Vector2(2.2, 5.4)]

static var _tex: Dictionary = {}          # kind -> Texture2D; the key exists (null) while rendering
static var _busy: bool = false


static func texture(host: Node, kind: int) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	if not _busy and host.is_inside_tree():
		_busy = true
		var rn: _Renderer = _Renderer.new()
		host.get_tree().root.add_child.call_deferred(rn)
	return null


# the drawn size of a piece's texture, in game units (a cell is 40)
static func view_size(kind: int) -> Vector2:
	return (VIEW[kind] as Vector2) * 40.0


class _Renderer extends Node:
	func _ready() -> void:
		for kind in [MmmHallArt.Kind.COLUMN, MmmHallArt.Kind.FOUNTAIN, MmmHallArt.Kind.TOPIARY]:
			var tex: Texture2D = await _render(kind)
			if not is_inside_tree():
				MmmHallArt._busy = false
				return
			MmmHallArt._tex[kind] = tex
		MmmHallArt._busy = false
		queue_free()

	func _render(kind: int) -> Texture2D:
		var view: Vector2 = MmmHallArt.VIEW[kind]
		var vp: SubViewport = SubViewport.new()
		vp.size = Vector2i(int(view.x * MmmHallArt.PX_PER_CELL), int(view.y * MmmHallArt.PX_PER_CELL))
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(vp)
		var env: WorldEnvironment = WorldEnvironment.new()
		var e: Environment = Environment.new()
		e.background_mode = Environment.BG_CLEAR_COLOR
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.50, 0.48, 0.58)
		e.ambient_light_energy = 0.30
		e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.environment = e
		vp.add_child(env)
		var key: DirectionalLight3D = DirectionalLight3D.new()
		# warm, steeply from above and the left: faces turned up clearly brighter than faces turned to the
		# viewer, so a block reads as a block
		key.rotation_degrees = Vector3(-66.0, -62.0, 0.0)
		key.light_color = Color(1.0, 0.88, 0.68)
		key.light_energy = 0.85
		vp.add_child(key)
		var fill: DirectionalLight3D = DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(-20.0, 140.0, 0.0)          # a cool fill from behind
		fill.light_color = Color(0.55, 0.62, 0.85)
		fill.light_energy = 0.22
		vp.add_child(fill)
		var cam: Camera3D = Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.size = view.y
		var p: float = deg_to_rad(MmmHallArt.PITCH_DEG)
		cam.position = Vector3(0.0, sin(p), cos(p)) * 40.0
		vp.add_child(cam)
		cam.look_at(Vector3.ZERO)
		# (no floor: the compatibility renderer cannot cast onto a see-through one; hall_decor.gd draws
		# each piece's shadow in 2-D)
		match kind:
			MmmHallArt.Kind.COLUMN:
				_column(vp)
			MmmHallArt.Kind.FOUNTAIN:
				_fountain(vp)
			_:
				_topiary(vp)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img: Image = vp.get_texture().get_image()
		vp.queue_free()
		img.generate_mipmaps()
		return ImageTexture.create_from_image(img)

	# --- materials ---
	func _marble(tone: Color = Color(0.72, 0.70, 0.66)) -> StandardMaterial3D:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = tone
		m.roughness = 0.38
		m.metallic_specular = 0.45
		return m

	func _gold() -> StandardMaterial3D:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = Color(0.86, 0.66, 0.28)
		m.metallic = 0.85
		m.roughness = 0.30
		return m

	func _water() -> StandardMaterial3D:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = Color(0.07, 0.24, 0.30)
		m.roughness = 0.05
		m.metallic = 0.25
		m.metallic_specular = 1.0
		return m

	func _add(vp: SubViewport, mesh: Mesh, mat: Material, at: Vector3 = Vector3.ZERO) -> void:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mesh
		if mat is BaseMaterial3D:
			(mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat
		mi.position = at
		vp.add_child(mi)

	func _box(vp: SubViewport, box_size: Vector3, at: Vector3, mat: Material) -> void:
		var bm: BoxMesh = BoxMesh.new()
		bm.size = box_size
		_add(vp, bm, mat, at)

	# A surface of revolution from `prof` (radius, height) bottom to top, `seg` segments round; `flute`
	# fluting depth (as a share of the radius) and how many flutes.
	func _lathe(prof: Array, flute: float = 0.0, flutes: float = 1.0, seg: int = 64) -> Mesh:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in prof.size() - 1:
			var a: Vector2 = prof[i]
			var b: Vector2 = prof[i + 1]
			for k in seg:
				var t0: float = TAU * float(k) / float(seg)
				var t1: float = TAU * float(k + 1) / float(seg)
				var pts: Array = []
				for c: Array in [[a, t0], [a, t1], [b, t1], [b, t0]]:
					var pr: Vector2 = c[0]
					var ang: float = c[1]
					var r: float = pr.x * (1.0 - flute * absf(sin(ang * flutes * 0.5)))
					pts.append(Vector3(cos(ang) * r, pr.y, sin(ang) * r))
				for idx in [0, 2, 1, 0, 3, 2]:
					st.add_vertex(pts[idx])
		st.generate_normals()
		return st.commit()

	# --- a fluted column on a square plinth, an Attic base below, a Tuscan capital above ---
	func _column(vp: SubViewport) -> void:
		var mb: StandardMaterial3D = _marble()
		_box(vp, Vector3(0.62, 0.14, 0.62), Vector3(0, 0.07, 0), _marble(Color(0.62, 0.60, 0.57)))
		_add(vp, _lathe([Vector2(0.28, 0.14), Vector2(0.28, 0.20), Vector2(0.24, 0.25), Vector2(0.26, 0.30), Vector2(0.21, 0.35), Vector2(0.20, 0.38)]), mb)
		_add(vp, _lathe([Vector2(0.20, 0.38), Vector2(0.17, 2.90)], 0.10, 20.0), mb)
		# the capital, Tuscan: a gold ring at the neck, a rounded flare (the echinus) and a THIN square
		# abacus only a little wider than the shaft. (Ionic volutes stuck out like ears, and a big abacus
		# read from above as a pale lid: "a wrong and strange top".)
		_add(vp, _lathe([Vector2(0.185, 2.86), Vector2(0.185, 2.92)]), _gold())
		_add(vp, _lathe([Vector2(0.17, 2.92), Vector2(0.19, 2.96), Vector2(0.23, 3.00), Vector2(0.25, 3.04), Vector2(0.25, 3.06)]), mb)
		# a ROUND abacus: a short disc a little wider than the flare, its top face closed. (A square one
		# showed its top and front in the same tone -- "a flat rectangle that doesn't fit".)
		_add(vp, _lathe([Vector2(0.24, 3.06), Vector2(0.245, 3.065), Vector2(0.245, 3.10), Vector2(0.23, 3.11), Vector2(0.0, 3.11)]), mb)
		# crowned with a small gold ball on a short neck (a free-standing column carries something; a
		# bare wide disc made it a mushroom)
		_add(vp, _lathe([Vector2(0.07, 3.11), Vector2(0.05, 3.16), Vector2(0.06, 3.18)]), _gold())
		var ball: SphereMesh = SphereMesh.new()
		ball.radius = 0.10
		ball.height = 0.20
		_add(vp, ball, _gold(), Vector3(0, 3.27, 0))


	# --- a round basin on a molded foot, water in it; a stem up the middle to a smaller bowl, water
	# in that too, falling over its lip in a sheet into the basin ---
	func _fountain(vp: SubViewport) -> void:
		var mb: StandardMaterial3D = _marble()
		_add(vp, _lathe([Vector2(0.0, 0.0), Vector2(1.42, 0.0), Vector2(1.42, 0.06), Vector2(1.36, 0.10), Vector2(1.36, 0.36),
			Vector2(1.46, 0.40), Vector2(1.46, 0.48), Vector2(1.30, 0.50), Vector2(1.28, 0.30), Vector2(0.0, 0.30)]), mb)
		_add(vp, _lathe([Vector2(0.0, 0.40), Vector2(1.29, 0.40)], 0.0, 1.0, 64), _water())
		_add(vp, _lathe([Vector2(0.24, 0.40), Vector2(0.20, 0.55), Vector2(0.13, 0.70), Vector2(0.12, 1.10), Vector2(0.18, 1.20)]), mb)
		_add(vp, _lathe([Vector2(0.18, 1.20), Vector2(0.50, 1.30), Vector2(0.64, 1.42), Vector2(0.66, 1.48), Vector2(0.58, 1.48), Vector2(0.0, 1.38)]), mb)
		_add(vp, _lathe([Vector2(0.0, 1.44), Vector2(0.58, 1.44)]), _water())
		_add(vp, _lathe([Vector2(0.06, 1.44), Vector2(0.05, 1.62), Vector2(0.09, 1.66), Vector2(0.0, 1.70)]), _gold())
		# the falling sheet: a thin translucent skirt from the bowl's lip down to the basin's water
		var fm: StandardMaterial3D = StandardMaterial3D.new()
		fm.albedo_color = Color(0.80, 0.92, 1.0, 0.42)
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.roughness = 0.1
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		_add(vp, _lathe([Vector2(0.67, 1.46), Vector2(0.74, 1.10), Vector2(0.80, 0.70), Vector2(0.84, 0.41)], 0.06, 18.0), fm)
		# the jet from the spout, falling back into the bowl
		_add(vp, _lathe([Vector2(0.02, 1.70), Vector2(0.06, 1.95), Vector2(0.14, 2.02), Vector2(0.30, 1.85), Vector2(0.42, 1.50)], 0.0, 1.0, 32), fm)

	# --- a clipped palace topiary: a square stone planter with a gold band, a dark trunk, and the crown
	# clipped into a ball, its surface broken into leaf clumps ---
	func _topiary(vp: SubViewport) -> void:
		var stone: StandardMaterial3D = _marble(Color(0.78, 0.76, 0.72))
		_box(vp, Vector3(0.80, 0.62, 0.80), Vector3(0, 0.31, 0), stone)
		_box(vp, Vector3(0.90, 0.10, 0.90), Vector3(0, 0.65, 0), stone)
		_box(vp, Vector3(0.82, 0.06, 0.82), Vector3(0, 0.50, 0), _gold())
		var soil: StandardMaterial3D = StandardMaterial3D.new()
		soil.albedo_color = Color(0.18, 0.12, 0.08)
		_box(vp, Vector3(0.70, 0.02, 0.70), Vector3(0, 0.70, 0), soil)
		var bark: StandardMaterial3D = StandardMaterial3D.new()
		bark.albedo_color = Color(0.30, 0.20, 0.12)
		bark.roughness = 0.9
		_add(vp, _lathe([Vector2(0.06, 0.70), Vector2(0.05, 1.60)], 0.0, 1.0, 16), bark)
		_add(vp, _leaf_ball(0.62, 7), _leaves(), Vector3(0, 2.05, 0))

	func _leaves() -> StandardMaterial3D:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color(1, 1, 1)
		m.roughness = 0.85
		return m

	# a sphere whose surface is pushed in and out by layered noise into leaf clumps, darker in the hollows
	func _leaf_ball(r: float, sd: int) -> Mesh:
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = 64
		sm.rings = 32
		var arr: Array = sm.get_mesh_arrays()
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var nz: FastNoiseLite = FastNoiseLite.new()
		nz.seed = sd
		nz.frequency = 3.2
		nz.fractal_octaves = 3
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var moved: PackedVector3Array = PackedVector3Array()
		var cols: PackedColorArray = PackedColorArray()
		for v in verts:
			var n: float = nz.get_noise_3dv(v / r)
			var leaf: float = nz.get_noise_3dv(v / r * 4.0) * 0.4
			var d: float = 1.0 + 0.14 * n + 0.05 * leaf
			moved.append(v * d)
			var t: float = clampf(0.5 + n * 1.2 + leaf * 0.6, 0.0, 1.0)
			cols.append(Color(0.10, 0.26, 0.10).lerp(Color(0.34, 0.58, 0.24), t))
		for i in idx:
			st.set_color(cols[i])
			st.add_vertex(moved[i])
		st.generate_normals()
		return st.commit()

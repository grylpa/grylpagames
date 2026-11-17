extends "res://scripts/menu_poster.gd"

# A MENU POSTER IN REAL 3-D (over the shared scripts/menu_poster.gd). Hand-drawn polygon "3-D" kept coming out
# "cartoon", "flat", "so bad" (the user, 2026-11-17); a poster built on this is a small 3-D world the engine renders:
#  - THE WORLD STANDS AT 1:100 under `root` (scaled 0.01; the camera at eye * 0.01): the engine's lights fall off
#    with the square of the distance in METRES, and at the posters' scale of hundreds of units a light lit nothing.
#    Light ranges are in metres -- `light()` takes them in units and converts.
#  - WHAT NEVER MOVES IS A PICTURE shipped with the game: devtools/make_menu_bake.gd sets `bake_mode` and renders the
#    still scene (`_build_still`) at twice the size into `_baked_path()` (BAKE_W x BAKE_H, centered on BAKE_CY; the
#    layouts only slide it up or down). At run time the picture is drawn at once and a SEE-THROUGH live view over it
#    holds only what moves and what can stand in front of it (`_build_live`), lit by the same lights (`_build_lights`).
#    Without the picture (before the first bake) everything is built live.
#  - A see-through view cannot ADD light (it comes out black): light on baked surfaces is a translucent patch.
#  - Hand-built meshes are drawn on both faces (their winding is not checked).
# A subclass gives its camera (`_eye`, `_aim`, `_fov`), where its center sits (`_frame_frac`), and fills in the
# builders and `_animate(delta)`.

const BAKE_W: int = 680
const BAKE_H: int = 1500
const BAKE_CY: float = 750.0

var root: Node3D = null              # the scene, at 1:100
var _live_only: bool = false
var _bg_tex: Texture2D = null
var _bg_layer: Control = null
var _vpc: SubViewportContainer = null
var _vp3: SubViewport = null
var _cy3: float = 0.0
var _bottom3: float = -2.0

# --- for the poster to fill in -----------------------------------------------------------------------------

func _baked_path() -> String:
	return ""

func _eye() -> Vector3:
	return Vector3(0, 100, 400)

func _aim() -> Vector3:
	return Vector3.ZERO

func _fov() -> float:
	return 50.0                    # horizontal (the width is kept)

func _frame_frac() -> float:
	return 0.5                     # where between the title's foot and the panel the scene's center sits

func _environment(env: Environment) -> void:
	env.background_color = Color(0.03, 0.04, 0.09)
	env.ambient_light_color = Color(0.40, 0.42, 0.55)
	env.ambient_light_energy = 0.3

func _build_lights() -> void:
	pass

func _build_still() -> void:
	pass

func _build_live() -> void:
	pass

func _animate(_delta: float) -> void:
	pass

# --- the machinery ---------------------------------------------------------------------------------------------

func _setup() -> void:
	var path: String = _baked_path()
	_live_only = not bake_mode and path != "" and ResourceLoader.exists(path)
	if _live_only:
		_bg_tex = load(path)
		_bg_layer = Control.new()
		_bg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_bg_layer.draw.connect(func() -> void: _bg_layer.draw_texture(_bg_tex, Vector2(0.0, _cy3 - BAKE_CY)))
		add_child(_bg_layer)
	_vp3 = SubViewport.new()
	_vp3.own_world_3d = true
	_vp3.msaa_3d = Viewport.MSAA_8X if bake_mode else Viewport.MSAA_4X
	_vp3.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if bake_mode:
		_vp3.size = Vector2i(BAKE_W * 2, BAKE_H * 2)
		add_child(_vp3)
		var pic: Control = Control.new()
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.draw.connect(func() -> void: pic.draw_texture_rect(_vp3.get_texture(), Rect2(0, 0, BAKE_W, BAKE_H), false))
		add_child(pic)
		pic.size = Vector2(BAKE_W, BAKE_H)
	else:
		_vpc = SubViewportContainer.new()
		_vpc.stretch = true
		_vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_vpc)
		_vp3.transparent_bg = _live_only
		_vpc.add_child(_vp3)
	var world: Node3D = Node3D.new()
	_vp3.add_child(world)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment(env)
	if _live_only:
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.glow_enabled = false
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var cam: Camera3D = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = _fov()
	cam.near = 0.05
	cam.far = 60.0
	world.add_child(cam)
	cam.look_at_from_position(_eye() * 0.01, _aim() * 0.01, Vector3.UP)
	cam.current = true
	root = Node3D.new()
	world.add_child(root)
	root.scale = Vector3.ONE * 0.01
	_build_lights()
	if not _live_only:
		_build_still()
	if not bake_mode:
		_build_live()

# a live view renders only while the poster is on screen (it rendered on behind the game)
func _shown_changed(shown: bool) -> void:
	if _vp3 != null and not bake_mode:
		_vp3.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED

func _tick(delta: float) -> void:
	if bake_mode:
		return
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	if absf(scene_bottom - _bottom3) > 0.5:
		_bottom3 = scene_bottom
		var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
		var top: float = 230.0 if mobile else 150.0
		_cy3 = top + (bottom - top) * _frame_frac()
		var half_h: float = maxf(_cy3, full.y - _cy3)
		_vpc.position = Vector2(0.0, _cy3 - half_h)
		_vpc.size = Vector2(full.x, half_h * 2.0)
		if _bg_layer != null:
			_bg_layer.queue_redraw()
	_animate(delta)

# --- builders ----------------------------------------------------------------------------------------------------

func mat(col: Color, rough: float = 0.8, metal: float = 0.0, tex: Texture2D = null, uv: Vector3 = Vector3.ONE) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col if tex == null else Color(1, 1, 1, col.a)
	m.roughness = rough
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if tex != null:
		m.albedo_texture = tex
		m.uv1_scale = uv
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

# something that gives light: unshaded, in its own color
func glow(col: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func put(mesh: Mesh, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	(parent if parent != null else root).add_child(mi)
	mi.position = pos
	mi.rotation_degrees = rot
	return mi

func box(sz: Vector3, m: Material, center: Vector3, rot: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = sz
	return put(bm, m, center, rot, parent)

func cyl(r_top: float, r_bot: float, h: float, m: Material, center: Vector3, rot: Vector3 = Vector3.ZERO, parent: Node3D = null, segs: int = 32) -> MeshInstance3D:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	return put(cm, m, center, rot, parent)

func sphere(r: float, m: Material, center: Vector3, parent: Node3D = null, hemi: bool = false) -> MeshInstance3D:
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = r
	sm.height = r if hemi else r * 2.0
	sm.is_hemisphere = hemi
	sm.radial_segments = 32
	sm.rings = 16
	return put(sm, m, center, Vector3.ZERO, parent)

# a light at pos (units), its range in units (converted to metres)
func light(pos: Vector3, col: Color, energy: float, range_units: float, shadow: bool = false, parent: Node3D = null) -> OmniLight3D:
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = range_units * 0.01
	l.shadow_enabled = shadow
	(parent if parent != null else root).add_child(l)
	l.position = pos
	return l

func spot(pos: Vector3, aim_at: Vector3, col: Color, energy: float, range_units: float, angle: float, shadow: bool = false) -> SpotLight3D:
	var l: SpotLight3D = SpotLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.spot_range = range_units * 0.01
	l.spot_angle = angle
	l.shadow_enabled = shadow
	root.add_child(l)
	l.look_at_from_position(pos, aim_at, Vector3.UP if absf((aim_at - pos).normalized().y) < 0.99 else Vector3.FORWARD)
	return l

func label(txt: String, size_units: float, col: Color, pos: Vector3, rot: Vector3 = Vector3.ZERO, parent: Node3D = null, lit: bool = false) -> Label3D:
	var lb: Label3D = Label3D.new()
	lb.text = txt
	lb.font = MainGlobals.get_text_font()
	lb.font_size = 128
	lb.pixel_size = size_units / 128.0
	lb.modulate = col
	lb.shaded = lit
	lb.outline_size = 0
	lb.double_sided = true
	(parent if parent != null else root).add_child(lb)
	lb.position = pos
	lb.rotation_degrees = rot
	return lb

# a picture made in code: a base color, specks, and optional joints every n/joints texels
func tex_speckle(n: int, base: Color, speck: float, seed_i: int, joints: int = 0, joint_col: Color = Color.BLACK) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	img.fill(base)
	for k in n * n / 5:
		var v: float = (h01(seed_i * 100003 + k * 3) - 0.5) * speck
		var x: int = int(h01(seed_i * 100003 + k * 3 + 1) * float(n - 1))
		var y: int = int(h01(seed_i * 100003 + k * 3 + 2) * float(n - 1))
		var c: Color = img.get_pixel(x, y)
		img.set_pixel(x, y, Color(clampf(c.r + v, 0, 1), clampf(c.g + v, 0, 1), clampf(c.b + v, 0, 1)))
	if joints > 0:
		var step: int = n / joints
		for k2 in joints:
			img.fill_rect(Rect2i(k2 * step, 0, 1, n), joint_col)
			img.fill_rect(Rect2i(0, k2 * step, n, 1), joint_col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# wood: long grain along x, darker streaks and a ring or two
func tex_wood(n: int, base: Color, seed_i: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		var band: float = 0.5 + 0.5 * sin(float(y) * 0.35 + 3.0 * sin(float(y) * 0.05 + float(seed_i)))
		for x in n:
			var wob: float = 0.06 * sin(float(x) * 0.02 + float(y) * 0.11 + float(seed_i))
			var k: float = 0.82 + 0.18 * band + wob + (h01(seed_i * 7919 + y * n + x) - 0.5) * 0.06
			img.set_pixel(x, y, Color(base.r * k, base.g * k, base.b * k))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# A ROUNDED BOX standing on its foot: a rounded-rectangle section (half sizes hx, hz, corner radius r) swept up h,
# the top edge bevelled, smooth normals all round
func rbox_mesh(hx: float, hz: float, h: float, r: float, bev: float) -> ArrayMesh:
	var ring: Array = []
	var corners: Array = [Vector2(hx - r, hz - r), Vector2(-(hx - r), hz - r), Vector2(-(hx - r), -(hz - r)), Vector2(hx - r, -(hz - r))]
	for ci in 4:
		for k in 7:
			var a: float = PI * 0.5 * float(ci) + PI * 0.5 * float(k) / 6.0
			var nrm: Vector2 = Vector2(cos(a), sin(a))
			ring.append([Vector2(corners[ci]) + nrm * r, nrm])
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = ring.size()
	var top_y: float = h - bev
	for i in n:
		var j: int = (i + 1) % n
		var pa: Vector2 = ring[i][0]
		var pb: Vector2 = ring[j][0]
		var na: Vector3 = Vector3(Vector2(ring[i][1]).x, 0.0, Vector2(ring[i][1]).y)
		var nb: Vector3 = Vector3(Vector2(ring[j][1]).x, 0.0, Vector2(ring[j][1]).y)
		var a0: Vector3 = Vector3(pa.x, 0.0, pa.y)
		var b0: Vector3 = Vector3(pb.x, 0.0, pb.y)
		var a1: Vector3 = Vector3(pa.x, top_y, pa.y)
		var b1: Vector3 = Vector3(pb.x, top_y, pb.y)
		for v in [[a0, na], [a1, na], [b1, nb], [a0, na], [b1, nb], [b0, nb]]:
			_sv(st, v[0], v[1])
		var ia: Vector3 = Vector3(pa.x - na.x * bev, h, pa.y - na.z * bev)
		var ib: Vector3 = Vector3(pb.x - nb.x * bev, h, pb.y - nb.z * bev)
		var ma: Vector3 = (na + Vector3.UP).normalized()
		var mb: Vector3 = (nb + Vector3.UP).normalized()
		for v2 in [[a1, na], [ia, ma], [ib, mb], [a1, na], [ib, mb], [b1, nb]]:
			_sv(st, v2[0], v2[1])
		for v3 in [[Vector3(0.0, h, 0.0), Vector3.UP], [ib, Vector3.UP], [ia, Vector3.UP]]:
			_sv(st, v3[0], v3[1])
	return st.commit()

func _sv(st: SurfaceTool, p: Vector3, n: Vector3) -> void:
	st.set_normal(n)
	st.add_vertex(p)

# a smooth tube of radius r along a path
func tube_mesh(path: PackedVector3Array, r: float, sides: int) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for i in path.size():
		var tg: Vector3 = (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var side: Vector3 = tg.cross(Vector3.UP)
		if side.length() < 0.1:
			side = tg.cross(Vector3.RIGHT)
		side = side.normalized()
		var up2: Vector3 = side.cross(tg).normalized()
		var ring: Array = []
		for k in sides:
			var a: float = TAU * float(k) / float(sides)
			var nrm: Vector3 = side * cos(a) + up2 * sin(a)
			ring.append([path[i] + nrm * r, nrm])
		rings.append(ring)
	for i in rings.size() - 1:
		for k in sides:
			var k2: int = (k + 1) % sides
			for v in [rings[i][k], rings[i + 1][k], rings[i + 1][k2], rings[i][k], rings[i + 1][k2], rings[i][k2]]:
				_sv(st, v[0], v[1])
	return st.commit()

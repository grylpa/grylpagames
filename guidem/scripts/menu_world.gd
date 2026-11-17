extends "res://scripts/menu_poster.gd"

# VALET'S OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): THE FORECOURT OF A GRAND HOTEL AT
# NIGHT -- in REAL 3-D. Hand-built from flat polygons it was "so bad ... literally everything is ugly" (the user),
# so this one is a small 3-D world rendered by the engine in a viewport behind the menu: actual meshes, lights,
# materials, glow. The hotel's stone face with its windows lit room by room, pilasters and a cornice standing
# out; at its foot the entrance -- a marble platform with steps, the red carpet between brass posts and velvet
# ropes, topiary in planters, a glazed lobby with a turning revolving door -- under a copper canopy on brass
# columns whose bulbs chase round its fascia; lamp posts along the front, each a real light; a fountain playing;
# a row of parking bays. Guests' cars (bodies swept from a side profile, metallic paint, glass, wheels, lamps)
# come in off the street, stop by the canopy, glide into a bay; the one there before reverses out, its reversing
# lights on, and drives away. Everything follows one clock (`t`); nothing pops. Made up, never the board.

const PERIOD: float = 4.0            # a new guest every PERIOD seconds
const BAYS: int = 5
const BAY_X0: float = 150.0
const BAY_DX: float = 42.0
const FACADE_Z: float = -320.0
const CANOPY: Rect2 = Rect2(-95.0, -320.0, 190.0, 160.0)     # x, z, width, depth (from the facade forward)
const PLAT_Z: float = -175.0          # the entrance platform's front edge
const FOUNTAIN: Vector3 = Vector3(-250.0, 0.0, 40.0)
const COLORS: Array = [Color(0.55, 0.05, 0.07), Color(0.08, 0.13, 0.32), Color(0.72, 0.74, 0.78), Color(0.06, 0.06, 0.07),
	Color(0.90, 0.88, 0.84), Color(0.07, 0.26, 0.16), Color(0.40, 0.22, 0.10)]
const LAMPS: Array = [Vector3(-440.0, 0.0, 100.0), Vector3(-130.0, 0.0, 100.0), Vector3(110.0, 0.0, 100.0), Vector3(440.0, 0.0, 100.0)]
const PROFILE: Array = [Vector2(-23.0, 3.0), Vector2(-23.6, 9.0), Vector2(-21.5, 12.6), Vector2(-13.5, 13.6), Vector2(-8.0, 21.0),
	Vector2(6.0, 21.4), Vector2(12.5, 13.9), Vector2(22.0, 12.3), Vector2(23.6, 8.2), Vector2(23.0, 3.0)]
const POOL: int = BAYS + 4

# THE STILL SCENE IS A PICTURE (the user: "use the saved background trick for anything that doesnt change"): the
# hotel, the entrance, the canopy, the ground are rendered once at twice the size by devtools/make_menu_bake.gd
# (this script's `bake_mode`) into BAKED; at run time only what moves -- the cars, the chasing bulbs, the revolving
# door's wings, the fountain's spray -- and what may stand in front of a car (the lamp posts, the basin) are 3-D,
# in a see-through viewport over the picture, lit by the same lights
const BAKED: String = "res://guidem/art/menu_hotel.webp"
const BAKE_W: int = 680
const BAKE_H: int = 1500
const BAKE_CY: float = 750.0
var bake_mode: bool = false
var _live_only: bool = false
var _bg_tex: Texture2D = null
var _bg_layer: Control = null
var _cy: float = 0.0
var _box_vc: SubViewportContainer = null
var _vp: SubViewport = null
var _world: Node3D = null
var _root: Node3D = null            # the scene at 1:100, in metres: the engine's lights fall off by metres
var _cam3: Camera3D = null
var _cars: Array = []                 # per pool slot: [root Node3D, paint material, rear material]
var _bulbs: Array = []                # the canopy's bulb materials, for the chase
var _door: Node3D = null
var _for_bottom: float = -2.0

func _setup() -> void:
	_live_only = not bake_mode and ResourceLoader.exists(BAKED)
	if _live_only:
		_bg_tex = load(BAKED)
		_bg_layer = Control.new()
		_bg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_bg_layer.draw.connect(func() -> void: _bg_layer.draw_texture(_bg_tex, Vector2(0.0, _cy - BAKE_CY)))
		add_child(_bg_layer)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_8X if bake_mode else Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if bake_mode:
		_vp.size = Vector2i(BAKE_W * 2, BAKE_H * 2)
		add_child(_vp)
		var pic: Control = Control.new()
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.draw.connect(func() -> void: pic.draw_texture_rect(_vp.get_texture(), Rect2(0, 0, BAKE_W, BAKE_H), false))
		add_child(pic)
		pic.size = Vector2(BAKE_W, BAKE_H)
	else:
		_box_vc = SubViewportContainer.new()
		_box_vc.stretch = true
		_box_vc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_box_vc)
		_vp.transparent_bg = _live_only
		_box_vc.add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	# THE SCENE IN METRES: built in hundreds of units, its lamps (which fall off with the square of the distance
	# in metres) lit nothing -- so everything stands in a root at 1:100, and the lights' ranges are in metres
	_root = Node3D.new()
	_world.add_child(_root)
	_root.scale = Vector3.ONE * 0.01
	_environment()
	_cam3 = Camera3D.new()
	_cam3.keep_aspect = Camera3D.KEEP_WIDTH
	_cam3.fov = 50.0
	_cam3.near = 0.05
	_cam3.far = 40.0
	_world.add_child(_cam3)
	_cam3.look_at_from_position(Vector3(-30.0, 175.0, 360.0) * 0.01, Vector3(50.0, 25.0, -140.0) * 0.01, Vector3.UP)
	_cam3.current = true
	_static_lights()
	if not _live_only:
		_ground()
		_hotel()
		_entrance()
		_canopy()
	_lamps()
	_fountain()
	if not bake_mode:
		_door_wings()
		_canopy_bulbs()
		for k in POOL:
			_cars.append(_make_car())

# --- the frame: the viewport is sized and placed so the scene's center sits where the menu wants it ------------

func _tick(_delta: float) -> void:
	if bake_mode:
		return
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	if absf(scene_bottom - _for_bottom) > 0.5:
		_for_bottom = scene_bottom
		var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
		var top: float = 230.0 if mobile else 150.0
		var cy: float = top + (bottom - top) * (0.52 if mobile else 0.70)
		var half_h: float = maxf(cy, full.y - cy)
		_box_vc.position = Vector2(0.0, cy - half_h)
		_box_vc.size = Vector2(full.x, half_h * 2.0)
		_cy = cy
		if _bg_layer != null:
			_bg_layer.queue_redraw()
	_animate()

# --- the world -------------------------------------------------------------------------------------------------

func _environment() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR if _live_only else Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.34, 0.55)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = not _live_only
	env.glow_intensity = 0.8
	env.glow_bloom = 0.15
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	# a faint moonlight from high behind, so the shapes have a side in shadow even away from the lamps
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.62, 0.90)
	moon.light_energy = 0.25
	_world.add_child(moon)
	moon.rotation_degrees = Vector3(-50.0, -30.0, 0.0)

func _mat(col: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m

func _glow_mat(col: Color, energy: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m

func _put(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	(parent if parent != null else _root).add_child(mi)
	mi.position = pos
	mi.rotation_degrees = rot
	return mi

func _box(sz: Vector3, mat: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = sz
	return _put(bm, mat, pos, Vector3.ZERO, parent)

func _cyl(r_top: float, r_bot: float, h: float, mat: Material, pos: Vector3, parent: Node3D = null, segs: int = 24) -> MeshInstance3D:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	return _put(cm, mat, pos, Vector3.ZERO, parent)

func _light(pos: Vector3, col: Color, energy: float, rng: float, shadow: bool = false) -> OmniLight3D:
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng * 0.01
	l.omni_attenuation = 1.0
	l.shadow_enabled = shadow
	_root.add_child(l)
	l.position = pos
	return l

# a texture made in code: noise-like speckle over a base color, for asphalt, stone, marble
func _speckle_tex(w: int, h: int, base: Color, amount: float, seed_i: int) -> ImageTexture:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(base)
	var n: int = int(float(w * h) * 0.06)
	for k in n:
		var x: int = int(h01(seed_i * 100003 + k * 2) * float(w))
		var y: int = int(h01(seed_i * 100003 + k * 2 + 1) * float(h))
		var v: float = (h01(seed_i * 7 + k) - 0.5) * amount
		var c: Color = Color(clampf(base.r + v, 0.0, 1.0), clampf(base.g + v, 0.0, 1.0), clampf(base.b + v, 0.0, 1.0))
		img.set_pixel(mini(x, w - 1), mini(y, h - 1), c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _ground() -> void:
	# the forecourt's asphalt and the street beyond, fine grit in it, a little sheen
	var asphalt: StandardMaterial3D = _mat(Color(1, 1, 1), 0.55)
	asphalt.albedo_texture = _speckle_tex(256, 256, Color(0.20, 0.19, 0.20), 0.16, 3)
	asphalt.uv1_scale = Vector3(8, 8, 1)
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(2400.0, 1400.0)
	_put(pm, asphalt, Vector3(0.0, 0.0, -100.0))
	# the kerb between forecourt and street, with the gaps the cars use
	var kerb: StandardMaterial3D = _mat(Color(0.62, 0.60, 0.56), 0.9)
	for seg in [[-1200.0, -470.0], [-330.0, 370.0], [520.0, 1200.0]]:
		var x0: float = float(seg[0])
		var x1: float = float(seg[1])
		_box(Vector3(x1 - x0, 5.0, 8.0), kerb, Vector3((x0 + x1) * 0.5, 2.5, 122.0))
	# the street's center line
	var paint: StandardMaterial3D = _mat(Color(0.85, 0.82, 0.70), 0.7)
	var lx: float = -1200.0
	while lx < 1200.0:
		_box(Vector3(40.0, 0.3, 4.0), paint, Vector3(lx + 20.0, 0.15, 190.0))
		lx += 90.0
	# the bays' white lines
	var white: StandardMaterial3D = _mat(Color(0.92, 0.92, 0.90), 0.6)
	for k in BAYS + 1:
		var x: float = BAY_X0 - BAY_DX * 0.5 + float(k) * BAY_DX
		_box(Vector3(3.0, 0.3, 135.0), white, Vector3(x, 0.15, -27.5))
	_box(Vector3(BAY_DX * float(BAYS), 0.3, 3.0), white, Vector3(BAY_X0 - BAY_DX * 0.5 + BAY_DX * float(BAYS) * 0.5, 0.15, 39.5))

# THE HOTEL: a stone face (its texture drawn in code: courses of dressed stone, rusticated at the ground floor,
# the windows -- dark glass in its color, lit rooms in its emission), pilasters, string course and cornice
# standing out as real boxes
func _hotel() -> void:
	var w: int = 1040
	var h: int = 520
	var albedo: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	albedo.fill(Color(0.40, 0.36, 0.32))
	# the stone, block by block, each its own tone, mortar showing between (image y runs down from the roof)
	var y: int = 0
	var course: int = 0
	while y < h:
		var from_ground: int = h - y
		var rustic: bool = from_ground <= 96
		var ch: int = 24 if rustic else 17
		var bw: int = 62 if rustic else 40
		var gap: int = 2 if rustic else 1
		var x: int = -int(float(bw) * 0.5 * float(course % 2))
		var k: int = 0
		while x < w:
			var tone: float = 0.88 + 0.22 * h01(course * 131 + k * 7)
			var c: Color = Color(0.62 * tone, 0.56 * tone, 0.50 * tone)
			var rx: int = maxi(x + gap, 0)
			var rw: int = mini(x + bw - gap, w) - rx
			if rw > 0:
				albedo.fill_rect(Rect2i(rx, y + gap, rw, ch - gap * 2), c)
			x += bw
			k += 1
		y += ch
		course += 1
	# the windows: lit rooms (warm, brighter toward their ceiling, a bar across) or dark glass
	for fl in 9:
		for b in 16:
			var wx: int = 30 + b * 62
			var wy_from_ground: int = 110 + fl * 46
			var wy: int = h - wy_from_ground - 30
			if absi(wx - 520 + 18) < 70 and fl < 1:
				continue
			var lit: bool = h01(fl * 37 + b) > 0.25
			albedo.fill_rect(Rect2i(wx - 3, wy + 30, 40, 4), Color(0.72, 0.66, 0.58))
			if lit:
				var dim: float = 0.6 + 0.4 * h01(fl * 11 + b * 5)
				for row in 30:
					var f: float = 1.0 - float(row) / 30.0
					var c2: Color = Color(1.0, 0.78, 0.48) * (dim * (0.55 + 0.45 * f))
					albedo.fill_rect(Rect2i(wx, wy + row, 34, 1), c2 * 0.6)
			else:
				for row2 in 30:
					var g2: float = float(row2) / 30.0
					albedo.fill_rect(Rect2i(wx, wy + row2, 34, 1), Color(0.05, 0.06, 0.10).lerp(Color(0.16, 0.15, 0.20), g2))
			albedo.fill_rect(Rect2i(wx + 16, wy, 2, 30), Color(0.12, 0.10, 0.09))
			albedo.fill_rect(Rect2i(wx, wy + 17, 34, 2), Color(0.12, 0.10, 0.09))
	# THE ENTRANCE'S OPENING, cut through the face (it was a sheet of stone over the lobby): see-through texels
	albedo.fill_rect(Rect2i(520 - 62, h - 96, 124, 96), Color(0, 0, 0, 0))
	albedo.generate_mipmaps()
	var face: StandardMaterial3D = _mat(Color(1, 1, 1), 0.85)
	face.albedo_texture = ImageTexture.create_from_image(albedo)
	face.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	face.alpha_scissor_threshold = 0.5
	face.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# the lit windows are their own mesh, each a quad glowing warm, brighter toward its ceiling (an emission
	# texture on the stone made the whole face glow in this renderer)
	_lit_windows()
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(1040.0, 520.0)
	_put(qm, face, Vector3(0.0, 260.0, FACADE_Z))
	# the body behind the face, set back behind the lobby (it stood right behind the face and walled it up)
	_box(Vector3(1040.0, 520.0, 200.0), _mat(Color(0.30, 0.27, 0.24)), Vector3(0.0, 260.0, FACADE_Z - 146.0))
	var trim: StandardMaterial3D = _mat(Color(0.70, 0.64, 0.56), 0.8)
	for k in 9:
		var px: float = -520.0 + float(k) * 130.0
		if absf(px) < 70.0:
			continue
		_box(Vector3(14.0, 520.0, 8.0), trim, Vector3(px, 260.0, FACADE_Z + 4.0))
	_box(Vector3(1060.0, 16.0, 18.0), trim, Vector3(0.0, 512.0, FACADE_Z + 9.0))
	_box(Vector3(1060.0, 6.0, 8.0), trim, Vector3(0.0, 102.0, FACADE_Z + 4.0))
	# a sill under every window
	for fl in 9:
		for b in 16:
			var wx2: float = -490.0 + float(b) * 62.0 + 17.0
			var wy2: float = 110.0 + float(fl) * 46.0
			if absf(wx2 - 17.0 + 18.0) < 70.0 and fl < 1:
				continue
			_box(Vector3(40.0, 3.0, 5.0), trim, Vector3(wx2, wy2 - 1.5, FACADE_Z + 2.5))

func _lit_windows() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z: float = FACADE_Z + 0.4
	for fl in 9:
		for b in 16:
			var wx: float = -490.0 + float(b) * 62.0
			var wy: float = 110.0 + float(fl) * 46.0
			if absf(wx + 18.0) < 70.0 and fl < 1:
				continue
			if h01(fl * 37 + b) <= 0.25:
				continue
			var dim: float = 0.6 + 0.4 * h01(fl * 11 + b * 5)
			var top_c: Color = Color(1.0, 0.82, 0.52) * dim
			var bot_c: Color = Color(0.80, 0.50, 0.26) * dim
			var curtain: bool = h01(fl * 3 + b) < 0.4
			# the two halves of the window, either side of its bar; a curtain darkens the outer edges
			for half in 2:
				var x0: float = wx + (0.0 if half == 0 else 18.0)
				var x1: float = x0 + 16.0
				var tl: Color = top_c.darkened(0.45) if curtain and half == 0 else top_c
				var tr_c: Color = top_c.darkened(0.45) if curtain and half == 1 else top_c
				var bl: Color = bot_c.darkened(0.45) if curtain and half == 0 else bot_c
				var br: Color = bot_c.darkened(0.45) if curtain and half == 1 else bot_c
				for v in [[Vector3(x0, wy, z), bl], [Vector3(x1, wy, z), br], [Vector3(x1, wy + 30.0, z), tr_c],
						[Vector3(x0, wy, z), bl], [Vector3(x1, wy + 30.0, z), tr_c], [Vector3(x0, wy + 30.0, z), tl]]:
					st.set_color(v[1])
					st.add_vertex(v[0])
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	_root.add_child(mi)

# THE ENTRANCE: the lit lobby behind a glazed brass front with a revolving door; the marble platform and its
# steps; the carpet with brass rods; brass posts with velvet ropes; topiary in planters
func _entrance() -> void:
	var ph: float = 8.0
	var brass: StandardMaterial3D = _mat(Color(0.85, 0.66, 0.30), 0.35, 0.3)
	# THE LOBBY, a room behind the opening: a marble floor with a rug, panelled walls, a coffered ceiling, the
	# reception desk with its brass top and a lamp, palms in pots, the chandelier (it was a glowing box)
	var lz0: float = FACADE_Z - 44.0
	var wall: StandardMaterial3D = _mat(Color(0.62, 0.42, 0.26), 0.6)
	var panel: StandardMaterial3D = _mat(Color(0.48, 0.30, 0.17), 0.5)
	_box(Vector3(124.0, 2.0, 44.0), _mat(Color(0.86, 0.84, 0.80), 0.15), Vector3(0.0, ph - 1.0, FACADE_Z - 22.0))
	_box(Vector3(70.0, 0.6, 26.0), _mat(Color(0.50, 0.06, 0.08), 1.0), Vector3(0.0, ph + 0.3, FACADE_Z - 22.0))
	_box(Vector3(124.0, 96.0, 2.0), wall, Vector3(0.0, 48.0, lz0 - 1.0))
	for k in 4:
		_box(Vector3(22.0, 40.0, 0.8), panel, Vector3(-45.0 + float(k) * 30.0, 30.0, lz0 + 0.4))
	for sx in [-63.0, 63.0]:
		_box(Vector3(2.0, 96.0, 44.0), wall, Vector3(sx, 48.0, FACADE_Z - 22.0))
	_box(Vector3(124.0, 2.0, 44.0), _mat(Color(0.85, 0.78, 0.62), 0.7), Vector3(0.0, 97.0, FACADE_Z - 22.0))
	_box(Vector3(56.0, 18.0, 10.0), _mat(Color(0.26, 0.14, 0.07), 0.4), Vector3(0.0, ph + 9.0, lz0 + 10.0))
	_box(Vector3(58.0, 1.5, 11.0), brass, Vector3(0.0, ph + 18.75, lz0 + 10.0))
	var lamp_shade: SphereMesh = SphereMesh.new()
	lamp_shade.radius = 3.0
	lamp_shade.height = 4.0
	_put(lamp_shade, _glow_mat(Color(1.0, 0.85, 0.60), 2.0), Vector3(20.0, ph + 24.0, lz0 + 10.0))
	for px in [-48.0, 48.0]:
		_cyl(4.0, 3.0, 10.0, _mat(Color(0.20, 0.20, 0.22), 0.4, 0.3), Vector3(px, ph + 5.0, lz0 + 8.0))
		for fr in 5:
			var leaf: SphereMesh = SphereMesh.new()
			leaf.radius = 5.0
			leaf.height = 4.0
			var la: float = TAU * float(fr) / 5.0
			_put(leaf, _mat(Color(0.12, 0.32, 0.12), 0.8), Vector3(px + cos(la) * 5.0, ph + 18.0 + float(fr % 2) * 3.0, lz0 + 8.0 + sin(la) * 5.0))
	var chand: SphereMesh = SphereMesh.new()
	chand.radius = 6.0
	chand.height = 9.0
	_put(chand, _glow_mat(Color(1.0, 0.92, 0.70), 4.0), Vector3(0.0, 82.0, FACADE_Z - 12.0))
	# the glazed front: brass mullions and a transom bar, glass over the hall
	for fx in [-62.0, -36.0, 36.0, 62.0]:
		_box(Vector3(3.0, 88.0, 3.0), brass, Vector3(fx, ph + 44.0, FACADE_Z + 1.5))
	_box(Vector3(128.0, 3.0, 3.0), brass, Vector3(0.0, 76.0, FACADE_Z + 1.5))
	var glass: StandardMaterial3D = _mat(Color(0.75, 0.85, 1.0, 0.18), 0.05, 0.3)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box(Vector3(124.0, 88.0, 0.5), glass, Vector3(0.0, ph + 44.0, FACADE_Z + 0.5))
	# the revolving door: a glass drum, brass rings, four wings that turn
	_cyl(28.0, 28.0, 66.0, glass, Vector3(0.0, ph + 33.0, FACADE_Z + 4.0))
	_cyl(30.0, 30.0, 4.0, brass, Vector3(0.0, ph + 68.0, FACADE_Z + 4.0))
	_cyl(30.0, 30.0, 2.0, brass, Vector3(0.0, ph + 1.0, FACADE_Z + 4.0))

	# THE PLATFORM: marble slabs in a soft checker; its riser and two steps down to the drive
	var marble_img: Image = Image.create(256, 256, false, Image.FORMAT_RGB8)
	for gx in 8:
		for gy in 8:
			var light: bool = (gx + gy) % 2 == 0
			var base: Color = Color(0.90, 0.88, 0.84) if light else Color(0.55, 0.52, 0.50)
			marble_img.fill_rect(Rect2i(gx * 32, gy * 32, 32, 32), base)
			for v in 6:
				var vx: int = gx * 32 + int(h01(gx * 31 + gy * 7 + v) * 31.0)
				var vy: int = gy * 32 + int(h01(gx * 17 + gy * 3 + v) * 31.0)
				marble_img.fill_rect(Rect2i(vx, vy, 1 + v % 3, 1), base.darkened(0.12))
	marble_img.generate_mipmaps()
	var marble: StandardMaterial3D = _mat(Color(1, 1, 1), 0.2)
	marble.albedo_texture = ImageTexture.create_from_image(marble_img)
	marble.uv1_scale = Vector3(3, 2, 1)
	var plat_d: float = PLAT_Z - FACADE_Z
	_box(Vector3(220.0, ph, plat_d), marble, Vector3(0.0, ph * 0.5, FACADE_Z + plat_d * 0.5))
	var step_m: StandardMaterial3D = _mat(Color(0.80, 0.78, 0.74), 0.4)
	_box(Vector3(232.0, ph * 0.66, 12.0), step_m, Vector3(0.0, ph * 0.33, PLAT_Z + 6.0))
	_box(Vector3(244.0, ph * 0.33, 12.0), step_m, Vector3(0.0, ph * 0.165, PLAT_Z + 18.0))
	# THE CARPET: velvet red with gold edging, down the steps, brass rods
	var velvet: StandardMaterial3D = _mat(Color(0.55, 0.03, 0.06), 1.0)
	var gold_edge: StandardMaterial3D = _mat(Color(0.85, 0.65, 0.25), 0.5, 0.6)
	_box(Vector3(48.0, 0.8, plat_d - 4.0), velvet, Vector3(0.0, ph + 0.4, FACADE_Z + 4.0 + (plat_d - 4.0) * 0.5))
	for e in [-1.0, 1.0]:
		_box(Vector3(2.5, 0.9, plat_d - 4.0), gold_edge, Vector3(e * 24.0, ph + 0.45, FACADE_Z + 4.0 + (plat_d - 4.0) * 0.5))
	_box(Vector3(48.0, 0.8, 12.0), velvet, Vector3(0.0, ph * 0.66 + 0.4, PLAT_Z + 6.0))
	_box(Vector3(48.0, 0.8, 12.0), velvet, Vector3(0.0, ph * 0.33 + 0.4, PLAT_Z + 18.0))
	for sz in [PLAT_Z + 0.8, PLAT_Z + 12.8]:
		var rod: MeshInstance3D = _cyl(0.7, 0.7, 52.0, brass, Vector3(0.0, (ph * 0.66 if sz < PLAT_Z + 5.0 else ph * 0.33) + 1.0, sz))
		rod.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	# brass posts and velvet ropes along the carpet
	for e2 in [-1.0, 1.0]:
		var pz: float = FACADE_Z + 40.0
		var prev: Vector3 = Vector3.INF
		while pz < PLAT_Z - 5.0:
			var base_p: Vector3 = Vector3(e2 * 38.0, ph, pz)
			_cyl(1.2, 1.6, 22.0, brass, base_p + Vector3(0, 11.0, 0))
			_cyl(3.5, 4.0, 1.5, brass, base_p + Vector3(0, 0.75, 0))
			var knob: SphereMesh = SphereMesh.new()
			knob.radius = 2.4
			knob.height = 4.8
			_put(knob, brass, base_p + Vector3(0, 23.0, 0))
			if prev != Vector3.INF:
				_rope(prev + Vector3(0, 20.0, 0), base_p + Vector3(0, 20.0, 0), velvet)
			prev = base_p
			pz += 40.0
	# topiary in planters either side of the doors
	var pot: StandardMaterial3D = _mat(Color(0.28, 0.28, 0.30), 0.5, 0.3)
	var leaf: StandardMaterial3D = _mat(Color(0.10, 0.28, 0.10), 0.9)
	for e3 in [-1.0, 1.0]:
		var tb: Vector3 = Vector3(e3 * 92.0, ph, FACADE_Z + 24.0)
		_box(Vector3(22.0, 18.0, 22.0), pot, tb + Vector3(0, 9.0, 0))
		for tier in 4:
			var sm: SphereMesh = SphereMesh.new()
			var rr: float = 11.0 - float(tier) * 2.4
			sm.radius = rr
			sm.height = rr * 1.6
			_put(sm, leaf, tb + Vector3(0, 24.0 + float(tier) * 9.0, 0))

# a velvet rope sagging between two posts: short cylinders along the curve
# the canopy's bulbs, chasing (live)
func _canopy_bulbs() -> void:
	var x0: float = CANOPY.position.x
	var x1: float = CANOPY.end.x
	var z0: float = CANOPY.position.y
	var z1: float = CANOPY.end.y
	var y0: float = 98.0
	# the bulbs: little glowing spheres along the foot of the front and sides
	var bulb: SphereMesh = SphereMesh.new()
	bulb.radius = 1.6
	bulb.height = 3.2
	var path: Array = [Vector3(x0 - 1.6, y0 + 4.0, z0 + 40.0), Vector3(x0 - 1.6, y0 + 4.0, z1 + 3.4), Vector3(x1 + 1.6, y0 + 4.0, z1 + 3.4), Vector3(x1 + 1.6, y0 + 4.0, z0 + 40.0)]
	var total: float = 0.0
	for k in path.size() - 1:
		total += Vector3(path[k]).distance_to(path[k + 1])
	var count: int = 46
	for k in count:
		var sv: float = total * float(k) / float(count - 1)
		var acc: float = 0.0
		var bp: Vector3 = path[0]
		for j in path.size() - 1:
			var seg: float = Vector3(path[j]).distance_to(path[j + 1])
			if sv <= acc + seg:
				bp = Vector3(path[j]).lerp(path[j + 1], (sv - acc) / seg)
				break
			acc += seg
		var bm: StandardMaterial3D = _glow_mat(Color(1.0, 0.86, 0.55), 3.0)
		_put(bulb, bm, bp)
		_bulbs.append(bm)

# the revolving door's wings, turning (live)
func _door_wings() -> void:
	var glass: StandardMaterial3D = _mat(Color(0.75, 0.85, 1.0, 0.22), 0.05, 0.3)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var brass: StandardMaterial3D = _mat(Color(0.85, 0.66, 0.30), 0.35, 0.3)
	_door = Node3D.new()
	_root.add_child(_door)
	_door.position = Vector3(0.0, 8.0 + 33.0, FACADE_Z + 4.0)
	for k in 4:
		var wing: MeshInstance3D = _box(Vector3(27.0, 64.0, 1.2), glass, Vector3.ZERO, _door)
		wing.rotation_degrees = Vector3(0.0, 90.0 * float(k), 0.0)
		wing.position = Vector3(cos(deg_to_rad(90.0 * float(k))) * 13.5, 0.0, -sin(deg_to_rad(90.0 * float(k))) * 13.5)
		_box(Vector3(27.0, 2.0, 2.0), brass, wing.position + Vector3(0, 31.0, 0), _door).rotation_degrees = wing.rotation_degrees
	_box(Vector3(3.0, 64.0, 3.0), brass, Vector3.ZERO, _door)

func _rope(a: Vector3, b: Vector3, mat: Material) -> void:
	var prev: Vector3 = a
	for k in range(1, 9):
		var u: float = float(k) / 8.0
		var p: Vector3 = a.lerp(b, u) + Vector3(0, -sin(u * PI) * 6.0, 0)
		var seg: MeshInstance3D = _cyl(0.9, 0.9, prev.distance_to(p), mat, (prev + p) * 0.5)
		seg.look_at_from_position((prev + p) * 0.5, p, Vector3.UP if absf((p - prev).normalized().y) < 0.99 else Vector3.RIGHT)
		seg.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		prev = p

# THE CANOPY: brass columns, a copper roof with standing seams, a maroon fascia trimmed in gold, the bulbs along
# its foot (each its own light material, so they chase), VALET in raised letters, its light on the drive
func _canopy() -> void:
	var x0: float = CANOPY.position.x
	var x1: float = CANOPY.end.x
	var z0: float = CANOPY.position.y
	var z1: float = CANOPY.end.y
	var y0: float = 98.0
	var y1: float = 118.0
	var brass: StandardMaterial3D = _mat(Color(0.85, 0.66, 0.30), 0.35, 0.3)
	for cx in [x0 + 10.0, x1 - 10.0]:
		for cz in [z1 - 12.0, z0 + 70.0]:
			_cyl(4.5, 5.0, y0 - 8.0, brass, Vector3(cx, 8.0 + (y0 - 8.0) * 0.5, cz))
			_cyl(7.0, 7.0, 4.0, brass, Vector3(cx, 10.0, cz))
			_cyl(7.5, 6.0, 5.0, brass, Vector3(cx, y0 - 2.5, cz))
	var copper: StandardMaterial3D = _mat(Color(0.36, 0.56, 0.48), 0.45, 0.5)
	_box(Vector3(x1 - x0, 4.0, z1 - z0), copper, Vector3((x0 + x1) * 0.5, y1 - 2.0, (z0 + z1) * 0.5))
	var seam: StandardMaterial3D = _mat(Color(0.50, 0.70, 0.60), 0.35, 0.6)
	var sx: float = x0 + 10.0
	while sx < x1:
		_box(Vector3(1.6, 1.4, z1 - z0), seam, Vector3(sx, y1 + 0.5, (z0 + z1) * 0.5))
		sx += 14.0
	var maroon: StandardMaterial3D = _mat(Color(0.35, 0.05, 0.07), 0.6)
	_box(Vector3(x1 - x0 + 2.0, y1 - y0, 3.0), maroon, Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, z1 + 1.5))
	for e in [x0, x1]:
		_box(Vector3(3.0, y1 - y0, z1 - z0), maroon, Vector3(float(e), (y0 + y1) * 0.5, (z0 + z1) * 0.5))
	var gold: StandardMaterial3D = _mat(Color(0.90, 0.70, 0.30), 0.35, 0.3)
	for gy in [y0 + 1.0, y1 - 1.0]:
		_box(Vector3(x1 - x0 + 4.0, 1.4, 1.0), gold, Vector3((x0 + x1) * 0.5, gy, z1 + 3.2))
	# VALET, raised on the front
	var lbl: Label3D = Label3D.new()
	lbl.text = "VALET"
	lbl.font = MainGlobals.get_text_font()
	lbl.font_size = 96
	lbl.pixel_size = 0.11
	lbl.modulate = Color(1.0, 0.86, 0.50)
	lbl.outline_size = 0
	lbl.shaded = false
	_root.add_child(lbl)
	lbl.position = Vector3(0.0, y0 + 10.5, z1 + 3.3)


# the lights that light both the picture and the live cars: the lobby's, the canopy's
func _static_lights() -> void:
	_light(Vector3(0.0, 70.0, FACADE_Z - 20.0), Color(1.0, 0.82, 0.55), 0.35, 160.0)
	_light(Vector3(0.0, 70.0, FACADE_Z + 30.0), Color(1.0, 0.82, 0.55), 0.18, 200.0, true)
	var y0: float = 98.0
	var z1: float = CANOPY.end.y
	_light(Vector3(-40.0, y0 - 6.0, z1 - 40.0), Color(1.0, 0.85, 0.60), 0.5, 230.0, true)
	_light(Vector3(40.0, y0 - 6.0, z1 - 40.0), Color(1.0, 0.85, 0.60), 0.5, 230.0)

# THE LAMP POSTS: dark posts with a lantern, each a real light on the forecourt
func _lamps() -> void:
	var iron: StandardMaterial3D = _mat(Color(0.10, 0.10, 0.11), 0.5, 0.6)
	var globe: StandardMaterial3D = _glow_mat(Color(1.0, 0.86, 0.62), 3.5)
	for lp in LAMPS:
		var b: Vector3 = lp
		_cyl(2.0, 3.2, 86.0, iron, b + Vector3(0, 43.0, 0))
		_cyl(5.0, 5.0, 4.0, iron, b + Vector3(0, 2.0, 0))
		var gm: SphereMesh = SphereMesh.new()
		gm.radius = 7.0
		gm.height = 14.0
		_put(gm, globe, b + Vector3(0, 93.0, 0))
		# the lantern's head: a collar under the globe, a small domed cap over it, a finial (it wore a flat black
		# disc, like a hat)
		_cyl(3.6, 2.6, 3.0, iron, b + Vector3(0, 85.5, 0))
		var cap: SphereMesh = SphereMesh.new()
		cap.radius = 3.8
		cap.height = 3.8
		cap.is_hemisphere = true
		_put(cap, iron, b + Vector3(0, 99.4, 0))
		_cyl(0.3, 0.9, 6.0, iron, b + Vector3(0, 104.0, 0), null, 12)
		_light(b + Vector3(0, 93.0, 0), Color(1.0, 0.80, 0.52), 1.6, 320.0)

# THE FOUNTAIN: a stone basin, the water lit from below, a jet and its falling drops
func _fountain() -> void:
	var stone: StandardMaterial3D = _mat(Color(0.70, 0.66, 0.60), 0.8)
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 58.0
	tm.outer_radius = 68.0
	var ring: MeshInstance3D = _put(tm, stone, FOUNTAIN + Vector3(0, 8.0, 0))
	ring.scale = Vector3(1.0, 1.6, 1.0)
	var water: StandardMaterial3D = _glow_mat(Color(0.20, 0.55, 0.70), 0.5)
	water.roughness = 0.05
	_cyl(60.0, 60.0, 1.0, water, FOUNTAIN + Vector3(0, 8.0, 0))
	_light(FOUNTAIN + Vector3(0, 14.0, 0), Color(0.55, 0.85, 1.0), 0.35, 130.0)
	var spray: CPUParticles3D = CPUParticles3D.new()
	var drop: SphereMesh = SphereMesh.new()
	drop.radius = 0.9
	drop.height = 1.8
	spray.mesh = drop
	spray.material_override = _glow_mat(Color(0.80, 0.92, 1.0), 1.5)
	spray.amount = 220
	spray.lifetime = 1.6
	spray.direction = Vector3.UP
	spray.spread = 18.0
	spray.initial_velocity_min = 70.0
	spray.initial_velocity_max = 80.0
	spray.gravity = Vector3(0, -95.0, 0)
	spray.emitting = not bake_mode
	spray.visible = not bake_mode
	spray.preprocess = 2.0
	spray.local_coords = true
	_root.add_child(spray)
	spray.position = FOUNTAIN + Vector3(0, 10.0, 0)

# --- a car: a body swept from the side profile, as a real mesh ----------------------------------------------------

func _half_w(hgt: float) -> float:
	return 10.5 - maxf(0.0, hgt - 13.5) * 0.28

func _car_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = PROFILE.size()
	# the panels round the profile (bumper, bonnet, windshield, roof, rear window, boot), then the two sides
	for i in n - 1:
		var a: Vector2 = PROFILE[i]
		var b: Vector2 = PROFILE[i + 1]
		var al: Vector3 = Vector3(a.x, a.y, -_half_w(a.y))
		var ar: Vector3 = Vector3(a.x, a.y, _half_w(a.y))
		var bl: Vector3 = Vector3(b.x, b.y, -_half_w(b.y))
		var br: Vector3 = Vector3(b.x, b.y, _half_w(b.y))
		_tri(st, al, bl, br)
		_tri(st, al, br, ar)
	for side in [-1.0, 1.0]:
		var c: Vector3 = Vector3(0.0, 11.0, 0.0)
		for i2 in n:
			var p0: Vector2 = PROFILE[i2]
			var p1: Vector2 = PROFILE[(i2 + 1) % n]
			var v0: Vector3 = Vector3(p0.x, p0.y, side * _half_w(p0.y))
			var v1: Vector3 = Vector3(p1.x, p1.y, side * _half_w(p1.y))
			if side > 0.0:
				_tri(st, c + Vector3(0, 0, side * 10.0), v1, v0)
			else:
				_tri(st, c + Vector3(0, 0, side * 10.0), v0, v1)
	st.generate_normals()
	return st.commit()

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

func _make_car() -> Array:
	var root: Node3D = Node3D.new()
	_root.add_child(root)
	root.visible = false
	var paint: StandardMaterial3D = _mat(Color(0.5, 0.5, 0.5), 0.28, 0.15)
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = _car_mesh()
	body.material_override = paint
	root.add_child(body)
	# the glass: windshield, rear window and the side windows as dark glossy panels just proud of the body
	var glass: StandardMaterial3D = _mat(Color(0.05, 0.06, 0.09), 0.05, 0.4)
	for side in [-1.0, 1.0]:
		var pane: MeshInstance3D = _box(Vector3(22.0, 5.0, 0.3), glass, Vector3(-1.0, 17.2, side * (_half_w(17.2) + 0.15)), root)
		pane.rotation_degrees = Vector3(side * -6.0, 0.0, 0.0)
	var ws: MeshInstance3D = _box(Vector3(9.2, 0.3, 15.0), glass, Vector3(9.2, 17.7, 0.0), root)
	ws.rotation_degrees = Vector3(0.0, 0.0, -49.0)
	var rw: MeshInstance3D = _box(Vector3(8.6, 0.3, 15.0), glass, Vector3(-10.8, 17.3, 0.0), root)
	rw.rotation_degrees = Vector3(0.0, 0.0, 53.0)
	# wheels, black tires with silver hubs
	var tire: StandardMaterial3D = _mat(Color(0.03, 0.03, 0.03), 0.9)
	var hub: StandardMaterial3D = _mat(Color(0.75, 0.75, 0.78), 0.3, 0.3)
	for wf in [-14.5, 14.0]:
		for side2 in [-1.0, 1.0]:
			var t_mi: MeshInstance3D = _cyl(4.6, 4.6, 3.8, tire, Vector3(wf, 4.6, side2 * 8.7), root, 16)
			t_mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			var h_mi: MeshInstance3D = _cyl(2.4, 2.4, 3.9, hub, Vector3(wf, 4.6, side2 * 8.75), root, 12)
			h_mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	# headlights and rear lights
	var head: StandardMaterial3D = _glow_mat(Color(1.0, 0.97, 0.88), 4.0)
	var rear: StandardMaterial3D = _glow_mat(Color(1.0, 0.15, 0.10), 2.5)
	for side3 in [-1.0, 1.0]:
		_box(Vector3(0.6, 2.4, 4.8), head, Vector3(23.4, 9.6, side3 * 7.0), root)
		_box(Vector3(0.6, 2.6, 4.8), rear, Vector3(-23.5, 10.2, side3 * 7.2), root)
	# ON THE ASPHALT (it is in the baked picture, so no live light can reach it): a soft shadow under the car, its
	# headlights' pool on the ground ahead, a faint glow of its rear lights behind -- planes that go with it
	var shadow_m: StandardMaterial3D = StandardMaterial3D.new()
	shadow_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_m.albedo_texture = _pool_tex(false, Color(0, 0, 0))
	_plane(root, Vector2(58.0, 30.0), shadow_m, Vector3(0.0, 0.4, 0.0))
	var head_m: StandardMaterial3D = StandardMaterial3D.new()
	head_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	head_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	head_m.albedo_texture = _pool_tex(true, Color(1.0, 0.92, 0.75))
	# one cone from each headlight
	for hz in [-7.0, 7.0]:
		_plane(root, Vector2(70.0, 34.0), head_m, Vector3(58.0, 0.5 + 0.05 * hz / 7.0, hz))
	var rear_m: StandardMaterial3D = StandardMaterial3D.new()
	rear_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rear_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rear_m.albedo_texture = _pool_tex(false, Color(1.0, 1.0, 1.0))
	rear_m.albedo_color = Color(1.0, 0.12, 0.08, 0.18)
	_plane(root, Vector2(26.0, 30.0), rear_m, Vector3(-30.0, 0.5, 0.0))
	return [root, paint, rear, rear_m]

func _plane(parent: Node3D, sz: Vector2, m: Material, pos: Vector3) -> void:
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = sz
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	parent.add_child(mi)
	mi.position = pos

# a soft pool for the ground: a CONE of light spreading away from the car (along u) for the headlights, or a soft
# round blot for the shadow and the rear glow; its strength in its alpha (the view is see-through over the picture,
# so added light came out as black)
func _pool_tex(cone: bool, col: Color) -> ImageTexture:
	var n: int = 64
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u: float = float(x) / float(n - 1)
			var v: float = float(y) / float(n - 1) - 0.5
			var k: float = 0.0
			if cone:
				var width: float = 0.10 + 0.40 * u
				k = pow(1.0 - u, 1.4) * exp(-pow(v / width, 2.0) * 2.0) * smoothstep(0.0, 0.12, u)
				img.set_pixel(x, y, Color(col.r, col.g, col.b, minf(1.0, k * 0.85)))
			else:
				var r: float = Vector2((u - 0.5) * 2.0, v * 2.0).length()
				k = clampf(1.0 - r, 0.0, 1.0)
				k = k * k
				if col == Color(0, 0, 0):
					img.set_pixel(x, y, Color(0, 0, 0, k * 0.55))
				else:
					img.set_pixel(x, y, Color(1.0, 1.0, 1.0, k))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# --- motion ----------------------------------------------------------------------------------------------------

func _animate() -> void:
	# the bulbs chase, slowly
	for k in _bulbs.size():
		var wave: float = 0.55 + 0.45 * sin(float(k) * 0.55 - t * 3.0)
		(_bulbs[k] as StandardMaterial3D).emission_energy_multiplier = 1.0 + 3.5 * wave
	if _door != null:
		_door.rotation_degrees = Vector3(0.0, t * 18.0, 0.0)
	# the cars: each guest in its pool slot
	for c in _cars:
		(c[0] as Node3D).visible = false
	var n0: int = int(floor(t / PERIOD))
	for i in range(n0 - BAYS - 3, n0 + 1):
		var stt: Array = _car_state(i)
		if stt.is_empty():
			continue
		var slot: Array = _cars[posmod(i, POOL)]
		var root: Node3D = slot[0]
		root.visible = true
		var p: Vector3 = stt[0]
		var f: Vector3 = Vector3(Vector3(stt[1]).x, 0.0, Vector3(stt[1]).z).normalized()
		var s: Vector3 = f.cross(Vector3.UP).normalized()
		root.transform = Transform3D(Basis(f, Vector3.UP, s), p)
		(slot[1] as StandardMaterial3D).albedo_color = stt[2]
		var rear: StandardMaterial3D = slot[2]
		var rev: bool = stt[3]
		rear.albedo_color = Color(1.0, 1.0, 0.95) if rev else Color(1.0, 0.15, 0.10)
		rear.emission = rear.albedo_color
		rear.emission_energy_multiplier = 4.0 if (rev or bool(stt[4])) else 2.0
		# the rear lights' glow on the ground: brighter braking, white reversing
		var rg: StandardMaterial3D = slot[3]
		rg.albedo_color = Color(1.0, 1.0, 0.95, 0.35) if rev else (Color(1.0, 0.12, 0.08, 0.40) if bool(stt[4]) else Color(1.0, 0.12, 0.08, 0.18))

# a Catmull-Rom path through points (x, z), sampled with its running length
func _path(pts: Array) -> Array:
	var out: PackedVector3Array = PackedVector3Array()
	for i in pts.size() - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		for k in 10:
			var u: float = float(k) / 10.0
			var q: Vector2 = 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)
			out.append(Vector3(q.x, 0.0, q.y))
	var last: Vector2 = pts[pts.size() - 1]
	out.append(Vector3(last.x, 0.0, last.y))
	var cum: PackedFloat32Array = PackedFloat32Array([0.0])
	for i in range(1, out.size()):
		cum.append(cum[i - 1] + out[i].distance_to(out[i - 1]))
	return [out, cum]

func _along(pa: Array, u: float) -> Array:
	var pts: PackedVector3Array = pa[0]
	var cum: PackedFloat32Array = pa[1]
	var sv: float = clampf(u, 0.0, 1.0) * cum[cum.size() - 1]
	for i in range(1, pts.size()):
		if cum[i] >= sv or i == pts.size() - 1:
			var seg: float = maxf(cum[i] - cum[i - 1], 0.001)
			return [pts[i - 1].lerp(pts[i], (sv - cum[i - 1]) / seg), (pts[i] - pts[i - 1]).normalized()]
	return [pts[pts.size() - 1], Vector3(0, 0, 1)]

func _ease(t0: float, dur: float) -> float:
	return smoothstep(0.0, 1.0, clampf((t - t0) / dur, 0.0, 1.0))

# the state of guest i's car now: [position, heading, color, reversing, braking] -- or empty when not in the scene
func _car_state(i: int) -> Array:
	var t0: float = float(i) * PERIOD
	if t < t0:
		return []
	var bay: int = posmod(i, BAYS)
	var bx: float = BAY_X0 + float(bay) * BAY_DX
	var col: Color = COLORS[posmod(i * 3 + 1, COLORS.size())]
	var stop: Vector2 = Vector2(0.0, PLAT_Z + 48.0)
	var arrive: Array = _path([Vector2(-760, 190), Vector2(-560, 190), Vector2(-400, 120), Vector2(-260, -60), Vector2(-120, stop.y), stop])
	var park: Array = _path([stop, Vector2(60, stop.y), Vector2(bx - 20.0, -125), Vector2(bx, -80), Vector2(bx, -20), Vector2(bx, 10)])
	var back: Array = _path([Vector2(bx, 10), Vector2(bx, -55), Vector2(bx - 18.0, -112), Vector2(bx - 55.0, -128)])
	var leave: Array = _path([Vector2(bx - 55.0, -128), Vector2(bx - 10.0, -132), Vector2(BAY_X0 + BAY_DX * float(BAYS) + 40.0, -130), Vector2(470, 30), Vector2(560, 190), Vector2(820, 190)])
	var a_end: float = t0 + 2.4
	var h_end: float = a_end + 1.4
	var p_end: float = h_end + 2.6
	var out0: float = t0 + float(BAYS) * PERIOD + 1.2
	var r_end: float = out0 + 1.8
	var l_end: float = r_end + 3.0
	if t < a_end:
		var at: Array = _along(arrive, _ease(t0, 2.4) * 0.85 + clampf((t - t0) / 2.4, 0.0, 1.0) * 0.15)
		return [at[0], at[1], col, false, t > a_end - 0.9]
	if t < h_end:
		var at2: Array = _along(arrive, 1.0)
		return [at2[0], at2[1], col, false, true]
	if t < p_end:
		var at3: Array = _along(park, _ease(h_end, 2.6))
		return [at3[0], at3[1], col, false, t > p_end - 0.8]
	if t < out0:
		var at4: Array = _along(park, 1.0)
		return [at4[0], at4[1], col, false, false]
	if t < r_end:
		var at5: Array = _along(back, _ease(out0, 1.8))
		return [at5[0], -Vector3(at5[1]), col, true, false]
	if t < l_end:
		var lu: float = clampf((t - r_end) / 3.0, 0.0, 1.0)
		var at6: Array = _along(leave, lu * lu * 0.6 + lu * 0.4)
		return [at6[0], at6[1], col, false, false]
	return []

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Valet", "Help your players reach their targets", Color(1.0, 0.88, 0.60), Color(0.12, 0.06, 0.04),
		Color(1.0, 0.8, 0.45, 0.25))

extends "res://scripts/menu_poster3d.gd"

# STORM'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): THE HOUSE AT NIGHT
# IN THE STORM -- the game is keeping it dry. The house is REAL 3-D now (the flat front-on drawing was "flat"):
#   the sky       2-D, behind the scene: storm blue, layered clouds drifting (their undersides catching the flashes),
#                 a forked bolt behind the roof, a far curtain of fainter rain, rolling hills on the horizon
#   the house     two stories of painted clapboard under a shingled gable roof with a brick chimney, white trim,
#                 curtained windows lit warm, a porch on posts with steps and its lamp, a
#                 downspout to a bucket, a loose shutter swinging (live), a figure passing behind a curtain (live)
#   the yard      wet grass, stepping stones to the porch, a picket fence, a bare tree bent by the wind, puddles
#   the weather   2-D, over the scene: slanting rain, the gutter dripping, the downspout gushing, the chimney's
#                 smoke torn sideways, rings in the puddles, leaves blowing, and in a flash the whole scene whitened
# The house and yard are baked with a CLEAR sky (`_bake_alpha`: `menu_house.webp`), so the 2-D sky shows behind them.
# Made up, never the board.

const NEAR_DROPS: int = 150
const FAR_DROPS: int = 110
const LEAVES: int = 9
const SIDING: Color = Color(0.56, 0.62, 0.70)
const TRIM: Color = Color(0.92, 0.92, 0.88)
const WARM: Color = Color(1.0, 0.80, 0.46)

var _near: Array = []
var _far: Array = []
var _bolt: Array = []
var _bolt_at: float = -10.0
var _next_bolt: float = 1.4
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _shutter: Node3D = null

# the house's points the 2-D weather needs (units)
const EAVE_L: Vector3 = Vector3(-170.0, 205.0, 112.0)
const EAVE_R: Vector3 = Vector3(170.0, 205.0, 112.0)
const SPOUT: Vector3 = Vector3(162.0, 18.0, 128.0)
const DRAIN: Vector3 = Vector3(226.0, 0.0, 216.0)        # the yard drain the downspout's water runs to
const CHIMNEY: Vector3 = Vector3(95.0, 330.0, -20.0)
const PUDDLES: Array = [Vector3(-40.0, 0.0, 250.0), Vector3(120.0, 0.0, 300.0), Vector3(-200.0, 0.0, 330.0)]

# one picture per platform: a desktop's short band needs the camera further back (the title cut the roof)
func _baked_path() -> String:
	return "res://storm/art/menu_house.webp" if mobile else "res://storm/art/menu_house_d.webp"

func _bake_alpha() -> bool:
	return true

func _eye() -> Vector3:
	return Vector3(-390.0, 250.0, 700.0) if mobile else Vector3(-430.0, 250.0, 900.0)

func _aim() -> Vector3:
	return Vector3(20.0, 140.0, 60.0) if mobile else Vector3(20.0, 160.0, 60.0)

func _fov() -> float:
	return 54.0

func _frame_frac() -> float:
	return 0.50 if mobile else 0.56

func _environment(env: Environment) -> void:
	env.background_color = Color(0.03, 0.05, 0.11)
	env.ambient_light_color = Color(0.45, 0.52, 0.70)
	env.ambient_light_energy = 0.28

func _setup() -> void:
	live_title = true          # the name brightens with the lightning, and the rain is drawn over it
	_rng.seed = 7
	for _i in NEAR_DROPS:
		_near.append([_rng.randf(), _rng.randf(), _rng.randf_range(0.9, 1.4), _rng.randf_range(0.7, 1.2)])
	for _i in FAR_DROPS:
		_far.append([_rng.randf(), _rng.randf(), _rng.randf_range(0.5, 0.8), _rng.randf_range(0.4, 0.7)])
	super._setup()

func _build_lights() -> void:
	# the storm's cool light from above, the porch lamp, the windows' warm spill on the yard
	var sky: DirectionalLight3D = DirectionalLight3D.new()
	sky.light_color = Color(0.55, 0.65, 0.90)
	sky.light_energy = 0.40
	root.add_child(sky)
	sky.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	light(Vector3(-110.0, 100.0, 175.0), Color(1.0, 0.78, 0.45), 0.6, 200.0, true)
	for wx in [-90.0, 90.0]:
		light(Vector3(wx, 50.0, 160.0), WARM, 0.45, 180.0)

# --- textures ---------------------------------------------------------------------------------------------------

func _clapboard(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var boards: int = 16
	var bh: int = n / boards
	for y in n:
		var in_board: float = float(y % bh) / float(bh)
		var c: Color = Color(0.92, 0.92, 0.92).lerp(Color(1, 1, 1), in_board) if y % bh != 0 else Color(0.55, 0.55, 0.58)
		img.fill_rect(Rect2i(0, y, n, 1), c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _shingles(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var rows: int = 12
	var rh: int = n / rows
	for r in rows:
		var off: int = (n / 16) if r % 2 == 1 else 0
		for k in 9:
			var x0: int = k * (n / 8) - off
			var c: Color = Color(0.20, 0.17, 0.18).lerp(Color(0.32, 0.26, 0.26), h01(r * 17 + k))
			img.fill_rect(Rect2i(maxi(0, x0), r * rh, mini(n / 8 - 2, n - maxi(0, x0)), rh - 2), c)
			img.fill_rect(Rect2i(maxi(0, x0), r * rh + rh - 3, mini(n / 8 - 2, n - maxi(0, x0)), 2), c.darkened(0.45))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# a gable roof: two sloped planes (shingled) and the two triangular gable ends (clapboard)
func _roof(w: float, d: float, h: float, over: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw: float = w * 0.5 + over
	var hd: float = d * 0.5 + over
	var ridge_l: Vector3 = Vector3(-hw, h, 0.0)
	var ridge_r: Vector3 = Vector3(hw, h, 0.0)
	for side in [-1.0, 1.0]:
		var e_l: Vector3 = Vector3(-hw, -over * 0.6, side * hd)
		var e_r: Vector3 = Vector3(hw, -over * 0.6, side * hd)
		var slope: float = Vector2(hd, h + over * 0.6).length()
		var quad: Array = [[e_l, Vector2(0, slope / 40.0)], [e_r, Vector2(w / 40.0, slope / 40.0)], [ridge_r, Vector2(w / 40.0, 0)],
			[e_l, Vector2(0, slope / 40.0)], [ridge_r, Vector2(w / 40.0, 0)], [ridge_l, Vector2(0, 0)]]
		for q in quad:
			st.set_uv(q[1])
			st.add_vertex(q[0])
	st.generate_normals()
	return st.commit()

func _gable(w: float, h: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [[Vector3(-w * 0.5, 0, 0), Vector2(0, h / 30.0)], [Vector3(w * 0.5, 0, 0), Vector2(w / 30.0, h / 30.0)], [Vector3(0, h, 0), Vector2(w / 60.0, 0)]]:
		st.set_normal(Vector3.BACK)
		st.set_uv(v[1])
		st.add_vertex(v[0])
	return st.commit()

# --- the house and the yard: baked --------------------------------------------------------------------------------

func _window(c: Vector3, w: float, h: float, curtain: Color, yaw: float = 0.0) -> void:
	var pv: Node3D = Node3D.new()
	root.add_child(pv)
	pv.position = c
	pv.rotation_degrees = Vector3(0.0, yaw, 0.0)
	var trim: StandardMaterial3D = mat(TRIM, 0.6)
	box(Vector3(w + 12.0, h + 12.0, 4.0), trim, Vector3(0.0, 0.0, 1.0), Vector3.ZERO, pv)
	box(Vector3(w, h, 1.0), glow(WARM), Vector3(0.0, 0.0, 3.2), Vector3.ZERO, pv)
	# curtains drawn half across, in their color, lit from behind
	for side in [-1.0, 1.0]:
		box(Vector3(w * 0.30, h, 0.6), glow(curtain), Vector3(side * w * 0.35, 0.0, 3.6), Vector3.ZERO, pv)
	box(Vector3(2.5, h, 1.2), trim, Vector3(0.0, 0.0, 4.2), Vector3.ZERO, pv)
	box(Vector3(w, 2.5, 1.2), trim, Vector3(0.0, 0.0, 4.2), Vector3.ZERO, pv)
	box(Vector3(w + 20.0, 4.0, 10.0), trim, Vector3(0.0, -h * 0.5 - 8.0, 5.0), Vector3.ZERO, pv)
	box(Vector3(w + 16.0, 6.0, 6.0), trim, Vector3(0.0, h * 0.5 + 8.0, 3.0), Vector3.ZERO, pv)

func _build_still() -> void:
	var siding: StandardMaterial3D = mat(Color.WHITE, 0.7, 0.0, _clapboard(128), Vector3(4, 4, 1))
	siding.albedo_color = SIDING
	var siding_g: StandardMaterial3D = mat(Color.WHITE, 0.7, 0.0, _clapboard(128))
	siding_g.albedo_color = SIDING
	var shingle: StandardMaterial3D = mat(Color.WHITE, 0.85, 0.0, _shingles(256))
	var trim: StandardMaterial3D = mat(TRIM, 0.6)
	var brick: StandardMaterial3D = mat(Color(0.48, 0.24, 0.18), 0.9)
	var wood: StandardMaterial3D = mat(Color.WHITE, 0.8, 0.0, tex_wood(128, Color(0.36, 0.26, 0.18), 3))
	var grass: StandardMaterial3D = mat(Color.WHITE, 0.95, 0.0, tex_speckle(128, Color(0.12, 0.18, 0.10), 0.18, 9), Vector3(20, 20, 1))
	# the wet yard, out toward the hills
	box(Vector3(6000.0, 4.0, 4000.0), grass, Vector3(0.0, -2.0, -1200.0))
	# THE HOUSE: two stories, the roof, the chimney
	box(Vector3(340.0, 200.0, 220.0), siding, Vector3(0.0, 100.0, 0.0))
	box(Vector3(350.0, 10.0, 230.0), mat(Color(0.30, 0.30, 0.32), 0.9), Vector3(0.0, 4.0, 0.0))
	box(Vector3(344.0, 6.0, 224.0), trim, Vector3(0.0, 103.0, 0.0))
	put(_roof(340.0, 220.0, 110.0, 18.0), shingle, Vector3(0.0, 200.0, 0.0))
	for gz in [-1.0, 1.0]:
		put(_gable(220.0, 110.0), siding_g, Vector3(gz * 170.0, 200.0, 0.0), Vector3(0.0, 90.0 * gz, 0.0))
	# the fascia boards along the eaves, white
	box(Vector3(380.0, 8.0, 6.0), trim, Vector3(0.0, 203.0, 129.0))
	box(Vector3(12.0, 8.0, 6.0), mat(Color(0.35, 0.36, 0.38), 0.5, 0.5), Vector3(0.0, 200.0, 132.0))
	box(Vector3(30.0, 120.0, 30.0), brick, Vector3(95.0, 270.0, -20.0))
	box(Vector3(36.0, 8.0, 36.0), mat(Color(0.32, 0.30, 0.30), 0.8), Vector3(95.0, 332.0, -20.0))
	# the gutter along the front eave, and the downspout down the right front corner: an elbow at its foot onto a
	# concrete splash block, which runs the water to a round cast-iron YARD DRAIN in the lawn
	var zinc: StandardMaterial3D = mat(Color(0.42, 0.44, 0.48), 0.4, 0.6)
	cyl(4.0, 4.0, 360.0, zinc, Vector3(0.0, 198.0, 134.0), Vector3(0.0, 0.0, 90.0))
	cyl(3.5, 3.5, 180.0, zinc, Vector3(162.0, 108.0, 128.0))
	# the elbow: weathered galvanized steel, duller than the new zinc above (as bright metal it caught the windows' warm
	# light and read as a brass nozzle -- with the water a "blow torch", the user, 2026-11-20), its open mouth dark
	# -- and it slopes DOWN from the pipe's foot toward the splash block, as an elbow does (it pointed up and out)
	var galv: StandardMaterial3D = mat(Color(0.46, 0.48, 0.50), 0.62, 0.25)
	var e_rot: Vector3 = _elbow_rot()
	cyl(3.5, 3.5, 22.0, galv, ELBOW_C, e_rot)
	cyl(3.6, 3.6, 2.0, mat(Color(0.30, 0.31, 0.33), 0.6, 0.25), ELBOW_C + _elbow_dir() * 10.0, e_rot)
	cyl(2.9, 2.9, 0.6, mat(Color(0.02, 0.02, 0.03), 1.0), ELBOW_C + _elbow_dir() * 11.2, e_rot)
	for strap in 3:
		box(Vector3(9.0, 2.0, 9.0), zinc, Vector3(162.0, 40.0 + float(strap) * 55.0, 128.0))
	var concrete: StandardMaterial3D = mat(Color.WHITE, 0.8, 0.0, tex_speckle(64, Color(0.52, 0.52, 0.50), 0.10, 4), Vector3(1, 3, 1))
	var block: MeshInstance3D = box(Vector3(30.0, 4.0, 90.0), concrete, Vector3(194.0, 1.5, 174.0), Vector3(0.0, 38.0, 0.0))
	block.scale = Vector3.ONE
	for e in [-1.0, 1.0]:
		var lip: MeshInstance3D = box(Vector3(4.0, 6.0, 90.0), concrete, Vector3(194.0, 3.0, 174.0) + Vector3(e * 13.0, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(38.0)), Vector3(0.0, 38.0, 0.0))
		lip.scale = Vector3.ONE
	var iron: StandardMaterial3D = mat(Color(0.12, 0.12, 0.13), 0.5, 0.6)
	cyl(26.0, 26.0, 3.0, concrete, DRAIN + Vector3(0.0, 1.2, 0.0), Vector3.ZERO, null, 32)
	cyl(19.0, 19.0, 3.2, mat(Color(0.02, 0.02, 0.03), 1.0), DRAIN + Vector3(0.0, 1.4, 0.0), Vector3.ZERO, null, 32)
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 17.0
	ring.outer_radius = 20.0
	put(ring, iron, DRAIN + Vector3(0.0, 3.0, 0.0))
	for gb in 7:
		box(Vector3(2.2, 2.0, 36.0 * sqrt(1.0 - pow((float(gb) - 3.0) / 3.6, 2.0))), iron, DRAIN + Vector3(-13.5 + float(gb) * 4.5, 3.0, 0.0))
	box(Vector3(36.0, 2.0, 2.2), iron, DRAIN + Vector3(0.0, 3.1, 0.0))
	# the bucket by the porch steps, catching the porch roof's drips
	cyl(13.0, 10.5, 24.0, mat(Color(0.50, 0.52, 0.56), 0.35, 0.7), Vector3(-6.0, 12.0, 196.0), Vector3.ZERO, null, 24)
	var handle: TorusMesh = TorusMesh.new()
	handle.inner_radius = 12.0
	handle.outer_radius = 13.0
	put(handle, zinc, Vector3(-6.0, 24.0, 196.0), Vector3(0.0, 0.0, 70.0))
	cyl(12.0, 12.0, 0.6, mat(Color(0.10, 0.14, 0.20), 0.05, 0.3), Vector3(-6.0, 20.0, 196.0), Vector3.ZERO, null, 24)
	# a FOUNDATION of rough stone under the siding, the side wall's windows and shutters
	box(Vector3(348.0, 14.0, 228.0), mat(Color.WHITE, 0.9, 0.0, tex_speckle(64, Color(0.40, 0.38, 0.36), 0.18, 12, 4, Color(0.25, 0.24, 0.23)), Vector3(8, 1, 1)), Vector3(0.0, 7.0, 0.0))
	_window(Vector3(-171.0, 150.0, 30.0), 50.0, 60.0, Color(0.55, 0.62, 0.45), -90.0)
	_window(Vector3(-171.0, 58.0, -40.0), 50.0, 60.0, Color(0.70, 0.40, 0.30), -90.0)
	for shz in [-1.0, 1.0]:
		box(Vector3(3.0, 62.0, 22.0), mat(Color(0.22, 0.32, 0.26), 0.6), Vector3(-173.0, 150.0, 30.0 + shz * 40.0))
	# a rain barrel at the side wall's back corner
	cyl(22.0, 20.0, 50.0, mat(Color.WHITE, 0.8, 0.0, tex_wood(64, Color(0.34, 0.22, 0.12), 8), Vector3(4, 1, 1)), Vector3(-200.0, 25.0, -80.0), Vector3.ZERO, null, 24)
	for hb in [8.0, 42.0]:
		cyl(22.6, 22.6, 3.0, iron, Vector3(-200.0, hb, -80.0), Vector3.ZERO, null, 24)
	# THE WINDOWS: two up, one down beside the door
	_window(Vector3(-90.0, 150.0, 110.0), 56.0, 62.0, Color(0.70, 0.40, 0.30))
	_window(Vector3(90.0, 150.0, 110.0), 56.0, 62.0, Color(0.60, 0.50, 0.70))
	_window(Vector3(90.0, 58.0, 110.0), 64.0, 66.0, Color(0.72, 0.56, 0.30))
	# THE DOOR, under the porch
	box(Vector3(46.0, 86.0, 3.0), mat(Color(0.30, 0.12, 0.10), 0.5), Vector3(-90.0, 47.0, 111.5))
	box(Vector3(56.0, 94.0, 2.0), trim, Vector3(-90.0, 49.0, 110.5))
	sphere(2.5, mat(Color(0.85, 0.70, 0.35), 0.3, 0.7), Vector3(-75.0, 46.0, 114.0))
	box(Vector3(30.0, 12.0, 1.0), glow(WARM), Vector3(-90.0, 84.0, 113.5))
	# THE PORCH: a floor, steps, four posts and a sloping roof, the lamp by the door
	box(Vector3(160.0, 12.0, 70.0), wood, Vector3(-90.0, 14.0, 146.0))
	for st in 2:
		box(Vector3(60.0, 7.0, 14.0), wood, Vector3(-90.0, 4.0 + 3.5 * float(1 - st), 188.0 + float(st) * 12.0))
	for px in [-164.0, -16.0]:
		box(Vector3(8.0, 98.0, 8.0), trim, Vector3(px, 69.0, 178.0))
	box(Vector3(176.0, 5.0, 86.0), shingle, Vector3(-90.0, 122.0, 150.0), Vector3(14.0, 0.0, 0.0))
	box(Vector3(168.0, 6.0, 4.0), trim, Vector3(-90.0, 116.0, 191.0))
	cyl(4.0, 5.0, 12.0, mat(Color(0.12, 0.12, 0.12), 0.4, 0.6), Vector3(-130.0, 92.0, 114.0))
	sphere(5.0, glow(Color(1.0, 0.86, 0.55)), Vector3(-130.0, 86.0, 116.0))
	# the stepping stones to the porch, the picket fence, the bare tree bent by the wind
	for k in 5:
		var sp: MeshInstance3D = cyl(16.0, 16.0, 3.0, mat(Color(0.40, 0.40, 0.42), 0.4), Vector3(-90.0 + 8.0 * sin(float(k)), 1.0, 230.0 + float(k) * 40.0))
		sp.scale = Vector3(1.0, 1.0, 0.7)
	# THE PICKET FENCE closes the yard all the way round (the user: a run across the front that stopped in the grass
	# meant nothing -- it must go side to side or close an area): front, both sides and the back, a gate on the path
	var picket: StandardMaterial3D = mat(Color.WHITE, 0.7, 0.0, tex_wood(64, Color(0.86, 0.86, 0.83), 4), Vector3(1, 3, 1))
	var corners: Array = [Vector3(-330.0, 0.0, 330.0), Vector3(370.0, 0.0, 330.0), Vector3(370.0, 0.0, -250.0), Vector3(-330.0, 0.0, -250.0)]
	for side in 4:
		_fence_run(corners[side], corners[(side + 1) % 4], picket, -90.0 if side == 0 else 1e9)
	var bark: StandardMaterial3D = mat(Color(0.16, 0.12, 0.10), 0.9)
	# at the right of the house, bent away from the wind
	var trunk: PackedVector3Array = PackedVector3Array([Vector3(290.0, 0.0, 60.0), Vector3(286.0, 110.0, 60.0), Vector3(262.0, 220.0, 55.0), Vector3(222.0, 300.0, 50.0)])
	put(tube_mesh(trunk, 11.0, 12), bark, Vector3.ZERO)
	for b in 7:
		var root_p: Vector3 = trunk[1 + b % 3]
		var tip: Vector3 = root_p + Vector3(-60.0 - 50.0 * h01(b), 50.0 + 60.0 * h01(b + 4), (h01(b + 9) - 0.5) * 80.0)
		put(tube_mesh(PackedVector3Array([root_p, root_p.lerp(tip, 0.5) + Vector3(0, 12, 0), tip]), 3.5 - 0.3 * float(b % 3), 8), bark, Vector3.ZERO)
	# puddles: dark glossy pools
	for pp in PUDDLES:
		var pm: MeshInstance3D = cyl(40.0, 40.0, 0.6, mat(Color(0.05, 0.06, 0.09), 0.05, 0.3), (pp as Vector3) + Vector3(0.0, 0.6, 0.0))
		pm.scale = Vector3(1.4, 1.0, 0.6)

# one straight run of picket fence from a to b: a capped post at each end and every 120 or so, two rails, pickets
# between; on the path (gate_x) a gate of pickets on a Z-brace between taller posts
func _fence_run(a: Vector3, b: Vector3, picket: StandardMaterial3D, gate_x: float) -> void:
	var along: Vector3 = (b - a).normalized()
	var length: float = a.distance_to(b)
	var yaw: float = atan2(-along.z, along.x)
	var rot: Vector3 = Vector3(0.0, rad_to_deg(yaw), 0.0)
	var posts: int = maxi(1, int(round(length / 120.0)))
	for pk in posts + 1:
		var pp: Vector3 = a + along * length * float(pk) / float(posts)
		box(Vector3(9.0, 62.0, 9.0), picket, pp + Vector3(0.0, 31.0, 0.0), rot)
		box(Vector3(13.0, 4.0, 13.0), picket, pp + Vector3(0.0, 63.0, 0.0), rot)
	for ry in [16.0, 40.0]:
		box(Vector3(length, 5.0, 3.0), picket, (a + b) * 0.5 + Vector3(0.0, ry, 0.0) - Vector3(along.z, 0.0, -along.x) * 2.5, rot)
	var n: int = int(length / 24.0)
	for k in n:
		var fp: Vector3 = a + along * (12.0 + float(k) * length / float(n))
		var gate: bool = absf(fp.x - gate_x) < 40.0
		var lean: float = (h01(int(fp.x * 3.0 + fp.z)) - 0.5) * 3.0
		var hgt: float = 50.0 + 4.0 * h01(int(fp.x + fp.z * 7.0)) - (4.0 if gate else 0.0)
		box(Vector3(8.0, hgt, 2.6), picket, fp + Vector3(0.0, hgt * 0.5, 0.0), rot + Vector3(0.0, 0.0, lean))
		put(_gable(8.0, 6.0), picket, fp + Vector3(0.0, hgt, 0.0) + Vector3(along.z, 0.0, -along.x) * -1.5, rot)
	if gate_x < 1e8:
		var gc: Vector3 = Vector3(gate_x, 0.0, a.z)
		for gp in [-42.0, 42.0]:
			box(Vector3(11.0, 70.0, 11.0), picket, gc + Vector3(gp, 35.0, 0.0))
			sphere(6.5, picket, gc + Vector3(gp, 74.0, 0.0))
		box(Vector3(90.0, 5.0, 3.0), picket, gc + Vector3(0.0, 30.0, 2.0), Vector3(0.0, 0.0, 22.0))

# --- live: the loose shutter, the figure behind the curtain ---------------------------------------------------------

func _build_live() -> void:
	# THE LOOSE SHUTTER by the upper left window, hinged on its outer edge, swinging in the gusts
	_shutter = Node3D.new()
	root.add_child(_shutter)
	_shutter.position = Vector3(-90.0 - 28.0 - 8.0 - 30.0, 150.0, 114.0)
	box(Vector3(28.0, 64.0, 3.0), mat(Color(0.22, 0.32, 0.26), 0.6), Vector3(14.0, 0.0, 0.0), Vector3.ZERO, _shutter)
	for k in 5:
		box(Vector3(24.0, 2.0, 1.0), mat(Color(0.16, 0.24, 0.20), 0.6), Vector3(14.0, -24.0 + float(k) * 12.0, 2.0), Vector3.ZERO, _shutter)
	# the fixed shutter on the window's other side
	box(Vector3(28.0, 64.0, 3.0), mat(Color(0.22, 0.32, 0.26), 0.6), Vector3(-90.0 + 28.0 + 8.0 + 16.0, 150.0, 113.0))

func _animate(_delta: float) -> void:
	if _shutter == null:
		return
	if t >= _next_bolt:
		_bolt_at = t
		_next_bolt = t + _rng.randf_range(4.5, 8.0)
		_make_bolt()
		_thunder_at = t + _rng.randf_range(0.1, 0.5)
	if _thunder_at > 0.0 and t >= _thunder_at:
		_thunder_at = -1.0
		_thunder()
	# the shutter: blown open and banged back, eased (never a jump)
	var gust: float = _wind()
	_shutter.rotation_degrees = Vector3(0.0, -(35.0 + 40.0 * gust) * (0.5 + 0.5 * sin(t * 1.3 + sin(t * 0.7) * 1.5)), 0.0)

# --- the weather, in 2-D ----------------------------------------------------------------------------------------------

# THE THUNDER after each bolt (the user, 2026-11-19): the game's own recorded rolls, 0.1-0.5 s after the flash (the
# user: "max 0.5s"), exactly as loud as in the game (the user: menu sounds are never quieter); through the game's sound
# registry (mute, focus, stop_all_sounds), two players in turn so a new roll never cuts one still rumbling. Only from
# the menu on the screen -- never from the off-screen copy that prepares a poster's shaders (prep_card.gd), nor a
# bake -- and a roll still rumbling stops when the menu closes.
var _thunder_at: float = -1.0
var _thunder_turn: bool = false
var _thunder_ready: bool = false

func _thunder() -> void:
	if bake_mode or not is_visible_in_tree() or get_viewport().get_parent() is ShaderWarmer:
		return
	var g: GenericGameUtil = StormG.game
	if g == null:
		return
	if not _thunder_ready:
		_thunder_ready = true
		# (not thunder_3: 24 s long, its player would be taken for the next roll but one -- a bolt every 4.5-8 s, two
		# players in turn -- and cut off mid-rumble; these three, 6.3-8.1 s, always end first)
		var rolls: Array = [load("res://art/sounds/thunder_1.ogg"), load("res://art/sounds/thunder_2.ogg"),
			load("res://art/sounds/thunder_4.ogg")]
		for nm in ["menu_thunder", "menu_thunder2"]:
			g.add_sound(self, nm, rolls)
	_thunder_turn = not _thunder_turn
	g.play_sound("menu_thunder2" if _thunder_turn else "menu_thunder")

func _shown_changed(shown: bool) -> void:
	super._shown_changed(shown)
	if not shown and _thunder_ready and StormG.game != null:
		StormG.game.stop_sound("menu_thunder")
		StormG.game.stop_sound("menu_thunder2")
	_thunder_at = -1.0

func _flash() -> float:
	var u: float = t - _bolt_at
	if u < 0.0 or u > 0.9:
		return 0.0
	var g: float = 0.0
	for sk in _strokes:
		var du: float = u - float(sk)
		if du >= 0.0:
			g = maxf(g, exp(-du * 12.0) * (1.0 if float(sk) == 0.0 else 0.75))
	return g

func _wind() -> float:
	return 0.6 + 0.4 * sin(t * 0.7) * sin(t * 0.31 + 1.0)

func _horizon() -> float:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	if _cam3 == null:
		return full.y * 0.45
	return screen_of(Vector3(0.0, 0.0, -3000.0)).y

# A BOLT (the user: "the lightning is too simplistic"): the main channel from the cloud base down to the hills, its
# path split again and again with sideways jitter (midpoint displacement) so it is jagged at every scale; branches
# breaking off it, forking again, thinner and fading; each a [points, width, strength]
func _bolt_path(a: Vector2, b: Vector2, rough: float, depth: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array([a, b])
	var r: float = rough
	for _d in depth:
		var nxt: PackedVector2Array = PackedVector2Array()
		for i in pts.size() - 1:
			var p0: Vector2 = pts[i]
			var p1: Vector2 = pts[i + 1]
			var mid: Vector2 = (p0 + p1) * 0.5
			var nrm: Vector2 = (p1 - p0).orthogonal().normalized()
			nxt.append(p0)
			nxt.append(mid + nrm * _rng.randf_range(-r, r))
		nxt.append(pts[pts.size() - 1])
		pts = nxt
		r *= 0.55
	return pts

func _make_bolt() -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var top: Vector2 = Vector2(full.x * _rng.randf_range(0.15, 0.85), full.y * 0.07)
	var end: Vector2 = Vector2(top.x + _rng.randf_range(-120.0, 120.0), _horizon() - 6.0)
	var main: PackedVector2Array = _bolt_path(top, end, 60.0, 7)
	_bolt = [[main, 2.6, 1.0]]
	_bolt_top = top
	for _b in _rng.randi_range(4, 7):
		var at: int = _rng.randi_range(int(main.size() * 0.1), int(main.size() * 0.75))
		var p: Vector2 = main[at]
		var d: Vector2 = (main[mini(at + 4, main.size() - 1)] - p).normalized().rotated(_rng.randf_range(0.5, 1.0) * (1.0 if _rng.randf() < 0.5 else -1.0))
		var length: float = _rng.randf_range(50.0, 150.0)
		var br: PackedVector2Array = _bolt_path(p, p + d * length, length * 0.25, 5)
		_bolt.append([br, 1.3, 0.7])
		if _rng.randf() < 0.6:
			var at2: int = _rng.randi_range(2, br.size() - 3)
			var q: Vector2 = br[at2]
			var d2: Vector2 = d.rotated(_rng.randf_range(-0.9, 0.9))
			_bolt.append([_bolt_path(q, q + d2 * length * 0.45, length * 0.12, 4), 0.8, 0.45])
	# and two or three return strokes in quick succession, each re-lighting the channel
	_strokes = [0.0, _rng.randf_range(0.08, 0.14), _rng.randf_range(0.22, 0.32)]

var _bolt_top: Vector2 = Vector2.ZERO
var _strokes: Array = [0.0]

# how bright the channel is now: a sharp flash at each return stroke, fading fast
func _bolt_glow() -> float:
	var u: float = t - _bolt_at
	var g: float = 0.0
	for sk in _strokes:
		var du: float = u - float(sk)
		if du >= 0.0:
			g = maxf(g, exp(-du * 18.0))
	return g if u < 0.8 else 0.0

# a soft round blob of light or cloud (one smooth falloff texture, tinted)
var _blob: Texture2D = null

func _soft(at: Vector2, r: float, col: Color, squash: float = 1.0) -> void:
	if _blob == null:
		var gt: GradientTexture2D = GradientTexture2D.new()
		gt.width = 128
		gt.height = 128
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		gt.gradient = g
		_blob = gt
	cv.draw_texture_rect(_blob, Rect2(at - Vector2(r, r * squash), Vector2(r * 2.0, r * 2.0 * squash)), false, col)

func _rain(drops: Array, full: Vector2, floor_y: float, col: Color, length: float, speed: float) -> void:
	var slant: Vector2 = Vector2(-0.22 - 0.12 * _wind(), 1.0).normalized()
	for d in drops:
		var y: float = fmod(float(d[1]) * floor_y + t * speed * float(d[2]), floor_y + 60.0) - 40.0
		var x: float = float(d[0]) * (full.x + 160.0) + y * slant.x / slant.y + 60.0
		cv.draw_line(Vector2(x, y), Vector2(x, y) + slant * length * float(d[3]), col, 1.5)

# THE SKY behind the house: clouds drifting (lit beneath in a flash), the bolt, the far rain, the hills
func _paint(full: Vector2, _bottom: float) -> void:
	if bake_mode:
		return
	var fl: float = _flash()
	var horizon: float = _horizon()
	var top_c: Color = Color(0.03, 0.05, 0.11).lerp(Color(0.55, 0.62, 0.80), fl * 0.6)
	var hor_c: Color = Color(0.12, 0.17, 0.27).lerp(Color(0.78, 0.82, 0.94), fl * 0.6)
	vgrad(Rect2(0.0, 0.0, full.x, horizon + 4.0), top_c, hor_c)
	# THE CLOUDS: banks of soft billows in three layers drifting at their own speeds, darker above and paler
	# beneath; in a flash the bank round the bolt's head lights up from inside
	var bg: float = _bolt_glow()
	for cl in 3:
		var speed: float = 4.0 + 5.0 * float(cl)
		var cy0: float = full.y * (0.03 + 0.07 * float(cl))
		for k in 8:
			var cx: float = fmod(float(k) * 130.0 + float(cl) * 70.0 + t * speed, full.x + 300.0) - 150.0
			var cy: float = cy0 + 34.0 * h01(k + cl * 10)
			for j in 6:
				var pc: Vector2 = Vector2(cx + float(j) * 34.0 - 85.0, cy + 18.0 * sin(float(j * 3 + k)) - 8.0 * float(j % 2))
				var rr: float = 62.0 + 26.0 * h01(k * 5 + j + cl * 31)
				var near_bolt: float = clampf(1.0 - pc.distance_to(_bolt_top) / 300.0, 0.0, 1.0)
				var body: Color = Color(0.07, 0.09, 0.15).lerp(Color(0.13, 0.15, 0.22), float(cl) * 0.5)
				body = body.lerp(Color(0.62, 0.66, 0.86), fl * 0.45 + bg * near_bolt * 0.6)
				_soft(pc, rr, Color(body, 0.55), 0.62)
				_soft(pc + Vector2(0.0, rr * 0.28), rr * 0.8, Color(Color(0.20, 0.24, 0.36).lerp(Color(0.80, 0.84, 1.0), fl * 0.5 + bg * near_bolt), 0.18 + 0.3 * fl), 0.45)
	if bg > 0.02:
		_soft(_bolt_top, 260.0, Color(0.75, 0.80, 1.0, 0.55 * bg), 0.55)
		for br in _bolt:
			var line: PackedVector2Array = br[0]
			var w: float = float(br[1])
			var a2: float = float(br[2]) * bg
			cv.draw_polyline(line, Color(0.55, 0.62, 1.0, 0.10 * a2), w * 9.0, true)
			cv.draw_polyline(line, Color(0.75, 0.82, 1.0, 0.35 * a2), w * 3.2, true)
			cv.draw_polyline(line, Color(1.0, 1.0, 1.0, minf(1.0, 1.4 * a2)), w, true)
	_rain(_far, full, horizon + 30.0, Color(0.60, 0.70, 0.88, 0.22), 16.0, 600.0)
	var hills: PackedVector2Array = PackedVector2Array([Vector2(0.0, full.y)])
	for k3 in 25:
		var x: float = full.x * float(k3) / 24.0
		hills.append(Vector2(x, horizon + 2.0 - 26.0 * sin(float(k3) * 0.55 + 1.0) - 10.0 * sin(float(k3) * 1.7)))
	hills.append(Vector2(full.x, full.y))
	cv.draw_colored_polygon(hills, Color(0.05, 0.07, 0.10).lerp(Color(0.35, 0.40, 0.48), fl * 0.5))

# THE ELBOW at the downspout's foot: from the pipe's bottom (162, 18, 128) out and down toward the splash block; its
# center and the way its mouth points (its cylinder's +y end)
const ELBOW_C: Vector3 = Vector3(166.5, 13.5, 135.0)
const ELBOW_TO: Vector3 = Vector3(0.42, -0.40, 0.81)

func _elbow_dir() -> Vector3:
	return ELBOW_TO.normalized()

# the turn (degrees, as cyl() takes it) that stands a cylinder's axis along the elbow
func _elbow_rot() -> Vector3:
	var e: Vector3 = Basis(Quaternion(Vector3.UP, _elbow_dir())).get_euler()
	return Vector3(rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z))

# THE WATER OUT OF THE DOWNSPOUT: a stream leaving the elbow's mouth along its axis and falling under its weight onto
# the splash block -- a translucent band widening a little as it falls, a brighter core, streaks running down it -- a
# patch of foam where it lands, and droplets thrown out and falling back (it was seven short white streaks in a tight
# cone off a bright elbow: "a bunsen blow torch instead of water", the user, 2026-11-20)
func _spout_water(fl: float) -> void:
	var dir: Vector3 = _elbow_dir()
	var mouth: Vector3 = ELBOW_C + dir * 11.0
	var v0: Vector3 = dir * 10.0
	# the stream: p(u) = mouth + v0 u - (0, g u^2) until it meets the block's top (y 4)
	var pts: Array = []
	var land: Vector3 = mouth
	for k in 17:
		var u: float = float(k) / 16.0 * 1.6
		var p: Vector3 = mouth + v0 * u - Vector3(0.0, 8.5 * u * u, 0.0)
		if p.y <= 4.0:
			p.y = 4.0
			pts.append(p)
			land = p
			break
		pts.append(p)
		land = p
	var line: PackedVector2Array = PackedVector2Array()
	for p2 in pts:
		line.append(screen_of(p2))
	var sc: float = screen_of(mouth + Vector3(4.0, 0.0, 0.0)).distance_to(screen_of(mouth)) / 4.0
	var water: Color = Color(0.62, 0.70, 0.80).lerp(Color(0.85, 0.90, 1.0), fl * 0.6)
	if line.size() >= 2:
		cv.draw_polyline(line, Color(water, 0.30), 5.5 * sc, true)
		cv.draw_polyline(line, Color(water.lightened(0.25), 0.40), 2.4 * sc, true)
		# streaks running down the stream
		for k2 in 4:
			var su: float = fposmod(t * 3.2 + float(k2) / 4.0, 1.0)
			var i0: int = clampi(int(su * float(line.size() - 1)), 0, line.size() - 2)
			var a: Vector2 = line[i0].lerp(line[i0 + 1], fposmod(su * float(line.size() - 1), 1.0))
			var b: Vector2 = a + (line[i0 + 1] - line[i0]).normalized() * 3.0 * sc
			cv.draw_line(a, b, Color(0.92, 0.96, 1.0, 0.55), 1.2 * sc, true)
	# where it lands: a patch of foam on the block, breathing
	var lp: Vector2 = screen_of(land)
	_soft(lp, (5.0 + 0.8 * sin(t * 9.0)) * sc, Color(0.85, 0.90, 0.98, 0.35), 0.45)
	# droplets thrown out of the landing and falling back
	for k3 in 6:
		var du: float = fposmod(t * 1.9 + h01(k3 + 60), 1.0)
		var ang: float = TAU * h01(k3 + 70)
		var out: Vector3 = Vector3(cos(ang), 0.0, sin(ang)) * (2.0 + 4.0 * h01(k3 + 80))
		var dp: Vector3 = land + out * du + Vector3(0.0, 5.0 * du - 5.5 * du * du, 0.0)
		cv.draw_circle(screen_of(dp), 0.7 * sc, Color(0.88, 0.94, 1.0, 0.6 * (1.0 - du)))

# OVER THE SCENE: the gutter's drips, the downspout gushing, the chimney's smoke, rings in the puddles, the near rain,
# leaves, and the flash whitening everything
func _paint_top(full: Vector2, bottom: float) -> void:
	var fl: float = _flash()
	if _cam3 != null:
		# smoke from the chimney, torn sideways by the wind
		var ch: Vector2 = screen_of(CHIMNEY + Vector3(0.0, 8.0, 0.0))
		for k in 9:
			var su: float = fposmod(t * 0.35 + float(k) / 9.0, 1.0)
			var sp: Vector2 = ch + Vector2(-su * 140.0 * _wind() - 10.0 * su, -su * 50.0 + 8.0 * sin(t + float(k)))
			cv.draw_circle(sp, 6.0 + su * 22.0, Color(0.55, 0.58, 0.64, 0.16 * sin(su * PI)))
		# the gutter overflowing: drips falling from along the eave
		var e0: Vector2 = screen_of(EAVE_L)
		var e1: Vector2 = screen_of(EAVE_R)
		var floor_y: float = screen_of(Vector3(0.0, 0.0, 130.0)).y
		for k2 in 16:
			var ex: Vector2 = e0.lerp(e1, (float(k2) + 0.5) / 16.0)
			var du: float = fposmod(t * 1.3 + h01(k2 + 30), 1.0)
			var dy: Vector2 = ex + Vector2(0.0, (floor_y - ex.y) * du * du)
			cv.draw_line(dy, dy + Vector2(0.0, 6.0), Color(0.75, 0.85, 1.0, 0.55), 1.4)
		# the downspout pouring out of its elbow onto the splash block, the water running down it and swirling
		# into the yard drain
		_spout_water(fl)
		var run_a: Vector3 = Vector3(172.0, 4.2, 140.0)
		var run_b: Vector3 = DRAIN + Vector3(-14.0, 4.0, -12.0)
		for k6 in 14:
			var ru2: float = fposmod(t * 0.9 + float(k6) / 14.0, 1.0)
			var w0: Vector3 = run_a.lerp(run_b, ru2) + Vector3(sin(float(k6) * 2.1) * 5.0, 0.0, 0.0)
			var w1: Vector3 = run_a.lerp(run_b, minf(1.0, ru2 + 0.06)) + Vector3(sin(float(k6) * 2.1) * 5.0, 0.0, 0.0)
			cv.draw_line(screen_of(w0), screen_of(w1), Color(0.78, 0.86, 1.0, 0.55 * sin(ru2 * PI)), 1.6, true)
		var dc: Vector2 = screen_of(DRAIN + Vector3(0.0, 3.5, 0.0))
		var dsc: float = screen_of(DRAIN + Vector3(20.0, 3.5, 0.0)).distance_to(dc) / 20.0
		cv.draw_set_transform(dc, 0.0, Vector2(1.0, 0.42))
		for k7 in 4:
			var a0: float = t * 3.0 + float(k7) * TAU / 4.0
			cv.draw_arc(Vector2.ZERO, (8.0 + 4.0 * float(k7 % 2)) * dsc, a0, a0 + 1.6, 10, Color(0.80, 0.88, 1.0, 0.45), 1.3, true)
		cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# DRIPS off the porch roof's corner into the bucket: a bead swells at the eave's edge, lets go, falls ever faster
		# (a streak as long as its speed), and lands with a ring and a little crown of droplets -- at uneven beats
		var drip0: Vector3 = Vector3(-6.0, 113.0, 193.0)
		var bucket_w: Vector3 = Vector3(-6.0, 21.0, 196.0)
		var eave: Vector2 = screen_of(drip0)
		var bw: Vector2 = screen_of(bucket_w)
		var bsc: float = screen_of(bucket_w + Vector3(12.0, 0.0, 0.0)).distance_to(bw) / 12.0
		var fall_px: float = bw.y - eave.y
		for k8 in 2:
			var period: float = 1.3 + 0.4 * float(k8)
			var ph: float = fposmod(t + float(k8) * 0.71, period) / period
			var off: Vector2 = Vector2((float(k8) - 0.5) * 7.0 * bsc, 0.0)
			var grow_end: float = 0.62
			if ph < grow_end:
				# the bead swelling under the edge
				var gr: float = ph / grow_end
				cv.draw_circle(eave + off + Vector2(0.0, 1.2 * gr * bsc), (0.6 + 1.3 * gr) * bsc, Color(0.85, 0.92, 1.0, 0.75))
			else:
				var fu: float = (ph - grow_end) / (1.0 - grow_end)
				if fu < 0.55:
					var ff: float = fu / 0.55
					var y: float = fall_px * ff * ff
					var streak: float = maxf(2.0, 16.0 * ff * bsc)
					var head: Vector2 = eave + off + Vector2(0.0, y)
					cv.draw_line(head - Vector2(0.0, streak), head, Color(0.82, 0.90, 1.0, 0.25), 1.2 * bsc, true)
					cv.draw_circle(head, 1.3 * bsc, Color(0.88, 0.94, 1.0, 0.85))
				else:
					# the landing: a ring spreading on the water, a crown of droplets thrown up and falling back
					var su: float = (fu - 0.55) / 0.45
					var hit: Vector2 = bw + off * 0.6
					cv.draw_set_transform(hit, 0.0, Vector2(1.0, 0.38))
					cv.draw_arc(Vector2.ZERO, (2.0 + 9.0 * su) * bsc, 0.0, TAU, 20, Color(0.85, 0.92, 1.0, 0.55 * (1.0 - su)), 1.0, true)
					cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
					for cr in 5:
						var ca: float = PI * (0.15 + 0.7 * float(cr) / 4.0)
						var cvx: float = -cos(ca) * 9.0 * bsc
						var cvy: float = -sin(ca) * 13.0 * bsc
						var cp: Vector2 = hit + Vector2(cvx * su, cvy * su + 30.0 * bsc * su * su)
						if su < 0.6:
							cv.draw_circle(cp, 0.8 * bsc, Color(0.88, 0.94, 1.0, 0.7 * (1.0 - su / 0.6)))
		_shadow_figure()
		# rings spreading in the puddles
		for pp in PUDDLES:
			var pc: Vector2 = screen_of(pp)
			var sc: float = screen_of((pp as Vector3) + Vector3(40.0, 0.0, 0.0)).distance_to(pc) / 40.0
			for k4 in 3:
				var ru: float = fposmod(t * 0.8 + float(k4) / 3.0 + h01(int(pc.x)), 1.0)
				cv.draw_set_transform(pc + Vector2((h01(k4 + int(pc.y)) - 0.5) * 50.0 * sc, 0.0), 0.0, Vector2(1.0, 0.4))
				cv.draw_arc(Vector2.ZERO, ru * 20.0 * sc, 0.0, TAU, 20, Color(0.75, 0.85, 1.0, 0.35 * (1.0 - ru)), 1.2)
			cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_rain(_near, full, bottom + 40.0, Color(0.72, 0.82, 0.96, 0.42), 28.0, 950.0)
	for k5 in LEAVES:
		var lu: float = fmod(t * (0.12 + 0.06 * h01(k5)) + h01(k5 + 40), 1.0)
		var lp: Vector2 = Vector2(full.x * (1.1 - 1.3 * lu), bottom * (0.35 + 0.5 * h01(k5 + 80)) + sin(lu * 9.0 + float(k5)) * 30.0)
		var a: float = lu * 18.0 + float(k5)
		cv.draw_set_transform(lp, a, Vector2(1.0, 0.45 + 0.4 * absf(sin(a))))
		cv.draw_circle(Vector2.ZERO, 5.0, Color(0.55, 0.42, 0.16, 0.85))
		cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the flash: the whole scene whitened for a moment
	if fl > 0.02:
		cv.draw_rect(Rect2(Vector2.ZERO, full), Color(0.80, 0.86, 1.0, 0.28 * fl))
	title("STORM", "Save your house from the storm", Color(0.80, 0.90, 1.0).lerp(Color.WHITE, fl), Color(0.02, 0.04, 0.10),
		Color(0.35, 0.55, 1.0, 0.18 + 0.35 * fl), null, 86, Color(0.88, 0.92, 1.0))

# SOMEONE INSIDE (the user: "that person is very childishly drawn" -- a box and a ball behind the glass): now only
# their SHADOW, soft, thrown on the lit curtain of the lower right window by the lamp inside -- a head, the neck and
# shoulders, an arm hanging with a bucket from it -- moving across now and then, cut off at the window's frame
# the body (head, neck, shoulders, the torso down past the sill); the arm and the bucket are drawn apart, hung from
# the shoulder, so they can swing
const SIL: Array = [Vector2(0.00, -0.92), Vector2(0.10, -0.88), Vector2(0.13, -0.76), Vector2(0.09, -0.62), Vector2(0.07, -0.56),
	Vector2(0.24, -0.48), Vector2(0.30, -0.36), Vector2(0.28, 0.10), Vector2(0.22, 1.10), Vector2(-0.22, 1.10), Vector2(-0.25, 0.05),
	Vector2(-0.30, -0.36), Vector2(-0.24, -0.48), Vector2(-0.07, -0.56), Vector2(-0.09, -0.62), Vector2(-0.13, -0.76), Vector2(-0.10, -0.88)]
const SHOULDER: Vector2 = Vector2(0.27, -0.40)
const WALK_SPEED: float = 0.55     # window half-widths a second: an unhurried walk
const STEP: float = 0.34           # how far one step carries them

# where they are at time u of the 12 s round, and how fast they are going: in from the left at a walking pace
# (setting off and stopping over half a second each), a stop at the center to set the bucket's weight, on and out
func _walk_x(u: float) -> float:
	var legs: Array = [[0.5, -1.6, -0.15], [4.6, -0.15, 1.6], [7.0, 1.6, -1.6]]
	var x: float = -1.6
	for leg in legs:
		var t0: float = float(leg[0])
		var dur: float = absf(float(leg[2]) - float(leg[1])) / WALK_SPEED + 0.5
		if u >= t0:
			var k: float = clampf((u - t0) / dur, 0.0, 1.0)
			# constant pace with eased ends: the distance is the integral of a trapezoid of speed (peak v, ramps r)
			var r: float = 0.5 / dur
			var v: float = 1.0 / (1.0 - r)
			var dist: float = v * (0.5 * r + (k - r))
			if k < r:
				dist = v * k * k / (2.0 * r)
			elif k > 1.0 - r:
				dist = 1.0 - v * (1.0 - k) * (1.0 - k) / (2.0 * r)
			x = lerpf(float(leg[1]), float(leg[2]), dist)
	return x

func _shadow_figure() -> void:
	# THE WALK, read from the travel itself: the steps' phase is the distance walked, so the bob, the sway and the
	# bucket's swing come and go with the pace and never run while they stand
	var u: float = fmod(t, 12.0)
	var x: float = _walk_x(u)
	var x2: float = _walk_x(fmod(u + 0.05, 12.0))
	var vel: float = clampf((x2 - x) / 0.05 / WALK_SPEED, -1.0, 1.0) if u < 11.9 else 0.0
	var walked: float = 0.0
	var probe: float = 0.0
	while probe < u:
		var xa: float = _walk_x(probe)
		probe += 0.1
		walked += absf(_walk_x(minf(probe, u)) - xa)
	var phase: float = walked / STEP * PI
	var pace: float = absf(vel)
	var facing: float = 1.0 if vel >= 0.0 else -1.0
	var bob: float = -0.035 * absf(sin(phase)) * pace
	var lean: float = 0.05 * vel
	var sway: float = 0.03 * sin(phase) * pace
	# the bucket: a pendulum hung from the shoulder, swinging with the steps and lagging them, settling when they stop
	var swing: float = (0.22 * sin(phase - 0.9) * pace) - 0.10 * vel
	var wc: Vector3 = Vector3(90.0, 58.0, 113.7)
	var hw: float = 32.0
	var hh: float = 33.0
	var o: Vector2 = screen_of(wc)
	var ax: Vector2 = screen_of(wc + Vector3(hw, 0.0, 0.0)) - o
	var ay: Vector2 = screen_of(wc + Vector3(0.0, -hh, 0.0)) - o
	# the four PANES between the cross bars (2.5 wide): the shadow is on the curtain BEHIND the glass, so the bars and
	# the frame stay in front of it (clipped to the whole opening, it walked in front of the window, the user)
	var bar: float = 1.6 / hw
	var panes: Array = []
	for qx in [[-1.0, -bar], [bar, 1.0]]:
		for qy in [[-1.0, -bar * hw / hh], [bar * hw / hh, 1.0]]:
			panes.append(PackedVector2Array([o + ax * qx[0] + ay * qy[0], o + ax * qx[1] + ay * qy[0], o + ax * qx[1] + ay * qy[1], o + ax * qx[0] + ay * qy[1]]))
	var base: Vector2 = Vector2(x, 0.12 + bob)
	var body_rot: float = lean + sway
	# the arm (a tapered limb) and the bucket (a pail with its bail) in the shoulder's frame, before the swing
	var arm: Array = [Vector2(-0.05, 0.0), Vector2(0.05, 0.0), Vector2(0.04, 0.68), Vector2(-0.04, 0.68)]
	var pail: Array = [Vector2(-0.12, 0.74), Vector2(0.12, 0.74), Vector2(0.10, 0.98), Vector2(-0.10, 0.98)]
	var bail: Array = []
	for bk in 9:
		var ba: float = PI * float(bk) / 8.0
		bail.append(Vector2(cos(ba) * 0.12, 0.74 - sin(ba) * 0.08))
	var parts: Array = [[SIL, false], [arm, true], [pail, true], [bail, true]]
	for ring_i in 4:
		var grow: float = 1.0 + 0.05 * float(3 - ring_i)
		for part in parts:
			var poly: PackedVector2Array = PackedVector2Array()
			var pts: Array = part[0]
			for sp in pts:
				var q: Vector2 = sp as Vector2
				if bool(part[1]):
					q = SHOULDER + q.rotated(swing)
				q = (q * grow).rotated(body_rot) * Vector2(facing, 1.0) * 0.72
				q += base
				poly.append(o + ax * q.x + ay * q.y)
			if pts.size() == 9:
				# the bail is a line, drawn as a thin band
				var band: PackedVector2Array = PackedVector2Array()
				for bp in poly:
					band.append(bp)
				for bi in range(poly.size() - 1, -1, -1):
					band.append(poly[bi] + (ay.normalized() * 1.2))
				poly = band
			for pane in panes:
				for clipped in Geometry2D.intersect_polygons(poly, pane):
					# (a sliver clipped at the frame can be degenerate: it cannot be triangulated, and drawing it errors)
					if clipped.size() >= 3 and not Geometry2D.triangulate_polygon(clipped).is_empty():
						cv.draw_colored_polygon(clipped, Color(0.32, 0.17, 0.08, 0.10 + 0.07 * float(ring_i)))

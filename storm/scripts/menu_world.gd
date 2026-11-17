extends "res://scripts/menu_poster3d.gd"

# STORM'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): THE HOUSE AT NIGHT
# IN THE STORM -- the game is keeping it dry. The house is REAL 3-D now (the flat front-on drawing was "flat"):
#   the sky       2-D, behind the scene: storm blue, layered clouds drifting (their undersides catching the flashes),
#                 a forked bolt behind the roof, a far curtain of fainter rain, rolling hills on the horizon
#   the house     two storeys of painted clapboard under a shingled gable roof with a brick chimney, white trim,
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
var _figure: Node3D = null

# the house's points the 2-D weather needs (units)
const EAVE_L: Vector3 = Vector3(-170.0, 205.0, 112.0)
const EAVE_R: Vector3 = Vector3(170.0, 205.0, 112.0)
const SPOUT: Vector3 = Vector3(158.0, 30.0, 112.0)
const CHIMNEY: Vector3 = Vector3(95.0, 330.0, -20.0)
const PUDDLES: Array = [Vector3(-40.0, 0.0, 250.0), Vector3(120.0, 0.0, 300.0), Vector3(-200.0, 0.0, 330.0)]

# one picture per platform: a desktop's short band needs the camera further back (the title cut the roof)
func _baked_path() -> String:
	return "res://storm/art/menu_house.webp" if mobile else "res://storm/art/menu_house_d.webp"

func _bake_alpha() -> bool:
	return true

func _eye() -> Vector3:
	return Vector3(90.0, 170.0, 640.0) if mobile else Vector3(110.0, 190.0, 900.0)

func _aim() -> Vector3:
	return Vector3(0.0, 150.0, 0.0) if mobile else Vector3(0.0, 175.0, 0.0)

func _fov() -> float:
	return 54.0

func _frame_frac() -> float:
	return 0.56 if mobile else 0.62

func _environment(env: Environment) -> void:
	env.background_color = Color(0.03, 0.05, 0.11)
	env.ambient_light_color = Color(0.45, 0.52, 0.70)
	env.ambient_light_energy = 0.28

func _setup() -> void:
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

func _window(c: Vector3, w: float, h: float, curtain: Color) -> void:
	var trim: StandardMaterial3D = mat(TRIM, 0.6)
	box(Vector3(w + 12.0, h + 12.0, 4.0), trim, c + Vector3(0.0, 0.0, 1.0))
	box(Vector3(w, h, 1.0), glow(WARM), c + Vector3(0.0, 0.0, 3.2))
	# curtains drawn half across, in their color, lit from behind
	for side in [-1.0, 1.0]:
		box(Vector3(w * 0.30, h, 0.6), glow(curtain), c + Vector3(side * w * 0.35, 0.0, 3.6))
	box(Vector3(2.5, h, 1.2), trim, c + Vector3(0.0, 0.0, 4.2))
	box(Vector3(w, 2.5, 1.2), trim, c + Vector3(0.0, 0.0, 4.2))
	box(Vector3(w + 20.0, 4.0, 10.0), trim, c + Vector3(0.0, -h * 0.5 - 8.0, 5.0))

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
	# THE HOUSE: two storeys, the roof, the chimney
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
	# the gutter along the front eave, and the downspout down the right corner to a bucket
	cyl(4.0, 4.0, 360.0, mat(Color(0.42, 0.44, 0.48), 0.4, 0.6), Vector3(0.0, 198.0, 134.0), Vector3(0.0, 0.0, 90.0))
	cyl(3.5, 3.5, 170.0, mat(Color(0.42, 0.44, 0.48), 0.4, 0.6), Vector3(162.0, 115.0, 128.0))
	cyl(14.0, 11.0, 26.0, mat(Color(0.50, 0.52, 0.56), 0.4, 0.6), Vector3(162.0, 13.0, 140.0))
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
	var picket: StandardMaterial3D = mat(Color(0.85, 0.85, 0.82), 0.7)
	for k2 in 34:
		var fx: float = -420.0 + float(k2) * 25.0
		if absf(fx + 90.0) < 40.0:
			continue
		box(Vector3(8.0, 52.0, 3.0), picket, Vector3(fx, 26.0, 400.0))
		put(_gable(8.0, 6.0), picket, Vector3(fx, 52.0, 401.5))
	for ry in [16.0, 40.0]:
		box(Vector3(330.0, 5.0, 3.0), picket, Vector3(-270.0, ry, 398.0))
		box(Vector3(330.0, 5.0, 3.0), picket, Vector3(90.0 + 165.0 - 20.0, ry, 398.0))
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
	# A FIGURE passing behind the lower right window's curtains, a soft dark shape
	_figure = Node3D.new()
	root.add_child(_figure)
	var shade: StandardMaterial3D = glow(Color(0.30, 0.18, 0.10))
	box(Vector3(18.0, 34.0, 0.5), shade, Vector3(0.0, -8.0, 0.0), Vector3.ZERO, _figure)
	sphere(8.0, shade, Vector3(0.0, 15.0, 0.0), _figure)
	_figure.scale = Vector3(1.0, 1.0, 0.05)

func _animate(_delta: float) -> void:
	if _shutter == null:
		return
	if t >= _next_bolt:
		_bolt_at = t
		_next_bolt = t + _rng.randf_range(4.5, 8.0)
		_make_bolt()
	# the shutter: blown open and banged back, eased (never a jump)
	var gust: float = _wind()
	_shutter.rotation_degrees = Vector3(0.0, -(35.0 + 40.0 * gust) * (0.5 + 0.5 * sin(t * 1.3 + sin(t * 0.7) * 1.5)), 0.0)
	# the figure: across the window and back, now and then; hidden (outside the glass) the rest of the time
	var u: float = fmod(t, 9.0)
	var x: float = lerpf(-60.0, 60.0, smoothstep(2.0, 5.0, u)) if u < 5.5 else lerpf(60.0, -60.0, smoothstep(6.0, 8.6, u))
	_figure.position = Vector3(90.0 + x, 58.0, 113.9)
	_figure.visible = absf(x) < 30.0

# --- the weather, in 2-D ----------------------------------------------------------------------------------------------

func _flash() -> float:
	var u: float = t - _bolt_at
	if u < 0.0 or u > 0.7:
		return 0.0
	return maxf(exp(-u * 16.0), 0.55 * exp(-absf(u - 0.17) * 20.0))

func _wind() -> float:
	return 0.6 + 0.4 * sin(t * 0.7) * sin(t * 0.31 + 1.0)

func _horizon() -> float:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	if _cam3 == null:
		return full.y * 0.45
	return screen_of(Vector3(0.0, 0.0, -3000.0)).y

func _make_bolt() -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var x: float = full.x * _rng.randf_range(0.15, 0.85)
	var y: float = full.y * 0.08
	var main: PackedVector2Array = PackedVector2Array([Vector2(x, y)])
	var end_y: float = _horizon() - 10.0
	while y < end_y:
		y += _rng.randf_range(16.0, 30.0)
		x += _rng.randf_range(-22.0, 22.0)
		main.append(Vector2(x, y))
	_bolt = [main]
	for b in 3:
		var at: int = _rng.randi_range(2, maxi(3, main.size() - 3))
		var p: Vector2 = main[mini(at, main.size() - 1)]
		var br: PackedVector2Array = PackedVector2Array([p])
		var dirx: float = -1.0 if _rng.randf() < 0.5 else 1.0
		for _s in _rng.randi_range(3, 6):
			p += Vector2(dirx * _rng.randf_range(8.0, 20.0), _rng.randf_range(10.0, 22.0))
			br.append(p)
		_bolt.append(br)

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
	for cl in 3:
		var speed: float = 5.0 + 5.0 * float(cl)
		var cy0: float = full.y * (0.04 + 0.06 * float(cl))
		var shade: Color = Color(0.06, 0.08, 0.13).lerp(Color(0.10, 0.12, 0.18), float(cl) * 0.5)
		for k in 6:
			var cx: float = fmod(float(k) * 180.0 + float(cl) * 60.0 + t * speed, full.x + 360.0) - 180.0
			var cy: float = cy0 + 30.0 * h01(k + cl * 10)
			for j in 5:
				var pc: Vector2 = Vector2(cx + float(j) * 42.0 - 84.0, cy + 14.0 * sin(float(j * 3 + k)))
				var rr: float = 56.0 - float(j % 2) * 14.0 + 10.0 * h01(k * 5 + j)
				for g in 3:
					cv.draw_circle(pc, rr * (1.15 - 0.2 * float(g)), Color(shade, 0.22).lerp(Color(0.62, 0.68, 0.84, 0.28), fl * 0.55))
				cv.draw_circle(pc + Vector2(0.0, rr * 0.45), rr * 0.7, Color(0.30, 0.36, 0.52, 0.05 + 0.25 * fl))
	if fl > 0.05:
		for k2 in _bolt.size():
			var line: PackedVector2Array = _bolt[k2]
			var w: float = 3.0 if k2 == 0 else 1.6
			cv.draw_polyline(line, Color(0.70, 0.82, 1.0, 0.30 * fl), w * 4.0, true)
			cv.draw_polyline(line, Color(1.0, 1.0, 1.0, fl), w, true)
	_rain(_far, full, horizon + 30.0, Color(0.60, 0.70, 0.88, 0.22), 16.0, 600.0)
	var hills: PackedVector2Array = PackedVector2Array([Vector2(0.0, full.y)])
	for k3 in 25:
		var x: float = full.x * float(k3) / 24.0
		hills.append(Vector2(x, horizon + 2.0 - 26.0 * sin(float(k3) * 0.55 + 1.0) - 10.0 * sin(float(k3) * 1.7)))
	hills.append(Vector2(full.x, full.y))
	cv.draw_colored_polygon(hills, Color(0.05, 0.07, 0.10).lerp(Color(0.35, 0.40, 0.48), fl * 0.5))

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
		# the downspout gushing into its bucket
		var sp0: Vector2 = screen_of(SPOUT)
		for k3 in 6:
			var gu: float = fposmod(t * 2.2 + float(k3) / 6.0, 1.0)
			cv.draw_line(sp0 + Vector2(3.0 * gu, 18.0 * gu), sp0 + Vector2(4.0 * gu + 1.0, 18.0 * gu + 7.0), Color(0.80, 0.88, 1.0, 0.7 * (1.0 - gu)), 2.2)
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

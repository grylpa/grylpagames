extends "res://scripts/menu_poster3d.gd"

# MIND PALACE'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A PALACE OF
# THE MIND floating in the game's night sky (palace_sky.gdshader, in 2-D behind, with slow stars, a moon and a violet
# glow) -- REAL 3-D now (the front-on drawing was "flat"): a keep of stone blocks with a tall central tower, four
# round corner towers under conical roofs, crenellated curtain walls and an arched gate, on an island of rock with
# roots hanging under it; two islets beside it, each with a turret; glowing stepping stones floating up to the gate.
# Its windows light one after another, each in a room's color -- remembered one by one -- until the whole palace
# glows, then go dark and it begins again (`CYCLE` 11 s). The palace is baked with a CLEAR sky (`_bake_alpha`:
# `menu_palace.webp`, `menu_palace_d.webp`); the windows, the stones and the flags are live, the mist 2-D in front.
# Nothing with a hard edge moves except the flags (the first version bobbed, "jitter and flicker"). Made up, never
# the board.

const SKY: Shader = preload("res://mmm/scripts/palace_sky.gdshader")
const ROOM_COLORS: Array = [Color(0.95, 0.32, 0.32), Color(0.32, 0.64, 0.98), Color(0.42, 0.88, 0.46),
	Color(0.99, 0.80, 0.30), Color(0.78, 0.48, 0.98), Color(0.32, 0.88, 0.88), Color(1.0, 0.58, 0.26)]
const CYCLE: float = 11.0
const DARK_WIN: Color = Color(0.07, 0.05, 0.12)
const TOWERS: Array = [Vector3(-150.0, 0.0, 70.0), Vector3(150.0, 0.0, 70.0), Vector3(-130.0, 0.0, -70.0), Vector3(130.0, 0.0, -70.0)]
const ISLETS: Array = [Vector3(-340.0, 40.0, 40.0), Vector3(330.0, 10.0, -10.0)]

var _sky: ColorRect = null
var _back: Control = null
var _wins: Array = []                  # StandardMaterial3D per window
var _stones: Array = []                # [StandardMaterial3D, index]
var _flags: Array = []                 # Node3D per flag

func _baked_path() -> String:
	return "res://mmm/art/menu_palace.webp" if mobile else "res://mmm/art/menu_palace_d.webp"

func _bake_alpha() -> bool:
	return true

func _eye() -> Vector3:
	return Vector3(40.0, 260.0, 900.0) if mobile else Vector3(40.0, 260.0, 1150.0)

func _aim() -> Vector3:
	return Vector3(0.0, 150.0, 0.0) if mobile else Vector3(0.0, 175.0, 0.0)

func _fov() -> float:
	return 50.0

func _frame_frac() -> float:
	return 0.52

func _environment(env: Environment) -> void:
	env.background_color = Color(0.05, 0.04, 0.10)
	env.ambient_light_color = Color(0.55, 0.52, 0.70)
	env.ambient_light_energy = 0.34

func _setup() -> void:
	# the 2-D sky under everything: the game's sky shader, then stars, the moon, the violet glow (not when baking: the
	# picture keeps a clear sky)
	if bake_mode:
		super._setup()
		return
	_sky = ColorRect.new()
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = SKY
	_sky.material = m
	add_child(_sky)
	_back = Control.new()
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.draw.connect(func() -> void: _draw_back(_back))
	add_child(_back)
	super._setup()

func _build_lights() -> void:
	# the moon from the upper right, pale violet; a cool fill from the front
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.light_color = Color(0.82, 0.80, 1.0)
	moon.light_energy = 0.85
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 30.0
	root.add_child(moon)
	moon.rotation_degrees = Vector3(-35.0, 40.0, 0.0)
	light(Vector3(-200.0, 200.0, 500.0), Color(0.55, 0.50, 0.95), 0.8, 1000.0)

# --- the palace, the rock, the islets: baked ---------------------------------------------------------------------

func _stone_m(base: Color, uv: Vector3) -> StandardMaterial3D:
	return mat(Color.WHITE, 0.85, 0.0, tex_speckle(128, base, 0.10, 21, 8, base.darkened(0.45)), uv)

func _cone_roof(c: Vector3, r: float, h: float) -> void:
	cyl(0.0, r, h, mat(Color(0.25, 0.19, 0.40), 0.55), c + Vector3(0.0, h * 0.5, 0.0), Vector3.ZERO, null, 28)
	cyl(r + 2.0, r + 2.0, 4.0, mat(Color(0.22, 0.16, 0.36), 0.6), c + Vector3(0.0, 1.0, 0.0), Vector3.ZERO, null, 28)

func _crenels(c: Vector3, w: float, d: float, along_x: bool) -> void:
	var stone: StandardMaterial3D = mat(Color(0.47, 0.45, 0.52), 0.85)
	var n: int = int(w / 18.0)
	for k in n:
		if k % 2 == 0:
			var off: float = -w * 0.5 + (float(k) + 0.5) * w / float(n)
			box(Vector3(w / float(n), 10.0, d) if along_x else Vector3(d, 10.0, w / float(n)), stone, c + (Vector3(off, 5.0, 0.0) if along_x else Vector3(0.0, 5.0, off)))

func _build_still() -> void:
	var rock: StandardMaterial3D = mat(Color.WHITE, 0.95, 0.0, tex_speckle(128, Color(0.20, 0.16, 0.26), 0.25, 5), Vector3(4, 2, 1))
	var stone: StandardMaterial3D = _stone_m(Color(0.47, 0.45, 0.52), Vector3(1.5, 1.5, 1))
	var tower_m: StandardMaterial3D = _stone_m(Color(0.50, 0.48, 0.55), Vector3(2, 2.5, 1))
	var root_m: StandardMaterial3D = mat(Color(0.18, 0.14, 0.12), 0.9)
	# THE ISLAND: a rough inverted cone of rock, a ring of boulders round its rim, the top flat, roots hanging under it
	cyl(240.0, 26.0, 230.0, rock, Vector3(0.0, -118.0, 0.0), Vector3.ZERO, null, 18)
	cyl(250.0, 240.0, 10.0, mat(Color(0.26, 0.24, 0.32), 0.9), Vector3(0.0, -4.0, 0.0), Vector3.ZERO, null, 18)
	for k in 16:
		var a: float = TAU * float(k) / 16.0
		var bp: Vector3 = Vector3(cos(a) * 230.0, -14.0 - 20.0 * h01(k), sin(a) * 230.0)
		var bm: MeshInstance3D = sphere(26.0 + 14.0 * h01(k + 3), rock, bp)
		bm.scale = Vector3(1.3, 0.7, 1.0)
	for k2 in 7:
		var rx: float = (h01(k2 + 30) - 0.5) * 200.0
		var rz: float = 60.0 + (h01(k2 + 40) - 0.5) * 80.0
		var top: Vector3 = Vector3(rx, -110.0, rz)
		put(tube_mesh(PackedVector3Array([top, top + Vector3(10.0, -70.0, 6.0), top + Vector3(-6.0, -150.0 - 60.0 * h01(k2), 10.0)]), 3.0, 6), root_m, Vector3.ZERO)
	# THE CURTAIN WALLS between the towers, crenellated
	box(Vector3(300.0, 90.0, 18.0), stone, Vector3(0.0, 45.0, 70.0))
	box(Vector3(260.0, 90.0, 18.0), stone, Vector3(0.0, 45.0, -70.0))
	for sx in [-1.0, 1.0]:
		box(Vector3(18.0, 90.0, 140.0), stone, Vector3(sx * 140.0, 45.0, 0.0))
	_crenels(Vector3(0.0, 90.0, 70.0), 300.0, 18.0, true)
	_crenels(Vector3(0.0, 90.0, -70.0), 260.0, 18.0, true)
	# the gate: an arched dark opening with a stone surround
	box(Vector3(48.0, 52.0, 2.0), mat(Color(0.04, 0.03, 0.06), 1.0), Vector3(0.0, 26.0, 79.5))
	cyl(24.0, 24.0, 2.0, mat(Color(0.04, 0.03, 0.06), 1.0), Vector3(0.0, 52.0, 79.5), Vector3(90.0, 0.0, 0.0), null, 24)
	# its surround: straight jambs and a half-round of wedge stones over them (a full ring read as a porthole)
	var dressed: StandardMaterial3D = mat(Color(0.58, 0.56, 0.62), 0.8)
	for jx in [-1.0, 1.0]:
		box(Vector3(9.0, 54.0, 6.0), dressed, Vector3(jx * 28.5, 27.0, 80.5))
	for v in 9:
		var va: float = PI * float(v) / 8.0
		box(Vector3(9.0, 11.0, 6.0), dressed, Vector3(cos(va) * 28.5, 52.0 + sin(va) * 28.5, 80.5), Vector3(0.0, 0.0, rad_to_deg(va) - 90.0))
	# THE KEEP and its tall central tower
	box(Vector3(160.0, 170.0, 100.0), stone, Vector3(0.0, 85.0, -10.0))
	_crenels(Vector3(0.0, 170.0, 40.0), 160.0, 12.0, true)
	cyl(36.0, 38.0, 300.0, tower_m, Vector3(0.0, 150.0, -10.0), Vector3.ZERO, null, 28)
	_cone_roof(Vector3(0.0, 300.0, -10.0), 46.0, 110.0)
	# THE CORNER TOWERS, round, under conical roofs
	for k3 in TOWERS.size():
		var tp: Vector3 = TOWERS[k3]
		var th: float = 190.0 if k3 < 2 else 220.0
		cyl(30.0, 32.0, th, tower_m, tp + Vector3(0.0, th * 0.5, 0.0), Vector3.ZERO, null, 24)
		_cone_roof(tp + Vector3(0.0, th, 0.0), 40.0, 80.0)
	# THE ISLETS, each a small rock with a turret
	for k4 in ISLETS.size():
		var ip: Vector3 = ISLETS[k4]
		cyl(60.0, 8.0, 80.0, rock, ip + Vector3(0.0, -40.0, 0.0), Vector3.ZERO, null, 14)
		cyl(18.0, 20.0, 90.0, tower_m, ip + Vector3(0.0, 45.0, 0.0), Vector3.ZERO, null, 18)
		_cone_roof(ip + Vector3(0.0, 90.0, 0.0), 26.0, 50.0)

# --- live: the windows, the stones, the flags ----------------------------------------------------------------------

func _win(c: Vector3, w: float, h: float, yaw: float) -> void:
	var node: Node3D = Node3D.new()
	root.add_child(node)
	node.position = c
	node.rotation = Vector3(0.0, yaw, 0.0)
	var gm: StandardMaterial3D = glow(DARK_WIN)
	box(Vector3(w, h, 1.0), gm, Vector3(0.0, 0.0, 0.0), Vector3.ZERO, node)
	cyl(w * 0.5, w * 0.5, 1.0, gm, Vector3(0.0, h * 0.5, 0.0), Vector3(90.0, 0.0, 0.0), node, 16)
	_wins.append(gm)

func _build_live() -> void:
	# windows on what faces you: the keep (two rows), the central tower (up its height), the front towers, the islets
	for row in 2:
		for col in 3:
			_win(Vector3(-50.0 + float(col) * 50.0, 110.0 + float(row) * 34.0, 40.6), 12.0, 18.0, 0.0)
	for k in 4:
		_win(Vector3(0.0, 200.0 + float(k) * 22.0, 27.0), 9.0, 13.0, 0.0)
	for k2 in 2:
		var tp: Vector3 = TOWERS[k2]
		for r in 3:
			_win(tp + Vector3(0.0, 60.0 + float(r) * 42.0, 31.5), 10.0, 15.0, 0.0)
	for k3 in 2:
		var tp2: Vector3 = TOWERS[2 + k3]
		_win(tp2 + Vector3(0.0, 170.0, 31.0), 10.0, 14.0, 0.0)
	for ip in ISLETS:
		_win((ip as Vector3) + Vector3(0.0, 60.0, 19.5), 8.0, 12.0, 0.0)
	# the stepping stones, floating down from the gate toward you
	for s in 7:
		var sm: StandardMaterial3D = glow(Color(0.72, 0.64, 1.0))
		var st: MeshInstance3D = cyl(16.0, 14.0, 4.0, sm, Vector3(8.0 * sin(float(s) * 1.3), -6.0 - float(s) * 16.0, 110.0 + float(s) * 46.0))
		st.scale = Vector3(1.0, 1.0, 0.7)
		_stones.append([sm, s])
	# flags on the towers' points, in the rooms' colors
	var tops: Array = [Vector3(0.0, 410.0, -10.0)]
	for k4 in TOWERS.size():
		tops.append((TOWERS[k4] as Vector3) + Vector3(0.0, (190.0 if k4 < 2 else 220.0) + 80.0, 0.0))
	for k5 in tops.size():
		var tp3: Vector3 = tops[k5]
		cyl(1.2, 1.2, 30.0, mat(Color(0.2, 0.2, 0.2), 0.5), tp3 + Vector3(0.0, 15.0, 0.0))
		var f: Node3D = Node3D.new()
		root.add_child(f)
		f.position = tp3 + Vector3(0.0, 26.0, 0.0)
		box(Vector3(22.0, 12.0, 0.6), mat(ROOM_COLORS[k5 % ROOM_COLORS.size()], 0.6), Vector3(11.0, 0.0, 0.0), Vector3.ZERO, f)
		_flags.append(f)

func _animate(_delta: float) -> void:
	var u: float = fmod(t, CYCLE) / CYCLE
	var n: int = _wins.size()
	var fade: float = 1.0 - smoothstep(0.86, 0.98, u)
	for k in n:
		# each window eases on in its turn, in a room's color; all go dark together at the end
		var on_at: float = 0.04 + 0.70 * float(k) / float(maxi(1, n))
		var a: float = smoothstep(on_at, on_at + 0.04, u) * fade
		var idx: int = (k * 7) % n
		var c: Color = ROOM_COLORS[k % ROOM_COLORS.size()]
		(_wins[idx] as StandardMaterial3D).albedo_color = DARK_WIN.lerp(c, a)
	for st in _stones:
		var glow_v: float = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * 1.2 - float(st[1]) * 0.7))
		(st[0] as StandardMaterial3D).albedo_color = Color(0.40, 0.34, 0.62).lerp(Color(0.86, 0.80, 1.0), glow_v)
	for k2 in _flags.size():
		(_flags[k2] as Node3D).rotation = Vector3(0.0, 0.35 * sin(t * 2.2 + float(k2)), 0.0)

# --- the sky behind (2-D) and the mist in front ----------------------------------------------------------------------

func _tick(delta: float) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	if _sky != null and _back != null:
		_sky.position = Vector2.ZERO
		_sky.size = full
		_back.queue_redraw()
	super._tick(delta)

func _draw_back(d: Control) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	for k in 110:
		var sp: Vector2 = Vector2(h01(k * 5 + 1) * full.x, h01(k * 5 + 2) * full.y * 0.80)
		var tw: float = 0.5 + 0.5 * sin(t * (0.25 + 0.5 * h01(k + 9)) + float(k) * 1.7)
		d.draw_circle(sp, 0.8 + 1.3 * h01(k * 5 + 3), Color(0.92, 0.90, 1.0, 0.30 + 0.45 * tw * h01(k * 5 + 4)))
	if _cam3 == null:
		return
	var top: Vector2 = screen_of(Vector3(0.0, 300.0, -10.0))
	var moon: Vector2 = Vector2(full.x * 0.87, top.y + 30.0)
	for g in 7:
		d.draw_circle(moon, 90.0 - float(g) * 11.0, Color(0.85, 0.82, 1.0, 0.035))
	d.draw_circle(moon, 28.0, Color(0.96, 0.94, 1.0))
	d.draw_circle(moon + Vector2(10.0, -6.0), 24.0, Color(0.09, 0.07, 0.17, 0.94))
	var c: Vector2 = screen_of(Vector3(0.0, 120.0, 0.0))
	var r: float = screen_of(Vector3(300.0, 120.0, 0.0)).distance_to(c)
	for g2 in 9:
		d.draw_set_transform(c, 0.0, Vector2(1.0, 0.75))
		d.draw_circle(Vector2.ZERO, r * (1.2 - 0.1 * float(g2)), Color(0.55, 0.40, 0.95, 0.03))
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	# mist drifting under the island
	if _cam3 != null:
		var c: Vector2 = screen_of(Vector3(0.0, -160.0, 60.0))
		var w: float = screen_of(Vector3(260.0, -160.0, 60.0)).distance_to(c)
		for k in 6:
			var mx: float = fmod(t * (8.0 + float(k) * 3.0) + float(k) * 110.0, w * 3.6) - w * 1.8
			cv.draw_set_transform(c + Vector2(mx, float(k) * 12.0 - 30.0), 0.0, Vector2(1.0, 0.13))
			cv.draw_circle(Vector2.ZERO, 110.0, Color(0.72, 0.68, 0.92, 0.07))
		cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	title("Mind Palace", "Explore and remember the room colors", Color(0.90, 0.84, 1.0), Color(0.10, 0.06, 0.20),
		Color(0.60, 0.45, 1.0, 0.30))

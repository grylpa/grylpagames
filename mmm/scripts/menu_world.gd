extends "res://scripts/menu_poster3d.gd"

# MIND PALACE'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A PALACE OF
# THE MIND floating in the game's night sky (palace_sky.gdshader, in 2-D behind, with slow stars, a moon and a violet
# glow) -- REAL 3-D now (the front-on drawing was "flat"): a keep of stone blocks with a tall central tower, four
# round corner towers under conical roofs, crenellated curtain walls and an arched gate, on an island of rock with
# roots hanging under it; two islets beside it, each with a turret; glowing stepping stones floating up to the gate.
# Its windows light and go dark each at its own rhythm, in the rooms' colors -- rooms remembered and forgotten. The palace is baked with a CLEAR sky (`_bake_alpha`:
# `menu_palace.webp`, `menu_palace_d.webp`); the windows, the stones and the pennants are live, the mist 2-D in front.
# Nothing with a hard edge moves except the flags (the first version bobbed, "jitter and flicker"). Made up, never
# the board.

const SKY: Shader = preload("res://mmm/scripts/palace_sky.gdshader")
const ROOM_COLORS: Array = [Color(0.95, 0.32, 0.32), Color(0.32, 0.64, 0.98), Color(0.42, 0.88, 0.46),
	Color(0.99, 0.80, 0.30), Color(0.78, 0.48, 0.98), Color(0.32, 0.88, 0.88), Color(1.0, 0.58, 0.26)]
const DARK_WIN: Color = Color(0.07, 0.05, 0.12)
const TOWERS: Array = [Vector3(-150.0, 0.0, 70.0), Vector3(150.0, 0.0, 70.0), Vector3(-130.0, 0.0, -70.0), Vector3(130.0, 0.0, -70.0)]
const ISLETS: Array = [Vector3(-340.0, 40.0, 40.0), Vector3(330.0, 10.0, -10.0)]

var _sky: ColorRect = null
var _back: Control = null
var _wins: Array = []                  # StandardMaterial3D per window
var _stones: Array = []                # [StandardMaterial3D, index]

func _baked_path() -> String:
	return "res://mmm/art/menu_palace.webp" if mobile else "res://mmm/art/menu_palace_d.webp"

func _bake_alpha() -> bool:
	return true

func _eye() -> Vector3:
	return Vector3(40.0, 240.0, 1080.0) if mobile else Vector3(40.0, 260.0, 1450.0)

func _aim() -> Vector3:
	return Vector3(0.0, 150.0, 0.0) if mobile else Vector3(0.0, 175.0, 0.0)

func _fov() -> float:
	return 50.0

func _frame_frac() -> float:
	return 0.40 if mobile else 0.50

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
	m.set_shader_parameter("style", 0)       # the STARRY SKY: the game's dark hall (style 3) read as a grid of squares
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
	# (none on the back towers: a live window draws over the baked keep that hides it, and floated in the air)
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
		# a pole thick enough to see (thin, the flags read as color rects floating in the air), a gilt finial
		cyl(2.6, 2.6, 34.0, mat(Color(0.62, 0.60, 0.66), 0.4, 0.6), tp3 + Vector3(0.0, 15.0, 0.0))
		sphere(3.6, mat(Color(0.92, 0.74, 0.34), 0.3, 0.8), tp3 + Vector3(0.0, 33.0, 0.0))
		# A PENNANT OF CLOTH (they were stiff colored boxes turning on their poles): long and tapering, rippling in
		# the wind (palace pennant shader: a wave running out along it, growing toward the tip, and shaded by its folds)
		var pm: ShaderMaterial = ShaderMaterial.new()
		pm.shader = _pennant_shader()
		pm.set_shader_parameter("col", ROOM_COLORS[k5 % ROOM_COLORS.size()])
		pm.set_shader_parameter("phase", float(k5) * 1.7)
		var pq: PlaneMesh = PlaneMesh.new()
		pq.size = Vector2(44.0, 14.0)
		pq.subdivide_width = 22
		pq.subdivide_depth = 2
		pq.orientation = PlaneMesh.FACE_Z
		put(pq, pm, tp3 + Vector3(22.0, 26.0, 0.0))

var _pennant: Shader = null

func _pennant_shader() -> Shader:
	if _pennant != null:
		return _pennant
	_pennant = Shader.new()
	_pennant.code = """shader_type spatial;
render_mode cull_disabled;
uniform vec3 col = vec3(1.0, 0.3, 0.3);
uniform float phase = 0.0;
varying float along;
void vertex() {
	float u = (VERTEX.x + 22.0) / 44.0;           // 0 at the pole, 1 at the tip
	along = u;
	VERTEX.y *= mix(1.0, 0.12, u);                // tapering to a point
	VERTEX.y -= u * u * 3.0;                      // the tip droops a little
	float w = TIME * 5.5 + phase;
	float k = 7.0;
	float amp = 4.5 * u;
	VERTEX.z += amp * sin(u * k - w) + 1.2 * u * sin(u * 17.0 - w * 1.9);
	float dz = 4.5 * (sin(u * k - w) / 44.0 + u * k / 44.0 * cos(u * k - w));
	NORMAL = normalize(vec3(-dz * 3.0, 0.0, 1.0));
}
void fragment() {
	float edge = smoothstep(0.0, 0.04, along);
	ALBEDO = col * (0.75 + 0.25 * edge);
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	EMISSION = col * 0.18;
	BACKLIGHT = col * 0.4;
}"""
	return _pennant

func _animate(_delta: float) -> void:
	# EACH WINDOW ON ITS OWN: lit and dark by turns at its own rhythm, easing over a moment (the user: not all off at once)
	for k in _wins.size():
		var period: float = 1.8 + 2.6 * h01(k + 300)
		var tk: float = t + h01(k + 400) * period
		var seg: int = int(floor(tk / period))
		var fu: float = fmod(tk, period)
		var now_on: float = 1.0 if h01(k * 97 + seg) > 0.42 else 0.0
		var was_on: float = 1.0 if h01(k * 97 + seg - 1) > 0.42 else 0.0
		var a: float = lerpf(was_on, now_on, smoothstep(0.0, 0.35, fu))
		var c: Color = ROOM_COLORS[k % ROOM_COLORS.size()]
		(_wins[k] as StandardMaterial3D).albedo_color = DARK_WIN.lerp(c, a)
	for st in _stones:
		var glow_v: float = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * 1.2 - float(st[1]) * 0.7))
		(st[0] as StandardMaterial3D).albedo_color = Color(0.40, 0.34, 0.62).lerp(Color(0.86, 0.80, 1.0), glow_v)

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
	# A FEW BRIGHT STARS THAT TWINKLE: each now and then flares, its four rays reaching out and drawing back
	for k3 in 14:
		var bp: Vector2 = Vector2(h01(k3 * 7 + 500) * full.x, (0.04 + 0.6 * h01(k3 * 7 + 501)) * full.y)
		var per: float = 2.5 + 3.5 * h01(k3 + 502)
		var u: float = fmod(t + h01(k3 + 503) * per, per) / per
		var flare: float = pow(maxf(0.0, sin(u * PI)), 6.0)
		var base_a: float = 0.55 + 0.25 * sin(t * 3.1 + float(k3))
		var hue: Color = Color(0.85, 0.90, 1.0).lerp(Color(1.0, 0.92, 0.78), h01(k3 + 504))
		d.draw_circle(bp, 6.0 + 8.0 * flare, Color(hue, 0.05 + 0.10 * flare))
		d.draw_circle(bp, 1.5 + 0.8 * flare, Color(hue, base_a + 0.4 * flare))
		var ray: float = 4.0 + 16.0 * flare
		for ra in 4:
			var dv: Vector2 = Vector2.from_angle(PI * 0.5 * float(ra) + 0.1) * ray
			d.draw_line(bp, bp + dv, Color(hue, 0.15 + 0.6 * flare), 1.2, true)
			d.draw_line(bp, bp + dv * 0.45, Color(1, 1, 1, 0.2 + 0.6 * flare), 1.6, true)
	if _cam3 == null:
		return
	var top: Vector2 = screen_of(Vector3(0.0, 300.0, -10.0))
	var moon: Vector2 = Vector2(full.x * 0.87, top.y + 30.0)
	# THE MOON: a soft halo, then a sphere shaded from its lit upper left to a dim limb, with its seas and craters
	# (it was a flat crescent)
	var mr: float = 30.0
	for g in 10:
		d.draw_circle(moon, mr * (3.2 - 0.22 * float(g)), Color(0.85, 0.82, 1.0, 0.022))
	d.draw_circle(moon, mr, Color(0.50, 0.48, 0.58))
	for k in 20:
		var f: float = float(k + 1) / 20.0
		d.draw_circle(moon + Vector2(-mr, -mr) * 0.28 * f, mr * (1.0 - 0.60 * f), Color(0.50, 0.48, 0.58).lerp(Color(0.98, 0.96, 1.0), f))
	for sea in [[Vector2(-8.0, -6.0), 9.0], [Vector2(7.0, 4.0), 7.0], [Vector2(-2.0, 12.0), 5.0]]:
		d.draw_set_transform(moon + (sea[0] as Vector2), 0.3, Vector2(1.0, 0.75))
		d.draw_circle(Vector2.ZERO, float(sea[1]), Color(0.55, 0.53, 0.66, 0.45))
		d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for cr in [[Vector2(12.0, -10.0), 3.0], [Vector2(-14.0, 8.0), 2.4], [Vector2(4.0, -16.0), 2.0], [Vector2(16.0, 10.0), 2.2]]:
		var cp: Vector2 = moon + (cr[0] as Vector2)
		d.draw_circle(cp, float(cr[1]), Color(0.60, 0.58, 0.70, 0.7))
		d.draw_arc(cp, float(cr[1]), PI * 1.1, PI * 1.9, 8, Color(1, 1, 1, 0.45), 1.0, true)
	d.draw_arc(moon, mr - 0.5, deg_to_rad(110.0), deg_to_rad(340.0), 40, Color(1.0, 1.0, 1.0, 0.25), 1.5, true)
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

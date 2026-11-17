extends "res://scripts/menu_poster3d.gd"

# ALIENS' OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A SPACEPORT GATE
# ON AN ALIEN WORLD AT NIGHT -- REAL 3-D now (it was a drawn picture). In 2-D behind: the violet-to-teal sky, stars, a
# ringed planet and two moons. The world: violet-teal rocky ground with craters, rock spires on the horizon, the gate
# (two pylons and a lit crossbar), the round BOARDING PAD with its glowing ring, antenna masts with lamps, cargo crates.
# Over it a FLYING SAUCER hangs -- brushed metal under a glass dome, its rim lights chasing round -- and lets its
# passengers down a beam of light: the game's own aliens (alien.gd, 2-D, placed from the beam's 3-D path), each
# different, drifting gently down, turning a little; two more wait on the pad. The world is baked with a CLEAR sky
# (`_bake_alpha`: `menu_port.webp`, `menu_port_d.webp`); the saucer and the beam are live. Made up, never the board.

const ALIEN = preload("res://aliens/scripts/alien.gd")
const RIDERS: int = 5
const FALL: float = 9.0
const SHIP: Vector3 = Vector3(0.0, 345.0, -20.0)
const PAD: Vector3 = Vector3(0.0, 4.0, 0.0)

var _layer: Node2D = null
var _riders: Array = []
var _front: Array = []
var _saucer: Node3D = null
var _rim: Array = []

func _baked_path() -> String:
	return "res://aliens/art/menu_port.webp" if mobile else "res://aliens/art/menu_port_d.webp"

func _bake_alpha() -> bool:
	return true

func _eye() -> Vector3:
	return Vector3(0.0, 175.0, 610.0) if mobile else Vector3(0.0, 195.0, 860.0)

func _aim() -> Vector3:
	return Vector3(0.0, 175.0, 0.0) if mobile else Vector3(0.0, 185.0, 0.0)

func _fov() -> float:
	return 56.0

func _frame_frac() -> float:
	return 0.50 if mobile else 0.58

func _environment(env: Environment) -> void:
	env.background_color = Color(0.04, 0.05, 0.10)
	env.ambient_light_color = Color(0.45, 0.60, 0.75)
	env.ambient_light_energy = 0.45

func _setup() -> void:
	super._setup()
	if bake_mode:
		return
	# the game's aliens, over the 3-D view
	_layer = Node2D.new()
	add_child(_layer)
	for k in RIDERS:
		var a: Node2D = ALIEN.new()
		_layer.add_child(a)
		a.call("setup", 30.0, 1 + k % 3, k % 5, k % 2 == 0, (k + 1) % 3, k % 2 == 1)
		_riders.append(a)
	for k2 in 2:
		var a2: Node2D = ALIEN.new()
		_layer.add_child(a2)
		a2.call("setup", 40.0, 2 + k2, (k2 * 2 + 1) % 5, k2 == 0, 2 - k2, k2 == 0)
		_front.append(a2)
	if _top != null:
		move_child(_top, get_child_count() - 1)

func _build_lights() -> void:
	# the planet's pink light from the left, a cool teal from the right, the pad's glow
	var p: DirectionalLight3D = DirectionalLight3D.new()
	p.light_color = Color(1.0, 0.72, 0.88)
	p.light_energy = 0.75
	root.add_child(p)
	p.rotation_degrees = Vector3(-30.0, -55.0, 0.0)
	var q: DirectionalLight3D = DirectionalLight3D.new()
	q.light_color = Color(0.55, 0.95, 0.95)
	q.light_energy = 0.45
	root.add_child(q)
	q.rotation_degrees = Vector3(-40.0, 60.0, 0.0)
	light(PAD + Vector3(0.0, 30.0, 0.0), Color(0.70, 1.0, 1.0), 2.4, 320.0)
	light(Vector3(0.0, 210.0, -40.0), Color(1.0, 0.85, 0.50), 1.2, 260.0)

# --- the world: baked ---------------------------------------------------------------------------------------------

func _build_still() -> void:
	var ground: StandardMaterial3D = mat(Color.WHITE, 0.9, 0.0, tex_speckle(128, Color(0.13, 0.15, 0.22), 0.25, 7), Vector3(30, 30, 1))
	var rock: StandardMaterial3D = mat(Color(0.26, 0.24, 0.36), 0.9)
	var metal: StandardMaterial3D = mat(Color(0.55, 0.60, 0.68), 0.35, 0.7)
	var dark_metal: StandardMaterial3D = mat(Color(0.20, 0.22, 0.28), 0.4, 0.6)
	box(Vector3(8000.0, 4.0, 6000.0), ground, Vector3(0.0, -2.0, -1500.0))
	# craters: low rims of rock
	for k in 9:
		var cp: Vector3 = Vector3((h01(k + 1) - 0.5) * 1400.0, 0.0, -200.0 - h01(k + 2) * 1600.0)
		var rim: TorusMesh = TorusMesh.new()
		rim.inner_radius = 40.0 + 60.0 * h01(k + 3)
		rim.outer_radius = rim.inner_radius + 16.0
		var rm: MeshInstance3D = put(rim, rock, cp)
		rm.scale = Vector3(1.0, 0.35, 1.0)
	# rock spires on the horizon
	for k2 in 12:
		var sx: float = (h01(k2 + 20) - 0.5) * 3600.0
		var sz: float = -1800.0 - h01(k2 + 21) * 1200.0
		var sh: float = 160.0 + 300.0 * h01(k2 + 22)
		cyl(4.0, 50.0 + 40.0 * h01(k2 + 23), sh, rock, Vector3(sx, sh * 0.5, sz), Vector3.ZERO, null, 7)
	# THE PAD: a raised round deck, a ring of light round its edge (glowing), chevrons painted toward its center
	cyl(130.0, 140.0, 10.0, metal, PAD + Vector3(0.0, 1.0, 0.0), Vector3.ZERO, null, 48)
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 118.0
	ring.outer_radius = 126.0
	put(ring, glow(Color(0.65, 1.0, 1.0)), PAD + Vector3(0.0, 6.5, 0.0))
	cyl(60.0, 60.0, 1.0, glow(Color(0.40, 0.80, 0.85)), PAD + Vector3(0.0, 6.6, 0.0), Vector3.ZERO, null, 40)
	for c in 8:
		var ca: float = TAU * float(c) / 8.0
		box(Vector3(26.0, 0.6, 8.0), mat(Color(0.95, 0.80, 0.30), 0.6), PAD + Vector3(cos(ca) * 92.0, 6.4, sin(ca) * 92.0), Vector3(0.0, -rad_to_deg(ca), 0.0))
	# THE GATE behind the pad: two pylons, a crossbar with its lights, the port's sign
	for sx2 in [-1.0, 1.0]:
		put(rbox_mesh(16.0, 16.0, 240.0, 6.0, 3.0), dark_metal, Vector3(sx2 * 170.0, 0.0, -60.0))
		for l in 5:
			box(Vector3(2.0, 10.0, 4.0), glow(Color(0.60, 1.0, 0.90)), Vector3(sx2 * 170.0 + sx2 * -16.6, 30.0 + float(l) * 42.0, -60.0))
	box(Vector3(380.0, 24.0, 26.0), dark_metal, Vector3(0.0, 236.0, -60.0))
	for l2 in 13:
		sphere(3.4, glow(Color(1.0, 0.86, 0.45)), Vector3(-180.0 + float(l2) * 30.0, 236.0, -46.0))
	label("GATE 7", 26.0, Color(0.70, 1.0, 0.90), Vector3(0.0, 262.0, -50.0))
	# antenna masts and cargo crates about the port
	for m in 2:
		var mx: float = -360.0 if m == 0 else 380.0
		cyl(3.0, 4.0, 260.0, metal, Vector3(mx, 130.0, -180.0))
		cyl(26.0, 2.0, 14.0, metal, Vector3(mx, 250.0, -180.0), Vector3(30.0, 0.0, 0.0))
		sphere(5.0, glow(Color(1.0, 0.35, 0.30)), Vector3(mx, 266.0, -180.0))
	for k3 in 5:
		var cx: float = 220.0 + float(k3 % 3) * 46.0
		var cy: float = 20.0 + 40.0 * float(k3 / 3)
		box(Vector3(40.0, 40.0, 40.0), mat([Color(0.70, 0.40, 0.20), Color(0.30, 0.50, 0.65), Color(0.45, 0.55, 0.30)][k3 % 3], 0.7, 0.2), Vector3(cx, cy, 60.0 + 8.0 * float(k3 % 2)), Vector3(0.0, 8.0 * float(k3 % 3) - 6.0, 0.0))

# --- live: the saucer and its beam --------------------------------------------------------------------------------------

func _build_live() -> void:
	# the beam: a translucent cone of light from the saucer to the pad
	var bm: StandardMaterial3D = StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(0.75, 1.0, 0.95, 0.16)
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 46.0
	cone.bottom_radius = 120.0
	cone.height = SHIP.y - PAD.y - 30.0
	cone.cap_top = false
	cone.cap_bottom = false
	cone.radial_segments = 40
	put(cone, bm, (SHIP + PAD) * 0.5 + Vector3(0.0, -15.0, -10.0))
	# THE SAUCER: a flattened metal disc, a darker underside ring, the glass dome, the rim lights
	_saucer = Node3D.new()
	root.add_child(_saucer)
	var hull: StandardMaterial3D = mat(Color(0.70, 0.75, 0.82), 0.25, 0.85)
	var d: MeshInstance3D = sphere(160.0, hull, Vector3.ZERO, _saucer)
	d.scale = Vector3(1.0, 0.20, 1.0)
	var under: MeshInstance3D = sphere(98.0, mat(Color(0.30, 0.34, 0.42), 0.4, 0.7), Vector3(0.0, -8.0, 0.0), _saucer)
	under.scale = Vector3(1.0, 0.25, 1.0)
	cyl(36.0, 36.0, 4.0, glow(Color(0.75, 1.0, 0.95)), Vector3(0.0, -26.0, 0.0), Vector3.ZERO, _saucer, 32)
	var dome_m: StandardMaterial3D = mat(Color(0.55, 0.95, 1.0, 0.55), 0.05, 0.2)
	dome_m.clearcoat_enabled = true
	sphere(66.0, dome_m, Vector3(0.0, 22.0, 0.0), _saucer, true)
	for k in 16:
		var a: float = TAU * float(k) / 16.0
		var lm: StandardMaterial3D = glow(Color(1.0, 0.85, 0.35))
		sphere(6.0, lm, Vector3(cos(a) * 153.0, 0.0, sin(a) * 153.0), _saucer)
		_rim.append(lm)

func _animate(_delta: float) -> void:
	if _saucer == null:
		return
	_saucer.position = SHIP + Vector3(0.0, 5.0 * sin(t * 1.1), 0.0)
	_saucer.rotation = Vector3(deg_to_rad(4.0), t * 0.4, 0.0)
	for k in _rim.size():
		var on: float = 0.5 + 0.5 * sin(t * 4.0 - float(k) * 0.8)
		(_rim[k] as StandardMaterial3D).albedo_color = Color(0.55, 0.42, 0.18).lerp(Color(1.0, 0.92, 0.55), on)
	# the passengers down the beam, and the two waiting on the pad
	var top: Vector3 = SHIP + Vector3(0.0, -40.0, 0.0)
	for k2 in _riders.size():
		var a2: Node2D = _riders[k2]
		var u: float = fmod(t / FALL + float(k2) / float(_riders.size()), 1.0)
		var p: Vector3 = top.lerp(PAD + Vector3(0.0, 30.0, 10.0), u) + Vector3(sin(t * 0.8 + float(k2) * 1.9) * 30.0 * (0.3 + u), 0.0, 0.0)
		var sp: Vector2 = screen_of(p)
		var sc: float = screen_of(p + Vector3(0.0, 40.0, 0.0)).distance_to(sp) / 40.0
		a2.position = sp
		a2.rotation = sin(t * 0.6 + float(k2)) * 0.25
		a2.scale = Vector2.ONE * sc * (0.85 + 0.25 * u)
		a2.modulate = Color(1, 1, 1, clampf(u / 0.08, 0.0, 1.0) * clampf((1.0 - u) / 0.08, 0.0, 1.0))
	for k3 in _front.size():
		var a3: Node2D = _front[k3]
		var side: float = -1.0 if k3 == 0 else 1.0
		var fp: Vector3 = PAD + Vector3(side * 90.0, 32.0, 70.0)
		var fsp: Vector2 = screen_of(fp)
		var fsc: float = screen_of(fp + Vector3(0.0, 40.0, 0.0)).distance_to(fsp) / 40.0
		a3.position = fsp + Vector2(0.0, 3.0 * sin(t * 1.4 + float(k3) * 2.0))
		a3.scale = Vector2.ONE * fsc
		a3.call("set_bob", sin(t * 2.0 + float(k3)) * 2.0)

# --- the sky behind (2-D) ---------------------------------------------------------------------------------------------

func _paint(full: Vector2, _bottom: float) -> void:
	if bake_mode:
		return
	var ship_y: float = screen_of(SHIP).y if _cam3 != null else full.y * 0.3
	vgrad(Rect2(Vector2.ZERO, full), Color(0.05, 0.03, 0.12), Color(0.06, 0.16, 0.20))
	for k in 140:
		var sp: Vector2 = Vector2(h01(k * 5 + 1) * full.x, h01(k * 5 + 2) * full.y * 0.85)
		var tw: float = 0.5 + 0.5 * sin(t * (0.2 + 0.4 * h01(k + 9)) + float(k))
		cv.draw_circle(sp, 0.7 + 1.4 * h01(k * 5 + 3), Color(0.9, 0.95, 1.0, 0.25 + 0.5 * tw * h01(k * 5 + 4)))
	var planet: Vector2 = Vector2(full.x * 0.16, ship_y + 30.0)
	var pr: float = full.x * 0.15
	glow_at(planet, pr * 1.6, Color(0.95, 0.55, 0.85, 0.20))
	_ring(planet, pr * 1.8, pr * 0.42, Color(0.95, 0.80, 0.65, 0.55), true)
	_sphere(planet, pr, Color(0.30, 0.10, 0.28), Color(0.95, 0.62, 0.82))
	for b in 3:
		ellipse(planet + Vector2(-pr * 0.08, pr * (-0.32 + 0.3 * float(b))), pr * (0.86 - 0.12 * float(b)), pr * 0.07, Color(1.0, 0.80, 0.90, 0.14))
	_ring(planet, pr * 1.8, pr * 0.42, Color(0.95, 0.80, 0.65, 0.55), false)
	_sphere(Vector2(full.x * 0.86, ship_y - 90.0), 20.0, Color(0.25, 0.30, 0.38), Color(0.92, 0.96, 1.0))
	_sphere(Vector2(full.x * 0.74, ship_y - 40.0), 10.0, Color(0.15, 0.32, 0.26), Color(0.75, 1.0, 0.85))

func _paint_top(_full: Vector2, _bottom: float) -> void:
	# rings of light running down the beam
	if _cam3 != null:
		for k in 6:
			var u: float = fmod(t * 0.25 + float(k) / 6.0, 1.0)
			var p: Vector3 = (SHIP + Vector3(0.0, -40.0, -10.0)).lerp(PAD + Vector3(0.0, 8.0, -10.0), u)
			var c: Vector2 = screen_of(p)
			var rx: float = screen_of(p + Vector3(lerpf(46.0, 120.0, u), 0.0, 0.0)).distance_to(c)
			ellipse(c, rx, rx * 0.22, Color(0.85, 1.0, 0.95, 0.12 * sin(u * PI)))
	title("Aliens", "Work the spaceport gates", Color(0.70, 1.0, 0.85), Color(0.04, 0.10, 0.10), Color(0.4, 1.0, 0.8, 0.30))

func _sphere(c: Vector2, r: float, dark: Color, light_c: Color) -> void:
	glow_at(c, r * 1.35, Color(light_c, 0.18), 6)
	cv.draw_circle(c, r, dark)
	for k in 24:
		var f: float = float(k + 1) / 24.0
		cv.draw_circle(c + Vector2(-r, -r) * 0.32 * f, r * (1.0 - 0.62 * f), dark.lerp(light_c, f))
	cv.draw_arc(c, r - 1.0, deg_to_rad(150.0), deg_to_rad(300.0), 32, Color(light_c.lightened(0.3), 0.55), maxf(1.5, r * 0.04), true)

func _ring(c: Vector2, rx: float, ry: float, col: Color, back: bool) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 33:
		var a: float = (PI if back else 0.0) + PI * float(k) / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(-0.25))
	cv.draw_polyline(pts, col, 7.0, true)

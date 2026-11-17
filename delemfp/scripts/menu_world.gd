extends "res://scripts/menu_poster3d.gd"

# HEADLIGHTS' OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A COUNTRY
# ROAD AT NIGHT. A road winding through dark fields and trees, a farmhouse with a lit window, three small numbered
# DEPOTS along it, each under its own lamp -- and the game's delivery truck (an engine pulling a cart per parcel)
# driving round, seen only where its HEADLIGHTS fall: two cones sweeping the road ahead as it turns. As it passes
# each depot, in order, the depot's number lights. The night is a veil of dark over the baked country (`add_darkness`)
# with holes for the headlights, the depot lamps and a faint glow round the truck; the tail lamps glow live. The
# country is the baked picture, one per platform (`menu_road.webp`, `menu_road_d.webp`); the truck, the depots'
# numbers and the dark are live. Made up, never the board.

const LOOP: Array = [Vector3(-282.0, 0.0, 119.0), Vector3(-42.0, 0.0, 161.5), Vector3(126.0, 0.0, 76.5), Vector3(258.0, 0.0, -59.5),
	Vector3(318.0, 0.0, -221.0), Vector3(210.0, 0.0, -357.0), Vector3(18.0, 0.0, -306.0), Vector3(-120.0, 0.0, -170.0), Vector3(-318.0, 0.0, -102.0)]
const COLS: Array = [Color(0.88, 0.22, 0.20), Color(0.24, 0.50, 0.92), Color(0.96, 0.76, 0.18)]
const DEPOT_AT: Array = [0.22, 0.47, 0.70]          # where along the loop each depot stands (share of its length)
const SPEED: float = 120.0
const GAP: float = 60.0
const ROAD_W: float = 70.0

var _pts: PackedVector3Array = PackedVector3Array()   # the loop, sampled
var _cum: PackedFloat32Array = PackedFloat32Array()    # distance along it to each sample
var _len: float = 1.0
var _engine: Node3D = null
var _carts: Array = []
var _plates: Array = []

func _baked_path() -> String:
	return "res://delemfp/art/menu_road.webp" if mobile else "res://delemfp/art/menu_road_d.webp"

func _eye() -> Vector3:
	return Vector3(0.0, 560.0, 430.0) if mobile else Vector3(0.0, 560.0, 640.0)

func _aim() -> Vector3:
	return Vector3(0.0, 0.0, -90.0)

func _fov() -> float:
	return 58.0

func _environment(env: Environment) -> void:
	env.background_color = Color(0.02, 0.03, 0.06)
	# lit well: the NIGHT is the veil over it (add_darkness), and a hole in the veil shows the road as the lights see it
	env.ambient_light_color = Color(0.80, 0.80, 0.85)
	env.ambient_light_energy = 0.75

func _setup() -> void:
	_sample_loop()
	super._setup()
	add_darkness()

# the loop through its points (Catmull-Rom, closed), sampled evenly enough, with the distance to each sample
func _sample_loop() -> void:
	var n: int = LOOP.size()
	for i in n:
		var p0: Vector3 = LOOP[posmod(i - 1, n)]
		var p1: Vector3 = LOOP[i]
		var p2: Vector3 = LOOP[(i + 1) % n]
		var p3: Vector3 = LOOP[(i + 2) % n]
		for k in 40:
			var u: float = float(k) / 40.0
			var u2: float = u * u
			var u3: float = u2 * u
			_pts.append(0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3))
	_pts.append(_pts[0])
	_cum.append(0.0)
	for k2 in range(1, _pts.size()):
		_cum.append(_cum[k2 - 1] + _pts[k2].distance_to(_pts[k2 - 1]))
	_len = _cum[_cum.size() - 1]

# the point at distance d along the loop, and its heading (radians about +y, 0 = +x)
func _at(d: float) -> Array:
	var dd: float = fposmod(d, _len)
	var lo: int = 0
	var hi: int = _cum.size() - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) / 2
		if _cum[mid] <= dd:
			lo = mid
		else:
			hi = mid
	var s: float = (dd - _cum[lo]) / maxf(0.001, _cum[hi] - _cum[lo])
	var p: Vector3 = _pts[lo].lerp(_pts[hi], s)
	var tng: Vector3 = (_pts[hi] - _pts[lo]).normalized()
	return [p, atan2(-tng.z, tng.x), tng]

func _build_lights() -> void:
	# the moon, cool and faint; each depot's lamp, warm
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.light_color = Color(1.0, 0.94, 0.85)
	moon.light_energy = 1.0
	root.add_child(moon)
	moon.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	for k in DEPOT_AT.size():
		var a: Array = _depot(k)
		light((a[0] as Vector3) + Vector3(0.0, 90.0, 0.0), Color(1.0, 0.82, 0.55), 1.8, 260.0)

# a depot's place: beside the road at its share of the loop, set back on the OUTSIDE of the loop (the inside is the
# farmhouse's), turned so its door (local +z) faces the road
func _depot(k: int) -> Array:
	var a: Array = _at(float(DEPOT_AT[k]) * _len)
	var tng: Vector3 = a[2]
	var side: Vector3 = Vector3(tng.z, 0.0, -tng.x)
	var center: Vector3 = Vector3.ZERO
	for p in LOOP:
		center += p as Vector3
	center /= float(LOOP.size())
	var yaw: float = float(a[1])
	if side.dot((a[0] as Vector3) - center) < 0.0:
		side = -side
		yaw += PI
	return [(a[0] as Vector3) + side * (ROAD_W * 0.5 + 60.0), yaw]

# --- the country: baked -----------------------------------------------------------------------------------------

func _field(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var row: float = 0.5 + 0.5 * sin(float(x) * 0.35)
			img.set_pixel(x, y, Color(0.16, 0.22, 0.12).lerp(Color(0.24, 0.30, 0.15), row * 0.6 + 0.4 * h01(x * 7 + y * 13)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _build_still() -> void:
	var asphalt: StandardMaterial3D = mat(Color(0.20, 0.20, 0.22), 0.9)
	box(Vector3(4000.0, 4.0, 3000.0), mat(Color.WHITE, 1.0, 0.0, _field(128), Vector3(14, 10, 1)), Vector3(0.0, -2.0, -200.0))
	# THE ROAD: a ribbon along the loop, its verges, a dashed center line
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in _pts.size() - 1:
		var a: Vector3 = _pts[i]
		var b: Vector3 = _pts[i + 1]
		var tg: Vector3 = (b - a).normalized()
		var sd: Vector3 = Vector3(tg.z, 0.0, -tg.x) * ROAD_W * 0.5
		var lift: Vector3 = Vector3(0.0, 1.0, 0.0)
		for v in [a + sd, a - sd, b + sd, b - sd, b + sd, a - sd]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v + lift)
	var road: MeshInstance3D = MeshInstance3D.new()
	road.mesh = st.commit()
	road.material_override = asphalt
	root.add_child(road)
	var dash: StandardMaterial3D = mat(Color(0.92, 0.88, 0.70), 0.7)
	var d: float = 0.0
	while d < _len:
		var a2: Array = _at(d)
		box(Vector3(20.0, 0.6, 3.0), dash, (a2[0] as Vector3) + Vector3(0.0, 1.6, 0.0), Vector3(0.0, rad_to_deg(float(a2[1])), 0.0))
		d += 46.0
	# trees: round dark crowns in clumps, never on the road
	var leaf: StandardMaterial3D = mat(Color(0.10, 0.20, 0.10), 0.95)
	var bark: StandardMaterial3D = mat(Color(0.18, 0.12, 0.08), 0.95)
	var placed: int = 0
	var k: int = 0
	while placed < 46 and k < 400:
		var tp: Vector3 = Vector3((h01(k * 3 + 1) - 0.5) * 1100.0, 0.0, (h01(k * 3 + 2) - 0.5) * 1000.0 - 120.0)
		k += 1
		var clear: bool = true
		for j in range(0, _pts.size(), 4):
			if tp.distance_to(_pts[j]) < ROAD_W + 50.0:
				clear = false
				break
		for dk in DEPOT_AT.size():
			if tp.distance_to(_depot(dk)[0] as Vector3) < 110.0:
				clear = false
		if tp.distance_to(Vector3(10.0, 0.0, -140.0)) < 110.0:
			clear = false
		if not clear:
			continue
		var r: float = 26.0 + 22.0 * h01(k + 500)
		cyl(4.0, 5.0, 40.0, bark, tp + Vector3(0.0, 20.0, 0.0))
		sphere(r, leaf, tp + Vector3(0.0, 40.0 + r * 0.8, 0.0))
		placed += 1
	# a farmhouse with a lit window, off the road
	var house: Vector3 = Vector3(10.0, 0.0, -140.0)
	box(Vector3(110.0, 70.0, 80.0), mat(Color(0.60, 0.56, 0.50), 0.9), house + Vector3(0.0, 35.0, 0.0))
	box(Vector3(120.0, 6.0, 92.0), mat(Color(0.30, 0.16, 0.12), 0.8), house + Vector3(0.0, 80.0, 0.0), Vector3(0.0, 0.0, 0.0))
	put(_prism(60.0, 40.0, 92.0), mat(Color(0.34, 0.16, 0.12), 0.8), house + Vector3(0.0, 70.0, 0.0))
	box(Vector3(20.0, 18.0, 1.0), glow(Color(1.0, 0.82, 0.45)), house + Vector3(-25.0, 40.0, 40.6))
	# THE DEPOTS: a small shed with a roll door in its color, a lamp on a post, the number's board (lit live)
	for dk2 in DEPOT_AT.size():
		var dp: Array = _depot(dk2)
		var c: Vector3 = dp[0]
		var yaw: float = rad_to_deg(float(dp[1]))
		var shed: Node3D = Node3D.new()
		root.add_child(shed)
		shed.position = c
		shed.rotation_degrees = Vector3(0.0, yaw, 0.0)
		# its door faces the road (local +z)
		box(Vector3(90.0, 60.0, 60.0), mat(Color(0.52, 0.50, 0.48), 0.8), Vector3(0.0, 30.0, -30.0), Vector3.ZERO, shed)
		box(Vector3(98.0, 6.0, 70.0), mat(Color(0.25, 0.27, 0.30), 0.6, 0.4), Vector3(0.0, 63.0, -30.0), Vector3.ZERO, shed)
		box(Vector3(56.0, 46.0, 1.0), mat((COLS[dk2] as Color).lerp(Color(0.8, 0.8, 0.8), 0.4), 0.5, 0.3), Vector3(0.0, 23.0, 0.6), Vector3.ZERO, shed)
		cyl(2.5, 2.5, 100.0, mat(Color(0.2, 0.2, 0.22), 0.5, 0.5), Vector3(-56.0, 50.0, 6.0), Vector3.ZERO, shed)
		sphere(6.0, glow(Color(1.0, 0.86, 0.60)), Vector3(-56.0, 100.0, 6.0), shed)

func _prism(w: float, h: float, depth: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a: Vector3 = Vector3(-w, 0.0, -depth * 0.5)
	var b: Vector3 = Vector3(w, 0.0, -depth * 0.5)
	var c: Vector3 = Vector3(0.0, h, -depth * 0.5)
	var dz: Vector3 = Vector3(0.0, 0.0, depth)
	for v in [a, b, c, a + dz, c + dz, b + dz, a, c, c + dz, a, c + dz, a + dz, b, b + dz, c + dz, b, c + dz, c]:
		st.add_vertex(v)
	st.generate_normals()
	return st.commit()

# --- live: the truck and the depots' numbers ------------------------------------------------------------------------

func _wheel(parent: Node3D, x: float, z: float) -> void:
	cyl(9.0, 9.0, 7.0, mat(Color(0.10, 0.10, 0.11), 0.8), Vector3(x, 9.0, z), Vector3(90.0, 0.0, 0.0), parent, 18)

func _build_live() -> void:
	# (each depot's number is a badge drawn over the dark, facing you: _paint_top)
	for _dk in DEPOT_AT.size():
		_plates.append(0.0)
	_engine = Node3D.new()
	root.add_child(_engine)
	var paint: StandardMaterial3D = mat(Color(0.18, 0.42, 0.34), 0.35, 0.3)
	box(Vector3(60.0, 8.0, 34.0), mat(Color(0.15, 0.15, 0.16), 0.6, 0.4), Vector3(0.0, 14.0, 0.0), Vector3.ZERO, _engine)
	put(rbox_mesh(15.0, 17.0, 36.0, 5.0, 2.0), paint, Vector3(12.0, 18.0, 0.0), Vector3.ZERO, _engine)
	put(rbox_mesh(13.0, 16.0, 16.0, 4.0, 2.0), paint, Vector3(-14.0, 18.0, 0.0), Vector3.ZERO, _engine)
	box(Vector3(2.0, 14.0, 28.0), mat(Color(0.30, 0.45, 0.58), 0.1, 0.3), Vector3(27.6, 42.0, 0.0), Vector3.ZERO, _engine)
	for e in [-1.0, 1.0]:
		sphere(3.4, glow(Color(1.0, 0.96, 0.80)), Vector3(28.5, 24.0, e * 11.0), _engine)
	_wheel(_engine, 17.0, 17.0)
	_wheel(_engine, 17.0, -17.0)
	_wheel(_engine, -18.0, 17.0)
	_wheel(_engine, -18.0, -17.0)
	for k in 3:
		var cart: Node3D = Node3D.new()
		root.add_child(cart)
		box(Vector3(52.0, 6.0, 32.0), mat(Color(0.45, 0.34, 0.22), 0.7), Vector3(0.0, 18.0, 0.0), Vector3.ZERO, cart)
		box(Vector3(34.0, 26.0, 26.0), mat(COLS[2 - k], 0.6), Vector3(0.0, 34.0, 0.0), Vector3.ZERO, cart)
		_wheel(cart, 16.0, 16.0)
		_wheel(cart, 16.0, -16.0)
		_wheel(cart, -16.0, 16.0)
		_wheel(cart, -16.0, -16.0)
		_carts.append(cart)

# --- the motion ---------------------------------------------------------------------------------------------------

func _animate(_delta: float) -> void:
	if _engine == null:
		return
	var d: float = t * SPEED + _len * 0.05
	var a: Array = _at(d)
	_engine.position = a[0]
	_engine.rotation = Vector3(0.0, float(a[1]), 0.0)
	for k in _carts.size():
		var ak: Array = _at(d - GAP * float(k + 1))
		(_carts[k] as Node3D).position = ak[0]
		(_carts[k] as Node3D).rotation = Vector3(0.0, float(ak[1]), 0.0)
	# the depots' numbers: each lights as the truck passes it, and stays lit for the rest of the lap
	var lap_d: float = fposmod(d, _len)
	for k2 in _plates.size():
		var at_d: float = float(DEPOT_AT[k2]) * _len
		var lit: float = smoothstep(at_d, at_d + 40.0, lap_d) * (1.0 - smoothstep(_len - 120.0, _len - 20.0, lap_d))
		_plates[k2] = lit
	# THE NIGHT: dark, with the headlights' cones ahead of the truck, a pool under each depot lamp, a faint glow round
	# the truck itself, and the farmhouse window
	if _dark == null:
		return
	var tng: Vector3 = a[2]
	var side: Vector3 = Vector3(tng.z, 0.0, -tng.x)
	var cones: Array = []
	for e in [-1.0, 1.0]:
		var lamp: Vector3 = (a[0] as Vector3) + tng * 30.0 + side * e * 11.0 + Vector3(0.0, 4.0, 0.0)
		var sp: Vector3 = lamp
		# the beam follows the road a little ahead (it turns with it)
		var ahead: Vector3 = (_at(d + 220.0)[0] as Vector3) + side * e * 14.0
		var p0: Vector2 = screen_of(sp)
		var p1: Vector2 = screen_of(ahead)
		cones.append(Vector4(p0.x, p0.y, (p1 - p0).angle(), maxf(60.0, p0.distance_to(p1) * 1.35)))
	var lamps: Array = []
	var tp: Vector2 = screen_of(a[0])
	lamps.append(Vector4(tp.x, tp.y, 80.0, 0.5))
	for dk in DEPOT_AT.size():
		var dp: Array = _depot(dk)
		var lp: Vector2 = screen_of((dp[0] as Vector3))
		lamps.append(Vector4(lp.x, lp.y, 120.0, 0.85))
	var hp: Vector2 = screen_of(Vector3(-15.0, 40.0, -100.0))
	lamps.append(Vector4(hp.x, hp.y, 40.0, 0.6))
	set_darkness(0.86, Color(0.0, 0.01, 0.04), lamps, cones, [1.0, 1.0], 0.34, 0.32, Color(1.0, 0.86, 0.60))

func _paint_top(_full: Vector2, _bottom: float) -> void:
	# the truck's lamps over the dark: the headlamps bright, the tail lamps red
	if _engine != null and _dark != null:
		var d: float = t * SPEED + _len * 0.05
		var a: Array = _at(d)
		var tng: Vector3 = a[2]
		var side: Vector3 = Vector3(tng.z, 0.0, -tng.x)
		for e in [-1.0, 1.0]:
			var hp: Vector2 = screen_of((a[0] as Vector3) + tng * 30.0 + side * e * 11.0 + Vector3(0.0, 24.0, 0.0))
			for j in 4:
				cv.draw_circle(hp, 9.0 - float(j) * 2.0, Color(1.0, 0.96, 0.80, 0.25))
			var back: Array = _at(d - GAP * 3.0 - 28.0)
			var tl: Vector2 = screen_of((back[0] as Vector3) + side * e * 12.0 + Vector3(0.0, 20.0, 0.0))
			cv.draw_circle(tl, 5.0, Color(1.0, 0.15, 0.10, 0.35))
			cv.draw_circle(tl, 2.2, Color(1.0, 0.30, 0.25, 0.95))
	# THE DEPOTS' NUMBERS over their roofs, over the dark: a badge in the depot's color, lighting up as the truck passes
	if _dark != null:
		var f: Font = get_theme_default_font()
		var fs: int = 30 if mobile else 24
		for k3 in DEPOT_AT.size():
			var bp: Vector2 = screen_of((_depot(k3)[0] as Vector3) + Vector3(0.0, 120.0, 0.0))
			var lit2: float = float(_plates[k3]) if k3 < _plates.size() else 0.0
			var col: Color = (COLS[k3] as Color).darkened(0.55).lerp(COLS[k3], lit2)
			var r: float = float(fs) * 0.78
			if lit2 > 0.0:
				for j2 in 5:
					cv.draw_circle(bp, r + 4.0 + float(j2) * 4.0, Color(col, 0.10 * lit2))
			cv.draw_circle(bp + Vector2(2, 3), r, Color(0, 0, 0, 0.45))
			cv.draw_circle(bp, r, col)
			cv.draw_arc(bp, r, 0.0, TAU, 32, Color(1, 1, 1, 0.35 + 0.5 * lit2), 2.0, true)
			var txt: String = str(k3 + 1)
			var tw: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			cv.draw_string(f, bp + Vector2(-tw * 0.5, float(fs) * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.6 + 0.4 * lit2))
	title("Headlights", "Deliver packets in order while zoomed in", Color(1.0, 0.92, 0.70), Color(0.04, 0.06, 0.12),
		Color(0.8, 0.85, 1.0, 0.22))

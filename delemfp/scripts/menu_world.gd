extends "res://scripts/menu_poster3d.gd"

# HEADLIGHTS' OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A WAREHOUSE LANE
# AT NIGHT, at street level. A narrow lane of wet cobbles curving away between brick warehouses -- loading doors with
# their enamel number signs, pipes, a fire escape, wall lamps burning dim, a few lit windows high up -- and up the lane
# toward you comes the game's delivery truck, its HEADLIGHTS blazing: REAL lights now (2026-11-18; the user: "the
# scenery is nice but everything else pretty awful ... many many 3d ordering bugs" -- the night was a 2-D veil with
# holes cut for the beams, and the beams, the glare and the door numbers were drawn over everything). The lane renders
# LIVE at night: the truck's two headlamps are spot lights that sweep the brick and the wet cobbles as it rounds the
# bend (their shine on the puddles), soft beams of light in the damp air before them, their glare a flare that a wall
# hides like anything else; tail lamps glowing red; the three numbered doors' signs light in order as it passes them
# -- the game: the route ahead seen only in the headlights. Made up, never the board.

const PATH: Array = [Vector3(-620.0, 0.0, -1500.0), Vector3(-420.0, 0.0, -1050.0), Vector3(-120.0, 0.0, -700.0),
	Vector3(40.0, 0.0, -350.0), Vector3(90.0, 0.0, 0.0), Vector3(110.0, 0.0, 300.0), Vector3(120.0, 0.0, 700.0)]
const COLS: Array = [Color(0.88, 0.22, 0.20), Color(0.24, 0.50, 0.92), Color(0.96, 0.76, 0.18)]
const DOCK_AT: Array = [0.28, 0.46, 0.62]       # shares of the path where the doors stand, on its left
const LANE_W: float = 170.0
const SPEED: float = 165.0
const GAP: float = 64.0

var _pts: PackedVector3Array = PackedVector3Array()
var _cum: PackedFloat32Array = PackedFloat32Array()
var _len: float = 1.0
var _engine: Node3D = null
var _carts: Array = []
var _lit: Array = [0.0, 0.0, 0.0]
var _sign_mats: Array = []
var _sign_nums: Array = []
var _beams: Array = []                   # the beams' materials

# no picture: the lane is lit live, by the truck's own lights
func _baked_path() -> String:
	return ""

func _eye() -> Vector3:
	# standing in the lane, low, looking up it toward the bend
	return Vector3(115.0, 105.0, 560.0) if mobile else Vector3(115.0, 125.0, 720.0)

func _aim() -> Vector3:
	return Vector3(-40.0, 75.0, -420.0)

func _fov() -> float:
	return 62.0

func _environment(env: Environment) -> void:
	env.background_color = Color(0.03, 0.04, 0.08)
	env.ambient_light_color = Color(0.40, 0.45, 0.62)
	env.ambient_light_energy = 0.16
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.05, 0.06, 0.10)
	env.fog_depth_begin = 8.0
	env.fog_depth_end = 26.0
	env.fog_density = 0.85
	env.fog_sky_affect = 0.0

func _setup() -> void:
	_sample_path()
	_collect_glows()
	super._setup()

func _sample_path() -> void:
	var n: int = PATH.size()
	for i in n - 1:
		var p0: Vector3 = PATH[maxi(0, i - 1)]
		var p1: Vector3 = PATH[i]
		var p2: Vector3 = PATH[i + 1]
		var p3: Vector3 = PATH[mini(n - 1, i + 2)]
		for k in 30:
			var u: float = float(k) / 30.0
			var u2: float = u * u
			var u3: float = u2 * u
			_pts.append(0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3))
	_pts.append(PATH[n - 1])
	_cum.append(0.0)
	for k2 in range(1, _pts.size()):
		_cum.append(_cum[k2 - 1] + _pts[k2].distance_to(_pts[k2 - 1]))
	_len = _cum[_cum.size() - 1]

# the point at distance d along the lane (clamped), its heading about +y (0 = +x) and its tangent
func _at(d: float) -> Array:
	var dd: float = clampf(d, 0.0, _len - 0.01)
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
	# past the lane's end it drives straight on (under the camera and out of the foot of the picture)
	if d > _len:
		p = _pts[_pts.size() - 1] + tng * (d - _len)
	return [p, atan2(-tng.z, tng.x), tng]

# the left of travel at distance d (the side the doors are on)
func _left(d: float) -> Vector3:
	var tng: Vector3 = _at(d)[2]
	return Vector3(tng.z, 0.0, -tng.x)

func _build_lights() -> void:
	# a faint moonlight from above the roofs; each wall lamp a real light, warm and dim
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.62, 0.90)
	moon.light_energy = 0.22
	root.add_child(moon)
	moon.rotation_degrees = Vector3(-60.0, 25.0, 0.0)
	for g in _glows:
		if int(g[1]) == 0:
			light((g[0] as Vector3) + Vector3(0.0, -8.0, 0.0), Color(1.0, 0.76, 0.46), 0.9, 230.0)

# --- textures ---------------------------------------------------------------------------------------------------

func _brick(n: int, base: Color) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	img.fill(Color(0.30, 0.28, 0.26))
	var bh: int = n / 16
	var bw: int = n / 8
	for row in 16:
		var off: int = (bw / 2) if row % 2 == 1 else 0
		for col in 9:
			var x0: int = col * bw - off
			var c: Color = base.darkened(0.15 * h01(row * 31 + col)).lightened(0.08 * h01(row * 7 + col * 3))
			img.fill_rect(Rect2i(maxi(0, x0 + 1), row * bh + 1, mini(bw - 2, n - maxi(0, x0 + 1)), bh - 2), c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _cobbles(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	img.fill(Color(0.16, 0.16, 0.17))
	var cs: int = n / 12
	for row in 12:
		var off: int = (cs / 2) if row % 2 == 1 else 0
		for col in 13:
			var x0: int = col * cs - off
			var c: Color = Color(0.40, 0.39, 0.38).darkened(0.25 * h01(row * 17 + col)).lerp(Color(0.36, 0.33, 0.30), 0.3 * h01(row + col * 5))
			for yy in cs - 2:
				for xx in cs - 2:
					var dx: float = (float(xx) - float(cs - 2) * 0.5) / float(cs - 2)
					var dy: float = (float(yy) - float(cs - 2) * 0.5) / float(cs - 2)
					if dx * dx + dy * dy < 0.26:
						var px: int = x0 + 1 + xx
						if px >= 0 and px < n:
							img.set_pixel(px, row * cs + 1 + yy, c.lightened(0.18 * maxf(0.0, -dx - dy)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# where the wall lamps and the lit windows are (the same walk as the still build): [world place, kind 0 lamp / 1 window]
var _glows: Array = []

func _collect_glows() -> void:
	_glows.clear()
	for side in [-1.0, 1.0]:
		var d: float = 60.0
		var k: int = 0
		while d < _len - 60.0:
			var a2: Array = _at(d)
			var tg2: Vector3 = a2[2]
			var sd2: Vector3 = Vector3(tg2.z, 0.0, -tg2.x) * side
			var w: float = 230.0 + 80.0 * h01(k + int(side * 10.0) + 20)
			var h: float = 260.0 + 160.0 * h01(k * 3 + int(side * 7.0) + 40)
			var c: Vector3 = (a2[0] as Vector3) + sd2 * (LANE_W * 0.5 + 42.0 + 60.0)
			var basis: Basis = Basis(Vector3.UP, float(a2[1]))
			var face_z: float = side * 60.5
			for wy in 2:
				for wx in 3:
					if h01(k * 11 + wx + wy * 5 + int(side * 3.0) + 60) > 0.84:
						_glows.append([c + basis * Vector3(-w * 0.32 + float(wx) * w * 0.32, h * 0.62 + float(wy) * 60.0, face_z), 1])
			if k % 2 == 1:
				_glows.append([c + basis * Vector3(-w * 0.25, 146.0, face_z + side * 26.0), 0])
			d += w
			k += 1

# --- the lane: baked ---------------------------------------------------------------------------------------------

func _build_still() -> void:
	var cob: StandardMaterial3D = mat(Color.WHITE, 0.25, 0.15, _cobbles(192), Vector3(1, 1, 1))
	var brick_a: StandardMaterial3D = mat(Color.WHITE, 0.85, 0.0, _brick(256, Color(0.52, 0.26, 0.18)), Vector3(3, 3, 1))
	var brick_b: StandardMaterial3D = mat(Color.WHITE, 0.85, 0.0, _brick(256, Color(0.44, 0.34, 0.28)), Vector3(3, 3, 1))
	var stone: StandardMaterial3D = mat(Color(0.52, 0.50, 0.48), 0.8)
	var iron: StandardMaterial3D = mat(Color(0.14, 0.14, 0.15), 0.5, 0.6)
	var steel: StandardMaterial3D = mat(Color(0.50, 0.52, 0.56), 0.4, 0.7)
	# THE LANE: wet cobbles along the path (a ribbon, its texture laid along the way), stone kerbs each side
	# (in lengths: this renderer lights a mesh with at most 8 lights, and the lane runs past many)
	var i0: int = 0
	while i0 < _pts.size() - 1:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(i0, mini(i0 + 14, _pts.size() - 1)):
			var a: Vector3 = _pts[i]
			var b: Vector3 = _pts[i + 1]
			var tg: Vector3 = (b - a).normalized()
			var sd: Vector3 = Vector3(tg.z, 0.0, -tg.x) * LANE_W * 0.5
			var va: float = _cum[i] / 70.0
			var vb: float = _cum[i + 1] / 70.0
			for q in [[a + sd, Vector2(0, va)], [a - sd, Vector2(2.4, va)], [b + sd, Vector2(0, vb)], [b - sd, Vector2(2.4, vb)], [b + sd, Vector2(0, vb)], [a - sd, Vector2(2.4, va)]]:
				st.set_normal(Vector3.UP)
				st.set_uv(q[1])
				st.add_vertex((q[0] as Vector3) + Vector3(0.0, 0.5, 0.0))
		var lane: MeshInstance3D = MeshInstance3D.new()
		lane.mesh = st.commit()
		lane.material_override = cob
		root.add_child(lane)
		i0 += 14
	box(Vector3(6000.0, 2.0, 6000.0), mat(Color(0.22, 0.21, 0.20), 0.8), Vector3(0.0, -1.0, -1000.0))
	# THE WAREHOUSES along both sides: blocks set back from the kerb, brick, a stone string course and cornice, windows
	# (a few lit high up), drainpipes, wall lamps, a fire escape on the right
	for side in [-1.0, 1.0]:
		var d: float = 60.0
		var k: int = 0
		while d < _len - 60.0:
			var a2: Array = _at(d)
			var tg2: Vector3 = a2[2]
			var sd2: Vector3 = Vector3(tg2.z, 0.0, -tg2.x) * side
			var w: float = 230.0 + 80.0 * h01(k + int(side * 10.0) + 20)
			var h: float = 260.0 + 160.0 * h01(k * 3 + int(side * 7.0) + 40)
			var c: Vector3 = (a2[0] as Vector3) + sd2 * (LANE_W * 0.5 + 42.0 + 60.0)
			var yaw: float = rad_to_deg(float(a2[1]))
			var block: Node3D = Node3D.new()
			root.add_child(block)
			block.position = c
			block.rotation_degrees = Vector3(0.0, yaw, 0.0)
			box(Vector3(w - 4.0, h, 120.0), brick_a if k % 2 == 0 else brick_b, Vector3(0.0, h * 0.5, 0.0), Vector3.ZERO, block)
			box(Vector3(w, 8.0, 124.0), stone, Vector3(0.0, h * 0.55, 0.0), Vector3.ZERO, block)
			box(Vector3(w + 6.0, 10.0, 128.0), stone, Vector3(0.0, h + 4.0, 0.0), Vector3.ZERO, block)
			var face_z: float = side * 60.5
			for wy in 2:
				for wx in 3:
					var lit: bool = h01(k * 11 + wx + wy * 5 + int(side * 3.0) + 60) > 0.84
					var wpos: Vector3 = Vector3(-w * 0.32 + float(wx) * w * 0.32, h * 0.62 + float(wy) * 60.0, face_z)
					box(Vector3(34.0, 44.0, 2.0), glow(Color(1.0, 0.80, 0.48)) if lit else mat(Color(0.12, 0.14, 0.18), 0.1, 0.4), wpos, Vector3.ZERO, block)
					box(Vector3(40.0, 5.0, 6.0), stone, wpos + Vector3(0.0, -25.0, side * 2.0), Vector3.ZERO, block)
			cyl(4.0, 4.0, h, iron, Vector3(w * 0.5 - 8.0, h * 0.5, face_z + side * 4.0), Vector3.ZERO, block)
			if k % 2 == 1:
				var lp: Vector3 = Vector3(-w * 0.25, 150.0, face_z + side * 2.0)
				put(tube_mesh(PackedVector3Array([lp, lp + Vector3(0.0, 10.0, side * 14.0), lp + Vector3(0.0, 4.0, side * 26.0)]), 1.8, 8), iron, Vector3.ZERO, Vector3.ZERO, block)
				cyl(3.0, 11.0, 8.0, iron, lp + Vector3(0.0, 0.0, side * 26.0), Vector3.ZERO, block, 16)
				sphere(3.6, glow(Color(1.0, 0.86, 0.60)), lp + Vector3(0.0, -4.0, side * 26.0), block)
			if side > 0.0 and k == 1:
				for fl in 3:
					box(Vector3(120.0, 3.0, 36.0), iron, Vector3(0.0, 120.0 + float(fl) * 70.0, face_z + side * 18.0), Vector3.ZERO, block)
					box(Vector3(120.0, 18.0, 1.5), mat(Color(0.14, 0.14, 0.15, 0.7), 0.5, 0.6), Vector3(0.0, 130.0 + float(fl) * 70.0, face_z + side * 36.0), Vector3.ZERO, block)
			d += w
			k += 1
		var kd: float = 0.0
		while kd < _len:
			var a3: Array = _at(kd)
			var tg3: Vector3 = a3[2]
			var sd3: Vector3 = Vector3(tg3.z, 0.0, -tg3.x) * side
			box(Vector3(42.0, 8.0, 10.0), stone, (a3[0] as Vector3) + sd3 * (LANE_W * 0.5 + 5.0) + Vector3(0.0, 4.0, 0.0), Vector3(0.0, rad_to_deg(float(a3[1])), 0.0))
			kd += 40.0
	# THE LOADING DOORS on the left wall, numbered (their numbers lit live): a steel frame, a roll-up door with its ribs,
	# a hazard-striped step, a small canopy
	for di in DOCK_AT.size():
		var dd: float = float(DOCK_AT[di]) * _len
		var a4: Array = _at(dd)
		var lf: Vector3 = _left(dd)
		var dock: Node3D = Node3D.new()
		root.add_child(dock)
		dock.position = (a4[0] as Vector3) + lf * (LANE_W * 0.5 + 41.0)
		dock.rotation_degrees = Vector3(0.0, rad_to_deg(float(a4[1])), 0.0)
		# local +z is the RIGHT of travel: from the left wall, that is toward the lane, where the door faces
		var fz: float = 1.0
		box(Vector3(96.0, 110.0, 4.0), steel, Vector3(0.0, 55.0, fz * 2.0), Vector3.ZERO, dock)
		box(Vector3(86.0, 100.0, 3.0), mat((COLS[di] as Color).lerp(Color(0.82, 0.82, 0.82), 0.5), 0.5, 0.3), Vector3(0.0, 50.0, fz * 4.0), Vector3.ZERO, dock)
		for rb in 7:
			box(Vector3(86.0, 1.6, 1.0), mat(Color(0.30, 0.30, 0.32), 0.5), Vector3(0.0, 8.0 + float(rb) * 13.0, fz * 5.8), Vector3.ZERO, dock)
		box(Vector3(110.0, 4.0, 40.0), mat(Color(0.20, 0.22, 0.24), 0.5, 0.5), Vector3(0.0, 120.0, fz * 20.0), Vector3(fz * -8.0, 0.0, 0.0), dock)
		for hs in 6:
			box(Vector3(16.0, 6.0, 14.0), mat(Color(0.95, 0.75, 0.15) if hs % 2 == 0 else Color(0.08, 0.08, 0.09), 0.6), Vector3(-40.0 + float(hs) * 16.0, 3.0, fz * 10.0), Vector3.ZERO, dock)
		# ITS NUMBER: an enamel disc in the door's color on the wall over the canopy, a white rim, the figure -- lit from
		# within as the truck passes (live: _sign_mats)
		var sm: StandardMaterial3D = mat((COLS[di] as Color).darkened(0.55), 0.35)
		sm.emission_enabled = true
		sm.emission = COLS[di]
		sm.emission_energy_multiplier = 0.0
		cyl(23.0, 23.0, 3.0, mat(Color(0.94, 0.94, 0.90), 0.3), Vector3(0.0, 150.0, fz * 6.0), Vector3(90.0, 0.0, 0.0), dock, 32)
		cyl(19.5, 19.5, 3.6, sm, Vector3(0.0, 150.0, fz * 6.2), Vector3(90.0, 0.0, 0.0), dock, 32)
		var num: Label3D = label(str(di + 1), 26.0, Color(1.0, 1.0, 0.96), Vector3(0.0, 150.0, fz * 8.2), Vector3.ZERO, dock)
		num.outline_size = 6
		num.outline_modulate = Color(0.0, 0.0, 0.0, 0.5)
		num.shaded = true
		_sign_mats.append(sm)
		_sign_nums.append(num)
	# puddles in the lane: a faint film of water that catches the lights' shine (opaque and glossy they were black holes: this
	# renderer reflects nothing),
	# none in the near foreground
	for pk in 6:
		var pd: float = _len * (0.12 + 0.10 * float(pk))
		var pa: Array = _at(pd)
		var pp: Vector3 = (pa[0] as Vector3) + _left(pd) * ((h01(pk) - 0.5) * LANE_W * 0.7)
		var film: StandardMaterial3D = mat(Color(0.55, 0.60, 0.70, 0.20), 0.03, 0.0)
		film.metallic_specular = 1.0
		var puddle: MeshInstance3D = cyl(26.0 + 16.0 * h01(pk + 9), 26.0, 0.4, film, pp + Vector3(0.0, 1.0, 0.0))
		puddle.scale = Vector3(1.6, 1.0, 0.8)

# --- live: the truck ----------------------------------------------------------------------------------------------

func _wheel(parent: Node3D, x: float, z: float) -> void:
	cyl(10.0, 10.0, 7.0, mat(Color(0.08, 0.08, 0.09), 0.85), Vector3(x, 10.0, z), Vector3(90.0, 0.0, 0.0), parent, 20)
	cyl(5.0, 5.0, 7.6, mat(Color(0.72, 0.74, 0.78), 0.3, 0.8), Vector3(x, 10.0, z), Vector3(90.0, 0.0, 0.0), parent, 14)

func _build_live() -> void:
	# THE ENGINE: a small cab-over delivery tractor -- a rounded cab in green enamel, its windscreen and side windows,
	# a chrome grille and bumper, mudguards curved over the wheels, a roof marker lamp; its two HEADLAMPS chrome bowls
	# with their lenses lit, each a real spot light down the lane, a soft beam in the damp air, a flare at the lens
	var paint: StandardMaterial3D = mat(Color(0.14, 0.36, 0.30), 0.22, 0.4)
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.9
	paint.clearcoat_roughness = 0.08
	var chrome: StandardMaterial3D = mat(Color(0.82, 0.84, 0.88), 0.12, 0.95)
	var dark: StandardMaterial3D = mat(Color(0.08, 0.08, 0.09), 0.5, 0.5)
	var glass: StandardMaterial3D = mat(Color(0.10, 0.14, 0.20), 0.04, 0.5)
	var lens: StandardMaterial3D = glow(Color(1.0, 0.97, 0.88))
	_engine = Node3D.new()
	root.add_child(_engine)
	box(Vector3(70.0, 8.0, 34.0), dark, Vector3(-2.0, 14.0, 0.0), Vector3.ZERO, _engine)
	put(rbox_mesh(20.0, 19.0, 36.0, 7.0, 4.0), paint, Vector3(10.0, 18.0, 0.0), Vector3.ZERO, _engine)
	put(rbox_mesh(14.0, 18.0, 16.0, 6.0, 3.0), paint, Vector3(-16.0, 18.0, 0.0), Vector3.ZERO, _engine)
	box(Vector3(1.2, 15.0, 31.0), glass, Vector3(29.9, 44.0, 0.0), Vector3(0.0, 0.0, 10.0), _engine)
	for e in [-1.0, 1.0]:
		box(Vector3(24.0, 13.0, 0.8), glass, Vector3(10.0, 44.0, e * 19.3), Vector3.ZERO, _engine)
		# the mudguard: a curved arch over each front wheel
		var arch: PackedVector3Array = PackedVector3Array()
		for ak in 9:
			var aa: float = PI * float(ak) / 8.0
			arch.append(Vector3(17.0 + cos(aa) * 13.0, 10.0 + sin(aa) * 13.0, e * 18.5))
		put(tube_mesh(arch, 3.2, 8), paint, Vector3.ZERO, Vector3.ZERO, _engine)
		# the headlamp: a chrome bowl, its lens, a rim
		var hl: Vector3 = Vector3(31.0, 27.0, e * 12.0)
		var bowl: MeshInstance3D = sphere(5.6, chrome, hl + Vector3(-2.0, 0.0, 0.0), _engine, true)
		bowl.rotation_degrees = Vector3(0.0, 0.0, -90.0)
		cyl(4.6, 4.6, 0.8, lens, hl + Vector3(0.6, 0.0, 0.0), Vector3(0.0, 0.0, 90.0), _engine, 20)
		# THE LIGHT: down the lane, a little toward the ground
		var sl: SpotLight3D = SpotLight3D.new()
		sl.light_color = Color(1.0, 0.94, 0.80)
		sl.light_energy = 5.0
		sl.spot_range = 6.5
		sl.spot_angle = 24.0
		sl.spot_attenuation = 0.9
		sl.shadow_enabled = e < 0.0
		_engine.add_child(sl)
		sl.transform = Transform3D(Basis.looking_at(Vector3(1.0, -0.10, -e * 0.06)), hl + Vector3(1.5, 0.0, 0.0))
		# the beam in the damp air: a soft cone fading out ahead (additive light: the lane is rendered whole here)
		var bmat: ShaderMaterial = ShaderMaterial.new()
		bmat.shader = _beam_shader()
		var cone: CylinderMesh = CylinderMesh.new()
		cone.top_radius = 3.0
		cone.bottom_radius = 70.0
		cone.height = 340.0
		cone.cap_top = false
		cone.cap_bottom = false
		cone.radial_segments = 24
		var dir: Vector3 = Vector3(1.0, -0.10, -e * 0.06).normalized()
		var cm: MeshInstance3D = put(cone, bmat, Vector3.ZERO, Vector3.ZERO, _engine)
		cm.transform = Transform3D(Basis(Quaternion(Vector3.UP, -dir)), hl + dir * 170.0)
		_beams.append(bmat)
		# the flare at the lens: a soft billboard of light, hidden by whatever stands in front of it
		var flare: StandardMaterial3D = StandardMaterial3D.new()
		flare.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flare.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		flare.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		flare.billboard_keep_scale = true          # (without it the billboard dropped the 1:100 root and was 46 metres wide)
		flare.albedo_texture = _soft_tex()
		flare.albedo_color = Color(1.0, 0.92, 0.75, 0.9)
		flare.disable_fog = true
		var fq: QuadMesh = QuadMesh.new()
		fq.size = Vector2(46.0, 46.0)
		put(fq, flare, hl + Vector3(4.0, 0.0, 0.0), Vector3.ZERO, _engine)
	# the grille, the bumper, the roof lamp, an exhaust stack
	box(Vector3(1.4, 13.0, 18.0), dark, Vector3(30.2, 25.0, 0.0), Vector3.ZERO, _engine)
	for gb in 5:
		box(Vector3(1.8, 1.0, 17.0), chrome, Vector3(30.8, 19.5 + float(gb) * 2.8, 0.0), Vector3.ZERO, _engine)
	put(rbox_mesh(2.4, 21.0, 5.0, 2.0, 1.0), chrome, Vector3(32.0, 10.0, 0.0), Vector3.ZERO, _engine)
	cyl(2.0, 2.0, 3.0, glow(Color(1.0, 0.60, 0.20)), Vector3(12.0, 57.5, 0.0), Vector3.ZERO, _engine, 12)
	cyl(2.4, 2.4, 32.0, chrome, Vector3(-6.0, 50.0, -15.0), Vector3.ZERO, _engine, 10)
	_wheel(_engine, 17.0, 17.0)
	_wheel(_engine, 17.0, -17.0)
	_wheel(_engine, -17.0, 17.0)
	_wheel(_engine, -17.0, -17.0)
	# THE CARTS: a wooden flatbed each, stake sides, its parcel -- a taped carton with a label in its door's color
	var plank: StandardMaterial3D = mat(Color.WHITE, 0.7, 0.0, tex_wood(64, Color(0.46, 0.32, 0.18), 6), Vector3(2, 1, 1))
	var card: StandardMaterial3D = mat(Color.WHITE, 0.85, 0.0, tex_speckle(64, Color(0.66, 0.50, 0.32), 0.10, 9))
	var tape: StandardMaterial3D = mat(Color(0.80, 0.68, 0.46), 0.4)
	for k in 3:
		var cart: Node3D = Node3D.new()
		root.add_child(cart)
		box(Vector3(52.0, 4.0, 32.0), plank, Vector3(0.0, 19.0, 0.0), Vector3.ZERO, cart)
		box(Vector3(52.0, 3.0, 30.0), dark, Vector3(0.0, 15.0, 0.0), Vector3.ZERO, cart)
		for rs in [-1.0, 1.0]:
			box(Vector3(50.0, 2.0, 2.0), plank, Vector3(0.0, 29.0, rs * 15.0), Vector3.ZERO, cart)
			for sk in 3:
				box(Vector3(2.0, 10.0, 2.0), plank, Vector3(-20.0 + float(sk) * 20.0, 24.0, rs * 15.0), Vector3.ZERO, cart)
		box(Vector3(32.0, 24.0, 24.0), card, Vector3(0.0, 33.0, 0.0), Vector3.ZERO, cart)
		box(Vector3(32.4, 0.6, 6.0), tape, Vector3(0.0, 45.2, 0.0), Vector3.ZERO, cart)
		box(Vector3(14.0, 10.0, 0.6), mat((COLS[2 - k] as Color), 0.5), Vector3(-4.0, 34.0, 12.4), Vector3.ZERO, cart)
		box(Vector3(14.0, 10.0, 0.6), mat((COLS[2 - k] as Color), 0.5), Vector3(-4.0, 34.0, -12.4), Vector3.ZERO, cart)
		cyl(1.6, 1.6, 20.0, chrome, Vector3(34.0, 16.0, 0.0), Vector3(0.0, 0.0, 90.0), cart, 8)
		_wheel(cart, 15.0, 15.0)
		_wheel(cart, 15.0, -15.0)
		_wheel(cart, -15.0, 15.0)
		_wheel(cart, -15.0, -15.0)
		if k == 2:
			# tail lamps on the last, red, with a little red light on the cobbles behind
			for e2 in [-1.0, 1.0]:
				cyl(2.6, 2.6, 1.4, glow(Color(1.0, 0.16, 0.10)), Vector3(-26.6, 22.0, e2 * 12.0), Vector3(0.0, 0.0, 90.0), cart, 14)
			light(Vector3(-40.0, 18.0, 0.0), Color(1.0, 0.15, 0.10), 0.8, 90.0, false, cart)
		_carts.append(cart)

var _beam_sh: Shader = null

func _beam_shader() -> Shader:
	if _beam_sh != null:
		return _beam_sh
	_beam_sh = Shader.new()
	_beam_sh.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform float strength = 0.9;
void fragment() {
	float edge = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	float along = UV.y;                       // 0 at the lamp .. 1 at the far end
	float fade = (1.0 - smoothstep(0.0, 1.0, along)) * smoothstep(0.0, 0.08, along);
	ALBEDO = vec3(1.0, 0.92, 0.75) * 0.10 * strength * edge * fade;
}"""
	return _beam_sh

var _soft: Texture2D = null

func _soft_tex() -> Texture2D:
	if _soft == null:
		var gt: GradientTexture2D = GradientTexture2D.new()
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(0, 0, 0, 0))
		g.add_point(0.15, Color(1, 1, 1, 0.8))
		g.add_point(0.45, Color(0.4, 0.38, 0.32, 0.25))
		gt.gradient = g
		_soft = gt
	return _soft

# the truck from the far bend all the way down past you, the whole train; then the next one is already rounding the
# bend (the user: never a moment without a car; it vanished as it came to the front, when a fixed cycle ran out)
# THE TRUCK IS ALWAYS IN THE LANE (the user: never a time without one, and it drove off the front's end and vanished):
# each starts just behind the far bend, where the walls still hide it, and drives all the way down and under the
# camera until its last cart is out of the foot of the picture -- the moment the next comes round the bend
const ENTER_D: float = 820.0

func _truck_d() -> float:
	var out_d: float = _len + (_eye().z - (_pts[_pts.size() - 1] as Vector3).z) + 80.0 + GAP * 3.0
	var cyc: float = (out_d - ENTER_D) / SPEED
	return ENTER_D + fmod(t, cyc) * SPEED

func _animate(_delta: float) -> void:
	if _engine == null:
		return
	var d: float = _truck_d()
	var a: Array = _at(d)
	_engine.position = a[0]
	_engine.rotation = Vector3(0.0, float(a[1]), 0.0)
	_engine.visible = (a[0] as Vector3).z < _eye().z + 60.0
	for k in _carts.size():
		var ak: Array = _at(d - GAP * float(k + 1))
		var cart: Node3D = _carts[k]
		cart.position = ak[0]
		cart.rotation = Vector3(0.0, float(ak[1]), 0.0)
		cart.visible = (ak[0] as Vector3).z < _eye().z + 60.0
	# the doors' signs: each lights as the truck reaches it, and stays lit till the truck is gone
	for di in DOCK_AT.size():
		var dd: float = float(DOCK_AT[di]) * _len
		_lit[di] = smoothstep(dd - 60.0, dd, d) * (1.0 - smoothstep(_len - 120.0, _len - 30.0, d))
		var sm: StandardMaterial3D = _sign_mats[di]
		sm.emission_energy_multiplier = 2.2 * float(_lit[di])
		sm.albedo_color = (COLS[di] as Color).darkened(0.55).lerp(COLS[di], float(_lit[di]))
		var nl: Label3D = _sign_nums[di]
		nl.modulate = Color(1.0, 1.0, 0.96).lerp(Color(0.06, 0.05, 0.04), smoothstep(0.2, 0.7, float(_lit[di])))

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Headlights", "Deliver packets in order while zoomed in", Color(1.0, 0.92, 0.70), Color(0.04, 0.06, 0.12),
		Color(0.8, 0.85, 1.0, 0.22))

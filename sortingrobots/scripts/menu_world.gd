extends "res://scripts/menu_poster3d.gd"

# SORTING ROBOTS' OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A ROBOT
# SORTING STATION (2026-11-18, a new concept -- the crane swinging one parcel over a pile was "a bit boring", the
# user). In a lit depot -- pendant lamps, a corrugated wall with windows, floor markings, safety rails -- parcels come
# out through a strip curtain on a running belt, each carrying two of the game's shapes on its lid (Sleek's palette),
# pass under a SCANNER ARCH whose red laser sweeps them, and at the belt's end a ROBOT ARM (a turning base, two links
# solved to their fixed lengths, a wrist and a suction gripper) picks each one up, swings it round and sets it on
# one of two chutes -- the green or the red, by a rule you would have to work out -- down which it slides into its
# bin, the chute's lamp flashing. The depot, the belt's frame, the chutes and bins are baked, one picture per platform
# (`menu_depot.webp`, `menu_depot_d.webp`); the belt's surface, the parcels, the arm, the laser and the lamps are live.
# Made up, never the board.

const PAL: Array = [Color(0.878, 0.267, 0.271), Color(0.259, 0.518, 0.882), Color(0.243, 0.706, 0.400), Color(0.914, 0.729, 0.212)]
const BELT_Y: float = 80.0
const BELT_X0: float = -470.0
const BELT_X1: float = 20.0
const BASE: Vector3 = Vector3(140.0, 0.0, 0.0)
const SHOULDER_H: float = 120.0
const L1: float = 130.0
const L2: float = 120.0
const PERIOD: float = 3.0
const CHUTES: Array = [Vector3(225.0, 100.0, -35.0), Vector3(330.0, 100.0, -35.0)]   # where a parcel is set down: green, red (side by side at the robot's right)
const WALL_Z: float = -190.0             # the sorting wall the chutes run down into, through curtained hatches
const SLOPE: float = 18.0                # the chutes' fall, degrees
const HATCH_W: float = 84.0
const HATCH_Y0: float = 22.0
const HATCH_Y1: float = 118.0
const POOL: int = 6
const PARCEL: Vector3 = Vector3(56.0, 36.0, 46.0)

var _belt_m: StandardMaterial3D = null
var _parcels: Array = []                # [Node3D, [shape nodes per slot], [materials per slot]] per pool slot
var _shown_id: Array = []
var _base_yaw: Node3D = null
var _upper: Node3D = null
var _fore: Node3D = null
var _wrist: Node3D = null
var _laser: MeshInstance3D = null
var _lamps: Array = []
var _strips: Array = []                 # per hatch, its curtain strips' pivots

func _baked_path() -> String:
	return "res://sortingrobots/art/menu_depot.webp" if mobile else "res://sortingrobots/art/menu_depot_d.webp"

func _eye() -> Vector3:
	return Vector3(190.0, 330.0, 480.0) if mobile else Vector3(150.0, 300.0, 640.0)

func _aim() -> Vector3:
	return Vector3(120.0, 70.0, -70.0) if mobile else Vector3(70.0, 85.0, -70.0)

func _fov() -> float:
	return 54.0

func _environment(env: Environment) -> void:
	env.background_color = Color(0.10, 0.11, 0.13)
	env.ambient_light_color = Color(0.62, 0.64, 0.70)
	env.ambient_light_energy = 0.45

func _build_lights() -> void:
	# pendant lamps over the belt and the robot, warm; a cool light from the windows
	for lx in [-380.0, -100.0, 200.0]:
		light(Vector3(lx, 330.0, 0.0), Color(1.0, 0.90, 0.72), 2.2, 420.0, lx > 100.0)
	var win: DirectionalLight3D = DirectionalLight3D.new()
	win.light_color = Color(0.70, 0.80, 1.0)
	win.light_energy = 0.55
	root.add_child(win)
	win.rotation_degrees = Vector3(-35.0, -30.0, 0.0)

# --- textures ---------------------------------------------------------------------------------------------------

func _belt_tex(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var ridge: bool = (x % 16) < 3
			img.set_pixel(x, y, Color(0.10, 0.10, 0.11) if ridge else Color(0.17, 0.17, 0.18).darkened(0.1 * h01(x * 7 + y * 3)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _cardboard(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			img.set_pixel(x, y, Color(0.72, 0.55, 0.34).darkened(0.08 * h01(x * 13 + y * 5)).lerp(Color(0.62, 0.46, 0.28), 0.3 * float((y / 3) % 2)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _corrugated(n: int) -> ImageTexture:
	var img: Image = Image.create(n, 4, false, Image.FORMAT_RGB8)
	for x in n:
		var v: float = 0.5 + 0.5 * sin(float(x) / float(n) * TAU * 8.0)
		img.fill_rect(Rect2i(x, 0, 1, 4), Color(0.34, 0.40, 0.44).lerp(Color(0.52, 0.58, 0.62), v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# --- the depot: baked ---------------------------------------------------------------------------------------------

func _build_still() -> void:
	var concrete: StandardMaterial3D = mat(Color.WHITE, 0.85, 0.0, tex_speckle(128, Color(0.48, 0.48, 0.47), 0.08, 5, 4, Color(0.36, 0.36, 0.35)), Vector3(12, 12, 1))
	var steel: StandardMaterial3D = mat(Color(0.55, 0.58, 0.62), 0.35, 0.75)
	var yellow: StandardMaterial3D = mat(Color(0.95, 0.75, 0.15), 0.5, 0.2)
	var dark: StandardMaterial3D = mat(Color(0.14, 0.14, 0.15), 0.5, 0.6)
	box(Vector3(3000.0, 4.0, 2200.0), concrete, Vector3(0.0, -2.0, -300.0))
	# the back wall: corrugated panels, a row of windows, a door, and the walkway's lines on the floor
	box(Vector3(3000.0, 1400.0, 10.0), mat(Color.WHITE, 0.5, 0.5, _corrugated(128), Vector3(60, 1, 1)), Vector3(0.0, 700.0, -420.0))
	for wk in 10:
		var wx: float = -900.0 + float(wk) * 200.0
		box(Vector3(130.0, 80.0, 2.0), glow(Color(0.62, 0.72, 0.85)), Vector3(wx, 330.0, -414.0))
		for mb in 3:
			box(Vector3(2.0, 80.0, 3.0), dark, Vector3(wx - 32.0 + float(mb) * 32.0, 330.0, -413.0))
	for side in [-1.0, 1.0]:
		box(Vector3(2400.0, 0.5, 8.0), yellow, Vector3(0.0, 0.6, side * 120.0 - 10.0))
	# THE BELT's frame: side rails, legs, the end rollers' housings, a strip curtain where the parcels come in
	var length: float = BELT_X1 - BELT_X0
	for zs in [-36.0, 36.0]:
		box(Vector3(length + 20.0, 14.0, 6.0), steel, Vector3((BELT_X0 + BELT_X1) * 0.5, BELT_Y + 3.0, zs))
	for lx in range(int(BELT_X0) + 40, int(BELT_X1), 120):
		for zs2 in [-30.0, 30.0]:
			box(Vector3(8.0, BELT_Y, 8.0), dark, Vector3(float(lx), BELT_Y * 0.5, zs2))
	cyl(10.0, 10.0, 72.0, steel, Vector3(BELT_X1, BELT_Y - 4.0, 0.0), Vector3(90.0, 0.0, 0.0), null, 20)
	# the rollers showing along the belt's edge, and bolts along its guard rails
	for rl in range(int(BELT_X0) + 20, int(BELT_X1), 30):
		cyl(4.0, 4.0, 76.0, mat(Color(0.62, 0.64, 0.68), 0.3, 0.8), Vector3(float(rl), BELT_Y - 2.0, 0.0), Vector3(90.0, 0.0, 0.0), null, 12)
	for bl in range(int(BELT_X0) + 10, int(BELT_X1), 40):
		for zb in [-39.5, 39.5]:
			sphere(1.8, mat(Color(0.30, 0.30, 0.32), 0.3, 0.8), Vector3(float(bl), BELT_Y + 5.0, zb))
	# the strip curtain at the belt's start, in a hood
	box(Vector3(30.0, 120.0, 100.0), dark, Vector3(BELT_X0 - 10.0, BELT_Y + 60.0, 0.0))
	box(Vector3(44.0, 16.0, 110.0), yellow, Vector3(BELT_X0 - 10.0, BELT_Y + 126.0, 0.0))
	for st in 7:
		box(Vector3(1.5, 66.0, 12.0), mat(Color(0.75, 0.82, 0.88, 0.55), 0.1), Vector3(BELT_X0 + 6.0, BELT_Y + 40.0, -36.0 + float(st) * 12.0))
	# THE SCANNER ARCH over the belt: two posts, a beam with its head
	var sx: float = -250.0
	for zs3 in [-50.0, 50.0]:
		put(rbox_mesh(7.0, 7.0, 190.0, 3.0, 2.0), dark, Vector3(sx, 0.0, zs3))
	put(rbox_mesh(10.0, 58.0, 18.0, 4.0, 2.0), dark, Vector3(sx, 186.0, 0.0))
	box(Vector3(18.0, 8.0, 30.0), mat(Color(0.20, 0.05, 0.05), 0.4), Vector3(sx, 182.0, 0.0))
	# hazard striping down its posts, a lit scan window and a status light bar on its beam
	for zs4 in [-50.0, 50.0]:
		for hs in 6:
			box(Vector3(15.0, 8.0, 15.0), yellow if hs % 2 == 0 else dark, Vector3(sx, 20.0 + float(hs) * 16.0, zs4), Vector3(0.0, 0.0, 0.0))
	box(Vector3(2.0, 14.0, 70.0), glow(Color(0.55, 0.85, 1.0)), Vector3(sx + 11.0, 196.0, 0.0))
	for sl in 5:
		sphere(2.6, glow([Color(0.3, 1.0, 0.4), Color(1.0, 0.8, 0.2), Color(0.3, 1.0, 0.4), Color(0.3, 1.0, 0.4), Color(1.0, 0.3, 0.2)][sl]), Vector3(sx + 11.0, 208.0, -40.0 + float(sl) * 20.0))
	_build_chutes(false)
	# pipes along the back wall, a painted bay number, a floor drain
	for py in [470.0, 500.0]:
		cyl(6.0, 6.0, 3000.0, mat(Color(0.30, 0.45, 0.42), 0.4, 0.5), Vector3(0.0, py, -405.0), Vector3(0.0, 0.0, 90.0))
	label("BAY 3", 70.0, Color(0.95, 0.78, 0.20), Vector3(-420.0, 240.0, -414.0))
	# a floor drain: a steel grate in its frame (a plain black disc read as a hole)
	var drain: Vector3 = Vector3(-120.0, 0.0, 150.0)
	box(Vector3(44.0, 1.0, 44.0), mat(Color(0.30, 0.31, 0.33), 0.35, 0.8), drain + Vector3(0.0, 0.5, 0.0))
	box(Vector3(38.0, 1.1, 38.0), mat(Color(0.05, 0.05, 0.06), 0.9), drain + Vector3(0.0, 0.6, 0.0))
	for gb in 7:
		box(Vector3(2.0, 1.4, 38.0), mat(Color(0.42, 0.43, 0.46), 0.3, 0.85), drain + Vector3(-15.0 + float(gb) * 5.0, 0.9, 0.0))
	# THE ROBOT's plinth, bolted to the floor, with hazard stripes round it
	cyl(46.0, 52.0, 26.0, dark, BASE + Vector3(0.0, 13.0, 0.0), Vector3.ZERO, null, 32)
	for hz in 12:
		var ha: float = TAU * float(hz) / 12.0
		box(Vector3(14.0, 0.5, 36.0), yellow if hz % 2 == 0 else dark, BASE + Vector3(cos(ha) * 70.0, 0.6, sin(ha) * 70.0), Vector3(0.0, -rad_to_deg(ha), 0.0))
	# the pendant lamps' shades and cords
	for lx2 in [-380.0, -100.0, 200.0]:
		cyl(1.0, 1.0, 200.0, dark, Vector3(lx2, 440.0, 0.0))
		cyl(8.0, 34.0, 26.0, mat(Color(0.25, 0.40, 0.32), 0.5, 0.4), Vector3(lx2, 340.0, 0.0), Vector3.ZERO, null, 24)
		sphere(8.0, glow(Color(1.0, 0.94, 0.80)), Vector3(lx2, 328.0, 0.0))

# --- live: the belt, the parcels, the arm, the laser, the lamps ------------------------------------------------------

func _shape_nodes(parent: Node3D, at: Vector3) -> Array:
	# a disc, a square tile, a triangle -- one shown at a time, in the slot's color
	var m: StandardMaterial3D = mat(Color.WHITE, 0.4)
	var disc: MeshInstance3D = cyl(8.0, 8.0, 1.6, m, at, Vector3.ZERO, parent, 20)
	var sq: MeshInstance3D = box(Vector3(14.0, 1.6, 14.0), m, at, Vector3.ZERO, parent)
	var tri: MeshInstance3D = cyl(9.5, 9.5, 1.6, m, at, Vector3.ZERO, parent, 3)
	return [[disc, sq, tri], m]

func _build_live() -> void:
	# the belt's running surface (its texture slides)
	_belt_m = mat(Color.WHITE, 0.8, 0.0, _belt_tex(64), Vector3(14, 1, 1))
	box(Vector3(BELT_X1 - BELT_X0, 3.0, 66.0), _belt_m, Vector3((BELT_X0 + BELT_X1) * 0.5, BELT_Y + 1.5, 0.0))
	var card: StandardMaterial3D = mat(Color.WHITE, 0.85, 0.0, _cardboard(32))
	var tape: StandardMaterial3D = mat(Color(0.82, 0.70, 0.48), 0.4)
	for k in POOL:
		var p: Node3D = Node3D.new()
		root.add_child(p)
		box(PARCEL, card, Vector3(0.0, PARCEL.y * 0.5, 0.0), Vector3.ZERO, p)
		box(Vector3(PARCEL.x + 0.6, 0.6, 10.0), tape, Vector3(0.0, PARCEL.y + 0.2, 0.0), Vector3.ZERO, p)
		box(Vector3(10.0, PARCEL.y + 0.8, PARCEL.z + 0.6), tape, Vector3(0.0, PARCEL.y * 0.5, 0.0), Vector3.ZERO, p)
		box(Vector3(18.0, 12.0, 0.6), mat(Color(0.96, 0.95, 0.92), 0.7), Vector3(-14.0, PARCEL.y * 0.5, PARCEL.z * 0.5 + 0.4), Vector3.ZERO, p)
		for bc in 4:
			box(Vector3(14.0, 1.2, 0.4), mat(Color(0.15, 0.15, 0.15), 0.7), Vector3(-14.0, PARCEL.y * 0.5 - 3.0 + float(bc) * 2.0, PARCEL.z * 0.5 + 0.8), Vector3.ZERO, p)
		var a: Array = _shape_nodes(p, Vector3(-13.0, PARCEL.y + 0.9, 0.0))
		var b: Array = _shape_nodes(p, Vector3(13.0, PARCEL.y + 0.9, 0.0))
		_parcels.append([p, [a[0], b[0]], [a[1], b[1]]])
		_shown_id.append(-999)
	# THE ARM: a turning base, the upper link from the shoulder, the forearm from the elbow, the wrist with its gripper
	var orange: StandardMaterial3D = mat(Color(0.95, 0.52, 0.12), 0.35, 0.3)
	var dark: StandardMaterial3D = mat(Color(0.16, 0.16, 0.17), 0.4, 0.6)
	_base_yaw = Node3D.new()
	root.add_child(_base_yaw)
	_base_yaw.position = BASE + Vector3(0.0, 26.0, 0.0)
	cyl(36.0, 40.0, 30.0, orange, Vector3(0.0, 15.0, 0.0), Vector3.ZERO, _base_yaw, 32)
	put(rbox_mesh(22.0, 26.0, 70.0, 10.0, 4.0), orange, Vector3(0.0, 26.0, 0.0), Vector3.ZERO, _base_yaw)
	cyl(18.0, 18.0, 56.0, dark, Vector3(0.0, SHOULDER_H - 26.0, 0.0), Vector3(90.0, 0.0, 0.0), _base_yaw, 24)
	for ec2 in [-1.0, 1.0]:
		cyl(14.0, 14.0, 3.0, mat(Color(0.62, 0.64, 0.68), 0.3, 0.8), Vector3(0.0, SHOULDER_H - 26.0, ec2 * 29.0), Vector3(90.0, 0.0, 0.0), _base_yaw, 20)
	for bb in 8:
		var bang: float = TAU * float(bb) / 8.0
		sphere(2.2, mat(Color(0.62, 0.64, 0.68), 0.3, 0.8), Vector3(cos(bang) * 33.0, 2.0, sin(bang) * 33.0), _base_yaw)
	_upper = Node3D.new()
	_base_yaw.add_child(_upper)
	_upper.position = Vector3(0.0, SHOULDER_H - 26.0, 0.0)
	cyl(11.0, 15.0, L1, orange, Vector3(0.0, L1 * 0.5, 0.0), Vector3.ZERO, _upper, 24)
	put(rbox_mesh(9.0, 17.0, L1 * 0.7, 6.0, 3.0), orange, Vector3(0.0, L1 * 0.12, 0.0), Vector3.ZERO, _upper)
	box(Vector3(1.0, 16.0, 22.0), mat(Color(0.12, 0.12, 0.13), 0.4), Vector3(15.6, L1 * 0.45, 0.0), Vector3.ZERO, _upper)
	label("SR-7", 7.0, Color(0.95, 0.95, 0.95), Vector3(16.4, L1 * 0.45, 0.0), Vector3(0.0, 90.0, 0.0), _upper)
	# the elbow's motor: a housing with end caps and a ring of bolts
	cyl(16.0, 16.0, 42.0, dark, Vector3(0.0, L1, 0.0), Vector3(90.0, 0.0, 0.0), _upper, 24)
	for ec in [-1.0, 1.0]:
		cyl(12.0, 12.0, 3.0, mat(Color(0.62, 0.64, 0.68), 0.3, 0.8), Vector3(0.0, L1, ec * 22.0), Vector3(90.0, 0.0, 0.0), _upper, 20)
		for bo in 6:
			var ba: float = TAU * float(bo) / 6.0
			sphere(1.4, dark, Vector3(cos(ba) * 9.0, L1 + sin(ba) * 9.0, ec * 23.8), _upper)
	# a cable hose down the upper link
	put(tube_mesh(PackedVector3Array([Vector3(-14.0, 10.0, 12.0), Vector3(-18.0, L1 * 0.5, 14.0), Vector3(-12.0, L1 - 8.0, 12.0)]), 2.6, 8), mat(Color(0.10, 0.10, 0.11), 0.6), Vector3.ZERO, Vector3.ZERO, _upper)
	_fore = Node3D.new()
	_upper.add_child(_fore)
	_fore.position = Vector3(0.0, L1, 0.0)
	cyl(8.0, 11.5, L2, orange, Vector3(0.0, L2 * 0.5, 0.0), Vector3.ZERO, _fore, 24)
	put(tube_mesh(PackedVector3Array([Vector3(-11.0, 6.0, 10.0), Vector3(-13.0, L2 * 0.5, 11.0), Vector3(-8.0, L2 - 6.0, 9.0)]), 2.2, 8), mat(Color(0.10, 0.10, 0.11), 0.6), Vector3.ZERO, Vector3.ZERO, _fore)
	_wrist = Node3D.new()
	_fore.add_child(_wrist)
	_wrist.position = Vector3(0.0, L2, 0.0)
	cyl(9.0, 9.0, 24.0, dark, Vector3.ZERO, Vector3(90.0, 0.0, 0.0), _wrist, 16)
	cyl(5.0, 5.0, 26.0, mat(Color(0.65, 0.68, 0.72), 0.3, 0.8), Vector3(0.0, 14.0, 0.0), Vector3.ZERO, _wrist, 12)
	cyl(16.0, 12.0, 6.0, dark, Vector3(0.0, 29.0, 0.0), Vector3.ZERO, _wrist, 20)
	# the scanner's laser: a thin red line across the belt
	_laser = box(Vector3(2.0, 0.6, 66.0), glow(Color(1.0, 0.15, 0.10)), Vector3(-250.0, BELT_Y + 40.0, 0.0))
	_build_chutes(true)
	for c in 2:
		var lm: StandardMaterial3D = glow([Color(0.25, 0.85, 0.40), Color(0.95, 0.25, 0.20)][c])
		sphere(7.0, lm, Vector3((CHUTES[c] as Vector3).x, HATCH_Y1 + 34.0, WALL_Z + 11.0))
		_lamps.append(lm)
		# the hatch's strip curtain, each strip hung from a pivot at the hatch's head, swung by the parcels
		var strips: Array = []
		var cm: StandardMaterial3D = mat(Color(0.70, 0.80, 0.86, 0.50), 0.15)
		cm.cull_mode = BaseMaterial3D.CULL_DISABLED
		for st in 6:
			var pv: Node3D = Node3D.new()
			root.add_child(pv)
			pv.position = Vector3((CHUTES[c] as Vector3).x - HATCH_W * 0.5 + 7.0 + float(st) * 14.0, HATCH_Y1 - 2.0, WALL_Z + 6.0)
			box(Vector3(12.5, HATCH_Y1 - HATCH_Y0 - 4.0, 1.2), cm, Vector3(0.0, -(HATCH_Y1 - HATCH_Y0 - 4.0) * 0.5, 0.0), Vector3.ZERO, pv)
			strips.append(pv)
		_strips.append(strips)

# THE CHUTES AND THE SORTING WALL. Each chute is a steel slide with raised sides, falling away from where the arm
# sets a parcel down, through a curtained hatch in a low steel wall, into the dark behind it. Built into the picture
# AND again in the live view (`live`): there it stands in front of the parcels sliding down it and through the hatch,
# so they pass behind its rails and the wall (the picture alone cannot hide anything). The curtains are live only.
func _chute_dir() -> Vector3:
	return Vector3(0.0, -sin(deg_to_rad(SLOPE)), -cos(deg_to_rad(SLOPE)))

func _build_chutes(live: bool) -> void:
	var steel: StandardMaterial3D = mat(Color(0.58, 0.61, 0.65), 0.30, 0.80, tex_speckle(64, Color(0.80, 0.80, 0.80), 0.10, 21), Vector3(2, 6, 1))
	var rail: StandardMaterial3D = mat(Color(0.48, 0.50, 0.54), 0.35, 0.80)
	var dark: StandardMaterial3D = mat(Color(0.14, 0.14, 0.15), 0.5, 0.6)
	var yellow: StandardMaterial3D = mat(Color(0.95, 0.75, 0.15), 0.5, 0.2)
	var panel: StandardMaterial3D = mat(Color.WHITE, 0.55, 0.45, _corrugated(64), Vector3(8, 1, 1))
	panel.albedo_color = Color(0.62, 0.66, 0.70)
	var d: Vector3 = _chute_dir()
	var nrm: Vector3 = Vector3(0.0, cos(deg_to_rad(SLOPE)), -sin(deg_to_rad(SLOPE)))
	var rot: Vector3 = Vector3(-SLOPE, 0.0, 0.0)
	var run: float = (CHUTES[0] as Vector3).z - WALL_Z + 30.0          # to the wall and a little through it
	var length: float = run / cos(deg_to_rad(SLOPE)) + 20.0
	for c in CHUTES.size():
		var cp: Vector3 = CHUTES[c]
		var p0: Vector3 = cp + Vector3(0.0, -4.0, 0.0) - d * 20.0       # the chute's head, a little behind the set-down
		var mid: Vector3 = p0 + d * (length * 0.5)
		box(Vector3(64.0, 4.0, length), steel, mid - nrm * 2.0, rot)
		for e in [-1.0, 1.0]:
			box(Vector3(3.0, 16.0, length), rail, mid + nrm * 6.0 + Vector3(e * 33.5, 0.0, 0.0), rot)
			box(Vector3(5.0, 2.0, length), rail, mid + nrm * 14.0 + Vector3(e * 33.5, 0.0, 0.0), rot)
		# a lip at the head, and the legs: two posts under each side, braced
		box(Vector3(70.0, 14.0, 3.0), rail, p0 + nrm * 5.0 - d * 1.0, rot)
		if not live:
			for lg in [12.0, 70.0]:
				var foot: Vector3 = p0 + d * lg
				for e2 in [-1.0, 1.0]:
					var hgt: float = foot.y - 4.0
					box(Vector3(5.0, hgt, 5.0), dark, Vector3(cp.x + e2 * 28.0, hgt * 0.5, foot.z))
					box(Vector3(14.0, 2.0, 14.0), dark, Vector3(cp.x + e2 * 28.0, 1.0, foot.z))
				box(Vector3(56.0, 4.0, 4.0), dark, Vector3(cp.x, (foot.y - 4.0) * 0.45, foot.z))
	# THE WALL, a low run of ribbed steel panels with a cap, the hatches cut in it with hazard-striped frames
	var x0: float = 150.0
	var x1: float = 760.0
	var top: float = 190.0
	var edges: Array = [x0]
	for c2 in CHUTES.size():
		edges.append((CHUTES[c2] as Vector3).x - HATCH_W * 0.5)
		edges.append((CHUTES[c2] as Vector3).x + HATCH_W * 0.5)
	edges.append(x1)
	for k in range(0, edges.size(), 2):
		var a: float = edges[k]
		var b: float = edges[k + 1]
		box(Vector3(b - a, top, 10.0), panel, Vector3((a + b) * 0.5, top * 0.5, WALL_Z))
	for c3 in CHUTES.size():
		var hx: float = (CHUTES[c3] as Vector3).x
		box(Vector3(HATCH_W, HATCH_Y0, 10.0), panel, Vector3(hx, HATCH_Y0 * 0.5, WALL_Z))
		box(Vector3(HATCH_W, top - HATCH_Y1, 10.0), panel, Vector3(hx, (top + HATCH_Y1) * 0.5, WALL_Z))
		# the frame: black and yellow chevrons round the opening
		var fw: float = 7.0
		var n_s: int = 9
		for sk in n_s:
			var u: float = (float(sk) + 0.5) / float(n_s)
			var m2: StandardMaterial3D = yellow if sk % 2 == 0 else dark
			box(Vector3(fw, (HATCH_Y1 - HATCH_Y0) / float(n_s) + 0.2, 2.0), m2, Vector3(hx - HATCH_W * 0.5 - fw * 0.5, lerpf(HATCH_Y0, HATCH_Y1, u), WALL_Z + 6.0))
			box(Vector3(fw, (HATCH_Y1 - HATCH_Y0) / float(n_s) + 0.2, 2.0), m2, Vector3(hx + HATCH_W * 0.5 + fw * 0.5, lerpf(HATCH_Y0, HATCH_Y1, u), WALL_Z + 6.0))
		for sk2 in 7:
			var m3: StandardMaterial3D = yellow if sk2 % 2 == 0 else dark
			box(Vector3((HATCH_W + fw * 2.0) / 7.0 + 0.2, fw, 2.0), m3, Vector3(hx - HATCH_W * 0.5 - fw + (float(sk2) + 0.5) * (HATCH_W + fw * 2.0) / 7.0, HATCH_Y1 + fw * 0.5, WALL_Z + 6.0))
		# the dark beyond: a short tunnel behind the opening
		if not live:
			box(Vector3(HATCH_W, 4.0, 90.0), dark, Vector3(hx, HATCH_Y0 - 2.0, WALL_Z - 50.0))
			for e3 in [-1.0, 1.0]:
				box(Vector3(4.0, HATCH_Y1 - HATCH_Y0, 90.0), mat(Color(0.05, 0.05, 0.06), 0.9), Vector3(hx + e3 * HATCH_W * 0.5, (HATCH_Y0 + HATCH_Y1) * 0.5, WALL_Z - 50.0))
			box(Vector3(HATCH_W, 4.0, 90.0), mat(Color(0.05, 0.05, 0.06), 0.9), Vector3(hx, HATCH_Y1 + 2.0, WALL_Z - 50.0))
			box(Vector3(HATCH_W, HATCH_Y1 - HATCH_Y0, 4.0), mat(Color(0.02, 0.02, 0.03), 0.95), Vector3(hx, (HATCH_Y0 + HATCH_Y1) * 0.5, WALL_Z - 95.0))
		# the lamp's housing over the hatch and a colored band across the wall above it (in the live view too: its
		# wall would hide them)
		if true:
			box(Vector3(HATCH_W + 14.0, 10.0, 3.0), [mat(Color(0.20, 0.62, 0.30), 0.5), mat(Color(0.78, 0.20, 0.17), 0.5)][c3], Vector3(hx, HATCH_Y1 + 18.0, WALL_Z + 6.0))
			cyl(10.0, 10.0, 8.0, dark, Vector3(hx, HATCH_Y1 + 34.0, WALL_Z + 7.0), Vector3(90.0, 0.0, 0.0), null, 20)
	# the cap along the wall's top, and its posts
	if true:
		box(Vector3(x1 - x0 + 8.0, 6.0, 16.0), rail, Vector3((x0 + x1) * 0.5, top + 3.0, WALL_Z))
		for px in [x0, ((CHUTES[0] as Vector3).x + (CHUTES[1] as Vector3).x) * 0.5, (CHUTES[1] as Vector3).x + HATCH_W * 0.5 + 24.0, 560.0, x1]:
			box(Vector3(8.0, top, 14.0), dark, Vector3(float(px), top * 0.5, WALL_Z + 2.0))

# parcel i: its two shapes and colors, and whether it goes to the green chute (the rule: a red shape on it)
func _parcel(i: int) -> Array:
	var s0: int = int(h01(i * 17 + 3) * 3.0) % 3
	var s1: int = int(h01(i * 17 + 4) * 3.0) % 3
	var c0: int = int(h01(i * 17 + 5) * 4.0) % 4
	var c1: int = int(h01(i * 17 + 6) * 4.0) % 4
	return [s0, s1, c0, c1, c0 == 0 or c1 == 0]

# THE ARM's two-bone solve in its vertical plane: shoulder pitch and elbow bend to put the gripper's tip at `tip`
func _reach(tip: Vector3) -> void:
	var rel: Vector3 = tip - (BASE + Vector3(0.0, SHOULDER_H, 0.0))
	var yaw: float = atan2(rel.x, rel.z)
	_base_yaw.rotation = Vector3(0.0, yaw - PI * 0.5, 0.0)
	var horiz: float = Vector2(rel.x, rel.z).length()
	var target: Vector2 = Vector2(horiz, rel.y + 34.0)                 # the wrist above the tip by the gripper's length
	var d: float = clampf(target.length(), 20.0, L1 + L2 - 1.0)
	var a: float = acos(clampf((L1 * L1 + d * d - L2 * L2) / (2.0 * L1 * d), -1.0, 1.0))
	var b: float = acos(clampf((L1 * L1 + L2 * L2 - d * d) / (2.0 * L1 * L2), -1.0, 1.0))
	var base_ang: float = atan2(target.y, target.x)
	# links point along their local +y; the upper link's angle from the vertical, bent elbow-up
	var up_ang: float = base_ang + a
	_upper.rotation = Vector3(0.0, 0.0, -(PI * 0.5 - up_ang))
	_fore.rotation = Vector3(0.0, 0.0, -(PI - b))
	# the wrist keeps the gripper pointing straight down
	_wrist.rotation = Vector3(0.0, 0.0, -(_upper.rotation.z + _fore.rotation.z) + PI)

func _animate(_delta: float) -> void:
	if _base_yaw == null:
		return
	var speed: float = (BELT_X1 - BELT_X0) / (PERIOD * 3.6)
	_belt_m.uv1_offset = Vector3(-fmod(t * speed / ((BELT_X1 - BELT_X0) / 14.0), 1.0), 0.0, 0.0)
	var n: int = int(floor((t - 0.5) / PERIOD))                         # the parcel at the arm now
	var u: float = (t - 0.5) - float(n) * PERIOD
	var end_top: Vector3 = Vector3(BELT_X1 - PARCEL.x * 0.5, BELT_Y + 3.0 + PARCEL.y, 0.0)
	var cur: Array = _parcel(n)
	var chute: Vector3 = CHUTES[0 if bool(cur[4]) else 1]
	var above_end: Vector3 = end_top + Vector3(0.0, 60.0, 0.0)
	var above_chute: Vector3 = chute + Vector3(0.0, PARCEL.y + 60.0, 0.0)
	# THE ARM's course: down onto the parcel at the end, grip, up, swing round over its chute, down, let go, back
	var tip: Vector3
	if u < 0.35:
		tip = above_end.lerp(end_top, smoothstep(0.0, 0.35, u))
	elif u < 0.55:
		tip = end_top
	elif u < 1.0:
		tip = end_top.lerp(above_end, smoothstep(0.55, 1.0, u))
	elif u < 1.7:
		var su: float = smoothstep(1.0, 1.7, u)
		tip = above_end.lerp(above_chute, su) + Vector3(0.0, 30.0 * sin(su * PI), 0.0)
	elif u < 2.0:
		tip = above_chute.lerp(chute + Vector3(0.0, PARCEL.y, 0.0), smoothstep(1.7, 2.0, u))
	elif u < 2.15:
		tip = chute + Vector3(0.0, PARCEL.y, 0.0)
	else:
		var bu: float = smoothstep(2.15, PERIOD, u)
		tip = (chute + Vector3(0.0, PARCEL.y, 0.0)).lerp(above_end, bu) + Vector3(0.0, 40.0 * sin(bu * PI), 0.0)
	_reach(tip)
	var grip: Vector3 = _wrist.global_position * 100.0 + (_wrist.global_transform.basis.y.normalized() * 32.0)
	# THE PARCELS: on the belt, in the gripper, on the chute and down into the bin
	for k in range(n - 1, n + 4):
		var slot: int = posmod(k, POOL)
		var pp: Array = _parcels[slot]
		var node: Node3D = pp[0]
		if _shown_id[slot] != k:
			_shown_id[slot] = k
			var info: Array = _parcel(k)
			for s in 2:
				var shapes: Array = (pp[1] as Array)[s]
				for si in 3:
					(shapes[si] as Node3D).visible = si == int(info[s])
				((pp[2] as Array)[s] as StandardMaterial3D).albedo_color = PAL[int(info[2 + s])]
		var info2: Array = _parcel(k)
		var ch: Vector3 = CHUTES[0 if bool(info2[4]) else 1]
		var tk: float = float(k) * PERIOD + 0.5                     # when it reaches the arm
		var pos: Vector3
		node.visible = true
		node.rotation = Vector3.ZERO
		if t < tk + 0.45:
			var x: float = BELT_X1 - PARCEL.x * 0.5 - speed * maxf(0.0, tk - t)
			pos = Vector3(x, BELT_Y + 3.0, 0.0)
			node.visible = x > BELT_X0 + 10.0
		elif t < tk + 2.1:
			pos = grip - Vector3(0.0, PARCEL.y + 2.0, 0.0)
		else:
			# down the chute: it slides away, gathering speed, through the curtain and out of sight
			var tau: float = t - tk - 2.1
			var sl: float = 70.0 * tau * tau + 30.0 * tau
			pos = ch + Vector3(0.0, -4.0, 0.0) + _chute_dir() * sl
			node.rotation = Vector3(-deg_to_rad(SLOPE) * minf(1.0, tau * 8.0), 0.0, 0.0)
			node.visible = sl < 260.0
		node.position = pos
	# THE LASER sweeping across whichever parcel is passing under the arch
	var sweep: float = 0.5 + 0.5 * sin(t * 6.0)
	_laser.position = Vector3(-250.0, BELT_Y + 6.0 + PARCEL.y + 2.0, -30.0 + 60.0 * sweep)
	_laser.rotation = Vector3(0.0, PI * 0.5, 0.0)
	# THE CURTAINS: a parcel going through pushes the strips in its way back, and they swing and settle after it
	for c4 in 2:
		var push: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		for k3 in range(n - 3, n + 1):
			var inf3: Array = _parcel(k3)
			if (0 if bool(inf3[4]) else 1) != c4:
				continue
			var tau3: float = t - (float(k3) * PERIOD + 0.5 + 2.1)
			if tau3 < 0.0:
				continue
			var sl3: float = 70.0 * tau3 * tau3 + 30.0 * tau3
			var pz: float = ((CHUTES[c4] as Vector3) + _chute_dir() * sl3).z
			var front: float = pz - PARCEL.z * 0.5
			var back: float = pz + PARCEL.z * 0.5
			var plane: float = WALL_Z + 6.0
			var amt: float = 0.0
			if front < plane and back > plane - 6.0:
				amt = 1.15 * smoothstep(plane, plane - 14.0, front)
			elif back <= plane - 6.0:
				# gone through: the time since its back cleared the strips, a damped swing
				var vel: float = 140.0 * tau3 + 30.0
				var since3: float = (plane - 6.0 - back) / maxf(vel * cos(deg_to_rad(SLOPE)), 1.0)
				amt = 1.15 * exp(-3.2 * since3) * cos(8.5 * since3)
			for st2 in 6:
				var sx2: float = -HATCH_W * 0.5 + 7.0 + float(st2) * 14.0
				var cover: float = clampf((PARCEL.x * 0.5 + 6.0 - absf(sx2)) / 12.0, 0.0, 1.0)
				push[st2] = push[st2] + amt * lerpf(0.35, 1.0, cover)
		for st3 in 6:
			var swing: float = float(push[st3]) + 0.025 * sin(t * 1.3 + float(st3) * 1.7 + float(c4))
			(_strips[c4][st3] as Node3D).rotation = Vector3(swing, 0.0, 0.0)
	# the chutes' lamps: the one just used flashes, fading
	for c in 2:
		var since: float = 99.0
		for k2 in range(n - 1, n + 1):
			var inf: Array = _parcel(k2)
			if (0 if bool(inf[4]) else 1) == c:
				var t_drop: float = float(k2) * PERIOD + 0.5 + 2.1
				if t >= t_drop:
					since = minf(since, t - t_drop)
		var fl: float = 1.0 - clampf(since / 0.9, 0.0, 1.0)
		var base_c: Color = [Color(0.25, 0.85, 0.40), Color(0.95, 0.25, 0.20)][c]
		(_lamps[c] as StandardMaterial3D).albedo_color = base_c.darkened(0.6).lerp(base_c.lightened(0.3), fl)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Sorting Robots", "Sort items by hidden rules", Color(1.0, 0.82, 0.30), Color(0.12, 0.10, 0.04),
		Color(1.0, 0.75, 0.25, 0.22))

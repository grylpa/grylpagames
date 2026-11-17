extends "res://scripts/menu_poster3d.gd"

# DISPATCH'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A DEPOT YARD IN
# THE LATE AFTERNOON. A brick warehouse with three numbered loading bays -- roll-up doors in their bay's color, a lamp
# over each, a concrete apron -- a road along the front, pallets and a fence, a hazy sky. Along the road comes the
# game's delivery truck: an engine pulling a flatbed cart per delivery, each with its parcel in its bay's color. As it
# passes the bays the rear cart peels off, curves across the apron into ITS bay (the door rolls up for it, the bay's
# number lights), and the door rolls down behind it -- bay 1, then 2, then 3, in order; the engine drives on and out,
# and a while later the next truck comes. The yard is the baked picture, one per platform (`menu_yard.webp`,
# `menu_yard_d.webp`); the truck, the doors and the numbers are live. One clock (`t`); nothing pops (a cart is gone
# only behind its closed door). Made up, never the board.

const BAYS: Array = [-210.0, 0.0, 210.0]         # x of bays 1, 2, 3
const COLS: Array = [Color(0.88, 0.22, 0.20), Color(0.24, 0.50, 0.92), Color(0.96, 0.76, 0.18)]
const ROAD_Z: float = 150.0
const DOCK_Z: float = -40.0                        # a parked cart's place, just inside its door
const FRONT_Z: float = -60.0                       # the warehouse's front wall
const SPEED: float = 150.0
const GAP: float = 92.0                            # engine to first cart, cart to cart
const CYCLE: float = 15.0
const DOOR_W: float = 130.0
const DOOR_H: float = 120.0

var _engine: Node3D = null
var _carts: Array = []                             # Node3D per cart; cart k (k = 0 nearest the engine) goes to bay 2 - k
var _doors: Array = []
var _plates: Array = []                            # StandardMaterial3D per bay number

func _baked_path() -> String:
	return "res://deliverem/art/menu_yard.webp" if mobile else "res://deliverem/art/menu_yard_d.webp"

func _eye() -> Vector3:
	return Vector3(60.0, 330.0, 560.0) if mobile else Vector3(60.0, 380.0, 860.0)

func _aim() -> Vector3:
	return Vector3(0.0, 95.0, 0.0) if mobile else Vector3(0.0, 105.0, -10.0)

func _fov() -> float:
	return 52.0

func _scene_top() -> float:
	return 0.0

func _environment(env: Environment) -> void:
	env.background_color = Color(0.62, 0.70, 0.82)
	env.ambient_light_color = Color(0.70, 0.72, 0.80)
	env.ambient_light_energy = 0.55

func _build_lights() -> void:
	# the low sun from the left, warm, casting long shadows; a sky fill
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.66)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	root.add_child(sun)
	sun.rotation_degrees = Vector3(-38.0, -58.0, 0.0)
	light(Vector3(0.0, 400.0, 600.0), Color(0.85, 0.90, 1.0), 0.6, 1200.0)

# --- textures ---------------------------------------------------------------------------------------------------

func _brick(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	img.fill(Color(0.42, 0.40, 0.38))
	var bh: int = n / 16
	var bw: int = n / 8
	for row in 16:
		var off: int = (bw / 2) if row % 2 == 1 else 0
		for col in 9:
			var x0: int = col * bw - off
			var c: Color = Color(0.55, 0.26, 0.18).lerp(Color(0.66, 0.34, 0.22), h01(row * 31 + col))
			c = c.darkened(0.15 * h01(row * 7 + col * 3))
			img.fill_rect(Rect2i(maxi(0, x0 + 1), row * bh + 1, mini(bw - 2, n - maxi(0, x0 + 1)), bh - 2), c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _asphalt(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			img.set_pixel(x, y, Color(0.22, 0.22, 0.24).lightened(0.10 * (h01(x * 17 + y * 31) - 0.5)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _sky(n: int) -> ImageTexture:
	var img: Image = Image.create(4, n, false, Image.FORMAT_RGB8)
	for y in n:
		var v: float = float(y) / float(n - 1)
		img.fill_rect(Rect2i(0, y, 4, 1), Color(0.16, 0.24, 0.46).lerp(Color(1.0, 0.80, 0.60), pow(v, 1.8)))
	return ImageTexture.create_from_image(img)

# --- the yard: baked -----------------------------------------------------------------------------------------------

func _build_still() -> void:
	var concrete: StandardMaterial3D = mat(Color.WHITE, 0.9, 0.0, tex_speckle(128, Color(0.66, 0.64, 0.60), 0.06, 3, 4, Color(0.50, 0.48, 0.45)), Vector3(8, 8, 1))
	var brick: StandardMaterial3D = mat(Color.WHITE, 0.85, 0.0, _brick(256), Vector3(6, 2, 1))
	var steel: StandardMaterial3D = mat(Color(0.42, 0.44, 0.48), 0.5, 0.6)
	var dark: StandardMaterial3D = mat(Color(0.06, 0.06, 0.07), 0.9)
	var wood: StandardMaterial3D = mat(Color.WHITE, 0.8, 0.0, tex_wood(128, Color(0.62, 0.48, 0.30), 5))
	# the sky behind, and the ground: the yard's concrete, the road, a verge
	var sky: QuadMesh = QuadMesh.new()
	sky.size = Vector2(5000.0, 1600.0)
	var sky_m: StandardMaterial3D = mat(Color.WHITE, 1.0, 0.0, _sky(64))
	sky_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	put(sky, sky_m, Vector3(0.0, 500.0, -1200.0))
	box(Vector3(3000.0, 4.0, 2400.0), mat(Color(0.32, 0.40, 0.22), 1.0), Vector3(0.0, -3.0, 0.0))
	box(Vector3(1800.0, 2.0, 300.0), concrete, Vector3(0.0, 0.0, 30.0))
	box(Vector3(3000.0, 2.0, 120.0), mat(Color.WHITE, 0.95, 0.0, _asphalt(128), Vector3(20, 1, 1)), Vector3(0.0, 1.2, ROAD_Z))
	for k in 30:
		box(Vector3(40.0, 0.5, 4.0), mat(Color(0.95, 0.92, 0.80), 0.8), Vector3(-1450.0 + float(k) * 100.0, 2.4, ROAD_Z))
	for e in [-1.0, 1.0]:
		box(Vector3(3000.0, 6.0, 8.0), concrete, Vector3(0.0, 3.0, ROAD_Z + e * 64.0))
	# THE WAREHOUSE: brick, a steel roof edge, the three bays (dark inside, a steel frame painted in the bay's color,
	# a canopy, a lamp), the numbers' boards (the lit numbers are live)
	var front: float = FRONT_Z
	# the front wall: four stretches between and beside the three openings, and the brick over each opening
	for span in [[-560.0, -275.0], [-145.0, -65.0], [65.0, 145.0], [275.0, 560.0]]:
		var x0: float = span[0]
		var x1: float = span[1]
		box(Vector3(x1 - x0, 230.0, 20.0), brick, Vector3((x0 + x1) * 0.5, 115.0, front - 10.0))
	for bx in BAYS:
		box(Vector3(DOOR_W, 230.0 - DOOR_H, 20.0), brick, Vector3(float(bx), DOOR_H + (230.0 - DOOR_H) * 0.5, front - 10.0))
	box(Vector3(1100.0, 230.0, 260.0), brick, Vector3(0.0, 115.0, front - 350.0))    # behind the bays, so an open door shows its bay
	box(Vector3(1120.0, 14.0, 430.0), steel, Vector3(0.0, 236.0, front - 205.0))
	box(Vector3(1120.0, 10.0, 6.0), mat(Color(0.20, 0.30, 0.26), 0.5, 0.3), Vector3(0.0, 238.0, front + 10.0))
	for b in BAYS.size():
		var bx2: float = BAYS[b]
		var col: Color = COLS[b]
		# inside: a dark bay
		box(Vector3(DOOR_W, DOOR_H, 4.0), dark, Vector3(bx2, DOOR_H * 0.5, front - 140.0))
		box(Vector3(4.0, DOOR_H, 130.0), dark, Vector3(bx2 - DOOR_W * 0.5, DOOR_H * 0.5, front - 75.0))
		box(Vector3(4.0, DOOR_H, 130.0), dark, Vector3(bx2 + DOOR_W * 0.5, DOOR_H * 0.5, front - 75.0))
		box(Vector3(DOOR_W, 4.0, 130.0), dark, Vector3(bx2, DOOR_H, front - 75.0))
		box(Vector3(DOOR_W, 2.0, 130.0), mat(Color(0.30, 0.30, 0.30), 0.9), Vector3(bx2, 0.5, front - 75.0))
		# the frame, in the bay's color, and black-and-yellow bumpers
		var fm: StandardMaterial3D = mat(col, 0.5, 0.2)
		for e2 in [-1.0, 1.0]:
			box(Vector3(10.0, DOOR_H + 10.0, 10.0), fm, Vector3(bx2 + e2 * (DOOR_W * 0.5 + 5.0), (DOOR_H + 10.0) * 0.5, front + 2.0))
			box(Vector3(14.0, 22.0, 10.0), dark, Vector3(bx2 + e2 * (DOOR_W * 0.5 - 12.0), 18.0, front + 6.0))
		box(Vector3(DOOR_W + 20.0, 10.0, 10.0), fm, Vector3(bx2, DOOR_H + 5.0, front + 2.0))
		# the canopy and its lamp, and the number's board
		box(Vector3(DOOR_W + 40.0, 4.0, 60.0), steel, Vector3(bx2, DOOR_H + 52.0, front + 28.0), Vector3(-8.0, 0.0, 0.0))
		box(Vector3(56.0, 40.0, 4.0), mat(Color(0.12, 0.12, 0.14), 0.6), Vector3(bx2, DOOR_H + 30.0, front + 4.0))
		# painted guide lines on the apron, from the road into the bay
		for e3 in [-1.0, 1.0]:
			box(Vector3(4.0, 0.5, 170.0), mat(Color(0.95, 0.85, 0.30), 0.8), Vector3(bx2 + e3 * 54.0, 1.4, front + 90.0))
	# THE YARD round it: pallets stacked by the end walls, drums, a chain-link fence along the back of the verge
	for pk in 4:
		var px: float = -500.0 + float(pk % 2) * 70.0
		var pz: float = front + 50.0 + float(pk / 2) * 30.0
		box(Vector3(60.0, 10.0, 60.0), wood, Vector3(px, 5.0, pz))
		box(Vector3(52.0, 40.0, 52.0), mat(Color(0.70, 0.56, 0.36), 0.9), Vector3(px, 30.0, pz))
	for dk in 3:
		cyl(16.0, 16.0, 44.0, mat([Color(0.20, 0.35, 0.55), Color(0.60, 0.15, 0.12), Color(0.20, 0.45, 0.25)][dk], 0.5, 0.3), Vector3(470.0 + float(dk) * 36.0, 22.0, front + 40.0))
	# trees beyond, either side of the warehouse
	for tk in 6:
		var tx: float = (-760.0 if tk < 3 else 760.0) + float(tk % 3) * 90.0 * (1.0 if tk < 3 else -1.0)
		cyl(8.0, 10.0, 120.0, mat(Color(0.32, 0.22, 0.14), 0.9), Vector3(tx, 60.0, front - 120.0 - float(tk % 3) * 60.0))
		sphere(70.0 + 20.0 * h01(tk), mat(Color(0.26, 0.42, 0.20), 0.9), Vector3(tx, 170.0, front - 120.0 - float(tk % 3) * 60.0))

# --- live: the doors, the numbers, the truck -----------------------------------------------------------------------

func _wheel(parent: Node3D, x: float, z: float) -> void:
	cyl(11.0, 11.0, 8.0, mat(Color(0.10, 0.10, 0.11), 0.8), Vector3(x, 11.0, z), Vector3(90.0, 0.0, 0.0), parent, 20)
	cyl(5.0, 5.0, 8.6, mat(Color(0.70, 0.72, 0.75), 0.4, 0.6), Vector3(x, 11.0, z), Vector3(90.0, 0.0, 0.0), parent, 16)

func _build_live() -> void:
	# the roll-up doors (ribbed steel, in a lighter tone of the bay's color) and the bay numbers, lit when delivered
	for b in BAYS.size():
		# a ROLL-UP door hangs from its top edge and rolls up into it (drawn shorter from the bottom), inside the opening
		var door: Node3D = Node3D.new()
		root.add_child(door)
		var dc: Color = (COLS[b] as Color).lerp(Color(0.85, 0.85, 0.85), 0.55)
		box(Vector3(DOOR_W - 2.0, DOOR_H, 3.0), mat(dc, 0.5, 0.3), Vector3(0.0, -DOOR_H * 0.5, 0.0), Vector3.ZERO, door)
		for r in 8:
			box(Vector3(DOOR_W - 2.0, 2.0, 1.2), mat(dc.darkened(0.25), 0.5, 0.3), Vector3(0.0, -DOOR_H + 8.0 + float(r) * 14.5, 2.0), Vector3.ZERO, door)
		box(Vector3(30.0, 4.0, 2.0), mat(Color(0.2, 0.2, 0.2), 0.5), Vector3(0.0, -DOOR_H + 10.0, 2.6), Vector3.ZERO, door)
		door.position = Vector3(float(BAYS[b]), DOOR_H, FRONT_Z - 8.0)
		_doors.append(door)
		var pm: StandardMaterial3D = mat(COLS[b], 0.4)
		pm.emission_enabled = true
		pm.emission = COLS[b]
		pm.emission_energy_multiplier = 0.0
		label(str(b + 1), 34.0, Color.WHITE, Vector3(float(BAYS[b]), DOOR_H + 29.0, FRONT_Z + 7.0))
		box(Vector3(44.0, 32.0, 1.0), pm, Vector3(float(BAYS[b]), DOOR_H + 30.0, FRONT_Z + 6.4))
		_plates.append(pm)
	# THE TRUCK: an engine with its cab, then a flatbed cart per delivery, each with a parcel in its bay's color
	_engine = Node3D.new()
	root.add_child(_engine)
	var paint: StandardMaterial3D = mat(Color(0.18, 0.42, 0.34), 0.35, 0.3)
	box(Vector3(80.0, 10.0, 44.0), mat(Color(0.15, 0.15, 0.16), 0.6, 0.4), Vector3(0.0, 18.0, 0.0), Vector3.ZERO, _engine)
	put(rbox_mesh(20.0, 22.0, 46.0, 6.0, 3.0), paint, Vector3(16.0, 22.0, 0.0), Vector3.ZERO, _engine)
	put(rbox_mesh(18.0, 21.0, 22.0, 5.0, 3.0), paint, Vector3(-18.0, 22.0, 0.0), Vector3.ZERO, _engine)
	box(Vector3(2.0, 20.0, 38.0), mat(Color(0.30, 0.45, 0.58), 0.1, 0.3), Vector3(36.6, 52.0, 0.0), Vector3.ZERO, _engine)
	box(Vector3(30.0, 18.0, 1.0), mat(Color(0.30, 0.45, 0.58), 0.1, 0.3), Vector3(16.0, 52.0, 22.6), Vector3.ZERO, _engine)
	for e in [-1.0, 1.0]:
		sphere(4.0, glow(Color(1.0, 0.95, 0.75)), Vector3(37.0, 30.0, e * 14.0), _engine)
	_wheel(_engine, 22.0, 22.0)
	_wheel(_engine, 22.0, -22.0)
	_wheel(_engine, -24.0, 22.0)
	_wheel(_engine, -24.0, -22.0)
	for k in 3:
		var cart: Node3D = Node3D.new()
		root.add_child(cart)
		box(Vector3(70.0, 8.0, 42.0), mat(Color(0.55, 0.40, 0.25), 0.7), Vector3(0.0, 24.0, 0.0), Vector3.ZERO, cart)    # plain: a texture made per cart held up the first frame
		box(Vector3(70.0, 4.0, 42.0), mat(Color(0.18, 0.18, 0.19), 0.6, 0.4), Vector3(0.0, 18.0, 0.0), Vector3.ZERO, cart)
		box(Vector3(10.0, 3.0, 4.0), mat(Color(0.25, 0.25, 0.26), 0.5, 0.5), Vector3(40.0, 18.0, 0.0), Vector3.ZERO, cart)
		var bay: int = 2 - k
		var pc: Color = COLS[bay]
		box(Vector3(46.0, 34.0, 34.0), mat(pc, 0.6), Vector3(0.0, 45.0, 0.0), Vector3.ZERO, cart)
		box(Vector3(46.6, 6.0, 34.6), mat(pc.lightened(0.45), 0.6), Vector3(0.0, 45.0, 0.0), Vector3.ZERO, cart)
		box(Vector3(6.0, 34.6, 34.6), mat(pc.lightened(0.45), 0.6), Vector3(0.0, 45.0, 0.0), Vector3.ZERO, cart)
		_wheel(cart, 22.0, 21.0)
		_wheel(cart, 22.0, -21.0)
		_wheel(cart, -22.0, 21.0)
		_wheel(cart, -22.0, -21.0)
		_carts.append(cart)

# --- the motion ---------------------------------------------------------------------------------------------------

# a cart's way: along the road (heading +x), and from TURN_IN before its bay, a curve across the apron into it
const TURN_IN: float = 90.0

func _cart_pose(along: float, bay: int) -> Array:
	var bx: float = BAYS[bay]
	var start: float = bx - TURN_IN
	if along <= start:
		return [Vector3(along, 0.0, ROAD_Z - 26.0), 0.0]
	# the curve: from the road into the bay, its length about TURN_IN + the apron's depth; then on in, slowing
	var p0: Vector3 = Vector3(start, 0.0, ROAD_Z - 26.0)
	var p1: Vector3 = Vector3(bx, 0.0, ROAD_Z - 26.0)
	var p2: Vector3 = Vector3(bx, 0.0, DOCK_Z + 30.0)
	var curve_len: float = TURN_IN + (ROAD_Z - 26.0 - DOCK_Z - 30.0)
	var d: float = along - start
	if d < curve_len:
		var s: float = d / curve_len
		var p: Vector3 = p0.lerp(p1, s).lerp(p1.lerp(p2, s), s)
		var tan3: Vector3 = (p1 - p0).lerp(p2 - p1, s)
		return [p, atan2(-tan3.z, tan3.x)]
	# in through the door and on to the back of the bay, slowing to a stop
	var rest: float = minf(d - curve_len, 160.0)
	var e: float = 1.0 - pow(1.0 - rest / 160.0, 2.0)
	return [Vector3(bx, 0.0, DOCK_Z + 30.0 - e * 130.0), PI * 0.5]

func _animate(_delta: float) -> void:
	if _engine == null:
		return
	var u: float = fmod(t, CYCLE)
	var head: float = -980.0 + SPEED * u
	_engine.position = Vector3(head, 0.0, ROAD_Z - 26.0)
	_engine.rotation = Vector3.ZERO
	var opened: Array = [0.0, 0.0, 0.0]
	var done: Array = [0.0, 0.0, 0.0]
	for k in _carts.size():
		var bay: int = 2 - k
		var along: float = head - GAP * float(k + 1)
		var pose: Array = _cart_pose(along, bay)
		var cart: Node3D = _carts[k]
		cart.position = pose[0]
		cart.rotation = Vector3(0.0, float(pose[1]), 0.0)
		# the door: up as the cart turns in, down again once it is inside
		var bx: float = BAYS[bay]
		var into: float = along - (bx - TURN_IN)
		opened[bay] = smoothstep(-160.0, -20.0, into) * (1.0 - smoothstep(330.0, 450.0, into))
		done[bay] = smoothstep(200.0, 260.0, into)
	for b in _doors.size():
		(_doors[b] as Node3D).scale.y = maxf(0.03, 1.0 - 0.97 * float(opened[b]))
		var pm: StandardMaterial3D = _plates[b]
		var lit: float = float(done[b]) * (1.0 - smoothstep(CYCLE - 1.2, CYCLE - 0.2, u))
		pm.emission_energy_multiplier = 2.2 * lit
		pm.albedo_color = (COLS[b] as Color).darkened(0.55).lerp(COLS[b], lit)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Dispatch", "Remember the delivery order", Color(1.0, 0.88, 0.60), Color(0.10, 0.08, 0.06),
		Color(1.0, 0.8, 0.5, 0.22))

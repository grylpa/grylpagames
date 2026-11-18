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
var _enter_x: float = -440.0
var _cyc: float = 0.0                              # the truck's cycle: set from the camera on the first frame
const DOOR_W: float = 130.0
const DOOR_H: float = 120.0

var _engine: Node3D = null
var _carts: Array = []                             # Node3D per cart; cart k (k = 0 nearest the engine) goes to bay 2 - k
var _doors: Array = []
var _plates: Array = []                            # StandardMaterial3D per bay number
var _nums: Array = []                              # Label3D per bay number

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
	env.ambient_light_color = Color(0.62, 0.70, 0.88)
	env.ambient_light_energy = 0.32

func _build_lights() -> void:
	# the low sun from the left, warm, casting long shadows; a sky fill
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.80, 0.56)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	root.add_child(sun)
	sun.rotation_degrees = Vector3(-38.0, -58.0, 0.0)
	light(Vector3(0.0, 400.0, 600.0), Color(0.85, 0.90, 1.0), 0.6, 1200.0)

# --- textures ---------------------------------------------------------------------------------------------------

# mown grass: green with a fine grain of blades, lighter and darker patches, a little clover and bare earth
func _grass(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var patch: float = 0.5 + 0.5 * sin(float(x) * 0.09 + sin(float(y) * 0.07) * 2.0) * sin(float(y) * 0.05)
			var c: Color = Color(0.26, 0.38, 0.15).lerp(Color(0.40, 0.52, 0.22), patch * 0.7 + 0.3 * h01(x * 7 + y * 131))
			if h01(x * 17 + y * 29) > 0.80:
				c = c.darkened(0.25)
			if h01(x * 31 + y * 7) > 0.93:
				c = c.lightened(0.18)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

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
			# aggregate: fine grit, and here and there a pale stone in the tar
			var c: Color = Color(0.21, 0.21, 0.23).lightened(0.12 * (h01(x * 17 + y * 31) - 0.5))
			if h01(x * 7 + y * 53 + 11) > 0.97:
				c = Color(0.46, 0.45, 0.44)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _corrugated(n: int) -> ImageTexture:
	var img: Image = Image.create(n, 4, false, Image.FORMAT_RGB8)
	for x in n:
		var v: float = 0.5 + 0.5 * sin(float(x) / float(n) * TAU * 8.0)
		img.fill_rect(Rect2i(x, 0, 1, 4), Color(0.36, 0.40, 0.42).lerp(Color(0.62, 0.66, 0.68), v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _sky(n: int) -> ImageTexture:
	var img: Image = Image.create(4, n, false, Image.FORMAT_RGB8)
	for y in n:
		var v: float = float(y) / float(n - 1)
		img.fill_rect(Rect2i(0, y, 4, 1), Color(0.16, 0.24, 0.46).lerp(Color(1.0, 0.80, 0.60), pow(v, 1.8)))
	return ImageTexture.create_from_image(img)

# --- the yard: baked -----------------------------------------------------------------------------------------------

func _shared_mats() -> void:
	if _tire_m != null:
		return
	_tire_m = mat(Color.WHITE, 0.9, 0.0, _tire_tex(64), Vector3(4, 1, 1))
	_chrome_m = mat(Color(0.86, 0.88, 0.92), 0.12, 0.95)
	_card_tex = _cardboard(32)

func _build_still() -> void:
	_shared_mats()
	var concrete: StandardMaterial3D = mat(Color.WHITE, 0.9, 0.0, tex_speckle(128, Color(0.66, 0.64, 0.60), 0.06, 3, 4, Color(0.50, 0.48, 0.45)), Vector3(8, 8, 1))
	var brick: StandardMaterial3D = mat(Color.WHITE, 0.85, 0.0, _brick(256), Vector3(6, 2, 1))
	var steel: StandardMaterial3D = mat(Color(0.42, 0.44, 0.48), 0.5, 0.6)
	var wood: StandardMaterial3D = mat(Color.WHITE, 0.8, 0.0, tex_wood(128, Color(0.62, 0.48, 0.30), 5))
	# the sky behind, and the ground: the yard's concrete, the road, a verge
	var sky: QuadMesh = QuadMesh.new()
	sky.size = Vector2(5000.0, 1600.0)
	var sky_m: StandardMaterial3D = mat(Color.WHITE, 1.0, 0.0, _sky(64))
	sky_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	put(sky, sky_m, Vector3(0.0, 500.0, -1200.0))
	box(Vector3(3000.0, 4.0, 2400.0), mat(Color.WHITE, 1.0, 0.0, _grass(256), Vector3(30, 24, 1)), Vector3(0.0, -3.0, 0.0))
	box(Vector3(1800.0, 2.0, 300.0), concrete, Vector3(0.0, 0.0, 30.0))
	box(Vector3(3000.0, 2.0, 120.0), mat(Color.WHITE, 0.75, 0.0, _asphalt(128), Vector3(20, 1, 1)), Vector3(0.0, 1.2, ROAD_Z))
	# repair patches and a worn wheel track in the asphalt, the footpath and its kerb beyond the road
	for pt in 7:
		var pm2: MeshInstance3D = box(Vector3(40.0 + 50.0 * h01(pt), 0.3, 18.0 + 20.0 * h01(pt + 3)), mat(Color(0.16, 0.16, 0.18), 0.6), Vector3(-700.0 + float(pt) * 210.0 + 40.0 * h01(pt + 6), 2.3, ROAD_Z + (h01(pt + 9) - 0.5) * 80.0))
		pm2.rotation_degrees = Vector3(0.0, (h01(pt + 12) - 0.5) * 20.0, 0.0)
	for track in [-1.0, 1.0]:
		box(Vector3(3000.0, 0.2, 14.0), mat(Color(0.14, 0.14, 0.15), 0.5), Vector3(0.0, 2.3, ROAD_Z - 26.0 + track * 10.0))
	box(Vector3(3000.0, 6.0, 60.0), mat(Color.WHITE, 0.85, 0.0, tex_speckle(64, Color(0.60, 0.58, 0.55), 0.06, 8, 4, Color(0.45, 0.44, 0.42)), Vector3(60, 2, 1)), Vector3(0.0, 3.0, ROAD_Z + 94.0))
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
	var corr: StandardMaterial3D = mat(Color.WHITE, 0.45, 0.6, _corrugated(128), Vector3(40, 1, 1))
	box(Vector3(1120.0, 14.0, 430.0), corr, Vector3(0.0, 236.0, front - 205.0))
	# downspouts at the ends (no high windows: they clashed with the bays' canopies)
	for dsx in [-555.0, 555.0]:
		cyl(5.0, 5.0, 236.0, steel, Vector3(dsx, 118.0, front + 4.0))
	# the apron: expansion joints, a few oil stains
	for jk in 12:
		box(Vector3(2.0, 0.4, 290.0), mat(Color(0.40, 0.39, 0.37), 0.9), Vector3(-550.0 + float(jk) * 100.0, 1.2, 30.0))
	box(Vector3(1800.0, 0.4, 2.0), mat(Color(0.40, 0.39, 0.37), 0.9), Vector3(0.0, 1.2, 40.0))
	for ok in 5:
		var st: MeshInstance3D = cyl(18.0 + 14.0 * h01(ok + 60), 18.0, 0.3, mat(Color(0.18, 0.17, 0.16, 0.45), 0.3), Vector3(-400.0 + 190.0 * float(ok) + 40.0 * h01(ok), 1.3, 60.0 + 40.0 * h01(ok + 7)))
		st.scale = Vector3(1.4, 1.0, 0.8)
	box(Vector3(1120.0, 10.0, 6.0), mat(Color(0.20, 0.30, 0.26), 0.5, 0.3), Vector3(0.0, 238.0, front + 10.0))
	for b in BAYS.size():
		var bx2: float = BAYS[b]
		var col: Color = COLS[b]
		# INSIDE THE BAY: a warm lit room -- the back wall lit, a ceiling lamp, racking with stock on it, a pallet
		var inner: StandardMaterial3D = mat(Color(0.52, 0.46, 0.40), 0.85)
		box(Vector3(DOOR_W, DOOR_H, 4.0), inner, Vector3(bx2, DOOR_H * 0.5, front - 140.0))
		box(Vector3(4.0, DOOR_H, 130.0), inner, Vector3(bx2 - DOOR_W * 0.5, DOOR_H * 0.5, front - 75.0))
		box(Vector3(4.0, DOOR_H, 130.0), inner, Vector3(bx2 + DOOR_W * 0.5, DOOR_H * 0.5, front - 75.0))
		box(Vector3(DOOR_W, 4.0, 130.0), mat(Color(0.30, 0.28, 0.26), 0.9), Vector3(bx2, DOOR_H, front - 75.0))
		box(Vector3(DOOR_W, 2.0, 130.0), mat(Color(0.42, 0.40, 0.38), 0.7), Vector3(bx2, 0.5, front - 75.0))
		box(Vector3(40.0, 3.0, 8.0), glow(Color(1.0, 0.94, 0.80)), Vector3(bx2, DOOR_H - 3.0, front - 80.0))
		light(Vector3(bx2, DOOR_H - 12.0, front - 80.0), Color(1.0, 0.86, 0.62), 1.4, 150.0)
		var rack: StandardMaterial3D = mat(Color(0.20, 0.36, 0.62), 0.5, 0.4)
		for rs in [-1.0, 1.0]:
			box(Vector3(4.0, DOOR_H - 10.0, 4.0), rack, Vector3(bx2 + rs * 50.0, (DOOR_H - 10.0) * 0.5, front - 128.0))
		for sh in 3:
			box(Vector3(104.0, 3.0, 22.0), mat(Color(0.95, 0.55, 0.15), 0.5, 0.3), Vector3(bx2, 12.0 + float(sh) * 34.0, front - 126.0))
			for bx_k in 3:
				box(Vector3(24.0, 20.0, 18.0), mat(Color.WHITE, 0.85, 0.0, _card_tex), Vector3(bx2 - 34.0 + float(bx_k) * 32.0 + 6.0 * h01(sh * 3 + bx_k), 24.0 + float(sh) * 34.0, front - 126.0))
		# THE FRAME (the user: "the door frames are flat"): a steel channel painted in the bay's color -- a flange on
		# the wall's face with a bevelled edge, its return lining the opening, bolted on, the paint worn at the edges;
		# a black rubber seal inside it, the door's guide tracks, and rubber dock bumpers on steel backing plates
		var fm: StandardMaterial3D = mat(Color.WHITE, 0.45, 0.35, tex_speckle(64, col, 0.10, 31 + b), Vector3(1, 4, 1))
		var fm_dark: StandardMaterial3D = mat(col.darkened(0.30), 0.5, 0.35)
		var rubber: StandardMaterial3D = mat(Color(0.05, 0.05, 0.05), 0.85)
		var bolt: StandardMaterial3D = mat(Color(0.70, 0.70, 0.72), 0.3, 0.85)
		for e2 in [-1.0, 1.0]:
			var fx: float = bx2 + e2 * (DOOR_W * 0.5 + 8.0)
			put(rbox_mesh(8.0, 3.0, DOOR_H + 16.0, 2.5, 1.2), fm, Vector3(fx, 0.0, front + 3.0))
			box(Vector3(3.0, DOOR_H, 22.0), fm_dark, Vector3(bx2 + e2 * (DOOR_W * 0.5 + 1.5), DOOR_H * 0.5, front - 9.0))
			box(Vector3(2.5, DOOR_H, 3.0), rubber, Vector3(bx2 + e2 * (DOOR_W * 0.5 - 0.5), DOOR_H * 0.5, front - 4.0))
			box(Vector3(4.0, DOOR_H, 6.0), mat(Color(0.36, 0.38, 0.42), 0.4, 0.7), Vector3(bx2 + e2 * (DOOR_W * 0.5 - 3.0), DOOR_H * 0.5, front - 12.0))
			for bt in 6:
				sphere(1.5, bolt, Vector3(fx + e2 * 3.0, 12.0 + float(bt) * 22.0, front + 6.4))
			# the bumper: a steel plate, a thick rubber block with chamfered edges, two bolts
			box(Vector3(20.0, 30.0, 2.0), mat(Color(0.30, 0.31, 0.33), 0.4, 0.8), Vector3(bx2 + e2 * (DOOR_W * 0.5 - 12.0), 20.0, front + 7.0))
			var bump: MeshInstance3D = put(rbox_mesh(7.0, 6.0, 24.0, 2.5, 2.0), rubber, Vector3(bx2 + e2 * (DOOR_W * 0.5 - 12.0), 8.0, front + 14.0))
			bump.scale = Vector3(1.0, 1.0, 1.0)
			for bb in [-1.0, 1.0]:
				sphere(1.4, bolt, Vector3(bx2 + e2 * (DOOR_W * 0.5 - 12.0) + bb * 7.0, 30.0, front + 8.2))
		put(rbox_mesh(DOOR_W * 0.5 + 16.0, 3.0, 12.0, 2.5, 1.2), fm, Vector3(bx2, DOOR_H, front + 3.0))
		box(Vector3(DOOR_W + 6.0, 3.0, 22.0), fm_dark, Vector3(bx2, DOOR_H - 1.5, front - 9.0))
		for bt2 in 7:
			sphere(1.5, bolt, Vector3(bx2 - DOOR_W * 0.5 - 6.0 + float(bt2) * (DOOR_W + 12.0) / 6.0, DOOR_H + 9.0, front + 6.4))
		# the door's housing: a steel drum box over the opening, inside
		box(Vector3(DOOR_W + 4.0, 16.0, 18.0), mat(Color(0.40, 0.42, 0.45), 0.45, 0.6), Vector3(bx2, DOOR_H - 8.0, front - 20.0))
		# the canopy and its lamp, and the number's board
		# a canopy HIGH over the door (clear of the number's sign below it: a live sign drew over the baked canopy in
		# front of it), its lamp under it
		box(Vector3(DOOR_W + 40.0, 4.0, 56.0), steel, Vector3(bx2, DOOR_H + 86.0, front + 26.0), Vector3(-10.0, 0.0, 0.0))
		box(Vector3(DOOR_W + 40.0, 8.0, 3.0), mat(Color(0.20, 0.30, 0.26), 0.5, 0.3), Vector3(bx2, DOOR_H + 80.0, front + 54.0))
		# its brackets: triangular steel struts from the wall up under its front edge
		for bk in [-1.0, 1.0]:
			box(Vector3(3.0, 62.0, 3.0), steel, Vector3(bx2 + bk * (DOOR_W * 0.5 + 12.0), DOOR_H + 60.0, front + 26.0), Vector3(-58.0, 0.0, 0.0))
			box(Vector3(5.0, 10.0, 4.0), steel, Vector3(bx2 + bk * (DOOR_W * 0.5 + 12.0), DOOR_H + 38.0, front + 2.0))
		cyl(6.0, 12.0, 8.0, mat(Color(0.20, 0.30, 0.26), 0.5, 0.4), Vector3(bx2, DOOR_H + 78.0, front + 14.0))
		sphere(4.0, glow(Color(1.0, 0.92, 0.70)), Vector3(bx2, DOOR_H + 73.0, front + 14.0))
		# THE NUMBER: an enamel sign flat on the brick above the door -- a white plate, the bay's color inset, the figure
		# in white with a dark edge, four screws (its lit glow is live)
		var sign_c: Vector3 = Vector3(bx2, DOOR_H + 34.0, front + 1.0)
		put(rbox_mesh(26.0, 20.0, 3.0, 6.0, 1.0), mat(Color(0.95, 0.95, 0.92), 0.3), sign_c, Vector3(90.0, 0.0, 0.0))
		put(rbox_mesh(23.0, 17.0, 3.6, 4.5, 0.8), mat(col.lerp(Color(0.40, 0.40, 0.42), 0.65).darkened(0.35), 0.4), sign_c + Vector3(0.0, 0.0, 0.2), Vector3(90.0, 0.0, 0.0))
		var num: Label3D = label(str(b + 1), 30.0, Color(1.0, 1.0, 0.98), sign_c + Vector3(0.0, 0.0, 4.4))
		num.outline_size = 8
		num.outline_modulate = Color(0.0, 0.0, 0.0, 0.45)
		num.shaded = true
		for sx2 in [-1.0, 1.0]:
			for sy2 in [-1.0, 1.0]:
				sphere(1.4, mat(Color(0.75, 0.76, 0.78), 0.3, 0.8), sign_c + Vector3(sx2 * 22.0, sy2 * 17.0, 4.2))
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
		var tz: float = front - 120.0 - float(tk % 3) * 60.0
		cyl(8.0, 10.0, 130.0, mat(Color(0.32, 0.22, 0.14), 0.9), Vector3(tx, 65.0, tz))
		# a crown of several clumps, lighter where the sun is
		for cl in 5:
			var ca: float = TAU * float(cl) / 5.0 + h01(tk + cl)
			var cr: float = 42.0 + 14.0 * h01(tk * 5 + cl)
			sphere(cr, mat(Color(0.22, 0.38, 0.18).lerp(Color(0.34, 0.50, 0.24), h01(tk * 7 + cl)), 0.9), Vector3(tx + cos(ca) * 38.0, 170.0 + 26.0 * h01(tk * 3 + cl), tz + sin(ca) * 30.0))
		sphere(50.0, mat(Color(0.28, 0.45, 0.22), 0.9), Vector3(tx, 210.0, tz))

# --- live: the doors, the numbers, the truck -----------------------------------------------------------------------

# A WHEEL: a treaded tire (its tread a texture round it), a chrome rim, a hub with its nuts
func _wheel(parent: Node3D, x: float, z: float) -> void:
	var side: float = signf(z)
	cyl(11.0, 11.0, 8.0, _tire_m, Vector3(x, 11.0, z), Vector3(90.0, 0.0, 0.0), parent, 28)
	cyl(7.0, 7.0, 8.4, _chrome_m, Vector3(x, 11.0, z), Vector3(90.0, 0.0, 0.0), parent, 24)
	cyl(3.2, 3.2, 9.4, mat(Color(0.25, 0.25, 0.27), 0.4, 0.8), Vector3(x, 11.0, z), Vector3(90.0, 0.0, 0.0), parent, 16)
	for nt in 5:
		var na: float = TAU * float(nt) / 5.0
		sphere(0.9, _chrome_m, Vector3(x + cos(na) * 4.8, 11.0 + sin(na) * 4.8, z + side * 4.4), parent)

func _tire_tex(n: int) -> ImageTexture:
	var img: Image = Image.create(n, 8, false, Image.FORMAT_RGB8)
	for x in n:
		img.fill_rect(Rect2i(x, 0, 1, 8), Color(0.06, 0.06, 0.065) if (x / 3) % 2 == 0 else Color(0.11, 0.11, 0.12))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _cardboard(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			img.set_pixel(x, y, Color(0.70, 0.53, 0.33).darkened(0.07 * h01(x * 13 + y * 5)).lerp(Color(0.60, 0.44, 0.27), 0.25 * float((y / 2) % 2)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _plate_tex(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	img.fill(Color(0.42, 0.44, 0.47))
	for y in range(0, n, 8):
		for x in range(0, n, 8):
			var o: int = 4 if (y / 8) % 2 == 1 else 0
			img.fill_rect(Rect2i((x + o) % n, y + 2, 4, 2), Color(0.60, 0.62, 0.66))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

var _tire_m: StandardMaterial3D = null
var _chrome_m: StandardMaterial3D = null
var _card_tex: ImageTexture = null

func _build_live() -> void:
	_shared_mats()
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
		# THE NUMBER, LIT: the sign itself is in the picture (it takes the canopy's shadow there, like the brick round
		# it); live is its plate in the bay's own bright color when its parcel arrives, faded in over the baked one, the
		# figure in dark ink on it -- a PAINTED plate lit by the sun, NOT a light: the canopy's shadow lies across it
		# (glowing, it ignored the shadow -- "STILL the shadows do not affect the big numbers", the user)
		var sign_c: Vector3 = Vector3(float(BAYS[b]), DOOR_H + 34.0, FRONT_Z + 1.0)
		var pm: StandardMaterial3D = mat(Color((COLS[b] as Color).lightened(0.12), 0.0), 0.35)
		# a very faint glow only (enamel catching the sky): brighter, it read as unshaded beside the shaded brick
		pm.emission_enabled = true
		pm.emission = (COLS[b] as Color) * 0.12
		# the canopy and its brackets again, casting shadow only (the live view has its own shadows to cast)
		var cast_m: StandardMaterial3D = mat(Color(0.5, 0.5, 0.5), 0.5)
		var cb: Array = [box(Vector3(DOOR_W + 40.0, 4.0, 56.0), cast_m, Vector3(float(BAYS[b]), DOOR_H + 86.0, FRONT_Z + 26.0), Vector3(-10.0, 0.0, 0.0)),
			box(Vector3(DOOR_W + 40.0, 8.0, 3.0), cast_m, Vector3(float(BAYS[b]), DOOR_H + 80.0, FRONT_Z + 54.0))]
		for bk in [-1.0, 1.0]:
			cb.append(box(Vector3(3.0, 62.0, 3.0), cast_m, Vector3(float(BAYS[b]) + bk * (DOOR_W * 0.5 + 12.0), DOOR_H + 60.0, FRONT_Z + 26.0), Vector3(-58.0, 0.0, 0.0)))
		for cm in cb:
			(cm as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		put(rbox_mesh(23.0, 17.0, 3.6, 4.5, 0.8), pm, sign_c + Vector3(0.0, 0.0, 0.4), Vector3(90.0, 0.0, 0.0))
		var num: Label3D = label(str(b + 1), 30.0, Color(0.08, 0.06, 0.05, 0.0), sign_c + Vector3(0.0, 0.0, 4.6))
		num.outline_size = 0
		_nums.append(num)
		_plates.append(pm)
	# THE TRUCK: a cab-over engine and a flatbed cart per delivery, each with its parcel -- every part a shaped,
	# textured, lit thing (flat colored blocks read as toys)
	var paint: StandardMaterial3D = mat(Color(0.12, 0.36, 0.30), 0.22, 0.45)
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.9
	paint.clearcoat_roughness = 0.08
	var stripe: StandardMaterial3D = mat(Color(0.95, 0.78, 0.30), 0.3, 0.5)
	var glass: StandardMaterial3D = mat(Color(0.20, 0.28, 0.36), 0.03, 0.6)
	glass.clearcoat_enabled = true
	var dark: StandardMaterial3D = mat(Color(0.09, 0.09, 0.10), 0.55, 0.5)
	var plate: StandardMaterial3D = mat(Color.WHITE, 0.4, 0.8, _plate_tex(64), Vector3(3, 2, 1))
	var deck: StandardMaterial3D = mat(Color.WHITE, 0.7, 0.0, tex_wood(64, Color(0.55, 0.38, 0.22), 7), Vector3(1, 3, 1))
	_engine = Node3D.new()
	root.add_child(_engine)
	# the chassis and its frame rails
	box(Vector3(78.0, 6.0, 30.0), dark, Vector3(-2.0, 14.0, 0.0), Vector3.ZERO, _engine)
	# the cab: a rounded body, a raked windscreen, side windows, the roof's marker lamps, a pinstripe, the door seam
	put(rbox_mesh(19.0, 21.0, 40.0, 7.0, 4.0), paint, Vector3(16.0, 18.0, 0.0), Vector3.ZERO, _engine)
	box(Vector3(1.4, 15.0, 34.0), glass, Vector3(34.6, 46.0, 0.0), Vector3(0.0, 0.0, 10.0), _engine)
	for e in [-1.0, 1.0]:
		box(Vector3(20.0, 12.0, 1.0), glass, Vector3(14.0, 46.0, e * 21.2), Vector3.ZERO, _engine)
		box(Vector3(36.0, 1.6, 0.6), stripe, Vector3(16.0, 30.0, e * 21.6), Vector3.ZERO, _engine)
		box(Vector3(0.5, 22.0, 0.6), mat(Color(0.05, 0.08, 0.07), 0.6), Vector3(4.0, 36.0, e * 21.4), Vector3.ZERO, _engine)
		box(Vector3(5.0, 1.4, 0.8), _chrome_m, Vector3(8.0, 38.0, e * 21.8), Vector3.ZERO, _engine)
		# a step under the door, a fender arching over each wheel
		box(Vector3(14.0, 2.0, 5.0), plate, Vector3(14.0, 8.0, e * 20.0), Vector3.ZERO, _engine)
		# a FENDER over each wheel: a curved arch of plate following the tire's top (full discs read as more wheels)
		for fx in [22.0, -18.0]:
			for seg in 7:
				var fa: float = PI * (0.08 + 0.84 * float(seg) / 6.0)
				box(Vector3(5.4, 1.4, 10.0), dark, Vector3(fx + cos(fa) * 14.0, 11.0 + sin(fa) * 14.0, e * 18.0), Vector3(0.0, 0.0, rad_to_deg(fa) - 90.0), _engine)
		# the headlamps: chrome bezels round bright lenses; mirrors on arms
		cyl(4.4, 4.4, 2.0, _chrome_m, Vector3(35.4, 26.0, e * 13.0), Vector3(0.0, 0.0, 90.0), _engine, 20)
		cyl(3.4, 3.4, 2.4, glow(Color(1.0, 0.97, 0.86)), Vector3(36.0, 26.0, e * 13.0), Vector3(0.0, 0.0, 90.0), _engine, 20)
		box(Vector3(2.0, 1.4, 9.0), dark, Vector3(28.0, 52.0, e * 25.0), Vector3.ZERO, _engine)
		put(rbox_mesh(1.6, 2.6, 9.0, 1.0, 0.5), dark, Vector3(28.0, 46.0, e * 30.0), Vector3.ZERO, _engine)
	for ml in 3:
		sphere(1.5, glow(Color(1.0, 0.70, 0.25)), Vector3(30.0, 58.5, -8.0 + float(ml) * 8.0), _engine)
	# the grille and the bumper, chrome; a fuel tank on the frame, an exhaust stack
	box(Vector3(1.6, 12.0, 20.0), dark, Vector3(35.8, 26.0, 0.0), Vector3.ZERO, _engine)
	for gb in 5:
		box(Vector3(2.0, 1.0, 19.0), _chrome_m, Vector3(36.2, 21.0 + float(gb) * 2.6, 0.0), Vector3.ZERO, _engine)
	put(rbox_mesh(2.4, 22.0, 5.0, 2.0, 1.0), _chrome_m, Vector3(37.6, 11.0, 0.0), Vector3.ZERO, _engine)
	cyl(5.0, 5.0, 18.0, _chrome_m, Vector3(-8.0, 14.0, -17.0), Vector3(0.0, 0.0, 90.0), _engine, 20)
	cyl(2.2, 2.2, 34.0, _chrome_m, Vector3(-4.0, 52.0, 18.0), Vector3.ZERO, _engine, 12)
	cyl(2.6, 2.2, 4.0, dark, Vector3(-4.0, 70.0, 18.0), Vector3.ZERO, _engine, 12)
	_wheel(_engine, 22.0, 18.0)
	_wheel(_engine, 22.0, -18.0)
	_wheel(_engine, -18.0, 18.0)
	_wheel(_engine, -18.0, -18.0)
	for k in 3:
		var cart: Node3D = Node3D.new()
		root.add_child(cart)
		# a steel frame, a wooden deck of planks, stake sides, fenders, a drawbar to the one in front
		box(Vector3(72.0, 4.0, 40.0), plate, Vector3(0.0, 19.0, 0.0), Vector3.ZERO, cart)
		box(Vector3(70.0, 2.0, 38.0), deck, Vector3(0.0, 22.0, 0.0), Vector3.ZERO, cart)
		for pl in 6:
			box(Vector3(70.2, 0.4, 0.6), mat(Color(0.28, 0.18, 0.10), 0.8), Vector3(0.0, 23.1, -15.8 + float(pl) * 6.3), Vector3.ZERO, cart)
		for rs in [-1.0, 1.0]:
			for rp in 4:
				box(Vector3(2.4, 14.0, 2.4), plate, Vector3(-30.0 + float(rp) * 20.0, 30.0, rs * 19.5), Vector3.ZERO, cart)
			box(Vector3(66.0, 2.0, 1.6), deck, Vector3(0.0, 35.0, rs * 19.5), Vector3.ZERO, cart)
			box(Vector3(66.0, 2.0, 1.6), deck, Vector3(0.0, 29.0, rs * 19.5), Vector3.ZERO, cart)
		cyl(1.8, 1.8, 22.0, plate, Vector3(44.0, 16.0, 0.0), Vector3(0.0, 0.0, 90.0), cart, 10)
		# its PARCEL: cardboard, a band of tape in its bay's color, its bay's NUMBER on a white label
		var bay: int = 2 - k
		var pc: Color = COLS[bay]
		box(Vector3(46.0, 32.0, 32.0), mat(Color.WHITE, 0.85, 0.0, _card_tex), Vector3(0.0, 39.0, 0.0), Vector3.ZERO, cart)
		box(Vector3(46.6, 7.0, 32.6), mat(pc, 0.5), Vector3(0.0, 39.0, 0.0), Vector3.ZERO, cart)
		box(Vector3(9.0, 32.6, 32.6), mat(Color(0.82, 0.70, 0.48), 0.4), Vector3(-12.0, 39.0, 0.0), Vector3.ZERO, cart)
		box(Vector3(16.0, 14.0, 0.6), mat(Color(0.97, 0.96, 0.92), 0.7), Vector3(10.0, 45.0, 16.4), Vector3.ZERO, cart)
		var lb: Label3D = label(str(bay + 1), 12.0, Color(0.10, 0.10, 0.12), Vector3(10.0, 45.0, 16.9), Vector3.ZERO, cart)
		lb.outline_size = 0
		_wheel(cart, 22.0, 20.0)
		_wheel(cart, 22.0, -20.0)
		_wheel(cart, -22.0, 20.0)
		_wheel(cart, -22.0, -20.0)
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
	# THE CYCLE ENDS AS THE ENGINE LEAVES THE PICTURE and the next truck comes in at once (the user: no pause): its
	# length taken from the camera -- the x where the engine's tail is past the right edge -- and never shorter than
	# the last door's closing behind its cart
	if _cyc <= 0.0:
		var full: Vector2 = Vector2(MainGlobals.full_screen_size)
		var ex: float = 0.0
		while ex < 3000.0 and screen_of(Vector3(ex - 45.0, 30.0, ROAD_Z - 26.0)).x < full.x + 20.0:
			ex += 10.0
		# and where it comes in: its nose just off the left edge, so it is in view at once
		_enter_x = 0.0
		while _enter_x > -3000.0 and screen_of(Vector3(_enter_x + 45.0, 30.0, ROAD_Z - 26.0)).x > -10.0:
			_enter_x -= 10.0
		# the last cart's door (bay 1, the last cart's) is down again once the head is 350 on
		_cyc = (maxf(ex, 360.0) - _enter_x) / SPEED
	var u: float = fmod(t, _cyc)
	var head: float = _enter_x + SPEED * u        # the engine at the edge from the first frame, and again at once
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
		opened[bay] = smoothstep(-160.0, -20.0, into) * (1.0 - smoothstep(300.0, 370.0, into))
		done[bay] = smoothstep(260.0, 320.0, into)
	for b in _doors.size():
		(_doors[b] as Node3D).scale.y = maxf(0.03, 1.0 - 0.97 * float(opened[b]))
		var pm: StandardMaterial3D = _plates[b]
		# lit when its parcel is in; last round's signs fade out as the new truck comes in (never all off at once)
		var before: float = (1.0 - smoothstep(0.0, 1.2, u)) if t >= _cyc else 0.0
		var lit: float = maxf(float(done[b]), before)
		pm.albedo_color = Color(COLS[b], lit)
		var nl: Label3D = _nums[b]
		nl.modulate = Color(0.08, 0.06, 0.05, lit)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Dispatch", "Remember the delivery order", Color(1.0, 0.88, 0.60), Color(0.10, 0.08, 0.06),
		Color(1.0, 0.8, 0.5, 0.22))

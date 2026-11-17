extends "res://scripts/menu_poster3d.gd"

# WHACK'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A WHACK-A-MOLE
# STALL AT A FAIRGROUND AT NIGHT -- the game's own board is a fairground whack-a-mole box (board_backdrop.gd), so the
# poster is the stall it stands in (a shooting gallery was tried first: "why display a shooting range when whack is
# actually a whack-a-mole?", the user). A booth with red-and-white striped sides and posts, a striped awning with its
# scalloped valance, a valance of puffed scallops with chasing bulbs, a back wall of deep blue with gold stars,
# plush bears hung on the sides' fronts. In it the GAME TABLE: a turf top inside a striped rail, six burrows ringed
# with soil, a varnished body with striped panels. Out of the burrows pop the game's own DOMED BUTTONS (draw_area.gd),
# throwing soil -- the real ones red with the white center dot, the decoys blue without it -- and a big wooden
# MALLET swings down on each real one (a burst of stars, the button knocked back down) and lifts again, never
# touching a decoy, which sinks back on its own.
# The booth and the table's body are the baked picture (`whack/art/menu_booth.webp`); the turf top (the buttons
# come up THROUGH it), the burrows, buttons, soil, mallet, stars, bulbs, sides and bears are live. One clock (`t`);
# nothing pops. Made up, never the board.

const HOLES: Array = [Vector3(-125.0, 0.0, 30.0), Vector3(0.0, 0.0, 30.0), Vector3(125.0, 0.0, 30.0),
	Vector3(-125.0, 0.0, 115.0), Vector3(0.0, 0.0, 115.0), Vector3(125.0, 0.0, 115.0)]
const TOP_Y: float = 150.0             # the table's turf
const DOME_R: float = 27.0
const HIT_EVERY: float = 1.35
const RED: Color = Color(0.80, 0.08, 0.08)
const GOLD: Color = Color(0.95, 0.75, 0.25)
const TARGET: Color = Color(0.86, 0.20, 0.18)
const DECOY: Color = Color(0.26, 0.48, 0.90)
const SOIL: Color = Color(0.36, 0.24, 0.14)

var _domes: Array = []                # [Node3D, body material, rim material, dot node] per hole
var _clods: Array = []                # [MeshInstance3D, hole, k] -- soil thrown as a button comes up
var _sparks: Array = []               # [MeshInstance3D, material]
var _bulbs: Array = []
var _mallet: Node3D = null
var _swing: Node3D = null

# ONE PICTURE PER PLATFORM: a desktop's menu leaves the poster only a short band, so its camera stands further back
# and sees the whole stall, header to table, with the fair round it (with the phone's camera the panel hid the table)
func _baked_path() -> String:
	return "res://whack/art/menu_booth.webp" if mobile else "res://whack/art/menu_booth_d.webp"

func _eye() -> Vector3:
	return Vector3(0.0, 400.0, 600.0) if mobile else Vector3(0.0, 440.0, 930.0)

func _aim() -> Vector3:
	return Vector3(0.0, 205.0, 0.0) if mobile else Vector3(0.0, 215.0, 0.0)

func _fov() -> float:
	return 47.0

func _frame_frac() -> float:
	return 0.50

# the awning's top, above the scene's center
func _scene_top() -> float:
	return 250.0 if mobile else 150.0

func _environment(env: Environment) -> void:
	env.background_color = Color(0.015, 0.015, 0.04)
	env.ambient_light_color = Color(0.45, 0.42, 0.60)
	env.ambient_light_energy = 0.32

func _build_lights() -> void:
	# the booth's lamps under the header, warm on the table; a glow from the bulbs; a cool night fill
	spot(Vector3(-110.0, 380.0, 170.0), Vector3(-50.0, TOP_Y, 70.0), Color(1.0, 0.86, 0.62), 9.0, 460.0, 45.0, true)
	spot(Vector3(110.0, 380.0, 170.0), Vector3(50.0, TOP_Y, 70.0), Color(1.0, 0.86, 0.62), 9.0, 460.0, 45.0)
	light(Vector3(0.0, 400.0, 220.0), Color(1.0, 0.80, 0.50), 0.8, 320.0)
	light(Vector3(0.0, 60.0, 360.0), Color(1.0, 0.70, 0.45), 0.6, 300.0)
	light(Vector3(-300.0, 300.0, 300.0), Color(0.55, 0.65, 1.0), 0.5, 500.0)
	# a soft warm light in front, up at the valance
	light(Vector3(0.0, 300.0, 420.0), Color(1.0, 0.85, 0.65), 1.1, 420.0)

# --- textures ---------------------------------------------------------------------------------------------------

func _stripes(n: int, a: Color, b: Color, bands: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for x in n:
		var c: Color = a if (x * bands / n) % 2 == 0 else b
		img.fill_rect(Rect2i(x, 0, 1, n), c)
	for k in n * n / 6:
		var px: int = int(h01(k * 3 + 7) * float(n - 1))
		var py: int = int(h01(k * 3 + 8) * float(n - 1))
		img.set_pixel(px, py, img.get_pixel(px, py).darkened(0.08 * h01(k)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _stars(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	img.fill(Color(0.08, 0.10, 0.30))
	for k in 70:
		var cx: int = int(h01(k * 5 + 1) * float(n))
		var cy: int = int(h01(k * 5 + 2) * float(n))
		var r: int = 2 + int(h01(k * 5 + 3) * 4.0)
		for a in 5:
			var ang: float = TAU * float(a) / 5.0 - PI * 0.5
			for d in r * 2:
				var px: int = cx + int(cos(ang) * float(d) * 0.5)
				var py: int = cy + int(sin(ang) * float(d) * 0.5)
				if px >= 0 and px < n and py >= 0 and py < n:
					img.set_pixel(px, py, GOLD)
		img.fill_rect(Rect2i(cx - r / 2, cy - r / 2, r, r), GOLD)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# mown turf: green bands, fine speckle
func _turf(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var band: bool = (x * 6 / n) % 2 == 0
			var c: Color = Color(0.26, 0.52, 0.20) if band else Color(0.22, 0.45, 0.17)
			c = c.lightened(0.10 * (h01(x * 31 + y * 17) - 0.5))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# --- the booth and the table's body: baked -------------------------------------------------------------------

func _build_still() -> void:
	var wood: StandardMaterial3D = mat(Color.WHITE, 0.45, 0.0, tex_wood(256, Color(0.52, 0.28, 0.14), 3), Vector3(3, 1, 1))
	var dark_wood: StandardMaterial3D = mat(Color.WHITE, 0.35, 0.0, tex_wood(256, Color(0.28, 0.14, 0.07), 5), Vector3(3, 1, 1))
	var brass: StandardMaterial3D = mat(Color(0.88, 0.68, 0.32), 0.3, 0.4)
	var stripe: StandardMaterial3D = mat(Color.WHITE, 0.6, 0.0, _stripes(256, RED, Color(0.96, 0.93, 0.86), 8))
	# the boardwalk in front, planks
	box(Vector3(1000.0, 6.0, 700.0), mat(Color.WHITE, 0.7, 0.0, tex_wood(256, Color(0.40, 0.30, 0.22), 9), Vector3(4, 8, 1)), Vector3(0.0, -3.0, 300.0))
	# THE FAIR AROUND IT (seen at the sides, more on a desktop): the neighbor stalls, dim, under their own awnings,
	# and strings of bulbs looping between poles
	for side in [-1.0, 1.0]:
		var nx: float = side * 560.0
		var tent: StandardMaterial3D = mat(Color.WHITE, 0.7, 0.0, _stripes(128, Color(0.20, 0.30, 0.55) if side < 0.0 else Color(0.20, 0.45, 0.30), Color(0.85, 0.80, 0.70), 8))
		box(Vector3(300.0, 260.0, 20.0), tent, Vector3(nx, 130.0, -160.0))
		box(Vector3(330.0, 3.0, 90.0), tent, Vector3(nx, 290.0, -110.0), Vector3(-20.0, 0.0, 0.0))
		box(Vector3(260.0, 70.0, 6.0), mat(Color(0.10, 0.06, 0.04), 0.6), Vector3(nx, 205.0, -148.0))
		box(Vector3(240.0, 50.0, 2.0), glow(Color(0.50, 0.32, 0.16)), Vector3(nx, 205.0, -144.0))
		box(Vector3(310.0, 100.0, 60.0), dark_wood, Vector3(nx, 50.0, -110.0))
		cyl(5.0, 5.0, 520.0, dark_wood, Vector3(side * 360.0, 260.0, 260.0))
		for k in 13:
			var u: float = float(k) / 12.0
			var bx: float = lerpf(side * 360.0, side * 760.0, u)
			var by: float = 515.0 - 60.0 * 4.0 * u * (1.0 - u)
			sphere(3.4, glow([Color(1.0, 0.85, 0.5), Color(1.0, 0.45, 0.4), Color(0.6, 0.8, 1.0)][k % 3]), Vector3(bx, by, 260.0 - 300.0 * u))
	box(Vector3(2400.0, 6.0, 1400.0), mat(Color.WHITE, 0.7, 0.0, tex_wood(256, Color(0.40, 0.30, 0.22), 9), Vector3(10, 16, 1)), Vector3(0.0, -3.5, 0.0))
	# the back wall of stars, and a shelf of prizes along it
	box(Vector3(460.0, 350.0, 4.0), mat(Color.WHITE, 0.8, 0.0, _stars(256), Vector3(2, 1.4, 1)), Vector3(0.0, 175.0, -62.0))
	box(Vector3(440.0, 6.0, 30.0), dark_wood, Vector3(0.0, 262.0, -46.0))
	for k in 9:
		var px: float = -190.0 + float(k) * 47.5
		var col: Color = [Color(0.85, 0.55, 0.30), Color(0.45, 0.65, 0.90), Color(0.92, 0.55, 0.70), Color(0.95, 0.85, 0.40)][k % 4]
		var pm: StandardMaterial3D = mat(col, 0.95)
		sphere(13.0, pm, Vector3(px, 278.0, -44.0))
		sphere(10.0, pm, Vector3(px, 299.0, -42.0))
		for e in [-1.0, 1.0]:
			sphere(4.0, pm, Vector3(px + e * 7.0, 307.0, -44.0))
	# (no header board: the user -- "remove the win a prize area to make all else bigger")
	# the awning: a striped slope out over the table, its valance of scallops
	box(Vector3(500.0, 3.0, 90.0), stripe, Vector3(0.0, 366.0, 160.0), Vector3(-18.0, 0.0, 0.0))
	# THE VALANCE: a band along the awning's front edge, and under it PUFFED FABRIC SCALLOPS, each a rounded cushion
	# lit by the lamps (they were flat discs, the user: "make the white/red circles nicer"), a gold cord along the seam
	box(Vector3(504.0, 16.0, 10.0), stripe, Vector3(0.0, 349.0, 205.0))
	for k in 20:
		var sx: float = -240.0 + float(k) * 25.2 + 12.6
		var fab: StandardMaterial3D = mat(RED if k % 2 == 0 else Color(0.96, 0.93, 0.86), 0.55, 0.0)
		fab.clearcoat_enabled = true
		fab.clearcoat = 0.25
		var sc: MeshInstance3D = sphere(12.6, fab, Vector3(sx, 341.0, 204.0))
		sc.scale = Vector3(1.0, 1.05, 0.42)
	cyl(1.8, 1.8, 506.0, mat(Color(0.95, 0.76, 0.34), 0.3, 0.6), Vector3(0.0, 341.5, 210.5), Vector3(0.0, 0.0, 90.0))
	for k2 in 21:
		sphere(2.4, mat(Color(0.95, 0.76, 0.34), 0.3, 0.6), Vector3(-252.0 + float(k2) * 25.2, 341.5, 211.5))
	# THE TABLE's body: varnished, striped panels in brass frames, a lit strip under its lip
	box(Vector3(440.0, TOP_Y - 6.0, 200.0), wood, Vector3(0.0, (TOP_Y - 6.0) * 0.5, 70.0))
	box(Vector3(440.0, 3.0, 2.0), glow(Color(1.0, 0.82, 0.45)), Vector3(0.0, TOP_Y - 18.0, 171.0))
	var panel_stripe: StandardMaterial3D = mat(Color.WHITE, 0.55, 0.0, _stripes(128, RED, Color(0.96, 0.93, 0.86), 6))
	for k in 5:
		var px2: float = -168.0 + float(k) * 84.0
		box(Vector3(70.0, 80.0, 1.0), brass, Vector3(px2, 66.0, 170.4))
		box(Vector3(64.0, 74.0, 1.0), panel_stripe, Vector3(px2, 66.0, 171.0))
	# the posts at the corners, striped
	for px3 in [-245.0, 245.0]:
		cyl(7.0, 7.0, 380.0, stripe, Vector3(px3, 190.0, 118.0))
		sphere(9.0, brass, Vector3(px3, 384.0, 118.0))

# --- live ---------------------------------------------------------------------------------------------------------

func _build_live() -> void:
	var brass: StandardMaterial3D = mat(Color(0.88, 0.68, 0.32), 0.3, 0.4)
	# the striped sides
	var stripe: StandardMaterial3D = mat(Color.WHITE, 0.6, 0.0, _stripes(128, RED, Color(0.96, 0.93, 0.86), 8))
	for side in [-1.0, 1.0]:
		box(Vector3(30.0, 380.0, 170.0), stripe, Vector3(side * 238.0, 190.0, 30.0))
	# THE TURF TOP (live: the buttons come up through it) inside a striped rail, the burrows ringed with soil
	box(Vector3(436.0, 8.0, 196.0), mat(Color.WHITE, 0.9, 0.0, _turf(64), Vector3(3, 1.4, 1)), Vector3(0.0, TOP_Y - 4.0, 70.0))
	var rail: StandardMaterial3D = mat(Color.WHITE, 0.5, 0.0, _stripes(128, RED, Color(0.96, 0.93, 0.86), 16))
	box(Vector3(440.0, 12.0, 10.0), rail, Vector3(0.0, TOP_Y + 2.0, 168.0))
	box(Vector3(440.0, 12.0, 10.0), rail, Vector3(0.0, TOP_Y + 2.0, -28.0))
	for side2 in [-1.0, 1.0]:
		box(Vector3(10.0, 12.0, 196.0), rail, Vector3(side2 * 215.0, TOP_Y + 2.0, 70.0))
	var soil: StandardMaterial3D = mat(SOIL, 0.95)
	var hole_m: StandardMaterial3D = mat(Color(0.03, 0.02, 0.01), 1.0)
	for k in HOLES.size():
		var hp: Vector3 = HOLES[k] + Vector3(0.0, TOP_Y, 0.0)
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = DOME_R + 1.0
		ring.outer_radius = DOME_R + 12.0
		var rm: MeshInstance3D = put(ring, soil, hp + Vector3(0.0, 1.0, 0.0))
		rm.scale = Vector3(1.0, 0.45, 1.0)
		cyl(DOME_R + 2.0, DOME_R + 2.0, 1.0, hole_m, hp + Vector3(0.0, 0.6, 0.0))
		# THE BUTTON: a dome in its color on a darker rim; the real target's white center dot
		var d: Node3D = Node3D.new()
		root.add_child(d)
		var body_m: StandardMaterial3D = mat(TARGET, 0.25, 0.05)
		body_m.clearcoat_enabled = true
		body_m.clearcoat = 0.8
		var rim_m: StandardMaterial3D = mat(TARGET.darkened(0.35), 0.4)
		var dome: MeshInstance3D = sphere(DOME_R, body_m, Vector3(0.0, 8.0, 0.0), d, true)
		dome.scale = Vector3(1.0, 0.72, 1.0)
		cyl(DOME_R + 1.0, DOME_R + 1.0, 16.0, rim_m, Vector3(0.0, 0.0, 0.0), Vector3.ZERO, d, 40)
		var dot: MeshInstance3D = cyl(6.0, 6.0, 1.2, mat(Color(1, 1, 1), 0.3), Vector3(0.0, 8.0 + DOME_R * 0.72 + 0.2, 0.0), Vector3.ZERO, d, 24)
		_domes.append([d, body_m, rim_m, dot])
		for c in 6:
			var cm: MeshInstance3D = sphere(3.2 + 1.6 * h01(k * 9 + c), soil, Vector3.ZERO)
			cm.visible = false
			_clods.append([cm, k, c])
	# THE MALLET: a pivot at the grip, a turned handle, a big wooden head with brass bands, its face striking down
	_mallet = Node3D.new()
	root.add_child(_mallet)
	_swing = Node3D.new()
	_mallet.add_child(_swing)
	var handle_m: StandardMaterial3D = mat(Color.WHITE, 0.5, 0.0, tex_wood(64, Color(0.72, 0.52, 0.30), 4))
	var head_m: StandardMaterial3D = mat(Color.WHITE, 0.45, 0.0, tex_wood(64, Color(0.62, 0.32, 0.16), 2))
	cyl(5.0, 6.0, 130.0, handle_m, Vector3(-65.0, 0.0, 0.0), Vector3(0.0, 0.0, 90.0), _swing)
	cyl(7.0, 7.0, 30.0, mat(Color(0.15, 0.08, 0.05), 0.7), Vector3(-12.0, 0.0, 0.0), Vector3(0.0, 0.0, 90.0), _swing)
	cyl(26.0, 26.0, 74.0, head_m, Vector3(-135.0, 0.0, 0.0), Vector3.ZERO, _swing, 40)
	for e in [-1.0, 1.0]:
		cyl(26.6, 26.6, 6.0, brass, Vector3(-135.0, e * 30.0, 0.0), Vector3.ZERO, _swing, 40)
	# the stars of a hit
	for k in 12:
		var sm: StandardMaterial3D = glow(Color(1.0, 0.88, 0.40))
		var mi: MeshInstance3D = sphere(3.4, sm, Vector3.ZERO)
		mi.visible = false
		_sparks.append([mi, sm])
	# PRIZES on the sides' fronts: plush bears hung by cords from the awning's frame
	for k in 6:
		var side3: float = -1.0 if k < 3 else 1.0
		var bx2: float = side3 * 238.0
		var by: float = 318.0 - float(k % 3) * 62.0
		var bz: float = 128.0
		var fur: StandardMaterial3D = mat([Color(0.85, 0.55, 0.30), Color(0.45, 0.65, 0.90), Color(0.92, 0.55, 0.70)][(k + (k / 3)) % 3], 0.95)
		box(Vector3(0.6, 30.0, 0.6), mat(Color(0.9, 0.9, 0.85), 0.8), Vector3(bx2, by + 34.0, bz))
		sphere(12.0, fur, Vector3(bx2, by - 8.0, bz))
		sphere(9.0, fur, Vector3(bx2, by + 10.0, bz + 1.0))
		for e2 in [-1.0, 1.0]:
			sphere(3.6, fur, Vector3(bx2 + e2 * 6.5, by + 17.0, bz))
			sphere(3.6, fur, Vector3(bx2 + e2 * 11.0, by - 5.0, bz + 3.0))
		sphere(3.0, mat(Color(0.95, 0.88, 0.80), 0.9), Vector3(bx2, by + 8.0, bz + 8.5))
		for e3 in [-1.0, 1.0]:
			sphere(1.2, mat(Color(0.05, 0.04, 0.04), 0.3), Vector3(bx2 + e3 * 3.2, by + 12.5, bz + 8.6))
	# the bulbs along the valance band, chasing
	for k in 24:
		var bm: StandardMaterial3D = glow(Color(1.0, 0.86, 0.55))
		sphere(3.0, bm, Vector3(-236.0 + float(k) * 20.5, 349.0, 210.5))
		_bulbs.append(bm)

# --- the motion ---------------------------------------------------------------------------------------------------

# the hole of the real target struck at hit h (never the one just struck)
func _target_hole(h: int) -> int:
	var k: int = int(h01(h * 13 + 5) * float(HOLES.size())) % HOLES.size()
	var prev: int = int(h01((h - 1) * 13 + 5) * float(HOLES.size())) % HOLES.size()
	if k == prev:
		k = (k + 2) % HOLES.size()
	return k

# the decoy that comes up around hit h (on two hits of three), in a hole that is neither this target's nor the next's
func _decoy_hole(h: int) -> int:
	if posmod(h, 3) == 2:
		return -1
	var a: int = _target_hole(h)
	var b: int = _target_hole(h + 1)
	var k: int = int(h01(h * 29 + 11) * float(HOLES.size())) % HOLES.size()
	while k == a or k == b:
		k = (k + 1) % HOLES.size()
	return k

const RAISE: float = 0.30             # how far up a button stands out of its burrow

func _animate(_delta: float) -> void:
	if _mallet == null:
		return
	var hn: int = int(floor(t / HIT_EVERY))
	var up: Array = []
	up.resize(HOLES.size())
	up.fill(0.0)
	var kind: Array = []
	kind.resize(HOLES.size())
	kind.fill(0)                        # 0 target, 1 decoy
	var since_rise: Array = []
	since_rise.resize(HOLES.size())
	since_rise.fill(9.0)
	for h in range(hn - 1, hn + 3):
		var th: float = float(h) * HIT_EVERY
		var tk: int = _target_hole(h)
		# a target: up 0.7 s before its strike, knocked down by it
		var f: float = smoothstep(th - 0.80, th - 0.62, t) * (1.0 - smoothstep(th + 0.01, th + 0.16, t))
		if f > float(up[tk]):
			up[tk] = f
			kind[tk] = 0
		if t >= th - 0.80 and t - (th - 0.80) < float(since_rise[tk]):
			since_rise[tk] = t - (th - 0.80)
		var dk: int = _decoy_hole(h)
		if dk >= 0:
			var g: float = smoothstep(th - 0.55, th - 0.38, t) * (1.0 - smoothstep(th + 0.45, th + 0.70, t))
			if g > float(up[dk]):
				up[dk] = g
				kind[dk] = 1
			if t >= th - 0.55 and t - (th - 0.55) < float(since_rise[dk]):
				since_rise[dk] = t - (th - 0.55)
	for k in HOLES.size():
		var dd: Array = _domes[k]
		var node: Node3D = dd[0]
		var u: float = float(up[k])
		node.position = HOLES[k] + Vector3(0.0, TOP_Y - 24.0 + 24.0 * u + DOME_R * RAISE * u, 0.0)
		node.visible = u > 0.01
		var col: Color = TARGET if int(kind[k]) == 0 else DECOY
		(dd[1] as StandardMaterial3D).albedo_color = col
		(dd[2] as StandardMaterial3D).albedo_color = col.darkened(0.35)
		(dd[3] as Node3D).visible = int(kind[k]) == 0
	# the soil thrown up as a button comes out: clods flying out of the burrow and falling back on the turf
	for cl in _clods:
		var mi: MeshInstance3D = cl[0]
		var hk: int = int(cl[1])
		var s: float = float(since_rise[hk])
		if s > 0.55:
			mi.visible = false
			continue
		var a: float = TAU * (float(cl[2]) + h01(int(cl[2]) * 7 + hk * 3) * 0.6) / 6.0
		var reach: float = DOME_R + 8.0 + 26.0 * (s / 0.55)
		var hgt: float = 34.0 * (s / 0.55) * (1.0 - s / 0.55) * 4.0 * 0.5
		mi.visible = true
		mi.position = HOLES[hk] + Vector3(cos(a) * reach, TOP_Y + 3.0 + hgt, sin(a) * reach * 0.8)
		mi.scale = Vector3.ONE * (1.0 - smoothstep(0.40, 0.55, s))
	# THE MALLET: over the next target, raised; down on it at the strike; up again, and over to the next
	var th0: float = float(hn) * HIT_EVERY
	var u2: float = t - th0                       # since this period's strike
	var here: Vector3 = HOLES[_target_hole(hn)]
	var nxt: Vector3 = HOLES[_target_hole(hn + 1)]
	var travel: float = smoothstep(0.30, HIT_EVERY - 0.30, u2)
	var over: Vector3 = here.lerp(nxt, travel)
	var lift: float
	if u2 < 0.30:
		lift = smoothstep(0.04, 0.30, u2) * 38.0                     # up after the strike
	elif u2 > HIT_EVERY - 0.16:
		lift = 38.0 * (1.0 - smoothstep(HIT_EVERY - 0.16, HIT_EVERY, u2) )   # the swing down onto the next
	else:
		lift = 38.0 + 3.0 * sin((u2 - 0.30) * 5.0)
	var strike_y: float = TOP_Y + 8.0 + DOME_R * 0.72 + DOME_R * RAISE + 26.0
	var yaw: float = deg_to_rad(-28.0)
	_mallet.position = over + Vector3(0.0, strike_y, 0.0) + Vector3(135.0, 0.0, 0.0).rotated(Vector3.UP, yaw)
	_mallet.rotation = Vector3(0.0, yaw, 0.0)
	_swing.rotation = Vector3(0.0, 0.0, -deg_to_rad(lift))
	# the stars of the latest strike
	for sp in _sparks:
		(sp[0] as MeshInstance3D).visible = false
	if u2 < 0.5:
		var center: Vector3 = here + Vector3(0.0, TOP_Y + 22.0, 0.0)
		for k in _sparks.size():
			var a2: float = TAU * float(k) / float(_sparks.size()) + h01(hn * 41 + k) * 0.4
			var spk: Array = _sparks[k]
			var mi2: MeshInstance3D = spk[0]
			mi2.visible = true
			mi2.position = center + Vector3(cos(a2), 0.35 + 0.3 * h01(k), sin(a2)) * (90.0 * u2) + Vector3(0.0, 30.0 * u2, 0.0)
			var fade: float = 1.0 - u2 / 0.5
			mi2.scale = Vector3.ONE * (0.3 + fade)
			(spk[1] as StandardMaterial3D).albedo_color = Color(1.0, 0.92, 0.50).lerp(Color(1.0, 0.55, 0.20), 1.0 - fade)
	# the bulbs chase round the header, slowly
	for k in _bulbs.size():
		var wave: float = 0.5 + 0.5 * sin(float(k) * 0.6 - t * 3.2)
		(_bulbs[k] as StandardMaterial3D).albedo_color = Color(0.55, 0.40, 0.22).lerp(Color(1.0, 0.95, 0.75), wave)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Whack", "Tap quickly and accurately. Avoid decoys", Color(1.0, 0.86, 0.35), Color(0.20, 0.04, 0.04),
		Color(1.0, 0.7, 0.3, 0.25))

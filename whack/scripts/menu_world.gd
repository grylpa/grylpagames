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
const TOP_Y: float = 150.0
const SIDE_CUT: float = TOP_Y - 14.0     # the striped sides are baked below this, live above
const WHEEL_C: Vector3 = Vector3(-560.0, 760.0, -1500.0)
const WHEEL_R: float = 520.0             # the table's turf
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
var _wheel: Node3D = null
var _gondolas: Array = []              # [Node3D, its angle on the wheel]
var _fair_vpc: SubViewportContainer = null
var _fair_vp: SubViewport = null
var _score: Label3D = null
var _mallet: Node3D = null
var _swing: Node3D = null

# ONE PICTURE PER PLATFORM: a desktop's menu leaves the poster only a short band, so its camera stands further back
# and sees the whole stall, header to table, with the fair round it (with the phone's camera the panel hid the table)
func _baked_path() -> String:
	return "res://whack/art/menu_booth.webp" if mobile else "res://whack/art/menu_booth_d.webp"

func _eye() -> Vector3:
	return Vector3(0.0, 420.0, 700.0) if mobile else Vector3(0.0, 440.0, 930.0)

func _aim() -> Vector3:
	return Vector3(0.0, 205.0, 0.0) if mobile else Vector3(0.0, 215.0, 0.0)

func _fov() -> float:
	return 47.0

func _frame_frac() -> float:
	return 0.50

# the awning's top, above the scene's center
func _scene_top() -> float:
	return 250.0 if mobile else 150.0

func _bake_alpha() -> bool:
	return true

func _environment(env: Environment) -> void:
	env.background_color = Color(0.015, 0.015, 0.04)
	env.ambient_light_color = Color(0.45, 0.42, 0.60)
	env.ambient_light_energy = 0.32

func _build_lights() -> void:
	# the booth's lamps under the header, warm on the table; a glow from the bulbs; a cool night fill
	spot(Vector3(-110.0, 380.0, 170.0), Vector3(-50.0, TOP_Y, 70.0), Color(1.0, 0.86, 0.62), 0.9, 460.0, 45.0, true)
	spot(Vector3(110.0, 380.0, 170.0), Vector3(50.0, TOP_Y, 70.0), Color(1.0, 0.86, 0.62), 0.9, 460.0, 45.0)
	light(Vector3(0.0, 400.0, 220.0), Color(1.0, 0.80, 0.50), 0.8, 320.0)
	light(Vector3(0.0, 60.0, 360.0), Color(1.0, 0.70, 0.45), 0.6, 300.0)
	light(Vector3(-300.0, 300.0, 300.0), Color(0.55, 0.65, 1.0), 0.5, 500.0)
	# a low key from the front on the table, so the buttons coming up read in their colors
	spot(Vector3(0.0, 250.0, 420.0), Vector3(0.0, TOP_Y, 60.0), Color(1.0, 0.92, 0.80), 0.5, 520.0, 30.0)
	# a soft warm light in front, up at the valance
	light(Vector3(0.0, 300.0, 420.0), Color(1.0, 0.85, 0.65), 1.1, 420.0)
	# and a wash down the cabinet's front, so the enameled body reads as standing furniture, apart from the boards
	spot(Vector3(0.0, 230.0, 560.0), Vector3(0.0, 70.0, 170.0), Color(1.0, 0.90, 0.74), 1.1, 700.0, 26.0)

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
	# navy VELVET (a fine weave, the nap darker toward the foot) with painted GOLD-LEAF stars, each with a darker rim
	# and a lighter heart, and the paint worn a little at the edges
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var weave: float = 0.5 + 0.5 * sin(float(x) * 1.9) * sin(float(y) * 1.9)
			var c: Color = Color(0.10, 0.12, 0.34).darkened(0.25 * float(y) / float(n) + 0.10 * weave + 0.08 * h01(x * 7 + y * 13))
			img.set_pixel(x, y, c)
	for k in 46:
		var cx: float = h01(k * 5 + 1) * float(n)
		var cy: float = h01(k * 5 + 2) * float(n)
		var r: float = 4.0 + h01(k * 5 + 3) * 6.0
		var rot: float = h01(k * 5 + 4) * TAU
		for y2 in range(int(cy - r - 2.0), int(cy + r + 3.0)):
			for x2 in range(int(cx - r - 2.0), int(cx + r + 3.0)):
				var dx: float = float(x2) - cx
				var dy: float = float(y2) - cy
				var ang: float = atan2(dy, dx) + rot
				var reach: float = r * (0.45 + 0.55 * pow(absf(cos(ang * 2.5)), 6.0))
				var dist: float = sqrt(dx * dx + dy * dy)
				if dist > reach or x2 < 0 or y2 < 0 or x2 >= n or y2 >= n:
					continue
				var edge: float = clampf((reach - dist) / 1.6, 0.0, 1.0)
				var gc: Color = Color(0.70, 0.50, 0.18).lerp(Color(1.0, 0.86, 0.42), edge * (1.0 - dist / (r * 1.4)))
				if h01(x2 * 37 + y2 * 11) > 0.93:
					gc = gc.darkened(0.4)       # worn leaf
				img.set_pixel(x2, y2, gc)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _night(n: int) -> ImageTexture:
	# the sky over the fair: deep blue overhead to a warm violet glow over the rides, stars, a thin cloud
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var v: float = float(y) / float(n)
			var c: Color = Color(0.02, 0.03, 0.10).lerp(Color(0.10, 0.08, 0.24), smoothstep(0.1, 0.7, v)).lerp(Color(0.42, 0.20, 0.30), smoothstep(0.65, 1.0, v))
			var cloud: float = 0.5 + 0.5 * sin(float(x) * 0.05 + sin(float(y) * 0.11) * 2.0)
			c = c.lerp(Color(0.24, 0.16, 0.30), 0.18 * cloud * smoothstep(0.3, 0.6, v) * (1.0 - smoothstep(0.6, 0.8, v)))
			img.set_pixel(x, y, c)
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

# the boardwalk's planks (one tile: 8 planks across, the grain running along them): weathered silver-brown, each its own
# tone, dark gaps, staggered butt joints, a pair of nail heads over each joist; with a normal map from its height
func _deck_tex() -> Array:
	var n: int = 256
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var hgt: PackedFloat32Array = PackedFloat32Array()
	hgt.resize(n * n)
	for y in n:
		for x in n:
			var pk: int = x / 32
			var px: int = x % 32
			var joint: int = int(h01(pk * 17 + 3) * float(n))
			var base: Color = Color(0.46, 0.38, 0.30).lerp(Color(0.56, 0.52, 0.46), h01(pk * 7 + 1)).darkened(0.12 * h01(pk * 11 + 2))
			var grain: float = sin(float(x) * 1.7 + sin(float(y) * 0.05 + float(pk)) * 3.0) * 0.5 + 0.5
			var c: Color = base.darkened(0.10 * grain + 0.06 * h01(x * 131 + y * 7))
			var hh: float = 1.0 - 0.15 * grain
			var edge: int = mini(px, 31 - px)
			if edge < 2:
				c = Color(0.06, 0.05, 0.04)
				hh = 0.0
			elif edge < 4:
				c = c.darkened(0.25)
				hh = 0.6
			var dj: int = absi(y - joint)
			if dj < 2 or dj > n - 2:
				c = Color(0.10, 0.08, 0.06)
				hh = 0.1
			# the nails, over joists every 64 rows
			for jy in [32, 96, 160, 224]:
				for nx in [9, 23]:
					if Vector2(px - nx, y - jy).length() < 1.8:
						c = Color(0.20, 0.20, 0.22)
						hh = 0.8
			img.set_pixel(x, y, c)
			hgt[y * n + x] = hh
	img.generate_mipmaps()
	var nimg: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y2 in n:
		for x2 in n:
			var hx: float = hgt[y2 * n + (x2 + 1) % n] - hgt[y2 * n + (x2 - 1 + n) % n]
			var hy: float = hgt[((y2 + 1) % n) * n + x2] - hgt[((y2 - 1 + n) % n) * n + x2]
			var nrm: Vector3 = Vector3(-hx * 2.0, -hy * 2.0, 1.0).normalized()
			nimg.set_pixel(x2, y2, Color(nrm.x * 0.5 + 0.5, nrm.y * 0.5 + 0.5, nrm.z * 0.5 + 0.5))
	nimg.generate_mipmaps()
	return [ImageTexture.create_from_image(img), ImageTexture.create_from_image(nimg)]

# --- the booth and the table's body: baked -------------------------------------------------------------------

func _build_still() -> void:
	var dark_wood: StandardMaterial3D = mat(Color.WHITE, 0.35, 0.0, tex_wood(256, Color(0.28, 0.14, 0.07), 5), Vector3(3, 1, 1))
	var brass: StandardMaterial3D = mat(Color(0.88, 0.68, 0.32), 0.3, 0.4)
	var stripe: StandardMaterial3D = mat(Color.WHITE, 0.6, 0.0, _stripes(256, RED, Color(0.96, 0.93, 0.86), 8))
	# THE BOARDWALK: ONE deck of weathered planks running AWAY from us, gaps between them, butt joints and nail heads
	# (the user, 2026-11-19: "what is all the brown at the bottom ... two brown surfaces ... with the exact same color"
	# -- two overlapping dark boxes of differently scaled grain, plainer than the planks they stood for)
	var deck: Array = _deck_tex()
	var deck_m: StandardMaterial3D = mat(Color.WHITE, 0.62, 0.0, deck[0], Vector3(14.0, 7.0, 1.0))
	deck_m.normal_enabled = true
	deck_m.normal_texture = deck[1]
	var deck_q: PlaneMesh = PlaneMesh.new()
	deck_q.size = Vector2(2800.0, 1400.0)
	put(deck_q, deck_m, Vector3(0.0, 0.0, 0.0))
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
	if bake_mode:
		pass                      # (the fair is its own live view, behind the booth: its wheel turns)
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
	_build_header(false)
	# THE TABLE's body: a cabinet front in red lacquer framed in gilt beading, a lit SCOREBOARD set in it -- black glass
	# in a steel bezel, its figures live (the striped panels read as an empty basket, the lit strip on bare
	# wood as "a brown rect with a yellow line" -- the user)
	# (2026-11-18, the user: "what does that scoreboard stand on? ... it has the exact same color as the floor" -- the
	# dark red front read as more boardwalk): a CREAM-ENAMELED cabinet, plainly a piece of furniture standing on the
	# boards -- a black plinth set back under it (a dark shadow line at the floor), red fielded panels in gilt beading
	# either side of the scoreboard, a gilt rail along its top and foot
	var enamel: StandardMaterial3D = mat(Color.WHITE, 0.3, 0.0, tex_wood(256, Color(0.88, 0.80, 0.64), 21), Vector3(2, 1, 1))
	enamel.clearcoat_enabled = true
	enamel.clearcoat = 0.7
	var lacquer: StandardMaterial3D = mat(Color(0.62, 0.07, 0.08), 0.22, 0.1)
	lacquer.clearcoat_enabled = true
	lacquer.clearcoat = 0.9
	box(Vector3(424.0, 18.0, 186.0), mat(Color(0.05, 0.04, 0.04), 0.5), Vector3(0.0, 9.0, 62.0))
	box(Vector3(440.0, TOP_Y - 24.0, 200.0), enamel, Vector3(0.0, 18.0 + (TOP_Y - 24.0) * 0.5, 70.0))
	for by in [21.0, TOP_Y - 10.0]:
		cyl(2.6, 2.6, 438.0, brass, Vector3(0.0, by, 171.0), Vector3(0.0, 0.0, 90.0), null, 10)
	for bx in [-218.0, 218.0]:
		cyl(2.6, 2.6, TOP_Y - 31.0, brass, Vector3(bx, (TOP_Y + 11.0) * 0.5, 171.0), Vector3.ZERO, null, 10)
	for side_p in [-1.0, 1.0]:
		var pc: Vector3 = Vector3(side_p * 150.0, 84.0, 170.0)
		put(rbox_mesh(40.0, 44.0, 4.0, 6.0, 2.5), lacquer, pc, Vector3(90.0, 0.0, 0.0))
		put(rbox_mesh(28.0, 32.0, 6.5, 4.0, 3.0), lacquer, pc, Vector3(90.0, 0.0, 0.0))
		for gy2 in [-48.0, 48.0]:
			cyl(1.8, 1.8, 88.0, brass, pc + Vector3(0.0, gy2, 4.6), Vector3(0.0, 0.0, 90.0), null, 8)
		for gx2 in [-44.0, 44.0]:
			cyl(1.8, 1.8, 98.0, brass, pc + Vector3(gx2, 0.0, 4.6), Vector3.ZERO, null, 8)
	# the striped sides' feet, beside the cabinet (their upper part is live)
	for side_s in [-1.0, 1.0]:
		box(Vector3(30.0, SIDE_CUT, 170.0), stripe, Vector3(side_s * 238.0, SIDE_CUT * 0.5, 30.0))
	# the scoreboard SET INTO the cabinet front, higher up (the user: no word, a little higher, and "what does it stand
	# on?"): a dark steel bezel standing proud of the lacquer, its brass frame, the black glass recessed in it, a brass
	# screw at each corner
	var sb_y: float = 84.0
	var steel_b: StandardMaterial3D = mat(Color(0.10, 0.10, 0.11), 0.35, 0.7)
	put(rbox_mesh(104.0, 34.0, 5.0, 8.0, 2.0), steel_b, Vector3(0.0, sb_y, 169.5), Vector3(90.0, 0.0, 0.0))
	for gy in [sb_y - 28.0, sb_y + 28.0]:
		cyl(2.6, 2.6, 196.0, brass, Vector3(0.0, gy, 174.8), Vector3(0.0, 0.0, 90.0), null, 10)
	for gx in [-97.0, 97.0]:
		cyl(2.6, 2.6, 58.0, brass, Vector3(gx, sb_y, 174.8), Vector3.ZERO, null, 10)
	box(Vector3(184.0, 50.0, 1.0), mat(Color(0.02, 0.02, 0.03), 0.05, 0.4), Vector3(0.0, sb_y, 173.6))
	for sx in [-100.0, 100.0]:
		for sy in [-30.0, 30.0]:
			sphere(2.4, brass, Vector3(sx, sb_y + sy, 175.2))
	# the posts at the corners, striped
	for px3 in [-245.0, 245.0]:
		cyl(7.0, 7.0, FASCIA_Y0, stripe, Vector3(px3, FASCIA_Y0 * 0.5, 118.0))
		cyl(9.0, 7.0, 6.0, brass, Vector3(px3, FASCIA_Y0 - 3.0, 118.0))

# THE FAIR BEHIND, at night, filling the sky over the stall (it was an empty black band): the sky, a big Ferris
# wheel turning its lit rim over the stalls at the left, a carousel's peaked and scalloped roof at the right with its
# crown of bulbs, the far stalls between (bulb strings in front were tried: near the camera they swam as big
# blurs behind the title)
func _build_fair() -> void:
	var sky: StandardMaterial3D = mat(Color.WHITE, 1.0, 0.0, _night(128))
	sky.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box(Vector3(5200.0, 2600.0, 2.0), sky, Vector3(0.0, 900.0, -2400.0))
	# its stars as real points (stars in the stretched sky texture swam as white smears)
	for st in 90:
		var sp3: Vector3 = Vector3(lerpf(-2200.0, 2200.0, h01(st * 3 + 900)), lerpf(700.0, 2100.0, h01(st * 3 + 901)), -2390.0)
		sphere(2.0 + 3.0 * pow(h01(st * 3 + 902), 3.0), glow(Color(0.95, 0.93, 1.0).darkened(0.4 * h01(st + 903))), sp3)
	var steel: StandardMaterial3D = mat(Color(0.70, 0.72, 0.78), 0.35, 0.7)
	var bulb_cols: Array = [Color(1.0, 0.86, 0.52), Color(1.0, 0.50, 0.42), Color(0.60, 0.82, 1.0), Color(0.70, 1.0, 0.60)]
	# THE FERRIS WHEEL: two rims of steel, spokes, the hub, the A-frame legs, gondolas hanging plumb, bulbs on the rims
	var wc: Vector3 = WHEEL_C
	var wr: float = WHEEL_R
	# what turns hangs from a pivot at the hub (`_wheel`); the gondolas are their own, hanging plumb (`_gondolas`)
	_wheel = Node3D.new()
	root.add_child(_wheel)
	_wheel.position = wc
	for rim_z in [-30.0, 30.0]:
		var rim: TorusMesh = TorusMesh.new()
		rim.inner_radius = wr - 7.0
		rim.outer_radius = wr + 7.0
		rim.rings = 96
		put(rim, steel, Vector3(0.0, 0.0, rim_z), Vector3(90.0, 0.0, 0.0), _wheel)
	# neon tubes along the rim and round the hub, so the wheel reads at night
	for neon in [[wr + 9.0, Color(1.0, 0.45, 0.65)]]:
		var tube: TorusMesh = TorusMesh.new()
		tube.inner_radius = float(neon[0]) - 2.5
		tube.outer_radius = float(neon[0]) + 2.5
		tube.rings = 128
		put(tube, glow(neon[1]), Vector3(0.0, 0.0, 36.0), Vector3(90.0, 0.0, 0.0), _wheel)
	for sp in 16:
		var a: float = TAU * float(sp) / 16.0
		var tip: Vector3 = Vector3(cos(a), sin(a), 0.0) * wr
		var spoke: MeshInstance3D = cyl(2.5, 2.5, wr, steel, tip * 0.5, Vector3.ZERO, _wheel)
		spoke.rotation = Vector3(0.0, 0.0, a - PI * 0.5)
		# a gondola hanging plumb from the rim: a rounded cabin with a canopy
		var gon: Node3D = Node3D.new()
		root.add_child(gon)
		cyl(2.0, 2.0, 40.0, steel, Vector3(0.0, -20.0, 0.0), Vector3.ZERO, gon, 6)
		put(rbox_mesh(32.0, 24.0, 40.0, 10.0, 4.0), mat(bulb_cols[sp % 4].darkened(0.35), 0.4, 0.2), Vector3(0.0, -66.0, 0.0), Vector3.ZERO, gon)
		cyl(8.0, 38.0, 12.0, mat(Color(0.95, 0.93, 0.86), 0.5), Vector3(0.0, -28.0, 0.0), Vector3.ZERO, gon, 16)
		_gondolas.append([gon, a])
	for bl in 64:
		var ab: float = TAU * float(bl) / 64.0
		sphere(6.0, glow(bulb_cols[bl % 4]), Vector3(cos(ab), sin(ab), 0.0) * wr + Vector3(0.0, 0.0, 34.0), _wheel)
	for sp2 in 16:
		var a2: float = TAU * float(sp2) / 16.0
		for bs in 4:
			sphere(4.0, glow(Color(1.0, 0.90, 0.62)), Vector3(cos(a2), sin(a2), 0.0) * wr * (0.25 + 0.18 * float(bs)) + Vector3(0.0, 0.0, 34.0), _wheel)
	cyl(26.0, 26.0, 90.0, steel, wc, Vector3(90.0, 0.0, 0.0), null, 24)
	sphere(18.0, glow(Color(1.0, 0.86, 0.52)), wc + Vector3(0.0, 0.0, 46.0))
	for leg in [-1.0, 1.0]:
		var foot: Vector3 = Vector3(wc.x + leg * 330.0, 0.0, wc.z)
		var leg_m: MeshInstance3D = cyl(8.0, 12.0, foot.distance_to(wc), steel, (foot + wc) * 0.5)
		leg_m.rotation = Vector3(0.0, 0.0, atan2(wc.x - foot.x, foot.y - wc.y) + PI)
	# THE CAROUSEL at the right: a drum of mirrored panels lit from within, a peaked striped roof, its scalloped skirt,
	# a crown of bulbs, a pennant on top
	var cc: Vector3 = Vector3(760.0, 0.0, -1300.0)
	var roof_m: StandardMaterial3D = mat(Color.WHITE, 0.6, 0.0, _stripes(128, Color(0.75, 0.12, 0.14), Color(0.96, 0.92, 0.82), 16))
	cyl(240.0, 240.0, 220.0, mat(Color(0.95, 0.80, 0.50), 0.4, 0.3), cc + Vector3(0.0, 110.0, 0.0), Vector3.ZERO, null, 48)
	cyl(232.0, 232.0, 120.0, glow(Color(1.0, 0.70, 0.40)), cc + Vector3(0.0, 120.0, 0.0), Vector3.ZERO, null, 48)
	cyl(20.0, 280.0, 170.0, roof_m, cc + Vector3(0.0, 305.0, 0.0), Vector3.ZERO, null, 32)
	for sk in 32:
		var ak: float = TAU * float(sk) / 32.0
		var scl: MeshInstance3D = sphere(26.0, mat(Color(0.75, 0.12, 0.14) if sk % 2 == 0 else Color(0.96, 0.92, 0.82), 0.6), cc + Vector3(cos(ak) * 282.0, 214.0, sin(ak) * 282.0))
		scl.scale = Vector3(1.0, 0.8, 1.0)
		scl.rotation = Vector3(0.0, -ak, 0.0)
		sphere(5.0, glow(bulb_cols[sk % 4]), cc + Vector3(cos(ak) * 250.0, 232.0, sin(ak) * 250.0))
	cyl(3.0, 3.0, 90.0, mat(Color(0.88, 0.68, 0.32), 0.3, 0.7), cc + Vector3(0.0, 430.0, 0.0), Vector3.ZERO, null, 8)
	box(Vector3(50.0, 26.0, 2.0), mat(Color(0.95, 0.75, 0.25), 0.5), cc + Vector3(26.0, 460.0, 0.0))
	# far stalls between, their warm windows, and their own strings of bulbs
	for fs in 5:
		var fx: float = -300.0 + float(fs) * 230.0
		var fh: float = 160.0 + 60.0 * h01(fs + 60)
		box(Vector3(180.0, fh, 80.0), mat(Color(0.18, 0.12, 0.16), 0.8), Vector3(fx, fh * 0.5, -1800.0))
		box(Vector3(120.0, 40.0, 2.0), glow(Color(1.0, 0.70, 0.38).darkened(0.3 * h01(fs + 61))), Vector3(fx, fh * 0.55, -1759.0))
		cyl(10.0, 130.0, 60.0, mat(Color.WHITE, 0.6, 0.0, _stripes(64, [Color(0.18, 0.36, 0.62), Color(0.62, 0.20, 0.30), Color(0.20, 0.50, 0.30)][fs % 3], Color(0.90, 0.86, 0.74), 8)), Vector3(fx, fh + 30.0, -1800.0), Vector3.ZERO, null, 16)

# THE HEADER (2026-11-18; the user: "what is that string of circles floating in the air ... all other things about the
# booth's top are not good enough"): a solid lacquered FASCIA across the posts' tops, framed in gilt beading, its row
# of bulbs set in brass sockets in it (they hung in the air in front of the stall); an ARCHED CREST over its middle,
# painted with a sunburst, bulbs round its arch; a pitched striped canvas ROOF behind; and under the fascia a cloth
# VALANCE cut in scallops, red and cream panels with a gold braid along their edge and a tassel at each join.
# Built into the picture AND into the live view (`live`), where it stands in front of the live sides; the bulbs
# are live only (they chase).
const FASCIA_Z: float = 126.0
const FASCIA_Y0: float = 328.0
const FASCIA_Y1: float = 384.0
const CREST_R: float = 80.0

func _sunburst(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var cx: float = float(n) * 0.5
	for y in n:
		for x in n:
			var dx: float = float(x) - cx
			var dy: float = float(n) - float(y)
			var ang: float = atan2(dy, dx)
			var ray: float = 0.5 + 0.5 * cos(ang * 22.0)
			var dist: float = sqrt(dx * dx + dy * dy) / float(n)
			var c: Color = Color(0.62, 0.08, 0.10).lerp(Color(0.96, 0.78, 0.36), smoothstep(0.35, 0.65, ray) * (1.0 - smoothstep(0.75, 1.0, dist)))
			c = c.lerp(Color(1.0, 0.92, 0.66), (1.0 - smoothstep(0.0, 0.22, dist)) * 0.9)
			c = c.darkened(0.10 * h01(x * 13 + y * 7))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# one scalloped cloth panel: top edge straight, bottom a half-round, bulging a little forward in the middle
func _scallop_mesh(w: float, top_h: float, bulge: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs: int = 10
	var rows: int = 4
	var r: float = w * 0.5
	var grid: Array = []
	for j in rows + 1:
		var v: float = float(j) / float(rows)
		var row: Array = []
		for i in segs + 1:
			var u: float = float(i) / float(segs)
			var x: float = -r + u * w
			var bottom: float = -top_h - sqrt(maxf(0.0, r * r - x * x))
			var y: float = lerpf(0.0, bottom, v)
			var z: float = bulge * sin(u * PI) * v
			row.append(Vector3(x, y, z))
		grid.append(row)
	for j in rows:
		for i in segs:
			var p00: Vector3 = grid[j][i]
			var p10: Vector3 = grid[j][i + 1]
			var p01: Vector3 = grid[j + 1][i]
			var p11: Vector3 = grid[j + 1][i + 1]
			for tri in [[p00, p10, p11], [p00, p11, p01]]:
				var nrm: Vector3 = ((tri[1] as Vector3) - (tri[0] as Vector3)).cross((tri[2] as Vector3) - (tri[0] as Vector3)).normalized()
				if nrm.z < 0.0:
					nrm = -nrm
				for pt in tri:
					st.set_normal(nrm)
					st.add_vertex(pt)
	return st.commit()

func _build_header(live: bool) -> void:
	var lacquer: StandardMaterial3D = mat(Color(0.56, 0.06, 0.07), 0.28, 0.1)
	lacquer.clearcoat_enabled = true
	lacquer.clearcoat = 0.7
	var gilt: StandardMaterial3D = mat(Color(0.92, 0.70, 0.30), 0.28, 0.75)
	var cloth_red: StandardMaterial3D = mat(Color(0.78, 0.08, 0.09), 0.75)
	cloth_red.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cloth_cream: StandardMaterial3D = mat(Color(0.95, 0.91, 0.82), 0.75)
	cloth_cream.cull_mode = BaseMaterial3D.CULL_DISABLED
	var half: float = 262.0
	# the fascia board and its gilt beading
	box(Vector3(half * 2.0, FASCIA_Y1 - FASCIA_Y0, 10.0), lacquer, Vector3(0.0, (FASCIA_Y0 + FASCIA_Y1) * 0.5, FASCIA_Z))
	for yb in [FASCIA_Y0 + 3.0, FASCIA_Y1 - 3.0]:
		cyl(2.4, 2.4, half * 2.0 + 4.0, gilt, Vector3(0.0, yb, FASCIA_Z + 5.5), Vector3(0.0, 0.0, 90.0), null, 12)
	for xb in [-half, half]:
		cyl(2.4, 2.4, FASCIA_Y1 - FASCIA_Y0, gilt, Vector3(xb, (FASCIA_Y0 + FASCIA_Y1) * 0.5, FASCIA_Z + 5.5), Vector3.ZERO, null, 12)
	# brass sockets for the bulbs
	for k in 24:
		var bx: float = -half + 14.0 + float(k) * ((half * 2.0 - 28.0) / 23.0)
		cyl(4.6, 4.6, 3.0, gilt, Vector3(bx, (FASCIA_Y0 + FASCIA_Y1) * 0.5, FASCIA_Z + 6.0), Vector3(90.0, 0.0, 0.0), null, 16)
	# THE CREST: a half-disc board on the fascia's middle, the sunburst painted on it, a gilt rim round its arch
	var crest_m: StandardMaterial3D = mat(Color.WHITE, 0.4, 0.05, _sunburst(128))
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = CREST_R
	disc.bottom_radius = CREST_R
	disc.height = 8.0
	disc.radial_segments = 48
	var crest: MeshInstance3D = put(disc, crest_m, Vector3(0.0, FASCIA_Y1 - 2.0, FASCIA_Z - 1.0), Vector3(90.0, 0.0, 0.0))
	crest.scale = Vector3(1.0, 1.0, 1.0)
	var arc: PackedVector3Array = PackedVector3Array()
	for k2 in 33:
		var a: float = PI * float(k2) / 32.0
		arc.append(Vector3(cos(a) * (CREST_R + 1.5), FASCIA_Y1 - 2.0 + sin(a) * (CREST_R + 1.5), FASCIA_Z + 3.5))
	put(tube_mesh(arc, 3.2, 10), gilt, Vector3.ZERO)
	for k3 in 9:
		var a3: float = PI * (float(k3) + 0.5) / 9.0
		cyl(4.0, 4.0, 3.0, gilt, Vector3(cos(a3) * (CREST_R - 9.0), FASCIA_Y1 - 2.0 + sin(a3) * (CREST_R - 9.0), FASCIA_Z + 4.0), Vector3(90.0, 0.0, 0.0), null, 14)
	sphere(7.0, gilt, Vector3(0.0, FASCIA_Y1 + CREST_R + 6.0, FASCIA_Z + 2.0))
	# THE ROOF: striped canvas pitched back from the fascia's top to the back wall
	if not live:
		var stripe: StandardMaterial3D = mat(Color.WHITE, 0.65, 0.0, _stripes(256, RED, Color(0.96, 0.93, 0.86), 10))
		var run: float = FASCIA_Z + 62.0
		var rise: float = 34.0
		var roof: MeshInstance3D = box(Vector3(half * 2.0, 3.0, sqrt(run * run + rise * rise)), stripe, Vector3(0.0, FASCIA_Y1 + rise * 0.5, (FASCIA_Z - 62.0) * 0.5))
		roof.rotation = Vector3(-atan2(rise, run), 0.0, 0.0)
	# THE VALANCE under the fascia: scalloped panels, a gold braid on their edge, tassels at the joins
	var pw: float = 26.2
	var n_p: int = 20
	var x0: float = -pw * float(n_p) * 0.5
	var sm: ArrayMesh = _scallop_mesh(pw, 10.0, 3.5)
	for k4 in n_p:
		var cx: float = x0 + pw * (float(k4) + 0.5)
		put(sm, cloth_red if k4 % 2 == 0 else cloth_cream, Vector3(cx, FASCIA_Y0 + 1.0, FASCIA_Z + 5.5))
		var edge: PackedVector3Array = PackedVector3Array()
		for e in 13:
			var u: float = float(e) / 12.0
			var x: float = -pw * 0.5 + u * pw
			var r2: float = pw * 0.5
			edge.append(Vector3(cx + x, FASCIA_Y0 + 1.0 - 10.0 - sqrt(maxf(0.0, r2 * r2 - x * x)), FASCIA_Z + 5.5 + 3.5 * sin(u * PI) + 0.6))
		put(tube_mesh(edge, 0.9, 6), gilt, Vector3.ZERO)
	for k5 in n_p + 1:
		var tx: float = x0 + pw * float(k5)
		cyl(0.5, 0.5, 8.0, gilt, Vector3(tx, FASCIA_Y0 - 9.0, FASCIA_Z + 6.5), Vector3.ZERO, null, 6)
		cyl(1.0, 2.6, 7.0, gilt, Vector3(tx, FASCIA_Y0 - 16.0, FASCIA_Z + 6.5), Vector3.ZERO, null, 10)
		sphere(1.6, gilt, Vector3(tx, FASCIA_Y0 - 12.0, FASCIA_Z + 6.5))
	if live:
		for k6 in 24:
			var bx2: float = -half + 14.0 + float(k6) * ((half * 2.0 - 28.0) / 23.0)
			var bm: StandardMaterial3D = glow(Color(1.0, 0.86, 0.55))
			sphere(3.4, bm, Vector3(bx2, (FASCIA_Y0 + FASCIA_Y1) * 0.5, FASCIA_Z + 8.0))
			_bulbs.append(bm)
		for k7 in 9:
			var a7: float = PI * (float(k7) + 0.5) / 9.0
			var bm2: StandardMaterial3D = glow(Color(1.0, 0.86, 0.55))
			sphere(3.0, bm2, Vector3(cos(a7) * (CREST_R - 9.0), FASCIA_Y1 - 2.0 + sin(a7) * (CREST_R - 9.0), FASCIA_Z + 6.0))
			_bulbs.append(bm2)

# --- live ---------------------------------------------------------------------------------------------------------

# THE FAIR IS ITS OWN LIVE VIEW, BEHIND THE BOOTH (the user: "can the big wheel turn?"): the booth is baked with a
# clear sky, and under that picture a second 3-D view with the same camera holds the sky, the stars, the carousel,
# the far stalls and the FERRIS WHEEL, turning slowly, its gondolas hanging plumb -- so the wheel turns behind
# everything that stands in front of it
func _setup() -> void:
	super._setup()
	if bake_mode:
		return
	_fair_vpc = SubViewportContainer.new()
	_fair_vpc.stretch = true
	_fair_vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fair_vpc)
	move_child(_fair_vpc, 0)
	_fair_vp = SubViewport.new()
	_fair_vp.own_world_3d = true
	_fair_vp.msaa_3d = Viewport.MSAA_4X
	_fair_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_fair_vpc.add_child(_fair_vp)
	var world: Node3D = Node3D.new()
	_fair_vp.add_child(world)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.42, 0.60)
	env.ambient_light_energy = 0.35
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var cam: Camera3D = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = _fov()
	cam.near = 0.05
	cam.far = 60.0
	world.add_child(cam)
	cam.look_at_from_position(_eye() * 0.01, _aim() * 0.01, Vector3.UP)
	cam.current = true
	var keep: Node3D = root
	root = Node3D.new()
	world.add_child(root)
	root.scale = Vector3.ONE * 0.01
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.light_color = Color(0.70, 0.70, 0.95)
	moon.light_energy = 0.5
	root.add_child(moon)
	moon.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
	_build_fair()
	root = keep

func _shown_changed(shown: bool) -> void:
	super._shown_changed(shown)
	if _fair_vp != null:
		_fair_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED

func _tick(delta: float) -> void:
	super._tick(delta)
	if _fair_vpc != null and _vpc != null:
		_fair_vpc.position = _vpc.position
		_fair_vpc.size = _vpc.size
	# the wheel turning, slowly; each gondola hung plumb from its place on the rim
	if _wheel != null:
		var turn: float = -t * 0.10
		_wheel.rotation = Vector3(0.0, 0.0, turn)
		for g in _gondolas:
			var a: float = float(g[1]) + turn
			(g[0] as Node3D).position = WHEEL_C + Vector3(cos(a), sin(a), 0.0) * WHEEL_R + Vector3(0.0, 0.0, 0.0)

# a button's plastic, lit like the rest, but DISCARDED below the turf's top (in the world: the root is at 1:100), so the
# part of a button still down in its burrow never shows -- through the baked cabinet front, live meshes drawing over it
const BUTTON: String = """
shader_type spatial;
uniform vec4 col : source_color = vec4(1.0);
uniform float rough = 0.3;
uniform float coat = 0.0;
uniform float glow = 0.0;
uniform float clip_y = 0.0;
varying float wy;
void vertex() {
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}
void fragment() {
	if (wy < clip_y) {
		discard;
	}
	ALBEDO = col.rgb;
	ROUGHNESS = rough;
	METALLIC = 0.05;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = 0.15;
	EMISSION = col.rgb * glow;
}
"""
var _button_shader: Shader = null

func _button_mat(col: Color, rough: float, coat: float, glow_e: float) -> ShaderMaterial:
	if _button_shader == null:
		_button_shader = Shader.new()
		_button_shader.code = BUTTON
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _button_shader
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("coat", coat)
	m.set_shader_parameter("glow", glow_e)
	m.set_shader_parameter("clip_y", (TOP_Y - 0.5) * 0.01)
	return m

func _build_live() -> void:
	# the scoreboard's figures, amber in its black glass, counting each hit
	_score = label("0000", 30.0, Color(1.0, 0.70, 0.25), Vector3(0.0, 84.0, 174.4))
	_score.outline_size = 10
	_score.outline_modulate = Color(1.0, 0.40, 0.10, 0.45)
	_score.font = load("res://art/fonts/JetBrainsMono.ttf") if ResourceLoader.exists("res://art/fonts/JetBrainsMono.ttf") else _score.font
	var brass: StandardMaterial3D = mat(Color(0.88, 0.68, 0.32), 0.3, 0.4)
	# the striped sides, ABOVE THE TABLE ONLY (they hide the live turf and mallet there). Below, they are baked
	# (`_build_still`): live meshes always draw over the picture, and the sides' inner faces, which the cabinet hides,
	# were drawn over its front -- two maroon wedges connected to nothing (the user, 2026-11-19, twice)
	var stripe: StandardMaterial3D = mat(Color.WHITE, 0.6, 0.0, _stripes(128, RED, Color(0.96, 0.93, 0.86), 8))
	for side in [-1.0, 1.0]:
		box(Vector3(30.0, 380.0 - SIDE_CUT, 170.0), stripe, Vector3(side * 238.0, (380.0 + SIDE_CUT) * 0.5, 30.0))
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
		# (the plastic glows a little in its color: they read dark under the stall). CUT OFF AT THE TURF (`_button_mat`):
		# a button rising in a front hole was seen through the cabinet's front -- live meshes draw over the picture
		var body_m: ShaderMaterial = _button_mat(TARGET, 0.22, 0.8, 0.35)
		var rim_m: ShaderMaterial = _button_mat(TARGET.darkened(0.35), 0.4, 0.0, 0.0)
		var dome: MeshInstance3D = sphere(DOME_R, body_m, Vector3(0.0, 8.0, 0.0), d, true)
		dome.scale = Vector3(1.0, 0.72, 1.0)
		cyl(DOME_R + 1.0, DOME_R + 1.0, 16.0, rim_m, Vector3(0.0, 0.0, 0.0), Vector3.ZERO, d, 40)
		var dot: MeshInstance3D = cyl(6.0, 6.0, 1.2, _button_mat(Color(1, 1, 1), 0.3, 0.0, 0.0), Vector3(0.0, 8.0 + DOME_R * 0.72 + 0.2, 0.0), Vector3.ZERO, d, 24)
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
	_build_header(true)

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
	if _score != null:
		_score.text = "%04d" % (posmod(int(floor((t - 0.05) / HIT_EVERY)) + 1, 1000) * 10)
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
		(dd[1] as ShaderMaterial).set_shader_parameter("col", col)
		(dd[2] as ShaderMaterial).set_shader_parameter("col", col.darkened(0.35))
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

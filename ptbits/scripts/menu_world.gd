extends "res://scripts/menu_poster3d.gd"

# NUDGE'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): AN OLD ARCADE
# CABINET in a dim arcade at night. A varnished wooden case on turned legs (no marquee: the glass is the picture),
# a brass coin plate, a checkered floor under it, a neighbor cabinet's glow at each side. Behind its glass, the game in the
# cabinet's own world: a deep violet field (the game's arena colors), a brass funnel at the top dropping glass
# marbles one at a time, four colored cups on the side walls, and at the foot four TOOLS -- a colored disc on a
# brass rod with its loop below, one per color, standing in their slot. As each marble falls, the tool of ITS
# color rises to meet it and lofts it up and over into the cup of its color, which lights; then sinks back.
# The case, the room and the field are the baked picture (`ptbits/art/menu_cabinet.webp`); the marbles, the
# tools, the cups (a marble goes INTO one), the funnel (a marble starts inside it) and the glass are live.
# One clock (`t`); nothing pops. Made up, never the board.

const COLORS: Array = [
	Color(0.93, 0.30, 0.32),  # red
	Color(0.30, 0.55, 0.96),  # blue
	Color(0.34, 0.79, 0.44),  # green
	Color(0.97, 0.80, 0.26),  # yellow
]
const CUPS: Array = [Vector3(-124.0, 392.0, -6.0), Vector3(-124.0, 300.0, -6.0), Vector3(124.0, 392.0, -6.0), Vector3(124.0, 300.0, -6.0)]
const PARK_X: Array = [-90.0, -30.0, 30.0, 90.0]
const ORDER: Array = [0, 2, 1, 3, 2, 0, 3, 1]
const PERIOD: float = 2.7
const PARK_Y: float = 186.0          # a parked tool's disc center
const MEET_Y: float = 236.0          # where a marble meets its tool
const FUNNEL_Y: float = 456.0
const BALL_R: float = 15.0
const DISC_R: float = 21.0
const WIN: Rect2 = Rect2(-162.0, 150.0, 324.0, 330.0)   # the glass: x, y (bottom), width, height

var _ball: Node3D = null
var _ball_mat: StandardMaterial3D = null
var _tools: Array = []               # Node3D per color
var _cup_glow: Array = []            # StandardMaterial3D per cup (its lit rim)

# ONE PICTURE PER PLATFORM: on a phone the camera comes close, the game in the glass large; a desktop's menu leaves
# a short band, so its camera stands further back and the whole glass shows above the panel
func _baked_path() -> String:
	return "res://ptbits/art/menu_cabinet.webp" if mobile else "res://ptbits/art/menu_cabinet_d.webp"

func _eye() -> Vector3:
	return Vector3(0.0, 330.0, 690.0) if mobile else Vector3(0.0, 340.0, 1020.0)

func _aim() -> Vector3:
	return Vector3(0.0, 290.0, 0.0) if mobile else Vector3(0.0, 330.0, 0.0)

func _fov() -> float:
	return 47.0

func _frame_frac() -> float:
	return 0.44 if mobile else 0.50

func _scene_top() -> float:
	return 0.0

func _environment(env: Environment) -> void:
	env.background_color = Color(0.02, 0.015, 0.04)
	env.ambient_light_color = Color(0.50, 0.42, 0.62)
	env.ambient_light_energy = 0.32

func _build_lights() -> void:
	# the marquee's lamp shining down into the field, warm; a soft light on the case's front; the neighbors' glow
	spot(Vector3(0.0, 478.0, 30.0), Vector3(0.0, 200.0, -20.0), Color(1.0, 0.88, 0.70), 0.6, 420.0, 55.0)
	light(Vector3(0.0, 330.0, 200.0), Color(1.0, 0.90, 0.78), 0.6, 300.0)
	light(Vector3(0.0, 260.0, 340.0), Color(1.0, 0.82, 0.62), 0.9, 520.0)
	light(Vector3(-420.0, 260.0, 60.0), Color(0.95, 0.35, 0.75), 1.6, 380.0)
	light(Vector3(420.0, 260.0, 60.0), Color(0.30, 0.65, 1.0), 1.6, 380.0)

# --- textures ---------------------------------------------------------------------------------------------------

# the field's back panel: the game's violet, deeper at the foot, faint panel seams and a few dim guide arcs
func _field_tex(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var top: Color = Color(0.20, 0.16, 0.34)
	var bot: Color = Color(0.06, 0.05, 0.13)
	for y in n:
		var c: Color = top.lerp(bot, float(y) / float(n - 1))
		img.fill_rect(Rect2i(0, y, n, 1), c)
	for k in 5:
		var sy: int = int(float(n) * (0.15 + 0.18 * float(k)))
		img.fill_rect(Rect2i(0, sy, n, 1), img.get_pixel(0, sy).lightened(0.10))
	for k in 3:
		var cx: float = float(n) * (0.5 + 0.0 * float(k))
		var r: float = float(n) * (0.22 + 0.11 * float(k))
		for a in 400:
			var ang: float = PI + PI * float(a) / 400.0
			var px: int = int(cx + cos(ang) * r)
			var py: int = int(float(n) * 0.98 + sin(ang) * r)
			if px >= 0 and px < n and py >= 0 and py < n:
				img.set_pixel(px, py, img.get_pixel(px, py).lightened(0.18))
	# the cabinet maker's print: small gold stars scattered over the field, a cream pinstripe border inset from its edge
	for k2 in 26:
		var sx: int = int(h01(k2 * 3 + 40) * float(n - 12)) + 6
		var sy2: int = int(h01(k2 * 3 + 41) * float(n) * 0.75) + 4
		var rr: int = 2 + int(h01(k2 + 42) * 3.0)
		for d in range(-rr * 2, rr * 2 + 1):
			for pt in [Vector2i(sx + d, sy2), Vector2i(sx, sy2 + d)]:
				if pt.x >= 0 and pt.x < n and pt.y >= 0 and pt.y < n and absi(d) <= rr * 2 - absi(d) / 2:
					img.set_pixel(pt.x, pt.y, Color(0.92, 0.76, 0.40).lerp(img.get_pixel(pt.x, pt.y), float(absi(d)) / float(rr * 2 + 1)))
	for e in 2:
		var inset: int = 8 + e * 3
		img.fill_rect(Rect2i(inset, inset, n - inset * 2, 1), Color(0.82, 0.74, 0.58))
		img.fill_rect(Rect2i(inset, n - inset - 1, n - inset * 2, 1), Color(0.82, 0.74, 0.58))
		img.fill_rect(Rect2i(inset, inset, 1, n - inset * 2), Color(0.82, 0.74, 0.58))
		img.fill_rect(Rect2i(n - inset - 1, inset, 1, n - inset * 2), Color(0.82, 0.74, 0.58))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# the arcade floor: black and cream checks, worn
# an arcade carpet: deep navy, scattered with bright shapes -- rings, zigzags and stars in neon colors -- worn darker
func _carpet(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			img.set_pixel(x, y, Color(0.05, 0.05, 0.12).darkened(0.25 * h01(x * 7 + y * 13)))
	var cols: Array = [Color(0.95, 0.25, 0.65), Color(0.25, 0.80, 0.95), Color(0.98, 0.82, 0.25), Color(0.45, 0.95, 0.45)]
	for k in 70:
		var cx: float = h01(k * 3 + 1) * float(n)
		var cy: float = h01(k * 3 + 2) * float(n)
		var col: Color = cols[k % 4]
		var kind: int = k % 3
		for j in 60:
			var a: float = TAU * float(j) / 60.0
			var p: Vector2
			if kind == 0:
				p = Vector2(cx, cy) + Vector2(cos(a), sin(a)) * 5.0
			elif kind == 1:
				p = Vector2(cx + float(j) * 0.25 - 7.5, cy + (2.5 if (j / 6) % 2 == 0 else -2.5))
			else:
				var rr: float = 5.0 * (0.45 + 0.55 * pow(absf(cos(a * 2.5)), 4.0))
				p = Vector2(cx, cy) + Vector2(cos(a), sin(a)) * rr
			var px: int = posmod(int(p.x), n)
			var py: int = posmod(int(p.y), n)
			img.set_pixel(px, py, col.darkened(0.2 * h01(px + py * 3)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# the wall: a dark damask of plum on near-black, a faint gold in the pattern
func _wallpaper(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var u: float = float(x) / float(n) * TAU
			var v: float = float(y) / float(n) * TAU
			var pat: float = absf(sin(u * 2.0) * cos(v) + 0.5 * sin(v * 2.0 + u))
			var c: Color = Color(0.08, 0.04, 0.09).lerp(Color(0.22, 0.10, 0.20), smoothstep(0.55, 0.75, pat))
			c = c.lerp(Color(0.40, 0.30, 0.14), 0.25 * smoothstep(0.92, 1.0, pat))
			img.set_pixel(x, y, c.darkened(0.08 * h01(x * 11 + y * 5)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# a neon sign: the word in a glowing tube (a lit label with a halo), on a black backing board held off the wall on
# brackets, and the glow it throws on the wall
func _neon_sign(word: String, col: Color, at: Vector3, size_u: float) -> void:
	var w: float = float(word.length()) * size_u * 0.62 + 30.0
	box(Vector3(w, size_u * 1.25, 3.0), mat(Color(0.04, 0.04, 0.05), 0.4, 0.2), at + Vector3(0.0, 0.0, 10.0))
	for e in [-1.0, 1.0]:
		box(Vector3(3.0, 3.0, 10.0), mat(Color(0.5, 0.5, 0.55), 0.3, 0.8), at + Vector3(e * (w * 0.5 - 12.0), size_u * 0.5, 4.0))
	var lb: Label3D = label(word, size_u, col.lightened(0.45), at + Vector3(0.0, 0.0, 12.0))
	lb.outline_size = 18
	lb.outline_modulate = Color(col, 0.75)
	light(at + Vector3(0.0, 0.0, 60.0), col, 1.4, 320.0)

# THE CLAW MACHINE at the left: a cabinet, a glass box lit inside full of plush toys, the gantry and its claw, a
# marquee of chasing bulbs set into its top board, the prize chute
func _claw_machine(at: Vector3) -> void:
	var red: StandardMaterial3D = mat(Color(0.70, 0.08, 0.10), 0.3, 0.2)
	red.clearcoat_enabled = true
	red.clearcoat = 0.8
	var chrome: StandardMaterial3D = mat(Color(0.85, 0.86, 0.90), 0.12, 0.95)
	put(rbox_mesh(110.0, 90.0, 210.0, 10.0, 4.0), red, at)
	box(Vector3(200.0, 8.0, 170.0), chrome, at + Vector3(0.0, 212.0, 0.0))
	var glass: StandardMaterial3D = mat(Color(0.80, 0.90, 1.0, 0.16), 0.05, 0.2)
	box(Vector3(196.0, 230.0, 166.0), glass, at + Vector3(0.0, 330.0, 0.0))
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			box(Vector3(6.0, 230.0, 6.0), chrome, at + Vector3(cx * 98.0, 330.0, cz * 83.0))
	box(Vector3(200.0, 70.0, 170.0), red, at + Vector3(0.0, 480.0, 0.0))
	light(at + Vector3(0.0, 420.0, 0.0), Color(1.0, 0.90, 0.80), 1.8, 260.0)
	# the plush heap: soft round toys in candy colors
	var toy_cols: Array = [Color(0.95, 0.60, 0.70), Color(0.55, 0.80, 0.95), Color(0.98, 0.85, 0.40), Color(0.60, 0.90, 0.60), Color(0.85, 0.65, 0.95)]
	for tk in 26:
		var tp: Vector3 = at + Vector3(-80.0 + 160.0 * h01(tk * 3 + 40), 228.0 + 40.0 * h01(tk * 3 + 41), -60.0 + 120.0 * h01(tk * 3 + 42))
		var fur: StandardMaterial3D = mat(toy_cols[tk % 5], 0.95)
		sphere(16.0 + 4.0 * h01(tk), fur, tp)
		sphere(10.0, fur, tp + Vector3(0.0, 18.0, 4.0))
		for ear in [-1.0, 1.0]:
			sphere(4.0, fur, tp + Vector3(ear * 7.0, 27.0, 3.0))
	# the gantry and claw
	cyl(2.0, 2.0, 190.0, chrome, at + Vector3(0.0, 438.0, -20.0), Vector3(0.0, 0.0, 90.0), null, 8)
	cyl(1.0, 1.0, 50.0, chrome, at + Vector3(20.0, 412.0, -20.0), Vector3.ZERO, null, 6)
	cyl(8.0, 6.0, 10.0, chrome, at + Vector3(20.0, 384.0, -20.0), Vector3.ZERO, null, 12)
	for pr in 3:
		var pa: float = TAU * float(pr) / 3.0
		put(tube_mesh(PackedVector3Array([at + Vector3(20.0, 380.0, -20.0), at + Vector3(20.0 + cos(pa) * 12.0, 368.0, -20.0 + sin(pa) * 12.0), at + Vector3(20.0 + cos(pa) * 8.0, 356.0, -20.0 + sin(pa) * 8.0)]), 1.4, 6), chrome, Vector3.ZERO)
	# the prize chute's flap and the controls
	box(Vector3(60.0, 50.0, 4.0), mat(Color(0.05, 0.05, 0.06), 0.5), at + Vector3(40.0, 70.0, 91.0))
	box(Vector3(200.0, 14.0, 40.0), red, at + Vector3(0.0, 200.0, 100.0))
	cyl(3.0, 3.0, 26.0, chrome, at + Vector3(-30.0, 218.0, 104.0), Vector3.ZERO, null, 8)
	sphere(8.0, mat(Color(0.95, 0.15, 0.15), 0.2), at + Vector3(-30.0, 233.0, 104.0))
	sphere(9.0, mat(Color(0.98, 0.85, 0.20), 0.2), at + Vector3(40.0, 210.0, 106.0))
	for bl in 9:
		sphere(4.0, glow([Color(1.0, 0.85, 0.45), Color(1.0, 0.45, 0.55)][bl % 2]), at + Vector3(-80.0 + float(bl) * 20.0, 480.0, 86.0))
	label("PRIZES", 24.0, Color(1.0, 0.92, 0.70), at + Vector3(0.0, 500.0, 86.0))

# THE UPRIGHT at the right: a tall cabinet with its BACKGLASS lit -- painted rays and stars -- a playfield lid with
# its glass, chrome legs, a lit coin door
func _upright(at: Vector3) -> void:
	var blue: StandardMaterial3D = mat(Color(0.10, 0.18, 0.42), 0.3, 0.2)
	blue.clearcoat_enabled = true
	blue.clearcoat = 0.8
	var chrome: StandardMaterial3D = mat(Color(0.85, 0.86, 0.90), 0.12, 0.95)
	box(Vector3(200.0, 150.0, 300.0), blue, at + Vector3(0.0, 175.0, 40.0))
	for lx in [-1.0, 1.0]:
		for lz in [-1.0, 1.0]:
			cyl(5.0, 6.0, 100.0, chrome, at + Vector3(lx * 90.0, 50.0, 40.0 + lz * 135.0), Vector3.ZERO, null, 10)
	box(Vector3(190.0, 4.0, 290.0), mat(Color(0.80, 0.90, 1.0, 0.25), 0.05, 0.2), at + Vector3(0.0, 252.0, 40.0))
	box(Vector3(220.0, 230.0, 40.0), blue, at + Vector3(0.0, 370.0, -110.0))
	var bg_m: StandardMaterial3D = mat(Color.WHITE, 0.4, 0.0, _backglass(128))
	bg_m.emission_enabled = true
	bg_m.emission_texture = bg_m.albedo_texture
	bg_m.emission = Color(1.0, 1.0, 1.0)
	bg_m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY     # (ADD, the default, washed it white)
	bg_m.emission_energy_multiplier = 0.9
	box(Vector3(190.0, 190.0, 2.0), bg_m, at + Vector3(0.0, 375.0, -89.0))
	box(Vector3(200.0, 8.0, 8.0), chrome, at + Vector3(0.0, 476.0, -88.0))
	box(Vector3(200.0, 8.0, 8.0), chrome, at + Vector3(0.0, 274.0, -88.0))
	box(Vector3(70.0, 50.0, 2.0), glow(Color(1.0, 0.55, 0.25)), at + Vector3(0.0, 140.0, 191.0))
	light(at + Vector3(0.0, 380.0, 0.0), Color(0.40, 0.65, 1.0), 1.6, 320.0)

func _backglass(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var c0: Vector2 = Vector2(float(n) * 0.5, float(n) * 0.62)
	for y in n:
		for x in n:
			var d: Vector2 = Vector2(float(x), float(y)) - c0
			var ang: float = atan2(d.y, d.x)
			var ray: float = 0.5 + 0.5 * cos(ang * 12.0)
			var c: Color = Color(0.12, 0.05, 0.30).lerp(Color(0.95, 0.30, 0.60), ray * 0.6)
			c = c.lerp(Color(1.0, 0.85, 0.30), (1.0 - smoothstep(0.0, float(n) * 0.22, d.length())) * 0.9)
			img.set_pixel(x, y, c)
	for k in 30:
		var sx: int = int(h01(k * 2 + 7) * float(n - 4)) + 2
		var sy: int = int(h01(k * 2 + 8) * float(n - 4)) + 2
		for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			img.set_pixel(sx + o.x, sy + o.y, Color(1.0, 1.0, 0.85))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# streaks of light on the glass, otherwise clear
func _glass_tex(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0.0))
	for k in 3:
		var x0: float = float(n) * (0.10 + 0.30 * float(k))
		var w: float = float(n) * (0.10 - 0.025 * float(k))
		for y in n:
			for dx in int(w):
				var x: int = int(x0 + dx + float(n - y) * 0.45) % n
				var e: float = sin(PI * float(dx) / w)
				img.set_pixel(x, y, Color(1, 1, 1, 0.09 * e))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# --- the room and the case: baked --------------------------------------------------------------------------------

func _build_still() -> void:
	var case_wood: StandardMaterial3D = mat(Color.WHITE, 0.32, 0.0, tex_wood(256, Color(0.46, 0.22, 0.10), 7), Vector3(1, 3, 1))
	var dark_wood: StandardMaterial3D = mat(Color.WHITE, 0.4, 0.0, tex_wood(256, Color(0.22, 0.10, 0.05), 3), Vector3(1, 2, 1))
	var brass: StandardMaterial3D = mat(Color(0.90, 0.70, 0.34), 0.28, 0.6)
	var steel: StandardMaterial3D = mat(Color(0.30, 0.34, 0.44), 0.4, 0.5)
	# THE ARCADE ROUND IT (the user: the machine "occupies too little of the screen so the whole feeling is somewhat
	# empty"): a carpet of the arcade kind, a wall papered dark with a pattern and neon signs on brackets, and at each
	# side a NEIGHBOR lit up -- a claw machine full of plush toys at the left, an upright with its glowing backglass at
	# the right
	box(Vector3(1600.0, 4.0, 1000.0), mat(Color.WHITE, 0.95, 0.0, _carpet(256), Vector3(5, 3, 1)), Vector3(0.0, -2.0, 200.0))
	box(Vector3(1600.0, 900.0, 4.0), mat(Color.WHITE, 0.85, 0.0, _wallpaper(128), Vector3(12, 7, 1)), Vector3(0.0, 450.0, -260.0))
	box(Vector3(1600.0, 40.0, 6.0), dark_wood, Vector3(0.0, 20.0, -256.0))
	box(Vector3(1600.0, 12.0, 8.0), dark_wood, Vector3(0.0, 300.0, -255.0))
	# (the signs only where the band is wide enough to show them clear of the title: on a phone they ran into it;
	# their glow stays)
	if not mobile:
		_neon_sign("ARCADE", Color(1.0, 0.35, 0.70), Vector3(-250.0, 665.0, -250.0), 40.0)
		_neon_sign("PLAY", Color(0.35, 0.85, 1.0), Vector3(270.0, 650.0, -250.0), 40.0)
	else:
		light(Vector3(-250.0, 660.0, -190.0), Color(1.0, 0.35, 0.70), 1.4, 320.0)
		light(Vector3(270.0, 650.0, -190.0), Color(0.35, 0.85, 1.0), 1.4, 320.0)
	_claw_machine(Vector3(-370.0, 0.0, -40.0))
	_upright(Vector3(385.0, 0.0, -60.0))
	# THE CASE: sides, a back, the top, a front panel under the glass, the marquee over it
	for side in [-1.0, 1.0]:
		box(Vector3(26.0, 440.0, 150.0), case_wood, Vector3(side * 181.0, 290.0, 0.0))
		# turned legs
		cyl(9.0, 13.0, 70.0, dark_wood, Vector3(side * 170.0, 35.0, 55.0))
		cyl(9.0, 13.0, 70.0, dark_wood, Vector3(side * 170.0, 35.0, -55.0))
		sphere(7.0, brass, Vector3(side * 170.0, 4.0, 55.0))
	box(Vector3(388.0, 440.0, 10.0), dark_wood, Vector3(0.0, 290.0, -72.0))
	box(Vector3(396.0, 14.0, 160.0), case_wood, Vector3(0.0, 77.0, 0.0))
	# (no marquee -- the user: remove it "so the game screen itself can be moved up and enlarged"): a molded top
	# just over the glass, a brass lamp hood inside it lighting the field
	box(Vector3(396.0, 26.0, 160.0), case_wood, Vector3(0.0, 503.0, 0.0))
	box(Vector3(404.0, 8.0, 166.0), dark_wood, Vector3(0.0, 520.0, 0.0))
	# under the glass: the front panel with its brass coin plate and slot, a brass rail along the glass's foot
	box(Vector3(340.0, 66.0, 12.0), case_wood, Vector3(0.0, 117.0, 70.0))
	box(Vector3(70.0, 46.0, 2.0), brass, Vector3(0.0, 114.0, 77.0))
	box(Vector3(6.0, 22.0, 2.0), mat(Color(0.05, 0.04, 0.03), 0.6), Vector3(0.0, 118.0, 78.5))
	label("5¢", 12.0, Color(0.30, 0.18, 0.06), Vector3(0.0, 98.0, 78.5))
	box(Vector3(340.0, 8.0, 16.0), brass, Vector3(0.0, 152.0, 70.0))
	# the glass's frame: brass at the top and the sides
	box(Vector3(340.0, 8.0, 14.0), brass, Vector3(0.0, 482.0, 70.0))
	for side in [-1.0, 1.0]:
		box(Vector3(8.0, 330.0, 14.0), brass, Vector3(side * 166.0, 317.0, 70.0))
	# THE FIELD inside: the violet back panel, steel side walls, a floor with the tools' slot
	box(Vector3(330.0, 330.0, 2.0), mat(Color.WHITE, 0.6, 0.0, _field_tex(256)), Vector3(0.0, 317.0, -50.0))
	for side in [-1.0, 1.0]:
		box(Vector3(4.0, 330.0, 110.0), steel, Vector3(side * 164.0, 317.0, 5.0))
		# A BUMPER in each lower corner, as the game's (steel wedges): a chamfered steel wedge filling the corner, a red
		# rubber ring stretched round two chrome posts along its sloping face, a little amber lamp (it was a flat red box
		# turned 45 degrees -- "what are those flat red things?", the user)
		_bumper(Vector3(side * 162.0, 157.0, -10.0), side)
	box(Vector3(330.0, 6.0, 110.0), steel, Vector3(0.0, 154.0, 5.0))
	box(Vector3(250.0, 6.5, 8.0), mat(Color(0.02, 0.02, 0.03), 0.8), Vector3(0.0, 154.5, 10.0))
	# THE SHELVES the cups stand on: a wooden board with a rounded front lip, on a brass gusset bracket screwed to the
	# side wall (they were plain brass slabs)
	var shelf_wood: StandardMaterial3D = mat(Color.WHITE, 0.5, 0.0, tex_wood(64, Color(0.50, 0.30, 0.16), 6))
	for c in CUPS:
		var cvec: Vector3 = c
		var wall_x: float = signf(cvec.x) * 162.0
		var sx2: float = (cvec.x + wall_x) * 0.5
		var sw: float = absf(wall_x - cvec.x) + 30.0
		box(Vector3(sw, 5.0, 40.0), shelf_wood, Vector3(sx2, cvec.y - 19.5, cvec.z))
		cyl(2.6, 2.6, sw, shelf_wood, Vector3(sx2, cvec.y - 19.5, cvec.z + 20.0), Vector3(0.0, 0.0, 90.0), null, 12)
		for gz in [-12.0, 12.0]:
			var g: MeshInstance3D = box(Vector3(3.0, 26.0, 3.0), brass, Vector3(wall_x - signf(cvec.x) * 12.0, cvec.y - 31.0, cvec.z + gz), Vector3(0.0, 0.0, signf(cvec.x) * 38.0))
			g.scale = Vector3(1.0, 1.0, 1.0)
			box(Vector3(2.0, 12.0, 6.0), brass, Vector3(wall_x - signf(cvec.x) * 1.5, cvec.y - 28.0, cvec.z + gz))
			sphere(1.4, mat(Color(0.30, 0.28, 0.24), 0.4, 0.8), Vector3(wall_x - signf(cvec.x) * 3.0, cvec.y - 24.0, cvec.z + gz))
	# brass rivets down the steel side walls' front edges
	for side2 in [-1.0, 1.0]:
		for rv in 12:
			sphere(2.0, brass, Vector3(side2 * 161.5, 168.0 + float(rv) * 27.0, 58.0))
	# a soft shadow of the case on the floor
	box(Vector3(440.0, 0.5, 200.0), mat(Color(0, 0, 0, 0.45), 1.0), Vector3(0.0, 0.6, 10.0))

# --- live: the funnel, the cups, the tools, the marble, the glass ------------------------------------------------

func _cup_mesh(r_top: float, r_bot: float, h: float) -> CylinderMesh:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.cap_top = false
	cm.radial_segments = 40
	return cm

func _bumper(corner: Vector3, side: float) -> void:
	var leg: float = 58.0
	var depth: float = 56.0
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# the triangle: the corner, up the wall, out along the floor -- with its sloping face chamfered at both edges
	var a: Vector3 = Vector3(0.0, 0.0, 0.0)
	var b: Vector3 = Vector3(0.0, leg, 0.0)
	var c: Vector3 = Vector3(-side * leg, 0.0, 0.0)
	var ch: float = 5.0
	var slope_n: Vector3 = Vector3(-side, 1.0, 0.0).normalized()
	# the front and back faces: the triangle, its sloping edge drawn in by the chamfer
	for fz in [depth * 0.5, -depth * 0.5]:
		var tri: Array = [a, b - slope_n * ch, c - slope_n * ch]
		for v in ([0, 1, 2] if fz > 0.0 else [0, 2, 1]):
			st.set_normal(Vector3(0.0, 0.0, signf(fz)))
			st.add_vertex((tri[v] as Vector3) + Vector3(0.0, 0.0, fz))
	# the sloping face, its two chamfers toward the front and back faces
	var zf: float = depth * 0.5
	var zb: float = -depth * 0.5
	var quads: Array = [
		[b + Vector3(0, 0, zb + ch), c + Vector3(0, 0, zb + ch), c + Vector3(0, 0, zf - ch), b + Vector3(0, 0, zf - ch), slope_n],
		[b + Vector3(0, 0, zf - ch), c + Vector3(0, 0, zf - ch), c + Vector3(0, 0, zf) - slope_n * ch, b + Vector3(0, 0, zf) - slope_n * ch, (slope_n + Vector3(0, 0, 1)).normalized()],
		[b + Vector3(0, 0, zb) - slope_n * ch, c + Vector3(0, 0, zb) - slope_n * ch, c + Vector3(0, 0, zb + ch), b + Vector3(0, 0, zb + ch), (slope_n + Vector3(0, 0, -1)).normalized()]]
	for q in quads:
		for vi in [0, 1, 2, 0, 2, 3]:
			st.set_normal(q[4])
			st.add_vertex(q[vi])
	var bright: StandardMaterial3D = mat(Color(0.78, 0.80, 0.86), 0.28, 0.55)
	put(st.commit(), bright, corner)
	# the rubber ring round its two posts, standing off the slope
	var p0: Vector3 = corner + b * 0.80 + c * 0.08 + slope_n * 6.0
	var p1: Vector3 = corner + c * 0.80 + b * 0.08 + slope_n * 6.0
	var chrome: StandardMaterial3D = mat(Color(0.86, 0.88, 0.92), 0.12, 0.95)
	var rubber: StandardMaterial3D = mat(Color(0.62, 0.08, 0.08), 0.55, 0.0)
	for pp in [p0, p1]:
		cyl(4.0, 4.0, depth * 0.7, chrome, pp, Vector3(90.0, 0.0, 0.0), null, 14)
		cyl(5.5, 5.5, 3.0, chrome, pp + Vector3(0.0, 0.0, depth * 0.35), Vector3(90.0, 0.0, 0.0), null, 14)
	for zr in [-6.0, 6.0]:
		var band: PackedVector3Array = PackedVector3Array()
		for k in 25:
			var ang: float = TAU * float(k) / 24.0
			var along: Vector3 = (p1 - p0)
			var mid: Vector3 = (p0 + p1) * 0.5
			var half_len: float = along.length() * 0.5
			var dir: Vector3 = along.normalized()
			var off: float = cos(ang) * (half_len + 6.0)
			var out: float = sin(ang) * 6.5
			band.append(mid + dir * clampf(off, -half_len, half_len) + slope_n * out + Vector3(0.0, 0.0, zr) + dir * (off - clampf(off, -half_len, half_len)))
		put(tube_mesh(band, 2.4, 8), rubber, Vector3.ZERO)
	# the lamp: an amber jewel set in the wedge's front face
	sphere(5.0, glow(Color(1.0, 0.62, 0.22)), corner + (a + b + c) / 3.0 + Vector3(0.0, 0.0, depth * 0.5 + 1.0), null, true)

func _build_live() -> void:
	var brass: StandardMaterial3D = mat(Color(0.90, 0.70, 0.34), 0.28, 0.6)
	# the funnel (a marble starts inside it), open at both ends
	# (its spout wider than a marble and open at its foot: a marble starts INSIDE it, hidden by its walls, and drops out
	# of its bottom -- narrower than the marble, the marble showed through the spout in front of it, the user)
	var fm: CylinderMesh = _cup_mesh(38.0, 18.0, 34.0)
	fm.cap_bottom = false
	put(fm, brass, Vector3(0.0, FUNNEL_Y + 8.0, -6.0))
	var spout: MeshInstance3D = cyl(18.5, 18.5, 18.0, brass, Vector3(0.0, FUNNEL_Y - 18.0, -6.0))
	spout.mesh.set("cap_top", false)
	spout.mesh.set("cap_bottom", false)
	var lip: TorusMesh = TorusMesh.new()
	lip.inner_radius = 17.5
	lip.outer_radius = 20.5
	put(lip, brass, Vector3(0.0, FUNNEL_Y - 27.0, -6.0))
	box(Vector3(6.0, 30.0, 6.0), brass, Vector3(0.0, 481.0 - 8.0, -40.0))
	# the cups: glazed in their color, open at the top, a brass rim that lights when a marble drops in
	for k in CUPS.size():
		var c: Vector3 = CUPS[k]
		var col: Color = COLORS[k]
		put(_cup_mesh(23.0, 18.0, 34.0), mat(col, 0.25, 0.1), c)
		var rim_m: StandardMaterial3D = mat(col.lightened(0.2), 0.2, 0.4)
		var rim: MeshInstance3D = cyl(24.5, 24.5, 3.0, rim_m, c + Vector3(0.0, 17.0, 0.0))
		(rim.mesh as CylinderMesh).cap_top = false
		(rim.mesh as CylinderMesh).cap_bottom = false
		_cup_glow.append(rim_m)
	# THE TOOLS, one per color: a disc facing out, a short neck to a loop, a brass rod down into the slot
	for k in COLORS.size():
		var tool: Node3D = Node3D.new()
		root.add_child(tool)
		# the disc turned a little, so it reads as a DISC with an edge (face on, it was one more marble)
		var face: Node3D = Node3D.new()
		face.rotation_degrees = Vector3(0.0, 38.0 * (1.0 if k >= 2 else -1.0), 0.0)
		tool.add_child(face)
		var col2: Color = COLORS[k]
		cyl(DISC_R, DISC_R, 9.0, mat(col2.darkened(0.15), 0.3, 0.15), Vector3.ZERO, Vector3(90.0, 0.0, 0.0), face, 40)
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = DISC_R - 4.0
		ring.outer_radius = DISC_R + 1.0
		# the brass rim on BOTH faces of the disc (the back had none)
		for rz in [4.6, -4.6]:
			put(ring, mat(Color(0.90, 0.70, 0.34), 0.28, 0.6), Vector3(0.0, 0.0, rz), Vector3(90.0, 0.0, 0.0), face)
		cyl(DISC_R * 0.35, DISC_R * 0.35, 9.6, mat(col2.lightened(0.3), 0.25, 0.15), Vector3.ZERO, Vector3(90.0, 0.0, 0.0), face, 32)
		cyl(2.4, 2.4, 22.0, brass, Vector3(0.0, -DISC_R - 9.0, 0.0), Vector3.ZERO, tool)
		var loop: TorusMesh = TorusMesh.new()
		loop.inner_radius = 8.0
		loop.outer_radius = 11.5
		put(loop, brass, Vector3(0.0, -DISC_R - 30.0, 0.0), Vector3(90.0, 0.0, 0.0), tool)
		cyl(2.0, 2.0, 22.0, brass, Vector3(0.0, -DISC_R - 41.0 - 11.0, 0.0), Vector3.ZERO, tool)    # into the slot box, never below the case
		_tools.append(tool)
	# the marble: glass in its color, a bright highlight
	_ball = Node3D.new()
	root.add_child(_ball)
	_ball_mat = mat(COLORS[0], 0.08, 0.15)
	_ball_mat.clearcoat_enabled = true
	_ball_mat.clearcoat = 1.0
	_ball_mat.clearcoat_roughness = 0.05
	sphere(BALL_R, _ball_mat, Vector3.ZERO, _ball)
	sphere(BALL_R * 0.28, glow(Color(1, 1, 1, 0.85)), Vector3(-BALL_R * 0.38, BALL_R * 0.42, BALL_R * 0.72), _ball)
	# the glass, over everything in the case: clear, with soft streaks of light
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_texture = _glass_tex(64)
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gq: QuadMesh = QuadMesh.new()
	gq.size = Vector2(WIN.size.x, WIN.size.y)
	put(gq, gm, Vector3(0.0, WIN.position.y + WIN.size.y * 0.5 + 2.0, 66.0))
	# the bottom panel and the rail are live too, so the tools' rods vanish into the slot behind them
	var case_wood: StandardMaterial3D = mat(Color.WHITE, 0.32, 0.0, tex_wood(64, Color(0.46, 0.22, 0.10), 7), Vector3(1, 3, 1))
	box(Vector3(330.0, 50.0, 112.0), mat(Color(0.30, 0.34, 0.44), 0.4, 0.5), Vector3(0.0, 126.0, 5.0))
	box(Vector3(340.0, 66.0, 12.0), case_wood, Vector3(0.0, 117.0, 70.0))
	box(Vector3(70.0, 46.0, 2.0), brass, Vector3(0.0, 114.0, 77.0))
	box(Vector3(6.0, 22.0, 2.0), mat(Color(0.05, 0.04, 0.03), 0.6), Vector3(0.0, 118.0, 78.5))
	label("5¢", 12.0, Color(0.30, 0.18, 0.06), Vector3(0.0, 98.0, 78.5))
	box(Vector3(340.0, 8.0, 16.0), brass, Vector3(0.0, 152.0, 70.0))
	box(Vector3(330.0, 6.0, 110.0), mat(Color(0.30, 0.34, 0.44), 0.4, 0.5), Vector3(0.0, 154.0, 5.0))
	box(Vector3(250.0, 6.5, 8.0), mat(Color(0.02, 0.02, 0.03), 0.8), Vector3(0.0, 154.5, 10.0))

# --- the motion ---------------------------------------------------------------------------------------------------

func _ease(a: float, b: float, u: float) -> float:
	return smoothstep(a, b, u)

func _animate(_delta: float) -> void:
	if _ball == null:
		return
	var h: int = int(floor(t / PERIOD))
	var u: float = t - float(h) * PERIOD
	var c: int = ORDER[posmod(h, ORDER.size())]
	var cup: Vector3 = CUPS[c]
	var side: float = signf(cup.x)
	var meet: Vector3 = Vector3(side * 34.0, MEET_Y, -6.0)
	var g: float = 2.0 * (FUNNEL_Y - 12.0 - MEET_Y) / (0.9 * 0.9)
	_ball_mat.albedo_color = COLORS[c]
	# THE MARBLE: out of the funnel and falling, drifting a little toward its side; lofted by its tool up and over
	# into its cup; dropping in
	var pos: Vector3
	if u < 0.9:
		# from inside the spout (its walls hide it) straight down out of its foot, then drifting toward its side
		pos = Vector3(lerpf(0.0, meet.x, _ease(0.35, 0.9, u)), FUNNEL_Y - 12.0 - 0.5 * g * u * u, -6.0)
	elif u < 1.8:
		var s: float = (u - 0.9) / 0.9
		var top: Vector3 = cup + Vector3(-side * 6.0, 34.0, 0.0)
		pos = meet.lerp(top, s) + Vector3(0.0, 70.0 * 4.0 * s * (1.0 - s), 0.0)
	else:
		var s2: float = clampf((u - 1.8) / 0.22, 0.0, 1.0)
		pos = (cup + Vector3(-side * 6.0, 34.0, 0.0)).lerp(cup + Vector3(0.0, -2.0, 0.0), s2 * s2)
	_ball.position = pos
	_ball.visible = u < 2.3
	# THE TOOLS: the marble's own rises to meet it, follows through, and sinks back to its place
	for k in _tools.size():
		var tool: Node3D = _tools[k]
		var park: Vector3 = Vector3(float(PARK_X[k]), PARK_Y, -6.0)
		var p: Vector3 = park
		if k == c:
			var contact: Vector3 = meet - Vector3(0.0, BALL_R + DISC_R, 0.0)
			var up: float = _ease(0.15, 0.88, u)
			var push: float = _ease(0.86, 1.06, u) * (1.0 - _ease(1.10, 1.30, u))
			var back: float = _ease(1.2, 2.3, u)
			p = park.lerp(contact, up).lerp(park, back) + Vector3(side * 12.0, 26.0, 0.0) * push
		tool.position = p
	# a cup's rim lights as the marble drops in, and fades
	for k in _cup_glow.size():
		var lit: float = 0.0
		if k == c and u > 1.9:
			lit = 1.0 - _ease(2.0, 2.7, u)
		var base: Color = (COLORS[k] as Color).lightened(0.2)
		var m: StandardMaterial3D = _cup_glow[k]
		m.emission_enabled = true
		m.emission = base
		m.emission_energy_multiplier = 2.5 * lit
		m.albedo_color = base.lerp(Color(1, 1, 0.9), lit * 0.4)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Nudge", "Nudge every ball into its own basket", Color(1.0, 0.86, 0.62), Color(0.14, 0.06, 0.20),
		Color(0.85, 0.55, 1.0, 0.25))

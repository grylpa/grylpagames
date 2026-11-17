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
	return Vector3(0.0, 330.0, 700.0) if mobile else Vector3(0.0, 340.0, 1020.0)

func _aim() -> Vector3:
	return Vector3(0.0, 290.0, 0.0) if mobile else Vector3(0.0, 330.0, 0.0)

func _fov() -> float:
	return 47.0

func _frame_frac() -> float:
	return 0.50

func _scene_top() -> float:
	return 0.0

func _environment(env: Environment) -> void:
	env.background_color = Color(0.02, 0.015, 0.04)
	env.ambient_light_color = Color(0.50, 0.42, 0.62)
	env.ambient_light_energy = 0.32

func _build_lights() -> void:
	# the marquee's lamp shining down into the field, warm; a soft light on the case's front; the neighbors' glow
	spot(Vector3(0.0, 478.0, 30.0), Vector3(0.0, 200.0, -20.0), Color(1.0, 0.88, 0.70), 6.0, 420.0, 55.0)
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
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# the arcade floor: black and cream checks, worn
func _checks(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var cell: int = n / 8
	for y in n:
		for x in n:
			var dark: bool = ((x / cell) + (y / cell)) % 2 == 0
			var c: Color = Color(0.10, 0.09, 0.10) if dark else Color(0.62, 0.58, 0.50)
			c = c.darkened(0.12 * h01(x * 7 + y * 13))
			img.set_pixel(x, y, c)
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
	# the floor and the wall behind
	box(Vector3(1400.0, 4.0, 900.0), mat(Color.WHITE, 0.35, 0.0, _checks(256), Vector3(6, 4, 1)), Vector3(0.0, -2.0, 200.0))
	box(Vector3(1400.0, 900.0, 4.0), mat(Color(0.10, 0.07, 0.12), 0.9), Vector3(0.0, 450.0, -260.0))
	box(Vector3(1400.0, 40.0, 6.0), dark_wood, Vector3(0.0, 20.0, -256.0))
	# the neighbors: a cabinet's dark shoulder at each side, its screen's glow on the wall
	for side in [-1.0, 1.0]:
		box(Vector3(220.0, 520.0, 160.0), mat(Color(0.08, 0.05, 0.08), 0.5), Vector3(side * 470.0, 260.0, -40.0))
		box(Vector3(160.0, 120.0, 2.0), glow(Color(0.26, 0.10, 0.22) if side < 0.0 else Color(0.08, 0.17, 0.30)), Vector3(side * 450.0, 360.0, 41.0))
	# THE CASE: sides, a back, the top, a front panel under the glass, the marquee over it
	for side in [-1.0, 1.0]:
		box(Vector3(26.0, 440.0, 150.0), case_wood, Vector3(side * 181.0, 290.0, 0.0))
		# turned legs
		cyl(9.0, 13.0, 70.0, dark_wood, Vector3(side * 170.0, 35.0, 55.0))
		cyl(9.0, 13.0, 70.0, dark_wood, Vector3(side * 170.0, 35.0, -55.0))
		sphere(7.0, brass, Vector3(side * 170.0, 4.0, 55.0))
	box(Vector3(388.0, 440.0, 10.0), dark_wood, Vector3(0.0, 290.0, -72.0))
	box(Vector3(396.0, 14.0, 160.0), case_wood, Vector3(0.0, 77.0, 0.0))
	# (no marquee -- the user: remove it "so the game screen itself can be moved up and enlarged"): a moulded top
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
		# a bumper in each lower corner, the game's warm orange
		box(Vector3(46.0, 46.0, 30.0), mat(Color(0.90, 0.36, 0.30), 0.4, 0.1), Vector3(side * 148.0, 175.0, -20.0), Vector3(0.0, 0.0, 45.0))
	box(Vector3(330.0, 6.0, 110.0), steel, Vector3(0.0, 154.0, 5.0))
	box(Vector3(250.0, 6.5, 8.0), mat(Color(0.02, 0.02, 0.03), 0.8), Vector3(0.0, 154.5, 10.0))
	# the cups' brackets on the side walls
	for c in CUPS:
		var cv: Vector3 = c
		box(Vector3(28.0, 6.0, 20.0), brass, Vector3(cv.x + signf(cv.x) * 24.0, cv.y - 20.0, cv.z))
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

func _build_live() -> void:
	var brass: StandardMaterial3D = mat(Color(0.90, 0.70, 0.34), 0.28, 0.6)
	# the funnel (a marble starts inside it), open at both ends
	var fm: CylinderMesh = _cup_mesh(34.0, 13.0, 34.0)
	fm.cap_bottom = false
	put(fm, brass, Vector3(0.0, FUNNEL_Y + 8.0, -6.0))
	cyl(13.5, 13.5, 14.0, brass, Vector3(0.0, FUNNEL_Y - 16.0, -6.0)).mesh.set("cap_top", false)
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
		put(ring, mat(Color(0.90, 0.70, 0.34), 0.28, 0.6), Vector3(0.0, 0.0, 4.6), Vector3(90.0, 0.0, 0.0), face)
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
	var g: float = 2.0 * (FUNNEL_Y - 10.0 - MEET_Y) / (0.9 * 0.9)
	_ball_mat.albedo_color = COLORS[c]
	# THE MARBLE: out of the funnel and falling, drifting a little toward its side; lofted by its tool up and over
	# into its cup; dropping in
	var pos: Vector3
	if u < 0.9:
		pos = Vector3(lerpf(0.0, meet.x, _ease(0.2, 0.9, u)), FUNNEL_Y - 10.0 - 0.5 * g * u * u, -6.0)
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

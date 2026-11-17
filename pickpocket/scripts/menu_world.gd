extends "res://scripts/menu_poster3d.gd"

# PICKPOCKET'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A CLOSE-UP OF
# THE HUSTLER'S TABLE at dusk -- REAL 3-D now (it was a drawn picture), in the game's own colors (shell_table.gd):
# a small folding table under a red cloth with a gold fringe and green baize on top, the lantern on its pole beside
# it, and the hustler behind -- plum vest, white shirt, the red neckerchief, a flat cap, a mustache -- his hands on the
# copper cups, SHUFFLING them: two at a time swap places along arcs, his arms bending at the elbow to follow; after
# six swaps he lifts the cup with the red ball under it, sets it down, and goes on. Behind, the dusk street (cobbles,
# shopfronts with lit windows, a lamp post), and two people passing: someone, and the thief a step behind with a hand
# drifting to their pocket. The street, the table and the hustler's body are baked, one picture per platform
# (`menu_table.webp`, `menu_table_d.webp`); the cups, the ball, his arms and hands, and the passers-by are live. Made
# up, never the board (the game's wide street is not shown: the first version looked "too much like something that
# is playable").

const COPPER: Color = Color(0.78, 0.45, 0.24)
const BALL_COLOR: Color = Color(0.82, 0.12, 0.12)
const BAIZE: Color = Color(0.10, 0.30, 0.20)
const CLOTH: Color = Color(0.40, 0.08, 0.11)
const FRINGE: Color = Color(0.86, 0.68, 0.30)
const SKIN: Color = Color(0.95, 0.78, 0.65)
const SHIRT: Color = Color(0.86, 0.83, 0.76)
const VEST: Color = Color(0.20, 0.13, 0.16)
const CAP: Color = Color(0.36, 0.31, 0.26)
const KERCHIEF: Color = Color(0.72, 0.13, 0.14)
const LAMP_C: Color = Color(1.0, 0.78, 0.45)
const TOP_Y: float = 95.0
const CUP_Z: float = 0.0
const SHOULDERS: Array = [Vector3(-56.0, 188.0, -100.0), Vector3(56.0, 188.0, -100.0)]
const BEAT: float = 1.25
const SWAPS: int = 6
const REVEAL: float = 2.2

var _cups: Array = []                 # Node3D per cup
var _ball: Node3D = null
var _hands: Array = []                # Node3D per hand
var _walkers: Array = []              # Node3D: the mark, the thief
var _thief_arm: MeshInstance3D = null

func _baked_path() -> String:
	return "res://pickpocket/art/menu_table.webp" if mobile else "res://pickpocket/art/menu_table_d.webp"

func _eye() -> Vector3:
	return Vector3(0.0, 215.0, 400.0) if mobile else Vector3(0.0, 235.0, 560.0)

func _aim() -> Vector3:
	return Vector3(0.0, 140.0, -50.0) if mobile else Vector3(0.0, 160.0, -60.0)

func _fov() -> float:
	return 58.0

func _environment(env: Environment) -> void:
	env.background_color = Color(0.10, 0.08, 0.14)
	env.ambient_light_color = Color(0.55, 0.50, 0.65)
	env.ambient_light_energy = 0.35

func _build_lights() -> void:
	# the lantern's warm light on the table and the hustler; the dusk sky's cool light from behind
	light(Vector3(150.0, 200.0, 20.0), LAMP_C, 2.6, 360.0, true)
	var dusk: DirectionalLight3D = DirectionalLight3D.new()
	dusk.light_color = Color(0.55, 0.55, 0.85)
	dusk.light_energy = 0.45
	root.add_child(dusk)
	dusk.rotation_degrees = Vector3(-25.0, 160.0, 0.0)
	light(Vector3(-260.0, 220.0, -420.0), Color(1.0, 0.80, 0.50), 1.4, 300.0)

func _sky(n: int) -> ImageTexture:
	var img: Image = Image.create(4, n, false, Image.FORMAT_RGB8)
	for y in n:
		var v: float = float(y) / float(n - 1)
		img.fill_rect(Rect2i(0, y, 4, 1), Color(0.14, 0.12, 0.30).lerp(Color(0.85, 0.48, 0.38), pow(v, 1.5)))
	return ImageTexture.create_from_image(img)

# --- baked: the street, the table, the hustler, the lantern ---------------------------------------------------------

func _build_still() -> void:
	var stone: StandardMaterial3D = mat(Color.WHITE, 0.6, 0.0, tex_speckle(128, Color(0.30, 0.27, 0.28), 0.10, 3, 8, Color(0.16, 0.14, 0.15)), Vector3(18, 12, 1))
	var wood: StandardMaterial3D = mat(Color.WHITE, 0.6, 0.0, tex_wood(128, Color(0.36, 0.21, 0.11), 4))
	var iron: StandardMaterial3D = mat(Color(0.12, 0.12, 0.13), 0.4, 0.6)
	# THE STREET: cobbles, the shopfronts across it, a lamp post, the dusk sky over the roofs
	box(Vector3(3000.0, 4.0, 2000.0), stone, Vector3(0.0, -2.0, -400.0))
	var sky: QuadMesh = QuadMesh.new()
	sky.size = Vector2(4000.0, 1600.0)
	var sky_m: StandardMaterial3D = mat(Color.WHITE, 1.0, 0.0, _sky(64))
	sky_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	put(sky, sky_m, Vector3(0.0, 400.0, -1400.0))
	for k in 7:
		var sx: float = -900.0 + float(k) * 290.0
		var h: float = 300.0 + 120.0 * h01(k + 3)
		var col: Color = [Color(0.38, 0.26, 0.24), Color(0.30, 0.30, 0.36), Color(0.42, 0.36, 0.28), Color(0.28, 0.24, 0.30)][k % 4]
		box(Vector3(280.0, h, 30.0), mat(col, 0.85), Vector3(sx, h * 0.5, -620.0))
		box(Vector3(290.0, 12.0, 40.0), mat(col.darkened(0.3), 0.8), Vector3(sx, h + 6.0, -615.0))
		# a shop window below, lit, and windows above, some lit
		box(Vector3(180.0, 100.0, 2.0), glow(Color(1.0, 0.76, 0.42) if k % 2 == 0 else Color(0.85, 0.62, 0.38)), Vector3(sx, 70.0, -604.0))
		box(Vector3(200.0, 12.0, 30.0), mat([Color(0.20, 0.35, 0.25), Color(0.50, 0.15, 0.15)][k % 2], 0.6), Vector3(sx, 130.0, -592.0), Vector3(-20.0, 0.0, 0.0))
		for w in 2:
			var lit: bool = h01(k * 5 + w) > 0.5
			box(Vector3(46.0, 60.0, 2.0), glow(Color(1.0, 0.82, 0.50)) if lit else mat(Color(0.10, 0.10, 0.14), 0.2), Vector3(sx - 60.0 + float(w) * 120.0, 220.0, -604.0))
	cyl(5.0, 7.0, 260.0, iron, Vector3(-260.0, 130.0, -440.0))
	sphere(10.0, glow(Color(1.0, 0.86, 0.55)), Vector3(-260.0, 266.0, -440.0))
	# THE TABLE: legs, a red cloth draped to the ground with a gold fringe, green baize on top
	for lx in [-120.0, 120.0]:
		for lz in [-55.0, 55.0]:
			box(Vector3(8.0, TOP_Y, 8.0), wood, Vector3(lx, TOP_Y * 0.5, lz))
	box(Vector3(280.0, 6.0, 150.0), wood, Vector3(0.0, TOP_Y - 3.0, 0.0))
	box(Vector3(250.0, 1.0, 126.0), mat(BAIZE, 0.9), Vector3(0.0, TOP_Y + 0.5, 0.0))
	var cloth: StandardMaterial3D = mat(CLOTH, 0.85)
	box(Vector3(284.0, 60.0, 2.0), cloth, Vector3(0.0, TOP_Y - 30.0, 76.0))
	for sx2 in [-1.0, 1.0]:
		box(Vector3(2.0, 60.0, 152.0), cloth, Vector3(sx2 * 142.0, TOP_Y - 30.0, 0.0))
	for f in 40:
		cyl(1.6, 1.0, 14.0, mat(FRINGE, 0.5, 0.3), Vector3(-138.0 + float(f) * 7.0, TOP_Y - 66.0, 77.0))
	box(Vector3(286.0, 3.0, 3.0), mat(FRINGE, 0.5, 0.3), Vector3(0.0, TOP_Y - 59.0, 77.5))
	# THE HUSTLER's body behind it (his head and arms are live): a lathed torso -- narrow at the waist, broad at the
	# chest, the shoulders sloping to the neck -- in a striped shirt, the wool vest over it with a real V at the front,
	# its brass buttons, welt pockets and a watch chain; the red neckerchief, the neck
	var shirt: StandardMaterial3D = mat(Color.WHITE, 0.75, 0.0, _shirting(128), Vector3(3, 3, 1))
	var vest: StandardMaterial3D = mat(Color.WHITE, 0.85, 0.0, _wool(128, VEST), Vector3(3, 3, 1))
	var brass: StandardMaterial3D = mat(Color(0.92, 0.74, 0.34), 0.3, 0.8)
	var body_c: Vector3 = Vector3(0.0, 0.0, -104.0)
	put(_lathe(TORSO, 0.0, 1.0), shirt, body_c)
	put(_lathe(VEST_PROFILE, 1.0, 1.0), vest, body_c)
	# the shoulders: round caps in the shirt where the sleeves meet the body (without them the arms began at an edge)
	for sh in SHOULDERS:
		var cap: MeshInstance3D = sphere(15.0, shirt, Vector3((sh as Vector3).x * 0.96, (sh as Vector3).y - 2.0, body_c.z))
		cap.scale = Vector3(1.0, 0.85, 1.1)
	for b in 4:
		var by: float = 112.0 + float(b) * 15.0
		var gap: float = _v_gap(by)
		var zf: float = _front_z(by) + 1.5
		sphere(2.6, brass, body_c + Vector3(gap * 0.9 * _rx(by), by, zf))
	for px in [-1.0, 1.0]:
		box(Vector3(18.0, 2.0, 2.0), mat(VEST.darkened(0.4), 0.8), body_c + Vector3(px * 26.0, 125.0, _front_z(125.0) - 2.0), Vector3(0.0, px * -22.0, 0.0))
	var chain: PackedVector3Array = PackedVector3Array()
	for k in 9:
		var cu: float = float(k) / 8.0
		chain.append(body_c + Vector3(lerpf(8.0, 26.0, cu), 118.0 - 6.0 * sin(cu * PI), _front_z(118.0) + 2.0))
	put(tube_mesh(chain, 0.9, 6), brass, Vector3.ZERO)
	cyl(12.0, 13.5, 26.0, mat(Color.WHITE, 0.6, 0.0, _skin_tex(64)), body_c + Vector3(0.0, 204.0, 2.0))
	var kerch: TorusMesh = TorusMesh.new()
	kerch.inner_radius = 11.0
	kerch.outer_radius = 18.0
	put(kerch, mat(Color.WHITE, 0.8, 0.0, _wool(64, KERCHIEF)), body_c + Vector3(0.0, 197.0, 2.0))
	for kx in [-1.0, 1.0]:
		var tail: MeshInstance3D = sphere(7.0, mat(KERCHIEF, 0.8), body_c + Vector3(kx * 5.0, 188.0, 30.0))
		tail.scale = Vector3(0.8, 1.5, 0.5)
		tail.rotation_degrees = Vector3(0.0, 0.0, kx * 18.0)
	# THE LANTERN on its pole at the table's right, lit
	cyl(3.0, 3.0, 230.0, iron, Vector3(160.0, 115.0, -40.0))
	box(Vector3(40.0, 3.0, 3.0), iron, Vector3(145.0, 228.0, -40.0))
	cyl(10.0, 12.0, 26.0, mat(Color(1.0, 0.86, 0.55, 0.55), 0.1), Vector3(130.0, 200.0, -40.0))
	sphere(6.0, glow(LAMP_C), Vector3(130.0, 200.0, -40.0))
	cyl(0.0, 14.0, 10.0, iron, Vector3(130.0, 218.0, -40.0))
	cyl(13.0, 13.0, 3.0, iron, Vector3(130.0, 186.0, -40.0))

# --- live: the cups, the ball, the arms and hands, the passers-by ---------------------------------------------------

func _cup_mesh() -> Node3D:
	var cup: Node3D = Node3D.new()
	root.add_child(cup)
	var cm: StandardMaterial3D = mat(COPPER, 0.32, 0.75)
	cyl(13.0, 21.0, 36.0, cm, Vector3(0.0, 18.0, 0.0), Vector3.ZERO, cup, 32)
	var rim: TorusMesh = TorusMesh.new()
	rim.inner_radius = 19.5
	rim.outer_radius = 23.0
	put(rim, cm, Vector3(0.0, 1.5, 0.0), Vector3.ZERO, cup)
	cyl(9.0, 13.0, 4.0, cm, Vector3(0.0, 37.0, 0.0), Vector3.ZERO, cup, 24)
	return cup

func _limb(r: float, m: StandardMaterial3D) -> MeshInstance3D:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 1.0
	cm.radial_segments = 14
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = m
	root.add_child(mi)
	return mi

# set a unit cylinder to run from a to b
func _span(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d: Vector3 = b - a
	var l: float = maxf(0.01, d.length())
	var y: Vector3 = d / l
	var x: Vector3 = y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z: Vector3 = x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x, y * l, z), (a + b) * 0.5)

func _build_live() -> void:
	for k in 3:
		_cups.append(_cup_mesh())
	_ball = Node3D.new()
	root.add_child(_ball)
	sphere(7.5, mat(BALL_COLOR, 0.35), Vector3(0.0, 7.5, 0.0), _ball)
	_build_arms()
	_build_head()
	# the passers-by in the street behind: the mark, and the thief a step behind
	for w in 2:
		var p: Node3D = Node3D.new()
		root.add_child(p)
		var coat: StandardMaterial3D = mat([Color(0.30, 0.32, 0.45), Color(0.16, 0.14, 0.16)][w], 0.8)
		var body: CapsuleMesh = CapsuleMesh.new()
		body.radius = 18.0
		body.height = 120.0
		put(body, coat, Vector3(0.0, 70.0, 0.0), Vector3.ZERO, p)
		sphere(13.0, mat(SKIN.darkened(0.35), 0.6), Vector3(0.0, 142.0, 0.0), p)
		cyl(16.0, 16.0, 4.0, coat, Vector3(0.0, 152.0, 0.0), Vector3.ZERO, p)
		cyl(10.0, 11.0, 12.0, coat, Vector3(0.0, 159.0, 0.0), Vector3.ZERO, p)
		_walkers.append(p)
	_thief_arm = _limb(5.0, mat(Color(0.16, 0.14, 0.16), 0.8))

# which slot each cup is in at the start of beat n, and where the ball's cup is: the swaps replayed from the start
# FOUR PLACES, THREE CUPS (2026-11-17, the user: the arms crossed, "make it physically correct"): each beat ONE hand
# slides ONE cup to the empty place, along an arc in front of the others; the hand is the one on that side of the
# table, so neither ever crosses to the other side. `MOVES`: which cup moves, beat by beat.
const PLACES: Array = [-96.0, -32.0, 32.0, 96.0]
const MOVES: Array = [1, 0, 2, 1, 0, 2]

# the place of each cup at the start of beat n (cups start in places 0, 1, 2; 3 is empty)
func _places_at(n: int) -> Array:
	var at: Array = [0, 1, 2]
	for i in n:
		var used: Array = [false, false, false, false]
		for c in 3:
			used[at[c]] = true
		at[MOVES[i % MOVES.size()]] = used.find(false)
	return at

func _empty(at: Array) -> int:
	for pl in 4:
		if not at.has(pl):
			return pl
	return 3

func _animate(_delta: float) -> void:
	if _cups.is_empty():
		return
	# the time line: SWAPS moves, then the reveal, then again
	var cycle: float = float(SWAPS) * BEAT + REVEAL
	var cyc: int = int(floor(t / cycle))
	var u: float = t - float(cyc) * cycle
	var beat: int = int(floor(u / BEAT))
	var bu: float = fmod(u, BEAT) / BEAT
	var shuffling: bool = beat < SWAPS
	var n_done: int = cyc * SWAPS + mini(beat, SWAPS)
	var at: Array = _places_at(n_done)
	var mover: int = MOVES[n_done % MOVES.size()] if shuffling else -1
	var move: float = smoothstep(0.10, 0.80, bu) if shuffling else 0.0
	var rest: Array = [Vector3(-98.0, TOP_Y + 13.0, -24.0), Vector3(98.0, TOP_Y + 13.0, -24.0)]
	var hand_at: Array = rest.duplicate()
	for c in 3:
		var x0: float = PLACES[at[c]]
		var p: Vector3 = Vector3(x0, TOP_Y, CUP_Z)
		var tilt: float = 0.0
		if c == mover:
			var x1: float = PLACES[_empty(at)]
			# slid along an arc out in front of the others, the hand on that side of the table over it; the hand
			# reaches it before the move and leaves it after
			p = Vector3(lerpf(x0, x1, move), TOP_Y, CUP_Z + 24.0 * sin(move * PI))
			var k: int = 0 if (x0 + x1) < 0.0 else 1
			var grip: Vector3 = p + Vector3(0.0, 40.0, 0.0)
			var on: float = smoothstep(0.0, 0.12, bu) * (1.0 - smoothstep(0.84, 1.0, bu))
			hand_at[k] = (rest[k] as Vector3).lerp(grip, on)
		if not shuffling and c == 0:
			# THE REVEAL: the ball's cup lifted and tipped back by the hand on its side, set down again
			var ru: float = (u - float(SWAPS) * BEAT) / REVEAL
			var lift: float = smoothstep(0.08, 0.32, ru) * (1.0 - smoothstep(0.68, 0.92, ru))
			p += Vector3(0.0, 46.0 * lift, -10.0 * lift)
			tilt = -0.5 * lift
			var k2: int = 0 if x0 < 0.0 else 1
			var reach: float = smoothstep(0.0, 0.10, ru) * (1.0 - smoothstep(0.92, 1.0, ru))
			hand_at[k2] = (rest[k2] as Vector3).lerp(p + Vector3(0.0, 40.0, 0.0), reach)
		(_cups[c] as Node3D).position = p
		(_cups[c] as Node3D).rotation = Vector3(tilt, 0.0, 0.0)
	# the ball rides under its cup (cup 0), on the baize, seen only when that cup is lifted
	var c0: Vector3 = (_cups[0] as Node3D).position
	_ball.position = Vector3(c0.x, TOP_Y, c0.z if shuffling else CUP_Z)
	# THE ARMS (fixed lengths, a two-bone solve): shoulder to elbow to wrist, each elbow out, down and a little back;
	# the hands on the cups, turned along the forearm
	for k in 2:
		var hand: Node3D = _hands[k]
		var target: Vector3 = hand_at[k]
		hand.position = target if _hand_init < 2 else hand.position.lerp(target, 0.45)
		_pose_arm(k)
	_hand_init = 2
	# the head follows the cups: toward the one moving in front, back to the middle between shuffles
	var look_x: float = 0.0
	for c2 in 3:
		var cp: Vector3 = (_cups[c2] as Node3D).position
		if cp.z > CUP_Z + 3.0 or cp.y > TOP_Y + 3.0:
			look_x = cp.x
	_head.rotation.y = lerp_angle(_head.rotation.y, clampf(-look_x / 300.0, -0.35, 0.35), 0.08)
	_head.rotation.x = 0.22
	# THE PASSERS-BY: across the street behind, the thief a step behind the mark, his hand drifting to their pocket
	var span: float = 1300.0
	var x: float = fmod(t * 55.0, span) - span * 0.5
	var bob: float = absf(sin(t * 5.0)) * 4.0
	(_walkers[0] as Node3D).position = Vector3(x, bob, -380.0)
	(_walkers[1] as Node3D).position = Vector3(x - 70.0, absf(sin(t * 5.0 + 1.3)) * 4.0, -370.0)
	var reach_t: float = 0.5 + 0.5 * sin(t * 0.9)
	var th: Vector3 = (_walkers[1] as Node3D).position + Vector3(14.0, 92.0, 6.0)
	var pocket: Vector3 = (_walkers[0] as Node3D).position + Vector3(-14.0, 70.0, 8.0)
	_span(_thief_arm, th, th.lerp(pocket, 0.55 + 0.45 * reach_t))

# --- the hustler, made properly ----------------------------------------------------------------------------------

# the torso's sections: [height, half width, half depth] from the waist up to the base of the neck
const TORSO: Array = [[78.0, 40.0, 26.0], [100.0, 42.0, 27.0], [130.0, 48.0, 30.0], [160.0, 52.0, 31.0], [178.0, 54.0, 30.0],
	[190.0, 46.0, 27.0], [198.0, 30.0, 22.0], [204.0, 16.0, 15.0]]
const VEST_PROFILE: Array = [[78.0, 41.5, 27.5], [100.0, 43.5, 28.5], [130.0, 49.5, 31.5], [160.0, 53.5, 32.5], [178.0, 54.5, 31.0],
	[186.0, 48.0, 28.0]]
const UPPER: float = 64.0
const FORE: float = 62.0

var _hand_init: int = 0
var _head: Node3D = null
var _upper: Array = []
var _cuff: Array = []
var _fore: Array = []
var _fingers: Array = []              # per hand: [Node3D joint, ...]

func _rx(y: float) -> float:
	for i in TORSO.size() - 1:
		if y <= float(TORSO[i + 1][0]):
			var u: float = (y - float(TORSO[i][0])) / (float(TORSO[i + 1][0]) - float(TORSO[i][0]))
			return lerpf(float(TORSO[i][1]), float(TORSO[i + 1][1]), u)
	return 16.0

func _front_z(y: float) -> float:
	for i in VEST_PROFILE.size() - 1:
		if y <= float(VEST_PROFILE[i + 1][0]):
			var u: float = (y - float(VEST_PROFILE[i][0])) / (float(VEST_PROFILE[i + 1][0]) - float(VEST_PROFILE[i][0]))
			return lerpf(float(VEST_PROFILE[i][2]), float(VEST_PROFILE[i + 1][2]), u)
	return 30.0

# the vest's opening at the front, as a share of the half width: closed at the waist, a V widening to the shoulders
func _v_gap(y: float) -> float:
	return lerpf(0.10, 0.62, smoothstep(105.0, 186.0, y))

# A LATHED BODY: elliptical sections stacked, smooth normals; `open` > 0 leaves the vest's V open at the front
func _lathe(prof: Array, open: float, _k: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg: int = 40
	var rings: Array = []
	for sec in prof:
		var y: float = sec[0]
		var ring: PackedVector3Array = PackedVector3Array()
		var gap: float = asin(clampf(_v_gap(y), 0.0, 0.99)) * open
		for j in seg + 1:
			# from just right of the front round the back to just left of it (or all the way round)
			var a: float = PI * 0.5 + gap + (TAU - 2.0 * gap) * float(j) / float(seg)
			ring.append(Vector3(cos(a) * float(sec[1]), y, sin(a) * float(sec[2])))
		rings.append(ring)
	for r in rings.size() - 1:
		var a0: PackedVector3Array = rings[r]
		var a1: PackedVector3Array = rings[r + 1]
		for j in seg:
			for v in [a0[j], a1[j], a1[j + 1], a0[j], a1[j + 1], a0[j + 1]]:
				st.set_uv(Vector2(float(j) / float(seg) * 4.0, (v as Vector3).y / 40.0))
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()

func _wool(n: int, base: Color) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var v: float = 0.5 * h01(x * 7 + y * 13) + 0.5 * h01((x + y) / 2 * 5)
			img.set_pixel(x, y, base.darkened(0.18).lerp(base.lightened(0.12), v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _shirting(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var stripe: bool = (x / 6) % 4 == 0
			var c: Color = Color(0.88, 0.86, 0.80) if not stripe else Color(0.62, 0.66, 0.78)
			img.set_pixel(x, y, c.darkened(0.06 * h01(x * 31 + y * 17)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _skin_tex(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			img.set_pixel(x, y, SKIN.darkened(0.05 * h01(x * 13 + y * 7)).lerp(Color(0.92, 0.66, 0.58), 0.12 * h01(x / 8 + y / 8 * 9)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _tapered(r0: float, r1: float, m: StandardMaterial3D) -> MeshInstance3D:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r1
	cm.bottom_radius = r0
	cm.height = 1.0
	cm.radial_segments = 20
	cm.rings = 3
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = m
	root.add_child(mi)
	return mi

func _build_arms() -> void:
	var shirt: StandardMaterial3D = mat(Color.WHITE, 0.75, 0.0, _shirting(64), Vector3(1, 2, 1))
	var skin: StandardMaterial3D = mat(Color.WHITE, 0.55, 0.0, _skin_tex(64))
	for k in 2:
		# the upper arm in its sleeve (full at the shoulder), the sleeve ROLLED at the elbow (a thick fold), the bare
		# forearm tapering to the wrist
		_upper.append(_tapered(12.5, 10.0, shirt))
		var cuff: Node3D = Node3D.new()
		root.add_child(cuff)
		var roll: TorusMesh = TorusMesh.new()
		roll.inner_radius = 8.0
		roll.outer_radius = 13.5
		put(roll, shirt, Vector3.ZERO, Vector3(90.0, 0.0, 0.0), cuff)
		_cuff.append(cuff)
		_fore.append(_tapered(9.0, 6.5, skin))
		# THE HAND: a palm, a thumb, four fingers of two joints each curling down over the cup's top
		var hand: Node3D = Node3D.new()
		root.add_child(hand)
		var palm: MeshInstance3D = sphere(10.5, skin, Vector3(0.0, 0.0, 0.0), hand)
		palm.scale = Vector3(1.05, 0.55, 1.15)
		var joints: Array = []
		for fg in 4:
			var j1: Node3D = Node3D.new()
			hand.add_child(j1)
			j1.position = Vector3(-7.5 + float(fg) * 5.0, -1.0, 10.0)
			var ph1: MeshInstance3D = cyl(2.6, 2.8, 9.0, skin, Vector3(0.0, 0.0, 4.5), Vector3(90.0, 0.0, 0.0), j1, 10)
			ph1.name = "p1"
			var j2: Node3D = Node3D.new()
			j1.add_child(j2)
			j2.position = Vector3(0.0, 0.0, 9.0)
			cyl(2.3, 2.6, 7.0, skin, Vector3(0.0, 0.0, 3.5), Vector3(90.0, 0.0, 0.0), j2, 10)
			sphere(2.3, skin, Vector3(0.0, 0.0, 7.0), j2)
			joints.append([j1, j2])
		var side: float = 1.0 if k == 0 else -1.0
		var th: Node3D = Node3D.new()
		hand.add_child(th)
		th.position = Vector3(side * 9.0, -1.0, 2.0)
		th.rotation = Vector3(0.0, side * 0.9, side * -0.4)
		cyl(3.0, 3.4, 12.0, skin, Vector3(0.0, 0.0, 6.0), Vector3(90.0, 0.0, 0.0), th, 10)
		_fingers.append(joints)
		_hands.append(hand)

# the two-bone solve: the elbow where both bones keep their lengths, bent toward the pole (out, down, a little back)
func _pose_arm(k: int) -> void:
	var sh: Vector3 = SHOULDERS[k]
	var hand: Node3D = _hands[k]
	var wrist: Vector3 = hand.position + Vector3(0.0, 4.0, -12.0)
	var to: Vector3 = wrist - sh
	var d: float = clampf(to.length(), 10.0, UPPER + FORE - 0.5)
	var dir: Vector3 = to.normalized()
	wrist = sh + dir * d
	# out of reach, the hand stops at the wrist (it never comes off the arm)
	hand.position = wrist - Vector3(0.0, 4.0, -12.0)
	var a: float = (UPPER * UPPER - FORE * FORE + d * d) / (2.0 * d)
	var h: float = sqrt(maxf(0.0, UPPER * UPPER - a * a))
	var side: float = -1.0 if k == 0 else 1.0
	var pole: Vector3 = Vector3(side * 1.0, -0.8, -0.35)
	var perp: Vector3 = (pole - dir * pole.dot(dir)).normalized()
	var elbow: Vector3 = sh + dir * a + perp * h
	_span(_upper[k], sh, elbow)
	_span(_fore[k], elbow, wrist)
	var cuff: Node3D = _cuff[k]
	var fdir: Vector3 = (wrist - elbow).normalized()
	cuff.position = elbow + fdir * 6.0
	cuff.basis = _basis_along(fdir)
	# the hand turned along the forearm, flat over the cup, the fingers curled down round its top
	var yaw: float = atan2(fdir.x, fdir.z)
	hand.rotation = Vector3(0.18, yaw, 0.0)
	for jt in _fingers[k]:
		(jt[0] as Node3D).rotation = Vector3(0.55, 0.0, 0.0)
		(jt[1] as Node3D).rotation = Vector3(0.75, 0.0, 0.0)

func _basis_along(y: Vector3) -> Basis:
	var x: Vector3 = y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	return Basis(x, y, x.cross(y).normalized())

# THE HEAD, live (it turns with the cups): a skull a little longer than wide, ears, a jaw, brows, eyes with whites,
# irises and lids, a shaped nose, a full mustache, the tweed cap with its crown, brim and button
func _build_head() -> void:
	var skin: StandardMaterial3D = mat(Color.WHITE, 0.55, 0.0, _skin_tex(64))
	var hair: StandardMaterial3D = mat(Color(0.22, 0.14, 0.10), 0.85)
	var tweed: StandardMaterial3D = mat(Color.WHITE, 0.95, 0.0, _wool(64, CAP), Vector3(2, 2, 1))
	_head = Node3D.new()
	root.add_child(_head)
	_head.position = Vector3(0.0, 212.0, -100.0)
	var skull: MeshInstance3D = sphere(27.0, skin, Vector3(0.0, 24.0, 0.0), _head)
	skull.scale = Vector3(0.92, 1.08, 1.0)
	var jaw: MeshInstance3D = sphere(20.0, skin, Vector3(0.0, 8.0, 6.0), _head)
	jaw.scale = Vector3(1.05, 0.8, 0.95)
	for ex in [-1.0, 1.0]:
		var ear: MeshInstance3D = sphere(6.5, skin, Vector3(ex * 25.0, 22.0, -2.0), _head)
		ear.scale = Vector3(0.45, 1.0, 0.75)
		# the eye: white, iris, a lid over the top; the brow above
		var eye_c: Vector3 = Vector3(ex * 10.0, 28.0, 22.5)
		var white: MeshInstance3D = sphere(4.2, mat(Color(0.96, 0.95, 0.92), 0.2), eye_c, _head)
		white.scale = Vector3(1.2, 0.85, 0.6)
		sphere(2.3, mat(Color(0.20, 0.12, 0.08), 0.1), eye_c + Vector3(0.0, -0.3, 2.2), _head)
		var lid: MeshInstance3D = sphere(4.6, skin, eye_c + Vector3(0.0, 1.8, 0.2), _head, true)
		lid.scale = Vector3(1.25, 0.7, 0.7)
		var brow: MeshInstance3D = sphere(5.0, hair, eye_c + Vector3(ex * 0.5, 6.5, 0.4), _head)
		brow.scale = Vector3(1.8, 0.45, 0.6)
		brow.rotation_degrees = Vector3(0.0, 0.0, ex * -10.0)
		# the mustache: a full sweep each side
		var mus: MeshInstance3D = sphere(8.0, hair, Vector3(ex * 7.5, 14.5, 25.0), _head)
		mus.scale = Vector3(1.35, 0.5, 0.65)
		mus.rotation_degrees = Vector3(0.0, ex * -15.0, ex * -18.0)
		# the side hair under the cap
		var side_h: MeshInstance3D = sphere(9.0, hair, Vector3(ex * 22.0, 30.0, -8.0), _head)
		side_h.scale = Vector3(0.5, 0.9, 1.2)
	# the nose: a bridge and a rounded tip
	var bridge: MeshInstance3D = sphere(4.5, skin, Vector3(0.0, 24.0, 25.0), _head)
	bridge.scale = Vector3(0.8, 1.6, 0.9)
	sphere(5.2, skin, Vector3(0.0, 19.5, 27.5), _head)
	# the cap: a soft crown, a band, a peaked brim, a button on top
	var crown: MeshInstance3D = sphere(29.5, tweed, Vector3(0.0, 40.0, -2.0), _head, true)
	crown.scale = Vector3(1.05, 0.55, 1.12)
	cyl(28.0, 28.5, 8.0, tweed, Vector3(0.0, 40.0, -1.0), Vector3.ZERO, _head, 32)
	var brim: MeshInstance3D = cyl(20.0, 22.0, 3.0, mat(CAP.darkened(0.25), 0.9), Vector3(0.0, 38.0, 24.0), Vector3(-10.0, 0.0, 0.0), _head, 28)
	brim.scale = Vector3(1.1, 1.0, 0.65)
	sphere(3.2, tweed, Vector3(0.0, 56.0, -2.0), _head)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Pickpocket", "Follow the ball and catch the pickpocket", Color(1.0, 0.86, 0.55), Color(0.10, 0.06, 0.12),
		Color(1.0, 0.65, 0.35, 0.22))

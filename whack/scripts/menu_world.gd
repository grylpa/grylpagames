extends "res://scripts/menu_poster3d.gd"

# WHACK'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A FAIRGROUND
# SHOOTING GALLERY AT NIGHT. A booth with red-and-white striped sides and posts, a striped awning with its scalloped
# valance, a back wall of deep blue painted with gold stars, prizes hanging at the sides, a varnished counter with a
# brass rail and a lit strip, WHACK lit on the header in a frame of bulbs that chase; a boardwalk of planks in front.
# Across the back run three brass rails, and on them TARGETS slide by -- tin bullseyes, red and white with a gold
# heart -- and among them DECOYS (grey, a black cross, a red rim: don't hit those). Every so often a bullseye is
# HIT: a burst of sparks, it flips back on its hinge and rises again a moment later; the decoys are never hit.
# The booth is the baked picture (guidem's way: `whack/art/menu_booth.webp`); the targets, the sparks, the bulbs
# and the booth's sides (which the targets slide behind) are live. One clock (`t`); nothing pops.
# Made up, never the board.

const ROWS: Array = [[150.0, -20.0, 42.0], [215.0, -26.0, -36.0], [280.0, -32.0, 30.0]]   # y, z, speed (units/s)
const SPACING: float = 112.0
const SPAN: float = 560.0             # the rails' loop: the targets wrap behind the booth's sides
const HIT_EVERY: float = 1.15
const RED: Color = Color(0.80, 0.08, 0.08)
const GOLD: Color = Color(0.95, 0.75, 0.25)

var _targets: Array = []              # [Node3D hinge, row, index, decoy]
var _sparks: Array = []               # [MeshInstance3D, material]
var _bulbs: Array = []

func _baked_path() -> String:
	return "res://whack/art/menu_booth.webp"

func _eye() -> Vector3:
	return Vector3(0.0, 250.0, 780.0)

func _aim() -> Vector3:
	return Vector3(0.0, 230.0, 0.0)

func _fov() -> float:
	return 46.0

func _frame_frac() -> float:
	return 0.48

func _environment(env: Environment) -> void:
	env.background_color = Color(0.015, 0.015, 0.04)
	env.ambient_light_color = Color(0.45, 0.42, 0.60)
	env.ambient_light_energy = 0.30

func _build_lights() -> void:
	# the booth's lamps under the header, warm on the targets; the bulbs' glow on the awning; a cool night fill
	spot(Vector3(-90.0, 360.0, 140.0), Vector3(-40.0, 200.0, -30.0), Color(1.0, 0.86, 0.62), 9.0, 420.0, 40.0, true)
	spot(Vector3(90.0, 360.0, 140.0), Vector3(40.0, 200.0, -30.0), Color(1.0, 0.86, 0.62), 9.0, 420.0, 40.0)
	light(Vector3(0.0, 400.0, 200.0), Color(1.0, 0.80, 0.50), 0.8, 300.0)
	light(Vector3(0.0, 60.0, 260.0), Color(1.0, 0.70, 0.45), 0.6, 260.0)
	light(Vector3(-300.0, 300.0, 300.0), Color(0.55, 0.65, 1.0), 0.5, 500.0)

# --- the booth: baked --------------------------------------------------------------------------------------

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

func _build_still() -> void:
	var wood: StandardMaterial3D = mat(Color.WHITE, 0.45, 0.0, tex_wood(256, Color(0.52, 0.28, 0.14), 3), Vector3(3, 1, 1))
	var dark_wood: StandardMaterial3D = mat(Color.WHITE, 0.35, 0.0, tex_wood(256, Color(0.28, 0.14, 0.07), 5), Vector3(3, 1, 1))
	var brass: StandardMaterial3D = mat(Color(0.88, 0.68, 0.32), 0.3, 0.4)
	var stripe: StandardMaterial3D = mat(Color.WHITE, 0.6, 0.0, _stripes(256, RED, Color(0.96, 0.93, 0.86), 8))
	# the boardwalk in front, planks
	box(Vector3(900.0, 6.0, 500.0), mat(Color.WHITE, 0.7, 0.0, tex_wood(256, Color(0.40, 0.30, 0.22), 9), Vector3(4, 8, 1)), Vector3(0.0, -3.0, 300.0))
	# the back wall of stars
	box(Vector3(460.0, 340.0, 4.0), mat(Color.WHITE, 0.8, 0.0, _stars(256), Vector3(2, 1.5, 1)), Vector3(0.0, 200.0, -42.0))
	# the header board over the opening and its lettering, framed
	box(Vector3(480.0, 70.0, 12.0), mat(Color(0.12, 0.06, 0.20), 0.5), Vector3(0.0, 410.0, 112.0))
	box(Vector3(484.0, 4.0, 14.0), brass, Vector3(0.0, 446.0, 112.0))
	box(Vector3(484.0, 4.0, 14.0), brass, Vector3(0.0, 374.0, 112.0))
	# the header says what the booth offers (the game's name is the poster's own title, over it)
	label("WIN A PRIZE", 34.0, Color(1.0, 0.86, 0.35), Vector3(0.0, 422.0, 119.0))
	# the awning: a striped slope out over the counter, its valance of scallops
	var awning: MeshInstance3D = box(Vector3(500.0, 3.0, 90.0), stripe, Vector3(0.0, 366.0, 160.0), Vector3(-18.0, 0.0, 0.0))
	awning.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
	for k in 20:
		var sx: float = -240.0 + float(k) * 25.0 + 12.5
		var sc: MeshInstance3D = cyl(12.5, 12.5, 2.0, mat(RED if k % 2 == 0 else Color(0.96, 0.93, 0.86), 0.6), Vector3(sx, 342.0, 204.0), Vector3(90.0, 0.0, 0.0), null, 24)
		sc.scale = Vector3(1.0, 1.0, 0.8)
	# the counter: a varnished front with brass trim and a lit strip, a dark top, a brass rail along it
	box(Vector3(480.0, 92.0, 40.0), wood, Vector3(0.0, 46.0, 100.0))
	box(Vector3(492.0, 6.0, 52.0), dark_wood, Vector3(0.0, 95.0, 100.0))
	box(Vector3(480.0, 3.0, 2.0), glow(Color(1.0, 0.82, 0.45)), Vector3(0.0, 80.0, 121.0))
	cyl(1.6, 1.6, 486.0, brass, Vector3(0.0, 104.0, 118.0), Vector3(0.0, 0.0, 90.0))
	for k in 7:
		box(Vector3(46.0, 50.0, 1.0), dark_wood, Vector3(-195.0 + float(k) * 65.0, 42.0, 120.6))
	# the posts at the corners, striped
	for px in [-245.0, 245.0]:
		cyl(7.0, 7.0, 380.0, stripe, Vector3(px, 190.0, 118.0))
		sphere(9.0, brass, Vector3(px, 384.0, 118.0))
	# the rails across the back, brass, on brackets
	for row in ROWS:
		cyl(2.2, 2.2, 440.0, brass, Vector3(0.0, float(row[0]) - 4.0, float(row[1]) - 6.0), Vector3(0.0, 0.0, 90.0))
		for bx in [-200.0, 0.0, 200.0]:
			box(Vector3(4.0, 8.0, 12.0), brass, Vector3(bx, float(row[0]) - 4.0, float(row[1]) - 12.0))
	# prizes hanging at the sides: plush bears on cords
	for k in 6:
		var side: float = -1.0 if k < 3 else 1.0
		var bx2: float = side * (178.0 - float(k % 3) * 8.0)
		var by: float = 330.0 - float(k % 3) * 48.0
		var bz: float = 40.0 - float(k % 3) * 22.0
		var fur: StandardMaterial3D = mat([Color(0.85, 0.55, 0.30), Color(0.45, 0.65, 0.90), Color(0.92, 0.55, 0.70)][k % 3], 0.95)
		box(Vector3(0.6, 360.0 - by - 14.0, 0.6), mat(Color(0.9, 0.9, 0.85), 0.8), Vector3(bx2, (360.0 + by + 14.0) * 0.5, bz))
		sphere(11.0, fur, Vector3(bx2, by - 8.0, bz))
		sphere(8.0, fur, Vector3(bx2, by + 9.0, bz))
		for e in [-1.0, 1.0]:
			sphere(3.2, fur, Vector3(bx2 + e * 5.5, by + 15.5, bz))
		sphere(2.6, mat(Color(0.95, 0.88, 0.80), 0.9), Vector3(bx2, by + 7.0, bz + 7.0))
	# (the striped sides are live: the targets slide behind them)

# --- live: the sides, the targets, the sparks, the bulbs ------------------------------------------------------------

func _bullseye(decoy: bool) -> ImageTexture:
	var n: int = 128
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in n:
		for x in n:
			var r: float = Vector2(float(x) - 63.5, float(y) - 63.5).length() / 63.5
			if r > 1.0:
				continue
			var c: Color
			if decoy:
				c = Color(0.80, 0.08, 0.08) if r > 0.86 else Color(0.62, 0.64, 0.66)
				var u: float = (float(x) - 63.5) / 63.5
				var v: float = (float(y) - 63.5) / 63.5
				if r < 0.70 and (absf(u - v) < 0.14 or absf(u + v) < 0.14):
					c = Color(0.05, 0.05, 0.05)
			else:
				var ring: int = int(r * 5.0)
				c = GOLD if r < 0.18 else ([RED, Color(0.96, 0.94, 0.90)][ring % 2])
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _build_live() -> void:
	# the striped sides (the targets wrap out of sight behind them), in front of everything on the rails
	var stripe: StandardMaterial3D = mat(Color.WHITE, 0.6, 0.0, _stripes(256, RED, Color(0.96, 0.93, 0.86), 8))
	for side in [-1.0, 1.0]:
		box(Vector3(30.0, 380.0, 170.0), stripe, Vector3(side * 238.0, 190.0, 30.0))
	var face_mat: StandardMaterial3D = mat(Color.WHITE, 0.35, 0.3, _bullseye(false))
	face_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var decoy_mat: StandardMaterial3D = mat(Color.WHITE, 0.4, 0.3, _bullseye(true))
	decoy_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var tin: StandardMaterial3D = mat(Color(0.55, 0.56, 0.60), 0.35, 0.5)
	var disc_q: QuadMesh = QuadMesh.new()
	disc_q.size = Vector2(46.0, 46.0)
	for r in ROWS.size():
		var count: int = int(SPAN / SPACING)
		for i in count:
			var decoy: bool = h01(r * 31 + i * 7) < 0.25
			var hinge: Node3D = Node3D.new()
			root.add_child(hinge)
			# its carriage on the rail, its stem, the disc (a tin back and the painted face)
			box(Vector3(14.0, 8.0, 10.0), tin, Vector3(0.0, -2.0, -4.0), Vector3.ZERO, hinge)
			box(Vector3(3.0, 14.0, 2.0), tin, Vector3(0.0, 7.0, 0.0), Vector3.ZERO, hinge)
			cyl(23.5, 23.5, 1.6, tin, Vector3(0.0, 37.0, -1.0), Vector3(90.0, 0.0, 0.0), hinge, 40)
			put(disc_q, decoy_mat if decoy else face_mat, Vector3(0.0, 37.0, 0.2), Vector3.ZERO, hinge)
			_targets.append([hinge, r, i, decoy])
	for k in 14:
		var sm: StandardMaterial3D = glow(Color(1.0, 0.85, 0.40))
		var mi: MeshInstance3D = sphere(1.6, sm, Vector3.ZERO)
		mi.visible = false
		_sparks.append([mi, sm])
	# the bulbs round the header
	var n_b: int = 0
	for side_y in [448.0, 372.0]:
		for k in 24:
			var bm: StandardMaterial3D = glow(Color(1.0, 0.86, 0.55))
			sphere(3.0, bm, Vector3(-236.0 + float(k) * 20.5, side_y, 120.0))
			_bulbs.append(bm)
			n_b += 1
	for side_x in [-242.0, 242.0]:
		for k in 3:
			var bm2: StandardMaterial3D = glow(Color(1.0, 0.86, 0.55))
			sphere(3.0, bm2, Vector3(side_x, 391.0 + float(k) * 19.0, 120.0))
			_bulbs.append(bm2)

# which target is hit at hit number h (a bullseye near the middle), and when
func _hit_target(h: int) -> int:
	var tries: int = 0
	var k: int = int(h01(h * 13 + 5) * float(_targets.size()))
	while tries < _targets.size():
		var tg: Array = _targets[(k + tries) % _targets.size()]
		if not bool(tg[3]):
			return (k + tries) % _targets.size()
		tries += 1
	return 0

func _animate(_delta: float) -> void:
	# targets along their rails; flipped back on their hinge while "hit"
	var down: Array = []
	down.resize(_targets.size())
	down.fill(0.0)
	var hn: int = int(floor(t / HIT_EVERY))
	var hit_pos: Array = []
	for h in range(hn - 2, hn + 1):
		var th: float = float(h) * HIT_EVERY
		var dt: float = t - th
		if dt < 0.0:
			continue
		var idx: int = _hit_target(h)
		# down fast, a moment lying back, up again slowly
		var f: float = smoothstep(0.0, 0.14, dt) * (1.0 - smoothstep(1.0, 1.5, dt))
		down[idx] = maxf(float(down[idx]), f)
		if dt < 0.6:
			hit_pos.append([idx, dt, h])
	for k in _targets.size():
		var tg: Array = _targets[k]
		var hinge: Node3D = tg[0]
		var row: Array = ROWS[int(tg[1])]
		var x: float = fposmod(float(tg[2]) * SPACING + float(row[2]) * t + SPAN * 0.5, SPAN) - SPAN * 0.5
		hinge.position = Vector3(x, float(row[0]), float(row[1]))
		hinge.rotation_degrees = Vector3(-80.0 * float(down[k]), 0.0, 0.0)
	# the sparks of the latest hit, flying out and fading
	for s in _sparks:
		(s[0] as MeshInstance3D).visible = false
	if not hit_pos.is_empty():
		var hp: Array = hit_pos[hit_pos.size() - 1]
		var center: Vector3 = (_targets[int(hp[0])][0] as Node3D).position + Vector3(0.0, 37.0, 4.0)
		var dt2: float = float(hp[1])
		for k in _sparks.size():
			var a: float = TAU * h01(int(hp[2]) * 41 + k)
			var sp_dir: Vector3 = Vector3(cos(a), sin(a) * 0.8 + 0.3, 0.4 + 0.6 * h01(k + 3))
			var spk: Array = _sparks[k]
			var mi: MeshInstance3D = spk[0]
			mi.visible = true
			mi.position = center + sp_dir * (70.0 * dt2) + Vector3(0.0, -90.0 * dt2 * dt2, 0.0)
			var fade: float = 1.0 - dt2 / 0.6
			mi.scale = Vector3.ONE * (0.4 + fade)
			(spk[1] as StandardMaterial3D).albedo_color = Color(1.0, 0.85, 0.40).lerp(Color(1.0, 0.45, 0.15), 1.0 - fade)
	# the bulbs chase round the header, slowly
	for k in _bulbs.size():
		var wave: float = 0.5 + 0.5 * sin(float(k) * 0.6 - t * 3.2)
		(_bulbs[k] as StandardMaterial3D).albedo_color = Color(0.55, 0.40, 0.22).lerp(Color(1.0, 0.95, 0.75), wave)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Whack", "Tap quickly and accurately. Avoid decoys", Color(1.0, 0.86, 0.35), Color(0.20, 0.04, 0.04),
		Color(1.0, 0.7, 0.3, 0.25))

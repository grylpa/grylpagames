extends "res://scripts/menu_poster3d.gd"

# TYPIT'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A TYPEWRITER ON A
# DESK AT NIGHT. A black enamel machine with chrome-ringed round keys, on a varnished desk under a brass lamp, a mug
# and a pencil beside it, a few typed sheets. A line is being typed: each key goes down in turn, its letter appears
# on the paper at the typing point, and the carriage steps along; at the end of a line it slides back and the paper
# feeds up a line. When the page is done its lines fade, and it starts again. The desk, the lamp, the mug and the
# machine's body are the baked picture (`typit/art/menu_desk.webp`); the keys, the carriage (platen, paper, text)
# are live. One clock (`t`); nothing pops. Made up, never the board.

const LINES: Array = ["The quick brown fox", "jumps over the lazy", "dog. Fast and true!"]
const CPS: float = 9.0                    # characters a second
const RETURN_S: float = 0.5               # the carriage's return and the line feed
const HOLD_S: float = 0.8                 # the finished page, before it fades
const FADE_S: float = 0.5
const ROWS_KEYS: Array = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
const KEY_PITCH: float = 31.0
const TEXT_SIZE: float = 21.0             # the type's size on the paper
const LINE_H: float = 27.0
const PAPER_W: float = 300.0
const LAMP_C: Vector3 = Vector3(-320.0, 48.0, -220.0)   # the banker's lamp, on a stack of books at the machine's left
const TYPE_POINT: Vector3 = Vector3(0.0, 146.0, -61.0)   # where a letter is struck, on the paper over the platen

var _keys: Dictionary = {}                # char -> [Node3D, rest y]
var _space: Node3D = null
var _carriage: Node3D = null
var _feed: Node3D = null                  # the paper and its text, fed up a line at a time
var _line_labels: Array = []
var _cw: float = 9.0                      # one character's advance on the paper
var _cycle: float = 0.0
var _line_t0: Array = []                  # when each line starts

# ONE PICTURE PER PLATFORM: a desktop's menu leaves a short band, so its camera stands further back and the whole
# machine shows above the panel (with the phone's camera only the paper did)
func _baked_path() -> String:
	return "res://typit/art/menu_desk.webp" if mobile else "res://typit/art/menu_desk_d.webp"

func _eye() -> Vector3:
	return Vector3(-120.0, 330.0, 480.0) if mobile else Vector3(0.0, 380.0, 640.0)

func _aim() -> Vector3:
	return Vector3(-100.0, 118.0, -30.0) if mobile else Vector3(0.0, 105.0, -10.0)

func _fov() -> float:
	return 52.0

func _frame_frac() -> float:
	return 0.52

func _scene_top() -> float:
	return 250.0 if mobile else 150.0

func _environment(env: Environment) -> void:
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_color = Color(0.45, 0.42, 0.52)
	env.ambient_light_energy = 0.28

func _build_lights() -> void:
	# the desk lamp's warm pool from the left, a soft fill from the front, a cool rim from behind
	spot(LAMP_C + Vector3(0.0, 104.0, 40.0), Vector3(40.0, 40.0, 60.0), Color(1.0, 0.86, 0.62), 1.4, 600.0, 70.0, true)
	light(LAMP_C + Vector3(30.0, 96.0, 50.0), Color(1.0, 0.86, 0.62), 1.2, 300.0)
	# the page catches the lamp: a soft warm light from the left front, at its height
	light(Vector3(-150.0, 230.0, 80.0), Color(1.0, 0.84, 0.62), 0.9, 300.0)
	light(Vector3(60.0, 260.0, 380.0), Color(1.0, 0.86, 0.70), 0.7, 600.0)
	light(Vector3(200.0, 260.0, -300.0), Color(0.75, 0.80, 0.95), 0.35, 500.0)

func _paper_tex(n: int) -> ImageTexture:
	# good bond paper: warm white, a fine laid texture (faint lines across), long fibers, a tooth of speckle, the
	# edges a shade darker; a printed rule and a small embossed seal at the head
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var laid: float = 0.5 + 0.5 * sin(float(y) * 1.6)
			var c: Color = Color(0.965, 0.950, 0.900).darkened(0.035 * h01(x * 13 + y * 7) + 0.012 * laid)
			var ex: float = minf(minf(float(x), float(n - 1 - x)), minf(float(y), float(n - 1 - y))) / float(n)
			c = c.darkened(0.06 * (1.0 - smoothstep(0.0, 0.06, ex)))
			img.set_pixel(x, y, c)
	for k in 160:
		var fx: float = h01(k * 3 + 1) * float(n)
		var fy: float = h01(k * 3 + 2) * float(n)
		var ang: float = h01(k * 3 + 3) * TAU
		var ln: int = 3 + int(h01(k + 50) * 9.0)
		for j in ln:
			var px: int = int(fx + cos(ang) * float(j)) % n
			var py: int = int(fy + sin(ang) * float(j)) % n
			img.set_pixel(absi(px), absi(py), img.get_pixel(absi(px), absi(py)).darkened(0.05))
	# the head: a thin double rule, and a round seal pressed into the paper (a lit rim, a shadowed one)
	var hy: int = int(float(n) * 0.10)
	for x2 in range(int(n * 0.12), int(n * 0.88)):
		img.set_pixel(x2, hy, Color(0.55, 0.20, 0.18))
		img.set_pixel(x2, hy + 2, Color(0.62, 0.30, 0.26))
	var sc: Vector2 = Vector2(float(n) * 0.82, float(n) * 0.055)
	for y3 in range(0, int(n * 0.11)):
		for x3 in range(int(n * 0.74), int(n * 0.90)):
			var dd: float = Vector2(float(x3), float(y3)).distance_to(sc)
			if absf(dd - float(n) * 0.035) < 0.8:
				var up: bool = float(y3) < sc.y
				img.set_pixel(x3, y3, img.get_pixel(x3, y3).lightened(0.06) if up else img.get_pixel(x3, y3).darkened(0.08))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# THE SHEET IN THE MACHINE: flat where it is typed on (just over the platen), then curling back over the top as a
# sheet of paper does, a slight ripple across it -- in the quad's own frame (x across, y up the sheet, z out of it)
func _sheet_mesh(w: float, h: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu: int = 24
	var nv: int = 24
	var grid: Array = []
	for j in nv + 1:
		var v: float = -h * 0.5 + h * float(j) / float(nv)
		var row: Array = []
		for i in nu + 1:
			var u: float = -w * 0.5 + w * float(i) / float(nu)
			var bend: float = maxf(0.0, v - 10.0)
			var z: float = -0.0075 * bend * bend + 2.2 * sin(u * 0.025 + 0.7) * (v + h * 0.5) / h
			row.append([Vector3(u, v - 0.0022 * bend * bend, z), Vector2(float(i) / float(nu), 1.0 - float(j) / float(nv))])
		grid.append(row)
	for j in nv:
		for i in nu:
			for q in [[0, 0], [1, 0], [1, 1], [0, 0], [1, 1], [0, 1]]:
				var c: Array = grid[j + q[1]][i + q[0]]
				st.set_uv(c[1])
				st.add_vertex(c[0])
	st.generate_normals()
	return st.commit()

# --- the desk and the machine's body: baked --------------------------------------------------------------------

# a banker's lamp shade: half a tube, open below, its ends closed, glass of `t` thickness
func _half_tube(r: float, length: float, th: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = 24
	for side in [0.0, 1.0]:
		var rr: float = r - th * side
		for k in n:
			var a0: float = PI * float(k) / float(n)
			var a1: float = PI * float(k + 1) / float(n)
			var p0: Vector3 = Vector3(-length * 0.5, sin(a0) * rr, cos(a0) * rr)
			var p1: Vector3 = Vector3(length * 0.5, sin(a0) * rr, cos(a0) * rr)
			var p2: Vector3 = Vector3(length * 0.5, sin(a1) * rr, cos(a1) * rr)
			var p3: Vector3 = Vector3(-length * 0.5, sin(a1) * rr, cos(a1) * rr)
			for v in [p0, p1, p2, p0, p2, p3]:
				st.add_vertex(v)
	for e in [-1.0, 1.0]:
		for k2 in n:
			var b0: float = PI * float(k2) / float(n)
			var b1: float = PI * float(k2 + 1) / float(n)
			for v2 in [Vector3(e * length * 0.5, 0.0, 0.0), Vector3(e * length * 0.5, sin(b0) * r, cos(b0) * r), Vector3(e * length * 0.5, sin(b1) * r, cos(b1) * r)]:
				st.add_vertex(v2)
	st.generate_normals()
	return st.commit()

func _build_still() -> void:
	var desk: StandardMaterial3D = mat(Color.WHITE, 0.35, 0.0, tex_wood(256, Color(0.38, 0.20, 0.10), 11), Vector3(2, 1, 1))
	var enamel: StandardMaterial3D = mat(Color(0.05, 0.05, 0.06), 0.18, 0.2)
	enamel.clearcoat_enabled = true
	enamel.clearcoat = 1.0
	var chrome: StandardMaterial3D = mat(Color(0.85, 0.86, 0.88), 0.15, 0.9)
	var brass: StandardMaterial3D = mat(Color(0.88, 0.68, 0.32), 0.3, 0.6)
	var gold_line: StandardMaterial3D = mat(Color(0.85, 0.66, 0.30), 0.35, 0.6)
	# the desk top and the wall behind, dark
	box(Vector3(1400.0, 20.0, 900.0), desk, Vector3(0.0, -10.0, 0.0))
	box(Vector3(1400.0, 900.0, 4.0), mat(Color(0.07, 0.06, 0.07), 0.9), Vector3(0.0, 440.0, -420.0))
	# THE MACHINE'S BODY: a broad base, a stepped key bed, the rounded upper housing, gold pinstripes
	put(rbox_mesh(185.0, 125.0, 34.0, 22.0, 6.0), enamel, Vector3(0.0, 0.0, 0.0))
	for r in 3:
		box(Vector3(330.0 - float(r) * 10.0, 12.0, 34.0), enamel, Vector3(0.0, 34.0 + float(r) * 9.0, 92.0 - float(r) * 30.0))
	put(rbox_mesh(180.0, 62.0, 62.0, 26.0, 10.0), enamel, Vector3(0.0, 30.0, -62.0))
	box(Vector3(330.0, 1.5, 1.0), gold_line, Vector3(0.0, 24.0, 125.4))
	box(Vector3(300.0, 1.5, 1.0), gold_line, Vector3(0.0, 86.0, 0.6))
	# the type guide where the letters strike, a little chrome ring over the paper's foot
	box(Vector3(26.0, 6.0, 6.0), chrome, Vector3(0.0, 96.0, -18.0))
	# feet
	for fx in [-160.0, 160.0]:
		for fz in [-100.0, 100.0]:
			cyl(10.0, 12.0, 6.0, mat(Color(0.08, 0.08, 0.08), 0.8), Vector3(fx, -1.0, fz))
	# ON THE DESK: a BANKER'S LAMP at the left (a brass base and stem, a green glass shade lit from inside, the bulb's
	# glow under it -- the old arm lamp stood mostly out of the picture), a mug of coffee, a pencil, typed sheets
	var lamp_c: Vector3 = LAMP_C
	# the books under it: three old cloth bindings, each a little askew, their page edges cream, a gilt band on a spine
	var book_cols: Array = [Color(0.30, 0.08, 0.07), Color(0.10, 0.18, 0.26), Color(0.20, 0.26, 0.14)]
	var pages: StandardMaterial3D = mat(Color(0.90, 0.86, 0.74), 0.9)
	var by: float = 0.0
	for bk in 3:
		var bh: float = 15.0 + 2.0 * float(bk % 2)
		var rot_y: float = [6.0, -4.0, 9.0][bk]
		var bc: Vector3 = Vector3(LAMP_C.x + [4.0, -6.0, 2.0][bk], by + bh * 0.5, LAMP_C.z)
		box(Vector3(150.0 - float(bk) * 12.0, bh, 104.0 - float(bk) * 8.0), mat(book_cols[bk], 0.75), bc, Vector3(0.0, rot_y, 0.0))
		box(Vector3(144.0 - float(bk) * 12.0, bh - 3.0, 100.0 - float(bk) * 8.0), pages, bc + Vector3(-3.0, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(rot_y)) + Vector3(0.0, 0.0, 0.0), Vector3(0.0, rot_y, 0.0))
		box(Vector3(2.0, bh - 4.0, 104.0 - float(bk) * 8.0), mat(Color(0.88, 0.68, 0.32), 0.3, 0.7), bc + Vector3(-(150.0 - float(bk) * 12.0) * 0.5 + 10.0, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(rot_y)), Vector3(0.0, rot_y, 0.0))
		by += bh
	put(rbox_mesh(42.0, 28.0, 10.0, 12.0, 4.0), brass, lamp_c)
	cyl(10.0, 14.0, 8.0, brass, lamp_c + Vector3(0.0, 14.0, 0.0))
	cyl(3.2, 3.2, 92.0, brass, lamp_c + Vector3(0.0, 62.0, 0.0))
	cyl(5.0, 5.0, 8.0, brass, lamp_c + Vector3(0.0, 108.0, 0.0))
	var arm2: PackedVector3Array = PackedVector3Array([lamp_c + Vector3(0.0, 110.0, 0.0), lamp_c + Vector3(0.0, 120.0, 14.0), lamp_c + Vector3(0.0, 116.0, 30.0)])
	put(tube_mesh(arm2, 2.4, 8), brass, Vector3.ZERO)
	# THE SHADE: CASED GLASS (the user: "a very good lamp but needs improvement") -- deep green glass outside, glossy,
	# a little of the light coming through it; inside a layer of warm OPAL, glowing; rolled brass caps at its ends, a
	# brass ridge along its crown, the bulb under it, a pull chain of beads hanging from it
	var shade_m: StandardMaterial3D = mat(Color(0.03, 0.26, 0.12), 0.08, 0.05)
	shade_m.clearcoat_enabled = true
	shade_m.clearcoat = 1.0
	shade_m.clearcoat_roughness = 0.05
	shade_m.emission_enabled = true
	shade_m.emission = Color(0.06, 0.40, 0.18)
	shade_m.emission_energy_multiplier = 0.35
	shade_m.rim_enabled = true
	shade_m.rim = 0.6
	shade_m.rim_tint = 0.4
	var sc: Vector3 = lamp_c + Vector3(0.0, 112.0, 32.0)
	put(_half_tube(26.0, 120.0, 0.5), shade_m, sc)
	var opal: StandardMaterial3D = glow(Color(1.0, 0.94, 0.80))
	opal.cull_mode = BaseMaterial3D.CULL_DISABLED
	var inner: MeshInstance3D = put(_half_tube(24.6, 118.0, 0.4), opal, sc + Vector3(0.0, -0.3, 0.0))
	inner.scale = Vector3(1.0, 1.0, 1.0)
	for ex in [-1.0, 1.0]:
		var cap: TorusMesh = TorusMesh.new()
		cap.inner_radius = 24.5
		cap.outer_radius = 29.0
		cap.rings = 48
		var cm: MeshInstance3D = put(cap, brass, sc + Vector3(ex * 60.5, 0.0, 0.0), Vector3(0.0, 0.0, 90.0))
		cm.scale = Vector3(1.0, 1.0, 1.0)
		cyl(26.5, 26.5, 2.0, brass, sc + Vector3(ex * 61.5, 0.0, 0.0), Vector3(0.0, 0.0, 90.0), null, 40)
	cyl(2.2, 2.2, 122.0, brass, sc + Vector3(0.0, 26.0, 0.0), Vector3(0.0, 0.0, 90.0), null, 12)
	cyl(5.0, 6.0, 6.0, brass, sc + Vector3(0.0, 27.0, 0.0), Vector3.ZERO, null, 16)
	var bulb: MeshInstance3D = cyl(8.0, 8.0, 80.0, glow(Color(1.0, 0.95, 0.80)), sc + Vector3(0.0, -6.0, 0.0), Vector3(0.0, 0.0, 90.0))
	bulb.scale = Vector3(1.0, 1.0, 1.0)
	# the pull chain: a string of small brass beads down to a tassel-bead
	for bd in 14:
		sphere(1.3, brass, sc + Vector3(30.0, -4.0 - float(bd) * 2.6, 22.0))
	cyl(1.6, 3.0, 7.0, brass, sc + Vector3(30.0, -44.0, 22.0), Vector3.ZERO, null, 12)
	# the base: stepped, a moulded edge, the stem's collar knurled
	put(rbox_mesh(48.0, 32.0, 5.0, 14.0, 2.0), brass, lamp_c + Vector3(0.0, 10.0, 0.0))
	for kn in 10:
		var ka: float = TAU * float(kn) / 10.0
		box(Vector3(1.2, 7.0, 1.2), brass, lamp_c + Vector3(cos(ka) * 5.4, 108.0, sin(ka) * 5.4))
	cyl(34.0, 31.0, 70.0, mat(Color(0.90, 0.88, 0.84), 0.3), Vector3(310.0, 35.0, 40.0))
	cyl(30.0, 30.0, 1.0, mat(Color(0.18, 0.09, 0.04), 0.2), Vector3(310.0, 64.0, 40.0))
	var handle: TorusMesh = TorusMesh.new()
	handle.inner_radius = 14.0
	handle.outer_radius = 21.0
	put(handle, mat(Color(0.90, 0.88, 0.84), 0.3), Vector3(346.0, 38.0, 40.0), Vector3(90.0, 0.0, 0.0))
	cyl(3.5, 3.5, 150.0, mat(Color(0.95, 0.75, 0.20), 0.5), Vector3(220.0, 3.6, 170.0), Vector3(0.0, 30.0, 90.0))
	cyl(3.5, 0.5, 14.0, mat(Color(0.85, 0.70, 0.55), 0.6), Vector3(220.0, 3.6, 170.0) + Vector3(82.0, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(30.0)), Vector3(0.0, 30.0, -90.0))
	var sheet: StandardMaterial3D = mat(Color.WHITE, 0.85, 0.0, _paper_tex(64))
	for k in 3:
		box(Vector3(210.0, 0.8, 280.0), sheet, Vector3(-300.0 + float(k) * 6.0, 0.5 + float(k) * 0.9, 210.0 - float(k) * 4.0), Vector3(0.0, 12.0 + float(k) * 7.0, 0.0))
	for k in 6:
		box(Vector3(150.0 - 30.0 * h01(k), 0.4, 3.0), mat(Color(0.25, 0.25, 0.28), 0.8), Vector3(-300.0 + 18.0, 3.4, 140.0 + float(k) * 22.0), Vector3(0.0, 33.0, 0.0))

# --- live: the keys and the carriage --------------------------------------------------------------------------------

func _key(ch: String, pos: Vector3, cap_m: StandardMaterial3D, ring_m: StandardMaterial3D) -> Node3D:
	var k: Node3D = Node3D.new()
	root.add_child(k)
	k.position = pos
	cyl(1.8, 1.8, 26.0, ring_m, Vector3(0.0, -13.0, 0.0), Vector3.ZERO, k, 8)
	cyl(12.5, 12.5, 4.0, ring_m, Vector3.ZERO, Vector3.ZERO, k, 32)
	cyl(10.8, 10.8, 4.6, cap_m, Vector3(0.0, 0.3, 0.0), Vector3.ZERO, k, 32)
	var lb: Label3D = label(ch.to_upper(), 10.0, Color(0.95, 0.94, 0.90), Vector3(0.0, 2.8, 0.0), Vector3(-90.0, 0.0, 0.0), k)
	lb.font = MainGlobals.get_text_font()
	# rasterized small (a key's letter is a few pixels on screen; 26 letters at 128 px held up the first frame)
	lb.font_size = 32
	lb.pixel_size = 10.0 / 32.0
	return k

func _build_live() -> void:
	var cap_m: StandardMaterial3D = mat(Color(0.06, 0.06, 0.07), 0.25, 0.1)
	var ring_m: StandardMaterial3D = mat(Color(0.85, 0.86, 0.88), 0.15, 0.9)
	for r in ROWS_KEYS.size():
		var row: String = ROWS_KEYS[r]
		var y: float = 60.0 + float(2 - r) * 0.0 + float(r) * -9.0 + 18.0
		var z: float = 32.0 + float(r) * 30.0
		var x0: float = -float(row.length() - 1) * 0.5 * KEY_PITCH + float(r) * 8.0
		for i in row.length():
			var ch: String = row.substr(i, 1)
			var pos: Vector3 = Vector3(x0 + float(i) * KEY_PITCH, 69.0 - float(r) * 9.0, z)
			_keys[ch] = [_key(ch, pos, cap_m, ring_m), pos.y]
	# the space bar, chrome, on its two arms
	_space = Node3D.new()
	root.add_child(_space)
	_space.position = Vector3(0.0, 46.0, 120.0)
	put(rbox_mesh(90.0, 6.0, 7.0, 5.0, 2.0), ring_m, Vector3.ZERO, Vector3.ZERO, _space)
	# THE CARRIAGE: the black platen with its knobs, the paper bail, the paper standing up from it with its text
	_carriage = Node3D.new()
	root.add_child(_carriage)
	var rubber: StandardMaterial3D = mat(Color(0.04, 0.04, 0.04), 0.5)
	var chrome: StandardMaterial3D = mat(Color(0.85, 0.86, 0.88), 0.15, 0.9)
	cyl(19.0, 19.0, 330.0, rubber, Vector3(0.0, 118.0, -70.0), Vector3(0.0, 0.0, 90.0), _carriage, 40)
	for e in [-1.0, 1.0]:
		cyl(14.0, 14.0, 18.0, chrome, Vector3(e * 176.0, 118.0, -70.0), Vector3(0.0, 0.0, 90.0), _carriage, 32)
		cyl(9.0, 9.0, 24.0, rubber, Vector3(e * 196.0, 118.0, -70.0), Vector3(0.0, 0.0, 90.0), _carriage, 24)
	cyl(2.0, 2.0, 300.0, chrome, Vector3(0.0, 136.0, -47.0), Vector3(0.0, 0.0, 90.0), _carriage, 12)
	# the carriage return lever at the left
	var lever: PackedVector3Array = PackedVector3Array([Vector3(-170.0, 128.0, -60.0), Vector3(-190.0, 150.0, -30.0), Vector3(-215.0, 152.0, 0.0)])
	put(tube_mesh(lever, 3.0, 10), chrome, Vector3.ZERO, Vector3.ZERO, _carriage)
	# the paper and its lines feed up together; the sheet is tilted back with the platen's curve
	_feed = Node3D.new()
	_carriage.add_child(_feed)
	var paper_m: StandardMaterial3D = mat(Color.WHITE, 0.80, 0.0, _paper_tex(256))
	paper_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	paper_m.backlight_enabled = true                  # thin: the lamp shows through a little where it curls
	paper_m.backlight = Color(0.30, 0.26, 0.20)
	var tilt: Vector3 = Vector3(-14.0, 0.0, 0.0)
	put(_sheet_mesh(PAPER_W, 190.0), paper_m, Vector3(0.0, TYPE_POINT.y + 95.0 - 40.0, TYPE_POINT.z - 8.0 - 14.0), tilt, _feed)
	var mono: Font = load("res://art/fonts/JetBrainsMono.ttf") if ResourceLoader.exists("res://art/fonts/JetBrainsMono.ttf") else MainGlobals.get_text_font()
	_cw = mono.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, 128).x * TEXT_SIZE / 128.0
	for li in LINES.size():
		var lb: Label3D = label("", TEXT_SIZE, Color(0.10, 0.10, 0.12), Vector3.ZERO, tilt, _feed)
		lb.font = mono
		lb.font_size = 64
		lb.pixel_size = TEXT_SIZE / 64.0
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lb.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		lb.shaded = true
		lb.render_priority = 1
		_line_labels.append(lb)
	# the timeline: a line typed, the carriage returned; the page held, faded
	var tt: float = 0.15
	for li2 in LINES.size():
		_line_t0.append(tt)
		tt += float(str(LINES[li2]).length()) / CPS + RETURN_S
	_cycle = tt + HOLD_S + FADE_S + 0.1

# the paper's point for a character `col` of line `li`, before the carriage and the feed move it (on the tilted sheet)
func _char_pos(li: int, col: float) -> Vector3:
	var up: float = -float(li) * LINE_H
	var tilt: float = deg_to_rad(-14.0)
	# lower on the tilted sheet is nearer (+z), as the paper itself is -- the other way the lines sank behind it
	return Vector3(-PAPER_W * 0.5 + 18.0 + col * _cw, TYPE_POINT.y + up * cos(tilt), TYPE_POINT.z + 0.6 + up * sin(tilt))

func _animate(_delta: float) -> void:
	if _carriage == null:
		return
	var u: float = fmod(t, _cycle)
	# where the page is: the line being typed, how much of it, and the carriage's return between lines
	var li: int = 0
	var typed: float = 0.0
	var returning: float = 0.0
	for k in LINES.size():
		if u >= float(_line_t0[k]):
			li = k
	var line_len: int = str(LINES[li]).length()
	var since: float = u - float(_line_t0[li])
	if u < float(_line_t0[0]):
		since = 0.0
	typed = minf(float(line_len), since * CPS)
	if since * CPS > float(line_len):
		returning = clampf((since - float(line_len) / CPS) / RETURN_S, 0.0, 1.0)
		if li == LINES.size() - 1:
			returning = 0.0          # the last line stays where it ends while the page is held
	var col: float = floor(typed)
	# THE CARRIAGE: the typing point stays put, the carriage moves left a step with each letter (a quick step, not a
	# slide), and on a return slides back eased while the paper feeds up a line
	var step_u: float = typed - col
	# the letter strikes first (a fifth of its step), then the carriage steps on
	var col_eased: float = col + smoothstep(0.25, 0.55, step_u) if typed < float(line_len) else float(line_len)
	var cx: float = lerpf(col_eased, 0.0, smoothstep(0.0, 1.0, returning))
	# the page done and fading: the carriage glides home and the paper winds back down with it, so the next page
	# starts where this one left off (nothing jumps)
	var end_t: float = float(_line_t0[LINES.size() - 1]) + float(str(LINES[LINES.size() - 1]).length()) / CPS + HOLD_S
	var home: float = smoothstep(end_t, end_t + FADE_S + 0.3, u)
	cx = lerpf(cx, 0.0, home)
	var start_x: float = -PAPER_W * 0.5 + 18.0
	_carriage.position = Vector3(-(start_x + cx * _cw), 0.0, 0.0)
	var feed_lines: float = lerpf(float(li) + smoothstep(0.2, 1.0, returning), 0.0, home)
	var tilt: float = deg_to_rad(-14.0)
	_feed.position = Vector3(0.0, feed_lines * LINE_H * cos(tilt), feed_lines * LINE_H * sin(tilt))
	# the text: lines done, the current one as far as typed; the whole page fading at the end
	var fade: float = 1.0 - smoothstep(end_t, end_t + FADE_S, u)
	for k in LINES.size():
		var lb: Label3D = _line_labels[k]
		var full: String = LINES[k]
		var shown: int = int(col) + (1 if step_u > 0.18 and typed < float(line_len) else 0)
		lb.text = full if k < li else (full.substr(0, mini(shown, full.length())) if k == li else "")
		lb.position = _char_pos(k, 0.0)
		lb.modulate = Color(0.10, 0.10, 0.12, fade)
	# THE KEYS: the one just struck goes down and comes back up
	for ch in _keys.keys():
		var kk: Array = _keys[ch]
		(kk[0] as Node3D).position.y = float(kk[1])
	_space.position.y = 46.0
	if typed < float(line_len) and u >= float(_line_t0[0]):
		var cur: String = str(LINES[li]).substr(int(col), 1).to_lower()
		var press: float = smoothstep(0.0, 0.12, step_u) * (1.0 - smoothstep(0.18, 0.6, step_u))
		if cur == " ":
			_space.position.y = 46.0 - 4.0 * press
		elif _keys.has(cur):
			var kk2: Array = _keys[cur]
			(kk2[0] as Node3D).position.y = float(kk2[1]) - 6.0 * press

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Typit", "How fast and accurate can you type?", Color(1.0, 0.88, 0.60), Color(0.10, 0.06, 0.04),
		Color(1.0, 0.8, 0.5, 0.22))

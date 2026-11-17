extends "res://scripts/menu_poster3d.gd"

# TYPIT'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A TYPEWRITER ON A
# DESK AT NIGHT. A black enamel machine with chrome-ringed round keys, on a varnished desk under a brass lamp, a mug
# and a pencil beside it, a few typed sheets. A line is being typed: each key goes down in turn, its letter appears
# on the paper at the typing point, and the carriage steps along; at the end of a line it slides back and the paper
# feeds up a line. When the page is done its lines fade, and it starts again. The desk, the lamp, the mug and the
# machine's body are the baked picture (`typit/art/menu_desk.webp`); the keys, the carriage (platen, paper, text)
# are live. One clock (`t`); nothing pops. Made up, never the board.

const LINES: Array = ["The quick brown fox", "jumps over the lazy", "dog. Fast and true!"]
const CPS: float = 7.5                    # characters a second
const RETURN_S: float = 0.7               # the carriage's return and the line feed
const HOLD_S: float = 1.6                 # the finished page, before it fades
const FADE_S: float = 0.7
const ROWS_KEYS: Array = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
const KEY_PITCH: float = 31.0
const TEXT_SIZE: float = 21.0             # the type's size on the paper
const LINE_H: float = 27.0
const PAPER_W: float = 300.0
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
	return Vector3(0.0, 330.0, 470.0) if mobile else Vector3(0.0, 380.0, 640.0)

func _aim() -> Vector3:
	return Vector3(0.0, 118.0, -10.0) if mobile else Vector3(0.0, 105.0, -10.0)

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
	spot(Vector3(-240.0, 320.0, 45.0), Vector3(-10.0, 40.0, 40.0), Color(1.0, 0.84, 0.60), 22.0, 800.0, 55.0, true)
	light(Vector3(60.0, 260.0, 380.0), Color(1.0, 0.86, 0.70), 0.7, 600.0)
	light(Vector3(200.0, 260.0, -300.0), Color(0.75, 0.80, 0.95), 0.35, 500.0)

func _paper_tex(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var c: Color = Color(0.96, 0.94, 0.88).darkened(0.04 * h01(x * 13 + y * 7))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# --- the desk and the machine's body: baked --------------------------------------------------------------------

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
	label("TYPIT", 16.0, Color(0.90, 0.72, 0.36), Vector3(0.0, 80.0, 1.0), Vector3(0.0, 0.0, 0.0))    # above the top row of keys
	# the type guide where the letters strike, a little chrome ring over the paper's foot
	box(Vector3(26.0, 6.0, 6.0), chrome, Vector3(0.0, 96.0, -18.0))
	# feet
	for fx in [-160.0, 160.0]:
		for fz in [-100.0, 100.0]:
			cyl(10.0, 12.0, 6.0, mat(Color(0.08, 0.08, 0.08), 0.8), Vector3(fx, -1.0, fz))
	# ON THE DESK: a brass lamp at the left, a mug of coffee at the right, a pencil, typed sheets
	cyl(46.0, 52.0, 10.0, brass, Vector3(-330.0, 5.0, -60.0))
	var arm: PackedVector3Array = PackedVector3Array([Vector3(-330.0, 10.0, -60.0), Vector3(-330.0, 200.0, -70.0), Vector3(-300.0, 320.0, -10.0), Vector3(-250.0, 340.0, 40.0)])
	put(tube_mesh(arm, 4.5, 12), brass, Vector3.ZERO)
	var shade: MeshInstance3D = cyl(20.0, 62.0, 70.0, brass, Vector3(-240.0, 320.0, 45.0), Vector3(0.0, 0.0, -38.0))
	(shade.mesh as CylinderMesh).cap_bottom = false
	sphere(14.0, glow(Color(1.0, 0.92, 0.70)), Vector3(-232.0, 300.0, 47.0))
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
	var paper_m: StandardMaterial3D = mat(Color.WHITE, 0.85, 0.0, _paper_tex(64))
	var pq: QuadMesh = QuadMesh.new()
	pq.size = Vector2(PAPER_W, 190.0)
	var tilt: Vector3 = Vector3(-14.0, 0.0, 0.0)
	put(pq, paper_m, Vector3(0.0, TYPE_POINT.y + 95.0 - 40.0, TYPE_POINT.z - 8.0 - 14.0), tilt, _feed)
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
	var tt: float = 0.4
	for li2 in LINES.size():
		_line_t0.append(tt)
		tt += float(str(LINES[li2]).length()) / CPS + RETURN_S
	_cycle = tt + HOLD_S + FADE_S + 0.3

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

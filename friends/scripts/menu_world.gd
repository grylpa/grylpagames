extends "res://scripts/menu_poster3d.gd"

# FRIENDS' OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): FRIENDS' PHOTOS
# ON A STRING, IN A WARM ROOM AT EVENING (2026-11-18; before it a park walk with photo cards and 3-D people together --
# the user: "both cards and funny people?", and the park was poor). A whitewashed brick wall lit by a table lamp and a
# swag of fairy lights; under the lights a length of jute twine between two nails, and on it, held by wooden pegs, the
# game's own people as old photographic prints (the shared card's photo style), each swaying a little on its peg. Every
# couple of seconds one of them turns over on its peg and comes round as someone else: a FRIEND has their name written
# under the photo in ink, a stranger has none. Below, a sideboard with the lamp, a stack of books, a mug of tea with
# its steam, a potted fern; a window at the side onto the blue evening. The room, the twine and the nails are baked,
# one picture per platform (`menu_room.webp`, `menu_room_d.webp`); the photos and their pegs are live 2-D, the photos
# loaded on threads. Made up, never the board.

const CARD: GDScript = preload("res://shared/scripts/card.gd")
const PEOPLE: Array = ["Alina Vetrova", "Anand_Iyer", "Barbara_Coleman", "Beverly_Mitchel", "Carolyn_Ramirez"]
const NAMES: Array = ["Anna", "Ben", "Clara", "David", "Elena", "Frank", "Grace", "Hugo", "Iris", "Jonah", "Kate", "Leo",
	"Maya", "Nora", "Omar", "Paula", "Ruth", "Sam", "Tara", "Victor"]
const PEGS: int = 5
const NAIL_L: Vector3 = Vector3(-330.0, 600.0, -36.0)
const NAIL_R: Vector3 = Vector3(330.0, 600.0, -36.0)
const SAG: float = 46.0
const PHOTO_W: float = 104.0             # a print's width on the wall (units)
const TURN_EVERY: float = 2.2            # one photo turns over this often
const TURN_S: float = 0.7                # and takes this long

var _people: Array = []
var _tex: Dictionary = {}                # person -> Texture2D, once loaded
var _hangers: Array = []                 # Node2D per peg: the photo and its peg, swinging from the peg's point
var _cards: Array = []
var _who: Array = []                     # the person on each peg now
var _turned: Array = []                  # the turn number each peg last showed
var _steam: Control = null

func _baked_path() -> String:
	return "res://friends/art/menu_room.webp" if mobile else "res://friends/art/menu_room_d.webp"

func _eye() -> Vector3:
	return Vector3(0.0, 420.0, 760.0) if mobile else Vector3(0.0, 430.0, 1000.0)

func _aim() -> Vector3:
	return Vector3(0.0, 430.0, -40.0) if mobile else Vector3(0.0, 420.0, -40.0)

func _fov() -> float:
	return 52.0

func _frame_frac() -> float:
	return 0.5

func _environment(env: Environment) -> void:
	env.background_color = Color(0.04, 0.03, 0.03)
	env.ambient_light_color = Color(0.62, 0.52, 0.44)
	env.ambient_light_energy = 0.26

func _build_lights() -> void:
	# the table lamp's warm pool up the wall, the fairy lights along the swag, the window's cool evening light
	light(Vector3(-250.0, 300.0, 30.0), Color(1.0, 0.80, 0.55), 1.7, 900.0)
	for fl in 4:
		var fx: float = lerpf(-260.0, 260.0, float(fl) / 3.0)
		light(Vector3(fx, 640.0, 20.0), Color(1.0, 0.82, 0.55), 0.7, 300.0)
	light(Vector3(520.0, 420.0, 120.0), Color(0.55, 0.65, 1.0), 1.1, 700.0)
	spot(Vector3(80.0, 900.0, 650.0), Vector3(0.0, 420.0, -40.0), Color(1.0, 0.90, 0.78), 0.7, 1500.0, 34.0, true)

# --- the twine and the pegs ----------------------------------------------------------------------------------------

func _twine_at(x: float) -> Vector3:
	var u: float = (x - NAIL_L.x) / (NAIL_R.x - NAIL_L.x)
	return Vector3(x, NAIL_L.y - SAG * 4.0 * u * (1.0 - u), NAIL_L.z + 1.0)

func _peg_x(k: int) -> float:
	return lerpf(NAIL_L.x + 70.0, NAIL_R.x - 70.0, float(k) / float(PEGS - 1))

func _person(n: int) -> String:
	return _people[posmod(n * 7 + 3, _people.size())]

func _is_friend(n: int) -> bool:
	return posmod(n * 5 + 1, 3) != 0

func _setup() -> void:
	super._setup()
	if bake_mode:
		return
	var dir: DirAccess = DirAccess.open("res://art/people")
	if dir != null:
		for f in dir.get_files():
			var fn: String = f.trim_suffix(".import")
			if fn.ends_with(".jpg") and not _people.has(fn.get_basename()):
				_people.append(fn.get_basename())
	_people.sort()
	if _people.is_empty():
		_people = PEOPLE.duplicate()
	_steam = Control.new()
	_steam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_steam.set_anchors_preset(Control.PRESET_FULL_RECT)
	_steam.draw.connect(func() -> void: _draw_steam(_steam))
	add_child(_steam)
	for k in PEGS:
		var hanger: Node2D = Node2D.new()
		add_child(hanger)
		var c: Node2D = CARD.new()
		hanger.add_child(c)
		c.call("set_frame", 8, 8)
		c.call("set_photo", true)
		c.visible = false
		var peg: Node2D = Node2D.new()
		hanger.add_child(peg)
		var kk: int = k
		peg.draw.connect(func() -> void: _draw_peg(peg, kk))
		_hangers.append(hanger)
		_cards.append(c)
		_who.append(-1)
		_turned.append(-99)
	if _top != null:
		move_child(_top, get_child_count() - 1)

func _want(person: String) -> Texture2D:
	if _tex.has(person):
		return _tex[person]
	var path: String = "res://art/people/%s.jpg" % person
	var st: int = ResourceLoader.load_threaded_get_status(path)
	if st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)
	elif st == ResourceLoader.THREAD_LOAD_LOADED:
		_tex[person] = ResourceLoader.load_threaded_get(path)
		return _tex[person]
	return null

# the n-th photo shown on peg k (each peg has its own run of people)
func _photo_n(k: int, turn: int) -> int:
	return k * 11 + turn * 3

func _tick(delta: float) -> void:
	super._tick(delta)
	if bake_mode or _hangers.is_empty() or _cam3 == null:
		return
	var round_n: int = int(floor(t / TURN_EVERY))
	for k in PEGS:
		# the peg's own turn count: peg (round mod PEGS) turns on each round, in order along the string
		var turns: int = int(floor(float(round_n - k) / float(PEGS))) + 1
		var since: float = t - float(round_n - posmod(round_n - k, PEGS)) * TURN_EVERY
		var turning: float = clampf(since / TURN_S, 0.0, 1.0) if posmod(round_n - k, PEGS) == 0 and turns > 0 else 1.0
		var shown: int = turns if turning >= 0.5 else turns - 1
		var n: int = _photo_n(k, shown)
		var c: Node2D = _cards[k]
		if _who[k] != n:
			var tex: Texture2D = _want(_person(n))
			if tex != null:
				c.set("fit", 1)
				c.call("setup", tex, Color(1, 1, 1))
				c.call("set_width", 200.0)
				c.call("set_label", NAMES[posmod(n, NAMES.size())] if _is_friend(n) else "")
				c.call("show_label", true)
				if not c.visible:
					c.visible = true
					c.modulate.a = 0.0
				_who[k] = n
			# (until the photo has loaded the old one stays)
		c.modulate.a = fade_in(true, c.modulate.a, delta)
		# hung from the peg's point on the twine, scaled to the camera there, swaying on its own slow beat
		var px: float = _peg_x(k)
		var top3: Vector3 = _twine_at(px)
		var at: Vector2 = screen_of(top3)
		var px_per: float = screen_of(top3 + Vector3(100.0, 0.0, 0.0)).distance_to(at) / 100.0
		var sc: float = PHOTO_W * px_per / 200.0
		var hanger: Node2D = _hangers[k]
		var sway: float = 0.045 * sin(t * (0.9 + 0.13 * float(k)) + float(k) * 1.9) + 0.02 * sin(t * 2.3 + float(k))
		# THE TURN: the print turns about its own upright on the peg (narrowing to its edge, coming round as the next),
		# with a little swing set going by it
		var turn_a: float = turning * PI
		var squash: float = absf(cos(turn_a))
		if turning < 1.0:
			sway += 0.10 * sin(turning * PI) * sin(turning * TAU * 1.5)
		hanger.position = at
		hanger.rotation = sway
		hanger.scale = Vector2(sc, sc)
		var cw: float = 200.0
		var ch: float = float(c.call("card_height"))
		c.position = Vector2(-cw * 0.5 * squash, -10.0)
		c.scale = Vector2(maxf(0.02, squash), 1.0)
		var shade: float = 0.55 + 0.45 * squash
		c.modulate = Color(shade, shade, shade, c.modulate.a)
		c.set_meta("h", ch)
		(hanger.get_child(1) as Node2D).queue_redraw()
	_steam.queue_redraw()

# A WOODEN PEG gripping the print's top edge: two prongs of pale beech, rounded, the grain along them, their seam
# dark, and the coiled steel spring across the middle catching the light
func _draw_peg(d: Node2D, _k: int) -> void:
	var w: float = 26.0
	var h: float = 74.0
	var top: float = -40.0
	var body: PackedVector2Array = PackedVector2Array()
	for k2 in 16:
		var a: float = PI * float(k2) / 15.0
		body.append(Vector2(-w * 0.5 + w * 0.5 * (1.0 - cos(a)), top + 6.0 - 6.0 * sin(a)))
	body.append(Vector2(w * 0.5, top + h - 8.0))
	body.append(Vector2(w * 0.36, top + h))
	body.append(Vector2(-w * 0.36, top + h))
	body.append(Vector2(-w * 0.5, top + h - 8.0))
	# a drop shadow on the print below
	var sh: PackedVector2Array = PackedVector2Array()
	for p in body:
		sh.append(p + Vector2(4.0, 6.0))
	d.draw_colored_polygon(sh, Color(0.0, 0.0, 0.0, 0.28))
	d.draw_colored_polygon(body, Color(0.80, 0.64, 0.42))
	# rounded: lit from the left, darker to the right
	for band in 6:
		var x0: float = -w * 0.5 + w * float(band) / 6.0
		var shade: float = 0.10 - 0.05 * float(band)
		d.draw_rect(Rect2(x0, top + 4.0, w / 6.0, h - 10.0), Color(1.0, 0.95, 0.85, shade) if shade > 0.0 else Color(0.25, 0.12, 0.04, -shade * 1.6))
	for g in 4:
		var gx: float = -w * 0.32 + float(g) * w * 0.2 + 2.0 * sin(float(g) * 2.3)
		d.draw_line(Vector2(gx, top + 8.0), Vector2(gx + 1.5, top + h - 6.0), Color(0.55, 0.38, 0.20, 0.35), 1.0, true)
	d.draw_line(Vector2(0.0, top + 2.0), Vector2(0.0, top + h - 2.0), Color(0.30, 0.18, 0.08, 0.85), 2.2, true)
	# the spring: turns of steel wire across the waist
	var sy: float = top + h * 0.40
	d.draw_rect(Rect2(-w * 0.62, sy - 7.0, w * 1.24, 14.0), Color(0.22, 0.22, 0.24))
	for coil in 6:
		var cy: float = sy - 6.0 + float(coil) * 2.4
		d.draw_line(Vector2(-w * 0.62, cy), Vector2(w * 0.62, cy + 0.8), Color(0.80, 0.82, 0.86), 1.6, true)
		d.draw_line(Vector2(-w * 0.3, cy - 0.3), Vector2(-w * 0.05, cy), Color(1.0, 1.0, 1.0, 0.8), 1.0, true)

# STEAM rising off the mug: soft wisps curling up and thinning out
func _draw_steam(d: Control) -> void:
	if _cam3 == null:
		return
	var mug: Vector2 = screen_of(Vector3(150.0, 196.0, 60.0))
	var px_per: float = screen_of(Vector3(250.0, 196.0, 60.0)).distance_to(mug) / 100.0
	for w2 in 3:
		var pts: PackedVector2Array = PackedVector2Array()
		var ph: float = t * 0.6 + float(w2) * 2.1
		for k in 14:
			var f: float = float(k) / 13.0
			pts.append(mug + Vector2((sin(f * 5.0 + ph) * 7.0 + float(w2 - 1) * 5.0) * f * 1.6, -f * 70.0) * px_per)
		for k3 in pts.size() - 1:
			var f2: float = float(k3) / float(pts.size() - 1)
			d.draw_line(pts[k3], pts[k3 + 1], Color(1.0, 0.97, 0.92, 0.16 * (1.0 - f2) * (0.6 + 0.4 * sin(t + float(w2)))), (3.0 + 6.0 * f2) * px_per, true)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Friends", "Recognize your friends on an evening stroll", Color(1.0, 0.88, 0.62), Color(0.12, 0.06, 0.03),
		Color(1.0, 0.80, 0.45, 0.22))

# --- the room: real 3-D, baked ---------------------------------------------------------------------------------------

func _painted_brick(n: int) -> ImageTexture:
	# whitewashed brick: the courses showing through the paint, the mortar sunk and grayer, the wash thin in places
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var bh: int = n / 8
	var bw: int = n / 4
	for y in n:
		var row: int = y / bh
		for x in n:
			var xo: int = (x + (bw / 2 if row % 2 == 1 else 0)) % n
			var brick: int = row * 9 + xo / bw
			var thin: float = clampf(h01(brick * 17) * 1.3 - 0.9, 0.0, 1.0) * (0.5 + 0.5 * h01(x / 3 * 7 + y / 3 * 91))
			var c: Color = Color(0.90, 0.87, 0.80).lerp(Color(0.66, 0.42, 0.32), thin * 0.6).darkened(0.07 * h01(x * 5 + y * 77))
			var mx: int = xo % bw
			var my: int = y % bh
			if my < 2 or mx < 2:
				c = Color(0.70, 0.67, 0.62).darkened(0.08 * h01(x + y * 13))
			elif my == 2 or mx == 2:
				c = c.darkened(0.08)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _evening(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var v: float = float(y) / float(n - 1)
			var c: Color = Color(0.10, 0.14, 0.32).lerp(Color(0.32, 0.36, 0.58), smoothstep(0.3, 1.0, v))
			# rooftops and a few lit windows across the street
			var roof: float = 0.70 + 0.06 * sin(float(x) * 0.05) + (0.05 if (x / 18) % 3 == 0 else 0.0)
			if v > roof:
				c = Color(0.06, 0.06, 0.10)
				if (x % 11 < 4) and (y % 13 < 5) and h01(x / 11 * 31 + y / 13 * 7) > 0.55:
					c = Color(1.0, 0.80, 0.45)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _lathe(profile: Array, m: Material, at: Vector3, segs: int = 32) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size() - 1:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		for s in segs:
			var t0: float = TAU * float(s) / float(segs)
			var t1: float = TAU * float(s + 1) / float(segs)
			var q: Array = [Vector3(cos(t0) * a.x, a.y, sin(t0) * a.x), Vector3(cos(t1) * a.x, a.y, sin(t1) * a.x),
				Vector3(cos(t1) * b.x, b.y, sin(t1) * b.x), Vector3(cos(t0) * b.x, b.y, sin(t0) * b.x)]
			for vi in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(q[vi])
	st.generate_normals()
	put(st.commit(), m, at)

func _build_still() -> void:
	var oak: StandardMaterial3D = mat(Color.WHITE, 0.35, 0.0, tex_wood(128, Color(0.44, 0.26, 0.13), 7), Vector3(4, 1, 1))
	var brass: StandardMaterial3D = mat(Color(0.86, 0.66, 0.32), 0.3, 0.8)
	var iron: StandardMaterial3D = mat(Color(0.12, 0.11, 0.10), 0.4, 0.7)
	# THE WALL: whitewashed brick, a skirting board, the floor of dark boards at its foot
	box(Vector3(2600.0, 1600.0, 20.0), mat(Color.WHITE, 0.85, 0.0, _painted_brick(256), Vector3(10, 6, 1)), Vector3(0.0, 800.0, -50.0))
	box(Vector3(2600.0, 4.0, 1600.0), mat(Color.WHITE, 0.45, 0.0, tex_wood(128, Color(0.26, 0.15, 0.08), 3), Vector3(12, 10, 1)), Vector3(0.0, -2.0, 700.0))
	# A WINDOW at the right onto the evening street: deep reveal, a painted frame and glazing bars, a sill
	var wc: Vector3 = Vector3(560.0, 470.0, -40.0)
	var sky: StandardMaterial3D = mat(Color.WHITE, 1.0, 0.0, _evening(128))
	sky.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box(Vector3(200.0, 300.0, 2.0), sky, wc + Vector3(0.0, 0.0, -14.0))
	var paint: StandardMaterial3D = mat(Color(0.88, 0.86, 0.80), 0.5)
	for fb in [[Vector3(224.0, 14.0, 26.0), Vector3(0.0, 157.0, 0.0)], [Vector3(224.0, 14.0, 26.0), Vector3(0.0, -157.0, 0.0)], [Vector3(14.0, 300.0, 26.0), Vector3(-105.0, 0.0, 0.0)], [Vector3(14.0, 300.0, 26.0), Vector3(105.0, 0.0, 0.0)], [Vector3(6.0, 300.0, 6.0), Vector3(0.0, 0.0, -8.0)], [Vector3(200.0, 6.0, 6.0), Vector3(0.0, 40.0, -8.0)]]:
		box(fb[0], paint, wc + (fb[1] as Vector3))
	box(Vector3(250.0, 10.0, 46.0), paint, wc + Vector3(0.0, -168.0, 14.0))
	# THE NAILS and the JUTE TWINE between them, sagging; a second slack loop hanging off the right nail
	for nl in [NAIL_L, NAIL_R]:
		cyl(2.0, 2.0, 24.0, iron, (nl as Vector3) + Vector3(0.0, 0.0, 10.0), Vector3(90.0, 0.0, 0.0), null, 8)
		cyl(5.0, 5.0, 2.0, iron, (nl as Vector3) + Vector3(0.0, 0.0, 21.0), Vector3(90.0, 0.0, 0.0), null, 12)
	var jute: StandardMaterial3D = mat(Color(0.70, 0.56, 0.34), 0.95)
	var tw: PackedVector3Array = PackedVector3Array()
	for k in 41:
		tw.append(_twine_at(lerpf(NAIL_L.x, NAIL_R.x, float(k) / 40.0)) + Vector3(0.0, 0.0, 14.0))
	put(tube_mesh(tw, 1.5, 6), jute, Vector3.ZERO)
	var tail: PackedVector3Array = PackedVector3Array()
	for k5 in 10:
		var f: float = float(k5) / 9.0
		tail.append(NAIL_R + Vector3(2.0 + 10.0 * f, -80.0 * f + 10.0 * f * f, 14.0))
	put(tube_mesh(tail, 1.4, 6), jute, Vector3.ZERO)
	# THE FAIRY LIGHTS: a swag of fine green wire above the twine, small warm bulbs on it in their little sockets
	var wire: PackedVector3Array = PackedVector3Array()
	for k2 in 61:
		var u: float = float(k2) / 60.0
		var swag: float = 26.0 * absf(sin(u * PI * 3.0))
		wire.append(Vector3(lerpf(-420.0, 420.0, u), 720.0 - swag - 30.0 * 4.0 * u * (1.0 - u), -30.0))
	put(tube_mesh(wire, 0.9, 5), mat(Color(0.12, 0.20, 0.10), 0.6), Vector3.ZERO)
	for b in 21:
		var bp: Vector3 = wire[b * 3]
		cyl(2.0, 2.0, 5.0, mat(Color(0.12, 0.20, 0.10), 0.6), bp + Vector3(0.0, -3.0, 0.0), Vector3.ZERO, null, 8)
		var bulb: MeshInstance3D = sphere(4.0, glow(Color(1.0, 0.84, 0.52)), bp + Vector3(0.0, -9.0, 0.0))
		bulb.scale = Vector3(0.8, 1.2, 0.8)
	# THE SIDEBOARD: an oak top with a rounded front edge, its doors and brass pulls
	var top_y: float = 160.0
	box(Vector3(1000.0, 10.0, 130.0), oak, Vector3(0.0, top_y - 5.0, 30.0))
	cyl(5.0, 5.0, 1000.0, oak, Vector3(0.0, top_y - 5.0, 95.0), Vector3(0.0, 0.0, 90.0), null, 12)
	box(Vector3(980.0, top_y - 10.0, 120.0), oak, Vector3(0.0, (top_y - 10.0) * 0.5, 25.0))
	for dr in 4:
		var dx: float = -360.0 + float(dr) * 240.0
		box(Vector3(226.0, top_y - 40.0, 3.0), oak, Vector3(dx, (top_y - 10.0) * 0.5, 86.0))
		box(Vector3(200.0, top_y - 66.0, 2.0), mat(Color.WHITE, 0.4, 0.0, tex_wood(128, Color(0.38, 0.22, 0.10), 11), Vector3(2, 1, 1)), Vector3(dx, (top_y - 10.0) * 0.5, 88.0))
		sphere(5.0, brass, Vector3(dx + (90.0 if dr % 2 == 0 else -90.0), top_y * 0.55, 92.0))
	# THE LAMP at the left: a turned brass base and stem, a pleated linen shade glowing warm from within
	var lamp_c: Vector3 = Vector3(-250.0, top_y, 30.0)
	_lathe([Vector2(0.0, 0.0), Vector2(34.0, 0.0), Vector2(36.0, 4.0), Vector2(30.0, 10.0), Vector2(14.0, 18.0), Vector2(8.0, 26.0),
		Vector2(6.0, 60.0), Vector2(10.0, 66.0), Vector2(5.0, 72.0), Vector2(5.0, 120.0), Vector2(0.0, 122.0)], brass, lamp_c)
	# the shade's pleats: a fine stripe of fold light and fold shadow round it
	var pl: Image = Image.create(64, 4, false, Image.FORMAT_RGB8)
	for px in 64:
		var fold: float = 0.5 + 0.5 * sin(float(px) / 64.0 * TAU * 8.0)
		for py in 4:
			pl.set_pixel(px, py, Color(1.0, 0.88, 0.66).darkened(0.22 * (1.0 - fold)))
	var shade_m: StandardMaterial3D = mat(Color.WHITE, 0.9, 0.0, ImageTexture.create_from_image(pl), Vector3(5, 1, 1))
	shade_m.emission_enabled = true
	shade_m.emission = Color(1.0, 0.72, 0.40)
	shade_m.emission_energy_multiplier = 0.9
	var pleats: Array = []
	for pk in 2:
		pleats.append(Vector2(78.0 - 30.0 * float(pk), 112.0 + 80.0 * float(pk)))
	_lathe(pleats, shade_m, lamp_c, 40)
	sphere(10.0, glow(Color(1.0, 0.92, 0.75)), lamp_c + Vector3(0.0, 128.0, 0.0))
	# A STACK OF BOOKS: cloth covers, gilt bands on the spines, the page block cream
	var books: Array = [[Color(0.40, 0.10, 0.10), 18.0], [Color(0.12, 0.24, 0.36), 14.0], [Color(0.20, 0.32, 0.18), 22.0], [Color(0.55, 0.42, 0.20), 12.0]]
	var by: float = top_y
	for bk in books.size():
		var bh: float = books[bk][1]
		var bw2: float = 150.0 - float(bk) * 10.0
		var rot_y: float = (h01(bk + 40) - 0.5) * 14.0
		box(Vector3(bw2, bh, 100.0), mat(books[bk][0], 0.7), Vector3(-30.0, by + bh * 0.5, 30.0), Vector3(0.0, rot_y, 0.0))
		box(Vector3(bw2 - 6.0, bh - 4.0, 96.0), mat(Color(0.90, 0.86, 0.74), 0.9), Vector3(-30.0, by + bh * 0.5, 33.0), Vector3(0.0, rot_y, 0.0))
		box(Vector3(bw2 + 0.4, 2.0, 3.0), brass, Vector3(-30.0, by + bh * 0.5, 80.5), Vector3(0.0, rot_y, 0.0))
		by += bh
	# THE MUG: glazed stoneware, a handle, tea in it
	var mug_c: Vector3 = Vector3(150.0, top_y, 60.0)
	_lathe([Vector2(0.0, 0.0), Vector2(20.0, 0.0), Vector2(22.0, 3.0), Vector2(23.0, 36.0), Vector2(21.0, 37.0), Vector2(20.0, 4.0)], mat(Color(0.20, 0.34, 0.44), 0.25, 0.1), mug_c)
	cyl(19.5, 19.5, 1.0, mat(Color(0.42, 0.22, 0.08), 0.1), mug_c + Vector3(0.0, 30.0, 0.0), Vector3.ZERO, null, 24)
	var hdl: TorusMesh = TorusMesh.new()
	hdl.inner_radius = 8.0
	hdl.outer_radius = 12.0
	put(hdl, mat(Color(0.20, 0.34, 0.44), 0.25, 0.1), mug_c + Vector3(25.0, 18.0, 0.0), Vector3(90.0, 0.0, 0.0))
	# A FERN in a terracotta pot at the right, its fronds arching out
	var pot_c: Vector3 = Vector3(330.0, top_y, 30.0)
	_lathe([Vector2(0.0, 0.0), Vector2(30.0, 0.0), Vector2(40.0, 58.0), Vector2(46.0, 60.0), Vector2(46.0, 70.0), Vector2(36.0, 70.0), Vector2(34.0, 62.0)], mat(Color(0.72, 0.36, 0.22), 0.85), pot_c)
	cyl(35.0, 35.0, 2.0, mat(Color(0.20, 0.14, 0.10), 1.0), pot_c + Vector3(0.0, 62.0, 0.0), Vector3.ZERO, null, 24)
	var frond_m: StandardMaterial3D = mat(Color(0.20, 0.42, 0.18), 0.7)
	for fr in 22:
		var fa: float = TAU * float(fr) / 14.0 + 0.3 * h01(fr)
		var reach: float = 110.0 + 50.0 * h01(fr + 9)
		var path: PackedVector3Array = PackedVector3Array()
		for fk in 9:
			var f: float = float(fk) / 8.0
			path.append(pot_c + Vector3(cos(fa) * reach * f, 64.0 + reach * 0.9 * sin(f * 2.2) - 30.0 * f * f, sin(fa) * reach * f * 0.7))
		put(tube_mesh(path, 1.2, 4), frond_m, Vector3.ZERO)
		for lf in 12:
			var f3: float = float(lf + 1) / 13.0
			var lp: Vector3 = path[mini(7, int(f3 * 8.0))].lerp(path[mini(8, int(f3 * 8.0) + 1)], fmod(f3 * 8.0, 1.0))
			for sd in [-1.0, 1.0]:
				var leaf: MeshInstance3D = sphere(15.0 * (1.0 - 0.55 * f3), frond_m, lp + Vector3(-sin(fa), 0.0, cos(fa)) * sd * 8.0 * (1.0 - 0.5 * f3))
				leaf.scale = Vector3(1.0, 0.25, 0.45)
				leaf.rotation = Vector3(0.0, -fa + sd * 0.6, 0.0)

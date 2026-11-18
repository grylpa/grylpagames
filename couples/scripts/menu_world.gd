extends "res://scripts/menu_poster3d.gd"

# COUPLES' OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A CARD TABLE IN A
# PARLOR AT NIGHT, seen across it (it was a flat top-down view of scattered cards -- the user: "boring"). Green baize
# in a padded leather rail and a polished rim, under a lamp; beyond it the parlor -- paneled wall, a sideboard with a
# decanter, sconces. On the baize the game's own dino cards (the shared card, as old prints) laid out in a GRID, as in
# the game, each lying flat in the table's perspective (placed by the 3-D camera) -- and among them, two that are THE
# SAME. A soft pool of light goes from card to card, looking; when it comes to the second of the two, both glow, rise
# off the baize and stand up toward you side by side, a moment, and lie back down in their places. The table and room
# are baked (`menu_table.webp`, `menu_table_d.webp`); the cards load on threads and fade in as their photos arrive.
# Made up, never the board.

const CARD: GDScript = preload("res://shared/scripts/card.gd")
const COLS: int = 4
const ROWS: int = 4
const CW: float = 122.0                 # a card's size on the table (units)
const CH: float = 172.0
const PITCH: Vector2 = Vector2(146.0, 198.0)
const GRID_Z: float = -60.0            # the grid's center
# the pictures, row by row: THREE COUPLES among them, found one after another (the user: more couples, and hardly a
# moment with none picked out) -- cards 5 and 14, 12 and 2, 3 and 8
const PICS: Array = [3, 14, 8, 27, 11, 21, 19, 5, 27, 30, 33, 9, 8, 36, 21, 40]
const PAIRS: Array = [[5, 14], [12, 2], [3, 8]]
const ROUND: float = 2.6                # one couple: the light finds it, it rises and meets, lies back down
const CYCLE: float = 7.8
# each round's quick search: a card it glances at, then the couple's first and second
const GLANCE: Array = [9, 6, 15]

var _layer: Node2D = null
var _under: Control = null
var _cards: Array = []
var _pending: Dictionary = {}       # path -> [card indexes]

func _setup() -> void:
	super._setup()
	if bake_mode:
		return
	_under = Control.new()
	_under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_under.set_anchors_preset(Control.PRESET_FULL_RECT)
	_under.draw.connect(func() -> void: _draw_under(_under))
	add_child(_under)
	_layer = Node2D.new()
	add_child(_layer)
	if _top != null:
		move_child(_top, get_child_count() - 1)

func _make_cards(n: int) -> void:
	for _i in n:
		if _cards.size() >= PICS.size():
			return
		var k: int = _cards.size()
		var c: Node2D = CARD.new()
		_layer.add_child(c)
		c.call("set_frame", 8, 8)
		# a couple's two prints are never scorched alike (that would give them away): opposite sides
		var side: int = k % 4
		for pr in PAIRS:
			if (pr as Array)[1] == k:
				side = ((pr as Array)[0] % 4 + 2) % 4
		c.set("burn_side", side)
		c.call("set_photo", true)
		c.visible = false
		_cards.append(c)
		var p: String = "res://art/dinos/dino%d.jpg" % int(PICS[k])
		if ResourceLoader.exists(p):
			if not _pending.has(p):
				_pending[p] = []
				ResourceLoader.load_threaded_request(p)
			(_pending[p] as Array).append(k)

func _home(k: int) -> Vector3:
	var col: int = k % COLS
	var row: int = k / COLS
	return Vector3((float(col) - (COLS - 1) * 0.5) * PITCH.x, 1.0, GRID_Z + (float(row) - (ROWS - 1) * 0.5) * PITCH.y)

# where card k's center is, how far it has stood up (0 flat, 1 up), how much it glows
func _pose(k: int) -> Array:
	var c: Vector3 = _home(k)
	var stand: float = 0.0
	var glow_k: float = 0.0
	for r in PAIRS.size():
		var pi: int = (PAIRS[r] as Array).find(k)
		if pi < 0:
			continue
		var v: float = fmod(t, CYCLE) - float(r) * ROUND
		if v < -1.0:
			v += CYCLE
		# picked out almost at once, up and meeting for most of the round, down as the next couple rises
		glow_k = smoothstep(0.25, 0.45, v) * (1.0 - smoothstep(2.4, 2.8, v))
		var go: float = smoothstep(0.3, 0.8, v) * (1.0 - smoothstep(2.0, 2.5, v))
		var meet: Vector3 = Vector3((-0.56 if pi == 0 else 0.56) * CW * 1.1, 170.0, GRID_Z + 120.0)
		c = c.lerp(meet, go)
		stand = go
	return [c, stand, glow_k]

# the card's plane on the screen: an affine map of its local pixels (x across, y down from its top edge) taken from the
# 3-D camera at its center -- so it lies in the table's perspective, or stands up toward you
func _card_xform(c: Vector3, stand: float, w_px: float, h_px: float) -> Transform2D:
	var a: float = deg_to_rad(78.0) * stand
	var down: Vector3 = Vector3(0.0, -sin(a), cos(a))
	var top_c: Vector3 = c - down * CH * 0.5
	var o: Vector2 = screen_of(top_c)
	var ex: Vector2 = (screen_of(top_c + Vector3(CW * 0.5, 0.0, 0.0)) - o) / (w_px * 0.5)
	var ey: Vector2 = (screen_of(top_c + down * CH * 0.5) - o) / (h_px * 0.5)
	return Transform2D(ex, ey, o)

func _tick(delta: float) -> void:
	super._tick(delta)
	if bake_mode or _layer == null:
		return
	_make_cards(3)
	for path in _pending.keys():
		var st: int = ResourceLoader.load_threaded_get_status(path)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			var tex: Texture2D = ResourceLoader.load_threaded_get(path)
			for k in _pending[path]:
				var cc: Node2D = _cards[k]
				cc.set("fit", 1)
				cc.set("fixed_aspect", CH / CW)
				cc.call("setup", tex, Color(1, 1, 1))
				cc.call("set_width", 200.0)
				cc.set_meta("photo", true)
				cc.modulate.a = 0.0
			_pending.erase(path)
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_pending.erase(path)
	# the standing pair drawn over the rest
	for k in _cards.size():
		var c: Node2D = _cards[k]
		if not c.has_meta("photo"):
			continue
		c.visible = true
		c.modulate.a = fade_in(true, c.modulate.a, delta)
		var pose: Array = _pose(k)
		c.transform = _card_xform(pose[0], pose[1], 200.0, float(c.call("card_height")))
		c.z_index = 10 if float(pose[1]) > 0.02 else 0
	_under.queue_redraw()

# under the cards: each card's contact shadow on the baize (spreading and paling as the pair rises), the light pool
# that searches the grid, and the couple's glow
func _draw_under(d: Control) -> void:
	var u: float = fmod(t, CYCLE)
	# THE SEARCHING LIGHT: quick -- from the last couple to a card it glances at, to this couple's first, its second
	var r: int = int(u / ROUND)
	var v: float = u - float(r) * ROUND
	var prev: int = (PAIRS[(r + PAIRS.size() - 1) % PAIRS.size()] as Array)[1]
	var hops: Array = [prev, GLANCE[r], (PAIRS[r] as Array)[0], (PAIRS[r] as Array)[1]]
	var hop_t: float = 0.1
	var hi: int = clampi(int(v / hop_t), 0, hops.size() - 2)
	var hu: float = smoothstep(0.1, 0.9, (v - float(hi) * hop_t) / hop_t)
	var at: Vector3 = _home(hops[hi]).lerp(_home(hops[hi + 1]), hu) if v < hop_t * 3.0 else _home(hops[3])
	var seek: float = 1.0 - smoothstep(0.35, 0.6, v)
	if seek > 0.0:
		_pool(d, at, 120.0, Color(1.0, 0.92, 0.70, 0.30 * seek))
	for k in _cards.size():
		var c: Node2D = _cards[k]
		if not c.visible:
			continue
		var pose: Array = _pose(k)
		var stand: float = pose[1]
		var ground: Vector3 = Vector3((pose[0] as Vector3).x, 0.5, (pose[0] as Vector3).z)
		# a contact shadow: the card's footprint, offset away from the lamp, soft
		var sh_a: float = (0.32 - 0.20 * stand) * c.modulate.a
		var grow: float = 6.0 + 40.0 * stand
		var pts: PackedVector2Array = PackedVector2Array()
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			pts.append(screen_of(ground + Vector3(corner.x * (CW * 0.5 + grow) + 6.0, 0.0, corner.y * (CH * 0.5 + grow) * (1.0 - 0.6 * stand) + 10.0 + 40.0 * stand)))
		d.draw_colored_polygon(pts, Color(0.0, 0.03, 0.01, sh_a))
		if float(pose[2]) > 0.0:
			_pool(d, ground, 110.0 + 30.0 * stand, Color(1.0, 0.82, 0.40, 0.40 * float(pose[2]) * (0.8 + 0.2 * sin(t * 5.0))))

var _glow_tex: Texture2D = null

# a soft pool of light lying on the baize round a point
func _pool(d: Control, at: Vector3, r: float, col: Color) -> void:
	if _glow_tex == null:
		var gt: GradientTexture2D = GradientTexture2D.new()
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.5, Color(1, 1, 1, 0.45))
		gt.gradient = g
		_glow_tex = gt
	var o: Vector2 = screen_of(at)
	var rx: float = screen_of(at + Vector3(r, 0.0, 0.0)).distance_to(o)
	var rz: float = screen_of(at + Vector3(0.0, 0.0, r)).distance_to(o)
	d.draw_texture_rect(_glow_tex, Rect2(o - Vector2(rx, rz), Vector2(rx, rz) * 2.0), false, col)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Couples", "Find the two identical cards", Color(1.0, 0.88, 0.55), Color(0.06, 0.12, 0.06),
		Color(1.0, 0.85, 0.45, 0.22))

# --- the table: real 3-D, baked -------------------------------------------------------------------------------

func _baked_path() -> String:
	return "res://couples/art/menu_table.webp" if mobile else "res://couples/art/menu_table_d.webp"

func _eye() -> Vector3:
	return Vector3(0.0, 760.0, 560.0) if mobile else Vector3(0.0, 900.0, 900.0)

func _aim() -> Vector3:
	return Vector3(0.0, 0.0, -110.0) if mobile else Vector3(0.0, -40.0, -130.0)

func _fov() -> float:
	return 54.0

func _environment(env: Environment) -> void:
	env.background_color = Color(0.03, 0.03, 0.03)
	env.ambient_light_color = Color(0.55, 0.60, 0.55)
	env.ambient_light_energy = 0.30

func _build_lights() -> void:
	# the lamp hanging over the table: a warm pool on the felt, falling off into the dark at its edges
	spot(Vector3(0.0, 760.0, 80.0), Vector3(0.0, 0.0, 60.0), Color(1.0, 0.88, 0.66), 7.0, 1800.0, 50.0, true)
	light(Vector3(0.0, 500.0, 0.0), Color(1.0, 0.86, 0.62), 0.6, 1200.0)

func _felt(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			# a woven nap: a fine diagonal twill, fibres catching the light at random
			var twill: float = 0.5 + 0.5 * sin(float(x + y) * 1.6)
			var c: Color = Color(0.07, 0.30, 0.17).lerp(Color(0.10, 0.36, 0.21), twill * 0.6 + 0.4 * h01(x * 13 + y * 7))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _leather(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var grain: float = h01(x * 5 + y * 3) * 0.5 + h01((x / 3) * 11 + (y / 3) * 7) * 0.5
			img.set_pixel(x, y, Color(0.20, 0.09, 0.05).lerp(Color(0.32, 0.15, 0.08), grain))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _chip_edge(n: int, base: Color) -> ImageTexture:
	var img: Image = Image.create(n, 4, false, Image.FORMAT_RGB8)
	for x in n:
		img.fill_rect(Rect2i(x, 0, 1, 4), Color(0.95, 0.94, 0.90) if (x * 8 / n) % 2 == 0 else base)
	return ImageTexture.create_from_image(img)

func _build_still() -> void:
	# THE BAIZE: green felt with its woven nap; the table's far end and the parlor beyond it
	box(Vector3(940.0, 6.0, 1400.0), mat(Color.WHITE, 0.95, 0.0, _felt(128), Vector3(6, 9, 1)), Vector3(0.0, -3.0, -100.0))
	_parlor()
	# THE RAILS at the sides: a padded leather bumper, a polished wooden rim with a rounded edge outside it
	var leather: StandardMaterial3D = mat(Color.WHITE, 0.5, 0.0, _leather(64), Vector3(1, 20, 1))
	leather.clearcoat_enabled = true
	leather.clearcoat = 0.4
	var wood: StandardMaterial3D = mat(Color.WHITE, 0.25, 0.0, tex_wood(128, Color(0.36, 0.17, 0.08), 5), Vector3(1, 12, 1))
	wood.clearcoat_enabled = true
	wood.clearcoat = 0.8
	for sx in [-1.0, 1.0]:
		cyl(30.0, 30.0, 1400.0, leather, Vector3(sx * 425.0, 18.0, -100.0), Vector3(90.0, 0.0, 0.0), null, 32)
		box(Vector3(80.0, 30.0, 1400.0), wood, Vector3(sx * 490.0, 10.0, -100.0))
		cyl(15.0, 15.0, 1400.0, wood, Vector3(sx * 530.0, 10.0, -100.0), Vector3(90.0, 0.0, 0.0), null, 24)
	# the far end's rail, and the table's apron and legs below the rim
	cyl(30.0, 30.0, 880.0, leather, Vector3(0.0, 18.0, -800.0), Vector3(0.0, 0.0, 90.0), null, 32)
	box(Vector3(1060.0, 30.0, 80.0), wood, Vector3(0.0, 10.0, -865.0))
	box(Vector3(1040.0, 90.0, 20.0), wood, Vector3(0.0, -60.0, -895.0))
	# ON THE FELT, clear of the cards: stacks of chips by the left rail, a card box by the right, a few loose chips
	var chip_cols: Array = [Color(0.80, 0.12, 0.12), Color(0.12, 0.25, 0.70), Color(0.12, 0.12, 0.12)]
	for st in 3:
		var base: Vector3 = Vector3(-350.0 + float(st) * 34.0, 0.0, -430.0 + float(st % 2) * 30.0)
		var cm: StandardMaterial3D = mat(Color.WHITE, 0.35, 0.0, _chip_edge(64, chip_cols[st]))
		var top_m: StandardMaterial3D = mat(chip_cols[st], 0.35)
		for c in 6 + st * 2:
			cyl(16.0, 16.0, 3.4, cm, base + Vector3(sin(float(c)) * 0.8, 1.7 + float(c) * 3.5, cos(float(c)) * 0.8), Vector3.ZERO, null, 28)
		cyl(12.0, 12.0, 0.4, top_m, base + Vector3(0.0, 3.6 + float(5 + st * 2) * 3.5, 0.0), Vector3.ZERO, null, 28)
	for lc in 3:
		cyl(16.0, 16.0, 3.4, mat(Color.WHITE, 0.35, 0.0, _chip_edge(64, chip_cols[lc])), Vector3(-250.0 + float(lc) * 40.0, 1.7, -470.0 + float(lc) * 26.0), Vector3(0.0, float(lc) * 20.0, 0.0), null, 28)
	var deck_box: StandardMaterial3D = mat(Color(0.55, 0.08, 0.10), 0.4)
	box(Vector3(70.0, 22.0, 100.0), deck_box, Vector3(330.0, 11.0, -560.0), Vector3(0.0, 12.0, 0.0))
	box(Vector3(56.0, 0.6, 86.0), mat(Color(0.92, 0.82, 0.55), 0.4, 0.5), Vector3(330.0, 22.4, -560.0), Vector3(0.0, 12.0, 0.0))

# THE PARLOR beyond the table: a paneled wall in dark oak under a deep red damask, a SIDEBOARD with a decanter and
# glasses, a pair of brass sconces glowing, a framed landscape, the floor's boards and a rug's edge
func _parlor() -> void:
	var oak: StandardMaterial3D = mat(Color.WHITE, 0.35, 0.0, tex_wood(128, Color(0.24, 0.12, 0.06), 11), Vector3(4, 1, 1))
	var brass: StandardMaterial3D = mat(Color(0.88, 0.68, 0.30), 0.25, 0.85)
	var wall_z: float = -1180.0
	box(Vector3(3000.0, 3.0, 2000.0), mat(Color.WHITE, 0.5, 0.0, tex_wood(128, Color(0.26, 0.15, 0.08), 7), Vector3(14, 10, 1)), Vector3(0.0, -180.0, -400.0))
	box(Vector3(3000.0, 1400.0, 6.0), mat(Color(0.30, 0.07, 0.08), 0.85), Vector3(0.0, 400.0, wall_z))
	box(Vector3(3000.0, 300.0, 10.0), oak, Vector3(0.0, -30.0, wall_z + 4.0))
	for pn in 10:
		box(Vector3(200.0, 200.0, 3.0), oak, Vector3(-1100.0 + float(pn) * 250.0, -30.0, wall_z + 11.0))
	box(Vector3(3000.0, 12.0, 18.0), oak, Vector3(0.0, 124.0, wall_z + 8.0))
	# the sideboard, the decanter and two glasses on it
	box(Vector3(520.0, 160.0, 90.0), oak, Vector3(0.0, -100.0, wall_z + 60.0))
	box(Vector3(540.0, 10.0, 100.0), oak, Vector3(0.0, -15.0, wall_z + 60.0))
	var crystal: StandardMaterial3D = mat(Color(0.85, 0.90, 0.95, 0.35), 0.03, 0.3)
	cyl(26.0, 32.0, 70.0, crystal, Vector3(-110.0, 25.0, wall_z + 60.0), Vector3.ZERO, null, 24)
	cyl(10.0, 24.0, 30.0, crystal, Vector3(-110.0, 75.0, wall_z + 60.0), Vector3.ZERO, null, 24)
	sphere(13.0, crystal, Vector3(-110.0, 100.0, wall_z + 60.0))
	cyl(24.0, 30.0, 40.0, mat(Color(0.55, 0.20, 0.06, 0.8), 0.1), Vector3(-110.0, 12.0, wall_z + 60.0), Vector3.ZERO, null, 24)
	for gl in 2:
		cyl(14.0, 10.0, 34.0, crystal, Vector3(-30.0 + float(gl) * 46.0, 7.0, wall_z + 70.0), Vector3.ZERO, null, 20)
	# a mirror in a gilt frame low over it, the sconces either side
	box(Vector3(300.0, 110.0, 8.0), brass, Vector3(0.0, 70.0, wall_z + 8.0))
	box(Vector3(276.0, 90.0, 2.0), mat(Color(0.30, 0.26, 0.24), 0.05, 0.8), Vector3(0.0, 70.0, wall_z + 13.0))
	for sx in [-1.0, 1.0]:
		var sc: Vector3 = Vector3(sx * 300.0, 300.0, wall_z + 10.0)
		cyl(10.0, 10.0, 4.0, brass, sc, Vector3(90.0, 0.0, 0.0), null, 20)
		cyl(16.0, 9.0, 30.0, glow(Color(1.0, 0.82, 0.55)), sc + Vector3(0.0, 24.0, 26.0), Vector3.ZERO, null, 20)
		light(sc + Vector3(0.0, 30.0, 70.0), Color(1.0, 0.80, 0.55), 1.4, 420.0)

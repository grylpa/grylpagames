extends "res://scripts/menu_poster3d.gd"

# COUPLES' OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A NATURALIST'S
# WORKTABLE AT NIGHT, seen across it (it was a flat top-down view of scattered cards -- the user: "boring"; then a card
# table in a parlor, green baize and chips -- "stay as far from anything that remotely suggests gambling as possible",
# 2026-11-20). A long oak table of planks under a lamp, an ammonite, fossil brushes, a brass magnifier and a field
# notebook at its edges; beyond it the study -- paneled wall, a bookcase of old volumes with a fossil skull and a globe,
# sconces. On the table the game's own dino cards (the shared card, as old prints) laid out in a GRID, as in
# the game, each lying flat in the table's perspective (placed by the 3-D camera) -- and among them, two that are THE
# SAME. A soft pool of light goes from card to card, looking; when it comes to the second of the two, both glow, rise
# off the table and stand up toward you side by side, a moment, and lie back down in their places. The table and room
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
const ROUND: float = 4.2                # one couple: the light finds it, it rises and meets, lies back down
const CYCLE: float = 12.6
# THE SEARCH, slow enough to follow (it hopped card to card in 0.1 s -- the user: "a brief flash ... too brief and
# minimal to understand", 2026-11-20): the light GLIDES to a card in SEARCH_GLIDE and RESTS on it SEARCH_REST -- a
# card it glances at, the couple's first (which lights), its second (which lights) -- then the two rise
const SEARCH_GLIDE: float = 0.45
const SEARCH_REST: float = 0.3
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
		# each lights as the light comes to rest on it; both rise once the second is found, meet for most of the round,
		# and lie back down as the next search begins
		var lit_at: float = (SEARCH_GLIDE + SEARCH_REST) * float(pi + 1) + SEARCH_GLIDE
		glow_k = smoothstep(lit_at - 0.05, lit_at + 0.15, v) * (1.0 - smoothstep(4.0, 4.4, v))
		var go: float = smoothstep(2.25, 2.75, v) * (1.0 - smoothstep(3.7, 4.2, v))
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
	var srch: Array = _search()
	for k in _cards.size():
		var c: Node2D = _cards[k]
		if not c.has_meta("photo"):
			continue
		c.visible = true
		c.modulate.a = fade_in(true, c.modulate.a, delta)
		var pose: Array = _pose(k)
		c.transform = _card_xform(pose[0], pose[1], 200.0, float(c.call("card_height")))
		# the light on it: the searching light passing over, or its own once found -- warmer and brighter
		var lit: float = _card_light(k, srch, float(pose[2]))
		c.modulate = Color(1.0 + 0.30 * lit, 1.0 + 0.24 * lit, 1.0 + 0.12 * lit, c.modulate.a)
		c.z_index = 10 if float(pose[1]) > 0.02 else 0
	_under.queue_redraw()

# under the cards: each card's contact shadow on the table (spreading and paling as the pair rises), the light pool
# that searches the grid, and the couple's glow
# THE SEARCHING LIGHT now: where it is on the table and how strong -- from the last couple to a card it glances at, to
# this couple's first, its second, gliding and resting on each
func _search() -> Array:
	var u: float = fmod(t, CYCLE)
	var r: int = int(u / ROUND)
	var v: float = u - float(r) * ROUND
	var prev: int = (PAIRS[(r + PAIRS.size() - 1) % PAIRS.size()] as Array)[1]
	var hops: Array = [prev, GLANCE[r], (PAIRS[r] as Array)[0], (PAIRS[r] as Array)[1]]
	var step: float = SEARCH_GLIDE + SEARCH_REST
	var hi: int = clampi(int(floor(v / step)), 0, hops.size() - 2)
	var hu: float = smoothstep(0.0, 1.0, clampf((v - float(hi) * step) / SEARCH_GLIDE, 0.0, 1.0))
	var at: Vector3 = _home(hops[hi]).lerp(_home(hops[hi + 1]), hu) if v < step * 3.0 else _home(hops[3])
	# the light shows from the start of the search and fades as the couple rises
	var seek: float = smoothstep(0.0, 0.15, v) * (1.0 - smoothstep(2.3, 2.7, v))
	return [at, seek]

# how much light falls on card k: the searching light where it is over the card, or the card's own glow once found
func _card_light(k: int, srch: Array, glow_k: float) -> float:
	var at: Vector3 = srch[0]
	var h: Vector3 = _home(k)
	var near: float = 1.0 - smoothstep(50.0, 110.0, Vector2(h.x - at.x, h.z - at.z).length())
	return maxf(float(srch[1]) * near, glow_k)

func _draw_under(d: Control) -> void:
	# the searching light's pool on the table, round the card it lights (the card itself is brightened: _tick)
	var srch: Array = _search()
	if float(srch[1]) > 0.0:
		_pool(d, srch[0], 150.0, Color(1.0, 0.92, 0.70, 0.40 * float(srch[1])))
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
		d.draw_colored_polygon(pts, Color(0.04, 0.02, 0.0, sh_a))
		if float(pose[2]) > 0.0:
			_halo(d, c, float(pose[2]) * (0.85 + 0.15 * sin(t * 5.0)))

# A FOUND CARD'S HALO: a soft gold glow round its edge, showing beyond the card (drawn under it) -- lying or standing
func _halo(d: Control, c: Node2D, a: float) -> void:
	var h: float = float(c.call("card_height"))
	var xf: Transform2D = c.transform
	var corners: Array = [xf * Vector2(-100.0, 0.0), xf * Vector2(100.0, 0.0), xf * Vector2(100.0, h), xf * Vector2(-100.0, h)]
	var mid: Vector2 = (corners[0] + corners[2]) * 0.5
	var gold_in: Color = Color(1.0, 0.80, 0.36, 0.75 * a)
	var gold_out: Color = Color(1.0, 0.80, 0.36, 0.0)
	for i in 4:
		var p0: Vector2 = corners[i]
		var p1: Vector2 = corners[(i + 1) % 4]
		var o0: Vector2 = p0 + (p0 - mid).normalized() * 26.0
		var o1: Vector2 = p1 + (p1 - mid).normalized() * 26.0
		d.draw_polygon(PackedVector2Array([p0, p1, o1, o0]), PackedColorArray([gold_in, gold_in, gold_out, gold_out]))

var _glow_tex: Texture2D = null

# a soft pool of light lying on the table round a point
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
	title("Couples", "Find the two identical cards", Color(1.0, 0.88, 0.55), Color(0.12, 0.07, 0.03),
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
	# the lamp hanging over the table: a warm pool on the oak, falling off into the dark at its edges
	spot(Vector3(0.0, 760.0, 80.0), Vector3(0.0, 0.0, 60.0), Color(1.0, 0.88, 0.66), 7.0, 1800.0, 50.0, true)
	light(Vector3(0.0, 500.0, 0.0), Color(1.0, 0.86, 0.62), 0.6, 1200.0)

# THE TABLE'S PLANKS: four boards across the picture, each its own tone and grain (running along the board), a dark
# seam between, a knot here and there, a little wear down the middle of each
func _planks(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var boards: int = 4
	var bw: int = floori(float(n) / float(boards))
	for x in n:
		var b: int = floori(float(x) / float(bw))
		var bx: float = float(x - b * bw) / float(bw)
		var tone: float = 0.86 + 0.22 * h01(b * 31 + 5)
		var seam: float = 1.0 - 0.55 * (1.0 - smoothstep(0.0, 0.035, minf(bx, 1.0 - bx)))
		for y in n:
			# THE GRAIN: long fibres running down the board (each column its own shade), drifting slowly sideways, and
			# a few broad growth rings; every wave a whole number of turns down the picture, so it repeats without a seam
			var yy: float = TAU * float(y) / float(n)
			var drift: float = 3.0 * sin(yy + float(b) * 1.7) + 1.5 * sin(yy * 2.0 + float(b) * 0.6)
			var fx: int = int(floor(float(x) + drift))
			var fibre: float = h01(b * 1013 + fx) * 0.6 + h01(b * 2027 + floori(float(fx) / 3.0)) * 0.4
			var ring: float = 0.5 + 0.5 * sin((float(x) + drift * 2.2) * 0.18 + float(b) * 2.0)
			var knot: float = 1.0 - 0.22 * maxf(0.0, 1.0 - Vector2((bx - 0.6) * 1.0, (float(y) / float(n) - h01(b * 7 + 1)) * 0.5).length() * 10.0)
			var k: float = tone * (0.84 + 0.10 * fibre + 0.08 * ring) * seam * knot + (h01(b * 977 + y * n + x) - 0.5) * 0.03
			var wear: float = 0.05 * (1.0 - absf(bx - 0.5) * 2.0)
			img.set_pixel(x, y, Color(0.42 * k + wear, 0.25 * k + wear * 0.7, 0.12 * k + wear * 0.4))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# AN AMMONITE'S FACE: the coiled shell's whorls (a logarithmic spiral) crossed by its ribs, each groove shaded from the
# lamp's side
func _ammonite(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p: Vector2 = (Vector2(float(x), float(y)) + Vector2(0.5, 0.5)) / float(n) * 2.0 - Vector2.ONE
			var r: float = p.length()
			if r > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var th: float = atan2(p.y, p.x)
			var whorl: float = fposmod(log(maxf(r, 0.02)) / 0.42 - th / TAU, 1.0)
			var rib: float = 0.5 + 0.5 * cos(th * 26.0 + log(maxf(r, 0.02)) * 9.0)
			var groove: float = smoothstep(0.0, 0.12, whorl) * (1.0 - smoothstep(0.86, 1.0, whorl))
			var lit: float = 0.62 + 0.30 * groove * (0.75 + 0.25 * rib) + 0.12 * p.dot(Vector2(-0.6, -0.8))
			var c: Color = Color(0.78, 0.68, 0.52) * lit
			c = c.lerp(Color(0.45, 0.36, 0.26), 0.25 * h01(x * 13 + y * 71))
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
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

func _build_still() -> void:
	# THE TABLE: a long top of oak planks running away from us, its edge rounded, an apron and legs below
	# (the planks on a plane of their own: a box spreads its texture over its six faces)
	var oak_top: StandardMaterial3D = mat(Color.WHITE, 0.62, 0.0, _planks(256), Vector3(2.0, 2.0, 1.0))
	oak_top.clearcoat_enabled = true
	oak_top.clearcoat = 0.15
	oak_top.clearcoat_roughness = 0.7
	box(Vector3(1040.0, 36.0, 1500.0), mat(Color(0.30, 0.17, 0.08), 0.7), Vector3(0.0, -18.2, -100.0))
	var top_plane: PlaneMesh = PlaneMesh.new()
	top_plane.size = Vector2(1040.0, 1500.0)
	put(top_plane, oak_top, Vector3(0.0, 0.0, -100.0))
	var edge: StandardMaterial3D = mat(Color.WHITE, 0.45, 0.0, tex_wood(128, Color(0.36, 0.20, 0.09), 5), Vector3(1, 12, 1))
	for sx in [-1.0, 1.0]:
		cyl(18.0, 18.0, 1500.0, edge, Vector3(sx * 520.0, -18.0, -100.0), Vector3(90.0, 0.0, 0.0), null, 24)
	cyl(18.0, 18.0, 1040.0, edge, Vector3(0.0, -18.0, -850.0), Vector3(0.0, 0.0, 90.0), null, 24)
	box(Vector3(980.0, 90.0, 20.0), edge, Vector3(0.0, -80.0, -830.0))
	for lx in [-1.0, 1.0]:
		box(Vector3(60.0, 400.0, 60.0), edge, Vector3(lx * 450.0, -240.0, -800.0))
	_study()
	# ON THE TABLE, clear of the cards: an ammonite and two fossil brushes at the left, a brass magnifier and a field
	# notebook with its pencil at the right
	var stone: StandardMaterial3D = mat(Color.WHITE, 0.85, 0.0, tex_speckle(64, Color(0.62, 0.54, 0.42), 0.25, 3))
	cyl(54.0, 60.0, 20.0, stone, Vector3(-420.0, 10.0, -640.0), Vector3(0.0, 25.0, 0.0), null, 40)
	var face: StandardMaterial3D = mat(Color.WHITE, 0.7, 0.0, _ammonite(128))
	face.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	put(_disc_mesh(53.0), face, Vector3(-420.0, 20.3, -640.0), Vector3(0.0, 25.0, 0.0))
	var handle_w: StandardMaterial3D = mat(Color.WHITE, 0.4, 0.0, tex_wood(64, Color(0.48, 0.28, 0.12), 17), Vector3(1, 4, 1))
	var brass: StandardMaterial3D = mat(Color(0.88, 0.68, 0.30), 0.28, 0.85)
	var bristle: StandardMaterial3D = mat(Color(0.86, 0.80, 0.66), 0.9)
	for bi in 2:
		var br: Node3D = Node3D.new()
		root.add_child(br)
		br.position = Vector3(-440.0 + float(bi) * 34.0, 0.0, -420.0 + float(bi) * 20.0)
		br.rotation_degrees = Vector3(0.0, 8.0 + float(bi) * 14.0, 0.0)
		var hr: float = 6.0 - float(bi)
		cyl(hr - 1.0, hr, 120.0, handle_w, Vector3(0.0, hr, 0.0), Vector3(90.0, 0.0, 0.0), br, 16)
		cyl(hr + 1.0, hr + 1.0, 18.0, brass, Vector3(0.0, hr + 1.0, 68.0), Vector3(90.0, 0.0, 0.0), br, 16)
		cyl(hr + 3.0, hr + 1.0, 24.0, bristle, Vector3(0.0, hr + 3.0, 88.0), Vector3(90.0, 0.0, 0.0), br, 16)
	# the magnifier: a brass ring round its lens, a turned wooden handle with a brass ferrule
	var mag: Node3D = Node3D.new()
	root.add_child(mag)
	mag.position = Vector3(440.0, 0.0, -380.0)
	mag.rotation_degrees = Vector3(0.0, -30.0, 0.0)
	var ring: PackedVector3Array = PackedVector3Array()
	for k in 33:
		var a: float = TAU * float(k) / 32.0
		ring.append(Vector3(cos(a) * 44.0, 6.0, sin(a) * 44.0))
	put(tube_mesh(ring, 4.5, 12), brass, Vector3.ZERO, Vector3.ZERO, mag)
	var lens: StandardMaterial3D = mat(Color(0.88, 0.94, 1.0, 0.22), 0.02, 0.2)
	cyl(43.0, 43.0, 3.0, lens, Vector3(0.0, 6.0, 0.0), Vector3.ZERO, mag, 40).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cyl(6.0, 6.0, 16.0, brass, Vector3(54.0, 6.0, 0.0), Vector3(0.0, 0.0, 90.0), mag, 16)
	cyl(6.5, 8.0, 90.0, handle_w, Vector3(107.0, 8.0, 0.0), Vector3(0.0, 0.0, 90.0), mag, 16)
	# the notebook: leather boards, the page block's pale edge, its band, and a pencil beside it
	var nb: Node3D = Node3D.new()
	root.add_child(nb)
	nb.position = Vector3(410.0, 0.0, -660.0)
	nb.rotation_degrees = Vector3(0.0, 12.0, 0.0)
	var leather: StandardMaterial3D = mat(Color.WHITE, 0.6, 0.0, _leather(64), Vector3(2, 2, 1))
	box(Vector3(110.0, 3.0, 150.0), leather, Vector3(0.0, 1.5, 0.0), Vector3.ZERO, nb)
	box(Vector3(104.0, 14.0, 144.0), mat(Color(0.90, 0.85, 0.72), 0.9), Vector3(2.0, 10.0, 0.0), Vector3.ZERO, nb)
	box(Vector3(110.0, 3.0, 150.0), leather, Vector3(0.0, 18.5, 0.0), Vector3.ZERO, nb)
	box(Vector3(6.0, 21.0, 152.0), mat(Color(0.12, 0.10, 0.09), 0.7), Vector3(38.0, 10.5, 0.0), Vector3.ZERO, nb)
	cyl(3.5, 3.5, 140.0, mat(Color(0.20, 0.32, 0.20), 0.5), Vector3(-80.0, 3.5, 10.0), Vector3(90.0, 0.0, 0.0), nb, 6)
	cyl(0.6, 3.5, 12.0, mat(Color(0.85, 0.70, 0.50), 0.8), Vector3(-80.0, 3.5, 86.0), Vector3(90.0, 0.0, 0.0), nb, 12)

# a flat disc lying face up (the ammonite's face), its texture across it
func _disc_mesh(r: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs: int = 48
	for k in segs:
		var a0: float = TAU * float(k) / float(segs)
		var a1: float = TAU * float(k + 1) / float(segs)
		for pt in [Vector2.ZERO, Vector2(cos(a1), sin(a1)), Vector2(cos(a0), sin(a0))]:
			st.set_normal(Vector3.UP)
			st.set_uv(pt * 0.5 + Vector2(0.5, 0.5))
			st.add_vertex(Vector3(pt.x * r, 0.0, pt.y * r))
	return st.commit()

# THE STUDY beyond the table: a paneled wall in dark oak under deep green plaster, a BOOKCASE of old volumes in worn
# leather with gilt bands, a fossil skull and a globe on its shelves, a pair of brass sconces glowing
func _study() -> void:
	var oak: StandardMaterial3D = mat(Color.WHITE, 0.35, 0.0, tex_wood(128, Color(0.24, 0.12, 0.06), 11), Vector3(4, 1, 1))
	var brass: StandardMaterial3D = mat(Color(0.88, 0.68, 0.30), 0.25, 0.85)
	var wall_z: float = -1180.0
	box(Vector3(3000.0, 3.0, 2000.0), mat(Color.WHITE, 0.5, 0.0, tex_wood(128, Color(0.26, 0.15, 0.08), 7), Vector3(14, 10, 1)), Vector3(0.0, -180.0, -400.0))
	box(Vector3(3000.0, 1400.0, 6.0), mat(Color.WHITE, 0.9, 0.0, tex_speckle(64, Color(0.17, 0.22, 0.18), 0.08, 9), Vector3(12, 6, 1)), Vector3(0.0, 400.0, wall_z))
	box(Vector3(3000.0, 300.0, 10.0), oak, Vector3(0.0, -30.0, wall_z + 4.0))
	for pn in 10:
		box(Vector3(200.0, 200.0, 3.0), oak, Vector3(-1100.0 + float(pn) * 250.0, -30.0, wall_z + 11.0))
	box(Vector3(3000.0, 12.0, 18.0), oak, Vector3(0.0, 124.0, wall_z + 8.0))
	# the bookcase: sides, a cornice, a back, shelves, and the books on them -- each its own height, thickness and
	# leather, gilt bands across its spine, now and then one leaning
	var bc_z: float = wall_z + 60.0
	for sx in [-1.0, 1.0]:
		box(Vector3(24.0, 720.0, 110.0), oak, Vector3(sx * 380.0, 180.0, bc_z))
	box(Vector3(800.0, 30.0, 124.0), oak, Vector3(0.0, 550.0, bc_z + 4.0))
	box(Vector3(736.0, 700.0, 6.0), oak, Vector3(0.0, 180.0, bc_z - 52.0))
	var leathers: Array = [Color(0.36, 0.08, 0.07), Color(0.10, 0.20, 0.14), Color(0.10, 0.12, 0.24), Color(0.42, 0.26, 0.12), Color(0.12, 0.09, 0.08), Color(0.30, 0.22, 0.16)]
	var gilt: StandardMaterial3D = mat(Color(0.85, 0.66, 0.30), 0.35, 0.7)
	var shelf_ys: Array = [-160.0, 10.0, 180.0, 350.0]
	for si in shelf_ys.size():
		var sy: float = float(shelf_ys[si])
		box(Vector3(736.0, 14.0, 104.0), oak, Vector3(0.0, sy - 7.0, bc_z))
		var x: float = -360.0
		var k: int = si * 50
		while x < 350.0:
			k += 1
			# room left on two shelves for a specimen
			if (si == 1 and x > -80.0 and x < 80.0) or (si == 2 and x > 150.0 and x < 300.0):
				x += 20.0
				continue
			var th: float = 16.0 + 16.0 * h01(k * 3)
			var hh: float = 100.0 + 50.0 * h01(k * 3 + 1)
			var lean: float = 8.0 if h01(k * 3 + 2) > 0.93 else 0.0
			var col: Color = leathers[int(h01(k * 5 + 7) * float(leathers.size())) % leathers.size()]
			var bm: StandardMaterial3D = mat(col.lightened(0.08 * h01(k * 11)), 0.65)
			box(Vector3(th - 1.5, hh, 86.0), bm, Vector3(x + th * 0.5, sy + hh * 0.5, bc_z + 6.0), Vector3(0.0, 0.0, -lean))
			for gb in [0.18, 0.82]:
				box(Vector3(th - 1.0, 3.0, 1.0), gilt, Vector3(x + th * 0.5, sy + hh * float(gb), bc_z + 49.5), Vector3(0.0, 0.0, -lean))
			x += th + (6.0 if lean > 0.0 else 0.5)
	# a fossil skull on the second shelf on its plinth: a long snout, the eye's hollow, a row of teeth
	var bone: StandardMaterial3D = mat(Color.WHITE, 0.85, 0.0, tex_speckle(64, Color(0.70, 0.60, 0.46), 0.3, 21))
	var sk: Node3D = Node3D.new()
	root.add_child(sk)
	sk.position = Vector3(0.0, 10.0, bc_z + 10.0)
	sk.rotation_degrees = Vector3(0.0, -18.0, 0.0)
	box(Vector3(130.0, 8.0, 60.0), oak, Vector3(0.0, 4.0, 0.0), Vector3.ZERO, sk)
	cyl(26.0, 34.0, 70.0, bone, Vector3(-20.0, 42.0, 0.0), Vector3(0.0, 0.0, 90.0), sk, 20)
	cyl(14.0, 24.0, 60.0, bone, Vector3(42.0, 32.0, 0.0), Vector3(0.0, 0.0, 90.0), sk, 20)
	sphere(12.0, mat(Color(0.12, 0.09, 0.07), 0.9), Vector3(-26.0, 52.0, 22.0), sk)
	for tk in 6:
		cyl(0.5, 2.6, 9.0, mat(Color(0.86, 0.80, 0.66), 0.6), Vector3(22.0 + float(tk) * 8.0, 17.0, 14.0), Vector3(180.0, 0.0, 0.0), sk, 8)
	# a globe on the third shelf in its brass meridian, on a brass foot
	var gc: Vector3 = Vector3(225.0, 180.0 + 84.0, bc_z + 6.0)
	sphere(52.0, mat(Color.WHITE, 0.55, 0.0, tex_speckle(64, Color(0.62, 0.55, 0.36), 0.35, 33)), gc)
	var mer: PackedVector3Array = PackedVector3Array()
	for k2 in 33:
		var a2: float = TAU * float(k2) / 32.0
		mer.append(gc + Vector3(cos(a2) * 58.0, sin(a2) * 58.0, 0.0).rotated(Vector3(0, 0, 1), 0.4))
	put(tube_mesh(mer, 2.5, 8), brass, Vector3.ZERO)
	cyl(4.0, 4.0, 22.0, brass, gc + Vector3(0.0, -62.0, 0.0), Vector3.ZERO, null, 12)
	cyl(18.0, 26.0, 10.0, brass, gc + Vector3(0.0, -79.0, 0.0), Vector3.ZERO, null, 24)
	# the sconces either side
	for sx2 in [-1.0, 1.0]:
		var sc: Vector3 = Vector3(sx2 * 560.0, 300.0, wall_z + 10.0)
		cyl(10.0, 10.0, 4.0, brass, sc, Vector3(90.0, 0.0, 0.0), null, 20)
		cyl(16.0, 9.0, 30.0, glow(Color(1.0, 0.82, 0.55)), sc + Vector3(0.0, 24.0, 26.0), Vector3.ZERO, null, 20)
		light(sc + Vector3(0.0, 30.0, 70.0), Color(1.0, 0.80, 0.55), 1.4, 420.0)

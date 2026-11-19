extends "res://scripts/menu_poster3d.gd"

# FRIENDS' OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): AN EVENING STROLL
# DOWN A STREET OF TOWNHOUSES (2026-11-18, round 3; the user on the photos hung on a string before it: "the concept is
# stark. you hang people pictures to remember them" -- it read as a memorial wall). Three narrow houses side by side at
# dusk -- red brick, cream stucco with a rusticated ground floor, sage-green stucco -- their stone window surrounds,
# string courses, a dentiled cornice, chimney stacks against the evening sky; the cream house's front door up three
# steps between iron railings, bay trees in pots, a bicycle leaning on a railing, window boxes of geraniums, a cast-iron
# street lamp on the flagstone pavement. In six of the lit windows, ONE AT A TIME, a woman looks out (the photos, cut
# out, warmed by the room's light, shaded from the ceiling down, a sheen of glass over them): a window's curtains open
# on her, close, and the next window across the street opens on the next -- velvet, rose, navy, teal, moss, mustard. The street is baked, one picture per platform (`menu_houses.webp`, `menu_houses_d.webp`); the people, the
# curtains and the glass are live 2-D, each window's picture clipped to the part of its opening seen past the stone
# surround's soffit (`_visible_poly`), the photos loaded on threads. Made up, never the board.

# ONLY WOMEN at the windows (the user, 2026-11-19: with men among them, men's faces staring out of the dark houses, "it's a
# bit scary now"). The photos carry no gender, so they are named here -- each one CUT OUT of its studio backdrop, hair
# and all (`devtools/make_friends_cutouts.py` -> `art/menu_women/`): a fixed feathered ellipse round the head had cut
# into everyone's hair ("why do all those women look like you shaved their heads?")
const CUTOUTS: String = "res://friends/art/menu_women/%s.webp"
const WOMEN: Array = ["Barbara_Coleman", "Beverly_Mitchel", "Carolyn_Ramirez", "Eleni Makri", "Evelyn_Thompson",
	"Freja Nyberg", "Gladys_Rivera", "Helen_Stein", "Ingrid Holmgaard", "Irina Koval", "Katerina Theodorou",
	"Linnea Rautio", "Lucia_Moretti", "Marcia_Wallace", "Maria_Alvarez", "Maria Kyrgiou", "Molly_Bishop", "Naomi_Blake",
	"Natalia Rudnikova", "Patricia_O_Connor", "Tanya_Greene"]
const WIN_W: float = 96.0
const WIN_H: float = 150.0
const GLASS_Z: float = 0.5               # the glass, a little in front of the wall's face
const FRAME_Z: float = 11.0              # the surround's front: the opening's depth
# ONE window open at a time: its curtains open on a woman and, after the briefest hold (HOLD_S: the user, 2026-11-19 --
# "decrease the pause for when the curtains are open. to almost zero"), close; and the next window across the street
# opens LEAD_S before they quite meet (never a pause: the two eases' slow ends made a still moment between turns)
const OPEN_S: float = 0.6
const HOLD_S: float = 0.12
const CLOSE_S: float = 0.5
const TURN_S: float = OPEN_S + HOLD_S + CLOSE_S
const LEAD_S: float = 0.12
# the windows a woman comes to, IN TURN ORDER, and their curtains: [center x, sill y, curtain color] -- spread
# over both floors of all three houses, each turn jumping across the street (the user, 2026-11-19: "spread them out
# more, and only reveal one at a time"; five at once filled the middle row)
const FACES: Array = [
	[-240.0, 660.0, Color(0.10, 0.36, 0.40)],
	[240.0, 400.0, Color(0.78, 0.56, 0.16)],
	[-70.0, 400.0, Color(0.52, 0.07, 0.10)],
	[240.0, 660.0, Color(0.60, 0.30, 0.34)],
	[-240.0, 400.0, Color(0.30, 0.38, 0.22)],
	[70.0, 660.0, Color(0.16, 0.20, 0.38)],
]
# (every curtain OPAQUE cloth: two were lace, and closing they still showed the woman, who then vanished -- the user)
# every other window: [center x, sill y, kind] -- "lit": curtains drawn, glowing; "dark": the room unlit, the glass
# holding the sky; "box": dark, with a box of geraniums on its sill
const OTHERS: Array = [
	[-70.0, 660.0, "box"], [-390.0, 400.0, "lit"], [-390.0, 660.0, "dark"], [70.0, 400.0, "lit"],
	[390.0, 400.0, "dark"], [390.0, 660.0, "box"],
]

var _people: Array = []
var _tex: Dictionary = {}                # person -> Texture2D, once loaded
var _who: Array = []                     # the person in each face window now (-1: none yet)
var _closed: Array = []                  # each face window's curtains, 0 open .. 1 shut
var _layer: Control = null               # the rooms behind the glass
var _photo_layer: Control = null         # the people (cut out of their backdrops)
var _front: Control = null               # the curtains and the glass
const PERSON_W: float = 0.86             # a person's width in the window (a share of its width)
const PERSON_U: Array = [0.40, 0.58, 0.62, 0.38, 0.50, 0.55]    # where across each window the person stands

func _baked_path() -> String:
	return "res://friends/art/menu_houses.webp" if mobile else "res://friends/art/menu_houses_d.webp"

func _eye() -> Vector3:
	return Vector3(0.0, 330.0, 820.0) if mobile else Vector3(0.0, 380.0, 1080.0)

func _aim() -> Vector3:
	return Vector3(0.0, 470.0, 0.0) if mobile else Vector3(0.0, 470.0, 0.0)

func _fov() -> float:
	return 52.0

func _frame_frac() -> float:
	return 0.5

func _environment(env: Environment) -> void:
	env.background_color = Color(0.10, 0.12, 0.26)
	env.ambient_light_color = Color(0.42, 0.46, 0.70)
	env.ambient_light_energy = 0.22

func _build_lights() -> void:
	# the last of the daylight, cool, from high on the right; the street lamp; warm spill from every lit window
	var dusk: DirectionalLight3D = DirectionalLight3D.new()
	dusk.light_color = Color(0.62, 0.66, 0.92)
	dusk.light_energy = 0.32
	dusk.shadow_enabled = true
	dusk.directional_shadow_max_distance = 30.0
	root.add_child(dusk)
	dusk.rotation_degrees = Vector3(-34.0, 28.0, 0.0)
	light(_lamp_head() + Vector3(0.0, -6.0, 0.0), Color(1.0, 0.78, 0.48), 2.2, 520.0, true)
	for f in FACES:
		light(Vector3(float(f[0]), float(f[1]) + WIN_H * 0.4, 46.0), Color(1.0, 0.76, 0.46), 0.9, 190.0)
	for o in OTHERS:
		if str(o[2]) == "lit":
			light(Vector3(float(o[0]), float(o[1]) + WIN_H * 0.4, 46.0), Color(1.0, 0.74, 0.44), 0.8, 180.0)
	# the door's fanlight, a little warm on the steps
	light(Vector3(0.0, 250.0, 60.0), Color(1.0, 0.78, 0.50), 0.7, 220.0)

# (at the left, clear of every window with a person in it: they are live and would be drawn over it)
func _lamp_head() -> Vector3:
	return Vector3(-244.0, 420.0, 250.0)

# --- the people in the windows (live) -----------------------------------------------------------------------------

# the n-th person to come to a window: stepping through the list by a stride that shares no factor with its length, so
# every one comes round before anyone repeats (a stride of 7 through the 21 women showed only three of them, the same
# face in three windows at once)
func _person(n: int) -> String:
	var cnt: int = _people.size()
	var stride: int = 7
	while cnt > 1 and _gcd(stride, cnt) != 1:
		stride += 1
	return _people[posmod(n * stride + 3, cnt)]

func _gcd(a: int, b: int) -> int:
	while b != 0:
		var r: int = a % b
		a = b
		b = r
	return a

func _setup() -> void:
	super._setup()
	if bake_mode:
		return
	for w in WOMEN:
		if ResourceLoader.exists(CUTOUTS % w):
			_people.append(w)
	if _people.is_empty():
		_people = WOMEN.duplicate()
	for _k in FACES.size():
		_who.append(-1)
		_closed.append(1.0)
	_layer = Control.new()
	_photo_layer = Control.new()
	_front = Control.new()
	for ly in [_layer, _photo_layer, _front]:
		(ly as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(ly as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(ly)
	_layer.draw.connect(_draw_rooms)
	_photo_layer.draw.connect(_draw_people)
	_front.draw.connect(_draw_fronts)
	if _top != null:
		move_child(_top, get_child_count() - 1)

func _want(person: String) -> Texture2D:
	if _tex.has(person):
		return _tex[person]
	var path: String = CUTOUTS % person
	var st: int = ResourceLoader.load_threaded_get_status(path)
	if st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)
	elif st == ResourceLoader.THREAD_LOAD_LOADED:
		_tex[person] = ResourceLoader.load_threaded_get(path)
		return _tex[person]
	return null

func _tick(delta: float) -> void:
	super._tick(delta)
	if bake_mode or _layer == null or _cam3 == null:
		return
	# THE TURNS: turn n belongs to window n % FACES.size() and brings the n-th woman; the next window starts opening
	# the moment this one's curtains meet (overlapping, two were half open at once: "only reveal one at a time")
	var turn: float = TURN_S - LEAD_S
	var round_n: int = int(floor(t / turn))
	_want(_person(round_n + 1))          # the next one's photo, loading ahead
	for k in FACES.size():
		var shut: float = 1.0
		var n: int = -1
		for r in [round_n, round_n - 1]:
			if r >= 0 and posmod(r, FACES.size()) == k:
				var since: float = t - float(r) * turn
				if since < TURN_S:
					n = r
					shut = maxf(1.0 - smoothstep(0.0, OPEN_S, since), smoothstep(TURN_S - CLOSE_S, TURN_S, since))
		if n >= 0 and _who[k] != n and _want(_person(n)) != null and float(_closed[k]) > 0.99:
			_who[k] = n
		elif n < 0 and float(_closed[k]) > 0.99:
			_who[k] = -1                   # the curtains are shut: nobody waits behind them
		# until its photo is in, a window keeps its curtains shut, and opens them when it comes
		var want_shut: float = shut if _who[k] >= 0 and _who[k] == n else 1.0
		_closed[k] = want_shut if absf(want_shut - float(_closed[k])) < 0.05 else move_toward(float(_closed[k]), want_shut, delta * 1.6)
	_layer.queue_redraw()
	_photo_layer.queue_redraw()
	_front.queue_redraw()

# a point on window w's glass, (u, v) across and down it (0..1), on the screen
func _glass_pt(cx: float, sill: float, u: float, v: float, z: float = GLASS_Z) -> Vector2:
	return screen_of(Vector3(cx - WIN_W * 0.5 + u * WIN_W, sill + WIN_H - v * WIN_H, z))

# the part of the glass seen past the surround: the glass's outline clipped by the opening's front edge (seen from
# below, the head's soffit hides a strip at the top)
func _visible_poly(cx: float, sill: float) -> PackedVector2Array:
	var back: PackedVector2Array = PackedVector2Array([_glass_pt(cx, sill, 0.0, 0.0), _glass_pt(cx, sill, 1.0, 0.0), _glass_pt(cx, sill, 1.0, 1.0), _glass_pt(cx, sill, 0.0, 1.0)])
	var front: PackedVector2Array = PackedVector2Array([_glass_pt(cx, sill, 0.0, 0.0, FRAME_Z), _glass_pt(cx, sill, 1.0, 0.0, FRAME_Z), _glass_pt(cx, sill, 1.0, 1.0, FRAME_Z), _glass_pt(cx, sill, 0.0, 1.0, FRAME_Z)])
	var cut: Array = Geometry2D.intersect_polygons(back, front)
	return cut[0] if not cut.is_empty() else back

# (u, v) on the glass of a screen point: the inverse of the glass's (near-affine) mapping
func _uv_of(p: Vector2, o: Vector2, ax: Vector2, ay: Vector2) -> Vector2:
	var det: float = ax.x * ay.y - ax.y * ay.x
	var d: Vector2 = p - o
	return Vector2((d.x * ay.y - d.y * ay.x) / det, (ax.x * d.y - ax.y * d.x) / det)

func _clip_fill(poly: PackedVector2Array, vis: PackedVector2Array, col: Color) -> void:
	for piece in Geometry2D.intersect_polygons(poly, vis):
		_front.draw_colored_polygon(piece, col)

func _win_axes(cx: float, sill: float) -> Array:
	var o: Vector2 = _glass_pt(cx, sill, 0.0, 0.0)
	return [o, _glass_pt(cx, sill, 1.0, 0.0) - o, _glass_pt(cx, sill, 0.0, 1.0) - o]

# THE ROOMS: a warm wall lit by a lamp hanging in the room (brightest high and to the middle, falling off to the corners
# and the floor), a framed picture on the far wall beyond the person
func _draw_rooms() -> void:
	if _cam3 == null:
		return
	for k in FACES.size():
		var f: Array = FACES[k]
		var cx: float = f[0]
		var sill: float = f[1]
		var vis: PackedVector2Array = _visible_poly(cx, sill)
		var ax: Array = _win_axes(cx, sill)
		var room: PackedColorArray = PackedColorArray()
		var wall: Color = [Color(0.74, 0.56, 0.38), Color(0.62, 0.58, 0.48), Color(0.70, 0.50, 0.40), Color(0.56, 0.60, 0.52), Color(0.72, 0.62, 0.46), Color(0.66, 0.54, 0.50)][k % 6]
		for p in vis:
			var uv0: Vector2 = _uv_of(p, ax[0], ax[1], ax[2])
			room.append(wall.darkened(0.30 * uv0.y + 0.35 * absf(uv0.x - 0.5)))
		_layer.draw_polygon(vis, room)
		# the picture on the far wall, on the side the person is not
		var pu: float = 0.80 if float(PERSON_U[k]) < 0.5 else 0.20
		var pic: PackedVector2Array = PackedVector2Array([_glass_pt(cx, sill, pu - 0.11, 0.24), _glass_pt(cx, sill, pu + 0.11, 0.24), _glass_pt(cx, sill, pu + 0.11, 0.42), _glass_pt(cx, sill, pu - 0.11, 0.42)])
		for piece in Geometry2D.intersect_polygons(pic, vis):
			_layer.draw_colored_polygon(piece, Color(0.30, 0.20, 0.10))
		var inner: PackedVector2Array = PackedVector2Array([_glass_pt(cx, sill, pu - 0.08, 0.26), _glass_pt(cx, sill, pu + 0.08, 0.26), _glass_pt(cx, sill, pu + 0.08, 0.40), _glass_pt(cx, sill, pu - 0.08, 0.40)])
		for piece2 in Geometry2D.intersect_polygons(inner, vis):
			var pc: PackedColorArray = PackedColorArray()
			for p2 in piece2:
				var v2: float = _uv_of(p2, ax[0], ax[1], ax[2]).y
				pc.append(Color(0.46, 0.56, 0.62).lerp(Color(0.40, 0.46, 0.26), smoothstep(0.31, 0.36, v2)))
			_layer.draw_polygon(piece2, pc)
		# the lamp's glow high in the room
		var lg: Vector2 = _glass_pt(cx, sill, 0.5, 0.16)
		for r in 10:
			_layer.draw_circle(lg, (10.0 - float(r)) * 2.6, Color(1.0, 0.86, 0.60, 0.035))

# THE PEOPLE: the cut-out photo, standing in the room up to the sill, warmed and shaded by the room's light, so the person
# stands in the lit room rather than a picture in a frame (filling the glass, the photos read as portraits hung there)
func _draw_people() -> void:
	if _cam3 == null:
		return
	for k in FACES.size():
		if _who[k] < 0:
			continue
		var tex: Texture2D = _tex.get(_person(_who[k]), null)
		if tex == null:
			continue
		var f: Array = FACES[k]
		var cx: float = f[0]
		var sill: float = f[1]
		var vis: PackedVector2Array = _visible_poly(cx, sill)
		var ts: Vector2 = tex.get_size()
		var pw: float = PERSON_W
		var ph: float = pw * WIN_W / (ts.x / ts.y) / WIN_H
		var u0: float = float(PERSON_U[k]) - pw * 0.5
		var v0: float = 1.0 - ph
		var rect: PackedVector2Array = PackedVector2Array([_glass_pt(cx, sill, u0, v0), _glass_pt(cx, sill, u0 + pw, v0), _glass_pt(cx, sill, u0 + pw, v0 + ph), _glass_pt(cx, sill, u0, v0 + ph)])
		var o: Vector2 = rect[0]
		var px: Vector2 = rect[1] - o
		var py: Vector2 = rect[3] - o
		for piece in Geometry2D.intersect_polygons(rect, vis):
			var uvs: PackedVector2Array = PackedVector2Array()
			var cols: PackedColorArray = PackedColorArray()
			for p in piece:
				var uv: Vector2 = _uv_of(p, o, px, py)
				uvs.append(uv)
				var lit: float = 1.0 - 0.34 * uv.y
				cols.append(Color(1.04 * lit, 0.93 * lit, 0.80 * lit))
			_photo_layer.draw_polygon(piece, cols, uvs, tex)

# OVER THE PEOPLE: the frame's shadow under the head, the curtains, the glass's sheen and a glint of the street lamp
func _draw_fronts() -> void:
	if _cam3 == null:
		return
	for k in FACES.size():
		var f: Array = FACES[k]
		var cx: float = f[0]
		var sill: float = f[1]
		var vis: PackedVector2Array = _visible_poly(cx, sill)
		var ax: Array = _win_axes(cx, sill)
		var shade_top: PackedVector2Array = PackedVector2Array([_glass_pt(cx, sill, 0.0, 0.0), _glass_pt(cx, sill, 1.0, 0.0), _glass_pt(cx, sill, 1.0, 0.12), _glass_pt(cx, sill, 0.0, 0.12)])
		for piece in Geometry2D.intersect_polygons(shade_top, vis):
			var sc: PackedColorArray = PackedColorArray()
			for p3 in piece:
				sc.append(Color(0.0, 0.0, 0.0, 0.40 * (1.0 - clampf(_uv_of(p3, ax[0], ax[1], ax[2]).y / 0.12, 0.0, 1.0))))
			_front.draw_polygon(piece, sc)
		_draw_curtains(k, cx, sill, vis)
		var sheen: PackedVector2Array = PackedVector2Array([_glass_pt(cx, sill, 0.58, 0.0), _glass_pt(cx, sill, 0.80, 0.0), _glass_pt(cx, sill, 0.42, 1.0), _glass_pt(cx, sill, 0.20, 1.0)])
		_clip_fill(sheen, vis, Color(0.85, 0.90, 1.0, 0.07))
		var glint: Vector2 = _glass_pt(cx, sill, 0.82 if cx < -150.0 else 0.18, 0.22)
		_front.draw_circle(glint, 2.2, Color(1.0, 0.86, 0.60, 0.55))
		_front.draw_circle(glint, 5.0, Color(1.0, 0.86, 0.60, 0.12))

# THE CURTAINS: a pair on a brass rod, each a run of folds (shaded strip by strip, lighter on their crests), drawn back
# to the sides when open and meeting (overlapping) in the middle when shut
func _draw_curtains(k: int, cx: float, sill: float, vis: PackedVector2Array) -> void:
	var f: Array = FACES[k]
	var base: Color = f[2]
	var c: float = _closed[k]
	var cw: float = lerpf(0.17, 0.53, c)
	for side in [0, 1]:
		var folds: int = 9
		for s in folds:
			var a: float = float(s) / float(folds)
			var b: float = float(s + 1) / float(folds)
			var u0: float = (a * cw) if side == 0 else (1.0 - cw + a * cw)
			var u1: float = (b * cw) if side == 0 else (1.0 - cw + b * cw)
			# gathered at the rod, falling a little wider at the hem
			var flare: float = 0.02 * (1.0 - c)
			var u0b: float = u0 + (flare if side == 0 else -flare) * (1.0 - a)
			var u1b: float = u1 + (flare if side == 0 else -flare) * (1.0 - b)
			var strip: PackedVector2Array = PackedVector2Array([_glass_pt(cx, sill, u0, 0.04), _glass_pt(cx, sill, u1, 0.04), _glass_pt(cx, sill, u1b, 1.0), _glass_pt(cx, sill, u0b, 1.0)])
			var crest: float = 0.5 + 0.5 * sin((float(s) + 0.5) / float(folds) * TAU * 2.0 + float(side) * 1.3)
			var col: Color = base.darkened(0.42 * (1.0 - crest)).lightened(0.10 * crest)
			# the room's lamp warms the cloth from behind
			col = col.lerp(Color(1.0, 0.82, 0.56), 0.08)
			_clip_fill(strip, vis, col)
	# the rod across the head, brass, its finials
	var r0: Vector2 = _glass_pt(cx, sill, -0.02, 0.04)
	var r1: Vector2 = _glass_pt(cx, sill, 1.02, 0.04)
	_front.draw_line(r0, r1, Color(0.62, 0.46, 0.20), 2.2, true)
	_front.draw_line(r0 + Vector2(0.0, -0.8), r1 + Vector2(0.0, -0.8), Color(1.0, 0.86, 0.52, 0.8), 0.8, true)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	# the lantern's halo in the damp evening air: a wide faint bloom and a tight bright one
	if _cam3 != null:
		var lc: Vector2 = screen_of(_lamp_head())
		var pu: float = screen_of(_lamp_head() + Vector3(100.0, 0.0, 0.0)).distance_to(lc) / 100.0
		glow_at(lc, 120.0 * pu, Color(1.0, 0.72, 0.40, 0.10), 10)
		glow_at(lc, 44.0 * pu, Color(1.0, 0.86, 0.62, 0.22), 8)
	title("Friends", "Recognize your friends on an evening stroll", Color(1.0, 0.88, 0.62), Color(0.10, 0.06, 0.12),
		Color(1.0, 0.80, 0.45, 0.22))

# --- textures (a normal map with each, so the evening light rakes across them) -----------------------------------

func _normal_map(hgt: PackedFloat32Array, w: int, h: int, strength: float) -> ImageTexture:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var hx: float = hgt[y * w + (x + 1) % w] - hgt[y * w + (x - 1 + w) % w]
			var hy: float = hgt[((y + 1) % h) * w + x] - hgt[((y - 1 + h) % h) * w + x]
			var nrm: Vector3 = Vector3(-hx * strength, -hy * strength, 1.0).normalized()
			img.set_pixel(x, y, Color(nrm.x * 0.5 + 0.5, nrm.y * 0.5 + 0.5, nrm.z * 0.5 + 0.5))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _tmat(tex: Array, rough: float, uv: Vector3 = Vector3.ONE, nscale: float = 1.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = mat(Color.WHITE, rough, 0.0, tex[0], uv)
	m.normal_enabled = true
	m.normal_texture = tex[1]
	m.normal_scale = nscale
	return m

# old red brick, Flemish-ish: each brick its own fired tone, the mortar pale and raked
func _brick(n: int) -> Array:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var hgt: PackedFloat32Array = PackedFloat32Array()
	hgt.resize(n * n)
	var pit: FastNoiseLite = FastNoiseLite.new()
	pit.seed = 8
	pit.frequency = 0.25
	var bh: int = n / 16
	var bw: int = n / 8
	for y in n:
		var row: int = y / bh
		for x in n:
			var xo: int = (x + (bw / 2 if row % 2 == 1 else 0)) % n
			var id: int = row * 11 + xo / bw
			var mx: int = xo % bw
			var my: int = y % bh
			if mx < 2 or my < 2:
				img.set_pixel(x, y, Color(0.66, 0.63, 0.58).darkened(0.10 * h01(x * 3 + y * 7)))
				hgt[y * n + x] = 0.0
				continue
			var c: Color = Color(0.50, 0.20, 0.14).lerp(Color(0.64, 0.32, 0.20), h01(id * 7))
			if h01(id * 29) > 0.88:
				c = Color(0.30, 0.14, 0.11)
			var p: float = pit.get_noise_2d(float(x), float(y))
			c = c.darkened(0.10 * p + 0.05 * h01(x * 5 + y * 3))
			img.set_pixel(x, y, c)
			hgt[y * n + x] = 0.85 - (0.12 if p > 0.55 else 0.0)
	img.generate_mipmaps()
	return [ImageTexture.create_from_image(img), _normal_map(hgt, n, n, 3.0)]

# lime stucco: a soft mottle of its color, a fine sanded grain, a hairline crack or two; `rustic` cuts horizontal
# rustication grooves into it (the ground floor's banded base)
func _stucco(n: int, base: Color, seed_i: int, rustic: bool) -> Array:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var hgt: PackedFloat32Array = PackedFloat32Array()
	hgt.resize(n * n)
	var mot: FastNoiseLite = FastNoiseLite.new()
	mot.seed = seed_i
	mot.frequency = 0.012
	mot.fractal_octaves = 4
	for y in n:
		for x in n:
			var m: float = mot.get_noise_2d(float(x), float(y))
			var g: float = h01(x * 17 + y * 31 + seed_i)
			var c: Color = base.lightened(0.07 * m) if m > 0.0 else base.darkened(-0.12 * m)
			c = c.darkened(0.05 * g)
			var hh: float = 0.6 + 0.15 * g
			if rustic and y % (n / 4) < 3:
				c = c.darkened(0.35)
				hh = 0.1
			img.set_pixel(x, y, c)
			hgt[y * n + x] = hh
	img.generate_mipmaps()
	return [ImageTexture.create_from_image(img), _normal_map(hgt, n, n, 1.6)]

# flagstones: big worn slabs, each its own gray, the joints dark
func _flags(n: int) -> Array:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var hgt: PackedFloat32Array = PackedFloat32Array()
	hgt.resize(n * n)
	var mot: FastNoiseLite = FastNoiseLite.new()
	mot.seed = 4
	mot.frequency = 0.03
	var cell: int = n / 4
	for y in n:
		var row: int = y / cell
		for x in n:
			var xo: int = (x + (cell / 2 if row % 2 == 1 else 0)) % n
			var id: int = row * 7 + xo / cell
			var c: Color = Color(0.44, 0.44, 0.46).lerp(Color(0.56, 0.54, 0.52), h01(id * 5)).darkened(0.10 * mot.get_noise_2d(float(x), float(y)))
			var hh: float = 0.7
			if xo % cell < 2 or y % cell < 2:
				c = Color(0.16, 0.16, 0.17)
				hh = 0.0
			img.set_pixel(x, y, c.darkened(0.06 * h01(x * 7 + y * 13)))
			hgt[y * n + x] = hh
	img.generate_mipmaps()
	return [ImageTexture.create_from_image(img), _normal_map(hgt, n, n, 2.0)]

# a drawn curtain lit from behind: folds of warm cloth, for the lit windows' glass
func _lit_curtain(n: int, col: Color) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var fold: float = 0.5 + 0.5 * sin(float(x) / float(n) * TAU * 5.0 + 0.6 * sin(float(y) * 0.05))
			var c: Color = col.darkened(0.35 * (1.0 - fold)).darkened(0.25 * float(y) / float(n))
			if absi(x - n / 2) < 2:
				c = c.darkened(0.5)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# THE EVENING SKY: deep blue overhead, violet and a band of rose at the horizon
func _sky(n: int) -> ImageTexture:
	var img: Image = Image.create(4, n, false, Image.FORMAT_RGB8)
	for y in n:
		var v: float = float(y) / float(n - 1)
		var c: Color = Color(0.06, 0.08, 0.22).lerp(Color(0.22, 0.20, 0.44), smoothstep(0.0, 0.6, v)).lerp(Color(0.80, 0.50, 0.50), smoothstep(0.62, 1.0, v))
		img.fill_rect(Rect2i(0, y, 4, 1), c)
	return ImageTexture.create_from_image(img)

# --- the street: real 3-D, baked ----------------------------------------------------------------------------------

func _quad(q_size: Vector2, m: Material, center: Vector3) -> MeshInstance3D:
	var q: QuadMesh = QuadMesh.new()
	q.size = q_size
	return put(q, m, center)

# a facade's face as a quad, its texture at a fixed scale (`tile` units per repeat)
func _face(x0: float, x1: float, y0: float, y1: float, tex: Array, tile: Vector2, z: float = 0.0) -> void:
	var m: StandardMaterial3D = _tmat(tex, 0.92, Vector3((x1 - x0) / tile.x, (y1 - y0) / tile.y, 1.0))
	m.uv1_offset = Vector3(x0 / tile.x, -y1 / tile.y, 0.0)
	_quad(Vector2(x1 - x0, y1 - y0), m, Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, z))

# A WINDOW: the glass (by kind), a painted sash frame, a stone surround standing proud with a head and a sill
func _window(cx: float, sill: float, kind: String, stone: StandardMaterial3D, paint: StandardMaterial3D) -> void:
	var gc: Vector3 = Vector3(cx, sill + WIN_H * 0.5, GLASS_Z)
	if kind == "lit":
		var gm: StandardMaterial3D = mat(Color.WHITE, 1.0, 0.0, _lit_curtain(64, Color(0.95, 0.70, 0.40)))
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_quad(Vector2(WIN_W, WIN_H), gm, gc)
	elif kind == "face":
		_quad(Vector2(WIN_W, WIN_H), glow(Color(0.62, 0.44, 0.28)), gc)
	else:
		# an unlit room: the glass holding the dusk sky, darker low down
		var dm: StandardMaterial3D = mat(Color(0.10, 0.12, 0.22), 0.08, 0.5)
		dm.clearcoat_enabled = true
		_quad(Vector2(WIN_W, WIN_H), dm, gc)
	# the sash frame and (on the unlit and drawn windows) its glazing bars
	for e in [-1.0, 1.0]:
		box(Vector3(5.0, WIN_H, 4.0), paint, Vector3(cx + e * (WIN_W * 0.5 - 2.5), sill + WIN_H * 0.5, GLASS_Z + 1.5))
		box(Vector3(WIN_W, 5.0, 4.0), paint, Vector3(cx, sill + WIN_H * 0.5 + e * (WIN_H * 0.5 - 2.5), GLASS_Z + 1.5))
	if kind != "face":
		box(Vector3(WIN_W, 4.0, 4.0), paint, Vector3(cx, sill + WIN_H * 0.55, GLASS_Z + 2.0))
		box(Vector3(3.0, WIN_H, 3.0), paint, Vector3(cx, sill + WIN_H * 0.5, GLASS_Z + 1.8))
	# the surround: jambs and head standing proud of the wall, the opening's reveals inside them
	for e2 in [-1.0, 1.0]:
		box(Vector3(14.0, WIN_H + 14.0, FRAME_Z), stone, Vector3(cx + e2 * (WIN_W * 0.5 + 7.0), sill + WIN_H * 0.5 + 7.0, FRAME_Z * 0.5))
	box(Vector3(WIN_W + 28.0, 14.0, FRAME_Z), stone, Vector3(cx, sill + WIN_H + 7.0, FRAME_Z * 0.5))
	# a molded hood over the head, a keystone
	box(Vector3(WIN_W + 44.0, 6.0, FRAME_Z + 8.0), stone, Vector3(cx, sill + WIN_H + 17.0, (FRAME_Z + 8.0) * 0.5))
	box(Vector3(WIN_W + 38.0, 3.0, FRAME_Z + 5.0), stone, Vector3(cx, sill + WIN_H + 12.5, (FRAME_Z + 5.0) * 0.5))
	box(Vector3(14.0, 20.0, FRAME_Z + 2.0), stone, Vector3(cx, sill + WIN_H + 8.0, (FRAME_Z + 2.0) * 0.5))
	# the sill: a thick stone slab jutting out, its brackets
	box(Vector3(WIN_W + 40.0, 9.0, FRAME_Z + 12.0), stone, Vector3(cx, sill - 4.5, (FRAME_Z + 12.0) * 0.5))
	for e3 in [-1.0, 1.0]:
		box(Vector3(8.0, 14.0, 12.0), stone, Vector3(cx + e3 * (WIN_W * 0.5 + 8.0), sill - 16.0, 6.0))
	if kind == "box":
		# a WINDOW BOX of geraniums on the sill: a painted wooden trough, leaves, red flower heads
		box(Vector3(WIN_W + 10.0, 22.0, 20.0), mat(Color(0.18, 0.30, 0.24), 0.6), Vector3(cx, sill + 11.0, FRAME_Z + 6.0))
		for lf in 16:
			var lx: float = cx - WIN_W * 0.5 + float(lf) * WIN_W / 15.0
			var leaf: MeshInstance3D = sphere(9.0, mat(Color(0.16, 0.36, 0.14), 0.8), Vector3(lx, sill + 26.0 + 6.0 * h01(lf + int(cx)), FRAME_Z + 6.0 + 6.0 * (h01(lf * 3) - 0.5)))
			leaf.scale = Vector3(1.0, 0.6, 0.8)
		for fl in 7:
			var fx: float = cx - WIN_W * 0.42 + float(fl) * WIN_W * 0.14
			for pe in 5:
				sphere(3.4, mat(Color(0.86, 0.10, 0.12), 0.7), Vector3(fx + 4.0 * cos(float(pe) * 1.26), sill + 36.0 + 4.0 * sin(float(pe) * 1.26) + 4.0 * h01(fl), FRAME_Z + 8.0))

func _house(x0: float, x1: float, top: float, face: Array, ground: Array, tile: Vector2, stone: StandardMaterial3D) -> void:
	# the body behind the face (it casts the shadows), the ground floor's face, the upper floors' face
	box(Vector3(x1 - x0, top, 40.0), mat(Color(0.3, 0.3, 0.3), 0.9), Vector3((x0 + x1) * 0.5, top * 0.5, -20.2))
	_face(x0, x1, 0.0, 330.0, ground, tile, 0.0)
	_face(x0, x1, 330.0, top, face, tile, 0.0)
	# the string courses: a band of stone between the floors
	for sy in [330.0, 620.0]:
		box(Vector3(x1 - x0, 12.0, 8.0), stone, Vector3((x0 + x1) * 0.5, sy, 4.0))
		box(Vector3(x1 - x0, 3.0, 11.0), stone, Vector3((x0 + x1) * 0.5, sy + 7.0, 5.5))
	# THE CORNICE: a frieze, a row of dentils, the crown jutting far out over them; a parapet, chimney stacks
	box(Vector3(x1 - x0, 30.0, 6.0), stone, Vector3((x0 + x1) * 0.5, top - 15.0, 3.0))
	var nd: int = int((x1 - x0) / 14.0)
	for d in nd:
		box(Vector3(7.0, 10.0, 12.0), stone, Vector3(x0 + 7.0 + float(d) * 14.0, top + 5.0, 6.0))
	box(Vector3(x1 - x0 + 8.0, 10.0, 22.0), stone, Vector3((x0 + x1) * 0.5, top + 15.0, 9.0))
	box(Vector3(x1 - x0 + 12.0, 5.0, 26.0), stone, Vector3((x0 + x1) * 0.5, top + 22.0, 11.0))
	box(Vector3(x1 - x0, 50.0, 14.0), mat(Color(0.3, 0.3, 0.3), 0.9), Vector3((x0 + x1) * 0.5, top + 50.0, -10.0))
	_face(x0, x1, top + 25.0, top + 75.0, face, tile, -2.9)
	var brick_m: StandardMaterial3D = _tmat(_brick(128), 0.9, Vector3(1, 2, 1))
	for ch in [x0 + 50.0, x1 - 60.0]:
		box(Vector3(46.0, 130.0, 36.0), brick_m, Vector3(ch, top + 120.0, -60.0))
		box(Vector3(54.0, 8.0, 44.0), stone, Vector3(ch, top + 188.0, -60.0))
		for pot in 2:
			cyl(6.0, 7.5, 26.0, mat(Color(0.62, 0.32, 0.20), 0.8), Vector3(ch - 11.0 + float(pot) * 22.0, top + 205.0, -60.0), Vector3.ZERO, null, 12)

func _build_still() -> void:
	var stone: StandardMaterial3D = _tmat(_stucco(128, Color(0.72, 0.69, 0.62), 3, false), 0.85, Vector3(1, 1, 1))
	var paint: StandardMaterial3D = mat(Color(0.94, 0.93, 0.88), 0.4)
	var iron: StandardMaterial3D = mat(Color(0.07, 0.07, 0.08), 0.45, 0.6)
	# THE SKY behind the roofs, the first stars, the moon
	var sky_m: StandardMaterial3D = mat(Color.WHITE, 1.0, 0.0, _sky(128))
	sky_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_m.texture_repeat = false
	_quad(Vector2(6000.0, 2400.0), sky_m, Vector3(0.0, 700.0, -900.0))
	for st in 50:
		var star: MeshInstance3D = sphere(1.6 + 1.6 * h01(st + 7), glow(Color(1.0, 0.96, 0.86, 0.5 + 0.5 * h01(st))), Vector3(-1400.0 + 2800.0 * h01(st * 3), 1150.0 + 700.0 * h01(st * 3 + 1), -880.0))
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var moon: MeshInstance3D = sphere(26.0, glow(Color(1.0, 0.97, 0.86)), Vector3(380.0, 1420.0, -870.0))
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sphere(25.0, glow(Color(0.12, 0.14, 0.30)), Vector3(368.0, 1426.0, -860.0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# THE THREE HOUSES
	var brick_t: Array = _brick(256)
	var cream: Array = _stucco(256, Color(0.76, 0.70, 0.58), 5, false)
	var cream_r: Array = _stucco(256, Color(0.74, 0.68, 0.56), 5, true)
	var sage: Array = _stucco(256, Color(0.46, 0.54, 0.46), 9, false)
	_house(-470.0, -160.0, 880.0, brick_t, brick_t, Vector2(150.0, 100.0), stone)
	_house(-160.0, 160.0, 940.0, cream, cream_r, Vector2(240.0, 240.0), stone)
	_house(160.0, 470.0, 860.0, sage, sage, Vector2(240.0, 240.0), stone)
	# and the street running on either side (seen on a desktop's wider picture): an ochre house, another of brick
	var ochre: Array = _stucco(256, Color(0.70, 0.56, 0.34), 13, false)
	_house(-780.0, -470.0, 900.0, ochre, ochre, Vector2(240.0, 240.0), stone)
	_house(470.0, 780.0, 900.0, brick_t, brick_t, Vector2(150.0, 100.0), stone)
	for sx in [-1.0, 1.0]:
		for wk in 6:
			var wx: float = sx * (550.0 + float(wk % 2) * 150.0)
			var wy: float = [120.0, 400.0, 660.0][wk / 2]
			_window(wx, wy, ["lit", "dark", "box", "lit", "dark", "lit"][(wk + (3 if sx > 0.0 else 0)) % 6], stone, paint)
	# a downpipe between each pair
	for dp in [-470.0, -160.0, 160.0, 470.0]:
		cyl(4.0, 4.0, 860.0, iron, Vector3(dp, 430.0, 8.0), Vector3.ZERO, null, 10)
	for f in FACES:
		_window(float(f[0]), float(f[1]), "face", stone, paint)
	for o in OTHERS:
		_window(float(o[0]), float(o[1]), str(o[2]), stone, paint)
	# THE GROUND FLOORS: the cream house's front door up its steps; a parlor window either side
	_window(-390.0, 120.0, "lit", stone, paint)
	_window(-240.0, 120.0, "dark", stone, paint)
	_window(240.0, 120.0, "lit", stone, paint)
	_window(390.0, 120.0, "box", stone, paint)
	_door(0.0, stone, paint, iron)
	_window(-100.0, 140.0, "dark", stone, paint)
	# THE PAVEMENT: flagstones, a granite curb, the cobbled road beyond
	var flags: StandardMaterial3D = _tmat(_flags(256), 0.85, Vector3(10, 2, 1))
	box(Vector3(3000.0, 4.0, 300.0), flags, Vector3(0.0, -2.0, 150.0))
	box(Vector3(3000.0, 14.0, 16.0), mat(Color(0.52, 0.52, 0.54), 0.8), Vector3(0.0, -5.0, 308.0))
	box(Vector3(3000.0, 4.0, 1200.0), _tmat(_flags(128), 0.7, Vector3(60, 24, 1)), Vector3(0.0, -14.0, 916.0))
	# THE STREET LAMP: a fluted cast-iron post on a base, a lantern of four glass panes round its glowing mantle, a cap
	var lh: Vector3 = _lamp_head()
	var lp: Vector3 = Vector3(lh.x, 0.0, lh.z)
	cyl(16.0, 18.0, 30.0, iron, lp + Vector3(0.0, 15.0, 0.0), Vector3.ZERO, null, 16)
	cyl(10.0, 14.0, 20.0, iron, lp + Vector3(0.0, 40.0, 0.0), Vector3.ZERO, null, 16)
	cyl(5.0, 7.0, lh.y - 90.0, iron, lp + Vector3(0.0, 50.0 + (lh.y - 90.0) * 0.5, 0.0), Vector3.ZERO, null, 12)
	_lantern(lh, iron)
	# A BICYCLE leaning on the right-hand railing: two wheels, the frame, the saddle and the bars
	_bicycle(Vector3(300.0, 0.0, 70.0), iron)

# THE LANTERN (the user, 2026-11-19: "improve the light in the light pole" -- it was a glowing four-sided block under a
# cap): a cast collar on the post, a ladder bar with ball ends, four FROSTED panes in an iron frame (hottest round the
# mantle, cooler to their corners, faint streaks of the frosting), a pierced crown, a domed hood and a finial
func _lantern(lh: Vector3, iron: StandardMaterial3D) -> void:
	var bot: float = lh.y - 24.0
	var top: float = lh.y + 22.0
	var sb: float = 10.0           # the panes' half width at the foot and at the head
	var st_: float = 16.0
	cyl(9.0, 6.0, 12.0, iron, Vector3(lh.x, bot - 12.0, lh.z), Vector3.ZERO, null, 12)
	cyl(sb + 3.0, 8.0, 5.0, iron, Vector3(lh.x, bot - 3.0, lh.z), Vector3(0.0, 45.0, 0.0), null, 4)
	box(Vector3(46.0, 3.0, 3.0), iron, Vector3(lh.x, bot - 22.0, lh.z))
	for e in [-1.0, 1.0]:
		sphere(3.2, iron, Vector3(lh.x + e * 24.0, bot - 22.0, lh.z))
	var pane_m: StandardMaterial3D = StandardMaterial3D.new()
	pane_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pane_m.albedo_texture = _pane_tex()
	pane_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sf: SurfaceTool = SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cb: Array = [Vector2(-sb, -sb), Vector2(sb, -sb), Vector2(sb, sb), Vector2(-sb, sb)]
	var ct: Array = [Vector2(-st_, -st_), Vector2(st_, -st_), Vector2(st_, st_), Vector2(-st_, st_)]
	for k in 4:
		var a0: Vector3 = Vector3(lh.x + (cb[k] as Vector2).x, bot, lh.z + (cb[k] as Vector2).y)
		var a1: Vector3 = Vector3(lh.x + (cb[(k + 1) % 4] as Vector2).x, bot, lh.z + (cb[(k + 1) % 4] as Vector2).y)
		var b0: Vector3 = Vector3(lh.x + (ct[k] as Vector2).x, top, lh.z + (ct[k] as Vector2).y)
		var b1: Vector3 = Vector3(lh.x + (ct[(k + 1) % 4] as Vector2).x, top, lh.z + (ct[(k + 1) % 4] as Vector2).y)
		for v in [[a0, Vector2(0, 1)], [a1, Vector2(1, 1)], [b1, Vector2(1, 0)], [a0, Vector2(0, 1)], [b1, Vector2(1, 0)], [b0, Vector2(0, 0)]]:
			sf.set_uv(v[1])
			sf.add_vertex(v[0])
		# the frame: a rod up each corner, the rails round the foot and the head
		put(tube_mesh(PackedVector3Array([a0, b0]), 1.5, 6), iron, Vector3.ZERO)
		put(tube_mesh(PackedVector3Array([a0, a1]), 1.6, 6), iron, Vector3.ZERO)
		put(tube_mesh(PackedVector3Array([b0, b1]), 2.0, 6), iron, Vector3.ZERO)
	var panes: MeshInstance3D = put(sf.commit(), pane_m, Vector3.ZERO)
	panes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the crown: a band of iron with the hot air's vents lit from inside, the hood, the finial
	cyl(st_ * 1.414 + 2.0, st_ * 1.414 + 2.0, 6.0, iron, Vector3(lh.x, top + 3.0, lh.z), Vector3(0.0, 45.0, 0.0), null, 4)
	for v2 in 8:
		var va: float = TAU * (float(v2) + 0.5) / 8.0
		var vent: MeshInstance3D = box(Vector3(3.0, 2.2, 0.6), glow(Color(1.0, 0.70, 0.36)), Vector3(lh.x + sin(va) * (st_ + 2.6), top + 3.0, lh.z + cos(va) * (st_ + 2.6)), Vector3(0.0, rad_to_deg(va), 0.0))
		vent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cyl(4.0, st_ * 1.414 + 5.0, 16.0, iron, Vector3(lh.x, top + 14.0, lh.z), Vector3(0.0, 45.0, 0.0), null, 4)
	sphere(4.5, iron, Vector3(lh.x, top + 24.0, lh.z))
	cyl(0.5, 2.5, 9.0, iron, Vector3(lh.x, top + 32.0, lh.z), Vector3.ZERO, null, 8)

# a frosted pane, lit from the mantle behind it: warm white at the mantle's height, amber to the corners, streaked
func _pane_tex() -> ImageTexture:
	var w: int = 32
	var h: int = 64
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var u: float = (float(x) + 0.5) / float(w)
			var v: float = (float(y) + 0.5) / float(h)
			var d: float = Vector2((u - 0.5) * 1.6, v - 0.55).length()
			var hot: float = exp(-d * d * 9.0)
			var c: Color = Color(0.86, 0.50, 0.20).lerp(Color(1.0, 0.95, 0.80), hot)
			c = c.darkened(0.08 * h01(x * 13 + 5) + 0.25 * smoothstep(0.35, 0.5, absf(u - 0.5)))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# THE FRONT DOOR: up three stone steps, a paneled door in deep blue with a brass knocker and knob, the fanlight over
# it glowing, a pilastered doorcase; iron railings along the steps; bay trees in pots either side
func _door(cx: float, stone: StandardMaterial3D, paint: StandardMaterial3D, iron: StandardMaterial3D) -> void:
	for s in 3:
		box(Vector3(150.0 - float(s) * 16.0, 14.0, 70.0 - float(s) * 20.0), stone, Vector3(cx, 7.0 + float(s) * 14.0, 35.0 - float(s) * 10.0 + 6.0))
	var dw: float = 84.0
	var dh: float = 200.0
	var y0: float = 42.0
	var blue: StandardMaterial3D = mat(Color(0.10, 0.16, 0.34), 0.3)
	blue.clearcoat_enabled = true
	box(Vector3(dw, dh, 4.0), blue, Vector3(cx, y0 + dh * 0.5, 2.0))
	for pr in 3:
		for pc in 2:
			put(rbox_mesh(16.0, 26.0 if pr < 2 else 18.0, 2.4, 3.0, 1.0), blue, Vector3(cx - 20.0 + float(pc) * 40.0, y0 + 30.0 + float(pr) * 62.0, 4.0), Vector3(90.0, 0.0, 0.0))
	var brass: StandardMaterial3D = mat(Color(0.86, 0.66, 0.30), 0.25, 0.85)
	var kn: TorusMesh = TorusMesh.new()
	kn.inner_radius = 5.0
	kn.outer_radius = 7.0
	put(kn, brass, Vector3(cx, y0 + 130.0, 8.0), Vector3(90.0, 0.0, 0.0))
	sphere(3.5, brass, Vector3(cx + 30.0, y0 + 100.0, 8.0))
	box(Vector3(30.0, 7.0, 1.0), brass, Vector3(cx, y0 + 92.0, 4.6))
	# the fanlight: a half wheel of glass, glowing, its spokes
	var fan_c: Vector3 = Vector3(cx, y0 + dh + 2.0, 1.0)
	var fan: MeshInstance3D = cyl(dw * 0.5, dw * 0.5, 2.0, glow(Color(1.0, 0.80, 0.50)), fan_c, Vector3(90.0, 0.0, 0.0), null, 32)
	fan.scale = Vector3(1.0, 1.0, 1.0)
	for sp in 7:
		var sa: float = PI * float(sp) / 6.0
		box(Vector3(2.0, dw * 0.5, 2.0), paint, fan_c + Vector3(cos(sa) * dw * 0.25, sin(sa) * dw * 0.25, 2.0), Vector3(0.0, 0.0, rad_to_deg(sa) - 90.0))
	box(Vector3(dw + 6.0, 4.0, 4.0), paint, Vector3(cx, y0 + dh, 3.0))
	# the doorcase: pilasters, an entablature, the arch's stone surround
	for e in [-1.0, 1.0]:
		box(Vector3(18.0, dh + 40.0, 12.0), stone, Vector3(cx + e * (dw * 0.5 + 10.0), y0 + (dh + 40.0) * 0.5, 6.0))
		box(Vector3(24.0, 10.0, 16.0), stone, Vector3(cx + e * (dw * 0.5 + 10.0), y0 + dh + 44.0, 8.0))
	var arch: PackedVector3Array = PackedVector3Array()
	for ak in 17:
		var aa: float = PI * float(ak) / 16.0
		arch.append(Vector3(cx + cos(aa) * (dw * 0.5 + 6.0), y0 + dh + 2.0 + sin(aa) * (dw * 0.5 + 6.0), 4.0))
	put(tube_mesh(arch, 6.0, 8), stone, Vector3.ZERO)
	# the railings along the steps: square bars with spear heads, a handrail
	for e2 in [-1.0, 1.0]:
		var rx: float = cx + e2 * 82.0
		for rb in 7:
			var rz: float = 70.0 - float(rb) * 10.0
			var ry: float = 14.0 + float(mini(rb / 2, 2)) * 14.0
			box(Vector3(2.4, 90.0, 2.4), iron, Vector3(rx, ry + 45.0, rz))
			sphere(3.0, iron, Vector3(rx, ry + 92.0, rz))
		box(Vector3(4.0, 3.0, 76.0), iron, Vector3(rx, 112.0, 40.0), Vector3(-14.0, 0.0, 0.0))
		# a bay tree in a lead-gray planter at the step's foot: a clipped ball on a bare stem
		var tp: Vector3 = Vector3(cx + e2 * 118.0, 0.0, 70.0)
		box(Vector3(36.0, 40.0, 36.0), mat(Color(0.30, 0.32, 0.34), 0.7, 0.3), tp + Vector3(0.0, 20.0, 0.0))
		cyl(2.4, 3.0, 70.0, mat(Color(0.30, 0.22, 0.14), 0.9), tp + Vector3(0.0, 75.0, 0.0), Vector3.ZERO, null, 8)
		for cl in 9:
			var ca: float = TAU * float(cl) / 9.0
			sphere(16.0, mat(Color(0.16, 0.32, 0.14).lerp(Color(0.24, 0.42, 0.18), h01(cl + int(e2 * 5.0))), 0.8), tp + Vector3(cos(ca) * 14.0, 130.0 + 10.0 * sin(ca * 2.0), sin(ca) * 14.0))
		sphere(22.0, mat(Color(0.20, 0.38, 0.16), 0.8), tp + Vector3(0.0, 132.0, 0.0))

func _bicycle(at: Vector3, iron: StandardMaterial3D) -> void:
	var frame: StandardMaterial3D = mat(Color(0.12, 0.30, 0.42), 0.35, 0.4)
	var tire: StandardMaterial3D = mat(Color(0.06, 0.06, 0.06), 0.8)
	var chrome: StandardMaterial3D = mat(Color(0.80, 0.82, 0.86), 0.15, 0.95)
	var lean: Vector3 = Vector3(0.0, 0.0, -12.0)
	var wheels: Array = [at + Vector3(-50.0, 34.0, 0.0), at + Vector3(50.0, 34.0, 0.0)]
	for wc in wheels:
		var tire_ring: TorusMesh = TorusMesh.new()
		tire_ring.inner_radius = 30.0
		tire_ring.outer_radius = 34.0
		put(tire_ring, tire, wc, Vector3(90.0, 0.0, 0.0) + lean)
		var rim: TorusMesh = TorusMesh.new()
		rim.inner_radius = 28.6
		rim.outer_radius = 30.2
		put(rim, chrome, wc, Vector3(90.0, 0.0, 0.0) + lean)
		for sp in 12:
			var sa: float = TAU * float(sp) / 12.0
			box(Vector3(0.6, 29.0, 0.6), chrome, (wc as Vector3) + Vector3(cos(sa) * 14.5, sin(sa) * 14.5, 0.0), Vector3(0.0, 0.0, rad_to_deg(sa) - 90.0))
	var bb: Vector3 = at + Vector3(-4.0, 30.0, 0.0)
	var seat: Vector3 = at + Vector3(-20.0, 86.0, 0.0)
	var head: Vector3 = at + Vector3(36.0, 84.0, 0.0)
	for seg in [[bb, seat], [bb, head], [seat, head], [bb, wheels[0]], [seat, wheels[0]], [head, wheels[1]]]:
		put(tube_mesh(PackedVector3Array([seg[0], seg[1]]), 2.0, 8), frame, Vector3.ZERO)
	put(tube_mesh(PackedVector3Array([head, head + Vector3(4.0, 14.0, 0.0)]), 1.6, 8), chrome, Vector3.ZERO)
	put(tube_mesh(PackedVector3Array([head + Vector3(4.0, 14.0, -22.0), head + Vector3(4.0, 14.0, 22.0)]), 1.4, 8), chrome, Vector3.ZERO)
	var saddle: MeshInstance3D = sphere(9.0, mat(Color(0.30, 0.18, 0.10), 0.5), seat + Vector3(0.0, 6.0, 0.0))
	saddle.scale = Vector3(1.6, 0.5, 0.8)
	# a wicker basket on the front
	cyl(14.0, 11.0, 16.0, mat(Color.WHITE, 0.9, 0.0, tex_wood(32, Color(0.70, 0.54, 0.30), 3)), head + Vector3(14.0, 8.0, 0.0), Vector3.ZERO, null, 16)
	box(Vector3(2.0, 90.0, 2.0), iron, at + Vector3(0.0, 45.0, -20.0))

extends "res://scripts/menu_poster3d.gd"

# DINO N-BACK'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A
# PALEONTOLOGIST'S DESK AT NIGHT (2026-11-18; the valley before it -- cone mountains, stick palms, cards on posts --
# was "wrong and ugly"; only the cards moving along a winding way were kept). An old expedition map spread on a walnut
# desk under an oil lamp: aged parchment, coasts and contour lines in sepia, a river, a compass rose, and a ROUTE
# dotted across it, winding from the near edge to the far one. Along the route the game's own cards lie flat as old
# prints, the newest at the front: every beat a new card slides onto the map from the near edge and the whole line
# moves one place along the route; when the new card is the same as the one N back, a golden thread joins the two.
# Round the map: the lamp with its glass chimney and flame, a brass magnifying glass, an ammonite, a brass compass, an
# inkwell and a quill, books at the back. The desk is baked, one picture per platform (`menu_desk.webp`,
# `menu_desk_d.webp`); the cards, their shadows and the thread are live 2-D, laid in the map's perspective by the
# 3-D camera. Made up, never the board.

const CARD: GDScript = preload("res://shared/scripts/card.gd")
const N_BACK: int = 2
const STEP: float = 1.1          # a card every 1.1 s (2.6 and then 1.6 were "too long" a pause, the user)
const SHOWN: int = 8              # enough to fill the route to the map's far edge
# the stream of pictures; where a card repeats the one two before it, the thread shows
const STREAM: Array = [3, 14, 3, 21, 8, 21, 11, 27, 11, 19, 5, 19]
# THE ROUTE across the map, (x, z), near to far
const ROUTE: Array = [Vector2(-30.0, 560.0), Vector2(-60.0, 400.0), Vector2(-210.0, 250.0), Vector2(-150.0, 70.0),
	Vector2(140.0, -60.0), Vector2(210.0, -250.0), Vector2(10.0, -410.0), Vector2(-220.0, -560.0), Vector2(-130.0, -760.0),
	Vector2(120.0, -840.0), Vector2(190.0, -910.0)]
const CARD_AT: float = 190.0             # the front card's place along the route (units from its near end)
const SPACING: float = 240.0             # one card back is this much further along it
const CW: float = 126.0                  # a card on the map (units)
const CH: float = 178.0
const MAP_C: Vector3 = Vector3(0.0, 0.0, -200.0)
const MAP_W: float = 980.0
const MAP_D: float = 1480.0

var _layer: Node2D = null
var _cards: Array = []          # one node per slot, re-dressed as the line moves
var _under: Control = null
var _over: Control = null           # the cord between a matching pair, over the cards
var _dressed: int = -1
var _route_pts: PackedVector3Array = PackedVector3Array()
var _route_cum: PackedFloat32Array = PackedFloat32Array()

func _setup() -> void:
	super._setup()
	if bake_mode:
		return
	# under the cards: their shadows on the map and the thread between a matching pair, which so never lies across a
	# picture
	_under = Control.new()
	_under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_under.set_anchors_preset(Control.PRESET_FULL_RECT)
	_under.draw.connect(func() -> void: _draw_link(_under))
	add_child(_under)
	_layer = Node2D.new()
	add_child(_layer)
	for k in SHOWN + 1:
		var c: Node2D = CARD.new()
		_layer.add_child(c)
		c.set("fit", 1)
		c.set("fixed_aspect", CH / CW)
		c.call("set_frame", 8, 8)
		c.set("burn_side", k % 4)
		c.call("set_photo", true)
		c.call("set_width", 200.0)
		_cards.append(c)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(func() -> void: _draw_cord(_over))
	add_child(_over)
	if _top != null:
		move_child(_top, get_child_count() - 1)

# the stream read from its third card, so the very first beat is a match and the thread shows at once
func _seq(i: int) -> int:
	return int(STREAM[posmod(i + 1, STREAM.size())])

func _tex(n: int) -> Texture2D:
	var p: String = "res://art/dinos/dino%d.jpg" % n
	return load(p) if ResourceLoader.exists(p) else null

func _route_build() -> void:
	if not _route_pts.is_empty():
		return
	for i in ROUTE.size() - 1:
		var p0: Vector2 = ROUTE[maxi(i - 1, 0)]
		var p1: Vector2 = ROUTE[i]
		var p2: Vector2 = ROUTE[i + 1]
		var p3: Vector2 = ROUTE[mini(i + 2, ROUTE.size() - 1)]
		for k in 16:
			var u: float = float(k) / 16.0
			var q: Vector2 = 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)
			_route_pts.append(Vector3(q.x, 0.0, q.y))
	var last: Vector2 = ROUTE[ROUTE.size() - 1]
	_route_pts.append(Vector3(last.x, 0.0, last.y))
	_route_cum.append(0.0)
	for i2 in range(1, _route_pts.size()):
		_route_cum.append(_route_cum[i2 - 1] + _route_pts[i2].distance_to(_route_pts[i2 - 1]))

# the route's point at a distance along it and the way it runs there (before its start: straight on, off the map)
func _along(sv: float) -> Array:
	_route_build()
	if sv <= 0.0:
		var d0: Vector3 = (_route_pts[1] - _route_pts[0]).normalized()
		return [_route_pts[0] + d0 * sv, d0]
	for i in range(1, _route_pts.size()):
		if _route_cum[i] >= sv:
			var seg: float = maxf(_route_cum[i] - _route_cum[i - 1], 0.001)
			var f: float = (sv - _route_cum[i - 1]) / seg
			# the heading eased between the segments' so a card turns smoothly round a bend
			var d1: Vector3 = (_route_pts[i] - _route_pts[i - 1]).normalized()
			var d2: Vector3 = (_route_pts[mini(i + 1, _route_pts.size() - 1)] - _route_pts[i]).normalized() if i + 1 < _route_pts.size() else d1
			return [_route_pts[i - 1].lerp(_route_pts[i], f), d1.lerp(d2, f).normalized()]
	return [_route_pts[_route_pts.size() - 1], Vector3(0, 0, -1)]

# a card lying flat on the map at `c`, its top toward `ahead`, raised `lift` off the paper: the affine map of its
# local pixels (x across, y down from its top edge) taken from the 3-D camera there
func _card_xform(c: Vector3, ahead: Vector3, tilt: float, lift: float, w_px: float, h_px: float) -> Transform2D:
	var fwd: Vector3 = ahead.rotated(Vector3.UP, tilt)
	var right: Vector3 = fwd.cross(Vector3.UP).normalized() * -1.0
	var down: Vector3 = -fwd
	var at: Vector3 = c + Vector3(0.0, 1.5 + lift, 0.0)
	var top_c: Vector3 = at - down * CH * 0.5
	var o: Vector2 = screen_of(top_c - right * CW * 0.5)
	var ex: Vector2 = (screen_of(top_c + right * CW * 0.5) - o) / w_px
	var ey: Vector2 = (screen_of(top_c - right * CW * 0.5 + down * CH) - o) / h_px
	return Transform2D(ex, ey, o)

# where the card `pos` places back lies, which way, and how it is turned a little on the paper
func _slot(pos: float, idx: int) -> Array:
	var a: Array = _along(CARD_AT + pos * SPACING)
	return [a[0], a[1], (h01(idx * 13 + 5) - 0.5) * 0.30]

func _tick(delta: float) -> void:
	super._tick(delta)
	if bake_mode or _cam3 == null or _cards.is_empty():
		return
	var n: int = int(t / STEP)
	var u: float = fmod(t, STEP) / STEP
	# the line moves on in the first part of a beat, every card along the route together, easing in and out
	var shift: float = smoothstep(0.0, 0.45, u)
	for k in _cards.size():
		var c: Node2D = _cards[k]
		var idx: int = n - k + 1                           # the picture this slot shows
		if _dressed != n:
			c.call("setup", _tex(_seq(idx)), Color(1, 1, 1))
			c.call("set_width", 200.0)
		var pos: float = float(k) - 1.0 + shift          # slot 0 is the arriving card, coming on from the near edge
		var sl: Array = _slot(pos, idx)
		# a card in motion lifts a hair off the paper, as a slid card does
		var lift: float = 4.0 * sin(clampf(u / 0.45, 0.0, 1.0) * PI)
		var h_px: float = float(c.call("card_height"))
		c.transform = _card_xform(sl[0], sl[1], sl[2], lift, 200.0, h_px)
		c.set_meta("slot", sl)
		# the lamp is at the back left: the cards far from it a little darker; the oldest fading as it leaves
		var leave: float = 1.0 - smoothstep(float(SHOWN) - 1.2, float(SHOWN) - 0.2, pos)
		var dim: float = 0.80 + 0.20 * clampf(1.0 - (sl[0] as Vector3).distance_to(Vector3(-360.0, 0.0, -560.0)) / 1600.0, 0.0, 1.0)
		c.modulate = Color(dim, dim * 0.97, dim * 0.92, leave)
	if _dressed != n:
		_dressed = n
		for k in _cards.size():
			_layer.move_child(_cards[k], _cards.size() - 1 - k)
	_under.queue_redraw()
	_over.queue_redraw()

# under the cards: each one's soft shadow on the map (wider while it is lifted, toward the viewer: the lamp is behind),
# then THE THREAD between a matching pair
func _draw_link(d: Control) -> void:
	for k in _cards.size():
		var c: Node2D = _cards[k]
		if c.modulate.a <= 0.02 or not c.has_meta("slot"):
			continue
		var sl: Array = c.get_meta("slot")
		var fwd: Vector3 = (sl[1] as Vector3).rotated(Vector3.UP, float(sl[2]))
		var right: Vector3 = fwd.cross(Vector3.UP).normalized()
		var ctr: Vector3 = (sl[0] as Vector3) + Vector3(6.0, 0.5, 9.0)
		for g in 6:
			var grow: float = 1.0 + 4.0 * float(g)
			var sh_pts: PackedVector2Array = PackedVector2Array()
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				sh_pts.append(screen_of(ctr + right * corner.x * (CW * 0.5 + grow) + fwd * corner.y * (CH * 0.5 + grow)))
			d.draw_colored_polygon(sh_pts, Color(0.06, 0.03, 0.0, 0.06 * c.modulate.a))
	# the matching pair's warm halo on the paper, under the cards
	var a: float = _match_a()
	if a > 0.0:
		for cc in [_cards[0], _cards[N_BACK]]:
			var ctr: Vector2 = (cc as Node2D).transform * Vector2(100.0, float(cc.call("card_height")) * 0.5)
			var rad: float = (cc as Node2D).transform.x.length() * 150.0
			for g in 5:
				d.draw_circle(ctr, rad * (1.0 - 0.16 * float(g)), Color(1.0, 0.78, 0.25, 0.10 * a))

# how strongly the cord shows: from as the new card settles, through the beat, fading as the line moves on -- held
# until then, so it is seen (a brief faint glow under the cards went unnoticed, the user)
func _match_a() -> float:
	var n: int = int(t / STEP)
	var u: float = fmod(t, STEP) / STEP
	if _seq(n + 1) != _seq(n + 1 - N_BACK):
		return 0.0
	return smoothstep(0.28, 0.45, u)

# and the last beat's pair, now one place on along the route: its cord fading out through this beat
func _prev_match_a() -> float:
	var n: int = int(t / STEP)
	var u: float = fmod(t, STEP) / STEP
	if _seq(n) != _seq(n - N_BACK):
		return 0.0
	return 1.0 - smoothstep(0.35, 0.95, u)

# THE CORD between a matching pair: tied to a brass pin pressed into each card's top edge, a gilt cord bowing out to
# the side between them -- its shadow on the paper, the deep gold body, a bright line along it, sparkles running
func _draw_cord(d: Control) -> void:
	_cord(d, _cards[0], _cards[N_BACK], _match_a())
	_cord(d, _cards[1], _cards[N_BACK + 1], _prev_match_a())

func _cord(d: Control, c0: Node2D, c1: Node2D, a: float) -> void:
	if a <= 0.0:
		return
	var p0: Vector2 = c0.transform * Vector2(100.0, 14.0)
	var p1: Vector2 = c1.transform * Vector2(100.0, 14.0)
	var side: Vector2 = (p1 - p0).orthogonal().normalized()
	if side.x > 0.0:
		side = -side
	var ctrl: Vector2 = (p0 + p1) * 0.5 + side * p0.distance_to(p1) * 0.55
	var pts: Array = []
	var n_pts: int = 40
	for k in n_pts + 1:
		var f: float = float(k) / float(n_pts)
		# drawn on from the new card toward the old one as it appears
		var grow: float = clampf(a * 1.4, 0.0, 1.0)
		var ff: float = f * grow
		pts.append(p0.lerp(ctrl, ff).lerp(ctrl.lerp(p1, ff), ff))
	for k in n_pts:
		d.draw_line(pts[k] + Vector2(3.0, 5.0), pts[k + 1] + Vector2(3.0, 5.0), Color(0.15, 0.08, 0.0, 0.30 * a), 9.0, true)
	for k in n_pts:
		d.draw_line(pts[k], pts[k + 1], Color(0.52, 0.32, 0.05, a), 7.0, true)
	for k in n_pts:
		d.draw_line(pts[k], pts[k + 1], Color(1.0, 0.80, 0.32, a), 4.0, true)
	for k in n_pts:
		d.draw_line(pts[k] + Vector2(-0.8, -1.3), pts[k + 1] + Vector2(-0.8, -1.3), Color(1.0, 0.97, 0.82, 0.9 * a), 1.5, true)
	for k in 5:
		var f3: float = fmod(t * 0.45 + float(k) / 5.0, 1.0)
		var sp: Vector2 = pts[int(f3 * float(n_pts))]
		var tw: float = sin(f3 * PI)
		for g2 in 4:
			d.draw_circle(sp, (8.0 - 1.8 * float(g2)) * tw, Color(1.0, 0.95, 0.75, 0.16 * a))
		d.draw_circle(sp, 2.2 * tw, Color(1, 1, 1, a))
	# the PINS: a domed brass head with its shadow and a glint
	for pin in [p0, p1]:
		var pp: Vector2 = pin
		d.draw_circle(pp + Vector2(2.0, 3.0), 7.0, Color(0.0, 0.0, 0.0, 0.35 * a))
		d.draw_circle(pp, 7.0, Color(0.55, 0.38, 0.12, a))
		d.draw_circle(pp + Vector2(-0.8, -0.8), 5.6, Color(0.90, 0.70, 0.32, a))
		d.draw_circle(pp + Vector2(-2.2, -2.4), 2.0, Color(1.0, 0.96, 0.82, a))

# --- the desk: real 3-D, baked -----------------------------------------------------------------------------------

func _baked_path() -> String:
	return "res://dinoback/art/menu_desk.webp" if mobile else "res://dinoback/art/menu_desk_d.webp"

func _eye() -> Vector3:
	return Vector3(0.0, 1050.0, 900.0) if mobile else Vector3(0.0, 1150.0, 1150.0)

func _aim() -> Vector3:
	return Vector3(0.0, 0.0, -230.0) if mobile else Vector3(0.0, 0.0, -260.0)

func _fov() -> float:
	return 50.0

func _frame_frac() -> float:
	return 0.5

func _environment(env: Environment) -> void:
	env.background_color = Color(0.03, 0.025, 0.02)
	env.ambient_light_color = Color(0.70, 0.58, 0.46)
	env.ambient_light_energy = 0.26

const LAMP: Vector3 = Vector3(-400.0, 0.0, -640.0)

func _build_lights() -> void:
	# the oil lamp's flame, warm, low over the desk (its long soft shadows run toward you); a cool fill from the
	# window side; a dim warm bounce from the front so the near edge is not lost
	light(LAMP + Vector3(0.0, 236.0, 0.0), Color(1.0, 0.76, 0.44), 4.2, 2400.0, true)
	light(Vector3(700.0, 700.0, 300.0), Color(0.55, 0.62, 0.95), 0.9, 2000.0)
	light(Vector3(0.0, 500.0, 900.0), Color(1.0, 0.82, 0.62), 0.6, 1500.0)

# the parchment: aged paper, stains and foxing, darker edges, two creases; the land in sepia contours, the sea washed
# blue-gray with hatching along the coast, a river, a compass rose, and the route dotted in red-brown
func _map_tex(w: int, h: int) -> ImageTexture:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.006
	noise.fractal_octaves = 5
	var stain: FastNoiseLite = FastNoiseLite.new()
	stain.seed = 4
	stain.frequency = 0.02
	for y in h:
		for x in w:
			var land: float = noise.get_noise_2d(float(x), float(y)) + 0.10 - 0.25 * pow(absf(float(x) / float(w) - 0.5) * 2.0, 3.0)
			var paper: Color = Color(0.86, 0.78, 0.60)
			var c: Color = paper
			if land < 0.0:
				c = paper.lerp(Color(0.56, 0.62, 0.62), clampf(-land * 2.5, 0.25, 0.55))
				# hatching along the coast
				if land > -0.06 and (x + y) % 5 == 0:
					c = c.darkened(0.25)
			else:
				# contour lines every step of height
				var hgt: float = land * 14.0
				if absf(hgt - round(hgt)) < 0.06:
					c = c.lerp(Color(0.42, 0.28, 0.14), 0.55)
				c = c.darkened(0.06 * land)
			# the coast's ink line
			if absf(land) < 0.008:
				c = Color(0.30, 0.20, 0.10)
			var st: float = stain.get_noise_2d(float(x) + 300.0, float(y))
			if st > 0.45:
				c = c.darkened(0.10 * (st - 0.45) * 6.0)
			var ex: float = minf(minf(float(x), float(w - 1 - x)) / float(w), minf(float(y), float(h - 1 - y)) / float(h))
			c = c.darkened(0.35 * (1.0 - smoothstep(0.0, 0.08, ex)))
			# two creases: a darker line with a lighter shoulder
			for cr in [w / 2, w / 4]:
				var dx: int = absi(x - int(cr))
				if dx == 0:
					c = c.darkened(0.18)
				elif dx < 3:
					c = c.lightened(0.05)
			var cy: int = absi(y - h / 2)
			if cy == 0:
				c = c.darkened(0.18)
			img.set_pixel(x, y, c)
	# the compass rose, bottom right: eight points in ink, alternately filled
	var rc: Vector2 = Vector2(float(w) * 0.80, float(h) * 0.86)
	for pt in 16:
		var a: float = TAU * float(pt) / 16.0
		var long_pt: bool = pt % 2 == 0
		var r: float = 44.0 if pt % 4 == 0 else (30.0 if long_pt else 18.0)
		for s in 60:
			var f: float = float(s) / 59.0
			for side in [-1.0, 1.0]:
				var half: float = (1.0 - f) * 5.0
				for hw in int(half) + 1:
					var p: Vector2 = rc + Vector2(cos(a), sin(a)) * r * f + Vector2(-sin(a), cos(a)) * float(hw) * side
					if p.x >= 0.0 and p.y >= 0.0 and p.x < float(w) and p.y < float(h):
						var ink: bool = (side > 0.0) == (pt % 4 < 2)
						img.set_pixel(int(p.x), int(p.y), Color(0.32, 0.20, 0.10) if ink else Color(0.70, 0.30, 0.20))
	for ring_r in [48.0, 52.0]:
		for s2 in 300:
			var a2: float = TAU * float(s2) / 300.0
			var p2: Vector2 = rc + Vector2(cos(a2), sin(a2)) * ring_r
			img.set_pixel(int(p2.x), int(p2.y), Color(0.32, 0.20, 0.10))
	# THE ROUTE, dotted: dashes in red-brown ink along it, from the near edge to the far
	_route_build()
	var total: float = _route_cum[_route_cum.size() - 1]
	var dist: float = 0.0
	while dist < total:
		var a3: Array = _along(dist)
		var mp: Vector3 = a3[0]
		var uv: Vector2 = Vector2((mp.x - MAP_C.x + MAP_W * 0.5) / MAP_W, (mp.z - MAP_C.z + MAP_D * 0.5) / MAP_D)
		var px: Vector2 = uv * Vector2(float(w), float(h))
		if fmod(dist, 26.0) < 15.0:
			for oy in range(-2, 3):
				for ox in range(-2, 3):
					var q: Vector2i = Vector2i(int(px.x) + ox, int(px.y) + oy)
					if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and ox * ox + oy * oy <= 5:
						img.set_pixel(q.x, q.y, Color(0.55, 0.14, 0.08))
		dist += 1.5
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _lathe(profile: Array, m: Material, at: Vector3, segs: int = 32, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
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
	return put(st.commit(), m, at, rot)

func _build_still() -> void:
	var walnut: StandardMaterial3D = mat(Color.WHITE, 0.30, 0.0, tex_wood(256, Color(0.30, 0.17, 0.09), 4), Vector3(3, 2, 1))
	walnut.clearcoat_enabled = true
	walnut.clearcoat = 0.5
	var brass: StandardMaterial3D = mat(Color(0.86, 0.66, 0.32), 0.28, 0.85)
	var glass: StandardMaterial3D = mat(Color(0.85, 0.92, 0.95, 0.22), 0.05, 0.1)
	# THE DESK: a walnut top, its front edge rounded, a green leather inlay showing round the map
	box(Vector3(1800.0, 30.0, 1900.0), walnut, Vector3(0.0, -15.0, -250.0))
	cyl(15.0, 15.0, 1800.0, walnut, Vector3(0.0, -15.0, 700.0), Vector3(0.0, 0.0, 90.0), null, 16)
	box(Vector3(1400.0, 1.0, 1700.0), mat(Color.WHITE, 0.6, 0.0, tex_speckle(128, Color(0.12, 0.24, 0.16), 0.10, 7)), Vector3(0.0, 0.2, -230.0))
	for gl in [[Vector3(1404.0, 1.4, 6.0), Vector3(0.0, 0.5, 620.0)], [Vector3(1404.0, 1.4, 6.0), Vector3(0.0, 0.5, -1080.0)], [Vector3(6.0, 1.4, 1700.0), Vector3(-700.0, 0.5, -230.0)], [Vector3(6.0, 1.4, 1700.0), Vector3(700.0, 0.5, -230.0)]]:
		box(gl[0], mat(Color(0.80, 0.62, 0.30), 0.3, 0.8), gl[1])
	# THE MAP, its corners lifting a little off the leather
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(MAP_W, MAP_D)
	pm.subdivide_width = 16
	pm.subdivide_depth = 24
	var parchment: StandardMaterial3D = mat(Color.WHITE, 0.75, 0.0, _map_tex(640, 968))
	put(pm, parchment, MAP_C + Vector3(0.0, 1.2, 0.0))
	var title_l: Label3D = label("TERRA  DINOSAURIA", 34.0, Color(0.34, 0.20, 0.10), MAP_C + Vector3(110.0, 1.6, -640.0), Vector3(-90.0, 0.0, 0.0))
	title_l.outline_size = 0
	var sub_l: Label3D = label("~ the expedition of 1882 ~", 16.0, Color(0.40, 0.26, 0.14), MAP_C + Vector3(110.0, 1.6, -600.0), Vector3(-90.0, 0.0, 0.0))
	sub_l.outline_size = 0
	# THE OIL LAMP at the back left: a brass foot, a glass font with its oil, the burner, the tall chimney, the flame
	_lathe([Vector2(0.0, 0.0), Vector2(70.0, 0.0), Vector2(72.0, 6.0), Vector2(60.0, 14.0), Vector2(26.0, 26.0), Vector2(18.0, 60.0), Vector2(24.0, 70.0), Vector2(0.0, 72.0)], brass, LAMP)
	# (the glass and the flame cast no shadow: round the light, they put the whole desk in a ring of shade)
	_lathe([Vector2(22.0, 70.0), Vector2(56.0, 96.0), Vector2(62.0, 124.0), Vector2(50.0, 150.0), Vector2(20.0, 162.0)], glass, LAMP, 40).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cyl(46.0, 54.0, 20.0, mat(Color(0.75, 0.55, 0.20, 0.55), 0.1), LAMP + Vector3(0.0, 100.0, 0.0), Vector3.ZERO, null, 32).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lathe([Vector2(20.0, 160.0), Vector2(26.0, 168.0), Vector2(26.0, 186.0), Vector2(18.0, 192.0)], brass, LAMP).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lathe([Vector2(22.0, 190.0), Vector2(36.0, 230.0), Vector2(30.0, 262.0), Vector2(17.0, 290.0), Vector2(17.0, 380.0)], glass, LAMP, 40).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flame: MeshInstance3D = sphere(10.0, glow(Color(1.0, 0.80, 0.42)), LAMP + Vector3(0.0, 222.0, 0.0))
	flame.scale = Vector3(0.7, 1.8, 0.7)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sphere(5.0, glow(Color(1.0, 0.96, 0.85)), LAMP + Vector3(0.0, 214.0, 0.0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# THE MAGNIFYING GLASS lying on the map at the right: a brass rim, the lens, a turned ebony handle
	var mg: Vector3 = Vector3(330.0, 6.0, 260.0)
	var rim: TorusMesh = TorusMesh.new()
	rim.inner_radius = 66.0
	rim.outer_radius = 74.0
	rim.rings = 64
	put(rim, brass, mg)
	var lens: CylinderMesh = CylinderMesh.new()
	lens.top_radius = 67.0
	lens.bottom_radius = 67.0
	lens.height = 3.0
	lens.radial_segments = 48
	put(lens, mat(Color(0.90, 0.95, 1.0, 0.16), 0.02, 0.2), mg)
	var hd: Vector3 = Vector3(cos(0.6), 0.0, sin(0.6))
	_lathe([Vector2(0.0, 0.0), Vector2(7.0, 0.0), Vector2(9.0, 10.0), Vector2(12.0, 20.0), Vector2(10.0, 30.0), Vector2(13.0, 80.0), Vector2(11.0, 120.0), Vector2(14.0, 128.0), Vector2(0.0, 132.0)],
		mat(Color(0.08, 0.05, 0.04), 0.25, 0.1), mg + hd * 72.0 + Vector3(0.0, 4.0, 0.0), 24, Vector3(0.0, -rad_to_deg(0.6), -90.0))
	# THE AMMONITE at the left front: its whorls coiling inward, ribbed, a stone of warm gray-brown
	var amm: Vector3 = Vector3(-380.0, 4.0, 330.0)
	var stone: StandardMaterial3D = mat(Color.WHITE, 0.6, 0.1, tex_speckle(64, Color(0.58, 0.48, 0.36), 0.16, 21))
	# a planispiral: the whorl's tube shrinking as it coils in, each turn resting on the next; a rib every few steps
	var coil_k: float = 0.075
	var turns: float = 3.6
	var steps: int = 220
	for rb in steps:
		var ang: float = turns * TAU * float(rb) / float(steps - 1)
		var rad: float = 92.0 * exp(-coil_k * ang)
		var thick: float = rad * (1.0 - exp(-coil_k * TAU)) * 0.55
		var rib: float = 1.0 + 0.10 * maxf(0.0, sin(ang * 9.0))
		var seg: MeshInstance3D = sphere(thick * rib, stone, amm + Vector3(cos(ang) * rad, thick * 0.85, sin(ang) * rad))
		seg.scale = Vector3(1.0, 0.85, 1.0)
	sphere(8.0, mat(Color(0.30, 0.24, 0.18), 0.8), amm + Vector3(0.0, 2.0, 0.0))
	# THE COMPASS at the near right corner of the map: a brass case, the white card with its needle under glass
	var cmp: Vector3 = Vector3(420.0, 0.0, -60.0)
	_lathe([Vector2(0.0, 0.0), Vector2(46.0, 0.0), Vector2(50.0, 6.0), Vector2(50.0, 18.0), Vector2(44.0, 20.0)], brass, cmp, 40)
	cyl(43.0, 43.0, 1.0, mat(Color(0.94, 0.92, 0.84), 0.6), cmp + Vector3(0.0, 15.0, 0.0), Vector3.ZERO, null, 40)
	for tk in 16:
		var ta: float = TAU * float(tk) / 16.0
		box(Vector3(1.4, 0.6, 6.0 if tk % 4 == 0 else 3.5), mat(Color(0.2, 0.15, 0.1), 0.6), cmp + Vector3(cos(ta) * 37.0, 15.8, sin(ta) * 37.0), Vector3(0.0, -rad_to_deg(ta) + 90.0, 0.0))
	box(Vector3(5.0, 1.6, 32.0), mat(Color(0.75, 0.15, 0.10), 0.4), cmp + Vector3(0.0, 16.6, -14.0), Vector3(0.0, 20.0, 0.0))
	box(Vector3(5.0, 1.6, 32.0), mat(Color(0.15, 0.15, 0.18), 0.4), cmp + Vector3(0.0, 16.6, 14.0), Vector3(0.0, 20.0, 0.0))
	sphere(3.0, brass, cmp + Vector3(0.0, 17.0, 0.0))
	cyl(44.0, 44.0, 1.0, glass, cmp + Vector3(0.0, 19.0, 0.0), Vector3.ZERO, null, 40)
	# THE INKWELL and QUILL at the back right: a square cut-glass well with its brass cap, the quill's vane and shaft
	var ink: Vector3 = Vector3(420.0, 0.0, -700.0)
	box(Vector3(70.0, 56.0, 70.0), mat(Color(0.14, 0.16, 0.22, 0.75), 0.05, 0.2), ink + Vector3(0.0, 28.0, 0.0))
	box(Vector3(56.0, 40.0, 56.0), mat(Color(0.02, 0.02, 0.05), 0.2), ink + Vector3(0.0, 22.0, 0.0))
	cyl(18.0, 18.0, 14.0, brass, ink + Vector3(0.0, 63.0, 0.0), Vector3.ZERO, null, 24)
	var shaft: PackedVector3Array = PackedVector3Array()
	for qk in 12:
		var qf: float = float(qk) / 11.0
		shaft.append(ink + Vector3(-10.0 - 150.0 * qf, 70.0 + 220.0 * qf - 40.0 * qf * qf, 40.0 * qf))
	put(tube_mesh(shaft, 2.0, 6), mat(Color(0.92, 0.88, 0.78), 0.5), Vector3.ZERO)
	var feather: StandardMaterial3D = mat(Color(0.88, 0.84, 0.76), 0.85)
	for vk in 22:
		var vf: float = 0.3 + 0.7 * float(vk) / 21.0
		var vp: Vector3 = ink + Vector3(-10.0 - 150.0 * vf, 70.0 + 220.0 * vf - 40.0 * vf * vf, 40.0 * vf)
		var width: float = 26.0 * sin(PI * (vf - 0.3) / 0.7 * 0.9 + 0.1)
		for sd in [-1.0, 1.0]:
			var barb: MeshInstance3D = box(Vector3(width, 1.0, 4.0), feather, vp + Vector3(sd * width * 0.5 * 0.8, -sd * width * 0.25, 0.0))
			barb.rotation = Vector3(0.0, 0.0, sd * -0.5 + 0.9)
	# BOOKS standing at the back, leather spines with raised bands and gilt titles
	var bx: float = -200.0
	var colors: Array = [Color(0.30, 0.10, 0.08), Color(0.12, 0.20, 0.14), Color(0.32, 0.22, 0.10), Color(0.10, 0.12, 0.22), Color(0.36, 0.14, 0.10), Color(0.18, 0.12, 0.08)]
	for bk in 9:
		var bw: float = 34.0 + 22.0 * h01(bk + 3)
		var bh: float = 220.0 + 80.0 * h01(bk + 7)
		box(Vector3(bw, bh, 170.0), mat(colors[bk % colors.size()], 0.55), Vector3(bx + bw * 0.5, bh * 0.5, -1120.0))
		for band in 4:
			box(Vector3(bw + 1.0, 4.0, 3.0), mat(Color(0.80, 0.62, 0.30), 0.3, 0.8), Vector3(bx + bw * 0.5, bh * (0.18 + 0.2 * float(band)), -1034.0))
		bx += bw + 2.0
	# the dark room behind: paneled wall
	box(Vector3(3000.0, 2000.0, 20.0), mat(Color.WHITE, 0.6, 0.0, tex_wood(128, Color(0.16, 0.09, 0.05), 13), Vector3(6, 4, 1)), Vector3(0.0, 1000.0, -1300.0))

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Dino N-Back", "Does this card match the one N cards back?", Color(0.96, 0.84, 0.52), Color(0.14, 0.08, 0.03),
		Color(1.0, 0.8, 0.4, 0.22))

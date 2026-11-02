extends Control
class_name ParcelArt

# A SORTING-GAME ITEM AS A PARCEL: a real 3-D cardboard box, crumpled and taped, with the pair's two
# items on two equal cards laid on its lid (2026-11-02).
#
# The items were white glyphs on dark tiles, and no amount of styling round them made the screen
# anything but plain. Drawn 2-D boxes were tried first, several times, and always read as cartoons
# of cardboard; this is an actual box -- a mesh with a CC0 cardboard material (art/cardboard/),
# lit by one lamp behind it, so its lid is bright, its front is in shade and the fold between
# them reads.
#
# CHEAP ON A PHONE, by construction:
#   * The 3-D is rendered ONCE per game size, not per item and never per frame: VARIANTS boxes
#     (each its own size, crumple, dents and tape) are rendered into images when a game first asks,
#     a few frames each, and every item after that just picks one. There is no 3-D at all while
#     playing.
#   * The CARDS are not in the 3-D. They are drawn in 2-D over the picture, through the exact
#     mapping of the lid onto the screen (the camera is orthographic, so that mapping is affine and
#     a card drawn through it lies precisely on the lid). So they stay sharp at any resolution, and
#     their colors are exactly the game's -- the rules compare item colors, and a lit, tone-mapped
#     card would shift them.
#
# THE PAIR STAYS TWO EQUAL THINGS (the user's point, and the game's: the player must first work out
# which of the two the rule is about). One box, two cards of the same height, side by side with a
# gap, each turned its own way; a wide card (a stroop word) only gets wider, never taller.
#
# Usage (from a sorting game's item builder):
#     var item: ParcelArt = ParcelArt.make(self, Vector2(bw, item_h), left, right, rng.randi())
# where left / right are {"text": "7"} or {"shape": "★"}, each with "color". The control is
# `unit_size`; keep item_h >= bw * ASPECT so the box fits.

const VARIANTS: int = 16
const ASPECT: float = 0.62             # item height / width the box is framed for
const VIEW_W: float = 0.56             # metres of world across the item's width: the box, and a lane for the rail lights each side
const PITCH: float = 0.87              # the camera looks down at 50 degrees: the box fronts show (62 read as flat lids)
const CARD_H: float = 0.160            # every card's height on the lid, metres
const CARD_GAP: float = 0.022
const MM: float = 1000.0               # card drawing units per metre
const TAG: Color = Color(0.110, 0.122, 0.157)
const TAG_EDGE: Color = Color(0.95, 0.92, 0.84)

static var _sets: Dictionary = {}       # key -> {"tex": Array, "info": Array}
static var _busy: Dictionary = {}       # key -> the renderer working on it

var _key: String = ""
var _variant: int = 0
var _cards: Array = []                  # [{desc, w (m), x (m), z (m), beta}]
var _font_fit: Array = []               # per card: font size in MM units (text cards)
var _info: Dictionary = {}
var _pic: TextureRect = null
var _overlay: Control = null

# THE ITEM IN QUESTION AND THE VERDICT, in the parcels' own world (2026-11-02) -- a flat UI frame
# round a lit 3-D box looked pasted on. In question (set_spotlight): the belt's side rails light up
# in amber LEDs level with the box (see _draw_rail_lights for what was tried before). Answered (stamp): a solid seal -- a green tick or red cross -- thumps onto the box's
# front edge, below the cards, with a small squash of the box.
var _spot: float = 0.0                  # 0..1, eased in/out
var _spot_on: bool = false
var _t: float = 0.0
var _stamp_ok: bool = true
var _stamp_k: float = -1.0              # <0 no stamp; else the stamp's landing, 0..1
var _stamp_rot: float = 0.0

static func make(host: Node, unit_size: Vector2, left: Dictionary, right: Dictionary, seed_i: int) -> ParcelArt:
	var p: ParcelArt = ParcelArt.new()
	p.size = unit_size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var px_scale: float = 1.0
	if host.is_inside_tree():
		px_scale = clampf(host.get_viewport().get_final_transform().get_scale().x, 1.0, 3.0)
	var px: Vector2i = Vector2i(int(round(unit_size.x * px_scale)), int(round(unit_size.y * px_scale)))
	p._key = "%dx%d|%dx%d" % [px.x, px.y, int(unit_size.x), int(unit_size.y)]
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = seed_i
	p._variant = r.randi_range(0, VARIANTS - 1)
	p._layout_cards(left, right, r)
	_ensure(host, p._key, px, unit_size)
	return p

func _ready() -> void:
	_pic = TextureRect.new()
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_SCALE
	_pic.size = size
	add_child(_pic)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.size = size
	_overlay.draw.connect(_draw_cards)
	add_child(_overlay)
	_try_show()

func _process(delta: float) -> void:
	if _info.is_empty():
		_try_show()
	_t += delta
	var target: float = 1.0 if _spot_on else 0.0
	_spot = move_toward(_spot, target, delta * 6.0)
	_overlay.queue_redraw()
	queue_redraw()
	if not _spot_on and _spot <= 0.0 and not _info.is_empty() and _stamp_k < 0.0:
		set_process(false)

func set_spotlight(on: bool) -> void:
	_spot_on = on
	set_process(true)

# The seal fades off: a newer item has become the question (one active item at a time).
func clear_stamp() -> void:
	if _stamp_k < 0.0:
		return
	var tw: Tween = create_tween()
	tw.tween_method(func(k: float) -> void:
		_stamp_k = k
		_overlay.queue_redraw(), _stamp_k, 0.0, 0.15)
	tw.tween_callback(func() -> void:
		_stamp_k = -1.0
		_overlay.queue_redraw())

func stamp(ok: bool) -> void:
	_stamp_ok = ok
	_stamp_rot = randf_range(-0.35, 0.35)
	_stamp_k = 0.0
	set_spotlight(false)
	var tw: Tween = create_tween()
	tw.tween_method(func(k: float) -> void:
		_stamp_k = k
		_overlay.queue_redraw(), 0.0, 1.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# the thump: the box squashes a little under the stamp and springs back
	pivot_offset = size * Vector2(0.5, 0.8)
	var sq: Tween = create_tween()
	sq.tween_interval(0.11)
	sq.tween_property(self, "scale", Vector2(1.03, 0.95), 0.05)
	sq.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Shown as soon as this item's box picture exists (the first items of a game may wait a few frames).
func _try_show() -> void:
	var st: Dictionary = _sets.get(_key, {})
	var texs: Array = st.get("tex", [])
	if _variant < texs.size() and texs[_variant] != null:
		_pic.texture = texs[_variant]
		_info = st["info"][_variant]
		set_process(_spot_on or _spot > 0.0)
		queue_redraw()
		_overlay.queue_redraw()
	else:
		set_process(true)

# --- the cards ----------------------------------------------------------------------------------

func _font_of(desc: Dictionary) -> Font:
	return desc.get("font", MainGlobals.get_system_sans_font())

# Equal heights; a card is as wide as its content needs (at least square), and if the two do not
# fit side by side on the narrowest lid they share the room in proportion and their text shrinks.
func _layout_cards(left: Dictionary, right: Dictionary, r: RandomNumberGenerator) -> void:
	var avail: float = 2.0 * 0.185 - 0.024 - CARD_GAP         # the narrowest lid, less its margins
	var fs0: int = 100
	var nat: Array = []
	for desc: Dictionary in [left, right]:
		var w: float = CARD_H
		if desc.has("text"):
			var tw: float = _font_of(desc).get_string_size(str(desc["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs0).x / MM
			w = maxf(CARD_H, tw + 0.04)
		nat.append(w)
	var widths: Array = nat.duplicate()
	if float(nat[0]) + float(nat[1]) > avail:
		var share: float = clampf(float(nat[0]) / (float(nat[0]) + float(nat[1])), 0.3, 0.7)
		widths = [avail * share, avail * (1.0 - share)]
	var descs: Array = [left, right]
	var total: float = float(widths[0]) + CARD_GAP + float(widths[1])
	for k in 2:
		var w2: float = float(widths[k])
		var x: float = (-total * 0.5 + w2 * 0.5) if k == 0 else (total * 0.5 - w2 * 0.5)
		x += r.randf_range(-0.004, 0.004)
		var beta: float = r.randf_range(-0.10, 0.10) * (CARD_H / w2)
		_cards.append({"desc": descs[k], "w": w2, "x": x, "z": r.randf_range(-0.006, 0.006), "beta": beta})
		var fs: int = fs0
		var d: Dictionary = descs[k]
		if d.has("text"):
			while fs > 30 and _font_of(d).get_string_size(str(d["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / MM > w2 - 0.03:
				fs -= 4
		_font_fit.append(fs)

func _draw() -> void:
	# The box's shadow on the belt, under the picture: its footprint, thrown a little toward the
	# viewer (the lamp is behind), soft-edged.
	if _info.is_empty():
		return
	var foot: PackedVector2Array = _info["foot"]
	# the item in question: a warm glow on the belt round it, UNDER the box (over it, it dimmed the cards)
	if _spot > 0.0:
		var hull: PackedVector2Array = _info["hull"]
		var top: float = INF
		var bot: float = -INF
		for pt in hull:
			top = minf(top, pt.y)
			bot = maxf(bot, pt.y)
		var gc: Vector2 = Vector2(size.x * 0.5, (top + bot) * 0.5)
		for g in 7:
			var f: float = 1.0 - float(g) / 7.0
			var pts: PackedVector2Array = PackedVector2Array()
			for a in 24:
				var ang: float = TAU * float(a) / 24.0
				pts.append(gc + Vector2(cos(ang) * size.x * 0.58 * f, sin(ang) * (bot - top) * 0.80 * f))
			draw_colored_polygon(pts, Color(1.0, 0.62, 0.15, 0.07 * _spot))
	var drop: Vector2 = Vector2(0.0, size.y * 0.035)
	for g in 3:
		for poly: PackedVector2Array in Geometry2D.offset_polygon(foot, size.y * 0.025 * float(3 - g)):
			var moved: PackedVector2Array = PackedVector2Array()
			for pt in poly:
				moved.append(pt + drop)
			draw_colored_polygon(moved, Color(0, 0, 0, 0.13))

func _draw_cards() -> void:
	if _info.is_empty():
		return
	var lid: Transform2D = Transform2D(_info["pu"] / MM, _info["pv"] / MM, _info["o"])
	for k in _cards.size():
		var cd: Dictionary = _cards[k]
		var w: float = float(cd["w"]) * MM
		var h: float = CARD_H * MM
		_overlay.draw_set_transform_matrix(lid * Transform2D(float(cd["beta"]), Vector2(float(cd["x"]) * MM, float(cd["z"]) * MM)))
		var r: Rect2 = Rect2(-w * 0.5, -h * 0.5, w, h)
		var sh: StyleBoxFlat = StyleBoxFlat.new()
		sh.bg_color = Color(0, 0, 0, 0.30)
		sh.set_corner_radius_all(16)
		_overlay.draw_style_box(sh, Rect2(r.position + Vector2(-4.0, 7.0), r.size))
		var tag: StyleBoxFlat = StyleBoxFlat.new()
		tag.bg_color = TAG
		tag.set_corner_radius_all(16)
		tag.border_color = TAG_EDGE
		tag.set_border_width_all(7)
		tag.anti_aliasing = true
		_overlay.draw_style_box(tag, r)
		var d: Dictionary = cd["desc"]
		var col: Color = d.get("color", Sleek.PALETTE["WHITE"])
		if d.has("shape"):
			var side: float = h - 44.0
			Sleek.draw_shape(_overlay, str(d["shape"]), Rect2(-side * 0.5, -side * 0.5, side, side), col)
		else:
			var f: Font = _font_of(d)
			var fs: int = int(_font_fit[k])
			var txt: String = str(d["text"])
			var tsz: Vector2 = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			var base: Vector2 = Vector2(-tsz.x * 0.5, (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
			_overlay.draw_string_outline(f, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0.04, 0.05, 0.08, 0.9))
			_overlay.draw_string(f, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if _stamp_k >= 0.0:
		_draw_stamp(lid)
	_overlay.draw_set_transform_matrix(Transform2D.IDENTITY)
	if _spot > 0.0:
		_draw_rail_lights()

# THE RAIL LIGHTS: a row of amber LEDs along both of the belt's side rails, level with the box in
# question, travelling with it, a chase running through them -- the machine flagging that slot. The
# box itself is left alone (a lifted, lamp-lit box and a red scanner laser were tried and turned
# down).
func _draw_rail_lights() -> void:
	var hull: PackedVector2Array = _info["hull"]
	var top: float = INF
	var bot: float = -INF
	for pt in hull:
		top = minf(top, pt.y)
		bot = maxf(bot, pt.y)
	var k: float = _spot
	var amber: Color = Color(1.0, 0.62, 0.15)
	var n: int = 9
	for side in 2:
		var x: float = 6.0 if side == 0 else size.x - 6.0
		# the lit strip along the rail, level with the box
		_overlay.draw_line(Vector2(x, top - 2.0), Vector2(x, bot + 2.0), Color(amber.r, amber.g, amber.b, 0.25 * k), 12.0)
		_overlay.draw_line(Vector2(x, top - 2.0), Vector2(x, bot + 2.0), Color(1.0, 0.75, 0.30, 0.55 * k), 4.0)
		for i2 in n:
			var y: float = lerpf(top, bot, float(i2) / float(n - 1))
			# the chase: a bright pulse running down the row, the rest steadily lit
			var ph: float = fposmod(_t * 3.0 - float(i2) * 0.30, 2.0)
			var pulse: float = maxf(0.0, 1.0 - absf(ph - 0.5) * 2.0)
			var lit: float = (0.70 + 0.30 * pulse) * k
			_overlay.draw_circle(Vector2(x, y), 14.0, Color(amber.r, amber.g, amber.b, 0.20 * lit))
			_overlay.draw_circle(Vector2(x, y), 8.0, Color(1.0, 0.66, 0.18, 0.50 * lit))
			_overlay.draw_circle(Vector2(x, y), 5.0, Color(1.0, 0.82, 0.38, lit))
			_overlay.draw_circle(Vector2(x, y), 2.2, Color(1.0, 0.97, 0.88, lit))

# The rubber stamp on the lid: an ink ring with a tick or a cross, landing from a little above (big
# and faint) to its place (full ink). Ink, not paint: slightly see-through, the ring broken in a
# couple of places where the stamp did not quite touch.
func _draw_stamp(lid: Transform2D) -> void:
	var k: float = clampf(_stamp_k, 0.0, 1.0)
	var grow: float = lerpf(1.6, 1.0, k)
	# ON THE FRONT EDGE, between and below the cards -- never over them: in MonkeyC the verdict is the
	# evidence, and the player has to see WHAT was marked.
	var at: Vector2 = Vector2(0.0, (float(_info.get("hz", 0.1)) + 0.004) * MM)
	# Placed through the lid, but drawn FACING THE VIEWER: laid in the lid's plane it was squashed on a
	# turned box, and the tick read as an "L".
	var upm: float = (_info["pu"] as Vector2).length() / MM        # item units per drawing unit
	_overlay.draw_set_transform(lid * at, _stamp_rot * 0.5, Vector2(grow, grow) * upm)
	# A SOLID SEAL, not an outline: thin ink lines were lost against both the dark cards and the
	# cardboard. A filled disc in the verdict color with a white mark reads on anything.
	var ink: Color = Color(0.16, 0.70, 0.30) if _stamp_ok else Color(0.90, 0.20, 0.14)
	var rad: float = 80.0
	var a: float = k
	_overlay.draw_circle(Vector2(5.0, 9.0), rad, Color(0, 0, 0, 0.35 * a))
	_overlay.draw_circle(Vector2.ZERO, rad, Color(ink.r, ink.g, ink.b, 0.96 * a))
	_overlay.draw_arc(Vector2.ZERO, rad * 0.82, 0.0, TAU, 48, Color(1, 1, 1, 0.85 * a), 7.0, true)
	_overlay.draw_arc(Vector2.ZERO, rad, 0.0, TAU, 48, Color(ink.r, ink.g, ink.b, a).darkened(0.35), 6.0, true)
	var m: float = rad * 0.50
	var white: Color = Color(1, 1, 1, a)
	if _stamp_ok:
		_overlay.draw_polyline(PackedVector2Array([Vector2(-m * 0.85, 0.0), Vector2(-m * 0.2, m * 0.62), Vector2(m * 0.95, -m * 0.7)]), white, 27.0, true)
	else:
		_overlay.draw_line(Vector2(-m * 0.72, -m * 0.72), Vector2(m * 0.72, m * 0.72), white, 27.0, true)
		_overlay.draw_line(Vector2(m * 0.72, -m * 0.72), Vector2(-m * 0.72, m * 0.72), white, 27.0, true)

# --- rendering the boxes --------------------------------------------------------------------------

# DEPOT PROPS, rendered by the same renderer from the same box builder so they match the parcels:
# "pallet" -- a wooden pallet stacked with crumpled, taped boxes. A few variants, rendered once per
# pixel size; null until ready (draw nothing that frame).
const PROP_VARIANTS: int = 6

static func prop_texture(host: Node, kind: String, variant: int, px: int) -> Texture2D:
	var key: String = "%s|%d" % [kind, px]
	_ensure(host, key, Vector2i(px, px), Vector2(px, px), kind, PROP_VARIANTS)
	var texs: Array = _sets[key]["tex"]
	return texs[variant % PROP_VARIANTS]

static func _ensure(host: Node, key: String, px: Vector2i, unit: Vector2, mode: String = "parcel", count: int = VARIANTS) -> void:
	if not _sets.has(key):
		var texs: Array = []
		var infos: Array = []
		texs.resize(count)
		infos.resize(count)
		_sets[key] = {"tex": texs, "info": infos}
	var running: Variant = _busy.get(key, null)
	if running != null and is_instance_valid(running):
		return
	var done: bool = true
	for t in _sets[key]["tex"]:
		if t == null:
			done = false
	if done or not host.is_inside_tree():
		return
	var rn: _Renderer = _Renderer.new()
	rn.key = key
	rn.px = px
	rn.unit = unit
	rn.mode = mode
	_busy[key] = rn
	host.add_child(rn)

class _Renderer extends Node:
	var key: String = ""
	var mode: String = "parcel"
	var px: Vector2i = Vector2i.ONE
	var unit: Vector2 = Vector2.ONE
	var _vp: SubViewport = null
	var _cam: Camera3D = null
	var _he: Vector3 = Vector3.ONE
	var _r: float = 0.0026
	var _seed_off: Vector3 = Vector3.ZERO
	var _dents: Array = []
	var _noise: FastNoiseLite = FastNoiseLite.new()
	var _mat: StandardMaterial3D = null
	var _tape_mat: StandardMaterial3D = null

	func _ready() -> void:
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 9.0
		_vp = SubViewport.new()
		_vp.size = px
		_vp.own_world_3d = true
		_vp.transparent_bg = true
		_vp.msaa_3d = Viewport.MSAA_4X
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(_vp)
		var env: WorldEnvironment = WorldEnvironment.new()
		var e: Environment = Environment.new()
		e.background_mode = Environment.BG_CLEAR_COLOR
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.85, 0.72, 0.58)
		e.ambient_light_energy = 0.38
		e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.environment = e
		_vp.add_child(env)
		var sun: DirectionalLight3D = DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-58.0, 155.0, 0.0)      # above and BEHIND: lit lid, shaded front
		sun.light_color = Color(1.0, 0.88, 0.72)
		sun.light_energy = 0.80
		sun.shadow_enabled = true
		_vp.add_child(sun)
		_cam = Camera3D.new()
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.keep_aspect = Camera3D.KEEP_WIDTH
		_cam.size = ParcelArt.VIEW_W
		_vp.add_child(_cam)
		_mat = StandardMaterial3D.new()
		_mat.albedo_texture = load("res://art/cardboard/cardboard_color.jpg")
		_mat.albedo_color = Color(0.80, 0.80, 0.90)
		_mat.normal_enabled = true
		_mat.normal_texture = load("res://art/cardboard/cardboard_normal.jpg")
		_mat.roughness_texture = load("res://art/cardboard/cardboard_roughness.jpg")
		_mat.vertex_color_use_as_albedo = true
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_tape_mat = StandardMaterial3D.new()
		_tape_mat.albedo_color = Color(0.80, 0.70, 0.54, 0.80)
		_tape_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tape_mat.roughness = 0.45
		_tape_mat.metallic_specular = 0.35
		_tape_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_tape_mat.vertex_color_use_as_albedo = true
		_run()

	func _run() -> void:
		var st: Dictionary = ParcelArt._sets[key]
		for v in (st["tex"] as Array).size():
			if st["tex"][v] != null:
				continue
			var meshes: Array = _build(v)
			_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			if not is_inside_tree():
				return
			var img: Image = _vp.get_texture().get_image()
			st["info"][v] = _measure() if mode == "parcel" else {}
			st["tex"][v] = ImageTexture.create_from_image(img)
			for m: Node in meshes:
				m.queue_free()
		ParcelArt._busy.erase(key)
		queue_free()

	# Box-space point -> item-control units.
	func _to_unit(world: Vector3) -> Vector2:
		var p: Vector2 = _cam.unproject_position(world)
		return Vector2(p.x * unit.x / float(px.x), p.y * unit.y / float(px.y))

	var _xf: Transform3D = Transform3D.IDENTITY

	func _measure() -> Dictionary:
		var top: float = _he.y
		var o: Vector3 = _xf * Vector3(0, top, 0)
		var ou: Vector2 = _to_unit(o)
		var foot: PackedVector2Array = PackedVector2Array()
		for c in [Vector3(-_he.x, -_he.y, -_he.z), Vector3(_he.x, -_he.y, -_he.z), Vector3(_he.x, -_he.y, _he.z), Vector3(-_he.x, -_he.y, _he.z)]:
			foot.append(_to_unit(_xf * c))
		var all: PackedVector2Array = foot.duplicate()
		for c2 in [Vector3(-_he.x, _he.y, -_he.z), Vector3(_he.x, _he.y, -_he.z), Vector3(_he.x, _he.y, _he.z), Vector3(-_he.x, _he.y, _he.z)]:
			all.append(_to_unit(_xf * c2))
		return {"o": ou, "pu": _to_unit(_xf * Vector3(1, top, 0)) - ou, "pv": _to_unit(_xf * Vector3(0, top, 1)) - ou,
			"foot": foot, "hull": Geometry2D.convex_hull(all), "hz": _he.z, "hx": _he.x, "hy": _he.y,
			"fo": _to_unit(_xf * Vector3(0, top, _he.z)),
			"fx": _to_unit(_xf * Vector3(1, top, _he.z)) - _to_unit(_xf * Vector3(0, top, _he.z)),
			"fy": _to_unit(_xf * Vector3(0, top - 1.0, _he.z)) - _to_unit(_xf * Vector3(0, top, _he.z))}

	# --- the box surface: rounded edges, crumple and dents along the outward direction, and the
	# groove where the lid's two flaps meet ---
	func _surface(f: int, s: float, t: float) -> Array:
		var hx: float = _he.x
		var hy: float = _he.y
		var hz: float = _he.z
		var b: Vector3
		match f:
			0: b = Vector3(lerpf(-hx, hx, s), hy, lerpf(-hz, hz, t))
			1: b = Vector3(lerpf(-hx, hx, s), lerpf(hy, -hy, t), hz)
			2: b = Vector3(hx, lerpf(hy, -hy, t), lerpf(hz, -hz, s))
			3: b = Vector3(-hx, lerpf(hy, -hy, t), lerpf(-hz, hz, s))
			_: b = Vector3(lerpf(hx, -hx, s), lerpf(hy, -hy, t), -hz)
		var inner: Vector3 = b.clamp(-_he + Vector3.ONE * _r, _he - Vector3.ONE * _r)
		var n: Vector3 = (b - inner).normalized()
		var p: Vector3 = inner + n * _r
		var amp: float = 0.0045 if f == 0 else 0.0030
		var disp: float = _noise.get_noise_3dv(p + _seed_off) * amp + _noise.get_noise_3dv((p + _seed_off) * 2.7) * amp * 0.35
		for dn: Array in _dents:
			disp -= float(dn[2]) * exp(-pow(p.distance_to(dn[0]) / float(dn[1]), 2.0))
		if f == 0:
			disp -= 0.0022 * exp(-pow(p.z / 0.0025, 2.0))
		return [p + n * disp, n]

	func _grid(st: SurfaceTool, f: int, s0: float, s1: float, t0: float, t1: float, ns: int, nt: int, lift: float,
			col_fn: Callable, uv_fn: Callable, dt_ds: float = 0.0, ds_dt: float = 0.0) -> void:
		var pts: Array = []
		for j in nt + 1:
			var row: Array = []
			for i in ns + 1:
				var s: float = lerpf(s0, s1, float(i) / float(ns))
				var t: float = lerpf(t0, t1, float(j) / float(nt))
				var s_raw: float = s
				s += ds_dt * (t - 0.5)
				t += dt_ds * (s_raw - 0.5)
				var sp: Array = _surface(f, s, t)
				row.append((sp[0] as Vector3) + (sp[1] as Vector3) * lift)
			pts.append(row)
		for j in nt:
			for i in ns:
				var quad: Array = [pts[j][i], pts[j][i + 1], pts[j + 1][i + 1], pts[j + 1][i]]
				var nrm: Vector3 = ((quad[1] as Vector3) - (quad[0] as Vector3)).cross((quad[3] as Vector3) - (quad[0] as Vector3)).normalized()
				if nrm.dot(quad[0] as Vector3) < 0.0:
					nrm = -nrm
				for k in [0, 1, 2, 0, 2, 3]:
					var q: Vector3 = quad[k]
					st.set_normal(nrm)
					st.set_uv(uv_fn.call(q))
					st.set_color(col_fn.call(q))
					st.add_vertex(q)

	func _build(v: int) -> Array:
		if mode == "pallet":
			return _build_pallet(v)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = v * 7919 + 101
		var he0: Vector3 = Vector3(rng.randf_range(0.185, 0.21), rng.randf_range(0.045, 0.075), rng.randf_range(0.098, 0.108))
		# turned enough that a side shows on most boxes (never nearly square-on)
		var yaw: float = rng.randf_range(0.10, 0.24) * (1.0 if v % 2 == 0 else -1.0)
		_xf = Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)
		_cam.size = ParcelArt.VIEW_W
		var cam_dir: Vector3 = Vector3(0.0, sin(ParcelArt.PITCH), cos(ParcelArt.PITCH))
		_cam.position = cam_dir * 3.0
		_cam.look_at(Vector3.ZERO)
		return _make_box(rng, he0, _xf)

	# A depot prop seen from the same camera, of three kinds by variant so a floor never repeats one
	# pile: (0) a pallet stacked with boxes, a second layer on some; (1) a loose pile of boxes on the
	# floor, crooked, one on top; (2) a pallet with just one or two boxes left on it.
	func _build_pallet(v: int) -> Array:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = v * 104729 + 7
		var kind: int = v % 3
		if kind == 1:
			return _build_loose_pile(rng)
		var nodes: Array = []
		var yaw: float = rng.randf_range(-0.25, 0.25)
		var base: Transform3D = Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)
		var wood: StandardMaterial3D = StandardMaterial3D.new()
		wood.albedo_color = Color(0.62, 0.47, 0.30)
		wood.roughness = 0.85
		var wood_dark: StandardMaterial3D = StandardMaterial3D.new()
		wood_dark.albedo_color = Color(0.42, 0.31, 0.19)
		wood_dark.roughness = 0.9
		var pw: float = 0.80
		var pd: float = 0.62
		var deck_y: float = 0.11
		# blocks and stringers, then the deck boards with gaps
		for bx in [-0.36, 0.0, 0.36]:
			var blk: MeshInstance3D = MeshInstance3D.new()
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(0.09, deck_y - 0.02, pd)
			blk.mesh = bm
			blk.material_override = wood_dark
			blk.transform = base * Transform3D(Basis.IDENTITY, Vector3(bx, (deck_y - 0.02) * 0.5, 0.0))
			_vp.add_child(blk)
			nodes.append(blk)
		var boards: int = 7
		for i in boards:
			var bd: MeshInstance3D = MeshInstance3D.new()
			var dm: BoxMesh = BoxMesh.new()
			dm.size = Vector3(pw, 0.022, pd / float(boards) * 0.78)
			bd.mesh = dm
			bd.material_override = wood if i % 2 == 0 else wood_dark
			var z: float = lerpf(-pd * 0.5, pd * 0.5, (float(i) + 0.5) / float(boards))
			bd.transform = base * Transform3D(Basis(Vector3.UP, rng.randf_range(-0.01, 0.01)), Vector3(0.0, deck_y, z))
			_vp.add_child(bd)
			nodes.append(bd)
		# the load: boxes packed on the deck, never over its edge
		var top_y: float = deck_y + 0.011
		var layers: int = 1 if (rng.randf() < 0.5 or kind == 2) else 2
		for tier in layers:
			var count: int = (rng.randi_range(2, 4) if tier == 0 else rng.randi_range(1, 2)) if kind == 0 else rng.randi_range(1, 2)
			var x0: float = -pw * 0.5 + 0.03
			var tallest: float = 0.0
			for _b in count:
				var hx: float = rng.randf_range(0.10, 0.17)
				if x0 + hx * 2.0 > pw * 0.5 - 0.02:
					break
				var hy: float = rng.randf_range(0.06, 0.12)
				var hz: float = rng.randf_range(0.16, 0.28)
				var cz: float = rng.randf_range(-pd * 0.5 + hz + 0.01, pd * 0.5 - hz - 0.01) if pd * 0.5 - hz - 0.01 > -pd * 0.5 + hz + 0.01 else 0.0
				var bxf: Transform3D = base * Transform3D(Basis(Vector3.UP, rng.randf_range(-0.08, 0.08)), Vector3(x0 + hx, top_y + hy, cz))
				nodes.append_array(_make_box(rng, Vector3(hx, hy, hz), bxf))
				x0 += hx * 2.0 + rng.randf_range(0.01, 0.03)
				tallest = maxf(tallest, hy * 2.0)
			top_y += tallest + 0.004
		_cam.size = 1.05
		var cam_dir2: Vector3 = Vector3(0.0, sin(ParcelArt.PITCH), cos(ParcelArt.PITCH))
		var aim: Vector3 = Vector3(0.0, top_y * 0.4, 0.0)
		_cam.position = aim + cam_dir2 * 3.0
		_cam.look_at(aim)
		return nodes

	# A few boxes dumped on the floor: turned every which way, one sometimes resting on another.
	func _build_loose_pile(rng: RandomNumberGenerator) -> Array:
		var nodes: Array = []
		var count: int = rng.randi_range(2, 4)
		var placed: Array = []          # [centre (Vector2 in x/z), radius, top]
		for _b in count:
			var he: Vector3 = Vector3(rng.randf_range(0.09, 0.16), rng.randf_range(0.06, 0.11), rng.randf_range(0.09, 0.15))
			var at: Vector2 = Vector2(rng.randf_range(-0.22, 0.22), rng.randf_range(-0.16, 0.16))
			var y: float = 0.0
			for pl: Array in placed:
				if at.distance_to(pl[0]) < float(pl[1]) + maxf(he.x, he.z) * 0.6:
					if rng.randf() < 0.5:
						y = maxf(y, float(pl[2]))          # rests on it
					else:
						at += (at - (pl[0] as Vector2)).normalized() * 0.12   # or beside it
			var xf: Transform3D = Transform3D(Basis(Vector3.UP, rng.randf_range(-0.9, 0.9)), Vector3(at.x, y + he.y, at.y))
			nodes.append_array(_make_box(rng, he, xf))
			placed.append([at, maxf(he.x, he.z), y + he.y * 2.0])
		_cam.size = 0.85
		var cam_dir: Vector3 = Vector3(0.0, sin(ParcelArt.PITCH), cos(ParcelArt.PITCH))
		var aim: Vector3 = Vector3(0.0, 0.08, 0.0)
		_cam.position = aim + cam_dir * 3.0
		_cam.look_at(aim)
		return nodes

	# One crumpled, taped box of half-extents `he_in` at `xf`: the crumple, dents and both tape strips
	# are seeded from `rng`. Returns its mesh nodes (box, tape), already added to the scene.
	func _make_box(rng: RandomNumberGenerator, he_in: Vector3, xf: Transform3D) -> Array:
		_he = he_in
		_seed_off = Vector3(rng.randf() * 50.0, rng.randf() * 50.0, rng.randf() * 50.0)
		_dents = []
		for _d in rng.randi_range(0, 2):
			var on_top: bool = rng.randf() < 0.6
			var c: Vector3 = Vector3(rng.randf_range(-0.8, 0.8) * _he.x, _he.y if on_top else rng.randf_range(-0.2, 0.7) * _he.y,
				rng.randf_range(-0.7, 0.7) * _he.z if on_top else _he.z)
			_dents.append([c, rng.randf_range(0.025, 0.05), rng.randf_range(0.004, 0.009)])
		if rng.randf() < 0.5:
			_dents.append([Vector3(_he.x * (1.0 if rng.randf() < 0.5 else -1.0), _he.y, _he.z * (1.0 if rng.randf() < 0.5 else -1.0)), 0.035, 0.012])
		var he: Vector3 = _he
		var rr: float = _r
		var hy: float = _he.y
		# baked occlusion toward the floor, and every fold a little lighter (a worn edge), so the lid's
		# front fold reads between the lit lid and the shaded front
		var col_fn: Callable = func(p: Vector3) -> Color:
			var k: float = lerpf(0.55, 1.0, smoothstep(-hy, hy * 0.6, p.y))
			var near: int = 0
			for ax in 3:
				if absf(p[ax]) > he[ax] - rr * 1.6:
					near += 1
			if near >= 2:
				k *= 1.22
			return Color(k, k, k)
		var uv_top: Callable = func(p: Vector3) -> Vector2: return Vector2(p.x, p.z) / 0.35
		var uv_fb: Callable = func(p: Vector3) -> Vector2: return Vector2(p.x, -p.y) / 0.35 + Vector2(0.37, 0.11)
		var uv_lr: Callable = func(p: Vector3) -> Vector2: return Vector2(p.z, -p.y) / 0.35 + Vector2(0.71, 0.53)
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_grid(st, 0, 0, 1, 0, 1, 28, 14, 0.0, col_fn, uv_top)
		_grid(st, 1, 0, 1, 0, 1, 28, 7, 0.0, col_fn, uv_fb)
		_grid(st, 2, 0, 1, 0, 1, 12, 7, 0.0, col_fn, uv_lr)
		_grid(st, 3, 0, 1, 0, 1, 12, 7, 0.0, col_fn, uv_lr)
		var box: MeshInstance3D = MeshInstance3D.new()
		box.mesh = st.commit()
		box.material_override = _mat
		box.transform = xf
		_vp.add_child(box)
		# TAPE: both strips on every box, each off-center and a little slanted at random --
		# lengthways over both ends and down the sides, crossways between the cards and down the front.
		var tw: float = rng.randf_range(0.022, 0.028)
		var tape_col: Callable = func(p: Vector3) -> Color:
			var k2: float = lerpf(0.75, 1.0, smoothstep(-hy, hy * 0.6, p.y))
			return Color(k2, k2, k2)
		var no_uv: Callable = func(_p: Vector3) -> Vector2: return Vector2.ZERO
		var st2: SurfaceTool = SurfaceTool.new()
		st2.begin(Mesh.PRIMITIVE_TRIANGLES)
		var t_mid: float = 0.5 + rng.randf_range(-0.16, 0.16)
		var t_half: float = tw * 0.5 / (2.0 * _he.z)
		var slope_t: float = rng.randf_range(-0.10, 0.10)
		_grid(st2, 0, 0, 1, t_mid - t_half, t_mid + t_half, 28, 2, 0.0006, tape_col, no_uv, slope_t)
		var t_right: float = t_mid + slope_t * 0.5
		var t_left: float = t_mid - slope_t * 0.5
		_grid(st2, 2, (1.0 - t_right) - t_half, (1.0 - t_right) + t_half, 0, rng.randf_range(0.45, 0.8), 2, 7, 0.0006, tape_col, no_uv)
		_grid(st2, 3, t_left - t_half, t_left + t_half, 0, rng.randf_range(0.45, 0.8), 2, 7, 0.0006, tape_col, no_uv)
		var s_mid: float = 0.5 + rng.randf_range(-0.05, 0.05)
		var s_half: float = tw * 0.5 / (2.0 * _he.x)
		var slope_s: float = rng.randf_range(-0.07, 0.07)
		_grid(st2, 0, s_mid - s_half, s_mid + s_half, 0, 1, 2, 14, 0.0011, tape_col, no_uv, 0.0, slope_s)
		var s_front: float = s_mid + slope_s * 0.5
		_grid(st2, 1, s_front - s_half, s_front + s_half, 0, rng.randf_range(0.5, 0.85), 2, 7, 0.0011, tape_col, no_uv)
		var tape: MeshInstance3D = MeshInstance3D.new()
		tape.mesh = st2.commit()
		tape.material_override = _tape_mat
		tape.transform = xf
		_vp.add_child(tape)
		return [box, tape]

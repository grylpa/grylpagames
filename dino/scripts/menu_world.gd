extends "res://scripts/menu_poster3d.gd"

# DINO'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): the game's own
# dinosaur cards (the shared card, framed as an old print) riding a great turning wheel over A PREHISTORIC LAGOON AT SUNSET, in
# REAL 3-D since 2026-11-18 (the darkened backdrop photo, then a painted lagoon, read flat): calm water rippled and
# glinting with the low sun's path, a smoking volcano with lava running down its flank, hazy ranges, a long-necked
# dinosaur wading in the shallows, palms leaning over the banks, ferns framing the foot. The lagoon is baked, one
# picture per platform (`menu_lagoon.webp`, `menu_lagoon_d.webp`); the cards are live. Staged as a picture, not a
# deal (the user: one card dealt at a time in the middle looked "too much like it's playable"). Made up, never the
# board.

const CARD: GDScript = preload("res://shared/scripts/card.gd")
const CARDS: Array = [3, 14, 21, 8, 27, 11, 19, 5, 24, 16, 9, 30, 12, 26, 7]
# A TURNING WHEEL (the user: the rising card made "disturbing jumps", and the poster was "too slow and
# boring"): the cards ride round a great wheel whose hub is below the screen, its upper arc showing, turning
# steadily; the card passing the top grows, lifts and brightens as it goes by. They are spaced so that no
# two ever overlap, so their stacking never has to change -- nothing can pop.
const SPACING: float = 0.42       # radians between cards on the wheel
const SPEED: float = 0.32          # radians a second

var _layer: Node2D = null
var _cards: Array = []

var _pending: Dictionary = {}       # photo path -> the card it is for (-1: the backdrop)

# photos that have arrived go onto their cards (or the backdrop); everything fades in as it comes
func _take_photos(_delta: float) -> void:
	for path in _pending.keys():
		var st: int = ResourceLoader.load_threaded_get_status(path)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			var tex: Texture2D = ResourceLoader.load_threaded_get(path)
			var k: int = _pending[path]
			_pending.erase(path)
			if k >= 0:
				(_cards[k] as Node2D).call("setup", tex, Color(1, 1, 1))
				(_cards[k] as Node2D).set_meta("photo", true)
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_pending.erase(path)


func _setup() -> void:
	super._setup()
	if bake_mode:
		return
	# THE PHOTOS LOAD ON THREADS (loading them one by one held the menu up for a tenth of a second -- more on a
	# phone): the backdrop and each card fade in as their photo arrives

	var shade: Control = Control.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.draw.connect(func() -> void: _draw_shade(shade))
	add_child(shade)
	_layer = Node2D.new()
	add_child(_layer)
	if _top != null:
		move_child(_top, get_child_count() - 1)

# the cards are made a few a frame (fifteen at once held the first frame up), each fading in with its photo
func _make_cards(n: int) -> void:
	for _i in n:
		if _cards.size() >= CARDS.size():
			return
		var k: int = _cards.size()
		var c: Node2D = CARD.new()
		_layer.add_child(c)
		c.call("set_frame", 8, 8)
		c.call("set_photo", true)
		var p: String = "res://art/dinos/dino%d.jpg" % int(CARDS[k])
		if ResourceLoader.exists(p):
			ResourceLoader.load_threaded_request(p)
			_pending[p] = k
		c.visible = false
		_cards.append(c)

# a vignette, and a warm spotlight behind the fan
func _draw_shade(d: Control) -> void:
	var f: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else f.y * 0.62
	for k in 10:
		d.draw_set_transform(Vector2(f.x * 0.5, bottom * 0.62), 0.0, Vector2(1.0, 0.9))
		d.draw_circle(Vector2.ZERO, f.x * (0.95 - 0.08 * float(k)), Color(1.0, 0.85, 0.55, 0.015))
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	d.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(f.x, 0), Vector2(f.x, f.y * 0.32), Vector2(0, f.y * 0.32)]),
		PackedColorArray([Color(0, 0, 0, 0.25), Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
	for side in [0.0, 1.0]:
		var x0: float = side * f.x
		var x1: float = x0 + (f.x * 0.22 if side == 0.0 else -f.x * 0.22)
		d.draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, f.y), Vector2(x0, f.y)]),
			PackedColorArray([Color(0, 0, 0, 0.30), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.30)]))

# --- THE LAGOON: real 3-D, baked ----------------------------------------------------------------------------------

func _baked_path() -> String:
	return "res://dino/art/menu_lagoon.webp" if mobile else "res://dino/art/menu_lagoon_d.webp"

func _eye() -> Vector3:
	return Vector3(0.0, 110.0, 520.0) if mobile else Vector3(0.0, 130.0, 700.0)

func _aim() -> Vector3:
	return Vector3(0.0, 150.0, -700.0)

func _fov() -> float:
	return 58.0

func _environment(env: Environment) -> void:
	env.background_color = Color(0.16, 0.10, 0.28)      # the sky's own top, so its edge never shows
	env.ambient_light_color = Color(0.90, 0.58, 0.52)
	env.ambient_light_energy = 0.42
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.92, 0.56, 0.44)
	env.fog_depth_begin = 14.0
	env.fog_depth_end = 75.0
	env.fog_density = 0.5
	env.fog_sky_affect = 0.0

func _build_lights() -> void:
	# THE LOW SUN ahead, a little to the right: it lights the near sides warm-gold and lays its glinting path down the
	# water toward you; a violet fill from the open sky behind
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.72, 0.46)
	sun.light_energy = 1.5
	sun.light_specular = 1.4
	sun.rotation_degrees = Vector3(-7.0, 172.0, 0.0)     # its glint path runs from the sun painted in the sky
	root.add_child(sun)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.light_color = Color(0.55, 0.50, 0.85)
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-40.0, 20.0, 0.0)
	root.add_child(fill)

func _sky_tex(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var v: float = float(y) / float(n)
			var c: Color = Color(0.16, 0.10, 0.28).lerp(Color(0.56, 0.24, 0.36), smoothstep(0.05, 0.55, v)).lerp(Color(0.98, 0.54, 0.30), smoothstep(0.50, 0.85, v)).lerp(Color(1.0, 0.80, 0.50), smoothstep(0.85, 1.0, v))
			var sun_d: float = Vector2((float(x) / float(n) - 0.60) * 1.6, v - 0.94).length()
			c = c.lerp(Color(1.0, 0.92, 0.70), clampf(0.9 - sun_d * 3.2, 0.0, 0.9))
			# long clouds lit from below
			var cloud: float = 0.5 + 0.5 * sin(float(x) * 0.045 + sin(float(y) * 0.21) * 1.8 + float(y) * 0.02)
			var band: float = smoothstep(0.30, 0.45, v) * (1.0 - smoothstep(0.62, 0.78, v))
			c = c.lerp(Color(1.0, 0.66, 0.52), 0.35 * band * pow(cloud, 3.0))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# fine ripples, as a normal map: the low sun's light breaks on them into a glittering path
func _ripples(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var hgt: float = 0.5 + 0.18 * sin(float(x) * 0.20 + sin(float(y) * 0.11) * 2.0) + 0.12 * sin(float(y) * 0.45 + float(x) * 0.05) + 0.06 * (h01(x * 31 + y * 17) - 0.5)
			img.set_pixel(x, y, Color(hgt, hgt, hgt))
	img.bump_map_to_normal_map(3.0)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _rock(n: int, base: Color) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var strata: float = 0.5 + 0.5 * sin(float(y) * 0.30 + sin(float(x) * 0.08) * 2.5)
			img.set_pixel(x, y, base.darkened(0.25 * strata + 0.15 * h01(x * 13 + y * 7)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# a frond or a leaf: a tapering strip along a drooping arc, both faces drawn
func _frond(base: Vector3, dir: Vector3, length: float, width: float, droop: float, m: StandardMaterial3D) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side: Vector3 = dir.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var segs: int = 10
	var prev: Array = []
	for i in segs + 1:
		var u: float = float(i) / float(segs)
		var p: Vector3 = base + dir * length * u + Vector3(0.0, -droop * u * u, 0.0)
		var w: float = width * sin(PI * (0.15 + 0.85 * u)) * (1.0 - 0.6 * u)
		# the leaflets fan out and down from the rib, so the frond is a shallow V, not a board
		var l: Vector3 = p - side * w + Vector3(0.0, -w * 0.35, 0.0)
		var r: Vector3 = p + side * w + Vector3(0.0, -w * 0.35, 0.0)
		if i > 0:
			for v in [prev[0], prev[1], p, prev[1], prev[2], p, prev[0], p, l, prev[2], r, p]:
				st.add_vertex(v)
			for v2 in [prev[1], l, p]:
				st.add_vertex(v2)
		prev = [l, p, r]
	st.generate_normals()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	root.add_child(mi)

func _palm(foot: Vector3, lean: Vector3, h: float, leaf: StandardMaterial3D, bark: StandardMaterial3D) -> void:
	# a curving ringed trunk, a crown of drooping fronds, coconuts under them
	var path: PackedVector3Array = PackedVector3Array()
	for i in 12:
		var u: float = float(i) / 11.0
		path.append(foot + Vector3(0.0, h * u, 0.0) + lean * u * u)
	put(tube_mesh(path, 7.0, 12), bark, Vector3.ZERO)
	for rg in 11:
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = 6.0
		ring.outer_radius = 8.6
		put(ring, bark, path[rg] + (path[rg + 1] - path[rg]) * 0.5)
	var top: Vector3 = path[11]
	for f in 9:
		var a: float = TAU * float(f) / 9.0 + h * 0.01
		var dir: Vector3 = Vector3(cos(a), 0.35 + 0.25 * h01(f + int(h)), sin(a)).normalized()
		_frond(top, dir, 110.0 + 20.0 * h01(f + 3), 18.0, 70.0, leaf)
	for cn in 3:
		sphere(6.5, mat(Color(0.30, 0.20, 0.10), 0.6), top + Vector3(cos(float(cn) * 2.1) * 8.0, -8.0, sin(float(cn) * 2.1) * 8.0))

func _build_still() -> void:
	var sky: StandardMaterial3D = mat(Color.WHITE, 1.0, 0.0, _sky_tex(256))
	sky.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky.disable_fog = true
	sky.texture_repeat = false
	box(Vector3(12000.0, 5400.0, 2.0), sky, Vector3(0.0, 2400.0, -5000.0))
	sphere(150.0, glow(Color(1.0, 0.90, 0.66)), Vector3(1200.0, 250.0, -4900.0))      # just over the ridge
	# THE WATER: dark, smooth, rippled (a normal map), its color the sky's; the sun's glint path comes off its specular
	var water: StandardMaterial3D = mat(Color(0.30, 0.18, 0.24), 0.10, 0.0)
	water.normal_enabled = true
	water.normal_texture = _ripples(256)
	water.normal_scale = 0.8
	water.uv1_scale = Vector3(24, 24, 1)
	water.metallic_specular = 1.0
	box(Vector3(12000.0, 2.0, 9000.0), water, Vector3(0.0, -1.0, -2500.0))
	# THE RANGES, hazed by distance, and THE VOLCANO on the left: a rugged cone, a glowing crater, lava down its flank,
	# its smoke rising and spreading
	var range_m: StandardMaterial3D = mat(Color.WHITE, 0.9, 0.0, _rock(128, Color(0.36, 0.22, 0.26)), Vector3(4, 2, 1))
	for rg in 9:
		var rx: float = -3000.0 + float(rg) * 760.0
		var rh: float = 260.0 + 220.0 * h01(rg + 10)
		var rm: MeshInstance3D = cyl(30.0, rh * 1.6, rh, range_m, Vector3(rx, rh * 0.5 - 10.0, -3800.0 - 300.0 * h01(rg + 11)), Vector3.ZERO, null, 7)
		rm.rotation.y = h01(rg + 12) * 3.0
		# a shoulder on its flank, so the ridgeline is broken, never a row of cones
		var sh: MeshInstance3D = cyl(40.0, rh * 1.1, rh * 0.62, range_m, Vector3(rx + (h01(rg + 13) - 0.5) * rh * 1.6, rh * 0.31 - 10.0, -3700.0 - 300.0 * h01(rg + 11)), Vector3.ZERO, null, 9)
		sh.rotation.y = h01(rg + 14) * 3.0
	var vc: Vector3 = Vector3(-900.0, 0.0, -2700.0)
	var vrock: StandardMaterial3D = mat(Color.WHITE, 0.95, 0.0, _rock(128, Color(0.26, 0.18, 0.18)), Vector3(6, 3, 1))
	cyl(90.0, 640.0, 620.0, vrock, vc + Vector3(0.0, 300.0, 0.0), Vector3.ZERO, null, 11)
	cyl(96.0, 96.0, 10.0, glow(Color(1.0, 0.46, 0.16)), vc + Vector3(0.0, 612.0, 0.0), Vector3.ZERO, null, 16)
	for lv in 4:
		var la: float = 0.45 + float(lv) * 0.25
		var top_p: Vector3 = vc + Vector3(sin(la) * 92.0, 606.0, cos(la) * 92.0)
		var bot_p: Vector3 = vc + Vector3(sin(la) * (300.0 + 80.0 * h01(lv)), 300.0 - 120.0 * h01(lv + 4), cos(la) * (300.0 + 80.0 * h01(lv)))
		var lpath: PackedVector3Array = PackedVector3Array()
		for i in 8:
			var u: float = float(i) / 7.0
			lpath.append(top_p.lerp(bot_p, u) + Vector3(sin(u * 6.0 + float(lv)) * 14.0, 0.0, 0.0) + (top_p.lerp(bot_p, u) - vc).normalized() * Vector3(1, 0, 1) * 8.0)
		put(tube_mesh(lpath, 7.0 - float(lv), 6), glow(Color(1.0, 0.40 + 0.08 * float(lv), 0.12)), Vector3.ZERO)
	# the smoke: many faint puffs, overlapping into a soft plume (a few big ones showed their edges like discs)
	var smoke: StandardMaterial3D = mat(Color(0.40, 0.28, 0.32, 0.16), 1.0)
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.cull_mode = BaseMaterial3D.CULL_BACK
	for sm in 46:
		var su: float = float(sm) / 45.0
		var jitter: Vector3 = Vector3(h01(sm + 500) - 0.5, h01(sm + 501) - 0.5, h01(sm + 502) - 0.5) * (60.0 + su * 260.0)
		sphere(50.0 + su * 150.0 * (0.6 + 0.6 * h01(sm + 503)), smoke, vc + Vector3(su * su * 520.0, 660.0 + su * 760.0, -su * 200.0) + jitter)
	# THE BANKS: low shores of sand and grass either side, and a rock or two in the shallows
	var sand: StandardMaterial3D = mat(Color.WHITE, 0.9, 0.0, tex_speckle(128, Color(0.62, 0.48, 0.34), 0.20, 5), Vector3(8, 8, 1))
	var turf: StandardMaterial3D = mat(Color.WHITE, 0.9, 0.0, tex_speckle(128, Color(0.20, 0.30, 0.14), 0.25, 9), Vector3(10, 10, 1))
	for side in [-1.0, 1.0]:
		var bank: MeshInstance3D = sphere(700.0, sand, Vector3(side * 900.0, -560.0, -300.0))
		bank.scale = Vector3(1.0, 1.0, 1.6)
		var grass_bank: MeshInstance3D = sphere(640.0, turf, Vector3(side * 1000.0, -500.0, -320.0))
		grass_bank.scale = Vector3(1.0, 1.0, 1.6)
	var stone: StandardMaterial3D = mat(Color.WHITE, 0.7, 0.0, _rock(64, Color(0.40, 0.34, 0.32)))
	for rk in 5:
		var rkm: MeshInstance3D = sphere(20.0 + 26.0 * h01(rk + 30), stone, Vector3(-300.0 + float(rk) * 170.0 + 60.0 * h01(rk + 31), -6.0, -500.0 - 500.0 * h01(rk + 32)))
		rkm.scale = Vector3(1.3, 0.6, 1.0)
	# THE DINOSAUR wading in the shallows, side-on: its body, the long neck rising and arching, the small head, the
	# tail trailing on the water, a ripple ring round it
	var hide: StandardMaterial3D = mat(Color.WHITE, 0.6, 0.0, tex_speckle(128, Color(0.30, 0.30, 0.26), 0.30, 21), Vector3(3, 3, 1))
	var dc: Vector3 = Vector3(-60.0, 0.0, -1250.0)      # in the clear between the cards' wheel and the title
	var body: MeshInstance3D = sphere(70.0, hide, dc + Vector3(0.0, 24.0, 0.0))
	body.scale = Vector3(1.7, 0.85, 0.9)
	var neck: PackedVector3Array = PackedVector3Array()
	for i in 14:
		var u: float = float(i) / 13.0
		neck.append(dc + Vector3(-90.0 - u * 110.0, 50.0 + sin(u * 1.9) * 230.0, 0.0))
	put(tube_mesh(neck, 13.0, 12), hide, Vector3.ZERO)
	for i in 13:
		sphere(13.0 + (1.0 - float(i) / 13.0) * 9.0, hide, neck[i])
	var head: MeshInstance3D = sphere(18.0, hide, neck[13] + Vector3(-14.0, -2.0, 0.0))
	head.scale = Vector3(1.6, 0.9, 0.9)
	var tail: PackedVector3Array = PackedVector3Array()
	for i in 12:
		var u2: float = float(i) / 11.0
		tail.append(dc + Vector3(110.0 + u2 * 220.0, 30.0 - u2 * 28.0, sin(u2 * 2.5) * 30.0))
	put(tube_mesh(tail, 10.0, 10), hide, Vector3.ZERO)
	for i in 12:
		sphere(16.0 * (1.0 - float(i) / 12.0) + 3.0, hide, tail[i])
	for rr in 2:
		var ring2: TorusMesh = TorusMesh.new()
		ring2.inner_radius = 150.0 + float(rr) * 60.0
		ring2.outer_radius = 154.0 + float(rr) * 60.0
		var ripple: MeshInstance3D = put(ring2, mat(Color(1.0, 0.80, 0.60, 0.35), 0.2), dc + Vector3(0.0, 0.5, 0.0))
		ripple.scale = Vector3(1.0, 0.1, 0.45)
		(ripple.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# PALMS leaning over the banks, and FERNS framing the foot
	var leaf: StandardMaterial3D = mat(Color(0.16, 0.28, 0.10), 0.7)
	leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	var leaf2: StandardMaterial3D = mat(Color(0.22, 0.36, 0.12), 0.7)
	leaf2.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bark: StandardMaterial3D = mat(Color.WHITE, 0.9, 0.0, _rock(64, Color(0.40, 0.30, 0.20)), Vector3(1, 4, 1))
	_palm(Vector3(-420.0, 70.0, -500.0), Vector3(90.0, 0.0, 30.0), 300.0, leaf, bark)
	_palm(Vector3(-560.0, 80.0, -900.0), Vector3(140.0, 0.0, 0.0), 360.0, leaf2, bark)
	_palm(Vector3(470.0, 70.0, -620.0), Vector3(-110.0, 0.0, 20.0), 320.0, leaf, bark)
	_palm(Vector3(640.0, 80.0, -1100.0), Vector3(-60.0, 0.0, 0.0), 380.0, leaf2, bark)
	for fk in 14:
		var fside: float = -1.0 if fk < 7 else 1.0
		var fb: Vector3 = Vector3(fside * (230.0 + 26.0 * float(fk % 7)), -10.0, 280.0 - 20.0 * float(fk % 7))
		var fa: float = (PI if fside < 0.0 else 0.0) + (h01(fk + 70) - 0.5) * 1.6 + fside * -0.4
		_frond(fb, Vector3(cos(fa), 0.9, sin(fa) * 0.6).normalized(), 140.0 + 40.0 * h01(fk + 71), 22.0, 110.0, leaf if fk % 2 == 0 else leaf2)

func _tick(delta: float) -> void:
	super._tick(delta)
	if bake_mode or _layer == null:
		return
	_make_cards(3)
	_take_photos(delta)
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var top: float = 230.0 if mobile else 150.0
	var room: float = maxf(120.0, bottom - top)
	var w: float = minf(full.x * 0.24, room * 0.26)
	var radius: float = (w * 1.35) / SPACING * 1.05        # the cards' arc spacing a little over their width
	var hub: Vector2 = Vector2(full.x * 0.5, top + room * 0.42 + radius)
	var n: int = _cards.size()
	for k in n:
		var c: Node2D = _cards[k]
		c.call("set_width", w)
		var a: float = wrapf(t * SPEED + float(k) * SPACING, -PI, PI)
		var near_top: float = exp(-pow(a / 0.30, 2.0))
		var sc: float = 0.82 + 0.48 * near_top
		var dir: Vector2 = Vector2(sin(a), -cos(a))
		var center: Vector2 = hub + dir * (radius + 26.0 * near_top)
		var half_h: float = float(c.call("card_height")) * 0.5 * sc
		var rot: float = a * (1.0 - 0.6 * near_top)
		c.position = center - Vector2(0.0, half_h).rotated(rot)
		c.rotation = rot
		c.scale = Vector2.ONE * sc
		c.visible = absf(a) < 1.6 and c.has_meta("photo")
		c.modulate = Color(0.72, 0.70, 0.68).lerp(Color(1, 1, 1), near_top)
	# no reordering: no two cards overlap

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Dino", "Swipe to say if you've seen the card already", Color(0.66, 0.92, 0.36), Color(0.08, 0.14, 0.04),
		Color(0.4, 0.8, 0.2, 0.25))

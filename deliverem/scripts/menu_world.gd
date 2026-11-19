extends "res://scripts/menu_poster3d.gd"

# DISPATCH'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A DEPOT YARD IN
# THE LATE AFTERNOON. A brick warehouse with three numbered loading bays -- roll-up doors in their bay's color, a lamp
# over each, a concrete apron -- a road along the front, pallets and a fence, a hazy sky. Along the road comes the
# game's delivery truck: an engine pulling a flatbed cart per delivery, each with its parcel in its bay's color. As it
# passes the bays the rear cart peels off, curves across the apron into ITS bay (the door rolls up for it, the bay's
# number lights), and the door rolls down behind it -- bay 1, then 2, then 3, in order; the engine drives on and out,
# and a while later the next truck comes. The yard is the baked picture, one per platform (`menu_yard.webp`,
# `menu_yard_d.webp`); the truck, the doors and the numbers are live. One clock (`t`); nothing pops (a cart is gone
# only behind its closed door). Made up, never the board.

const BAYS: Array = [-210.0, 0.0, 210.0]         # x of bays 1, 2, 3
const COLS: Array = [Color(0.88, 0.22, 0.20), Color(0.24, 0.50, 0.92), Color(0.96, 0.76, 0.18)]
const ROAD_Z: float = 150.0
const DOCK_Z: float = -40.0                        # a parked cart's place, just inside its door
const FRONT_Z: float = -60.0                       # the warehouse's front wall
const SPEED: float = 150.0
const GAP: float = 92.0                            # engine to first cart, cart to cart
var _enter_x: float = -440.0
var _cyc: float = 0.0                              # the truck's cycle: set from the camera on the first frame
const DOOR_W: float = 130.0
const DOOR_H: float = 120.0

var _engine: Node3D = null
var _carts: Array = []                             # Node3D per cart; cart k (k = 0 nearest the engine) goes to bay 2 - k
var _doors: Array = []
var _plates: Array = []                            # StandardMaterial3D per bay number
var _nums: Array = []                              # StandardMaterial3D per bay number's figure (a TextMesh)

func _baked_path() -> String:
	return "res://deliverem/art/menu_yard.webp" if mobile else "res://deliverem/art/menu_yard_d.webp"

func _eye() -> Vector3:
	return Vector3(60.0, 330.0, 560.0) if mobile else Vector3(60.0, 380.0, 860.0)

func _aim() -> Vector3:
	return Vector3(0.0, 95.0, 0.0) if mobile else Vector3(0.0, 105.0, -10.0)

func _fov() -> float:
	return 52.0

func _scene_top() -> float:
	return 0.0

func _environment(env: Environment) -> void:
	env.background_color = Color(0.62, 0.70, 0.82)
	env.ambient_light_color = Color(0.62, 0.70, 0.88)
	env.ambient_light_energy = 0.32
	# a late-afternoon haze: the distance blued and softened (sky panels left alone) -- in the picture only: the live
	# truck is nearer than the haze begins, and fog in the live view made every live material compile again (~80 ms on
	# the menu's first frame)
	env.fog_enabled = bake_mode
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.74, 0.78, 0.86)
	env.fog_depth_begin = 9.0
	env.fog_depth_end = 40.0
	env.fog_density = 0.35
	env.fog_sky_affect = 0.0

func _build_lights() -> void:
	# the low sun from the left, warm, casting long shadows; a sky fill
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.80, 0.56)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	root.add_child(sun)
	sun.rotation_degrees = Vector3(-38.0, -58.0, 0.0)
	light(Vector3(0.0, 400.0, 600.0), Color(0.85, 0.90, 1.0), 0.6, 1200.0)

# --- textures (2026-11-18, round 3: the user -- "this poster does not follow the rule ... its all still just a cartoon":
# every surface now a real texture with its own NORMAL MAP, so the low sun rakes across mortar, aggregate, ribs and
# leaves) ------------------------------------------------------------------------------------------------------------

# a normal map from a height field (w x h floats, 0..1), `strength` the slope's exaggeration; wraps at the edges
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

# a lit material: albedo and normal map, the texture repeated `uv` times
func _tmat(tex: Array, rough: float, uv: Vector3 = Vector3.ONE, metal: float = 0.0, nscale: float = 1.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = mat(Color.WHITE, rough, metal, tex[0], uv)
	m.normal_enabled = true
	m.normal_texture = tex[1]
	m.normal_scale = nscale
	return m

# mown grass: blades in a fine grain, lighter and darker patches, clover, a little bare earth
func _grass(n: int) -> Array:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var hgt: PackedFloat32Array = PackedFloat32Array()
	hgt.resize(n * n)
	var patch_n: FastNoiseLite = FastNoiseLite.new()
	patch_n.seed = 4
	patch_n.frequency = 0.02
	for y in n:
		for x in n:
			var patch: float = 0.5 + 0.5 * patch_n.get_noise_2d(float(x), float(y))
			var blade: float = h01(x * 7 + y * 131)
			var c: Color = Color(0.22, 0.33, 0.12).lerp(Color(0.42, 0.52, 0.22), patch * 0.6 + 0.4 * blade)
			if h01(x * 17 + y * 29) > 0.82:
				c = c.darkened(0.30)
			if h01(x * 31 + y * 7) > 0.94:
				c = c.lightened(0.20).lerp(Color(0.70, 0.66, 0.40), 0.3)
			if patch < 0.12 and h01(x * 3 + y * 5) > 0.5:
				c = Color(0.40, 0.32, 0.22)
			img.set_pixel(x, y, c)
			hgt[y * n + x] = blade
	img.generate_mipmaps()
	return [ImageTexture.create_from_image(img), _normal_map(hgt, n, n, 2.0)]

# OLD RED BRICK in stretcher bond: every brick its own fired color (reds, browns, a burnt dark header now and then),
# its face pitted, an edge chipped here and there; the mortar raked back, gray, sandy. One tile is 8 bricks by 16
# courses (`BRICK_TILE` units)
const BRICK_TILE: Vector2 = Vector2(180.0, 120.0)

func _brick(n: int) -> Array:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var hgt: PackedFloat32Array = PackedFloat32Array()
	hgt.resize(n * n)
	var pit: FastNoiseLite = FastNoiseLite.new()
	pit.seed = 8
	pit.frequency = 0.25
	var bh: int = n / 16
	var bw: int = n / 8
	var mortar: int = maxi(2, n / 160)
	for y in n:
		var row: int = y / bh
		for x in n:
			var off: int = bw / 2 if row % 2 == 1 else 0
			var xo: int = (x + off) % n
			var col_i: int = xo / bw
			var id: int = row * 11 + col_i
			var mx: int = xo % bw
			var my: int = y % bh
			var p: float = pit.get_noise_2d(float(x), float(y))
			var edge: float = float(mini(mini(mx, bw - 1 - mx), mini(my, bh - 1 - my)))
			var chip: bool = edge < float(mortar) + 2.0 and h01(id * 13 + (mx + my) / 3) > 0.86
			if mx < mortar or my < mortar or chip:
				img.set_pixel(x, y, Color(0.58, 0.56, 0.52).darkened(0.12 * h01(x * 3 + y * 7)))
				hgt[y * n + x] = 0.0
				continue
			var fired: float = h01(id * 7)
			var c: Color = Color(0.56, 0.24, 0.16).lerp(Color(0.70, 0.38, 0.24), fired)
			if h01(id * 29) > 0.88:
				c = Color(0.34, 0.17, 0.13)          # an over-fired header, near black
			elif h01(id * 31) > 0.85:
				c = Color(0.66, 0.46, 0.32)          # a pale one
			c = c.darkened(0.10 * p + 0.05 * h01(x * 5 + y * 3))
			if p > 0.55:
				c = c.darkened(0.18)                 # a pit
			img.set_pixel(x, y, c)
			hgt[y * n + x] = 0.8 + 0.2 * smoothstep(0.0, 3.0, edge - float(mortar)) - (0.12 if p > 0.55 else 0.0)
	img.generate_mipmaps()
	return [ImageTexture.create_from_image(img), _normal_map(hgt, n, n, 3.0)]

# CONCRETE: a mottle of cement, fine aggregate, hairline cracks wandering across, rust and oil stains
func _concrete(n: int, base: Color, seed_i: int) -> Array:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var hgt: PackedFloat32Array = PackedFloat32Array()
	hgt.resize(n * n)
	var mot: FastNoiseLite = FastNoiseLite.new()
	mot.seed = seed_i
	mot.frequency = 0.015
	mot.fractal_octaves = 4
	for y in n:
		for x in n:
			var m: float = mot.get_noise_2d(float(x), float(y))
			var c: Color = base.lightened(0.10 * m) if m > 0.0 else base.darkened(-0.14 * m)
			var g: float = h01(x * 17 + y * 31 + seed_i)
			if g > 0.93:
				c = c.lightened(0.12)
			elif g < 0.06:
				c = c.darkened(0.15)
			img.set_pixel(x, y, c)
			hgt[y * n + x] = 0.5 + 0.3 * g
	# hairline cracks: short random walks
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_i * 7 + 1
	for _cr in 5:
		var at: Vector2 = Vector2(rng.randf() * float(n), rng.randf() * float(n))
		var ang: float = rng.randf() * TAU
		for _st in 60 + rng.randi() % 80:
			ang += rng.randf_range(-0.5, 0.5)
			at += Vector2(cos(ang), sin(ang))
			var ix: int = posmod(int(at.x), n)
			var iy: int = posmod(int(at.y), n)
			img.set_pixel(ix, iy, img.get_pixel(ix, iy).darkened(0.40))
			hgt[iy * n + ix] = 0.1
	img.generate_mipmaps()
	return [ImageTexture.create_from_image(img), _normal_map(hgt, n, n, 1.5)]

# ASPHALT: black tar gone gray in the sun, its aggregate standing out, a crack or two sealed with fresh black
func _asphalt(n: int) -> Array:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var hgt: PackedFloat32Array = PackedFloat32Array()
	hgt.resize(n * n)
	var mot: FastNoiseLite = FastNoiseLite.new()
	mot.seed = 21
	mot.frequency = 0.02
	for y in n:
		for x in n:
			var g: float = h01(x * 17 + y * 31)
			var m: float = mot.get_noise_2d(float(x), float(y))
			var c: Color = Color(0.24, 0.24, 0.25).lightened(0.06 * m).darkened(0.12 * (1.0 - g))
			var stone: bool = h01(x * 7 + y * 53 + 11) > 0.92
			if stone:
				c = Color(0.40, 0.39, 0.37).darkened(0.25 * h01(x * 3 + y))
			img.set_pixel(x, y, c)
			hgt[y * n + x] = (0.8 if stone else 0.3) + 0.2 * g
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 33
	for _cr in 3:
		var at: Vector2 = Vector2(rng.randf() * float(n), rng.randf() * float(n))
		var ang: float = rng.randf() * TAU
		for _st in 120:
			ang += rng.randf_range(-0.4, 0.4)
			at += Vector2(cos(ang), sin(ang))
			for wd in 2:
				var ix: int = posmod(int(at.x) + wd, n)
				var iy: int = posmod(int(at.y), n)
				img.set_pixel(ix, iy, Color(0.07, 0.07, 0.08))
				hgt[iy * n + ix] = 0.45
	img.generate_mipmaps()
	return [ImageTexture.create_from_image(img), _normal_map(hgt, n, n, 2.0)]

# FOLIAGE: clusters of leaves, lit on their tops, dark gaps between, for the trees' crowns
func _leaves(n: int, base: Color) -> Array:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var hgt: PackedFloat32Array = PackedFloat32Array()
	hgt.resize(n * n)
	var cl: FastNoiseLite = FastNoiseLite.new()
	cl.seed = 6
	cl.frequency = 0.09
	cl.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	cl.noise_type = FastNoiseLite.TYPE_CELLULAR
	for y in n:
		for x in n:
			var d: float = cl.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var leaf: float = clampf(1.0 - d * 1.6, 0.0, 1.0)
			var c: Color = base.darkened(0.55).lerp(base.lightened(0.15), leaf).lerp(base.lightened(0.3), 0.15 * h01(x * 7 + y * 3))
			img.set_pixel(x, y, c)
			hgt[y * n + x] = leaf
	img.generate_mipmaps()
	return [ImageTexture.create_from_image(img), _normal_map(hgt, n, n, 2.5)]

# BARK: furrows running up the trunk
func _bark(n: int) -> Array:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var hgt: PackedFloat32Array = PackedFloat32Array()
	hgt.resize(n * n)
	for y in n:
		for x in n:
			var f: float = 0.5 + 0.5 * sin(float(x) * 0.8 + 2.0 * sin(float(y) * 0.15 + float(x) * 0.3))
			img.set_pixel(x, y, Color(0.30, 0.24, 0.18).darkened(0.45 * (1.0 - f)))
			hgt[y * n + x] = f
	img.generate_mipmaps()
	return [ImageTexture.create_from_image(img), _normal_map(hgt, n, n, 2.0)]

# THE SKY of a late afternoon: deep blue overhead down to a warm haze at the horizon, a field of cumulus lit warm on
# their sunward (left) sides, their bases gray-violet
func _sky(w: int, h: int) -> ImageTexture:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
	var cl: FastNoiseLite = FastNoiseLite.new()
	cl.seed = 12
	cl.frequency = 0.010
	cl.fractal_octaves = 5
	for y in h:
		var v: float = float(y) / float(h - 1)
		var sky: Color = Color(0.24, 0.38, 0.66).lerp(Color(0.62, 0.70, 0.84), smoothstep(0.0, 0.75, v)).lerp(Color(0.98, 0.84, 0.66), smoothstep(0.65, 1.0, v))
		for x in w:
			var c: Color = sky
			# the clouds: a band of them through the middle height, thinning up and toward the horizon
			var dens: float = cl.get_noise_2d(float(x), float(y) * 2.2) * 0.5 + 0.5
			var band: float = smoothstep(0.08, 0.35, v) * (1.0 - smoothstep(0.62, 0.86, v))
			var cover: float = smoothstep(0.52, 0.72, dens) * band
			if cover > 0.0:
				# lit from the left and above: sample the density a little toward the sun -- thinner there, brighter
				var toward: float = cl.get_noise_2d(float(x) - 6.0, float(y) * 2.2 - 5.0) * 0.5 + 0.5
				var lit: float = clampf(0.55 + (dens - toward) * 6.0, 0.0, 1.0)
				var cc: Color = Color(0.56, 0.54, 0.66).lerp(Color(1.0, 0.92, 0.80), lit)
				c = c.lerp(cc, cover)
			# the sun's glow from the left
			c = c.lerp(Color(1.0, 0.90, 0.70), 0.30 * pow(clampf(1.0 - Vector2(float(x) / float(w) - 0.02, (v - 0.75) * 0.8).length() * 1.8, 0.0, 1.0), 2.0))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# THE DISTANCE beyond the yard: a line of trees and the roofs of the town, blued by the haze; transparent above
func _distance(w: int, h: int) -> ImageTexture:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var tops: FastNoiseLite = FastNoiseLite.new()
	tops.seed = 2
	tops.frequency = 0.03
	tops.fractal_octaves = 4
	for x in w:
		var tree_top: float = 0.62 + 0.10 * tops.get_noise_1d(float(x)) + 0.05 * tops.get_noise_1d(float(x) * 4.0)
		var roof_top: float = 1.0
		var bld: int = x / 37
		if h01(bld * 5) > 0.55:
			roof_top = 0.55 + 0.20 * h01(bld * 3)
		for y in h:
			var v: float = float(y) / float(h - 1)
			var c: Color = Color(0, 0, 0, 0)
			if v > tree_top:
				c = Color(0.46, 0.54, 0.62).lerp(Color(0.36, 0.44, 0.48), smoothstep(tree_top, 1.0, v))
				c = c.darkened(0.08 * h01(x * 3 + y * 7))
				c.a = 1.0
			elif v > roof_top:
				c = Color(0.56, 0.62, 0.72)
				c.a = 1.0
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# GRIME on a wall: darker toward the ground (rain splash, dust) and in streaks down from the coping; black, its alpha
# the amount
func _grime(w: int, h: int) -> ImageTexture:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var st: FastNoiseLite = FastNoiseLite.new()
	st.seed = 17
	st.frequency = 0.06
	for x in w:
		var streak: float = clampf(st.get_noise_1d(float(x)) * 1.6, 0.0, 1.0)
		for y in h:
			var v: float = float(y) / float(h - 1)
			var a: float = 0.40 * pow(smoothstep(0.70, 1.0, v), 1.5) + 0.22 * streak * (1.0 - smoothstep(0.0, 0.55, v)) + 0.05 * h01(x * 7 + y * 3)
			img.set_pixel(x, y, Color(0.06, 0.05, 0.04, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# a brick face as a quad, its bricks always the same size (a box spread its texture over six faces, every stretch at
# its own scale), a little in front of the wall's box; and its grime over it
func _brick_face(x0: float, x1: float, y0: float, y1: float, z: float, brick_tex: Array, grime_tex: ImageTexture) -> void:
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(x1 - x0, y1 - y0)
	var m: StandardMaterial3D = _tmat(brick_tex, 0.9, Vector3((x1 - x0) / BRICK_TILE.x, (y1 - y0) / BRICK_TILE.y, 1.0))
	m.uv1_offset = Vector3(x0 / BRICK_TILE.x, -y1 / BRICK_TILE.y, 0.0)     # (so the courses run on across the gaps)
	put(q, m, Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, z))
	var g: QuadMesh = QuadMesh.new()
	g.size = q.size
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.albedo_texture = grime_tex
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.uv1_scale = Vector3((x1 - x0) / 1120.0, (y1 - y0) / 230.0, 1.0)
	gm.uv1_offset = Vector3((x0 + 560.0) / 1120.0, (230.0 - y1) / 230.0, 0.0)
	var gi: MeshInstance3D = put(g, gm, Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, z + 0.4))
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# CORRUGATED galvanized roofing: the waves in the normal map, the zinc dulled and streaked
func _corrugated(n: int) -> Array:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var hgt: PackedFloat32Array = PackedFloat32Array()
	hgt.resize(n * n)
	for y in n:
		for x in n:
			var v: float = 0.5 + 0.5 * sin(float(x) / float(n) * TAU * 8.0)
			var c: Color = Color(0.50, 0.53, 0.55).lerp(Color(0.62, 0.65, 0.66), v * 0.4).darkened(0.12 * h01(x / 4 * 7 + y / 9 * 3))
			if h01(x / 16 * 13 + 5) > 0.7:
				c = c.lerp(Color(0.46, 0.36, 0.28), 0.25 * float(y) / float(n))
			img.set_pixel(x, y, c)
			hgt[y * n + x] = v
	img.generate_mipmaps()
	return [ImageTexture.create_from_image(img), _normal_map(hgt, n, n, 3.0)]

# --- the yard: baked -----------------------------------------------------------------------------------------------

func _shared_mats() -> void:
	if _tire_m != null:
		return
	_tire_m = mat(Color.WHITE, 0.9, 0.0, _tire_tex(64), Vector3(4, 1, 1))
	_chrome_m = mat(Color(0.86, 0.88, 0.92), 0.12, 0.95)
	_card_tex = _cardboard(32)

func _build_still() -> void:
	_shared_mats()
	var concrete_t: Array = _concrete(256, Color(0.64, 0.62, 0.58), 3)
	var concrete: StandardMaterial3D = _tmat(concrete_t, 0.9, Vector3(8, 2, 1))
	var brick_t: Array = _brick(512)
	var brick_body: StandardMaterial3D = mat(Color(0.50, 0.26, 0.18), 0.9)
	var grime_t: ImageTexture = _grime(256, 64)
	var steel: StandardMaterial3D = mat(Color(0.42, 0.44, 0.48), 0.5, 0.6)
	var wood: StandardMaterial3D = mat(Color.WHITE, 0.8, 0.0, tex_wood(128, Color(0.62, 0.48, 0.30), 5))
	var front: float = FRONT_Z
	# THE SKY, and the town and trees beyond in the haze
	var sky: QuadMesh = QuadMesh.new()
	sky.size = Vector2(5000.0, 1600.0)
	var sky_m: StandardMaterial3D = mat(Color.WHITE, 1.0, 0.0, _sky(512, 256))
	sky_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_m.texture_repeat = false          # (repeating, the bottom rows' mipmaps bled into the top: a line across the sky)
	put(sky, sky_m, Vector3(0.0, 500.0, -1200.0))
	var far_q: QuadMesh = QuadMesh.new()
	far_q.size = Vector2(4400.0, 420.0)
	var far_m: StandardMaterial3D = mat(Color.WHITE, 1.0, 0.0, _distance(1024, 128))
	far_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	far_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	far_m.texture_repeat = false
	var far_i: MeshInstance3D = put(far_q, far_m, Vector3(0.0, 180.0, -1100.0))
	far_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# THE GROUND: grass, the yard's concrete apron, the road, the far footpath and its curbs
	box(Vector3(3000.0, 4.0, 2400.0), _tmat(_grass(256), 1.0, Vector3(30, 24, 1)), Vector3(0.0, -3.0, 0.0))
	box(Vector3(1800.0, 2.0, 300.0), concrete, Vector3(0.0, 0.0, 30.0))
	var asphalt: StandardMaterial3D = _tmat(_asphalt(256), 0.8, Vector3(24, 1, 1), 0.0, 0.6)
	box(Vector3(3000.0, 2.0, 120.0), asphalt, Vector3(0.0, 1.2, ROAD_Z))
	# repair patches, darker and smoother; the worn wheel tracks
	for pt in 7:
		var pm2: MeshInstance3D = box(Vector3(40.0 + 50.0 * h01(pt), 0.3, 18.0 + 20.0 * h01(pt + 3)), mat(Color(0.14, 0.14, 0.15), 0.55), Vector3(-700.0 + float(pt) * 210.0 + 40.0 * h01(pt + 6), 2.3, ROAD_Z + (h01(pt + 9) - 0.5) * 80.0))
		pm2.rotation_degrees = Vector3(0.0, (h01(pt + 12) - 0.5) * 20.0, 0.0)
	for track in [-1.0, 1.0]:
		var tr_m: StandardMaterial3D = mat(Color(0.10, 0.10, 0.11, 0.35), 0.5)
		tr_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		box(Vector3(3000.0, 0.2, 14.0), tr_m, Vector3(0.0, 2.3, ROAD_Z - 26.0 + track * 10.0))
	# the center line: worn paint, each dash a little chipped
	for k in 30:
		box(Vector3(40.0, 0.5, 4.0), mat(Color(0.86, 0.84, 0.74).darkened(0.12 * h01(k)), 0.8), Vector3(-1450.0 + float(k) * 100.0, 2.4, ROAD_Z))
	# CURBSTONES: granite blocks, each a slightly different gray, a joint between them
	for e in [-1.0, 1.0]:
		for cb in 30:
			var curb_m: StandardMaterial3D = _tmat(concrete_t, 0.8, Vector3(1, 1, 1))
			curb_m.albedo_color = Color(1.0, 1.0, 1.0).darkened(0.14 * h01(cb * 3 + int(e) * 50))
			box(Vector3(98.0, 7.0, 9.0), curb_m, Vector3(-1450.0 + float(cb) * 100.0, 3.5, ROAD_Z + e * 64.0))
	# the footpath: cast slabs, each its own tone, a joint between
	for fs in 50:
		var slab_m: StandardMaterial3D = _tmat(concrete_t, 0.85, Vector3(0.3, 0.3, 1))
		slab_m.albedo_color = Color(1.0, 1.0, 1.0).darkened(0.10 * h01(fs * 7 + 3))
		box(Vector3(58.5, 6.0, 58.5), slab_m, Vector3(-1450.0 + float(fs) * 60.0, 3.0, ROAD_Z + 94.0))
	# THE WAREHOUSE: old red brick on a concrete plinth, a precast coping, a corrugated roof; the three bays
	for span in [[-560.0, -275.0], [-145.0, -65.0], [65.0, 145.0], [275.0, 560.0]]:
		var x0: float = span[0]
		var x1: float = span[1]
		box(Vector3(x1 - x0, 230.0, 20.0), brick_body, Vector3((x0 + x1) * 0.5, 115.0, front - 10.0))
		_brick_face(x0, x1, 20.0, 230.0, front + 0.3, brick_t, grime_t)
		# the plinth: cast concrete, a chamfered top
		box(Vector3(x1 - x0, 20.0, 6.0), concrete, Vector3((x0 + x1) * 0.5, 10.0, front + 3.0))
		box(Vector3(x1 - x0, 3.0, 4.0), concrete, Vector3((x0 + x1) * 0.5, 20.5, front + 1.6), Vector3(-40.0, 0.0, 0.0))
	for bx in BAYS:
		box(Vector3(DOOR_W, 230.0 - DOOR_H, 20.0), brick_body, Vector3(float(bx), DOOR_H + (230.0 - DOOR_H) * 0.5, front - 10.0))
		_brick_face(float(bx) - DOOR_W * 0.5, float(bx) + DOOR_W * 0.5, DOOR_H, 230.0, front + 0.3, brick_t, grime_t)
		# a steel lintel over the opening, its flange showing, rust-stained under it
		box(Vector3(DOOR_W + 40.0, 6.0, 3.0), mat(Color(0.26, 0.24, 0.23), 0.6, 0.5), Vector3(float(bx), DOOR_H + 19.0, front + 1.6))
	box(Vector3(1100.0, 230.0, 260.0), brick_body, Vector3(0.0, 115.0, front - 350.0))    # behind the bays, so an open door shows its bay
	var corr: StandardMaterial3D = _tmat(_corrugated(128), 0.45, Vector3(40, 3, 1), 0.6, 1.5)
	box(Vector3(1120.0, 14.0, 430.0), corr, Vector3(0.0, 238.0, front - 205.0))
	# the coping: precast concrete units along the parapet, a drip groove under their nose
	for cp in 14:
		box(Vector3(79.0, 8.0, 30.0), concrete, Vector3(-520.0 + float(cp) * 80.0, 234.0, front - 6.0))
	box(Vector3(1120.0, 1.0, 1.5), mat(Color(0.12, 0.11, 0.10), 0.9), Vector3(0.0, 229.6, front + 8.6))
	# downspouts: a galvanized pipe on brackets, a hopper head under the coping, a shoe at the foot
	for dsx in [-552.0, 552.0]:
		cyl(5.0, 5.0, 214.0, steel, Vector3(dsx, 116.0, front + 7.0))
		put(rbox_mesh(10.0, 8.0, 14.0, 3.0, 1.5), steel, Vector3(dsx, 214.0, front + 8.0))
		for br in 4:
			box(Vector3(14.0, 2.5, 8.0), mat(Color(0.30, 0.30, 0.32), 0.5, 0.7), Vector3(dsx, 40.0 + float(br) * 50.0, front + 4.0))
		cyl(5.0, 5.0, 16.0, steel, Vector3(dsx, 18.0, front + 12.0), Vector3(40.0, 0.0, 0.0))
	# the apron: saw-cut joints, oil and rust stains, TIRE MARKS curving in from the road to each bay
	for jk in 12:
		box(Vector3(1.6, 0.4, 290.0), mat(Color(0.30, 0.29, 0.28), 0.9), Vector3(-550.0 + float(jk) * 100.0, 1.2, 30.0))
	box(Vector3(1800.0, 0.4, 1.6), mat(Color(0.30, 0.29, 0.28), 0.9), Vector3(0.0, 1.2, 40.0))
	for ok in 5:
		var stain_m: StandardMaterial3D = mat(Color(0.12, 0.11, 0.10, 0.35 + 0.2 * h01(ok)), 0.25)
		stain_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var st: MeshInstance3D = cyl(18.0 + 14.0 * h01(ok + 60), 18.0, 0.3, stain_m, Vector3(-400.0 + 190.0 * float(ok) + 40.0 * h01(ok), 1.3, 60.0 + 40.0 * h01(ok + 7)))
		st.scale = Vector3(1.4, 1.0, 0.8)
		st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tire_mark: StandardMaterial3D = mat(Color(0.08, 0.08, 0.08, 0.22), 0.6)
	tire_mark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for tb in BAYS.size():
		for wheel_off in [-20.0, 20.0]:
			var path: PackedVector3Array = PackedVector3Array()
			for tk in 14:
				var pose: Array = _cart_pose(float(BAYS[tb]) - TURN_IN + float(tk) * 16.0, tb)
				var pp: Vector3 = pose[0]
				var side: Vector3 = Vector3(sin(float(pose[1])), 0.0, cos(float(pose[1])))
				path.append(pp + side * wheel_off)
			var tmi: MeshInstance3D = put(tube_mesh(path, 3.0, 4), tire_mark, Vector3(0.0, 1.35, 0.0))
			tmi.scale = Vector3(1.0, 0.1, 1.0)
			tmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bollard_m: StandardMaterial3D = mat(Color(0.95, 0.74, 0.12), 0.45, 0.2)
	for b in BAYS.size():
		var bx2: float = BAYS[b]
		var col: Color = COLS[b]
		# INSIDE THE BAY: a warm lit room -- the back wall lit, a ceiling lamp, racking with stock on it, a pallet
		var inner: StandardMaterial3D = mat(Color(0.52, 0.46, 0.40), 0.85)
		box(Vector3(DOOR_W, DOOR_H, 4.0), inner, Vector3(bx2, DOOR_H * 0.5, front - 140.0))
		box(Vector3(4.0, DOOR_H, 130.0), inner, Vector3(bx2 - DOOR_W * 0.5, DOOR_H * 0.5, front - 75.0))
		box(Vector3(4.0, DOOR_H, 130.0), inner, Vector3(bx2 + DOOR_W * 0.5, DOOR_H * 0.5, front - 75.0))
		box(Vector3(DOOR_W, 4.0, 130.0), mat(Color(0.30, 0.28, 0.26), 0.9), Vector3(bx2, DOOR_H, front - 75.0))
		box(Vector3(DOOR_W, 2.0, 130.0), concrete, Vector3(bx2, 0.5, front - 75.0))
		box(Vector3(40.0, 3.0, 8.0), glow(Color(1.0, 0.94, 0.80)), Vector3(bx2, DOOR_H - 3.0, front - 80.0))
		light(Vector3(bx2, DOOR_H - 12.0, front - 80.0), Color(1.0, 0.86, 0.62), 1.4, 150.0)
		var rack: StandardMaterial3D = mat(Color(0.20, 0.36, 0.62), 0.5, 0.4)
		for rs in [-1.0, 1.0]:
			box(Vector3(4.0, DOOR_H - 10.0, 4.0), rack, Vector3(bx2 + rs * 50.0, (DOOR_H - 10.0) * 0.5, front - 128.0))
		for sh in 3:
			box(Vector3(104.0, 3.0, 22.0), mat(Color(0.95, 0.55, 0.15), 0.5, 0.3), Vector3(bx2, 12.0 + float(sh) * 34.0, front - 126.0))
			for bx_k in 3:
				box(Vector3(24.0, 20.0, 18.0), mat(Color.WHITE, 0.85, 0.0, _card_tex), Vector3(bx2 - 34.0 + float(bx_k) * 32.0 + 6.0 * h01(sh * 3 + bx_k), 24.0 + float(sh) * 34.0, front - 126.0))
		# THE FRAME: a steel channel painted in the bay's color -- a flange on the wall's face with a beveled edge, its
		# return lining the opening, bolted on, the paint worn at the edges; a black rubber seal inside it, the door's
		# guide tracks, and rubber dock bumpers on steel backing plates
		var fm: StandardMaterial3D = mat(Color.WHITE, 0.45, 0.35, tex_speckle(64, col.darkened(0.08), 0.14, 31 + b), Vector3(1, 4, 1))
		var fm_dark: StandardMaterial3D = mat(col.darkened(0.35), 0.5, 0.35)
		var rubber: StandardMaterial3D = mat(Color(0.05, 0.05, 0.05), 0.85)
		var bolt: StandardMaterial3D = mat(Color(0.70, 0.70, 0.72), 0.3, 0.85)
		for e2 in [-1.0, 1.0]:
			var fx: float = bx2 + e2 * (DOOR_W * 0.5 + 8.0)
			put(rbox_mesh(8.0, 3.0, DOOR_H + 16.0, 2.5, 1.2), fm, Vector3(fx, 0.0, front + 3.0))
			box(Vector3(3.0, DOOR_H, 22.0), fm_dark, Vector3(bx2 + e2 * (DOOR_W * 0.5 + 1.5), DOOR_H * 0.5, front - 9.0))
			box(Vector3(2.5, DOOR_H, 3.0), rubber, Vector3(bx2 + e2 * (DOOR_W * 0.5 - 0.5), DOOR_H * 0.5, front - 4.0))
			box(Vector3(4.0, DOOR_H, 6.0), mat(Color(0.36, 0.38, 0.42), 0.4, 0.7), Vector3(bx2 + e2 * (DOOR_W * 0.5 - 3.0), DOOR_H * 0.5, front - 12.0))
			for bt in 6:
				sphere(1.5, bolt, Vector3(fx + e2 * 3.0, 12.0 + float(bt) * 22.0, front + 6.4))
			box(Vector3(20.0, 30.0, 2.0), mat(Color(0.30, 0.31, 0.33), 0.4, 0.8), Vector3(bx2 + e2 * (DOOR_W * 0.5 - 12.0), 20.0, front + 7.0))
			put(rbox_mesh(7.0, 6.0, 24.0, 2.5, 2.0), rubber, Vector3(bx2 + e2 * (DOOR_W * 0.5 - 12.0), 8.0, front + 14.0))
			for bb in [-1.0, 1.0]:
				sphere(1.4, bolt, Vector3(bx2 + e2 * (DOOR_W * 0.5 - 12.0) + bb * 7.0, 30.0, front + 8.2))
			# A BOLLARD beside the bay: a steel post in safety yellow, its domed cap, two black bands, scuffed
			var bp: Vector3 = Vector3(bx2 + e2 * (DOOR_W * 0.5 + 26.0), 0.0, front + 36.0)
			cyl(6.0, 6.0, 70.0, bollard_m, bp + Vector3(0.0, 35.0, 0.0), Vector3.ZERO, null, 20)
			sphere(6.0, bollard_m, bp + Vector3(0.0, 70.0, 0.0), null, true)
			for band in 2:
				cyl(6.1, 6.1, 6.0, mat(Color(0.06, 0.06, 0.06), 0.6), bp + Vector3(0.0, 46.0 + float(band) * 12.0, 0.0), Vector3.ZERO, null, 20)
			cyl(9.0, 9.0, 1.5, mat(Color(0.34, 0.33, 0.32), 0.6, 0.6), bp + Vector3(0.0, 0.8, 0.0), Vector3.ZERO, null, 20)
		put(rbox_mesh(DOOR_W * 0.5 + 16.0, 3.0, 12.0, 2.5, 1.2), fm, Vector3(bx2, DOOR_H, front + 3.0))
		box(Vector3(DOOR_W + 6.0, 3.0, 22.0), fm_dark, Vector3(bx2, DOOR_H - 1.5, front - 9.0))
		for bt2 in 7:
			sphere(1.5, bolt, Vector3(bx2 - DOOR_W * 0.5 - 6.0 + float(bt2) * (DOOR_W + 12.0) / 6.0, DOOR_H + 9.0, front + 6.4))
		# the door's housing: a steel drum box over the opening, inside
		box(Vector3(DOOR_W + 4.0, 16.0, 18.0), mat(Color(0.40, 0.42, 0.45), 0.45, 0.6), Vector3(bx2, DOOR_H - 8.0, front - 20.0))
		# a canopy HIGH over the door (clear of the number's sign below it), its brackets, its lamp under it
		box(Vector3(DOOR_W + 40.0, 4.0, 56.0), steel, Vector3(bx2, DOOR_H + 86.0, front + 26.0), Vector3(-10.0, 0.0, 0.0))
		box(Vector3(DOOR_W + 40.0, 8.0, 3.0), mat(Color(0.20, 0.30, 0.26), 0.5, 0.3), Vector3(bx2, DOOR_H + 80.0, front + 54.0))
		for bk in [-1.0, 1.0]:
			box(Vector3(3.0, 62.0, 3.0), steel, Vector3(bx2 + bk * (DOOR_W * 0.5 + 12.0), DOOR_H + 60.0, front + 26.0), Vector3(-58.0, 0.0, 0.0))
			box(Vector3(5.0, 10.0, 4.0), steel, Vector3(bx2 + bk * (DOOR_W * 0.5 + 12.0), DOOR_H + 38.0, front + 2.0))
		cyl(6.0, 12.0, 8.0, mat(Color(0.20, 0.30, 0.26), 0.5, 0.4), Vector3(bx2, DOOR_H + 78.0, front + 14.0))
		sphere(4.0, glow(Color(1.0, 0.92, 0.70)), Vector3(bx2, DOOR_H + 73.0, front + 14.0))
		# THE NUMBER: an enamel sign on the brick above the door -- a white plate, the bay's color inset, the figure (live:
		# the inset and the figure, opaque, so the canopy's shadow lies on them exactly as on the plate round them)
		var sign_c: Vector3 = Vector3(bx2, DOOR_H + 34.0, front + 1.0)
		put(rbox_mesh(26.0, 20.0, 3.0, 6.0, 1.0), mat(Color(0.95, 0.95, 0.92), 0.3), sign_c, Vector3(90.0, 0.0, 0.0))
		for sx2 in [-1.0, 1.0]:
			for sy2 in [-1.0, 1.0]:
				sphere(1.4, mat(Color(0.75, 0.76, 0.78), 0.3, 0.8), sign_c + Vector3(sx2 * 22.0, sy2 * 17.0, 4.2))
		# painted guide lines on the apron, from the road into the bay: worn yellow
		for e3 in [-1.0, 1.0]:
			box(Vector3(4.0, 0.5, 170.0), mat(Color(0.90, 0.78, 0.26).darkened(0.1 * h01(b * 2 + int(e3))), 0.8), Vector3(bx2 + e3 * 54.0, 1.4, front + 90.0))
	# THE YARD round it: pallets with their loads by the end wall, oil drums, all weathered
	for pk in 4:
		var px: float = -500.0 + float(pk % 2) * 70.0
		var pz: float = front + 50.0 + float(pk / 2) * 30.0
		_pallet(Vector3(px, 0.0, pz), wood)
		box(Vector3(52.0, 40.0, 52.0), mat(Color.WHITE, 0.9, 0.0, _card_tex, Vector3(2, 2, 1)), Vector3(px, 32.0, pz), Vector3(0.0, 4.0 * (h01(pk) - 0.5), 0.0))
		box(Vector3(53.0, 4.0, 53.0), mat(Color(0.86, 0.84, 0.80), 0.4), Vector3(px, 42.0, pz), Vector3(0.0, 4.0 * (h01(pk) - 0.5), 0.0))
	for dk in 3:
		var dp: Vector3 = Vector3(470.0 + float(dk) * 36.0, 0.0, front + 40.0)
		var drum_m: StandardMaterial3D = mat(Color.WHITE, 0.5, 0.3, tex_speckle(64, [Color(0.20, 0.35, 0.55), Color(0.60, 0.15, 0.12), Color(0.20, 0.45, 0.25)][dk], 0.16, 40 + dk))
		cyl(16.0, 16.0, 44.0, drum_m, dp + Vector3(0.0, 22.0, 0.0))
		for rib in 2:
			var rib_ring: TorusMesh = TorusMesh.new()
			rib_ring.inner_radius = 15.6
			rib_ring.outer_radius = 17.2
			put(rib_ring, drum_m, dp + Vector3(0.0, 15.0 + float(rib) * 14.0, 0.0))
		cyl(15.0, 15.0, 1.0, mat(Color(0.30, 0.30, 0.32), 0.5, 0.6), dp + Vector3(0.0, 44.4, 0.0))
		sphere(2.5, mat(Color(0.30, 0.30, 0.32), 0.5, 0.6), dp + Vector3(7.0, 45.0, 4.0), null, true)
	# TREES beyond, either side of the warehouse: a barked trunk forking into boughs, the crown many clumps of leaves
	var bark: StandardMaterial3D = _tmat(_bark(64), 0.95, Vector3(2, 3, 1))
	var leaf_ts: Array = [_leaves(128, Color(0.26, 0.42, 0.18)), _leaves(128, Color(0.34, 0.48, 0.22))]
	for tk in 6:
		var tx: float = (-760.0 if tk < 3 else 760.0) + float(tk % 3) * 90.0 * (1.0 if tk < 3 else -1.0)
		var tz: float = front - 120.0 - float(tk % 3) * 60.0
		cyl(7.0, 10.0, 120.0, bark, Vector3(tx, 60.0, tz), Vector3.ZERO, null, 12)
		for bo in 3:
			var ba: float = TAU * float(bo) / 3.0 + float(tk)
			cyl(3.0, 5.0, 60.0, bark, Vector3(tx + cos(ba) * 14.0, 140.0, tz + sin(ba) * 10.0), Vector3(sin(ba) * 25.0, 0.0, -cos(ba) * 25.0), null, 8)
		var lm: StandardMaterial3D = _tmat(leaf_ts[tk % 2], 0.9, Vector3(2, 2, 1))
		for cl in 14:
			var ca: float = TAU * float(cl) / 7.0 + h01(tk + cl)
			var up: float = h01(tk * 5 + cl)
			var cr: float = 26.0 + 14.0 * h01(tk * 11 + cl)
			var clump: MeshInstance3D = sphere(cr, lm, Vector3(tx + cos(ca) * (30.0 + 20.0 * (1.0 - up)), 150.0 + 80.0 * up, tz + sin(ca) * 26.0))
			clump.scale = Vector3(1.0, 0.82, 1.0)
		sphere(44.0, lm, Vector3(tx, 200.0, tz))

# A PALLET: three runners under a deck of boards, the gaps between them
func _pallet(at: Vector3, wood: StandardMaterial3D) -> void:
	for rn in 3:
		box(Vector3(60.0, 6.0, 8.0), wood, at + Vector3(0.0, 3.0, -24.0 + float(rn) * 24.0))
	for bd in 5:
		box(Vector3(11.0, 2.4, 60.0), wood, at + Vector3(-24.0 + float(bd) * 12.0, 7.2, 0.0))

# --- live: the doors, the numbers, the truck -----------------------------------------------------------------------

# A WHEEL: a treaded tire (its tread a texture round it), a chrome rim, a hub with its nuts
func _wheel(parent: Node3D, x: float, z: float) -> void:
	var side: float = signf(z)
	cyl(11.0, 11.0, 8.0, _tire_m, Vector3(x, 11.0, z), Vector3(90.0, 0.0, 0.0), parent, 28)
	cyl(7.0, 7.0, 8.4, _chrome_m, Vector3(x, 11.0, z), Vector3(90.0, 0.0, 0.0), parent, 24)
	cyl(3.2, 3.2, 9.4, mat(Color(0.25, 0.25, 0.27), 0.4, 0.8), Vector3(x, 11.0, z), Vector3(90.0, 0.0, 0.0), parent, 16)
	for nt in 5:
		var na: float = TAU * float(nt) / 5.0
		sphere(0.9, _chrome_m, Vector3(x + cos(na) * 4.8, 11.0 + sin(na) * 4.8, z + side * 4.4), parent)

func _tire_tex(n: int) -> ImageTexture:
	var img: Image = Image.create(n, 8, false, Image.FORMAT_RGB8)
	for x in n:
		img.fill_rect(Rect2i(x, 0, 1, 8), Color(0.06, 0.06, 0.065) if (x / 3) % 2 == 0 else Color(0.11, 0.11, 0.12))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _cardboard(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			img.set_pixel(x, y, Color(0.70, 0.53, 0.33).darkened(0.07 * h01(x * 13 + y * 5)).lerp(Color(0.60, 0.44, 0.27), 0.25 * float((y / 2) % 2)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _plate_tex(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	img.fill(Color(0.42, 0.44, 0.47))
	for y in range(0, n, 8):
		for x in range(0, n, 8):
			var o: int = 4 if (y / 8) % 2 == 1 else 0
			img.fill_rect(Rect2i((x + o) % n, y + 2, 4, 2), Color(0.60, 0.62, 0.66))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

var _tire_m: StandardMaterial3D = null
var _chrome_m: StandardMaterial3D = null
var _card_tex: ImageTexture = null

func _build_live() -> void:
	_shared_mats()
	# THE ROLL-UP DOORS: ribbed steel in a weathered tone of the bay's color (`_door_tex`, the ribs painted in), grimy
	# toward the foot; a steel bottom rail with its rubber seal and a handle. It ROLLS UP: the curtain's visible height
	# shrinks from the bottom with its ribs keeping their spacing (the texture slides with it, as a real curtain winds onto
	# its drum), and the bottom rail rides up with it
	for b in BAYS.size():
		var door: Node3D = Node3D.new()
		root.add_child(door)
		var dt: ImageTexture = _door_tex(COLS[b])
		# (no normal map on the live doors: its shader variant cost the menu's first frame ~60 ms to compile; the ribs'
		# relief is painted into the texture instead)
		var dm: StandardMaterial3D = mat(Color.WHITE, 0.55, 0.35, dt)
		var curtain_q: QuadMesh = QuadMesh.new()
		curtain_q.size = Vector2(DOOR_W - 2.0, DOOR_H)
		var curtain: MeshInstance3D = put(curtain_q, dm, Vector3(0.0, -DOOR_H * 0.5, 0.0), Vector3.ZERO, door)
		curtain.set_meta("m", dm)
		var foot: Node3D = Node3D.new()
		door.add_child(foot)
		box(Vector3(DOOR_W - 2.0, 4.0, 4.0), mat(Color(0.40, 0.42, 0.45), 0.4, 0.7), Vector3(0.0, 2.0, 0.6), Vector3.ZERO, foot)
		box(Vector3(DOOR_W - 2.0, 2.0, 3.0), mat(Color(0.05, 0.05, 0.05), 0.85), Vector3(0.0, -0.5, 0.6), Vector3.ZERO, foot)
		box(Vector3(22.0, 3.0, 2.0), mat(Color(0.75, 0.76, 0.78), 0.3, 0.85), Vector3(0.0, 9.0, 2.8), Vector3.ZERO, foot)
		for hb in [-1.0, 1.0]:
			box(Vector3(2.0, 4.0, 3.0), mat(Color(0.75, 0.76, 0.78), 0.3, 0.85), Vector3(hb * 10.0, 9.0, 1.6), Vector3.ZERO, foot)
		door.set_meta("curtain", curtain)
		door.set_meta("foot", foot)
		door.position = Vector3(float(BAYS[b]), DOOR_H, FRONT_Z - 8.0)
		_doors.append(door)
		# THE NUMBER: the sign's inset and figure, live and OPAQUE -- a painted plate, its color changing in place when
		# the parcel arrives (muted to bright), the figure a real raised TextMesh. Faded in with alpha, or glowing, it
		# was drawn without the canopy's shadow ("STILL the shadows do not affect the big numbers below them correctly",
		# the user): opaque and lit by the sun like the brick round it, the shadow lies across it exactly
		var sign_c: Vector3 = Vector3(float(BAYS[b]), DOOR_H + 34.0, FRONT_Z + 1.0)
		var pm: StandardMaterial3D = mat(_unlit_col(b), 0.35, 0.05)
		# the canopy and its brackets again, casting shadow only (the live view has its own shadows to cast)
		var cast_m: StandardMaterial3D = mat(Color(0.5, 0.5, 0.5), 0.5)
		var cb: Array = [box(Vector3(DOOR_W + 40.0, 4.0, 56.0), cast_m, Vector3(float(BAYS[b]), DOOR_H + 86.0, FRONT_Z + 26.0), Vector3(-10.0, 0.0, 0.0)),
			box(Vector3(DOOR_W + 40.0, 8.0, 3.0), cast_m, Vector3(float(BAYS[b]), DOOR_H + 80.0, FRONT_Z + 54.0))]
		for bk in [-1.0, 1.0]:
			cb.append(box(Vector3(3.0, 62.0, 3.0), cast_m, Vector3(float(BAYS[b]) + bk * (DOOR_W * 0.5 + 12.0), DOOR_H + 60.0, FRONT_Z + 26.0), Vector3(-58.0, 0.0, 0.0)))
		for cm in cb:
			(cm as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		put(rbox_mesh(23.0, 17.0, 3.6, 4.5, 0.8), pm, sign_c + Vector3(0.0, 0.0, 0.2), Vector3(90.0, 0.0, 0.0))
		var tm: TextMesh = TextMesh.new()
		tm.text = str(b + 1)
		tm.font = MainGlobals.get_text_font()
		tm.font_size = 128
		tm.pixel_size = 30.0 / 128.0
		tm.depth = 1.2
		var fig_m: StandardMaterial3D = mat(Color(0.97, 0.96, 0.92), 0.4)
		var fig: MeshInstance3D = put(tm, fig_m, sign_c + Vector3(0.0, 0.0, 4.6))
		fig.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_nums.append(fig_m)
		_plates.append(pm)
	# THE TRUCK: a cab-over engine and a flatbed cart per delivery, each with its parcel -- every part a shaped,
	# textured, lit thing (flat colored blocks read as toys)
	var paint: StandardMaterial3D = mat(Color(0.12, 0.36, 0.30), 0.22, 0.45)
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.9
	paint.clearcoat_roughness = 0.08
	var stripe: StandardMaterial3D = mat(Color(0.95, 0.78, 0.30), 0.3, 0.5)
	var glass: StandardMaterial3D = mat(Color(0.20, 0.28, 0.36), 0.03, 0.6)
	glass.clearcoat_enabled = true
	var dark: StandardMaterial3D = mat(Color(0.09, 0.09, 0.10), 0.55, 0.5)
	var plate: StandardMaterial3D = mat(Color.WHITE, 0.4, 0.8, _plate_tex(64), Vector3(3, 2, 1))
	var deck: StandardMaterial3D = mat(Color.WHITE, 0.7, 0.0, tex_wood(64, Color(0.55, 0.38, 0.22), 7), Vector3(1, 3, 1))
	_engine = Node3D.new()
	root.add_child(_engine)
	# the chassis and its frame rails
	box(Vector3(78.0, 6.0, 30.0), dark, Vector3(-2.0, 14.0, 0.0), Vector3.ZERO, _engine)
	# the cab: a rounded body, a raked windscreen, side windows, the roof's marker lamps, a pinstripe, the door seam
	put(rbox_mesh(19.0, 21.0, 40.0, 7.0, 4.0), paint, Vector3(16.0, 18.0, 0.0), Vector3.ZERO, _engine)
	box(Vector3(1.4, 15.0, 34.0), glass, Vector3(34.6, 46.0, 0.0), Vector3(0.0, 0.0, 10.0), _engine)
	for e in [-1.0, 1.0]:
		box(Vector3(20.0, 12.0, 1.0), glass, Vector3(14.0, 46.0, e * 21.2), Vector3.ZERO, _engine)
		box(Vector3(36.0, 1.6, 0.6), stripe, Vector3(16.0, 30.0, e * 21.6), Vector3.ZERO, _engine)
		box(Vector3(0.5, 22.0, 0.6), mat(Color(0.05, 0.08, 0.07), 0.6), Vector3(4.0, 36.0, e * 21.4), Vector3.ZERO, _engine)
		box(Vector3(5.0, 1.4, 0.8), _chrome_m, Vector3(8.0, 38.0, e * 21.8), Vector3.ZERO, _engine)
		# a step under the door, a fender arching over each wheel
		box(Vector3(14.0, 2.0, 5.0), plate, Vector3(14.0, 8.0, e * 20.0), Vector3.ZERO, _engine)
		# a FENDER over each wheel: a curved arch of plate following the tire's top (full discs read as more wheels)
		for fx in [22.0, -18.0]:
			for seg in 7:
				var fa: float = PI * (0.08 + 0.84 * float(seg) / 6.0)
				box(Vector3(5.4, 1.4, 10.0), dark, Vector3(fx + cos(fa) * 14.0, 11.0 + sin(fa) * 14.0, e * 18.0), Vector3(0.0, 0.0, rad_to_deg(fa) - 90.0), _engine)
		# the headlamps: chrome bezels round bright lenses; mirrors on arms
		cyl(4.4, 4.4, 2.0, _chrome_m, Vector3(35.4, 26.0, e * 13.0), Vector3(0.0, 0.0, 90.0), _engine, 20)
		cyl(3.4, 3.4, 2.4, glow(Color(1.0, 0.97, 0.86)), Vector3(36.0, 26.0, e * 13.0), Vector3(0.0, 0.0, 90.0), _engine, 20)
		box(Vector3(2.0, 1.4, 9.0), dark, Vector3(28.0, 52.0, e * 25.0), Vector3.ZERO, _engine)
		put(rbox_mesh(1.6, 2.6, 9.0, 1.0, 0.5), dark, Vector3(28.0, 46.0, e * 30.0), Vector3.ZERO, _engine)
	for ml in 3:
		sphere(1.5, glow(Color(1.0, 0.70, 0.25)), Vector3(30.0, 58.5, -8.0 + float(ml) * 8.0), _engine)
	# the grille and the bumper, chrome; a fuel tank on the frame, an exhaust stack
	box(Vector3(1.6, 12.0, 20.0), dark, Vector3(35.8, 26.0, 0.0), Vector3.ZERO, _engine)
	for gb in 5:
		box(Vector3(2.0, 1.0, 19.0), _chrome_m, Vector3(36.2, 21.0 + float(gb) * 2.6, 0.0), Vector3.ZERO, _engine)
	put(rbox_mesh(2.4, 22.0, 5.0, 2.0, 1.0), _chrome_m, Vector3(37.6, 11.0, 0.0), Vector3.ZERO, _engine)
	cyl(5.0, 5.0, 18.0, _chrome_m, Vector3(-8.0, 14.0, -17.0), Vector3(0.0, 0.0, 90.0), _engine, 20)
	cyl(2.2, 2.2, 34.0, _chrome_m, Vector3(-4.0, 52.0, 18.0), Vector3.ZERO, _engine, 12)
	cyl(2.6, 2.2, 4.0, dark, Vector3(-4.0, 70.0, 18.0), Vector3.ZERO, _engine, 12)
	_wheel(_engine, 22.0, 18.0)
	_wheel(_engine, 22.0, -18.0)
	_wheel(_engine, -18.0, 18.0)
	_wheel(_engine, -18.0, -18.0)
	for k in 3:
		var cart: Node3D = Node3D.new()
		root.add_child(cart)
		# a steel frame, a wooden deck of planks, stake sides, fenders, a drawbar to the one in front
		box(Vector3(72.0, 4.0, 40.0), plate, Vector3(0.0, 19.0, 0.0), Vector3.ZERO, cart)
		box(Vector3(70.0, 2.0, 38.0), deck, Vector3(0.0, 22.0, 0.0), Vector3.ZERO, cart)
		for pl in 6:
			box(Vector3(70.2, 0.4, 0.6), mat(Color(0.28, 0.18, 0.10), 0.8), Vector3(0.0, 23.1, -15.8 + float(pl) * 6.3), Vector3.ZERO, cart)
		for rs in [-1.0, 1.0]:
			for rp in 4:
				box(Vector3(2.4, 14.0, 2.4), plate, Vector3(-30.0 + float(rp) * 20.0, 30.0, rs * 19.5), Vector3.ZERO, cart)
			box(Vector3(66.0, 2.0, 1.6), deck, Vector3(0.0, 35.0, rs * 19.5), Vector3.ZERO, cart)
			box(Vector3(66.0, 2.0, 1.6), deck, Vector3(0.0, 29.0, rs * 19.5), Vector3.ZERO, cart)
		cyl(1.8, 1.8, 22.0, plate, Vector3(44.0, 16.0, 0.0), Vector3(0.0, 0.0, 90.0), cart, 10)
		# its PARCEL: cardboard, a band of tape in its bay's color, its bay's NUMBER on a white label
		var bay: int = 2 - k
		var pc: Color = COLS[bay]
		box(Vector3(46.0, 32.0, 32.0), mat(Color.WHITE, 0.85, 0.0, _card_tex), Vector3(0.0, 39.0, 0.0), Vector3.ZERO, cart)
		box(Vector3(46.6, 7.0, 32.6), mat(pc, 0.5), Vector3(0.0, 39.0, 0.0), Vector3.ZERO, cart)
		box(Vector3(9.0, 32.6, 32.6), mat(Color(0.82, 0.70, 0.48), 0.4), Vector3(-12.0, 39.0, 0.0), Vector3.ZERO, cart)
		box(Vector3(16.0, 14.0, 0.6), mat(Color(0.97, 0.96, 0.92), 0.7), Vector3(10.0, 45.0, 16.4), Vector3.ZERO, cart)
		var lb: Label3D = label(str(bay + 1), 12.0, Color(0.10, 0.10, 0.12), Vector3(10.0, 45.0, 16.9), Vector3.ZERO, cart)
		lb.outline_size = 0
		_wheel(cart, 22.0, 20.0)
		_wheel(cart, 22.0, -20.0)
		_wheel(cart, -22.0, 20.0)
		_wheel(cart, -22.0, -20.0)
		_carts.append(cart)

# --- the motion ---------------------------------------------------------------------------------------------------

# a cart's way: along the road (heading +x), and from TURN_IN before its bay, a curve across the apron into it
const TURN_IN: float = 90.0

func _cart_pose(along: float, bay: int) -> Array:
	var bx: float = BAYS[bay]
	var start: float = bx - TURN_IN
	if along <= start:
		return [Vector3(along, 0.0, ROAD_Z - 26.0), 0.0]
	# the curve: from the road into the bay, its length about TURN_IN + the apron's depth; then on in, slowing
	var p0: Vector3 = Vector3(start, 0.0, ROAD_Z - 26.0)
	var p1: Vector3 = Vector3(bx, 0.0, ROAD_Z - 26.0)
	var p2: Vector3 = Vector3(bx, 0.0, DOCK_Z + 30.0)
	var curve_len: float = TURN_IN + (ROAD_Z - 26.0 - DOCK_Z - 30.0)
	var d: float = along - start
	if d < curve_len:
		var s: float = d / curve_len
		var p: Vector3 = p0.lerp(p1, s).lerp(p1.lerp(p2, s), s)
		var tan3: Vector3 = (p1 - p0).lerp(p2 - p1, s)
		return [p, atan2(-tan3.z, tan3.x)]
	# in through the door and on to the back of the bay, slowing to a stop
	var rest: float = minf(d - curve_len, 160.0)
	var e: float = 1.0 - pow(1.0 - rest / 160.0, 2.0)
	return [Vector3(bx, 0.0, DOCK_Z + 30.0 - e * 130.0), PI * 0.5]

func _animate(_delta: float) -> void:
	if _engine == null:
		return
	# THE CYCLE ENDS AS THE ENGINE LEAVES THE PICTURE and the next truck comes in at once (the user: no pause): its
	# length taken from the camera -- the x where the engine's tail is past the right edge -- and never shorter than
	# the last door's closing behind its cart
	if _cyc <= 0.0:
		var full: Vector2 = Vector2(MainGlobals.full_screen_size)
		var ex: float = 0.0
		while ex < 3000.0 and screen_of(Vector3(ex - 45.0, 30.0, ROAD_Z - 26.0)).x < full.x + 20.0:
			ex += 10.0
		# and where it comes in: its nose just off the left edge, so it is in view at once
		_enter_x = 0.0
		while _enter_x > -3000.0 and screen_of(Vector3(_enter_x + 45.0, 30.0, ROAD_Z - 26.0)).x > -10.0:
			_enter_x -= 10.0
		# the last cart's door (bay 1, the last cart's) is down again once the head is 350 on
		_cyc = (maxf(ex, 360.0) - _enter_x) / SPEED
	var u: float = fmod(t, _cyc)
	var head: float = _enter_x + SPEED * u        # the engine at the edge from the first frame, and again at once
	_engine.position = Vector3(head, 0.0, ROAD_Z - 26.0)
	_engine.rotation = Vector3.ZERO
	var opened: Array = [0.0, 0.0, 0.0]
	var done: Array = [0.0, 0.0, 0.0]
	for k in _carts.size():
		var bay: int = 2 - k
		var along: float = head - GAP * float(k + 1)
		var pose: Array = _cart_pose(along, bay)
		var cart: Node3D = _carts[k]
		cart.position = pose[0]
		cart.rotation = Vector3(0.0, float(pose[1]), 0.0)
		# the door: up as the cart turns in, down again once it is inside
		var bx: float = BAYS[bay]
		var into: float = along - (bx - TURN_IN)
		opened[bay] = smoothstep(-160.0, -20.0, into) * (1.0 - smoothstep(300.0, 370.0, into))
		done[bay] = smoothstep(260.0, 320.0, into)
	for b in _doors.size():
		var door: Node3D = _doors[b]
		var f: float = maxf(0.03, 1.0 - 0.97 * float(opened[b]))
		var curtain: MeshInstance3D = door.get_meta("curtain")
		curtain.scale.y = f
		curtain.position.y = -DOOR_H * f * 0.5
		var dm: StandardMaterial3D = curtain.get_meta("m")
		dm.uv1_scale = Vector3(1.0, f, 1.0)
		dm.uv1_offset = Vector3(0.0, 1.0 - f, 0.0)
		(door.get_meta("foot") as Node3D).position.y = -DOOR_H * f
		# lit when its parcel is in; last round's signs fade out as the new truck comes in (never all off at once)
		var before: float = (1.0 - smoothstep(0.0, 1.2, u)) if t >= _cyc else 0.0
		var lit: float = maxf(float(done[b]), before)
		(_plates[b] as StandardMaterial3D).albedo_color = _unlit_col(b).lerp((COLS[b] as Color).lightened(0.08), lit)
		(_nums[b] as StandardMaterial3D).albedo_color = Color(0.97, 0.96, 0.92).lerp(Color(0.08, 0.06, 0.05), lit)

# the sign's inset before its parcel is in: the bay's color, muted
func _unlit_col(b: int) -> Color:
	return (COLS[b] as Color).lerp(Color(0.40, 0.40, 0.42), 0.65).darkened(0.35)

# A ROLL-UP DOOR'S STEEL: sixteen ribs down it (rounded, a dark groove between), the paint a weathered tone of the
# bay's color, scuffed, grimy and rust-spotted toward the foot, the ribs' relief painted in
func _door_tex(col: Color) -> ImageTexture:
	var w: int = 32                       # (small: they are made live, on the menu's first frame)
	var h: int = 128
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
	var paint: Color = col.lerp(Color(0.78, 0.78, 0.76), 0.40)
	for y in h:
		var v: float = float(y) / float(h - 1)
		var r: float = fposmod(float(y), 8.0) / 8.0
		var rib: float = sin(r * PI)
		for x in w:
			var c: Color = paint.darkened(0.22 * (1.0 - rib) + 0.04 * h01(x * 7 + y * 13)).lightened(0.10 * smoothstep(0.3, 0.5, r) * (1.0 - smoothstep(0.5, 0.7, r)))
			if r < 0.12:
				c = c.darkened(0.45)
			# grime rising from the foot, rust spots low down, a few scuffs
			c = c.lerp(Color(0.24, 0.22, 0.20), 0.45 * smoothstep(0.70, 1.0, v) * (0.7 + 0.3 * h01(x * 3 + y)))
			if v > 0.80 and h01(x / 2 * 31 + y / 2 * 17) > 0.97:
				c = Color(0.45, 0.24, 0.12)
			if h01(y * 29 + 7) > 0.985 and h01(x / 6 + y * 3) > 0.4:
				c = c.lightened(0.18)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Dispatch", "Remember the delivery order", Color(1.0, 0.88, 0.60), Color(0.10, 0.08, 0.06),
		Color(1.0, 0.8, 0.5, 0.22))

extends "res://scripts/menu_poster3d.gd"

# MOSAIC'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A WALL MOSAIC by
# candlelight. The hall around it is REAL 3-D now (the flat drawing was "low quality and flat", the user): a wall of
# dressed stone blocks with real relief; a deep ARCHED NICHE -- side walls, a vault, a ring of wedge stones round its
# arch, a molded sill; FLUTED COLUMNS either side with bases and carved capitals; heavy BANNERS hanging in folds from
# brass rods, embroidered, with gold fringes; turned stone URNS on the flagstone floor with 3-D ivy trailing over them;
# CANDLES of dripping wax in iron sconces on the columns, really lighting the stone. In the niche, drawn over the 3-D
# exactly where the camera sees its panel (the camera faces it square), one of the game's own pictures (picture.gd)
# laid in hundreds of small TESSERAE -- each a shade off its neighbor, dark grout between -- inside a border of gold,
# lapis and terracotta; a slow glint crosses it, a ripple of light runs through it, and a few tesserae at a time
# drift out, turn in the air and settle back. The hall is baked, one picture per platform (`menu_hall.webp`,
# `menu_hall_d.webp`); the mosaic, the flames and the loose tiles are live. Made up, never the board.

const GRID: int = 26                 # tesserae across (and the rows follow the panel's shape)
const LOOSE: int = 14
const DRIFT: float = 2.6
const GOLD: Color = Color(0.86, 0.66, 0.26)
const LAPIS: Color = Color(0.16, 0.24, 0.52)
const TERRA: Color = Color(0.66, 0.30, 0.20)
const PANEL_C: Vector3 = Vector3(0.0, 270.0, -60.0)     # the mosaic's panel, at the back of the niche
const PANEL_HALF: Vector2 = Vector2(150.0, 165.0)
const NICHE_HALF: float = 190.0
const ARCH_Y: float = 445.0                              # the arch's springing
const CANDLE_X: float = 262.0
const CANDLE_Z: float = 64.0
const CANDLE_TOP: float = 352.0

var _img: Image = null
var _img_task: int = -1
var _made: Image = null
var _live_a: float = 0.0
var _pic: Control = null
var _live: Control = null
var _rows: int = 26
var _tiles: Array = []
var _border: Array = []
var _laid_for: float = -2.0

func _make_picture() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 404
	var img: Image = MosaicPicture.make("scenery", 4, 4, false, rng)
	if img != null and img.is_compressed():
		img.decompress()
	_made = img

func _baked_path() -> String:
	return "res://mosaic/art/menu_hall.webp" if mobile else "res://mosaic/art/menu_hall_d.webp"

func _eye() -> Vector3:
	return Vector3(0.0, 290.0, 1200.0) if mobile else Vector3(0.0, 320.0, 1700.0)

func _aim() -> Vector3:
	return Vector3(0.0, 290.0, 0.0)

func _fov() -> float:
	return 48.0

func _frame_frac() -> float:
	return 0.54

func _environment(env: Environment) -> void:
	env.background_color = Color(0.04, 0.03, 0.03)
	env.ambient_light_color = Color(0.50, 0.44, 0.40)
	env.ambient_light_energy = 0.22

func _setup() -> void:
	super._setup()
	if bake_mode:
		return
	# THE PICTURE is always the same one (seed 404): made once and shipped small (`art/menu_mosaic.png`, 128 x 128), so
	# the mosaic is there from the first frame (made on a thread each time, it was slow to appear -- the user)
	var tex: Texture2D = load("res://mosaic/art/menu_mosaic.png")
	if tex != null:
		_img = tex.get_image()
		if _img.is_compressed():
			_img.decompress()
		_laid_for = -2.0
	else:
		_img_task = WorkerThreadPool.add_task(_make_picture)
	_pic = Control.new()
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic.draw.connect(func() -> void: _draw_pic(_pic))
	add_child(_pic)
	_live = Control.new()
	_live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_live.draw.connect(func() -> void: _draw_live(_live))
	add_child(_live)
	if _top != null:
		move_child(_top, get_child_count() - 1)

func _build_lights() -> void:
	# the two candles, warm and close, lighting the stone round them; a faint cool light from high in the hall
	for side in [-1.0, 1.0]:
		light(Vector3(side * CANDLE_X, CANDLE_TOP + 10.0, CANDLE_Z + 10.0), Color(1.0, 0.70, 0.40), 3.2, 520.0, true)
	var high: DirectionalLight3D = DirectionalLight3D.new()
	high.light_color = Color(0.55, 0.60, 0.80)
	high.light_energy = 0.25
	root.add_child(high)
	high.rotation_degrees = Vector3(-50.0, -20.0, 0.0)

# the mosaic's rectangle on the screen: the panel's corners as the camera sees them
func _pic_rect() -> Rect2:
	var a: Vector2 = screen_of(PANEL_C + Vector3(-PANEL_HALF.x, PANEL_HALF.y, 0.0))
	var b: Vector2 = screen_of(PANEL_C + Vector3(PANEL_HALF.x, -PANEL_HALF.y, 0.0))
	return Rect2(a, b - a)

# --- textures ---------------------------------------------------------------------------------------------------

func _ashlar(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	img.fill(Color(0.16, 0.13, 0.11))
	var rows: int = 6
	var rh: int = n / rows
	for r in rows:
		var bw: int = n / 3
		var off: int = (bw / 2) if r % 2 == 1 else 0
		for c in 4:
			var x0: int = c * bw - off
			var base: Color = Color(0.44, 0.38, 0.32).lerp(Color(0.52, 0.46, 0.38), h01(r * 13 + c))
			for y in rh - 3:
				for x in bw - 3:
					var px: int = x0 + 2 + x
					if px < 0 or px >= n:
						continue
					var edge: float = minf(minf(float(x), float(bw - 4 - x)), minf(float(y), float(rh - 4 - y)))
					var c2: Color = base.darkened(0.12 * h01(px * 7 + (r * rh + y) * 13)).lightened(0.10 * clampf(1.0 - edge / 3.0, 0.0, 1.0) * (1.0 if y < 3 or x < 3 else -1.0))
					img.set_pixel(px, r * rh + 2 + y, c2)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _flutes(n: int) -> ImageTexture:
	var img: Image = Image.create(n, 4, false, Image.FORMAT_RGB8)
	for x in n:
		var v: float = 0.5 + 0.5 * cos(float(x) / float(n) * TAU * 12.0)
		img.fill_rect(Rect2i(x, 0, 1, 4), Color(0.40, 0.35, 0.30).lerp(Color(0.62, 0.56, 0.48), v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _banner_tex(n: int, base: Color) -> ImageTexture:
	var img: Image = Image.create(n, n * 2, false, Image.FORMAT_RGB8)
	for y in n * 2:
		for x in n:
			var c: Color = base.darkened(0.06 * h01(x * 3 + y * 7))
			# a gold border, and a column of embroidered gold lozenges
			if x < 5 or x > n - 6:
				c = Color(0.82, 0.62, 0.24)
			var cy: int = y % (n / 2)
			var dx: int = absi(x - n / 2)
			var dy: int = absi(cy - n / 4)
			if dx + dy < n / 7 and dx + dy > n / 7 - 4:
				c = Color(0.90, 0.72, 0.30)
			if dx + dy < n / 14:
				c = Color(0.85, 0.66, 0.26)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _flags(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	img.fill(Color(0.12, 0.10, 0.09))
	var cs: int = n / 4
	for r in 4:
		for c in 4:
			var col: Color = Color(0.34, 0.31, 0.28).lerp(Color(0.42, 0.38, 0.33), h01(r * 5 + c))
			img.fill_rect(Rect2i(c * cs + 2, r * cs + 2, cs - 4, cs - 4), col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# --- the hall: baked ----------------------------------------------------------------------------------------------

# a block of the wall, with a slight relief (each block its own small box, proud of the mortar)
func _wall_span(x0: float, x1: float, y0: float, y1: float, ashlar: StandardMaterial3D) -> void:
	if x1 - x0 < 1.0 or y1 - y0 < 1.0:
		return
	box(Vector3(x1 - x0, y1 - y0, 30.0), ashlar, Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, -15.0))

func _build_still() -> void:
	var ashlar: StandardMaterial3D = mat(Color.WHITE, 0.85, 0.0, _ashlar(256), Vector3(5.0, 5.0, 1))
	var dressed: StandardMaterial3D = mat(Color(0.56, 0.50, 0.42), 0.75)
	var iron: StandardMaterial3D = mat(Color(0.12, 0.11, 0.11), 0.45, 0.6)
	var brass: StandardMaterial3D = mat(Color(0.86, 0.66, 0.30), 0.3, 0.8)
	# THE FLOOR of flagstones, the WALL round the niche: full beside it, below it, above the arch, and the
	# spandrels between the arch and its square
	box(Vector3(2600.0, 4.0, 1400.0), mat(Color.WHITE, 0.7, 0.0, _flags(128), Vector3(16, 9, 1)), Vector3(0.0, -2.0, 300.0))
	var r_arch: float = NICHE_HALF
	_wall_span(-1300.0, -NICHE_HALF - 30.0, 0.0, 1300.0, ashlar)
	_wall_span(NICHE_HALF + 30.0, 1300.0, 0.0, 1300.0, ashlar)
	_wall_span(-NICHE_HALF - 30.0, NICHE_HALF + 30.0, 0.0, 70.0, ashlar)
	_wall_span(-NICHE_HALF - 30.0, NICHE_HALF + 30.0, ARCH_Y + r_arch + 30.0, 1300.0, ashlar)
	for row in 24:
		var y0: float = ARCH_Y + (r_arch + 30.0) * float(row) / 24.0
		var y1: float = ARCH_Y + (r_arch + 30.0) * float(row + 1) / 24.0
		var ym: float = (y0 + y1) * 0.5 - ARCH_Y
		var half: float = sqrt(maxf(0.0, (r_arch + 30.0) * (r_arch + 30.0) - ym * ym))
		_wall_span(-NICHE_HALF - 30.0, -half, y0, y1, ashlar)
		_wall_span(half, NICHE_HALF + 30.0, y0, y1, ashlar)
	# THE NICHE: its back (dark grout behind the tesserae), its side walls, its vault, the ring of wedge stones round
	# its arch, the molded sill
	box(Vector3(NICHE_HALF * 2.0, ARCH_Y + r_arch, 4.0), mat(Color(0.20, 0.17, 0.15), 0.9), Vector3(0.0, (ARCH_Y + r_arch) * 0.5, PANEL_C.z - 4.0))
	for sx in [-1.0, 1.0]:
		box(Vector3(4.0, ARCH_Y - 70.0, 64.0), ashlar, Vector3(sx * NICHE_HALF, 70.0 + (ARCH_Y - 70.0) * 0.5, -32.0))
	for v in 16:
		var a0: float = PI * float(v) / 16.0
		var a1: float = PI * float(v + 1) / 16.0
		var am: float = (a0 + a1) * 0.5
		box(Vector3(4.0, r_arch * (a1 - a0) + 1.0, 64.0), ashlar, Vector3(cos(am) * r_arch, ARCH_Y + sin(am) * r_arch, -32.0), Vector3(0.0, 0.0, rad_to_deg(am)))
	for w in 15:
		var wa: float = PI * (float(w) + 0.5) / 15.0
		box(Vector3(30.0, r_arch * PI / 15.0 - 3.0, 36.0), dressed, Vector3(cos(wa) * (r_arch + 15.0), ARCH_Y + sin(wa) * (r_arch + 15.0), 2.0), Vector3(0.0, 0.0, rad_to_deg(wa)))
	box(Vector3(34.0, 44.0, 38.0), dressed, Vector3(0.0, ARCH_Y + r_arch + 18.0, 4.0))
	for jx in [-1.0, 1.0]:
		box(Vector3(30.0, ARCH_Y - 70.0, 36.0), dressed, Vector3(jx * (NICHE_HALF + 15.0), 70.0 + (ARCH_Y - 70.0) * 0.5, 2.0))
	box(Vector3(NICHE_HALF * 2.0 + 80.0, 14.0, 60.0), dressed, Vector3(0.0, 63.0, 0.0))
	box(Vector3(NICHE_HALF * 2.0 + 90.0, 6.0, 66.0), dressed, Vector3(0.0, 72.0, 0.0))
	# THE COLUMNS: a square plinth, a torus at the foot, a fluted shaft tapering a little, a carved capital
	var flute: StandardMaterial3D = mat(Color.WHITE, 0.7, 0.0, _flutes(128))
	for sx2 in [-1.0, 1.0]:
		var cx: float = sx2 * 300.0
		box(Vector3(70.0, 30.0, 70.0), dressed, Vector3(cx, 15.0, 50.0))
		var tor: TorusMesh = TorusMesh.new()
		tor.inner_radius = 18.0
		tor.outer_radius = 32.0
		put(tor, dressed, Vector3(cx, 36.0, 50.0))
		cyl(22.0, 26.0, 560.0, flute, Vector3(cx, 320.0, 50.0), Vector3.ZERO, null, 32)
		var neck: TorusMesh = TorusMesh.new()
		neck.inner_radius = 16.0
		neck.outer_radius = 26.0
		put(neck, dressed, Vector3(cx, 600.0, 50.0))
		cyl(38.0, 24.0, 34.0, dressed, Vector3(cx, 618.0, 50.0), Vector3.ZERO, null, 32)
		for vl in [-1.0, 1.0]:
			cyl(9.0, 9.0, 60.0, dressed, Vector3(cx + vl * 36.0, 622.0, 50.0), Vector3(90.0, 0.0, 0.0), null, 16)
		box(Vector3(86.0, 14.0, 86.0), dressed, Vector3(cx, 642.0, 50.0))
		# THE SCONCE on the column: an iron arm, a drip pan, the candle (wax with drips down it)
		var sc: Vector3 = Vector3(sx2 * CANDLE_X, CANDLE_TOP - 70.0, CANDLE_Z)
		put(tube_mesh(PackedVector3Array([Vector3(cx, sc.y - 30.0, 74.0), Vector3(cx - sx2 * 18.0, sc.y - 14.0, CANDLE_Z + 4.0), sc + Vector3(0.0, -8.0, 0.0)]), 2.6, 8), iron, Vector3.ZERO)
		cyl(14.0, 9.0, 5.0, iron, sc + Vector3(0.0, -4.0, 0.0), Vector3.ZERO, null, 20)
		var wax: StandardMaterial3D = mat(Color(0.95, 0.90, 0.78), 0.45)
		cyl(7.5, 8.0, 66.0, wax, sc + Vector3(0.0, 33.0, 0.0), Vector3.ZERO, null, 20)
		for dr in 5:
			var da: float = TAU * h01(dr + int(sx2 * 5.0) + 30)
			var drip: MeshInstance3D = sphere(2.4, wax, sc + Vector3(cos(da) * 7.6, 66.0 - 8.0 - 18.0 * h01(dr + 40), sin(da) * 7.6))
			drip.scale = Vector3(1.0, 2.4, 1.0)
		cyl(1.0, 1.0, 6.0, mat(Color(0.10, 0.08, 0.06), 0.8), sc + Vector3(0.0, 69.0, 0.0))
	# THE BANNERS: cloth hanging in soft folds from a brass rod with finials, a V at the foot with a gold fringe
	for sx3 in [-1.0, 1.0]:
		var bx: float = sx3 * 420.0
		var col: Color = Color(0.52, 0.10, 0.10) if sx3 < 0.0 else Color(0.14, 0.20, 0.46)
		var bm: StandardMaterial3D = mat(Color.WHITE, 0.8, 0.0, _banner_tex(64, col))
		_banner(Vector3(bx, 690.0, 18.0), 120.0, 340.0, bm)
		cyl(3.0, 3.0, 150.0, brass, Vector3(bx, 696.0, 18.0), Vector3(0.0, 0.0, 90.0))
		for fn in [-1.0, 1.0]:
			sphere(6.0, brass, Vector3(bx + fn * 78.0, 696.0, 18.0))
		for cord in [-1.0, 1.0]:
			cyl(0.8, 0.8, 60.0, brass, Vector3(bx + cord * 40.0, 726.0, 18.0), Vector3(0.0, 0.0, cord * -34.0))
	# THE URNS on the floor before the banners: turned stone, and ivy trailing over their lips
	for sx4 in [-1.0, 1.0]:
		var uc: Vector3 = Vector3(sx4 * 400.0, 0.0, 160.0)
		var prof: Array = [[0.0, 22.0], [10.0, 26.0], [14.0, 18.0], [30.0, 22.0], [62.0, 42.0], [92.0, 40.0], [110.0, 30.0], [118.0, 34.0], [126.0, 38.0]]
		for pi in prof.size() - 1:
			var a2: Array = prof[pi]
			var b2: Array = prof[pi + 1]
			cyl(float(b2[1]), float(a2[1]), float(b2[0]) - float(a2[0]), dressed, uc + Vector3(0.0, (float(a2[0]) + float(b2[0])) * 0.5, 0.0), Vector3.ZERO, null, 32)
		cyl(34.0, 34.0, 2.0, mat(Color(0.14, 0.10, 0.07), 0.9), uc + Vector3(0.0, 125.0, 0.0), Vector3.ZERO, null, 32)
		_ivy(uc + Vector3(0.0, 124.0, 0.0), sx4)

func _banner(top_c: Vector3, w: float, h: float, m: StandardMaterial3D) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx: int = 16
	var ny: int = 12
	var grid: Array = []
	for j in ny + 1:
		var v: float = float(j) / float(ny)
		var row: Array = []
		for i in nx + 1:
			var u: float = float(i) / float(nx)
			var x: float = (u - 0.5) * w
			var point_drop: float = (1.0 - absf(u - 0.5) * 2.0) * w * 0.35 if v > 0.999 else 0.0
			var y: float = -v * h - (1.0 - absf(u - 0.5) * 2.0) * w * 0.35 * v * v * (1.0 if j == ny else 0.6)
			var z: float = sin(u * TAU * 3.0) * 6.0 * (0.4 + 0.6 * v)
			row.append([Vector3(x, y - point_drop * 0.0, z), Vector2(u, v)])
		grid.append(row)
	for j2 in ny:
		for i2 in nx:
			var q: Array = [grid[j2][i2], grid[j2 + 1][i2], grid[j2 + 1][i2 + 1], grid[j2][i2], grid[j2 + 1][i2 + 1], grid[j2][i2 + 1]]
			for vv in q:
				st.set_uv(vv[1])
				st.add_vertex(top_c + (vv[0] as Vector3))
	st.generate_normals()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	root.add_child(mi)
	# the gold fringe along the V at the foot
	var gold: StandardMaterial3D = mat(Color(0.88, 0.68, 0.28), 0.35, 0.7)
	for f in 17:
		var u2: float = float(f) / 16.0
		var last: Vector3 = (grid[ny][int(round(u2 * float(nx)))][0] as Vector3)
		cyl(1.0, 0.6, 14.0, gold, top_c + last + Vector3(0.0, -7.0, 0.0), Vector3.ZERO, null, 6)

# ivy over an urn's lip: vines curving down its sides, pointed leaves along them, each turned its own way
func _ivy(lip: Vector3, side: float) -> void:
	var vine: StandardMaterial3D = mat(Color(0.20, 0.24, 0.12), 0.8)
	var leaf_a: StandardMaterial3D = mat(Color(0.20, 0.42, 0.16), 0.6)
	var leaf_b: StandardMaterial3D = mat(Color(0.14, 0.32, 0.12), 0.6)
	for k in 7:
		var a: float = TAU * float(k) / 7.0 + 0.4
		var start: Vector3 = lip + Vector3(cos(a) * 32.0, 2.0, sin(a) * 32.0)
		var pts: PackedVector3Array = PackedVector3Array([start])
		var length: float = 50.0 + 60.0 * h01(k + int(side * 7.0) + 20)
		for s in 5:
			var f: float = float(s + 1) / 5.0
			pts.append(start + Vector3(cos(a) * 18.0 * f, -length * f, sin(a) * 18.0 * f) + Vector3(sin(f * 4.0 + float(k)) * 6.0, 0.0, 0.0))
		put(tube_mesh(pts, 1.1, 6), vine, Vector3.ZERO)
		for lf in 6:
			var p: Vector3 = pts[1 + lf % 5]
			var leaf: MeshInstance3D = sphere(5.5, leaf_a if (lf + k) % 2 == 0 else leaf_b, p + Vector3(cos(a + float(lf)) * 4.0, -float(lf) * 3.0, sin(a + float(lf)) * 4.0))
			leaf.scale = Vector3(1.0, 0.25, 1.6)
			leaf.rotation = Vector3(h01(k * 9 + lf) * 1.6 - 0.8, a + h01(k * 5 + lf) * 2.0, h01(k * 3 + lf) * 1.2 - 0.6)

# --- the mosaic, the flames, the light, the loose tiles (2-D, over the 3-D) ------------------------------------------

func _tick(delta: float) -> void:
	super._tick(delta)
	if bake_mode or _pic == null:
		return
	if _img == null and _img_task >= 0 and WorkerThreadPool.is_task_completed(_img_task):
		WorkerThreadPool.wait_for_task_completion(_img_task)
		_img_task = -1
		_img = _made
		_laid_for = -2.0
	if _img == null:
		return
	_live_a = 1.0 if _img_task < 0 else fade_in(true, _live_a, delta)
	_pic.modulate = Color(1, 1, 1, _live_a)
	_live.modulate = Color(1, 1, 1, _live_a)
	if absf(scene_bottom - _laid_for) > 0.5:
		_laid_for = scene_bottom
		_lay()
		_pic.queue_redraw()
	_live.queue_redraw()

func _draw_pic(d: Control) -> void:
	if _tiles.is_empty():
		return
	var pr: Rect2 = _pic_rect()
	d.draw_rect(pr.grow(pr.size.x / float(GRID) * 2.4), Color(0.20, 0.17, 0.15))
	for b in _border:
		_tessera(d, b[0], b[1], 0.0)
	d.draw_rect(pr, Color(0.22, 0.19, 0.17))
	for tile in _tiles:
		_tessera(d, tile[0], tile[1], tile[2])

func _lay() -> void:
	# the tesserae fill the niche's panel as the camera sees it
	_tiles.clear()
	_border.clear()
	if _img == null:
		return
	var pr: Rect2 = _pic_rect()
	var cell: float = pr.size.x / float(GRID)
	_rows = maxi(1, int(round(pr.size.y / cell)))
	var iw: int = _img.get_width()
	var ih: int = _img.get_height()
	for r in _rows:
		for c in GRID:
			var i: int = r * GRID + c
			var px: int = clampi(int((float(c) + 0.5) / float(GRID) * float(iw)), 0, iw - 1)
			var py: int = clampi(int((float(r) + 0.5) / float(_rows) * float(ih)), 0, ih - 1)
			var col: Color = _img.get_pixel(px, py)
			# each tessera a shade off: glass catches the light differently
			var v: float = (h01(i * 3 + 1) - 0.5) * 0.16
			col = Color(clampf(col.r + v, 0.0, 1.0), clampf(col.g + v, 0.0, 1.0), clampf(col.b + v * 1.2, 0.0, 1.0))
			var jitter: Vector2 = Vector2(h01(i * 3 + 2) - 0.5, h01(i * 3 + 3) - 0.5) * cell * 0.12
			var sz: float = cell * (0.80 + 0.08 * h01(i * 5))
			var rect: Rect2 = Rect2(pr.position + Vector2((float(c) + 0.5) * cell, (float(r) + 0.5) * cell) + jitter - Vector2(sz, sz) * 0.5, Vector2(sz, sz))
			_tiles.append([rect, col, (h01(i * 7) - 0.5) * 0.14])
	# the border: two rows of tiles round the picture, a gold band and a pattern of lapis and terracotta
	var b: float = cell * 1.05
	for ring in 2:
		var outer: Rect2 = pr.grow(b * float(ring + 1))
		var n_x: int = int(outer.size.x / b)
		var n_y: int = int(outer.size.y / b)
		for k in n_x:
			for edge_y in [outer.position.y, outer.end.y - b]:
				_border.append([Rect2(outer.position.x + float(k) * outer.size.x / float(n_x), edge_y, b * 0.86, b * 0.86), _border_col(ring, k), ring == 0])
		for k in range(1, n_y - 1):
			for edge_x in [outer.position.x, outer.end.x - b]:
				_border.append([Rect2(edge_x, outer.position.y + float(k) * outer.size.y / float(n_y), b * 0.86, b * 0.86), _border_col(ring, k), ring == 0])

func _border_col(ring: int, k: int) -> Color:
	if ring == 0:
		return GOLD.lightened(0.10 * h01(k + 77))
	return [LAPIS, TERRA, LAPIS, GOLD][k % 4]

func _tessera(d: CanvasItem, r: Rect2, col: Color, rot: float) -> void:
	var c: Vector2 = r.get_center()
	var h: Vector2 = r.size * 0.5
	var pts: PackedVector2Array = PackedVector2Array([c + Vector2(-h.x, -h.y).rotated(rot), c + Vector2(h.x, -h.y).rotated(rot),
		c + Vector2(h.x, h.y).rotated(rot), c + Vector2(-h.x, h.y).rotated(rot)])
	d.draw_colored_polygon(pts, col)
	# a lit top-left edge and a shaded bottom-right: glass set slightly proud of the grout
	d.draw_line(pts[0], pts[1], Color(1, 1, 1, 0.22), 1.0)
	d.draw_line(pts[0], pts[3], Color(1, 1, 1, 0.14), 1.0)
	d.draw_line(pts[1], pts[2], Color(0, 0, 0, 0.25), 1.0)

func _draw_live(d: Control) -> void:
	var pr: Rect2 = _pic_rect()
	if _tiles.is_empty():
		return
	# THE FLAMES, alive (the user: they did not move and flicker like a real flame): each a few nested tongues
	# whose height, width and tip sway with a mix of quick and slow wavering, the glow on the wall breathing
	# with them a little
	for side in [-1.0, 1.0]:
		var tip3: Vector3 = Vector3(side * CANDLE_X, CANDLE_TOP, CANDLE_Z)
		var sc: Vector2 = screen_of(tip3) + Vector2(0.0, 6.0)
		var fs: float = screen_of(tip3 + Vector3(0.0, 10.0, 0.0)).distance_to(screen_of(tip3)) / 10.0
		var tt: float = t + side * 3.7
		var flick: float = 0.5 * sin(tt * 11.0) + 0.3 * sin(tt * 17.3 + 1.0) + 0.2 * sin(tt * 4.1)
		var glow_k: float = 0.88 + 0.12 * flick
		for k in 8:
			d.draw_circle(sc + Vector2(0, -20.0 * fs), 62.0 * fs * (1.0 - float(k) / 8.0), Color(1.0, 0.72, 0.38, 0.032 * glow_k))
		var sway: float = (3.6 * sin(tt * 3.1) + 1.9 * sin(tt * 9.7)) * fs
		var hgt: float = (26.0 + 5.0 * flick + 2.0 * sin(tt * 23.0)) * fs * 1.25
		for layer_i in 3:
			var k2: float = 1.0 - 0.28 * float(layer_i)
			var col: Color = [Color(1.0, 0.50, 0.12, 0.85), Color(1.0, 0.80, 0.30), Color(1.0, 0.97, 0.86)][layer_i]
			var w: float = 6.0 * k2 * fs * 1.2
			var base: Vector2 = sc + Vector2(0, -6)
			var tip: Vector2 = base + Vector2(sway * k2, -hgt * k2)
			var pts2: PackedVector2Array = PackedVector2Array()
			for s2 in 9:
				var a: float = PI * float(s2) / 8.0
				pts2.append(base + Vector2(-cos(a) * w, sin(a) * w * 0.6))
			for s3 in 7:
				var f: float = float(s3) / 6.0
				var bend: float = sin(f * PI) * sway * 0.5 * k2
				pts2.append(base.lerp(tip, f) + Vector2(w * (1.0 - f) * (1.0 - f) + bend, 0.0))
			for s4 in 7:
				var f2: float = 1.0 - float(s4) / 6.0
				var bend2: float = sin(f2 * PI) * sway * 0.5 * k2
				pts2.append(base.lerp(tip, f2) + Vector2(-w * (1.0 - f2) * (1.0 - f2) + bend2, 0.0))
			var hull: PackedVector2Array = Geometry2D.convex_hull(pts2)
			if hull.size() >= 4:
				hull.remove_at(hull.size() - 1)
				d.draw_colored_polygon(hull, col)
	# A RIPPLE OF LIGHT through the mosaic every few seconds: a ring spreading from a point, the tesserae
	# under it catching the light one after another
	var rip_n: int = int(t / 3.5)
	var rip_u: float = fmod(t, 3.5) / 3.5
	var rip_c: Vector2 = pr.position + Vector2(h01(rip_n * 3) * pr.size.x, h01(rip_n * 3 + 1) * pr.size.y)
	var rip_r: float = rip_u * pr.size.x * 1.2
	var cell: float = pr.size.x / float(GRID)
	for tile2 in _tiles:
		var tr2: Rect2 = tile2[0]
		var dd: float = absf(tr2.get_center().distance_to(rip_c) - rip_r)
		if dd < cell * 1.6:
			var a2: float = (1.0 - dd / (cell * 1.6)) * (1.0 - rip_u) * 0.55
			d.draw_rect(tr2, Color(1.0, 0.95, 0.80, a2))
	# THE SWEEP OF LIGHT across the mosaic, slow, and the gold tiles glinting in it
	var sweep: float = fmod(t * 0.10, 1.4) - 0.2
	var sx: float = pr.position.x + pr.size.x * sweep
	# lighting only the tiles it crosses (a polygon sliding in and out ran off the picture as a big triangle)
	for tile3 in _tiles:
		var tr3: Rect2 = tile3[0]
		var tc: Vector2 = tr3.get_center()
		var line_x: float = sx - 40.0 * (tc.y - pr.position.y) / maxf(1.0, pr.size.y)
		var dx: float = absf(tc.x - line_x)
		if dx < 46.0:
			d.draw_rect(tr3, Color(1.0, 0.92, 0.75, 0.16 * (1.0 - dx / 46.0)))
	for b in _border:
		if bool(b[2]):
			var bp: Vector2 = (b[0] as Rect2).get_center()
			var near: float = 1.0 - clampf(absf(bp.x - (sx - 30.0)) / 50.0, 0.0, 1.0)
			if near > 0.0:
				d.draw_circle(bp + Vector2(-2, -2), 2.5 * near, Color(1.0, 0.97, 0.85, 0.9 * near))
	# THE LOOSE TILES: a few at a time out of the wall, each drifting out, turning, settling back; its empty
	# place showing the grout meanwhile
	var n: int = _tiles.size()
	for k in LOOSE:
		var phase: float = t / DRIFT + float(k) / float(LOOSE)
		var cycle_i: int = int(floor(phase))
		var u: float = phase - float(cycle_i)
		var idx: int = int(h01(cycle_i * 31 + k * 7) * float(n)) % n
		var tile: Array = _tiles[idx]
		var r: Rect2 = tile[0]
		d.draw_rect(r.grow(1.0), Color(0.24, 0.21, 0.19))
		var lift: float = sin(u * PI)
		var out_dir: Vector2 = Vector2(h01(cycle_i * 13 + k) - 0.5, -0.6 - 0.4 * h01(cycle_i * 17 + k)).normalized()
		var pos: Vector2 = r.get_center() + out_dir * 110.0 * lift
		var rot: float = float(tile[2]) + sin(u * PI) * (h01(cycle_i + k * 5) - 0.5) * 2.4
		var scale_k: float = 1.0 + 1.3 * lift
		d.draw_set_transform(pos + Vector2(6, 10) * lift, rot, Vector2.ONE * scale_k)
		d.draw_rect(Rect2(-r.size * 0.5, r.size), Color(0, 0, 0, 0.30 * lift))
		d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_tessera_at(d, pos, r.size * scale_k, tile[1], rot, lift)

func _tessera_at(d: CanvasItem, c: Vector2, sz: Vector2, col: Color, rot: float, lift: float) -> void:
	var h: Vector2 = sz * 0.5
	var pts: PackedVector2Array = PackedVector2Array([c + Vector2(-h.x, -h.y).rotated(rot), c + Vector2(h.x, -h.y).rotated(rot),
		c + Vector2(h.x, h.y).rotated(rot), c + Vector2(-h.x, h.y).rotated(rot)])
	d.draw_colored_polygon(pts, col.lightened(0.12 * lift))
	d.draw_line(pts[0], pts[1], Color(1, 1, 1, 0.30 + 0.3 * lift), 1.5)
	d.draw_line(pts[1], pts[2], Color(0, 0, 0, 0.30), 1.5)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Mosaic", "Rebuild the picture faster every round", Color(0.98, 0.84, 0.50), Color(0.10, 0.06, 0.02),
		Color(1.0, 0.80, 0.40, 0.22))

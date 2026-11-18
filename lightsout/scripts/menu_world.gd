extends "res://scripts/menu_poster3d.gd"

# LIGHTS OUT'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A COAL MINE
# GALLERY (the game's own coal mine look). A tunnel through dark coal-seamed rock, timber sets every few paces, rails
# on sleepers running away into it, a cart of coal at the near end, lanterns hung on the posts -- and down the
# gallery a side opening with a TNT crate at its mouth (the obstacle) and, far off, a green lamp by the way out (the
# goal). Then, as in the game, THE LIGHTS GO OUT: lantern by lantern from the far end toward you, the dark closing
# in, until only a faint glow is left -- a moment -- and they come on again from the near end, flickering as they
# catch. The gallery is the baked picture (`menu_mine.webp`, lit by its lanterns); the dark is a veil over it with a
# hole round each lit lantern (`add_darkness`), and the flames are drawn live. Made up, never the board.

const SET_EVERY: float = 170.0           # timber sets along the gallery
const SETS: int = 9
const HALF_W: float = 125.0
const HEIGHT: float = 215.0
const CYCLE: float = 5.0
const TNT_Z: float = -560.0
const GOAL_Z: float = -1350.0

var _lanterns: Array = []                # Vector3 per lantern, near to far

func _baked_path() -> String:
	return "res://lightsout/art/menu_mine.webp"

func _eye() -> Vector3:
	return Vector3(-20.0, 140.0, 430.0)

func _aim() -> Vector3:
	return Vector3(10.0, 105.0, -400.0)

func _fov() -> float:
	return 62.0

func _environment(env: Environment) -> void:
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_color = Color(0.40, 0.36, 0.34)
	env.ambient_light_energy = 0.10

func _setup() -> void:
	for k in SETS:
		var z: float = 160.0 - float(k) * SET_EVERY
		var side: float = -1.0 if k % 2 == 0 else 1.0
		_lanterns.append(Vector3(side * (HALF_W - 22.0), 150.0, z + 14.0))
	super._setup()
	add_darkness()

func _build_lights() -> void:
	# each lantern lights its stretch of the gallery, warm; the goal's green lamp far off
	for p in _lanterns:
		light((p as Vector3) + Vector3(0.0, -6.0, 6.0), Color(1.0, 0.70, 0.38), 1.7, 260.0, false)
	light(Vector3(70.0, 120.0, GOAL_Z + 30.0), Color(0.45, 1.0, 0.55), 2.0, 240.0)

# --- the gallery: baked ---------------------------------------------------------------------------------------------

func _rock(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var v: float = h01(x * 13 + y * 7) * 0.5 + h01((x / 4) * 31 + (y / 4) * 17) * 0.5
			var c: Color = Color(0.11, 0.11, 0.12).lerp(Color(0.25, 0.24, 0.24), v)
			# coal seams: dark bands that wander across the rock
			var seam: float = sin(float(y) * 0.07 + sin(float(x) * 0.031) * 3.0 + h01((x / 16) * 7 + (y / 16)) * 1.5)
			if seam > 0.93 and h01((x / 8) * 13 + (y / 8) * 5) > 0.3:
				c = Color(0.05, 0.05, 0.06).lerp(Color(0.16, 0.16, 0.18), h01(x + y * 3))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# smooth value noise from the poster's hash: for the rock's relief
func _vn(x: float, y: float) -> float:
	var ix: int = int(floor(x))
	var iy: int = int(floor(y))
	var fx: float = x - float(ix)
	var fy: float = y - float(iy)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a00: float = h01(ix * 73 + iy * 151 + 7)
	var a10: float = h01((ix + 1) * 73 + iy * 151 + 7)
	var a01: float = h01(ix * 73 + (iy + 1) * 151 + 7)
	var a11: float = h01((ix + 1) * 73 + (iy + 1) * 151 + 7)
	return lerpf(lerpf(a00, a10, fx), lerpf(a01, a11, fx), fy)

# A ROCK FACE with real relief: a grid across (u: up the wall or across the roof) and along (z), each point pushed
# into the gallery by layered noise, smooth normals -- lit by the lanterns it shows its lumps and hollows (flat boxes
# did not). `side` -1 / 1 a wall, 0 the roof.
func _rock_face(z0: float, z1: float, side: float, m: StandardMaterial3D) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu: int = 9
	var nz: int = 10
	var grid: Array = []
	for i in nu + 1:
		var row: Array = []
		var u: float = float(i) / float(nu)
		for j in nz + 1:
			var z: float = lerpf(z0, z1, float(j) / float(nz))
			var key_u: float = u * (HEIGHT if side != 0.0 else 2.0 * HALF_W)
			var bump: float = 22.0 * _vn(key_u / 55.0 + side * 9.0, z / 70.0) + 8.0 * _vn(key_u / 18.0 + 3.0, z / 22.0) - 15.0
			var p: Vector3
			if side != 0.0:
				p = Vector3(side * (HALF_W + 6.0 - bump), u * (HEIGHT + 10.0) - 4.0, z)
			else:
				p = Vector3(lerpf(-HALF_W - 10.0, HALF_W + 10.0, u), HEIGHT + 6.0 - bump * 0.6, z)
			row.append([p, Vector2(u * 2.0, z / 120.0)])
		grid.append(row)
	for i2 in nu:
		for j2 in nz:
			var q: Array = [grid[i2][j2], grid[i2 + 1][j2], grid[i2 + 1][j2 + 1], grid[i2][j2], grid[i2 + 1][j2 + 1], grid[i2][j2 + 1]]
			for v in q:
				st.set_uv(v[1])
				st.add_vertex(v[0])
	st.generate_normals()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	root.add_child(mi)

# a hurricane lantern hung from its hook: base, glass globe, wire guards, a cap and a bail handle
func _lantern(lp: Vector3, steel: StandardMaterial3D) -> void:
	var into: float = signf(lp.x)
	box(Vector3(20.0, 3.0, 3.0), steel, lp + Vector3(into * 9.0, 24.0, 0.0))
	var bail: TorusMesh = TorusMesh.new()
	bail.inner_radius = 6.0
	bail.outer_radius = 7.0
	put(bail, steel, lp + Vector3(0.0, 18.0, 0.0), Vector3(90.0, 0.0, 0.0))
	cyl(3.0, 9.0, 6.0, steel, lp + Vector3(0.0, 13.0, 0.0), Vector3.ZERO, null, 16)
	var globe: MeshInstance3D = sphere(8.0, mat(Color(1.0, 0.88, 0.62, 0.45), 0.05, 0.1), lp + Vector3(0.0, 2.0, 0.0))
	globe.scale = Vector3(1.0, 1.25, 1.0)
	for g in 4:
		var ga: float = TAU * float(g) / 4.0
		cyl(0.6, 0.6, 20.0, steel, lp + Vector3(cos(ga) * 8.6, 2.0, sin(ga) * 8.6), Vector3.ZERO, null, 6)
	cyl(9.0, 10.0, 5.0, steel, lp + Vector3(0.0, -10.0, 0.0), Vector3.ZERO, null, 16)
	sphere(3.0, glow(Color(1.0, 0.86, 0.50)), lp + Vector3(0.0, 1.0, 0.0))

# a round black bomb on the ground, its fuse curling up
func _bomb(c: Vector3, steel: StandardMaterial3D) -> void:
	sphere(16.0, mat(Color(0.06, 0.06, 0.07), 0.25, 0.6), c + Vector3(0.0, 16.0, 0.0))
	cyl(5.0, 5.0, 6.0, steel, c + Vector3(0.0, 33.0, 0.0), Vector3.ZERO, null, 12)
	put(tube_mesh(PackedVector3Array([c + Vector3(0.0, 35.0, 0.0), c + Vector3(4.0, 44.0, 2.0), c + Vector3(10.0, 48.0, 0.0)]), 1.2, 6), mat(Color(0.55, 0.45, 0.30), 0.9), Vector3.ZERO)
	sphere(2.4, glow(Color(1.0, 0.70, 0.30)), c + Vector3(10.0, 48.0, 0.0))

func _build_still() -> void:
	var rock: StandardMaterial3D = mat(Color.WHITE, 0.92, 0.0, _rock(256), Vector3(2, 2, 1))
	var ballast: StandardMaterial3D = mat(Color.WHITE, 1.0, 0.0, tex_speckle(128, Color(0.20, 0.18, 0.16), 0.35, 4), Vector3(3, 18, 1))
	var timber: StandardMaterial3D = mat(Color.WHITE, 0.85, 0.0, tex_wood(128, Color(0.36, 0.24, 0.13), 6), Vector3(1, 3, 1))
	var steel: StandardMaterial3D = mat(Color(0.45, 0.42, 0.40), 0.4, 0.7)
	var iron: StandardMaterial3D = mat(Color(0.20, 0.18, 0.17), 0.5, 0.7)
	var length: float = 2400.0
	var near_end: float = 640.0          # past the camera: we stand INSIDE the gallery
	# THE GALLERY in pieces a timber set long (the renderer lights an object with at most eight lights): a gravel bed,
	# the rock walls and roof with their relief
	var pieces: int = int(ceil(length / SET_EVERY))
	for pc in pieces:
		var z0: float = near_end - float(pc) * SET_EVERY
		var z1: float = z0 - SET_EVERY - 0.5
		box(Vector3(2.0 * HALF_W + 40.0, 10.0, SET_EVERY + 0.5), ballast, Vector3(0.0, -5.0, (z0 + z1) * 0.5))
		for side in [-1.0, 1.0, 0.0]:
			_rock_face(z0, z1, side, rock)
	box(Vector3(2.0 * HALF_W + 40.0, HEIGHT + 20.0, 20.0), rock, Vector3(0.0, HEIGHT * 0.5, near_end - length))
	# puddles in the low spots between the sleepers, dark and glossy
	for pk in 6:
		var pd: MeshInstance3D = cyl(30.0 + 20.0 * h01(pk), 30.0, 0.4, mat(Color(0.04, 0.05, 0.06), 0.04, 0.4), Vector3((h01(pk + 9) - 0.5) * 160.0, 0.6, 400.0 - float(pk) * 260.0))
		pd.scale = Vector3(1.4, 1.0, 0.7)
	# THE TIMBER SETS: two posts and a cap, wedged, every SET_EVERY
	for k4 in SETS + 6:
		var z4: float = 160.0 + 3.0 * SET_EVERY - float(k4) * SET_EVERY
		for side4 in [-1.0, 1.0]:
			box(Vector3(18.0, HEIGHT - 6.0, 18.0), timber, Vector3(side4 * (HALF_W - 12.0), (HEIGHT - 6.0) * 0.5, z4), Vector3(0.0, 0.0, side4 * -3.0))
		box(Vector3(2.0 * HALF_W, 20.0, 20.0), timber, Vector3(0.0, HEIGHT - 12.0, z4))
		for w in 3:
			box(Vector3(14.0, 6.0, 26.0), timber, Vector3(-60.0 + float(w) * 60.0, HEIGHT - 1.0, z4))
	# THE RAILS on their sleepers, running away down the gallery: rails with a head and a foot, spikes
	for k5 in 72:
		box(Vector3(120.0, 6.0, 16.0), timber, Vector3(0.0, 3.0, 620.0 - float(k5) * 32.0))
	for rx in [-38.0, 38.0]:
		for pc2 in pieces:
			var rz: float = near_end - (float(pc2) + 0.5) * SET_EVERY
			box(Vector3(9.0, 2.0, SET_EVERY + 0.5), steel, Vector3(rx, 7.0, rz))
			box(Vector3(3.0, 6.0, SET_EVERY + 0.5), steel, Vector3(rx, 10.0, rz))
			box(Vector3(6.0, 3.0, SET_EVERY + 0.5), mat(Color(0.62, 0.60, 0.58), 0.25, 0.85), Vector3(rx, 14.0, rz))
	for p in _lanterns:
		_lantern(p, steel)
	# A CART of coal down the gallery: a body tapering to its foot, iron bands and rivets, spoked wheels, a heap of
	# faceted lumps
	var cart: Vector3 = Vector3(0.0, 0.0, -300.0)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tb: Array = [Vector3(-52.0, 74.0, -62.0), Vector3(52.0, 74.0, -62.0), Vector3(52.0, 74.0, 62.0), Vector3(-52.0, 74.0, 62.0)]
	var bt: Array = [Vector3(-40.0, 22.0, -50.0), Vector3(40.0, 22.0, -50.0), Vector3(40.0, 22.0, 50.0), Vector3(-40.0, 22.0, 50.0)]
	for f in 4:
		var f2: int = (f + 1) % 4
		for v in [bt[f], bt[f2], tb[f2], bt[f], tb[f2], tb[f]]:
			st.add_vertex(cart + (v as Vector3))
	for v2 in [bt[0], bt[2], bt[1], bt[0], bt[3], bt[2]]:
		st.add_vertex(cart + (v2 as Vector3))
	st.generate_normals()
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = st.commit()
	body.material_override = mat(Color(0.32, 0.24, 0.18), 0.55, 0.55)
	root.add_child(body)
	for band_y in [30.0, 52.0, 72.0]:
		var hw: float = lerpf(40.0, 52.0, (band_y - 22.0) / 52.0) + 1.0
		var hd: float = lerpf(50.0, 62.0, (band_y - 22.0) / 52.0) + 1.0
		box(Vector3(hw * 2.0, 4.0, 2.0), iron, cart + Vector3(0.0, band_y, hd))
		box(Vector3(hw * 2.0, 4.0, 2.0), iron, cart + Vector3(0.0, band_y, -hd))
		box(Vector3(2.0, 4.0, hd * 2.0), iron, cart + Vector3(hw, band_y, 0.0))
		box(Vector3(2.0, 4.0, hd * 2.0), iron, cart + Vector3(-hw, band_y, 0.0))
		for rv in 6:
			sphere(1.6, iron, cart + Vector3(-hw + float(rv) * hw * 0.4, band_y, hd + 1.0))
	for k6 in 30:
		var lump: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radial_segments = 5
		sm.rings = 3
		sm.radius = 9.0 + 6.0 * h01(k6 + 80)
		sm.height = sm.radius * 1.6
		lump.mesh = sm
		lump.material_override = mat(Color(0.07, 0.07, 0.08), 0.25, 0.3)
		root.add_child(lump)
		lump.position = cart + Vector3((h01(k6 + 81) - 0.5) * 84.0, 76.0 + 10.0 * h01(k6 + 82) * (1.0 - absf(h01(k6 + 81) - 0.5)), (h01(k6 + 83) - 0.5) * 104.0)
		lump.rotation = Vector3(h01(k6 + 84) * 3.0, h01(k6 + 85) * 3.0, 0.0)
	for wx in [-46.0, 46.0]:
		for wz in [-36.0, 36.0]:
			cyl(15.0, 15.0, 5.0, iron, cart + Vector3(wx, 15.0, wz), Vector3(0.0, 0.0, 90.0), null, 24)
			cyl(4.0, 4.0, 7.0, steel, cart + Vector3(wx, 15.0, wz), Vector3(0.0, 0.0, 90.0), null, 12)
			for sp in 4:
				box(Vector3(2.0, 24.0, 2.0), steel, cart + Vector3(wx + signf(wx) * 1.0, 15.0, wz), Vector3(float(sp) * 45.0, 0.0, 0.0))
	# THE SIDE OPENING on the right, dark, and at its mouth the OBSTACLES: a slatted TNT crate with a bundle of
	# dynamite on it and its fuse, and round black bombs along the gallery
	box(Vector3(30.0, 150.0, 120.0), mat(Color(0.0, 0.0, 0.0), 1.0), Vector3(HALF_W + 2.0, 75.0, TNT_Z))
	var tnt: Vector3 = Vector3(HALF_W - 44.0, 0.0, TNT_Z + 14.0)
	var crate_wood: StandardMaterial3D = mat(Color.WHITE, 0.8, 0.0, tex_wood(64, Color(0.58, 0.40, 0.22), 9))
	box(Vector3(50.0, 36.0, 40.0), crate_wood, tnt + Vector3(0.0, 18.0, 0.0), Vector3(0.0, 18.0, 0.0))
	for sl in 3:
		box(Vector3(52.0, 3.0, 41.0), mat(Color(0.40, 0.26, 0.14), 0.8), tnt + Vector3(0.0, 6.0 + float(sl) * 12.0, 0.0), Vector3(0.0, 18.0, 0.0))
	label("TNT", 15.0, Color(0.85, 0.15, 0.10), tnt + Vector3(-6.0, 20.0, 21.0), Vector3(0.0, 18.0, 0.0))
	for dy in 4:
		cyl(4.0, 4.0, 30.0, mat(Color(0.80, 0.16, 0.12), 0.6), tnt + Vector3(-12.0 + float(dy) * 8.0, 40.0, 0.0), Vector3(90.0, 18.0, 0.0), null, 12)
	box(Vector3(36.0, 2.0, 8.0), mat(Color(0.20, 0.18, 0.16), 0.8), tnt + Vector3(0.0, 44.0, 0.0), Vector3(0.0, 18.0, 0.0))
	put(tube_mesh(PackedVector3Array([tnt + Vector3(0.0, 44.0, 14.0), tnt + Vector3(-10.0, 30.0, 34.0), tnt + Vector3(-30.0, 2.0, 46.0)]), 1.2, 6), mat(Color(0.55, 0.45, 0.30), 0.9), Vector3.ZERO)
	_bomb(Vector3(-70.0, 0.0, -760.0), steel)
	_bomb(Vector3(80.0, 0.0, -1040.0), steel)
	# far down, THE WAY OUT: a signal lamp on its post (a housing, a hood, the green lens glowing) and an EXIT sign
	var gx: float = 70.0
	cyl(3.5, 4.5, 130.0, steel, Vector3(gx, 65.0, GOAL_Z))
	put(rbox_mesh(14.0, 12.0, 30.0, 4.0, 2.0), iron, Vector3(gx, 118.0, GOAL_Z))
	cyl(9.0, 9.0, 3.0, glow(Color(0.45, 1.0, 0.55)), Vector3(gx, 133.0, GOAL_Z + 12.5), Vector3(90.0, 0.0, 0.0), null, 20)
	box(Vector3(22.0, 2.0, 12.0), iron, Vector3(gx, 144.0, GOAL_Z + 14.0), Vector3(-15.0, 0.0, 0.0))
	box(Vector3(64.0, 24.0, 3.0), mat(Color(0.10, 0.36, 0.16), 0.6), Vector3(gx - 70.0, 150.0, GOAL_Z + 4.0))
	label("EXIT", 16.0, Color(0.85, 1.0, 0.85), Vector3(gx - 70.0, 150.0, GOAL_Z + 6.0))

# --- live: the lanterns going out and coming back ------------------------------------------------------------------

# how lit lantern k is now (0 out .. 1 lit): out one by one from the far end, back from the near end
func _lit(k: int) -> float:
	var u: float = fmod(t, CYCLE)
	var n: float = float(_lanterns.size())
	var far_first: float = n - 1.0 - float(k)               # 0 for the farthest
	var off_at: float = 0.6 + far_first * 0.20
	var on_at: float = 3.0 + float(k) * 0.14
	var lit: float = 1.0 - smoothstep(off_at, off_at + 0.25, u) + smoothstep(on_at, on_at + 0.20, u)
	lit = clampf(lit, 0.0, 1.0)
	# catching: a flicker as it comes on
	if u > on_at and u < on_at + 0.6:
		lit *= 0.65 + 0.35 * sin((u - on_at) * 60.0 + float(k))
	return lit * (0.90 + 0.10 * sin(t * 13.0 + float(k) * 3.1) * sin(t * 7.3 + float(k)))

func _animate(_delta: float) -> void:
	if _dark == null:
		return
	var lamps: Array = []
	var any: float = 0.0
	for k in _lanterns.size():
		var lt: float = _lit(k)
		any = maxf(any, lt)
		var sp: Vector2 = screen_of(_lanterns[k])
		var near: float = screen_of((_lanterns[k] as Vector3) + Vector3(0.0, 100.0, 0.0)).distance_to(sp)
		lamps.append(Vector4(sp.x, sp.y, near * 1.5, 1.1 * lt))
	# the goal's lamp stays: the one thing left in the dark, faint
	var gp: Vector2 = screen_of(Vector3(70.0, 124.0, GOAL_Z))
	lamps.append(Vector4(gp.x, gp.y, 50.0, 0.7))
	var u: float = fmod(t, CYCLE)
	var dark: float = lerpf(0.55, 0.96, smoothstep(0.6, 2.4, u) * (1.0 - smoothstep(3.0, 4.4, u)))
	set_darkness(dark, Color(0.0, 0.0, 0.01), lamps)

# the flames over the dark: a small bright core and a soft halo, for each lit lantern
func _paint_top(_full: Vector2, _bottom: float) -> void:
	if _dark != null:
		for k in _lanterns.size():
			var lt: float = _lit(k)
			if lt <= 0.02:
				continue
			var sp: Vector2 = screen_of(_lanterns[k])
			var sc: float = screen_of((_lanterns[k] as Vector3) + Vector3(0.0, 100.0, 0.0)).distance_to(sp) / 100.0
			# a soft halo through the glass, then THE FLAME: a teardrop that leans and stretches as it flickers (flat
			# discs read as "flat circles")
			for j in 8:
				cv.draw_circle(sp, (34.0 - float(j) * 3.6) * sc, Color(1.0, 0.72, 0.38, 0.035 * lt))
			var fl_h: float = (7.0 + 1.6 * sin(t * 17.0 + float(k)) + 0.8 * sin(t * 29.0 + float(k) * 2.0)) * sc
			var fl_w: float = 2.6 * sc
			var lean: float = 1.0 * sin(t * 7.0 + float(k)) * sc
			var base: Vector2 = sp + Vector2(0.0, 2.0 * sc)
			for layer_i in 2:
				var kk: float = 1.0 - 0.45 * float(layer_i)
				var pts: PackedVector2Array = PackedVector2Array()
				for a in 10:
					var ang: float = PI * float(a) / 9.0
					pts.append(base + Vector2(-cos(ang) * fl_w * kk, sin(ang) * fl_w * kk * 0.8))
				pts.append(base + Vector2(lean * kk, -fl_h * kk))
				cv.draw_colored_polygon(pts, Color(1.0, 0.72, 0.30, lt) if layer_i == 0 else Color(1.0, 0.97, 0.82, lt))
	title("Lights Out", "Remember your path, goal, and obstacles", Color(1.0, 0.82, 0.50), Color(0.10, 0.06, 0.02),
		Color(1.0, 0.7, 0.35, 0.25))

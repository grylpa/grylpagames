extends "res://scripts/menu_poster3d.gd"

# PICKPOCKET'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): THE
# PICKPOCKET'S HAUL, BY CANDLELIGHT (2026-11-18; a new concept -- the shell game at the table, tried several ways, kept
# failing, the user: "think of another concept completely"). A night's takings tipped out on an old oak table: a
# leather purse on its side spilling gold and silver coins, wallets of different leathers -- one open on its banknotes
# --, pocket watches in gold and silver with their chains, a string of pearls, a lady's ring; a tallow candle in a
# brass stick lights it all from the back, its flame alive, and over the table's front edge ONE WATCH HANGS BY ITS
# CHAIN, caught under a wallet, swinging slowly, its second hand ticking. No people: the pickpocket is only what he
# took. The table and its haul are baked, one picture per platform (`menu_haul.webp`, `menu_haul_d.webp`); the
# candle's flame and the hanging watch are live. Made up, never the board.

const CANDLE: Vector3 = Vector3(-300.0, 0.0, -300.0)
const STAND: Vector3 = Vector3(270.0, 0.0, -110.0)    # the brass watch stand the swinging watch hangs from
const HANG: Vector3 = Vector3(270.0, 238.0, -78.0)    # its hook
const CHAIN_L: float = 46.0

var _flame: MeshInstance3D = null
var _halo: MeshInstance3D = null
var _swing: Node3D = null
var _second: Node3D = null
var _root_flame: MeshInstance3D = null
var _flame_pivot: Node3D = null         # at the wick: the flame bends from its root, never leaves it
var _flame_light: OmniLight3D = null

func _baked_path() -> String:
	return "res://pickpocket/art/menu_haul.webp" if mobile else "res://pickpocket/art/menu_haul_d.webp"

func _eye() -> Vector3:
	return Vector3(30.0, 520.0, 690.0) if mobile else Vector3(30.0, 520.0, 900.0)

func _aim() -> Vector3:
	return Vector3(20.0, -30.0, 10.0) if mobile else Vector3(20.0, 0.0, -20.0)

func _fov() -> float:
	return 44.0

func _frame_frac() -> float:
	return 0.5

func _environment(env: Environment) -> void:
	env.background_color = Color(0.02, 0.015, 0.012)
	env.ambient_light_color = Color(0.55, 0.45, 0.38)
	env.ambient_light_energy = 0.16

func _build_lights() -> void:
	# the candle: warm, low, from the back left, its shadows running toward you; a cold glint of moonlight from the
	# right so the silver reads; a faint warm bounce off the table
	light(CANDLE + Vector3(0.0, 250.0, 0.0), Color(1.0, 0.74, 0.42), 5.0, 2200.0, true)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.light_color = Color(0.62, 0.70, 1.0)
	moon.light_energy = 0.35
	moon.rotation_degrees = Vector3(-40.0, 60.0, 0.0)
	root.add_child(moon)
	light(Vector3(100.0, 200.0, 650.0), Color(1.0, 0.80, 0.60), 0.9, 1400.0)

# --- the haul: real 3-D, baked ------------------------------------------------------------------------------------

func _lathe(profile: Array, m: Material, at: Vector3, segs: int = 32, rot: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
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
	return put(st.commit(), m, at, rot, parent)

func _leather(n: int, base: Color, seed_i: int) -> ImageTexture:
	# grained leather: a fine pebble, creases, worn paler along the edges
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_i
	noise.frequency = 0.25
	var crease: FastNoiseLite = FastNoiseLite.new()
	crease.seed = seed_i + 7
	crease.frequency = 0.03
	for y in n:
		for x in n:
			var g: float = noise.get_noise_2d(float(x), float(y)) * 0.08
			var cr: float = absf(crease.get_noise_2d(float(x), float(y)))
			var c: Color = base.lightened(g) if g > 0.0 else base.darkened(-g)
			if cr < 0.03:
				c = c.darkened(0.25)
			var ex: float = minf(minf(float(x), float(n - 1 - x)), minf(float(y), float(n - 1 - y))) / float(n)
			c = c.lightened(0.18 * (1.0 - smoothstep(0.0, 0.06, ex)))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _banknote(n: int, tint: Color) -> ImageTexture:
	# an engraved note: a pale ground, a frame of fine lines, an oval with a portrait's shading, the denomination's corners
	var img: Image = Image.create(n * 2, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n * 2:
			var c: Color = Color(0.86, 0.84, 0.74).lerp(tint, 0.35)
			var ex: int = mini(mini(x, n * 2 - 1 - x), mini(y, n - 1 - y))
			if ex == 4 or ex == 6:
				c = tint.darkened(0.45)
			elif ex > 6 and ex < 12 and (x + y) % 3 == 0:
				c = tint.darkened(0.3)
			var o: Vector2 = Vector2(float(x) - float(n) * 1.25, (float(y) - float(n) * 0.5) * 1.3)
			if o.length() < float(n) * 0.30:
				if (x * 3 + y) % 4 == 0 or o.length() > float(n) * 0.27:
					c = tint.darkened(0.5)
			if (x < n / 3 or x > n * 5 / 3) and (y < n / 3 or y > n * 2 / 3) and ex > 12 and (x / 3 + y / 3) % 2 == 0:
				c = tint.darkened(0.4)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _watch_face(n: int, roman: bool) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var ctr: Vector2 = Vector2(float(n), float(n)) * 0.5
	for y in n:
		for x in n:
			var p: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5) - ctr
			var r: float = p.length() / (float(n) * 0.5)
			var c: Color = Color(0.95, 0.93, 0.86) if roman else Color(0.92, 0.90, 0.84)
			c = c.darkened(0.08 * r * r)
			var a: float = atan2(p.y, p.x)
			# the minute track, the hour marks, the small seconds dial at six
			if r > 0.84 and r < 0.86:
				c = Color(0.12, 0.10, 0.08)
			var tick: float = fposmod(a / TAU * 60.0, 1.0)
			if r > 0.86 and r < 0.92 and (tick < 0.06 or tick > 0.94):
				c = Color(0.12, 0.10, 0.08)
			var hr: float = fposmod(a / TAU * 12.0, 1.0)
			if r > 0.62 and r < 0.82 and (hr < 0.035 or hr > 0.965):
				c = Color(0.10, 0.08, 0.06)
			var sd: float = (p - Vector2(0.0, float(n) * 0.24)).length() / (float(n) * 0.5)
			if absf(sd - 0.20) < 0.012:
				c = Color(0.20, 0.16, 0.12)
			img.set_pixel(x, y, Color(c, 1.0 if r < 1.0 else 0.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# a pocket watch lying (or hanging) in `parent`'s frame, its face toward +y: case, bezel, crystal, the face, hands, the
# crown and bow at twelve (toward -z)
func _watch(at: Vector3, gold: bool, roman: bool, hands: float, parent: Node3D = null, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var w: Node3D = Node3D.new()
	(parent if parent != null else root).add_child(w)
	w.position = at
	w.rotation_degrees = rot
	var metal: StandardMaterial3D = mat(Color(0.92, 0.72, 0.36) if gold else Color(0.80, 0.82, 0.86), 0.18, 0.95)
	_lathe([Vector2(0.0, 0.0), Vector2(30.0, 0.0), Vector2(36.0, 4.0), Vector2(38.0, 9.0), Vector2(37.0, 13.0), Vector2(33.0, 15.0), Vector2(31.0, 16.0)], metal, Vector3.ZERO, 48, Vector3.ZERO, w)
	var face_m: StandardMaterial3D = mat(Color.WHITE, 0.5, 0.0, _watch_face(128, roman))
	face_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var fq: PlaneMesh = PlaneMesh.new()
	fq.size = Vector2(62.0, 62.0)
	put(fq, face_m, Vector3(0.0, 13.5, 0.0), Vector3.ZERO, w)
	var hand_m: StandardMaterial3D = mat(Color(0.06, 0.06, 0.10), 0.3, 0.6)
	var hh: MeshInstance3D = box(Vector3(2.4, 0.6, 16.0), hand_m, Vector3(0.0, 14.2, 0.0), Vector3.ZERO, w)
	hh.rotation = Vector3(0.0, -hands, 0.0)
	hh.position = Vector3(sin(hands) * -8.0, 14.2, -cos(hands) * 8.0)
	var mh: MeshInstance3D = box(Vector3(1.6, 0.6, 24.0), hand_m, Vector3(0.0, 14.4, 0.0), Vector3.ZERO, w)
	mh.rotation = Vector3(0.0, -hands * 7.3, 0.0)
	mh.position = Vector3(sin(hands * 7.3) * -12.0, 14.4, -cos(hands * 7.3) * 12.0)
	sphere(1.8, metal, Vector3(0.0, 14.8, 0.0), w)
	var crystal: CylinderMesh = CylinderMesh.new()
	crystal.top_radius = 30.0
	crystal.bottom_radius = 31.0
	crystal.height = 1.2
	crystal.radial_segments = 40
	var glass: StandardMaterial3D = mat(Color(0.9, 0.95, 1.0, 0.12), 0.02, 0.3)
	put(crystal, glass, Vector3(0.0, 15.6, 0.0), Vector3.ZERO, w).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the pendant, the crown (knurled) and the bow
	cyl(4.0, 4.0, 8.0, metal, Vector3(0.0, 8.0, -40.0), Vector3(90.0, 0.0, 0.0), w, 12)
	cyl(5.5, 5.5, 6.0, metal, Vector3(0.0, 8.0, -46.0), Vector3(90.0, 0.0, 0.0), w, 16)
	var bow: TorusMesh = TorusMesh.new()
	bow.inner_radius = 9.0
	bow.outer_radius = 11.5
	put(bow, metal, Vector3(0.0, 8.0, -56.0), Vector3(0.0, 0.0, 90.0), w)
	return w

# a chain of oval links along a path, each turned a quarter from the last
func _chain(path: PackedVector3Array, gold: bool, parent: Node3D = null) -> void:
	var metal: StandardMaterial3D = mat(Color(0.92, 0.72, 0.36) if gold else Color(0.80, 0.82, 0.86), 0.2, 0.95)
	var link: TorusMesh = TorusMesh.new()
	link.inner_radius = 2.4
	link.outer_radius = 3.6
	link.rings = 10
	link.ring_segments = 6
	var total: float = 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	var step: float = 5.6
	var d: float = 0.0
	var k: int = 0
	var seg_i: int = 0
	var seg_d: float = 0.0
	while d < total and seg_i < path.size() - 1:
		var seg_len: float = path[seg_i].distance_to(path[seg_i + 1])
		if d - seg_d > seg_len:
			seg_d += seg_len
			seg_i += 1
			continue
		var f: float = (d - seg_d) / maxf(0.001, seg_len)
		var p: Vector3 = path[seg_i].lerp(path[seg_i + 1], f)
		var dir: Vector3 = (path[seg_i + 1] - path[seg_i]).normalized()
		var mi: MeshInstance3D = put(link, metal, p, Vector3.ZERO, parent)
		# the link's long axis along the chain, its ring's axis across it -- turned a quarter from the last link's
		var n1: Vector3 = dir.cross(Vector3.UP)
		if n1.length() < 0.1:
			n1 = dir.cross(Vector3.RIGHT)
		n1 = n1.normalized()
		var axis: Vector3 = n1 if k % 2 == 0 else dir.cross(n1).normalized()
		mi.basis = Basis(dir * 1.6, axis, dir.cross(axis))
		d += step
		k += 1

# THE PURSE: a soft leather sack slumped on its side -- a squashed body, crumpled (its skin pushed in and out by a
# noise), its mouth toward you drawn into a short neck gathered into folds by the string, the lip flaring out past it
func _sack() -> ArrayMesh:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.035
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: int = 28
	var segs: int = 40
	var grid: Array = []
	for i in rings + 1:
		var v: float = float(i) / float(rings)            # 0 at the back, 1 at the mouth
		var row: Array = []
		for j in segs + 1:
			var th: float = TAU * float(j) / float(segs)
			var r: float
			var z: float
			if v < 0.72:
				var ph: float = v / 0.72 * PI
				r = 100.0 * sin(ph) + 30.0 * smoothstep(0.5, 1.0, v / 0.72)
				z = -95.0 * cos(ph) - 10.0
			elif v < 0.88:
				var nv: float = (v - 0.72) / 0.16
				r = lerpf(30.0, 22.0, nv) * (1.0 + 0.16 * sin(th * 9.0))
				z = lerpf(85.0, 118.0, nv)
			else:
				var lv: float = (v - 0.88) / 0.12
				r = lerpf(22.0, 42.0, lv) * (1.0 + 0.22 * sin(th * 9.0))
				z = lerpf(118.0, 136.0, lv)
			var p: Vector3 = Vector3(cos(th) * r * 1.15, sin(th) * r * 0.62, z)
			var bump: float = noise.get_noise_3d(p.x, p.y, p.z) * 12.0 * (1.0 if v < 0.72 else 0.3)
			p += Vector3(cos(th), sin(th), 0.0) * bump
			p.y += 62.0
			# the body sags onto the table: nothing below it
			p.y = maxf(p.y, 2.0 + 0.02 * absf(p.x))
			row.append(p)
		grid.append(row)
	for i in rings:
		for j in segs:
			var q: Array = [grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]]
			for vi in [0, 2, 1, 0, 3, 2]:
				st.set_uv(Vector2(float(j) / float(segs), float(i) / float(rings)))
				st.add_vertex(q[vi])
	st.generate_normals()
	return st.commit()

func _coin(at: Vector3, r: float, gold: bool, tilt: Vector3 = Vector3.ZERO) -> void:
	var m: StandardMaterial3D = mat(Color(0.94, 0.74, 0.34) if gold else Color(0.78, 0.78, 0.80), 0.25, 0.95)
	_lathe([Vector2(0.0, 0.0), Vector2(r - 0.6, 0.0), Vector2(r, 0.6), Vector2(r, 2.4), Vector2(r - 0.6, 3.0), Vector2(r - 2.0, 3.0),
		Vector2(r - 2.4, 2.2), Vector2(r * 0.55, 2.4), Vector2(r * 0.5, 2.9), Vector2(0.0, 2.9)], m, at, 28, tilt)

func _wallet(at: Vector3, w: float, d: float, h: float, base: Color, yaw: float, seed_i: int) -> void:
	var m: StandardMaterial3D = mat(Color.WHITE, 0.55, 0.0, _leather(64, base, seed_i))
	put(rbox_mesh(w * 0.5, d * 0.5, h, 6.0, 2.5), m, at, Vector3(0.0, yaw, 0.0))
	# the stitching round its edge
	var stitch: StandardMaterial3D = mat(base.lightened(0.45), 0.8)
	var yr: float = deg_to_rad(yaw)
	for sk in 24:
		var f: float = float(sk) / 24.0
		var p: Vector3
		if f < 0.5:
			p = Vector3(lerpf(-w * 0.44, w * 0.44, f * 2.0), h + 0.2, -d * 0.44)
		else:
			p = Vector3(lerpf(-w * 0.44, w * 0.44, (f - 0.5) * 2.0), h + 0.2, d * 0.44)
		box(Vector3(3.0, 0.4, 0.8), stitch, at + p.rotated(Vector3.UP, yr), Vector3(0.0, yaw, 0.0))

func _build_still() -> void:
	var oak: StandardMaterial3D = mat(Color.WHITE, 0.45, 0.0, tex_wood(256, Color(0.30, 0.18, 0.10), 6), Vector3(2, 3, 1))
	# THE TABLE: thick planks, their joints, a worn rounded front edge; the dark room behind
	for pl in 6:
		var pz: float = -700.0 + float(pl) * 160.0
		box(Vector3(1800.0, 30.0, 156.0), oak, Vector3(0.0, -15.0, pz + 80.0))
	cyl(15.0, 15.0, 1800.0, oak, Vector3(0.0, -15.0, 262.0), Vector3(0.0, 0.0, 90.0), null, 20)
	box(Vector3(1800.0, 200.0, 30.0), oak, Vector3(0.0, -130.0, 250.0))
	box(Vector3(4000.0, 3000.0, 20.0), mat(Color.WHITE, 0.9, 0.0, tex_speckle(64, Color(0.10, 0.08, 0.07), 0.12, 3)), Vector3(0.0, 800.0, -900.0))
	# THE CANDLE in a brass chamberstick: the dish, the socket, a tallow candle with its drips
	var brass: StandardMaterial3D = mat(Color(0.86, 0.66, 0.32), 0.25, 0.85)
	_lathe([Vector2(0.0, 0.0), Vector2(70.0, 0.0), Vector2(74.0, 6.0), Vector2(70.0, 12.0), Vector2(30.0, 14.0), Vector2(22.0, 20.0), Vector2(20.0, 48.0), Vector2(26.0, 54.0), Vector2(0.0, 54.0)], brass, CANDLE, 48)
	var tallow: StandardMaterial3D = mat(Color(0.94, 0.88, 0.72), 0.6)
	tallow.subsurf_scatter_enabled = true
	tallow.subsurf_scatter_strength = 0.6
	_lathe([Vector2(0.0, 52.0), Vector2(17.0, 52.0), Vector2(17.0, 190.0), Vector2(15.0, 196.0), Vector2(10.0, 192.0), Vector2(0.0, 194.0)], tallow, CANDLE, 32)
	for dr in 5:
		var da: float = TAU * float(dr) / 5.0 + 0.4
		var drip: PackedVector3Array = PackedVector3Array()
		var dl: float = 30.0 + 60.0 * h01(dr + 3)
		for dk in 6:
			var f: float = float(dk) / 5.0
			drip.append(CANDLE + Vector3(cos(da) * 17.6, 194.0 - dl * f, sin(da) * 17.6))
		put(tube_mesh(drip, 2.6, 6), tallow, Vector3.ZERO)
	cyl(1.0, 1.4, 12.0, mat(Color(0.05, 0.04, 0.04), 0.9), CANDLE + Vector3(0.0, 200.0, 0.0), Vector3(8.0, 0.0, 0.0), null, 6)
	# THE PURSE on its side at the back, mouth toward you, spilling coins: soft leather gathered at a drawstring
	var purse_c: Vector3 = Vector3(-80.0, 0.0, -260.0)
	var purse_m: StandardMaterial3D = mat(Color.WHITE, 0.62, 0.0, _leather(128, Color(0.22, 0.12, 0.06), 3), Vector3(2, 2, 1))
	put(_sack(), purse_m, purse_c)
	# the drawstring round the gathered neck, tied, its ends trailing on the table
	var cord: PackedVector3Array = PackedVector3Array()
	for ck in 40:
		var ca: float = TAU * float(ck) / 39.0
		cord.append(purse_c + Vector3(cos(ca) * 30.0, 50.0 + sin(ca) * 28.0, 118.0))
	put(tube_mesh(cord, 3.0, 8), mat(Color(0.62, 0.48, 0.26), 0.8), Vector3.ZERO)
	var tail: PackedVector3Array = PackedVector3Array([purse_c + Vector3(28.0, 40.0, 122.0), purse_c + Vector3(50.0, 16.0, 150.0), purse_c + Vector3(100.0, 3.0, 176.0), purse_c + Vector3(150.0, 3.0, 196.0)])
	put(tube_mesh(tail, 3.0, 8), mat(Color(0.62, 0.48, 0.26), 0.8), Vector3.ZERO)
	# THE COINS: a spill fanning out of the purse's mouth, stacks, a few on edge against things
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	for cn in 46:
		var spread: float = rng.randf()
		var ang: float = rng.randf_range(-0.9, 0.9)
		var dist: float = 40.0 + 260.0 * spread * spread
		var pos: Vector3 = purse_c + Vector3(sin(ang) * dist, 0.0, 130.0 + cos(ang) * dist * 0.7)
		var gold: bool = rng.randf() < 0.55
		# none on the newspaper: its headline must read whole
		if pos.x > -60.0 and pos.z > -100.0:
			continue
		var r: float = rng.randf_range(19.0, 25.0) if gold else rng.randf_range(22.0, 29.0)
		var lean: Vector3 = Vector3(rng.randf_range(-6.0, 6.0), rng.randf_range(0.0, 360.0), rng.randf_range(-6.0, 6.0))
		if cn % 9 == 0:
			lean.x = 24.0
		_coin(pos + Vector3(0.0, 0.5 + (4.0 if cn % 9 == 0 else 0.0), 0.0), r, gold, lean)
	for stack in 2:
		var sp: Vector3 = Vector3(-280.0 + float(stack) * 70.0, 0.0, -40.0 + float(stack) * 40.0)
		for sc in 6 + stack * 3:
			_coin(sp + Vector3(rng.randf_range(-1.5, 1.5), float(sc) * 3.0, rng.randf_range(-1.5, 1.5)), 18.0, stack == 0, Vector3(0.0, rng.randf_range(0.0, 360.0), 0.0))
	# THE WALLETS: black, oxblood and tan, one OPEN on its banknotes
	_wallet(Vector3(120.0, 0.0, -270.0), 210.0, 130.0, 18.0, Color(0.10, 0.09, 0.09), -18.0, 4)
	_wallet(Vector3(150.0, 18.0, -260.0), 200.0, 120.0, 16.0, Color(0.38, 0.08, 0.08), 8.0, 9)
	_wallet(Vector3(130.0, 0.0, 200.0), 190.0, 120.0, 16.0, Color(0.50, 0.32, 0.16), 14.0, 12)
	var open_c: Vector3 = Vector3(-280.0, 0.0, 120.0)
	var tan_m: StandardMaterial3D = mat(Color.WHITE, 0.55, 0.0, _leather(64, Color(0.24, 0.14, 0.08), 21))
	put(rbox_mesh(110.0, 70.0, 6.0, 6.0, 2.0), tan_m, open_c, Vector3(0.0, 24.0, 0.0))
	var notes: Array = [Color(0.40, 0.55, 0.40), Color(0.55, 0.40, 0.55), Color(0.62, 0.50, 0.30)]
	for nt in 3:
		var nq: PlaneMesh = PlaneMesh.new()
		nq.size = Vector2(196.0, 98.0)
		var nm: StandardMaterial3D = mat(Color.WHITE, 0.8, 0.0, _banknote(64, notes[nt]))
		put(nq, nm, open_c + Vector3(-6.0 + float(nt) * 10.0, 7.0 + float(nt) * 0.8, -10.0 + float(nt) * 12.0), Vector3(0.0, 24.0 + float(nt) * 9.0 - 9.0, 0.0))
	# THE WATCHES lying: gold with Roman numerals, silver with a plain dial, each with its chain trailing
	_watch(Vector3(-110.0, 0.0, 60.0), true, true, 1.2, null, Vector3(0.0, -30.0, 0.0))
	var ch1: PackedVector3Array = PackedVector3Array()
	for c1 in 12:
		var f1: float = float(c1) / 11.0
		ch1.append(Vector3(-110.0 + 30.0 - 120.0 * f1, 2.5, 60.0 - 50.0 - 60.0 * sin(f1 * 2.4)))
	_chain(ch1, true)
	_watch(Vector3(400.0, 0.0, 60.0), false, false, 4.0, null, Vector3(0.0, 40.0, 0.0))
	var ch2: PackedVector3Array = PackedVector3Array()
	for c2 in 12:
		var f2: float = float(c2) / 11.0
		ch2.append(Vector3(400.0 + 40.0 + 90.0 * f2, 2.5, 60.0 - 40.0 + 70.0 * sin(f2 * 3.0)))
	_chain(ch2, false)
	# A STRING OF PEARLS looping across the front, their luster; a lady's ring with its stone
	var pearl: StandardMaterial3D = mat(Color(0.96, 0.94, 0.90), 0.15, 0.1)
	pearl.clearcoat_enabled = true
	pearl.rim_enabled = true
	pearl.rim = 0.4
	# (lying on a clear patch of the table, each pearl resting on the wood -- across the wallet they hovered, the user;
	# then a perfect ring of them with no shadow still looked afloat): a strand DROPPED -- an open, slack loop folding back
	# on itself, one end trailing to the clasp, the pearls touching along a silk thread, each sitting ON the wood, and a
	# soft contact shadow under the whole strand (the lamp's own shadow of pearls this small is lost in the bias)
	var dense: PackedVector3Array = PackedVector3Array()
	for dk in 400:
		var u: float = float(dk) / 399.0
		var pa: float = lerpf(-0.35, TAU * 1.08, u)
		var pr: float = 66.0 + 16.0 * sin(pa * 2.0 + 0.7) + 7.0 * sin(pa * 3.0 + 2.0) - 22.0 * u * u
		dense.append(Vector3(-85.0 + cos(pa) * pr * 1.1, 0.0, 192.0 + sin(pa) * pr * 0.42 + 10.0 * u))
	var strand: PackedVector3Array = PackedVector3Array()
	strand.append(dense[0])
	var run: float = 0.0
	for dk2 in range(1, dense.size()):
		run += dense[dk2].distance_to(dense[dk2 - 1])
		if run >= 11.6:
			strand.append(dense[dk2])
			run = 0.0
	var pearl_r: float = 5.6
	var thread: PackedVector3Array = PackedVector3Array()
	for pk in strand.size():
		var pp: Vector3 = strand[pk]
		# where the strand crosses itself the upper pearls ride on the lower ones
		var lift: float = 0.0
		for qk in pk - 3:
			if strand[qk].distance_to(pp) < pearl_r * 1.6:
				lift = pearl_r * 1.3
		var sz: float = pearl_r * (0.94 + 0.10 * h01(pk + 300))
		sphere(sz, pearl, Vector3(pp.x, sz + lift, pp.z))
		thread.append(Vector3(pp.x, sz + lift, pp.z))
	put(tube_mesh(thread, 0.7, 4), mat(Color(0.80, 0.76, 0.66), 0.8), Vector3.ZERO)
	var last: Vector3 = strand[strand.size() - 1]
	box(Vector3(10.0, 5.0, 6.0), mat(Color(0.92, 0.74, 0.40), 0.2, 0.95), Vector3(last.x + 8.0, 2.6, last.z + 2.0), Vector3(0.0, 20.0, 0.0))
	# the contact shadow: a soft dark trace of the strand on the wood
	var sh_min: Vector2 = Vector2(1e9, 1e9)
	var sh_max: Vector2 = Vector2(-1e9, -1e9)
	for sp in strand:
		sh_min = Vector2(minf(sh_min.x, sp.x), minf(sh_min.y, sp.z))
		sh_max = Vector2(maxf(sh_max.x, sp.x), maxf(sh_max.y, sp.z))
	sh_min -= Vector2(24.0, 24.0)
	sh_max += Vector2(24.0, 24.0)
	var sw: int = 256
	var shh: int = int(256.0 * (sh_max.y - sh_min.y) / (sh_max.x - sh_min.x)) + 1
	var sh_img: Image = Image.create(sw, shh, false, Image.FORMAT_RGBA8)
	var per: float = float(sw) / (sh_max.x - sh_min.x)
	for sy in shh:
		for sx in sw:
			var wpt: Vector2 = sh_min + Vector2(float(sx), float(sy)) / per
			var dark: float = 0.0
			for sp2 in strand:
				var dd: float = wpt.distance_to(Vector2(sp2.x + 3.0, sp2.z + 2.5))
				dark = maxf(dark, 1.0 - smoothstep(pearl_r * 0.4, pearl_r * 1.9, dd))
			sh_img.set_pixel(sx, sy, Color(0.02, 0.01, 0.0, 0.72 * dark))
	var sh_m: StandardMaterial3D = StandardMaterial3D.new()
	sh_m.albedo_texture = ImageTexture.create_from_image(sh_img)
	sh_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sh_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sh_q: PlaneMesh = PlaneMesh.new()
	sh_q.size = sh_max - sh_min
	var sh_mi: MeshInstance3D = put(sh_q, sh_m, Vector3((sh_min.x + sh_max.x) * 0.5, 0.3, (sh_min.y + sh_max.y) * 0.5))
	sh_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_c: Vector3 = Vector3(250.0, 0.0, 100.0)
	var band: TorusMesh = TorusMesh.new()
	band.inner_radius = 12.0
	band.outer_radius = 16.0
	put(band, mat(Color(0.94, 0.76, 0.40), 0.2, 0.95), ring_c + Vector3(0.0, 4.0, 0.0))
	var stone_m: StandardMaterial3D = mat(Color(0.70, 0.05, 0.12), 0.05, 0.1)
	stone_m.emission_enabled = true
	stone_m.emission = Color(0.4, 0.0, 0.05)
	sphere(7.0, stone_m, ring_c + Vector3(0.0, 8.0, -16.0))
	# THE WATCH STAND the swinging watch hangs from: a turned brass foot, a slender column, a curved arm with a hook
	_lathe([Vector2(0.0, 0.0), Vector2(46.0, 0.0), Vector2(48.0, 5.0), Vector2(40.0, 10.0), Vector2(16.0, 16.0), Vector2(10.0, 24.0), Vector2(0.0, 24.0)], mat(Color(0.86, 0.66, 0.32), 0.25, 0.85), STAND, 40)
	var stand_m: StandardMaterial3D = mat(Color(0.86, 0.66, 0.32), 0.25, 0.85)
	cyl(3.6, 4.6, 210.0, stand_m, STAND + Vector3(0.0, 128.0, 0.0), Vector3.ZERO, null, 14)
	sphere(6.0, stand_m, STAND + Vector3(0.0, 236.0, 0.0))
	var arm: PackedVector3Array = PackedVector3Array()
	for ak in 10:
		var af: float = float(ak) / 9.0
		arm.append(STAND + Vector3(0.0, 236.0 + 14.0 * sin(af * PI * 0.8), 32.0 * af))
	put(tube_mesh(arm, 2.6, 8), stand_m, Vector3.ZERO)
	var hook: TorusMesh = TorusMesh.new()
	hook.inner_radius = 3.0
	hook.outer_radius = 5.0
	put(hook, stand_m, HANG + Vector3(0.0, -2.0, 0.0), Vector3(0.0, 90.0, 90.0))
	# THE NEWSPAPER the haul lies on, folded: its masthead and the headline that says what this is -- and the thief's
	# own flat cap beside it (the user: "what does it represent? things stolen?")
	var paper_c: Vector3 = Vector3(110.0, 0.6, 30.0)
	var npm: PlaneMesh = PlaneMesh.new()
	npm.size = Vector2(300.0, 210.0)
	put(npm, mat(Color.WHITE, 0.9, 0.0, _newsprint(256)), paper_c, Vector3(0.0, -8.0, 0.0))
	var mast: Label3D = label("THE EVENING COURIER", 15.0, Color(0.10, 0.09, 0.08), paper_c + Vector3(-8.0, 0.8, -84.0), Vector3(-90.0, -8.0, 0.0))
	mast.outline_size = 0
	var head: Label3D = label("PICKPOCKET STRIKES AGAIN", 21.0, Color(0.06, 0.05, 0.05), paper_c + Vector3(-4.0, 0.8, -56.0), Vector3(-90.0, -8.0, 0.0))
	head.outline_size = 0
	var sub: Label3D = label("Seven purses and a gold watch taken at the market", 8.5, Color(0.18, 0.16, 0.14), paper_c + Vector3(-2.0, 0.8, -36.0), Vector3(-90.0, -8.0, 0.0))
	sub.outline_size = 0
	_cap(Vector3(-330.0, 0.0, -40.0))

func _newsprint(n: int) -> ImageTexture:
	# yellowed newsprint: columns of fine text lines, a rule under the masthead, a fold across the middle
	var img: Image = Image.create(n, n * 7 / 10, false, Image.FORMAT_RGB8)
	var h: int = n * 7 / 10
	for y in h:
		for x in n:
			var c: Color = Color(0.84, 0.81, 0.72).darkened(0.05 * h01(x * 5 + y * 31))
			var col_i: int = x / (n / 4)
			var inc: int = x % (n / 4)
			var row_y: int = y - int(float(h) * 0.42)
			if row_y > 0 and inc > 4 and inc < n / 4 - 4 and row_y % 4 == 0 and h01(col_i * 97 + row_y / 4 * 13) > 0.08:
				c = c.darkened(0.30 + 0.15 * h01(x / 3 + y * 7))
			if absi(y - int(float(h) * 0.08)) < 1 or absi(y - int(float(h) * 0.40)) < 1:
				c = Color(0.20, 0.18, 0.16)
			if absi(y - h / 2) < 2:
				c = c.darkened(0.12)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# THE THIEF'S FLAT CAP: a tweed crown, soft and a little slumped, its peak snapped down at the front
func _cap(at: Vector3) -> void:
	var tweed_img: Image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var hb: bool = ((x + (y / 4) * 2) % 8) < 4 if (y / 8) % 2 == 0 else ((x - (y / 4) * 2 + 64) % 8) < 4
			var c: Color = Color(0.34, 0.30, 0.24) if hb else Color(0.24, 0.21, 0.17)
			_img_speck(tweed_img, x, y, c)
	tweed_img.generate_mipmaps()
	var tweed: StandardMaterial3D = mat(Color.WHITE, 0.95, 0.0, ImageTexture.create_from_image(tweed_img), Vector3(3, 3, 1))
	var crown: MeshInstance3D = sphere(78.0, tweed, at + Vector3(0.0, 10.0, -12.0), null, true)
	crown.scale = Vector3(1.0, 0.36, 1.1)
	crown.rotation = Vector3(0.10, 0.4, 0.0)
	var peak: MeshInstance3D = sphere(64.0, tweed, at + Vector3(sin(0.4) * 60.0, 6.0, cos(0.4) * 60.0), null, true)
	peak.scale = Vector3(0.9, 0.10, 0.45)
	peak.rotation = Vector3(0.0, 0.4, 0.0)
	sphere(5.0, tweed, at + Vector3(0.0, 38.0, -10.0))

func _img_speck(img: Image, x: int, y: int, c: Color) -> void:
	img.set_pixel(x, y, c.darkened(0.12 * h01(x * 13 + y * 7)))

# --- live: the candle's flame and the hanging watch ---------------------------------------------------------------

func _build_live() -> void:
	# THE FLAME: a bright core in a soft teardrop, and a halo in the air round it
	var fm: StandardMaterial3D = glow(Color(1.0, 0.78, 0.36))
	_flame_pivot = Node3D.new()
	root.add_child(_flame_pivot)
	_flame_pivot.position = CANDLE + Vector3(0.0, 205.0, 0.0)
	_flame = sphere(9.0, fm, Vector3(0.0, 17.0, 0.0), _flame_pivot)
	_flame.scale = Vector3(0.6, 2.0, 0.6)
	# its blue root at the wick, and the flame's own light, flickering on the live watch
	_root_flame = sphere(4.0, glow(Color(0.35, 0.50, 1.0, 0.7)), Vector3(0.0, 2.0, 0.0), _flame_pivot)
	_flame_light = light(CANDLE + Vector3(0.0, 236.0, 0.0), Color(1.0, 0.72, 0.40), 2.0, 1600.0)
	sphere(4.0, glow(Color(1.0, 0.98, 0.90)), Vector3(0.0, 7.0, 0.0), _flame_pivot)
	var hm: StandardMaterial3D = StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.billboard_keep_scale = true
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.55, 0.55))
	g.set_color(1, Color(1.0, 0.6, 0.3, 0.0))
	gt.gradient = g
	hm.albedo_texture = gt
	var hq: QuadMesh = QuadMesh.new()
	hq.size = Vector2(150.0, 150.0)
	_halo = put(hq, hm, CANDLE + Vector3(0.0, 222.0, 4.0))
	# THE HANGING WATCH: a pivot at the table's edge, the chain hanging from it, the watch at its end, face toward you
	_swing = Node3D.new()
	root.add_child(_swing)
	_swing.position = HANG
	var hang_path: PackedVector3Array = PackedVector3Array()
	for hk in 8:
		hang_path.append(Vector3(0.0, -CHAIN_L * float(hk) / 7.0, 0.0))
	_chain(hang_path, true, _swing)
	var w: Node3D = _watch(Vector3(0.0, -CHAIN_L - 56.0, 0.0), true, true, 2.1, _swing, Vector3(90.0, 0.0, 0.0))
	# its seconds hand on the small dial, ticking
	_second = Node3D.new()
	w.add_child(_second)
	_second.position = Vector3(0.0, 14.6, 15.4)
	box(Vector3(0.8, 0.4, 9.0), mat(Color(0.5, 0.05, 0.05), 0.4), Vector3(0.0, 0.0, -3.5), Vector3.ZERO, _second)

func _animate(_delta: float) -> void:
	if _flame == null:
		return
	# the flame breathing and leaning in the draft, never jumping
	# ALIVE (the user: "much more active"): it stretches and squats quickly, dances side to side, and every few
	# seconds a draft bends it hard over and lets it spring back; the halo and the light breathe with it
	var fl: float = 0.45 * sin(t * 9.3) + 0.30 * sin(t * 15.1 + 1.0) + 0.25 * sin(t * 4.7 + 2.0)
	var gust: float = pow(maxf(0.0, sin(t * 0.9) * sin(t * 0.37 + 1.0)), 3.0)
	var dance: float = 0.16 * sin(t * 5.3) + 0.08 * sin(t * 11.0 + 0.5)
	var stretch: float = 2.0 + 0.55 * fl - 0.5 * gust
	_flame.scale = Vector3(0.62 - 0.08 * fl, stretch, 0.62 - 0.08 * fl)
	_flame.position = Vector3(0.0, 8.5 * stretch, 0.0)      # its root stays at the wick as it stretches
	_flame_pivot.rotation = Vector3(0.10 * sin(t * 6.1), 0.0, dance + 0.7 * gust)
	_root_flame.scale = Vector3.ONE * (1.0 + 0.15 * fl)
	_halo.scale = Vector3.ONE * (1.0 + 0.16 * fl - 0.2 * gust)
	_flame_light.light_energy = 2.0 + 0.6 * fl - 0.8 * gust
	# the watch swinging, a slow pendulum, its swing very slowly dying and being renewed (a draft)
	var amp: float = 0.22 + 0.06 * sin(t * 0.21)
	_swing.rotation = Vector3(0.0, 0.0, amp * sin(t * TAU / 2.6))
	# and turning a little on its chain
	_swing.rotation.y = 0.25 * sin(t * 0.37)
	# the seconds hand, a tick each second with a small settle
	var s: float = floor(t)
	var ft: float = t - s
	var settle: float = 1.0 - pow(1.0 - clampf(ft / 0.12, 0.0, 1.0), 3.0)
	_second.rotation = Vector3(0.0, -(s + settle) * TAU / 60.0, 0.0)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Pickpocket", "Follow the ball and catch the pickpocket", Color(1.0, 0.86, 0.55), Color(0.10, 0.06, 0.12),
		Color(1.0, 0.65, 0.35, 0.22))

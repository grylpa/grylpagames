extends "res://scripts/menu_poster3d.gd"

# POLKA DOTS' OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): A RAILWAY
# STATION AT DUSK AND ITS FLIP-DOT BOARD (2026-11-18; the user liked the dressmaker's dotted dress but worried its
# femininity would put people off, and found its spools too simple). Under the iron-and-glass shed, hung from a lattice
# girder between cast-iron columns, a black steel cabinet holds a grid of round discs, yellow on one face and black on
# the other: every couple of seconds a wave runs across them, each disc turning over with a snap, and a new LETTER (or
# digit) stands in yellow dots with a few stray dots scattered round it -- dots that make a character, which is the
# game. Behind: the shed's glazed end against the dusk sky, a train standing at the platform with its windows lit,
# globe lamps, a station clock, a bench. The station is the baked picture (`menu_station.webp`, `menu_station_d.webp`);
# the discs that turn are live, one MultiMesh. Made up, never the board.

# the characters, as strokes in a box 1 wide and 1.4 tall (y down)
const GLYPHS: Dictionary = {
	"A": [[Vector2(0.0, 1.4), Vector2(0.5, 0.0), Vector2(1.0, 1.4)], [Vector2(0.22, 0.86), Vector2(0.78, 0.86)]],
	"K": [[Vector2(0.1, 0.0), Vector2(0.1, 1.4)], [Vector2(0.9, 0.0), Vector2(0.1, 0.82)], [Vector2(0.36, 0.6), Vector2(0.95, 1.4)]],
	"7": [[Vector2(0.05, 0.0), Vector2(0.95, 0.0), Vector2(0.38, 1.4)]],
	"4": [[Vector2(0.72, 1.4), Vector2(0.72, 0.0), Vector2(0.02, 0.95), Vector2(0.98, 0.95)]],
	"E": [[Vector2(0.9, 0.0), Vector2(0.1, 0.0), Vector2(0.1, 1.4), Vector2(0.9, 1.4)], [Vector2(0.1, 0.7), Vector2(0.72, 0.7)]],
	"R": [[Vector2(0.1, 1.4), Vector2(0.1, 0.0), Vector2(0.58, 0.0), Vector2(0.84, 0.1), Vector2(0.92, 0.35), Vector2(0.84, 0.6), Vector2(0.58, 0.7), Vector2(0.1, 0.7)], [Vector2(0.48, 0.7), Vector2(0.95, 1.4)]],
	"Z": [[Vector2(0.08, 0.0), Vector2(0.92, 0.0), Vector2(0.08, 1.4), Vector2(0.92, 1.4)]],
}
const ORDER: Array = ["A", "7", "K", "4", "R", "E", "Z"]
const CLOUD_S: float = 0.9               # a random cloud of polka dots, its wave crossing the board
const GLYPH_S: float = 1.8               # the character: a slower wave turns it in from the cloud, left to right
const CYCLE: float = CLOUD_S + GLYPH_S   # (no pauses at all, the user: each wave fills its phase, never a still board)
const CLOUD_FILL: float = 0.30
const COLS: int = 14
const ROWS: int = 18
const PITCH: float = 21.0
const DOT_R: float = 8.6
const PANEL_C: Vector3 = Vector3(0.0, 450.0, 0.0)  # the grid's center, on the cabinet's face
const GLOBE_Y: float = 720.0
const GLOBE_Z: float = 60.0
const OPAL: String = """
shader_type spatial;
render_mode unshaded;
varying float oy;
void vertex() {
	oy = VERTEX.y;
}
void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 rim = vec3(0.62, 0.34, 0.14);
	vec3 mid = vec3(1.0, 0.78, 0.50);
	vec3 core = vec3(1.0, 0.96, 0.86);
	vec3 c = mix(rim, mid, smoothstep(0.05, 0.65, f));
	c = mix(c, core, pow(f, 5.0));
	c *= 0.93 + 0.07 * sin(oy * 0.75);
	c *= 0.90 + 0.10 * smoothstep(-26.0, 10.0, oy);
	ALBEDO = c;
}
"""
const STRAYS: int = 0                    # no strays: the character shows clean (the user, 2026-11-18)

var _lit: Dictionary = {}                # character -> {cell index: true}
var _live_cells: Array = []              # the cells that ever turn
var _mm: MultiMesh = null

func _baked_path() -> String:
	return "res://polkadots/art/menu_station.webp" if mobile else "res://polkadots/art/menu_station_d.webp"

func _eye() -> Vector3:
	return Vector3(0.0, 330.0, 1050.0) if mobile else Vector3(0.0, 360.0, 1400.0)

func _aim() -> Vector3:
	return Vector3(0.0, 520.0, 0.0) if mobile else Vector3(0.0, 500.0, 0.0)

func _fov() -> float:
	return 50.0

func _frame_frac() -> float:
	return 0.48

func _environment(env: Environment) -> void:
	env.background_color = Color(0.05, 0.05, 0.08)
	env.ambient_light_color = Color(0.55, 0.58, 0.72)
	env.ambient_light_energy = 0.30

func _build_lights() -> void:
	# the globes' warm light on the board and the floor, the dusk through the glass, a lamp over the platform
	spot(Vector3(0.0, 980.0, 520.0), PANEL_C, Color(1.0, 0.90, 0.74), 2.4, 1400.0, 26.0, true)
	light(Vector3(-260.0, 740.0, 70.0), Color(1.0, 0.84, 0.62), 1.4, 700.0)
	light(Vector3(260.0, 740.0, 70.0), Color(1.0, 0.84, 0.62), 1.4, 700.0)
	light(Vector3(0.0, 900.0, -1300.0), Color(0.60, 0.66, 1.0), 2.0, 1600.0)
	light(Vector3(620.0, 420.0, -300.0), Color(1.0, 0.80, 0.55), 1.2, 700.0)
	light(Vector3(-500.0, 300.0, 500.0), Color(0.75, 0.80, 1.0), 0.6, 900.0)

# --- the characters on the grid ---------------------------------------------------------------------------------

func _setup() -> void:
	_raster()
	super._setup()

func _cell_pos(i: int) -> Vector3:
	var c: int = i % COLS
	var r: int = i / COLS
	return PANEL_C + Vector3((float(c) - float(COLS - 1) * 0.5) * PITCH, (float(ROWS - 1) * 0.5 - float(r)) * PITCH, 6.0)

func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var k: float = clampf((p - a).dot(ab) / maxf(0.0001, ab.length_squared()), 0.0, 1.0)
	return p.distance_to(a + ab * k)

# each character set into the grid: a cell is lit where its center lies on a stroke (the glyph 10 cells wide, 14 tall,
# two cells in from the top left) (no strays)
func _raster() -> void:
	var union: Dictionary = {}
	for gi in ORDER.size():
		var ch: String = ORDER[gi]
		var on: Dictionary = {}
		for i in COLS * ROWS:
			var g: Vector2 = Vector2((float(i % COLS) - 2.0) / 10.0, (float(i / COLS) - 2.0) / 10.0)
			var best: float = 9.0
			for stroke in GLYPHS[ch]:
				var pts: Array = stroke
				for k in pts.size() - 1:
					best = minf(best, _seg_dist(g, pts[k], pts[k + 1]))
			if best < 0.062:
				on[i] = true
		var placed: int = 0
		var seed_i: int = gi * 31
		while placed < STRAYS and seed_i < gi * 31 + 400:
			var cand: int = int(h01(seed_i) * float(COLS * ROWS)) % (COLS * ROWS)
			seed_i += 1
			var near_any: bool = false
			for dc in [-1, 0, 1]:
				for dr in [-COLS, 0, COLS]:
					if on.has(cand + int(dc) + int(dr)):
						near_any = true
			if not near_any:
				on[cand] = true
				placed += 1
		_lit[ch] = on
		for key in on.keys():
			union[key] = true
	# every disc turns now: the clouds between characters use the whole board
	_live_cells = range(COLS * ROWS)

var _disc_sh: Shader = null

# a disc: its +y face the bright yellow, its -y face matte black, its rim dark; the yellow a touch luminous, as the
# painted discs catch the light
func _disc_material() -> ShaderMaterial:
	if _disc_sh == null:
		_disc_sh = Shader.new()
		_disc_sh.code = """shader_type spatial;
render_mode cull_disabled;
varying float face;
varying vec2 local_xz;
void vertex() {
	face = NORMAL.y;
	local_xz = VERTEX.xz;
}
void fragment() {
	float yel = step(0.5, face);
	float blk = step(0.5, -face);
	float r = length(local_xz) / 8.6;
	vec3 y_col = mix(vec3(1.0, 0.84, 0.16), vec3(0.92, 0.66, 0.06), smoothstep(0.55, 1.0, r));
	vec3 b_col = vec3(0.035, 0.035, 0.04) + vec3(0.03) * smoothstep(0.80, 0.95, r);
	ALBEDO = mix(vec3(0.06, 0.06, 0.07), mix(b_col, y_col, yel), max(yel, blk));
	ROUGHNESS = mix(0.55, 0.38, yel);
	SPECULAR = 0.4;
	EMISSION = y_col * 0.30 * yel;
}"""
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _disc_sh
	return m

func _disc_mesh() -> CylinderMesh:
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = DOT_R
	disc.bottom_radius = DOT_R
	disc.height = 1.2
	disc.radial_segments = 24
	return disc

# a disc's place and its turn (0 yellow toward you, PI black), about its own horizontal axle
func _disc_xf(i: int, ang: float) -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, PI * 0.5 + ang), _cell_pos(i))

# --- the station: real 3-D, baked ---------------------------------------------------------------------------------

func _stone(n: int) -> ImageTexture:
	# big floor flags, two stones laid in a check, honed, with fine joints
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var half: int = n / 2
	for y in n:
		for x in n:
			var cell: int = (x / half + y / half) % 2
			var base: Color = Color(0.62, 0.60, 0.56) if cell == 0 else Color(0.40, 0.40, 0.42)
			var v: float = (h01(x * 7 + y * 131) - 0.5) * 0.06 + 0.04 * sin(float(x) * 0.21 + float(y) * 0.13)
			var c: Color = base.lightened(v) if v > 0.0 else base.darkened(-v)
			if x % half == 0 or y % half == 0:
				c = c.darkened(0.45)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _bricks(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	var bh: int = n / 8
	var bw: int = n / 4
	for y in n:
		var row: int = y / bh
		for x in n:
			var xo: int = (x + (bw / 2 if row % 2 == 1 else 0)) % n
			var brick: int = row * 7 + xo / bw
			var c: Color = Color(0.46, 0.22, 0.15).lerp(Color(0.56, 0.30, 0.20), h01(brick * 13)).darkened(0.12 * h01(x * 3 + y * 57))
			if y % bh < 2 or xo % bw < 2:
				c = Color(0.55, 0.52, 0.48).darkened(0.2)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _dusk(n: int) -> ImageTexture:
	var img: Image = Image.create(4, n, false, Image.FORMAT_RGB8)
	for y in n:
		var v: float = float(y) / float(n - 1)
		var c: Color = Color(0.16, 0.20, 0.42).lerp(Color(0.55, 0.42, 0.62), smoothstep(0.2, 0.75, v)).lerp(Color(1.0, 0.66, 0.40), smoothstep(0.72, 1.0, v))
		for x in 4:
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

# a barrel vault: the arch (from just above the springing to just below on the far side) swept along z, its UVs
# counting panes (one pane: 1 x 1), its normals facing down into the shed
func _vault(r: float, spring: float, rise: float, z0: float, z1: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var na: int = 32
	var nz: int = 40
	var across: float = 16.0
	var along: float = (z1 - z0) / 56.0
	for i in na:
		for j in nz:
			var q: Array = []
			for c in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var a: float = PI * (0.08 + 0.84 * float(c[0]) / float(na))
				var z: float = lerpf(z0, z1, float(c[1]) / float(nz))
				q.append([Vector3(-cos(a) * r, spring + sin(a) * rise, z), Vector2(float(c[0]) / float(na) * across, float(c[1]) / float(nz) * along), Vector3(cos(a), -sin(a), 0.0)])
			for vi in [0, 1, 2, 0, 2, 3]:
				st.set_normal(q[vi][2])
				st.set_uv(q[vi][1])
				st.add_vertex(q[vi][0])
	return st.commit()

func _vault_mat() -> StandardMaterial3D:
	# one pane, tiled: the dusk seen through old glass, a soft gradient top to bottom, a grimy rim, a dark putty edge,
	# soot streaks running down it
	var n: int = 64
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var sky: Color = Color(0.28, 0.28, 0.48).lerp(Color(0.52, 0.40, 0.52), float(y) / float(n))
			var ex: float = minf(minf(float(x), float(n - 1 - x)), minf(float(y), float(n - 1 - y))) / float(n)
			var c: Color = sky.darkened(0.35 * (1.0 - smoothstep(0.0, 0.18, ex)))
			if ex < 0.03:
				c = Color(0.08, 0.08, 0.09)
			# streaks of soot running down the glass
			c = c.darkened(0.10 * h01(x * 13) * (float(y) / float(n)))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

# a cast-iron column: a square plinth, a molded base, the shaft, a flared capital and its abacus
func _column(at: Vector3, iron: StandardMaterial3D, h: float) -> void:
	box(Vector3(56.0, 34.0, 56.0), iron, at + Vector3(0.0, 17.0, 0.0))
	cyl(22.0, 27.0, 20.0, iron, at + Vector3(0.0, 44.0, 0.0), Vector3.ZERO, null, 24)
	var torus_b: MeshInstance3D = sphere(21.0, iron, at + Vector3(0.0, 56.0, 0.0))
	torus_b.scale = Vector3(1.0, 0.35, 1.0)
	cyl(13.0, 16.0, h - 140.0, iron, at + Vector3(0.0, 60.0 + (h - 140.0) * 0.5, 0.0), Vector3.ZERO, null, 16)
	cyl(15.0, 15.0, 8.0, iron, at + Vector3(0.0, h - 76.0, 0.0), Vector3.ZERO, null, 20)
	cyl(36.0, 15.0, 52.0, iron, at + Vector3(0.0, h - 46.0, 0.0), Vector3.ZERO, null, 24)
	box(Vector3(80.0, 14.0, 80.0), iron, at + Vector3(0.0, h - 13.0, 0.0))

func _build_still() -> void:
	var iron: StandardMaterial3D = mat(Color(0.12, 0.22, 0.18), 0.45, 0.55)
	var black_steel: StandardMaterial3D = mat(Color(0.06, 0.06, 0.07), 0.35, 0.7)
	var brass: StandardMaterial3D = mat(Color(0.86, 0.66, 0.32), 0.3, 0.8)
	var oak: StandardMaterial3D = mat(Color.WHITE, 0.45, 0.0, tex_wood(128, Color(0.48, 0.30, 0.16), 5), Vector3(3, 1, 1))
	# THE FLOOR: honed stone flags in a check, faintly glossy
	box(Vector3(3200.0, 4.0, 3600.0), mat(Color.WHITE, 0.32, 0.0, _stone(256), Vector3(16, 18, 1)), Vector3(0.0, -2.0, -600.0))
	# THE SHED'S END: a brick wall with a great glazed lunette against the dusk, radial glazing bars
	var end_z: float = -2000.0
	box(Vector3(3200.0, 2400.0, 20.0), mat(Color.WHITE, 0.9, 0.0, _bricks(256), Vector3(14, 10, 1)), Vector3(0.0, 1200.0, end_z))
	var sky: StandardMaterial3D = mat(Color.WHITE, 1.0, 0.0, _dusk(128))
	sky.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var arch_r: float = 900.0
	var lun: CylinderMesh = CylinderMesh.new()
	lun.top_radius = arch_r
	lun.bottom_radius = arch_r
	lun.height = 4.0
	lun.radial_segments = 64
	put(lun, sky, Vector3(0.0, 300.0, end_z + 12.0), Vector3(90.0, 0.0, 0.0))
	box(Vector3(arch_r * 2.0, 300.0, 4.0), sky, Vector3(0.0, 150.0, end_z + 12.0))
	for spoke in 13:
		var a: float = PI * float(spoke) / 12.0
		var tip: Vector3 = Vector3(cos(a) * arch_r, 300.0 + sin(a) * arch_r, end_z + 18.0)
		var bar: MeshInstance3D = cyl(4.0, 4.0, arch_r, black_steel, (Vector3(0.0, 300.0, end_z + 18.0) + tip) * 0.5)
		bar.rotation = Vector3(0.0, 0.0, a - PI * 0.5)
	for ring_r in [arch_r * 0.35, arch_r * 0.68, arch_r]:
		var tr2: TorusMesh = TorusMesh.new()
		tr2.inner_radius = ring_r - 5.0
		tr2.outer_radius = ring_r + 5.0
		tr2.rings = 96
		put(tr2, black_steel, Vector3(0.0, 300.0, end_z + 18.0), Vector3(90.0, 0.0, 0.0))
	for hb in 4:
		box(Vector3(arch_r * 2.0, 6.0, 6.0), black_steel, Vector3(0.0, 40.0 + float(hb) * 85.0, end_z + 18.0))
	# THE COLUMNS down both sides and the SHED's arched iron ribs on them, purlins along, glass between
	var col_x: float = 470.0
	var col_h: float = 860.0
	for cz in [120.0, -500.0, -1120.0, -1740.0]:
		for sx in [-1.0, 1.0]:
			_column(Vector3(sx * col_x, 0.0, cz), iron, col_h)
		var rib: PackedVector3Array = PackedVector3Array()
		for rk in 25:
			var ra: float = PI * float(rk) / 24.0
			rib.append(Vector3(-cos(ra) * col_x, col_h + sin(ra) * 360.0, cz))
		put(tube_mesh(rib, 9.0, 10), iron, Vector3.ZERO)
		# the spandrel's ironwork: rings between the rib and the tie
		for sp in [-1.0, 1.0]:
			var rr: TorusMesh = TorusMesh.new()
			rr.inner_radius = 40.0
			rr.outer_radius = 46.0
			put(rr, iron, Vector3(sp * 330.0, col_h + 70.0, cz), Vector3(90.0, 0.0, 0.0))
		box(Vector3(col_x * 2.0, 10.0, 10.0), iron, Vector3(0.0, col_h, cz))
	for pk in 9:
		var pa: float = PI * (0.1 + 0.8 * float(pk) / 8.0)
		box(Vector3(8.0, 8.0, 2000.0), iron, Vector3(-cos(pa) * col_x, col_h + sin(pa) * 360.0, -820.0))
	# THE GLASS: a barrel vault of panes over the ribs -- each pane its own shade of the twilight seen through it,
	# soot gathered toward its edges, the putty lines dark -- with IRON GLAZING BARS following the arch every pane's
	# width, and a louvered LANTERN along the ridge (the glass was one blue shell, the user: "improve the canopy")
	put(_vault(col_x, col_h, 360.0, -1950.0, 260.0), _vault_mat(), Vector3.ZERO)
	var z_bar: float = -1950.0
	while z_bar <= 260.0:
		var bar: PackedVector3Array = PackedVector3Array()
		for bk in 21:
			var ba: float = PI * (0.08 + 0.84 * float(bk) / 20.0)
			bar.append(Vector3(-cos(ba) * (col_x - 3.0), col_h + sin(ba) * 357.0, z_bar))
		put(tube_mesh(bar, 2.2, 5), iron, Vector3.ZERO)
		z_bar += 56.0
	box(Vector3(120.0, 12.0, 2210.0), iron, Vector3(0.0, col_h + 372.0, -845.0))
	for lv in 2:
		var lside: float = -1.0 if lv == 0 else 1.0
		box(Vector3(4.0, 46.0, 2210.0), mat(Color(0.20, 0.22, 0.26), 0.5, 0.4), Vector3(lside * 56.0, col_h + 396.0, -845.0))
	put(_vault(70.0, col_h + 410.0, 30.0, -1950.0, 260.0), iron, Vector3.ZERO)
	# THE GIRDER the board hangs from: a lattice beam between the front columns
	var gy: float = 820.0
	box(Vector3(col_x * 2.0, 10.0, 18.0), iron, Vector3(0.0, gy + 30.0, 0.0))
	box(Vector3(col_x * 2.0, 10.0, 18.0), iron, Vector3(0.0, gy - 30.0, 0.0))
	for lk in 18:
		var lx: float = -col_x + 26.0 + float(lk) * (col_x * 2.0 - 52.0) / 17.0
		var dia: MeshInstance3D = box(Vector3(5.0, 72.0, 5.0), iron, Vector3(lx, gy, 0.0))
		dia.rotation = Vector3(0.0, 0.0, 0.6 if lk % 2 == 0 else -0.6)
	# THE BOARD: a black steel cabinet with a rolled bevel, riveted round its face, a header strip with DEPARTURES in
	# cream enamel, the grid recessed in it, every disc set in its own shallow socket; hung on two rods with turnbuckles
	var hx: float = float(COLS) * PITCH * 0.5 + 26.0
	var dots_h: float = float(ROWS) * PITCH
	var cab_h: float = dots_h + 26.0 * 2.0 + 52.0
	var cab_cy: float = PANEL_C.y + 26.0
	put(rbox_mesh(hx, cab_h * 0.5, 34.0, 12.0, 5.0), black_steel, Vector3(0.0, cab_cy, -34.0), Vector3(90.0, 0.0, 0.0))
	box(Vector3(float(COLS) * PITCH + 8.0, dots_h + 8.0, 2.0), mat(Color(0.02, 0.02, 0.025), 0.9), Vector3(PANEL_C.x, PANEL_C.y, 0.5))
	var rv_m: StandardMaterial3D = mat(Color(0.20, 0.20, 0.22), 0.3, 0.8)
	var top_y: float = cab_cy + cab_h * 0.5
	var bot_y: float = cab_cy - cab_h * 0.5
	for rv in 13:
		var rx: float = -hx + 12.0 + float(rv) * (hx * 2.0 - 24.0) / 12.0
		sphere(2.6, rv_m, Vector3(rx, top_y - 9.0, 1.0))
		sphere(2.6, rv_m, Vector3(rx, bot_y + 9.0, 1.0))
	for rv2 in 17:
		var ry: float = bot_y + 12.0 + float(rv2) * (cab_h - 24.0) / 16.0
		sphere(2.6, rv_m, Vector3(-hx + 9.0, ry, 1.0))
		sphere(2.6, rv_m, Vector3(hx - 9.0, ry, 1.0))
	var head_y: float = PANEL_C.y + dots_h * 0.5 + 34.0
	box(Vector3(hx * 2.0 - 40.0, 34.0, 2.0), mat(Color(0.08, 0.14, 0.24), 0.35, 0.2), Vector3(0.0, head_y, 1.0))
	var word: Label3D = label("DEPARTURES", 24.0, Color(0.96, 0.92, 0.80), Vector3(0.0, head_y, 2.6))
	word.outline_size = 0
	var sockets: MultiMesh = MultiMesh.new()
	sockets.transform_format = MultiMesh.TRANSFORM_3D
	var sock: CylinderMesh = CylinderMesh.new()
	sock.top_radius = DOT_R + 1.4
	sock.bottom_radius = DOT_R + 1.4
	sock.height = 1.0
	sock.radial_segments = 20
	sockets.mesh = sock
	sockets.instance_count = COLS * ROWS
	for si in COLS * ROWS:
		sockets.set_instance_transform(si, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), _cell_pos(si) - Vector3(0.0, 0.0, 4.0)))
	var smi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	smi.multimesh = sockets
	smi.material_override = mat(Color(0.10, 0.10, 0.11), 0.6, 0.4)
	root.add_child(smi)
	# every disc, black side out (those that turn stand again in the live view)
	var still: MultiMesh = MultiMesh.new()
	still.transform_format = MultiMesh.TRANSFORM_3D
	still.mesh = _disc_mesh()
	still.instance_count = COLS * ROWS
	for di in COLS * ROWS:
		still.set_instance_transform(di, _disc_xf(di, PI))
	var dmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	dmi.multimesh = still
	dmi.material_override = _disc_material()
	root.add_child(dmi)
	for hr in [-hx + 40.0, hx - 40.0]:
		cyl(2.6, 2.6, gy - 30.0 - top_y, black_steel, Vector3(hr, (gy - 30.0 + top_y) * 0.5, -17.0), Vector3.ZERO, null, 8)
		cyl(4.2, 4.2, 22.0, brass, Vector3(hr, top_y + (gy - 30.0 - top_y) * 0.45, -17.0), Vector3.ZERO, null, 10)
		box(Vector3(14.0, 10.0, 14.0), black_steel, Vector3(hr, top_y + 4.0, -17.0))
	# GLOBE LAMPS hung from the girder either side: OPAL GLASS lit from within -- a hot core where the lamp shows
	# through, warm cream round it, deepening to amber at the rim where the glass is seen edge-on, faint molded ribs --
	# under a brass fitter and gallery, a small brass finial below (they were flat white discs: the user, 2026-11-19)
	var opal: ShaderMaterial = ShaderMaterial.new()
	opal.shader = Shader.new()
	opal.shader.code = OPAL
	for gl in [-260.0, 260.0]:
		var lc: Vector3 = Vector3(gl, GLOBE_Y, GLOBE_Z)
		cyl(1.6, 1.6, gy - 30.0 - lc.y - 34.0, brass, Vector3(gl, (gy - 30.0 + lc.y + 34.0) * 0.5, 30.0), Vector3(-8.0, 0.0, 0.0), null, 6)
		var gm: MeshInstance3D = sphere(26.0, opal, lc)
		gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cyl(9.0, 13.0, 7.0, brass, lc + Vector3(0.0, 25.0, 0.0), Vector3.ZERO, null, 16)
		cyl(5.0, 8.0, 8.0, brass, lc + Vector3(0.0, 32.0, 0.0), Vector3.ZERO, null, 16)
		var gal: TorusMesh = TorusMesh.new()
		gal.inner_radius = 12.5
		gal.outer_radius = 15.0
		put(gal, brass, lc + Vector3(0.0, 22.0, 0.0))
		sphere(3.4, brass, lc + Vector3(0.0, -27.0, 0.0))
		cyl(0.4, 2.0, 6.0, brass, lc + Vector3(0.0, -32.0, 0.0), Vector3.ZERO, null, 8)
	# THE STATION CLOCK on a bracket from the right column: two faces back to back, a brass case, the hands at ten to
	var ck: Vector3 = Vector3(col_x - 110.0, 600.0, 120.0)
	box(Vector3(90.0, 8.0, 8.0), iron, Vector3(col_x - 50.0, 660.0, 120.0))
	cyl(2.0, 2.0, 30.0, iron, ck + Vector3(0.0, 46.0, 0.0), Vector3.ZERO, null, 6)
	cyl(44.0, 44.0, 20.0, brass, ck, Vector3(90.0, 0.0, 0.0), null, 40)
	cyl(39.0, 39.0, 21.0, mat(Color(0.96, 0.94, 0.88), 0.5), ck, Vector3(90.0, 0.0, 0.0), null, 40)
	for tk in 12:
		var ta: float = TAU * float(tk) / 12.0
		var tick: MeshInstance3D = box(Vector3(2.4, 7.0 if tk % 3 == 0 else 4.5, 1.0), black_steel, ck + Vector3(sin(ta) * 33.0, cos(ta) * 33.0, 11.0))
		tick.rotation = Vector3(0.0, 0.0, -ta)
	var hand_h: MeshInstance3D = box(Vector3(3.4, 22.0, 1.0), black_steel, ck + Vector3(0.0, 0.0, 12.0) + Vector3(sin(-0.52), cos(-0.52), 0.0) * 10.0)
	hand_h.rotation = Vector3(0.0, 0.0, 0.52)
	var hand_m: MeshInstance3D = box(Vector3(2.4, 32.0, 1.0), black_steel, ck + Vector3(0.0, 0.0, 12.6) + Vector3(sin(-1.05), cos(-1.05), 0.0) * 15.0)
	hand_m.rotation = Vector3(0.0, 0.0, 1.05)
	sphere(3.0, brass, ck + Vector3(0.0, 0.0, 13.0))
	# THE PLATFORM at the right: its stone edge with the yellow line, and A TRAIN standing at it, windows lit
	var plat_x: float = 600.0
	box(Vector3(40.0, 40.0, 2600.0), mat(Color(0.58, 0.56, 0.52), 0.6), Vector3(plat_x, -20.0 + 22.0, -800.0))
	box(Vector3(10.0, 1.0, 2600.0), mat(Color(0.95, 0.80, 0.20), 0.6), Vector3(plat_x - 6.0, 3.0, -800.0))
	var paint: StandardMaterial3D = mat(Color(0.10, 0.26, 0.20), 0.3, 0.3)
	paint.clearcoat_enabled = true
	var tx: float = plat_x + 120.0
	for car in 2:
		var cz0: float = -260.0 - float(car) * 760.0
		box(Vector3(160.0, 190.0, 720.0), paint, Vector3(tx, 150.0, cz0 - 360.0))
		var roof: MeshInstance3D = cyl(86.0, 86.0, 720.0, mat(Color(0.22, 0.22, 0.24), 0.6, 0.3), Vector3(tx, 240.0, cz0 - 360.0), Vector3(90.0, 0.0, 0.0), null, 24)
		roof.scale = Vector3(1.0, 1.0, 0.36)
		box(Vector3(2.0, 8.0, 720.0), brass, Vector3(tx - 81.0, 108.0, cz0 - 360.0))
		for w in 9:
			var wz: float = cz0 - 40.0 - float(w) * 76.0
			box(Vector3(2.0, 58.0, 50.0), glow(Color(1.0, 0.84, 0.56)), Vector3(tx - 81.0, 180.0, wz))
			box(Vector3(3.0, 64.0, 4.0), paint, Vector3(tx - 81.5, 180.0, wz + 27.0))
		for bg in 2:
			box(Vector3(140.0, 40.0, 140.0), black_steel, Vector3(tx, 38.0, cz0 - 110.0 - float(bg) * 500.0))
	# A BENCH under the board's left: oak slats on cast-iron ends
	var bc: Vector3 = Vector3(-300.0, 0.0, 240.0)
	for se in [-1.0, 1.0]:
		var end_p: PackedVector3Array = PackedVector3Array([bc + Vector3(se * 90.0, 0.0, 22.0), bc + Vector3(se * 90.0, 46.0, 18.0), bc + Vector3(se * 90.0, 50.0, -16.0), bc + Vector3(se * 90.0, 104.0, -30.0)])
		put(tube_mesh(end_p, 3.6, 8), iron, Vector3.ZERO)
		box(Vector3(5.0, 4.0, 40.0), iron, bc + Vector3(se * 90.0, 2.0, 0.0))
	for sl in 4:
		box(Vector3(200.0, 3.0, 8.0), oak, bc + Vector3(0.0, 48.0, 16.0 - float(sl) * 10.0))
	for bs in 3:
		var back: MeshInstance3D = box(Vector3(200.0, 8.0, 3.0), oak, bc + Vector3(0.0, 66.0 + float(bs) * 13.0, -20.0 - float(bs) * 3.0))
		back.rotation = Vector3(-0.25, 0.0, 0.0)

# --- live: the discs that turn ----------------------------------------------------------------------------------

func _build_live() -> void:
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = _disc_mesh()
	_mm.instance_count = _live_cells.size()
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.material_override = _disc_material()
	root.add_child(mmi)
	_animate(0.0)

# what the board shows in phase p: even phases a CLOUD of polka dots scattered at random (a new one each time), odd
# phases the next CHARACTER, clean
func _state(p: int) -> Dictionary:
	if posmod(p, 2) == 0:
		var cloud: Dictionary = {}
		var m: int = p / 2
		for i in COLS * ROWS:
			if h01(i * 7 + m * 131 + 11) < CLOUD_FILL:
				cloud[i] = true
		return cloud
	return _lit[ORDER[posmod((p - 1) / 2, ORDER.size())]]

func _animate(_delta: float) -> void:
	if _mm == null:
		return
	var c: int = int(floor(t / CYCLE))
	var u: float = fmod(t, CYCLE)
	var phase: int = c * 2 if u < CLOUD_S else c * 2 + 1
	var local: float = u if u < CLOUD_S else u - CLOUD_S
	var now: Dictionary = _state(phase)
	var was: Dictionary = _state(phase - 1)
	for k in _live_cells.size():
		var i: int = _live_cells[k]
		var a0: float = 0.0 if was.has(i) else PI
		var a1: float = 0.0 if now.has(i) else PI
		var ang: float = a1
		# THE WAVE: left to right, a touch down the rows, each disc turning over in a fifth of a second and snapping
		# home with a small overshoot, as the magnet catches it. NEVER STILL (the user, 2026-11-19: "no pauses. at
		# all"): each wave is spread over its whole phase, so the next sets off from the left as this one reaches the
		# right; and the magnets' pulse ROCKS the discs it does not turn, a small nod as the front passes, so the sweep
		# shows even across a stretch where little changes
		var span: float = (CLOUD_S if posmod(phase, 2) == 0 else GLYPH_S) - 0.20
		var delay: float = span * (0.028 * float(i % COLS) + 0.008 * float(i / COLS) + 0.02 * h01(i + 5)) / 0.52
		var f: float = clampf((local - delay) / 0.20, 0.0, 1.0)
		if a0 != a1:
			var c1: float = 2.2
			var e: float = 1.0 + (c1 + 1.0) * pow(f - 1.0, 3.0) + c1 * pow(f - 1.0, 2.0)
			ang = lerpf(a0, a1, e)
		else:
			ang = a1 + 0.30 * sin(PI * f) * (1.0 - f)
		_mm.set_instance_transform(k, _disc_xf(i, ang))

func _paint_top(_full: Vector2, _bottom: float) -> void:
	# the globes' glow in the air round them
	if _cam3 != null:
		for gl in [-260.0, 260.0]:
			var gc: Vector2 = screen_of(Vector3(gl, GLOBE_Y, GLOBE_Z))
			var pu: float = screen_of(Vector3(gl + 100.0, GLOBE_Y, GLOBE_Z)).distance_to(gc) / 100.0
			glow_at(gc, 90.0 * pu, Color(1.0, 0.74, 0.42, 0.10), 10)
			glow_at(gc, 40.0 * pu, Color(1.0, 0.86, 0.62, 0.16), 6)
	title("Polka Dots", "Identify the scatter of dots", Color(1.0, 0.86, 0.30), Color(0.06, 0.06, 0.10),
		Color(1.0, 0.80, 0.30, 0.22))

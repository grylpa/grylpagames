extends "res://scripts/menu_poster3d.gd"

# ALIENS' OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): THE SPACEPORT AT
# NIGHT, AT WORK -- the game acted out (2026-11-18; the user: "one of the most important games, so try to make this
# much more engaging ... the action area takes a very small area of the screen ... i also dont think that gate thing
# works"). A big SAUCER hangs over a landing deck of hex plates with glowing seams and lets its passengers down its
# beam -- the game's own aliens (alien.gd), each different -- onto the ARRIVALS PAD; each then hops across the deck to
# the BOARDING PAD whose pass it fits -- a hologram over each pad shows its rule, "BLUE" at the left, "3 EYES" at the
# right -- and is lifted aboard in a column of light; one that fits neither wanders off into the field. Round the deck
# the alien plain: rock arches and mesas, and in 2-D behind it the sky with the ringed planet
# and the moons. The world is baked with a CLEAR sky (`_bake_alpha`: `menu_port.webp`, `menu_port_d.webp`); the saucer,
# its beam, the boarding columns, the holograms and the aliens are live. Made up, never the board.

const ALIEN = preload("res://aliens/scripts/alien.gd")
const SHIP: Vector3 = Vector3(0.0, 430.0, -200.0)
const EMIT_R: float = 46.0                                  # the emitter lens under the saucer = the beam's top
const PAD: Vector3 = Vector3(0.0, 6.0, -120.0)            # the arrivals pad under the beam
const GATES: Array = [Vector3(-250.0, 6.0, 150.0), Vector3(250.0, 6.0, 150.0)]   # the boarding pads: BLUE, 3 EYES
const PERIOD: float = 7.0
# THE SHUTTLES (the user, 2026-11-19: the matching aliens rose up their columns into empty sky -- boarding WHAT?): over
# each gate a departure shuttle in the gate's color hovers; its column of light runs up into its hatch, a boarding
# alien rises into it and the hatch closes; once a cycle, after the gate's last boarding, it lifts off and a fresh one
# comes down into its place
const HOVER_Y: float = 265.0               # the shuttles' hull center: low, under the saucer's line (at 400 they rivaled it -- the user)
const HATCH_DROP: float = 26.0             # the hatch, under the hull's center
const HATCH_R: float = 20.0
const SHUTTLE_SCALE: float = 1.15
const DEPART_S: float = 1.0                # lifting off and away
const ARRIVE_S: float = 1.3                # the fresh one coming down
const LIFT: float = 700.0                  # how far above the hover they go
const RIDERS: int = 5
# each rider's traits [eyes, color, fat, antennae, spots] -- and so where it goes: 0 BLUE, 1 3 EYES, -1 neither
const TRAITS: Array = [[2, 0, false, 1, false], [3, 1, true, 2, false], [1, 2, false, 0, true], [3, 4, false, 1, true], [2, 3, true, 2, false]]

var _layer: Node2D = null
var _riders: Array = []
var _holo: Control = null
var _saucer: Node3D = null
var _rim: Array = []
var _columns: Array = []                 # the boarding pads' columns of light (materials)
var _shuttles: Array = []                # per gate: [Node3D, hatch lens material, iris door node]
var _glass_shader: Shader = null

func _dest(k: int) -> int:
	var trt: Array = TRAITS[k % TRAITS.size()]
	if int(trt[1]) == 0:
		return 0
	if int(trt[0]) == 3:
		return 1
	return -1

func _baked_path() -> String:
	return "res://aliens/art/menu_port.webp" if mobile else "res://aliens/art/menu_port_d.webp"

func _bake_alpha() -> bool:
	return true

func _eye() -> Vector3:
	return Vector3(0.0, 330.0, 780.0) if mobile else Vector3(0.0, 380.0, 1100.0)

func _aim() -> Vector3:
	return Vector3(0.0, 170.0, -60.0) if mobile else Vector3(0.0, 180.0, -60.0)

func _fov() -> float:
	return 58.0

func _frame_frac() -> float:
	return 0.46 if mobile else 0.50

func _environment(env: Environment) -> void:
	env.background_color = Color(0.04, 0.05, 0.10)
	env.ambient_light_color = Color(0.45, 0.60, 0.75)
	env.ambient_light_energy = 0.42

# THE SKY IN THREE LAYERS UNDER THE SCENE (2026-11-19: painted every frame, 170 stars with their glows and flares and
# a ringed planet cost a phone ~15 ms): the gradient drawn once, the stars one batched draw twinkling on the GPU
# (STARS), the planet and the moons drawn once
var _sky_grad: Control = null
var _stars: MultiMeshInstance2D = null
var _planet: Control = null
var _sky_for: String = ""

# each star a quad; INSTANCE_CUSTOM = (rate, phase, phase 2, the quad's half-size), COLOR = (hue, its radius / 4).
# Its twinkle tw, its disc (radius r(0.8 + 0.4 tw), alpha 0.25 + 0.7 tw), and for a big one (r > 1) the glow of four
# rings (glow_at: radius 6r, each 0.072 tw) and the two flare lines (half-length r(4 + 10 tw^3), 1 wide, 0.55 tw^3),
# as _paint drew them -- all one color, so together they are 1 - (1 - a1)(1 - a2)(1 - a3)
const STARS: String = """shader_type canvas_item;
uniform float t = 0.0;
varying float v_tw;
varying float v_r;
varying vec2 v_p;
void vertex() {
	v_tw = 0.5 + 0.5 * sin(t * INSTANCE_CUSTOM.x + INSTANCE_CUSTOM.y) * sin(t * INSTANCE_CUSTOM.x * 0.37 + INSTANCE_CUSTOM.z);
	v_r = COLOR.a * 4.0;
	COLOR.a = 1.0;
	v_p = VERTEX * INSTANCE_CUSTOM.w;
}
void fragment() {
	vec2 p = v_p;
	float aa = max(fwidth(p.x), 1e-4);
	float d = length(p);
	float tw = v_tw;
	float r = v_r;
	float a_core = (0.25 + 0.70 * tw) * clamp((r * (0.8 + 0.4 * tw) - d) / aa + 0.5, 0.0, 1.0);
	float keep = 1.0 - a_core;
	if (r > 1.0) {
		float gr = r * 6.0;
		float n = clamp(ceil(4.0 * (1.0 - d / gr)), 0.0, 4.0);
		keep *= pow(1.0 - 0.072 * tw, n);
		float flare = tw * tw * tw;
		float arm = r * (4.0 + 10.0 * flare);
		for (int g = 0; g < 2; g++) {
			float ang = 1.5707963 * float(g) + 0.12;
			vec2 dv = vec2(cos(ang), sin(ang));
			float along = abs(dot(p, dv));
			float across = abs(dot(p, vec2(-dv.y, dv.x)));
			float cov = clamp((0.5 - across) / aa + 0.5, 0.0, 1.0) * clamp((arm - along) / aa + 0.5, 0.0, 1.0);
			keep *= 1.0 - 0.55 * flare * cov;
		}
	}
	COLOR.a = 1.0 - keep;
}
"""

func _setup() -> void:
	super._setup()
	if bake_mode:
		return
	_sky_grad = cached_layer(func(d: Control) -> void:
		var keep: CanvasItem = cv
		cv = d
		vgrad(Rect2(Vector2.ZERO, Vector2(MainGlobals.full_screen_size)), Color(0.05, 0.03, 0.12), Color(0.06, 0.16, 0.20))
		cv = keep)
	_stars = MultiMeshInstance2D.new()
	var sm: ShaderMaterial = ShaderMaterial.new()
	var ssh: Shader = Shader.new()
	ssh.code = STARS
	sm.shader = ssh
	_stars.material = sm
	add_child(_stars)
	_planet = cached_layer(func(d: Control) -> void: _draw_planet(d))
	move_child(_sky_grad, 0)
	move_child(_stars, 1)
	move_child(_planet, 2)
	_holo = Control.new()
	_holo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holo.draw.connect(func() -> void: _draw_holo(_holo))
	add_child(_holo)
	_layer = Node2D.new()
	add_child(_layer)
	for k in RIDERS:
		var a: Node2D = ALIEN.new()
		_layer.add_child(a)
		var trt: Array = TRAITS[k]
		a.call("setup", 30.0, int(trt[0]), int(trt[1]), bool(trt[2]), int(trt[3]), bool(trt[4]))
		_riders.append(a)
	if _top != null:
		move_child(_top, get_child_count() - 1)

func _build_lights() -> void:
	# the planet's pink light from the left, a cool teal from the right, the pads' glows
	var p: DirectionalLight3D = DirectionalLight3D.new()
	p.light_color = Color(1.0, 0.72, 0.88)
	p.light_energy = 0.75
	root.add_child(p)
	p.rotation_degrees = Vector3(-30.0, -55.0, 0.0)
	var q: DirectionalLight3D = DirectionalLight3D.new()
	q.light_color = Color(0.55, 0.95, 0.95)
	q.light_energy = 0.45
	root.add_child(q)
	q.rotation_degrees = Vector3(-40.0, 60.0, 0.0)
	light(PAD + Vector3(0.0, 40.0, 0.0), Color(0.70, 1.0, 1.0), 1.4, 300.0)
	light(GATES[0] + Vector3(0.0, 40.0, 0.0), Color(0.45, 0.65, 1.0), 1.1, 240.0)
	light(GATES[1] + Vector3(0.0, 40.0, 0.0), Color(1.0, 0.55, 0.85), 1.1, 240.0)
	light(SHIP + Vector3(0.0, -60.0, 0.0), Color(0.80, 1.0, 0.95), 1.2, 600.0)

# --- textures ---------------------------------------------------------------------------------------------------

# THE DECK: hexagonal plates of dark alloy, each its own tone, worn, the seams between them a glowing cyan. The tile
# holds EXACTLY 4 hexes across and 4 rows down (a hex row repeats every sqrt(3) units across, every 3 units down two
# rows): the grid was laid at n/4 pixels a unit in a square, which does not divide either, and every repeat of the
# texture broke the hexes along a line (the user, 2026-11-19: "a vertical line breaking it")
const HEX_A: int = 4                      # hexes across the tile
const HEX_B: int = 2                      # pairs of rows down it
func _hex_tex(n: int, glow_seams: bool) -> ImageTexture:
	var w: int = n
	var h: int = int(round(float(n) * 3.0 * float(HEX_B) / (sqrt(3.0) * float(HEX_A))))
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var p: Vector2 = Vector2(float(x) / float(w) * sqrt(3.0) * float(HEX_A), float(y) / float(h) * 3.0 * float(HEX_B))
			# axial hex coordinates of the cell
			var q: float = (sqrt(3.0) / 3.0 * p.x - 1.0 / 3.0 * p.y)
			var r: float = 2.0 / 3.0 * p.y
			var cx: float = q
			var cz: float = r
			var cy: float = -cx - cz
			var rx: float = round(cx)
			var ry: float = round(cy)
			var rz: float = round(cz)
			var dx: float = absf(rx - cx)
			var dy: float = absf(ry - cy)
			var dz: float = absf(rz - cz)
			if dx > dy and dx > dz:
				rx = -ry - rz
			elif dy > dz:
				ry = -rx - rz
			else:
				rz = -rx - ry
			# the distance to the cell's own edge: from its center in pixel space, by the hexagon's own shape
			var pc: Vector2 = Vector2(sqrt(3.0) * rx + sqrt(3.0) * 0.5 * rz, 1.5 * rz)
			var v: Vector2 = Vector2(absf(p.x - pc.x), absf(p.y - pc.y))
			var edge: float = maxf(v.x, v.x * 0.5 + v.y * 0.866)
			var seam: float = smoothstep(0.78, 0.84, edge)
			# (each plate's tone from its place WITHIN the tile, so the tone repeats with it too)
			var row: int = int(rz)
			var col: int = int(rx) + (row - posmod(row, 2)) / 2
			var tone: float = h01(posmod(col, HEX_A) * 31 + posmod(row, 2 * HEX_B) * 17 + 400)
			var c: Color
			if glow_seams:
				c = Color(0.0, 0.0, 0.0).lerp(Color(0.30, 0.95, 1.0), seam)
			else:
				c = Color(0.16, 0.18, 0.24).lerp(Color(0.22, 0.25, 0.32), tone).darkened(0.08 * h01(x * 7 + y * 13))
				c = c.lerp(Color(0.06, 0.08, 0.10), seam)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _rock_tex(n: int, base: Color) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var strata: float = 0.5 + 0.5 * sin(float(y) * 0.32 + sin(float(x) * 0.07) * 2.2)
			img.set_pixel(x, y, base.darkened(0.30 * strata + 0.15 * h01(x * 13 + y * 7)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# a butte's banded rock: soft layers of rose and violet, weathered
func _strata(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var band: float = 0.5 + 0.5 * sin(float(y) * 0.18 + sin(float(x) * 0.05) * 1.4)
			var c: Color = Color(0.30, 0.22, 0.34).lerp(Color(0.42, 0.28, 0.38), band * 0.6)
			img.set_pixel(x, y, c.darkened(0.12 * h01(x * 13 + y * 7)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _build_still() -> void:
	var ground: StandardMaterial3D = mat(Color.WHITE, 0.9, 0.0, _rock_tex(128, Color(0.20, 0.17, 0.28)), Vector3(28, 28, 1))
	var rock: StandardMaterial3D = mat(Color.WHITE, 0.9, 0.0, _rock_tex(64, Color(0.34, 0.26, 0.40)), Vector3(2, 3, 1))
	var metal: StandardMaterial3D = mat(Color(0.55, 0.60, 0.68), 0.35, 0.7)
	box(Vector3(9000.0, 4.0, 7000.0), ground, Vector3(0.0, -2.0, -2000.0))
	# THE DECK: a broad platform of hex plates, its seams glowing, a raised rim with a light strip
	var deck: StandardMaterial3D = mat(Color.WHITE, 0.55, 0.4, _hex_tex(256, false), Vector3(5.0, 5.0 * sqrt(3.0) * float(HEX_A) / (3.0 * float(HEX_B)), 1.0))   # (the tile is wider than tall: repeated more down, so the hexes stay regular)
	deck.emission_enabled = true
	deck.emission_texture = _hex_tex(256, true)
	deck.emission = Color(1, 1, 1)
	deck.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY     # (ADD, the default, lit every plate white)
	deck.emission_energy_multiplier = 1.2
	cyl(470.0, 480.0, 6.0, deck, Vector3(0.0, 1.0, 0.0), Vector3.ZERO, null, 64)
	var rim: TorusMesh = TorusMesh.new()
	rim.inner_radius = 466.0
	rim.outer_radius = 482.0
	rim.rings = 96
	put(rim, metal, Vector3(0.0, 3.0, 0.0))
	var strip: TorusMesh = TorusMesh.new()
	strip.inner_radius = 474.0
	strip.outer_radius = 477.0
	strip.rings = 96
	put(strip, glow(Color(0.55, 1.0, 1.0)), Vector3(0.0, 9.0, 0.0))
	# THE PADS: the arrivals pad under the beam (cyan) and the two boarding pads (blue, pink), each a raised disc with
	# a lit ring and chevrons pointing in
	_pad(PAD, 110.0, Color(0.65, 1.0, 1.0), metal)
	_pad(GATES[0], 78.0, Color(0.45, 0.65, 1.0), metal)
	_pad(GATES[1], 78.0, Color(1.0, 0.50, 0.85), metal)
	# guide lights across the deck from the arrivals pad to each boarding pad
	for g in 2:
		var gp: Vector3 = GATES[g]
		for k in 6:
			var f: float = (float(k) + 1.0) / 7.0
			var lp: Vector3 = PAD.lerp(gp, f)
			cyl(5.0, 5.0, 1.0, glow([Color(0.45, 0.65, 1.0), Color(1.0, 0.50, 0.85)][g]), lp + Vector3(0.0, 4.6, 0.0), Vector3.ZERO, null, 12)
	# THE PLAIN round it: boulders, rock arches and mesas far off (the crystal clusters read as paper flowers and the
	# beacon masts as gray poles -- the user; both gone)
	for bd in 12:
		var bp: Vector3 = Vector3((h01(bd + 1) - 0.5) * 2600.0, 0.0, -560.0 - h01(bd + 2) * 1600.0)
		var bm: MeshInstance3D = sphere(30.0 + 50.0 * h01(bd + 3), rock, bp)
		bm.scale = Vector3(1.4, 0.7, 1.1)
	# an ARCH of rock, and MESAS: flat-topped buttes in layers
	var arch: PackedVector3Array = PackedVector3Array()
	for k2 in 17:
		var u: float = float(k2) / 16.0
		arch.append(Vector3(-900.0 + u * 520.0, sin(u * PI) * 380.0, -1800.0))
	put(tube_mesh(arch, 46.0, 12), rock, Vector3.ZERO)
	var mesa: StandardMaterial3D = mat(Color.WHITE, 0.95, 0.0, _strata(128), Vector3(3, 1, 1))
	for ms in 7:
		var mx: float = -2600.0 + float(ms) * 860.0 + 200.0 * h01(ms + 30)
		var mh: float = 130.0 + 140.0 * h01(ms + 31)
		var mz: float = -2600.0 - 500.0 * h01(ms + 32)
		var butte: MeshInstance3D = cyl(320.0 + 160.0 * h01(ms + 33), 460.0 + 200.0 * h01(ms + 34), mh, mesa, Vector3(mx, mh * 0.5, mz), Vector3.ZERO, null, 24)
		butte.rotation.y = h01(ms + 35) * TAU
		var talus: MeshInstance3D = sphere(300.0 + 100.0 * h01(ms + 36), mesa, Vector3(mx, -120.0, mz + 60.0))
		talus.scale = Vector3(1.4, 0.55, 1.0)

func _pad(c: Vector3, r: float, col: Color, metal: StandardMaterial3D) -> void:
	cyl(r, r + 10.0, 10.0, metal, c + Vector3(0.0, 0.0, 0.0), Vector3.ZERO, null, 48)
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = r - 10.0
	ring.outer_radius = r - 3.0
	ring.rings = 64
	put(ring, glow(col), c + Vector3(0.0, 5.6, 0.0))
	cyl(r * 0.45, r * 0.45, 1.0, glow(col.darkened(0.35)), c + Vector3(0.0, 5.4, 0.0), Vector3.ZERO, null, 40)
	for k in 8:
		var a: float = TAU * float(k) / 8.0
		box(Vector3(r * 0.22, 0.6, 7.0), mat(Color(0.95, 0.85, 0.40), 0.6), c + Vector3(cos(a) * r * 0.72, 5.4, sin(a) * r * 0.72), Vector3(0.0, -rad_to_deg(a), 0.0))

# --- live: the saucer and its beam, the boarding columns -------------------------------------------------------------

func _build_live() -> void:
	# THE RAY from the saucer to the arrivals pad (the user liked it; it had faded to a ghost): a cone of light,
	# brightest along its rim and its core, strongest at the saucer and softening as it reaches the pad, a slow
	# shimmer running down it; and a pool of its light on the pad
	var rsh: Shader = Shader.new()
	rsh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float time = 0.0;
void fragment() {
	float facing = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.0);
	float core = pow(facing, 6.0);
	float down = UV.y;
	float fade = mix(1.0, 0.45, down) * (1.0 - smoothstep(0.93, 1.0, down)) * (1.0 + 0.8 * (1.0 - smoothstep(0.0, 0.10, down)));
	float shimmer = 0.80 + 0.20 * sin(down * 38.0 - time * 5.0 + UV.x * 6.2832 * 3.0);
	ALBEDO = mix(vec3(0.55, 1.0, 0.92), vec3(0.95, 1.0, 1.0), core);
	ALPHA = clamp((0.10 + 0.45 * rim + 0.30 * core) * fade * shimmer, 0.0, 0.85);
}"""
	_ray = ShaderMaterial.new()
	_ray.shader = rsh
	# (the beam POURS OUT OF THE SAUCER: it starts inside the engine ring, as wide as the emitter, brightest there, and
	# rides with the saucer's bob -- it stopped short under it, faded in, narrower, and stood still while the saucer
	# moved: the user, 2026-11-19, "the light below it doesn't connect to it")
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = EMIT_R
	cone.bottom_radius = 118.0
	cone.height = SHIP.y - PAD.y - 34.0
	cone.cap_top = false
	cone.cap_bottom = false
	cone.radial_segments = 48
	_beam = Node3D.new()
	root.add_child(_beam)
	put(cone, _ray, Vector3(0.0, -34.0 - cone.height * 0.5, 0.0), Vector3.ZERO, _beam)
	var inner: CylinderMesh = CylinderMesh.new()
	inner.top_radius = 30.0
	inner.bottom_radius = 60.0
	inner.height = cone.height
	inner.cap_top = false
	inner.cap_bottom = false
	inner.radial_segments = 32
	put(inner, _ray, Vector3(0.0, -34.0 - cone.height * 0.5, 0.0), Vector3.ZERO, _beam)
	var pool: StandardMaterial3D = StandardMaterial3D.new()
	pool.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pool.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool.albedo_texture = _pool_tex()
	pool.albedo_color = Color(0.70, 1.0, 0.95, 0.75)
	var pq: PlaneMesh = PlaneMesh.new()
	pq.size = Vector2(300.0, 300.0)
	put(pq, pool, PAD + Vector3(0.0, 7.0, 0.0))
	# the boarding columns: a tall faint tube of light over each boarding pad, brightening as an alien goes up it
	# the boarding columns: a shaft of light over each boarding pad, soft at its edges and fading upward, brightening
	# as an alien goes up it (a plain translucent tube read as a gray pillar)
	var sh: Shader = Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 col = vec4(1.0);
void fragment() {
	// (whole up to the hatch it now reaches -- it faded out upward, into the empty sky it used to rise into)
	float facing = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.0);
	ALBEDO = mix(col.rgb, vec3(1.0), 0.35 * pow(facing, 4.0));
	ALPHA = col.a * (0.25 + 0.45 * rim + 0.30 * pow(facing, 4.0)) * (0.75 + 0.25 * UV.y);
}"""
	for g in 2:
		var cmat: ShaderMaterial = ShaderMaterial.new()
		cmat.shader = sh
		cmat.set_shader_parameter("col", Color([Color(0.45, 0.65, 1.0), Color(1.0, 0.50, 0.85)][g], 0.0))
		var tube: CylinderMesh = CylinderMesh.new()
		tube.top_radius = 46.0
		tube.bottom_radius = 62.0
		tube.top_radius = HATCH_R
		tube.height = HOVER_Y - HATCH_DROP - (GATES[g] as Vector3).y
		tube.cap_top = false
		tube.cap_bottom = false
		put(tube, cmat, (GATES[g] as Vector3) + Vector3(0.0, tube.height * 0.5, 0.0))
		_columns.append(cmat)
	# THE SAUCER: a broad hull of paneled metal, a darker band with its rim lights, the underside's engine ring, the
	# glass dome lit from inside
	_saucer = Node3D.new()
	root.add_child(_saucer)
	var hull: StandardMaterial3D = mat(Color.WHITE, 0.28, 0.85, _rock_tex(64, Color(0.78, 0.80, 0.86)), Vector3(6, 1, 1))
	var d: MeshInstance3D = sphere(210.0, hull, Vector3.ZERO, _saucer)
	d.scale = Vector3(1.0, 0.18, 1.0)
	var band: TorusMesh = TorusMesh.new()
	band.inner_radius = 196.0
	band.outer_radius = 212.0
	band.rings = 96
	put(band, mat(Color(0.30, 0.33, 0.40), 0.35, 0.8), Vector3.ZERO, Vector3.ZERO, _saucer)
	var under: MeshInstance3D = sphere(130.0, mat(Color(0.28, 0.32, 0.40), 0.4, 0.7), Vector3(0.0, -10.0, 0.0), _saucer)
	under.scale = Vector3(1.0, 0.22, 1.0)
	var eng: TorusMesh = TorusMesh.new()
	eng.inner_radius = EMIT_R - 2.0
	eng.outer_radius = EMIT_R + 10.0
	eng.rings = 48
	# THE EMITTER: a metal ring round a glowing LENS exactly as wide as the beam's top, so the light visibly comes out of
	# it (a glowing ring and disc, wider than the beam and seen edge-on, read as a strange bar of light under the hull)
	put(eng, mat(Color(0.40, 0.44, 0.52), 0.3, 0.85), Vector3(0.0, -34.0, 0.0), Vector3.ZERO, _saucer)
	var lens: MeshInstance3D = sphere(EMIT_R, glow(Color(0.88, 1.0, 0.97)), Vector3(0.0, -34.0, 0.0), _saucer)
	lens.scale = Vector3(1.0, 0.22, 1.0)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# THE DOME (it was a half-see-through sphere with a flat glow: a pasted teal disc -- the user): GLASS with depth --
	# the cabin inside lit warm-teal from below, darkening up into the crown, the glass bright where it is seen
	# edge-on, a highlight of the key light -- seated in a metal COLLAR with small lights round the hull's top
	var dsh: Shader = Shader.new()
	dsh.code = """shader_type spatial;
render_mode unshaded;
uniform float rad = 84.0;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
}
void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - f, 2.2);
	float h = clamp(lp.y / rad, 0.0, 1.0);
	vec3 inside = mix(vec3(0.30, 0.78, 0.74), vec3(0.03, 0.14, 0.20), smoothstep(0.0, 0.9, h));
	vec3 c = inside + vec3(0.55, 0.95, 1.0) * fres * 0.85;
	float spec = pow(clamp(dot(NORMAL, normalize(vec3(-0.45, 0.55, 0.70))), 0.0, 1.0), 48.0);
	float spec2 = pow(clamp(dot(NORMAL, normalize(vec3(0.55, 0.25, 0.80))), 0.0, 1.0), 90.0);
	ALBEDO = c + vec3(1.0) * spec * 0.85 + vec3(0.7, 1.0, 1.0) * spec2 * 0.35;
}"""
	_glass_shader = dsh
	var dome_m: ShaderMaterial = ShaderMaterial.new()
	dome_m.shader = dsh
	var dome: MeshInstance3D = sphere(84.0, dome_m, Vector3(0.0, 30.0, 0.0), _saucer, true)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var collar: TorusMesh = TorusMesh.new()
	collar.inner_radius = 80.0
	collar.outer_radius = 94.0
	collar.rings = 64
	var cm: MeshInstance3D = put(collar, mat(Color(0.62, 0.66, 0.74), 0.25, 0.9), Vector3(0.0, 39.0, 0.0), Vector3.ZERO, _saucer)
	cm.scale = Vector3(1.0, 0.75, 1.0)
	for ck in 12:
		var ca: float = TAU * (float(ck) + 0.5) / 12.0
		sphere(2.6, glow(Color(0.60, 1.0, 0.95)), Vector3(cos(ca) * 93.0, 40.0, sin(ca) * 93.0), _saucer)
	for k in 24:
		var a: float = TAU * float(k) / 24.0
		var lm: StandardMaterial3D = glow(Color(1.0, 0.85, 0.35))
		sphere(7.0, lm, Vector3(cos(a) * 212.0, 0.0, sin(a) * 212.0), _saucer)
		_rim.append(lm)
	for g2 in 2:
		_shuttles.append(_build_shuttle([Color(0.45, 0.65, 1.0), Color(1.0, 0.50, 0.85)][g2], g2))

# where rider k is: [3-D position, size factor, alpha], for its time in its cycle
var _ray: ShaderMaterial = null
var _beam: Node3D = null

func _pool_tex() -> Texture2D:
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.4, Color(1, 1, 1, 0.45))
	gt.gradient = g
	return gt

# a departure shuttle: a squat hull of the saucer's metal, a band in the gate's color with its window lights, a small
# glass canopy, and under it the HATCH -- a ring, a glowing lens, and an iris door that opens for each boarding
func _build_shuttle(col: Color, seed_i: int) -> Array:
	var sh_n: Node3D = Node3D.new()
	root.add_child(sh_n)
	var hull: StandardMaterial3D = mat(Color.WHITE, 0.30, 0.85, _rock_tex(64, Color(0.80, 0.82, 0.88)), Vector3(4, 1, 1))
	var body: MeshInstance3D = sphere(64.0, hull, Vector3.ZERO, sh_n)
	body.scale = Vector3(1.0, 0.36, 1.0)
	var band_m: StandardMaterial3D = mat(col.darkened(0.35), 0.3, 0.6)
	band_m.emission_enabled = true
	band_m.emission = col
	band_m.emission_energy_multiplier = 0.25
	var band: TorusMesh = TorusMesh.new()
	band.inner_radius = 58.0
	band.outer_radius = 68.0
	band.rings = 64
	var bm: MeshInstance3D = put(band, band_m, Vector3(0.0, 2.0, 0.0), Vector3.ZERO, sh_n)
	bm.scale = Vector3(1.0, 0.7, 1.0)
	for w in 10:
		var wa: float = TAU * (float(w) + 0.25 * float(seed_i)) / 10.0
		sphere(3.4, glow(col.lightened(0.45)), Vector3(cos(wa) * 67.0, 3.0, sin(wa) * 67.0), sh_n)
	var cm: ShaderMaterial = ShaderMaterial.new()
	cm.shader = _glass_shader
	cm.set_shader_parameter("rad", 26.0)
	var canopy: MeshInstance3D = sphere(26.0, cm, Vector3(0.0, 16.0, 0.0), sh_n, true)
	canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var metal: StandardMaterial3D = mat(Color(0.50, 0.54, 0.62), 0.3, 0.85)
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = HATCH_R - 1.0
	ring.outer_radius = HATCH_R + 6.0
	put(ring, metal, Vector3(0.0, -HATCH_DROP + 4.0, 0.0), Vector3.ZERO, sh_n)
	var lens_m: StandardMaterial3D = glow(col.lightened(0.6))
	var lens: MeshInstance3D = sphere(HATCH_R, lens_m, Vector3(0.0, -HATCH_DROP + 4.0, 0.0), sh_n)
	lens.scale = Vector3(1.0, 0.25, 1.0)
	var door: MeshInstance3D = cyl(HATCH_R + 0.5, HATCH_R + 0.5, 2.0, metal, Vector3(0.0, -HATCH_DROP + 2.5, 0.0), Vector3.ZERO, sh_n, 24)
	return [sh_n, lens_m, door, col]

# rider k's boarding at gate g: its time in the cycle when it starts up the column, and when it is aboard
func _board_window(k: int) -> Vector2:
	var t0: float = fposmod((0.74 - float(k) / float(RIDERS)) * PERIOD, PERIOD)
	return Vector2(t0, t0 + 0.26 * PERIOD)

# when (in the cycle) gate g's shuttle lifts off: just after the boarding followed by the longest quiet stretch
func _depart_at(g: int) -> float:
	var wins: Array = []
	for k in RIDERS:
		if _dest(k) == g:
			wins.append(_board_window(k))
	if wins.is_empty():
		return 0.0
	var best: float = 0.0
	var best_gap: float = -1.0
	for wv in wins:
		var w: Vector2 = wv
		var gap: float = PERIOD
		for ov in wins:
			var o: Vector2 = ov
			var d: float = fposmod(o.x - w.y, PERIOD)
			if d < gap:
				gap = d
		if gap > best_gap:
			best_gap = gap
			best = w.y
	return best + 0.15

# the shuttle's height over its hover for the time in its cycle (0 while it waits), and how open its hatch is
func _shuttle_state(g: int) -> Vector2:
	var ph: float = fposmod(t - _depart_at(g), PERIOD)
	var lift: float = 0.0
	if ph < DEPART_S:
		lift = LIFT * pow(ph / DEPART_S, 2.2)
	elif ph < DEPART_S + ARRIVE_S:
		lift = LIFT * pow(1.0 - (ph - DEPART_S) / ARRIVE_S, 3.0)
	var open: float = 0.0
	for k in RIDERS:
		if _dest(k) == g:
			var u: float = fmod(t / PERIOD + float(k) / float(RIDERS), 1.0)
			if u > 0.74:
				var f3: float = (u - 0.74) / 0.26
				open = maxf(open, smoothstep(0.0, 0.25, f3) * (1.0 - smoothstep(0.92, 1.0, f3)))
	return Vector2(lift, open)

func _rider_at(k: int) -> Array:
	var u: float = fmod(t / PERIOD + float(k) / float(RIDERS), 1.0)
	# out of the EMITTER: just under its lens, riding the saucer's bob, centered in the beam, fading in in its light (they
	# started 50 under the saucer's rest height, drifting 20 aside, a 2-D figure over the hull: "they sometimes seem to come
	# out of the saucer's edge")
	var top: Vector3 = SHIP + Vector3(0.0, 6.0 * sin(t * 1.1) - 82.0, 0.0)
	var land: Vector3 = PAD + Vector3((float(k % 3) - 1.0) * 30.0, 8.0, 0.0)
	var dest: int = _dest(k)
	if u < 0.34:
		# down the beam, drifting a little
		var f: float = smoothstep(0.0, 0.34, u)
		var p: Vector3 = top.lerp(land, f) + Vector3(sin(t * 0.9 + float(k) * 1.9) * 40.0 * f * (1.0 - f), 0.0, 0.0)
		return [p, 0.8 + 0.2 * f, smoothstep(0.0, 0.05, u)]
	if u < 0.42:
		return [land + Vector3(0.0, 6.0 * absf(sin((u - 0.34) * 40.0)) * (0.42 - u) * 12.0, 0.0), 1.0, 1.0]
	# across the deck in hops to its pad -- or off into the field
	var goal: Vector3 = (GATES[dest] as Vector3) + Vector3(0.0, 8.0, 0.0) if dest >= 0 else Vector3(-60.0 if k % 2 == 0 else 60.0, 8.0, 520.0)
	if u < 0.74:
		var f2: float = (u - 0.42) / 0.32
		var hop: float = absf(sin(f2 * PI * 4.0)) * 18.0
		var p2: Vector3 = land.lerp(goal, smoothstep(0.0, 1.0, f2)) + Vector3(0.0, hop, 0.0)
		return [p2, 1.0, 1.0 if dest >= 0 else 1.0 - smoothstep(0.85, 1.0, f2)]
	if dest < 0:
		return [goal, 1.0, 0.0]
	# up the column and INTO THE SHUTTLE'S HATCH, gone as it passes in
	var f3: float = (u - 0.74) / 0.26
	var hatch_y: float = HOVER_Y - HATCH_DROP - 14.0
	var rise: float = (hatch_y - goal.y) * smoothstep(0.0, 1.0, f3)
	return [goal + Vector3(0.0, rise, 0.0), 1.0 - 0.35 * f3, 1.0 - smoothstep(0.80, 0.97, f3)]

func _animate(_delta: float) -> void:
	if _stars != null:
		var key: String = "%s %s" % [MainGlobals.full_screen_size, screen_of(SHIP) if _cam3 != null else Vector2(-1, -1)]
		if key != _sky_for:
			_sky_for = key
			_build_stars()
			_sky_grad.queue_redraw()
			_planet.queue_redraw()
		(_stars.material as ShaderMaterial).set_shader_parameter("t", t)
	if _ray != null:
		_ray.set_shader_parameter("time", t)
	if _saucer == null:
		return
	_saucer.position = SHIP + Vector3(0.0, 6.0 * sin(t * 1.1), 0.0)
	if _beam != null:
		_beam.position = _saucer.position
	_saucer.rotation = Vector3(deg_to_rad(3.0), t * 0.35, 0.0)
	# the rim lights BREATHE TOGETHER (a chase running round them looked like a second rotation, out of step with the
	# hull and the collar's lights -- the user)
	for k in _rim.size():
		var on: float = 0.55 + 0.45 * sin(t * 2.2)
		(_rim[k] as StandardMaterial3D).albedo_color = Color(0.55, 0.42, 0.18).lerp(Color(1.0, 0.92, 0.55), on)
	for g3 in _shuttles.size():
		var shv: Array = _shuttles[g3]
		var st: Vector2 = _shuttle_state(g3)
		var gp: Vector3 = GATES[g3]
		var node: Node3D = shv[0]
		node.position = Vector3(gp.x, HOVER_Y + st.x + 4.0 * sin(t * 1.3 + float(g3) * 2.0), gp.z)
		node.rotation = Vector3(0.0, t * 0.5 * (1.0 if g3 == 0 else -1.0), deg_to_rad(4.0) * sin(t * 0.9 + float(g3)))
		node.scale = Vector3.ONE * SHUTTLE_SCALE
		var lc: Color = shv[3]
		(shv[1] as StandardMaterial3D).albedo_color = lc.darkened(0.55).lerp(lc.lightened(0.7), st.y)
		(shv[2] as Node3D).scale = Vector3(maxf(0.02, 1.0 - st.y), 1.0, maxf(0.02, 1.0 - st.y))
	var column_boost: Array = [0.0, 0.0]
	for k2 in _riders.size():
		var a2: Node2D = _riders[k2]
		var at: Array = _rider_at(k2)
		var p: Vector3 = at[0]
		var sp: Vector2 = screen_of(p)
		var sc: float = screen_of(p + Vector3(0.0, 40.0, 0.0)).distance_to(sp) / 40.0
		a2.position = sp
		a2.rotation = sin(t * 0.7 + float(k2)) * 0.12
		a2.scale = Vector2.ONE * sc * float(at[1]) * 1.25
		a2.modulate = Color(1, 1, 1, float(at[2]))
		a2.call("set_bob", sin(t * 3.0 + float(k2)) * 2.0)
		var u: float = fmod(t / PERIOD + float(k2) / float(RIDERS), 1.0)
		var dest: int = _dest(k2)
		if dest >= 0 and u > 0.72:
			column_boost[dest] = maxf(float(column_boost[dest]), sin(clampf((u - 0.72) / 0.28, 0.0, 1.0) * PI))
	# the nearer aliens drawn over the farther
	var order: Array = range(_riders.size())
	order.sort_custom(func(x: int, y: int) -> bool: return ((_rider_at(x)[0]) as Vector3).z < ((_rider_at(y)[0]) as Vector3).z)
	for oi in order.size():
		_layer.move_child(_riders[order[oi]], oi)
	for g in 2:
		var cm: ShaderMaterial = _columns[g]
		var base: Color = [Color(0.45, 0.65, 1.0), Color(1.0, 0.50, 0.85)][g]
		cm.set_shader_parameter("col", Color(base, 0.85 * float(column_boost[g])))
	if _holo != null:
		_holo.queue_redraw()

# THE PASSES: a hologram over each boarding pad -- a frame of light, scanlines running up it, a faint flicker -- with
# the rule as the game shows it: a blue alien and "BLUE", three eyes and "3 EYES"
func _draw_holo(d: Control) -> void:
	if _cam3 == null:
		return
	var f: Font = MainGlobals.get_text_font()
	for g in 2:
		var c3: Vector3 = (GATES[g] as Vector3) + Vector3(0.0, 120.0, 0.0)
		var c: Vector2 = screen_of(c3)
		var w: float = screen_of(c3 + Vector3(56.0, 0.0, 0.0)).distance_to(c)
		var h: float = w * 0.82
		var col: Color = [Color(0.55, 0.75, 1.0), Color(1.0, 0.60, 0.90)][g]
		var flick: float = 0.85 + 0.15 * sin(t * 23.0 + float(g) * 3.0) * sin(t * 7.0)
		var r: Rect2 = Rect2(c - Vector2(w, h), Vector2(w, h) * 2.0)
		d.draw_rect(r, Color(col, 0.10 * flick))
		for sl in int(h / 3.0):
			var yy: float = r.position.y + fmod(float(sl) * 6.0 + t * 20.0, r.size.y)
			d.draw_line(Vector2(r.position.x, yy), Vector2(r.end.x, yy), Color(col, 0.07 * flick), 1.0)
		d.draw_rect(r, Color(col, 0.75 * flick), false, 2.0)
		for cn in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			d.draw_circle(cn, 3.0, Color(1, 1, 1, 0.8 * flick))
		# the beam of light that projects it, up from the pad
		var base: Vector2 = screen_of((GATES[g] as Vector3) + Vector3(0.0, 10.0, 0.0))
		d.draw_colored_polygon(PackedVector2Array([base + Vector2(-6.0, 0.0), base + Vector2(6.0, 0.0), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]), Color(col, 0.05 * flick))
		var fs: int = int(clampf(w * 0.40, 12.0, 40.0))
		var txt: String = ["BLUE", "3 EYES"][g]
		var tw: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		d.draw_string(f, Vector2(c.x - tw * 0.5, r.end.y - h * 0.18), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 1.0, 1.0, 0.95 * flick))
		# the icon: a blue blob, or three eyes
		var ic: Vector2 = c + Vector2(0.0, -h * 0.30)
		var ir: float = w * 0.30
		if g == 0:
			d.draw_circle(ic, ir, Color(0.28, 0.56, 0.95, 0.9 * flick))
			d.draw_circle(ic + Vector2(-ir * 0.35, -ir * 0.1), ir * 0.22, Color(1, 1, 1, 0.95))
			d.draw_circle(ic + Vector2(ir * 0.35, -ir * 0.1), ir * 0.22, Color(1, 1, 1, 0.95))
			d.draw_circle(ic + Vector2(-ir * 0.32, -ir * 0.08), ir * 0.10, Color(0.05, 0.05, 0.1, 0.95))
			d.draw_circle(ic + Vector2(ir * 0.38, -ir * 0.08), ir * 0.10, Color(0.05, 0.05, 0.1, 0.95))
		else:
			for e in [Vector2(-0.55, -0.35), Vector2(0.55, -0.35), Vector2(0.0, 0.45)]:
				var ep: Vector2 = ic + (e as Vector2) * ir
				d.draw_circle(ep, ir * 0.32, Color(1, 1, 1, 0.95 * flick))
				d.draw_circle(ep + Vector2(0.0, ir * 0.06), ir * 0.15, Color(0.10, 0.05, 0.15, 0.95))

# --- the sky behind (2-D) ---------------------------------------------------------------------------------------------

func _paint(_full: Vector2, _bottom: float) -> void:
	pass                    # the sky is in its three layers (_setup)

# the stars for the STARS shader, for this layout
func _build_stars() -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = 170
	for k in 170:
		var sp: Vector2 = Vector2(h01(k * 5 + 1) * full.x, h01(k * 5 + 2) * full.y * 0.80)
		var big: float = pow(h01(k * 5 + 3), 3.0)
		var rate: float = 0.8 + 2.2 * h01(k + 9)
		var hue: Color = [Color(0.85, 0.92, 1.0), Color(1.0, 0.92, 0.80), Color(0.80, 1.0, 0.95), Color(1.0, 0.85, 0.95)][k % 4]
		var r: float = 0.6 + 1.6 * big
		var half: float = (r * 14.0 if r > 1.0 else r * 1.2) + 1.5
		mm.set_instance_transform_2d(k, Transform2D(0.0, Vector2(half, half), 0.0, sp))
		mm.set_instance_color(k, Color(hue.r, hue.g, hue.b, r / 4.0))
		mm.set_instance_custom_data(k, Color(rate, float(k) * 1.7, float(k), half))
	_stars.multimesh = mm

# the ringed planet and the two moons (still)
func _draw_planet(d: Control) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var keep: CanvasItem = cv
	cv = d
	var ship_y: float = screen_of(SHIP).y if _cam3 != null else full.y * 0.3
	var planet: Vector2 = Vector2(full.x * 0.16, ship_y + 30.0)
	var pr: float = full.x * 0.15
	glow_at(planet, pr * 1.6, Color(0.95, 0.55, 0.85, 0.20))
	_ring(planet, pr * 1.8, pr * 0.42, Color(0.95, 0.80, 0.65, 0.55), true)
	_sphere(planet, pr, Color(0.30, 0.10, 0.28), Color(0.95, 0.62, 0.82))
	for b in 3:
		ellipse(planet + Vector2(-pr * 0.08, pr * (-0.32 + 0.3 * float(b))), pr * (0.86 - 0.12 * float(b)), pr * 0.07, Color(1.0, 0.80, 0.90, 0.14))
	_ring(planet, pr * 1.8, pr * 0.42, Color(0.95, 0.80, 0.65, 0.55), false)
	_sphere(Vector2(full.x * 0.86, ship_y - 90.0), 20.0, Color(0.25, 0.30, 0.38), Color(0.92, 0.96, 1.0))
	_sphere(Vector2(full.x * 0.74, ship_y - 40.0), 10.0, Color(0.15, 0.32, 0.26), Color(0.75, 1.0, 0.85))
	cv = keep

func _paint_top(_full: Vector2, _bottom: float) -> void:
	# rings of light running down the beam
	if _cam3 != null:
		for k in 6:
			var u: float = fmod(t * 0.25 + float(k) / 6.0, 1.0)
			var src: Vector3 = _saucer.position if _saucer != null else SHIP
			var p: Vector3 = (src + Vector3(0.0, -40.0, 0.0)).lerp(PAD + Vector3(0.0, 8.0, 0.0), u)
			var c: Vector2 = screen_of(p)
			var rx: float = screen_of(p + Vector3(lerpf(54.0, 112.0, u), 0.0, 0.0)).distance_to(c)
			ellipse(c, rx, rx * 0.22, Color(0.85, 1.0, 0.95, 0.12 * sin(u * PI)))
	title("Aliens", "Work the spaceport gates", Color(0.70, 1.0, 0.85), Color(0.04, 0.10, 0.10), Color(0.4, 1.0, 0.8, 0.30))

func _sphere(c: Vector2, r: float, dark: Color, light_c: Color) -> void:
	glow_at(c, r * 1.35, Color(light_c, 0.18), 6)
	cv.draw_circle(c, r, dark)
	for k in 24:
		var f: float = float(k + 1) / 24.0
		cv.draw_circle(c + Vector2(-r, -r) * 0.32 * f, r * (1.0 - 0.62 * f), dark.lerp(light_c, f))
	cv.draw_arc(c, r - 1.0, deg_to_rad(150.0), deg_to_rad(300.0), 32, Color(light_c.lightened(0.3), 0.55), maxf(1.5, r * 0.04), true)

func _ring(c: Vector2, rx: float, ry: float, col: Color, back: bool) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 33:
		var a: float = (PI if back else 0.0) + PI * float(k) / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(-0.25))
	cv.draw_polyline(pts, col, 7.0, true)

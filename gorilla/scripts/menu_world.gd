extends "res://scripts/menu_poster3d.gd"

# GORILLA'S OPENING POSTER (main.gd menu_backdrop(); a real 3-D world, see scripts/menu_poster3d.gd): THE RAINFOREST
# FLOOR AT DAWN, seen low from the side (2026-11-20; it was flat vector art -- star-shaped leaf clusters in a few greens,
# the game's cartoon figures -- "looks like a one year old child's book"). Great trunks with furrowed bark and buttress
# roots going up into the canopy, lianas hanging, ferns and broad-leaved plants, a leaf-litter floor, the far trunks
# fading into a green-gold haze, the low sun behind them; a mossy fallen log with a cut end, a bunch of bananas and two
# apples on it, and a BABY gorilla sitting there, breathing, watching; a SILVERBACK walking across the floor on its
# knuckles -- built in 3-D with a gorilla's proportions (massive shoulders and arms, the crest on its head, the silver
# saddle on its back, a dark leathery face), each arm and leg solved by IK with fixed bone lengths, every hand and foot
# planted while it pushes. The forest and the log are baked (`menu_forest.webp`, `menu_forest_d.webp`); the gorillas,
# the hanging fronds at the top corners and the light shafts are live. Made up, never the board.

# THE WALK: across the floor in front of the log, left to right, off the screen and round again
const PATH_Z: float = 60.0
const SPEED: float = 26.0              # units a second: slow and heavy
const GAIT_T: float = 2.0              # one full cycle of the four limbs (s)
const DUTY: float = 0.68               # the share of the cycle a limb stands on the ground
# (the walk runs from just out of sight at the left to just out of sight at the right and starts again at once -- no
# pause with an empty forest, the user, 2026-11-20: `_walk_span`)
const REACH_FRONT: float = 125.0       # how far the body reaches ahead of its origin (the head) and behind (the rump)
const REACH_BACK: float = 95.0
# the limbs, in the gorilla's own frame (x forward, y up, z to its left): root, the foot's neutral contact, bone
# lengths, phase in the cycle (a lateral-sequence walk: hind left, fore left, hind right, fore right)
const ARM_UP: float = 56.0
const ARM_FORE: float = 54.0
const LEG_UP: float = 40.0
const LEG_LOW: float = 38.0
# THE LOG: lying on the floor behind the walk, turned a little toward us so its cut end shows
const LOG_C: Vector3 = Vector3(-150.0, 24.0, -40.0)
const LOG_R: float = 24.0
const LOG_LEN: float = 300.0
const LOG_YAW: float = 22.0            # degrees
const BABY_S: float = 10.0             # where the baby sits along the log from its middle

const FUR: Color = Color(0.075, 0.072, 0.07)
const SILVER: Color = Color(0.30, 0.30, 0.30)    # the saddle's gray
const SKIN: Color = Color(0.07, 0.065, 0.07)

# FUR: strands running down the body (value noise stretched along the part's own y), each a little lighter or darker; a
# soft rim where the low sun catches it from behind; and a FUZZY SILHOUETTE -- where the surface turns away, pixels
# drop out by the strands' noise, so the outline is hair and the seams between the body's parts disappear. `saddle`
# turns the top of a part gray toward its back (the silverback's saddle, worked into the torso's own fur)
const FUR_SHADER: String = """shader_type spatial;
render_mode cull_back;
uniform vec3 base : source_color = vec3(0.11, 0.105, 0.10);
uniform vec3 silver : source_color = vec3(0.50, 0.50, 0.50);
uniform float saddle = 0.0;
uniform float freq = 30.0;
varying vec3 lp;
float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() {
	lp = VERTEX;
}
void fragment() {
	vec3 q = lp * vec3(freq, freq * 0.18, freq);
	float n = vnoise(q) * 0.65 + vnoise(q * 2.3 + 7.0) * 0.35;
	vec3 col = base;
	if (saddle > 0.0) {
		// the top of the torso, from behind the shoulders back to the rump
		float s = smoothstep(0.05, 0.75, lp.y) * (1.0 - smoothstep(0.05, 0.75, lp.x)) * smoothstep(-1.0, -0.5, lp.x);
		col = mix(col, silver, s * saddle * (0.55 + 0.45 * vnoise(lp * 9.0)));
	}
	ALBEDO = col * (0.55 + 0.45 * n);
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	if (fres > 0.80 && n < (fres - 0.80) * 2.6) {
		discard;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
	RIM = 0.45;
	RIM_TINT = 0.7;
	BACKLIGHT = col * 0.25;
}
"""

func _fur_mat(base: Color, saddle: float = 0.0, freq: float = 30.0) -> ShaderMaterial:
	var sh: Shader = Shader.new()
	sh.code = FUR_SHADER
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("base", base)
	m.set_shader_parameter("silver", SILVER)
	m.set_shader_parameter("saddle", saddle)
	m.set_shader_parameter("freq", freq)
	return m

var _adult: Node3D = null
var _body: Node3D = null
var _head: Node3D = null
var _limbs: Array = []                 # [{root, phase, hand: bool, side, up: MeshInstance3D, low, end}]
var _adult_shadow: MeshInstance3D = null
var _baby: Node3D = null
var _baby_head: Node3D = null
var _baby_body: Node3D = null
var _baby_arm: Array = []              # [shoulder, upper, fore, hand] of its right arm (it reaches for the fruit)
var _fronds: Array = []                # [Node3D, base yaw] -- the live hanging fronds at the top corners
var _baby_legs: Array = []             # per side: [hip, thigh, shin, foot]
var _baby_apple: Node3D = null         # the apple in its right hand
var _flies: Array = []                 # butterflies: [Node3D, [wing pivots], seed]
var _falling: Array = []               # leaves drifting down: [MeshInstance3D, seed]
var _look: float = 0.0                 # the baby's head turn, eased

func _baked_path() -> String:
	return "res://gorilla/art/menu_forest.webp" if mobile else "res://gorilla/art/menu_forest_d.webp"

func _eye() -> Vector3:
	return Vector3(0.0, 96.0, 470.0) if mobile else Vector3(0.0, 118.0, 620.0)

func _aim() -> Vector3:
	return Vector3(0.0, 112.0, 0.0) if mobile else Vector3(0.0, 98.0, 0.0)

func _fov() -> float:
	return 56.0

func _frame_frac() -> float:
	return 0.62 if mobile else 0.60

func _environment(env: Environment) -> void:
	env.background_color = Color(0.32, 0.42, 0.24)
	# A RICHER GRADE for the forest (the user, 2026-11-20: "colors are still very dull and washed out"): the filmic tone
	# mapping and the haze flattened every green. The bake only: in the live view it turned the gorillas red and orange
	if bake_mode:
		env.adjustment_enabled = true
		env.adjustment_saturation = 1.22
		env.adjustment_contrast = 1.12
	env.ambient_light_color = Color(0.26, 0.40, 0.20)
	env.ambient_light_energy = 0.38
	if bake_mode:
		# THE HAZE: the far trunks fade into green-gold (the bake only: fog in a live view recompiles its materials)
		env.fog_enabled = true
		env.fog_light_color = Color(0.44, 0.56, 0.28)
		env.fog_light_energy = 0.9
		env.fog_density = 0.008
		env.fog_sky_affect = 0.0

func _build_lights() -> void:
	# THE LOW SUN behind the forest, a little to the right: rims every trunk and leaf, long shadows toward us
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.78, 0.42)
	sun.light_energy = 1.6
	# (its shadows are baked into the forest; in the live view a shadow map cost a phone dearly, and the gorillas have
	# their own soft shadows)
	sun.shadow_enabled = bake_mode
	sun.directional_shadow_max_distance = 30.0
	root.add_child(sun)
	sun.rotation_degrees = Vector3(-40.0, 160.0, 0.0)
	# the sky's cool fill from in front, so nothing facing us goes black
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.light_color = Color(0.70, 0.80, 0.72)
	fill.light_energy = 0.30
	root.add_child(fill)
	fill.rotation_degrees = Vector3(-25.0, -10.0, 0.0)

# --- textures ---------------------------------------------------------------------------------------------------

# LEAF LITTER: brown leaves of many shades lying every way, darker gaps of soil between, a twig or two
func _litter(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	img.fill(Color(0.09, 0.07, 0.05))
	for k in 900:
		var c: Vector2 = Vector2(h01(k * 3) * float(n), h01(k * 3 + 1) * float(n))
		var ang: float = TAU * h01(k * 3 + 2)
		var ln: float = 5.0 + 9.0 * h01(k * 7 + 5)
		var wd: float = ln * (0.35 + 0.2 * h01(k * 7 + 6))
		var col: Color = [Color(0.32, 0.21, 0.11), Color(0.40, 0.28, 0.14), Color(0.25, 0.17, 0.09), Color(0.34, 0.30, 0.16),
			Color(0.22, 0.20, 0.10)][k % 5].lerp(Color(0.15, 0.11, 0.07), 0.4 * h01(k * 11))
		var ax: Vector2 = Vector2(cos(ang), sin(ang))
		var ay: Vector2 = Vector2(-ax.y, ax.x)
		for yy in range(-int(ln), int(ln) + 1):
			for xx in range(-int(ln), int(ln) + 1):
				var q: Vector2 = Vector2(float(xx), float(yy))
				var u: float = q.dot(ax) / ln
				var v: float = q.dot(ay) / wd
				var inside: float = u * u + v * v * (1.0 + 0.6 * u)
				if inside <= 1.0:
					var px: int = posmod(int(c.x) + xx, n)
					var py: int = posmod(int(c.y) + yy, n)
					var vein: float = 0.82 if absf(v) < 0.08 else 1.0
					var shade: float = (0.85 + 0.25 * (1.0 - inside)) * vein
					img.set_pixel(px, py, Color(col.r * shade, col.g * shade, col.b * shade))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# BARK: deep vertical furrows, ridges catching the light, lichen in gray-green patches
func _bark(n: int, base: Color, seed_i: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for x in n:
		var xx: float = TAU * float(x) / float(n)
		for y in n:
			var yy: float = TAU * float(y) / float(n)
			var drift: float = 0.6 * sin(yy * 2.0 + float(seed_i)) + 0.3 * sin(yy * 5.0 + xx)
			var ridge: float = 0.5 + 0.5 * sin(xx * 9.0 + drift * 2.0)
			var fine: float = h01(seed_i * 977 + int(float(x) + drift * 6.0) * 31 + y / 5)
			var k: float = 0.55 + 0.45 * pow(ridge, 0.6) + (fine - 0.5) * 0.15
			var c: Color = Color(base.r * k, base.g * k, base.b * k)
			var lich: float = 0.5 + 0.5 * sin(xx * 3.0 + float(seed_i)) * sin(yy * 4.0 + float(seed_i) * 2.0)
			if lich > 0.82:
				c = c.lerp(Color(0.52, 0.56, 0.44), 0.55 * (lich - 0.82) / 0.18)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# A LEAF: green, a pale midrib and lateral veins, darker toward the edges
func _leaf_tex(n: int, base: Color) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		var v: float = float(y) / float(n)
		for x in n:
			var u: float = float(x) / float(n) * 2.0 - 1.0
			var k: float = 0.92 + 0.12 * (1.0 - absf(u)) + (h01(x * 31 + y * 7) - 0.5) * 0.05
			var c: Color = Color(base.r * k, base.g * k, base.b * k)
			if absf(u) < 0.035:
				c = c.lerp(Color(0.70, 0.78, 0.48), 0.6)
			else:
				var lat: float = absf(fposmod(v * 9.0 - absf(u) * 2.2, 1.0) - 0.5)
				if lat < 0.05:
					c = c.lerp(Color(0.55, 0.66, 0.36), 0.35)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# GROWTH RINGS on the log's cut end: pale wood, rings closer toward the bark, a dark heart and two radial cracks
func _rings(n: int) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p: Vector2 = (Vector2(float(x), float(y)) + Vector2(0.5, 0.5)) / float(n) * 2.0 - Vector2.ONE
			var r: float = p.length()
			if r > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var th: float = atan2(p.y, p.x)
			var wob: float = 0.015 * sin(th * 5.0) + 0.01 * sin(th * 11.0 + 1.0)
			var ring: float = 0.5 + 0.5 * cos((pow(r + wob, 0.8)) * 70.0)
			var c: Color = Color(0.72, 0.56, 0.36).lerp(Color(0.52, 0.36, 0.20), 0.45 * ring)
			c = c.lerp(Color(0.30, 0.18, 0.09), (1.0 - smoothstep(0.0, 0.18, r)) * 0.6)
			for ck in [0.7, 3.4]:
				var dth: float = absf(wrapf(th - float(ck), -PI, PI))
				if dth < 0.035 * (1.0 - r) and r > 0.15:
					c = c.darkened(0.6)
			# weathered gray toward the rim
			c = c.lerp(Color(0.40, 0.36, 0.30), smoothstep(0.75, 1.0, r) * 0.5)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# MOSS: a soft green cushion, tufted
func _moss(n: int) -> ImageTexture:
	return tex_speckle(n, Color(0.20, 0.34, 0.10), 0.35, 41)

# --- meshes -------------------------------------------------------------------------------------------------------

# AN ELLIPSOID (a sphere scaled), optionally turned
func _ell(radii: Vector3, m: Material, c: Vector3, parent: Node3D, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	# (the baked forest's ellipsoids finer; the live gorillas' are a few dozen pixels across: 24 x 12 is as round)
	sm.radial_segments = 40 if bake_mode else 24
	sm.rings = 20 if bake_mode else 12
	var mi: MeshInstance3D = put(sm, m, c, Vector3.ZERO, parent)
	mi.basis = Basis.from_euler(rot * PI / 180.0).scaled(radii)
	return mi

# A FERN: fronds arching out of its crown and over, each a rachis with paired leaflets, smaller toward the tip --
# one mesh for the whole plant
func _fern_mesh(n_fronds: int, ln: float, seed_i: int) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in n_fronds:
		var yaw: float = TAU * (float(f) + 0.4 * h01(seed_i * 31 + f)) / float(n_fronds)
		var out: Vector3 = Vector3(cos(yaw), 0.0, sin(yaw))
		var side: Vector3 = Vector3(-out.z, 0.0, out.x)
		var fl: float = ln * (0.75 + 0.35 * h01(seed_i * 7 + f))
		var rise: float = fl * (0.55 + 0.2 * h01(seed_i * 13 + f))
		var segs: int = 16
		for s in segs:
			var u0: float = float(s) / float(segs)
			var u1: float = float(s + 1) / float(segs)
			var p0: Vector3 = out * fl * u0 + Vector3.UP * rise * sin(u0 * PI * 0.85)
			var p1: Vector3 = out * fl * u1 + Vector3.UP * rise * sin(u1 * PI * 0.85)
			var along: Vector3 = (p1 - p0).normalized()
			var leaf_l: float = fl * 0.20 * sin(PI * (0.15 + 0.85 * u0)) * (1.0 - 0.6 * u0)
			var tone: float = 0.85 + 0.25 * h01(seed_i * 101 + f * 17 + s)
			var col: Color = Color(0.20 * tone, 0.40 * tone, 0.12 * tone)
			for sd in [-1.0, 1.0]:
				var tip: Vector3 = p0 + side * sd * leaf_l + along * leaf_l * 0.35 - Vector3.UP * leaf_l * 0.25
				var a: Vector3 = p0
				var b: Vector3 = p0 + along * (p1 - p0).length() * 0.9
				var nrm: Vector3 = (b - a).cross(tip - a).normalized()
				if nrm.y < 0.0:
					nrm = -nrm
				for v in [a, b, tip]:
					st.set_color(col)
					st.set_normal(nrm)
					st.add_vertex(v)
	return st.commit()

# A BROAD LEAF on its stalk: a blade folded a little along its midrib, drooping toward its tip, pointing along +x
func _leaf_mesh(ln: float, wd: float, droop: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: int = 10
	var pts: Array = []
	for r in rows + 1:
		var u: float = float(r) / float(rows)
		var half: float = wd * 0.5 * sin(PI * pow(u, 0.75)) * (1.0 - 0.15 * u)
		var y: float = -droop * u * u
		var row: Array = []
		for c in 3:
			var vv: float = float(c) - 1.0
			row.append([Vector3(u * ln, y + absf(vv) * half * 0.18, vv * half), Vector2(0.5 + vv * 0.5, u)])
		pts.append(row)
	for r in rows:
		for c in 2:
			var quad: Array = [pts[r][c], pts[r + 1][c], pts[r + 1][c + 1], pts[r][c], pts[r + 1][c + 1], pts[r][c + 1]]
			for q in quad:
				st.set_uv(q[1])
				st.add_vertex(q[0])
	st.generate_normals()
	return st.commit()

# A BUTTRESS ROOT: a thin fin from up the trunk curving down to the ground, pointing along +x from the trunk's axis
func _buttress_mesh(r: float, h: float, reach: float, th: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = 10
	var top: Array = []
	for k in n + 1:
		var u: float = float(k) / float(n)
		var x: float = r * 0.8 + reach * u
		var y: float = h * pow(1.0 - u, 2.2)
		top.append(Vector3(x, y, 0.0))
	for k in n:
		var a: Vector3 = top[k]
		var b: Vector3 = top[k + 1]
		var a0: Vector3 = Vector3(a.x, 0.0, 0.0)
		var b0: Vector3 = Vector3(b.x, 0.0, 0.0)
		var tk: float = th * (1.0 - float(k) / float(n) * 0.7)
		for sd in [-1.0, 1.0]:
			var off: Vector3 = Vector3(0.0, 0.0, sd * tk * 0.5)
			for v in [a0 + off, a + off, b + off, a0 + off, b + off, b0 + off]:
				st.set_uv(Vector2(v.x / 60.0, v.y / 60.0))
				st.add_vertex(v)
		# the ridge along its top
		for v2 in [a + Vector3(0, 0, -tk * 0.5), a + Vector3(0, 0, tk * 0.5), b + Vector3(0, 0, tk * 0.5),
				a + Vector3(0, 0, -tk * 0.5), b + Vector3(0, 0, tk * 0.5), b + Vector3(0, 0, -tk * 0.5)]:
			st.set_uv(Vector2(v2.x / 60.0, v2.z / 60.0))
			st.add_vertex(v2)
	st.generate_normals()
	return st.commit()

# A BANANA: a curved, five-sided fruit tapering to both ends, yellow going green at its stalk, its tip dark; lying along
# +x, curving up
func _banana_mesh(ln: float, r: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs: int = 14
	var sides: int = 5
	var rings: Array = []
	for s in segs + 1:
		var u: float = float(s) / float(segs)
		var c: Vector3 = Vector3(u * ln, 0.0, 0.0) + Vector3(0.0, ln * 0.18 * sin(u * PI), 0.0)
		var rad: float = r * sin(PI * (0.06 + 0.88 * u)) + 0.6
		var ring: Array = []
		for k in sides:
			var a: float = TAU * float(k) / float(sides)
			ring.append(c + Vector3(0.0, cos(a) * rad, sin(a) * rad))
		var col: Color = Color(0.93, 0.78, 0.22).lerp(Color(0.55, 0.62, 0.20), smoothstep(0.75, 1.0, u))
		col = col.lerp(Color(0.22, 0.15, 0.08), 1.0 - smoothstep(0.0, 0.07, u))
		rings.append([ring, col])
	for s in segs:
		for k in sides:
			var k2: int = (k + 1) % sides
			var r0: Array = rings[s][0]
			var r1: Array = rings[s + 1][0]
			var c0: Color = rings[s][1]
			var c1: Color = rings[s + 1][1]
			for vc in [[r0[k], c0], [r1[k], c1], [r1[k2], c1], [r0[k], c0], [r1[k2], c1], [r0[k2], c0]]:
				st.set_color(vc[1])
				st.add_vertex(vc[0])
	st.generate_normals()
	return st.commit()

# --- the forest: baked ----------------------------------------------------------------------------------------------

# the trunks: x, z, radius -- near ones big with buttresses, far ones thin and lost in the haze
const TREES: Array = [[-360.0, -120.0, 52.0], [300.0, -260.0, 44.0], [-40.0, -520.0, 34.0], [170.0, -760.0, 30.0],
	[-330.0, -820.0, 34.0], [480.0, -980.0, 26.0], [-560.0, -1100.0, 28.0], [40.0, -1250.0, 22.0], [-200.0, -1450.0, 24.0],
	[320.0, -1500.0, 22.0], [620.0, -600.0, 36.0], [-660.0, -420.0, 40.0]]

func _build_still() -> void:
	var litter: StandardMaterial3D = mat(Color.WHITE, 0.95, 0.0, _litter(256), Vector3(40, 40, 1))
	box(Vector3(8000.0, 4.0, 8000.0), litter, Vector3(0.0, -2.0, -1500.0))
	for k in TREES.size():
		_tree(TREES[k], k)
	_lianas()
	_understory()
	_midstory()
	_canopy()
	_log()

func _tree(tr_: Array, k: int) -> void:
	var x: float = tr_[0]
	var z: float = tr_[1]
	var r: float = tr_[2]
	var bark: StandardMaterial3D = mat(Color.WHITE, 0.9, 0.0, _bark(128, Color(0.36, 0.30, 0.24).lerp(Color(0.44, 0.40, 0.34), h01(k * 5)), k), Vector3(3, 6, 1))
	var h: float = 1600.0
	cyl(r * 0.85, r, h, bark, Vector3(x, h * 0.5, z), Vector3.ZERO, null, 28)
	# the flare at its foot, and buttress roots for the big ones
	cyl(r, r * 1.35, r * 0.9, bark, Vector3(x, r * 0.45, z), Vector3.ZERO, null, 28)
	if r > 32.0:
		var n_b: int = 5
		for b in n_b:
			var yaw: float = TAU * (float(b) + 0.3 * h01(k * 9 + b)) / float(n_b)
			var bm: MeshInstance3D = put(_buttress_mesh(r, r * (2.2 + 0.8 * h01(k * 3 + b)), r * (1.6 + 0.8 * h01(k * 7 + b)), 7.0), bark,
				Vector3(x, 0.0, z), Vector3(0.0, rad_to_deg(yaw), 0.0))
			bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# moss creeping up the shaded side
	var moss: StandardMaterial3D = mat(Color.WHITE, 0.95, 0.0, _moss(64), Vector3(2, 2, 1))
	_ell(Vector3(r * 0.5, r * 1.6, r * 0.55), moss, Vector3(x - r * 0.5, r * 1.2, z + r * 0.62), root, Vector3(0.0, 0.0, 6.0))
	# LEAF CLUSTERS all the way up every trunk (epiphytes, sprouts, a climber's leaves)
	var tl_m: StandardMaterial3D = mat(Color.WHITE, 0.6, 0.0, _leaf_tex(32, Color(0.14, 0.36, 0.08).lerp(Color(0.30, 0.46, 0.08), h01(k * 13))))
	tl_m.backlight_enabled = true
	tl_m.backlight = Color(0.40, 0.55, 0.12)
	var tlm: ArrayMesh = _leaf_mesh(40.0, 20.0, 10.0)
	for cl in 12:
		var ca: float = TAU * h01(k * 41 + cl)
		var cy: float = 120.0 + 900.0 * h01(k * 43 + cl)
		var cc: Vector3 = Vector3(x + cos(ca) * (r + 10.0), cy, z + sin(ca) * (r + 10.0))
		for lf in 14:
			var off: Vector3 = Vector3((h01(k * 977 + cl * 31 + lf) - 0.5) * 70.0, (h01(k * 911 + cl * 29 + lf) - 0.5) * 50.0, (h01(k * 863 + cl * 37 + lf) - 0.5) * 70.0)
			put(tlm, tl_m, cc + off, Vector3(-30.0 + 60.0 * h01(k * 5 + cl * 7 + lf), 360.0 * h01(k * 7 + cl + lf * 3), -40.0 + 70.0 * h01(k * 11 + cl * 5 + lf)))
	# A CLIMBER wound up the trunk, leafy all the way; FERNS growing out of the bark (the trees were bare poles: "why
	# are the trees so empty", the user, 2026-11-20)
	if r > 28.0:
		var vine_m: StandardMaterial3D = mat(Color(0.22, 0.20, 0.12), 0.9)
		var leaf_m: StandardMaterial3D = mat(Color.WHITE, 0.6, 0.0, _leaf_tex(32, Color(0.16, 0.34, 0.10).lerp(Color(0.22, 0.38, 0.08), h01(k))))
		leaf_m.backlight_enabled = true
		leaf_m.backlight = Color(0.35, 0.45, 0.12)
		var lm: ArrayMesh = _leaf_mesh(26.0, 13.0, 6.0)
		var spiral: PackedVector3Array = PackedVector3Array()
		var turns: float = 2.5 + h01(k * 3)
		for j in 60:
			var u: float = float(j) / 59.0
			var ang: float = TAU * turns * u + float(k)
			var rr: float = r * (1.0 - 0.12 * u) + 3.0
			spiral.append(Vector3(x + cos(ang) * rr, 10.0 + 900.0 * u, z + sin(ang) * rr))
		put(tube_mesh(spiral, 2.2, 6), vine_m, Vector3.ZERO)
		for j2 in 70:
			var u2: float = float(j2) / 69.0
			var ang2: float = TAU * turns * u2 + float(k)
			var rr2: float = r * (1.0 - 0.12 * u2) + 6.0
			var at: Vector3 = Vector3(x + cos(ang2) * rr2, 10.0 + 900.0 * u2, z + sin(ang2) * rr2)
			put(lm, leaf_m, at, Vector3(-20.0 + 40.0 * h01(k * 51 + j2), rad_to_deg(-ang2) + 90.0 * h01(k * 17 + j2), -30.0 + 50.0 * h01(k * 23 + j2)))
		var fern_m: StandardMaterial3D = mat(Color.WHITE, 0.7)
		fern_m.vertex_color_use_as_albedo = true
		fern_m.backlight_enabled = true
		fern_m.backlight = Color(0.35, 0.45, 0.15)
		for e in 3:
			var ea: float = TAU * h01(k * 7 + e)
			var eh: float = 160.0 + 320.0 * h01(k * 9 + e)
			var ep: Vector3 = Vector3(x + cos(ea) * r, eh, z + sin(ea) * r)
			put(_fern_mesh(9, 60.0, k * 10 + e), fern_m, ep, Vector3(sin(ea) * 35.0, 0.0, -cos(ea) * 35.0))

var _vine_leaf: ArrayMesh = null
var _vine_leaf_m: StandardMaterial3D = null

# LIANAS: woody vines hanging out of the canopy in long sags, some reaching the floor
func _lianas() -> void:
	var vine: StandardMaterial3D = mat(Color.WHITE, 0.85, 0.0, _bark(64, Color(0.30, 0.26, 0.18), 77), Vector3(1, 8, 1))
	_vine_leaf = _leaf_mesh(30.0, 14.0, 8.0)
	_vine_leaf_m = mat(Color.WHITE, 0.6, 0.0, _leaf_tex(32, Color(0.18, 0.40, 0.08)))
	_vine_leaf_m.backlight_enabled = true
	_vine_leaf_m.backlight = Color(0.40, 0.55, 0.12)
	var hangs: Array = [[-250.0, -200.0, 140.0], [120.0, -340.0, 420.0], [400.0, -150.0, 260.0], [-120.0, -700.0, 80.0], [260.0, -900.0, 30.0],
		[-480.0, -420.0, 200.0], [40.0, -560.0, 300.0], [560.0, -500.0, 120.0], [-330.0, -1000.0, 180.0], [200.0, -200.0, 520.0]]
	for k in hangs.size():
		var hx: float = hangs[k][0]
		var hz: float = hangs[k][1]
		var low: float = hangs[k][2]
		var path: PackedVector3Array = PackedVector3Array()
		for j in 24:
			var u: float = float(j) / 23.0
			path.append(Vector3(hx + 30.0 * sin(u * 3.0 + float(k)) * u, lerpf(1300.0, low, u), hz + 18.0 * sin(u * 5.0 + float(k)) * u))
		put(tube_mesh(path, 3.0 + 1.2 * h01(k), 8), vine, Vector3.ZERO)
		# leaves all down it
		for j3 in 40:
			var lp: Vector3 = path[int(float(j3) / 40.0 * 23.0)]
			put(_vine_leaf, _vine_leaf_m, lp + Vector3((h01(k * 71 + j3) - 0.5) * 24.0, 0.0, (h01(k * 73 + j3) - 0.5) * 16.0),
				Vector3(-50.0 + 40.0 * h01(k * 5 + j3), 360.0 * h01(k * 9 + j3), -20.0 + 40.0 * h01(k * 13 + j3)))
	# one great loop slung between the two near trunks
	var loop: PackedVector3Array = PackedVector3Array()
	var a: Vector3 = Vector3(-340.0, 520.0, -110.0)
	var b: Vector3 = Vector3(285.0, 640.0, -250.0)
	for j2 in 30:
		var u2: float = float(j2) / 29.0
		loop.append(a.lerp(b, u2) - Vector3(0.0, 260.0 * sin(u2 * PI), 0.0))
	put(tube_mesh(loop, 4.5, 10), vine, Vector3.ZERO)

# THE UNDERSTORY: ferns and broad-leaved plants round the trunks' feet and behind the log -- never in front of the walk
func _understory() -> void:
	var ferns: Array = [[-470.0, -60.0, 105.0], [-250.0, -150.0, 90.0], [-20.0, -150.0, 110.0], [220.0, -110.0, 120.0],
		[420.0, -200.0, 100.0], [110.0, -420.0, 90.0], [-180.0, -460.0, 85.0], [380.0, -560.0, 85.0], [-460.0, -640.0, 90.0],
		[60.0, -30.0, 80.0], [560.0, -40.0, 115.0], [-640.0, -150.0, 120.0], [150.0, -250.0, 70.0], [-330.0, -330.0, 80.0],
		[300.0, -40.0, 70.0], [-560.0, -20.0, 90.0], [480.0, -380.0, 90.0], [-80.0, -640.0, 80.0], [250.0, -680.0, 75.0],
		[-20.0, -20.0, 55.0], [-300.0, -60.0, 60.0]]
	var fern_m: StandardMaterial3D = mat(Color.WHITE, 0.7)
	fern_m.vertex_color_use_as_albedo = true
	fern_m.backlight_enabled = true
	fern_m.backlight = Color(0.35, 0.45, 0.15)
	for k in ferns.size():
		var f: Array = ferns[k]
		put(_fern_mesh(12, float(f[2]), k), fern_m, Vector3(float(f[0]), 0.0, float(f[1])), Vector3(0.0, 40.0 * float(k), 0.0))
	# broad leaves: several on long stalks out of one crown, each its own green
	var plants: Array = [[-560.0, -260.0, 1.2], [460.0, -330.0, 1.1], [-90.0, -300.0, 1.0], [250.0, -40.0, 0.85], [-330.0, 10.0, 0.9],
		[120.0, -120.0, 0.9], [-200.0, -560.0, 1.0], [360.0, -460.0, 1.0], [600.0, -150.0, 1.2], [-650.0, -60.0, 1.2]]
	for k2 in plants.size():
		var pl: Array = plants[k2]
		var sc: float = pl[2]
		var leaf_m: StandardMaterial3D = mat(Color.WHITE, 0.55, 0.0, _leaf_tex(64, Color(0.18, 0.38, 0.12).lerp(Color(0.26, 0.42, 0.10), h01(k2))))
		leaf_m.backlight_enabled = true
		leaf_m.backlight = Color(0.40, 0.50, 0.15)
		var stalk: StandardMaterial3D = mat(Color(0.22, 0.32, 0.12), 0.7)
		for l in 6:
			var yaw: float = 60.0 * float(l) + 25.0 * h01(k2 * 11 + l)
			var h: float = (70.0 + 50.0 * h01(k2 * 5 + l)) * sc
			var hold: Node3D = Node3D.new()
			root.add_child(hold)
			hold.position = Vector3(float(pl[0]), 0.0, float(pl[1]))
			hold.rotation_degrees = Vector3(0.0, yaw, 0.0)
			var lean: float = 0.35 * h
			var path: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3(lean * 0.3, h * 0.6, 0.0), Vector3(lean, h, 0.0)])
			put(tube_mesh(path, 1.6 * sc, 6), stalk, Vector3.ZERO, Vector3.ZERO, hold)
			put(_leaf_mesh(90.0 * sc, 44.0 * sc, 26.0 * sc), leaf_m, Vector3(lean, h, 0.0), Vector3(0.0, 0.0, 12.0), hold)

# THE CANOPY above: CLUMPS of leaves close round the trunks high up (single leaves scattered in the air read as floating;
# bare branches out to them read as poles), dark against the bright haze, lit through from behind
func _canopy() -> void:
	var leaf_m: StandardMaterial3D = mat(Color.WHITE, 0.6, 0.0, _leaf_tex(64, Color(0.12, 0.25, 0.08)))
	leaf_m.backlight_enabled = true
	leaf_m.backlight = Color(0.40, 0.50, 0.15)
	var lm: ArrayMesh = _leaf_mesh(70.0, 32.0, 18.0)
	for c in 70:
		var tr_: Array = TREES[c % TREES.size()]
		var trunk: Vector3 = Vector3(float(tr_[0]), 0.0, float(tr_[1]))
		var ang: float = TAU * h01(c * 3)
		var reach: float = 50.0 + 150.0 * h01(c * 3 + 1)
		var hy: float = 260.0 + 800.0 * h01(c * 3 + 2)
		var tip: Vector3 = trunk + Vector3(cos(ang) * reach, hy + 90.0, sin(ang) * reach * 0.6)
		for k in 30:
			var off: Vector3 = Vector3((h01(c * 97 + k) - 0.5) * 150.0, (h01(c * 89 + k) - 0.5) * 70.0, (h01(c * 83 + k) - 0.5) * 110.0)
			put(lm, leaf_m, tip + off, Vector3(-35.0 + 60.0 * h01(c * 5 + k), 360.0 * h01(c * 7 + k), -40.0 + 70.0 * h01(c * 11 + k)))

# THE MIDSTORY: young trees and shrubs between the great trunks, leaf masses at head height and above at every depth,
# so the forest is full between the floor and the canopy
func _midstory() -> void:
	var stem_m: StandardMaterial3D = mat(Color.WHITE, 0.9, 0.0, _bark(64, Color(0.34, 0.30, 0.22), 63), Vector3(1, 6, 1))
	var spots: Array = []
	for sp in 45:
		spots.append([(h01(sp * 3 + 500) - 0.5) * 1500.0, -260.0 - 1100.0 * h01(sp * 3 + 501)])
	for k in spots.size():
		var base: Vector3 = Vector3(float(spots[k][0]), 0.0, float(spots[k][1]))
		var h: float = 220.0 + 260.0 * h01(k * 5)
		var top: Vector3 = base + Vector3((h01(k * 7) - 0.5) * 60.0, h, 0.0)
		put(tube_mesh(PackedVector3Array([base, base.lerp(top, 0.5) + Vector3(10.0, 0.0, 0.0), top]), 5.0 + 3.0 * h01(k), 8), stem_m, Vector3.ZERO)
		var leaf_m: StandardMaterial3D = mat(Color.WHITE, 0.6, 0.0, _leaf_tex(32, Color(0.13, 0.30, 0.08).lerp(Color(0.24, 0.40, 0.10), h01(k * 3))))
		leaf_m.backlight_enabled = true
		leaf_m.backlight = Color(0.40, 0.50, 0.14)
		var lm: ArrayMesh = _leaf_mesh(60.0, 30.0, 14.0)
		for j in 60:
			var off: Vector3 = Vector3((h01(k * 97 + j) - 0.5) * 220.0, (h01(k * 89 + j) - 0.3) * 200.0, (h01(k * 83 + j) - 0.5) * 140.0)
			put(lm, leaf_m, top + off, Vector3(-30.0 + 60.0 * h01(k * 5 + j), 360.0 * h01(k * 7 + j), -40.0 + 70.0 * h01(k * 11 + j)))

# THE FALLEN LOG: bark, a mossy back, its cut end with growth rings and a bark rim; on it the bananas and two apples
func _log() -> void:
	var hold: Node3D = Node3D.new()
	root.add_child(hold)
	hold.position = LOG_C
	hold.rotation_degrees = Vector3(0.0, -LOG_YAW, 0.0)
	# (dark wet bark, deep moss: lit from behind, the paler log read washed out)
	var bark: StandardMaterial3D = mat(Color.WHITE, 0.9, 0.0, _bark(128, Color(0.22, 0.15, 0.10), 55), Vector3(4, 3, 1))
	cyl(LOG_R, LOG_R, LOG_LEN, bark, Vector3.ZERO, Vector3(0.0, 0.0, 90.0), hold, 32)
	# the cut end: a bark rim standing a little proud, the wood inside it
	var end_x: float = LOG_LEN * 0.5
	cyl(LOG_R + 0.8, LOG_R + 0.8, 3.0, bark, Vector3(end_x - 1.0, 0.0, 0.0), Vector3(0.0, 0.0, 90.0), hold, 32)
	var wood: StandardMaterial3D = mat(Color.WHITE, 0.8, 0.0, _rings(128))
	wood.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var face: QuadMesh = QuadMesh.new()
	face.size = Vector2(LOG_R * 2.0 - 2.0, LOG_R * 2.0 - 2.0)
	put(face, wood, Vector3(end_x + 0.6, 0.0, 0.0), Vector3(0.0, 90.0, 0.0), hold)
	# moss along its back, in cushions
	var moss: StandardMaterial3D = mat(Color.WHITE, 0.95, 0.0, tex_speckle(64, Color(0.16, 0.36, 0.06), 0.40, 41), Vector3(2, 2, 1))
	for m in 14:
		var mx: float = -LOG_LEN * 0.47 + LOG_LEN * 0.92 * float(m) / 13.0
		if absf(mx - BABY_S) < 24.0 or absf(mx - (BABY_S + 30.0)) < 20.0:
			continue
		# cushions of every size and shape over the top, never a row of equal pads (that read as a caterpillar)
		if h01(m + 90) < 0.35:
			continue
		_ell(Vector3(10.0 + 16.0 * h01(m), 4.0 + 5.0 * h01(m + 7), 8.0 + 12.0 * h01(m + 3)), moss,
			Vector3(mx + (h01(m + 11) - 0.5) * 14.0, LOG_R - 3.5, -10.0 + 14.0 * h01(m + 5)), hold, Vector3(0.0, 180.0 * h01(m + 13), 0.0))
	# the bunch of bananas beside where the baby sits, and two apples
	var banana_m: StandardMaterial3D = mat(Color.WHITE, 0.45)
	banana_m.vertex_color_use_as_albedo = true
	# A HAND OF BANANAS: five separate fingers fanning out of their crown, each curving up at its tip (they were laid side
	# by side and merged into one flat yellow wedge -- "what is that yellow triangle flag?", the user)
	var bm: ArrayMesh = _banana_mesh(32.0, 4.2)
	var crown: Vector3 = Vector3(BABY_S + 30.0, LOG_R + 3.0, -10.0)
	for bk in 5:
		var fan: float = -44.0 + 22.0 * float(bk)
		var fd: Vector3 = Vector3(cos(deg_to_rad(fan)), 0.0, -sin(deg_to_rad(fan)))
		put(bm, banana_m, crown + fd * 3.0 + Vector3(0.0, float(bk % 2) * 2.5, 0.0), Vector3(0.0, fan, 6.0 + 4.0 * float(bk % 2)), hold)
	cyl(2.6, 3.0, 9.0, mat(Color(0.32, 0.30, 0.14), 0.8), crown + Vector3(-4.0, 1.5, 0.0), Vector3(0.0, 0.0, 70.0), hold, 8)
	var apple_m: StandardMaterial3D = mat(Color.WHITE, 0.35, 0.0, tex_speckle(64, Color(0.70, 0.10, 0.08), 0.25, 13))
	apple_m.clearcoat_enabled = true
	apple_m.clearcoat = 0.5
	for ak in 2:
		var ac: Vector3 = Vector3(BABY_S - 34.0 - float(ak) * 15.0, LOG_R + 6.0, 2.0 + float(ak) * 6.0)
		_ell(Vector3(7.5, 6.8, 7.5), apple_m, ac, hold)
		cyl(0.6, 0.8, 4.0, mat(Color(0.25, 0.16, 0.08), 0.8), ac + Vector3(0.0, 7.5, 0.0), Vector3(0.0, 0.0, 12.0), hold, 6)

# --- the gorillas: live ---------------------------------------------------------------------------------------------

func _build_live() -> void:
	var fur: ShaderMaterial = _fur_mat(FUR)
	var torso: ShaderMaterial = _fur_mat(FUR, 1.0)
	var skin: StandardMaterial3D = mat(SKIN, 0.62)
	_build_adult(fur, torso, skin)
	_build_baby(_fur_mat(Color(0.15, 0.115, 0.09), 0.0, 40.0), skin)
	_build_fronds()
	_build_flies()
	_build_falling()

# a soft shadow lying on the floor under a body (a see-through live view casts none on the picture)
func _blob(parent: Node3D, radii: Vector2) -> MeshInstance3D:
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(0.02, 0.03, 0.01, 0.55))
	g.set_color(1, Color(0.02, 0.03, 0.01, 0.0))
	gt.gradient = g
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = gt
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q: QuadMesh = QuadMesh.new()
	q.size = radii * 2.0
	var mi: MeshInstance3D = put(q, m, Vector3(0.0, 0.6, 0.0), Vector3(-90.0, 0.0, 0.0), parent)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _build_adult(fur: Material, torso: Material, skin: Material) -> void:
	_adult = Node3D.new()
	root.add_child(_adult)
	_adult_shadow = _blob(root, Vector2(110.0, 46.0))
	_body = Node3D.new()
	_adult.add_child(_body)
	# THE BODY IN A KNUCKLE-WALKER'S STANCE: the shoulders well above the hips (the arms are the longer pair), the back
	# sloping down from the great hump over the shoulders to a small rump, the deep chest under the hump; the SILVER
	# SADDLE a gray stretch of the back's own fur, behind the hump
	_ell(Vector3(68.0, 40.0, 38.0), torso, Vector3(-4.0, 96.0, 0.0), _body, Vector3(0.0, 0.0, 22.0))
	_ell(Vector3(42.0, 44.0, 46.0), fur, Vector3(36.0, 118.0, 0.0), _body, Vector3(0.0, 0.0, 15.0))
	_ell(Vector3(34.0, 34.0, 36.0), fur, Vector3(26.0, 90.0, 0.0), _body)
	_ell(Vector3(31.0, 31.0, 31.0), fur, Vector3(-54.0, 78.0, 0.0), _body)
	_ell(Vector3(26.0, 25.0, 28.0), fur, Vector3(62.0, 110.0, 0.0), _body)
	# THE HEAD: small for the body, set LOW in front of the hump (its top under the shoulders' line), the crest rising at
	# its back; a broad, FLAT black face -- the heavy brow, small deep eyes, a wide flat nose, the jaw
	_head = Node3D.new()
	_body.add_child(_head)
	_head.position = Vector3(86.0, 110.0, 0.0)
	_ell(Vector3(24.0, 27.0, 24.0), fur, Vector3(0.0, 0.0, 0.0), _head)
	_ell(Vector3(22.0, 15.0, 10.0), fur, Vector3(-7.0, 21.0, 0.0), _head, Vector3(0.0, 0.0, -14.0))
	_ell(Vector3(8.0, 17.0, 18.5), skin, Vector3(18.0, -4.0, 0.0), _head)
	_ell(Vector3(7.0, 6.0, 20.0), skin, Vector3(20.0, 9.0, 0.0), _head)
	_ell(Vector3(4.5, 6.0, 10.0), skin, Vector3(24.5, -2.0, 0.0), _head)
	_ell(Vector3(8.5, 7.0, 15.0), skin, Vector3(18.5, -16.0, 0.0), _head)
	var eye_m: StandardMaterial3D = mat(Color(0.12, 0.07, 0.04), 0.15)
	for sd in [-1.0, 1.0]:
		sphere(2.5, eye_m, Vector3(23.5, 3.0, sd * 8.0), _head)
		sphere(1.6, mat(Color(0.02, 0.02, 0.02), 0.6), Vector3(28.6, -3.5, sd * 3.4), _head)
		_ell(Vector3(3.6, 5.5, 2.2), skin, Vector3(-4.0, 2.0, sd * 23.0), _head)
	# THE LIMBS: arms long and thick, legs short; each a bone pair solved to its planted hand or foot
	var arm_r: Array = [15.0, 13.5]
	var leg_r: Array = [15.0, 11.0]
	for spec in [[false, 1.0, 0.0], [true, 1.0, 0.25], [false, -1.0, 0.5], [true, -1.0, 0.75]]:
		var hand: bool = spec[0]
		var sd2: float = spec[1]
		var rr: Array = arm_r if hand else leg_r
		var up: MeshInstance3D = _capsule(float(rr[0]), (ARM_UP if hand else LEG_UP) + float(rr[0]) * 1.2, fur)
		var low: MeshInstance3D = _capsule(float(rr[1]), (ARM_FORE if hand else LEG_LOW) + float(rr[1]) * 1.2, fur)
		var end: MeshInstance3D = null
		if hand:
			end = _ell(Vector3(10.0, 8.0, 9.0), fur, Vector3.ZERO, _adult)
		else:
			end = _ell(Vector3(15.0, 5.5, 8.5), skin, Vector3.ZERO, _adult)
		_limbs.append({"hand": hand, "side": sd2, "phase": spec[2], "up": up, "low": low, "end": end})

func _capsule(r: float, h: float, m: Material) -> MeshInstance3D:
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = r
	cm.height = maxf(h, r * 2.0 + 0.1)
	cm.radial_segments = 16
	cm.rings = 6
	return put(cm, m, Vector3.ZERO, Vector3.ZERO, _adult if _baby == null else _baby)

# a bone from a to b: the capsule centered between them, its long axis along the bone
func _bone(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var y: Vector3 = (b - a).normalized()
	var ref: Vector3 = Vector3.BACK if absf(y.dot(Vector3.BACK)) < 0.9 else Vector3.RIGHT
	var x: Vector3 = ref.cross(y).normalized()
	var z: Vector3 = x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)

# TWO-BONE IK: the joint between root s and end t for bones la, lb, bending toward `hint` (fixed lengths: a target out
# of reach is pulled in along the line, never stretched)
func _ik(s: Vector3, t_: Vector3, la: float, lb: float, hint: Vector3) -> Vector3:
	var d: Vector3 = t_ - s
	var dist: float = clampf(d.length(), absf(la - lb) + 0.01, la + lb - 0.01)
	var dir: Vector3 = d.normalized()
	var cos_a: float = clampf((la * la + dist * dist - lb * lb) / (2.0 * la * dist), -1.0, 1.0)
	var perp: Vector3 = (hint - dir * hint.dot(dir)).normalized()
	return s + dir * (la * cos_a) + perp * (la * sqrt(1.0 - cos_a * cos_a))

func _build_baby(fur: Material, skin: Material) -> void:
	_baby = Node3D.new()
	root.add_child(_baby)
	# sitting on the log's top at BABY_S along it, facing us
	# (the log turned -LOG_YAW about y: its axis is (cos, 0, +sin))
	var dir: Vector3 = Vector3(cos(deg_to_rad(LOG_YAW)), 0.0, sin(deg_to_rad(LOG_YAW)))
	_baby.position = LOG_C + dir * BABY_S + Vector3(0.0, LOG_R - 2.0, 6.0)
	_baby.rotation_degrees = Vector3(0.0, -78.0, 0.0)        # its +x (forward) toward us
	_baby_body = Node3D.new()
	_baby.add_child(_baby_body)
	# A FLUFFY ROUND BODY (a pot belly, a rounded back), a big round head with a pale little face, large dark eyes, small
	# ears; thick soft limbs with hands and feet
	_ell(Vector3(16.0, 19.0, 15.5), fur, Vector3(-3.0, 20.0, 0.0), _baby_body)
	_ell(Vector3(11.0, 13.0, 13.0), fur, Vector3(4.0, 14.0, 0.0), _baby_body)
	_ell(Vector3(14.0, 10.0, 15.0), fur, Vector3(0.0, 5.0, 0.0), _baby_body)
	_ell(Vector3(9.0, 8.0, 17.0), fur, Vector3(-1.0, 31.0, 0.0), _baby_body)
	_baby_head = Node3D.new()
	_baby_body.add_child(_baby_head)
	_baby_head.position = Vector3(2.0, 46.0, 0.0)
	_ell(Vector3(14.0, 14.0, 13.5), fur, Vector3.ZERO, _baby_head)
	_ell(Vector3(9.0, 6.0, 9.0), fur, Vector3(-4.0, 10.0, 0.0), _baby_head)
	var face_m: StandardMaterial3D = mat(Color(0.24, 0.19, 0.17), 0.45)
	_ell(Vector3(6.0, 8.0, 9.5), face_m, Vector3(10.5, -3.0, 0.0), _baby_head)
	_ell(Vector3(4.0, 2.8, 10.5), face_m, Vector3(10.0, 4.0, 0.0), _baby_head)
	_ell(Vector3(4.2, 4.0, 5.5), face_m, Vector3(14.5, -5.5, 0.0), _baby_head)
	for sd in [-1.0, 1.0]:
		sphere(2.5, mat(Color(0.10, 0.06, 0.04), 0.12), Vector3(13.5, 1.5, sd * 4.8), _baby_head)
		sphere(0.8, glow(Color(0.95, 0.95, 0.9)), Vector3(15.6, 2.5, sd * 4.2), _baby_head)
		sphere(0.9, mat(Color(0.03, 0.03, 0.03), 0.6), Vector3(18.0, -5.0, sd * 1.8), _baby_head)
		_ell(Vector3(2.8, 4.0, 2.0), face_m, Vector3(-1.0, 1.5, sd * 13.8), _baby_head)
	# legs: thighs forward over the log, shins hanging down its front, feet with their soles toward us
	for sd2 in [-1.0, 1.0]:
		_baby_legs.append([Vector3(2.0, 7.0, sd2 * 8.0), _capsule(7.5, 24.0, fur), _capsule(5.8, 22.0, fur),
			_ell(Vector3(7.0, 3.4, 5.0), skin, Vector3.ZERO, _baby)])
	# arms: the left resting on its lap, the right reaching for the fruit now and then (_animate)
	var l_sh: Vector3 = Vector3(0.0, 32.0, 13.0)
	var l_hand: Vector3 = Vector3(17.0, 11.0, 7.0)
	var l_el: Vector3 = _ik(l_sh, l_hand, 13.0, 13.0, Vector3(-1.0, -0.2, 0.6))
	_bone(_capsule(6.2, 19.0, fur), l_sh, l_el)
	_bone(_capsule(5.4, 18.0, fur), l_el, l_hand)
	_ell(Vector3(5.0, 3.6, 4.6), skin, l_hand, _baby)
	_baby_arm = [Vector3(0.0, 32.0, -13.0), _capsule(6.2, 19.0, fur), _capsule(5.4, 18.0, fur), _ell(Vector3(5.0, 3.6, 4.6), skin, Vector3.ZERO, _baby)]
	# AN APPLE in its right hand, which it bites now and then (_animate)
	_baby_apple = Node3D.new()
	_baby.add_child(_baby_apple)
	var apple_m: StandardMaterial3D = mat(Color.WHITE, 0.35, 0.0, tex_speckle(64, Color(0.72, 0.10, 0.08), 0.25, 13))
	apple_m.clearcoat_enabled = true
	apple_m.clearcoat = 0.5
	_ell(Vector3(6.0, 5.5, 6.0), apple_m, Vector3(2.0, 2.0, 0.0), _baby_apple)
	cyl(0.5, 0.7, 3.5, mat(Color(0.25, 0.16, 0.08), 0.8), Vector3(2.0, 8.0, 0.0), Vector3.ZERO, _baby_apple, 6)
	# ITS SEAT: a soft contact shadow on the log's top where it sits, and on the log's face behind its legs
	var seat: MeshInstance3D = _blob(root, Vector2(24.0, 15.0))
	seat.position = _baby.position + Vector3(0.0, 1.6, -2.0)
	var log_n: Vector3 = Vector3(-sin(deg_to_rad(LOG_YAW)), 0.0, cos(deg_to_rad(LOG_YAW)))
	var face_shadow: MeshInstance3D = _blob(root, Vector2(22.0, 16.0))
	face_shadow.position = LOG_C + dir * BABY_S + log_n * (LOG_R + 0.8) + Vector3(0.0, 4.0, 0.0)
	face_shadow.rotation = Vector3(0.0, atan2(log_n.x, log_n.z), 0.0)

# THE HANGING FRONDS at the top corners, near us, nodding (live: they sway)
func _build_fronds() -> void:
	var fern_m: StandardMaterial3D = mat(Color.WHITE, 0.7)
	fern_m.vertex_color_use_as_albedo = true
	fern_m.backlight_enabled = true
	fern_m.backlight = Color(0.30, 0.40, 0.12)
	for spec in [[-300.0, 400.0, 240.0, 30.0], [310.0, 420.0, 240.0, 200.0]]:
		var hold: Node3D = Node3D.new()
		root.add_child(hold)
		hold.position = Vector3(float(spec[0]), float(spec[1]), float(spec[2]))
		put(_fern_mesh(7, 130.0, int(spec[3])), fern_m, Vector3.ZERO, Vector3(180.0, float(spec[3]), 0.0), hold)
		_fronds.append([hold, float(spec[3])])

# BUTTERFLIES: a blue morpho and an orange one, wings on pivots that flap (_animate), fluttering through the clearing
func _wing_tex(n: int, base: Color, edge: Color) -> ImageTexture:
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p: Vector2 = Vector2(float(x) / float(n), float(y) / float(n))
			# a rounded wing: inside an ellipse from the root (0, 0.5)
			var q: Vector2 = Vector2(p.x, (p.y - 0.5) * 1.6)
			var d: float = q.length()
			if d > 1.0 or p.x < 0.02:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var c: Color = base.lerp(base.lightened(0.35), 1.0 - d)
			if d > 0.80:
				c = edge
			elif absf(fposmod(atan2(q.y, q.x) * 3.0, 1.0) - 0.5) < 0.04:
				c = c.darkened(0.5)                   # the veins
			if d > 0.84 and d < 0.92 and fposmod(atan2(q.y, q.x) * 6.0, 1.0) < 0.35:
				c = Color(0.95, 0.92, 0.80)             # white spots in the dark border
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _build_flies() -> void:
	var looks: Array = [[Color(0.10, 0.45, 0.95), Color(0.04, 0.05, 0.08)], [Color(0.98, 0.55, 0.10), Color(0.10, 0.06, 0.04)]]
	for k in looks.size():
		var fly: Node3D = Node3D.new()
		root.add_child(fly)
		var wm: StandardMaterial3D = mat(Color.WHITE, 0.4, 0.0, _wing_tex(64, looks[k][0], looks[k][1]))
		wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		wm.emission_enabled = true
		wm.emission = Color(looks[k][0]) * 0.25
		_capsule_on(fly, 1.0, 9.0, mat(Color(0.06, 0.05, 0.05), 0.6), Vector3(90.0, 0.0, 0.0))
		var pivots: Array = []
		for sd in [-1.0, 1.0]:
			var pv: Node3D = Node3D.new()
			fly.add_child(pv)
			var q: QuadMesh = QuadMesh.new()
			q.size = Vector2(22.0, 19.0)
			# the wing lies along +x from the body, flat (its face up); the pivot turns it about the body's axis
			put(q, wm, Vector3(sd * 11.0, 0.0, 0.0), Vector3(-90.0, 0.0 if sd > 0.0 else 180.0, 0.0), pv)
			pivots.append([pv, sd])
		_flies.append([fly, pivots, k])

func _capsule_on(parent: Node3D, r: float, h: float, m: Material, rot: Vector3) -> MeshInstance3D:
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	return put(cm, m, Vector3.ZERO, rot, parent)

# LEAVES drifting down out of the canopy, turning over as they fall, in front of the forest
func _build_falling() -> void:
	var lm: ArrayMesh = _leaf_mesh(16.0, 8.0, 3.0)
	for k in 6:
		var m: StandardMaterial3D = mat(Color.WHITE, 0.6, 0.0, _leaf_tex(16, [Color(0.55, 0.45, 0.12), Color(0.25, 0.45, 0.10), Color(0.62, 0.32, 0.10)][k % 3]))
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_falling.append([put(lm, m, Vector3.ZERO), k])

# --- motion ---------------------------------------------------------------------------------------------------------

# where the walk starts and ends: the body just out of sight at each side, at the path's depth (the camera keeps its
# width: its fov is horizontal)
func _walk_span() -> Vector2:
	var half: float = (_eye().z - PATH_Z) * tan(deg_to_rad(_fov() * 0.5))
	return Vector2(-half - REACH_FRONT - 10.0, half + REACH_BACK + 10.0)

func _animate(delta: float) -> void:
	if _adult == null:
		return
	# THE SILVERBACK'S WALK: its place along the path, the gait's clock tied to the distance (so no foot slides)
	var span: Vector2 = _walk_span()
	var pass_t: float = (span.y - span.x) / SPEED
	var tp: float = fposmod(t + pass_t * 0.4, pass_t)
	var ax: float = span.x + SPEED * tp
	_adult.position = Vector3(ax, 0.0, PATH_Z)
	_adult_shadow.position = Vector3(ax, 0.6, PATH_Z)
	var cyc: float = (SPEED * tp) / (SPEED * GAIT_T)            # walk cycles since it set off
	var stride: float = SPEED * DUTY * GAIT_T                   # how far a planted foot travels back in the body's frame
	# the body: a slight rise and fall twice a cycle as the weight passes over the limbs
	_body.position = Vector3(0.0, 1.2 * sin(cyc * TAU * 2.0), 0.0)
	_body.rotation = Vector3.ZERO
	# the head: looking about, slowly; toward the little one as it passes
	var to_baby: float = clampf((_baby.position.x - ax) / 260.0, -1.0, 1.0)
	_head.rotation = Vector3(0.0, 0.35 * sin(t * 0.4) * (1.0 - absf(to_baby)) + 0.5 * to_baby * (1.0 - absf(to_baby)), 0.05 * sin(t * 0.7))
	for lb in _limbs:
		var hand: bool = lb["hand"]
		var sd: float = lb["side"]
		var p: float = fposmod(cyc + float(lb["phase"]), 1.0)
		var rel: float = 0.0
		var lift: float = 0.0
		if p < DUTY:
			rel = stride * 0.5 - stride * (p / DUTY)
		else:
			var q: float = (p - DUTY) / (1.0 - DUTY)
			rel = -stride * 0.5 + stride * smoothstep(0.0, 1.0, q)
			lift = sin(q * PI) * (9.0 if hand else 6.0)
		var bob: Vector3 = _body.position
		if hand:
			var sh: Vector3 = Vector3(48.0, 112.0, sd * 34.0) + bob
			var knuckle: Vector3 = Vector3(56.0 + rel, lift, sd * 36.0)
			var wrist: Vector3 = knuckle + Vector3(-2.0, 13.0, 0.0)
			var elbow: Vector3 = _ik(sh, wrist, ARM_UP, ARM_FORE, Vector3(-1.0, 0.0, sd * 0.35))
			_bone(lb["up"], sh, elbow)
			_bone(lb["low"], elbow, wrist)
			(lb["end"] as MeshInstance3D).position = knuckle + Vector3(0.0, 7.0, 0.0)
		else:
			var hip: Vector3 = Vector3(-52.0, 74.0, sd * 24.0) + bob
			var contact: Vector3 = Vector3(-40.0 + rel, lift, sd * 25.0)
			var ankle: Vector3 = contact + Vector3(-7.0, 9.0, 0.0)
			var knee: Vector3 = _ik(hip, ankle, LEG_UP, LEG_LOW, Vector3(1.0, 0.1, sd * 0.3))
			_bone(lb["up"], hip, knee)
			_bone(lb["low"], knee, ankle)
			(lb["end"] as MeshInstance3D).position = contact + Vector3(4.0, 5.0, 0.0)
	# THE BABY: breathing; its head following the big one as it passes, eased; now and then reaching for the fruit
	var want: float = 0.0
	want = clampf((ax - _baby.position.x) / 300.0, -1.0, 1.0) * 0.9
	_baby_body.scale = Vector3(1.0, 1.0 + 0.012 * sin(t * 2.4), 1.0)
	_baby_head.rotation = Vector3(0.0, -_look, 0.10 * sin(t * 0.9) + 0.05 * sin(t * 2.3))
	# its right hand brings the apple up to its mouth for a bite every few seconds, and down to its lap again
	var bite_u: float = fposmod(t, 5.5)
	var up: float = smoothstep(0.0, 0.6, bite_u - 2.5) * (1.0 - smoothstep(1.6, 2.2, bite_u - 2.5))
	var sh2: Vector3 = _baby_arm[0]
	var rest: Vector3 = Vector3(17.0, 12.0, -8.0)
	var mouth: Vector3 = Vector3(18.0, 37.0, -3.0)
	var hand2: Vector3 = rest.lerp(mouth, up)
	var el2: Vector3 = _ik(sh2, hand2, 13.0, 13.0, Vector3(-1.0, -0.5, -0.6))
	_bone(_baby_arm[1], sh2, el2)
	_bone(_baby_arm[2], el2, hand2)
	(_baby_arm[3] as MeshInstance3D).position = hand2
	_baby_apple.position = hand2 + Vector3(3.0, 3.0, 0.0)
	# chewing: the head nods a little while the apple is up; legs swinging, one after the other
	_baby_head.rotation.z += 0.10 * up * (0.5 + 0.5 * sin(t * 9.0)) - 0.06 * up
	for k3 in _baby_legs.size():
		var lg: Array = _baby_legs[k3]
		var hipb: Vector3 = lg[0]
		var swing: float = 0.35 * sin(t * 2.2 + float(k3) * PI)
		var knee2: Vector3 = Vector3(19.0, 8.0, hipb.z * 1.25)
		var ankle2: Vector3 = knee2 + Vector3(sin(swing) * 20.0, -cos(swing) * 20.0, 0.0)
		_bone(lg[1], hipb, knee2)
		_bone(lg[2], knee2, ankle2)
		(lg[3] as MeshInstance3D).position = ankle2 + Vector3(3.5, -2.5, 0.0)
	# the butterflies: wandering loops through the clearing in front of the forest, wings beating
	for fl in _flies:
		var node: Node3D = fl[0]
		var sk: float = float(fl[2])
		var tt: float = t * (0.22 + 0.05 * sk) + sk * 2.7
		# (inside the frame and nearer than the walk: at the scene's depth they were small and mostly off the screen)
		var pos: Vector3 = Vector3(130.0 * sin(tt) + 30.0 * sin(tt * 3.1), 150.0 + 70.0 * sin(tt * 1.7 + sk) + 12.0 * sin(t * 6.0 + sk),
			200.0 + 60.0 * sin(tt * 1.3 + sk * 1.9))
		var vel: Vector3 = Vector3(130.0 * cos(tt) + 93.0 * cos(tt * 3.1), 0.0, 78.0 * cos(tt * 1.3 + sk * 1.9))
		node.position = pos
		# its body (local z) along its flight; the wings beating about a raised angle, so from the side their faces show
		node.rotation = Vector3(0.0, atan2(vel.x, vel.z), 0.0)
		var flap: float = 0.95 + 0.55 * sin(t * (15.0 + 3.0 * sk))
		for pv in fl[1]:
			(pv[0] as Node3D).rotation = Vector3(0.0, 0.0, flap * float(pv[1]))
	# the baby watches the nearer butterfly whenever the big one is away from it
	var fly0: Vector3 = (_flies[0][0] as Node3D).position
	var to_fly: float = clampf((fly0.x - _baby.position.x) / 300.0, -1.0, 1.0) * 0.8
	var near_big: float = 1.0 - smoothstep(150.0, 320.0, absf(ax - _baby.position.x))
	_look = lerpf(_look, lerpf(to_fly, want, near_big), 1.0 - exp(-delta * 2.0))
	_baby_head.rotation.y = -_look
	# leaves drifting down, tumbling, and starting again from the canopy
	for lf in _falling:
		var mi: MeshInstance3D = lf[0]
		var ks: float = float(lf[1])
		var period: float = 9.0 + 3.0 * h01(int(ks) + 300)
		var u: float = fposmod(t + ks * 1.7, period) / period
		mi.position = Vector3(-300.0 + 600.0 * h01(int(ks) + 310) + 40.0 * sin(t * 1.3 + ks), 520.0 * (1.0 - u), 120.0 + 120.0 * h01(int(ks) + 320))
		mi.rotation = Vector3(t * 2.0 + ks, t * 0.7, sin(t * 3.0 + ks) * 0.8)
	# the fronds nodding
	for k in _fronds.size():
		var fh: Node3D = _fronds[k][0]
		fh.rotation = Vector3(0.04 * sin(t * 0.7 + float(k)), 0.0, 0.05 * sin(t * 0.55 + float(k) * 2.0))

# --- over the scene: light and the name ------------------------------------------------------------------------------

func _paint_top(full: Vector2, bottom: float) -> void:
	# SHAFTS OF LIGHT from the low sun, slanting down through the canopy, breathing; motes drifting in them
	var floor_y: float = bottom
	for k in 4:
		var x0: float = full.x * (0.38 + 0.17 * float(k))
		var a: float = 0.055 + 0.03 * sin(t * 0.3 + float(k) * 1.3)
		var w: float = 34.0 + 20.0 * h01(k + 9)
		cv.draw_polygon(PackedVector2Array([Vector2(x0, 0.0), Vector2(x0 + w, 0.0), Vector2(x0 - 170.0 + w * 2.2, floor_y), Vector2(x0 - 170.0, floor_y)]),
			PackedColorArray([Color(1.0, 0.94, 0.72, a), Color(1.0, 0.94, 0.72, a), Color(1.0, 0.94, 0.72, 0.0), Color(1.0, 0.94, 0.72, 0.0)]))
	for k2 in 22:
		var u: float = fmod(t * (0.015 + 0.015 * h01(k2)) + h01(k2 + 3), 1.0)
		var p: Vector2 = Vector2(full.x * (0.25 + 0.6 * h01(k2 + 40)) + sin(t * 0.4 + float(k2)) * 16.0 - u * 90.0, floor_y * (1.0 - u))
		cv.draw_circle(p, 1.2, Color(1.0, 0.95, 0.75, 0.45 * sin(u * PI)))
	title("Gorilla", "Eat apples and rescue the lost baby gorillas", Color(0.98, 0.86, 0.42), Color(0.08, 0.12, 0.04),
		Color(0.9, 0.9, 0.4, 0.22))

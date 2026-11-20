extends "res://scripts/menu_poster.gd"

# LIGHTHOUSE'S OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): night at sea. A
# lighthouse on a rocky headland, its lamp turning; a small sailing boat out on the swell, its lantern lit,
# making for home under a moon behind thin cloud.
#
# THE BEAMS TURN IN 3-D (the user: "a correct 3d turn not a fade out-in effect"): the lamp throws two
# opposite cones of light that turn about the tower's vertical axis, and every point of each cone is
# projected through a camera in front of the scene -- so a beam reaching side-on is long and level, one
# turning away shortens toward the horizon and passes behind the lantern room, and one sweeping toward us
# grows wide and short and floods the lamp with glare. Where a beam crosses the clouds they light up, and
# its light lies on the water beneath it.
# Made up, never the board: the menu also opens mid-game.

const TURN: float = 0.62            # radians a second
const FOCAL: float = 900.0          # the camera's distance in front of the lamp, in screen units
const REACH: float = 2600.0         # how far a beam reaches, in the same units
const CONE: float = 0.075           # a beam's half-angle (radians)
const EYE_D: float = 500.0          # the tower's eye distance, in screen units: a ring's depth is height / EYE_D
const WARM: Color = Color(1.0, 0.93, 0.70)

var _hz: float = 0.0                # the horizon, cached for the tower's rings while it is drawn
var _sky: Control = null
var _sea: Control = null
var _glints: MultiMeshInstance2D = null

# THE SEA'S GLINTS ON THE GPU (they were 144 lines drawn every frame): the foam on the crests (kind 0), the moon's path
# (1) and the lamp's reflection (2), each line a square stretched between its two ends, worked out here from t by the
# same formulas, in the same order and colors. custom: (kind, number) -- see _build_glints
const GLINTS: String = """shader_type canvas_item;
uniform float t = 0.0;
uniform float full_x = 680.0;
uniform float full_y = 1200.0;
uniform float bottom = 800.0;
uniform float moon_x = 150.0;
uniform float horizon = 0.0;
uniform vec2 lamp = vec2(0.0);
uniform vec3 warm = vec3(1.0, 0.93, 0.70);
varying vec4 v_col;
// menu_poster.gd's h01, the same bits
float h01(int i) {
	uint x = uint(i) * 0x9E3779B1u;
	x ^= x >> 16u;
	x *= 0x85EBCA6Bu;
	x ^= x >> 13u;
	x *= 0xC2B2AE35u;
	x ^= x >> 16u;
	return float(x & 0xffffffu) / 16777216.0;
}
void vertex() {
	int kind = int(INSTANCE_CUSTOM.x + 0.5);
	int ki = int(INSTANCE_CUSTOM.y + 0.5);
	float k = float(ki);
	vec2 a;
	vec2 b;
	float w;
	if (kind == 0) {
		// flecks of foam on the nearer crests
		float u2 = 0.35 + 0.65 * h01(ki * 7 + 300);
		float y2 = horizon + pow(u2, 1.9) * (full_y - horizon);
		float x2 = mod(h01(ki * 7 + 301) * full_x + t * 6.0 * u2, full_x);
		a = vec2(x2, y2);
		b = vec2(x2 + 6.0 + 10.0 * u2, y2 - 1.0);
		w = 1.5;
		float al = 0.5 + 0.5 * sin(t * 1.3 + k * 2.1);
		v_col = vec4(0.85, 0.90, 1.0, 0.25 * al * u2);
	} else if (kind == 1) {
		// the moon's path: a broadening column of glints, the near ones long and bright, shimmering
		float u3 = h01(ki * 3 + 400);
		float y3 = horizon + 3.0 + pow(u3, 1.6) * (bottom + 30.0 - horizon);
		float spread = 8.0 + (y3 - horizon) * 0.32;
		float x3 = moon_x + (h01(ki * 3 + 401) - 0.5) * spread * 2.0 * (0.6 + 0.4 * sin(t * 0.7 + k));
		float a3 = 0.35 + 0.65 * abs(sin(t * (0.8 + h01(ki)) + k * 1.3));
		float len3 = 3.0 + u3 * 16.0;
		a = vec2(x3 - len3, y3);
		b = vec2(x3 + len3, y3);
		w = 1.0 + u3 * 1.6;
		v_col = vec4(0.92, 0.94, 1.0, 0.50 * a3 * (1.0 - u3 * 0.4));
	} else {
		// the lamp's reflection: a warm column broken by the swell, under the lighthouse
		float y4 = horizon + 4.0 + k * 7.0;
		float wob = sin(t * 2.0 + k * 1.3) * (3.0 + k);
		a = vec2(lamp.x - 8.0 - k + wob, y4);
		b = vec2(lamp.x + 8.0 + k + wob, y4);
		w = 1.5;
		v_col = vec4(warm, 0.22 * (1.0 - k / 14.0));
	}
	vec2 ab = b - a;
	vec2 n = normalize(vec2(-ab.y, ab.x));
	VERTEX = a + ab * (VERTEX.x + 0.5) + n * w * VERTEX.y;
}
void fragment() {
	COLOR = v_col;
}
"""
var _land: Control = null
var _beam_back: Control = null
var _beam_front: Control = null
var _beam_mi: Array = []          # [back 0, back 1, front 0, front 1]: each beam's cone as one mesh, projected on the GPU

# A BEAM'S CONE ON THE GPU (it was 54 quads a beam, each projected and hulled every frame): the same 18 slices of
# three quads -- across, upright, the brighter core -- built once as a mesh in the beam's own terms (VERTEX.x the
# fraction of the reach, VERTEX.y the signed share of the radius, UV.x which cross-section) and projected here as
# _proj does. The triangles keep the drawing's order, so they blend as it did
const BEAM: String = """shader_type canvas_item;
uniform vec3 dir = vec3(1.0, 0.0, 0.0);
uniform vec3 side = vec3(0.0, 0.0, 1.0);
uniform vec3 up = vec3(0.0, 1.0, 0.0);
uniform float reach = 100.0;
uniform vec2 lamp = vec2(0.0);
uniform float focal = 900.0;
uniform float tan_cone = 0.075;
void vertex() {
	float s = VERTEX.x * reach;
	float r = 6.0 + s * tan_cone;
	vec3 axis = UV.x < 0.5 ? side : up;
	vec3 p = dir * s + axis * r * VERTEX.y;
	float k = focal / max(focal - p.z, 40.0);
	VERTEX = lamp + vec2(p.x, -p.y) * k;
}
"""

# THE STILL PARTS DRAWN ONCE (2026-11-19: the poster redrew every layer, stars, moon and rock included, every frame --
# 14 fps on a mid-range phone): the sky's gradient and galaxy, the moon, are cached layers (menu_poster.gd
# `cached_layer`), redrawn only when the layout changes; between them, in the same order as before, the live ones
var _stars: Control = null
var _star_discs: MultiMeshInstance2D = null
var _sea_still: Control = null
var _glare: ColorRect = null
var _lamp_clip: Control = null
var _lamp: ColorRect = null

const LAMP: String = """shader_type canvas_item;
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	// a bright core easing out into the glass's own light: no edge to be cut by the glazing
	COLOR = vec4(1.0, 1.0, 0.97, 1.0 - smoothstep(0.30, 1.0, d));
}
"""

# THE GLARE as a beam sweeps toward the camera, on the GPU: it was 30 discs (radius gr (1 - k / 30), each `a`), up to
# 150 across, and a white core over them -- the stack is 1 - (1 - a)^n for the n discs over a pixel. The square is
# 2 gr across; `core` is the core's radius over gr
const GLARE: String = """shader_type canvas_item;
uniform float a = 0.018;
uniform float core = 0.2;
uniform vec3 warm = vec3(1.0, 0.85, 0.55);
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float n = clamp(ceil(30.0 * (1.0 - d)), 0.0, 30.0);
	vec4 c = vec4(warm, 1.0 - pow(1.0 - a, n));
	float aa = max(fwidth(d), 1e-4);
	float k = clamp((core - d) / aa + 0.5, 0.0, 1.0);
	COLOR = mix(c, vec4(1.0), k);
}
"""
var _swell: MeshInstance2D = null

# THE SWELL ON THE GPU: 22 rows, each a dark trough line and a lit crest line, as _draw_sea drew them with antialiased
# polylines every frame -- now one mesh built for the layout (_build_swell), each vertex lifted by the same wave here.
# UV.x = row + 0.5 for a crest line, UV.y = the signed distance from the line's center in units (for its soft edge)
const SWELL: String = """shader_type canvas_item;
uniform float t = 0.0;
varying float v_d;
varying float v_half;
void vertex() {
	float r = floor(UV.x);
	bool crest = fract(UV.x) > 0.25;
	float u = r / 21.0;
	float amp = 0.8 + u * 8.0;
	float wl = 0.07 - 0.055 * u;
	float x = VERTEX.x;
	float w = sin(x * wl + t * (0.6 + 0.35 * u) + r * 1.7) + 0.35 * sin(x * wl * 2.3 - t * 0.9 + r);
	VERTEX.y += w * amp + UV.y;
	v_d = UV.y;
	v_half = crest ? (1.0 + 1.8 * u) * 0.5 : (2.0 + 5.0 * u) * 0.5;
}
void fragment() {
	float aa = max(fwidth(v_d), 1e-4);
	COLOR.a *= clamp((v_half - abs(v_d)) / aa + 0.5, 0.0, 1.0);
}
"""
var _moon: Control = null
var _clouds: MultiMeshInstance2D = null

# THE CLOUD BANKS ON THE GPU: each ellipse an instance; INSTANCE_CUSTOM = (bank's start x, its speed, the wrap width,
# the ellipse's offset from the bank's center) -- the bank's center drifts and wraps exactly as _draw_clouds had it
const CLOUDS: String = """shader_type canvas_item;
uniform float t = 0.0;
void vertex() {
	float cx = mod(INSTANCE_CUSTOM.x + t * INSTANCE_CUSTOM.y, INSTANCE_CUSTOM.z) - 230.0;
	VERTEX.x += cx + INSTANCE_CUSTOM.w;
}
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float aa = max(fwidth(d), 1e-4);
	COLOR.a *= clamp((1.0 - d) / aa + 0.5, 0.0, 1.0);
}
"""
var _for_bottom: float = -2.0
var _land_live: Control = null
var _buildings: Control = null
var _land_live2: Control = null

func _setup() -> void:
	_sky = cached_layer(func(d: Control) -> void: _draw_sky(d))
	_star_discs = sprinkle(_star_list())          # the stars: one batched draw (menu_poster.gd `sprinkle`)
	_stars = _layer(func(d: Control) -> void: _draw_stars(d))
	_moon = cached_layer(func(d: Control) -> void: _draw_moon(d))
	_clouds = MultiMeshInstance2D.new()           # the clouds: one batched draw, drifting on the GPU (CLOUDS)
	var cm: ShaderMaterial = ShaderMaterial.new()
	var csh: Shader = Shader.new()
	csh.code = CLOUDS
	cm.shader = csh
	_clouds.material = cm
	add_child(_clouds)
	_build_clouds()
	_beam_back = _beam_layer()
	_sea_still = cached_layer(func(d: Control) -> void: _draw_sea_still(d))
	_swell = MeshInstance2D.new()                  # the swell: one mesh, waved on the GPU (SWELL)
	var sm: ShaderMaterial = ShaderMaterial.new()
	var sh: Shader = Shader.new()
	sh.code = SWELL
	sm.shader = sh
	_swell.material = sm
	add_child(_swell)
	_glints = MultiMeshInstance2D.new()
	var gm2: ShaderMaterial = ShaderMaterial.new()
	var gsh2: Shader = Shader.new()
	gsh2.code = GLINTS
	gm2.shader = gsh2
	_glints.material = gm2
	add_child(_glints)
	_build_glints()
	_sea = _layer(func(d: Control) -> void: _draw_sea(d))
	_land = cached_layer(func(d: Control) -> void: _draw_land(d, 0))
	_land_live = _layer(func(d: Control) -> void: _draw_land(d, 1))
	_buildings = cached_layer(func(d: Control) -> void: _draw_land(d, 2))
	# THE LAMP inside the glazing: a white disc clipped to the glass, under the near rail (as part of the glare, drawn
	# over everything, it spilled forward over the rail and the platform -- the user, 2026-11-20)
	_lamp_clip = Control.new()
	_lamp_clip.clip_contents = true
	_lamp_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lamp_clip)
	_lamp = ColorRect.new()
	_lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lm: ShaderMaterial = ShaderMaterial.new()
	var lsh: Shader = Shader.new()
	lsh.code = LAMP
	lm.shader = lsh
	_lamp.material = lm
	_lamp_clip.add_child(_lamp)
	_land_live2 = _layer(func(d: Control) -> void: _draw_land(d, 3))
	_beam_front = _beam_layer()
	_glare = ColorRect.new()                       # the glare: one square computing its 30 discs (GLARE)
	_glare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glm: ShaderMaterial = ShaderMaterial.new()
	var glsh: Shader = Shader.new()
	glsh.code = GLARE
	glm.shader = glsh
	_glare.material = glm
	add_child(_glare)

func _layer(fn: Callable) -> Control:
	var c: Control = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.draw.connect(fn.bind(c))
	add_child(c)
	return c

func _tick(_delta: float) -> void:
	(_swell.material as ShaderMaterial).set_shader_parameter("t", t)
	(_glints.material as ShaderMaterial).set_shader_parameter("t", t)
	_place_glare()
	_light_clouds()
	_place_beams()
	for c in [_stars, _sea, _land_live, _land_live2]:
		(c as Control).queue_redraw()
	if absf(scene_bottom - _for_bottom) > 0.5:
		_for_bottom = scene_bottom
		sprinkle_set(_star_discs, _star_list())
		_build_swell()
		_build_glints()
		_build_clouds()
		for c2 in [_sky, _moon, _sea_still, _land, _buildings]:
			(c2 as Control).queue_redraw()

func _geom() -> Dictionary:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var top: float = 230.0 if mobile else 150.0
	var horizon: float = top + (bottom - top) * 0.48
	var base: Vector2 = Vector2(full.x * 0.76, horizon + (bottom - horizon) * 0.20)
	var th: float = (base.y - top) * 0.78
	return {"full": full, "bottom": bottom, "top": top, "horizon": horizon, "base": base, "th": th,
		"lamp": base + Vector2(0.0, -th - 21.0)}      # the lantern room's center

# a point of a beam in 3-D (x right, y up, z toward the camera, the lamp at the origin) on the screen
func _proj(lamp: Vector2, p: Vector3) -> Vector2:
	var k: float = FOCAL / maxf(FOCAL - p.z, 40.0)
	return lamp + Vector2(p.x, -p.y) * k

# --- the sky: gradient, stars, the moon, clouds (lit where a beam crosses them) ------------------------

func _draw_sky(d: Control) -> void:
	var g: Dictionary = _geom()
	var full: Vector2 = g["full"]
	var horizon: float = g["horizon"]
	_vg(d, Rect2(0.0, 0.0, full.x, horizon + 2.0), Color(0.02, 0.03, 0.08), Color(0.12, 0.17, 0.30))
	# a faint band of the galaxy, and stars of three sizes, the brightest with a soft cross
	for k in 30:
		var u: float = float(k) / 29.0
		_ell(d, Vector2(full.x * (1.1 - 1.2 * u), horizon * (0.08 + 0.55 * u)), 70.0, 22.0, Color(0.55, 0.60, 0.80, 0.025))

# the stars, twinkling: [center, radius, color, speed, phase, a0, a1] for `sprinkle` -- alpha 0.20 + 0.55 * tw * h
func _star_list() -> Array:
	var g: Dictionary = _geom()
	var full: Vector2 = g["full"]
	var horizon: float = g["horizon"]
	var out: Array = []
	for k in 170:
		var sp: Vector2 = Vector2(h01(k * 5 + 1) * full.x, h01(k * 5 + 2) * horizon * 0.95)
		out.append([sp, 0.5 + 1.3 * h01(k * 5 + 3), Color(0.92, 0.94, 1.0), 0.3 + 0.4 * h01(k + 9), float(k), 0.20, 0.55 * h01(k * 5 + 4)])
	return out

# the brightest stars' soft crosses (live; their discs are in `_star_discs`)
func _draw_stars(d: Control) -> void:
	var g: Dictionary = _geom()
	var full: Vector2 = g["full"]
	var horizon: float = g["horizon"]
	for k in 170:
		var big: float = h01(k * 5 + 3)
		if big > 0.93:
			var sp: Vector2 = Vector2(h01(k * 5 + 1) * full.x, h01(k * 5 + 2) * horizon * 0.95)
			var tw: float = 0.5 + 0.5 * sin(t * (0.3 + 0.4 * h01(k + 9)) + float(k))
			d.draw_line(sp - Vector2(5, 0), sp + Vector2(5, 0), Color(0.9, 0.93, 1.0, 0.35 * tw), 1.0)
			d.draw_line(sp - Vector2(0, 5), sp + Vector2(0, 5), Color(0.9, 0.93, 1.0, 0.35 * tw), 1.0)

# THE MOON: a corona, the disc darkening toward its limb, its seas, a bright rim on the lit side (still)
func _draw_moon(d: Control) -> void:
	var g: Dictionary = _geom()
	var full: Vector2 = g["full"]
	var horizon: float = g["horizon"]
	var moon: Vector2 = Vector2(full.x * 0.22, float(g["top"]) + (horizon - float(g["top"])) * 0.30)
	var mr: float = 34.0
	for k in 26:
		d.draw_circle(moon, 160.0 - float(k) * 5.6, Color(0.78, 0.84, 1.0, 0.010))
	for k in 6:
		d.draw_circle(moon, mr * (1.6 - 0.1 * float(k)), Color(0.90, 0.92, 1.0, 0.03))
	d.draw_circle(moon, mr, Color(0.70, 0.71, 0.68))
	for k in 16:
		var f: float = float(k + 1) / 16.0
		d.draw_circle(moon + Vector2(-5, -6) * f, mr * (1.0 - 0.45 * f), Color(0.70, 0.71, 0.68).lerp(Color(0.98, 0.97, 0.92), f))
	var seas: Array = [Vector3(0.22, -0.30, 0.30), Vector3(-0.18, -0.05, 0.24), Vector3(0.30, 0.18, 0.20), Vector3(-0.32, 0.30, 0.14), Vector3(0.02, 0.42, 0.12)]
	for sea in seas:
		for j in 3:
			d.draw_circle(moon + Vector2(sea.x, sea.y) * mr, mr * sea.z * (1.0 - 0.25 * float(j)), Color(0.58, 0.60, 0.62, 0.22))
	for cr in [Vector3(-0.42, -0.36, 0.06), Vector3(0.10, -0.55, 0.05), Vector3(0.50, 0.40, 0.05)]:
		var cc: Vector2 = moon + Vector2(cr.x, cr.y) * mr
		d.draw_arc(cc, mr * cr.z, 0.0, TAU, 12, Color(0.55, 0.56, 0.56, 0.6), 1.5)
		d.draw_arc(cc, mr * cr.z, PI * 1.1, PI * 1.9, 8, Color(1, 1, 1, 0.5), 1.0)
	d.draw_arc(moon, mr - 1.0, PI * 0.75, PI * 1.6, 24, Color(1.0, 1.0, 0.96, 0.6), 2.0, true)

# THE CLOUDS: long flat banks (puffs read as bubble wrap) -- wide soft ellipses layered, dark-bellied,
# their upper edge silvered toward the moon, drifting; the beams warm them where they pass. Built for the layout
# (the GPU drifts them); each bank's silver edge takes the beams' warmth in _tick (_light_clouds)
func _build_clouds() -> void:
	var g: Dictionary = _geom()
	var full: Vector2 = g["full"]
	var lamp: Vector2 = g["lamp"]
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = 3 * 4 * 10
	var i: int = 0
	for row in 3:
		var cy: float = lamp.y - 70.0 - float(row) * 48.0
		for k in 4:
			var x0: float = float(k) * 230.0 + float(row) * 90.0
			var spd: float = 4.0 + 2.0 * float(row)
			var bw: float = 150.0 + 60.0 * h01(k + row * 7)
			for j in 9:
				var f: float = float(j) / 8.0
				var rx: float = bw * (0.55 - 0.04 * float(j))
				var ry: float = 9.0 + 4.0 * sin(f * PI)
				mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(rx, ry), 0.0, Vector2(0.0, cy + 4.0 * sin(f * 5.0 + float(k)))))
				mm.set_instance_color(i, Color(0.10, 0.12, 0.20, 0.10))
				mm.set_instance_custom_data(i, Color(x0, spd, full.x + 460.0, (f - 0.5) * bw * 0.6))
				i += 1
			mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(bw * 0.42, 5.0), 0.0, Vector2(0.0, cy - 6.0)))
			mm.set_instance_color(i, Color(0.50, 0.55, 0.72, 0.10))
			mm.set_instance_custom_data(i, Color(x0, spd, full.x + 460.0, 0.0))
			i += 1
	_clouds.multimesh = mm

# each bank's silver edge, warmed where a beam crosses it (the bank's center as _draw_clouds placed it)
func _light_clouds() -> void:
	var g: Dictionary = _geom()
	var full: Vector2 = g["full"]
	var lamp: Vector2 = g["lamp"]
	var segs: Array = _beam_screen_segments(lamp)
	var mm: MultiMesh = _clouds.multimesh
	var i: int = 0
	for row in 3:
		var cy: float = lamp.y - 70.0 - float(row) * 48.0
		for k in 4:
			var cx: float = fmod(float(k) * 230.0 + float(row) * 90.0 + t * (4.0 + 2.0 * float(row)), full.x + 460.0) - 230.0
			var lit: float = _beam_light_at(Vector2(cx, cy), segs)
			i += 9
			mm.set_instance_color(i, Color(0.50, 0.55, 0.72, 0.10).lerp(Color(0.90, 0.84, 0.70, 0.16), lit * 0.6))
			i += 1
	(_clouds.material as ShaderMaterial).set_shader_parameter("t", t)

# the two beams as screen segments (from the lamp out), for lighting the clouds and the water
func _beam_screen_segments(lamp: Vector2) -> Array:
	var out: Array = []
	for b in 2:
		var a: float = t * TURN + PI * float(b)
		var dir: Vector3 = Vector3(cos(a), -0.012, sin(a))
		var far: Vector3 = dir * _reach_for(dir)
		out.append([_proj(lamp, Vector3.ZERO), _proj(lamp, far), absf(cos(a))])
	return out

func _reach_for(dir: Vector3) -> float:
	# toward the camera a beam is cut where it would pass the lens
	if dir.z > 0.0:
		return minf(REACH, (FOCAL * 0.80) / dir.z)
	return REACH

func _beam_light_at(p: Vector2, segs: Array) -> float:
	var best: float = 0.0
	for sg in segs:
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		var ab: Vector2 = b - a
		var u: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.0, 1.0)
		var dist: float = p.distance_to(a + ab * u)
		best = maxf(best, (1.0 - smoothstep(20.0, 110.0, dist)) * (1.0 - u * 0.7) * float(sg[2]))
	return best

# --- the beams: cones turning in 3-D, projected -------------------------------------------------------

# `front`: the beams heading toward the camera (drawn over the tower); the others are drawn behind it
func _beam_mesh() -> ArrayMesh:
	var verts: PackedVector2Array = PackedVector2Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var cols: PackedColorArray = PackedColorArray()
	var steps: int = 18
	for i in steps:
		var f0: float = float(i) / float(steps)
		var f1: float = float(i + 1) / float(steps)
		var fade: float = pow(1.0 - float(i) / float(steps), 1.6)
		# across, upright, the core: each slice's quads in the drawing's order, fading out along the reach
		for q in [[0.0, 1.0, Color(WARM, 0.22 * fade)], [1.0, 1.0, Color(WARM, 0.22 * fade)], [1.0, 0.35, Color(1, 1, 1, 0.14 * fade)]]:
			var ax: float = float(q[0])
			var m: float = float(q[1])
			var corners: Array = [Vector2(f0, m), Vector2(f1, m), Vector2(f1, -m), Vector2(f0, -m)]
			for idx in [0, 1, 2, 0, 2, 3]:
				verts.append(corners[idx])
				uvs.append(Vector2(ax, 0.0))
				cols.append(q[2])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	var am: ArrayMesh = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am

func _beam_layer() -> Control:
	var c: Control = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	if _beam_mi.is_empty() or _beam_mi.size() == 2:
		var sh: Shader = Shader.new()
		sh.code = BEAM
		var mesh: ArrayMesh = _beam_mesh() if _beam_mi.is_empty() else (_beam_mi[0] as MeshInstance2D).mesh
		for _b in 2:
			var mi: MeshInstance2D = MeshInstance2D.new()
			mi.mesh = mesh
			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = sh
			mi.material = mat
			c.add_child(mi)
			_beam_mi.append(mi)
	return c

# each frame: which beams point away (drawn behind the sea and the land) and which toward us, and where they point
func _place_beams() -> void:
	var g: Dictionary = _geom()
	var lamp: Vector2 = g["lamp"]
	for b in 2:
		var a: float = t * TURN + PI * float(b)
		var dir: Vector3 = Vector3(cos(a), -0.012, sin(a)).normalized()
		var side: Vector3 = Vector3(-dir.z, 0.0, dir.x)
		var up: Vector3 = side.cross(dir).normalized()
		var front: bool = dir.z > 0.0
		for slot in 2:
			var mi: MeshInstance2D = _beam_mi[slot * 2 + b]
			mi.visible = (slot == 1) == front
			if mi.visible:
				var mat: ShaderMaterial = mi.material
				mat.set_shader_parameter("dir", dir)
				mat.set_shader_parameter("side", side)
				mat.set_shader_parameter("up", up)
				mat.set_shader_parameter("reach", _reach_for(dir))
				mat.set_shader_parameter("lamp", lamp)
				mat.set_shader_parameter("focal", FOCAL)
				mat.set_shader_parameter("tan_cone", tan(CONE))

# (the glare over the front beams: _glare, _place_glare)

# THE GLARE: as a beam sweeps toward the camera the lamp floods with light -- compact and smooth, many faint discs, the
# glare widening only so far (the GLARE shader on `_glare`, placed and sized here each frame)
func _place_glare() -> void:
	var lamp: Vector2 = _geom()["lamp"]
	var face: float = 0.0
	for b in 2:
		face = maxf(face, sin(t * TURN + PI * float(b)))
	var glare: float = pow(maxf(face, 0.0), 6.0)
	var gr: float = 40.0 + 110.0 * glare
	_glare.position = lamp - Vector2(gr, gr)
	_glare.size = Vector2(gr, gr) * 2.0
	var m: ShaderMaterial = _glare.material
	m.set_shader_parameter("a", 0.018 + 0.030 * glare)
	m.set_shader_parameter("core", 0.0)              # the lamp itself is _lamp, inside the glass
	# the lamp: as big as it was, clipped to the lantern room's glazing (the geometry of _tower)
	_hz = _geom()["horizon"]
	var g2: Dictionary = _geom()
	var base: Vector2 = g2["base"]
	var th: float = g2["th"]
	var lr_r: float = th * 0.14 * 0.55
	var lr_y0: float = base.y - th - 5.0
	var lr_y1: float = lr_y0 - 28.0
	var k: float = _ring_k(lr_y0)
	var top: float = lr_y1 + lr_r * _ring_k(lr_y1) + 3.0
	var bot: float = lr_y0 - 4.0 + lr_r * k
	_lamp_clip.position = Vector2(base.x - lr_r * 0.92, top)
	_lamp_clip.size = Vector2(lr_r * 1.84, maxf(bot - top, 1.0))
	var cr: float = minf((8.0 + 6.0 * glare) * 1.6, (bot - top) * 0.62)
	_lamp.position = lamp - Vector2(cr, cr) - _lamp_clip.position
	_lamp.size = Vector2(cr, cr) * 2.0
	m.set_shader_parameter("warm", Vector3(WARM.r, WARM.g, WARM.b))

# --- the sea: perspective swell, the moon's glittering path, the beams' light on the water, the boat ----

# the sea's gradient and the haze on the horizon (still)
func _draw_sea_still(d: Control) -> void:
	var g: Dictionary = _geom()
	var full: Vector2 = g["full"]
	var horizon: float = g["horizon"]
	_vg(d, Rect2(0.0, horizon, full.x, full.y - horizon), Color(0.11, 0.15, 0.27), Color(0.01, 0.02, 0.05))
	# a haze lying on the horizon
	_vg(d, Rect2(0.0, horizon - 14.0, full.x, 28.0), Color(0.20, 0.25, 0.40, 0.0), Color(0.20, 0.25, 0.40, 0.35))

# THE SWELL in perspective: each row a band -- its trough a shade darker, its crest catching the light. Built once
# for the layout; the SWELL shader moves it (trough then crest, row by row, as they were drawn)
func _build_swell() -> void:
	var g: Dictionary = _geom()
	var full: Vector2 = g["full"]
	var horizon: float = g["horizon"]
	var verts: PackedVector2Array = PackedVector2Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var cols: PackedColorArray = PackedColorArray()
	var idx: PackedInt32Array = PackedInt32Array()
	var rows: int = 22
	for r in rows:
		var u: float = float(r) / float(rows - 1)
		var y: float = horizon + pow(u, 1.9) * (full.y - horizon)
		for line in 2:
			var crest: bool = line == 1
			var half: float = ((1.0 + 1.8 * u) if crest else (2.0 + 5.0 * u)) * 0.5 + 1.0    # a unit more for the edge
			var yc: float = y if crest else y + 3.0 + 5.0 * u
			var col: Color = Color(0.55, 0.66, 0.90, 0.05 + 0.13 * u) if crest else Color(0.0, 0.01, 0.04, 0.20 + 0.15 * u)
			var ux: float = float(r) + (0.5 if crest else 0.0)
			var first: int = verts.size()
			for k in 81:
				var x: float = full.x * float(k) / 80.0
				verts.append(Vector2(x, yc))
				uvs.append(Vector2(ux, -half))
				cols.append(col)
				verts.append(Vector2(x, yc))
				uvs.append(Vector2(ux, half))
				cols.append(col)
			for k in 80:
				var a: int = first + k * 2
				idx.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m: ArrayMesh = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_swell.mesh = m

func _build_glints() -> void:
	var g: Dictionary = _geom()
	var full: Vector2 = g["full"]
	var horizon: float = g["horizon"]
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.mesh = q
	# only each line's kind and number go over (the instance data is half precision): the shader works out the rest
	var kinds: Array = [[0, 40], [1, 90], [2, 14]]
	mm.instance_count = 40 + 90 + 14
	var i: int = 0
	for kn in kinds:
		for k in int(kn[1]):
			mm.set_instance_transform_2d(i, Transform2D.IDENTITY)
			mm.set_instance_custom_data(i, Color(float(kn[0]), float(k), 0.0, 0.0))
			i += 1
	mm.custom_aabb = AABB(Vector3(-100.0, horizon - 100.0, -1.0), Vector3(full.x + 200.0, full.y - horizon + 200.0, 2.0))
	_glints.multimesh = mm
	var mat: ShaderMaterial = _glints.material
	mat.set_shader_parameter("full_x", full.x)
	mat.set_shader_parameter("full_y", full.y)
	mat.set_shader_parameter("bottom", float(g["bottom"]))
	mat.set_shader_parameter("moon_x", full.x * 0.22)
	mat.set_shader_parameter("horizon", horizon)
	mat.set_shader_parameter("lamp", g["lamp"])
	mat.set_shader_parameter("warm", Vector3(WARM.r, WARM.g, WARM.b))

func _draw_sea(d: Control) -> void:
	var g: Dictionary = _geom()
	var full: Vector2 = g["full"]
	var horizon: float = g["horizon"]
	# (the foam, the moon's path and the lamp's reflection: _glints, under this layer)
	var lamp: Vector2 = g["lamp"]
	# where the beams fall on the water: a long warm streak along each beam's line on the sea
	for sg in _beam_screen_segments(lamp):
		var p0: Vector2 = sg[0]
		var p1: Vector2 = sg[1]
		var strength: float = float(sg[2])
		for k in 10:
			var u5: float = 0.2 + 0.8 * float(k) / 9.0
			var px: float = lerpf(p0.x, p1.x, u5)
			if px < -40.0 or px > full.x + 40.0:
				continue
			_ell(d, Vector2(px, horizon + 6.0 + 8.0 * u5), 40.0 * u5 + 10.0, 3.0, Color(WARM, 0.08 * strength * (1.0 - u5 * 0.6)))
	_boat(d, g)

# THE BOAT: a little cutter -- a planked hull shaded from its lit side, a pale gunwale, a seamed mainsail
# and jib lit by the moon, stays and a pennant, its lantern at the bow; a wake, and
# the lantern's light trembling on the water
func _boat(d: Control, g: Dictionary) -> void:
	var full: Vector2 = g["full"]
	var horizon: float = g["horizon"]
	var bottom: float = g["bottom"]
	var bc: Vector2 = Vector2(full.x * 0.30 + 12.0 * sin(t * 0.17), lerpf(horizon, bottom, 0.58) + 5.0 * sin(t * 1.05))
	var rock: float = 0.07 * sin(t * 1.05 + 0.7)
	for k in 6:
		var u: float = fmod(t * 0.4 + float(k) / 6.0, 1.0)
		_ell(d, bc + Vector2(-56.0 - u * 100.0, 16.0 + u * 5.0), 12.0 + u * 34.0, 2.5, Color(0.82, 0.88, 1.0, 0.24 * (1.0 - u)))
	_ell(d, bc + Vector2(0.0, 22.0), 70.0, 7.0, Color(0, 0, 0, 0.35))
	d.draw_set_transform(bc, rock, Vector2.ONE)
	# the hull, planked, lighter toward the moon (the left)
	var sheer: PackedVector2Array = PackedVector2Array()
	for k in 15:
		var u2: float = float(k) / 14.0
		sheer.append(Vector2(lerpf(-64.0, 66.0, u2), -6.0 - 5.0 * sin(u2 * PI) + 10.0 * pow(absf(u2 - 0.5) * 2.0, 3.0)))
	var keel: PackedVector2Array = PackedVector2Array()
	for k in 15:
		var u3: float = 1.0 - float(k) / 14.0
		keel.append(Vector2(lerpf(-48.0, 56.0, u3), 20.0 + 5.0 * sin(u3 * PI)))
	var hull: PackedVector2Array = sheer + keel
	var cols: PackedColorArray = PackedColorArray()
	for p in hull:
		cols.append(Color(0.30, 0.18, 0.11).lerp(Color(0.10, 0.06, 0.04), clampf((p.x + 64.0) / 130.0, 0.0, 1.0)))
	d.draw_polygon(hull, cols)
	for k in 3:
		var pl: PackedVector2Array = PackedVector2Array()
		for j in 15:
			var a: Vector2 = sheer[j]
			var b: Vector2 = keel[14 - j]
			pl.append(a.lerp(b, 0.25 + 0.22 * float(k)))
		d.draw_polyline(pl, Color(0, 0, 0, 0.35), 1.0, true)
	d.draw_polyline(sheer, Color(0.82, 0.74, 0.58), 3.0, true)
	# mast, boom, stays
	d.draw_line(Vector2(0, -8), Vector2(0, -112), Color(0.26, 0.19, 0.13), 3.5)
	d.draw_line(Vector2(0, -18), Vector2(50, -16), Color(0.26, 0.19, 0.13), 3.0)
	d.draw_line(Vector2(0, -110), Vector2(64, -8), Color(0.60, 0.58, 0.55, 0.7), 1.0)
	d.draw_line(Vector2(0, -110), Vector2(-60, -6), Color(0.60, 0.58, 0.55, 0.7), 1.0)
	# the mainsail, bellied, its seams and the moonlight on its luff
	var main: PackedVector2Array = PackedVector2Array([Vector2(4, -106), Vector2(4, -20), Vector2(48, -18), Vector2(30, -62)])
	d.draw_polygon(main, PackedColorArray([Color(0.98, 0.97, 0.92), Color(0.86, 0.85, 0.82), Color(0.62, 0.62, 0.64), Color(0.80, 0.80, 0.80)]))
	for k in 4:
		var f: float = float(k + 1) / 5.0
		d.draw_line(Vector2(4, lerpf(-106.0, -20.0, f)), Vector2(lerpf(30.0, 48.0, f), lerpf(-62.0, -18.0, f)), Color(0.45, 0.45, 0.48, 0.35), 1.0)
	# the jib
	d.draw_polygon(PackedVector2Array([Vector2(-4, -100), Vector2(-4, -14), Vector2(-52, -10)]),
		PackedColorArray([Color(0.88, 0.87, 0.82), Color(0.66, 0.66, 0.64), Color(0.55, 0.55, 0.56)]))
	# the pennant at the masthead, streaming
	var fl: float = sin(t * 4.0) * 3.0
	d.draw_colored_polygon(PackedVector2Array([Vector2(0, -112), Vector2(18, -109 + fl), Vector2(0, -105)]), Color(0.80, 0.20, 0.18))
	# the lantern at the bow
	var lant: Vector2 = Vector2(60, -14)
	for k in 14:
		d.draw_circle(lant, 40.0 * (1.0 - float(k) / 14.0), Color(1.0, 0.80, 0.45, 0.035))
	d.draw_rect(Rect2(lant - Vector2(3, 4), Vector2(6, 8)), Color(1.0, 0.92, 0.66))
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in 7:
		var wob: float = 3.0 * sin(t * 2.2 + float(k))
		_ell(d, bc + Vector2(58.0 + wob, 28.0 + float(k) * 7.0), 7.0 - float(k) * 0.7, 1.5, Color(1.0, 0.82, 0.48, 0.34 - 0.045 * float(k)))

# --- the headland and the tower -------------------------------------------------------------------------

func _draw_land(d: Control, part: int) -> void:
	var g: Dictionary = _geom()
	var full: Vector2 = g["full"]
	var horizon: float = g["horizon"]
	var base: Vector2 = g["base"]
	var water: float = horizon + (float(g["bottom"]) - horizon) * 0.62
	# drawn in four parts, in this order (menu_poster.gd `cached_layer`): 0 the rock (still), 1 the grass, the stair,
	# the boulders and the water over the rock's foot (live), 2 the cottage and the tower (still), 3 the smoke and the
	# grass at the tower's foot (live) -- the live parts never cross a still part drawn after them
	# THE HEADLAND in layered rock: back mass, then strata of faceted slabs, each lit on the face toward the
	# moon and dark on the other, cracks between them; grass on top; boulders and foam at its foot, in the water
	var rock: PackedVector2Array = PackedVector2Array([Vector2(full.x * 0.42, water), Vector2(full.x * 0.49, horizon + 44.0),
		Vector2(full.x * 0.57, horizon + 16.0), Vector2(full.x * 0.64, horizon + 2.0), Vector2(base.x - 42.0, base.y - 6.0),
		Vector2(base.x + 48.0, base.y - 2.0), Vector2(full.x, base.y + 12.0), Vector2(full.x, water + 34.0),
		Vector2(full.x * 0.90, water + 22.0), Vector2(full.x * 0.80, water + 36.0), Vector2(full.x * 0.70, water + 20.0),
		Vector2(full.x * 0.60, water + 30.0), Vector2(full.x * 0.50, water + 12.0)])
	if part == 0:
		d.draw_colored_polygon(rock, Color(0.07, 0.07, 0.10))
		# THE CLIFF FACE in vertical facets, crest to waterline: each irregular, tilted toward or away from the
		# moon so its light differs from its neighbor's, cracks between them (rows of ledges read as a tiled roof)
		var xs: Array = []
		var fx0: float = full.x * 0.45
		var fk: int = 0
		while fx0 < full.x + 30.0:
			xs.append(fx0)
			fx0 += 34.0 + 30.0 * h01(fk + 600)
			fk += 1
		for i2 in xs.size() - 1:
			var x0: float = xs[i2]
			var x1: float = xs[i2 + 1]
			var t0: float = _rock_top(rock, clampf(x0, full.x * 0.42, full.x)) + 3.0
			var t1: float = _rock_top(rock, clampf(x1, full.x * 0.42, full.x)) + 3.0
			var lean: float = (h01(i2 + 700) - 0.5) * 18.0
			var facet: PackedVector2Array = PackedVector2Array([Vector2(x0, t0), Vector2(x1, t1), Vector2(x1 + lean, water + 10.0), Vector2(x0 + lean * 0.6, water + 10.0)])
			var tilt: float = h01(i2 + 710)
			var shade: Color = Color(0.08, 0.08, 0.12).lerp(Color(0.20, 0.22, 0.32), tilt * clampf(1.2 - (x0 - full.x * 0.45) / full.x * 1.6, 0.3, 1.0))
			d.draw_polygon(facet, PackedColorArray([shade.lightened(0.10), shade.lightened(0.06), shade.darkened(0.30), shade.darkened(0.30)]))
			d.draw_line(Vector2(x0, t0), Vector2(x0 + lean * 0.6, water + 10.0), Color(0.02, 0.02, 0.04, 0.8), 2.0)
			# a ledge or two across it, catching the light
			for j2 in 2:
				var ly: float = lerpf(maxf(t0, t1) + 20.0, water - 6.0, 0.30 + 0.40 * float(j2) + 0.1 * h01(i2 * 3 + j2))
				d.draw_line(Vector2(x0 + 4.0, ly), Vector2(x1 - 4.0, ly + 3.0), Color(0.34, 0.37, 0.50, 0.45), 1.5)
		# VOLUME: rough texture over the faces (moonlit flecks and dark pits), deepening shade toward the water,
		# and the top a grassy plateau, a band following the crest
		for k in 260:
			var tx: float = lerpf(full.x * 0.44, full.x, h01(k * 3 + 800))
			var ty: float = lerpf(_rock_top(rock, tx) + 10.0, water + 8.0, h01(k * 3 + 801))
			if h01(k * 3 + 802) > 0.5:
				d.draw_circle(Vector2(tx, ty), 1.2 + 1.5 * h01(k + 803), Color(0.40, 0.44, 0.58, 0.20))
			else:
				d.draw_circle(Vector2(tx, ty), 1.5 + 2.0 * h01(k + 804), Color(0.0, 0.0, 0.02, 0.35))
		for k in 6:
			var dy: float = float(k) / 6.0
			var band_k: PackedVector2Array = PackedVector2Array()
			for j in 25:
				var bx: float = lerpf(full.x * 0.44, full.x, float(j) / 24.0)
				band_k.append(Vector2(bx, lerpf(_rock_top(rock, bx), water + 10.0, 0.55 + 0.075 * float(k))))
			d.draw_polyline(band_k, Color(0.0, 0.0, 0.03, 0.10 + 0.02 * dy), 26.0, true)
		var plateau: PackedVector2Array = PackedVector2Array()
		var plateau_b: PackedVector2Array = PackedVector2Array()
		for j in 31:
			var px2: float = lerpf(full.x * 0.56, full.x, float(j) / 30.0)
			var py2: float = _rock_top(rock, px2)
			plateau.append(Vector2(px2, py2))
			plateau_b.append(Vector2(px2, py2 + 10.0 + 4.0 * sin(float(j) * 1.3)))
		plateau_b.reverse()
		d.draw_colored_polygon(plateau + plateau_b, Color(0.12, 0.17, 0.12))
		d.draw_polyline(plateau, Color(0.30, 0.40, 0.30), 2.0, true)
		# the moonlit crest line along the top
		d.draw_polyline(PackedVector2Array([rock[0], rock[1], rock[2], rock[3], rock[4], rock[5], rock[6]]), Color(0.40, 0.44, 0.58), 2.5, true)
	if part == 1:
		# grass on the top, leaning in the breeze
		for k in 60:
			var u2: float = float(k) / 59.0
			var gx: float = lerpf(full.x * 0.58, full.x, u2)
			var gy: float = _rock_top(rock, gx) + 1.0
			var lean: float = 3.0 + 2.0 * sin(t * 1.3 + float(k) * 0.4)
			d.draw_line(Vector2(gx, gy), Vector2(gx + lean, gy - 6.0 - 5.0 * h01(k + 400)), Color(0.20, 0.30, 0.18), 1.5)
		# the stair path up from the water to the tower, with its rail
		for k in 9:
			var f: float = float(k) / 8.0
			var sp: Vector2 = Vector2(lerpf(full.x * 0.56, base.x - 30.0, f), lerpf(water - 4.0, base.y - 4.0, f))
			d.draw_line(sp, sp + Vector2(16.0, 0.0), Color(0.42, 0.42, 0.48), 3.0)
			d.draw_line(sp + Vector2(0, 3), sp + Vector2(16.0, 3.0), Color(0.03, 0.03, 0.05), 2.0)
		d.draw_line(Vector2(full.x * 0.56, water - 22.0), Vector2(base.x - 30.0, base.y - 22.0), Color(0.30, 0.30, 0.34), 1.5)
		for k in 5:
			var f2: float = float(k) / 4.0
			var rp: Vector2 = Vector2(lerpf(full.x * 0.56, base.x - 30.0, f2), lerpf(water - 4.0, base.y - 4.0, f2))
			d.draw_line(rp, rp + Vector2(0.0, -18.0), Color(0.30, 0.30, 0.34), 1.5)
		# boulders at the waterline, moonlit tops (their feet in the water, below)
		for k in 9:
			var bp: Vector2 = Vector2(lerpf(full.x * 0.45, full.x * 0.98, float(k) / 8.0), water + 18.0 + 14.0 * h01(k + 50))
			var rr: float = 14.0 + 12.0 * h01(k)
			_ell(d, bp + Vector2(4, 4), rr, rr * 0.55, Color(0, 0, 0, 0.4))
			_ell(d, bp, rr, rr * 0.6, Color(0.09, 0.09, 0.13))
			_ell(d, bp + Vector2(-rr * 0.2, -rr * 0.25), rr * 0.6, rr * 0.22, Color(0.30, 0.33, 0.44))
			_ell(d, bp + Vector2(-rr * 0.3, -rr * 0.32), rr * 0.25, rr * 0.08, Color(0.60, 0.64, 0.78))
		# THE SEA OVER THE ROCK'S FOOT: below the waterline the rock and the boulders sink into the water --
		# a band of the sea's own color laid over them, deepening downward, its surface a wavy lit line (the
		# rock below the waterline showed whole, so the sea read as clear and the tide pools floated)
		var surf: float = water + 22.0
		var band: PackedVector2Array = PackedVector2Array()
		for k in 33:
			var bx: float = lerpf(full.x * 0.36, full.x, float(k) / 32.0)
			band.append(Vector2(bx, surf + 3.0 * sin(bx * 0.05 + t * 1.2)))
		var lip: PackedVector2Array = band.duplicate()
		band.append(Vector2(full.x, full.y))
		band.append(Vector2(full.x * 0.36, full.y))
		var cols: PackedColorArray = PackedColorArray()
		for k in band.size():
			cols.append(Color(0.06, 0.09, 0.18, 0.78) if k < 33 else Color(0.01, 0.02, 0.05, 0.96))
		d.draw_polygon(band, cols)
		d.draw_polyline(lip, Color(0.70, 0.78, 0.95, 0.35), 2.0, true)
		# the swell carries on across it
		for r in 5:
			var wy: float = surf + 14.0 + float(r) * float(r) * 6.0
			var wl: PackedVector2Array = PackedVector2Array()
			for k in 25:
				var wx: float = lerpf(full.x * 0.36, full.x, float(k) / 24.0)
				wl.append(Vector2(wx, wy + sin(wx * (0.05 - 0.006 * float(r)) + t * 0.9 + float(r)) * (2.0 + float(r))))
			d.draw_polyline(wl, Color(0.55, 0.66, 0.90, 0.10 + 0.03 * float(r)), 1.5 + float(r) * 0.4, true)
		for k in 12:
			var u4: float = fmod(t * 0.32 + float(k) / 12.0 + 0.37 * float(k % 3), 1.0)
			var fx: float = lerpf(full.x * 0.44, full.x * 0.99, float(k) / 11.0)
			_ell(d, Vector2(fx, surf + 2.0 + 4.0 * h01(k + 90) - u4 * 4.0), 18.0 + 22.0 * u4, 3.5 + 2.0 * u4, Color(0.88, 0.92, 1.0, 0.45 * sin(u4 * PI)))
	# THE KEEPER'S COTTAGE: stone walls lit and shaded, a slate roof, a chimney with a thread of smoke, and
	# a window that is a lit ROOM -- mullions, a curtain half drawn, a lamp's glow spilling out
	# ON THE TOP, beside the tower (on the slope's edge it hung out over the rock), on a stone foundation
	var cot_x: float = base.x - 112.0
	var cot_ground: float = maxf(_rock_top(rock, cot_x), _rock_top(rock, cot_x + 64.0))
	var cot: Rect2 = Rect2(cot_x, cot_ground - 36.0, 64.0, 34.0)
	if part == 2:
		d.draw_rect(Rect2(cot.position.x - 4.0, cot.end.y - 2.0, cot.size.x + 8.0, cot_ground - cot.end.y + 10.0), Color(0.16, 0.16, 0.20))
		d.draw_rect(cot, Color(0.20, 0.19, 0.22))
		d.draw_rect(Rect2(cot.position, Vector2(cot.size.x * 0.4, cot.size.y)), Color(0.28, 0.27, 0.32))
		for k in 4:
			d.draw_line(Vector2(cot.position.x, cot.position.y + 8.0 * float(k + 1)), Vector2(cot.end.x, cot.position.y + 8.0 * float(k + 1)), Color(0, 0, 0, 0.2), 1.0)
		var roof: PackedVector2Array = PackedVector2Array([cot.position + Vector2(-8, 0), Vector2(cot.end.x + 8, cot.position.y), Vector2(cot.get_center().x + 6.0, cot.position.y - 22.0), Vector2(cot.get_center().x - 6.0, cot.position.y - 22.0)])
		d.draw_colored_polygon(roof, Color(0.12, 0.12, 0.16))
		d.draw_line(roof[0], roof[3], Color(0.40, 0.42, 0.55), 1.5)
		d.draw_rect(Rect2(cot.end.x - 18.0, cot.position.y - 28.0, 8.0, 14.0), Color(0.18, 0.16, 0.18))
		_window(d, Rect2(cot.position + Vector2(14, 10), Vector2(14, 14)))
		_tower(d, g, false)
	if part == 3:
		for k in 5:
			var su: float = fmod(t * 0.25 + float(k) / 5.0, 1.0)
			d.draw_circle(Vector2(cot.end.x - 14.0 - su * 30.0, cot.position.y - 30.0 - su * 30.0), 3.0 + su * 8.0, Color(0.6, 0.62, 0.70, 0.12 * (1.0 - su)))
		_tower(d, g, true)
		# the gallery's near rail, over the lamp (_lamp) -- the geometry of _tower
		_hz = horizon
		var th2: float = g["th"]
		var top_y2: float = base.y - th2
		_rail(d, base.x, top_y2 - 5.0, th2 * 0.14 * 0.98 * 0.96, 14.0, true)

# a lit window: a warm room behind glass -- brighter low down where the lamp is, a curtain half drawn,
# mullions, a sill, and its glow on the wall around it
func _window(d: CanvasItem, r: Rect2) -> void:
	for k in 10:
		d.draw_circle(r.get_center(), r.size.x * (1.8 - 0.13 * float(k)), Color(1.0, 0.78, 0.42, 0.025))
	_vg(d, r, Color(0.95, 0.66, 0.32), Color(1.0, 0.90, 0.62))
	d.draw_colored_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x * 0.35, 0.0), r.position + Vector2(r.size.x * 0.18, r.size.y)]), Color(0.55, 0.16, 0.12, 0.9))
	d.draw_rect(r, Color(0.10, 0.08, 0.07), false, 1.5)
	d.draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Color(0.10, 0.08, 0.07), 1.2)
	d.draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Color(0.10, 0.08, 0.07), 1.2)
	d.draw_line(Vector2(r.position.x - 2.0, r.end.y + 1.0), Vector2(r.end.x + 2.0, r.end.y + 1.0), Color(0.55, 0.52, 0.50), 2.0)

func _rock_top(rock: PackedVector2Array, x: float) -> float:
	# the top edge runs from rock[0] through rock[6]
	for i in 6:
		var a: Vector2 = rock[i]
		var b: Vector2 = rock[i + 1]
		if x >= a.x and x <= b.x:
			return lerpf(a.y, b.y, (x - a.x) / maxf(b.x - a.x, 0.001))
	return rock[6].y

# THE TOWER IN 3-D (the user: "the very top is flat and the very bottom is flat. it doesnt connect to the
# surface it stands on"): a round tower is rings, and a ring is an ellipse whose depth depends on where it is
# against the eye -- below the horizon we look down on it and its near side curves DOWN, above it we look up
# at it and its near side curves UP (`_ring_y`). So every band edge, the plinth, the gallery (its UNDERSIDE
# shows, we are below it), the lantern room and the dome's base follow those curves; and the tower stands on
# a stone plinth seated in the turf, the grass growing up round its foot, a contact shadow behind.

# how much a ring at screen height y is opened up: + below the horizon (seen from above), - above it
func _ring_k(y: float) -> float:
	return clampf((y - _hz) / EYE_D, -0.34, 0.34)

# the screen point of a ring of radius r at height y, at angle a (0 the right side, PI/2 the near side)
func _ring_pt(cx: float, y: float, r: float, a: float) -> Vector2:
	return Vector2(cx + cos(a) * r, y + sin(a) * r * _ring_k(y))

# the front half of a ring, right to left, as screen points
func _ring_front(cx: float, y: float, r: float, n: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in n + 1:
		pts.append(_ring_pt(cx, y, r, PI * float(k) / float(n)))
	return pts

# one stretch of a round surface between two rings (y0 below, y1 above), shaded as a cylinder: lit on the
# moon's side (the left), dark round the right
func _drum(d: CanvasItem, cx: float, y0: float, r0: float, y1: float, r1: float, col: Color, lit: float = 0.15, dark: float = 0.75) -> void:
	var n: int = 12
	for k in n:
		var a0: float = PI * float(k) / float(n)
		var a1: float = PI * float(k + 1) / float(n)
		var q: PackedVector2Array = PackedVector2Array([_ring_pt(cx, y0, r0, a0), _ring_pt(cx, y0, r0, a1), _ring_pt(cx, y1, r1, a1), _ring_pt(cx, y1, r1, a0)])
		# a0 = 0 is the right (dark) side, PI the left (lit) side
		var u: float = 1.0 - (a0 + a1) * 0.5 / PI
		_poly(d, q, col.darkened(lerpf(lit, dark, pow(u, 1.3))))

# `grass_only`: just the grass at its foot (live); otherwise everything else (still)
func _tower(d: Control, g: Dictionary, grass_only: bool) -> void:
	var base: Vector2 = g["base"]
	var th: float = g["th"]
	_hz = g["horizon"]
	var cx: float = base.x
	var bw: float = th * 0.21
	var tw: float = th * 0.14
	var top_y: float = base.y - th
	var pr: float = bw * 0.62
	var ph: float = th * 0.045
	if not grass_only:
		# --- THE FOOT: a mound of turf the tower stands IN (the headland's top is only a crest line, so the
		# tower stood on a line), seen a little from above; a contact shadow on it; a stone plinth; grass round it
		var mound: PackedVector2Array = PackedVector2Array()
		for k in 33:
			var am: float = TAU * float(k) / 32.0
			var rr: float = pr * (1.9 + 0.15 * sin(am * 3.0 + 1.0))
			mound.append(Vector2(cx + cos(am) * rr, base.y + 1.0 + sin(am) * maxf(7.0, rr * 0.22)))
		_poly(d, mound, Color(0.12, 0.17, 0.12))
		var mound_lit: PackedVector2Array = PackedVector2Array()
		for k in 17:
			mound_lit.append(mound[16 + k])
		d.draw_polyline(mound_lit, Color(0.26, 0.36, 0.26), 2.0, true)
		_ell(d, Vector2(cx + bw * 0.25, base.y + 2.0), bw * 0.95, maxf(4.0, bw * 0.95 * _ring_k(base.y)) + 2.0, Color(0.0, 0.0, 0.02, 0.45))
		_drum(d, cx, base.y + 2.0, pr, base.y - ph, pr, Color(0.50, 0.50, 0.54), 0.10, 0.70)
		# its courses and blocks, following the curve
		for row in 2:
			var ry: float = base.y + 2.0 - (ph + 2.0) * float(row + 1) / 2.0
			if row == 0:
				d.draw_polyline(_ring_front(cx, ry, pr, 16), Color(0.0, 0.0, 0.0, 0.30), 1.0, true)
			for b in 5:
				var a: float = PI * (float(b) + 0.5 * float(row % 2) + 0.3) / 5.0
				var p0: Vector2 = _ring_pt(cx, ry, pr, a)
				d.draw_line(p0, p0 + Vector2(0.0, (ph + 2.0) * 0.5), Color(0.0, 0.0, 0.0, 0.25), 1.0)
		# its top: a ring of stone seen from above (we are above it), a lit lip
		var top_ring: PackedVector2Array = PackedVector2Array()
		for k in 33:
			top_ring.append(_ring_pt(cx, base.y - ph, pr, TAU * float(k) / 32.0))
		_poly(d, top_ring, Color(0.60, 0.60, 0.64))
		d.draw_polyline(_ring_front(cx, base.y - ph, pr, 16), Color(0.80, 0.80, 0.86), 1.5, true)
	if grass_only:
		# grass in front of the plinth's foot, leaning in the same breeze as the headland's
		for k in 22:
			var ag: float = PI * (0.04 + 0.92 * float(k) / 21.0)
			var gp: Vector2 = _ring_pt(cx, base.y + 2.0, pr * (1.02 + 0.5 * h01(k + 950)), ag) + Vector2(0.0, 1.0 + 4.0 * h01(k + 960))
			var lean: float = 3.0 + 2.0 * sin(t * 1.3 + float(k) * 0.4)
			d.draw_line(gp, gp + Vector2(lean, -5.0 - 4.0 * h01(k + 970)), Color(0.20, 0.30, 0.18), 1.5)
		return
	# SEEN FROM BELOW (the lantern is far above the horizon): the deck's top cannot be seen, and the platform hides
	# the foot of everything standing on it -- so the far rail, the lantern room and the dome are drawn FIRST, then the
	# platform's underside over them, the shaft over the underside's far half, the platform's near edge, the near rail.
	# (Drawn the other way round, the shaft hid the whole underside and a deck seen from above sat on top: the user,
	# 2026-11-20.)
	var gr: float = tw * 0.98
	# --- THE GALLERY: the lantern's light round it; the platform's rim, a short drum of LIGHT IRON lit by the
	# lantern (dark like the sky, the top looked cut off from the tower); posts and rail round it -- the far
	# half before the lantern room, the near half after
	for k in 8:
		d.draw_circle(Vector2(cx, top_y - 20.0), tw * (1.6 - 0.12 * float(k)), Color(1.0, 0.88, 0.58, 0.035))
	var plat_h: float = 5.0
	var rail_h: float = 14.0
	_rail(d, cx, top_y - plat_h, gr * 0.96, rail_h, false)
	# --- THE LANTERN ROOM: a glazed drum glowing, its frames curving round it
	var lr_r: float = tw * 0.55
	var lr_y0: float = top_y - plat_h
	var lr_y1: float = lr_y0 - 28.0
	_drum(d, cx, lr_y0, lr_r, lr_y0 - 4.0, lr_r, Color(0.86, 0.84, 0.80), 0.0, 0.4)
	var n_g: int = 12
	for k in n_g:
		var a0: float = PI * float(k) / float(n_g)
		var a1: float = PI * float(k + 1) / float(n_g)
		var u: float = absf(cos((a0 + a1) * 0.5))
		var glass: Color = Color(1.0, 0.97, 0.84).lerp(Color(1.0, 0.80, 0.46), u)
		_poly(d, PackedVector2Array([_ring_pt(cx, lr_y0 - 4.0, lr_r, a0), _ring_pt(cx, lr_y0 - 4.0, lr_r, a1), _ring_pt(cx, lr_y1, lr_r, a1), _ring_pt(cx, lr_y1, lr_r, a0)]), glass)
	for k in 7:
		var a2: float = PI * (float(k) + 0.5) / 7.0
		d.draw_line(_ring_pt(cx, lr_y0 - 4.0, lr_r, a2), _ring_pt(cx, lr_y1, lr_r, a2), Color(0.20, 0.16, 0.12), 1.5)
	d.draw_polyline(_ring_front(cx, (lr_y0 + lr_y1) * 0.5 - 2.0, lr_r, 12), Color(0.20, 0.16, 0.12), 1.0, true)
	# --- THE DOME, seen from a little below: its rim, then the cap rising over it, shaded round, a vent ball
	var dome_r: float = tw * 0.66
	_drum(d, cx, lr_y1, dome_r, lr_y1 - 3.0, dome_r, Color(0.26, 0.24, 0.26), 0.0, 0.6)
	var dome_h: float = 20.0
	var steps: int = 6
	for s2 in steps:
		var e0: float = PI * 0.5 * float(s2) / float(steps)
		var e1: float = PI * 0.5 * float(s2 + 1) / float(steps)
		_drum(d, cx, lr_y1 - 3.0 - sin(e0) * dome_h, dome_r * cos(e0), lr_y1 - 3.0 - sin(e1) * dome_h, maxf(dome_r * cos(e1), 0.5), Color(0.22, 0.20, 0.22), 0.0, 0.55)
	var tip: Vector2 = Vector2(cx, lr_y1 - 3.0 - dome_h)
	d.draw_circle(tip + Vector2(0, -3), 3.5, Color(0.26, 0.24, 0.26))
	d.draw_circle(tip + Vector2(-1, -4), 1.2, Color(0.70, 0.66, 0.60))
	d.draw_line(tip + Vector2(0, -6), tip + Vector2(0, -16), Color(0.22, 0.20, 0.22), 1.5)
	# --- THE GALLERY'S UNDERSIDE: a disc seen from below, its near half in front of the shaft's top
	var under: PackedVector2Array = PackedVector2Array()
	for k in 33:
		under.append(_ring_pt(cx, top_y, gr, TAU * float(k) / 32.0))
	_poly(d, under, Color(0.30, 0.30, 0.34))
	# --- THE SHAFT: banded, tapering, each band a drum
	var bands: int = 7
	var foot_y: float = base.y - ph
	for k in bands:
		var f0: float = float(k) / float(bands)
		var f1: float = float(k + 1) / float(bands)
		var y0: float = lerpf(foot_y, top_y, f0)
		var y1: float = lerpf(foot_y, top_y, f1)
		var col: Color = Color(0.86, 0.22, 0.20) if k % 2 == 0 else Color(0.96, 0.94, 0.90)
		_drum(d, cx, y0, lerpf(bw, tw, f0) * 0.5, y1, lerpf(bw, tw, f1) * 0.5, col)
	# the door, its arch, its step, on the near side of the curve
	var door_w: float = bw * 0.24
	var door_h: float = th * 0.09
	var dy: float = _ring_pt(cx, foot_y, bw * 0.5, PI * 0.5).y
	d.draw_rect(Rect2(cx - door_w * 0.5 - 2.0, dy - door_h - 2.0, door_w + 4.0, door_h + 2.0), Color(0.55, 0.52, 0.50))
	d.draw_rect(Rect2(cx - door_w * 0.5, dy - door_h, door_w, door_h), Color(0.14, 0.09, 0.06))
	_half_disc(d, Vector2(cx, dy - door_h), door_w * 0.5 + 2.0, Color(0.55, 0.52, 0.50))
	_half_disc(d, Vector2(cx, dy - door_h), door_w * 0.5, Color(0.14, 0.09, 0.06))
	d.draw_line(Vector2(cx + door_w * 0.25, dy - door_h * 0.45), Vector2(cx + door_w * 0.25, dy - door_h * 0.40), Color(0.75, 0.62, 0.30), 2.0)
	_ell(d, Vector2(cx, dy + 1.0), door_w * 0.8, 2.5, Color(0.48, 0.48, 0.52))
	# windows, set on the near face where the shaft is at that height
	for k in 3:
		var wy: float = base.y - th * (0.28 + 0.22 * float(k))
		var wr: float = lerpf(bw, tw, (base.y - wy) / th) * 0.5
		var wfy: float = _ring_pt(cx, wy, wr, PI * 0.5).y
		if k == 1:
			_window(d, Rect2(cx - 5.0, wfy - 7.0, 10.0, 14.0))
		else:
			d.draw_rect(Rect2(cx - 6.0, wfy - 8.0, 12.0, 16.0), Color(0.30, 0.28, 0.30))
			d.draw_rect(Rect2(cx - 5.0, wfy - 7.0, 10.0, 14.0), Color(0.05, 0.05, 0.08))
			d.draw_line(Vector2(cx - 5.0, wfy - 4.0), Vector2(cx + 2.0, wfy - 6.0), Color(0.5, 0.55, 0.7, 0.4), 1.0)
	# the platform's rim: a short drum of LIGHT IRON lit by the lantern, its near face
	_drum(d, cx, top_y, gr, top_y - plat_h, gr, Color(0.86, 0.84, 0.80), 0.0, 0.45)
	# (the gallery's near rail, in front of the lantern room and its lamp: live, _draw_land part 3)

# the upper half of a disc: a door's arch
func _half_disc(d: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 13:
		var a: float = PI + PI * float(k) / 12.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	d.draw_colored_polygon(pts, col)

# the gallery's railing: posts round the ring and a top rail following its curve; `near` the front half
# (angles 0..PI) or the back half
func _rail(d: CanvasItem, cx: float, y: float, r: float, h: float, near: bool) -> void:
	var col: Color = Color(0.92, 0.88, 0.78) if near else Color(0.62, 0.60, 0.56)
	var a_from: float = 0.0 if near else PI
	var n: int = 9
	for k in n + 1:
		var a: float = a_from + PI * float(k) / float(n)
		var p0: Vector2 = _ring_pt(cx, y, r, a)
		d.draw_line(p0, p0 + Vector2(0.0, -h), col, 1.5)
	var line: PackedVector2Array = PackedVector2Array()
	for k in 25:
		line.append(_ring_pt(cx, y, r, a_from + PI * float(k) / 24.0) + Vector2(0.0, -h))
	d.draw_polyline(line, col, 2.0, true)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Lighthouse", "Sail through the night by the lighthouse's beam", Color(1.0, 0.93, 0.70), Color(0.03, 0.05, 0.12),
		Color(1.0, 0.85, 0.5, 0.25))

# a projected quad can fold over itself (a beam pointing nearly along the camera's axis): its convex hull is
# the same patch of light, and never invalid; a sliver is skipped
func _poly(d: CanvasItem, q: PackedVector2Array, col: Color) -> void:
	var hull: PackedVector2Array = Geometry2D.convex_hull(q)
	if hull.size() < 4:
		return
	var area: float = 0.0
	for i in hull.size() - 1:
		area += hull[i].cross(hull[i + 1])
	if absf(area) < 2.0:
		return
	hull.remove_at(hull.size() - 1)       # convex_hull closes the loop
	d.draw_colored_polygon(hull, col)

func _vg(d: CanvasItem, r: Rect2, top_c: Color, bot: Color) -> void:
	d.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top_c, top_c, bot, bot]))

func _ell(d: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	d.draw_set_transform(c, 0.0, Vector2(1.0, ry / maxf(rx, 0.001)))
	d.draw_circle(Vector2.ZERO, rx, col)
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

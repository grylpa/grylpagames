extends "res://scripts/menu_poster.gd"

# ANTS' OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): THE GARDEN FLOOR AT AN ANT'S
# HEIGHT, ALL IN 3-D (one camera, `_proj`, low over the soil): a trail of ants carrying green crumbs from the
# food pile to the nest mound -- it comes toward us, passes large in front, swings round a pebble the colony
# has learned to go round, and climbs into the mound; others go back the other way empty. Every ant is a
# model: head, thorax and abdomen as ellipsoids, six legs stepping in a TRIPOD GAIT with their feet planted on
# the ground while they push (never sliding), antennae feeling ahead, a shadow on the soil. Around them the
# soil in perspective, a twig, dappled sunlight, slow motes, the garden out of focus beyond, and big grass
# blades framing the view, swaying. The game's own palette (AntsArt): the soil, the near-black ants, the
# green food. Made up, never the board: the menu also opens mid-game.

const ANT_L: float = 10.0            # an ant's length, in world units
const SPEED: float = 20.0            # units a second along the trail
const PER_WAY: int = 9               # ants going each way
const STRIDE: float = 7.0            # ground covered per step cycle
const NEST: Vector3 = Vector3(150.0, 0.0, -520.0)
const FOOD: Vector3 = Vector3(-125.0, 0.0, -390.0)
const STONE: Vector3 = Vector3(6.0, 0.0, -46.0)
const LEAF: Vector3 = Vector3(-6.0, 0.0, 80.0)     # a fallen leaf in the near left
const SUN: Vector3 = Vector3(-0.55, 0.0, -0.45)      # shadows fall away from the sun: toward +x, +z

# the trail, in (x, z) on the ground: from the food, toward us, past the near side of the pebble, to the nest
const PATH: Array = [Vector2(-125, -372), Vector2(-112, -270), Vector2(-80, -150), Vector2(-44, -40), Vector2(-16, 36),
	Vector2(4, 72), Vector2(24, 62), Vector2(44, 6), Vector2(76, -100), Vector2(114, -230), Vector2(134, -380), Vector2(150, -515)]

var _ground: Control = null
var _warm: Control = null
var _motes: Control = null
var _life: MultiMeshInstance2D = null

# THE ANTS ON THE GPU (2026-11-20): every part of every ant was some 30 shapes worked out and drawn every frame -- most of
# a phone's frame. Now each ant is ONE instance of a mesh of 31 squares, one per part in the drawing's order (its shadow,
# six upper and six lower legs, three body parts each with its sheen and glint -- far part first --, the waist, the
# antennae, the crumb), and this shader works each part out from the ant's place, heading and stride by the same
# formulas and the same camera; the ants go over far to near. The instance data is HALF precision, so the ant's exact
# screen place goes in its transform (full precision, added after this code) and the shape is worked out relative to it.
# custom: (x, z, heading, distance walked mod STRIDE); color: (number * 2 + carrying, -, -, fade)
const ANT: String = """shader_type canvas_item;
uniform vec3 eye = vec3(0.0);
uniform vec3 cf = vec3(0.0, 0.0, -1.0);
uniform vec3 cr = vec3(1.0, 0.0, 0.0);
uniform vec3 cu = vec3(0.0, 1.0, 0.0);
uniform vec2 center = vec2(0.0);
uniform float focal = 800.0;
uniform float t = 0.0;
uniform vec2 nest = vec2(150.0, -520.0);
uniform vec2 sun_xz = vec2(-0.55, -0.45);
uniform vec3 body_col = vec3(0.106, 0.070, 0.055);
uniform vec3 sheen_col = vec3(0.310, 0.192, 0.125);
uniform vec3 crumb_col = vec3(0.729, 0.902, 0.463);
uniform vec3 food_dark = vec3(0.125, 0.259, 0.071);
const float L = 10.0;
const float STRIDE = 7.0;
varying vec2 v_q;
varying flat float v_line;
varying flat float v_hw;
varying flat vec4 v_col;

float mound(float r) {
	return r < 7.0 ? 6.0 + r * 0.4 : max(0.0, 9.0 * (1.0 - (r - 7.0) / 34.0));
}
float gh(vec3 p) {
	return mound(length(p.xz - nest));
}
vec2 proj(vec3 p) {
	vec3 v = p - eye;
	float z = max(dot(v, cf), 1.0);
	return center + vec2(dot(v, cr), -dot(v, cu)) * focal / z;
}
float pxs(vec3 p) {
	return focal / max(dot(p - eye, cf), 1.0);
}
float depth(vec3 p) {
	return dot(p - eye, cf);
}

void vertex() {
	vec2 corner = VERTEX * 2.0;            // the square's corner, -1..1
	int kind = int(UV.x + 0.5);
	int sub = int(UV.y + 0.5);
	vec4 c = INSTANCE_CUSTOM;
	int code = int(COLOR.r + 0.5);
	float idx = float(code / 2);
	bool carrying = (code % 2) == 1;
	float alpha = COLOR.a;
	vec3 fwd = vec3(cos(c.z), 0.0, sin(c.z));
	vec3 p = vec3(c.x, 0.0, c.y);
	float dist = c.w;
	// the ant's frame, tipped with the slope it climbs
	float g0 = gh(p);
	vec3 base = p + vec3(0.0, g0, 0.0);
	float pitch = atan(gh(p + fwd * 4.0) - g0, 4.0);
	vec3 f = normalize(fwd * cos(pitch) + vec3(0.0, 1.0, 0.0) * sin(pitch));
	vec3 s = normalize(cross(f, vec3(0.0, 1.0, 0.0)));
	vec3 u = normalize(cross(s, f));
	float body_h = L * 0.22 + 0.3 * sin(dist / STRIDE * TAU * 2.0);
	vec3 thorax = base + u * body_h;
	vec3 head = thorax + f * L * 0.36 + u * L * 0.03;
	vec3 abdomen = thorax - f * L * 0.48 + u * L * 0.04;
	float px = pxs(base);
	vec2 o = proj(base);                   // the transform puts this exactly where it belongs
	vec4 dark = vec4(body_col, alpha);
	// what this square draws: a disc or ellipse (center m, axes a1 a2 -- the square is m + a1 x + a2 y) or a line
	bool line = false;
	bool hide = false;
	vec2 m = vec2(0.0);
	vec2 a1 = vec2(1.0, 0.0);
	vec2 a2 = vec2(0.0, 1.0);
	vec2 la = vec2(0.0);
	vec2 lb = vec2(0.0);
	float w = 1.0;
	vec4 col = dark;
	if (kind == 0) {
		// its shadow on the soil, away from the sun
		vec3 sc = base + vec3(-sun_xz.x, 0.0, -sun_xz.y) * L * 0.25 - f * L * 0.1;
		vec3 f2 = normalize(vec3(f.x, 0.0, f.z));
		vec3 s2 = normalize(vec3(s.x, 0.0, s.z));
		vec3 g = vec3(sc.x, gh(sc), sc.z);
		m = proj(g);
		a1 = proj(g + f2 * L * 0.62) - m;
		a2 = proj(g + s2 * L * 0.22) - m;
		col = vec4(0.0, 0.0, 0.0, 0.22 * alpha);
	} else if (kind == 1 || kind == 2) {
		// THE LEGS: three a side, tripod gait; a foot in stance is planted
		int li = sub % 3;
		float sd = sub < 3 ? -1.0 : 1.0;
		float hips[3] = float[3](0.10, 0.0, -0.10);
		float reach[3] = float[3](0.40, 0.04, -0.42);
		float amp = STRIDE * 0.6;
		float ph = ((li % 2 == 0) == (sd > 0.0)) ? 0.0 : 0.5;
		float cyc = fract(dist / STRIDE + ph + idx * 0.13);
		float rel = 0.0;
		float lift = 0.0;
		if (cyc < 0.6) {
			rel = amp * (0.5 - cyc / 0.6);
		} else {
			float ww = (cyc - 0.6) / 0.4;
			rel = amp * (-0.5 + smoothstep(0.0, 1.0, ww));
			lift = sin(ww * PI) * L * 0.12;
		}
		vec3 hip = thorax + f * L * hips[li] + s * sd * L * 0.06;
		vec3 foot = base + f * (L * reach[li] + rel) + s * sd * L * 0.34 + vec3(0.0, lift, 0.0);
		foot.y = gh(foot) + lift;
		vec3 knee = mix(hip, foot, 0.42) + vec3(0.0, L * 0.17, 0.0) + s * sd * L * 0.04;
		float w1 = max(1.0, 0.055 * L * px);
		line = true;
		if (kind == 1) {
			la = proj(hip); lb = proj(knee); w = w1;
		} else {
			la = proj(knee); lb = proj(foot); w = max(1.0, w1 * 0.7);
		}
	} else if (kind >= 3 && kind <= 5) {
		// THE BODY: abdomen, thorax, head -- each an ellipsoid, far parts first (slot `sub` takes the sub-th farthest)
		vec3 cs[3] = vec3[3](abdomen, thorax, head);
		vec3 rr[3] = vec3[3](vec3(L * 0.34, L * 0.23, L * 0.21), vec3(L * 0.20, L * 0.10, L * 0.10), vec3(L * 0.17, L * 0.15, L * 0.13));
		float dd[3] = float[3](depth(abdomen), depth(thorax), depth(head));
		int pick = 0;
		for (int q = 0; q < 3; q++) {
			int rank = 0;
			for (int q2 = 0; q2 < 3; q2++) {
				if (dd[q2] > dd[q] || (dd[q2] == dd[q] && q2 < q)) {
					rank++;
				}
			}
			if (rank == sub) {
				pick = q;
			}
		}
		vec3 pc = cs[pick];
		vec3 r3 = rr[pick];
		if (kind == 3) {
			// its outline: the ellipse whose matrix is the sum of its projected half-axes' outer products (L L^T)
			m = proj(pc);
			vec2 ax = proj(pc + f * r3.x) - m;
			vec2 bx = proj(pc + s * r3.y) - m;
			vec2 cx = proj(pc + u * r3.z) - m;
			float m11 = ax.x * ax.x + bx.x * bx.x + cx.x * cx.x;
			float m21 = ax.x * ax.y + bx.x * bx.y + cx.x * cx.y;
			float m22 = ax.y * ax.y + bx.y * bx.y + cx.y * cx.y;
			float l11 = sqrt(max(m11, 1e-6));
			float l21 = m21 / l11;
			float l22 = sqrt(max(m22 - l21 * l21, 1e-6));
			a1 = vec2(l11, l21);
			a2 = vec2(0.0, l22);
		} else {
			// the sheen: a soft highlight on the upper, sunward side, and its glint
			vec3 hl = pc + u * r3.z * 0.55 - s * r3.y * 0.25 + f * r3.x * 0.15;
			vec2 hp = proj(hl);
			float hr = min(r3.x, r3.y) * pxs(pc) * 0.55;
			if (kind == 4) {
				m = hp;
				a1 = vec2(hr, 0.0);
				col = vec4(sheen_col, alpha * 0.55);
			} else {
				m = hp + vec2(-hr * 0.2, -hr * 0.25);
				a1 = vec2(hr * 0.45, 0.0);
				col = vec4(0.72, 0.56, 0.42, alpha * 0.55);
			}
			a2 = vec2(0.0, a1.x);
		}
	} else if (kind == 6) {
		line = true;
		la = proj(thorax - f * L * 0.12);
		lb = proj(abdomen + f * L * 0.22);
		w = max(1.0, 0.06 * L * px);
	} else if (kind == 7 || kind == 8) {
		// THE ANTENNAE: up from the head, elbowed, feeling forward, waving
		float sd2 = sub == 0 ? -1.0 : 1.0;
		float wave = sin(t * 5.0 + sd2 + idx) * 0.25;
		vec3 root = head + f * L * 0.08 + u * L * 0.08 + s * sd2 * L * 0.04;
		vec3 elbow = root + u * L * 0.22 + f * L * 0.06 + s * sd2 * L * 0.05;
		vec3 tip = elbow + f * L * 0.30 + s * sd2 * L * (0.16 + wave * 0.3) - u * L * (0.06 + wave * 0.1);
		line = true;
		if (kind == 7) {
			la = proj(root); lb = proj(elbow); w = max(1.0, 0.04 * L * px);
		} else {
			la = proj(elbow); lb = proj(tip); w = max(1.0, 0.035 * L * px);
		}
	} else {
		// a green crumb held in the jaws
		hide = !carrying;
		vec3 cc = head + f * L * 0.22 + u * L * 0.02;
		vec2 sp = proj(cc);
		float pr = L * 0.16 * pxs(cc);
		if (sub == 0) {
			m = sp; a1 = vec2(pr, 0.0); col = vec4(food_dark, alpha);
		} else if (sub == 1) {
			m = sp + vec2(-pr * 0.12, -pr * 0.12); a1 = vec2(pr * 0.84, 0.0); col = vec4(crumb_col, alpha);
		} else if (sub == 2) {
			m = sp + vec2(-pr * 0.32, -pr * 0.34); a1 = vec2(pr * 0.42, 0.0); col = vec4(crumb_col + (vec3(1.0) - crumb_col) * 0.28, alpha);
		} else {
			m = sp + vec2(-pr * 0.40, -pr * 0.42); a1 = vec2(pr * 0.14, 0.0); col = vec4(1.0, 1.0, 1.0, 0.55 * alpha);
		}
		a2 = vec2(0.0, a1.x);
	}
	vec2 outp;
	if (line) {
		vec2 ab = lb - la;
		float ln = max(length(ab), 1e-4);
		vec2 n = vec2(-ab.y, ab.x) / ln;
		float across = corner.y * (w * 0.5 + 1.5);
		outp = la + ab * (corner.x * 0.5 + 0.5) + n * across;
		v_q = vec2(across, 0.0);
		v_hw = w * 0.5;
	} else {
		outp = m + (a1 * corner.x + a2 * corner.y) * 1.25;
		v_q = corner * 1.25;
		v_hw = 0.0;
	}
	v_line = line ? 1.0 : 0.0;
	v_col = col;
	VERTEX = (hide || alpha <= 0.0) ? vec2(0.0) : outp - o;
}

void fragment() {
	float cov;
	if (v_line > 0.5) {
		float d = abs(v_q.x);
		cov = clamp((v_hw - d) / max(fwidth(v_q.x), 1e-4) + 0.5, 0.0, 1.0);
	} else {
		float d = length(v_q);
		cov = clamp((1.0 - d) / max(fwidth(d), 1e-4) + 0.5, 0.0, 1.0);
	}
	COLOR = vec4(v_col.rgb, v_col.a * cov);
}
"""
var _front: Control = null
var _cam: Dictionary = {}
var _trail: PackedVector3Array = PackedVector3Array()
var _cum: PackedFloat32Array = PackedFloat32Array()
var _len: float = 1.0
var _crumbs: Array = []              # the food pile: [Vector3 center, radius]
var _grains: Array = []              # the nest mound's granules: [Vector3, radius, tone]
var _for_bottom: float = -2.0

func _setup() -> void:
	# the ground never moves: a still layer, baked (menu_poster.gd `add_still`)
	_ground = add_still(func(d: Control) -> void: _draw_ground(d))
	_life = MultiMeshInstance2D.new()
	var am: ShaderMaterial = ShaderMaterial.new()
	var ash: Shader = Shader.new()
	ash.code = ANT
	am.shader = ash
	am.set_shader_parameter("nest", Vector2(NEST.x, NEST.z))
	am.set_shader_parameter("sun_xz", Vector2(SUN.x, SUN.z))
	am.set_shader_parameter("body_col", Vector3(AntsArt.ANT_BODY.r, AntsArt.ANT_BODY.g, AntsArt.ANT_BODY.b))
	am.set_shader_parameter("sheen_col", Vector3(AntsArt.ANT_SHEEN.r, AntsArt.ANT_SHEEN.g, AntsArt.ANT_SHEEN.b))
	am.set_shader_parameter("crumb_col", Vector3(AntsArt.CRUMB.r, AntsArt.CRUMB.g, AntsArt.CRUMB.b))
	am.set_shader_parameter("food_dark", Vector3(AntsArt.FOOD_DARK.r, AntsArt.FOOD_DARK.g, AntsArt.FOOD_DARK.b))
	_life.material = am
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = _ant_mesh()
	mm.instance_count = PER_WAY * 2
	mm.custom_aabb = AABB(Vector3(-4000.0, -4000.0, -1.0), Vector3(8000.0, 8000.0, 2.0))
	_life.multimesh = mm
	add_child(_life)
	# the sun's warmth over the ants, drawn once (14 discs the size of the screen: 14 full-screen passes a frame)
	_warm = cached_layer(func(d: Control) -> void: _draw_warmth(d))
	_motes = _mk(func(d: Control) -> void: _draw_motes(d))
	_front = _mk(func(d: Control) -> void: _draw_front(d))
	_build_trail()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	for k in 90:
		var a: float = rng.randf() * TAU
		var rr: float = 24.0 * sqrt(rng.randf())
		var hh: float = 14.0 * (1.0 - rr / 25.0) * (0.6 + 0.4 * rng.randf())
		_crumbs.append([FOOD + Vector3(cos(a) * rr, hh, sin(a) * rr * 0.8), 1.8 + rng.randf() * 2.2])
	for k in 140:
		var a2: float = rng.randf() * TAU
		var rr2: float = 9.0 + 30.0 * pow(rng.randf(), 0.8)
		_grains.append([NEST + Vector3(cos(a2) * rr2, _mound_h(rr2) + 0.8, sin(a2) * rr2), 1.4 + rng.randf() * 1.6, rng.randf()])

func _mk(fn: Callable) -> Control:
	var c: Control = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.draw.connect(fn.bind(c))
	add_child(c)
	return c

# --- the camera ---------------------------------------------------------------------------------------

func _camera() -> Dictionary:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var eye: Vector3 = Vector3(10.0, 44.0, 165.0)
	var target: Vector3 = Vector3(16.0, 0.0, -150.0)
	var f: Vector3 = (target - eye).normalized()
	var r: Vector3 = f.cross(Vector3.UP).normalized()
	var u: Vector3 = r.cross(f)
	var top: float = 230.0 if mobile else 150.0
	return {"eye": eye, "f": f, "r": r, "u": u, "focal": full.x * 1.25, "full": full, "bottom": bottom,
		"center": Vector2(full.x * 0.5, top + (bottom - top) * 0.34)}

# the camera's parts as plain fields, for _proj (called thousands of times a frame: reading them from the
# dictionary each time cost a phone several ms a frame)
var _c_eye: Vector3 = Vector3.ZERO
var _c_f: Vector3 = Vector3.FORWARD
var _c_r: Vector3 = Vector3.RIGHT
var _c_u: Vector3 = Vector3.UP
var _c_center: Vector2 = Vector2.ZERO
var _c_focal: float = 1.0

func _set_cam(c: Dictionary) -> void:
	_cam = c
	_c_eye = c["eye"]
	_c_f = c["f"]
	_c_r = c["r"]
	_c_u = c["u"]
	_c_center = c["center"]
	_c_focal = c["focal"]

func _proj(p: Vector3) -> Vector2:
	var v: Vector3 = p - _c_eye
	var z: float = maxf(v.dot(_c_f), 1.0)
	return _c_center + Vector2(v.dot(_c_r), -v.dot(_c_u)) * _c_focal / z

# screen pixels per world unit at a point
func _px(p: Vector3) -> float:
	return _c_focal / maxf((p - _c_eye).dot(_c_f), 1.0)

func _depth(p: Vector3) -> float:
	return (p - _c_eye).dot(_c_f)

func _tick(_delta: float) -> void:
	_set_cam(_camera())
	if absf(scene_bottom - _for_bottom) > 0.5:
		_for_bottom = scene_bottom
		_ground.queue_redraw()
		_warm.queue_redraw()
	_place_ants()
	_motes.queue_redraw()
	_front.queue_redraw()

# --- the trail ------------------------------------------------------------------------------------------

func _build_trail() -> void:
	# a Catmull-Rom curve through PATH, sampled finely, with its running length
	var pts: Array = PATH
	_trail.clear()
	for i in pts.size() - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		for k in 12:
			var u: float = float(k) / 12.0
			var u2: float = u * u
			var u3: float = u2 * u
			var q: Vector2 = 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3)
			_trail.append(Vector3(q.x, 0.0, q.y))
	var last: Vector2 = pts[pts.size() - 1]
	_trail.append(Vector3(last.x, 0.0, last.y))
	_cum.clear()
	_cum.append(0.0)
	for i in range(1, _trail.size()):
		_cum.append(_cum[i - 1] + _trail[i].distance_to(_trail[i - 1]))
	_len = _cum[_cum.size() - 1]

# the point and the heading at a distance along the trail
func _along(s: float) -> Array:
	s = clampf(s, 0.0, _len)
	var lo: int = 0
	var hi: int = _cum.size() - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) / 2
		if _cum[mid] <= s:
			lo = mid
		else:
			hi = mid
	var seg: float = maxf(_cum[hi] - _cum[lo], 0.001)
	var p: Vector3 = _trail[lo].lerp(_trail[hi], (s - _cum[lo]) / seg)
	var dir: Vector3 = (_trail[hi] - _trail[lo]).normalized()
	return [p, dir]

func _mound_h(r: float) -> float:
	# the nest: a low cone of dug-out soil with a crater at its top
	if r < 7.0:
		return 6.0 + r * 0.4
	return maxf(0.0, 9.0 * (1.0 - (r - 7.0) / 34.0))

func _ground_h(p: Vector3) -> float:
	return _mound_h(Vector2(p.x - NEST.x, p.z - NEST.z).length())

# --- the ground, drawn once: background garden, soil, sunlight, the twig, the food, the nest ---------------

func _draw_ground(d: Control) -> void:
	if _cam.is_empty():
		_set_cam(_camera())
	var full: Vector2 = _cam["full"]
	# the garden beyond, out of focus: a warm green gradient and soft discs of light
	var horizon: float = _proj(Vector3(0.0, 0.0, -6000.0)).y
	d.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(full.x, 0), Vector2(full.x, horizon + 40.0), Vector2(0, horizon + 40.0)]),
		PackedColorArray([Color(0.20, 0.30, 0.16), Color(0.26, 0.34, 0.18), Color(0.62, 0.62, 0.40), Color(0.56, 0.58, 0.36)]))
	for k in 26:
		var bp: Vector2 = Vector2(full.x * h01(k * 5 + 1), horizon * (0.15 + 0.9 * h01(k * 5 + 2)))
		var br: float = 18.0 + 46.0 * h01(k * 5 + 3)
		var warm: bool = h01(k * 5 + 4) > 0.45
		var bc: Color = Color(1.0, 0.92, 0.62) if warm else Color(0.62, 0.80, 0.42)
		for g in 5:
			d.draw_circle(bp, br * (1.0 - 0.14 * float(g)), Color(bc, 0.035 + 0.01 * float(g)))
	# THE GARDEN BEYOND, OUT OF FOCUS: tall stems and broad leaves as soft layered silhouettes against the light, a
	# flower head or two -- each drawn as a few widening translucent copies, so its edges are blurred like a lens's
	for k in 22:
		var px: float = full.x * h01(k * 7 + 300)
		var base_y: float = horizon + 30.0
		var tall: float = horizon * (0.35 + 0.6 * h01(k * 7 + 301))
		var lean: float = (h01(k * 7 + 302) - 0.5) * 60.0
		var dark: Color = Color(0.14, 0.24, 0.10) if h01(k * 7 + 303) > 0.4 else Color(0.22, 0.32, 0.14)
		for blur in 4:
			var w: float = 5.0 + float(blur) * 5.0
			var al: float = 0.20 - float(blur) * 0.04
			var pts: PackedVector2Array = PackedVector2Array()
			for sg in 9:
				var u: float = float(sg) / 8.0
				pts.append(Vector2(px + lean * u * u, base_y - tall * u))
			d.draw_polyline(pts, Color(dark, al), w * (1.0 - 0.3 * float(k % 2)), true)
			if k % 3 == 0:
				# a broad leaf off the stem
				var lp2: Vector2 = Vector2(px + lean * 0.3, base_y - tall * 0.55)
				var side: float = 1.0 if k % 2 == 0 else -1.0
				var leaf: PackedVector2Array = PackedVector2Array()
				for lk in 13:
					var lu: float = float(lk) / 12.0
					leaf.append(lp2 + Vector2(side * lu * 70.0, -sin(lu * PI) * (14.0 + float(blur) * 3.0) - lu * 30.0))
				for lk in range(12, -1, -1):
					var lu2: float = float(lk) / 12.0
					leaf.append(lp2 + Vector2(side * lu2 * 70.0, sin(lu2 * PI) * (6.0 + float(blur) * 3.0) - lu2 * 30.0))
				_safe(d, leaf, Color(dark, al * 0.8))
			if k % 5 == 1:
				d.draw_circle(Vector2(px + lean, base_y - tall), 10.0 + float(blur) * 5.0, Color(0.95, 0.80, 0.45, al * 0.9))
	# (the sun's warmth is laid over everything at the end of the life layer)
	# the soil plane: lighter and hazier with distance, warm close to
	var near_z: float = 160.0
	var far_z: float = -2400.0
	var strips: int = 18
	for k in strips:
		var z0: float = lerpf(near_z, far_z, pow(float(k) / float(strips), 1.8))
		var z1: float = lerpf(near_z, far_z, pow(float(k + 1) / float(strips), 1.8))
		var f0: float = clampf(-z0 / 1400.0, 0.0, 1.0)
		var f1: float = clampf(-z1 / 1400.0, 0.0, 1.0)
		var c0: Color = AntsArt.SOIL.darkened(0.12).lerp(Color(0.60, 0.58, 0.40), f0 * 0.85)
		var c1: Color = AntsArt.SOIL.darkened(0.12).lerp(Color(0.60, 0.58, 0.40), f1 * 0.85)
		var q: PackedVector2Array = PackedVector2Array([_proj(Vector3(-900, 0, z0)), _proj(Vector3(900, 0, z0)), _proj(Vector3(900, 0, z1)), _proj(Vector3(-900, 0, z1))])
		d.draw_polygon(q, PackedColorArray([c0, c0, c1, c1]))
	# THE SOIL'S OWN FACE: damp dark patches and dry pale ones, so the plane is never one color
	for k in 70:
		var mp: Vector3 = Vector3(lerpf(-400.0, 400.0, h01(k * 3 + 400)), 0.0, lerpf(150.0, -1200.0, pow(h01(k * 3 + 401), 0.8)))
		var damp: bool = h01(k * 3 + 402) > 0.5
		var haze0: float = clampf(-mp.z / 1300.0, 0.0, 0.85)
		for ring in 4:
			_ground_disc(d, mp, (30.0 + 70.0 * h01(k + 403)) * (1.0 - 0.2 * float(ring)),
				Color(0.20, 0.12, 0.06, 0.09 * (1.0 - haze0)) if damp else Color(0.86, 0.74, 0.52, 0.08 * (1.0 - haze0)))
	# DRYING CRACKS in the open soil: dark hairlines that branch, each with a lit lip on the sun's side
	for k in 14:
		var cp: Vector3 = Vector3(lerpf(-300.0, 300.0, h01(k * 5 + 500)), 0.0, lerpf(120.0, -500.0, h01(k * 5 + 501)))
		if absf(cp.x - lerpf(-60.0, 60.0, (cp.z + 500.0) / 620.0)) < 70.0:
			continue          # never across the trail
		var ang: float = h01(k * 5 + 502) * TAU
		for br in 3:
			var q0: Vector3 = cp
			var pts2: PackedVector2Array = PackedVector2Array([_proj(q0)])
			var a2: float = ang + float(br) * 2.1
			for sg in 7:
				a2 += (h01(k * 31 + br * 7 + sg) - 0.5) * 0.9
				q0 += Vector3(cos(a2), 0.0, sin(a2)) * (5.0 + 4.0 * h01(k + sg + 600))
				pts2.append(_proj(q0))
			d.draw_polyline(pts2, Color(0.80, 0.66, 0.46, 0.45), 3.4, true)
			d.draw_polyline(pts2, Color(0.12, 0.07, 0.03, 0.75), 1.6, true)
	# MOSS in the damp: tufts of tiny green-gold beads, each lit from the sun's side
	for k in 9:
		var mc: Vector3 = Vector3(lerpf(-280.0, 280.0, h01(k * 3 + 700)), 0.0, lerpf(130.0, -420.0, h01(k * 3 + 701)))
		if absf(mc.x) < 90.0:
			mc.x += 180.0 * signf(mc.x + 0.01)
		_ground_disc(d, mc + Vector3(2.0, 0.0, 2.0), 16.0, Color(0.0, 0.0, 0.0, 0.14))
		for b in 70:
			var ba: float = h01(k * 97 + b) * TAU
			var bra: float = 14.0 * sqrt(h01(k * 97 + b + 1))
			var bp3: Vector3 = mc + Vector3(cos(ba) * bra, 1.2 * (1.0 - bra / 14.0), sin(ba) * bra)
			var rr: float = 0.9 * _px(bp3)
			d.draw_circle(_proj(bp3), rr, Color(0.22, 0.36, 0.10))
			d.draw_circle(_proj(bp3) + Vector2(-rr * 0.3, -rr * 0.35), rr * 0.5, Color(0.58, 0.70, 0.26))
	# DRY GRASS, PINE NEEDLES AND SEED HUSKS lying on the soil: thin straws in perspective, each with a lit top edge
	for k in 110:
		var sp: Vector3 = Vector3(lerpf(-330.0, 330.0, h01(k * 4 + 800)), 0.0, lerpf(140.0, -700.0, pow(h01(k * 4 + 801), 0.8)))
		var sa: float = h01(k * 4 + 802) * PI
		var sl: float = 8.0 + 22.0 * h01(k * 4 + 803)
		var e0: Vector3 = sp - Vector3(cos(sa), 0.0, sin(sa)) * sl * 0.5
		var e1: Vector3 = sp + Vector3(cos(sa), 0.0, sin(sa)) * sl * 0.5
		var haze1: float = clampf(-sp.z / 900.0, 0.0, 0.8)
		var straw: Color = Color(0.74, 0.62, 0.36) if k % 3 != 0 else Color(0.42, 0.26, 0.14)
		var wpx: float = maxf(0.8, 0.45 * _px(sp))
		d.draw_line(_proj(e0 + Vector3(0.6, 0.0, 0.6)), _proj(e1 + Vector3(0.6, 0.0, 0.6)), Color(0.0, 0.0, 0.0, 0.18 * (1.0 - haze1)), wpx * 1.4, true)
		d.draw_line(_proj(e0), _proj(e1), Color(straw, 1.0 - haze1), wpx, true)
		d.draw_line(_proj(e0) + Vector2(0.0, -wpx * 0.35), _proj(e1) + Vector2(0.0, -wpx * 0.35), Color(straw.lightened(0.35), 0.6 * (1.0 - haze1)), wpx * 0.4, true)
		if k % 9 == 0:
			# a seed husk: a little split shell, lit
			var hp: Vector2 = _proj(sp)
			var hr: float = 2.2 * _px(sp)
			_ell(d, hp + Vector2(hr * 0.3, hr * 0.3), hr * 1.6, hr * 0.8, Color(0.0, 0.0, 0.0, 0.2))
			_ell(d, hp, hr * 1.5, hr * 0.7, Color(0.52, 0.36, 0.20))
			_ell(d, hp + Vector2(-hr * 0.3, -hr * 0.2), hr * 0.8, hr * 0.3, Color(0.86, 0.70, 0.46))
	# PEBBLES: real little stones (the same model as the big one) scattered off the trail
	for k in 26:
		var pp: Vector3 = Vector3(lerpf(-300.0, 300.0, h01(k * 3 + 900)), 0.0, lerpf(130.0, -650.0, pow(h01(k * 3 + 901), 0.9)))
		if absf(pp.x - lerpf(-60.0, 60.0, (pp.z + 500.0) / 620.0)) < 45.0 or pp.distance_to(STONE) < 40.0:
			continue
		_stone(d, pp, 2.0 + 4.0 * h01(k * 3 + 902))
	# dappled sunlight through leaves, lying on the soil
	for k in 14:
		var lp: Vector3 = Vector3(lerpf(-260.0, 260.0, h01(k * 3 + 50)), 0.0, lerpf(60.0, -700.0, h01(k * 3 + 51)))
		_ground_disc(d, lp, 20.0 + 40.0 * h01(k * 3 + 52), Color(1.0, 0.90, 0.62, 0.07))
		_ground_disc(d, lp, 12.0 + 22.0 * h01(k * 3 + 52), Color(1.0, 0.92, 0.66, 0.07))
	# the grain of the soil: crumbs of earth, little stones, lit on the sun's side
	for k in 3200:
		var gp: Vector3 = Vector3(lerpf(-320.0, 320.0, h01(k * 4 + 100)), 0.0, lerpf(150.0, -900.0, pow(h01(k * 4 + 101), 0.7)))
		var gr: float = 0.5 + 1.6 * h01(k * 4 + 102)
		var tone: float = h01(k * 4 + 103)
		var gc: Color = AntsArt.GRAIN_DARK if tone < 0.55 else AntsArt.GRAIN_LIGHT
		var haze: float = clampf(-gp.z / 1000.0, 0.0, 0.8)
		_ground_disc(d, gp, gr, Color(gc, gc.a * (1.0 - haze)))
		if gr > 1.4 and tone > 0.8:
			# a small pebble with its own little shadow
			_ground_disc(d, gp + Vector3(0.6, 0.0, 0.5), gr, Color(0.0, 0.0, 0.0, 0.12 * (1.0 - haze)))
			# earthy, each its own mineral (pale pearls of one gray read as beads, not stones)
			var pc: Color = [Color(0.48, 0.40, 0.32), Color(0.56, 0.46, 0.34), Color(0.40, 0.38, 0.36), Color(0.62, 0.50, 0.36)][int(h01(k + 7) * 4.0) % 4]
			var pr: float = gr * _px(gp) * 0.9
			var pc2: Vector2 = _proj(gp + Vector3(0, gr * 0.6, 0))
			_ell(d, pc2, pr * 1.1, pr * 0.85, Color(pc, 1.0 - haze))
			_ell(d, pc2 + Vector2(pr * 0.2, pr * 0.25), pr * 0.8, pr * 0.5, Color(pc.darkened(0.35), 0.6 * (1.0 - haze)))
			d.draw_circle(pc2 + Vector2(-pr * 0.35, -pr * 0.3), pr * 0.35, Color(pc.lightened(0.45), 0.8 * (1.0 - haze)))
	# THE NEAR SOIL'S GRAIN, close enough to see each crumb: a body in one of the soil's tones, its shade toward +x+z,
	# a lit cap toward the sun
	for k in 9000:
		var np2: Vector3 = Vector3(lerpf(-260.0, 260.0, h01(k * 5 + 1100)), 0.0, lerpf(165.0, -260.0, pow(h01(k * 5 + 1101), 1.3)))
		var nr: float = (0.12 + 0.42 * pow(h01(k * 5 + 1102), 3.0)) * _px(np2)
		if nr < 0.5:
			continue
		var tn: float = h01(k * 5 + 1103)
		var body: Color = AntsArt.SOIL.darkened(0.22).lerp(AntsArt.SOIL.lightened(0.15), tn)
		var c2: Vector2 = _proj(np2)
		var flat: float = 0.55 + 0.25 * h01(k * 5 + 1104)       # crumbs lie on the ground: seen foreshortened
		_ell(d, c2 + Vector2(nr * 0.4, nr * 0.3), nr * 1.05, nr * flat, Color(0.10, 0.06, 0.03, 0.18))
		_ell(d, c2, nr, nr * flat, Color(body, 0.85))
		_ell(d, c2 + Vector2(-nr * 0.3, -nr * flat * 0.35), nr * 0.45, nr * flat * 0.4, Color(body.lightened(0.28), 0.6))
	# the scent of the trail: a faint darker road worn into the soil
	for k in 120:
		var s: float = _len * float(k) / 120.0
		var a: Array = _along(s)
		_ground_disc(d, a[0], 7.0, Color(AntsArt.TRAIL, 0.035))
	_leaf(d, LEAF, 20.0, 0.35)
	# THE TWIG lying across the old way, the colony's first detour
	_twig(d, Vector3(-200.0, 0.0, -470.0), Vector3(-60.0, 0.0, -430.0), 3.2)
	_twig(d, Vector3(-120.0, 0.0, -452.0), Vector3(-96.0, 0.0, -500.0), 1.8)
	# THE PEBBLE the trail swings round
	_stone(d, STONE, 17.0)
	# THE FOOD: a heap of green crumbs, shaded each
	_ground_disc(d, FOOD + Vector3(4.0, 0.0, 4.0), 30.0, Color(0.0, 0.0, 0.0, 0.16))
	var order: Array = _crumbs.duplicate()
	order.sort_custom(func(x, y): return _depth(x[0]) > _depth(y[0]))
	for c in order:
		_sphere(d, c[0], c[1], AntsArt.FOOD_BODY, AntsArt.FOOD_DARK)
	# THE NEST: the far half of the mound's granules, the crater, the near half
	var hole: Vector3 = NEST + Vector3(0.0, _mound_h(6.9), 0.0)
	var back: Array = []
	var front: Array = []
	for g2 in _grains:
		if Vector3(g2[0]).z < NEST.z:
			back.append(g2)
		else:
			front.append(g2)
	_ground_disc(d, NEST, 44.0, Color(AntsArt.NEST_RIM, 0.55))
	_ground_disc(d, NEST, 30.0, Color(AntsArt.NEST_RIM.lightened(0.1), 0.6))
	back.sort_custom(func(x, y): return _depth(x[0]) > _depth(y[0]))
	front.sort_custom(func(x, y): return _depth(x[0]) > _depth(y[0]))
	for g3 in back:
		_grain(d, g3)
	_ground_disc(d, hole, 7.5, AntsArt.NEST_HOLE)
	_ground_disc(d, hole + Vector3(0.0, 0.0, 1.0), 5.5, Color(0.0, 0.0, 0.0, 0.7))
	for g4 in front:
		_grain(d, g4)

func _grain(d: CanvasItem, g: Array) -> void:
	var p: Vector3 = g[0]
	var col: Color = AntsArt.SOIL_DARK.lerp(AntsArt.SOIL_LIGHT, float(g[2]))
	_sphere(d, p, g[1], col, col.darkened(0.45))

# a disc lying on the ground (or level at a height), projected
func _ground_disc(d: CanvasItem, c: Vector3, r: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 20:
		var a: float = TAU * float(k) / 20.0
		pts.append(_proj(c + Vector3(cos(a) * r, 0.0, sin(a) * r)))
	if Geometry2D.triangulate_polygon(pts).size() > 0:
		d.draw_colored_polygon(pts, col)

# a ball: dark rim, body, lit cap toward the sun, a glint
func _sphere(d: CanvasItem, c: Vector3, r: float, body: Color, dark: Color) -> void:
	var sp: Vector2 = _proj(c)
	var pr: float = r * _px(c)
	d.draw_circle(sp, pr, dark)
	d.draw_circle(sp + Vector2(-pr * 0.12, -pr * 0.12), pr * 0.84, body)
	d.draw_circle(sp + Vector2(-pr * 0.32, -pr * 0.34), pr * 0.42, body.lightened(0.28))
	d.draw_circle(sp + Vector2(-pr * 0.40, -pr * 0.42), pr * 0.14, Color(1, 1, 1, 0.55))

# THE STONE the trail swings round (a smooth ellipsoid read as "a big egg", the user): a real pebble -- a
# LOW, LUMPY DOME, its outline irregular, its crown squashed, built as a mesh of patches in 3-D and each patch
# shaded by how it faces the sun, blended corner to corner; mottled with darker and lighter flecks of mineral;
# bedded in the soil, a rim of grains against its foot, its shadow beside it
func _stone_pt(c: Vector3, r: float, th: float, ph: float) -> Vector3:
	var lump: float = 1.0 + 0.16 * sin(2.0 * th + 1.1) + 0.09 * sin(3.0 * th + 2.3) + 0.05 * sin(5.0 * th + 0.4)
	var rr: float = r * lump * cos(ph)
	var hh: float = r * 0.56 * pow(sin(ph), 0.8) * (1.0 + 0.10 * sin(2.0 * th + 0.3))
	return c + Vector3(cos(th) * rr, hh, sin(th) * rr * 0.85)

func _stone(d: CanvasItem, c: Vector3, r: float) -> void:
	_ground_disc(d, c + Vector3(r * 0.45, 0.0, r * 0.40), r * 1.05, Color(0.0, 0.0, 0.0, 0.26))
	var light: Vector3 = Vector3(-0.45, 0.80, 0.15).normalized()
	var eye: Vector3 = _cam["eye"]
	var nt: int = 28
	var np: int = 7
	var quads: Array = []
	for i in np:
		var p0: float = PI * 0.5 * float(i) / float(np)
		var p1: float = PI * 0.5 * float(i + 1) / float(np)
		for j in nt:
			var t0: float = TAU * float(j) / float(nt)
			var t1: float = TAU * float(j + 1) / float(nt)
			var v: Array = [_stone_pt(c, r, t0, p0), _stone_pt(c, r, t1, p0), _stone_pt(c, r, t1, p1), _stone_pt(c, r, t0, p1)]
			var mid: Vector3 = (Vector3(v[0]) + Vector3(v[1]) + Vector3(v[2]) + Vector3(v[3])) * 0.25
			var nrm: Vector3 = (Vector3(v[1]) - Vector3(v[0])).cross(Vector3(v[3]) - Vector3(v[0])).normalized()
			if nrm.dot(mid - c) < 0.0:
				nrm = -nrm
			if nrm.dot(eye - mid) <= 0.0:
				continue
			var cols: PackedColorArray = PackedColorArray()
			for q in v:
				var vq: Vector3 = q
				var vn: Vector3 = (vq - (c + Vector3(0.0, -r * 0.3, 0.0))).normalized()
				var lam: float = clampf(vn.dot(light), 0.0, 1.0)
				var tone: float = 0.92 + 0.16 * h01(int(vq.x * 7.0) * 31 + int(vq.z * 7.0))
				var col: Color = Color(0.36, 0.34, 0.31).lerp(Color(0.78, 0.75, 0.69), lam)
				cols.append(Color(col.r * tone, col.g * tone, col.b * tone))
			quads.append([_depth(mid), PackedVector2Array([_proj(v[0]), _proj(v[1]), _proj(v[2]), _proj(v[3])]), cols])
	quads.sort_custom(func(x, y): return float(x[0]) > float(y[0]))
	for qd in quads:
		var poly: PackedVector2Array = qd[1]
		if Geometry2D.triangulate_polygon(poly).size() > 0:
			d.draw_polygon(poly, qd[2])
	# flecks of mineral on its face
	for k in 40:
		var th: float = TAU * h01(k * 3 + 300)
		var ph: float = PI * 0.5 * (0.15 + 0.8 * h01(k * 3 + 301))
		var fp: Vector3 = _stone_pt(c, r, th, ph)
		if (fp - c).dot(eye - fp) <= 0.0:
			continue
		var dark: bool = h01(k * 3 + 302) > 0.45
		d.draw_circle(_proj(fp), (0.25 + 0.35 * h01(k + 310)) * _px(fp), Color(0.20, 0.19, 0.17, 0.45) if dark else Color(0.92, 0.90, 0.84, 0.40))
	# bedded in the soil: a soft line of shade where it meets the ground, the soil a little heaped at its foot
	var foot: PackedVector2Array = PackedVector2Array()
	for k in 29:
		var th3: float = PI * float(k) / 28.0
		foot.append(_proj(_stone_pt(c, r, th3, 0.0) + Vector3(0.0, 0.2, 0.0)))
	d.draw_polyline(foot, Color(0.18, 0.13, 0.08, 0.55), maxf(1.0, 0.25 * _px(c)), true)
	d.draw_polyline(foot, Color(AntsArt.SOIL_LIGHT, 0.35), maxf(1.0, 0.12 * _px(c)) * 3.0, true)

func _twig(d: CanvasItem, a: Vector3, b: Vector3, r: float) -> void:
	var axis: Vector3 = (b - a).normalized()
	var side: Vector3 = axis.cross(Vector3.UP).normalized()
	_ground_disc(d, (a + b) * 0.5 + Vector3(2.0, 0.0, 3.0), (b - a).length() * 0.5, Color(0.0, 0.0, 0.0, 0.0))
	# its shadow: a band beside it on the soil
	var sh: PackedVector2Array = PackedVector2Array([_proj(a + side * r + Vector3(1.5, 0, 2)), _proj(b + side * r + Vector3(1.5, 0, 2)), _proj(b - side * r * 0.2 + Vector3(4, 0, 5)), _proj(a - side * r * 0.2 + Vector3(4, 0, 5))])
	_safe(d, sh, Color(0.0, 0.0, 0.0, 0.22))
	# a cylinder lying down: strips round its upper half, lit toward the sun
	var n: int = 6
	for k in n:
		var a0: float = PI * float(k) / float(n)
		var a1: float = PI * float(k + 1) / float(n)
		var o0: Vector3 = side * cos(a0) * r + Vector3.UP * (sin(a0) * r + r)
		var o1: Vector3 = side * cos(a1) * r + Vector3.UP * (sin(a1) * r + r)
		var lit: float = 0.5 + 0.5 * sin((a0 + a1) * 0.5)
		var q: PackedVector2Array = PackedVector2Array([_proj(a + o0), _proj(b + o0), _proj(b + o1), _proj(a + o1)])
		_safe(d, q, AntsArt.TWIG_DARK.lerp(AntsArt.TWIG_LIT, lit))
	# bark lines along it
	for k in 5:
		var u: float = 0.1 + 0.8 * h01(k + 700)
		var p0: Vector3 = a.lerp(b, u) + Vector3.UP * r * 1.9
		d.draw_line(_proj(p0), _proj(p0 + axis * 10.0), Color(AntsArt.TWIG_DARK, 0.6), 1.0)

# A FALLEN LEAF lying on the soil, its edges curling up a little: an outline pointed at both ends, a warm
# autumn color lit toward the sun, a midrib and veins, its shadow under the curl
func _leaf(d: CanvasItem, c: Vector3, ln: float, ang: float) -> void:
	var ax: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
	var sd: Vector3 = ax.cross(Vector3.UP).normalized()
	var n: int = 24
	var edge_a: Array = []
	var edge_b: Array = []
	for k in n + 1:
		var v: float = float(k) / float(n)
		var along: float = (v - 0.5) * ln
		var half_w: float = ln * 0.30 * sin(v * PI) * (1.0 - 0.25 * v)
		var curl: float = half_w * 0.22
		edge_a.append(c + ax * along + sd * half_w + Vector3.UP * curl)
		edge_b.append(c + ax * along - sd * half_w + Vector3.UP * curl * 1.4)
	var sh: PackedVector2Array = PackedVector2Array()
	for p3 in edge_a:
		sh.append(_proj(Vector3(p3.x + 2.5, 0.0, p3.z + 2.0)))
	for k in range(n, -1, -1):
		var p4: Vector3 = edge_b[k]
		sh.append(_proj(Vector3(p4.x + 2.5, 0.0, p4.z + 2.0)))
	if Geometry2D.triangulate_polygon(sh).size() > 0:
		d.draw_colored_polygon(sh, Color(0.0, 0.0, 0.0, 0.20))
	# the two halves, the sunward one lighter
	for half in 2:
		var edge: Array = edge_a if half == 0 else edge_b
		var poly: PackedVector2Array = PackedVector2Array()
		for k in n + 1:
			poly.append(_proj(c + ax * ((float(k) / float(n) - 0.5) * ln)))
		for k in range(n, -1, -1):
			poly.append(_proj(edge[k]))
		var col: Color = Color(0.80, 0.52, 0.18) if half == 0 else Color(0.66, 0.38, 0.12)
		if Geometry2D.triangulate_polygon(poly).size() > 0:
			d.draw_colored_polygon(poly, col)
		# veins from the midrib to the edge
		for k in range(3, n - 2, 3):
			var v2: float = float(k) / float(n)
			var m: Vector3 = c + ax * ((v2 - 0.5) * ln)
			var e: Vector3 = Vector3(edge[mini(k + 2, n)])
			d.draw_line(_proj(m), _proj(m.lerp(e, 0.85)), Color(0.52, 0.28, 0.08, 0.6), 1.0, true)
	d.draw_line(_proj(c - ax * ln * 0.62), _proj(c + ax * ln * 0.5), Color(0.50, 0.30, 0.10), 2.0, true)
	# a few spots of age
	for k in 4:
		var sp: Vector3 = c + ax * (h01(k + 40) - 0.5) * ln * 0.7 + sd * (h01(k + 41) - 0.5) * ln * 0.3
		_ground_disc(d, sp + Vector3(0, 1.0, 0), 1.2 + 1.5 * h01(k + 42), Color(0.42, 0.22, 0.06, 0.45))

func _safe(d: CanvasItem, q: PackedVector2Array, col: Color) -> void:
	var hull: PackedVector2Array = Geometry2D.convex_hull(q)
	if hull.size() < 4:
		return
	hull.remove_at(hull.size() - 1)
	if Geometry2D.triangulate_polygon(hull).size() > 0:
		d.draw_colored_polygon(hull, col)

func _ell(d: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	d.draw_set_transform(c, 0.0, Vector2(1.0, ry / maxf(rx, 0.001)))
	d.draw_circle(Vector2.ZERO, rx, col)
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- the ants ---------------------------------------------------------------------------------------------

# the mesh of one ant: a square per part, in the order they are drawn (UV: which part, which one of its kind)
func _ant_mesh() -> ArrayMesh:
	var parts: Array = [[0, 0]]
	for kind in [1, 2]:
		for sub in 6:
			parts.append([kind, sub])
	for slot in 3:
		for kind2 in [3, 4, 5]:
			parts.append([kind2, slot])
	parts.append([6, 0])
	for kind3 in [7, 8]:
		for sub2 in 2:
			parts.append([kind3, sub2])
	for sub3 in 4:
		parts.append([9, sub3])
	var verts: PackedVector2Array = PackedVector2Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var corners: Array = [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]
	for pt in parts:
		for idx in [0, 1, 2, 0, 2, 3]:
			verts.append(corners[idx])
			uvs.append(Vector2(float(pt[0]), float(pt[1])))
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var am: ArrayMesh = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am

# each frame: where every ant is, far to near, handed to the shader (ANT)
func _place_ants() -> void:
	if _cam.is_empty() or _life == null:
		return
	var mat: ShaderMaterial = _life.material
	mat.set_shader_parameter("eye", _c_eye)
	mat.set_shader_parameter("cf", _c_f)
	mat.set_shader_parameter("cr", _c_r)
	mat.set_shader_parameter("cu", _c_u)
	mat.set_shader_parameter("center", _c_center)
	mat.set_shader_parameter("focal", _c_focal)
	mat.set_shader_parameter("t", t)
	var ants: Array = []
	var spacing: float = _len / float(PER_WAY)
	for way in 2:
		for i in PER_WAY:
			var s: float = fposmod(t * SPEED + float(i) * spacing + float(way) * spacing * 0.5, _len)
			var dist: float = t * SPEED + float(i) * 37.0           # for the gait: how far it has walked
			if way == 1:
				s = _len - s                                         # going back to the food
			var a: Array = _along(s)
			var dir: Vector3 = a[1]
			if way == 1:
				dir = -dir
			# the two streams keep to their own side of the road
			var side: Vector3 = dir.cross(Vector3.UP).normalized()
			var p: Vector3 = Vector3(a[0]) + side * 4.5 + side * 2.0 * sin(s * 0.09 + float(i))
			# a wander in the heading too, eased
			dir = dir.rotated(Vector3.UP, 0.18 * sin(s * 0.07 + float(i) * 1.7))
			# fading into the nest's crater and out of the food heap
			var a_end: float = clampf(minf(s, _len - s) / 18.0, 0.0, 1.0)
			ants.append([_depth(p), p, dir, dist, way == 0, a_end, i])
	ants.sort_custom(func(x, y): return float(x[0]) > float(y[0]))
	var mm: MultiMesh = _life.multimesh
	for k in ants.size():
		var an: Array = ants[k]
		var p2: Vector3 = an[1]
		var d2: Vector3 = an[2]
		# the exact screen place of the ant's base, full precision (the shape is worked out relative to it)
		var base: Vector3 = p2 + Vector3(0.0, _ground_h(p2), 0.0)
		mm.set_instance_transform_2d(k, Transform2D(0.0, _proj(base)))
		mm.set_instance_custom_data(k, Color(p2.x, p2.z, atan2(d2.z, d2.x), fposmod(float(an[3]), STRIDE)))
		mm.set_instance_color(k, Color(float(int(an[6]) * 2 + (1 if an[4] else 0)), 0.0, 0.0, float(an[5])))

# the sun's warmth from the upper left, over everything below the title (still)
func _draw_warmth(d: Control) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	for k in 14:
		d.draw_circle(Vector2(full.x * 0.12, full.y * 0.18), full.x * (1.1 - 0.07 * float(k)), Color(1.0, 0.86, 0.52, 0.018))

# motes drifting in the sunlight (live)
func _draw_motes(d: Control) -> void:
	if _cam.is_empty():
		return
	for k in 16:
		var mp: Vector3 = Vector3(lerpf(-220.0, 220.0, h01(k + 900)) + 18.0 * sin(t * 0.21 + float(k)), 18.0 + 40.0 * h01(k + 901) + 8.0 * sin(t * 0.17 + float(k) * 2.0), lerpf(40.0, -500.0, h01(k + 902)))
		var mr: float = 0.6 * _px(mp)
		d.draw_circle(_proj(mp), mr * 2.5, Color(1.0, 0.95, 0.75, 0.10))
		d.draw_circle(_proj(mp), mr, Color(1.0, 0.97, 0.85, 0.55))

# --- in front of everything: big grass blades at the near corners, out of focus, swaying -----------------

func _draw_front(d: Control) -> void:
	if _cam.is_empty():
		return
	var blades: Array = [[-64.0, 0.0, 44.0, 0.16], [-60.0, 4.0, 56.0, 0.04], [-56.0, -2.0, 34.0, 0.26], [-68.0, -4.0, 50.0, -0.06], [-52.0, 2.0, 40.0, 0.10],
		[78.0, -6.0, 52.0, -0.16], [74.0, -2.0, 40.0, -0.05], [82.0, -10.0, 46.0, -0.26], [70.0, -8.0, 34.0, -0.10],
		[-60.0, -260.0, 36.0, 0.2], [-48.0, -270.0, 28.0, -0.3], [176.0, -470.0, 34.0, -0.2], [168.0, -490.0, 26.0, 0.3], [-170.0, -380.0, 30.0, 0.4]]
	for k in blades.size():
		var b: Array = blades[k]
		var root: Vector3 = Vector3(b[0], 0.0, b[1])
		var hgt: float = b[2]
		var lean: float = float(b[3]) + 0.06 * sin(t * 0.7 + float(k) * 1.3)
		var near: bool = float(b[1]) > -20.0
		var wid: float = 3.2 if near else 2.6
		var col: Color = Color(0.16, 0.30, 0.10) if near else Color(0.30, 0.46, 0.18)
		var lit: Color = Color(0.36, 0.56, 0.22) if near else Color(0.52, 0.68, 0.30)
		var left: PackedVector2Array = PackedVector2Array()
		var right: PackedVector2Array = PackedVector2Array()
		var n: int = 10
		for j in n + 1:
			var v: float = float(j) / float(n)
			var bend: float = lean * hgt * v * v
			var c: Vector3 = root + Vector3(bend, hgt * v * (1.0 - 0.15 * v * v), -bend * 0.2)
			var w: float = wid * (1.0 - v * 0.92)
			left.append(_proj(c + Vector3(-w * 0.5, 0.0, 0.0)))
			right.append(_proj(c + Vector3(w * 0.5, 0.0, 0.0)))
		right.reverse()
		var poly: PackedVector2Array = left + right
		if Geometry2D.triangulate_polygon(poly).size() > 0:
			d.draw_colored_polygon(poly, col)
		d.draw_polyline(left, lit, 1.5 if near else 1.0, true)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Ants", "Keep the colony from carrying the food home", Color(1.0, 0.92, 0.70), Color(0.14, 0.09, 0.03),
		Color(1.0, 0.85, 0.5, 0.25))

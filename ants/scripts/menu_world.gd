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
var _life: Control = null
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
	_life = _mk(func(d: Control) -> void: _draw_life(d))
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

func _proj(p: Vector3) -> Vector2:
	var v: Vector3 = p - _cam["eye"]
	var z: float = maxf(v.dot(_cam["f"]), 1.0)
	return Vector2(_cam["center"]) + Vector2(v.dot(_cam["r"]), -v.dot(_cam["u"])) * float(_cam["focal"]) / z

# screen pixels per world unit at a point
func _px(p: Vector3) -> float:
	return float(_cam["focal"]) / maxf((p - _cam["eye"]).dot(_cam["f"]), 1.0)

func _depth(p: Vector3) -> float:
	return (p - _cam["eye"]).dot(_cam["f"])

func _tick(_delta: float) -> void:
	_cam = _camera()
	if absf(scene_bottom - _for_bottom) > 0.5:
		_for_bottom = scene_bottom
		_ground.queue_redraw()
	_life.queue_redraw()
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
		_cam = _camera()
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

func _draw_life(d: Control) -> void:
	if _cam.is_empty():
		return
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
	for an in ants:
		_ant(d, an[1], an[2], an[3], an[4], an[5], int(an[6]))
	# the sun's warmth from the upper left, over everything below the title
	var full: Vector2 = _cam["full"]
	for k in 14:
		d.draw_circle(Vector2(full.x * 0.12, full.y * 0.18), full.x * (1.1 - 0.07 * float(k)), Color(1.0, 0.86, 0.52, 0.018))
	# motes drifting in the sunlight
	for k in 16:
		var mp: Vector3 = Vector3(lerpf(-220.0, 220.0, h01(k + 900)) + 18.0 * sin(t * 0.21 + float(k)), 18.0 + 40.0 * h01(k + 901) + 8.0 * sin(t * 0.17 + float(k) * 2.0), lerpf(40.0, -500.0, h01(k + 902)))
		var mr: float = 0.6 * _px(mp)
		d.draw_circle(_proj(mp), mr * 2.5, Color(1.0, 0.95, 0.75, 0.10))
		d.draw_circle(_proj(mp), mr, Color(1.0, 0.97, 0.85, 0.55))

# ONE ANT, a 3-D model on the ground at `p` heading `fwd`
func _ant(d: CanvasItem, p: Vector3, fwd: Vector3, dist: float, carrying: bool, alpha: float, idx: int) -> void:
	if alpha <= 0.0:
		return
	var L: float = ANT_L
	var gh: float = _ground_h(p)
	var base: Vector3 = p + Vector3(0.0, gh, 0.0)
	# climbing the mound, it tips with the slope
	var ahead_h: float = _ground_h(p + fwd * 4.0)
	var pitch: float = atan2(ahead_h - gh, 4.0)
	var f: Vector3 = (fwd * cos(pitch) + Vector3.UP * sin(pitch)).normalized()
	var s: Vector3 = f.cross(Vector3.UP).normalized()
	var u: Vector3 = s.cross(f).normalized()
	var body_h: float = L * 0.22 + 0.3 * sin(dist / STRIDE * TAU * 2.0)     # a little bob with each step
	var thorax: Vector3 = base + u * body_h
	var head: Vector3 = thorax + f * L * 0.36 + u * L * 0.03
	var abdomen: Vector3 = thorax - f * L * 0.48 + u * L * 0.04
	var px: float = _px(base)
	var dark: Color = Color(AntsArt.ANT_BODY, alpha)
	var sheen: Color = Color(AntsArt.ANT_SHEEN, alpha)
	# its shadow on the soil, away from the sun
	var sh_off: Vector3 = Vector3(-SUN.x, 0.0, -SUN.z) * L * 0.25
	_ell_on_ground(d, base + sh_off - f * L * 0.1, f, s, L * 0.62, L * 0.22, Color(0.0, 0.0, 0.0, 0.22 * alpha))
	# THE LEGS: three a side, tripod gait -- front and back on one side step with the middle of the other.
	# A foot in stance is planted: it slides back relative to the body exactly as fast as the body goes on
	var hips: Array = [0.10, 0.0, -0.10]
	var reach_f: Array = [0.40, 0.04, -0.42]
	var amp: float = STRIDE * 0.6
	for sd in [-1.0, 1.0]:
		for li in 3:
			var ph: float = 0.0 if (li % 2 == 0) == (sd > 0.0) else 0.5
			var cyc: float = fposmod(dist / STRIDE + ph + float(idx) * 0.13, 1.0)
			var rel: float = 0.0
			var lift: float = 0.0
			if cyc < 0.6:
				rel = amp * (0.5 - cyc / 0.6)
			else:
				var w: float = (cyc - 0.6) / 0.4
				rel = amp * (-0.5 + smoothstep(0.0, 1.0, w))
				lift = sin(w * PI) * L * 0.12
			var hip: Vector3 = thorax + f * L * float(hips[li]) + s * sd * L * 0.06
			var foot: Vector3 = base + f * (L * float(reach_f[li]) + rel) + s * sd * L * 0.34 + Vector3.UP * lift
			foot.y = _ground_h(foot) + lift
			var knee: Vector3 = hip.lerp(foot, 0.42) + Vector3.UP * L * 0.17 + s * sd * L * 0.04
			var w1: float = maxf(1.0, 0.055 * L * px)
			d.draw_line(_proj(hip), _proj(knee), dark, w1, true)
			d.draw_line(_proj(knee), _proj(foot), dark, maxf(1.0, w1 * 0.7), true)
	# THE BODY: abdomen, waist, thorax, head -- each an ellipsoid, far parts first
	var parts: Array = [[abdomen, L * 0.34, L * 0.23, L * 0.21], [thorax, L * 0.20, L * 0.10, L * 0.10], [head, L * 0.17, L * 0.15, L * 0.13]]
	parts.sort_custom(func(x, y): return _depth(x[0]) > _depth(y[0]))
	for pt in parts:
		_ellipsoid(d, pt[0], f, s, u, pt[1], pt[2], pt[3], dark, sheen)
	d.draw_line(_proj(thorax - f * L * 0.12), _proj(abdomen + f * L * 0.22), dark, maxf(1.0, 0.06 * L * px), true)
	# THE ANTENNAE: up from the head, elbowed, feeling forward, waving
	for sd2 in [-1.0, 1.0]:
		var wave: float = sin(t * 5.0 + sd2 + float(idx)) * 0.25
		var root: Vector3 = head + f * L * 0.08 + u * L * 0.08 + s * sd2 * L * 0.04
		var elbow: Vector3 = root + u * L * 0.22 + f * L * 0.06 + s * sd2 * L * 0.05
		var tip: Vector3 = elbow + f * L * 0.30 + s * sd2 * L * (0.16 + wave * 0.3) - u * L * (0.06 + wave * 0.1)
		d.draw_line(_proj(root), _proj(elbow), dark, maxf(1.0, 0.04 * L * px), true)
		d.draw_line(_proj(elbow), _proj(tip), dark, maxf(1.0, 0.035 * L * px), true)
	# a green crumb held in the jaws
	if carrying:
		var crumb: Vector3 = head + f * L * 0.22 + u * L * 0.02
		_sphere(d, crumb, L * 0.16, Color(AntsArt.CRUMB, alpha), Color(AntsArt.FOOD_DARK, alpha))

# an ellipsoid along f (rf), s (rs) and u (ru): its silhouette is the hull of its three principal sections;
# shaded dark with a sheen toward the light
func _ellipsoid(d: CanvasItem, c: Vector3, f: Vector3, s: Vector3, u: Vector3, rf: float, rs: float, ru: float, dark: Color, sheen: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 16:
		var a: float = TAU * float(k) / 16.0
		pts.append(_proj(c + f * cos(a) * rf + s * sin(a) * rs))
		pts.append(_proj(c + f * cos(a) * rf + u * sin(a) * ru))
		pts.append(_proj(c + s * cos(a) * rs + u * sin(a) * ru))
	var hull: PackedVector2Array = Geometry2D.convex_hull(pts)
	if hull.size() >= 4:
		hull.remove_at(hull.size() - 1)
		if Geometry2D.triangulate_polygon(hull).size() > 0:
			d.draw_colored_polygon(hull, dark)
	# the sheen: a soft highlight on the upper, sunward side
	var hl: Vector3 = c + u * ru * 0.55 - s * rs * 0.25 + f * rf * 0.15
	var hp: Vector2 = _proj(hl)
	var hr: float = minf(rf, rs) * _px(c) * 0.55
	d.draw_circle(hp, hr, Color(sheen, sheen.a * 0.55))
	d.draw_circle(hp + Vector2(-hr * 0.2, -hr * 0.25), hr * 0.45, Color(0.72, 0.56, 0.42, sheen.a * 0.55))

func _ell_on_ground(d: CanvasItem, c: Vector3, f: Vector3, s: Vector3, rf: float, rs: float, col: Color) -> void:
	var f2: Vector3 = Vector3(f.x, 0.0, f.z).normalized()
	var s2: Vector3 = Vector3(s.x, 0.0, s.z).normalized()
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 16:
		var a: float = TAU * float(k) / 16.0
		pts.append(_proj(Vector3(c.x, _ground_h(c), c.z) + f2 * cos(a) * rf + s2 * sin(a) * rs))
	if Geometry2D.triangulate_polygon(pts).size() > 0:
		d.draw_colored_polygon(pts, col)

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

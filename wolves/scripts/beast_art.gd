extends Node2D

# THE ANIMALS -- the sheep, the dog and the wolves -- drawn by this one script, in ONE style, seen from
# above: a soft shadow on the grass, one dark outline of the same weight round every shape, flat fills
# lit from the top left of the screen (a lighter side and a darker side), and a real HEAD on each, set
# off from the body by its neck, with the ears and the tail that make each one what it is:
#
#   sheep  a fluffy cream fleece (a cloud of round tufts, each lit on its top left), a dark face with
#          two little ears sticking out sideways
#   dog    a border collie: black with a white ruff round the neck and a white blaze down the face to
#          a white muzzle, soft folded ears, a plumed tail with a white tip that WAGS (evenly)
#   wolf   gray with a darker saddle, broad shoulders, a long pointed snout with pale cheeks, tall
#          upright ears, amber eyes, a thick bushy tail with a dark tip, held low and swaying slowly
#
# A child of the animal's `Head` node, so the head's rotation steers it and its scale tweens (bark,
# eat, scare) still play; the head's own sprite is made invisible (self_modulate), not removed. Drawn
# facing +x, in level pixels (the head's scale is undone).
#
# History: the sheep were a sprite (an egg with fleece dashes) while the dog and wolves were drawn, in
# two attempts that never matched it ("the wolves look like mice"); all three are drawn here now.

var kind: String = "dog"

var _t: float = 0.0
var _tufts: Array = []          # sheep: [offset, radius] per tuft of fleece

const SIZE: float = 0.86            # all three drawn at this scale of the numbers below
const BEAST_SIZE: float = 1.22      # and the dog and the wolf at this much more
const OUTLINE: Color = Color(0.07, 0.06, 0.07)
const OUT_W: float = 1.4
const SHADOW: Color = Color(0.0, 0.05, 0.0, 0.22)
const FLEECE: Color = Color(0.97, 0.95, 0.89)
const FLEECE_SHADE: Color = Color(0.80, 0.78, 0.76)
const SHEEP_FACE: Color = Color(0.20, 0.18, 0.18)
const DOG_COAT: Color = Color(0.12, 0.12, 0.14)
const DOG_SHEEN: Color = Color(0.32, 0.32, 0.36)
const DOG_WHITE: Color = Color(0.97, 0.96, 0.93)
const WOLF_COAT: Color = Color(0.58, 0.57, 0.55)
const WOLF_LIGHT: Color = Color(0.74, 0.73, 0.70)
const WOLF_SADDLE: Color = Color(0.34, 0.33, 0.33)
const WOLF_PALE: Color = Color(0.88, 0.86, 0.82)
const WOLF_EYE: Color = Color(0.98, 0.72, 0.16)

func _ready() -> void:
	var hs: Vector2 = (get_parent() as Node2D).scale
	# the dog and the wolf drawn larger, uniformly, so they stand as tall on the field as a sheep
	var k: float = SIZE * (1.0 if kind == "sheep" else BEAST_SIZE)
	scale = Vector2(k / maxf(hs.x, 0.001), k / maxf(hs.y, 0.001))
	if kind == "sheep":
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = get_instance_id()
		# a THICK fleece: two rings of tufts round the rim, and more inside, each bigger than before
		var n: int = 14
		for i in n:
			var a: float = TAU * float(i) / float(n) + rng.randf_range(-0.10, 0.10)
			_tufts.append([Vector2(cos(a) * 13.5, sin(a) * 10.0), rng.randf_range(4.8, 6.0)])
		for i in 9:
			var a2: float = TAU * float(i) / 9.0 + rng.randf_range(-0.2, 0.2)
			_tufts.append([Vector2(cos(a2) * 7.5, sin(a2) * 5.0), rng.randf_range(4.6, 5.6)])
		for i in 3:
			_tufts.append([Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-2.0, 2.0)), rng.randf_range(4.8, 5.8)])

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

# Which way the light falls in THIS node's space (the light is fixed on the screen).
func _light_dir() -> Vector2:
	return Vector2(-0.6, -0.8).rotated(-global_rotation)

# A smooth closed shape from a side profile: `prof` is [[x, half_width], ...] from tail to nose; the
# outline runs down one side and back up the other.
func _profile(prof: Array) -> PackedVector2Array:
	var top: PackedVector2Array = PackedVector2Array()
	var bot: PackedVector2Array = PackedVector2Array()
	var steps: int = 6
	for i in prof.size() - 1:
		var a: Array = prof[i]
		var b: Array = prof[i + 1]
		for k in steps:
			var u: float = float(k) / float(steps)
			var su: float = u * u * (3.0 - 2.0 * u)
			var x: float = lerpf(float(a[0]), float(b[0]), u)
			var hw: float = lerpf(float(a[1]), float(b[1]), su)
			top.append(Vector2(x, -hw))
			bot.append(Vector2(x, hw))
	var last: Array = prof[prof.size() - 1]
	top.append(Vector2(float(last[0]), -float(last[1])))
	bot.append(Vector2(float(last[0]), float(last[1])))
	var out: PackedVector2Array = top
	for i in range(bot.size() - 1, -1, -1):
		out.append(bot[i])
	return out

# A rounded body part along x from x0 (back) to x1 (front): half-width w at its widest, which falls
# `peak` of the way along; `power` < 1 makes it fuller, the ends always round.
func _shape(x0: float, x1: float, w: float, peak: float, power: float) -> PackedVector2Array:
	var k: float = log(0.5) / log(clampf(peak, 0.05, 0.95))
	var top: PackedVector2Array = PackedVector2Array()
	var bot: PackedVector2Array = PackedVector2Array()
	var n: int = 28
	for i in n + 1:
		var t: float = float(i) / float(n)
		var hw: float = w * pow(maxf(0.0, sin(PI * pow(t, k))), power)
		var x: float = lerpf(x0, x1, t)
		top.append(Vector2(x, -hw))
		bot.append(Vector2(x, hw))
	var out: PackedVector2Array = top
	for i in range(bot.size() - 2, 0, -1):
		out.append(bot[i])
	return out

# A tapered stroke round a polyline: half-width widths[i] at points[i] (a tail).
func _tapered(points: PackedVector2Array, widths: Array) -> PackedVector2Array:
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	var n: int = points.size()
	for i in n:
		var a: Vector2 = points[maxi(0, i - 1)]
		var b: Vector2 = points[mini(n - 1, i + 1)]
		var along: Vector2 = (b - a).normalized()
		var nrm: Vector2 = Vector2(-along.y, along.x)
		left.append(points[i] + nrm * float(widths[i]))
		right.append(points[i] - nrm * float(widths[i]))
	var out: PackedVector2Array = left
	# a round end at the tip
	var tip: Vector2 = points[n - 1]
	var dirv: Vector2 = (points[n - 1] - points[n - 2]).normalized()
	var r: float = float(widths[n - 1])
	for k in range(1, 6):
		var a2: float = PI * float(k) / 6.0
		out.append(tip + Vector2(-dirv.y, dirv.x).rotated(-a2) * r)
	for i in range(n - 1, -1, -1):
		out.append(right[i])
	return out

func _outlined(pts: PackedVector2Array, col: Color) -> void:
	draw_colored_polygon(pts, col)
	var ring: PackedVector2Array = pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, OUTLINE, OUT_W, true)

func _shadow_of(pts: PackedVector2Array) -> void:
	var down: Vector2 = Vector2(1.6, 2.6).rotated(-global_rotation)
	var moved: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in pts:
		moved.append(p + down)
	draw_colored_polygon(moved, SHADOW)

func _ellipse(c: Vector2, rx: float, ry: float, rot: float = 0.0) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 24:
		var a: float = TAU * float(i) / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts

func _draw() -> void:
	match kind:
		"sheep":
			_draw_sheep()
		"wolf":
			_draw_wolf()
		_:
			_draw_dog()

# --- sheep --------------------------------------------------------------------------------------

func _draw_sheep() -> void:
	var lit: Vector2 = _light_dir()
	var head_c: Vector2 = Vector2(19.5, 0.0)
	var head: PackedVector2Array = _profile([[13.5, 3.8], [17.0, 4.6], [21.0, 4.1], [24.0, 2.6], [25.5, 0.9]])
	# shadow: the fleece and the head together
	_shadow_of(_ellipse(Vector2.ZERO, 19.0, 15.0))
	_shadow_of(head)
	# the fleece: every tuft outlined first (a scalloped edge), then filled in its shade, then lit
	for tf: Array in _tufts:
		draw_circle(tf[0], float(tf[1]) + OUT_W, OUTLINE, true, -1.0, true)
	for tf: Array in _tufts:
		draw_circle(tf[0], float(tf[1]), FLEECE_SHADE, true, -1.0, true)
	for tf: Array in _tufts:
		draw_circle((tf[0] as Vector2) + lit * float(tf[1]) * 0.22, float(tf[1]) * 0.80, FLEECE, true, -1.0, true)
	# a little curl in each tuft, so the wool reads as wool
	for tf: Array in _tufts:
		var c: Vector2 = (tf[0] as Vector2) - lit * float(tf[1]) * 0.15
		draw_arc(c, float(tf[1]) * 0.42, 0.6, 3.6, 8, Color(FLEECE_SHADE, 0.9), 0.9, true)
	# the dark face in front of the fleece, ears sticking out sideways behind it
	for s: float in [-1.0, 1.0]:
		_outlined(_ellipse(head_c + Vector2(-2.5, s * 5.4), 3.4, 1.7, s * 0.55), SHEEP_FACE)
	_outlined(head, SHEEP_FACE)
	for s2: float in [-1.0, 1.0]:
		draw_circle(head_c + Vector2(1.5, s2 * 2.3), 0.85, Color(0.95, 0.92, 0.85), true, -1.0, true)

# --- dog ----------------------------------------------------------------------------------------

# A tail as a curve, not a stick: each segment turns a little further than the one before (a natural
# curl to one side), and the wag is a WAVE travelling from the root to the tip, so the tail bends as it
# swings instead of pivoting rigidly at the root (a straight stroke with a white bulb on the end,
# swinging round its root, read as "a reverse pendulum").
func _wavy_tail(base: Vector2, length: float, curl: float, wag: float, speed: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array([base])
	var dir: float = PI
	var seg: float = length / 10.0
	for k in range(1, 11):
		var u: float = float(k) / 10.0
		dir = PI + curl * u + wag * sin(_t * speed - u * 3.2) * u
		pts.append(pts[k - 1] + Vector2.from_angle(dir) * seg)
	return pts

# Fur along both edges of a tail: small pointed tufts angled back toward the tip.
func _tail_tufts(pts: PackedVector2Array, widths: Array, col: Color, from_k: int) -> void:
	for k in range(from_k, pts.size() - 1):
		var along: Vector2 = (pts[k + 1] - pts[k]).normalized()
		var nrm: Vector2 = Vector2(-along.y, along.x)
		var w: float = float(widths[k])
		for sgn: float in [-1.0, 1.0]:
			# filled, with a thin dark edge only on the outside: at game size an outline all round
			# swallowed the tufts and they came out as black spikes
			var root: Vector2 = pts[k] + nrm * sgn * w * 0.5
			var tip: Vector2 = pts[k] + nrm * sgn * (w + 2.6) + along * 3.2
			var tri: PackedVector2Array = PackedVector2Array([root - along * 2.4, tip, root + along * 2.2])
			draw_colored_polygon(tri, col)
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2]]), Color(OUTLINE, 0.30), 0.6, true)

func _tail_points(base: Vector2, length: float, bend: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 9:
		var u: float = float(k) / 8.0
		pts.append(base + Vector2(-u * length, 0.0).rotated(bend * u))
	return pts

# ONE SILHOUETTE from tail root to nose: the body, the neck and the head are a single outlined shape,
# so the animal reads as one animal and not as a body with a head stuck on. `jag` roughens the
# outline between x0 and x1 into fur tufts (the wolf's ruff).
func _silhouette(prof: Array, jag_x0: float = 0.0, jag_x1: float = 0.0, jag: float = 0.0) -> PackedVector2Array:
	var pts: PackedVector2Array = _profile(prof)
	if jag > 0.0:
		var c: int = 0
		for k in pts.size():
			var x: float = pts[k].x
			if x > jag_x0 and x < jag_x1:
				var sgn: float = signf(pts[k].y)
				pts[k] += Vector2(-0.8, sgn * jag) if c % 2 == 0 else Vector2.ZERO
				c += 1
	return pts

func _draw_dog() -> void:
	var lit: Vector2 = _light_dir()
	# a border collie from above: a long even body, a slight waist, a neck, a domed skull and a
	# tapering muzzle -- one outline
	var body: PackedVector2Array = _silhouette([[-17.0, 4.6], [-14.0, 8.0], [-7.0, 8.6], [0.0, 8.0], [5.0, 8.8],
		[9.5, 6.6], [12.0, 5.2], [14.5, 6.0], [18.0, 5.6], [21.0, 3.6], [24.0, 2.4], [25.5, 0.9]])
	_shadow_of(body)
	# the tail: a long feathered plume curving to one side, the wag a wave along it, the tip white
	var tail: PackedVector2Array = _wavy_tail(Vector2(-15.5, 0.0), 19.0, 0.6, 0.55, 9.0)
	var tw: Array = [2.6, 3.0, 3.3, 3.5, 3.5, 3.4, 3.1, 2.7, 2.2, 1.7, 1.2]
	_tail_tufts(tail, tw, DOG_COAT, 3)
	_outlined(_tapered(tail, tw), DOG_COAT)
	var tip: PackedVector2Array = PackedVector2Array()
	var tipw: Array = []
	for k in range(7, 11):
		tip.append(tail[k])
		tipw.append(float(tw[k]) - 0.3)
	draw_colored_polygon(_tapered(tip, tipw), DOG_WHITE)
	_outlined(body, DOG_COAT)
	# a sheen along the back on the lit side
	draw_colored_polygon(_ellipse(Vector2(-4.0, 0.0) + lit * 2.8, 8.5, 2.4), DOG_SHEEN)
	# the white collar round the neck, wider underneath (on both flanks), and the blaze to the muzzle
	draw_colored_polygon(_silhouette([[6.0, 6.0], [8.5, 8.0], [11.0, 6.0], [13.5, 3.2]]), DOG_WHITE)
	draw_colored_polygon(_silhouette([[13.0, 0.9], [18.0, 1.3], [21.5, 2.6], [24.5, 2.0], [25.4, 0.7]]), DOG_WHITE)
	# soft ears folded forward over the sides of the skull
	for s: float in [-1.0, 1.0]:
		_outlined(PackedVector2Array([Vector2(13.5, s * 4.0), Vector2(16.5, s * 7.4), Vector2(17.8, s * 5.0)]), DOG_COAT)
	for s2: float in [-1.0, 1.0]:
		var ep: Vector2 = Vector2(18.6, s2 * 3.0)
		draw_circle(ep, 1.3, Color(0.62, 0.40, 0.16), true, -1.0, true)
		draw_circle(ep, 0.6, OUTLINE, true, -1.0, true)
	draw_circle(Vector2(25.0, 0.0), 1.5, OUTLINE, true, -1.0, true)

# --- wolf ---------------------------------------------------------------------------------------

func _draw_wolf() -> void:
	# a gray wolf from above: lean flanks, heavy SHAGGY shoulders and neck (the ruff, as a rough
	# outline), a broad skull, a long narrow muzzle -- one outline -- with tall pointed ears, a dark
	# saddle and mask, amber eyes and a long bushy tail held low
	var lit: Vector2 = _light_dir()
	var body: PackedVector2Array = _silhouette([[-17.0, 4.4], [-13.0, 7.0], [-6.0, 7.4], [1.0, 8.2], [6.0, 10.0],
		[10.5, 9.2], [13.0, 6.6], [15.5, 6.8], [19.0, 5.4], [23.0, 3.0], [28.0, 1.8], [30.0, 0.7]])
	_shadow_of(body)
	# the RUFF: shaggy tufts standing out round the shoulders and neck, filled in the coat's color
	for sgn: float in [-1.0, 1.0]:
		var edge: PackedVector2Array = PackedVector2Array()
		var ew: Array = []
		for k in 7:
			var x: float = lerpf(2.0, 13.0, float(k) / 6.0)
			var hw: float = 8.2 + 1.8 * sin(PI * float(k) / 6.0)
			edge.append(Vector2(x, sgn * hw * 0.55))
			ew.append(hw * 0.45)
		_tail_tufts(edge, ew, WOLF_COAT, 0)
	var tail: PackedVector2Array = _wavy_tail(Vector2(-15.5, 0.0), 21.0, 0.15, 0.12, 2.4)
	var tw: Array = [2.2, 3.4, 4.6, 5.4, 5.8, 5.8, 5.4, 4.7, 3.8, 2.8, 1.6]
	_tail_tufts(tail, tw, WOLF_COAT, 2)
	_outlined(_tapered(tail, tw), WOLF_COAT)
	var tip: PackedVector2Array = PackedVector2Array()
	var tipw: Array = []
	for k in range(8, 11):
		tip.append(tail[k])
		tipw.append(float(tw[k]) - 0.4)
	draw_colored_polygon(_tapered(tip, tipw), WOLF_SADDLE.darkened(0.45))
	_outlined(body, WOLF_COAT)
	draw_colored_polygon(_ellipse(Vector2(-2.0, 0.0) + lit * 3.0, 10.0, 3.6), WOLF_LIGHT)
	# the dark saddle along the back, running up the neck into the mask between the eyes
	draw_colored_polygon(_silhouette([[-13.0, 1.5], [-6.0, 3.8], [3.0, 4.6], [10.0, 3.2], [16.0, 2.6], [22.0, 1.4], [24.0, 0.4]]), WOLF_SADDLE)
	# pale cheeks and the pale front of the muzzle
	for s3: float in [-1.0, 1.0]:
		draw_colored_polygon(_ellipse(Vector2(18.5, s3 * 3.6), 3.0, 1.5, s3 * 0.25), WOLF_PALE)
	draw_colored_polygon(_silhouette([[22.5, 2.4], [26.0, 1.9], [29.6, 0.8]]), WOLF_PALE)
	# tall pointed ears standing up from the back of the skull
	for s: float in [-1.0, 1.0]:
		var e0: Vector2 = Vector2(17.5, s * 2.6)
		var e1: Vector2 = Vector2(13.0, s * 4.6)
		var tip_e: Vector2 = Vector2(13.5, s * 10.2)
		_outlined(PackedVector2Array([e0, tip_e, e1]), WOLF_SADDLE)
		draw_colored_polygon(PackedVector2Array([e0.lerp(tip_e, 0.3), tip_e.lerp(Vector2(15.0, s * 3.6), 0.25),
			e1.lerp(tip_e, 0.25)]), WOLF_PALE)
	for s2: float in [-1.0, 1.0]:
		var ep: Vector2 = Vector2(20.0, s2 * 2.9)
		draw_colored_polygon(_ellipse(ep, 1.6, 0.85, s2 * 0.45), WOLF_EYE)
		draw_colored_polygon(_ellipse(ep + Vector2(0.25, 0.0), 0.45, 0.7), OUTLINE)
	draw_colored_polygon(_ellipse(Vector2(29.4, 0.0), 1.5, 1.7), OUTLINE)

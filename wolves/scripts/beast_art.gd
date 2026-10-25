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
# the dog and the wolf are drawn a little longer and much broader than their numbers say, so they
# stand as large on the field as a sheep (drawn as numbered, they were half a sheep's width)
const BEAST_STRETCH: Vector2 = Vector2(1.08, 1.40)
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
	scale = Vector2(SIZE / maxf(hs.x, 0.001), SIZE / maxf(hs.y, 0.001))
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
			draw_set_transform(Vector2.ZERO, 0.0, BEAST_STRETCH)
			_draw_wolf()
		_:
			draw_set_transform(Vector2.ZERO, 0.0, BEAST_STRETCH)
			_draw_dog()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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

func _tail_points(base: Vector2, length: float, bend: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 9:
		var u: float = float(k) / 8.0
		pts.append(base + Vector2(-u * length, 0.0).rotated(bend * u))
	return pts

func _draw_dog() -> void:
	var lit: Vector2 = _light_dir()
	# a dog's body is long and even -- hips nearly as broad as the chest -- not a teardrop (that, with
	# a round head on the narrow end turned forward, read as "a reverse pendulum")
	var body: PackedVector2Array = _shape(-16.0, 13.0, 8.4, 0.55, 0.28)
	var head: PackedVector2Array = _shape(8.5, 25.0, 6.2, 0.36, 0.55)
	_shadow_of(body)
	_shadow_of(head)
	# the tail, plumed (fullest in the middle), wagging the same amount to each side
	var tail: PackedVector2Array = _tail_points(Vector2(-12.0, 0.0), 14.0, sin(_t * 9.0) * 0.45)
	var tw: Array = [2.6, 3.4, 4.0, 4.3, 4.3, 4.0, 3.5, 2.8, 2.0]
	_outlined(_tapered(tail, tw), DOG_COAT)
	var tip: PackedVector2Array = PackedVector2Array()
	var tipw: Array = []
	for k in range(5, 9):
		tip.append(tail[k])
		tipw.append(float(tw[k]) - 0.4)
	draw_colored_polygon(_tapered(tip, tipw), DOG_WHITE)
	_outlined(body, DOG_COAT)
	# a sheen along the back on the lit side
	var sheen: PackedVector2Array = _shape(-10.0, 6.0, 2.6, 0.5, 0.8)
	for k in sheen.size():
		sheen[k] += lit * 2.6
	draw_colored_polygon(sheen, DOG_SHEEN)
	# the white ruff round the neck
	_outlined(_shape(2.5, 13.0, 9.2, 0.55, 0.35), DOG_WHITE)
	# folded ears, soft, at the back of the head
	for s: float in [-1.0, 1.0]:
		_outlined(_ellipse(Vector2(12.0, s * 6.2), 3.8, 2.5, s * 0.55), DOG_COAT)
	_outlined(head, DOG_COAT)
	# the blaze down the face, and the white muzzle
	draw_colored_polygon(_shape(11.5, 24.4, 3.0, 0.78, 0.7), DOG_WHITE)
	for s2: float in [-1.0, 1.0]:
		var ep: Vector2 = Vector2(16.0, s2 * 3.3)
		draw_circle(ep, 1.5, Color(0.62, 0.40, 0.16), true, -1.0, true)
		draw_circle(ep, 0.7, OUTLINE, true, -1.0, true)
		draw_circle(ep + Vector2(0.4, -0.4 * s2), 0.45, Color(1, 1, 1, 0.9), true, -1.0, true)
	draw_circle(Vector2(23.8, 0.0), 1.6, OUTLINE, true, -1.0, true)

# --- wolf ---------------------------------------------------------------------------------------

func _draw_wolf() -> void:
	var lit: Vector2 = _light_dir()
	var body: PackedVector2Array = _shape(-16.5, 13.0, 9.0, 0.62, 0.32)
	var head: PackedVector2Array = _shape(9.0, 28.0, 6.4, 0.26, 0.66)
	_shadow_of(body)
	_shadow_of(head)
	# the tail: thick and bushy, held low behind, swaying slowly, the tip dark
	var tail: PackedVector2Array = _tail_points(Vector2(-13.5, 0.0), 17.0, sin(_t * 2.4) * 0.15)
	var tw: Array = [3.4, 4.6, 5.4, 5.8, 5.8, 5.4, 4.8, 3.9, 2.8]
	_outlined(_tapered(tail, tw), WOLF_COAT)
	var tip: PackedVector2Array = PackedVector2Array()
	var tipw: Array = []
	for k in range(6, 9):
		tip.append(tail[k])
		tipw.append(float(tw[k]) - 0.5)
	draw_colored_polygon(_tapered(tip, tipw), WOLF_SADDLE.darkened(0.4))
	_outlined(body, WOLF_COAT)
	# the lit side of the coat, and the dark saddle along the back
	draw_colored_polygon(_ellipse(lit * 3.4, 10.5, 4.2), WOLF_LIGHT)
	draw_colored_polygon(_shape(-12.0, 10.0, 4.4, 0.55, 0.7), WOLF_SADDLE)
	# a shaggy RUFF of fur round the neck and shoulders: a ring of pointed tufts, the wolf's mane
	var ruff: PackedVector2Array = PackedVector2Array()
	var nr: int = 22
	for k in nr:
		var a: float = TAU * float(k) / float(nr)
		var rr: float = 11.4 if k % 2 == 0 else 9.4
		ruff.append(Vector2(6.0, 0.0) + Vector2(cos(a) * rr * 0.70, sin(a) * rr))
	_outlined(ruff, WOLF_COAT)
	# tall upright ears at the back of the head, broad at the base, pointing back and out
	for s: float in [-1.0, 1.0]:
		var e0: Vector2 = Vector2(16.0, s * 1.6)
		var e1: Vector2 = Vector2(9.5, s * 5.2)
		var tip_e: Vector2 = Vector2(6.5, s * 8.6)
		_outlined(PackedVector2Array([e0, tip_e, e1]), WOLF_SADDLE)
		draw_colored_polygon(PackedVector2Array([e0.lerp(tip_e, 0.3), tip_e.lerp(Vector2(12.0, s * 3.6), 0.35),
			e1.lerp(tip_e, 0.25)]), WOLF_PALE.darkened(0.12))
	_outlined(head, WOLF_COAT)
	# fur tufts sticking out at the cheeks
	for s3: float in [-1.0, 1.0]:
		_outlined(PackedVector2Array([Vector2(13.0, s3 * 5.6), Vector2(14.5, s3 * 8.6), Vector2(17.0, s3 * 5.4)]), WOLF_LIGHT)
	# pale cheeks and muzzle, a dark line down the forehead
	draw_colored_polygon(_shape(15.5, 27.8, 4.6, 0.30, 0.7), WOLF_PALE)
	draw_colored_polygon(_shape(10.5, 19.0, 1.5, 0.4, 0.8), WOLF_SADDLE)
	for s2: float in [-1.0, 1.0]:
		var ep: Vector2 = Vector2(16.5, s2 * 3.6)
		draw_colored_polygon(_ellipse(ep, 1.7, 1.05, s2 * 0.35), WOLF_EYE)
		draw_colored_polygon(_ellipse(ep + Vector2(0.2, 0.0), 0.5, 0.95), OUTLINE)
	draw_circle(Vector2(27.4, 0.0), 1.7, OUTLINE, true, -1.0, true)

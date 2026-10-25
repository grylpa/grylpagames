extends Node2D

# THE DOG AND THE WOLVES, drawn in the SHEEP'S style: the sheep are flat cartoon eggs seen from above --
# a white egg with a thin dark outline, fleece dashes and two dot eyes at the narrow end -- so the dog
# and the wolves are too: an egg body, narrower at the head end, the same thin outline, a few dashes
# of fur, dot eyes, and only what tells them apart. No legs or feet (from above they only cluttered).
# A child of the animal's `Head`, so the head's rotation steers it and its scale tweens (bark, eat,
# scare) still play; the head's own sprite is made invisible (self_modulate), not removed. Drawn
# facing +x, in level pixels (the head's scale is undone).
#
#   dog   a border collie: a black coat, a white blaze down the face to a white muzzle, a white ruff,
#         small folded ears, and a white-tipped tail that WAGS (evenly to both sides)
#   wolf  gray with a darker saddle, a longer, pointed head, upright pointed ears, amber eyes, and a
#         bushy dark-tipped tail that sways slowly
#
# They replaced a detailed shaded version (body, separate round head, striding paws) that did not
# belong with the sheep, and whose tail swung further to one side than the other.

var kind: String = "dog"

var _t: float = 0.0
var _fur: PackedVector2Array = PackedVector2Array()

const OUTLINE: Color = Color(0.06, 0.06, 0.07)
const DOG_COAT: Color = Color(0.13, 0.13, 0.15)
const DOG_WHITE: Color = Color(0.97, 0.96, 0.93)
const WOLF_COAT: Color = Color(0.60, 0.59, 0.56)
const WOLF_SADDLE: Color = Color(0.38, 0.37, 0.36)
const WOLF_PALE: Color = Color(0.86, 0.84, 0.80)
const WOLF_EYE: Color = Color(0.98, 0.74, 0.18)

func _ready() -> void:
	var hs: Vector2 = (get_parent() as Node2D).scale
	scale = Vector2(1.0 / maxf(hs.x, 0.001), 1.0 / maxf(hs.y, 0.001))
	# the fur dashes, fixed per animal (like the sheep's fleece)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7 if kind == "dog" else 11
	for i in 14:
		var u: float = rng.randf_range(-0.75, 0.45)
		var v: float = rng.randf_range(-0.6, 0.6)
		_fur.append(Vector2(u, v))

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

# The egg: an ellipse pinched toward its +x end (the head), as a polygon.
func _egg(rx: float, ry: float, pinch: float, at: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var n: int = 32
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var c: float = cos(a)
		pts.append(at + Vector2(c * rx, sin(a) * ry * (1.0 - pinch * c)))
	return pts

func _fill_outlined(pts: PackedVector2Array, col: Color, w: float = 1.3) -> void:
	draw_colored_polygon(pts, col)
	var ring: PackedVector2Array = pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, OUTLINE, w, true)

func _draw() -> void:
	var dog: bool = kind == "dog"
	var rx: float = 17.0 if dog else 18.5
	var ry: float = 10.5 if dog else 10.5
	var pinch: float = 0.28 if dog else 0.40
	var coat: Color = DOG_COAT if dog else WOLF_COAT

	# the tail first, so the body covers its root: a tapered stroke, wagging the same amount each way
	var wag: float = sin(_t * (9.0 if dog else 2.4)) * (0.45 if dog else 0.16)
	var base: Vector2 = Vector2(-rx * 0.85, 0.0)
	var tail_len: float = 11.0 if dog else 13.0
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 6:
		var u: float = float(k) / 5.0
		pts.append(base + Vector2(-u * tail_len, 0.0).rotated(wag * u))
	var tw: float = 4.6 if dog else 6.4
	draw_polyline(pts, OUTLINE, tw + 2.4, true)
	draw_polyline(pts, coat, tw, true)
	var tip_col: Color = DOG_WHITE if dog else WOLF_SADDLE.darkened(0.45)
	draw_polyline(PackedVector2Array([pts[3], pts[4], pts[5]]), tip_col, tw, true)
	draw_circle(pts[5], tw * 0.5 + 1.2, OUTLINE, true, -1.0, true)
	draw_circle(pts[5], tw * 0.5, tip_col, true, -1.0, true)

	# the ears, at the sides of the head end (drawn before the body, which overlaps their roots)
	for s: float in [-1.0, 1.0]:
		if dog:
			var e: PackedVector2Array = _egg(3.4, 2.4, 0.0, Vector2(rx * 0.42, s * ry * 0.62))
			_fill_outlined(e, DOG_COAT, 1.1)
		else:
			var tip: Vector2 = Vector2(rx * 0.18, s * (ry + 5.5))
			var e0: Vector2 = Vector2(rx * 0.50, s * ry * 0.30)
			var e1: Vector2 = Vector2(-rx * 0.05, s * ry * 0.50)
			_fill_outlined(PackedVector2Array([e0, tip, e1]), WOLF_SADDLE, 1.1)
			draw_colored_polygon(PackedVector2Array([e0.lerp(tip, 0.25), tip.lerp(Vector2(rx * 0.3, 0.0), 0.2), e1.lerp(tip, 0.25)]),
				WOLF_PALE.darkened(0.15))

	# the body
	var body: PackedVector2Array = _egg(rx, ry, pinch)
	_fill_outlined(body, coat)
	if dog:
		# the white ruff across the shoulders, and the blaze running forward from it to the muzzle
		draw_colored_polygon(_egg(2.6, ry * 0.86, 0.0, Vector2(rx * 0.18, 0.0)), DOG_WHITE)
		draw_colored_polygon(PackedVector2Array([Vector2(rx * 0.18, -1.6), Vector2(rx * 0.86, -1.1),
			Vector2(rx * 0.86, 1.1), Vector2(rx * 0.18, 1.6)]), DOG_WHITE)
		draw_colored_polygon(_egg(3.4, 3.0, 0.0, Vector2(rx * 0.84, 0.0)), DOG_WHITE)
	else:
		# the darker saddle along the back, and the pale muzzle
		draw_colored_polygon(_egg(rx * 0.55, ry * 0.42, 0.0, Vector2(-rx * 0.20, 0.0)), WOLF_SADDLE)
		draw_colored_polygon(_egg(4.2, 2.6, 0.3, Vector2(rx * 0.78, 0.0)), WOLF_PALE)
	# fur: short dashes, like the sheep's fleece
	var dash: Color = Color(1, 1, 1, 0.16) if dog else Color(0, 0, 0, 0.22)
	for f: Vector2 in _fur:
		var p: Vector2 = Vector2(f.x * rx, f.y * ry * (1.0 - pinch * f.x))
		draw_line(p, p + Vector2(2.4, 0.8 * signf(f.y)), dash, 1.0, true)
	# the outline again, so nothing above crosses it
	var ring: PackedVector2Array = body.duplicate()
	ring.append(body[0])
	draw_polyline(ring, OUTLINE, 1.3, true)

	# the eyes: dots, like the sheep's
	for s2: float in [-1.0, 1.0]:
		var ep: Vector2 = Vector2(rx * 0.55, s2 * ry * 0.30)
		if dog:
			draw_circle(ep, 1.9, OUTLINE, true, -1.0, true)
			draw_circle(ep + Vector2(0.5, -0.5), 0.6, Color(1, 1, 1, 0.9), true, -1.0, true)
		else:
			draw_circle(ep, 1.6, WOLF_EYE, true, -1.0, true)
			draw_circle(ep + Vector2(0.3, 0.0), 0.75, OUTLINE, true, -1.0, true)
	# the nose at the tip
	draw_circle(Vector2(rx * 0.97, 0.0), 1.7, OUTLINE, true, -1.0, true)

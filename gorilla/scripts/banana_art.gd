extends Node2D

# A BUNCH OF BANANAS lying in a maze cell for a few seconds (2026-11-09), somewhere away from the
# player, gone if no one gets there in time. Eating it fills the hunger ring right up (level.gd
# BANANA_FULL_MS), which pays for a trip far from the apples. It arrives quietly (a fade in) and blinks in its
# last second. Drawn in code: three curved fingers on a stem, lit from the upper left.

var size: float = 30.0
var life_ms: float = 6000.0
var born_ms: float = 0.0
var now_ms: float = 0.0

func _draw() -> void:
	var age: float = now_ms - born_ms
	var a: float = clampf(age / 400.0, 0.0, 1.0)
	if life_ms - age < 1000.0 and int(age / 120.0) % 2 == 0:
		a *= 0.35
	var s: float = size
	var stem: Vector2 = Vector2(-s * 0.12, -s * 0.42)
	draw_colored_polygon(_oval(Vector2(s * 0.08, s * 0.40), s * 0.40, s * 0.10), Color(0, 0, 0, 0.28 * a))
	# back to front, so the middle banana lies over the other two
	for k in [0, 2, 1]:
		_banana(stem, -0.45 + 0.45 * float(k), s, a, k)
	draw_line(stem, stem + Vector2(s * 0.02, -s * 0.12), Color(0.36, 0.28, 0.12, a), s * 0.10)
	draw_circle(stem + Vector2(s * 0.02, -s * 0.13), s * 0.055, Color(0.24, 0.19, 0.09, a))

# One banana hanging from the stem: an arc of a circle curving down and out, thickest in the middle,
# yellow with a lit outer edge and a dark tip; turned by `rot` to fan out from the others.
func _banana(stem: Vector2, rot: float, s: float, a: float, k: int) -> void:
	var radius: float = s * 0.95
	var sweep: float = 1.05
	var outer: PackedVector2Array = PackedVector2Array()
	var inner: PackedVector2Array = PackedVector2Array()
	var n: int = 12
	for q in n + 1:
		var t: float = float(q) / float(n)
		var phi: float = PI - sweep * t
		var c: Vector2 = Vector2(radius, 0.0)
		var p: Vector2 = c + Vector2(cos(phi), sin(phi)) * radius      # down and to the right
		var nrm: Vector2 = (p - c).normalized()
		var w: float = s * (0.03 + 0.12 * pow(sin(PI * t), 0.8))
		outer.append(stem + (p + nrm * w * 0.5).rotated(rot))
		inner.append(stem + (p - nrm * w * 0.5).rotated(rot))
	var pts: PackedVector2Array = outer.duplicate()
	var back: PackedVector2Array = inner.duplicate()
	back.reverse()
	pts.append_array(back)
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	var y: Color = Color(0.98, 0.84, 0.22, a).darkened(0.10 * float(k % 2 == 0))
	draw_colored_polygon(pts, y)
	draw_polyline(inner, Color(0.70, 0.52, 0.10, 0.7 * a), maxf(1.0, s * 0.025), true)
	draw_polyline(outer, Color(1.0, 0.96, 0.66, 0.85 * a), maxf(1.0, s * 0.03), true)
	draw_circle(outer[outer.size() - 1].lerp(inner[inner.size() - 1], 0.5), s * 0.035, Color(0.30, 0.22, 0.10, a))

func _oval(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 16:
		var t: float = TAU * float(k) / 16.0
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	return pts

# Half its drawn extent, for the tutorial's spotlight (it is drawn, so it has no sprite to measure).
func visual_half() -> Vector2:
	return Vector2(size * 0.55, size * 0.55)

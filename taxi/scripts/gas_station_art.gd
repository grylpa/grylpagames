extends Node2D

# The drawn GAS STATION (taxi's refuel dock): the old icon's idea, which read at a glance -- a bold
# yellow sign with a black fuel pump -- redrawn in the app's style: a rounded plate lit from the top
# left with a bevel, a dark rim and a soft shadow, and a crisp pump with its window, hose and
# nozzle. (A small drawn pump standing on a slab was tried and was much less readable, user
# 2026-10-29.) A child of the GasStation sprite (whose pixels are hidden), drawn in screen units at
# the size the old icon was shown at.

const PLATE: Color = Color(0.99, 0.80, 0.12)
const RIM: Color = Color(0.20, 0.14, 0.02)
const PUMP: Color = Color(0.08, 0.07, 0.06)
const HALF: float = 30.0


func _ready() -> void:
	var spr: Sprite2D = get_parent() as Sprite2D
	if spr != null:
		spr.self_modulate = Color(1, 1, 1, 0)
		scale = Vector2.ONE / spr.scale


func _rrect(r: Rect2, rad: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var cs: Array = [[Vector2(r.end.x - rad, r.position.y + rad), -PI * 0.5],
		[Vector2(r.end.x - rad, r.end.y - rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5],
		[Vector2(r.position.x + rad, r.position.y + rad), PI]]
	for c: Array in cs:
		for k in 6:
			var a: float = float(c[1]) + PI * 0.5 * float(k) / 5.0
			pts.append(Vector2(c[0]) + Vector2(cos(a), sin(a)) * rad)
	return pts


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = pts.duplicate()
	out.append(pts[0])
	return out


func _draw() -> void:
	var outer: Rect2 = Rect2(-HALF, -HALF, HALF * 2.0, HALF * 2.0)
	draw_colored_polygon(_rrect(Rect2(outer.position + Vector2(2.5, 3.5), outer.size), 9.0), Color(0, 0, 0, 0.35))
	# the plate: dark rim, then the yellow face lit from the top left
	draw_colored_polygon(_rrect(outer, 9.0), RIM)
	var face: Rect2 = outer.grow(-3.0)
	var pts: PackedVector2Array = _rrect(face, 7.0)
	var cols: PackedColorArray = PackedColorArray()
	for p: Vector2 in pts:
		var t: float = clampf((p / HALF).dot(Vector2(-0.6, -0.8)), -1.0, 1.0)
		cols.append(PLATE.lightened(0.25 * t) if t > 0.0 else PLATE.darkened(-0.18 * t))
	draw_polygon(pts, cols)
	draw_polyline(_closed(_rrect(face.grow(-2.5), 5.0)), Color(1, 1, 1, 0.35), 1.2, true)
	# the pump: body with a window, a base, the hose curling up to the nozzle on its side
	draw_colored_polygon(_rrect(Rect2(-15.0, -18.0, 19.0, 32.0), 3.0), PUMP)
	draw_colored_polygon(_rrect(Rect2(-18.0, 13.0, 25.0, 6.0), 1.5), PUMP)
	draw_colored_polygon(_rrect(Rect2(-11.5, -14.5, 12.0, 9.0), 1.5), PLATE.lightened(0.15))
	var hose: PackedVector2Array = PackedVector2Array()
	for k in 15:
		var u: float = float(k) / 14.0
		hose.append(Vector2(4.0 + u * 7.0 + sin(u * PI) * 2.0, 6.0 - u * 18.0 + sin(u * PI * 2.0) * 1.5))
	draw_polyline(hose, PUMP, 2.6, true)
	draw_colored_polygon(PackedVector2Array([Vector2(9.0, -15.0), Vector2(15.0, -18.5), Vector2(16.5, -15.5),
		Vector2(13.0, -10.0), Vector2(10.0, -10.5)]), PUMP)

class_name StormRoomArt
extends RefCounted

# Storm's FURNITURE, drawn (pipe.gd calls this from the draw callback it adds). The floor is a shader now
# (room_floor.gdshader).
#  - floor: a glazed ceramic tile per cell -- a face in near-white with a soft bevel and a grout
#    line -- drawn in grays so the room's color (the sprite's modulate) tints it. It was art/floor2.png,
#    a streaky texture that read as wet grass under the tint.
#  - furniture: a vase of flowers (flower), a television on its stand (screen) and a fringed rug (rug),
#    in their own colors. They were faint one-color icons at 30% opacity. Soaked (ruined) furniture
#    is drawn dark and dull with a water stain, which is what ruin_furniture used to do by tinting.

# (The room floors are drawn by storm/scripts/room_floor.gdshader since 2026-11-12; the floors drawn
# here -- marble, then boards, kitchen tiles and carpet -- are gone.)


static func _shade(c: Color, ruined: bool) -> Color:
	if not ruined:
		return c
	var g: float = (c.r + c.g + c.b) / 3.0
	return Color(lerpf(c.r, g, 0.7) * 0.5, lerpf(c.g, g, 0.7) * 0.5, lerpf(c.b, g, 0.7) * 0.58, c.a)


static func _rbox(r: Rect2, rad: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var cs: Array = [[Vector2(r.end.x - rad, r.position.y + rad), -PI * 0.5],
		[Vector2(r.end.x - rad, r.end.y - rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5],
		[Vector2(r.position.x + rad, r.position.y + rad), PI]]
	for c: Array in cs:
		for k in 5:
			var a: float = float(c[1]) + PI * 0.5 * float(k) / 4.0
			pts.append(Vector2(c[0]) + Vector2(cos(a), sin(a)) * rad)
	return pts


static func draw_furniture(ci: CanvasItem, kind: String, ruined: bool) -> void:
	var shadow: Color = Color(0, 0, 0, 0.28)
	match kind:
		"flower":
			# A POTTED PLANT seen from above (2026-11-12, one style with the other furniture: from above,
			# lit from the top left, on a soft shadow, outlined): a terracotta pot's rim, leaves spreading
			# out of it, flowers on top. It was a pot with flowers seen from the side.
			ci.draw_circle(Vector2(2.0, 3.0), 13.0, shadow, true, -1.0, true)
			ci.draw_circle(Vector2.ZERO, 10.5, _shade(Color(0.70, 0.36, 0.22), ruined), true, -1.0, true)
			ci.draw_circle(Vector2(-1.0, -1.0), 9.5, _shade(Color(0.82, 0.46, 0.30), ruined), true, -1.0, true)
			ci.draw_circle(Vector2.ZERO, 8.0, _shade(Color(0.24, 0.16, 0.10), ruined), true, -1.0, true)
			var leaf: Color = _shade(Color(0.24, 0.52, 0.26), ruined)
			var leaf_l: Color = _shade(Color(0.40, 0.70, 0.36), ruined)
			for k in 9:
				var a1: float = TAU * float(k) / 9.0 + 0.3
				var tip: Vector2 = Vector2(cos(a1), sin(a1)) * 13.5
				var sidev: Vector2 = Vector2(-sin(a1), cos(a1)) * 3.2
				ci.draw_colored_polygon(PackedVector2Array([Vector2(cos(a1), sin(a1)) * 2.0, tip * 0.55 + sidev, tip, tip * 0.55 - sidev]), leaf)
				ci.draw_line(Vector2(cos(a1), sin(a1)) * 2.0, tip * 0.92, leaf_l, 0.8, true)
			var petal: Array = [Color(0.95, 0.35, 0.45), Color(1.0, 0.80, 0.25), Color(0.92, 0.45, 0.75)]
			for i in 5:
				var a2: float = TAU * float(i) / 5.0
				var fc: Vector2 = Vector2(cos(a2), sin(a2)) * (4.5 if i % 2 == 0 else 6.5)
				for k2 in 5:
					var a3: float = TAU * float(k2) / 5.0
					ci.draw_circle(fc + Vector2(cos(a3), sin(a3)) * 1.9, 1.7, _shade(petal[i % 3], ruined), true, -1.0, true)
				ci.draw_circle(fc, 1.1, _shade(Color(1.0, 0.92, 0.50), ruined), true, -1.0, true)
			ci.draw_arc(Vector2.ZERO, 10.5, 0.0, TAU, 32, Color(0.12, 0.06, 0.04, 0.8), 0.8, true)
		"screen":
			# A TELEVISION ON ITS MEDIA CONSOLE, from above: from straight above a TV is a thin dark slab,
			# so it stands on a low wooden console, its screen's light falling forward across the top.
			ci.draw_colored_polygon(_rbox(Rect2(-13.0, -10.0, 30.0, 23.0), 2.0), shadow)
			var wood: Color = _shade(Color(0.40, 0.26, 0.15), ruined)
			ci.draw_colored_polygon(_rbox(Rect2(-15.0, -12.0, 30.0, 23.0), 2.0), wood)
			ci.draw_rect(Rect2(-15.0, -12.0, 30.0, 2.0), wood.lightened(0.22))
			ci.draw_rect(Rect2(-15.0, 9.0, 30.0, 2.0), wood.darkened(0.30))
			for gy: float in [-6.0, 0.0, 5.0]:
				ci.draw_line(Vector2(-13.0, gy), Vector2(13.0, gy + 0.6), Color(0.28, 0.17, 0.09, 0.5), 0.7, true)
			if not ruined:
				ci.draw_polygon(PackedVector2Array([Vector2(-11.0, -5.0), Vector2(11.0, -5.0), Vector2(14.0, 9.0), Vector2(-14.0, 9.0)]),
					PackedColorArray([Color(0.45, 0.70, 1.0, 0.35), Color(0.45, 0.70, 1.0, 0.35), Color(0.45, 0.70, 1.0, 0.0), Color(0.45, 0.70, 1.0, 0.0)]))
			ci.draw_colored_polygon(_rbox(Rect2(-12.0, -9.0, 24.0, 4.0), 1.0), _shade(Color(0.10, 0.10, 0.12), ruined))
			ci.draw_line(Vector2(-11.0, -5.2), Vector2(11.0, -5.2), Color(0.45, 0.70, 1.0) if not ruined else Color(0.15, 0.15, 0.16), 1.2)
			ci.draw_colored_polygon(_rbox(Rect2(-4.0, -5.0, 8.0, 3.0), 1.0), _shade(Color(0.18, 0.18, 0.20), ruined))
			ci.draw_rect(Rect2(6.0, 3.0, 5.0, 2.0), _shade(Color(0.15, 0.15, 0.17), ruined))           # the remote
			ci.draw_polyline(_rbox(Rect2(-15.0, -12.0, 30.0, 23.0), 2.0), Color(0.12, 0.06, 0.04, 0.8), 0.8, true)
		_:
			# A RUG filling its tile, lying flat: a border, a field, a round medallion, fringe at both ends
			ci.draw_colored_polygon(_rbox(Rect2(-12.5, -12.5, 28.0, 28.0), 1.5), shadow)
			var base: Color = _shade(Color(0.62, 0.18, 0.15), ruined)
			ci.draw_colored_polygon(_rbox(Rect2(-14.0, -13.0, 28.0, 26.0), 1.5), base)
			ci.draw_colored_polygon(_rbox(Rect2(-11.5, -10.5, 23.0, 21.0), 1.0), _shade(Color(0.92, 0.80, 0.55), ruined))
			ci.draw_colored_polygon(_rbox(Rect2(-10.0, -9.0, 20.0, 18.0), 1.0), _shade(Color(0.18, 0.26, 0.48), ruined))
			for c: Vector2 in [Vector2(-8.0, -7.0), Vector2(8.0, -7.0), Vector2(-8.0, 7.0), Vector2(8.0, 7.0)]:
				ci.draw_circle(c, 1.6, _shade(Color(0.92, 0.80, 0.55), ruined), true, -1.0, true)
			ci.draw_circle(Vector2.ZERO, 5.5, _shade(Color(0.92, 0.80, 0.55), ruined), true, -1.0, true)
			ci.draw_circle(Vector2.ZERO, 3.6, base, true, -1.0, true)
			ci.draw_circle(Vector2.ZERO, 1.6, _shade(Color(0.92, 0.80, 0.55), ruined), true, -1.0, true)
			for k in 9:
				var x: float = -12.0 + 3.0 * float(k)
				for y: float in [-13.0, 13.0]:
					ci.draw_line(Vector2(x, y), Vector2(x, y + signf(y) * 1.8), _shade(Color(0.95, 0.90, 0.80), ruined), 0.9, true)
			ci.draw_polyline(_rbox(Rect2(-14.0, -13.0, 28.0, 26.0), 1.5), Color(0.12, 0.06, 0.04, 0.6), 0.8, true)
	if ruined:
		# a water stain over it
		ci.draw_circle(Vector2(2.0, 1.0), 9.0, Color(0.20, 0.35, 0.55, 0.28), true, -1.0, true)

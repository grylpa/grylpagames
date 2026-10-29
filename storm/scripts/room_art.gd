class_name StormRoomArt
extends RefCounted

# Storm's FLOOR TILE and FURNITURE, drawn (pipe.gd calls these from the draw callbacks it adds).
#  - floor: a glazed ceramic tile per cell -- a face in near-white with a soft bevel and a grout
#    line -- drawn in grays so the room's color (the sprite's modulate) tints it. It was art/floor2.png,
#    a streaky texture that read as wet grass under the tint.
#  - furniture: a vase of flowers (flower), a television on its stand (screen) and a fringed rug (rug),
#    in their own colors. They were faint one-color icons at 30% opacity. Soaked (ruined) furniture
#    is drawn dark and dull with a water stain, which is what ruin_furniture used to do by tinting.

const GROUT: Color = Color(0.70, 0.70, 0.72)


static func draw_floor(ci: CanvasItem, half: float, cell: Vector2i) -> void:
	# A MARBLE FLOOR, in grays the room's color tints: every tile the same stone with only a slight
	# difference in tone (a checker of two tones was disliked, user 2026-10-29), soft natural veins
	# that run ACROSS tiles in the world (each tile draws its own piece of the same veins), and a
	# small inset where four tiles meet.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = cell.x * 7919 + cell.y * 104729 + 17
	var tone: float = 0.93 + rng.randf_range(-0.025, 0.025)
	var face_c: Color = Color(tone, tone, tone + 0.01)
	var r: Rect2 = Rect2(-half, -half, half * 2.0, half * 2.0)
	ci.draw_rect(r, GROUT)
	var face: Rect2 = r.grow(-0.7)
	ci.draw_rect(face, face_c)
	# soft clouding in the stone
	for k in 3:
		var cpos: Vector2 = Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		ci.draw_circle(cpos, rng.randf_range(6.0, 12.0), Color(0.80, 0.80, 0.82, 0.10), true, -1.0, true)
	# VEINS: smooth curves defined in WORLD space (a few long sweeping lines across the floor), so a
	# vein continues from tile to tile; drawn thin, soft and low in contrast, thinning at the ends
	var origin: Vector2 = Vector2(cell) * half * 2.0
	for vi in VEINS.size() * 5:
		var v: int = vi % VEINS.size()
		var repeat_y: float = float(vi / VEINS.size() - 2) * 340.0     # each vein again down the floor
		var vein: Array = VEINS[v]
		var pts: PackedVector2Array = PackedVector2Array()
		var x: float = origin.x - half
		while x <= origin.x + half + 0.1:
			var y: float = repeat_y + float(vein[0]) + float(vein[1]) * x + float(vein[2]) * sin(x * float(vein[3]) + float(vein[4])) \
				+ 2.0 * sin(x * 0.31 + float(v))
			pts.append(Vector2(x, y) - origin)
			x += 2.0
		var w: float = float(vein[5])
		var keep: PackedVector2Array = PackedVector2Array()
		for q: Vector2 in pts:
			if absf(q.y) <= half:
				keep.append(q)
			elif keep.size() > 1:
				ci.draw_polyline(keep, Color(0.55, 0.55, 0.60, 0.24), w, true)
				keep = PackedVector2Array()
			else:
				keep = PackedVector2Array()
		if keep.size() > 1:
			ci.draw_polyline(keep, Color(0.55, 0.55, 0.60, 0.24), w, true)
			ci.draw_polyline(keep, Color(0.45, 0.45, 0.50, 0.16), w * 0.4, true)
	# bevel
	ci.draw_line(face.position + Vector2(0.5, 0.6), Vector2(face.end.x - 0.5, face.position.y + 0.6),
		Color(1, 1, 1, 0.6), 1.0)
	ci.draw_line(Vector2(face.position.x + 1.0, face.end.y - 0.6), face.end - Vector2(0.5, 0.6),
		face_c.darkened(0.10), 1.0)
	# the inset where four tiles meet: each tile draws its own quarter of it at all four corners,
	# so a neighbor drawn later never covers it
	var k2: float = 3.0
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var c: Vector2 = Vector2(sx, sy) * half
			ci.draw_rect(Rect2(c, Vector2(-sx, -sy) * k2).abs(), Color(0.45, 0.45, 0.50))
			ci.draw_rect(Rect2(c + Vector2(-sx, -sy) * 0.8, Vector2(-sx, -sy) * (k2 - 1.6)).abs(), Color(0.62, 0.62, 0.66))


# The floor's veins, in board pixels: [offset, slope, wave amplitude, wave frequency, phase, width].
# Long gentle sweeps at different angles, with the odd fine one.
const VEINS: Array = [
	[60.0, 0.55, 18.0, 0.035, 0.0, 1.3],
	[260.0, -0.40, 24.0, 0.025, 1.7, 1.0],
	[-120.0, 0.95, 14.0, 0.05, 3.1, 0.8],
	[420.0, -0.85, 20.0, 0.03, 4.4, 1.2],
	[150.0, 0.15, 30.0, 0.02, 2.2, 0.7],
	[640.0, -0.20, 16.0, 0.045, 5.0, 0.9],
]


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
			# a vase of flowers, shown from the side: a glazed pot with flowers above it
			ci.draw_colored_polygon(_rbox(Rect2(-9.0, 7.0, 20.0, 6.0), 3.0), shadow)
			var pot: PackedVector2Array = PackedVector2Array([Vector2(-6.5, 0.0), Vector2(6.5, 0.0),
				Vector2(5.0, 11.0), Vector2(-5.0, 11.0)])
			ci.draw_colored_polygon(pot, _shade(Color(0.78, 0.40, 0.24), ruined))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-6.5, 0.0), Vector2(-2.5, 0.0), Vector2(-2.0, 11.0),
				Vector2(-5.0, 11.0)]), _shade(Color(0.88, 0.52, 0.34), ruined))
			ci.draw_colored_polygon(_rbox(Rect2(-7.5, -1.5, 15.0, 3.0), 1.2), _shade(Color(0.62, 0.30, 0.17), ruined))
			var stems: Array = [Vector2(-6.0, -11.0), Vector2(0.0, -14.0), Vector2(6.0, -10.0), Vector2(-2.5, -7.0), Vector2(3.5, -6.0)]
			for st: Vector2 in stems:
				ci.draw_line(Vector2(st.x * 0.3, -1.0), st, _shade(Color(0.22, 0.55, 0.26), ruined), 1.2, true)
			for sd: float in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(0.0, -2.0), Vector2(5.0 * sd, -6.0),
					Vector2(7.0 * sd, -3.0)]), _shade(Color(0.28, 0.64, 0.32), ruined))
			var petal: Array = [Color(0.95, 0.35, 0.45), Color(1.0, 0.80, 0.25), Color(0.92, 0.45, 0.75),
				Color(0.95, 0.35, 0.45), Color(1.0, 0.80, 0.25)]
			for i in stems.size():
				var fc: Vector2 = stems[i]
				for k in 5:
					var a3: float = TAU * float(k) / 5.0
					ci.draw_circle(fc + Vector2(cos(a3), sin(a3)) * 2.0, 1.7, _shade(petal[i], ruined), true, -1.0, true)
				ci.draw_circle(fc, 1.1, _shade(Color(1.0, 0.92, 0.50), ruined), true, -1.0, true)
		"screen":
			# a television on its low stand, seen from above at a slant: the screen face toward us
			ci.draw_colored_polygon(_rbox(Rect2(-14.0, -7.0, 31.0, 20.0), 3.0), shadow)
			ci.draw_colored_polygon(_rbox(Rect2(-8.0, 8.0, 16.0, 5.0), 1.5), _shade(Color(0.28, 0.28, 0.32), ruined))
			ci.draw_colored_polygon(_rbox(Rect2(-15.0, -10.0, 30.0, 19.0), 2.5), _shade(Color(0.12, 0.12, 0.14), ruined))
			var glass: Color = Color(0.20, 0.42, 0.62) if not ruined else Color(0.10, 0.12, 0.14)
			ci.draw_colored_polygon(_rbox(Rect2(-13.0, -8.0, 26.0, 15.0), 1.5), glass)
			if not ruined:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(-12.0, -7.0), Vector2(-3.0, -7.0),
					Vector2(-11.0, 4.0), Vector2(-12.0, 4.0)]), Color(1, 1, 1, 0.22))
			ci.draw_circle(Vector2(12.0, 7.5), 0.8, Color(0.3, 0.9, 0.4) if not ruined else Color(0.2, 0.2, 0.2), true, -1.0, true)
		_:
			# a rug with a border pattern and fringed ends
			# drawn at 1.3x: the rug and its fringe stay inside the tile, so a fringe never pokes into a
			# neighboring brick
			ci.draw_colored_polygon(_rbox(Rect2(-9.0, -12.0, 20.0, 26.0), 1.5), shadow)
			var base: Color = _shade(Color(0.66, 0.20, 0.16), ruined)
			ci.draw_colored_polygon(_rbox(Rect2(-10.0, -13.0, 20.0, 26.0), 1.5), base)
			ci.draw_colored_polygon(_rbox(Rect2(-7.0, -10.5, 14.0, 21.0), 1.0), _shade(Color(0.92, 0.80, 0.55), ruined))
			ci.draw_colored_polygon(_rbox(Rect2(-5.0, -8.5, 10.0, 17.0), 1.0), _shade(Color(0.20, 0.30, 0.52), ruined))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -5.5), Vector2(3.0, 0), Vector2(0, 5.5), Vector2(-3.0, 0)]),
				_shade(Color(0.92, 0.80, 0.55), ruined))
			for k in 6:
				var x: float = -8.5 + 3.4 * float(k)
				for y: float in [-13.0, 13.0]:
					ci.draw_line(Vector2(x, y), Vector2(x, y + signf(y) * 1.6), _shade(Color(0.95, 0.90, 0.80), ruined), 0.9, true)
	if ruined:
		# a water stain over it
		ci.draw_circle(Vector2(2.0, 1.0), 9.0, Color(0.20, 0.35, 0.55, 0.28), true, -1.0, true)

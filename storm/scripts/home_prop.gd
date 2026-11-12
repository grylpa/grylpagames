class_name StormHomeProp
extends Node2D

# WHAT BLOCKS A TILE IN THE HOUSE (2026-11-12): the three brick types became three pieces of household
# furniture -- a BOOKCASE, an ARMCHAIR and a CABINET -- seen from above like everything else, lit from
# the top left, each filling its whole tile (the water stops at the edge of a tile it cannot enter, and
# a margin showed a strip of floor between the two; the bricks were cropped to fill it for the same
# reason). pipe.gd puts one on a tile that `has_brick` (kind = has_brick % 3); the logic is unchanged:
# it is still a brick. A pile of bricks in a living room read as a building site.

enum Kind { BOOKCASE, ARMCHAIR, CABINET }

var kind: int = Kind.BOOKCASE
var half: float = 20.3          # a hair over the tile, so no seam shows against the water


func _draw() -> void:
	match kind:
		Kind.BOOKCASE:
			_bookcase()
		Kind.ARMCHAIR:
			_armchair()
		_:
			_cabinet()


func _box(r: Rect2, base: Color) -> void:
	draw_rect(r, base)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2.5)), base.lightened(0.22))
	draw_rect(Rect2(r.position, Vector2(2.0, r.size.y)), base.lightened(0.12))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2.5), Vector2(r.size.x, 2.5)), base.darkened(0.30))
	draw_rect(Rect2(r.position + Vector2(r.size.x - 2.0, 0), Vector2(2.0, r.size.y)), base.darkened(0.22))
	draw_rect(r, Color(0.12, 0.08, 0.05, 0.9), false, 1.0)


# a bookcase against nothing in particular, seen from above: its top in dark wood, and down its open
# front the tops of the books in a row, every one its own color and height
func _bookcase() -> void:
	var r: Rect2 = Rect2(-half, -half, half * 2.0, half * 2.0)
	_box(r, Color(0.36, 0.23, 0.13))
	var shelf: Rect2 = Rect2(-half + 3.0, -half * 0.15, half * 2.0 - 6.0, half * 1.05)
	draw_rect(shelf, Color(0.16, 0.10, 0.06))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 41
	var cols: Array = [Color(0.62, 0.16, 0.14), Color(0.16, 0.30, 0.52), Color(0.20, 0.42, 0.24), Color(0.78, 0.62, 0.22), Color(0.45, 0.18, 0.40), Color(0.85, 0.82, 0.74)]
	var x: float = shelf.position.x + 1.0
	while x < shelf.end.x - 2.0:
		var bw: float = rng.randf_range(2.6, 4.6)
		var bh: float = shelf.size.y * rng.randf_range(0.70, 0.95)
		var c: Color = cols[rng.randi() % cols.size()]
		var b: Rect2 = Rect2(x, shelf.end.y - bh, minf(bw, shelf.end.x - 1.0 - x), bh)
		draw_rect(b, c)
		draw_rect(Rect2(b.position, Vector2(b.size.x, 1.2)), c.lightened(0.25))
		x += bw + 0.4
	# the top's wood grain
	for k in 3:
		var gy: float = -half + 4.0 + float(k) * 3.0
		draw_line(Vector2(-half + 3.0, gy), Vector2(half - 3.0, gy + 0.6), Color(0.26, 0.16, 0.09, 0.6), 0.7)


# an armchair: a deep cushioned seat between two padded arms, the back rolled over at the top
func _armchair() -> void:
	var fabric: Color = Color(0.50, 0.24, 0.20)
	var r: Rect2 = Rect2(-half, -half, half * 2.0, half * 2.0)
	draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.30))
	_rounded(r, 6.0, fabric.darkened(0.20))
	_rounded(Rect2(-half, -half, half * 2.0, 11.0), 5.0, fabric.lightened(0.05))          # the back
	_rounded(Rect2(-half, -half + 6.0, 9.0, half * 2.0 - 6.0), 4.0, fabric)                # left arm
	_rounded(Rect2(half - 9.0, -half + 6.0, 9.0, half * 2.0 - 6.0), 4.0, fabric.darkened(0.08))
	_rounded(Rect2(-half + 9.5, -half + 11.0, half * 2.0 - 19.0, half * 2.0 - 13.0), 4.0, fabric.lightened(0.14))   # the seat
	draw_line(Vector2(-half + 11.0, -half + 12.5), Vector2(half - 11.0, -half + 12.5), Color(1, 1, 1, 0.25), 1.2)
	draw_line(Vector2(-half + 2.0, -half + 1.5), Vector2(half - 2.0, -half + 1.5), Color(1, 1, 1, 0.25), 1.2)
	# a cushion's button
	draw_circle(Vector2(0, 4), 1.4, fabric.darkened(0.35))


# a low cabinet: its top in pale painted wood with two doors' seams, two brass knobs, and a small
# lamp standing on it
func _cabinet() -> void:
	var r: Rect2 = Rect2(-half, -half, half * 2.0, half * 2.0)
	_box(r, Color(0.78, 0.74, 0.66))
	draw_line(Vector2(0, -half + 3.0), Vector2(0, half - 3.0), Color(0.45, 0.42, 0.37), 1.0)
	draw_rect(Rect2(-half + 3.0, -half + 3.0, half * 2.0 - 6.0, half * 2.0 - 6.0), Color(0.55, 0.52, 0.46), false, 0.8)
	for sx in [-1.0, 1.0]:
		draw_circle(Vector2(sx * 3.0, 6.0), 1.6, Color(0.80, 0.62, 0.25))
		draw_circle(Vector2(sx * 3.0 - 0.4, 5.6), 0.6, Color(1.0, 0.92, 0.65))
	# the lamp: its base, and the shade seen from above with the bulb's light in it
	var lc: Vector2 = Vector2(-7.0, -8.0)
	draw_circle(lc + Vector2(1.5, 2.0), 7.0, Color(0, 0, 0, 0.25))
	draw_circle(lc, 7.0, Color(0.93, 0.86, 0.66))
	draw_circle(lc, 4.0, Color(1.0, 0.95, 0.78))
	draw_arc(lc, 7.0, 0.0, TAU, 28, Color(0.55, 0.45, 0.28), 1.0, true)


func _rounded(r: Rect2, rad: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var rr: float = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var cs: Array = [[Vector2(r.end.x - rr, r.position.y + rr), -PI * 0.5], [Vector2(r.end.x - rr, r.end.y - rr), 0.0],
		[Vector2(r.position.x + rr, r.end.y - rr), PI * 0.5], [Vector2(r.position.x + rr, r.position.y + rr), PI]]
	for c: Array in cs:
		for k in 5:
			var a: float = float(c[1]) + PI * 0.5 * float(k) / 4.0
			pts.append(Vector2(c[0]) + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
	var closed: PackedVector2Array = pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color(0.12, 0.06, 0.05, 0.7), 1.0, true)

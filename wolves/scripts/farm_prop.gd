class_name WolvesFarmProp
extends Node2D

# WHAT BLOCKS A TILE ON THE FARM (2026-11-12): the three brick types became three farm things -- a HAY
# BALE, a BOULDER and a WATER TROUGH -- seen from above like the animals, lit from the top left, on a soft
# shadow, outlined. Bricks on a pasture read as a building site. pipe.gd puts one on a tile that
# `has_brick`; the logic is unchanged (still a brick, still blocks the tile).

enum Kind { HAY, BOULDER, TROUGH }

var kind: int = Kind.HAY
var seed_v: int = 0
const OUT: Color = Color(0.12, 0.08, 0.05, 0.85)


func _draw() -> void:
	match kind:
		Kind.HAY:
			_hay()
		Kind.BOULDER:
			_boulder()
		_:
			_trough()


# a round bale seen from above: a spiral of straw, its face lit on the top left
func _hay() -> void:
	draw_circle(Vector2(3.0, 4.0), 16.0, Color(0, 0, 0, 0.32))
	draw_circle(Vector2.ZERO, 16.0, Color(0.70, 0.56, 0.26))
	draw_circle(Vector2(-1.5, -1.5), 14.0, Color(0.84, 0.70, 0.36))
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 90:
		var a: float = float(i) * 0.28
		var r: float = 1.0 + float(i) * 0.155
		pts.append(Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts, Color(0.62, 0.48, 0.20, 0.8), 1.0, true)
	for k in 14:
		var a2: float = TAU * float(k) / 14.0
		draw_line(Vector2(cos(a2), sin(a2)) * 13.0, Vector2(cos(a2 + 0.1), sin(a2 + 0.1)) * 16.5, Color(0.92, 0.80, 0.45), 1.2, true)
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 40, OUT, 1.0, true)


# a gray boulder: an irregular lumpy outline, lit on its top left, a crack, a patch of lichen
func _boulder() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7 + seed_v
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 11:
		var a: float = TAU * float(i) / 11.0
		pts.append(Vector2(cos(a), sin(a)) * rng.randf_range(12.5, 16.5))
	var sh: PackedVector2Array = PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(3.0, 4.0))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.32))
	draw_colored_polygon(pts, Color(0.44, 0.44, 0.46))
	var lit: PackedVector2Array = PackedVector2Array()
	for p2 in pts:
		lit.append(p2 * 0.72 + Vector2(-2.5, -3.0))
	draw_colored_polygon(lit, Color(0.58, 0.58, 0.60))
	draw_line(Vector2(-4, -6), Vector2(2, 1), Color(0.28, 0.28, 0.30), 1.2, true)
	draw_line(Vector2(2, 1), Vector2(1, 7), Color(0.28, 0.28, 0.30), 1.0, true)
	draw_circle(Vector2(6, -4), 3.0, Color(0.60, 0.66, 0.40, 0.7))
	var closed: PackedVector2Array = pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, OUT, 1.0, true)


# a wooden water trough: a long box of planks with water in it catching the light
func _trough() -> void:
	var r: Rect2 = Rect2(-17, -10, 34, 20)
	draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.32))
	draw_rect(r, Color(0.46, 0.32, 0.18))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2.5)), Color(0.62, 0.46, 0.28))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2.5), Vector2(r.size.x, 2.5)), Color(0.32, 0.22, 0.12))
	var w: Rect2 = r.grow(-3.5)
	draw_rect(w, Color(0.16, 0.34, 0.42))
	draw_rect(Rect2(w.position, Vector2(w.size.x, w.size.y * 0.4)), Color(0.24, 0.46, 0.54))
	draw_line(w.position + Vector2(4, 3), w.position + Vector2(14, 3), Color(0.85, 0.95, 1.0, 0.7), 1.2)
	for x in [-6.0, 6.0]:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0.30, 0.20, 0.10, 0.7), 1.0)
	draw_rect(r, OUT, false, 1.0)

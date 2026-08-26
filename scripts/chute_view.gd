extends Control
class_name ChuteView

# The chute items fall down in bucketmadness.
#
# It was one flat-colored trapezoid — a single `Polygon2D` in one color, covering the largest part
# of the screen, with no edges, no depth and nothing moving in it. The objects falling through it
# were the only thing that ever changed.
#
# This draws it as a real chute: walls that darken toward the sides, rails down the slanted edges,
# a lip shadow under the mouth, and chevrons drifting downward so the chute reads as flowing the
# way the item is about to. The chevrons are the same idea as the belt tread in the other two
# sorting games, so the three look like one family.

const WALL_MID: Color = Color(0.086, 0.106, 0.149, 0.92)
const WALL_EDGE: Color = Color(0.031, 0.039, 0.059, 0.96)
const RAIL: Color = Color(0.322, 0.376, 0.475, 0.95)
const CHEVRON: Color = Color(0.322, 0.376, 0.475, 0.16)
const FLOOR_GLOW: Color = Color(0.392, 0.541, 0.741, 0.10)
const LIP: Color = Color(0.376, 0.431, 0.529)
const RIVET: Color = Color(0.541, 0.596, 0.694, 0.75)

const CHEVRON_GAP: float = 54.0
@export var speed: float = 26.0

# Set by the level: how far in from each side the chute's mouth starts.
var top_inset: float = 40.0:
	set(v):
		top_inset = v
		queue_redraw()

var _offset: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	_offset = fmod(_offset + speed * delta, CHEVRON_GAP)
	queue_redraw()

# Left and right wall x at a given depth 0..1, following the trapezoid.
func _edges(t: float) -> Vector2:
	return Vector2(lerpf(top_inset, 0.0, t), lerpf(size.x - top_inset, size.x, t))

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 10.0 or h < 10.0:
		return

	# Body, in vertical bands so the sides can darken toward the walls without a texture.
	var bands: int = 3
	for b in range(bands):
		var f0: float = float(b) / float(bands)
		var f1: float = float(b + 1) / float(bands)
		var e0: Vector2 = _edges(f0)
		var e1: Vector2 = _edges(f1)
		var c0: Color = WALL_MID.lerp(WALL_EDGE, f0)
		var c1: Color = WALL_MID.lerp(WALL_EDGE, f1)
		draw_polygon(
			PackedVector2Array([Vector2(e0.x, h * f0), Vector2(e0.y, h * f0),
				Vector2(e1.y, h * f1), Vector2(e1.x, h * f1)]),
			PackedColorArray([c0, c0, c1, c1]))

	# Chevrons drifting down, clipped to the walls at their own depth.
	var y: float = -CHEVRON_GAP + _offset
	while y < h + CHEVRON_GAP:
		var t: float = clampf(y / h, 0.0, 1.0)
		var e: Vector2 = _edges(t)
		var mid: float = (e.x + e.y) * 0.5
		var half: float = (e.y - e.x) * 0.22
		if y > 4.0 and y < h - 4.0 and half > 4.0:
			draw_line(Vector2(mid - half, y - half * 0.35), Vector2(mid, y + half * 0.35), CHEVRON, 3.0)
			draw_line(Vector2(mid, y + half * 0.35), Vector2(mid + half, y - half * 0.35), CHEVRON, 3.0)
		y += CHEVRON_GAP

	# A pool of light where the item is heading, so the eye is drawn down the chute.
	var eb: Vector2 = _edges(1.0)
	draw_polygon(
		PackedVector2Array([Vector2(eb.x, h * 0.72), Vector2(eb.y, h * 0.72),
			Vector2(eb.y, h), Vector2(eb.x, h)]),
		PackedColorArray([Color(FLOOR_GLOW.r, FLOOR_GLOW.g, FLOOR_GLOW.b, 0.0),
			Color(FLOOR_GLOW.r, FLOOR_GLOW.g, FLOOR_GLOW.b, 0.0), FLOOR_GLOW, FLOOR_GLOW]))

	# Rails down both slanted edges, as solid tapering bands rather than hairlines, with rivets.
	var t0: Vector2 = _edges(0.0)
	var t1: Vector2 = _edges(1.0)
	_rail(Vector2(t0.x, 0.0), Vector2(t1.x, h), 1.0)
	_rail(Vector2(t0.y, 0.0), Vector2(t1.y, h), -1.0)

	# A lip at the mouth: the chute is a piece of hardware bolted to something above, not a hole.
	var lip_h: float = maxf(h * 0.035, 7.0)
	draw_polygon(
		PackedVector2Array([Vector2(t0.x - 6.0, -1.0), Vector2(t0.y + 6.0, -1.0),
			Vector2(_edges(0.04).y + 3.0, lip_h), Vector2(_edges(0.04).x - 3.0, lip_h)]),
		PackedColorArray([LIP, LIP, LIP.darkened(0.35), LIP.darkened(0.35)]))
	draw_line(Vector2(t0.x - 6.0, 0.0), Vector2(t0.y + 6.0, 0.0), LIP.lightened(0.35), 2.0)
	var bolts: int = 6
	for i in range(bolts):
		var bx: float = lerpf(t0.x + 8.0, t0.y - 8.0, (float(i) + 0.5) / float(bolts))
		draw_circle(Vector2(bx, lip_h * 0.5), 2.2, RIVET)

	# Shadow under the mouth, so the throat looks like it recedes.
	draw_polygon(
		PackedVector2Array([Vector2(t0.x, lip_h), Vector2(t0.y, lip_h),
			Vector2(_edges(0.10).y, h * 0.10), Vector2(_edges(0.10).x, h * 0.10)]),
		PackedColorArray([Color(0, 0, 0, 0.45), Color(0, 0, 0, 0.45),
			Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0)]))

	# The bottom edge flares outward and catches the light: the chute visibly DELIVERS into the row
	# of containers below instead of simply stopping.
	var out_l: Vector2 = Vector2(t1.x - 10.0, h)
	var out_r: Vector2 = Vector2(t1.y + 10.0, h)
	draw_polygon(
		PackedVector2Array([Vector2(_edges(0.93).x, h * 0.93), Vector2(_edges(0.93).y, h * 0.93), out_r, out_l]),
		PackedColorArray([WALL_MID, WALL_MID, LIP.darkened(0.2), LIP.darkened(0.2)]))
	draw_line(out_l, out_r, LIP.lightened(0.25), 3.0, true)

# A rail as a tapering band with a lit inner edge and rivets, rather than a 3px line.
func _rail(top: Vector2, bot: Vector2, inward: float) -> void:
	var w_top: float = 7.0
	var w_bot: float = 10.0
	var a: Vector2 = top + Vector2(w_top * inward, 0.0)
	var b: Vector2 = bot + Vector2(w_bot * inward, 0.0)
	draw_polygon(PackedVector2Array([top, a, b, bot]),
		PackedColorArray([RAIL, RAIL, RAIL.darkened(0.35), RAIL.darkened(0.35)]))
	draw_line(top, bot, RAIL.lightened(0.30), 2.0, true)
	var n: int = 7
	for i in range(n):
		var t: float = (float(i) + 0.5) / float(n)
		var p: Vector2 = top.lerp(bot, t) + Vector2(w_top * 0.5 * inward, 0.0)
		draw_circle(p, 2.0, RIVET)

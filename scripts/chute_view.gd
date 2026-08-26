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

	# Rails down both slanted edges, and a shadow under the mouth.
	var t0: Vector2 = _edges(0.0)
	var t1: Vector2 = _edges(1.0)
	draw_line(Vector2(t0.x, 0.0), Vector2(t1.x, h), RAIL, 3.0, true)
	draw_line(Vector2(t0.y, 0.0), Vector2(t1.y, h), RAIL, 3.0, true)
	draw_polygon(
		PackedVector2Array([Vector2(t0.x, 0.0), Vector2(t0.y, 0.0),
			Vector2(_edges(0.06).y, h * 0.06), Vector2(_edges(0.06).x, h * 0.06)]),
		PackedColorArray([Color(0, 0, 0, 0.45), Color(0, 0, 0, 0.45),
			Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0)]))

extends Control
class_name BucketStage

# The ground the buckets stand on, and the impact when something lands in one.
#
# They were three PNGs floating in a row with nothing under them: no contact with the floor, no
# weight, and no reaction to an item arriving beyond the tick appearing in a label. A drop is the
# whole point of the game and it produced no event on screen at all.
#
# An overlay across the level, positioning itself from the buckets' own rects each frame, so no
# layout changes. Drawn UNDER the buckets (added below them in the tree), so shadows and dust sit
# behind the art rather than over it.

const SHELF: Color = Color(0.078, 0.090, 0.122)
const SHELF_LIP: Color = Color(0.286, 0.325, 0.400, 0.55)
const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.42)
const DUST: Color = Color(0.639, 0.686, 0.780)

# Rects of the buckets, in this control's space.
var rects: Array = []

# Live puffs: {"at": Vector2, "age": float}
var _puffs: Array = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if _puffs.is_empty():
		return
	for i in range(_puffs.size() - 1, -1, -1):
		_puffs[i]["age"] = float(_puffs[i]["age"]) + delta
		if float(_puffs[i]["age"]) > 0.55:
			_puffs.remove_at(i)
	queue_redraw()

# Something landed in this bucket.
func thump(idx: int) -> void:
	if idx < 0 or idx >= rects.size():
		return
	var r: Rect2 = rects[idx]
	_puffs.append({"at": Vector2(r.get_center().x, r.position.y + r.size.y * 0.18), "age": 0.0})
	queue_redraw()

func _draw() -> void:
	if rects.is_empty():
		return
	# One shelf spanning the row, so the three buckets stand on the same floor rather than each
	# hovering over its own patch of background.
	var left: float = INF
	var right: float = -INF
	var base: float = -INF
	for r in rects:
		left = minf(left, (r as Rect2).position.x)
		right = maxf(right, (r as Rect2).end.x)
		base = maxf(base, (r as Rect2).end.y)
	var shelf_top: float = base - 10.0
	draw_rect(Rect2(left - 18.0, shelf_top, right - left + 36.0, 16.0), SHELF)
	draw_line(Vector2(left - 18.0, shelf_top), Vector2(right + 18.0, shelf_top), SHELF_LIP, 2.0)

	# Contact shadow under each bucket.
	for r in rects:
		var rr: Rect2 = r
		_ellipse(Vector2(rr.get_center().x, base - 4.0), rr.size.x * 0.42, 7.0, SHADOW)

	# Dust from a landing, rising and fading.
	for p in _puffs:
		var t: float = clampf(float(p["age"]) / 0.55, 0.0, 1.0)
		var at: Vector2 = p["at"]
		var a: float = (1.0 - t) * 0.55
		for k in range(5):
			var ang: float = float(k) / 5.0 * TAU + t * 1.4
			var spread: float = 8.0 + t * 30.0
			var pos: Vector2 = at + Vector2(cos(ang) * spread, -t * 22.0 + sin(ang) * spread * 0.35)
			draw_circle(pos, 4.5 * (1.0 - t) + 1.0, Color(DUST.r, DUST.g, DUST.b, a))

func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	if rx <= 0.5 or ry <= 0.5:
		return
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(24):
		var a: float = float(i) / 24.0 * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

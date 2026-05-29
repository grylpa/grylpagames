extends Control
# Narrow smooth gradient strips just OUTSIDE the belt's top and bottom edges:
# belt colour where they meet the belt, fading to transparent into the background.
# Fit to the full belt rect (panel content margins are zeroed in level.gd), and
# draws beyond it (above y=0, below y=h); no ancestor may clip it.

const STRIP_H: float = 5.0
const BELT_COLOR: Color = Color(0.0, 0.06, 0.0, 0.6)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var clear: Color = Color(BELT_COLOR.r, BELT_COLOR.g, BELT_COLOR.b, 0.0)
	# Above the belt: transparent at the outer edge, belt colour at the belt edge.
	draw_polygon(
		PackedVector2Array([Vector2(0.0, -STRIP_H), Vector2(w, -STRIP_H), Vector2(w, 0.0), Vector2(0.0, 0.0)]),
		PackedColorArray([clear, clear, BELT_COLOR, BELT_COLOR]))
	# Below the belt: belt colour at the belt edge, transparent at the outer edge.
	draw_polygon(
		PackedVector2Array([Vector2(0.0, h), Vector2(w, h), Vector2(w, h + STRIP_H), Vector2(0.0, h + STRIP_H)]),
		PackedColorArray([BELT_COLOR, BELT_COLOR, clear, clear]))

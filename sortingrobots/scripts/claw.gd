extends Node2D

# A simple mechanical arm + gripper for the "robot arm pulls the picked item off" effect.
# Drawn ENTIRELY OUTSIDE the gripped box so it never covers the item. Origin = box top-left;
# the box spans (0,0)..box_size. `side` = +1 the arm comes from the RIGHT, -1 from the LEFT.

var side: int = 1
var box_size: Vector2 = Vector2(60.0, 60.0)
var reach: float = 520.0

const METAL: Color = Color(0.60, 0.63, 0.70, 1.0)
const METAL_DARK: Color = Color(0.34, 0.36, 0.44, 1.0)

func _draw() -> void:
	var d: float = float(side)
	var cy: float = box_size.y * 0.5
	var edge_x: float = box_size.x if d > 0.0 else 0.0
	# arm bar: from the box's near edge outward to the side
	var bar_h: float = 14.0
	var arm_end: float = edge_x + d * reach
	draw_rect(Rect2(minf(edge_x, arm_end), cy - bar_h * 0.5, absf(arm_end - edge_x), bar_h), METAL)
	# gripper: a vertical bar just OUTSIDE the near edge (gripping the item's side, not over it)
	var grip_w: float = 14.0
	var grip_h: float = box_size.y * 0.85
	var gx: float = edge_x if d > 0.0 else edge_x - grip_w
	draw_rect(Rect2(gx, cy - grip_h * 0.5, grip_w, grip_h), METAL_DARK)

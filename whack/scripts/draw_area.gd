extends Control

# Set by level.gd after instantiation
var level_node: Node = null

func _ready() -> void:
	level_node = get_parent()

func _draw() -> void:
	if level_node == null:
		return
	var state: Dictionary = level_node.get_draw_state()
	var targets: Array = state["targets"]
	var flash_color: Color = state["flash_color"]
	var flash_alpha: float = state["flash_alpha"]
	var flash_pos: Vector2 = state["flash_pos"]
	var flash_radius: float = state["target_radius"]

	for t in targets:
		var pos: Vector2 = t["pos"]
		var radius: float = t["radius"]
		var color: Color = t["color"]
		var age: float = t["age"]
		# Outer target circle
		draw_circle(pos, radius, color)
		# Center dot (aiming guide) — omitted for same-color decoys
		if t["draw_dot"]:
			draw_circle(pos, radius * 0.22, Color(1.0, 1.0, 1.0, 0.85))
		# Thin ring outline
		draw_arc(pos, radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.4), 2.0)
		# Countdown arc: starts full, depletes clockwise as age approaches 1.0
		var remaining: float = 1.0 - age
		var arc_end: float = -PI * 0.5 + remaining * TAU
		var arc_col: Color = Color(1.0, 1.0, 1.0, 0.85).lerp(Color(1.0, 0.25, 0.0, 1.0), age)
		draw_arc(pos, radius + 9.0, -PI * 0.5, arc_end, 48, arc_col, 4.0)

	# Flash feedback
	if flash_alpha > 0.0:
		var fc: Color = flash_color
		fc.a = flash_alpha * flash_color.a
		draw_circle(flash_pos, flash_radius * 1.3, fc)

extends Control

var level_node: Node = null

func _ready() -> void:
	level_node = get_parent()

func _draw() -> void:
	if level_node == null:
		return
	var mobile: bool = MainGlobals.is_mobile()
	var state: Dictionary = level_node.get_tap_draw_state()

	# Thin progress bar along the top edge
	if state.get("session_active", false):
		var progress: float = state.get("session_progress", 0.0)
		const PAD_X: float = 24.0
		const BAR_Y: float = 18.0
		var bar_h: float = 7.0 if mobile else 5.0
		var bar_w: float = size.x - PAD_X * 2.0
		draw_rect(Rect2(PAD_X, BAR_Y, bar_w, bar_h),
			Color(0.3, 0.55, 0.65, 0.30 if mobile else 0.12), true)
		if progress > 0.0:
			draw_rect(Rect2(PAD_X, BAR_Y, bar_w * progress, bar_h),
				Color(0.4, 0.82, 0.92, 0.70 if mobile else 0.28), true)

	# Large breathing circle — static before first tap, animated after
	if state.get("session_active", false):
		var cx: float = size.x * 0.5
		var cy: float = size.y * 0.5
		var breath: float = state.get("breath_value", 0.0)
		var anim: bool = state.get("anim_active", false)
		var r_min: float = 220.0 if mobile else 150.0
		var full_amp: float = 20.0 if mobile else 12.0
		var amp: float = full_amp * state.get("amplitude_factor", 1.0)
		var r: float = r_min + amp * breath
		var alpha_fill: float = (0.11 + breath * 0.10) if mobile else (0.07 + breath * 0.07)
		var alpha_outer: float
		var alpha_inner: float
		if mobile:
			alpha_outer = (0.36 + breath * 0.30) if anim else 0.28
			alpha_inner = (0.20 + breath * 0.18) if anim else 0.16
		else:
			alpha_outer = (0.20 + breath * 0.18) if anim else 0.16
			alpha_inner = (0.10 + breath * 0.10) if anim else 0.08
		var w_outer: float = 4.0 if mobile else 2.5
		var w_inner: float = 3.0 if mobile else 2.0
		draw_circle(Vector2(cx, cy), r, Color(0.3, 0.7, 0.85, alpha_fill))
		draw_arc(Vector2(cx, cy), r, 0.0, TAU, 80, Color(0.4, 0.82, 0.92, alpha_outer), w_outer)
		draw_arc(Vector2(cx, cy), r * 0.55, 0.0, TAU, 60, Color(0.4, 0.82, 0.92, alpha_inner), w_inner)

	# Expanding ring feedback on each tap — always centerd on the circle
	if not state.get("ring_active", false):
		return
	var pos: Vector2 = Vector2(size.x * 0.5, size.y * 0.5)
	var age: float = state["ring_age"]

	var outer_r: float = (50.0 + age * 170.0) if mobile else (30.0 + age * 100.0)
	var inner_r: float = outer_r * 0.55
	var alpha: float = (1.0 - age) * (1.0 if mobile else 0.75)
	var color: Color = Color(0.45, 0.85, 0.95, alpha)
	var w_ring: float = 4.0 if mobile else 2.5
	var w_ring_inner: float = 2.5 if mobile else 1.5

	draw_arc(pos, outer_r, 0.0, TAU, 48, color, w_ring)
	draw_arc(pos, inner_r, 0.0, TAU, 32, Color(0.45, 0.85, 0.95, alpha * (0.7 if mobile else 0.5)), w_ring_inner)
	draw_circle(pos, (7.0 if mobile else 5.0) * (1.0 - age), Color(0.7, 0.95, 1.0, alpha))

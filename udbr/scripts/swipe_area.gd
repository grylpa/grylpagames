extends Control

var level_node: Node = null

func _ready() -> void:
	level_node = get_parent()

# Builds a closed polygon for a vertically-oriented rounded trapezoid.
# The top cap is a semicircle of radius top_w/2 (wider),
# the bottom cap is a semicircle of radius bot_w/2 (narrower),
# connected by diagonal sides.
func _lane_polygon(cx: float, top_y: float, bot_y: float, top_w: float, bot_w: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var top_r: float = top_w * 0.5
	var bot_r: float = bot_w * 0.5
	const N: int = 20
	# Top semicircle: left edge → up → right edge
	for i: int in range(N + 1):
		var a: float = PI * (1.0 - float(i) / float(N))
		pts.append(Vector2(cx + top_r * cos(a), top_y - top_r * sin(a)))
	# Bottom semicircle: right edge → down → left edge
	for i: int in range(N + 1):
		var a: float = PI * float(i) / float(N)
		pts.append(Vector2(cx + bot_r * cos(a), bot_y + bot_r * sin(a)))
	return pts

func _draw() -> void:
	if level_node == null:
		return
	var state: Dictionary = level_node.get_swipe_draw_state()
	var w: float = size.x
	var h: float = size.y
	var cx: float = w * 0.5

	# Progress bar along the top edge (shared: scripts/session_bar.gd)
	if state.get("session_active", false):
		SessionBar.draw_cool(self, w, state.get("session_progress", 0.0))

	if not state.get("session_active", false):
		return

	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var pulse: float = sin(t * 0.65) * 0.5 + 0.5

	var lane_top: float = h * UdbrG.LANE_TOP_FRAC
	var lane_bot: float = h * UdbrG.LANE_BOT_FRAC
	var mobile: bool = MainGlobals.is_mobile()
	var top_w: float = 180.0 if mobile else 130.0
	var bot_w: float = 130.0 if mobile else 96.0
	var fill_alpha: float = (0.12 + pulse * 0.06) if mobile else (0.04 + pulse * 0.02)
	var outline_alpha: float = (0.30 + pulse * 0.15) if mobile else (0.08 + pulse * 0.06)
	var outline_w: float = 2.0 if mobile else 1.5

	# Guide lane — filled rounded trapezoid
	var poly: PackedVector2Array = _lane_polygon(cx, lane_top, lane_bot, top_w, bot_w)
	draw_colored_polygon(poly, Color(0.3, 0.7, 0.85, fill_alpha))
	# Outline — close the polyline by appending first point
	var outline: PackedVector2Array = poly.duplicate()
	outline.append(poly[0])
	draw_polyline(outline, Color(0.4, 0.82, 0.92, outline_alpha), outline_w, true)

	# Pattern label at top center (guided mode only)
	var pat: String = state.get("pattern_text", "")
	if pat != "":
		draw_string(MainGlobals.get_system_sans_font(), Vector2(0.0, 62.0),
			"Goal: " + pat, HORIZONTAL_ALIGNMENT_CENTER, w, 20,
			Color(1.0, 1.0, 1.0, 0.55))

	# Finger indicator — ball trapped inside the shape.
	# Center travels in [lane_top, lane_bot]; radius = shape half-width at that y minus 10.
	if state.get("touch_active", false):
		var y_norm: float = clampf(state.get("touch_y_norm", 0.5), 0.0, 1.0)
		var fy: float = clampf(y_norm * h, lane_top, lane_bot)
		var ball_t: float = (fy - lane_top) / maxf(lane_bot - lane_top, 1.0)
		var ball_r: float = lerp(top_w * 0.5, bot_w * 0.5, ball_t) - 10.0
		var in_hold: bool = state.get("in_hold", false)
		var dot_col: Color = Color(0.9, 0.7, 0.3, 0.85) if in_hold else Color(0.5, 0.9, 1.0, 0.7)
		draw_circle(Vector2(cx, fy), ball_r, Color(dot_col.r, dot_col.g, dot_col.b, 0.18))
		draw_arc(Vector2(cx, fy), ball_r, 0.0, TAU, 52, dot_col, 2.5)

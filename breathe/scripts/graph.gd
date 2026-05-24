extends Control

var tap_times_ms: Array = []
var session_duration_ms: float = 0.0

func set_data(taps: Array, duration_ms: float) -> void:
	tap_times_ms = taps
	session_duration_ms = duration_ms

func _draw() -> void:
	if tap_times_ms.size() < 2:
		draw_string(ThemeDB.fallback_font, Vector2(10.0, size.y * 0.5),
			"Not enough data for graph", HORIZONTAL_ALIGNMENT_LEFT, -1, 24,
			Color(0.6, 0.7, 0.8, 0.7))
		return

	var w: float = size.x
	var h: float = size.y

	var mobile: bool = MainGlobals.is_mobile()
	var left_pad: float = 12.0
	var right_pad: float = 12.0
	var bottom_pad: float = 70.0 if mobile else 38.0
	var top_pad: float = 12.0

	var font: Font = MainGlobals.get_system_sans_font()
	var fs: int = 32 if mobile else 16
	var grid_col: Color = Color(0.4, 0.5, 0.65, 0.22)
	var label_col: Color = Color(0.5, 0.62, 0.78, 0.65)
	var tap_col: Color = Color(0.5, 0.9, 1.0, 0.85)
	const BORDER_COLOR: Color = Color(1.0, 0.898, 0.0078, 1.0)

	var chart_x: float = left_pad
	var chart_y: float = top_pad
	var chart_w: float = w - left_pad - right_pad
	var chart_h: float = h - top_pad - bottom_pad

	# y range: 0 (bottom) to 1.05 (top) so tap line tips at y=1 are visible
	var tap_top_y: float = chart_y + chart_h * (1.0 - 1.0 / 1.05)
	var tap_bot_y: float = chart_y + chart_h

	var dur_ms: float = maxf(session_duration_ms, 1.0)
	var dur_s: float = dur_ms / 1000.0

	# Time grid lines — never at t=0
	var x_step_s: float = 10.0
	if dur_s > 120.0: x_step_s = 30.0
	elif dur_s > 60.0: x_step_s = 20.0

	var tick_label_y: float = chart_y + chart_h + maxf(15.0, fs * 0.85)
	var axis_label_y: float = chart_y + chart_h + bottom_pad * 0.88

	var xi: float = x_step_s
	while xi <= dur_s + 0.01:
		var gx: float = chart_x + (xi / dur_s) * chart_w
		draw_line(Vector2(gx, chart_y), Vector2(gx, tap_bot_y), grid_col, 1.0)
		draw_string(font, Vector2(gx - 14.0, tick_label_y), "%ds" % int(xi),
			HORIZONTAL_ALIGNMENT_CENTER, 28, fs, label_col)
		xi += x_step_s

	# Tap vertical lines — drawn before border so border sits on top
	for t in tap_times_ms:
		var tx: float = chart_x + (float(t) / dur_ms) * chart_w
		draw_line(Vector2(tx, tap_bot_y), Vector2(tx, tap_top_y), tap_col, 2.0)

	# Border LAST so it covers line edges
	draw_rect(Rect2(chart_x, chart_y, chart_w, chart_h), BORDER_COLOR, false, 2.0)

	# X-axis label below tick labels with a gap
	draw_string(font, Vector2(chart_x, axis_label_y), "time",
		HORIZONTAL_ALIGNMENT_CENTER, chart_w, fs, label_col)

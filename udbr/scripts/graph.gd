extends Control

# Each segment: Array of Vector2(time_ms, y_norm)
# y_norm: 0 = top of swipe area, 1 = bottom (inverted on chart so up = up)
var _segments: Array = []
var _duration_ms: float = 1.0

func set_data(segments: Array, duration_ms: float) -> void:
	_segments = segments
	_duration_ms = maxf(duration_ms, 1.0)

func _draw() -> void:
	var total_pts: int = 0
	for seg in _segments:
		total_pts += seg.size()

	if total_pts < 2:
		draw_string(ThemeDB.fallback_font, Vector2(10.0, size.y * 0.5),
			"Not enough data for graph", HORIZONTAL_ALIGNMENT_LEFT, -1, 24,
			Color(0.6, 0.7, 0.8, 0.7))
		return

	var w: float = size.x
	var h: float = size.y

	var mobile: bool = MainGlobals.is_mobile()
	var left_pad: float = 56.0 if mobile else 40.0
	var bottom_pad: float = 70.0 if mobile else 36.0
	var w_chart: float = w - left_pad
	var h_draw: float = h - bottom_pad

	var font: Font = MainGlobals.get_system_sans_font()
	var fs: int = 32 if mobile else 16
	var grid_col: Color = Color(0.4, 0.5, 0.65, 0.22)
	var label_col: Color = Color(0.5, 0.62, 0.78, 0.65)

	var dur_sec: float = _duration_ms / 1000.0

	# X grid — one tick every 30s up to duration
	var x_step_sec: float = 30.0
	if dur_sec <= 60.0: x_step_sec = 15.0
	elif dur_sec >= 600.0: x_step_sec = 60.0
	var xi_sec: float = x_step_sec
	while xi_sec <= dur_sec + 0.1:
		var gx: float = left_pad + (xi_sec / dur_sec) * w_chart
		draw_line(Vector2(gx, 0.0), Vector2(gx, h_draw), grid_col, 1.0)
		# Plain integer — unit shown in axis label below
		var lbl: String = "%d" % [int(xi_sec)] if dur_sec < 120.0 else "%d" % [int(xi_sec / 60.0)]
		draw_string(font, Vector2(gx - 14.0, h_draw + maxf(15.0, fs * 0.85)), lbl,
			HORIZONTAL_ALIGNMENT_CENTER, 28, fs, label_col)
		xi_sec += x_step_sec

	# Y grid — 5 evenly spaced lines; y_norm 0=top 1=bottom → chart: 0=bottom 1=top
	for i: int in range(6):
		var t: float = float(i) / 5.0
		var gy: float = t * h_draw
		draw_line(Vector2(left_pad, gy), Vector2(w, gy), grid_col, 1.0)

	# Y axis labels: "up" at top, "down" at bottom
	draw_string(font, Vector2(0.0, fs + 2.0), "up",
		HORIZONTAL_ALIGNMENT_RIGHT, left_pad - 3.0, fs, label_col)
	draw_string(font, Vector2(0.0, h_draw - 2.0), "dn",
		HORIZONTAL_ALIGNMENT_RIGHT, left_pad - 3.0, fs, label_col)

	# Find actual data y min/max so we can fill the chart height
	var data_y_min: float = 1e9
	var data_y_max: float = -1e9
	for seg in _segments:
		for pt: Vector2 in seg:
			data_y_min = minf(data_y_min, pt.y)
			data_y_max = maxf(data_y_max, pt.y)
	if data_y_min > data_y_max:
		data_y_min = 0.0
		data_y_max = 1.0
	var raw_range: float = maxf(data_y_max - data_y_min, 0.001)
	var pad: float = raw_range * 0.05
	var y_plot_min: float = data_y_min - pad
	var y_plot_max: float = data_y_max + pad
	var y_plot_range: float = y_plot_max - y_plot_min

	# Draw each segment as a polyline
	var seg_color: Color = Color(0.5, 0.9, 1.0, 0.85)
	for seg in _segments:
		if seg.size() < 2:
			continue
		var screen_pts: PackedVector2Array = []
		for pt: Vector2 in seg:
			var px: float = left_pad + clampf(pt.x / _duration_ms, 0.0, 1.0) * w_chart
			var py: float = h_draw * (1.0 - (pt.y - y_plot_min) / y_plot_range)
			screen_pts.append(Vector2(px, clampf(py, 0.0, h_draw)))
		draw_polyline(screen_pts, seg_color, 2.0)

	# Border drawn last so it sits on top of the data lines
	const BORDER_COLOR: Color = Color(1.0, 0.898, 0.0078, 1.0)
	draw_rect(Rect2(left_pad, 0.0, w_chart, h_draw), BORDER_COLOR, false, 2.0)

	# X-axis label — shows the unit for the tick numbers
	var x_unit_lbl: String = "seconds" if dur_sec < 120.0 else "minutes"
	draw_string(font, Vector2(left_pad, h_draw + bottom_pad * 0.88), x_unit_lbl,
		HORIZONTAL_ALIGNMENT_CENTER, w_chart, fs, Color(0.5, 0.62, 0.78, 0.6))

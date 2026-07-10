extends Control

var _child_poll: Array = []   # int per 50ms: 0=hold, 1=inhale, 2=exhale
var _mother_poll: Array = []  # same encoding, same length (may be empty in active mode)
var _duration_ms: float = 1.0
var bg_color: Color = Color(0.04, 0.07, 0.14, 1.0)

const MOTHER_COLOR: Color = Color(0.35, 1.0, 0.40, 0.80)
const CHILD_COLOR:  Color = Color(0.40, 0.65, 1.00, 0.80)
const MOTHER_Y_OFFSET: float = -14.0  # mother dots drawn above child dots

func set_data(child_poll: Array, mother_poll: Array, duration_ms: float) -> void:
	_child_poll = child_poll
	_mother_poll = mother_poll
	_duration_ms = maxf(duration_ms, 1.0)

func _draw() -> void:
	if _child_poll.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(10.0, size.y * 0.5),
			"No data", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.6, 0.7, 0.8, 0.7))
		return

	var w: float = size.x
	var h: float = size.y
	var mobile: bool = MainGlobals.is_mobile()
	var left_pad: float = 56.0 if mobile else 52.0
	var bottom_pad: float = 64.0 if mobile else 28.0
	var w_chart: float = w - left_pad
	var h_draw: float = h - bottom_pad

	var font: Font = MainGlobals.get_system_sans_font()
	var fs: int = 28 if mobile else 14
	var label_col: Color = Color(0.5, 0.62, 0.78, 0.65)
	var grid_col: Color = Color(0.4, 0.5, 0.65, 0.20)

	# Row centers: inhale=top, hold=middle, exhale=bottom
	var row_y: Array = [h_draw * 0.18, h_draw * 0.50, h_draw * 0.82]
	var row_labels: Array = ["Inhale", "Hold", "Exhale"]

	# Horizontal guide lines and Y labels
	for i: int in 3:
		draw_line(Vector2(left_pad, row_y[i]), Vector2(w, row_y[i]), grid_col, 1.0)
		draw_string(font, Vector2(0.0, row_y[i] + fs * 0.38), row_labels[i],
			HORIZONTAL_ALIGNMENT_RIGHT, left_pad - 4.0, fs, label_col)

	var n: int = _child_poll.size()
	var dot_r: float = 5.0 if mobile else 3.6
	var has_mother: bool = _mother_poll.size() == n

	# X axis ticks — start at 0, end exactly at dur_sec
	var dur_sec: float = _duration_ms / 1000.0
	var x_step_sec: float = 30.0
	if dur_sec <= 60.0:
		x_step_sec = 15.0
	elif dur_sec >= 600.0:
		x_step_sec = 60.0
	var lbl_w: float = 56.0 if mobile else 28.0
	var xi_sec: float = 0.0
	while xi_sec <= dur_sec + 0.1:
		var gx: float = left_pad + (xi_sec / dur_sec) * w_chart
		draw_line(Vector2(gx, 0.0), Vector2(gx, h_draw), grid_col, 1.0)
		var lbl: String = "%d" % int(xi_sec) if dur_sec < 120.0 else "%d" % int(xi_sec / 60.0)
		draw_string(font, Vector2(gx - lbl_w * 0.5, h_draw + maxf(15.0, fs * 0.9)), lbl,
			HORIZONTAL_ALIGNMENT_CENTER, lbl_w, fs, label_col)
		if xi_sec >= dur_sec:
			break
		xi_sec = minf(xi_sec + x_step_sec, dur_sec)

	# Child dots at row center
	for i: int in n:
		var k: int = _child_poll[i]
		var row_idx: int = 0 if k == 1 else (2 if k == 2 else 1)
		var px: float = left_pad + (float(i) / float(n)) * w_chart
		draw_circle(Vector2(px, row_y[row_idx]), dot_r, CHILD_COLOR)

	# Mother dots shifted up by MOTHER_Y_OFFSET
	if has_mother:
		for i: int in n:
			var k: int = _mother_poll[i]
			var row_idx: int = 0 if k == 1 else (2 if k == 2 else 1)
			var px: float = left_pad + (float(i) / float(n)) * w_chart
			draw_circle(Vector2(px, row_y[row_idx] + MOTHER_Y_OFFSET), dot_r, MOTHER_COLOR)

	# Mask strips in panel bg color to clip dots that bleed outside the chart edges
	var mask_col: Color = Color(bg_color.r, bg_color.g, bg_color.b, 1.0)
	draw_rect(Rect2(left_pad - dot_r, 0.0, dot_r, h_draw), mask_col)
	draw_rect(Rect2(left_pad + w_chart, 0.0, dot_r, h_draw), mask_col)

	# Border on top
	draw_rect(Rect2(left_pad, 0.0, w_chart, h_draw), Color(1.0, 0.898, 0.0078, 1.0), false, 2.0)

	# X axis unit label
	var x_unit: String = "seconds" if dur_sec < 120.0 else "minutes"
	draw_string(font, Vector2(left_pad, h_draw + bottom_pad * 0.88), x_unit,
		HORIZONTAL_ALIGNMENT_CENTER, w_chart, fs, Color(0.5, 0.62, 0.78, 0.6))

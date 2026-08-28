class_name ChartControl
extends Control

# The chart's own ground. Dark, because the plot lines and the grid are drawn against it — and
# PUBLIC, because the panel that frames the chart has to be filled with exactly this. Any other
# value there shows as a mat of a different color between the frame and the plot.
const GROUND: Color = Color(0.055, 0.067, 0.106, 1.0)

const SERIES_COLORS: Array = [
	Color(0.4, 0.9, 0.5),
	Color(0.4, 0.7, 1.0),
	Color(1.0, 0.6, 0.3),
	Color(0.9, 0.4, 0.4),
	Color(0.8, 0.5, 1.0),
	Color(0.4, 0.95, 0.95),
	Color(1.0, 0.9, 0.3),
	Color(1.0, 0.5, 0.8),
]

const MARGIN_LEFT: int = 64
const MARGIN_BOTTOM: int = 38
const MARGIN_TOP: int = 16
const MARGIN_RIGHT: int = 16

var y_label: String = ""
var x_as_index: bool = false
var y_max_override: float = -1.0  # when >= 0, caps y_max to this value
var y_integer_only: bool = false  # when true, snap y ticks to integers and skip duplicates
var y_min_padding: float = 0.0    # when > 0, y_min = data_min - padding * span (instead of 0)
var y_label_divisor: float = 1.0  # divide raw value before formatting y-axis labels
var y_label_format: String = ""   # if set, used instead of _fmt_y for axis labels
var _series: Array = []

func set_series(series_list: Array) -> void:
	_series = series_list
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(0.0, 0.0, w, h), GROUND, true)

	var px_left: float = float(MARGIN_LEFT)
	var px_right: float = w - float(MARGIN_RIGHT)
	var px_top: float = float(MARGIN_TOP)
	var px_bottom: float = h - float(MARGIN_BOTTOM)
	var plot_w: float = px_right - px_left
	var plot_h: float = px_bottom - px_top

	if plot_w <= 0.0 or plot_h <= 0.0:
		return

	var all_x: Array = []
	var all_y: Array = []
	for s: Dictionary in _series:
		for pt: Vector2 in s["points"]:
			all_x.append(pt.x)
			all_y.append(pt.y)

	var has_data: bool = not all_x.is_empty()

	var x_min: float
	var x_max: float
	var y_min: float = 0.0
	var y_max: float

	if has_data:
		x_min = all_x.min()
		x_max = all_x.max()
		if y_integer_only:
			y_max = float(max(1, ceili(all_y.max())))
		else:
			var data_min: float = all_y.min()
			var data_max: float = all_y.max()
			if y_min_padding > 0.0:
				var span: float = maxf(data_max - data_min, 1.0)
				y_min = maxf(0.0, data_min - y_min_padding * span)
				y_max = data_max + y_min_padding * span
			else:
				y_max = data_max * 1.1
				if y_max_override >= 0.0:
					y_max = min(y_max, y_max_override)
				if y_max <= 0.0:
					y_max = 1.0
		if x_min >= x_max:
			if x_as_index:
				x_min = float(max(1, int(x_min) - 1))
				x_max = float(int(x_max) + 1)
			else:
				x_min -= 86400.0
				x_max += 86400.0
	else:
		if x_as_index:
			x_min = 1.0
			x_max = 10.0
		else:
			var now: float = float(Time.get_unix_time_from_system())
			x_min = now - 30.0 * 86400.0
			x_max = now
		match y_label:
			"Score":
				y_max = 1000.0
			"Avg Time (ms)":
				y_max = 2000.0
			"% Correct":
				y_max = 100.0
			_:
				y_max = 100.0

	var font: Font = ThemeDB.fallback_font
	var font_size: int = 17
	var grid_color: Color = Color(1.0, 1.0, 1.0, 0.07)
	var label_color: Color = ResultCard.MUTED

	# Horizontal gridlines + Y-axis labels
	var y_range: float = y_max - y_min
	var num_y: int = 5
	for i: int in range(num_y + 1):
		var t: float = float(i) / float(num_y)
		var yv: float = y_min + t * y_range
		var py: float = px_bottom - t * plot_h
		if y_integer_only and absf(yv - roundi(yv)) > 0.01:
			continue
		draw_line(Vector2(px_left, py), Vector2(px_right, py), grid_color, 1.0)
		var display_val: float = yv / y_label_divisor
		var lbl: String = (y_label_format % display_val) if y_label_format != "" else _fmt_y(display_val)
		var ts: Vector2 = font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, Vector2(px_left - ts.x - 4.0, py + ts.y * 0.35), lbl,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)

	# Vertical gridlines + X-axis labels
	var num_x: int = 5
	for i: int in range(num_x + 1):
		var t: float = float(i) / float(num_x)
		var xv: float = x_min + t * (x_max - x_min)
		var px: float = px_left + t * plot_w
		draw_line(Vector2(px, px_top), Vector2(px, px_bottom), grid_color, 1.0)
		var x_label: String
		if x_as_index:
			x_label = "%d" % [int(round(xv))]
		else:
			var dt: Dictionary = Time.get_datetime_dict_from_unix_time(int(xv))
			x_label = "%02d/%02d" % [dt.month, dt.day]
		var ts: Vector2 = font.get_string_size(x_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var lx: float = clamp(px - ts.x * 0.5, px_left, px_right - ts.x)
		draw_string(font, Vector2(lx, px_bottom + ts.y + 2.0), x_label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)

	if not has_data:
		var msg: String = "No data yet"
		var msg_size: Vector2 = font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		var mx: float = px_left + (plot_w - msg_size.x) * 0.5
		var my: float = px_top + (plot_h + msg_size.y) * 0.5
		draw_string(font, Vector2(mx, my), msg,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.35, 0.35, 0.38, 1.0))
		return

	# Series: sorted polylines and dots
	for si: int in range(_series.size()):
		var s: Dictionary = _series[si]
		var series_color: Color = s.get("color", SERIES_COLORS[si % SERIES_COLORS.size()])
		var pts: Array = s.get("points", [])
		if pts.is_empty():
			continue
		var sorted_pts: Array = pts.duplicate()
		sorted_pts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var screen_pts: PackedVector2Array = []
		for pt: Vector2 in sorted_pts:
			var px: float = px_left + (pt.x - x_min) / (x_max - x_min) * plot_w
			var py: float = px_bottom - ((pt.y - y_min) / y_range) * plot_h
			screen_pts.append(Vector2(px, py))
		if screen_pts.size() > 1:
			draw_polyline(screen_pts, series_color, 2.0)
		for sp: Vector2 in screen_pts:
			draw_circle(sp, 4.0, series_color)

	# Legend: top-right of plot area, boxes aligned, text left-aligned after boxes
	var box_sz: float = 12.0
	var box_gap: float = 6.0
	var max_lbl_w: float = 0.0
	for s: Dictionary in _series:
		var lbl: String = s.get("label", "")
		var ts: Vector2 = font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		if ts.x > max_lbl_w:
			max_lbl_w = ts.x
	var box_x: float = px_right - 8.0 - max_lbl_w - box_gap - box_sz
	var leg_y: float = px_top + 6.0
	for si: int in range(_series.size()):
		var s: Dictionary = _series[si]
		var series_color: Color = s.get("color", SERIES_COLORS[si % SERIES_COLORS.size()])
		var lbl: String = s.get("label", "")
		var ts: Vector2 = font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_rect(Rect2(box_x, leg_y, box_sz, box_sz), series_color, true)
		draw_string(font, Vector2(box_x + box_sz + box_gap, leg_y + ts.y * 0.85), lbl,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.78, 0.78, 0.78, 0.6))
		leg_y += ts.y + 4.0


func _fmt_y(val: float) -> String:
	if val >= 10000.0:
		return "%dk" % [int(val / 1000.0)]
	elif val == float(int(val)):
		return "%d" % [int(val)]
	else:
		return "%.1f" % [val]

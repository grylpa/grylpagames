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

# THE BASELINE BAND. A trend line on its own cannot answer the only question that matters for
# noticing change — "is this different from how I usually am?" — because the reader has no idea
# which wobbles are ordinary. The band draws the player's own usual range behind the line, so a
# point inside it is unremarkable at a glance and most points should be.
#
# Set band_lo/band_hi in DATA units and the band is drawn; leave them equal and it is skipped.
# Points outside get a ring so an unusual session is visible without reading the axis.
var band_lo: float = 0.0
var band_hi: float = 0.0
var band_color: Color = Color(0.45, 0.75, 0.85, 0.13)
var band_edge: Color = Color(0.45, 0.75, 0.85, 0.30)
var mark_outliers: bool = true
var outlier_color: Color = ScreenBackdrop.STATS_MARK

# AXIS TITLES. Without them a chart whose x is not time is unreadable — "12" on the x axis says
# nothing unless something says "faces in the crowd".
var x_title: String = ""
var y_title: String = ""

# A fitted straight line through the points, with its slope stated.
#
# For the per-game panels the SLOPE is the measurement — the cost of each extra face, how fast
# recognition falls off with delay — and leaving the reader to eyeball it defeats the point.
var fit_line: bool = false
var fit_color: Color = ScreenBackdrop.STATS_MARK

var _series: Array = []
# Whether a numeric series label is a LEVEL NUMBER. Set by whoever supplies the series, because
# only they know: a chart's series are levels here, but crowd sizes or lags in a game's own chart,
# where an "L" prefix would be a lie. Affects the legend only -- the labels themselves are used
# elsewhere and are not rewritten.
var legend_numbers_are_levels: bool = false

# Which corner the legend last chose, for tests. See _draw_legend.
var _last_legend_corner: String = ""

func _debug_legend_corner() -> String:
	return _last_legend_corner

# Least-squares slope of the first series, in y units per x unit.
func fit_slope() -> float:
	if _series.is_empty():
		return 0.0
	var pts: Array = _series[0].get("points", [])
	if pts.size() < 2:
		return 0.0
	var mx: float = 0.0
	var my: float = 0.0
	for p: Vector2 in pts:
		mx += p.x
		my += p.y
	mx /= float(pts.size())
	my /= float(pts.size())
	var num: float = 0.0
	var den: float = 0.0
	for p2: Vector2 in pts:
		var dx: float = p2.x - mx
		num += dx * (p2.y - my)
		den += dx * dx
	return 0.0 if den == 0.0 else num / den

# What the key will say, in order. Public so it can be checked without rendering.
func legend_entries() -> Array:
	var out: Array = []
	for si: int in range(_series.size()):
		var lbl: String = str(_series[si].get("label", ""))
		# A bare "3" in a key beside a coloured line says nothing. Most games fall back to "L3"
		# already; the ones that NAME their levels can name them with digits, and those are the
		# legends this is for. Only the key is rewritten -- the label is used elsewhere.
		if legend_numbers_are_levels and lbl.is_valid_int():
			lbl = "L" + lbl
		out.append({"label": lbl,
			"color": _series[si].get("color", SERIES_COLORS[si % SERIES_COLORS.size()]),
			"dashed": false})
	if fit_line and not _series.is_empty():
		out.append({"label": "trend", "color": fit_color, "dashed": true})
	return out

func set_band(lo: float, hi: float) -> void:
	band_lo = minf(lo, hi)
	band_hi = maxf(lo, hi)
	queue_redraw()

func clear_band() -> void:
	band_lo = 0.0
	band_hi = 0.0
	queue_redraw()

func has_band() -> bool:
	return band_hi > band_lo

func set_series(series_list: Array) -> void:
	_series = series_list
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(0.0, 0.0, w, h), GROUND, true)

	# An axis title needs its OWN room. Drawn into the existing margins they landed on top of the
	# tick labels already living there, so the plot gives back a title's worth of space at each
	# edge that has one.
	var title_h: float = 20.0
	var px_left: float = float(MARGIN_LEFT)
	var px_right: float = w - float(MARGIN_RIGHT)
	var px_top: float = float(MARGIN_TOP) + (title_h if y_title != "" else 0.0)
	var px_bottom: float = h - float(MARGIN_BOTTOM) - (title_h if x_title != "" else 0.0)
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

	# The app's own text face, not Godot's fallback. Numbers on an axis are the one place in the
	# app where reading accuracy matters more than character, and this is the readable one.
	var font: Font = MainGlobals.get_text_font()
	# Tick labels are DATA and sit quiet; an axis title says what the whole axis means and is set
	# apart from them, or the two read as one run of text.
	var font_size: int = 15
	var title_size: int = 17
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

	# The four EDGES of the plot, drawn brighter than the gridlines inside it. At the same faint
	# value as the grid the plot had no boundary — the data appeared to float on the panel rather
	# than sit in a frame, and the axes read as just two more gridlines.
	var axis_color: Color = Color(1.0, 1.0, 1.0, 0.30)
	draw_line(Vector2(px_left, px_top), Vector2(px_left, px_bottom), axis_color, 1.0)
	draw_line(Vector2(px_left, px_bottom), Vector2(px_right, px_bottom), axis_color, 1.0)
	draw_line(Vector2(px_left, px_top), Vector2(px_right, px_top), axis_color, 1.0)
	draw_line(Vector2(px_right, px_top), Vector2(px_right, px_bottom), axis_color, 1.0)

	# The band goes down BEFORE the lines, so it reads as ground the data sits on rather than as
	# another series competing with it.
	if has_band():
		var by_hi: float = px_bottom - ((band_hi - y_min) / y_range) * plot_h
		var by_lo: float = px_bottom - ((band_lo - y_min) / y_range) * plot_h
		var top_y: float = maxf(px_top, minf(by_hi, by_lo))
		var bot_y: float = minf(px_bottom, maxf(by_hi, by_lo))
		if bot_y > top_y:
			draw_rect(Rect2(px_left, top_y, plot_w, bot_y - top_y), band_color, true)
			draw_line(Vector2(px_left, top_y), Vector2(px_right, top_y), band_edge, 1.0)
			draw_line(Vector2(px_left, bot_y), Vector2(px_right, bot_y), band_edge, 1.0)

	# Screen positions for every series, computed once. The legend needs them to find an empty
	# corner, and the drawing below would otherwise recompute the same thing.
	var screen_series: Array = []
	var sorted_series: Array = []
	for sidx: int in range(_series.size()):
		var raw: Array = _series[sidx].get("points", [])
		var sp_sorted: Array = raw.duplicate()
		sp_sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var sp: PackedVector2Array = []
		for pt2: Vector2 in sp_sorted:
			sp.append(Vector2(px_left + (pt2.x - x_min) / (x_max - x_min) * plot_w,
					px_bottom - ((pt2.y - y_min) / y_range) * plot_h))
		sorted_series.append(sp_sorted)
		screen_series.append(sp)

	# Legend whenever the plot shows more than one line — and the fitted line counts as one.
	#
	# Suppressing it for a single series was right when the chart drew one line and the legend only
	# repeated the y-axis title. It was wrong once a fit was added: the plot then had two lines and
	# nothing named either, which is harder to read than the redundancy ever was. A word at the end
	# of the line was tried first and is too easy to miss.
	var entries: Array = legend_entries()
	# Behind the data lines: they pass over the key rather than stopping at it. So this cannot
	# return early any more — the series are still to be drawn below.
	if entries.size() >= 2:
		_draw_legend(entries, font, font_size,
				Rect2(px_left, px_top, plot_w, plot_h), screen_series)

	# Series: sorted polylines and dots
	for si: int in range(_series.size()):
		var s: Dictionary = _series[si]
		var series_color: Color = s.get("color", SERIES_COLORS[si % SERIES_COLORS.size()])
		var sorted_pts: Array = sorted_series[si]
		var screen_pts: PackedVector2Array = screen_series[si]
		if screen_pts.is_empty():
			continue
		if screen_pts.size() > 1:
			draw_polyline(screen_pts, series_color, 2.0)
		for pi: int in range(screen_pts.size()):
			var sp: Vector2 = screen_pts[pi]
			draw_circle(sp, 4.0, series_color)
			# A session outside the player's usual range is ringed rather than recoloured, so the
			# series stays readable as one line and the ring reads as an annotation on it.
			if mark_outliers and has_band():
				var v: float = sorted_pts[pi].y
				if v < band_lo or v > band_hi:
					draw_arc(sp, 7.5, 0.0, TAU, 20, outlier_color, 2.0)

	# The fitted line and its slope, for the panels where the slope IS the measurement.
	if fit_line and not _series.is_empty():
		var fpts: Array = _series[0].get("points", [])
		if fpts.size() >= 2:
			var m: float = fit_slope()
			var fmx: float = 0.0
			var fmy: float = 0.0
			for p3: Vector2 in fpts:
				fmx += p3.x
				fmy += p3.y
			fmx /= float(fpts.size())
			fmy /= float(fpts.size())
			var ax: float = px_left
			var bx: float = px_right
			var ay: float = px_bottom - ((fmy + m * (x_min - fmx)) - y_min) / y_range * plot_h
			var by: float = px_bottom - ((fmy + m * (x_max - fmx)) - y_min) / y_range * plot_h
			# DASHED, and labelled at its end.
			#
			# Solid, it read as a second measured series and the chart looked like it was showing
			# two things without saying what either was. A dash pattern is the usual way to say
			# "derived, not measured", and the word at the end says which one it is — cheaper than
			# a legend box, which for a single series is just the y-axis title repeated.
			_draw_dashed(Vector2(ax, ay), Vector2(bx, by), fit_color, 2.0)

	# Axis titles.
	var title_color: Color = Color(0.86, 0.88, 0.92, 1.0)
	if x_title != "":
		# In the strip below the tick labels, which is why px_bottom was raised for it.
		var xts: Vector2 = font.get_string_size(x_title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size)
		draw_string(font, Vector2(px_left + (plot_w - xts.x) * 0.5, h - 5.0), x_title,
				HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, title_color)
	if y_title != "":
		# Along the top of the axis rather than rotated: a rotated string at this size is harder to
		# read than a short one where the axis begins. It sits in the strip px_top was lowered for,
		# so the topmost tick label no longer shares the line with it.
		# Lifted clear of the plot: sitting on the top gridline it crowded the highest tick label
		# and read as part of the plot rather than as a heading for it.
		draw_string(font, Vector2(4.0, float(MARGIN_TOP) + title_h - 12.0), y_title,
				HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, title_color)

func _fmt_y(val: float) -> String:
	if val >= 10000.0:
		return "%dk" % [int(val / 1000.0)]
	elif val == float(int(val)):
		return "%d" % [int(val)]
	else:
		return "%.1f" % [val]


# A dashed straight line. Godot draws only solid ones, and the distinction between a measured line
# and a fitted one is worth the few lines it takes.
func _draw_dashed(from: Vector2, to: Vector2, col: Color, width: float,
		dash: float = 7.0, gap: float = 5.0) -> void:
	var total: float = from.distance_to(to)
	if total <= 0.0:
		return
	var dir: Vector2 = (to - from) / total
	var at: float = 0.0
	while at < total:
		var seg: float = minf(dash, total - at)
		draw_line(from + dir * at, from + dir * (at + seg), col, width)
		at += dash + gap


func _draw_legend(entries: Array, font: Font, font_size: int, plot: Rect2,
		screen_series: Array) -> void:
	# A KEY, framed and sat on its own ground.
	#
	# Loose swatches and text over the plot read as stray annotation — a legend is a small panel you
	# look up, and it needs an edge for the eye to stop at. Drawn BEFORE the series, so the data
	# lines pass over it rather than stopping at its edge.
	#
	# It also goes wherever the data is NOT. A key pinned to one corner sits on top of the line
	# half the time, and in a chart that rises left-to-right — which is most of them — the
	# top-right is the worst place it could be.
	var box_sz: float = 11.0
	var box_gap: float = 7.0
	var pad: float = 8.0
	var line_h: float = font.get_string_size("X", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).y + 4.0
	var max_lbl_w: float = 0.0
	for e: Dictionary in entries:
		var ts2: Vector2 = font.get_string_size(str(e["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1,
				font_size)
		max_lbl_w = maxf(max_lbl_w, ts2.x)

	var leg_w: float = pad * 2.0 + box_sz + box_gap + max_lbl_w
	var leg_h: float = pad * 2.0 + line_h * float(entries.size()) - 4.0
	var inset: float = 8.0
	# Corners in preference order, so a genuinely empty chart still puts the key where a reader
	# expects it.
	var corners: Array = [
		Vector2(plot.position.x + plot.size.x - leg_w - inset, plot.position.y + inset),
		Vector2(plot.position.x + inset, plot.position.y + inset),
		Vector2(plot.position.x + plot.size.x - leg_w - inset,
				plot.position.y + plot.size.y - leg_h - inset),
		Vector2(plot.position.x + inset, plot.position.y + plot.size.y - leg_h - inset),
	]
	var best: Vector2 = corners[0]
	var best_hits: int = -1
	for cand: Vector2 in corners:
		var r: Rect2 = Rect2(cand, Vector2(leg_w, leg_h)).grow(6.0)
		var hits: int = 0
		for sp_list in screen_series:
			for pt: Vector2 in sp_list:
				if r.has_point(pt):
					hits += 1
		if hits == 0:
			best = cand
			best_hits = 0
			break
		if best_hits < 0 or hits < best_hits:
			best = cand
			best_hits = hits
	var leg_x: float = best.x
	var leg_y0: float = best.y
	# Recorded for the probe: which corner the rule picked. Costs nothing and is the only way to
	# assert the placement from outside.
	_last_legend_corner = ("top-" if best.y < plot.position.y + plot.size.y * 0.5 else "bottom-") \
		+ ("left" if best.x < plot.position.x + plot.size.x * 0.5 else "right")

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	# A shade lighter than the chart's ground: enough to lift the key off the plot, not so much
	# that it becomes a bright block in the corner.
	sb.bg_color = GROUND.lightened(0.07)
	sb.border_color = Color(1.0, 1.0, 1.0, 0.22)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	draw_style_box(sb, Rect2(leg_x, leg_y0, leg_w, leg_h))

	var leg_y: float = leg_y0 + pad
	for e2: Dictionary in entries:
		var lbl2: String = str(e2["label"])
		var col2: Color = e2["color"]
		var ts3: Vector2 = font.get_string_size(lbl2, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var sw_x: float = leg_x + pad
		var mid_y: float = leg_y + line_h * 0.5 - 2.0
		if bool(e2["dashed"]):
			# A dashed swatch, so the key looks like the line it stands for.
			_draw_dashed(Vector2(sw_x, mid_y), Vector2(sw_x + box_sz, mid_y), col2, 2.0, 4.0, 3.0)
		else:
			draw_line(Vector2(sw_x, mid_y), Vector2(sw_x + box_sz, mid_y), col2, 2.0)
		draw_string(font, Vector2(sw_x + box_sz + box_gap, mid_y + ts3.y * 0.34), lbl2,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.86, 0.88, 0.92, 1.0))
		leg_y += line_h

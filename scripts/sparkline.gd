extends Control
class_name Sparkline

# A tiny line sized to a table row: no axes, no labels, no legend.
#
# The overview screen leads with one row per domain, and a domain's shape over recent sessions is
# the whole point of that row. A full ChartControl there would be six charts of furniture and very
# little data; this draws only the line, the band it should be sitting in, and where it ends up.

const LINE_W: float = 1.6
const DOT_R: float = 2.6

var values: Array = []
var line_color: Color = Color(0.45, 0.80, 0.88, 1.0)
var band_color: Color = Color(0.45, 0.75, 0.85, 0.14)
# The plot's own ground, drawn behind everything and the SAME in every row.
#
# Without it the band was the only visible rectangle, so it read as the plot's background — and
# since the band marks the usual range while the line may leave it, that made a perfectly correct
# "this row is outside its usual range" look like a drawing error.
var ground_color: Color = Color(1.0, 1.0, 1.0, 0.045)
# In the same units as `values`. Left equal to skip the band.
var band_lo: float = 0.0
var band_hi: float = 0.0
# An explicit y range shared by every line drawn beside this one. Left equal, each scales itself.
var fixed_lo: float = 0.0
var fixed_hi: float = 0.0
# Drawn filled at the last point, so the eye lands on where the player is NOW rather than on the
# shape of the whole line.
var end_color: Color = ScreenBackdrop.STATS_MARK
var mark_end: bool = true

func set_values(v: Array) -> void:
	values = v
	queue_redraw()

func set_band(lo: float, hi: float) -> void:
	band_lo = minf(lo, hi)
	band_hi = maxf(lo, hi)
	queue_redraw()

func _draw() -> void:
	if values.size() < 2:
		return
	var w: float = size.x
	var h: float = size.y
	if w <= 1.0 or h <= 1.0:
		return

	# A FIXED scale when the caller sets one, and it matters for more than looks.
	#
	# Auto-scaling each line to its own data made the band — the "usual range" — a different height
	# in every row, so the backgrounds visibly disagreed. Worse, it made the SHAPES incomparable:
	# rows stacked side by side invite comparison, and a steep-looking line next to a flat one meant
	# nothing when each was scaled to itself.
	var lo: float
	var hi: float
	if fixed_hi > fixed_lo:
		lo = fixed_lo
		hi = fixed_hi
	else:
		lo = float(values[0])
		hi = lo
		for v in values:
			lo = minf(lo, float(v))
			hi = maxf(hi, float(v))
		# The scale must cover the band as well as the data, or a run of sessions sitting entirely
		# outside the usual range would be drawn as if it were inside it.
		if band_hi > band_lo:
			lo = minf(lo, band_lo)
			hi = maxf(hi, band_hi)
	var span: float = hi - lo
	if span <= 0.0:
		span = 1.0
		lo -= 0.5
	var pad: float = h * 0.12

	# The ground first: one uniform rectangle per row, so the band is plainly a marker inside a
	# plot rather than the plot itself.
	draw_rect(Rect2(0.0, 0.0, w, h), ground_color, true)

	if band_hi > band_lo:
		var y_hi: float = h - pad - ((band_hi - lo) / span) * (h - pad * 2.0)
		var y_lo: float = h - pad - ((band_lo - lo) / span) * (h - pad * 2.0)
		draw_rect(Rect2(0.0, minf(y_hi, y_lo), w, absf(y_lo - y_hi)), band_color, true)

	var pts: PackedVector2Array = []
	for i in range(values.size()):
		var x: float = (float(i) / float(values.size() - 1)) * w
		# Clamped to the shared scale: a session far outside it sits on the edge rather than
		# leaving the row. The exact depth stops mattering once it is out of range — that it is out
		# is the whole message — and the game's own chart carries the real number.
		var y: float = h - pad - ((clampf(float(values[i]), lo, hi) - lo) / span) * (h - pad * 2.0)
		pts.append(Vector2(x, y))
	draw_polyline(pts, line_color, LINE_W)
	if mark_end:
		draw_circle(pts[pts.size() - 1], DOT_R, end_color)

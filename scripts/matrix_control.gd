extends Control
class_name MatrixControl

# A labelled grid of cells shaded by value, with the count written in each.
#
# One user, through GameInstrument._answer_panel: the six yes/no games as a 2x2 (said yes / said
# no against was yes / was no) and Bucket Madness as a 3x3 (which bucket was right against which
# was chosen). Both are read cell by cell, with the count written in every cell.
#
# It was once meant for Polka Dots and for error rate by screen position too. Polka Dots turned
# out to need two accuracy bars instead — see its design doc — and the positional panels were
# never built. What is left is the reason the shading is flat: see _draw().

const PAD: float = 2.0
# DESKTOP sizes, put through the app's type scale like everything else. These were flat 11s, which
# is small on a desktop and far too small on a phone, where every other size is 1.6x larger.
# DESKTOP sizes, put through the app's type scale. Raised from 13: a matrix is read cell by cell,
# not scanned like a table, so it carries far less text than a chart and can afford the room.
const LABEL_PT: int = 20
const VALUE_PT: int = 20
# The counts step down to fit a dense grid, but not below this — past it the number stops being
# readable and the cell may as well be empty.
const VALUE_PT_MIN: int = 14
# And the same floor for the labels, which now step down to fit their columns.
const LABEL_PT_MIN: int = 11
# Space between a row label and the first cell, and between the column labels and the top row.
const LABEL_GAP: float = 8.0

var rows: Array = []          # row labels, top to bottom
var cols: Array = []          # column labels, left to right
var cells: Dictionary = {}    # {Vector2i(col, row): value}
var low_color: Color = Color(0.11, 0.13, 0.18, 1.0)   # nothing landed here
var high_color: Color = ScreenBackdrop.STATS_HOT      # a mistake, however many
var label_color: Color = Color(0.78, 0.80, 0.84, 1.0)
var value_color: Color = Color(1.0, 1.0, 1.0, 0.92)
# When true the diagonal (correct answers) is drawn in a calm colour rather than a hot one, so a
# confusion matrix reads as "where the heat is off the diagonal".
var cool_diagonal: bool = true
var diagonal_color: Color = ScreenBackdrop.STATS_STEADY.darkened(0.25)

func set_matrix(row_labels: Array, col_labels: Array, values: Dictionary) -> void:
	rows = row_labels
	cols = col_labels
	cells = values
	queue_redraw()

# The row gutter, the column width and the type size the labels can be drawn at, for a control
# `w` wide. Extracted from _draw so it can be checked without rendering — the same reason
# ChartControl.legend_entries() was.
#
# Two things are measured rather than assumed. The GUTTER: it was a flat 34 units, so any row
# label wider than that was drawn at a negative x, running off the left edge and vanishing under
# the first column. And the TYPE: the counts already stepped down to fit their cells but the
# labels did not, so a third column was enough to make "Chose dumpster" run into its neighbours.
# THREE states, not a gradient: empty, right, wrong. Its own function so it can be checked
# without rendering.
func cell_color(key: Vector2i) -> Color:
	if float(cells.get(key, 0)) <= 0.0:
		return low_color
	return diagonal_color if (cool_diagonal and key.x == key.y) else high_color

func label_metrics(w: float) -> Dictionary:
	var font: Font = MainGlobals.get_text_font()
	var pt: int = MainGlobals.ui_font_size(LABEL_PT)
	var floor_pt: int = MainGlobals.ui_font_size(LABEL_PT_MIN)
	var left: float = 0.0
	var cw: float = 0.0
	while true:
		left = 0.0
		for r in rows:
			left = maxf(left, font.get_string_size(str(r), HORIZONTAL_ALIGNMENT_LEFT, -1, pt).x)
		left += LABEL_GAP
		cw = (w - left) / float(maxi(cols.size(), 1))
		var widest: float = 0.0
		for c in cols:
			widest = maxf(widest, font.get_string_size(
				str(c), HORIZONTAL_ALIGNMENT_LEFT, -1, pt).x)
		if widest <= cw - LABEL_GAP or pt <= floor_pt:
			break
		pt -= 1
	return {"label_pt": pt, "left": left, "cw": cw}

func _draw() -> void:
	if rows.is_empty() or cols.is_empty():
		return
	var font: Font = MainGlobals.get_text_font()
	var value_pt: int = MainGlobals.ui_font_size(VALUE_PT)

	var geo: Dictionary = label_metrics(size.x)
	var label_pt: int = int(geo["label_pt"])
	var left: float = float(geo["left"])
	var cw: float = float(geo["cw"])
	var top: float = font.get_string_size("X", HORIZONTAL_ALIGNMENT_LEFT, -1, label_pt).y \
		+ LABEL_GAP

	var h: float = size.y - top
	if cw <= 0.0 or h <= 0.0:
		return
	var ch: float = h / float(rows.size())
	# A count has to fit its cell. Where the grid is dense the number steps down rather than
	# spilling over the edges of the box it belongs to.
	while value_pt > MainGlobals.ui_font_size(VALUE_PT_MIN) \
			and font.get_string_size("88", HORIZONTAL_ALIGNMENT_LEFT, -1, value_pt).x \
			> cw - PAD * 3.0:
		value_pt -= 1

	for ci in range(cols.size()):
		var lbl: String = str(cols[ci])
		var ts: Vector2 = font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, label_pt)
		draw_string(font, Vector2(left + ci * cw + (cw - ts.x) * 0.5, top - LABEL_GAP * 0.5),
				lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, label_pt, label_color)

	for ri in range(rows.size()):
		var rlbl: String = str(rows[ri])
		var rts: Vector2 = font.get_string_size(rlbl, HORIZONTAL_ALIGNMENT_LEFT, -1, label_pt)
		# Right-aligned against the cells, and never past the left edge.
		draw_string(font, Vector2(maxf(0.0, left - LABEL_GAP - rts.x),
				top + ri * ch + ch * 0.5 + rts.y * 0.34),
				rlbl, HORIZONTAL_ALIGNMENT_LEFT, -1, label_pt, label_color)
		for ci2 in range(cols.size()):
			var key: Vector2i = Vector2i(ci2, ri)
			var v: float = float(cells.get(key, 0))
			var r2: Rect2 = Rect2(left + ci2 * cw + PAD, top + ri * ch + PAD,
					cw - PAD * 2.0, ch - PAD * 2.0)
			# THREE states, not a gradient: empty, right, wrong.
			#
			# Cells used to be shaded from low_color to high_color by their value, which in a
			# grid this size says exactly what the number printed in the cell already says —
			# two encodings of one fact, and the reader has to work out whether the brightness
			# means something the count does not. It does not. The gradient earns its keep on a
			# grid read as a picture, like error rate over screen positions, where a dark corner
			# is a finding; nothing in the app draws one of those, so it is gone rather than
			# kept for a panel that may never exist.
			var col: Color = cell_color(key)
			draw_rect(r2, col, true)
			if v > 0.0:
				var txt: String = str(int(v))
				var tts: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, value_pt)
				draw_string(font, Vector2(r2.position.x + (r2.size.x - tts.x) * 0.5,
						r2.position.y + (r2.size.y + tts.y * 0.7) * 0.5), txt,
						HORIZONTAL_ALIGNMENT_LEFT, -1, value_pt, value_color)

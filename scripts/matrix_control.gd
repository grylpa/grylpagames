extends Control
class_name MatrixControl

# A labelled grid of cells shaded by value, with the count written in each.
#
# Four of the game panels want the same widget and none of them is a chart:
#   - Polka Dots: which character was shown against which was chosen
#   - Witness:    which detail of the scene was lost
#   - Pinpoint / Glimpse / Lineup: error rate by screen position, where a blind sector shows up as
#     a dark corner and nothing else in the app could reveal it
#   - the six yes/no games: TP / FP / TN / FN as a 2x2
#
# typit already draws a per-key heat map of its own. Lifting that into this control would let Polka
# Dots and the 2x2 share it for free, but it means moving code out of a game into shared scripts —
# proposed in the plan, not done here, because that is the author's call.

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
# Space between a row label and the first cell, and between the column labels and the top row.
const LABEL_GAP: float = 8.0

var rows: Array = []          # row labels, top to bottom
var cols: Array = []          # column labels, left to right
var cells: Dictionary = {}    # {Vector2i(col, row): value}
var low_color: Color = Color(0.11, 0.13, 0.18, 1.0)
var high_color: Color = ScreenBackdrop.STATS_HOT
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

func _max_value() -> float:
	var m: float = 0.0
	for k in cells.keys():
		var v: float = float(cells[k])
		if cool_diagonal and k is Vector2i and k.x == k.y:
			continue      # the diagonal would otherwise set the scale and flatten everything else
		m = maxf(m, v)
	return m

func _draw() -> void:
	if rows.is_empty() or cols.is_empty():
		return
	var font: Font = MainGlobals.get_text_font()
	var label_pt: int = MainGlobals.ui_font_size(LABEL_PT)
	var value_pt: int = MainGlobals.ui_font_size(VALUE_PT)

	# THE GUTTER IS MEASURED, not assumed. It was a flat 34 units, so any row label wider than that
	# was drawn at a negative x — running off the left edge and disappearing under the first column
	# of cells. It now fits the widest label actually present.
	var left: float = 0.0
	for r in rows:
		left = maxf(left, font.get_string_size(str(r), HORIZONTAL_ALIGNMENT_LEFT, -1, label_pt).x)
	left += LABEL_GAP
	var top: float = font.get_string_size("X", HORIZONTAL_ALIGNMENT_LEFT, -1, label_pt).y + LABEL_GAP

	var w: float = size.x - left
	var h: float = size.y - top
	if w <= 0.0 or h <= 0.0:
		return
	var cw: float = w / float(cols.size())
	var ch: float = h / float(rows.size())
	# A count has to fit its cell. Where the grid is dense the number steps down rather than
	# spilling over the edges of the box it belongs to.
	while value_pt > MainGlobals.ui_font_size(VALUE_PT_MIN) \
			and font.get_string_size("88", HORIZONTAL_ALIGNMENT_LEFT, -1, value_pt).x \
			> cw - PAD * 3.0:
		value_pt -= 1
	var vmax: float = _max_value()

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
			var col: Color = low_color
			if v > 0.0:
				if cool_diagonal and ci2 == ri:
					col = diagonal_color
				else:
					col = low_color.lerp(high_color, clampf(v / maxf(vmax, 1.0), 0.0, 1.0))
			draw_rect(r2, col, true)
			if v > 0.0:
				var txt: String = str(int(v))
				var tts: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, value_pt)
				draw_string(font, Vector2(r2.position.x + (r2.size.x - tts.x) * 0.5,
						r2.position.y + (r2.size.y + tts.y * 0.7) * 0.5), txt,
						HORIZONTAL_ALIGNMENT_LEFT, -1, value_pt, value_color)

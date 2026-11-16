extends RefCounted

# TIP THE SCALES' DRAWINGS (static, drawn into whatever CanvasItem asks), over materials rendered once
# (level.gd _bake: crate.gdshader per color, paper.gdshader, leather.gdshader).
#
# THE LOOK (2026-11-16, second pass: the first followed Mor's desktop screen grab and was "far from
# amazing"): a weigh-house at lamplight.
#   CRATES stand on the rack's shelves: painted pine, worn, iron corners (the baked texture), the letter
#     sprayed through a stencil, and a SLATE hung on a nail with the weights it may still have CHALKED on
#     it -- a weight crossed out is rubbed off, leaving a smudge. A settled crate wears a BRASS PLATE with
#     its weight stamped in.
#   The WEIGHTS on the workbench are cast-iron bells, lit from above; the settled one is brass.
#   The CLUES are engravings on old ledger paper lying on the counter: an ink balance with hatched shading,
#     the crates in its pans as colored ink stamps; a weighed clue gets a rubber stamp across it.

const PUZZLE: Script = preload("res://tipscales/scripts/puzzle.gd")

const SET_NAMES: Array = ["Red", "Gold", "Teal", "Violet", "Blue", "Rose"]
const SET_COLORS: Array = [
	Color(0.74, 0.22, 0.18),
	Color(0.88, 0.62, 0.16),
	Color(0.12, 0.52, 0.50),
	Color(0.45, 0.32, 0.68),
	Color(0.20, 0.38, 0.72),
	Color(0.80, 0.38, 0.54),
]
const LETTERS: String = "ABCDEF"
const EITHER: String = " (either order)"

const INK: Color = Color(0.16, 0.11, 0.08)
const PAPER: Color = Color(0.95, 0.91, 0.82)
const BRASS: Color = Color(0.86, 0.68, 0.32)
const BRASS_DARK: Color = Color(0.55, 0.40, 0.16)
const GLOW: Color = Color(1.0, 0.80, 0.40)
const CHALK: Color = Color(0.95, 0.94, 0.89)
const SLATE: Color = Color(0.15, 0.17, 0.18)

static func set_color(row: int) -> Color:
	return SET_COLORS[row % SET_COLORS.size()]

static func crate_name(row: int, col: int) -> String:
	return "%s %s" % [SET_NAMES[row % SET_NAMES.size()], LETTERS[col]]

static func _soft_shadow(ci: CanvasItem, r: Rect2, off: Vector2, spread: float, alpha: float) -> void:
	for k in 4:
		var g: float = spread * (1.0 - float(k) / 4.0)
		ci.draw_rect(Rect2(r.position + off, r.size).grow(g), Color(0, 0, 0, alpha / 4.0))

static func _vgrad(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))

# --- crates -----------------------------------------------------------------------------------------

# One crate on its shelf. `tex`: its baked front (crate.gdshader, its color); `mask`: the weights still
# open (bit v-1); `rubbed`: weights crossed out (a smudge where the chalk was); `placed`: its weight once
# settled. `ring`: 0 none, 1 selected (lamplight round it), 2 named by the clue in focus, 3 a hint's.
static func draw_crate(ci: CanvasItem, r: Rect2, tex: Texture2D, row: int, col: int, n_w: int, mask: int,
		rubbed: int, placed: int, ring: int, pop: float, serif: Font) -> void:
	var c: Color = set_color(row)
	if pop != 1.0:
		var ctr: Vector2 = r.get_center()
		r = Rect2(ctr - r.size * 0.5 * pop, r.size * pop)
	var s: float = minf(r.size.x, r.size.y)
	if ring > 0:
		var rc: Color = GLOW if ring == 1 else (c.lightened(0.45) if ring == 2 else Color(0.60, 1.0, 0.68))
		for k in 5:
			ci.draw_rect(r.grow(s * (0.03 + 0.03 * float(k))), Color(rc, 0.16 - 0.025 * float(k)))
		ci.draw_rect(r.grow(s * 0.035), rc, false, maxf(2.0, s * 0.03))
	_soft_shadow(ci, r, Vector2(s * 0.02, s * 0.03), s * 0.05, 0.55)
	if tex != null:
		ci.draw_texture_rect(tex, r, false)
	else:
		ci.draw_rect(r, c.darkened(0.2))
	# the letter, sprayed through a stencil on the left of the planks
	var lfs: int = int(s * 0.42)
	var lt: String = LETTERS[col]
	var lw: float = serif.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
	var lx: float = r.position.x + r.size.x * 0.17 - lw * 0.5
	var ly: float = r.position.y + r.size.y * 0.5 + lfs * 0.36
	# a dark outline under the cream: on the gold (and rose) crates the cream alone did not stand out
	ci.draw_string_outline(serif, Vector2(lx, ly), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, maxi(3, int(s * 0.06)), Color(0.10, 0.06, 0.03, 0.85))
	ci.draw_string(serif, Vector2(lx, ly), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(0.99, 0.97, 0.90))
	# the board it hangs on: the slate, or the brass plate
	var b: Rect2 = Rect2(r.position.x + r.size.x * 0.31, r.position.y + r.size.y * 0.20,
		r.size.x * 0.61, r.size.y * 0.66)
	var nail: Vector2 = Vector2(b.get_center().x, r.position.y + r.size.y * 0.09)
	if placed > 0:
		_soft_shadow(ci, b, Vector2(1.5, 2.5), 3.0, 0.5)
		_vgrad(ci, b, Color(0.98, 0.84, 0.50), Color(0.66, 0.48, 0.20))
		ci.draw_rect(b, Color(0.42, 0.30, 0.12), false, maxf(1.5, s * 0.02))
		ci.draw_rect(Rect2(b.position + Vector2(2, 2), Vector2(b.size.x - 4.0, maxf(1.5, s * 0.02))), Color(1.0, 0.96, 0.80, 0.7))
		for rv in [b.position + Vector2(s * 0.05, s * 0.05), Vector2(b.end.x - s * 0.05, b.position.y + s * 0.05),
				Vector2(b.position.x + s * 0.05, b.end.y - s * 0.05), b.end - Vector2(s * 0.05, s * 0.05)]:
			ci.draw_circle(rv, maxf(1.2, s * 0.018), Color(0.45, 0.33, 0.14))
		var fs: int = int(b.size.y * 0.74)
		var txt: String = str(placed)
		var kfs: int = maxi(8, int(fs * 0.34))
		var w: float = serif.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var kw: float = serif.get_string_size("kg", HORIZONTAL_ALIGNMENT_LEFT, -1, kfs).x
		var base: Vector2 = Vector2(b.get_center().x - (w + kw + 2.0) * 0.5, b.end.y - b.size.y * 0.18)
		ci.draw_string(serif, base + Vector2(0, 1.2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.95, 0.75, 0.55))
		ci.draw_string(serif, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.24, 0.15, 0.05))
		ci.draw_string(serif, base + Vector2(w + 2.0, 0), "kg", HORIZONTAL_ALIGNMENT_LEFT, -1, kfs, Color(0.24, 0.15, 0.05, 0.8))
		return
	# the slate, on a string from a nail
	ci.draw_line(nail, b.position + Vector2(b.size.x * 0.12, 0), Color(0.80, 0.72, 0.55, 0.9), maxf(1.0, s * 0.012))
	ci.draw_line(nail, Vector2(b.end.x - b.size.x * 0.12, b.position.y), Color(0.80, 0.72, 0.55, 0.9), maxf(1.0, s * 0.012))
	ci.draw_circle(nail, maxf(1.6, s * 0.022), Color(0.30, 0.30, 0.32))
	_soft_shadow(ci, b, Vector2(1.5, 2.5), 3.0, 0.5)
	ci.draw_rect(b, Color(0.55, 0.40, 0.24))                  # its wooden frame
	var sb: Rect2 = b.grow(-maxf(1.5, s * 0.025))
	_vgrad(ci, sb, SLATE.lightened(0.08), SLATE.darkened(0.15))
	# NOTHING LEFT: every weight rubbed off -- one of them was right (level.gd counts it, once)
	if mask == 0:
		var qfs: int = int(sb.size.y * 0.80)
		var qw: float = serif.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, qfs).x
		ci.draw_rect(sb, Color(0.85, 0.25, 0.20), false, maxf(2.0, s * 0.03))
		ci.draw_string(serif, Vector2(sb.get_center().x - qw * 0.5, sb.get_center().y + qfs * 0.36), "?",
			HORIZONTAL_ALIGNMENT_LEFT, -1, qfs, Color(1.0, 0.55, 0.45, 0.95))
		return
	# the chalk: the open weights, in a grid; a rubbed-out one leaves a smudge
	var per_row: int = 2 if n_w == 4 else 3
	var nr: int = int(ceil(float(n_w) / float(per_row)))
	var cw: float = sb.size.x / float(per_row)
	var chh: float = sb.size.y / float(nr)
	var fs2: int = int(minf(cw * 0.95, chh * 0.86))
	for v in range(1, n_w + 1):
		var i2: int = v - 1
		var cx: float = sb.position.x + cw * (float(i2 % per_row) + 0.5)
		var cy: float = sb.position.y + chh * (float(i2 / per_row) + 0.5)
		if (mask & PUZZLE.bit(v)) == 0:
			if rubbed & PUZZLE.bit(v):
				ci.draw_circle(Vector2(cx, cy), minf(cw, chh) * 0.34, Color(CHALK, 0.06))
				ci.draw_circle(Vector2(cx + 2.0, cy - 1.0), minf(cw, chh) * 0.22, Color(CHALK, 0.05))
			continue
		var t: String = str(v)
		var tw: float = serif.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var p: Vector2 = Vector2(cx - tw * 0.5, cy + fs2 * 0.36)
		ci.draw_string(serif, p + Vector2(0.6, 0.4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(CHALK, 0.25))
		ci.draw_string(serif, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(CHALK, 0.93))

# --- the cast-iron weights on the workbench ---------------------------------------------------------

# state: 0 open, 1 crossed out, 2 taken by another crate of the color, 3 the crate's weight
static func draw_weight(ci: CanvasItem, r: Rect2, v: int, state: int, press: float, serif: Font) -> void:
	var ctr: Vector2 = r.get_center()
	var s: float = minf(r.size.x, r.size.y)
	var a: float = 1.0 if state == 0 or state == 3 else 0.30
	var brass: bool = state == 3
	var top_c: Color = Color(0.48, 0.48, 0.52) if not brass else Color(1.0, 0.88, 0.55)
	var mid_c: Color = Color(0.22, 0.22, 0.25) if not brass else Color(0.82, 0.62, 0.26)
	var bot_c: Color = Color(0.09, 0.09, 0.11) if not brass else Color(0.48, 0.33, 0.12)
	var w: float = s * (0.88 - 0.06 * press)
	var h: float = s * (0.66 - 0.05 * press)
	var top: float = ctr.y - h * 0.34
	var bot: float = ctr.y + h * 0.56
	# its shadow on the leather
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(ctr.x - w * 0.52, bot + 1.0), Vector2(ctr.x + w * 0.56, bot + 1.0),
		Vector2(ctr.x + w * 0.46, bot + s * 0.07), Vector2(ctr.x - w * 0.42, bot + s * 0.07)]), Color(0, 0, 0, 0.45 * a))
	# the bell: lit on its shoulders, dark at the foot
	var poly: PackedVector2Array = PackedVector2Array([
		Vector2(ctr.x - w * 0.34, top), Vector2(ctr.x + w * 0.34, top),
		Vector2(ctr.x + w * 0.50, bot), Vector2(ctr.x - w * 0.50, bot)])
	ci.draw_polygon(poly, PackedColorArray([Color(top_c, a), Color(mid_c, a), Color(bot_c, a), Color(mid_c.darkened(0.2), a)]))
	# the rim at the foot and a highlight down the left
	ci.draw_rect(Rect2(ctr.x - w * 0.52, bot - s * 0.07, w * 1.04, s * 0.07), Color(mid_c.darkened(0.35), a))
	ci.draw_line(Vector2(ctr.x - w * 0.30, top + 2.0), Vector2(ctr.x - w * 0.43, bot - s * 0.08), Color(top_c.lightened(0.3), 0.55 * a), maxf(1.5, s * 0.025))
	ci.draw_line(Vector2(ctr.x - w * 0.34, top), Vector2(ctr.x + w * 0.34, top), Color(top_c.lightened(0.2), a), maxf(2.0, s * 0.03))
	# the ring handle
	ci.draw_arc(Vector2(ctr.x, top - s * 0.07), s * 0.12, PI, TAU, 18, Color(mid_c, a), maxf(2.5, s * 0.05))
	ci.draw_arc(Vector2(ctr.x, top - s * 0.07), s * 0.12, PI * 1.1, PI * 1.5, 8, Color(top_c, 0.8 * a), maxf(1.0, s * 0.018))
	# the cast number, raised: a light edge above, dark below
	var fs: int = int(s * 0.38)
	var t: String = str(v)
	var tw: float = serif.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p: Vector2 = Vector2(ctr.x - tw * 0.5, ctr.y + h * 0.26)
	ci.draw_string(serif, p + Vector2(0, 1.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6 * a))
	ci.draw_string(serif, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		Color(0.94, 0.90, 0.80, a) if not brass else Color(0.30, 0.18, 0.05, a))
	if state == 1:
		# chalked out: a stroke across it
		var d: float = s * 0.30
		ci.draw_line(ctr + Vector2(-d, d * 0.6), ctr + Vector2(d, -d * 0.6), Color(CHALK, 0.85), maxf(3.0, s * 0.06))

# --- the clue engravings ----------------------------------------------------------------------------

# A clue as a picture: [left pan crates, right pan crates, brass weight on the right (0 none), tilt]:
# tilt -1 the left pan down, 0 level, 1 the right pan down. BETWEEN is a shelf (see draw_ticket).
static func pans(cl: Dictionary) -> Array:
	var c: Array = cl["c"]
	match int(cl["t"]):
		PUZZLE.T.EQUAL:
			return [[c[0]], [c[1]], 0, 0]
		PUZZLE.T.OFFSET:
			return [[c[0]], [c[1]], int(cl["k"]), 0]
		PUZZLE.T.SUM_EQ:
			return [[c[0], c[1]], [c[2]], 0, 0]
		PUZZLE.T.SUM_LIGHTER:
			return [[c[0], c[1]], [c[2]], 0, 1]
		PUZZLE.T.PAIRS_EQ:
			return [[c[0], c[1]], [c[2], c[3]], 0, 0]
		PUZZLE.T.HEAVIER:
			return [[c[0]], [c[1]], 0, -1]
		PUZZLE.T.SUM_HEAVIER:
			return [[c[0], c[1]], [c[2]], 0, -1]
	return [[], [], 0, 0]

static func caption(cl: Dictionary, cols: int) -> String:
	var n: Array = []
	for i in cl["c"]:
		# a no-break space inside the name: a wrapped rule split "Red / A" across its lines
		n.append(crate_name(i / cols, i % cols).replace(" ", "\u00a0"))
	match int(cl["t"]):
		PUZZLE.T.EQUAL:
			return "%s = %s" % [n[0], n[1]]
		PUZZLE.T.OFFSET:
			return "%s = %s + %d" % [n[0], n[1], int(cl["k"])]
		PUZZLE.T.SUM_EQ:
			return "%s + %s = %s" % [n[0], n[1], n[2]]
		PUZZLE.T.SUM_LIGHTER:
			return "%s + %s < %s" % [n[0], n[1], n[2]]
		PUZZLE.T.PAIRS_EQ:
			return "%s + %s = %s + %s" % [n[0], n[1], n[2], n[3]]
		PUZZLE.T.BETWEEN:
			# EITHER ORDER, said on the paper: read one way only, "D between C and E" lets a player rule out
			# a weight it does not (the user, 2026-11-16; Mor's owner asked the same)
			return "%s is between %s and %s%s" % [n[0], n[1], n[2], EITHER]
		PUZZLE.T.HEAVIER:
			return "%s > %s" % [n[0], n[1]]
		PUZZLE.T.SUM_HEAVIER:
			return "%s + %s > %s" % [n[0], n[1], n[2]]
	return ""

# A crate in an engraving: a colored ink STAMP, its letter left in the paper's color.
static func _stamp(ci: CanvasItem, ctr: Vector2, s: float, idx: int, cols: int, serif: Font, ring: bool, a: float) -> void:
	var c: Color = set_color(idx / cols)
	var r: Rect2 = Rect2(ctr - Vector2(s, s * 0.84) * 0.5, Vector2(s, s * 0.84))
	ci.draw_rect(r, Color(c.darkened(0.08), 0.92 * a))
	ci.draw_rect(r, Color(INK, 0.55 * a), false, maxf(1.0, s * 0.05))
	ci.draw_line(r.position + Vector2(0, r.size.y * 0.5), Vector2(r.end.x, r.position.y + r.size.y * 0.5), Color(INK, 0.25 * a), 1.0)
	if ring:
		ci.draw_rect(r.grow(s * 0.14), Color(INK, 0.8 * a), false, maxf(1.5, s * 0.06))
	var fs: int = int(s * 0.70)
	var t: String = LETTERS[idx % cols]
	var tw: float = serif.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string_outline(serif, Vector2(ctr.x - tw * 0.5, ctr.y + fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, int(s * 0.08)), Color(INK, 0.75 * a))
	ci.draw_string(serif, Vector2(ctr.x - tw * 0.5, ctr.y + fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.98, 0.92, a))

# engraver's hatching: diagonal strokes filling `r`
static func _hatch(ci: CanvasItem, r: Rect2, col: Color, step: float) -> void:
	var x: float = r.position.x - r.size.y
	while x < r.end.x:
		var p0: Vector2 = Vector2(maxf(x, r.position.x), r.end.y - maxf(0.0, r.position.x - x))
		var p1: Vector2 = Vector2(minf(x + r.size.y, r.end.x), r.position.y + maxf(0.0, (x + r.size.y) - r.end.x))
		ci.draw_line(p0, p1, col, 1.0)
		x += step

# The paper: the engraving (or the shelf, for BETWEEN) and the caption. state: 0 live, 1 in focus, 2 set
# aside, 3 settled (all its crates known). `tilt_deg`: the paper lies a little askew on the counter.
static func draw_ticket(ci: CanvasItem, r: Rect2, cl: Dictionary, cols: int, state: int, serif: Font,
		paper: Texture2D, aside_btn: Rect2, swing: float, tilt_deg: float, show_rule: bool) -> void:
	var a: float = 1.0 if state <= 1 else 0.62
	var ctr: Vector2 = r.get_center()
	ci.draw_set_transform(ctr, deg_to_rad(tilt_deg), Vector2.ONE)
	var lr: Rect2 = Rect2(-r.size * 0.5, r.size)
	if state == 1:
		for k in 5:
			ci.draw_rect(lr.grow(4.0 + 3.0 * float(k)), Color(GLOW, 0.13 - 0.02 * float(k)))
	_soft_shadow(ci, lr.grow(-2.0), Vector2(3.0, 5.0), 6.0, 0.55)
	if paper != null:
		ci.draw_texture_rect(paper, lr, false, Color(1, 1, 1, 1) if state <= 1 else Color(0.78, 0.76, 0.72))
	else:
		ci.draw_rect(lr, PAPER)
	var ink: Color = Color(INK, 0.9 * a)
	# THE ENGRAVING has the paper to itself unless the rule is written out under it (the menu's switch: the
	# picture says it all, so the written rule is off by default)
	var rule_h: float = clampf(lr.size.y * 0.21, 26.0, 46.0) if show_rule else 0.0
	var pic: Rect2 = Rect2(lr.position.x + 10.0, lr.position.y + 8.0, lr.size.x - 20.0,
		lr.size.y - 14.0 - (rule_h + 4.0 if show_rule else 0.0))
	var s: float = clampf(pic.size.y * 0.31, 14.0, 46.0)
	if int(cl["t"]) == PUZZLE.T.BETWEEN:
		var c: Array = cl["c"]
		var sy: float = pic.position.y + s * 1.85
		var shelf: Rect2 = Rect2(pic.position.x + pic.size.x * 0.14, sy, pic.size.x * 0.72, maxf(4.0, s * 0.18))
		ci.draw_rect(shelf, Color(INK, 0.10 * a))
		_hatch(ci, shelf, Color(INK, 0.45 * a), 3.0)
		ci.draw_rect(shelf, ink, false, 1.2)
		var xs: Array = [pic.position.x + pic.size.x * 0.28, pic.get_center().x, pic.position.x + pic.size.x * 0.72]
		_stamp(ci, Vector2(xs[0], sy - s * 0.46), s, c[1], cols, serif, false, a)
		_stamp(ci, Vector2(xs[2], sy - s * 0.46), s, c[2], cols, serif, false, a)
		_stamp(ci, Vector2(xs[1], sy - s * 1.20), s, c[0], cols, serif, true, a)
		ci.draw_dashed_line(Vector2(xs[1], sy - s * 0.70), Vector2(xs[1], sy), Color(INK, 0.5 * a), 1.2, 3.0)
		# EITHER ORDER, drawn: a swap under the shelf, from one outer crate to the other and back (a row of
		# three alone reads as a ruler, lightest on the left: the user, 2026-11-16)
		var ah: float = s * 0.20
		var y1: float = sy + s * 0.50
		var y2: float = sy + s * 0.80
		for arrow in [[xs[0], xs[2], y1], [xs[2], xs[0], y2]]:
			var ax0: float = arrow[0]
			var ax1: float = arrow[1]
			var yy: float = arrow[2]
			var dx: float = signf(ax1 - ax0)
			ci.draw_line(Vector2(ax0, yy), Vector2(ax1, yy), Color(INK, 0.6 * a), 1.4)
			ci.draw_line(Vector2(ax1, yy), Vector2(ax1 - dx * ah, yy - ah * 0.55), Color(INK, 0.6 * a), 1.4)
			ci.draw_line(Vector2(ax1, yy), Vector2(ax1 - dx * ah, yy + ah * 0.55), Color(INK, 0.6 * a), 1.4)
	else:
		var pn: Array = pans(cl)
		var tilt: float = deg_to_rad(10.0) * float(pn[3]) + swing
		var pivot: Vector2 = Vector2(pic.get_center().x, pic.position.y + pic.size.y * 0.12)
		var half: float = pic.size.x * 0.35
		var dir: Vector2 = Vector2(cos(tilt), sin(tilt))
		var lp: Vector2 = pivot - dir * half
		var rp: Vector2 = pivot + dir * half
		# the stand: a column hatched on its shaded side, a stepped base
		var foot: float = pic.end.y
		var col_w: float = maxf(5.0, s * 0.26)
		var column: Rect2 = Rect2(pivot.x - col_w * 0.5, pivot.y, col_w, foot - pivot.y - s * 0.30)
		_hatch(ci, Rect2(column.position.x + col_w * 0.5, column.position.y, col_w * 0.5, column.size.y), Color(INK, 0.40 * a), 2.6)
		ci.draw_rect(column, ink, false, 1.2)
		var base1: Rect2 = Rect2(pivot.x - s * 0.75, foot - s * 0.30, s * 1.5, s * 0.14)
		var base2: Rect2 = Rect2(pivot.x - s * 1.05, foot - s * 0.16, s * 2.1, s * 0.16)
		for bs in [base1, base2]:
			_hatch(ci, Rect2(bs.position + Vector2(bs.size.x * 0.55, 0), Vector2(bs.size.x * 0.45, bs.size.y)), Color(INK, 0.40 * a), 2.6)
			ci.draw_rect(bs, ink, false, 1.2)
		# the beam: tapered from the pivot, with a pointer
		var nrm: Vector2 = Vector2(-dir.y, dir.x)
		var bw: float = maxf(2.0, s * 0.12)
		ci.draw_colored_polygon(PackedVector2Array([lp + nrm * bw * 0.35, pivot + nrm * bw, rp + nrm * bw * 0.35,
			rp - nrm * bw * 0.35, pivot - nrm * bw, lp - nrm * bw * 0.35]), Color(INK, 0.85 * a))
		ci.draw_line(pivot, pivot + nrm * s * 0.70, ink, 1.4)
		ci.draw_circle(pivot, maxf(3.0, s * 0.15), Color(PAPER, a))
		ci.draw_arc(pivot, maxf(3.0, s * 0.15), 0.0, TAU, 16, ink, 1.4)
		ci.draw_circle(lp, maxf(1.5, s * 0.07), ink)
		ci.draw_circle(rp, maxf(1.5, s * 0.07), ink)
		# the pans, each on three chains
		for side in 2:
			var end: Vector2 = lp if side == 0 else rp
			var items: Array = pn[side]
			var n_items: int = items.size() + (1 if side == 1 and int(pn[2]) > 0 else 0)
			var pw: float = maxf(s * 1.35, s * 1.12 * float(n_items) + s * 0.4)
			var py: float = end.y + s * 1.95
			for k in 3:
				var fx: float = -0.42 + 0.42 * float(k)
				ci.draw_line(end, Vector2(end.x + pw * fx, py), Color(INK, 0.5 * a), 1.0)
			var pan: PackedVector2Array = PackedVector2Array()
			for i in 15:
				var u: float = float(i) / 14.0
				pan.append(Vector2(end.x - pw * 0.5 + pw * u, py + sin(u * PI) * s * 0.32))
			ci.draw_colored_polygon(pan, Color(INK, 0.12 * a))
			ci.draw_polyline(pan, ink, maxf(1.6, s * 0.07))
			ci.draw_line(pan[0], pan[pan.size() - 1], ink, 1.2)
			var x0: float = end.x - (float(n_items) - 1.0) * s * 0.56
			for j in items.size():
				_stamp(ci, Vector2(x0 + float(j) * s * 1.12, py - s * 0.40), s * 0.92, items[j], cols, serif, false, a)
			if side == 1 and int(pn[2]) > 0:
				# the brass weight, engraved, its kilos on it
				var wc: Vector2 = Vector2(x0 + float(items.size()) * s * 1.12, py - s * 0.36)
				var ws: float = s * 1.12
				var wp: PackedVector2Array = PackedVector2Array([
					wc + Vector2(-ws * 0.5, ws * 0.40), wc + Vector2(ws * 0.5, ws * 0.40),
					wc + Vector2(ws * 0.32, -ws * 0.36), wc + Vector2(-ws * 0.32, -ws * 0.36)])
				ci.draw_colored_polygon(wp, Color(BRASS, 0.85 * a))
				wp.append(wp[0])
				ci.draw_polyline(wp, ink, 1.2)
				ci.draw_arc(wc + Vector2(0, -ws * 0.46), ws * 0.13, PI, TAU, 10, ink, 1.4)
				var kt: String = str(int(pn[2]))
				var kfs: int = int(ws * 0.66)
				var kw: float = serif.get_string_size(kt, HORIZONTAL_ALIGNMENT_LEFT, -1, kfs).x
				ci.draw_string(serif, wc + Vector2(-kw * 0.5, ws * 0.28), kt, HORIZONTAL_ALIGNMENT_LEFT, -1, kfs, Color(INK, a))
	if show_rule:
		draw_rule(ci, Rect2(lr.position.x + 8.0, pic.end.y + 2.0, lr.size.x - 16.0, rule_h), cl, cols, serif, a)
	# WEIGHED: a rubber stamp across a clue whose crates are all known
	if state == 3:
		ci.draw_set_transform(ctr, deg_to_rad(tilt_deg - 12.0), Vector2.ONE)
		var st: String = "WEIGHED"
		var sfs: int = int(lr.size.y * 0.20)
		var sw: float = serif.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
		var sr: Rect2 = Rect2(-sw * 0.5 - 8.0, -sfs * 0.62 - 6.0, sw + 16.0, sfs + 12.0)
		var red: Color = Color(0.68, 0.16, 0.14, 0.62)
		ci.draw_rect(sr, red, false, 2.5)
		ci.draw_rect(sr.grow(-4.0), Color(red, 0.4), false, 1.0)
		ci.draw_string(serif, Vector2(-sw * 0.5, sfs * 0.36), st, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, red)
		ci.draw_set_transform(ctr, deg_to_rad(tilt_deg), Vector2.ONE)
	# the set-aside check, in the corner: an inked box
	if aside_btn.size.x > 0.0 and state != 3:
		var bc: Vector2 = aside_btn.get_center() - ctr
		var br: float = aside_btn.size.x * 0.30
		var box: Rect2 = Rect2(bc - Vector2(br, br), Vector2(br, br) * 2.0)
		ci.draw_rect(box, Color(INK, 0.06 if state != 2 else 0.20))
		ci.draw_rect(box, Color(INK, 0.55 * a), false, 1.4)
		if state == 2:
			ci.draw_polyline(PackedVector2Array([bc + Vector2(-br * 0.6, 0.0), bc + Vector2(-br * 0.1, br * 0.55),
				bc + Vector2(br * 0.8, -br * 0.8)]), Color(0.68, 0.16, 0.14, 0.9), 2.2)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# THE RULE, WRITTEN OUT (when the menu's switch is on): the same colored crate stamps as the engraving, and
# the math between them in large type -- "Red C" in words took the room the signs needed.
static func rule_tokens(cl: Dictionary) -> Array:
	var c: Array = cl["c"]
	match int(cl["t"]):
		PUZZLE.T.EQUAL:
			return [["box", c[0]], ["sign", "="], ["box", c[1]]]
		PUZZLE.T.OFFSET:
			return [["box", c[0]], ["sign", "="], ["box", c[1]], ["sign", "+"], ["kg", int(cl["k"])]]
		PUZZLE.T.SUM_EQ:
			return [["box", c[0]], ["sign", "+"], ["box", c[1]], ["sign", "="], ["box", c[2]]]
		PUZZLE.T.SUM_LIGHTER:
			return [["box", c[0]], ["sign", "+"], ["box", c[1]], ["sign", "<"], ["box", c[2]]]
		PUZZLE.T.PAIRS_EQ:
			return [["box", c[0]], ["sign", "+"], ["box", c[1]], ["sign", "="], ["box", c[2]], ["sign", "+"], ["box", c[3]]]
		PUZZLE.T.BETWEEN:
			return [["box", c[0]], ["word", "between"], ["box", c[1]], ["word", "&"], ["box", c[2]]]
		PUZZLE.T.HEAVIER:
			return [["box", c[0]], ["sign", ">"], ["box", c[1]]]
		PUZZLE.T.SUM_HEAVIER:
			return [["box", c[0]], ["sign", "+"], ["box", c[1]], ["sign", ">"], ["box", c[2]]]
	return []

static func draw_rule(ci: CanvasItem, area: Rect2, cl: Dictionary, cols: int, serif: Font, a: float) -> void:
	var toks: Array = rule_tokens(cl)
	var b: float = area.size.y * 0.80
	var widths: Array = []
	var total: float = 0.0
	# fit: shrink everything together until the row fits the paper
	for _try in 12:
		widths.clear()
		total = 0.0
		var fs: int = int(b * 0.95)
		for t in toks:
			var w: float = b
			if t[0] == "sign":
				w = serif.get_string_size(str(t[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			elif t[0] == "word":
				w = serif.get_string_size(str(t[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.62)).x
			elif t[0] == "kg":
				w = b * 0.95
			widths.append(w)
			total += w
		total += b * 0.22 * float(toks.size() - 1)
		if total <= area.size.x:
			break
		b *= 0.92
	var x: float = area.get_center().x - total * 0.5
	var cy: float = area.get_center().y
	var fs2: int = int(b * 0.95)
	for k in toks.size():
		var t: Array = toks[k]
		var w2: float = widths[k]
		if t[0] == "box":
			_stamp(ci, Vector2(x + w2 * 0.5, cy), b, int(t[1]), cols, serif, false, a)
		elif t[0] == "sign":
			ci.draw_string(serif, Vector2(x, cy + fs2 * 0.34), str(t[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(INK, 0.95 * a))
		elif t[0] == "word":
			ci.draw_string(serif, Vector2(x, cy + fs2 * 0.22), str(t[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs2 * 0.62), Color(INK, 0.85 * a))
		elif t[0] == "kg":
			var wc: Vector2 = Vector2(x + w2 * 0.5, cy)
			var ws: float = b * 0.95
			var wp: PackedVector2Array = PackedVector2Array([
				wc + Vector2(-ws * 0.5, ws * 0.42), wc + Vector2(ws * 0.5, ws * 0.42),
				wc + Vector2(ws * 0.32, -ws * 0.36), wc + Vector2(-ws * 0.32, -ws * 0.36)])
			ci.draw_colored_polygon(wp, Color(BRASS, 0.9 * a))
			wp.append(wp[0])
			ci.draw_polyline(wp, Color(INK, 0.9 * a), 1.4)
			var kt: String = str(int(t[1]))
			var kfs: int = int(ws * 0.66)
			var kw: float = serif.get_string_size(kt, HORIZONTAL_ALIGNMENT_LEFT, -1, kfs).x
			ci.draw_string(serif, wc + Vector2(-kw * 0.5, ws * 0.30), kt, HORIZONTAL_ALIGNMENT_LEFT, -1, kfs, Color(INK, a))
		x += w2 + b * 0.22

extends Control
class_name DirectionRose

# Accuracy by WHERE on the screen it happened, drawn where it happened.
#
# The three games that flash something off to one side — Pinpoint, Witness, Glimpse — ask the
# same question of every direction, so a person has no reason to be better at one than another.
# A list of eight percentages makes that comparison hard work; a 3x3 laid out like the screen
# makes a weak corner obvious at a glance. It is a CARTOON of the screen, not a picture of it:
# the cells say which direction they stand for and nothing more.
#
# Each game hands over a `slot` (row * 3 + column, 4 being the centre) and a `dir_name`, so this
# knows nothing about any game's own index order — the same arrangement as the rule games handing
# over a rule name rather than a key.

# A direction is flagged when its accuracy is further from the player's own overall accuracy than
# chance explains. Under "direction makes no difference" the hits in one direction are binomial
# with the overall rate, so the deviation is measured in its own standard errors.
#
# 2.5 rather than the 2.0 the baseline band uses, because this is EIGHT tests at once and the
# baseline is one. At 2.0 per direction, the chance of at least one false flag across 8 is about
# 1 - 0.9545^8 = 31%, which would mark a healthy player most sessions. At 2.5 it is about
# 1 - 0.9876^8 = 9.5%, and a real lopsidedness clears it easily. Nominal figures: the directions
# are not quite independent, since they share the overall rate they are measured against.
const FLAG_SD: float = 2.5
# Below this a direction has not been asked often enough for a proportion to mean anything.
const MIN_PER_DIR: int = 8
const MIN_TOTAL: int = 40

const PAD: float = 4.0
const NAME_PT: int = 11
const PCT_PT: int = 20
const N_PT: int = 10

# slot -> {"name": String, "right": int, "n": int}
var cells: Dictionary = {}
var overall_pct: float = 0.0
var flagged: Dictionary = {}      # slot -> true

func set_directions(by_slot: Dictionary) -> void:
	cells = by_slot
	var right: int = 0
	var total: int = 0
	for k in cells:
		right += int(cells[k]["right"])
		total += int(cells[k]["n"])
	overall_pct = 100.0 * float(right) / float(maxi(total, 1))
	flagged = {}
	if total >= MIN_TOTAL:
		var p: float = float(right) / float(maxi(total, 1))
		for k in cells:
			var n: int = int(cells[k]["n"])
			if n < MIN_PER_DIR:
				continue
			var se: float = sqrt(maxf(p * (1.0 - p), 0.0001) * float(n))
			if absf(float(cells[k]["right"]) - p * float(n)) >= FLAG_SD * se:
				flagged[k] = true
	queue_redraw()

# Which directions stood out, and which way, in words. Empty when none did.
func imbalance_note() -> String:
	if flagged.is_empty():
		return ""
	var weak: Array = []
	var strong: Array = []
	for k in flagged:
		var pct: float = 100.0 * float(cells[k]["right"]) / float(maxi(int(cells[k]["n"]), 1))
		if pct < overall_pct:
			weak.append(str(cells[k]["name"]).to_lower())
		else:
			strong.append(str(cells[k]["name"]).to_lower())
	var parts: Array = []
	if not weak.is_empty():
		parts.append("further off %s than anywhere else" % " and ".join(weak))
	if not strong.is_empty():
		parts.append("better %s" % " and ".join(strong))
	return "Marked: you are " + ", and ".join(parts) + "."

func _draw() -> void:
	if cells.is_empty():
		return
	var font: Font = MainGlobals.get_text_font()
	var name_pt: int = MainGlobals.ui_font_size(NAME_PT)
	var pct_pt: int = MainGlobals.ui_font_size(PCT_PT)
	var n_pt: int = MainGlobals.ui_font_size(N_PT)
	var side: float = minf(size.x, size.y)
	var cw: float = side / 3.0
	var ox: float = (size.x - side) * 0.5

	for slot in 9:
		var col: int = slot % 3
		var row: int = slot / 3
		var r: Rect2 = Rect2(ox + float(col) * cw + PAD, float(row) * cw + PAD,
			cw - PAD * 2.0, cw - PAD * 2.0)
		if not cells.has(slot):
			# An empty slot is drawn faintly rather than left blank: the 3x3 has to read as a
			# compass even when a game only uses four of its points.
			draw_rect(r, Color(1, 1, 1, 0.035), true)
			continue
		var e: Dictionary = cells[slot]
		var n: int = int(e["n"])
		var pct: float = 100.0 * float(e["right"]) / float(maxi(n, 1))
		# Green where the player is doing well, red where they are not, on their OWN scale: the
		# question is whether one direction is unlike the others, not whether 70% is good.
		var t: float = clampf((pct - (overall_pct - 25.0)) / 50.0, 0.0, 1.0)
		draw_rect(r, ScreenBackdrop.STATS_HOT.lerp(ScreenBackdrop.STATS_STEADY, t).darkened(0.45),
			true)
		if flagged.has(slot):
			draw_rect(r, ScreenBackdrop.STATS_MARK, false, 3.0)

		var nm: String = str(e["name"])
		var ns: Vector2 = font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, name_pt)
		draw_string(font, Vector2(r.position.x + (r.size.x - ns.x) * 0.5,
			r.position.y + ns.y + 2.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, name_pt,
			Color(0.82, 0.85, 0.90, 1.0))

		var pt: String = "%d%%" % int(round(pct))
		var ps: Vector2 = font.get_string_size(pt, HORIZONTAL_ALIGNMENT_LEFT, -1, pct_pt)
		draw_string(font, Vector2(r.position.x + (r.size.x - ps.x) * 0.5,
			r.position.y + r.size.y * 0.60), pt, HORIZONTAL_ALIGNMENT_LEFT, -1, pct_pt,
			Color(1, 1, 1, 0.95))

		var cnt: String = "%d round%s" % [n, "" if n == 1 else "s"]
		var cs: Vector2 = font.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, n_pt)
		draw_string(font, Vector2(r.position.x + (r.size.x - cs.x) * 0.5,
			r.position.y + r.size.y - 4.0), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, n_pt,
			Color(0.72, 0.74, 0.78, 1.0))

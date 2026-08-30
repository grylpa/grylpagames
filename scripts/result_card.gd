extends RefCounted
class_name ResultCard

# The card behind BOTH end-of-thing dialogs: the level summary (`scripts/level_done_popup.gd`) and
# the between-rounds / pre-level popup (`scripts/game_popup.gd`).
#
# They were two copies of one scene — the same tree, the same script, the same 60px translucent
# border, both tiled with a GRASS texture out of a game's own art folder (matchws/art/, for the
# game most likely to be cut). A player sees them back to back: finish a level, read the summary,
# and the next dialog has to look like it belongs to the same app. Two copies guarantee it stops
# being true the moment one of them is touched, which is exactly what happened.
#
# Everything is built in code because the body is free text whose SHAPE varies per game, and the
# rows have to be created from whatever arrives.
#
# Body conventions, for anyone writing one of these strings:
#   "Label: value"  a FACT. Consecutive facts become one table — as wide as its widest row, no
#                   wider, centered, labels left and values right, a hairline between each pair.
#                   A blank line between two facts is ignored, so `text` + `text_add` still make
#                   one table. COL_GAP sets the space between the two columns.
#   anything else   prose. It wraps to the card, so write sentences and do not hand-break lines.
#                   Keep colons out of a sentence (see stat_split).

const ACCENT: Color = Color(0.976, 0.792, 0.353)   # an outcome: a level summary, a round won
const BRIEF: Color = Color(0.478, 0.749, 0.902)    # a briefing: what THIS level is about to be
const ALERT: Color = Color(0.949, 0.478, 0.353)    # a round lost
const HEADER_INK: Color = Color(0.153, 0.118, 0.043)
const CARD_BG: Color = Color(0.098, 0.118, 0.176, 0.99)
const CARD_EDGE: Color = Color(1.0, 1.0, 1.0, 0.10)
const TEXT: Color = Color(0.929, 0.941, 0.969)
const MUTED: Color = Color(0.929, 0.941, 0.969, 0.60)
const RULE: Color = Color(1.0, 1.0, 1.0, 0.07)
# Clear air between a label and its number. The table is sized from its widest row, so this gap IS
# the table's breathing room — there is no slack anywhere else to provide it.
const COL_GAP: int = 44
const COL_GAP_DESKTOP: int = 34

# Type sizes, phone first. The old dialogs these replaced set 40 for a title and 60 for a button on
# mobile; the first version of this card used 34 and 30, which is a step DOWN on the device where
# the text is furthest from your eyes and the target is a thumb. Every size here is one place, so
# the whole family moves together.
const TITLE_SIZE: int = 46
const TITLE_SIZE_DESKTOP: int = 27
const PROSE_SIZE: int = 32
const PROSE_SIZE_DESKTOP: int = 20
const LABEL_SIZE: int = 30
const LABEL_SIZE_DESKTOP: int = 20
const VALUE_SIZE: int = 32
const VALUE_SIZE_DESKTOP: int = 22
const BUTTON_SIZE: int = 46
const BUTTON_SIZE_DESKTOP: int = 23

# A briefing ("Level 3"), a congratulation ("Well done!") and a loss ("Oh no!") arrive through the
# same call and used to look identical — same gold, same word on the button. They are three
# different moments: one says what is ABOUT to happen, two say what just did.
#
# The tone is read off the title because the title is all the ~10 callers pass, and across the
# whole project it is only ever one of two shapes: "Level %d" for a briefing, or an outcome
# ("Well done!", "Oh no!", "Time's up!"). Anything unrecognized is treated as a briefing, which is
# the safe end: a neutral panel and a "Start" button in front of a level that is about to begin.
enum Tone {BRIEFING, WIN, LOSS}

const LOSS_TITLES: Array = ["oh no", "time's up", "game over", "failed"]
const WIN_TITLES: Array = ["well done", "complete", "nice", "excellent"]

static func tone_for(title: String) -> Tone:
	var low: String = title.to_lower()
	for word in LOSS_TITLES:
		if low.contains(word):
			return Tone.LOSS
	for word in WIN_TITLES:
		if low.contains(word):
			return Tone.WIN
	return Tone.BRIEFING

static func accent_for(title: String) -> Color:
	match tone_for(title):
		Tone.LOSS:
			return ALERT
		Tone.WIN:
			return ACCENT
	return BRIEF

static func has_badge(title: String) -> bool:
	return tone_for(title) == Tone.WIN

# A briefing has not happened yet, so there is nothing to continue.
static func button_for(title: String) -> String:
	return "Start" if tone_for(title) == Tone.BRIEFING else "Continue"

# Builds the whole dialog into `host` and hands back the parts the caller fills in.
static func build(host: CanvasLayer, accent: Color, badge: bool, button_text: String,
		on_close: Callable) -> Dictionary:
	var parts: Dictionary = _shell(host, accent, badge, on_close)
	parts["foot"].add_child(_button(button_text, accent, bool(parts["mobile"]), on_close))
	return parts

# A confirmation: the same card, two buttons. The SAFE choice is the filled one on the right, where
# the thumb already is; the one that loses something is a ghost button, present but not inviting.
static func build_confirm(host: CanvasLayer, ok_text: String, cancel_text: String,
		on_ok: Callable, on_cancel: Callable) -> Dictionary:
	# A tap outside means "no". Canceling is what a stray tap should do when the other option
	# throws away a game in progress.
	# OPAQUE, not a card floating over the game. This dialog is reachable mid-play, and a
	# see-through one would be a free pause: hold the board still, study it through the scrim,
	# then cancel. The old dialog was a full-screen window for exactly that reason.
	var parts: Dictionary = _shell(host, ALERT, false, on_cancel, true)
	var mob: bool = bool(parts["mobile"])
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	parts["foot"].add_child(row)
	# Cancel LEFT, confirm RIGHT — where they have always been. Muscle memory on a dialog that
	# throws away a game in progress is not something to redesign. They are told apart by weight
	# instead: the safe one is filled, the one that loses your progress is a ghost.
	var safe: Button = _button(cancel_text, ACCENT, mob, on_cancel)
	safe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(safe)
	var danger: Button = _button(ok_text, ALERT, mob, on_ok, true)
	danger.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(danger)
	return parts

static func _shell(host: CanvasLayer, accent: Color, badge: bool, on_close: Callable,
		opaque: bool = false) -> Dictionary:
	var mob: bool = MainGlobals.is_mobile()
	# Wider on a phone. The card was capped at 560 on a 680 screen, which left 120px of scrim doing
	# nothing while two buttons fought over the room inside it.
	var card_w: float = minf(620.0, float(MainGlobals.screen_size.x) * 0.92) if mob \
		else minf(560.0, float(MainGlobals.screen_size.x) * 0.88)

	var scrim: ColorRect = ColorRect.new()
	scrim.color = Color(0.043, 0.055, 0.086, 1.0) if opaque else Color(0.0, 0.0, 0.0, 0.62)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
				or (event is InputEventScreenTouch and event.pressed):
			on_close.call()
			host.get_viewport().set_input_as_handled())
	host.add_child(scrim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	card.custom_minimum_size = Vector2(card_w, 0.0)
	# The card swallows its own taps, so only a tap OUTSIDE it (or the button) dismisses — a
	# mis-tap while reading the numbers used to close the screen the player was reading.
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	card.add_child(col)

	var title_label: Label = _header(col, accent, badge, card_w, mob)

	var body: MarginContainer = MarginContainer.new()
	body.add_theme_constant_override("margin_left", 26 if mob else 22)
	body.add_theme_constant_override("margin_right", 26 if mob else 22)
	body.add_theme_constant_override("margin_top", 22)
	body.add_theme_constant_override("margin_bottom", 8)
	col.add_child(body)

	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	body.add_child(rows)

	var foot: MarginContainer = MarginContainer.new()
	foot.add_theme_constant_override("margin_left", 22)
	foot.add_theme_constant_override("margin_right", 22)
	foot.add_theme_constant_override("margin_top", 14)
	foot.add_theme_constant_override("margin_bottom", 22)
	col.add_child(foot)

	return {"title": title_label, "rows": rows, "card": card, "foot": foot,
		"width": card_w, "mobile": mob}

static func _card_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = CARD_BG
	sb.set_corner_radius_all(24)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = CARD_EDGE
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.shadow_size = 26
	sb.shadow_offset = Vector2(0.0, 10.0)
	return sb

static func _header(parent: Control, accent: Color, badge: bool, card_w: float, mob: bool) -> Label:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = accent
	sb.corner_radius_top_left = 22
	sb.corner_radius_top_right = 22
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)

	var d: float = 0.0
	if badge:
		# A DRAWN check, not a "✓" glyph: the prose font has no U+2713, so whether one appeared at
		# all came down to what symbol font the device happened to fall back on.
		d = 38.0 if mob else 32.0
		var mark: Control = Control.new()
		mark.custom_minimum_size = Vector2(d, d)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.draw.connect(func() -> void:
			var c: Vector2 = Vector2(d, d) * 0.5
			mark.draw_circle(c, d * 0.5, Color(HEADER_INK.r, HEADER_INK.g, HEADER_INK.b, 0.92))
			var w: float = d * 0.13
			mark.draw_line(c + Vector2(-d * 0.22, 0.0), c + Vector2(-d * 0.05, d * 0.17), accent, w, true)
			mark.draw_line(c + Vector2(-d * 0.05, d * 0.17), c + Vector2(d * 0.24, -d * 0.20), accent, w, true))
		row.add_child(mark)

	var title_label: Label = Label.new()
	title_label.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(title_label, TITLE_SIZE_DESKTOP)
	title_label.add_theme_color_override("font_color", HEADER_INK)
	# An autowrapping Label with nothing constraining its width wraps at effectively ZERO — one
	# character per line — and then reports THAT as its minimum height. This header measured 669px
	# tall for "Level 3 complete!" until the wrap width was pinned. Autowrap still has to be on, or
	# a long title reports its full width as a minimum and pushes the card off the screen.
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.custom_minimum_size = Vector2(card_w - d - 96.0, 0.0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)
	return title_label

static func _button(label: String, accent: Color, mob: bool, on_close: Callable,
		ghost: bool = false) -> Button:
	var btn: Button = Button.new()
	btn.text = label
	btn.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(btn, BUTTON_SIZE_DESKTOP)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(state, accent if ghost else HEADER_INK)
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = accent
		if ghost:
			sb.bg_color = Color(accent.r, accent.g, accent.b, 0.10 if state == "pressed" else 0.0)
			sb.border_width_left = 2
			sb.border_width_top = 2
			sb.border_width_right = 2
			sb.border_width_bottom = 2
			sb.border_color = Color(accent.r, accent.g, accent.b, 0.75)
		elif state == "pressed":
			sb.bg_color = accent.darkened(0.16)
		elif state == "hover":
			sb.bg_color = accent.lightened(0.10)
		sb.set_corner_radius_all(16)
		sb.content_margin_top = 14.0
		sb.content_margin_bottom = 14.0
		sb.content_margin_left = 18.0 if mob else 26.0
		sb.content_margin_right = 18.0 if mob else 26.0
		btn.add_theme_stylebox_override(state, sb)
	btn.pressed.connect(func() -> void: on_close.call())
	return btn

# --- body -----------------------------------------------------------------------------------

# The body arrives as one free-text block, and across the games it is consistently two kinds of
# line: "Label: value" facts, and whole sentences. Splitting them means the numbers can be set as a
# table — label left, value right, hairline between — instead of a centered wall of text where
# "Total score: 240" and "Accuracy: 80%" line up with nothing.
# "Label: value" is how a caller sends a FACT, and the card sets those as a table. Prose is
# everything else — but prose has colons in it too, and a sentence like
# "NOW BOARDING: the ringed alien must be dealt with..." silently became a row with half a sentence
# in the value column. A fact is recognizable: a short label, a short value, and a label that is
# not SHOUTING, since all-caps is how these games mark an instruction and never how they label a
# number. Returns [] when the line is prose.
static func stat_split(line: String) -> Array:
	var sep: int = line.find(": ")
	if sep <= 0 or sep >= line.length() - 2:
		return []
	var label: String = line.substr(0, sep)
	var value: String = line.substr(sep + 2)
	if label.length() > 24 or value.length() > 34:
		return []
	if label.length() > 3 and label == label.to_upper():
		return []
	return [label, value]

static func set_body(parts: Dictionary, text: String, accent: Color) -> void:
	var rows: VBoxContainer = parts["rows"]
	if rows == null or not is_instance_valid(rows):
		return
	for child in rows.get_children():
		child.queue_free()
	var mob: bool = bool(parts["mobile"])
	var card_w: float = float(parts["width"])
	var blank_run: bool = false
	# Consecutive facts are collected and laid out as ONE table, so the table can be exactly as
	# wide as its widest row instead of as wide as the card.
	var pending: Array = []
	for raw in text.strip_edges().split("\n"):
		var line: String = raw.strip_edges()
		if line == "":
			blank_run = true
			continue
		var stat: Array = stat_split(line)
		if not stat.is_empty():
			# A blank line BETWEEN TWO FACTS is ignored. The body is assembled as `text` +
			# `text_add` by the caller, so "Total score / Time left" and "Accuracy / Mean time"
			# arrive with a blank line between them purely because they were concatenated — and
			# that split the table in half: one gap wider than the rest, with no hairline across
			# it. Facts are one table however they were pasted together. A blank line BEFORE the
			# table still means what it says.
			if pending.is_empty() and blank_run and rows.get_child_count() > 0:
				_add_gap(rows)
			pending.append(stat)
			blank_run = false
			continue
		_flush_table(rows, pending, mob)
		if blank_run and rows.get_child_count() > 0:
			_add_gap(rows)
		blank_run = false
		_add_prose(rows, line, accent, card_w, mob)
	_flush_table(rows, pending, mob)

static func _add_gap(rows: VBoxContainer) -> void:
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, 10.0)
	rows.add_child(gap)

# One table, centered, no wider than it has to be. Left in a full-width column the labels sat
# against one edge of the card and the values against the other, with a lake of empty space between
# a word and its number — and the hairlines spanned the whole card, so they read as dividers across
# the dialog rather than as part of a table.
#
# The CenterContainer takes the VBox's minimum width, which is the widest row's (label + 16 +
# value). Every row then fills that width, so the labels line up on the left, the values line up on
# the right, and each hairline is exactly as wide as the table it belongs to.
static func _flush_table(rows: VBoxContainer, pending: Array, mob: bool) -> void:
	if pending.is_empty():
		return
	var holder: CenterContainer = CenterContainer.new()
	var table: VBoxContainer = VBoxContainer.new()
	table.add_theme_constant_override("separation", 2)
	holder.add_child(table)
	rows.add_child(holder)
	var cells: Array = []
	for i in pending.size():
		if i > 0:
			var rule: ColorRect = ColorRect.new()
			rule.color = RULE
			rule.custom_minimum_size = Vector2(0.0, 1.0)
			table.add_child(rule)
		cells.append(_add_stat(table, pending[i][0], pending[i][1], mob))
	_align_columns(cells)
	pending.clear()

# Two COLUMNS, not two rows of independently sized text. Each row was laying itself out on its own:
# the label took whatever slack was left after its own value, so the boundary between the columns
# moved from row to row, and a long value like "50% (need 60%)" began over the word "response" in
# the row below it. That is a pair of lines, not a table.
#
# Both columns are therefore sized once, from the widest cell in each, and every row uses those
# widths — labels flush left down one edge, values flush right down the other, and the gap between
# the columns is the same on every line.
static func _align_columns(cells: Array) -> void:
	if cells.is_empty():
		return
	var label_w: float = 0.0
	var value_w: float = 0.0
	for pair in cells:
		label_w = maxf(label_w, (pair[0] as Label).get_combined_minimum_size().x)
		value_w = maxf(value_w, (pair[1] as Label).get_combined_minimum_size().x)
	for pair in cells:
		(pair[0] as Label).custom_minimum_size = Vector2(label_w, 0.0)
		(pair[1] as Label).custom_minimum_size = Vector2(value_w, 0.0)

# Returns [label, value] so the caller can size the two columns once all the rows are known.
static func _add_stat(table: VBoxContainer, label_text: String, value_text: String, mob: bool) -> Array:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", COL_GAP if mob else COL_GAP_DESKTOP)
	var lab: Label = Label.new()
	lab.text = label_text
	lab.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(lab, LABEL_SIZE_DESKTOP)
	lab.add_theme_color_override("font_color", MUTED)
	# FILL, not EXPAND: the column widths are set by _align_columns once every row is known, and an
	# expanding label would hand each row's leftover space back to itself and break the alignment.
	lab.size_flags_horizontal = Control.SIZE_FILL
	row.add_child(lab)
	var val: Label = Label.new()
	val.text = value_text
	val.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(val, VALUE_SIZE_DESKTOP)
	val.add_theme_color_override("font_color", TEXT)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.size_flags_horizontal = Control.SIZE_FILL
	row.add_child(val)
	table.add_child(row)
	return [lab, val]

static func _add_prose(rows: VBoxContainer, line: String, accent: Color, card_w: float, _mob: bool) -> void:
	var lab: Label = Label.new()
	lab.text = line
	lab.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(lab, PROSE_SIZE_DESKTOP)
	lab.add_theme_color_override("font_color", accent if line.ends_with("!") else TEXT)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.custom_minimum_size = Vector2(card_w - 56.0, 0.0)
	rows.add_child(lab)

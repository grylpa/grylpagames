extends RefCounted
class_name GameInstrument

# The per-game panel: the one measurement a game is uniquely placed to make.
#
# This turns a game's per-trial log into a control ready to be shown. It is deliberately separate
# from the scores window, so adding an instrument to a game does not mean editing a shared screen,
# and a game with nothing special simply has no entry here.
#
# THE TAB EXISTS FOR EVERY GAME, and always shows something:
#
#   1. the four games below get their own picture, drawn from the per-trial log
#   2. a game that asks a yes/no question gets its four cells as a 2x2
#   3. anything else gets a plain readout of the numbers that game keeps
#   4. and where there is not yet enough, it says what is still needed and how much
#
# A tab that appears and disappears tells the player nothing, and leaves them no way to learn the
# view exists at all.

# The games whose own measurement IS a chart. These are shown as an extra metric in the Charts tab,
# beside score / time / accuracy — a chart belongs with the charts, and a separate tab holding one
# picture is a distinction the player would have to learn for no reason.
const CHART_GAMES: Dictionary = {
	"dino": "Recall",
	"weris": "Search",
	"gorilla": "Counting",
}

# Polka Dots is the exception, and deliberately: a confusion matrix is a table, not a plot. It has
# no shared axis with score or time and would make no sense sitting beside them, so it lives in the
# Summary tab with the rest of what a game says about itself.

# SUFFICIENCY, and it is not the same thing as variety.
#
# An earlier version asked only for two distinct buckets, which one session could satisfy with a
# dozen trials — and would then draw a confident-looking curve out of noise. That is exactly the
# failure the plan's own pitfalls warn about, so these floors match the rest of the system: the
# baseline skips warm-up sessions and ignores thin ones, and so does this.
const MIN_SESSIONS: int = 3        # separate sittings that contributed trials
const MIN_PER_BUCKET: int = 4      # samples before a bucket is worth averaging
const MIN_BUCKETS: int = 2         # points needed to have a shape at all
# A confusion matrix is a table, not a fit, so it needs characters rather than buckets.
const MIN_CHARS: int = 2
const MAX_MATRIX_ROWS: int = 12

# A game's OWN VIEW: the one picture it is uniquely placed to draw. It occupies a single extra
# metric slot in the Charts tab, whether it happens to be a curve or a table.
#
#   dino / weris / gorilla   a curve      (accuracy against lag, time against crowd, error vs load)
#   polkadots                a 2x2        (right and wrong with the options up, and from memory)
#   the other yes/no games   a 2x2        (said yes / said no against was yes / was no)
#
# All of them are PICTURES, so all of them belong with the charts. The Summary tab is words and
# numbers — a verdict, a difficulty note, a readout — and mixing a picture into it produced exactly
# the "these two things are unrelated" problem twice over.
const YES_NO_GAMES: Array = ["aliens", "sortingrobots", "dino", "dinoback", "friends", "whack"]

static func has_chart(folder: String) -> bool:
	return CHART_GAMES.has(folder)

static func has_own_view(folder: String) -> bool:
	return has_chart(folder) or folder == "polkadots" or YES_NO_GAMES.has(folder)

# What the extra metric button says. Named after the measurement, since it sits beside "Score" and
# "Avg Time" which are also named after theirs.
static func chart_metric_name(folder: String) -> String:
	if CHART_GAMES.has(folder):
		return str(CHART_GAMES[folder])
	if folder == "polkadots":
		# Not "Letters": the view stopped being about individual characters when the confusion
		# matrix went. What it separates now is the round played with the options on screen from
		# the same round played from memory.
		return "Memory"
	if YES_NO_GAMES.has(folder):
		return "Answers"
	return "Detail"

# Friendly names for the game-specific counters, so a readout is readable rather than a dump of
# field names. Anything not listed here is simply not shown.
const METRIC_LABELS: Dictionary = {
	"leaks_appeared": "Leaks appeared", "overflows": "Overflowed",
	"creatures_stopped": "Creatures stopped", "creatures_parked": "Creatures that got through",
	"door_actions": "Door changes", "deliveries": "Delivered", "collisions": "Collisions",
	"jobs_assigned": "Jobs assigned", "jobs_cancelled": "Jobs cancelled",
	"span": "Longest order held", "rounds_right": "Rounds correct", "rounds_wrong": "Rounds wrong",
	"cycles": "Cycles completed", "no_answer": "Left unanswered",
	"rt_lapses": "Lapses", "rt_sd": "Steadiness (spread, ms)", "rt_mean": "Typical answer (ms)",
	"jumped_ahead": "Jumped ahead", "fell_back": "Fell back",
	# The breathing games and typit keep their own vocabulary, and without these their Detail tab
	# fell through to "play a session" even with a full history behind it.
	"duration_min": "Minutes practised", "mean_interval_ms": "Typical breath (ms)",
	"bpm": "Breaths per minute", "num_taps": "Breaths marked",
	"missed_breaths": "Out of rhythm", "num_reversals": "Cycles", "missed_cycles": "Out of rhythm",
	"session_ps": "Following the path (%)", "react_ms": "Reaction (ms)",
	"cycles_opened": "Safe turns", "speed_cpm": "Typing speed (cpm)",
	"mistake_rate": "Mistakes (%)", "dist_pct": "Off key centre (%)",
}

# Keys that are a RATE or a TYPICAL value, so a total across sessions would be meaningless — a
# breathing rate summed over five sittings is not a number about anything.
const AVERAGED: Array = ["rt_mean", "rt_sd", "mean_interval_ms", "bpm", "session_ps", "react_ms",
	"speed_cpm", "mistake_rate", "dist_pct", "duration_min"]

# What the tab should show: either the panel, or a plain statement of what is still missing.
# Always returns a Control for a game that has an instrument.
# The game's own view, ready to drop into the Charts tab. Null where it has none, or has not been
# played enough to draw one.
static func chart_for(folder: String) -> Control:
	if not has_own_view(folder):
		return null
	var gu: GenericGameUtil = GenericGameUtil.new(folder, folder, 0, 5, 0)
	if has_chart(folder) or folder == "polkadots":
		if gu.read_trial_blocks().size() < MIN_SESSIONS:
			return null
		return _body_for(folder)
	return _four_cells(gu)

# THE SUMMARY TAB: what this game says about how you are doing.
#
# The verdict and the difficulty note first, because they are the answer to the question people
# open this for. Then anything the game measures that is NOT a chart — a confusion matrix, the
# four-cell breakdown, a readout of its own counters. The charts live with the charts.
static func summary_for(folder: String) -> Control:
	var gu: GenericGameUtil = GenericGameUtil.new(folder, folder, 0, 5, 0)
	var all: Array = gu.read_sessions()
	var sessions: Array = StatsBaseline.for_task(all, StatsBaseline.busiest_task(all))
	var v: Dictionary = StatsBaseline.verdict(sessions)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)

	var trend: Label = Label.new()
	trend.text = str(v["trend"])
	trend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trend.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(trend, 16)
	trend.add_theme_color_override("font_color", _verdict_color(int(v["state"])))
	col.add_child(trend)

	if str(v["challenge"]) != "":
		var ch: Label = Label.new()
		ch.text = str(v["challenge"])
		ch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ch.add_theme_font_override("font", MainGlobals.get_text_font())
		MainGlobals.set_font_size(ch, 13)
		ch.add_theme_color_override("font_color", Color(0.72, 0.75, 0.80, 1.0))
		col.add_child(ch)

	# Where the game's own picture is a CHART it is not repeated here — it is a metric in the
	# Charts tab. Its headline is worth a line of prose, though, since that is the finding.
	if has_chart(folder):
		var c: Control = chart_for(folder)
		var line: String = _slope_sentence(folder, c) if c != null else ""
		if c != null:
			c.free()
		if line != "":
			var sl: Label = Label.new()
			sl.text = line
			sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			sl.add_theme_font_override("font", MainGlobals.get_text_font())
			MainGlobals.set_font_size(sl, 13)
			sl.add_theme_color_override("font_color", ScreenBackdrop.STATS_MARK)
			col.add_child(sl)
		return col

	# The counter readout is numbers, so it belongs here. Anything that draws a PICTURE — a curve,
	# a confusion matrix, a 2x2 — is a metric in the Charts tab instead.
	if not has_own_view(folder):
		var readout: Control = _summary(GenericGameUtil.new(folder, folder, 0, 5, 0))
		if readout != null:
			var rule: ColorRect = ColorRect.new()
			rule.color = Color(1, 1, 1, 0.10)
			rule.custom_minimum_size = Vector2(0, 1)
			col.add_child(rule)
			readout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(readout)
	return col

# The fitted line's headline, in words and rounded to whole units: a person's response has no
# meaningful fraction of a millisecond, and a bare number beside a chart names nothing.
static func _slope_sentence(folder: String, body: Control) -> String:
	if not (body is ChartControl):
		return ""
	var m: float = (body as ChartControl).fit_slope()
	match folder:
		"weris":
			return "Each extra face in the crowd costs you about %d ms." % int(round(absf(m)))
		"dino":
			return "Recognition falls off by about %d%% for each step further back." % int(round(absf(m)))
		"gorilla":
			return "Your miscount grows by about %.1f for each extra gorilla." % absf(m)
	return ""

static func _verdict_color(state: int) -> Color:
	match state:
		StatsBaseline.State.WATCH:
			return ScreenBackdrop.STATS_MARK
		StatsBaseline.State.IMPROVING:
			return ScreenBackdrop.STATS_STEADY
		StatsBaseline.State.STEADY:
			return Color(0.82, 0.85, 0.89, 1.0)
	return Color(0.62, 0.65, 0.70, 1.0)

static func _body_for(folder: String) -> Control:
	var gu: GenericGameUtil = GenericGameUtil.new(folder, folder, 0, 5, 0)
	if not (CHART_GAMES.has(folder) or folder == "polkadots"):
		# No bespoke instrument: the four cells where the game asks a yes/no question, and its own
		# recorded numbers otherwise.
		var four: Control = _four_cells(gu)
		if four != null:
			return four
		return _summary(gu)
	var blocks: Array = gu.read_trial_blocks()
	var sessions: int = blocks.size()
	if sessions < MIN_SESSIONS:
		return _waiting(_sessions_needed_text(MIN_SESSIONS - sessions))

	var trials: Array = gu.read_trials()
	var panel: Control = null
	match folder:
		"dino":
			panel = _lag_curve(trials)
		"weris":
			panel = _search_slope(trials)
		"polkadots":
			panel = _visibility_split(trials)
		"gorilla":
			panel = _count_load(trials)
	if panel != null:
		return panel
	# Enough sessions, but not yet the right SPREAD of them. Say which, in the game's own terms.
	return _waiting(_variety_needed_text(folder))

static func _sessions_needed_text(n: int) -> String:
	if n == 1:
		return "One more session and this will start to fill in."
	return "%d more sessions and this will start to fill in." % n

# Why a game with enough sessions still cannot draw. Each of these is a real property of the game,
# not a generic "keep playing".
static func _variety_needed_text(folder: String) -> String:
	match folder:
		"dino":
			return ("This compares how well you recognise a card against how long ago you saw it,\n"
				+ "so it needs more rounds where cards come back after different gaps.")
		"weris":
			return ("This compares how long you take against how big the crowd is, so it needs\n"
				+ "rounds at more than one crowd size — the crowd grows as you reach new levels.")
		"polkadots":
			return ("This compares how you do with the options on screen against from memory,\n"
				+ "so it needs a few more rounds of each.")
		"gorilla":
			return ("This compares your count against how many actually went past, so it needs\n"
				+ "rounds with different numbers of gorillas.")
	return "Not enough yet."

static func _waiting(text: String) -> Control:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(lbl, 15)
	lbl.add_theme_color_override("font_color", Color(0.62, 0.65, 0.70, 1.0))
	return lbl


# A bucket chart, built on the SAME control the Chart tab uses.
#
# There was briefly a second chart class for these panels. It was a mistake: it had no gridlines and
# no axis titles, so a point at "12" told the reader nothing, and it looked like a different app.
# ChartControl already draws a grid, labels both axes and knows how to plot a numeric x — it only
# needed the axis titles and the fitted line, which every one of these panels wants anyway.
static func _bucket_chart(buckets: Dictionary, x_title: String, y_title: String,
		as_pct: bool) -> Control:
	var keys: Array = buckets.keys()
	keys.sort()
	var pts: Array = []
	for k in keys:
		pts.append(Vector2(float(k), SessionStats.mean(buckets[k])))
	var c: ChartControl = ChartControl.new()
	# "measured", not the y-axis title again: in a legend beside "trend" what matters is which line
	# is the data and which is the fit.
	c.set_series([{"label": "measured", "color": ChartControl.SERIES_COLORS[1], "points": pts}])
	c.x_as_index = true          # the x is a count, not a date
	c.x_title = x_title
	c.y_title = y_title
	c.fit_line = true
	if as_pct:
		c.y_max_override = 100.0
		c.y_integer_only = true
	else:
		c.y_min_padding = 0.12
		# A human response has no meaningful fraction of a millisecond; the decimals were noise.
		c.y_integer_only = true
	return c

# Drop buckets too thin to average, then require enough of them to have a shape.
static func _usable(buckets: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in buckets.keys():
		if buckets[k].size() >= MIN_PER_BUCKET:
			out[k] = buckets[k]
	return out

# DINO — accuracy against how long ago the card was seen. The shape of forgetting, which no single
# percentage can carry. Only repeats have a lag; first showings are excluded rather than counted as
# lag zero, which would flatten the near end of the curve.
static func _lag_curve(trials: Array) -> Control:
	var buckets: Dictionary = {}
	for t in trials:
		if not (t is Dictionary) or not bool(t.get("seen", false)):
			continue
		var lag: int = int(t.get("lag", -1))
		if lag <= 0:
			continue
		var b: int = 1 if lag <= 2 else (3 if lag <= 5 else (6 if lag <= 10 else 11))
		if not buckets.has(b):
			buckets[b] = []
		buckets[b].append(100.0 if bool(t.get("right", false)) else 0.0)
	var use: Dictionary = _usable(buckets)
	if use.size() < MIN_BUCKETS:
		return null
	return _bucket_chart(use, "cards ago", "% remembered", true)

# WERIS — find time against crowd size. The slope is the cost of each extra face, steadier session
# to session than raw speed.
static func _search_slope(trials: Array) -> Control:
	var buckets: Dictionary = {}
	for t in trials:
		if not (t is Dictionary) or not bool(t.get("right", false)):
			continue    # a wrong or timed-out find says nothing about search time
		var crowd: int = int(t.get("crowd", 0))
		var ms: int = int(t.get("ms", 0))
		if crowd <= 0 or ms <= 0:
			continue
		if not buckets.has(crowd):
			buckets[crowd] = []
		buckets[crowd].append(float(ms))
	var use: Dictionary = _usable(buckets)
	if use.size() < MIN_BUCKETS:
		return null
	return _bucket_chart(use, "faces in the crowd", "time to find (ms)", false)

# POLKA DOTS — right and wrong with the options on screen, against from memory.
#
# THIS REPLACED A CONFUSION MATRIX, which could not work here for two reasons:
#
#   1. The game PREVENTS the confusions it would have shown. _build_options() excludes the correct
#      character's whole confusable group from the wrong answers, so when "O" is the answer neither
#      "0" nor "Q" is ever offered. The interesting mix-ups cannot occur.
#   2. There is nowhere near enough data. 36 characters against 10-12 rounds a session and five
#      sessions kept is under two showings per character, for a 36x36 grid of 1296 cells.
#
# The visible/hidden split has both. It is two buckets rather than 1296, so every cell fills; and it
# separates a perceptual task from the same task with a memory load on top, which is a real
# difference the game creates deliberately.
static func _visibility_split(trials: Array) -> Control:
	var counts: Dictionary = {
		Vector2i(0, 0): 0, Vector2i(1, 0): 0,   # options shown: right, wrong
		Vector2i(0, 1): 0, Vector2i(1, 1): 0,   # from memory:   right, wrong
	}
	var seen: int = 0
	for t in trials:
		if not (t is Dictionary):
			continue
		var shown: String = str(t.get("shown", ""))
		var chose: String = str(t.get("chose", ""))
		if shown == "" or chose == "":
			continue
		seen += 1
		var row: int = 1 if bool(t.get("hidden", false)) else 0
		var col: int = 0 if shown == chose else 1
		counts[Vector2i(col, row)] = int(counts[Vector2i(col, row)]) + 1
	if seen < MIN_PER_BUCKET * 2:
		return null
	var m: MatrixControl = MatrixControl.new()
	# The diagonal is not "correct" in this table, so its cool colouring would mislead.
	m.cool_diagonal = false
	# NOT "Options shown" / "From memory", which said nothing about what the player saw. The
	# characters on the option buttons are what disappears; the buttons stay, showing their
	# numbers. Naming the thing that changes on screen is what makes the two rows readable.
	m.set_matrix(["Choices on screen", "Choices hidden"], ["Right", "Wrong"], counts)
	return _captioned(m,
		"On the harder levels the characters on the option buttons disappear part-way through "
		+ "the round, leaving only their numbers, so the same puzzle has to be answered from "
		+ "memory. This splits your answers by which kind of round it was.")

# A picture plus the one line that says what it is. Four numbers in a 2x2 are not self-explanatory,
# and the reader who has to guess the rows guesses wrong.
static func _captioned(body: Control, text: String) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(lbl, 13)
	lbl.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78, 1.0))
	box.add_child(lbl)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	return box

# GORILLA — count error against how many actually went past, which shows whether accuracy falls
# away as the load grows.
static func _count_load(trials: Array) -> Control:
	var buckets: Dictionary = {}
	for t in trials:
		if not (t is Dictionary):
			continue
		var tc: int = int(t.get("true_count", -1))
		if tc < 0:
			continue
		if not buckets.has(tc):
			buckets[tc] = []
		buckets[tc].append(absf(float(t.get("signed_err", 0))))
	var use: Dictionary = _usable(buckets)
	if use.size() < MIN_BUCKETS:
		return null
	return _bucket_chart(use, "gorillas that went past", "miscount", false)


# THE FOUR CELLS, for the six games that ask a yes/no question. Drawn as a 2x2 so the shape of a
# player's answers is visible at once: a column that has grown means they are saying yes more often,
# which a percentage would have hidden entirely.
static func _four_cells(gu: GenericGameUtil) -> Control:
	var tp: int = 0
	var fp: int = 0
	var tn: int = 0
	var fn: int = 0
	var found: bool = false
	for rec: Dictionary in gu.read_sessions():
		if rec.has("tp") or rec.has("fp") or rec.has("tn") or rec.has("fn"):
			found = true
			tp += int(rec.get("tp", 0))
			fp += int(rec.get("fp", 0))
			tn += int(rec.get("tn", 0))
			fn += int(rec.get("fn", 0))
	if not found or tp + fp + tn + fn == 0:
		return null
	var m: MatrixControl = MatrixControl.new()
	# Rows are what was true, columns what the player said, so the diagonal is "right".
	m.set_matrix(["Was yes", "Was no"], ["Said yes", "Said no"], {
		Vector2i(0, 0): tp, Vector2i(1, 0): fn,
		Vector2i(0, 1): fp, Vector2i(1, 1): tn,
	})
	return m

# A plain readout of the numbers this game keeps, for games with neither a bespoke panel nor a
# yes/no question. Not a chart: these are counts, and a count is best simply stated.
static func _summary(gu: GenericGameUtil) -> Control:
	var sessions: Array = gu.read_sessions()
	if sessions.is_empty():
		return _waiting("Play a session and what this game keeps track of will appear here.")
	var totals: Dictionary = {}
	var n: int = 0
	for i in range(maxi(0, sessions.size() - 5), sessions.size()):
		n += 1
		for k in sessions[i].keys():
			if METRIC_LABELS.has(k) and typeof(sessions[i][k]) in [TYPE_INT, TYPE_FLOAT]:
				totals[k] = float(totals.get(k, 0.0)) + float(sessions[i][k])
	if totals.is_empty():
		return _waiting("Play a session and what this game keeps track of will appear here.")

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var head: Label = Label.new()
	head.text = "Your last %d session%s" % [n, "" if n == 1 else "s"]
	head.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(head, 15)
	head.add_theme_color_override("font_color", ScreenBackdrop.ACCENT)
	box.add_child(head)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	var keys: Array = totals.keys()
	keys.sort()
	for k2 in keys:
		var name_lbl: Label = Label.new()
		name_lbl.text = str(METRIC_LABELS[k2])
		name_lbl.add_theme_font_override("font", MainGlobals.get_text_font())
		MainGlobals.set_font_size(name_lbl, 14)
		name_lbl.add_theme_color_override("font_color", Color(0.78, 0.80, 0.84, 1.0))
		grid.add_child(name_lbl)
		var val_lbl: Label = Label.new()
		# Averaged where a total would be meaningless -- a typical answer time is not something to
		# add up across sessions.
		var per_session: bool = AVERAGED.has(str(k2))
		val_lbl.text = ("%d" % int(round(float(totals[k2]) / float(n)))) if per_session \
			else ("%d" % int(round(float(totals[k2]))))
		val_lbl.add_theme_font_override("font", MainGlobals.get_text_font())
		MainGlobals.set_font_size(val_lbl, 14)
		val_lbl.add_theme_color_override("font_color", ScreenBackdrop.STATS_MARK)
		grid.add_child(val_lbl)
	return box

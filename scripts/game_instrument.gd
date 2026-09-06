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

# Polka Dots has a view of its own too, but not a curve: it compares two CONDITIONS rather than
# plotting a metric against a scale, so it sits in the Charts tab as a pair of bars.

# SUFFICIENCY, and it is not the same thing as variety.
#
# An earlier version asked only for two distinct buckets, which one session could satisfy with a
# dozen trials — and would then draw a confident-looking curve out of noise. That is exactly the
# failure the plan's own pitfalls warn about, so these floors match the rest of the system: the
# baseline skips warm-up sessions and ignores thin ones, and so does this.
const MIN_SESSIONS: int = 3        # separate sittings that contributed trials
const MIN_PER_BUCKET: int = 4      # samples before a bucket is worth averaging
const MIN_BUCKETS: int = 2         # points needed to have a shape at all

# A game's OWN VIEW: the one picture it is uniquely placed to draw. It occupies a single extra
# metric slot in the Charts tab, whether it happens to be a curve or a table.
#
#   dino / weris / gorilla   a curve      (accuracy against lag, time against crowd, error vs load)
#   polkadots                two bars     (accuracy with the choices up, against from memory)
#   the other yes/no games   a 2x2        (said yes / said no against was yes / was no)
#
# All of them are PICTURES, so all of them belong with the charts. The Summary tab is words and
# numbers — a verdict, a difficulty note, a readout — and mixing a picture into it produced exactly
# the "these two things are unrelated" problem twice over.
const YES_NO_GAMES: Array = ["aliens", "sortingrobots", "dino", "dinoback", "friends", "whack"]

# Games whose answer is a THREE-way choice, drawn as a 3x3 of what was right against what was
# chosen. The 2x2 cannot express these: with three destinations "wrong" splits three ways, and
# which way it split is the only thing a matrix adds to a percentage.
#
# Each entry is the option labels in the game's own index order, used for both axes.
const THREE_WAY_GAMES: Dictionary = {
	"bucketmadness": ["Left", "Dumpster", "Right"],
}

static func has_chart(folder: String) -> bool:
	return CHART_GAMES.has(folder)

static func has_own_view(folder: String) -> bool:
	return has_chart(folder) or folder == "polkadots" or YES_NO_GAMES.has(folder) \
		or THREE_WAY_GAMES.has(folder)

# What the extra metric button says. Named after the measurement, since it sits beside "Score" and
# "Avg Time" which are also named after theirs.
static func chart_metric_name(folder: String) -> String:
	if CHART_GAMES.has(folder):
		return str(CHART_GAMES[folder])
	if folder == "polkadots":
		# Not "Letters": the view is not about individual characters. What it separates is the
		# round played with the choices on screen from the same round played from memory.
		return "Memory"
	if YES_NO_GAMES.has(folder) or THREE_WAY_GAMES.has(folder):
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
	# Both say what the number IS, not just what it is called. "Lapses" and "spread" are the terms
	# the code uses; neither tells a player what was counted or what it was measured across.
	"rt_lapses": "Lapses (extra slow rounds)",
	"rt_sd": "Steadiness (spread of answer time, ms)",
	"rt_mean": "Typical answer (ms)",
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
	if THREE_WAY_GAMES.has(folder):
		return _choice_cells(gu, THREE_WAY_GAMES[folder] as Array)
	return _four_cells(gu)

# The rows the Summary tab shows, in this order, and what to call each one.
#
# The same shape as the global "Your progress" overlay, one zoom level in: a row per METRIC this
# game measures rather than a row per category, drawn from this game's own sessions only. A game
# shows the rows it actually has -- most have the first three, the calm games and typit speak their
# own vocabulary, and nothing invents a row out of data that was never recorded.
#
# Direction (which way is better) is NOT repeated here; it comes from StatsOverview.METRICS, so the
# two screens cannot disagree about whether a rising line is good news.
const SUMMARY_ROWS: Dictionary = {
	"rt_cv": "Consistency",
	"rt_mean": "Speed",
	"pct_correct": "Accuracy",
	"missed_breaths": "Rhythm",
	"missed_cycles": "Rhythm",
	"session_ps": "Following the path",
	"speed_cpm": "Typing speed",
	"mistake_rate": "Mistakes",
	"cycles_opened": "Safe turns",
}

# Sessions drawn in a Summary row's sparkline.
const SUMMARY_SPARK_LEN: int = 12

# This game's own rows, or null when it has recorded nothing that can fill one.
static func summary_rows_for(folder: String) -> Control:
	var gu: GenericGameUtil = GenericGameUtil.new(folder, folder, 0, 5, 0)
	var all: Array = gu.read_sessions()
	if all.is_empty():
		return null
	var sessions: Array = StatsBaseline.for_task(all, StatsBaseline.busiest_task(all))
	if sessions.is_empty():
		return null

	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	var rows: int = 0
	var shown_names: Array = []
	for metric: String in SUMMARY_ROWS.keys():
		if not StatsOverview.METRICS.has(metric):
			continue
		# The game has to have RECORDED it. Without this every game grows every row, and a breathing
		# row on a sorting game says "not yet" forever.
		var seen: bool = false
		for rec: Dictionary in sessions:
			if rec.has(metric):
				seen = true
				break
		if not seen:
			continue
		# ONE ROW PER NAME. missed_breaths and missed_cycles are both "Rhythm" -- different games
		# count a different thing and only one of them is ever real for a given game -- so a record
		# carrying both (a game that changed its columns, or seeded data) drew the row twice.
		if shown_names.has(str(SUMMARY_ROWS[metric])):
			continue
		shown_names.append(str(SUMMARY_ROWS[metric]))
		var higher_better: bool = bool(StatsOverview.METRICS[metric])
		var st: Dictionary = StatsBaseline.state_for(sessions, metric, higher_better)
		var vals: Array = _z_for(sessions, metric, higher_better)
		for cell: Control in ScreenBackdrop.stats_row_cells(
				str(SUMMARY_ROWS[metric]), vals, int(st.get("state", StatsBaseline.State.UNKNOWN))):
			grid.add_child(cell)
		rows += 1
	if rows == 0:
		grid.free()
		return null
	return grid

# One metric's recent sessions as "how far from your usual, in your own units, positive = better".
# Empty when there is no baseline yet, which is the honest answer -- a flat line at zero would read
# as "exactly average" for a player the app has barely met.
static func _z_for(sessions: Array, metric: String, higher_better: bool) -> Array:
	var b: Dictionary = StatsBaseline.band(sessions, metric)
	if not bool(b.get("ok", false)) or float(b.get("sd", 0.0)) <= 0.0:
		return []
	var out: Array = []
	for rec: Dictionary in sessions:
		if not rec.has(metric):
			continue
		var z: float = (float(rec[metric]) - float(b["mean"])) / float(b["sd"])
		if not higher_better:
			z = -z
		out.append(z)
	if out.size() > SUMMARY_SPARK_LEN:
		out = out.slice(out.size() - SUMMARY_SPARK_LEN)
	return out

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

	# THE BREAKDOWN BEHIND THE VERDICT, in the same rows the global overlay uses -- but one per
	# metric of THIS game, from this game's own sessions. The verdict above is a single sentence
	# drawn from these, so showing them under it says which part of the game it came from.
	var rows: Control = summary_rows_for(folder)
	if rows != null:
		col.add_child(_rule())
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(rows)

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
			col.add_child(_rule())
			readout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(readout)
	return col

# The divider between two sections of the Summary tab. The FRAME's colour, not a grey: these lines
# sit inside the framed panel, and a grey hairline across it reads as a seam rather than as a
# division the panel itself is making.
static func _rule() -> Control:
	var line: ColorRect = ColorRect.new()
	line.color = ScreenBackdrop.PANEL_FRAME
	line.custom_minimum_size = Vector2(0, 1)
	return line

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
		# No bespoke instrument: the grid where the game records what it asked against what the
		# player answered, and its own recorded numbers otherwise. Routed the same way as
		# chart_for(), so the two cannot disagree about which panel a game gets.
		var grid: Control = _choice_cells(gu, THREE_WAY_GAMES[folder] as Array) \
			if THREE_WAY_GAMES.has(folder) else _four_cells(gu)
		if grid != null:
			return grid
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
	var right: Dictionary = {false: 0, true: 0}
	var total: Dictionary = {false: 0, true: 0}
	var times: Dictionary = {false: [], true: []}
	for t in trials:
		if not (t is Dictionary):
			continue
		var shown: String = str(t.get("shown", ""))
		var chose: String = str(t.get("chose", ""))
		if shown == "" or chose == "":
			continue
		var hid: bool = bool(t.get("hidden", false))
		total[hid] = int(total[hid]) + 1
		if shown == chose:
			right[hid] = int(right[hid]) + 1
		var ms: int = int(t.get("ms", 0))
		if ms > 0:
			times[hid].append(float(ms))
	if int(total[false]) < MIN_PER_BUCKET and int(total[true]) < MIN_PER_BUCKET:
		return null

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	for hid2: bool in [false, true]:
		if int(total[hid2]) < MIN_PER_BUCKET:
			# Honest about which half is missing, and says how to fill it. A row of zeroes would
			# read as "you get everything wrong from memory".
			box.add_child(_note("From memory: not yet — the choices only disappear from level 4."
				if hid2 else "With the choices on screen: not yet."))
			continue
		box.add_child(_accuracy_row(
			"When choices were hidden" if hid2 else "When choices were visible",
			int(right[hid2]), int(total[hid2]),
			SessionStats.median(times[hid2]) if not times[hid2].is_empty() else 0.0))
	return _captioned(box,
		"On the harder levels the characters on the option buttons disappear part-way through "
		+ "the round, leaving only their numbers, so the same puzzle has to be answered from "
		+ "memory. This is how you did in each kind of round.")

# One condition, as a bar you can compare by length plus the figures behind it.
#
# NOT a 2x2 of counts, which is what this was. A matrix shades each cell by its raw count, so the
# biggest cell -- the CORRECT answers -- came out the hottest red while the worst cell was nearly
# invisible, and the two rows were only comparable when they happened to hold the same number of
# rounds. Which levels you played decides that, so usually they do not: levels 1-3 produce only
# on-screen rounds and 4-8 only hidden ones. A percentage is comparable by construction.
static func _accuracy_row(title: String, n_right: int, n_total: int, median_ms: float) -> Control:
	var pct: float = 100.0 * float(n_right) / float(maxi(1, n_total))
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)

	var head: HBoxContainer = HBoxContainer.new()
	var name_lbl: Label = Label.new()
	name_lbl.text = title
	name_lbl.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(name_lbl, 15)
	name_lbl.add_theme_color_override("font_color", Color(0.86, 0.88, 0.92, 1.0))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_lbl)

	var pct_lbl: Label = Label.new()
	# NAMED, not a bare number. A percentage on its own beside a bar does not say what it is a
	# percentage OF, and the honest guesses -- share of rounds, share of the session, progress --
	# are not the same thing.
	pct_lbl.text = "Accuracy: %d%%" % int(round(pct))
	pct_lbl.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(pct_lbl, 15)
	pct_lbl.add_theme_color_override("font_color", ScreenBackdrop.ACCENT)
	head.add_child(pct_lbl)
	row.add_child(head)

	# Two rectangles sharing the width in proportion. No drawing code, and it cannot disagree with
	# the number printed beside it, because both come from `pct`.
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 0)
	bar.custom_minimum_size = Vector2(0, MainGlobals.ui_font_size(10))
	var fill: ColorRect = ColorRect.new()
	fill.color = ScreenBackdrop.STATS_STEADY
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.size_flags_stretch_ratio = maxf(0.001, pct)
	bar.add_child(fill)
	var rest: ColorRect = ColorRect.new()
	rest.color = Color(1, 1, 1, 0.10)
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rest.size_flags_stretch_ratio = maxf(0.001, 100.0 - pct)
	bar.add_child(rest)
	row.add_child(bar)

	var detail: String = "Correct in %d out of %d rounds" % [n_right, n_total]
	if median_ms > 0.0:
		detail += " · typically %.1f s" % (median_ms / 1000.0)
	row.add_child(_note(detail))
	return row

static func _note(text: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(lbl, 12)
	lbl.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78, 1.0))
	return lbl

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
# ONE TASK AT A TIME, and a way to change which.
#
# The answer panel for every game that records what it was asked against what the player said,
# whether that is a 2x2 or a 3x3. It used to sum every session ever played into one grid and it
# was the only panel that did: the Summary rows, the baseline and the verdict all narrow to
# `busiest_task` first. Pooling a game's levels hides exactly what the matrix is for -- a bias
# that appears at the hard levels is diluted by the easy ones, and the harder a level gets the
# fewer sessions it has to speak with.
#
# Narrowing alone was not enough either: it left one grid covering one level with the player's
# other levels simply absent. The tasks played are a LevelPicker row, the same control typit's
# Keys tab uses.
#
#   fields     the session metrics to sum, INCLUDING no_answer -- a round left unanswered is a
#              round got wrong, so it belongs in the accuracy denominator
#   cells_of   {Vector2i(col, row): count} for one task's totals
#   right_of   how many of those were correct, i.e. the diagonal
static func _answer_panel(gu: GenericGameUtil, fields: Array, rows: Array, cols: Array,
		cells_of: Callable, right_of: Callable) -> Control:
	var per: Dictionary = {}                # task_key -> {field: total, "n": sessions}
	for rec: Dictionary in gu.read_sessions():
		var any: bool = false
		for f: String in fields:
			if rec.has(f):
				any = true
				break
		if not any:
			continue
		var k: String = str(rec.get("task_key", ""))
		if not per.has(k):
			var fresh: Dictionary = {"n": 0}
			for f2: String in fields:
				fresh[f2] = 0
			per[k] = fresh
		var e: Dictionary = per[k]
		e["n"] = int(e["n"]) + 1
		for f3: String in fields:
			e[f3] = int(e[f3]) + int(rec.get(f3, 0))
	for k: String in per.keys():
		if _asked(per[k], fields) == 0:
			per.erase(k)
	if per.is_empty():
		return null

	var keys: Array = per.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return _task_order(a) < _task_order(b))
	var sel: int = 0
	for i in keys.size():
		if int(per[keys[i]]["n"]) > int(per[keys[sel]]["n"]):
			sel = i                          # open on the one played most
	var picked: Dictionary = _varying(keys)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var m: MatrixControl = MatrixControl.new()
	# MatrixControl draws into whatever rect it is given and declares no minimum of its own, so
	# without this it collapses to nothing inside a VBox and the panel comes up blank.
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var foot: Label = Label.new()
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	foot.add_theme_font_size_override("font_size", LevelPicker.font_size())
	foot.add_theme_color_override("font_color", LevelPicker.TITLE_FG)

	var buttons: Array = []
	var show: Callable = func(i: int) -> void:
		var e2: Dictionary = per[keys[i]]
		m.set_matrix(rows, cols, cells_of.call(e2))
		var right: int = int(right_of.call(e2))
		var asked: int = _asked(e2, fields)
		# The number the grid is for. Reading it off the cells is arithmetic nobody should have
		# to do to answer "how am I doing".
		foot.text = "Accuracy %d%%, correct %d out of %d answers" % [
			int(round(100.0 * float(right) / float(maxi(asked, 1)))), right, asked]
		LevelPicker.select(buttons, i)

	if keys.size() > 1:
		var made: Dictionary = LevelPicker.build(str(picked["title"]) + ":",
			(picked["labels"] as Array), show)
		# APPENDED, never reassigned. A lambda captures the VALUE of a local, and for an Array
		# that value is the reference -- so mutating it in place is visible inside `show`, while
		# `buttons = made["buttons"]` left the closure holding the original empty array and no
		# button was ever lit.
		buttons.append_array(made["buttons"] as Array)
		box.add_child(made["row"])
	else:
		# A single task is not a choice; say which one it is and leave it at that.
		var made2: Dictionary = LevelPicker.build(task_label(keys[0]), [], show)
		box.add_child(made2["row"])
	box.add_child(m)
	box.add_child(foot)
	show.call(sel)
	return box

static func _asked(e: Dictionary, fields: Array) -> int:
	var n: int = 0
	for f: String in fields:
		n += int(e.get(f, 0))
	return n

# The six yes/no games. Rows are what was true, columns what the player said, so the diagonal is
# "right".
static func _four_cells(gu: GenericGameUtil) -> Control:
	return _answer_panel(gu, ["tp", "fp", "tn", "fn", "no_answer"],
		["Was yes", "Was no"], ["Said yes", "Said no"],
		func(e: Dictionary) -> Dictionary:
			return {
				Vector2i(0, 0): int(e["tp"]), Vector2i(1, 0): int(e["fn"]),
				Vector2i(0, 1): int(e["fp"]), Vector2i(1, 1): int(e["tn"]),
			},
		func(e: Dictionary) -> int:
			return int(e["tp"]) + int(e["tn"]))

# A three-way choice, as nine counts written by GenericGameUtil.record_choice.
static func _choice_cells(gu: GenericGameUtil, labels: Array) -> Control:
	var n: int = labels.size()
	var fields: Array = ["no_answer"]
	for was in n:
		for chose in n:
			fields.append("c%d%d" % [was, chose])
	var rows: Array = []
	var cols: Array = []
	for l: String in labels:
		rows.append("Was " + l.to_lower())
		cols.append("Chose " + l.to_lower())
	return _answer_panel(gu, fields, rows, cols,
		func(e: Dictionary) -> Dictionary:
			var out: Dictionary = {}
			for was in n:
				for chose in n:
					out[Vector2i(chose, was)] = int(e.get("c%d%d" % [was, chose], 0))
			return out,
		func(e: Dictionary) -> int:
			var r: int = 0
			for i in n:
				r += int(e.get("c%d%d" % [i, i], 0))
			return r)

# What actually differs between the tasks played, so the picker can be one short button per value
# instead of the whole signature repeated on each. dino's tasks are four fields wide and usually
# only one of them moves; "Level 1 / Level 2" spelled out in full is the same problem smaller.
static func _varying(keys: Array) -> Dictionary:
	var fields: Dictionary = {}              # field -> {value: true}
	var parsed: Dictionary = {}              # key -> {field: value}
	for k: String in keys:
		var d: Dictionary = {}
		for pair: String in k.split("|"):
			var kv: PackedStringArray = pair.split("=")
			if kv.size() == 2:
				d[kv[0]] = kv[1]
				if not fields.has(kv[0]):
					fields[kv[0]] = {}
				(fields[kv[0]] as Dictionary)[kv[1]] = true
		parsed[k] = d
	var moving: Array = []
	for f: String in fields.keys():
		if (fields[f] as Dictionary).size() > 1:
			moving.append(f)
	moving.sort()
	var labels: Array = []
	for k: String in keys:
		var parts: Array = []
		for f: String in moving:
			parts.append(str((parsed[k] as Dictionary).get(f, "?")))
		labels.append(" · ".join(parts) if not parts.is_empty() else task_label(k))
	var title: String = "Task"
	if moving.size() == 1:
		title = "Level" if moving[0] == "level" else str(METRIC_LABELS.get(moving[0], moving[0]))
	return {"labels": labels, "title": title}

# Sort key for a task, so the buttons read 1, 2, 3 rather than "level=1", "level=10", "level=2".
static func _task_order(key: String) -> float:
	for pair: String in key.split("|"):
		var kv: PackedStringArray = pair.split("=")
		if kv.size() == 2 and kv[1].is_valid_float():
			return float(kv[1])
	return INF

# A task key ("level=3", "duration_min=5|mode=2") as something to put under a panel.
static func task_label(key: String) -> String:
	if key == "":
		return "All sessions"
	var parts: Array = []
	for pair: String in key.split("|"):
		var kv: PackedStringArray = pair.split("=")
		if kv.size() != 2:
			continue
		parts.append("Level %s" % kv[1] if kv[0] == "level" else "%s %s" % [kv[0], kv[1]])
	return " · ".join(parts) if not parts.is_empty() else key

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
	# ONE LINE PER NAME, for the same reason the Summary rows need it: missed_breaths and
	# missed_cycles are both "Out of rhythm", so a record carrying both listed it twice with two
	# different numbers beside it -- which reads as a bug in the readout rather than in the data.
	var listed: Array = []
	for k2 in keys:
		if listed.has(str(METRIC_LABELS[k2])):
			continue
		listed.append(str(METRIC_LABELS[k2]))
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

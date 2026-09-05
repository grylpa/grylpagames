extends RefCounted
class_name StatsOverview

# The across-games view: one row per category, which is the right unit to lead with.
#
# A single game's numbers are too noisy to read month to month — that is the whole reason the plan
# leads with categories rather than with 34 sparklines. But raw values cannot simply be averaged
# together: 300 ms in Whack and 4000 ms in Change are not the same quantity, and a category mean
# over them would be dominated by whichever game happens to have the biggest numbers.
#
# So every session is first expressed as a DISTANCE FROM THAT GAME'S OWN BASELINE, in units of that
# game's own spread. Those are comparable across games by construction, and a category is their
# average. The sign convention is fixed once here: POSITIVE IS ALWAYS BETTER, whichever direction
# the underlying metric happens to run in.

# The metrics a category score is built from, and which way each runs.
# `false` means a lower number is the better one.
const METRICS: Dictionary = {
	"rt_cv": false,        # consistency — the one that moves first
	"pct_correct": true,
	"rt_mean": false,
	# The calm games and typit speak a different vocabulary, and without these their whole category
	# could never say anything but "not yet" however much the player practised.
	"missed_breaths": false,
	"missed_cycles": false,
	"session_ps": true,    # how closely the path was followed
	"speed_cpm": true,
	"mistake_rate": false,
	# Crack the Safe counts nothing else. Without it that game had no metric any of these screens
	# recognised, so its Summary rows were empty and its category could never contribute.
	"cycles_opened": true,
}

# Sessions to draw in a row's sparkline.
const SPARK_LEN: int = 12

# Categories come from the app's own game table, so this cannot drift from the chooser.
static func categories() -> Array:
	var seen: Array = []
	for entry in MainCfg.games:
		if entry.size() > 3 and not seen.has(entry[3]):
			seen.append(entry[3])
	return seen

static func games_in(category: String) -> Array:
	var out: Array = []
	for entry in MainCfg.games:
		if entry.size() > 3 and entry[3] == category:
			out.append(entry[0])
	return out

# One game's recent sessions as "how far from your usual, in your own units, positive = better".
#
# Returns [] when the game has no baseline yet, which is the honest answer for a game the player
# has barely touched — a zero would read as "average" and be a quiet lie.
static func z_series(folder: String) -> Array:
	var gu: GenericGameUtil = GenericGameUtil.new(folder, folder, 0, 5, 0)
	var all: Array = gu.read_sessions()
	if all.is_empty():
		return []
	var task: String = StatsBaseline.busiest_task(all)
	var sessions: Array = StatsBaseline.for_task(all, task)
	if sessions.size() < StatsBaseline.MIN_BASELINE_SESSIONS:
		return []

	var bands: Dictionary = {}
	for metric: String in METRICS.keys():
		var b: Dictionary = StatsBaseline.band(sessions, metric)
		if bool(b.get("ok", false)) and float(b.get("sd", 0.0)) > 0.0:
			bands[metric] = b
	if bands.is_empty():
		return []

	var out: Array = []
	for rec: Dictionary in sessions:
		var zs: Array = []
		for metric in bands.keys():
			if not rec.has(metric):
				continue
			var b2: Dictionary = bands[metric]
			var z: float = (float(rec[metric]) - float(b2["mean"])) / float(b2["sd"])
			# Fix the sign so that positive always means "better than usual", whichever way the
			# underlying metric runs. Without this, consistency and accuracy would cancel out.
			if not bool(METRICS[metric]):
				z = -z
			zs.append(z)
		if not zs.is_empty():
			out.append(SessionStats.mean(zs))
	return out

# One category row: {"category":, "values": Array, "state": int, "games": int, "worst_game": String}
static func category_row(category: String) -> Dictionary:
	var per_game: Array = []
	var worst_game: String = ""
	var worst_state: int = StatsBaseline.State.UNKNOWN
	var contributing: int = 0

	for folder: String in games_in(category):
		var zs: Array = z_series(folder)
		if zs.is_empty():
			continue
		contributing += 1
		per_game.append(zs)
		# A category is flagged when one of its games is, and the game is named — "Memory" alone
		# tells the player nothing they can act on.
		var gu: GenericGameUtil = GenericGameUtil.new(folder, folder, 0, 5, 0)
		var all: Array = gu.read_sessions()
		var sessions: Array = StatsBaseline.for_task(all, StatsBaseline.busiest_task(all))
		for metric: String in METRICS.keys():
			var st: Dictionary = StatsBaseline.state_for(sessions, metric, bool(METRICS[metric]))
			if int(st.get("state", 0)) == StatsBaseline.State.WATCH:
				worst_state = StatsBaseline.State.WATCH
				if worst_game == "":
					worst_game = folder
	if per_game.is_empty():
		return {"category": category, "values": [], "state": StatsBaseline.State.UNKNOWN,
				"games": 0, "worst_game": ""}

	# Average the games' series over their LAST sessions, which is what a row is showing. Games are
	# played different numbers of times, so they are aligned at the recent end rather than the start.
	var n: int = SPARK_LEN
	var merged: Array = []
	for i in range(n):
		var acc: Array = []
		for zs2: Array in per_game:
			var idx: int = zs2.size() - n + i
			if idx >= 0 and idx < zs2.size():
				acc.append(zs2[idx])
		if not acc.is_empty():
			merged.append(SessionStats.mean(acc))
	var state: int = worst_state
	if state != StatsBaseline.State.WATCH:
		state = StatsBaseline.State.STEADY if merged.size() >= 3 else StatsBaseline.State.UNKNOWN
	return {"category": category, "values": merged, "state": state,
			"games": contributing, "worst_game": worst_game}

static func all_rows() -> Array:
	var rows: Array = []
	for c: String in categories():
		rows.append(category_row(c))
	return rows

# Adherence, which is the Goal 1 number and the one a player can actually act on.
static func week_summary() -> Dictionary:
	var cutoff: int = int(Time.get_unix_time_from_system()) - 7 * 86400
	var sessions: int = 0
	var ms: int = 0
	var games: Dictionary = {}
	for entry in MainCfg.games:
		var folder: String = entry[0]
		var gu: GenericGameUtil = GenericGameUtil.new(folder, folder, 0, 5, 0)
		for rec: Dictionary in gu.read_sessions():
			if int(rec.get("ts", 0)) >= cutoff:
				sessions += 1
				ms += int(rec.get("session_ms", 0))
				games[folder] = true
	return {"sessions": sessions, "minutes": int(round(float(ms) / 60000.0)),
			"games": games.size()}

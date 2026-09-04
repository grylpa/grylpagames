extends RefCounted
class_name StatsBaseline

# "Is this different from how I usually am?" — answered against the player's OWN early sessions,
# never against anyone else's.
#
# Three rules decide what goes into a baseline, and each exists because ignoring it produces a
# confident wrong answer:
#
#   1. GROUP BY TASK. Sessions only compare if they were the same task. A level number is an index
#      into an editable table (see SessionStats.task_key), so grouping by it silently mixes a
#      retuned level with its old self.
#   2. SKIP THE LEARNING CURVE. The first sessions of any game improve steeply for reasons that have
#      nothing to do with the player's mind — they are learning the controls. Baselining from
#      session one makes every player's first month look like a triumph and the inevitable levelling
#      off afterwards look like decline.
#   3. IGNORE THIN SESSIONS. A mean over three trials is noise. Sessions below the trial floor are
#      still recorded, and still shown in the table, but must not shape a baseline or a verdict.

# Sessions skipped at the start of a task, as practice rather than measurement.
const WARMUP_SESSIONS: int = 3
# Sessions needed AFTER the warm-up before a baseline means anything.
const MIN_BASELINE_SESSIONS: int = 5
# How wide the "usual range" is, in standard deviations either side of the player's own mean.
const BAND_SD: float = 1.5
# How many of the recent sessions must sit outside the band, in the same direction, before anything
# is said. One unusual session is a bad night, not a finding.
const RECENT_WINDOW: int = 6
const RECENT_TRIGGER: int = 4

enum State { UNKNOWN, STEADY, WATCH, IMPROVING }

# Sessions of one game that are worth comparing with each other, newest last.
static func for_task(sessions: Array, task_key: String) -> Array:
	var out: Array = []
	for rec: Dictionary in sessions:
		if str(rec.get("task_key", "")) != task_key:
			continue
		if int(rec.get("n_trials", SessionStats.MIN_TRIALS_FOR_TREND)) < SessionStats.MIN_TRIALS_FOR_TREND:
			continue
		out.append(rec)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("ts", 0)) < int(b.get("ts", 0)))
	return out

# The task signature the player has played most, which is what a screen should open on.
static func busiest_task(sessions: Array) -> String:
	var counts: Dictionary = {}
	for rec: Dictionary in sessions:
		var k: String = str(rec.get("task_key", ""))
		counts[k] = int(counts.get(k, 0)) + 1
	var best_key: String = ""
	var best_n: int = -1
	for k in counts.keys():
		if int(counts[k]) > best_n:
			best_n = int(counts[k])
			best_key = str(k)
	return best_key

# The most sessions a baseline is built from. Kept bounded so it stays an EARLY reference rather
# than slowly following the player: a baseline that drifts along with a gradual decline would never
# notice it, which is the whole failure this is meant to avoid.
const BASELINE_WINDOW: int = 20

# The player's usual range for one metric: {"ok": bool, "mean":, "sd":, "lo":, "hi":, "n":}.
# `ok` false means there is not yet enough to say anything, which the screens must show as "not yet"
# rather than as a flat line at zero.
#
# THE RECENT SESSIONS ARE EXCLUDED, and that exclusion is the difference between this working and
# not. Measured on a run of ten steady sessions followed by five clearly slower ones: including the
# slow ones pulled the mean from 300 to 438 and the spread from 3 to 171, widening the band to
# 182-694 — so the drift sat comfortably inside its own baseline and nothing was ever reported.
# A baseline may not contain the period it is judging.
static func band(sessions: Array, metric: String) -> Dictionary:
	var usable: Array = []
	for i in range(sessions.size()):
		if i < WARMUP_SESSIONS:
			continue
		if sessions[i].has(metric):
			usable.append(float(sessions[i][metric]))
	# Hold back the window being judged, as long as enough is left to say anything at all. Early on
	# there is no such luxury: the whole history is used, and the recent window still has to
	# disagree with it before anything is reported.
	return band_from_values(usable)

# The same rules applied to a plain list of values in time order, for callers that already have the
# series they are plotting and do not need to go back to the records.
static func band_from_values(usable: Array) -> Dictionary:
	# Hold back the window being judged, as long as enough is left to say anything at all. Early on
	# there is no such luxury: the whole history is used, and the recent window still has to
	# disagree with it before anything is reported.
	var vals: Array = usable
	if usable.size() - RECENT_WINDOW >= MIN_BASELINE_SESSIONS:
		vals = usable.slice(0, usable.size() - RECENT_WINDOW)
	if vals.size() > BASELINE_WINDOW:
		vals = vals.slice(0, BASELINE_WINDOW)
	if vals.size() < MIN_BASELINE_SESSIONS:
		return {"ok": false, "n": vals.size()}
	var m: float = SessionStats.mean(vals)
	var s: float = SessionStats.sd(vals)
	return {
		"ok": true, "n": vals.size(), "mean": m, "sd": s,
		"lo": m - BAND_SD * s, "hi": m + BAND_SD * s,
	}

# Whether recent sessions have drifted out of that range, and which way.
#
# Deliberately hard to trigger. With 34 games and a dozen metrics each, something will always look
# like it is moving; requiring several recent sessions to agree on a direction is what keeps this
# from crying wolf on a tired Tuesday.
static func state_for(sessions: Array, metric: String, higher_is_better: bool) -> Dictionary:
	var b: Dictionary = band(sessions, metric)
	if not bool(b.get("ok", false)):
		return {"state": State.UNKNOWN, "band": b}
	var recent: Array = []
	var start: int = maxi(0, sessions.size() - RECENT_WINDOW)
	for i in range(start, sessions.size()):
		if sessions[i].has(metric):
			recent.append(float(sessions[i][metric]))
	if recent.size() < RECENT_TRIGGER:
		return {"state": State.UNKNOWN, "band": b}
	# BOTH directions. Counting only the bad one meant a player who had genuinely got better was
	# told they were "steady", which is true of the band and useless to them.
	var worse: int = 0
	var better: int = 0
	for v: float in recent:
		var below: bool = v < float(b["lo"])
		var above: bool = v > float(b["hi"])
		if (higher_is_better and below) or ((not higher_is_better) and above):
			worse += 1
		elif (higher_is_better and above) or ((not higher_is_better) and below):
			better += 1
	if worse >= RECENT_TRIGGER:
		return {"state": State.WATCH, "band": b, "count": worse, "of": recent.size()}
	if better >= RECENT_TRIGGER:
		return {"state": State.IMPROVING, "band": b, "count": better, "of": recent.size()}
	return {"state": State.STEADY, "band": b}

# Wording for the player. Describes their own scores and stops there — never what it might mean
# about them. "Below your usual range" is the right register; anything diagnostic is not.
static func state_text(st: Dictionary, game_title: String) -> String:
	match int(st.get("state", State.UNKNOWN)):
		State.WATCH:
			return "%s has been outside your usual range in %d of the last %d sessions." % [
				game_title, int(st.get("count", 0)), int(st.get("of", 0))]
		State.IMPROVING:
			return "%s has been better than your usual range in %d of the last %d sessions." % [
				game_title, int(st.get("count", 0)), int(st.get("of", 0))]
		State.STEADY:
			return "%s is in your usual range." % game_title
		_:
			return "%s needs a few more sessions before there is anything to compare." % game_title

# --- the per-game verdict -----------------------------------------------------------------------

# The metric a game is judged on, in order of preference: consistency first, because it moves before
# anything else; then accuracy; then plain speed.
const VERDICT_METRICS: Array = [
	["rt_cv", false], ["react_cv", false], ["pct_correct", true],
	["rt_mean", false], ["react_mean", false], ["session_ps", true],
	["missed_breaths", false], ["missed_cycles", false], ["speed_cpm", true],
]

# Two separate questions, which is why this returns two lines.
#
#   "trend"     — is this different from how you usually are?      (noticing change)
#   "challenge" — is the game still asking anything of you?        (keeping it worth playing)
#
# They are not the same, and a player can be steady at a level that stopped stretching them months
# ago — which is the case a single trend line will never surface.
static func verdict(sessions: Array) -> Dictionary:
	var out: Dictionary = {"state": State.UNKNOWN, "trend": "", "challenge": "", "metric": ""}
	if sessions.is_empty():
		out["trend"] = "No sessions yet."
		return out
	for spec: Array in VERDICT_METRICS:
		var metric: String = str(spec[0])
		var higher: bool = bool(spec[1])
		var st: Dictionary = state_for(sessions, metric, higher)
		if int(st["state"]) == State.UNKNOWN:
			continue
		out["state"] = int(st["state"])
		out["metric"] = metric
		match int(st["state"]):
			State.WATCH:
				out["trend"] = "Outside your usual range in %d of the last %d sessions." % [
					int(st.get("count", 0)), int(st.get("of", 0))]
			State.IMPROVING:
				out["trend"] = "Better than your usual range in %d of the last %d sessions." % [
					int(st.get("count", 0)), int(st.get("of", 0))]
			_:
				out["trend"] = "Holding steady, in your usual range."
		break
	if str(out["trend"]) == "":
		out["trend"] = "A few more sessions and there will be something to compare."

	out["challenge"] = _challenge_text(sessions)
	return out

# Whether the game is still hard enough — the other half of the point, and the half a trend cannot
# answer. The aim is roughly three or four right out of five: comfortably above that and the game
# has stopped being exercise, well below and it is only discouraging.
static func _challenge_text(sessions: Array) -> String:
	var pcts: Array = []
	var start: int = maxi(0, sessions.size() - RECENT_WINDOW)
	for i in range(start, sessions.size()):
		if sessions[i].has("pct_correct"):
			pcts.append(float(sessions[i]["pct_correct"]))
	if pcts.size() < 3:
		return ""
	var m: float = SessionStats.mean(pcts)
	if m >= 88.0:
		return "You are getting almost everything right — try a harder level."
	if m >= 80.0:
		return "Comfortable. A harder level would give you more to work with."
	if m < 55.0:
		return "This is coming out hard. An easier level may suit you better."
	return "Difficulty looks about right."

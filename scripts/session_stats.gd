extends RefCounted
class_name SessionStats

# The numbers a session is worth keeping, computed from the per-trial times every game already
# collects and then throws away.
#
# Games accumulate a full `times_to_answer` array for a whole session and collapse it to a mean at
# save time. The mean is the least informative thing in that array: a person's SLOWEST responses
# drift before their average does, so response-time VARIABILITY moves earlier than speed. Everything
# here is derived from an array that already exists — this is not new measurement, it is keeping
# what was being discarded.
#
# All functions are static and tolerate empty or one-element input, because a session that ended
# after one trial is a real thing that must not crash the save path.

# A trial this far above the player's own mean is counted as a lapse rather than a slow answer.
const LAPSE_SD: float = 3.0

# Below this many trials a session's derived numbers are too noisy to mean anything. Sessions are
# still recorded — `n_trials` travels with them — but the trend views must exclude them.
const MIN_TRIALS_FOR_TREND: int = 5

static func mean(vals: Array) -> float:
	if vals.is_empty():
		return 0.0
	var s: float = 0.0
	for v in vals:
		s += float(v)
	return s / float(vals.size())

# Sample standard deviation (n-1). Zero for fewer than two values, which is correct rather than
# merely safe: one trial genuinely carries no information about variability.
static func sd(vals: Array) -> float:
	var n: int = vals.size()
	if n < 2:
		return 0.0
	var m: float = mean(vals)
	var acc: float = 0.0
	for v in vals:
		var d: float = float(v) - m
		acc += d * d
	return sqrt(acc / float(n - 1))

# Coefficient of variation: variability with overall speed divided out, so it stays comparable as a
# player gets generally faster or slower. This is the headline consistency number.
static func cv(vals: Array) -> float:
	var m: float = mean(vals)
	if m <= 0.0:
		return 0.0
	return sd(vals) / m

static func median(vals: Array) -> float:
	if vals.is_empty():
		return 0.0
	var sorted_vals: Array = vals.duplicate()
	sorted_vals.sort()
	var n: int = sorted_vals.size()
	if n % 2 == 1:
		return float(sorted_vals[n / 2])
	return (float(sorted_vals[n / 2 - 1]) + float(sorted_vals[n / 2])) * 0.5

# Least-squares slope of value against trial index, in units per trial. Positive means the player
# slowed as the session went on, which separates fatigue from being uniformly slower.
static func slope(vals: Array) -> float:
	var n: int = vals.size()
	if n < 3:
		return 0.0
	var mean_x: float = float(n - 1) * 0.5
	var mean_y: float = mean(vals)
	var num: float = 0.0
	var den: float = 0.0
	for i in n:
		var dx: float = float(i) - mean_x
		num += dx * (float(vals[i]) - mean_y)
		den += dx * dx
	if den == 0.0:
		return 0.0
	return num / den

# Median absolute deviation, scaled so it is comparable to a standard deviation on normal data.
# Unlike SD it is not moved by the very outliers it is used to find.
static func mad(vals: Array) -> float:
	if vals.size() < 2:
		return 0.0
	var med: float = median(vals)
	var devs: Array = []
	for v in vals:
		devs.append(abs(float(v) - med))
	return median(devs) * 1.4826

# Trials far enough above the player's own typical response to be an attentional lapse rather than
# a merely slow answer.
#
# The obvious test — mean + 3 SD — is self-defeating, and measurably so: one 5000 ms trial among
# nine ~100 ms ones drags the mean to 590 and the SD to ~1550, putting the cut at 5238, so the lapse
# HIDES ITSELF and the count comes back zero. The threshold has to come from a statistic the outlier
# cannot move, which is the median and the MAD.
#
# Two conditions, both required, because either alone misfires:
#   - above median + LAPSE_MAD * MAD  — catches the outlier robustly
#   - at least LAPSE_MIN_RATIO x the median — stops a very CONSISTENT player being punished, where
#     a tiny MAD would otherwise make an ordinary trial 30 ms off the median count as a lapse.
const LAPSE_MAD: float = 3.0
const LAPSE_MIN_RATIO: float = 1.5

static func lapses(vals: Array) -> int:
	if vals.size() < 3:
		return 0
	var med: float = median(vals)
	var spread: float = mad(vals)
	if spread <= 0.0:
		# Every trial identical, or so nearly so that the MAD collapses. Fall back to the SD, and if
		# that is zero too there is genuinely nothing to find.
		spread = sd(vals)
	if spread <= 0.0:
		return 0
	var cut: float = max(med + LAPSE_MAD * spread, med * LAPSE_MIN_RATIO)
	var count: int = 0
	for v in vals:
		if float(v) > cut:
			count += 1
	return count

# The whole response-time block for one session, ready to merge into the saved record.
#
# `prefix` lets a game store more than one timing stream under distinct names (whack has reaction
# and distance; typit has per-key streams), without any of them colliding.
static func rt_block(times_ms: Array, prefix: String = "rt") -> Dictionary:
	var out: Dictionary = {}
	out[prefix + "_n"] = times_ms.size()
	if times_ms.is_empty():
		return out
	out[prefix + "_mean"] = int(round(mean(times_ms)))
	out[prefix + "_median"] = int(round(median(times_ms)))
	out[prefix + "_sd"] = int(round(sd(times_ms)))
	out[prefix + "_cv"] = snappedf(cv(times_ms), 0.001)
	out[prefix + "_slope"] = snappedf(slope(times_ms), 0.01)
	out[prefix + "_lapses"] = lapses(times_ms)
	return out

# --- accuracy -------------------------------------------------------------------------------

# The four outcome counts of a yes/no question, kept apart instead of collapsed to a percentage.
#
#   tp  said yes, was yes      fp  said yes, was no   (a false alarm)
#   tn  said no,  was no       fn  said no,  was yes  (a miss)
#
# A percentage smears together two independent things: how well the player TELLS THE CASES APART,
# and how willing they are to SAY YES. Someone whose discrimination is slipping often compensates by
# guessing yes more — tp rises, fp rises with it, and the percentage barely moves. The percentage
# then shows a steady player while these four counts show what is actually happening.
static func acc_block(tp: int, fp: int, tn: int, fn: int) -> Dictionary:
	var total: int = tp + fp + tn + fn
	var out: Dictionary = {"tp": tp, "fp": fp, "tn": tn, "fn": fn, "n_trials": total}
	if total > 0:
		out["pct_correct"] = int(round(100.0 * float(tp + tn) / float(total)))
	return out

# Hit rate and false-alarm rate, the two numbers discrimination and bias are read from. Kept as
# rates rather than a single index so the stats screen can show them plainly; the log-based indices
# can be derived later without re-recording anything.
static func rates(rec: Dictionary) -> Dictionary:
	var tp: int = int(rec.get("tp", 0))
	var fn: int = int(rec.get("fn", 0))
	var fp: int = int(rec.get("fp", 0))
	var tn: int = int(rec.get("tn", 0))
	var out: Dictionary = {}
	if tp + fn > 0:
		out["hit_rate"] = float(tp) / float(tp + fn)
	if fp + tn > 0:
		out["fa_rate"] = float(fp) / float(fp + tn)
	return out

# --- task signature -------------------------------------------------------------------------

# A stable, READABLE key for "the same task", built from the settings that define it.
#
# A level number is an index into an editable table: insert a level between 1 and 2, retune a
# timing, and every historical record silently changes meaning while its number stays the same. For
# a year-long trend that is fatal, so analysis groups by this instead. Dino is the plain case — its
# levels differ by `source`, and recognising faces is not the same capacity as recognising dinosaur
# pictures.
#
# Readable rather than hashed on purpose: "n_back=2|source=people" is something a stats screen can
# show and a person can debug, and the string is short enough that a hash buys nothing.
static func task_key(task: Dictionary) -> String:
	if task.is_empty():
		return ""
	var keys: Array = task.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for k in keys:
		parts.append("%s=%s" % [str(k), str(task[k])])
	return "|".join(parts)

# --- time of day ----------------------------------------------------------------------------

# LOCAL time, not UTC. What matters is whether it was morning FOR THE PLAYER — performance swings
# with time of day, and a UTC hour says nothing about that once someone travels or the clocks change.
# The offset is stored alongside so the wall-clock hour can always be reconstructed exactly.
static func local_time_block() -> Dictionary:
	var dt: Dictionary = Time.get_datetime_dict_from_system(false)
	var tz: Dictionary = Time.get_time_zone_from_system()
	return {
		"local_hour": int(dt.get("hour", 0)),
		"local_min": int(dt.get("minute", 0)),
		"local_dow": int(dt.get("weekday", 0)),
		"tz_offset_min": int(tz.get("bias", 0)),
	}

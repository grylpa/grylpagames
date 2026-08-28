class_name MmmLevelConfig

# Per-level configuration for Mmm.
# rounds: how many rounds at this level before it is judged
# pass_pct: share of those rounds that must be WON to move on. Below it the SAME level is played
#   again. A level is a fixed number of rounds, so only some percentages exist: out of 3 the rungs
#   are 0, 33, 66 and 100. 60 lands exactly on 2 of 3. Recheck it whenever "rounds" changes.

const LEVELS: Array = [
	{"level": 1,  "rounds": 3, "pass_pct": 60},
	{"level": 2,  "rounds": 3, "pass_pct": 60},
	{"level": 3,  "rounds": 3, "pass_pct": 60},
	{"level": 4,  "rounds": 3, "pass_pct": 60},
	{"level": 5,  "rounds": 3, "pass_pct": 60},
	{"level": 6,  "rounds": 3, "pass_pct": 60},
	{"level": 7,  "rounds": 3, "pass_pct": 60},
	{"level": 8,  "rounds": 3, "pass_pct": 60},
	{"level": 9,  "rounds": 3, "pass_pct": 60},
	{"level": 10, "rounds": 3, "pass_pct": 60},
	{"level": 11, "rounds": 3, "pass_pct": 60},
	{"level": 12, "rounds": 3, "pass_pct": 60},
]

const DEFAULT_PASS_PCT: int = 60

# Falls back rather than failing, so adding a level without a pass_pct cannot silently make it
# ungated.
static func pass_pct_for(level_id: int) -> int:
	for lv: Dictionary in LEVELS:
		if int(lv["level"]) == level_id:
			return int(lv.get("pass_pct", DEFAULT_PASS_PCT))
	return DEFAULT_PASS_PCT

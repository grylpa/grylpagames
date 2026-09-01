class_name WerisLevelConfig

# Per-level configuration for Weris.
#
# Everything the level varies lives HERE, not in a `match level:` ladder inside level.gd. This file
# used to state only `rounds`, and nothing read it except the menu slider's LEVELS.size() — the real
# numbers were in the ladder. One place, or the two drift.
#
# grid_cols/rows  the crowd the target hides in. 2x2 up to 5x4
# rounds          correct answers needed to advance
# study_ms        how long the target's face is shown before the crowd appears
# find_ms         how long the player has to find them before it counts as a miss. This used to be
#                 a single WerisG.find_time_sec of 30 s for every level — the same generous window
#                 whether the crowd was four faces or twenty, so the early levels had no pressure
#                 at all and the number never taught anything. The top bar counts it down.

const LEVELS: Array = [
	{"level": 1, "grid_cols": 2, "grid_rows": 2, "rounds": 10, "study_ms": 5000, "find_ms": 15000},
	{"level": 2, "grid_cols": 3, "grid_rows": 2, "rounds": 10, "study_ms": 4000, "find_ms": 14000},
	{"level": 3, "grid_cols": 3, "grid_rows": 3, "rounds": 10, "study_ms": 3000, "find_ms": 13000},
	{"level": 4, "grid_cols": 4, "grid_rows": 3, "rounds": 10, "study_ms": 3000, "find_ms": 12000},
	{"level": 5, "grid_cols": 4, "grid_rows": 4, "rounds": 10, "study_ms": 2000, "find_ms": 11000},
	{"level": 6, "grid_cols": 5, "grid_rows": 4, "rounds": 15, "study_ms": 2000, "find_ms": 10000},
]

const MAX_LEVEL: int = 6

# A level past the end of the table plays the last one again rather than crashing, which is what the
# old ladder did with its unmatched `match` — it simply left the previous level's values in place.
static func get_level(level_id: int) -> Dictionary:
	for lv: Dictionary in LEVELS:
		if int(lv["level"]) == level_id:
			return lv
	return LEVELS[LEVELS.size() - 1]

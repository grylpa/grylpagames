class_name FriendsLevelConfig

# Per-level configuration for Friends.
#
# Everything the level varies lives HERE, not in a `match level:` ladder inside level.gd. This file
# used to state only `rounds`, and nothing read it except the menu slider's LEVELS.size() — the real
# numbers were in a ladder, and the two had already drifted apart (the ladder said 5/10/5 rounds
# where this said 10/10/10). One place, or they disagree again.
#
# num_friends   friends to memorize, per row: [top row, bottom row]. [3, 0] is a single row of
#               three; [3, 2] is three above and two below. The second row is what makes the later
#               levels hard — the faces are no longer in one line to scan.
# rounds        correct answers needed to advance
# study_ms      how long the whole cast is shown before the questions start
# answer_ms     how long one face waits for an answer before it counts as a miss

const LEVELS: Array = [
	{"level": 1, "num_friends": [2, 0], "rounds": 10, "study_ms": 60000, "answer_ms": 10000},
	{"level": 2, "num_friends": [3, 0], "rounds": 10, "study_ms": 30000, "answer_ms": 9000},
	{"level": 3, "num_friends": [4, 0], "rounds": 10, "study_ms": 30000, "answer_ms": 8000},
	{"level": 4, "num_friends": [3, 2], "rounds": 20, "study_ms": 30000, "answer_ms": 7500},
	{"level": 5, "num_friends": [3, 3], "rounds": 20, "study_ms": 30000, "answer_ms": 6500},
	{"level": 6, "num_friends": [4, 3], "rounds": 20, "study_ms": 30000, "answer_ms": 5000},
]

const MAX_LEVEL: int = 6

# A level past the end of the table plays the last one again rather than crashing, which is what the
# old ladder did with its unmatched `match` — it simply left the previous level's values in place.
static func get_level(level_id: int) -> Dictionary:
	for lv: Dictionary in LEVELS:
		if int(lv["level"]) == level_id:
			return lv
	return LEVELS[LEVELS.size() - 1]

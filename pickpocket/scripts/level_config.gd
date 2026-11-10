extends Node

# PickpocketLevelConfig autoload. Per-level knobs for Pickpocket.
#
# Fields per level:
#   id, name     level id (monotonic) and its display name
#   cups         cups on the table
#   swaps        swaps in one shuffle
#   swap_ms      how long one swap takes
#   crowd        how many passers-by the street keeps
#   lift_ms      how long the theft takes, from the hand reaching the pocket to the wallet gone
#   cue          the easy theft: a bright wallet, and the victim starts at the touch
#   thief_q      the share of rounds that ask for the THIEF instead of the victim
#   empty_p      the share of rounds with no theft at all (the answer is "No one")
#   fake_p       the share of swaps that are feints: the two cups meet and go back
#   far_thefts   whether a theft may happen among the FAR people, on the sidewalk across the road by
#                the shops. They are small and far off, far harder to notice than the near lane, so
#                the first levels keep every theft on the near side of the road (or at the table).
#   rounds       rounds in the level
#   pass_pct     the share of rounds with BOTH answers right needed to pass. It sits exactly on
#                a rung of the rounds: 66 = 4 of 6, 75 = 6 of 8.

var LEVELS: Array = [
	{"id": 1, "name": "1", "cups": 3, "swaps": 4,  "swap_ms": 760, "crowd": 4, "lift_ms": 1100, "cue": true,  "thief_q": 0.0,  "empty_p": 0.0,  "fake_p": 0.0, "far_thefts": false,  "rounds": 6, "pass_pct": 66},
	{"id": 2, "name": "2", "cups": 3, "swaps": 5,  "swap_ms": 660, "crowd": 5, "lift_ms": 900,  "cue": true,  "thief_q": 0.0,  "empty_p": 0.0,  "fake_p": 0.0, "far_thefts": false,  "rounds": 6, "pass_pct": 66},
	{"id": 3, "name": "3", "cups": 3, "swaps": 6,  "swap_ms": 570, "crowd": 6, "lift_ms": 760,  "cue": false, "thief_q": 0.0,  "empty_p": 0.0,  "fake_p": 0.0, "far_thefts": true,  "rounds": 6, "pass_pct": 66},
	{"id": 4, "name": "4", "cups": 3, "swaps": 7,  "swap_ms": 510, "crowd": 6, "lift_ms": 660,  "cue": false, "thief_q": 0.3,  "empty_p": 0.0,  "fake_p": 0.0, "far_thefts": true,  "rounds": 8, "pass_pct": 75},
	{"id": 5, "name": "5", "cups": 4, "swaps": 7,  "swap_ms": 490, "crowd": 7, "lift_ms": 570,  "cue": false, "thief_q": 0.3,  "empty_p": 0.0,  "fake_p": 0.15, "far_thefts": true, "rounds": 8, "pass_pct": 75},
	{"id": 6, "name": "6", "cups": 4, "swaps": 8,  "swap_ms": 450, "crowd": 7, "lift_ms": 500,  "cue": false, "thief_q": 0.35, "empty_p": 0.15, "fake_p": 0.2, "far_thefts": true,  "rounds": 8, "pass_pct": 75},
	{"id": 7, "name": "7", "cups": 4, "swaps": 9,  "swap_ms": 410, "crowd": 8, "lift_ms": 430,  "cue": false, "thief_q": 0.4,  "empty_p": 0.2,  "fake_p": 0.25, "far_thefts": true, "rounds": 8, "pass_pct": 75},
	{"id": 8, "name": "8", "cups": 5, "swaps": 10, "swap_ms": 380, "crowd": 9, "lift_ms": 370,  "cue": false, "thief_q": 0.4,  "empty_p": 0.2,  "fake_p": 0.3, "far_thefts": true,  "rounds": 8, "pass_pct": 75},
]

func max_level() -> int:
	return int(LEVELS[LEVELS.size() - 1]["id"])

func get_level(id: int) -> Dictionary:
	for lvl in LEVELS:
		if lvl["id"] == id:
			return lvl
	return LEVELS[0]

func level_names() -> Array:
	var names: Array = []
	for lvl in LEVELS:
		names.append(lvl["name"])
	return names

func id_to_index(id: int) -> int:
	for i in LEVELS.size():
		if LEVELS[i]["id"] == id:
			return i
	return 0

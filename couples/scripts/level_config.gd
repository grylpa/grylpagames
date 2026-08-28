extends Node

# CouplesLevelConfig autoload. Per-level knobs for the Couples game (find the one pair of
# identical cards in a grid and tap both).
#
# Fields per level:
#   id             level id (monotonic)
#   name           display name (scores / level label)
#   nc             number of grid columns
#   nr             number of grid rows
#   show_time_sec  seconds a board stays up before it counts as a miss (time to find the pair)
#   gap_sec        blank pause between boards
#   duration_sec   how long the level lasts; the level completes when it elapses

var LEVELS: Array = [
	{"id": 1, "name": "1", "nc": 2, "nr": 2, "show_time_sec": 6.0,  "gap_sec": 1.0, "duration_sec": 40, "pass_pct": 60},
	{"id": 2, "name": "2", "nc": 3, "nr": 2, "show_time_sec": 7.0,  "gap_sec": 1.0, "duration_sec": 50, "pass_pct": 60},
	{"id": 3, "name": "3", "nc": 3, "nr": 3, "show_time_sec": 8.0,  "gap_sec": 0.9, "duration_sec": 60, "pass_pct": 65},
	{"id": 4, "name": "4", "nc": 4, "nr": 3, "show_time_sec": 10.0, "gap_sec": 0.9, "duration_sec": 70, "pass_pct": 70},
	{"id": 5, "name": "5", "nc": 4, "nr": 4, "show_time_sec": 12.0, "gap_sec": 0.8, "duration_sec": 80, "pass_pct": 70},
	{"id": 6, "name": "6", "nc": 5, "nr": 4, "show_time_sec": 12.0, "gap_sec": 0.8, "duration_sec": 80, "pass_pct": 70},
	{"id": 7, "name": "7", "nc": 6, "nr": 4, "show_time_sec": 12.0, "gap_sec": 0.8, "duration_sec": 80, "pass_pct": 75},
	{"id": 8, "name": "8", "nc": 7, "nr": 4, "show_time_sec": 12.0, "gap_sec": 0.8, "duration_sec": 80, "pass_pct": 80},
	{"id": 9, "name": "9", "nc": 8, "nr": 4, "show_time_sec": 15.0, "gap_sec": 0.8, "duration_sec": 100, "pass_pct": 80},
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

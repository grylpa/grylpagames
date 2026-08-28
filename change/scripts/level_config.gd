extends Node

# ChangeLevelConfig autoload. Per-level knobs for the Change game (pay an exact amount by
# dragging coins from a pile into the tray, then press Pay).
#
# Fields per level:
#   id             level id (monotonic)
#   name           display name (scores / level label)
#   coin_size      "big" | "med" | "small" — the base coin size. Each denomination keeps its
#                  own relative size (a dime is smaller than a quarter); this scales them all.
#   board_time_sec seconds a board stays up before it counts as a miss (time to make change)
#   gap_sec        blank pause between boards
#   duration_sec   how long the level lasts; the level completes when it elapses
#   num_coins      total coins in the pile
#   overlap        "none" | "med" | "max" — how much the piled coins cover each other
#                  (none: try no overlap; max: heavy overlap, some coins fully hidden)

var LEVELS: Array = [
	{"id": 1, "name": "1", "coin_size": "big",   "board_time_sec": 30.0, "gap_sec": 1.0, "duration_sec": 60,  "num_coins": 5,  "overlap": "none", "pass_pct": 70},
	{"id": 2, "name": "2", "coin_size": "big",   "board_time_sec": 30.0, "gap_sec": 1.0, "duration_sec": 80,  "num_coins": 6,  "overlap": "none", "pass_pct": 70},
	{"id": 3, "name": "3", "coin_size": "med",   "board_time_sec": 28.0, "gap_sec": 1.0, "duration_sec": 90,  "num_coins": 7,  "overlap": "med", "pass_pct": 75},
	{"id": 4, "name": "4", "coin_size": "med",   "board_time_sec": 28.0, "gap_sec": 1.0, "duration_sec": 100, "num_coins": 8,  "overlap": "med", "pass_pct": 75},
	{"id": 5, "name": "5", "coin_size": "med",   "board_time_sec": 26.0, "gap_sec": 0.9, "duration_sec": 110, "num_coins": 9,  "overlap": "med", "pass_pct": 80},
	{"id": 6, "name": "6", "coin_size": "small", "board_time_sec": 26.0, "gap_sec": 0.9, "duration_sec": 120, "num_coins": 10, "overlap": "max", "pass_pct": 80},
	{"id": 7, "name": "7", "coin_size": "small", "board_time_sec": 24.0, "gap_sec": 0.9, "duration_sec": 140, "num_coins": 12, "overlap": "max", "pass_pct": 80},
	{"id": 8, "name": "8", "coin_size": "small", "board_time_sec": 22.0, "gap_sec": 0.8, "duration_sec": 180, "num_coins": 14, "overlap": "max", "pass_pct": 80},
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

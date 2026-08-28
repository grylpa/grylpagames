class_name DelemfpLevelConfig

# Per-level configuration for Delemfp.
#
# rounds           : rounds played at this level before it advances. A round is one board; the level
#                    is `rounds` of them.
# num_more_packets : extra packets the courier carries
# board_size       : board width/height in tiles
#
# These were two formulas in level.gd (`7 + level * 2` and `max(0, min(7, level - 1))`). A formula
# is fine until one level needs to be different, and then it cannot be — the table can.

const LEVELS: Array = [
	{"level": 1, "rounds": 5, "num_more_packets": 0, "board_size": 9},
	{"level": 2, "rounds": 5, "num_more_packets": 1, "board_size": 11},
	{"level": 3, "rounds": 5, "num_more_packets": 2, "board_size": 13},
	{"level": 4, "rounds": 5, "num_more_packets": 3, "board_size": 15},
	{"level": 5, "rounds": 5, "num_more_packets": 4, "board_size": 17},
	{"level": 6, "rounds": 5, "num_more_packets": 5, "board_size": 19},
	{"level": 7, "rounds": 5, "num_more_packets": 6, "board_size": 21},
	{"level": 8, "rounds": 5, "num_more_packets": 7, "board_size": 23},
	{"level": 9, "rounds": 5, "num_more_packets": 7, "board_size": 25},
]

static func get_level(level_id: int) -> Dictionary:
	for lv: Dictionary in LEVELS:
		if int(lv["level"]) == level_id:
			return lv
	return LEVELS[LEVELS.size() - 1]

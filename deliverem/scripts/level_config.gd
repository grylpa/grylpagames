class_name DeliveremLevelConfig

# Per-level configuration for Deliverem.
#
# rounds           : rounds played at this level before it advances. A round is one board; the level
#                    is `rounds` of them.
# num_more_packets : extra packets each courier carries
# num_more_agents  : extra couriers on the board
# board_size       : board width/height in tiles (less on mobile)
#
# This table used to be an `if level == n:` ladder in level.gd, and the ladder had a bug that only
# an explicit table makes obvious: it set `num_more_agents` at levels 1, 6, 7, 8 and 9 and left it
# alone at 2-5, so the value CARRIED whatever it happened to be. Every level now states its own.

const LEVELS: Array = [
	{"level": 1, "rounds": 5, "num_more_packets": 0, "num_more_agents": 0, "board_size": 17},
	{"level": 2, "rounds": 5, "num_more_packets": 1, "num_more_agents": 0, "board_size": 17},
	{"level": 3, "rounds": 5, "num_more_packets": 2, "num_more_agents": 0, "board_size": 17},
	{"level": 4, "rounds": 5, "num_more_packets": 3, "num_more_agents": 0, "board_size": 17},
	{"level": 5, "rounds": 5, "num_more_packets": 3, "num_more_agents": 0, "board_size": 17},
	{"level": 6, "rounds": 5, "num_more_packets": 0, "num_more_agents": 1, "board_size": 17},
	{"level": 7, "rounds": 5, "num_more_packets": 1, "num_more_agents": 1, "board_size": 17},
	{"level": 8, "rounds": 5, "num_more_packets": 2, "num_more_agents": 2, "board_size": 17},
	{"level": 9, "rounds": 5, "num_more_packets": 3, "num_more_agents": 3, "board_size": 17},
]

static func get_level(level_id: int) -> Dictionary:
	for lv: Dictionary in LEVELS:
		if int(lv["level"]) == level_id:
			return lv
	return LEVELS[LEVELS.size() - 1]

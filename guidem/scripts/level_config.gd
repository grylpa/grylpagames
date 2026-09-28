class_name GuidemLevelConfig

# Per-level configuration for Valet.
#
# rounds           : rounds played at this level before it advances (a level is one board)
# board_size       : board width/height in tiles, before the screen caps it. ODD: the roads run on the
#                    even rows and columns, so an odd size ends every side on a row of short stubs
#                    with the docks beyond them. The cap is made odd too (level.gd,
#                    _fit_board_to_screen).
# dispatch_ms      : time between two cars being sent out
# num_more_packets : extra body segments on each car
# max_speed_scale  : each car's speed is picked from 0.8 up to this
# cars_to_park     : cars to park to finish the level (200 = the last level does not end)
#
# This table used to be an `if level == n:` ladder in level.gd, with the board size computed
# beside it as 7 + 2 * level. Every level now states its own values.

const LEVELS: Array = [
	{"level": 1, "rounds": 1, "board_size": 9,  "dispatch_ms": 5000, "num_more_packets": 0, "max_speed_scale": 1.0, "cars_to_park": 3},
	{"level": 2, "rounds": 1, "board_size": 11, "dispatch_ms": 2500, "num_more_packets": 0, "max_speed_scale": 1.5, "cars_to_park": 3},
	{"level": 3, "rounds": 1, "board_size": 13, "dispatch_ms": 3500, "num_more_packets": 1, "max_speed_scale": 2.0, "cars_to_park": 3},
	{"level": 4, "rounds": 1, "board_size": 15, "dispatch_ms": 2500, "num_more_packets": 1, "max_speed_scale": 2.0, "cars_to_park": 3},
	{"level": 5, "rounds": 1, "board_size": 17, "dispatch_ms": 3000, "num_more_packets": 2, "max_speed_scale": 2.0, "cars_to_park": 3},
	{"level": 6, "rounds": 1, "board_size": 19, "dispatch_ms": 3000, "num_more_packets": 3, "max_speed_scale": 3.0, "cars_to_park": 4},
	{"level": 7, "rounds": 1, "board_size": 21, "dispatch_ms": 3000, "num_more_packets": 4, "max_speed_scale": 3.0, "cars_to_park": 4},
	{"level": 8, "rounds": 1, "board_size": 23, "dispatch_ms": 2000, "num_more_packets": 5, "max_speed_scale": 3.0, "cars_to_park": 5},
	{"level": 9, "rounds": 1, "board_size": 25, "dispatch_ms": 2000, "num_more_packets": 6, "max_speed_scale": 4.0, "cars_to_park": 200},
]

# Past the last level, the last level.
static func get_level(level_id: int) -> Dictionary:
	for lv: Dictionary in LEVELS:
		if int(lv["level"]) == level_id:
			return lv
	return LEVELS[LEVELS.size() - 1]

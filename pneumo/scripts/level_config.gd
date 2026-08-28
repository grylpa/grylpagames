class_name PneumoLevelConfig

# Per-level configuration for Pneumo.
#
# The level's whole shape lives here rather than in a `match level:` ladder inside level.gd, so
# adding or retuning a level is one line in one place.
#
# time_between_dispatches_ms : gap between capsules being sent in
# num_more_packets           : extra body segments on each capsule — how LONG it is
# max_speed_scale            : fastest a capsule may move
# min_deliveries             : capsules that must be landed for the level to be PASSED. Surviving
#                              the clock is not enough on its own: standing back and touching
#                              nothing crashes nothing, and would otherwise promote the player.
# allowed_collisions         : how many crashes the player is allowed before the game is over. The
#                              counter at the top of the screen starts here and ticks DOWN with
#                              every collision; at zero the session ends.
# level_time                 : seconds the level lasts. Surviving to zero IS passing the level —
#                              deliveries are what you score, not a quota to finish.

const LEVELS: Array = [
	{"level": 1, "min_deliveries": 3, "time_between_dispatches_ms": 5000, "num_more_packets": 0, "max_speed_scale": 1.0,
	 "allowed_collisions": 5, "level_time": 90},
	{"level": 2, "min_deliveries": 4, "time_between_dispatches_ms": 2500, "num_more_packets": 0, "max_speed_scale": 1.5,
	 "allowed_collisions": 5, "level_time": 100},
	{"level": 3, "min_deliveries": 5, "time_between_dispatches_ms": 3500, "num_more_packets": 1, "max_speed_scale": 2.0,
	 "allowed_collisions": 4, "level_time": 110},
	{"level": 4, "min_deliveries": 6, "time_between_dispatches_ms": 2500, "num_more_packets": 1, "max_speed_scale": 2.0,
	 "allowed_collisions": 4, "level_time": 120},
	{"level": 5, "min_deliveries": 7, "time_between_dispatches_ms": 3000, "num_more_packets": 2, "max_speed_scale": 2.0,
	 "allowed_collisions": 3, "level_time": 130},
	{"level": 6, "min_deliveries": 8, "time_between_dispatches_ms": 3000, "num_more_packets": 3, "max_speed_scale": 3.0,
	 "allowed_collisions": 3, "level_time": 140},
	{"level": 7, "min_deliveries": 9, "time_between_dispatches_ms": 3000, "num_more_packets": 4, "max_speed_scale": 3.0,
	 "allowed_collisions": 3, "level_time": 150},
	{"level": 8, "min_deliveries": 10, "time_between_dispatches_ms": 2000, "num_more_packets": 5, "max_speed_scale": 3.0,
	 "allowed_collisions": 2, "level_time": 160},
	{"level": 9, "min_deliveries": 11, "time_between_dispatches_ms": 2000, "num_more_packets": 6, "max_speed_scale": 4.0,
	 "allowed_collisions": 2, "level_time": 170},
]

# A level past the end of the table plays the last one again rather than crashing, which is what
# the old ladder did with its `elif level >= 9` catch-all.
static func get_level(level_id: int) -> Dictionary:
	for lv: Dictionary in LEVELS:
		if int(lv["level"]) == level_id:
			return lv
	return LEVELS[LEVELS.size() - 1]

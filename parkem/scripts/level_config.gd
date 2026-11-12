class_name ParkemLevelConfig

# Per-level configuration for Detour (the folder and the class name stay `parkem`/`Parkem*`).
#
# The level's whole shape lives here rather than in a `match level:` ladder inside level.gd, so
# adding or retuning a level is one line in one place.
#
# time_between_dispatches_ms : gap between creatures being sent in
# num_more_packets           : extra tube segments on each creature — how LONG it is
# max_speed_scale            : fastest a creature may move
# num_bombs_to_use           : hazards placed on the board
# allowed_arrivals           : how many creatures may reach their parking spot before the game is
#                              over. The counter at the top of the screen starts here and ticks
#                              DOWN with every creature that parks; at zero the session ends.
# level_time                 : seconds the level lasts. Surviving to zero IS passing the level —
#                              there is nothing else to finish, so the clock is the level.

# THE THEME (2026-11-12), chosen in the main menu (ParkemG.theme, saved with the settings): the floor
# the creatures walk and what it lies in. LOOK_COURTYARD an old courtyard (mossy paving on a lawn with
# garden bushes, leaves and weeds about), LOOK_DUNGEON a dungeon (dark slabs with torchlight between
# dressed-stone walls). Random picks one for every board. ParkemG.look is the CURRENT board's (settled in
# create_board); pipe.gd and level.gd read it. A new theme is one more entry here (before Random), its
# floor in flagstone.gdshader and its surroundings in level.gd _fit_ground_to_board.
const LOOK_COURTYARD: int = 0       # (= flagstone.gdshader floor_style 0)
const LOOK_DUNGEON: int = 2         # (= floor_style 2)
const LOOK_RANDOM: int = -1
const DEFAULT_THEME: int = LOOK_RANDOM
const REAL_LOOKS: Array = [LOOK_DUNGEON, LOOK_COURTYARD]
const THEMES: Array = [
	{"look": LOOK_DUNGEON, "name": "Dungeon"},
	{"look": LOOK_COURTYARD, "name": "Courtyard"},
	{"look": LOOK_RANDOM, "name": "Random"},
]

static func theme_names() -> Array:
	var out: Array = []
	for t: Dictionary in THEMES:
		out.append(t["name"])
	return out

static func theme_index(look: int) -> int:
	for i in THEMES.size():
		if int(THEMES[i]["look"]) == look:
			return i
	return 0

const LEVELS: Array = [
	{"level": 1, "time_between_dispatches_ms": 5000, "num_more_packets": 4, "max_speed_scale": 2.0,
	 "num_bombs_to_use": 3, "allowed_arrivals": 6, "level_time": 90},
	{"level": 2, "time_between_dispatches_ms": 3500, "num_more_packets": 2, "max_speed_scale": 2.5,
	 "num_bombs_to_use": 5, "allowed_arrivals": 5, "level_time": 105},
	{"level": 3, "time_between_dispatches_ms": 2500, "num_more_packets": 0, "max_speed_scale": 3.0,
	 "num_bombs_to_use": 6, "allowed_arrivals": 4, "level_time": 120},
	{"level": 4, "time_between_dispatches_ms": 2500, "num_more_packets": 0, "max_speed_scale": 3.5,
	 "num_bombs_to_use": 7, "allowed_arrivals": 4, "level_time": 135},
	{"level": 5, "time_between_dispatches_ms": 2000, "num_more_packets": 0, "max_speed_scale": 4.0,
	 "num_bombs_to_use": 8, "allowed_arrivals": 3, "level_time": 150},
]

# A level past the end of the table plays the last one again rather than crashing, which is what
# the old ladder did with its `elif level == 5` fall-through.
static func get_level(level_id: int) -> Dictionary:
	for lv: Dictionary in LEVELS:
		if int(lv["level"]) == level_id:
			return lv
	return LEVELS[LEVELS.size() - 1]

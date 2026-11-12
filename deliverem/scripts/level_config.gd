class_name DeliveremLevelConfig

# Per-level configuration for Dispatch.
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

# THE THEME (2026-11-12), chosen in the main menu (DeliveremG.theme, saved with the settings): the weather and
# the hour the roads lie in. LOOK_DAY the roads as they were; LOOK_NIGHT a dark cool lawn, darker asphalt
# and streetlights casting warm pools (level.gd StreetLamp); LOOK_RAIN an overcast lawn, wet asphalt
# with puddles (asphalt.gdshader `weather`), falling rain and ripples on the roads (level.gd RainFX).
# Random picks one for every board. DeliveremG.look is the CURRENT board's (settled in create_board); pipe.gd,
# level.gd and the shader read it. A new theme: one more entry here (before Random) and its look there.
const LOOK_DAY: int = 0
const LOOK_NIGHT: int = 1
const LOOK_RAIN: int = 2
const LOOK_RANDOM: int = -1
const DEFAULT_THEME: int = LOOK_RANDOM
const REAL_LOOKS: Array = [LOOK_DAY, LOOK_NIGHT, LOOK_RAIN]
const THEMES: Array = [
	{"look": LOOK_DAY, "name": "Day"},
	{"look": LOOK_NIGHT, "name": "Night"},
	{"look": LOOK_RAIN, "name": "Rain"},
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

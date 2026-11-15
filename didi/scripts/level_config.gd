class_name DidiLevelConfig

# Level parameters for Pinpoint (the stakeout -- see level.gd's header).
# flash_ms:            the lightning's STARTING length: the courier's umbrella and the lookout are shown
#                      together for this long. It then ADAPTS (level.gd's staircase): shorter after
#                      three fully right answers in a row, longer after a miss, between 34 ms and
#                      1.6x this. (It replaced center_ms / periph_ms, the shape and the dot shown one
#                      after the other.)
# clutter:             passers-by in dark coats glimpsed in the same flash, on the lookout's ring
# num_same:            how many of the 8 corners have an umbrella with the courier's print
#                      (always including the lookout's corner)
# num_options:         people (umbrellas) at each spot, 2 or 3, queued down its street (3 at most, so the
#                      queues stay on screen; it was 4 on levels 7-8). NEVER 1: with one per spot the tap
#                      only answers WHERE, and the center item is no longer needed -- the research
#                      task always asks for both (the center item from two, the place from eight).
#                      Tried at levels 1-2 and taken back the same day (2026-11-15).
# rotate:              whether the corner umbrellas may be turned differently from the courier's. Off
#                      until level 6: a turned "half" or "stripes" print looks like a different one.
# two_colors:          whether a canopy may be two colors (its print in the second)
# same_color_alts:     every umbrella at the spots shares the courier's colors: the print alone tells.
#                      OFF at level 1: the decoy is a CLEARLY different umbrella (another color as
#                      well), the research's starting stage ("a car or a truck"). With num_same 8 a
#                      matching umbrella stands at every spot, exactly the research's two answers.
# rounds:              fully right rounds (right umbrella AND right corner) to finish the level
# time_to_consider_fail: ms to answer before the round counts as missed

const MAX_LEVEL: int = 8

const LEVELS: Array = [
	{"id": 1, "flash_ms": 500, "clutter": 0,  "num_same": 8, "num_options": 2, "rotate": false, "two_colors": false, "same_color_alts": false, "rounds": 10, "time_to_consider_fail": 6000},
	{"id": 2, "flash_ms": 450, "clutter": 0,  "num_same": 8, "num_options": 2, "rotate": false, "two_colors": false, "same_color_alts": true,  "rounds": 15, "time_to_consider_fail": 5500},
	{"id": 3, "flash_ms": 380, "clutter": 2,  "num_same": 5, "num_options": 2, "rotate": false, "two_colors": false, "same_color_alts": true,  "rounds": 20, "time_to_consider_fail": 5000},
	{"id": 4, "flash_ms": 320, "clutter": 4,  "num_same": 5, "num_options": 3, "rotate": false, "two_colors": false, "same_color_alts": true,  "rounds": 20, "time_to_consider_fail": 4500},
	{"id": 5, "flash_ms": 270, "clutter": 4,  "num_same": 4, "num_options": 3, "rotate": false, "two_colors": true,  "same_color_alts": true,  "rounds": 20, "time_to_consider_fail": 4000},
	{"id": 6, "flash_ms": 230, "clutter": 6,  "num_same": 5, "num_options": 3, "rotate": true,  "two_colors": true,  "same_color_alts": true,  "rounds": 20, "time_to_consider_fail": 3500},
	{"id": 7, "flash_ms": 190, "clutter": 8,  "num_same": 5, "num_options": 3, "rotate": true,  "two_colors": true,  "same_color_alts": true,  "rounds": 20, "time_to_consider_fail": 3000},
	{"id": 8, "flash_ms": 160, "clutter": 10, "num_same": 6, "num_options": 3, "rotate": true,  "two_colors": true,  "same_color_alts": true,  "rounds": 10, "time_to_consider_fail": 2500},
]

static func get_level(id: int) -> Dictionary:
	for lvl in LEVELS:
		if lvl["id"] == id:
			return lvl
	return LEVELS[0]

static func level_names() -> Array:
	var names: Array = []
	for lvl in LEVELS:
		names.append("Level %d" % lvl["id"])
	return names

static func id_to_index(id: int) -> int:
	for i in LEVELS.size():
		if LEVELS[i]["id"] == id:
			return i
	return 0

static func level_header(id: int) -> String:
	var lvl: Dictionary = get_level(id)
	return "L%d: flash from %d ms" % [id, lvl["flash_ms"]]

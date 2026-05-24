class_name DidiLevelConfig

# Level parameters for DIDI.
# center_ms:           how long the central shape is shown before auto-hiding
# periph_ms:           how long the peripheral flash is visible
# num_same:            how many of the 8 direction clusters show the correct shape
#                      (always includes the true correct direction)
# num_options:         how many shape choices appear at each direction cluster (2, 3, or 4)
#                        2 → pair arranged perpendicular to inward axis
#                        3 → triangle: one outer + two inner (closer to center)
#                        4 → diamond: outer/inner/left/right
# two_colors:          whether the shape may use split left/right colors
# same_color_alts:     all clusters share the model color; shape texture alone distinguishes
# rounds:              fully-correct rounds (correct shape AND direction) to advance
# time_to_consider_fail: ms before auto-fail if no answer given

const MAX_LEVEL: int = 8

const LEVELS: Array = [
	{"id": 1, "center_ms": 700, "periph_ms": 200, "num_same": 3, "num_options": 2, "two_colors": false, "same_color_alts": true,  "rounds": 10,  "time_to_consider_fail": 6000},
	{"id": 2, "center_ms": 600, "periph_ms": 150, "num_same": 3, "num_options": 2, "two_colors": false, "same_color_alts": true,  "rounds": 15,  "time_to_consider_fail": 5500},
	{"id": 3, "center_ms": 500, "periph_ms": 100, "num_same": 3, "num_options": 3, "two_colors": false, "same_color_alts": true,  "rounds": 20,  "time_to_consider_fail": 5000},
	{"id": 4, "center_ms": 400, "periph_ms": 80,  "num_same": 3, "num_options": 3, "two_colors": false, "same_color_alts": true,  "rounds": 20,  "time_to_consider_fail": 4500},
	{"id": 5, "center_ms": 350, "periph_ms": 70,  "num_same": 4, "num_options": 3, "two_colors": true,  "same_color_alts": true,  "rounds": 20,  "time_to_consider_fail": 4000},
	{"id": 6, "center_ms": 300, "periph_ms": 60,  "num_same": 4, "num_options": 4, "two_colors": true,  "same_color_alts": true,  "rounds": 20,  "time_to_consider_fail": 3500},
	{"id": 7, "center_ms": 250, "periph_ms": 50,  "num_same": 5, "num_options": 4, "two_colors": true,  "same_color_alts": true,  "rounds": 20, "time_to_consider_fail": 3000},
	{"id": 8, "center_ms": 200, "periph_ms": 40,  "num_same": 6, "num_options": 4, "two_colors": true,  "same_color_alts": true,  "rounds": 10, "time_to_consider_fail": 2500},
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
	return "L%d: Ctr %dms / Per %dms" % [id, lvl["center_ms"], lvl["periph_ms"]]

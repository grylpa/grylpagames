extends Node

const MAX_LEVEL: int = 8

# Level parameters for DDOOO.
# center_ms:  how long the central item (model) is shown before auto-hiding
# periph_ms:  how long the peripheral flash is visible
# num_alts:   how many alternative choices appear for the central task
# two_colors:      whether the central item may show split colors (advanced levels only)
# same_color_alts: all alternatives share the model's colors; player must distinguish by shape
# rounds:          number of fully-correct rounds (center + periphery) to advance
const LEVELS: Array = [
	{"id": 1, "center_ms": 700, "periph_ms": 200, "num_alts": 2, "two_colors": false, "same_color_alts": false, "rounds": 5},
	{"id": 2, "center_ms": 600, "periph_ms": 150, "num_alts": 2, "two_colors": false, "same_color_alts": false, "rounds": 6},
	{"id": 3, "center_ms": 500, "periph_ms": 150, "num_alts": 2, "two_colors": false, "same_color_alts": true, "rounds": 6},
	{"id": 4, "center_ms": 400, "periph_ms": 100, "num_alts": 2, "two_colors": false, "same_color_alts": true, "rounds": 8},
	{"id": 5, "center_ms": 300, "periph_ms": 100, "num_alts": 2, "two_colors": true,  "same_color_alts": true,  "rounds": 8},
	{"id": 6, "center_ms": 250, "periph_ms": 50,  "num_alts": 2, "two_colors": true,  "same_color_alts": true,  "rounds": 10},
	{"id": 7, "center_ms": 200, "periph_ms": 30,  "num_alts": 3, "two_colors": true,  "same_color_alts": true,  "rounds": 10},
	{"id": 8, "center_ms": 150, "periph_ms": 20,  "num_alts": 3, "two_colors": true,  "same_color_alts": true,  "rounds": 999},
]

func get_level(id: int) -> Dictionary:
	for lvl in LEVELS:
		if lvl["id"] == id:
			return lvl
	return LEVELS[0]

func level_names() -> Array:
	var names: Array = []
	for lvl in LEVELS:
		names.append("Level %d" % lvl["id"])
	return names

func id_to_index(id: int) -> int:
	for i in LEVELS.size():
		if LEVELS[i]["id"] == id:
			return i
	return 0

func level_header(id: int) -> String:
	var lvl: Dictionary = get_level(id)
	return "L%d: Ctr %dms / Per %dms" % [id, lvl["center_ms"], lvl["periph_ms"]]

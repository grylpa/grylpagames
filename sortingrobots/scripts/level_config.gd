extends Node

# window_dur: seconds the highlight window stays open per judgment
# belt_spd: pixels/second the conveyor scrolls
const LEVELS: Array = [
	{"id": 1, "name": "Green",  "left": "digit",    "right": "square",     "hide_after": 6, "rounds": 10, "window_dur": 3.0, "belt_spd": 65},
	{"id": 2, "name": "Blue",   "left": "even_odd", "right": "vowel",      "hide_after": 5, "rounds": 12, "window_dur": 2.6, "belt_spd": 70},
	{"id": 3, "name": "Red",    "left": "prime",    "right": "filled",     "hide_after": 4, "rounds": 12, "window_dur": 2.3, "belt_spd": 75},
	{"id": 4, "name": "Cyan",   "left": "stroop",   "right": "color_shape","hide_after": 3, "rounds": 15, "window_dur": 2.0, "belt_spd": 80},
	{"id": 5, "name": "Orange", "left": "lines",    "right": "hollow",   "hide_after": 2, "rounds": 15, "window_dur": 1.7, "belt_spd": 85},
]

const LEVEL_PROGRESSION_ORDER: Array = [1, 2, 1, 2, 3, 4, 5, 3, 4, 5]

func get_level(id: int) -> Dictionary:
	for lvl in LEVELS:
		if lvl["id"] == id:
			return lvl
	return {}

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

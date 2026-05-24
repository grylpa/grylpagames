extends Node

# Each level definition:
# id, name, left modality key, right modality key, rounds_before_hide, num_rounds
# possible modalities: digit, square, even_odd, vowel, prime, convex, stroop, color_shape, lines
const LEVELS: Array = [
	{"id": 1, "name": "Green",  "left": "digit",    "right": "square",      "hide_after": 6, "rounds": 10},
	{"id": 2, "name": "Blue",    "left": "even_odd", "right": "vowel",        "hide_after": 5, "rounds": 12},
	{"id": 3, "name": "Red",  "left": "prime",    "right": "convex",       "hide_after": 4, "rounds": 12},
	{"id": 4, "name": "Cyan",  "left": "stroop",   "right": "color_shape",  "hide_after": 3, "rounds": 15},
	{"id": 5, "name": "Orange",  "left": "lines",    "right": "even_odd",     "hide_after": 2, "rounds": 15},
]

# Default level play order — may repeat levels; driver code inserts repeats for poorly-done levels
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

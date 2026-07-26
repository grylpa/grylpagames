extends Node

# num_belts: 1 or 2 (how many rules to identify per question round)
# belt_spd: pixels per second
# robot_answer_time: seconds until robot acts on each highlighted item
# min_examples: min items per belt rule shown before asking the question
const LEVELS: Array = [
	{"id": 1, "name": "Simple",  "left": "digit",    "right": "square",   "num_belts": 1, "belt_spd": 55.0, "robot_answer_time": 1.8, "min_examples": 4, "rounds": 3, "num_options": 3},
	{"id": 2, "name": "Even",    "left": "even_odd", "right": "vowel",    "num_belts": 1, "belt_spd": 60.0, "robot_answer_time": 1.5, "min_examples": 4, "rounds": 3, "num_options": 3},
	{"id": 3, "name": "Two",     "left": "digit",    "right": "vowel",    "num_belts": 2, "belt_spd": 60.0, "robot_answer_time": 1.5, "min_examples": 4, "rounds": 3, "num_options": 4},
	{"id": 4, "name": "Tricky",  "left": "prime",    "right": "filled",   "num_belts": 1, "belt_spd": 65.0, "robot_answer_time": 1.3, "min_examples": 5, "rounds": 4, "num_options": 4},
	{"id": 5, "name": "Expert",  "left": "lines",    "right": "hollow", "num_belts": 2, "belt_spd": 70.0, "robot_answer_time": 1.2, "min_examples": 5, "rounds": 4, "num_options": 5},
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

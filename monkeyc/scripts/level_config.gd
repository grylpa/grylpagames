extends Node

# num_belts: 1 or 2 (how many rules to identify per question round)
# belt_spd: pixels per second
# min_examples: min items per belt rule shown before asking the question
# num_options: how many multiple-choice options to offer (capped at the pool size)
# robot_answer_time: seconds the ✓/✗ answer is shown before the robot takes the item (take always
#   lands between h/2 and 3h/4; longer = answer appears sooner/shown longer = easier)
#
# rules: the pool of rule keys allowed for this level. Each round picks the shown attributes AND the
#   multiple-choice options from this pool, so the rules vary round to round (bigger pool = harder,
#   less predictable). Need at least 2. For 1 belt one picked rule is the hidden rule and the other
#   is a decoy attribute; for 2 belts both picked rules are hidden (one per belt).
#
#   An EMPTY list ([]) means "use every rule below" — handy for a free-for-all level.
#   Overlapping rules may safely sit in the same pool: the picker only ever shows a legal pair.
# Available rule keys (choose any for a level's "rules" pool):
#   "digit"        — Is it a digit?               (digits vs letters)
#   "square"       — Is it a square?              (■ vs other shapes)
#   "even_odd"     — Is it even? / Is it odd?     (random each pick)
#   "vowel"        — Is it a vowel?               (vowels vs consonants)
#   "prime"        — Is it prime?                 (prime vs non-prime numbers)
#   "filled"       — Is it a filled shape?        (■●▲★ vs □○△☆)
#   "hollow"       — Is it a hollow shape?        (□○△☆ vs ■●▲★)
#   "stroop"       — Color = text color?          (word/ink match)
#   "color_shape"  — Shape is blue or red?        (colored shapes)
#   "lines"        — Letter is straight lines?    (AEFHIKLMNTVWXYZ vs curved)
# NOTE: "square" overlaps with "filled"/"hollow" (a ■ is both square AND filled) — avoid putting
#   "square" in the same pool as "filled"/"hollow" (they are never paired or co-offered anyway).
const LEVELS: Array = [
	{"id": 1, "name": "1", "rules": ["digit", "square"],                                            "num_belts": 1, "belt_spd": 55.0, "robot_answer_time": 5.0, "min_examples": 4, "rounds": 3, "num_options": 2},
	{"id": 2, "name": "2", "rules": ["even_odd", "vowel", "hollow"],                                "num_belts": 1, "belt_spd": 60.0, "robot_answer_time": 2.6, "min_examples": 4, "rounds": 3, "num_options": 3},
	{"id": 3, "name": "3", "rules": ["hollow", "vowel", "even_odd", "square"],                      "num_belts": 2, "belt_spd": 60.0, "robot_answer_time": 1.4, "min_examples": 4, "rounds": 3, "num_options": 4},
	{"id": 4, "name": "4", "rules": ["prime", "filled", "vowel", "lines", "color_shape"],           "num_belts": 1, "belt_spd": 65.0, "robot_answer_time": 1.2, "min_examples": 5, "rounds": 4, "num_options": 4},
	{"id": 5, "name": "5", "rules": ["lines", "hollow", "prime", "color_shape", "stroop", "vowel"], "num_belts": 2, "belt_spd": 70.0, "robot_answer_time": 1.0, "min_examples": 5, "rounds": 4, "num_options": 5},
	{"id": 6, "name": "6", "rules": [],                                                             "num_belts": 2, "belt_spd": 70.0, "robot_answer_time": 1.0, "min_examples": 5, "rounds": 4, "num_options": 5},
]

# LEVEL_PROGRESSION_ORDER: the level play order; may repeat ids. When the list runs out it
#   cycles back to the start. End the list with -1 instead to REPEAT THE LAST LEVEL forever
#   (e.g. [1, 2, 3, 4, 5, -1] plays 1..5 then stays on 5). -1 is a sentinel, never a level id.
const LEVEL_PROGRESSION_ORDER: Array = [1, 2, 3, 4, 5, 3, 4, 5, 6, -1]

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

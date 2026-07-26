extends Node

# window_dur: seconds the highlight window stays open per judgment
# belt_spd: pixels/second the conveyor scrolls
# hide_after: rounds after which the rule labels are hidden
#
# rules: the pool of rule keys allowed for this level. The two shown rules are picked from this
#   pool at RANDOM each time the level loads, so which rules appear — and which belt each one
#   lands on — varies from play to play (bigger pool = less predictable). Need at least 2.
#
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
# NOTE: "square" overlaps with "filled"/"hollow" (a ■ is both square AND filled) — they are never
#   shown together as the two rules, so a pool may safely contain all of them.
const LEVELS: Array = [
	{"id": 1, "name": "Green",  "rules": ["digit", "square"],                                            "hide_after": 6, "rounds": 10, "window_dur": 3.0, "belt_spd": 65},
	{"id": 2, "name": "Blue",   "rules": ["even_odd", "vowel", "hollow"],                                "hide_after": 5, "rounds": 12, "window_dur": 2.6, "belt_spd": 70},
	{"id": 3, "name": "Red",    "rules": ["hollow", "even_odd", "vowel", "square"],                      "hide_after": 4, "rounds": 12, "window_dur": 2.3, "belt_spd": 75},
	{"id": 4, "name": "Cyan",   "rules": ["prime", "filled", "vowel", "lines", "color_shape"],      	 "hide_after": 3, "rounds": 15, "window_dur": 2.0, "belt_spd": 80},
	{"id": 5, "name": "Orange", "rules": ["lines", "hollow", "prime", "color_shape", "stroop", "vowel"], "hide_after": 2, "rounds": 15, "window_dur": 1.7, "belt_spd": 85},
]

const LEVEL_PROGRESSION_ORDER: Array = [1, 2, 3, 4, 5, 3, 4, 5]

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

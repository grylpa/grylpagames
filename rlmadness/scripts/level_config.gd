extends Node

# Each level definition:
# id, name, rules pool, hide_after (rounds before the rule labels are hidden), rounds
#
# rules: the pool of rule keys allowed for this level. The two shown rules are picked from this
#   pool at RANDOM each time the level loads, so which rules appear — and which side each one
#   lands on — varies from play to play (bigger pool = less predictable). Need at least 2.
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
# NOTE: "square" overlaps with "filled"/"hollow" (a ■ is both square AND filled) — they are never
#   shown together as the two rules, so a pool may safely contain all of them.
const LEVELS: Array = [
	{"id": 1, "name": "1", "rules": ["digit", "square"],                                            "hide_after": 6, "rounds": 10},
	{"id": 2, "name": "2", "rules": ["even_odd", "vowel", "hollow"],                                "hide_after": 5, "rounds": 12},
	{"id": 3, "name": "3", "rules": ["hollow", "even_odd", "vowel", "square"],                      "hide_after": 4, "rounds": 12},
	{"id": 4, "name": "4", "rules": ["prime", "filled", "vowel", "lines", "color_shape"],      	    "hide_after": 3, "rounds": 15},
	{"id": 5, "name": "5", "rules": ["lines", "hollow", "prime", "color_shape", "stroop", "vowel"], "hide_after": 2, "rounds": 15},
	{"id": 6, "name": "6", "rules": [],                                                             "hide_after": 2, "rounds": 15},
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

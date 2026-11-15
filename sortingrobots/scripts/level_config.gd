extends Node

# QUALITY CONTROL (2026-11-15): parcels pass through a scanner gate on each belt; tap it to grab the one
# at its line when it passes that belt's rule, or let it ride (see level.gd).
# belt_spd: the belts' STARTING speed, in pixels per second for a desktop-sized parcel (scaled to the
#   parcel's size, so a phone runs at the same pace). It then adapts: faster after three right in a
#   row, slower after a miss, between 0.65x and 2.1x.
# hide_after: judgments after which the rule labels are hidden
# rounds: judgments in a level (every parcel that crosses a scanner is one: grabbed or let ride)
# pass_pct: BALANCED accuracy (matches grabbed and non-matches let ride, averaged; chance is 50).
# swap_sec: 0 = never; else about every this many seconds the two belts trade rules (a banner, the
#   signs up again briefly)
#
# rules: the pool of rule keys allowed for this level. The two shown rules are picked from this
#   pool at RANDOM each time the level loads, so which rules appear — and which belt each one
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
# pass_pct: accuracy (%) needed to move on. Below it the SAME level is played again.
const LEVELS: Array = [
	{"id": 1, "name": "1", "rules": ["digit", "square"],                                            "hide_after": 18, "rounds": 30, "belt_spd": 95,  "swap_sec": 0,  "pass_pct": 65},
	{"id": 2, "name": "2", "rules": ["even_odd", "vowel", "hollow"],                                "hide_after": 15, "rounds": 36, "belt_spd": 105, "swap_sec": 0,  "pass_pct": 65},
	{"id": 3, "name": "3", "rules": ["hollow", "even_odd", "vowel", "square"],                      "hide_after": 12, "rounds": 36, "belt_spd": 115, "swap_sec": 0,  "pass_pct": 70},
	{"id": 4, "name": "4", "rules": ["prime", "filled", "vowel", "lines", "color_shape"],            "hide_after": 9,  "rounds": 45, "belt_spd": 120, "swap_sec": 24, "pass_pct": 70},
	{"id": 5, "name": "5", "rules": ["lines", "hollow", "prime", "color_shape", "stroop", "vowel"], "hide_after": 6,  "rounds": 45, "belt_spd": 130, "swap_sec": 20, "pass_pct": 75},
	{"id": 6, "name": "6", "rules": [],                                                             "hide_after": 6,  "rounds": 45, "belt_spd": 130, "swap_sec": 18, "pass_pct": 75},
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

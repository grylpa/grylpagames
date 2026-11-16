extends Node

# TipscalesLevelConfig autoload. Per-level knobs for Tip the Scales.
#
# A LEVEL IS A FEW SHORT PUZZLES, not one long one (the phone's sessions are minutes): the size grows
# with the level, and the deduction gets deeper through the clue mix and the spare clues.
#   id, name     level id and its display name
#   colors       crate colors (rows); crates     crates per color, weighing 1..crates kg
#   mix          a weight per clue type, in puzzle.gd's order:
#                [equal, offset, balanced sum, lighter sum, balanced pairs, between, heavier, heavier sum]
#                MIX_EASY leans on the strong clues (an equal or a balanced sum nearly fixes its crates),
#                MIX_TIPPING on the weak ones (a tipped scale only says which side is heavier)
#   spare        clues added after the minimal set: more to go on
#   k_max        the largest brass weight on an offset clue (a big one nearly fixes both crates)
#   tries        puzzles generated, the one needing the most rounds of deduction kept
#   puzzles      puzzles in the level
#   pass_pct     the share of puzzles that must be solved CLEANLY (at most CLEAN_MISTAKES mistakes and
#                no hint) to move on. With 3 puzzles the rungs are 0, 33, 66, 100.

const MIX_EASY: Array = [4, 4, 3, 1, 1, 1, 1, 0]
const MIX_BALANCED: Array = [2, 2, 2, 2, 2, 2, 2, 1]
const MIX_TIPPING: Array = [1, 1, 2, 2, 2, 3, 4, 2]

const CLEAN_MISTAKES: int = 1

# THE TUTORIAL'S PUZZLE: far smaller and easier than level 1 (the user: "offer a much smaller and easier
# riddle than level 1") -- 2 colors of 3 crates, strong clues only, one spare. Seeded (level.gd
# TUTORIAL_SEED): three scales, one of which ("Gold B = Red B + 2") settles two crates on its own.
const TUTORIAL: Dictionary = {"id": 0, "name": "Tutorial", "colors": 2, "crates": 3, "mix": [4, 4, 3, 1, 0, 1, 1, 0],
	"spare": 1, "k_max": 2, "tries": 1, "puzzles": 1, "pass_pct": 0}

var LEVELS: Array = [
	{"id": 1, "name": "Porter", "colors": 2, "crates": 4, "mix": MIX_EASY,     "spare": 3, "k_max": 3, "tries": 1, "puzzles": 3, "pass_pct": 66},
	{"id": 2, "name": "Clerk", "colors": 3, "crates": 4, "mix": MIX_EASY,     "spare": 2, "k_max": 3, "tries": 1, "puzzles": 3, "pass_pct": 66},
	{"id": 3, "name": "Weigher", "colors": 3, "crates": 5, "mix": MIX_BALANCED, "spare": 2, "k_max": 3, "tries": 2, "puzzles": 3, "pass_pct": 66},
	{"id": 4, "name": "Bookkeeper", "colors": 4, "crates": 5, "mix": MIX_BALANCED, "spare": 1, "k_max": 2, "tries": 2, "puzzles": 3, "pass_pct": 66},
	{"id": 5, "name": "Assayer", "colors": 4, "crates": 6, "mix": MIX_BALANCED, "spare": 0, "k_max": 2, "tries": 2, "puzzles": 3, "pass_pct": 66},
	{"id": 6, "name": "Warden", "colors": 5, "crates": 6, "mix": MIX_TIPPING,  "spare": 0, "k_max": 2, "tries": 3, "puzzles": 3, "pass_pct": 66},
	{"id": 7, "name": "Weighmaster", "colors": 6, "crates": 6, "mix": MIX_TIPPING,  "spare": 0, "k_max": 2, "tries": 3, "puzzles": 3, "pass_pct": 66},
]

func max_level() -> int:
	return int(LEVELS[LEVELS.size() - 1]["id"])

func get_level(id: int) -> Dictionary:
	for lvl in LEVELS:
		if int(lvl["id"]) == id:
			return lvl
	return LEVELS[0]

# THE LEVELS ARE RANKS IN THE WEIGH-HOUSE, from the porter who carries the crates to the weighmaster who
# keeps the scales. Shown as "3 · Weigher" in the menu and "Level 3: Weigher" on the cards.
func level_names() -> Array:
	var names: Array = []
	for lvl in LEVELS:
		names.append("%d · %s" % [int(lvl["id"]), str(lvl["name"])])
	return names

func level_title(id: int) -> String:
	return "Level %d: %s" % [id, str(get_level(id)["name"])]

func id_to_index(id: int) -> int:
	for i in LEVELS.size():
		if int(LEVELS[i]["id"]) == id:
			return i
	return 0

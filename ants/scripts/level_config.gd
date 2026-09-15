extends Node

# AntsLevelConfig autoload. Per-level knobs.
#
# world            world size as a MULTIPLE of the 680-unit screen width: [1,1] is 680x680,
#                  [10,10] is 6800x6800. There is no hard cap -- nothing in the simulation is
#                  sized against the world (see ants/docs/design.md), so a larger number costs
#                  only what the extra ants and the longer trails cost.
# colonies         how many nests. Each has its own scent field and never reads another's.
# speed_scale      [lo, hi] multiplier on Ant.BASE_SPEED (56 px/s). Drawn ONCE per ant at spawn,
#                  so a colony walks at many paces rather than one.
# ants_per_colony  ants in each nest.
# food_piles       piles placed far from the nests (see level.gd _place_food).
# crumbs_per_pile  how many trips it takes to clear one pile.
# stock            how many of each obstacle the player starts holding, in AntObstacle.KINDS
#                  order: [stone, twig, water]. Placing one spends it; picking it up again puts it
#                  back, so the stock is a budget for the whole level rather than a rate.
# time_sec         the level's time budget.
#
# A world wider than the screen cannot be shown whole at a readable scale, so the camera fits the
# world only until an ant would shrink past legibility, and pans from then on (level.gd MIN_ZOOM).
# Level 1 is 1x1 precisely so that the whole world IS the screen and nothing has to be panned to
# watch the trail form.
var LEVELS: Array = [
	{"id": 1, "name": "1", "world": [1.0, 1.0],   "colonies": 1, "speed_scale": [0.80, 1.25],
		"ants_per_colony": 40,  "food_piles": 1, "crumbs_per_pile": 120, "stock": [4, 3, 2], "time_sec": 300},
	{"id": 2, "name": "2", "world": [1.5, 1.5],   "colonies": 1, "speed_scale": [0.80, 1.25],
		"ants_per_colony": 60,  "food_piles": 2, "crumbs_per_pile": 110, "stock": [4, 3, 2], "time_sec": 330},
	{"id": 3, "name": "3", "world": [2.0, 2.0],   "colonies": 2, "speed_scale": [0.75, 1.30],
		"ants_per_colony": 70,  "food_piles": 3, "crumbs_per_pile": 100, "stock": [4, 3, 2], "time_sec": 360},
	{"id": 4, "name": "4", "world": [4.0, 4.0],   "colonies": 3, "speed_scale": [0.75, 1.35],
		"ants_per_colony": 90,  "food_piles": 5, "crumbs_per_pile": 90, "stock": [4, 3, 2],  "time_sec": 420},
	{"id": 5, "name": "5", "world": [10.0, 10.0], "colonies": 4, "speed_scale": [0.70, 1.40],
		"ants_per_colony": 120, "food_piles": 8, "crumbs_per_pile": 80, "stock": [4, 3, 2],  "time_sec": 480},
]

func max_level() -> int:
	return int(LEVELS[LEVELS.size() - 1]["id"])

func get_level(id: int) -> Dictionary:
	for lvl: Dictionary in LEVELS:
		if lvl["id"] == id:
			return lvl
	return LEVELS[0]

func level_names() -> Array:
	var names: Array = []
	for lvl: Dictionary in LEVELS:
		names.append(lvl["name"])
	return names

func id_to_index(id: int) -> int:
	for i in LEVELS.size():
		if LEVELS[i]["id"] == id:
			return i
	return 0

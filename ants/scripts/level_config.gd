extends Node

# AntsLevelConfig autoload. Per-level knobs.
#
# world            world size in SCREENFULS -- [1,1] is one screen wide by one screen tall, [3,3]
#                  is three by three. A screenful is 680 units wide everywhere and as tall as the
#                  usable band (the canvas less the HUD and the button bar), so a world is square
#                  on a desktop and tall on a phone, and fills the space either way. The largest level is 3x3, which is an intention and not a
#                  limit -- nothing in the simulation is sized against the world (see
#                  ants/docs/design.md), so a larger number costs only what the extra ants and the
#                  longer trails cost, and this table is the only place that decides.
# cam_zoom_out     how much wider than 1:1 the camera sees. 1.0 means an ant is drawn at its true
#                  size and a world bigger than the screen is PANNED, never shrunk to fit. The
#                  camera used to fit the world automatically and only stop at a legibility floor,
#                  which was never the intention: on the big levels it silently made every ant
#                  smaller instead of letting the player move around a full-size world.
# colonies         how many nests. Each has its own scent field and never reads another's.
# speed_scale      [lo, hi] multiplier on Ant.BASE_SPEED (56 px/s). Drawn ONCE per ant at spawn,
#                  so a colony walks at many paces rather than one.
# ants_per_colony  ants in each nest.
# food_piles       piles placed far from the nests (see level.gd _place_food).
# crumbs_per_pile  how many trips it takes to clear one pile.
# stock            how many of each obstacle the player starts holding, in AntObstacle.KINDS
#                  order: [stone, twig, water, bait]. Placing one spends it; picking it up again puts it
#                  back, so the stock is a budget for the whole level rather than a rate.
# tell_world       what the level briefing is allowed to tell the player. When false the popup
# tell_colonies    says "Unknown" for that line instead of the number -- the world is meant to be
# tell_food        something you can be sent into knowing less about than you would like.
#                  The ants' speed is always told; it is the one thing you can see for yourself.
# allowance        how many crumbs the colony may get home before you lose. Set from measurement:
#                  an unopposed colony delivers 181/237/520/769/996 over each level's time, so
#                  these ask for the same 58% cut on every level. Difficulty is the number of
#                  routes to cover against a stock that grows more slowly, not a harder sum. It is the score: it
#                  starts here and each crumb through takes one off it, so the number on the HUD is
#                  always "how much more can I afford to let past".
# spray_presses    presses in the can. Many, because one press is a patch and not a wall -- it
#                  bends a column aside for a while and then fades. One press is a full squirt,
#                  bought with a trip through the popup like any other tool, so there are few.
# time_sec         the level's time budget -- survive it with anything left and you win.
#
# Level 1 is 1x1 precisely so that the whole world IS the screen and nothing has to be panned to
# watch the trail form. From level 2 on the world is larger than the screen and is panned by drag.
# Difficulty is ROUTES TO COVER, not ants. A bigger colony just raises the rate past anything nine
# obstacles could answer -- level 5 unopposed was 17.6 crumbs a second, which is not a game -- and
# it was also what made a phone struggle. So the ladder grows the world, the nests and the piles,
# grows the stock more slowly, and keeps the colonies modest.
var LEVELS: Array = [
	{"id": 1, "name": "1", "world": [1.00, 1.00], "cam_zoom_out": 1.0, "colonies": 1, "speed_scale": [0.80, 1.25],
		"ants_per_colony": 40, "food_piles": 1, "crumbs_per_pile": 300, "stock": [4, 3, 2, 2],
		"tell_world": true, "tell_colonies": true, "tell_food": true, "spray_presses": 9, "allowance": 78, "time_sec": 150},
	{"id": 2, "name": "2", "world": [1.25, 1.25], "cam_zoom_out": 1.0, "colonies": 1, "speed_scale": [0.80, 1.25],
		"ants_per_colony": 45, "food_piles": 2, "crumbs_per_pile": 220, "stock": [4, 3, 2, 2],
		"tell_world": true, "tell_colonies": true, "tell_food": true, "spray_presses": 9, "allowance": 100, "time_sec": 150},
	{"id": 3, "name": "3", "world": [1.50, 1.50], "cam_zoom_out": 1.0, "colonies": 2, "speed_scale": [0.75, 1.30],
		"ants_per_colony": 40, "food_piles": 3, "crumbs_per_pile": 220, "stock": [5, 4, 3, 3],
		"tell_world": true, "tell_colonies": true, "tell_food": true, "spray_presses": 9, "allowance": 220, "time_sec": 165},
	{"id": 4, "name": "4", "world": [2.00, 2.00], "cam_zoom_out": 1.0, "colonies": 3, "speed_scale": [0.75, 1.35],
		"ants_per_colony": 35, "food_piles": 4, "crumbs_per_pile": 220, "stock": [6, 5, 3, 3],
		"tell_world": true, "tell_colonies": true, "tell_food": true, "spray_presses": 9, "allowance": 325, "time_sec": 180},
	{"id": 5, "name": "5", "world": [3.00, 3.00], "cam_zoom_out": 1.0, "colonies": 4, "speed_scale": [0.70, 1.40],
		"ants_per_colony": 30, "food_piles": 6, "crumbs_per_pile": 220, "stock": [7, 6, 4, 4],
		"tell_world": true, "tell_colonies": true, "tell_food": true, "spray_presses": 9, "allowance": 420, "time_sec": 200},
]

func max_level() -> int:
	return int(LEVELS[LEVELS.size() - 1]["id"])

# The level after this one, or this one again at the top of the ladder. IDs are read from the table
# rather than assumed to be 1..n, because the table is meant to be editable.
func next_id(id: int) -> int:
	var i: int = id_to_index(id)
	if i < 0 or i >= LEVELS.size() - 1:
		return int(LEVELS[LEVELS.size() - 1]["id"])
	return int(LEVELS[i + 1]["id"])

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

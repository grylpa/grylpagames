extends Node

# PtbitsLevelDefs autoload. Per-level difficulty knobs.
#
# num_colors      how many ball colours / tools / baskets are in play
# gravity_scale   how fast balls fall (RigidBody2D.gravity_scale) — smaller = slower
# spawn_interval  seconds between ball spawns
# max_active      max balls on screen at once
# rounds          balls to resolve (score or miss) before the level is done
# ball_radius     ball radius in px

# NOTE: with ball linear_damp ~3.2 the fall terminal velocity ≈ 980*gravity_scale/3.2.
# These scales give a gentle ~80 px/s (L1) rising to ~140 px/s (L5) fall.
var LEVELS: Array = [
	{"id": 1, "name": "Green",  "num_colors": 2, "gravity_scale": 0.26, "spawn_interval": 3.4, "max_active": 1, "rounds": 6,  "ball_radius": 27},
	{"id": 2, "name": "Blue",   "num_colors": 2, "gravity_scale": 0.30, "spawn_interval": 2.9, "max_active": 2, "rounds": 8,  "ball_radius": 25},
	{"id": 3, "name": "Red",    "num_colors": 3, "gravity_scale": 0.34, "spawn_interval": 2.6, "max_active": 2, "rounds": 10, "ball_radius": 25},
	{"id": 4, "name": "Cyan",   "num_colors": 3, "gravity_scale": 0.40, "spawn_interval": 2.2, "max_active": 3, "rounds": 12, "ball_radius": 23},
	{"id": 5, "name": "Orange", "num_colors": 4, "gravity_scale": 0.46, "spawn_interval": 2.0, "max_active": 3, "rounds": 14, "ball_radius": 23},
]

var LEVEL_PROGRESSION_ORDER: Array = [1, 2, 3, 4, 5]

func get_level(id: int) -> Dictionary:
	for lvl in LEVELS:
		if lvl["id"] == id:
			return lvl
	return LEVELS[0]

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

extends Node

# PtbitsLevelConfig autoload. Per-level difficulty knobs.
#
# num_colors      how many ball colors / tools / baskets are in play
# gravity_scale   how fast balls fall (RigidBody2D.gravity_scale) — smaller = slower
# spawn_interval  seconds between ball spawns
# max_active      max balls on screen at once (10000 = effectively unlimited for now)
# rounds          balls to resolve (score or miss) before the level is done
# ball_radius     ball radius in px
# time_sec        this level's time budget; the clock is (re)set to it at each level start.
#
# time_sec is sized to be enough to bucket EVERY ball: the player maneuvers balls one at a
# time (one tool drag) at ~SEC_PER_BALL each, and all `rounds` balls have appeared by
# rounds*spawn_interval (spawn_interval <= SEC_PER_BALL for every level, so handling time
# dominates). So time_sec ≈ rounds*SEC_PER_BALL + BUFFER  (SEC_PER_BALL=5, BUFFER=10).

# NOTE: with ball linear_damp ~3.2 the fall terminal velocity ≈ 980*gravity_scale/3.2.
# These scales give a gentle ~80 px/s (L1) rising to ~140 px/s (L5) fall.
var LEVELS: Array = [
	{"id": 1, "name": "1", "num_colors": 2, "gravity_scale": 0.26, "spawn_interval": 4.8, "max_active": 10000, "rounds": 6,  "ball_radius": 27, "time_sec": 40, "pass_pct": 50},
	{"id": 2, "name": "2", "num_colors": 2, "gravity_scale": 0.30, "spawn_interval": 3.8, "max_active": 10000, "rounds": 8,  "ball_radius": 25, "time_sec": 50, "pass_pct": 62},
	{"id": 3, "name": "3", "num_colors": 3, "gravity_scale": 0.34, "spawn_interval": 3.6, "max_active": 10000, "rounds": 10, "ball_radius": 25, "time_sec": 60, "pass_pct": 70},
	{"id": 4, "name": "4", "num_colors": 3, "gravity_scale": 0.40, "spawn_interval": 3.2, "max_active": 10000, "rounds": 12, "ball_radius": 23, "time_sec": 70, "pass_pct": 75},
	{"id": 5, "name": "5", "num_colors": 4, "gravity_scale": 0.46, "spawn_interval": 3.0, "max_active": 10000, "rounds": 14, "ball_radius": 23, "time_sec": 80, "pass_pct": 78},
	{"id": 6, "name": "6", "num_colors": 4, "gravity_scale": 0.48, "spawn_interval": 2.0, "max_active": 10000, "rounds": 14, "ball_radius": 23, "time_sec": 80, "pass_pct": 78},
]

func max_level() -> int:
	return int(LEVELS[LEVELS.size() - 1]["id"])

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

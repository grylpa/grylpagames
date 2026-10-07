extends Node

# LighthouseLevelConfig autoload: every per-level value of Lighthouse.
#
# Distances and speeds are in units of a 680-wide sea and scaled to the real one, so a level plays
# the same on a desktop and on a phone.
#
#   obstacles              how many obstacles (rocks, wrecks, cliffs) are in the sea
#   obstacle_size          their typical radius. SMALLER IS HARDER: a small thing caught for a moment
#                          in the beam is harder to remember than a big one
#   beam_turn_deg          the lighthouse beam's turning speed, degrees a second
#   beam_width             the beam's width where it reaches the far edge of the sea (it widens from
#                          the lamp outward); its sides fade gradually
#   boat_light             how far ahead the boat's own light reaches, fading into the dark
#   boat_speed             the boat's speed
#   rounds                 crossings per level
#   round_sec              each round's time limit; a round whose time runs out is lost, and the
#                          level goes on to the next
#   same_sea               true: every round of the level is played on the SAME sea, so what was
#                          seen in one round helps in the next; false: a new sea each round
#   max_crashes            the most crashes the FIRST round can take: the HUD's lifebuoys count them
#                          down, and the crash that reaches the maximum loses the round. On a same-sea
#                          level each later round allows one fewer (never below 1) -- the sea has
#                          been seen; on a new-sea level every round allows the same
#   boats                  how many other boats cross the sea, slowly, each in its own horizontal lane
#                          (left to right or right to left), wrapping round at the edges. 0 for none.
#                          Seen only where light falls; bumping into one is a crash
#
# A level is passed when every round reached the pier. How much faster the crossings got is what
# is measured and charted, not a condition for passing.

const LEVELS: Array = [
	{"id": 1, "name": "1", "obstacles": 6,  "obstacle_size": 34, "beam_turn_deg": 50, "beam_width": 230, "boat_light": 150, "boat_speed": 105, "rounds": 3, "round_sec": 60, "same_sea": true,  "max_crashes": 3, "boats": 0},
	{"id": 2, "name": "2", "obstacles": 8,  "obstacle_size": 30, "beam_turn_deg": 46, "beam_width": 200, "boat_light": 140, "boat_speed": 110, "rounds": 3, "round_sec": 60, "same_sea": true,  "max_crashes": 3, "boats": 0},
	{"id": 3, "name": "3", "obstacles": 10, "obstacle_size": 28, "beam_turn_deg": 42, "beam_width": 180, "boat_light": 130, "boat_speed": 115, "rounds": 3, "round_sec": 65, "same_sea": true,  "max_crashes": 3, "boats": 1},
	{"id": 4, "name": "4", "obstacles": 10, "obstacle_size": 26, "beam_turn_deg": 40, "beam_width": 170, "boat_light": 120, "boat_speed": 120, "rounds": 4, "round_sec": 60, "same_sea": false, "max_crashes": 3, "boats": 1},
	{"id": 5, "name": "5", "obstacles": 12, "obstacle_size": 24, "beam_turn_deg": 36, "beam_width": 160, "boat_light": 110, "boat_speed": 125, "rounds": 4, "round_sec": 65, "same_sea": true,  "max_crashes": 2, "boats": 2},
	{"id": 6, "name": "6", "obstacles": 14, "obstacle_size": 22, "beam_turn_deg": 34, "beam_width": 150, "boat_light": 100, "boat_speed": 130, "rounds": 4, "round_sec": 65, "same_sea": false, "max_crashes": 2, "boats": 2},
	{"id": 7, "name": "7", "obstacles": 16, "obstacle_size": 20, "beam_turn_deg": 30, "beam_width": 140, "boat_light": 95,  "boat_speed": 135, "rounds": 4, "round_sec": 70, "same_sea": true,  "max_crashes": 2, "boats": 3},
	{"id": 8, "name": "8", "obstacles": 18, "obstacle_size": 18, "beam_turn_deg": 28, "beam_width": 130, "boat_light": 90,  "boat_speed": 140, "rounds": 5, "round_sec": 70, "same_sea": false, "max_crashes": 2, "boats": 3},
]

func max_level() -> int:
	return int(LEVELS[LEVELS.size() - 1]["id"])

func get_level(id: int) -> Dictionary:
	for l: Dictionary in LEVELS:
		if int(l["id"]) == id:
			return l
	return LEVELS[0]

func next_id(id: int) -> int:
	for i in LEVELS.size():
		if int(LEVELS[i]["id"]) == id:
			return int(LEVELS[mini(i + 1, LEVELS.size() - 1)]["id"])
	return int(LEVELS[0]["id"])

func level_names() -> Array:
	var out: Array = []
	for l: Dictionary in LEVELS:
		out.append(str(l["name"]))
	return out

func id_to_index(id: int) -> int:
	for i in LEVELS.size():
		if int(LEVELS[i]["id"]) == id:
			return i
	return 0

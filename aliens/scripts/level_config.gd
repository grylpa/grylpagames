extends Node

# AliensLevelConfig autoload. Per-level knobs for the Aliens game: little aliens roam a field and
# walk into the OUTER ring of a target area on their own; the player drags each one either into
# that gate's INNER ring (if it matches the gate's pass) or back out to the hall (if it doesn't).
#
# ---------------------------------------------------------------------------------------------
# AVAILABLE MODALITIES for the "rules" pool. A level lists MODALITIES, not individual rules:
# one modality is drawn per gate and then a random rule from inside it. Because two gates always
# get different modalities, the player is forced to SWITCH ATTENTION between traits rather than
# just compare two values of the same trait — which is the point of the game.
#
#   "eyes"      -> 1 EYE / 2 EYES / 3 EYES     (which eye arrangement)
#   "shape"     -> FAT / THIN                  (FAT = wider than tall, THIN = taller than wide)
#   "antennae"  -> NO ANTENNAE / 1 ANTENNA / 2 ANTENNAE
#   "spots"     -> SPOTTED / NO SPOTS
#   "color"     -> BLUE / RED / GREEN / YELLOW / PURPLE
#
# An EMPTY pool ([]) means "any modality". A pool needs at least `num_areas` entries, or the level
# quietly falls back to the full set.
#
# Which rules a modality can actually pose depends on this level's trait pools: a color rule needs
# its color id in "colors" (and at least 2 colors to choose from); "eyes" needs at least 2 entries
# in "eye_counts"; "antennae" likewise in "antennae_counts"; "spots" needs 0 < spots_chance < 1.
# A modality with nothing usable is silently skipped, so pools can safely over-list.
#
# Fields per level:
#   id                 level id (monotonic)
#   name               display name (level label / scores)
#   level_time_sec     how long the level lasts; it completes when this elapses
#   rules              pool of MODALITY names (see above); [] = any modality
#   num_areas          number of target areas. 1 sits in the middle of the field; 2 go in
#                      OPPOSING corners; 3 and 4 fill the remaining corners. 1..2 is the tuned
#                      range on a phone — 3+ auto-shrinks the aliens.
#   alien_speed        roaming speed in SCREEN WIDTHS PER SECOND (0.13 relaxed .. 0.27 brisk).
#                      0.13 crosses a 680-wide screen in about 8 seconds. An alien heading for an
#                      area walks 1.7x this.
#   alien_size         "big" | "med" | "small" — alien diameter as a fraction of screen width
#                      (0.112 / 0.098 / 0.086), x0.70 off mobile. Shrunk further automatically
#                      if the rings would not otherwise fit the screen.
#   num_free_aliens    how many aliens live on the field at once
#   (Neither ring has a slot count: each simply holds as many aliens as physically fit without
#    overlapping, so both capacities follow from alien_size alone.
#    While an outer ring is full, every alien that walks up to it is turned away = 1 MISS,
#    so enter_chance is the pressure knob.)
#   hide_after_sec     seconds after the level starts before the rule labels turn into "?".
#                      0 = never hide (teaching levels).
#   enter_chance       0..1. EVERY alien wants in: each time it picks a new wander target
#                      (roughly every 1-2s) it rolls this chance to commit to an area and walk
#                      in. Higher = more arrivals = more pressure. Between commits an alien
#                      loiters near the rings rather than wandering the whole field, so the crowd
#                      reads as "queueing up". A short global cooldown stops two aliens
#                      committing on the very same frame.
#   park_patience_sec  a parked alien the player never resolves gives up and leaves after this
#                      many seconds. If it MATCHED the gate's pass this costs a MISS — you let a
#                      valid passenger walk away; if it did not match it costs nothing, since
#                      leaving is what should have happened to it anyway.
#                      0 means it waits FOREVER (not "zero seconds") — the check is skipped.
#   colors             OPTIONAL color-id pool, default [0, 1, 2] (blue, red, green)
#   eye_counts         OPTIONAL eye-count pool, default [1, 2, 3]
#   antennae_counts    OPTIONAL antenna-count pool, default [0, 1, 2]
#   spots_chance       OPTIONAL probability an alien is spotted, default 0.5

const LEVELS: Array = [
	# 1 — teach the loop: one area, color rules only, the rule never hides, roomy ring.
	{"id": 1, "name": "1", "level_time_sec": 70, "rules": ["color"],
	 "num_areas": 1, "alien_speed": 0.145, "alien_size": "big", "num_free_aliens": 9, "hide_after_sec": 0, "enter_chance": 0.16,
	 "park_patience_sec": 30.0},

	# 2 — same shape, but now the rule disappears partway through.
	{"id": 2, "name": "2", "level_time_sec": 80, "rules": ["eyes", "color"],
	 "num_areas": 2, "alien_speed": 0.155, "alien_size": "big", "num_free_aliens": 10, "hide_after_sec": 35, "enter_chance": 0.20,
	 "park_patience_sec": 30.0},

	# 3 — silhouette rules; body shape varies independently of everything else.
	{"id": 3, "name": "3", "level_time_sec": 90, "rules": ["shape", "eyes", "color", "antennae"],
	 "num_areas": 2, "alien_speed": 0.165, "alien_size": "med", "num_free_aliens": 9, "hide_after_sec": 28, "enter_chance": 0.24,
	 "park_patience_sec": 29.0},

	# 4 — TWO areas: two rules to hold at once.
	{"id": 4, "name": "4", "level_time_sec": 100, "rules": ["color", "eyes"],
	 "num_areas": 2, "alien_speed": 0.175, "alien_size": "med", "num_free_aliens": 10, "hide_after_sec": 25, "enter_chance": 0.30,
	 "park_patience_sec": 28.0},

	# 5 — antennae join in; slots tighten to 3, so a ring fills sooner.
	{"id": 5, "name": "5", "level_time_sec": 110,
	 "rules": ["antennae", "eyes", "color", "shape"],
	 "num_areas": 2, "alien_speed": 0.185, "alien_size": "med", "num_free_aliens": 11, "hide_after_sec": 20, "enter_chance": 0.36,
	 "colors": [0, 1, 3], "park_patience_sec": 27.0},

	# 6 — spots added (the weakest trait), rules hide early.
	{"id": 6, "name": "6", "level_time_sec": 120,
	 "rules": ["spots", "eyes", "shape", "antennae", "color"],
	 "num_areas": 2, "alien_speed": 0.205, "alien_size": "med", "num_free_aliens": 12, "hide_after_sec": 14, "enter_chance": 0.42,
	 "colors": [0, 2, 4], "park_patience_sec": 26.0},

	# 7 — wide pool, smaller aliens, brisk arrivals, no patience valve.
	{"id": 7, "name": "7", "level_time_sec": 140,
	 "rules": ["eyes", "shape", "antennae", "spots", "color"],
	 "num_areas": 3, "alien_speed": 0.235, "alien_size": "small", "num_free_aliens": 13, "hide_after_sec": 9, "enter_chance": 0.50,
	 "colors": [0, 1, 3, 4], "park_patience_sec": 25.0},

	# 8 — every usable rule, fast: the ring only empties if the player empties it.
	{"id": 8, "name": "8", "level_time_sec": 170, "rules": [],
	 "num_areas": 4, "alien_speed": 0.265, "alien_size": "small", "num_free_aliens": 14, "hide_after_sec": 6, "enter_chance": 0.60,
	 "colors": [0, 1, 2, 3], "park_patience_sec": 25.0},
]

# LEVEL_PROGRESSION_ORDER: the level play order; may repeat ids. When the list runs out it
#   cycles back to the start. End the list with -1 instead to REPEAT THE LAST LEVEL forever
#   (e.g. [1, 2, 3, -1] plays 1..3 then stays on 3). -1 is a sentinel, never a level id.
const LEVEL_PROGRESSION_ORDER: Array = [1, 2, 3, 4, 5, 4, 5, 6, 7, 8, -1]

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

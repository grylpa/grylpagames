extends Node

# AliensLevelConfig autoload. Per-level knobs for the Aliens game: little aliens roam a field and
# walk into the OUTER ring of a target area on their own; the player drags each one either into
# that area's INNER ring (if it matches the area's rule) or back out to the field (if it doesn't).
#
# ---------------------------------------------------------------------------------------------
# AVAILABLE RULE KEYS for the "rules" pool (the label shown on the area is in parentheses):
#
#   EYES        "eyes1"    (1 EYE)          one big central eye
#               "eyes2"    (2 EYES)         a horizontal pair
#               "eyes3"    (3 EYES)         a triangle of three
#   HEIGHT      "tall"     (TALL)           taller than it is wide  (always, at any girth)
#               "short"    (SHORT)          wider than it is tall   (always, at any girth)
#   GIRTH       "fat"      (WIDE)           a wide body
#               "thin"     (NARROW)         a narrow body
#   ANTENNAE    "ant0"     (NO ANTENNAE)
#               "ant1"     (1 ANTENNA)
#               "ant2"     (2 ANTENNAE)
#   SPOTS       "spots"    (SPOTTED)        darker dots on the lower body
#               "nospots"  (NO SPOTS)
#   COLOR       "blue"     (BLUE)           color id 0
#               "red"      (RED)            color id 1
#               "green"    (GREEN)          color id 2
#               "yellow"   (YELLOW)         color id 3
#               "purple"   (PURPLE)         color id 4
#
# A level's "rules" list is a POOL: one distinct rule is drawn from it per target area at load
# time, so which rules appear (and which area gets which) varies from play to play. An EMPTY
# pool ([]) means "use every usable rule".
#
# A rule is USABLE only if this level's trait pools can produce both matches and non-matches:
#   a color rule needs its color id in "colors"; "eyesN" needs N in "eye_counts"; "antN" needs N
#   in "antennae_counts"; "spots"/"nospots" need 0 < spots_chance < 1. Unusable rules are
#   silently dropped, so a pool can safely over-list. The pool needs at least `num_areas` usable
#   entries or the level falls back to a safe default trio.
# Two areas never get the same rule, and never get an exact COMPLEMENT pair (tall/short,
# fat/thin, spots/nospots) — that would collapse two judgments into one binary.
# Two DIFFERENT values of the same dimension (BLUE vs RED, 2 EYES vs 3 EYES) are fine and
# actually good: they force a value comparison rather than a mere dimension check.
# Aim for 2..4 colors. With all 5, a color rule matches only 20% of aliens and "push it out"
# becomes almost always the right answer.
#
# NOTE: no confusability table is needed (unlike sortingrobots/monkeyc). An alien is judged only
# against the rule of the area it walked into, so an alien matching both areas' rules is
# harmless — it simply belongs wherever it went.
# ---------------------------------------------------------------------------------------------
#
# Fields per level:
#   id                 level id (monotonic)
#   name               display name (level label / scores)
#   level_time_sec     how long the level lasts; it completes when this elapses
#   rules              pool of rule keys (see above); [] = every usable rule
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
#   (The OUTER ring has no slot count: it simply holds as many aliens as physically fit around
#    it without overlapping. Its capacity therefore follows from alien_size and inner_slots.
#    While a ring is full, every alien that walks up to it is turned away = 1 MISS, so
#    enter_chance is the pressure knob.)
#   inner_slots        places in each INNER ring. Also sets the inner circle's size. 2 is plenty.
#   hide_after_sec     seconds after the level starts before the rule labels turn into "?".
#                      0 = never hide (teaching levels).
#   enter_chance       0..1. EVERY alien wants in: each time it picks a new wander target
#                      (roughly every 1-2s) it rolls this chance to commit to an area and walk
#                      in. Higher = more arrivals = more pressure. Between commits an alien
#                      loiters near the rings rather than wandering the whole field, so the crowd
#                      reads as "queueing up". A short global cooldown stops two aliens
#                      committing on the very same frame.
#   park_patience_sec  a parked alien the player never resolves gives up and leaves after this
#                      many seconds, with NO penalty. 0 = it waits forever (hardest).
#   colors             OPTIONAL color-id pool, default [0, 1, 2] (blue, red, green)
#   eye_counts         OPTIONAL eye-count pool, default [1, 2, 3]
#   antennae_counts    OPTIONAL antenna-count pool, default [0, 1, 2]
#   spots_chance       OPTIONAL probability an alien is spotted, default 0.5

const LEVELS: Array = [
	# 1 — teach the loop: one area, color rules only, the rule never hides, roomy ring.
	{"id": 1, "name": "1", "level_time_sec": 70, "rules": ["blue", "red", "green"],
	 "num_areas": 1, "alien_speed": 0.130, "alien_size": "big", "num_free_aliens": 7, "inner_slots": 2, "hide_after_sec": 0, "enter_chance": 0.16,
	 "park_patience_sec": 30.0},

	# 2 — same shape, but now the rule disappears partway through.
	{"id": 2, "name": "2", "level_time_sec": 80, "rules": ["eyes1", "eyes2", "eyes3"],
	 "num_areas": 1, "alien_speed": 0.145, "alien_size": "big", "num_free_aliens": 8, "inner_slots": 2, "hide_after_sec": 35, "enter_chance": 0.20,
	 "park_patience_sec": 30.0},

	# 3 — silhouette rules; body shape varies independently of everything else.
	{"id": 3, "name": "3", "level_time_sec": 90, "rules": ["tall", "fat", "eyes3", "green"],
	 "num_areas": 1, "alien_speed": 0.160, "alien_size": "med", "num_free_aliens": 9, "inner_slots": 2, "hide_after_sec": 28, "enter_chance": 0.24,
	 "park_patience_sec": 28.0},

	# 4 — TWO areas: two rules to hold at once.
	{"id": 4, "name": "4", "level_time_sec": 100, "rules": ["blue", "red", "eyes2", "eyes3"],
	 "num_areas": 2, "alien_speed": 0.160, "alien_size": "med", "num_free_aliens": 10, "inner_slots": 2, "hide_after_sec": 25, "enter_chance": 0.30,
	 "park_patience_sec": 26.0},

	# 5 — antennae join in; slots tighten to 3, so a ring fills sooner.
	{"id": 5, "name": "5", "level_time_sec": 110,
	 "rules": ["ant0", "ant2", "tall", "eyes1", "yellow"],
	 "num_areas": 2, "alien_speed": 0.185, "alien_size": "med", "num_free_aliens": 11, "inner_slots": 2, "hide_after_sec": 20, "enter_chance": 0.36,
	 "colors": [0, 1, 3], "park_patience_sec": 24.0},

	# 6 — spots added (the weakest trait), rules hide early.
	{"id": 6, "name": "6", "level_time_sec": 120,
	 "rules": ["spots", "eyes3", "thin", "ant1", "purple"],
	 "num_areas": 2, "alien_speed": 0.205, "alien_size": "med", "num_free_aliens": 12, "inner_slots": 2, "hide_after_sec": 14, "enter_chance": 0.42,
	 "colors": [0, 2, 4], "park_patience_sec": 22.0},

	# 7 — wide pool, smaller aliens, brisk arrivals, no patience valve.
	{"id": 7, "name": "7", "level_time_sec": 140,
	 "rules": ["eyes1", "eyes3", "tall", "thin", "ant0", "ant2", "spots", "blue", "yellow"],
	 "num_areas": 2, "alien_speed": 0.235, "alien_size": "small", "num_free_aliens": 13, "inner_slots": 2, "hide_after_sec": 9, "enter_chance": 0.50,
	 "colors": [0, 1, 3, 4], "park_patience_sec": 0.0},

	# 8 — every usable rule, fast: the ring only empties if the player empties it.
	{"id": 8, "name": "8", "level_time_sec": 170, "rules": [],
	 "num_areas": 2, "alien_speed": 0.265, "alien_size": "small", "num_free_aliens": 14, "inner_slots": 2, "hide_after_sec": 6, "enter_chance": 0.60,
	 "colors": [0, 1, 2, 3], "park_patience_sec": 0.0},
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

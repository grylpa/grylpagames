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
#   pass_pct           accuracy (%) needed to move on; below it the SAME level is played again
#   rules              pool of MODALITY names (see above); [] = any modality
#   num_areas          number of target areas. 1 sits in the center of the field; 2 go in
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
#
# ---------------------------------------------------------------------------------------------
# THE INTERFERENCE LAYER. The three fields below are what make the later levels genuinely hard
# rather than merely busy. Each one removes a specific shortcut:
#
#   gate_change_sec    0 = off. Every this-many seconds (+/- jitter) the passes ROTATE between
#                      the gates, and the chips come back up for ~2 s so the new arrangement can
#                      be read. Needs num_areas >= 2.
#                      WHY: without it the rule stops being a rule and becomes a place —
#                      "left = blue" — and recalling a place is nearly free. A rotation voids
#                      every such binding at once, and the old one keeps interfering.
#
#   deny_chance        0..1, an INDEPENDENT roll per gate with no correction afterwards, so the
#                      number means what it says: 0.5 on 4 gates really is ~2 deny gates on
#                      average, and sometimes none at all. A DENY gate boards everything EXCEPT
#                      its pass; its chip reads "NOT SPOTTED" and its rings are tinted warm.
#                      A COMPOUND pass is never denied (see compound_chance).
#                      WHY: it doubles what has to be held per gate — the trait AND its sense.
#
#   compound_chance    0..1, per gate. The pass becomes TWO rules from different modalities
#                      joined by an operator: "1 EYE AND BLUE", "1 EYE OR NOT PURPLE".
#   compound_ops       which operators may be drawn; default all four. Their characters differ:
#                        "and"    both must hold      — rare, so a match is precious
#                        "or"     either will do      — often decidable from one trait alone
#                        "andnot" A but not B         — the sharpest: two traits, opposite senses
#                        "ornot"  A or anything not B — common, so a REJECT is the rare event
#                      WHY: a single pass now spans two traits, so there is no "the trait for
#                      this gate" to settle on — the switch happens inside one decision.
#                      NOTE both atoms always come from DIFFERENT modalities, which is what keeps
#                      the supply system exact (forcing one atom cannot disturb the other).
#
#   priority_every_sec 0 = off. Every this-many seconds one PARKED alien is called to board and
#                      must be resolved within priority_window_sec or it costs a MISS. It is
#                      drawn from a gate other than the last one called whenever possible.
#   priority_window_sec  how long the call stands (default 6; floored at 1.5).
#                      WHY: this is the deepest one. Free choice of what to handle lets the
#                      player work a single gate at a time, and batching a gate removes the
#                      task-switch cost that IS the difficulty. A call from the gate you are not
#                      looking at, on a clock, breaks the batch.

const LEVELS: Array = [
	# 1 — teach the loop: one area, color rules only, the rule never hides, roomy ring.
	{"id": 1, "name": "1", "level_time_sec": 70, "rules": ["color"],
	 "num_areas": 1, "alien_speed": 0.145, "alien_size": "big", "num_free_aliens": 9, "hide_after_sec": 0, "enter_chance": 0.16,
	 "park_patience_sec": 30.0, "pass_pct": 60},

	# 2 — same shape, but now the rule disappears partway through.
	{"id": 2, "name": "2", "level_time_sec": 80, "rules": ["eyes", "color"],
	 "num_areas": 2, "alien_speed": 0.155, "alien_size": "big", "num_free_aliens": 10, "hide_after_sec": 35, "enter_chance": 0.20,
	 "park_patience_sec": 30.0, "pass_pct": 65},

	# 3 — silhouette rules; body shape varies independently of everything else.
	{"id": 3, "name": "3", "level_time_sec": 90, "rules": ["shape", "eyes", "color", "antennae"],
	 "num_areas": 2, "alien_speed": 0.165, "alien_size": "med", "num_free_aliens": 9, "hide_after_sec": 28, "enter_chance": 0.24,
	 "park_patience_sec": 29.0, "pass_pct": 70},

	# 4 — GATE CHANGE arrives. Everything else is held at level 3's settings on purpose: one new
	#     idea at a time, and this is a big one.
	{"id": 4, "name": "4", "level_time_sec": 100, "rules": ["color", "eyes"],
	 "num_areas": 2, "alien_speed": 0.175, "alien_size": "med", "num_free_aliens": 10, "hide_after_sec": 25, "enter_chance": 0.30,
	 "park_patience_sec": 28.0,
	 "gate_change_sec": 34.0, "pass_pct": 70},

	# 5 — NOW BOARDING arrives: a called alien on a clock, so a gate can no longer be worked alone.
	{"id": 5, "name": "5", "level_time_sec": 110,
	 "rules": ["antennae", "eyes", "color", "shape"],
	 "num_areas": 2, "alien_speed": 0.185, "alien_size": "med", "num_free_aliens": 11, "hide_after_sec": 20, "enter_chance": 0.36,
	 "colors": [0, 1, 3], "park_patience_sec": 27.0,
	 "gate_change_sec": 30.0, "priority_every_sec": 19.0, "priority_window_sec": 8.0, "pass_pct": 75},

	# 6 — DENY gates arrive; spots join the pool. Gate change is eased off while the new polarity
	#     is learned, then tightened again from 7.
	{"id": 6, "name": "6", "level_time_sec": 120,
	 "rules": ["spots", "eyes", "shape", "antennae", "color"],
	 "num_areas": 2, "alien_speed": 0.205, "alien_size": "med", "num_free_aliens": 12, "hide_after_sec": 14, "enter_chance": 0.42,
	 "colors": [0, 2, 4], "park_patience_sec": 26.0,
	 "gate_change_sec": 34.0, "deny_chance": 0.5,
	 "priority_every_sec": 18.0, "priority_window_sec": 7.5, "pass_pct": 75},

	# 7 — three gates, all three twists running together.
	{"id": 7, "name": "7", "level_time_sec": 140,
	 "rules": ["eyes", "shape", "antennae", "spots", "color"],
	 "num_areas": 3, "alien_speed": 0.235, "alien_size": "small", "num_free_aliens": 13, "hide_after_sec": 9, "enter_chance": 0.50,
	 "colors": [0, 1, 3, 4], "park_patience_sec": 25.0,
	 "gate_change_sec": 26.0, "deny_chance": 0.5,
	 "priority_every_sec": 15.0, "priority_window_sec": 6.5, "pass_pct": 80},

	# 8 — every usable rule, four gates, fast: the ring only empties if the player empties it.
	{"id": 8, "name": "8", "level_time_sec": 170, "rules": [],
	 "num_areas": 4, "alien_speed": 0.265, "alien_size": "small", "num_free_aliens": 14, "hide_after_sec": 6, "enter_chance": 0.60,
	 "colors": [0, 1, 2, 3], "park_patience_sec": 25.0,
	 "gate_change_sec": 22.0, "deny_chance": 0.5,
	 "priority_every_sec": 13.0, "priority_window_sec": 6.0, "pass_pct": 80},

	# 9 — COMPOUND passes arrive: two traits in one pass. Back to 2 gates and a slower clock, and
	#     deny is off — one pass now spans two traits, which is quite enough to be going on with.
	#     Only AND and OR at first: they read the most naturally.
	{"id": 9, "name": "9", "level_time_sec": 130,
	 "rules": ["color", "eyes", "shape", "antennae"],
	 "num_areas": 2, "alien_speed": 0.195, "alien_size": "med", "num_free_aliens": 11, "hide_after_sec": 22, "enter_chance": 0.36,
	 "colors": [0, 1, 3], "park_patience_sec": 27.0,
	 "gate_change_sec": 32.0,
	 "priority_every_sec": 18.0, "priority_window_sec": 7.5,
	 "compound_chance": 1.0, "compound_ops": ["and", "or"], "pass_pct": 85},

	# 10 — everything at once: all four operators, deny on whichever gates stay simple, 3 gates.
	{"id": 10, "name": "10", "level_time_sec": 180, "rules": [],
	 "num_areas": 3, "alien_speed": 0.235, "alien_size": "small", "num_free_aliens": 13, "hide_after_sec": 10, "enter_chance": 0.50,
	 "colors": [0, 1, 2, 3], "park_patience_sec": 25.0,
	 "gate_change_sec": 26.0, "deny_chance": 0.5,
	 "priority_every_sec": 14.0, "priority_window_sec": 6.5,
	 "compound_chance": 0.6, "pass_pct": 85},
]

# LEVEL_PROGRESSION_ORDER: the level play order; may repeat ids. When the list runs out it
#   cycles back to the start. End the list with -1 instead to REPEAT THE LAST LEVEL forever
#   (e.g. [1, 2, 3, -1] plays 1..3 then stays on 3). -1 is a sentinel, never a level id.
const LEVEL_PROGRESSION_ORDER: Array = [1, 2, 3, 4, 5, 4, 5, 6, 7, 8, 9, 10, -1]

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

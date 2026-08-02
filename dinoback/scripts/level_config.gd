extends Node

# DinobackLevelConfig autoload. Per-level knobs for Dino N-Back.
#
# THE TASK. Cards appear one at a time. The player answers whether the card in front of them
# matches the card exactly N positions back — not "have I seen this before" (that is the Dino
# game), but "was THIS the card N ago". The first N cards of a level have no predecessor, so they
# are shown as PRIMING cards: watch, remember, no answer, no score.
#
# Fields per level:
#   id, name       level id, and the COMPACT label ("9 N2") used by the scores table and the
#                  progress chart legend. Both are narrow — the scores level column is about a
#                  quarter of the table width — so this one has to stay short.
#   menu_name      the descriptive name for the level DROPDOWN only, where there is room:
#                  "<id> N<n> <what to match>", space-padded so the ids line up in the dropdown's
#                  mono font. "only" means the OTHER attribute is a distractor to be ignored;
#                  "+" means both must match; "/" separates mixed categories.
#                  The HUD uses neither — it shows "Level <id>  N=<n>", since which cards you are
#                  looking at is obvious from the screen but N is not.
#   n_back         how many cards back to compare against. The whole difficulty axis.
#   source         category, or a comma list: "shapes", "letters", "digits", "dinos", "people".
#                  Photographs (dinos/people) have no color, so they force rule "symbol" and
#                  num_colors 1 — level.gd corrects a config that asks otherwise.
#   rule           what counts as a match against the card N back:
#                    "symbol"  same shape / letter / digit / picture (color is a DISTRACTOR)
#                    "color"   same color (the symbol is a DISTRACTOR)
#                    "both"    same symbol AND same color
#                  Needs at least 2 of whatever it reads, so "color"/"both" require num_colors >= 2.
#   pool_size      how many DISTINCT symbols (or images) are in play. Keep it SMALL — this is what
#                  makes it an n-back task at all. With a large pool every non-target is brand new,
#                  so "is it a match" collapses into "have I seen it", and the player never has to
#                  track position. 4-8 is the useful range.
#   num_colors     distinct colors in play, from DinobackG.COLORS (most distinct first).
#                  1 = every card the same color, i.e. no color dimension at all.
#   card_size      "small" | "med" | "big" — on-screen card size
#   card_time_sec  seconds a card stays up before a non-answer counts as a miss
#   gap_sec        blank pause between cards
#   duration_sec   level length; the level completes when it elapses
#   target_rate    (optional, default 0.30) fraction of scored cards that ARE a match
#   lure_rate      (optional, default 0.15) fraction of non-matches that instead match the card
#                  N-1 or N+1 back — the near miss that feels exactly like a hit. This is where
#                  n-back difficulty actually comes from; without lures the task is much easier
#                  than its N suggests.
#   partial_rate   (optional, default 0.40) rule "both" only: fraction of non-matches that match
#                  EXACTLY ONE of symbol/color. The other half-right card.
#
# DIFFICULTY RAMP. Shapes first because a filled shape in one color is the least to hold in mind;
# then color arrives as a distractor before it becomes the rule; then letters and digits (more
# items, more verbal interference); then N grows; photographs come LAST because a dino is far
# harder to rehearse than the letter K — there is no name to repeat to yourself.

var LEVELS: Array = [
	# --- 1-back: learn the task itself -----------------------------------------------------------
	{"id": 1, "name": "1 N1", "menu_name": " 1 N1 Shapes", "n_back": 1, "source": "shapes", "rule": "symbol",
	 "pool_size": 4, "num_colors": 1, "card_size": "big", "card_time_sec": 5.0, "gap_sec": 0.7,
	 "duration_sec": 60},
	# color appears, but the rule ignores it: the first thing to learn is what to NOT look at
	{"id": 2, "name": "2 N1", "menu_name": " 2 N1 Shape only", "n_back": 1, "source": "shapes", "rule": "symbol",
	 "pool_size": 4, "num_colors": 3, "card_size": "big", "card_time_sec": 4.5, "gap_sec": 0.7,
	 "duration_sec": 75},
	# and now the other way round — same cards, the shape is the distractor
	{"id": 3, "name": "3 N1", "menu_name": " 3 N1 Color only", "n_back": 1, "source": "shapes", "rule": "color",
	 "pool_size": 5, "num_colors": 3, "card_size": "big", "card_time_sec": 4.5, "gap_sec": 0.6,
	 "duration_sec": 75},

	# --- 2-back ----------------------------------------------------------------------------------
	{"id": 4, "name": "4 N2", "menu_name": " 4 N2 Digits", "n_back": 2, "source": "digits", "rule": "symbol",
	 "pool_size": 5, "num_colors": 1, "card_size": "big", "card_time_sec": 4.0, "gap_sec": 0.6,
	 "duration_sec": 90},
	{"id": 5, "name": "5 N2", "menu_name": " 5 N2 Shape only", "n_back": 2, "source": "shapes", "rule": "symbol",
	 "pool_size": 5, "num_colors": 3, "card_size": "med", "card_time_sec": 4.0, "gap_sec": 0.6,
	 "duration_sec": 90},
	{"id": 6, "name": "6 N2", "menu_name": " 6 N2 Letter only", "n_back": 2, "source": "letters", "rule": "symbol",
	 "pool_size": 6, "num_colors": 3, "card_size": "med", "card_time_sec": 3.5, "gap_sec": 0.6,
	 "duration_sec": 90},
	{"id": 7, "name": "7 N2", "menu_name": " 7 N2 Color only", "n_back": 2, "source": "shapes", "rule": "color",
	 "pool_size": 6, "num_colors": 4, "card_size": "med", "card_time_sec": 3.5, "gap_sec": 0.5,
	 "duration_sec": 100},
	# both at once: a small pool, because now every card has two things to hold
	{"id": 8, "name": "8 N2", "menu_name": " 8 N2 Shape+color", "n_back": 2, "source": "shapes", "rule": "both",
	 "pool_size": 4, "num_colors": 3, "card_size": "med", "card_time_sec": 3.5, "gap_sec": 0.5,
	 "duration_sec": 100},
	{"id": 9, "name": "9 N2", "menu_name": " 9 N2 Letter/digit", "n_back": 2, "source": "letters,digits", "rule": "symbol",
	 "pool_size": 8, "num_colors": 4, "card_size": "med", "card_time_sec": 3.0, "gap_sec": 0.5,
	 "duration_sec": 110},
	{"id": 10, "name": "10 N2", "menu_name": "10 N2 Letter+color", "n_back": 2, "source": "letters", "rule": "both",
	 "pool_size": 5, "num_colors": 4, "card_size": "med", "card_time_sec": 3.0, "gap_sec": 0.5,
	 "duration_sec": 110},

	# --- 3-back ----------------------------------------------------------------------------------
	{"id": 11, "name": "11 N3", "menu_name": "11 N3 Shape only", "n_back": 3, "source": "shapes", "rule": "symbol",
	 "pool_size": 5, "num_colors": 3, "card_size": "med", "card_time_sec": 3.0, "gap_sec": 0.5,
	 "duration_sec": 120},
	{"id": 12, "name": "12 N3", "menu_name": "12 N3 Letter only", "n_back": 3, "source": "letters", "rule": "symbol",
	 "pool_size": 6, "num_colors": 4, "card_size": "med", "card_time_sec": 3.0, "gap_sec": 0.5,
	 "duration_sec": 120},

	# --- photographs: no name to rehearse, so a 2-back here bites harder than a 3-back on shapes --
	{"id": 13, "name": "13 N2", "menu_name": "13 N2 Faces", "n_back": 2, "source": "people", "rule": "symbol",
	 "pool_size": 6, "num_colors": 1, "card_size": "med", "card_time_sec": 3.5, "gap_sec": 0.5,
	 "duration_sec": 120},
	{"id": 14, "name": "14 N2", "menu_name": "14 N2 Dinos", "n_back": 2, "source": "dinos", "rule": "symbol",
	 "pool_size": 6, "num_colors": 1, "card_size": "med", "card_time_sec": 3.5, "gap_sec": 0.5,
	 "duration_sec": 130},

	# --- the top of the ramp ---------------------------------------------------------------------
	{"id": 15, "name": "15 N3", "menu_name": "15 N3 Shape+color", "n_back": 3, "source": "shapes", "rule": "both",
	 "pool_size": 4, "num_colors": 3, "card_size": "small", "card_time_sec": 2.5, "gap_sec": 0.4,
	 "duration_sec": 140, "lure_rate": 0.22},
	{"id": 16, "name": "16 N3", "menu_name": "16 N3 Dinos", "n_back": 3, "source": "dinos", "rule": "symbol",
	 "pool_size": 7, "num_colors": 1, "card_size": "small", "card_time_sec": 2.5, "gap_sec": 0.4,
	 "duration_sec": 150, "lure_rate": 0.22},
	# endless practice level: same as 16 but faster and it never advances
	{"id": 17, "name": "17 N3", "menu_name": "17 N3 Dino/face", "n_back": 3, "source": "dinos,people", "rule": "symbol",
	 "pool_size": 8, "num_colors": 1, "card_size": "small", "card_time_sec": 2.0, "gap_sec": 0.4,
	 "duration_sec": 20 * 60, "lure_rate": 0.25},
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

# For the level dropdown, which has room for the long form. Falls back to `name`.
func menu_names() -> Array:
	var names: Array = []
	for lvl in LEVELS:
		names.append(lvl.get("menu_name", lvl["name"]))
	return names

func id_to_index(id: int) -> int:
	for i in LEVELS.size():
		if LEVELS[i]["id"] == id:
			return i
	return 0

extends Node

# DinoLevelConfig autoload. Per-level knobs for the Dino recognition-memory game.
#
# The player is shown one card at a time and must decide whether they have ALREADY
# seen that card earlier in the current round (swipe right / "Seen") or whether it
# is new this round (swipe left / "New").
#
# Fields per level:
#   card_size      "small" | "med" | "big" — on-screen card size
#   card_time_sec  seconds a card stays up before a non-answer counts as a miss
#   gap_sec        blank pause between cards
#   start_cards    working set size at the start of the round (the difficulty lever) —
#                  how many distinct images are in play before the set grows
#   new_after      a fresh image is unlocked each time a card has been shown this many
#                  times (default 2). This keeps a steady ~50/50 new/seen mix that adapts
#                  to the player's own pace and never collapses to "all seen": new images
#                  keep flowing from the folder(s), the only cap being how many images the
#                  source folder(s) actually have.
#   duration_sec   how long the level lasts; the level completes when it elapses
#   source         image folder(s): "dinos", "people", or a comma list "dinos,people".
#                  With more than one folder, each new card first picks a folder with
#                  EQUAL probability, then an image within it. If any folder is "dinos"
#                  the dino background (bk1) is used, otherwise the weris grass background.
#   border_colors  (optional) one Color per source folder, same order/length. If omitted,
#                  each folder uses its default: dinos -> white, people -> weris yellow.

const WHITE: Color = Color(1, 1, 1, 1)
const PEOPLE_YELLOW: Color = Color(1, 0.8039216, 0, 1)  # exact weris card-border yellow

var LEVELS: Array = [
	{"id": 1, "name": "1 D",  "card_size": "big",   "card_time_sec": 6.0, "gap_sec": 0.8, "start_cards": 3, "new_after": 2, "duration_sec": 40,  "source": "dinos"},
	{"id": 2, "name": "2 D",  "card_size": "big",   "card_time_sec": 5.0, "gap_sec": 0.7, "start_cards": 3, "new_after": 2, "duration_sec": 70,  "source": "dinos"},
	{"id": 3, "name": "3 D",  "card_size": "med",   "card_time_sec": 4.0, "gap_sec": 0.6, "start_cards": 4, "new_after": 2, "duration_sec": 80,  "source": "dinos"},
	{"id": 4, "name": "4 P",  "card_size": "med",   "card_time_sec": 5.0, "gap_sec": 0.7, "start_cards": 4, "new_after": 2, "duration_sec": 80,  "source": "people"},
	{"id": 5, "name": "5 DP", "card_size": "med",   "card_time_sec": 4.5, "gap_sec": 0.6, "start_cards": 5, "new_after": 2, "duration_sec": 90,  "source": "dinos,people", "border_colors": [WHITE, PEOPLE_YELLOW]},
	{"id": 6, "name": "6 D",  "card_size": "small", "card_time_sec": 2.0, "gap_sec": 0.5, "start_cards": 6, "new_after": 2, "duration_sec": 120, "source": "dinos"},
	{"id": 7, "name": "7 DP", "card_size": "small", "card_time_sec": 2.0, "gap_sec": 0.5, "start_cards": 6, "new_after": 2, "duration_sec": 120, "source": "dinos,people", "border_colors": [WHITE, PEOPLE_YELLOW]},
	{"id": 8, "name": "8 D",  "card_size": "small", "card_time_sec": 1.0, "gap_sec": 0.5, "start_cards": 6, "new_after": 2, "duration_sec": 300, "source": "dinos"},
	{"id": 9, "name": "9 DP", "card_size": "small", "card_time_sec": 1.0, "gap_sec": 0.5, "start_cards": 6, "new_after": 2, "duration_sec": 30*60, "source": "dinos,people", "border_colors": [WHITE, PEOPLE_YELLOW]},
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

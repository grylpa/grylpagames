extends Node

# MosaicLevelConfig autoload. One level is one picture: studied, cut into pieces, shuffled, and
# rebuilt from memory within `rounds` tries.
#
# Fields per level:
#   id, name       level id (monotonic) and its display name
#   cols, rows     the grid the picture is cut into (square pieces)
#   picture        A LIST of picture kinds; each play of the level picks one of them at random, so a
#                  level with dino cards is not limited to their finite set. An EMPTY list means every
#                  kind (on a rotation level, every kind that can be rotated: all but dino). The kinds (see
#                  mosaic/scripts/picture.gd), from most help to least
#                  for a player who would rather solve it like a jigsaw than remember it:
#                    "scenery"    sky, hills, trees, houses -- edges carry across pieces. (Not
#                                 "landscape": the picture takes the board's shape, often taller
#                                 than wide, and "landscape" promised a wide one.)
#                    "poster"     a background and large flat shapes -- fewer edge cues
#                    "quilt"      every piece its own swatch -- nothing crosses an edge, pure memory.
#                                 With no leading clues it is inherently harder, so quilts get the
#                                 SMALL boards (3 x 3, 3 x 4), and this table gives them no rotation
#                                 (the code would allow it -- a 2 x 2 quilt with rotation, say)
#                    "dino"       one of the shared dino cards, whole and never cropped -- so its
#                                 pieces take the card's proportions, and it is never rotated: on a
#                                 rotation level it is left out of the list's choice
#   study_sec      THE COUNTDOWN: how long the whole picture is shown before it is shuffled -- in
#                  the first round, and again after a round that ran out of time
#   restudy_sec    the SHORTER countdown before a round that follows a rebuilt one: the picture is
#                  already known, so a second look is a reminder, not a study
#   round_sec      the time limit of one round; when it runs out the round is failed
#   rounds         how many rounds the level plays -- the SAME picture each time, shown again and
#                  reshuffled whether the round before was rebuilt or not, so the rounds' times show
#                  how much faster the player gets at it
#   pass_pct       the level is passed when the LAST round is rebuilt AND at least this percent of
#                  all its rounds were
#   rotation       true: pieces are also turned when shuffled, and a tap turns one a quarter turn.
#                  This table uses it only on pictures with full image content, where how the
#                  picture continues shows which way up a piece goes. A dino card is never rotated
#                  (its pieces are not square); anything else, quilts included, follows this flag.

var LEVELS: Array = [
	{"id": 1, "name": "1", "cols": 3, "rows": 3, "picture": ["scenery"], "study_sec": 8,  "restudy_sec": 4, "round_sec": 45,  "rounds": 4, "pass_pct": 50, "rotation": false},
	{"id": 2, "name": "2", "cols": 3, "rows": 4, "picture": ["scenery", "dino"], "study_sec": 10, "restudy_sec": 5, "round_sec": 60,  "rounds": 4, "pass_pct": 50, "rotation": false},
	{"id": 3, "name": "3", "cols": 4, "rows": 4, "picture": ["poster"], "study_sec": 12, "restudy_sec": 6, "round_sec": 75,  "rounds": 4, "pass_pct": 60, "rotation": false},
	{"id": 4, "name": "4", "cols": 4, "rows": 4, "picture": ["scenery"], "study_sec": 12, "restudy_sec": 6, "round_sec": 80,  "rounds": 4, "pass_pct": 60, "rotation": true},
	{"id": 5, "name": "5", "cols": 3, "rows": 3, "picture": ["quilt"], "study_sec": 10, "restudy_sec": 5, "round_sec": 60,  "rounds": 4, "pass_pct": 60, "rotation": false},
	{"id": 6, "name": "6", "cols": 4, "rows": 5, "picture": ["dino", "scenery", "poster"], "study_sec": 14, "restudy_sec": 7, "round_sec": 90,  "rounds": 4, "pass_pct": 60, "rotation": false},
	{"id": 7, "name": "7", "cols": 5, "rows": 5, "picture": ["poster"], "study_sec": 16, "restudy_sec": 8, "round_sec": 110, "rounds": 5, "pass_pct": 70, "rotation": true},
	{"id": 8, "name": "8", "cols": 3, "rows": 4, "picture": ["quilt"], "study_sec": 12, "restudy_sec": 6, "round_sec": 75,  "rounds": 5, "pass_pct": 70, "rotation": false},
	{"id": 9, "name": "9", "cols": 5, "rows": 5, "picture": ["scenery"], "study_sec": 18, "restudy_sec": 9, "round_sec": 120, "rounds": 5, "pass_pct": 70, "rotation": true},
]

func max_level() -> int:
	return int(LEVELS[LEVELS.size() - 1]["id"])

func get_level(id: int) -> Dictionary:
	for lvl in LEVELS:
		if int(lvl["id"]) == id:
			return lvl
	return LEVELS[0]

func next_id(id: int) -> int:
	for i in LEVELS.size():
		if int(LEVELS[i]["id"]) == id:
			return int(LEVELS[mini(i + 1, LEVELS.size() - 1)]["id"])
	return int(LEVELS[0]["id"])

func level_names() -> Array:
	var names: Array = []
	for lvl in LEVELS:
		names.append(lvl["name"])
	return names

func id_to_index(id: int) -> int:
	for i in LEVELS.size():
		if int(LEVELS[i]["id"]) == id:
			return i
	return 0

class_name MmmLevelConfig

# Per-level configuration for Mmm.
# rounds: how many rounds at this level before it is judged
# pass_pct: share of those rounds that must be WON to move on. Below it the SAME level is played
#   again. A level is a fixed number of rounds, so only some percentages exist: out of 3 the rungs
#   are 0, 33, 66 and 100. 60 lands exactly on 2 of 3. Recheck it whenever "rounds" changes.

# THE MAP'S HELP, withdrawn level by level (2026-11-16). On level 1 the map helps as much as it can; from
# there each kind of help goes in turn, so the castle in the player's head has to carry more:
#   reveal_wrong  a wrong room shows what is really in it ("That's the teacup"). Off from level 2: the
#                 reveal told the player where ANOTHER object was, answering a later question for them.
#   color_found   a room found on the map takes back its floor. Off from level 3: the colored rooms
#                 narrowed what was left to choose from.
#   keep_found    a found room's object stays on show. Off from level 4: the same, for the objects.
const LEVELS: Array = [
	{"level": 1, "rounds": 3, "pass_pct": 60, "reveal_wrong": true, "color_found": true, "keep_found": true},
	{"level": 2, "rounds": 3, "pass_pct": 60, "reveal_wrong": false, "color_found": true, "keep_found": true},
	{"level": 3, "rounds": 3, "pass_pct": 60, "reveal_wrong": false, "color_found": false, "keep_found": true},
	{"level": 4, "rounds": 3, "pass_pct": 60, "reveal_wrong": false, "color_found": false, "keep_found": false},
	{"level": 5, "rounds": 3, "pass_pct": 60, "reveal_wrong": false, "color_found": false, "keep_found": false},
	{"level": 6, "rounds": 3, "pass_pct": 60, "reveal_wrong": false, "color_found": false, "keep_found": false},
	{"level": 7, "rounds": 3, "pass_pct": 60, "reveal_wrong": false, "color_found": false, "keep_found": false},
	{"level": 8, "rounds": 3, "pass_pct": 60, "reveal_wrong": false, "color_found": false, "keep_found": false},
	{"level": 9, "rounds": 3, "pass_pct": 60, "reveal_wrong": false, "color_found": false, "keep_found": false},
	{"level": 10, "rounds": 3, "pass_pct": 60, "reveal_wrong": false, "color_found": false, "keep_found": false},
	{"level": 11, "rounds": 3, "pass_pct": 60, "reveal_wrong": false, "color_found": false, "keep_found": false},
	{"level": 12, "rounds": 3, "pass_pct": 60, "reveal_wrong": false, "color_found": false, "keep_found": false},
]

const DEFAULT_PASS_PCT: int = 60

# Falls back rather than failing, so adding a level without a pass_pct cannot silently make it
# ungated.
static func pass_pct_for(level_id: int) -> int:
	for lv: Dictionary in LEVELS:
		if int(lv["level"]) == level_id:
			return int(lv.get("pass_pct", DEFAULT_PASS_PCT))
	return DEFAULT_PASS_PCT

static func flag(level_id: int, key: String, default: bool = true) -> bool:
	for lv: Dictionary in LEVELS:
		if int(lv["level"]) == level_id:
			return bool(lv.get(key, default))
	return default

class_name GorillaLevelConfig

# Per-level configuration for Gorilla (2026-11-09: the maze fills the screen; the walking gorillas
# and the count question are gone -- see docs/design.md).
#
# rounds            : rounds (boards) played at this level before it is judged
# pass_pct          : share of the level's BABIES that must be rescued to move on. Below it the
#                     SAME level is played again. A level has rounds x babies babies in all, so the
#                     rungs are multiples of 1/(rounds*babies): 6 babies -> 66 = 4 of 6, 8 -> 75 = 6 of 8.
# cols              : maze width in cells; the height follows from the screen's shape
# apples            : apples on the board (the round ends when all are eaten, or the time runs out)
# round_sec         : the round's time limit
# num_inside_monsters, extra_passages, agent_speed_min/max, directed_chance: as before
# gift_ms           : how long a rescued baby's MOTHER waits, holding out the sword (which works as
#                     the super-food did; there are no super-food apples any more)
# babies            : lost baby gorillas per round, one at a time
# baby_far          : how far away a baby appears, as a share of the farthest cell's walking distance
# hunt_ms           : how long a baby is safe before the nearest monster starts hunting it
# hunt_chance       : how often (per step) the hunter takes the shortest way to the baby
# bananas           : banana bunches per round (a bonus, not judged)
# banana_ms         : how long a bunch lies before it is gone

const LEVELS: Array = [
	{"level": 1, "rounds": 3, "pass_pct": 66, "cols": 11, "apples": 34, "round_sec": 75, "num_inside_monsters": 3, "extra_passages": 30,
	"agent_speed_min": 0.3, "agent_speed_max": 0.7, "directed_chance": 0.30, "gift_ms": 9000,
	"babies": 2, "baby_far": 0.45, "hunt_ms": 7000, "hunt_chance": 0.55, "bananas": 2, "banana_ms": 7000},
	{"level": 2, "rounds": 3, "pass_pct": 66, "cols": 11, "apples": 38, "round_sec": 75, "num_inside_monsters": 3, "extra_passages": 24,
	"agent_speed_min": 0.4, "agent_speed_max": 0.9, "directed_chance": 0.35, "gift_ms": 8500,
	"babies": 2, "baby_far": 0.50, "hunt_ms": 6000, "hunt_chance": 0.65, "bananas": 2, "banana_ms": 6500},
	{"level": 3, "rounds": 3, "pass_pct": 66, "cols": 13, "apples": 44, "round_sec": 80, "num_inside_monsters": 4, "extra_passages": 26,
	"agent_speed_min": 0.5, "agent_speed_max": 1.0, "directed_chance": 0.40, "gift_ms": 8000,
	"babies": 2, "baby_far": 0.55, "hunt_ms": 5500, "hunt_chance": 0.70, "bananas": 3, "banana_ms": 6000},
	{"level": 4, "rounds": 4, "pass_pct": 75, "cols": 13, "apples": 48, "round_sec": 80, "num_inside_monsters": 4, "extra_passages": 22,
	"agent_speed_min": 0.6, "agent_speed_max": 1.2, "directed_chance": 0.50, "gift_ms": 7500,
	"babies": 2, "baby_far": 0.60, "hunt_ms": 5000, "hunt_chance": 0.75, "bananas": 3, "banana_ms": 5500},
	{"level": 5, "rounds": 4, "pass_pct": 75, "cols": 13, "apples": 50, "round_sec": 85, "num_inside_monsters": 5, "extra_passages": 20,
	"agent_speed_min": 0.6, "agent_speed_max": 1.3, "directed_chance": 0.60, "gift_ms": 7000,
	"babies": 2, "baby_far": 0.65, "hunt_ms": 4500, "hunt_chance": 0.80, "bananas": 3, "banana_ms": 5000},
	{"level": 6, "rounds": 4, "pass_pct": 75, "cols": 15, "apples": 56, "round_sec": 90, "num_inside_monsters": 5, "extra_passages": 22,
	"agent_speed_min": 0.7, "agent_speed_max": 1.4, "directed_chance": 0.70, "gift_ms": 6500,
	"babies": 2, "baby_far": 0.70, "hunt_ms": 4200, "hunt_chance": 0.85, "bananas": 4, "banana_ms": 4500},
	{"level": 7, "rounds": 4, "pass_pct": 75, "cols": 15, "apples": 60, "round_sec": 90, "num_inside_monsters": 6, "extra_passages": 20,
	"agent_speed_min": 0.7, "agent_speed_max": 1.5, "directed_chance": 0.80, "gift_ms": 6000,
	"babies": 2, "baby_far": 0.75, "hunt_ms": 3800, "hunt_chance": 0.90, "bananas": 4, "banana_ms": 4000},
	{"level": 8, "rounds": 4, "pass_pct": 75, "cols": 15, "apples": 64, "round_sec": 95, "num_inside_monsters": 6, "extra_passages": 18,
	"agent_speed_min": 0.7, "agent_speed_max": 1.5, "directed_chance": 0.90, "gift_ms": 5500,
	"babies": 2, "baby_far": 0.80, "hunt_ms": 3500, "hunt_chance": 0.95, "bananas": 4, "banana_ms": 3500},
]

const DEFAULT_PASS_PCT: int = 66

# Falls back rather than failing, so adding a level without a pass_pct cannot silently make it
# ungated.
static func pass_pct_for(level_id: int) -> int:
	for lv: Dictionary in LEVELS:
		if int(lv["level"]) == level_id:
			return int(lv.get("pass_pct", DEFAULT_PASS_PCT))
	return DEFAULT_PASS_PCT

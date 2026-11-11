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
# num_inside_monsters, extra_passages, agent_speed_min/max: as before (max under the player's 1.5 - 0.2)
# smart_chase       : per step, the chance a monster takes the SHORTEST way to the player (2026-11-11)
# directed_chance   : otherwise, the chance it leans toward the player (a step along the longer axis;
#                     a wall stops it -- the old, loose "chase")
# gift_ms           : how long a rescued baby's MOTHER waits, holding out the sword (which works as
#                     the super-food did; there are no super-food apples any more)
# babies            : lost baby gorillas per round, one at a time
# baby_far          : how far away a baby appears, as a share of the farthest cell's walking distance
# hunt_ms           : how long a baby is safe before the nearest monster starts hunting it
# hunt_chance       : how often (per step) the hunter takes the shortest way to the baby
# bananas           : banana bunches per round (a bonus, not judged)
# banana_ms         : how long a bunch lies before it is gone

# Retuned 2026-11-11:
# - smart_chase is new: monsters now really CHASE (the shortest way through the maze), off at 1-2 and
#   up to half the time at 8; directed_chance, the old loose lean toward the player, is what is left.
# - pass marks step evenly: the fourth round arrives at level 4 at 62 (5 of 8) rather than with 75
#   (6 of 8) at once, which was the curve's one double jump.
# - THREE babies a round from level 6 (75 = 9 of 12): the thing the game measures gets denser at the
#   top, not just the monsters faster.
# - agent_speed_max stays under _apply_level's cap (the player's 1.5 less 0.2 = 1.3), so every level's
#   top speed is its own; 1.4 and 1.5 were silently capped, and levels 6-8 were the same speed.
# - level 8 is no longer level 7 again: a seventh monster, the most chasing, the shortest windows.
const LEVELS: Array = [
	{"level": 1, "rounds": 3, "pass_pct": 66, "cols": 11, "apples": 34, "round_sec": 75, "num_inside_monsters": 3, "extra_passages": 30,
	"agent_speed_min": 0.30, "agent_speed_max": 0.70, "smart_chase": 0.00, "directed_chance": 0.30, "gift_ms": 9000,
	"babies": 2, "baby_far": 0.45, "hunt_ms": 7000, "hunt_chance": 0.55, "bananas": 2, "banana_ms": 7000},
	{"level": 2, "rounds": 3, "pass_pct": 66, "cols": 11, "apples": 38, "round_sec": 75, "num_inside_monsters": 3, "extra_passages": 24,
	"agent_speed_min": 0.40, "agent_speed_max": 0.85, "smart_chase": 0.00, "directed_chance": 0.35, "gift_ms": 8500,
	"babies": 2, "baby_far": 0.50, "hunt_ms": 6000, "hunt_chance": 0.65, "bananas": 2, "banana_ms": 6500},
	{"level": 3, "rounds": 3, "pass_pct": 66, "cols": 13, "apples": 44, "round_sec": 80, "num_inside_monsters": 4, "extra_passages": 26,
	"agent_speed_min": 0.50, "agent_speed_max": 0.95, "smart_chase": 0.10, "directed_chance": 0.40, "gift_ms": 8000,
	"babies": 2, "baby_far": 0.55, "hunt_ms": 5500, "hunt_chance": 0.70, "bananas": 3, "banana_ms": 6000},
	{"level": 4, "rounds": 4, "pass_pct": 62, "cols": 13, "apples": 48, "round_sec": 80, "num_inside_monsters": 4, "extra_passages": 22,
	"agent_speed_min": 0.55, "agent_speed_max": 1.05, "smart_chase": 0.15, "directed_chance": 0.45, "gift_ms": 7500,
	"babies": 2, "baby_far": 0.60, "hunt_ms": 5000, "hunt_chance": 0.75, "bananas": 3, "banana_ms": 5500},
	{"level": 5, "rounds": 4, "pass_pct": 75, "cols": 13, "apples": 50, "round_sec": 85, "num_inside_monsters": 5, "extra_passages": 20,
	"agent_speed_min": 0.60, "agent_speed_max": 1.15, "smart_chase": 0.25, "directed_chance": 0.50, "gift_ms": 7000,
	"babies": 2, "baby_far": 0.65, "hunt_ms": 4500, "hunt_chance": 0.80, "bananas": 3, "banana_ms": 5000},
	{"level": 6, "rounds": 4, "pass_pct": 75, "cols": 15, "apples": 56, "round_sec": 95, "num_inside_monsters": 5, "extra_passages": 22,
	"agent_speed_min": 0.65, "agent_speed_max": 1.20, "smart_chase": 0.30, "directed_chance": 0.50, "gift_ms": 6500,
	"babies": 3, "baby_far": 0.65, "hunt_ms": 4500, "hunt_chance": 0.80, "bananas": 4, "banana_ms": 4500},
	{"level": 7, "rounds": 4, "pass_pct": 75, "cols": 15, "apples": 60, "round_sec": 95, "num_inside_monsters": 6, "extra_passages": 20,
	"agent_speed_min": 0.70, "agent_speed_max": 1.25, "smart_chase": 0.40, "directed_chance": 0.55, "gift_ms": 6000,
	"babies": 3, "baby_far": 0.70, "hunt_ms": 4000, "hunt_chance": 0.85, "bananas": 4, "banana_ms": 4000},
	{"level": 8, "rounds": 4, "pass_pct": 75, "cols": 15, "apples": 64, "round_sec": 100, "num_inside_monsters": 7, "extra_passages": 18,
	"agent_speed_min": 0.70, "agent_speed_max": 1.30, "smart_chase": 0.50, "directed_chance": 0.55, "gift_ms": 5500,
	"babies": 3, "baby_far": 0.75, "hunt_ms": 3500, "hunt_chance": 0.90, "bananas": 4, "banana_ms": 3500},
]

const DEFAULT_PASS_PCT: int = 66

# Falls back rather than failing, so adding a level without a pass_pct cannot silently make it
# ungated.
static func pass_pct_for(level_id: int) -> int:
	for lv: Dictionary in LEVELS:
		if int(lv["level"]) == level_id:
			return int(lv.get("pass_pct", DEFAULT_PASS_PCT))
	return DEFAULT_PASS_PCT

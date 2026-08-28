class_name GorillaLevelConfig

# Per-level configuration for Gorilla.
# rounds            : buildings played at this level before it is judged
# pass_pct          : share of those buildings that must be counted EXACTLY right to move on.
#                     Below it the SAME level is played again.
#
#                     A level is a fixed number of rounds, so only some percentages exist: out of
#                     3 the rungs are 0, 33, 66, 100; out of 4 they are 0, 25, 50, 75, 100. A
#                     pass_pct off those rungs promises the player a bar that cannot be met — 60
#                     out of 3 rounds really means 2 of 3, i.e. 66. The values below land exactly:
#                     60 = 2 of 3, 70 = 3 of 4. Recheck them whenever `rounds` changes.
# room_size         : board width/height (tiles). 11 is the MAXIMUM that still fits: the peripheral
#                     gorillas must clear the room floor by a full tile on every side, and at 11
#                     there is exactly that much margin left. Going bigger makes levels spawn no
#                     gorillas at all — see docs/design.md "Lane placement".
# num_inside_monsters: number of enemy agents inside the room
# num_bricks        : number of bricks (obstacles) placed in room
# extra_passages    : number of extra wall removals on top of the spanning tree (more = more open, easier to escape)
# agent_speed_min   : minimum random speed scale for enemy agents
# agent_speed_max   : maximum random speed scale (also capped to player.speed_scale - 0.2 at runtime)
# gorilla_speed_px  : speed of the gorilla in pixels/sec
# directed_chance   : probability (0.0–1.0) that an agent moves toward the player

const LEVELS: Array = [
	{"level":  1, "rounds": 3, "pass_pct": 60, "room_size":  9, "num_inside_monsters": 3, "num_bricks":  5, "extra_passages": 25, "agent_speed_min": 0.3, 
	"agent_speed_max": 0.7, "gorilla_speed_px": 205.0, "directed_chance": 0.35, "powers":3},
	{"level":  2, "rounds": 3, "pass_pct": 60, "room_size":  9, "num_inside_monsters": 3, "num_bricks":  6, "extra_passages": 16, "agent_speed_min": 0.4, 
	"agent_speed_max": 0.9, "gorilla_speed_px": 230.0, "directed_chance": 0.4 , "powers":3},
	{"level":  3, "rounds": 3, "pass_pct": 60, "room_size":  9, "num_inside_monsters": 3, "num_bricks":  7, "extra_passages": 11, "agent_speed_min": 0.6, 
	"agent_speed_max": 1.2, "gorilla_speed_px": 255.0, "directed_chance": 0.55, "powers":3},
	{"level":  4, "rounds": 3, "pass_pct": 60, "room_size": 11, "num_inside_monsters": 4, "num_bricks":  8, "extra_passages": 10, "agent_speed_min": 0.7, 
	"agent_speed_max": 1.4, "gorilla_speed_px": 280.0, "directed_chance": 0.65, "powers":3},
	{"level":  5, "rounds": 3, "pass_pct": 60, "room_size": 11, "num_inside_monsters": 4, "num_bricks":  9, "extra_passages":  9, "agent_speed_min": 0.7, 
	"agent_speed_max": 1.5, "gorilla_speed_px": 305.0, "directed_chance": 0.8 , "powers":3},
	{"level":  6, "rounds": 4, "pass_pct": 70, "room_size": 11, "num_inside_monsters": 5, "num_bricks": 10, "extra_passages":  8, "agent_speed_min": 0.7, 
	"agent_speed_max": 1.5, "gorilla_speed_px": 330.0, "directed_chance": 0.95, "powers":3},
	{"level":  7, "rounds": 4, "pass_pct": 70, "room_size": 11, "num_inside_monsters": 5, "num_bricks": 11, "extra_passages":  7, "agent_speed_min": 0.7, 
	"agent_speed_max": 1.5, "gorilla_speed_px": 355.0, "directed_chance": 1.0 , "powers":3},
	{"level":  8, "rounds": 4, "pass_pct": 70, "room_size": 11, "num_inside_monsters": 5, "num_bricks": 12, "extra_passages":  6, "agent_speed_min": 0.7, 
	"agent_speed_max": 1.5, "gorilla_speed_px": 380.0, "directed_chance": 1.0 , "powers":3},
	{"level":  9, "rounds": 4, "pass_pct": 70, "room_size": 11, "num_inside_monsters": 5, "num_bricks": 13, "extra_passages":  5, "agent_speed_min": 0.5, 
	"agent_speed_max": 1.5, "gorilla_speed_px": 405.0, "directed_chance": 1.0 , "powers":3},
	{"level": 10, "rounds": 4, "pass_pct": 70, "room_size": 11, "num_inside_monsters": 5, "num_bricks": 14, "extra_passages":  4, "agent_speed_min": 0.5, 
	"agent_speed_max": 1.5, "gorilla_speed_px": 430.0, "directed_chance": 1.0 , "powers":3},
]

const DEFAULT_PASS_PCT: int = 60

# Falls back rather than failing, so adding a level without a pass_pct cannot silently make it
# ungated.
static func pass_pct_for(level_id: int) -> int:
	for lv: Dictionary in LEVELS:
		if int(lv["level"]) == level_id:
			return int(lv.get("pass_pct", DEFAULT_PASS_PCT))
	return DEFAULT_PASS_PCT

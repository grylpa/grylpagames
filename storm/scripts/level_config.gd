class_name StormLevelConfig

# Per-level configuration for Storm. EVERY difficulty setting lives here: nothing in level.gd works a
# number out from the level any more. The values below reproduce what the code used to compute
# (noted per key), except furniture, which was 3 pieces for the whole board and is now per room.
#
# rounds              rounds at this level before moving up (was a fixed 3 in level.gd; the column
#                     existed but was never read)
# fill_rate           how fast a leak pours, as a multiple of pipe.gd's BASE_WATER_RATE (0.01 of a
#                     tile-full a second). Everything that pours -- onto the floor and into the tools --
#                     uses it, so it also sets how fast puddles grow and rooms flood.
# room_ruin           the share of a room's floor under water that ruins it -- and one ruined room
#                     loses the round (was a fixed 0.4). The HUD's "Worst: N%" warms toward red as the
#                     worst room nears it.
# arrow_ms            how long the blue arrow toward a new leak out of view stays up, in ms; negative:
#                     until the leak is on screen or caught. A newer leak out of view replaces it either
#                     way (StormLeakArrows). Multi-room levels only.
# rooms               rooms on the board (was min(12, level))
# board               the board is board x board tiles (was 51 + 2 * level)
# room_size           [min, max] side of a room, in tiles, before it is made odd (was 9..12 for all)
# storm_sec           how long the storm lasts; outlasting it with no room ruined wins (was
#                     60 * (1 + level))
# leak_every_ms       [min, max] wait before the next leak, drawn at random each time (was 2000..4000)
# bricks_per_room     bricks in each room (was 2)
# drains_per_room     drains in each room (was 1)
# furniture_per_room  pieces of furniture in each room, of the kinds in level.gd's `furniture` (was 3
#                     for the whole board, handed out a room at a time)
# tools               how many of each tool the player is dealt (bucket / rag / fix were
#                     min(3, 1 + level); cup and plate were 4)
# player_speed        how fast the player walks (was 1.5)
# corridor_run        how many times faster than that the player runs along a corridor, where there
#                     is nothing to do (level._set_player_pace())
# blackout_every_sec  [min, max] seconds between blackouts (was 10..20)

# SET FROM MEASUREMENT (devtools/measure_storm.gd: a bot playing like a person, 2026-09-25; see
# docs/design.md, "Tuning with a bot"). The shape of the ladder, decided on the way:
#  * rooms are lost at 40% on every level -- difficulty never comes from a more forgiving flood line;
#  * the storm grows by a minute a level up to 5 minutes and stops there: with a fixed set of tools, a
#    longer storm only meant every leak after the first few minutes poured freely, and from level 6 up
#    nothing was winnable at any leak rate tried;
#  * no more than 9 rooms: levels 9-12 all have 9 on the same 75 x 75 board, and grow harder by
#    leaks and fill rate alone;
#  * from level 6 up the player is dealt 3 more tools per room past two (a bucket, a towel and a cup),
#    so a leak in any room can be covered; levels 1-5 were measured, and play, with the base set. The
#    tool menu shows at most 24 at a time.
const LEVELS: Array = [
	{"level": 1, "rounds": 3, "fill_rate": 1.5, "room_ruin": 0.4, "arrow_ms": 1000, "rooms": 1, "board": 53, "room_size": [9, 12],
		"storm_sec": 120, "leak_every_ms": [4000, 8000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 3, "tools": {"bucket": 2, "rag": 2, "fix": 2, "cup": 4, "plate": 4},
		"player_speed": 1.5, "corridor_run": 2.0, "blackout_every_sec": [10, 20]},
	{"level": 2, "rounds": 3, "fill_rate": 1.0, "room_ruin": 0.4, "arrow_ms": 1000, "rooms": 2, "board": 55, "room_size": [9, 12],
		"storm_sec": 180, "leak_every_ms": [4000, 8000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 2, "tools": {"bucket": 3, "rag": 3, "fix": 3, "cup": 4, "plate": 4},
		"player_speed": 1.5, "corridor_run": 2.0, "blackout_every_sec": [10, 20]},
	{"level": 3, "rounds": 3, "fill_rate": 1.0, "room_ruin": 0.4, "arrow_ms": 1000, "rooms": 3, "board": 57, "room_size": [9, 12],
		"storm_sec": 240, "leak_every_ms": [4000, 8000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 1, "tools": {"bucket": 3, "rag": 3, "fix": 3, "cup": 4, "plate": 4},
		"player_speed": 1.5, "corridor_run": 2.0, "blackout_every_sec": [10, 20]},
	{"level": 4, "rounds": 3, "fill_rate": 1.0, "room_ruin": 0.4, "arrow_ms": 1000, "rooms": 4, "board": 59, "room_size": [9, 12],
		"storm_sec": 300, "leak_every_ms": [5000, 10000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 1, "tools": {"bucket": 3, "rag": 3, "fix": 3, "cup": 4, "plate": 4},
		"player_speed": 1.5, "corridor_run": 2.0, "blackout_every_sec": [10, 20]},
	{"level": 5, "rounds": 3, "fill_rate": 1.0, "room_ruin": 0.4, "arrow_ms": 1000, "rooms": 5, "board": 61, "room_size": [9, 12],
		"storm_sec": 360, "leak_every_ms": [8000, 16000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 1, "tools": {"bucket": 3, "rag": 3, "fix": 3, "cup": 4, "plate": 4},
		"player_speed": 1.5, "corridor_run": 2.0, "blackout_every_sec": [10, 20]},
	{"level": 6, "rounds": 3, "fill_rate": 1.0, "room_ruin": 0.4, "arrow_ms": 1000, "rooms": 6, "board": 63, "room_size": [9, 12],
		"storm_sec": 300, "leak_every_ms": [6000, 12000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 1, "tools": {"bucket": 7, "rag": 7, "fix": 3, "cup": 8, "plate": 4},
		"player_speed": 1.5, "corridor_run": 2.0, "blackout_every_sec": [10, 20]},
	{"level": 7, "rounds": 3, "fill_rate": 1.0, "room_ruin": 0.4, "arrow_ms": 1000, "rooms": 7, "board": 65, "room_size": [9, 12],
		"storm_sec": 300, "leak_every_ms": [5000, 10000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 1, "tools": {"bucket": 8, "rag": 8, "fix": 3, "cup": 9, "plate": 4},
		"player_speed": 1.5, "corridor_run": 2.0, "blackout_every_sec": [10, 20]},
	{"level": 8, "rounds": 3, "fill_rate": 1.0, "room_ruin": 0.4, "arrow_ms": 1000, "rooms": 8, "board": 67, "room_size": [9, 12],
		"storm_sec": 300, "leak_every_ms": [5000, 10000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 1, "tools": {"bucket": 9, "rag": 9, "fix": 3, "cup": 10, "plate": 4},
		"player_speed": 1.5, "corridor_run": 2.0, "blackout_every_sec": [10, 20]},
	{"level": 9, "rounds": 3, "fill_rate": 1.0, "room_ruin": 0.4, "arrow_ms": 1000, "rooms": 9, "board": 75, "room_size": [9, 12],
		"storm_sec": 300, "leak_every_ms": [5000, 10000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 1, "tools": {"bucket": 10, "rag": 10, "fix": 3, "cup": 11, "plate": 4},
		"player_speed": 1.5, "corridor_run": 2.0, "blackout_every_sec": [10, 20]},
	{"level": 10, "rounds": 3, "fill_rate": 1.0, "room_ruin": 0.4, "arrow_ms": 1000, "rooms": 9, "board": 75, "room_size": [9, 12],
		"storm_sec": 300, "leak_every_ms": [4000, 8000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 1, "tools": {"bucket": 10, "rag": 10, "fix": 3, "cup": 11, "plate": 4},
		"player_speed": 1.5, "corridor_run": 2.0, "blackout_every_sec": [10, 20]},
	{"level": 11, "rounds": 3, "fill_rate": 1.5, "room_ruin": 0.4, "arrow_ms": 1000, "rooms": 9, "board": 75, "room_size": [9, 12],
		"storm_sec": 300, "leak_every_ms": [6000, 12000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 1, "tools": {"bucket": 10, "rag": 10, "fix": 3, "cup": 11, "plate": 4},
		"player_speed": 1.5, "corridor_run": 2.0, "blackout_every_sec": [10, 20]},
	{"level": 12, "rounds": 3, "fill_rate": 1.5, "room_ruin": 0.4, "arrow_ms": 1000, "rooms": 9, "board": 75, "room_size": [9, 12],
		"storm_sec": 300, "leak_every_ms": [5000, 10000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 1, "tools": {"bucket": 10, "rag": 10, "fix": 3, "cup": 11, "plate": 4},
		"player_speed": 1.5, "corridor_run": 2.0, "blackout_every_sec": [10, 20]},
]

# The row for a level, holding at the last row for any level past the end of the table (the game
# keeps going at the top level).
static func get_level(level: int) -> Dictionary:
	return LEVELS[clampi(level - 1, 0, LEVELS.size() - 1)]

static func fill_rate(level: int) -> float:
	return float(get_level(level).get("fill_rate", 1.0))

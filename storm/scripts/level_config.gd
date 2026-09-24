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
# blackout_every_sec  [min, max] seconds between blackouts (was 10..20)

const LEVELS: Array = [
	{"level": 1, "rounds": 3, "fill_rate": 9.0, "room_ruin": 0.4, "rooms": 1, "board": 53, "room_size": [9, 12],
		"storm_sec": 120, "leak_every_ms": [2000, 4000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 3, "tools": {"bucket": 2, "rag": 2, "fix": 2, "cup": 4, "plate": 4},
		"player_speed": 1.5, "blackout_every_sec": [10, 20]},
	{"level": 2, "rounds": 3, "fill_rate": 2.1, "room_ruin": 0.4, "rooms": 2, "board": 55, "room_size": [9, 12],
		"storm_sec": 180, "leak_every_ms": [2000, 4000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 2, "tools": {"bucket": 3, "rag": 3, "fix": 3, "cup": 4, "plate": 4},
		"player_speed": 1.5, "blackout_every_sec": [10, 20]},
	{"level": 3, "rounds": 3, "fill_rate": 2.3, "room_ruin": 0.4, "rooms": 3, "board": 57, "room_size": [9, 12],
		"storm_sec": 240, "leak_every_ms": [2000, 4000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 1, "tools": {"bucket": 3, "rag": 3, "fix": 3, "cup": 4, "plate": 4},
		"player_speed": 1.5, "blackout_every_sec": [10, 20]},
	{"level": 4, "rounds": 3, "fill_rate": 2.4, "room_ruin": 0.4, "rooms": 4, "board": 59, "room_size": [9, 12],
		"storm_sec": 300, "leak_every_ms": [2000, 4000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 1, "tools": {"bucket": 3, "rag": 3, "fix": 3, "cup": 4, "plate": 4},
		"player_speed": 1.5, "blackout_every_sec": [10, 20]},
	{"level": 5, "rounds": 3, "fill_rate": 2.5, "room_ruin": 0.4, "rooms": 5, "board": 61, "room_size": [9, 12],
		"storm_sec": 360, "leak_every_ms": [2000, 4000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 1, "tools": {"bucket": 3, "rag": 3, "fix": 3, "cup": 4, "plate": 4},
		"player_speed": 1.5, "blackout_every_sec": [10, 20]},
	{"level": 6, "rounds": 3, "fill_rate": 2.7, "room_ruin": 0.4, "rooms": 6, "board": 63, "room_size": [9, 12],
		"storm_sec": 420, "leak_every_ms": [2000, 4000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 1, "tools": {"bucket": 3, "rag": 3, "fix": 3, "cup": 4, "plate": 4},
		"player_speed": 1.5, "blackout_every_sec": [10, 20]},
	{"level": 7, "rounds": 3, "fill_rate": 2.8, "room_ruin": 0.4, "rooms": 7, "board": 65, "room_size": [9, 12],
		"storm_sec": 480, "leak_every_ms": [2000, 4000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 1, "tools": {"bucket": 3, "rag": 3, "fix": 3, "cup": 4, "plate": 4},
		"player_speed": 1.5, "blackout_every_sec": [10, 20]},
	{"level": 8, "rounds": 3, "fill_rate": 2.9, "room_ruin": 0.4, "rooms": 8, "board": 67, "room_size": [9, 12],
		"storm_sec": 540, "leak_every_ms": [2000, 4000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 1, "tools": {"bucket": 3, "rag": 3, "fix": 3, "cup": 4, "plate": 4},
		"player_speed": 1.5, "blackout_every_sec": [10, 20]},
	{"level": 9, "rounds": 3, "fill_rate": 3.0, "room_ruin": 0.4, "rooms": 9, "board": 69, "room_size": [9, 12],
		"storm_sec": 600, "leak_every_ms": [2000, 4000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 1, "tools": {"bucket": 3, "rag": 3, "fix": 3, "cup": 4, "plate": 4},
		"player_speed": 1.5, "blackout_every_sec": [10, 20]},
	{"level": 10, "rounds": 3, "fill_rate": 3.2, "room_ruin": 0.4, "rooms": 10, "board": 71, "room_size": [9, 12],
		"storm_sec": 660, "leak_every_ms": [2000, 4000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 1, "tools": {"bucket": 3, "rag": 3, "fix": 3, "cup": 4, "plate": 4},
		"player_speed": 1.5, "blackout_every_sec": [10, 20]},
	{"level": 11, "rounds": 3, "fill_rate": 3.3, "room_ruin": 0.4, "rooms": 11, "board": 73, "room_size": [9, 12],
		"storm_sec": 720, "leak_every_ms": [2000, 4000], "bricks_per_room": 2, "drains_per_room": 1,
		"furniture_per_room": 1, "tools": {"bucket": 3, "rag": 3, "fix": 3, "cup": 4, "plate": 4},
		"player_speed": 1.5, "blackout_every_sec": [10, 20]},
	{"level": 12, "rounds": 3, "fill_rate": 23.5, "room_ruin": 0.8, "rooms": 12, "board": 75, "room_size": [9, 12],
		"storm_sec": 780, "leak_every_ms": [200, 400], "bricks_per_room": 5, "drains_per_room": 2,
		"furniture_per_room": 4, "tools": {"bucket": 3, "rag": 3, "fix": 3, "cup": 4, "plate": 4},
		"player_speed": 1.5, "blackout_every_sec": [10, 20]},
]

# The row for a level, holding at the last row for any level past the end of the table (the game
# keeps going at the top level).
static func get_level(level: int) -> Dictionary:
	return LEVELS[clampi(level - 1, 0, LEVELS.size() - 1)]

static func fill_rate(level: int) -> float:
	return float(get_level(level).get("fill_rate", 1.0))

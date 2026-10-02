extends Node

# MosaicG autoload: Mosaic's state between sessions.
#
# fails_by_level: {level id: rounds failed on that level, ever}. A failed round is one whose time
# ran out before the picture was whole -- the picture is shown again and reshuffled. Kept across
# sessions in the settings file, so how often a level had to be shown again is never lost.

var starting_level_id: int = 1
var fails_by_level: Dictionary = {}

var game: GenericGameUtil = GenericGameUtil.new("Mosaic", "mosaic", 0, 5, 0)

func init_globals() -> void:
	# No session clock: each round has its own limit (MosaicLevelConfig round_sec), run by the level.
	game.uses_session_clock = false

func add_failed_round(level_id: int) -> void:
	fails_by_level[level_id] = int(fails_by_level.get(level_id, 0)) + 1
	save_settings()

func failed_rounds(level_id: int) -> int:
	return int(fails_by_level.get(level_id, 0))

func save_settings() -> void:
	game.save_settings([starting_level_id, fails_by_level])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		starting_level_id = int(settings[0])
	if settings.size() > 1 and settings[1] is Dictionary:
		fails_by_level = {}
		for k in (settings[1] as Dictionary).keys():
			fails_by_level[int(k)] = int(settings[1][k])

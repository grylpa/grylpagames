extends Node

var game: GenericGameUtil = GenericGameUtil.new("Polka Dots", "polkadots", 0, 5, 0)
var starting_level: int = 1

func reset() -> void:
	game.reset(false)

func init_globals() -> void:
	reset()
	game.init_sizes()
	game.progress_level_pos = 6
	game.progress_time_pos = 7
	game.progress_pct_pos = 8
	game.progress_level_names = {}
	for cfg in PolkadotsLevelConfig.LEVELS:
		game.progress_level_names[cfg["level"]] = "L" + str(cfg["level"])

func save_settings() -> void:
	game.save_settings([starting_level])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		starting_level = settings[0]

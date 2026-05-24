extends Node

var starting_level: int = 1

var game: GenericGameUtil = GenericGameUtil.new("Whack", "whack", 0,10,0,0)

func init_globals() -> void:
	game.init_sizes()
	game.reset(true)

func save_settings() -> void:
	game.save_settings([starting_level])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		starting_level = settings[0]

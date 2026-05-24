extends Node

var starting_level := 1
var always_moving := true

var game := GenericGameUtil.new("Gorilla", "gorilla", 0, 1, 0, 3)

func init_globals():
	game.init_sizes()
	game.reset(true)

func save_settings():
	game.save_settings([starting_level])

func load_settings():
	var settings = game.read_settings()
	if settings.size() > 0:
		starting_level = settings[0]

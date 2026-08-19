extends Node

var starting_level := 1

var game := GenericGameUtil.new("Lineup", "ooo", 0,2,0,0)

func init_globals():
	game.init_sizes()
	game.reset(true)
		
func save_settings():
	game.save_settings([starting_level])

func load_settings():
	var settings = game.read_settings()
	if settings.size() > 0:
		starting_level = settings[0]

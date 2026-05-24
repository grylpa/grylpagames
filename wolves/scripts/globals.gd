extends Node

var starting_level := 1
var always_moving := true

var game := GenericGameUtil.new("Wolves", "wolves", 0,5,0, 30)
	
func init_globals():
	game.init_sizes()
	game.reset(true)

func save_settings():
	game.save_settings([starting_level, always_moving])

func load_settings():
	var settings = game.read_settings()
	if settings.size() > 0:
		starting_level = settings[0]
	# if settings.size() > 1:
	# 	always_moving = settings[1]

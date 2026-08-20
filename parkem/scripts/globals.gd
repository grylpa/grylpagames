extends Node

var num_packets: int = 0
var starting_level: int = 1

var game = GenericGameUtil.new("Parkem", "parkem", 0,5,0)

func init_globals():
	game.init_sizes()
	game.reset(true)
		
func save_settings():
	game.save_settings([num_packets, starting_level])

func load_settings():
	var settings = game.read_settings()
	if settings.size() > 1:
		num_packets = settings[0]
		starting_level = settings[1]

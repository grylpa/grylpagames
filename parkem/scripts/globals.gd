extends Node

var num_packets: int = 0
var starting_level: int = 1

# "Detour" is the DISPLAY name. The second argument is file_names_prefix and names every file
# this game keeps under user://, so it must stay "parkem" through any rename — changing it
# would orphan every score and setting already saved.
var game = GenericGameUtil.new("Detour", "parkem", 0,5,0)

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

extends Node

var num_packets: int = 0
var starting_level: int = 1
var theme: int = ParkemLevelConfig.DEFAULT_THEME     # the chosen theme (ParkemLevelConfig.THEMES)
var look: int = ParkemLevelConfig.LOOK_DUNGEON       # the look the current board is drawn in

# Settles the look of the board about to be built: the chosen theme, or for Random a fresh pick.
func settle_look() -> void:
	if theme == ParkemLevelConfig.LOOK_RANDOM:
		var looks: Array = ParkemLevelConfig.REAL_LOOKS
		look = int(looks[randi() % looks.size()])
	else:
		look = theme

# "Detour" is the DISPLAY name. The second argument is file_names_prefix and names every file
# this game keeps under user://, so it must stay "parkem" through any rename — changing it
# would orphan every score and setting already saved.
var game = GenericGameUtil.new("Detour", "parkem", 0,5,0)

func init_globals():
	game.init_sizes()
	game.reset(true)
		
func save_settings():
	game.save_settings([num_packets, starting_level, theme])

func load_settings():
	var settings = game.read_settings()
	if settings.size() > 1:
		num_packets = settings[0]
		starting_level = settings[1]
	if settings.size() > 2:
		theme = int(settings[2])

extends Node

var num_packets: int = 0
var starting_level: int = 1
var theme: int = LightsoutLevelConfig.DEFAULT_THEME     # the chosen theme (LightsoutLevelConfig.THEMES)
var look: int = LightsoutLevelConfig.DEFAULT_THEME      # the look the current board is drawn in

# Settles the look of the board about to be built: the chosen theme, or for Random a fresh pick.
func settle_look() -> void:
	if theme == LightsoutLevelConfig.LOOK_RANDOM:
		var looks: Array = LightsoutLevelConfig.REAL_LOOKS
		look = int(looks[randi() % looks.size()])
	else:
		look = theme

var game = GenericGameUtil.new("Lights Out", "lightsout", 0,5,0, 3)
	
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

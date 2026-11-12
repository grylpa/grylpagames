extends Node

var num_packets := 0
var starting_level := 1

var game := GenericGameUtil.new("Valet", "guidem", 0,5,0)

func init_globals():
	game.init_sizes()
	game.reset(true)
	
var theme: int = GuidemLevelConfig.DEFAULT_THEME     # the chosen theme (GuidemLevelConfig.THEMES)
var look: int = GuidemLevelConfig.LOOK_DAY            # the look the current board is drawn in

# Settles the look of the board about to be built: the chosen theme, or for Random a fresh pick.
func settle_look() -> void:
	if theme == GuidemLevelConfig.LOOK_RANDOM:
		var looks: Array = GuidemLevelConfig.REAL_LOOKS
		look = int(looks[randi() % looks.size()])
	else:
		look = theme

func save_settings():
	game.save_settings([num_packets, starting_level, theme])

func load_settings():
	var settings = game.read_settings()
	if settings.size() > 1:
		num_packets = settings[0]
		starting_level = settings[1]
	if settings.size() > 2:
		theme = int(settings[2])

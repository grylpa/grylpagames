extends Node

var speed := 66.0		# pixels/sec
var body_delay_sec := 32.0 / speed		# sec
var num_packets := 3
var num_agents := 1
var starting_level := 1
var freeze := false

var game := GenericGameUtil.new("Headlights", "delemfp", 0,5,0)

func init_globals():
	game.init_sizes()
	game.reset(true)
	
var theme: int = DelemfpLevelConfig.DEFAULT_THEME     # the chosen theme (DelemfpLevelConfig.THEMES)
var look: int = DelemfpLevelConfig.LOOK_DAY            # the look the current board is drawn in

# Settles the look of the board about to be built: the chosen theme, or for Random a fresh pick.
func settle_look() -> void:
	if theme == DelemfpLevelConfig.LOOK_RANDOM:
		var looks: Array = DelemfpLevelConfig.REAL_LOOKS
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

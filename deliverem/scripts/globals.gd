extends Node

var speed := 66.0		# pixels/sec
var body_delay_sec := 32.0 / speed		# sec
var num_packets := 1
var num_agents := 1
var starting_level := 1

var game := GenericGameUtil.new("Dispatch", "deliverem", 0,5,0)

func init_globals():
	game.init_sizes()
	game.reset(true)
	
var theme: int = DeliveremLevelConfig.DEFAULT_THEME     # the chosen theme (DeliveremLevelConfig.THEMES)
var look: int = DeliveremLevelConfig.LOOK_DAY            # the look the current board is drawn in

# Settles the look of the board about to be built: the chosen theme, or for Random a fresh pick.
func settle_look() -> void:
	if theme == DeliveremLevelConfig.LOOK_RANDOM:
		var looks: Array = DeliveremLevelConfig.REAL_LOOKS
		look = int(looks[randi() % looks.size()])
	else:
		look = theme

func save_settings():
	game.save_settings([num_packets, num_agents, starting_level, theme])

func load_settings():
	var settings = game.read_settings()
	if settings.size() > 2:
		num_packets = settings[0]
		num_agents = settings[1]
		starting_level = settings[2]
	if settings.size() > 3:
		theme = int(settings[3])

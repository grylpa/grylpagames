extends Node

var speed := 66.0		# pixels/sec
var body_delay_sec := 32.0 / speed		# sec
var num_packets := 3
var num_agents := 1
var starting_level := 1
var freeze := false

var game := GenericGameUtil.new("Delem FP", "delemfp", 0,5,0)

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

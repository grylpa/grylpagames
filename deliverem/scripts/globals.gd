extends Node

var speed := 66.0		# pixels/sec
var body_delay_sec := 32.0 / speed		# sec
var num_packets := 1
var num_agents := 1
var starting_level := 1

var game := GenericGameUtil.new("Deliverem", "deliverem", 0,5,0)

func init_globals():
	game.init_sizes()
	game.reset(true)
	
func save_settings():
	game.save_settings([num_packets, num_agents, starting_level])

func load_settings():
	var settings = game.read_settings()
	if settings.size() > 2:
		num_packets = settings[0]
		num_agents = settings[1]
		starting_level = settings[2]

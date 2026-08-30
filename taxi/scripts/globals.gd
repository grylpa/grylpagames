extends Node

var starting_level := 1

var prices_for_taxi := 5000
var dtime_to_empty_full_tank_ms:float = 60 * 1000
var dtime_to_fill_full_tank_ms:float = 8000
var time_for_customer_to_give_up_ms:int = 30 * 1000
var dtime_to_save_state_ms := 30 * 1000
var num_tiles_for_empty_fuel_tank := 200
# float, not int: main.gd parks a 100000.0 here for the tutorial and restores a float
# afterwards, and agent.gd divides by it. `:= 60` inferred int and narrowed both assignments.
var time_to_empty_fuel_tank_on_idle_sec: float = 60.0

var num_delivered_passengers_for_next_level := 20
var num_delivered_passengers_in_this_level := 0

var game := GenericGameUtil.new("Taxi", "taxi", 0,5,0,3)

func init_globals():
	game.init_sizes()
	game.reset(true)
		
func save_settings():
	game.save_settings([starting_level])

func load_settings():
	var settings = game.read_settings()
	if settings.size() > 0:
		starting_level = settings[0]

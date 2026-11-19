extends Node

var num_packets: int = 0
var starting_level: int = 1

var game = GenericGameUtil.new("Pneumo", "pneumo", 0,5,0)

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

# the loop the menu plays under it (GenericGameUtil.menu_ambient looks for "ambient" by default): its music, registered as "motor" (pneumo_ambient.ogg) --
# without this the menu was silent (2026-11-19)
func _ready() -> void:
	game.menu_ambient_names = ["motor"]

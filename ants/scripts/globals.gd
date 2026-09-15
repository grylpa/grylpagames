extends Node

# AntsG autoload. Owns the GenericGameUtil instance and the settings.

var starting_level_id: int = 1
# The second argument is file_names_prefix and names every file this game keeps under user://.
# It must stay "ants" through any rename of the display name.
var game: GenericGameUtil = GenericGameUtil.new("Ants", "ants", 0, 5, 0)

func init_globals() -> void:
	game.init_sizes()
	game.reset(true)

func save_settings() -> void:
	game.save_settings([starting_level_id])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		starting_level_id = settings[0]

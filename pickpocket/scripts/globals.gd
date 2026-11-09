extends Node

# PickpocketG autoload: Pickpocket's state between sessions. A street shell game: follow the ball
# under the cups while, somewhere on the street around the table, a pickpocket lifts a wallet.

var starting_level_id: int = 1

var game: GenericGameUtil = GenericGameUtil.new("Pickpocket", "pickpocket", 0, 5, 0)

func init_globals() -> void:
	# No session clock: a level is a fixed number of rounds (PickpocketLevelConfig "rounds").
	game.uses_session_clock = false

func save_settings() -> void:
	game.save_settings([starting_level_id])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		starting_level_id = int(settings[0])

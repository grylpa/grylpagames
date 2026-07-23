extends Node

# ChangeG autoload — shared state for the Change game (pay an exact amount by dragging coins
# from a pile into a tray). Self-contained; the coins are drawn (see coin.gd), not images.

var starting_level_id: int = 1

var game: GenericGameUtil = GenericGameUtil.new("Change", "change", 0, 2, 0)

func save_settings() -> void:
	game.save_settings([starting_level_id])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		starting_level_id = int(settings[0])

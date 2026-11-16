extends Node

# TipscalesG autoload: Tip the Scales' state between sessions. A weigh-house logic puzzle: crates in
# color sets, each set weighing 1..n kg, and a pile of balance scales that say how they compare.

var starting_level_id: int = 1
# the menu's "Write the rules out" switch: each scale's rule under its picture, in colored boxes and signs.
# Off by default -- the picture says exactly the same.
var show_rules: bool = false

var game: GenericGameUtil = GenericGameUtil.new("Tip the Scales", "tipscales", 0, 5, 0)

func init_globals() -> void:
	# No session clock: a level is a few puzzles (TipscalesLevelConfig "puzzles"), and a puzzle takes
	# as long as it takes -- the time per puzzle is what is recorded.
	game.uses_session_clock = false
	game.initial_score = 0

func save_settings() -> void:
	game.save_settings([starting_level_id, show_rules])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		starting_level_id = int(settings[0])
	if settings.size() > 1:
		show_rules = bool(settings[1])

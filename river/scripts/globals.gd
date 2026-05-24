extends Node

# Each row: [inhale_s, hold_top_s, exhale_s, hold_bottom_s]
const GUIDED_PRESETS: Array = [
	[4, 1, 4, 1],
	[6, 1, 6, 1],
	[4, 4, 4, 4],
	[2, 1, 2, 1],
]

var duration_min: int = 1
var selected_mode: int = 0  # direct index into GUIDED_PRESETS

var game: GenericGameUtil = GenericGameUtil.new("River", "river", 16, 0, 0)

func init_globals() -> void:
	game.init_sizes()
	game.reset(true)

func get_guided_durations() -> Array:
	var idx: int = clampi(selected_mode, 0, GUIDED_PRESETS.size() - 1)
	var p: Array = GUIDED_PRESETS[idx]
	return [float(p[0]) * 1000.0, float(p[1]) * 1000.0, float(p[2]) * 1000.0, float(p[3]) * 1000.0]

func save_settings() -> void:
	game.save_settings([duration_min, selected_mode])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		duration_min = int(settings[0])
	if settings.size() > 1:
		selected_mode = clampi(int(settings[1]), 0, GUIDED_PRESETS.size() - 1)

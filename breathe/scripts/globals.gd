extends Node

const AMBIENT_SOUNDS: Array = [
	["No sound", ""],
	["Waves 1", "res://art/sounds/relaxing-ocean-waves-high-quality-recorded-177004.mp3"],
	["Waves 2", "res://art/sounds/small-ocean-lapping-waves-220314.mp3"],
	["Waves 3", "res://art/sounds/ocean-waves-250310.mp3"],
]

var duration_min: int = 1
var ambient_sound_idx: int = 0

# 16h dummy max so GenericGameUtil timer never expires — we manage our own elapsed timer
var game: GenericGameUtil = GenericGameUtil.new("Breathe", "breathe", 16, 0, 0)

func init_globals() -> void:
	game.init_sizes()
	game.reset(true)

func save_settings() -> void:
	game.save_settings([duration_min, ambient_sound_idx])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		duration_min = settings[0]
	if settings.size() > 1:
		ambient_sound_idx = int(settings[1])

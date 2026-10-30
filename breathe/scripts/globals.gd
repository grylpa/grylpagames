extends Node

# Slow, beatless music (devtools/make_ambient_sounds.py breath_*); they replaced three ocean-wave
# recordings, a noise bed heard on a phone as hiss with gaps. A saved index keeps its slot.
const AMBIENT_SOUNDS: Array = [
	["No sound", ""],
	["Harp", "res://art/sounds/breath_harp_ambient.ogg"],
	["Piano", "res://art/sounds/breath_piano_ambient.ogg"],
	["Bells", "res://art/sounds/breath_bells_ambient.ogg"],
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

extends Node

const LANE_TOP_FRAC: float = 0.28
const LANE_BOT_FRAC: float = 0.76

const AMBIENT_SOUNDS: Array = [
	["No sound", ""],
	["Waves 1", "res://art/sounds/ocean-waves-3.mp3"],
	["Waves 2", "res://art/sounds/ocean-waves-4.mp3"],
	["Waves 3", "res://art/sounds/ocean-waves-2.mp3"],
]

# Each row: [inhale_s, hold_top_s, exhale_s, hold_bottom_s]
const GUIDED_PRESETS: Array = [
	[4, 2, 4, 2],
	[4, 7, 8, 1],
	[4, 4, 4, 4],
	[5, 0, 5, 0],
	[4, 4, 8, 0],
	[4, 0, 8, 0],
	[4, 2, 4, 0],
]

var duration_min: int = 1
# 0 = Active (free), 1 = Guided from user, 2+ = GUIDED_PRESETS[selected_mode - 2]
# Guided 4-2-4-2 out of the box (GUIDED_PRESETS[0]). Active mode records whatever the player
# does but paces them through nothing, which is the wrong thing to hand someone who has
# just arrived: with no pattern to follow there is nothing to do and nothing to score.
# Only the shipped default changes -- load_settings() still overrides it with whatever a
# returning player last chose.
const DEFAULT_MODE: int = 2
var selected_mode: int = DEFAULT_MODE
var ambient_sound_idx: int = 0
var has_user_session: bool = false
var guided_mode: bool:
	get:
		return selected_mode != 0

var learned_inhale_ms: float = 4000.0
var learned_exhale_ms: float = 4000.0
var learned_hold_top_ms: float = 1000.0
var learned_hold_bottom_ms: float = 1000.0

# Fraction of swipe area height a stroke must travel to count as a large movement
var large_move_threshold_frac: float = 0.24

# 16h dummy max so GenericGameUtil timer never expires — we manage our own elapsed timer
var game: GenericGameUtil = GenericGameUtil.new("Buoy", "udbr", 16, 0, 0)

func init_globals() -> void:
	game.init_sizes()
	game.reset(true)

# Returns [inhale_ms, hold_top_ms, exhale_ms, hold_bottom_ms] for the active guided model.
func get_guided_durations() -> Array:
	if selected_mode == 1 and has_user_session:
		return [learned_inhale_ms, learned_hold_top_ms, learned_exhale_ms, learned_hold_bottom_ms]
	var idx: int = clampi(selected_mode - 2, 0, GUIDED_PRESETS.size() - 1)
	var p: Array = GUIDED_PRESETS[idx]
	return [float(p[0]) * 1000.0, float(p[1]) * 1000.0, float(p[2]) * 1000.0, float(p[3]) * 1000.0]

func save_settings() -> void:
	game.save_settings([duration_min, selected_mode, int(has_user_session),
		int(learned_inhale_ms), int(learned_exhale_ms),
		int(learned_hold_top_ms), int(learned_hold_bottom_ms),
		ambient_sound_idx])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		duration_min = settings[0]
	if settings.size() > 1:
		selected_mode = int(settings[1])
	if settings.size() > 2:
		has_user_session = int(settings[2]) != 0
	if settings.size() > 3:
		learned_inhale_ms = float(int(settings[3]))
	if settings.size() > 4:
		learned_exhale_ms = float(int(settings[4]))
	if settings.size() > 5:
		learned_hold_top_ms = float(int(settings[5]))
	if settings.size() > 6:
		learned_hold_bottom_ms = float(int(settings[6]))
	if settings.size() > 7:
		ambient_sound_idx = int(settings[7])
	if selected_mode == 1 and not has_user_session:
		selected_mode = 0

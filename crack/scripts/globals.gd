extends Node

const TIMING_THRESHOLD_MS: float = 1000.0
const DRAG_SCALE: float = 0.9

const GUIDED_PRESETS: Array = [
	[4, 1, 4, 1],
	[6, 1, 6, 1],
	[4, 4, 4, 4],
	[2, 1, 2, 1],
]

var duration_min: int = 1
# 0=Active (free), 1=Guided from user, 2+=GUIDED_PRESETS[selected_mode - 2]
var selected_mode: int = 0
var has_user_session: bool = false
var learned_inhale_ms: float = 4000.0
var learned_exhale_ms: float = 4000.0
var learned_hold_top_ms: float = 1000.0
var learned_hold_bottom_ms: float = 1000.0

var show_instructions: bool = true

var guided_mode: bool:
	get:
		return selected_mode != 0

var game: GenericGameUtil = GenericGameUtil.new("Crack the Safe", "crack", 16, 0, 0)

func init_globals() -> void:
	game.init_sizes()
	game.reset(true)

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
		int(show_instructions)])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		duration_min = int(settings[0])
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
		show_instructions = int(settings[7]) != 0
	if selected_mode == 1 and not has_user_session:
		selected_mode = 0

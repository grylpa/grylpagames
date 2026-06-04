extends Node

var selected_level: int = 1
var show_instructions: bool = true

# How many past sessions to use for per-key stats (0 = all sessions)
const KEY_STATS_SESSIONS: int = 50

# Key size arrays, derived from TypitLevelConfig.LEVELS (built in _ready).
# Kept as arrays so existing TypitG.LEVEL_KEY_W[i] / LEVEL_KEY_H[i] access still works.
var LEVEL_KEY_W: Array = []
var LEVEL_KEY_H: Array = []

var game: GenericGameUtil = GenericGameUtil.new("Typit", "typit", 0, 1, 0)

func _ready() -> void:
	for lv in TypitLevelConfig.LEVELS:
		LEVEL_KEY_W.append(float(lv.key_w))
		LEVEL_KEY_H.append(float(lv.key_h))

func num_levels() -> int:
	return TypitLevelConfig.LEVELS.size()

func level_index(level: int) -> int:
	return clampi(level - 1, 0, TypitLevelConfig.LEVELS.size() - 1)

func text_case(level: int) -> String:
	return TypitLevelConfig.LEVELS[level_index(level)].get("case", "lower")

func max_len(level: int) -> int:
	return int(TypitLevelConfig.LEVELS[level_index(level)].get("max_len", 0))

func init_globals() -> void:
	game.init_sizes()
	game.reset(true)

# User-specific file for per-key hit aggregates across sessions.
# v5: also stores actual offset-from-center sums (a*) so the stats graphic can show
# where you really tap, while dx/dy numbers stay spine-relative. Older data ignored.
func get_key_data_path() -> String:
	return "user://keydata_v5_" + MainGlobals.user_file_key + "_typit.gpa"

func save_settings() -> void:
	game.save_settings([selected_level, int(show_instructions)])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		selected_level = int(settings[0])
	if settings.size() > 1:
		show_instructions = int(settings[1]) != 0

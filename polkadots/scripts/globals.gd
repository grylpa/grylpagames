extends Node

var game: GenericGameUtil = GenericGameUtil.new("Polka Dots", "polkadots", 0, 5, 0)
var starting_level: int = 1

func reset() -> void:
	game.reset(false)

func init_globals() -> void:
	reset()
	game.init_sizes()
	# No session clock. The time pressure in this game is the PER-ROUND `timeout_sec` (the bar
	# above the options); the level ends after `rounds_per_level` rounds, and nothing ever calls
	# `game.playing = true` or `restart_time_left_timer()`, so the countdown never ran. It just
	# sat at 00:05:00 in the HUD and printed "Time left: 00:05:00" on every level summary.
	game.uses_session_clock = false
	game.progress_level_pos = 6
	game.progress_time_pos = 7
	game.progress_pct_pos = 8
	game.progress_level_names = {}
	for cfg in PolkadotsLevelConfig.LEVELS:
		game.progress_level_names[cfg["level"]] = "L" + str(cfg["level"])

func save_settings() -> void:
	game.save_settings([starting_level])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		starting_level = settings[0]

# The accuracy a level demands before the player moves on, from that level's own config. Without
# it every level advanced on completion alone — you could get every round wrong and still be moved
# up, which made the accuracy number on the summary decorative.
const DEFAULT_PASS_PCT: int = 70

func pass_pct_for(level_id: int) -> int:
	for cfg in PolkadotsLevelConfig.LEVELS:
		if int(cfg.get("level", -1)) == level_id:
			return int(cfg.get("pass_pct", DEFAULT_PASS_PCT))
	return DEFAULT_PASS_PCT

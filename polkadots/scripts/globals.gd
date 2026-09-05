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
	# THE SCORES WIRING LIVES IN main.gd, not here.
	#
	# It was in both, with different values: this set the level names to "L1" while main.gd set
	# them to "1", so what the screens said depended on which ran last -- an initialisation order
	# nobody chose. main.gd wins that race today, which is the only reason the naming looked right.
	# It also spelled the column positions as literals 6/7/8 beside main.gd's POS_LEVEL,
	# POS_TIME_MS and POS_PCT, so adding a column would have had to be remembered twice.
	#
	# The names it now supplies are bare numbers, deliberately: the shared display rules turn a
	# numeric level name into "Level 1" for a table heading and "L1" for a chart legend, which is
	# exactly the pair wanted here. Prefixing "L" at the source produced "L1" in both.

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

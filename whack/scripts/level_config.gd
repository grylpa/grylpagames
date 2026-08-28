class_name WhackLevelConfig

# Per-level parameters for Whack.
# interval between targets = randf_range(interval_min_ms, interval_max_ms)
# show_ms                   : how long targets stay visible before auto-disappearing
# rounds                    : rounds played at this level before it is judged. A round is one
#                             target presentation — hit, missed, or correctly left alone.
# pass_pct                  : share of those rounds that must be answered right to move on. Below
#                             it the SAME level is played again.
#                             A level is a fixed number of rounds, so only some percentages exist:
#                             out of 10 the rungs are multiples of 10. These land exactly.
# num_decoys                : how many decoy targets appear alongside the real one
# no_real_chance            : probability (0.0-1.0) that a round has only decoys and no real target
# same_color_decoy          : if true, decoys share the real target's color but have no center dot
# use_many_colors_for_decoys: if true, each decoy cycles through a varied color palette (not blue)
#                             ignored when same_color_decoy is true
# Number of levels is derived from LEVELS.size().

const LEVELS: Array = [
	{
		"level":                      1,
		"radius":                     38.0,
		"interval_min_ms":           700.0,
		"interval_max_ms":          1500.0,
		"show_ms":                  2000.0,
		"rounds":                     10,
		"pass_pct":                   60,
		"num_decoys":                   0,
		# 0 on purpose: with no decoys, an "empty" round would show nothing at all.
		"no_real_chance":             0.0,
		"same_color_decoy":          true,
		"use_many_colors_for_decoys": true,
	},
	{
		"level":                      2,
		"radius":                     30.0,
		"interval_min_ms":            700.0,
		"interval_max_ms":           1200.0,
		"show_ms":                   1500.0,
		"rounds":                     10,
		"pass_pct":                   60,
		"num_decoys":                    2,
		"no_real_chance":              0.2,
		"same_color_decoy":           true,
		"use_many_colors_for_decoys":  true,
	},
	{
		"level":                      3,
		"radius":                     25.0,
		"interval_min_ms":            700.0,
		"interval_max_ms":           1200.0,
		"show_ms":                   1000.0,
		"rounds":                     10,
		"pass_pct":                   70,
		"num_decoys":                    4,
		"no_real_chance":              0.3,
		"same_color_decoy":           true,
		"use_many_colors_for_decoys":  true,
	},
	{
		"level":                      4,
		"radius":                     20.0,
		"interval_min_ms":            700.0,
		"interval_max_ms":           1500.0,
		"show_ms":                   1000.0,
		"rounds":                     10,
		"pass_pct":                   70,
		"num_decoys":                    8,
		"no_real_chance":              0.3,
		"same_color_decoy":            true,
		"use_many_colors_for_decoys": true,
	},
	{
		"level":                      5,
		"radius":                     17.0,
		"interval_min_ms":            600.0,
		"interval_max_ms":           1200.0,
		"show_ms":                    800.0,
		"rounds":                     10,
		"pass_pct":                   80,
		"num_decoys":                    12,
		"no_real_chance":              0.3,
		"same_color_decoy":            false,
		"use_many_colors_for_decoys": true,
	},
	{
		"level":                      6,
		"radius":                     15.0,
		"interval_min_ms":            500.0,
		"interval_max_ms":           1000.0,
		"show_ms":                    700.0,
		"rounds":                     10,
		"pass_pct":                   80,
		"num_decoys":                    15,
		"no_real_chance":              0.3,
		"same_color_decoy":            false,
		"use_many_colors_for_decoys": true,
	},
	{
		"level":                      7,
		"radius":                     10.0,
		"interval_min_ms":            500.0,
		"interval_max_ms":           1000.0,
		"show_ms":                    500.0,
		"rounds":                     10,
		"pass_pct":                   80,
		"num_decoys":                    20,
		"no_real_chance":              0.3,
		"same_color_decoy":            false,
		"use_many_colors_for_decoys": true,
	},
]

const DEFAULT_PASS_PCT: int = 70

# Falls back rather than failing, so adding a level without a pass_pct cannot silently make it
# ungated.
static func pass_pct_for(level_id: int) -> int:
	for lv: Dictionary in LEVELS:
		if int(lv["level"]) == level_id:
			return int(lv.get("pass_pct", DEFAULT_PASS_PCT))
	return DEFAULT_PASS_PCT

static func rounds_for(level_id: int) -> int:
	for lv: Dictionary in LEVELS:
		if int(lv["level"]) == level_id:
			return int(lv.get("rounds", 10))
	return 10

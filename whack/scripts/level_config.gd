class_name WhackLevelConfig

# Per-level parameters for Whack.
# interval between targets = randf_range(interval_min_ms, interval_max_ms)
# show_ms                   : how long targets stay visible before auto-disappearing
# hits_to_complete          : hits needed to advance to next level (last level uses 999 = infinite)
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
		"hits_to_complete":            5,
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
		"hits_to_complete":             12,
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
		"hits_to_complete":             12,
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
		"hits_to_complete":             30,
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
		"hits_to_complete":             15,
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
		"hits_to_complete":             20,
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
		"hits_to_complete":            999,
		"num_decoys":                    20,
		"no_real_chance":              0.3,
		"same_color_decoy":            false,
		"use_many_colors_for_decoys": true,
	},
]

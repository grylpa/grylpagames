class_name MovingCardsLevelConfig

# Per-level configuration for Moving Cards.
#
# num_cards          : number of cards on the board
# moving_cards       : whether cards animate to new positions after display
# random_order       : whether cards are numbered in a random (non-sequential) order
# num_rounds         : successful rounds required to advance to the next level
# display_time_ms    : milliseconds the cards are shown face-up before hiding
# speed_scale        : multiplier applied to base card movement speed (200 px/s)
# movement_style     : "fixed"  — predefined board-position paths (card by card)
#                      "random" — fully random linear paths, no card overlap,
#                                 respecting top/bottom screen margins

const LEVELS: Array = [
	{
		"level":            1,
		"num_cards":        2,
		"moving_cards":     true,
		"random_order":     true,
		"num_rounds":       3,
		"display_time_ms":  5000,
		"speed_scale":      1.0,
		"movement_style":   "random",
	},
	{
		"level":            2,
		"num_cards":        3,
		"moving_cards":     true,
		"random_order":     true,
		"num_rounds":       3,
		"display_time_ms":  5000,
		"speed_scale":      1.2,
		"movement_style":   "random",
	},
	{
		"level":            3,
		"num_cards":        4,
		"moving_cards":     true,
		"random_order":     true,
		"num_rounds":       3,
		"display_time_ms":  4500,
		"speed_scale":      1.4,
		"movement_style":   "random",
	},
	{
		"level":            4,
		"num_cards":        5,
		"moving_cards":     true,
		"random_order":     true,
		"num_rounds":       3,
		"display_time_ms":  4000,
		"speed_scale":      1.6,
		"movement_style":   "random",
	},
	{
		"level":            5,
		"num_cards":        6,
		"moving_cards":     true,
		"random_order":     true,
		"num_rounds":       4,
		"display_time_ms":  4000,
		"speed_scale":      1.8,
		"movement_style":   "random",
	},
	{
		"level":            6,
		"num_cards":        6,
		"moving_cards":     true,
		"random_order":     true,
		"num_rounds":       4,
		"display_time_ms":  3500,
		"speed_scale":      2.0,
		"movement_style":   "random",
	},
	{
		"level":            7,
		"num_cards":        6,
		"moving_cards":     true,
		"random_order":     true,
		"num_rounds":       5,
		"display_time_ms":  3000,
		"speed_scale":      2.2,
		"movement_style":   "random",
	},
	{
		"level":            8,
		"num_cards":        6,
		"moving_cards":     true,
		"random_order":     true,
		"num_rounds":       5,
		"display_time_ms":  3000,
		"speed_scale":      2.5,
		"movement_style":   "random",
	},
]

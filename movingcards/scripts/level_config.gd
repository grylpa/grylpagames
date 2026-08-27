class_name MovingCardsLevelConfig

# Per-level configuration for Moving Cards.
#
# num_cards          : number of cards on the board
# moving_cards       : whether cards animate to new positions after display
# random_order       : whether cards are numbered in a random (non-sequential) order
# num_rounds         : rounds played in this level, right or wrong. It used to count only the
#                      SUCCESSFUL ones — a wrong answer simply bought another round, so the level
#                      could not be failed and there was nothing for an accuracy gate to measure.
# pass_pct           : accuracy (%) needed to move on; below it the SAME level is played again.
#                      A level is exactly `num_rounds` rounds long, so only some percentages are
#                      reachable: out of 6 rounds a score is 0/16/33/50/66/83/100, out of 8 it is
#                      a multiple of 12.5, out of 10 a multiple of 10. These land exactly —
#                      3/6, 4/6, 6/8, 8/10 — so the number on the card is the number required.
#                      Recheck them whenever num_rounds changes.
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
		"num_rounds":       6,
		"pass_pct":         60,
		"display_time_ms":  5000,
		"speed_scale":      1.0,
		"movement_style":   "random",
	},
	{
		"level":            2,
		"num_cards":        3,
		"moving_cards":     true,
		"random_order":     true,
		"num_rounds":       6,
		"pass_pct":         66,
		"display_time_ms":  5000,
		"speed_scale":      1.2,
		"movement_style":   "random",
	},
	{
		"level":            3,
		"num_cards":        4,
		"moving_cards":     true,
		"random_order":     true,
		"num_rounds":       6,
		"pass_pct":         66,
		"display_time_ms":  4500,
		"speed_scale":      1.4,
		"movement_style":   "random",
	},
	{
		"level":            4,
		"num_cards":        5,
		"moving_cards":     true,
		"random_order":     true,
		"num_rounds":       6,
		"pass_pct":         66,
		"display_time_ms":  4000,
		"speed_scale":      1.6,
		"movement_style":   "random",
	},
	{
		"level":            5,
		"num_cards":        6,
		"moving_cards":     true,
		"random_order":     true,
		"num_rounds":       8,
		"pass_pct":         75,
		"display_time_ms":  4000,
		"speed_scale":      1.8,
		"movement_style":   "random",
	},
	{
		"level":            6,
		"num_cards":        6,
		"moving_cards":     true,
		"random_order":     true,
		"num_rounds":       8,
		"pass_pct":         75,
		"display_time_ms":  3500,
		"speed_scale":      2.0,
		"movement_style":   "random",
	},
	{
		"level":            7,
		"num_cards":        6,
		"moving_cards":     true,
		"random_order":     true,
		"num_rounds":       10,
		"pass_pct":         80,
		"display_time_ms":  3000,
		"speed_scale":      2.2,
		"movement_style":   "random",
	},
	{
		"level":            8,
		"num_cards":        6,
		"moving_cards":     true,
		"random_order":     true,
		"num_rounds":       10,
		"pass_pct":         80,
		"display_time_ms":  3000,
		"speed_scale":      2.5,
		"movement_style":   "random",
	},
]

extends RefCounted

# Couples' coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time player actually gets wrong:
#   1. They do not know the answer is a PAIR. "Find the matching cards" reads as a memory game
#      (turn cards over and remember), which this is not — every card is face up the whole time,
#      and exactly one picture appears twice while every other appears once.
#   2. Tapping is two-stage: the first tap picks a card up, the second commits the pair. A player
#      who taps one card and sees it grow does not necessarily know a second tap is expected, and
#      tapping the SAME card again puts it back down rather than confirming it.
#   3. The bar is a deadline. Running out scores like a wrong pair.
#
# Every caption reads the board rather than assuming it: `tutorial_twin_rect()` finds the matching
# card from the picked-up one, and `tutorial_selection_is_pair()` says whether that pick was even
# part of the answer — so the coach can react to a wrong first tap instead of talking past it.
#
# No freeze work is needed: level._can_play() requires `not game.paused()`, and the board deadline
# is measured in game.game_time, which excludes paused time — a caption stops the board, the
# timeout bar and the gap to the next board together.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var grid_spot: Callable = func():
		var r: Rect2 = level.tutorial_grid_rect()
		if r.size.x <= 0.0:
			return null
		return r
	var picked_spot: Callable = func():
		var r: Rect2 = level.tutorial_selected_rect()
		if r.size.x <= 0.0:
			return null
		return r

	return [
		{
			"title": "Couples",
			"text": "A board of pictures, all face up.\n\nExactly two of them are the same. Everything else appears once.",
		},
		{
			"await": {"event": "board_shown", "timeout": 60.0},
		},
		{
			"text": "Here is a board. One picture on it appears twice — find it.",
			"spot": grid_spot,
			"spot_pad": 8.0,
		},
		{
			"text": "Tap one of the two.",
			"spot": grid_spot,
			"spot_pad": 8.0,
			"await": {"event": "card_selected", "timeout": 120.0},
			"hint_after": 12.0,
			"hint": "Look for the picture you can see twice, and tap either copy of it.",
		},
		{
			# Reads the board: if the first tap was NOT part of the pair, say so now rather than
			# letting them commit it and be marked wrong without knowing why.
			# Descriptive only: the board is frozen while this caption is up, so an instruction
			# here cannot be obeyed and the attempt just dismisses the step. Anything the player
			# should DO is on the next step.
			"title": "Picked up",
			"text": func():
				if level.tutorial_selection_is_pair():
					return "That card is now held — it grew a little to show it.\n\nA second tap on the same card would put it back down."
				return "That card is now held — it grew a little to show it.\n\nIt is not one of the matching pair, though.",
			"spot": picked_spot,
			"spot_pad": 6.0,
		},
		{
			"text": func():
				if level.tutorial_selection_is_pair():
					return "Now tap its twin to commit the pair."
				return "Tap the held card again to release it, then find the picture that appears twice.",
			"spot": func():
				var r: Rect2 = level.tutorial_twin_rect() if level.tutorial_selection_is_pair() else level.tutorial_selected_rect()
				if r.size.x <= 0.0:
					return null
				return r,
			"spot_pad": 6.0,
			"await": {"event": "answered", "timeout": 180.0},
			"hint_after": 15.0,
			"hint": "Two taps make a pair: one card, then the other.",
		},
		{
			"title": func(): return "That's it" if level.tutorial_last_was_right() else "Not that time",
			"text": func():
				if level.tutorial_last_was_right():
					return "The faster you spot it, the more it is worth."
				return "The right pair is shown in green. Both cards have to be the same picture.",
			"spot": func():
				var r: Rect2 = level.tutorial_pair_rect()
				if r.size.x <= 0.0:
					return null
				return r,
			"spot_pad": 8.0,
		},
		{
			"title": "The bar",
			"text": "Your time for each board. Run out and it counts as a miss.",
			"spot": func():
				var r: Rect2 = level.tutorial_bar_rect()
				if r.size.x <= 0.0:
					return null
				return r,
			"spot_pad": 8.0,
		},
		{
			"title": "Ready",
			"text": "The grid grows as you go, and the pictures start looking alike.\n\nThe pair is never hidden — only harder to see.",
		},
	]

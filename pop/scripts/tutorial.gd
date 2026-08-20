extends RefCounted

# Glimpse's coached tutorial. See docs/tutorials.md for the step schema.
#
# Glimpse is Lineup played at the edge of your vision. The difference is the whole game:
#   * In Lineup the shape to remember always appears in the same place, so you can stare at it.
#   * Here it pops up at ANY point around the rim of the board, and the candidates that follow
#     appear somewhere else entirely (_dispatch_new_agent keeps them >4 tiles from the last one).
#
# So the mistake a first-timer makes is watching one spot. They miss the flash, and the lineup that
# follows is meaningless. The coach's job is to say: watch the whole board, it could be anywhere.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	return [
		{
			"title": "Glimpse",
			"text": "A shape flashes somewhere around the edge of the board, and is gone.\n\nThen a few candidates appear elsewhere, and you pick the one you saw.",
		},
		{
			"await": {"event": "model_shown", "timeout": 60.0},
		},
		{
			"setup": func(): level.tutorial_freeze_board(true),
			"title": "There it is",
			"text": "That is the one to remember — its shape and its color.\n\nNote WHERE it appeared, too: it could have been anywhere around the rim.",
			"spot": func():
				var p: Vector2 = level.tutorial_model_pos()
				return null if p == Vector2.ZERO else p,
			"spot_radius": level.tutorial_frame_radius(),
			"spot_pad": 0.0,
		},
		{
			# The board must RUN here: the lineup only appears once the model times out. Freezing
			# through this step deadlocks the tutorial until the step's own timeout fires.
			"setup": func(): level.tutorial_freeze_board(false),
			"await": {"event": "lineup_shown", "timeout": 60.0},
		},
		{
			# No frame here on purpose. Unlike Lineup, whose candidates sit in a row, Glimpse
			# scatters them around the RIM — the rect enclosing them all measured 433x433px, most
			# of the screen. A frame that size names nothing and leaves the caption nowhere to sit
			# that is not on top of it. The words carry this step instead.
			"title": "Somewhere else",
			"text": "The candidates have appeared around the board, never where the flash was — that is the point of the game.\n\nOne of them matches it.",
		},
		{
			# Reactive: a wrong pick clears the board and starts a fresh round, which is confusing
			# unless the coach says what happened.
			"text": func():
				if level.tutorial_has_lineup():
					return "Tap the one that matches."
				return "That was not it — the board has reset. Watch for the next flash and try again.",
			# Frozen while there is something to choose FROM — at level 1 the lineup expires in
			# two seconds — but released the moment the board is empty, because a wrong pick clears
			# it and the next model can only arrive if the board is running. A static freeze here
			# hung the tutorial on exactly the caption that says "watch for the next shape".
			"setup": func(): level.tutorial_freeze_board(level.tutorial_has_lineup()),
			"tick": func(): level.tutorial_freeze_board(level.tutorial_has_lineup()),
			"await": {"event": "answered_right", "timeout": 300.0},
			"hint_after": 15.0,
			"hint": "Same shape, same color as the flash you saw.",
		},
		{
			"setup": func(): level.tutorial_freeze_board(false),
			"title": "Ready",
			"text": "Your score starts at 100 and the clock is always running — reach zero and the run is over.\n\nThe flash gets shorter, and the candidates get more alike.",
		},
	]

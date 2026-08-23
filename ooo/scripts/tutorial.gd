extends RefCounted

# Lineup's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time player actually gets wrong:
#   1. They do not realise the first shape is the QUESTION. It appears alone for a second and
#      vanishes; a player still working out what they are looking at has already missed it, and
#      the lineup that follows means nothing.
#   2. They look for the wrong kind of match. At the first level every candidate is the same SHAPE
#      and only the color differs — later levels invert that. So "the one you saw" has to be taken
#      literally: same shape AND same color, whichever of the two the round is testing.
#   3. They take their time. Score starts at 100 and only falls: a wrong pick or letting the
#      lineup expire costs, and answering fast is worth more.
#
# The agents' own timeouts run on game.game_time, which excludes paused time — so a caption holds
# the model, and later the lineup, on screen for as long as the player needs.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var frame_r: float = level.tutorial_frame_radius()

	return [
		{
			"title": "Lineup",
			"text": "One shape appears on its own, and then it is gone.\n\nA moment later a lineup turns up, and you have to pick the one you just saw.",
		},
		{
			"await": {"event": "model_shown", "timeout": 60.0},
		},
		{
			"setup": func(): level.tutorial_freeze_board(true),
			"title": "This is the one",
			"text": "Remember it — the shape and its color.\n\nIn a real round it is on screen for about a second.",
			"spot": func():
				var p: Vector2 = level.tutorial_model_pos()
				if p == Vector2.ZERO:
					return null
				return p,
			"spot_radius": frame_r,
			"spot_pad": 0.0,
		},
		{
			# The board must RUN here: the lineup only appears once the model times out. Freezing
			# through this step deadlocks the tutorial until the step's own timeout fires.
			"setup": func(): level.tutorial_freeze_board(false),
			"await": {"event": "lineup_shown", "timeout": 60.0},
		},
		{
			"title": "The lineup",
			"text": "One of these is the one you saw. The others are near misses.",
			"spot": func():
				var r: Rect2 = level.tutorial_lineup_rect()
				if r.size.x <= 0.0:
					return null
				return r,
			"spot_pad": 10.0,
		},
		{
			# Reactive: a wrong pick clears the board and starts a fresh round, which is confusing
			# unless the coach says what happened.
			"text": func():
				if level.tutorial_has_lineup():
					return "Tap the one that matches."
				return "That was not it — the board has reset. Watch for the next shape and try again.",
			# Frozen while there is something to choose FROM — at level 1 the lineup expires in
			# two seconds — but released the moment the board is empty, because a wrong pick clears
			# it and the next model can only arrive if the board is running. A static freeze here
			# hung the tutorial on exactly the caption that says "watch for the next shape".
			"setup": func(): level.tutorial_freeze_board(level.tutorial_has_lineup()),
			"tick": func(): level.tutorial_freeze_board(level.tutorial_has_lineup()),
			"await": {"event": "answered_right", "timeout": 300.0},
			"hint_after": 15.0,
			"hint": "Compare each one against what you remember: same shape, same color.",
		},
		{
			"setup": func(): level.tutorial_freeze_board(false),
			"title": "Speed counts",
			"text": "A correct pick is worth more the faster it comes, and buys you time.\n\nA wrong one, or letting the lineup expire, costs both.",
		},
		{
			"title": "Ready",
			"text": "Your score starts at 100 and the clock is always running — reach zero and the run is over.\n\nLater rounds change what varies: sometimes the shape, sometimes the color, sometimes both.",
		},
	]

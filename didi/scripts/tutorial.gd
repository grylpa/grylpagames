extends RefCounted

# DIDI's coached tutorial. See docs/tutorials.md for the step schema.
#
# This game cannot be learned by watching, because by the time a newcomer works out where to look,
# both cues have gone: a shape at the center for 700 ms, a dot off to one side for 200 ms, and then
# nothing. They are then shown eight clusters and asked a question they did not know was coming.
#
# So the tutorial FREEZES on each cue in turn. That works because the level scheduler and agent.gd
# both measure against game.game_time, which excludes paused time — a caption holds a flash on
# screen instead of racing it (see docs/design.md).
#
# The one rule a player is least likely to deduce, and the one that costs them rounds, is that the
# correct SHAPE also appears in directions the dot never flashed. That gets its own step, pointing
# at an actual decoy.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var model_spot: Callable = func():
		return level.tutorial_model_agent()
	var periph_spot: Callable = func():
		return level.tutorial_periph_agent()
	var decoy_spot: Callable = func():
		return level.tutorial_decoy_agent()
	var correct_spot: Callable = func():
		return level.tutorial_correct_agent()

	return [
		{
			"title": "Pinpoint",
			"text": "Two things flash, one after the other. You need both of them, and both are gone before you answer.",
		},
		{
			# The round is held here. Waiting for `model_shown` alone made this caption flash past:
			# the shape spawns half a second into the round, so "watch the center" was gone before
			# a player had read it, let alone looked.
			"setup": func() -> void: level.tutorial_hold_round = true,
			"text": "Watch the center. The shape appears there for a moment and then goes.\n\nIt starts on your next tap.",
		},
		{
			# No text: this step exists only to let the round run until the shape appears. A filler
			# line here flashed up between the player's tap and the shape, which reads as a glitch.
			"setup": func() -> void: level.tutorial_hold_round = false,
			"await": {"event": "model_shown", "timeout": 30.0},
		},
		{
			"title": "One: the shape",
			"text": "That is the shape to remember.",
			"spot": model_spot,
			"spot_radius": 60.0,
		},
		{
			"text": "Now a dot flashes somewhere around it.",
			"await": {"event": "periph_shown", "timeout": 30.0},
		},
		{
			"title": "Two: the place",
			"text": "There it is. Only WHERE it flashed matters — its own shape and color are random and mean nothing.",
			"spot": periph_spot,
			"spot_radius": 55.0,
		},
		{
			"text": "Both are gone now, and the choices come up.",
			"await": {"event": "answer_ready", "timeout": 30.0},
		},
		{
			"title": "The catch",
			"text": "The shape you remembered also sits in directions the dot never flashed — like this one.\n\nSo the shape alone will not do it.",
			"spot": decoy_spot,
			"spot_radius": 55.0,
		},
		{
			# Wrong taps do nothing at all here, so the player can hunt for it without being
			# punished for a first guess — and the answer is framed, because this step is a
			# demonstration of what "right shape, right direction" looks like, not a test.
			"setup": func() -> void: level.tutorial_only_correct_taps = true,
			"text": "This is the one: the shape from the center, in the direction the dot flashed.\n\nTap it.",
			"spot": correct_spot,
			"spot_radius": 55.0,
			"await": "answered_right",
			"hint_after": 12.0,
			"hint": "Only that one counts here — anything else is ignored.",
		},
		{
			"setup": func() -> void: level.tutorial_only_correct_taps = false,
			"title": "Ready",
			"text": "In play nothing is framed, and a near miss still scores: the right direction with the wrong shape, or the right shape in the wrong direction, is worth a little.\n\nRounds keep coming. Each level flashes both cues for less time, adds more choices at each direction, and later colors the shapes in two halves.",
		},
	]

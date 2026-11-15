extends RefCounted

# Pinpoint's coached tutorial (the stakeout, 2026-11-15). See docs/tutorials.md for the step schema.
#
# This game cannot be learned by watching: the lightning shows the courier's umbrella and the lookout
# together for half a second, then nothing, and then the player faces eight spots of people with umbrellas and a
# question they did not know was coming.
#
# So the tutorial FREEZES on the flash. The level and agent.gd measure against game.game_time, which
# excludes paused time, so a caption holds the lightning (and both figures) on screen instead of racing
# it -- first pointing at the umbrella, then at the lookout, both still lit.
#
# The one rule a player is least likely to deduce, and the one that costs them rounds, is that the
# courier's umbrella also stands at spots where the lookout was NOT. That gets its own step, pointing
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
			"text": "You're on a stakeout, watching a square at night. When lightning strikes you see two people for a moment, and then it's dark again.",
		},
		{
			# The round is held here, so the flash comes on the player's tap and not while they read.
			"setup": func() -> void: level.tutorial_hold_round = true,
			"text": "Watch the whole square. The lightning comes on your next tap.",
		},
		{
			# No text: this step only lets the round run until the lightning strikes.
			"setup": func() -> void: level.tutorial_hold_round = false,
			"await": {"event": "model_shown", "timeout": 30.0},
		},
		{
			"title": "The courier",
			"text": "At the center: the courier. Remember the umbrella, its pattern and color.",
			"spot": model_spot,
			"spot_radius": 60.0,
		},
		{
			"title": "The lookout",
			"text": "And at the same moment, a lookout: the yellow raincoat under a see-through umbrella, at one of the spots around the fountain. Remember WHERE.",
			"spot": periph_spot,
			"spot_radius": 55.0,
		},
		{
			"text": "Then it's dark, and the street lamps come on.",
			"await": {"event": "answer_ready", "timeout": 30.0},
		},
		{
			"title": "The catch",
			"text": "The courier's umbrella also turns up at spots where the lookout wasn't, like this one.\n\nSo the umbrella alone isn't enough.",
			"spot": decoy_spot,
			"spot_radius": 55.0,
		},
		{
			# Wrong taps do nothing at all here, and the answer is framed: this step shows what
			# "right umbrella, right spot" looks like rather than testing it.
			"setup": func() -> void: level.tutorial_only_correct_taps = true,
			"text": "This is the one: the courier's umbrella, at the lookout's spot.\n\nTap it.",
			"spot": correct_spot,
			"spot_radius": 55.0,
			"await": "answered_right",
			"hint_after": 12.0,
			"hint": "Only that one counts here. Anything else is ignored.",
		},
		{
			"setup": func() -> void: level.tutorial_only_correct_taps = false,
			# The round is over: nothing on the square needs to stay in view under this caption
			# (the answered umbrellas linger while it pauses the game).
			"keep_clear": [],
			"title": "Ready",
			"text": "In a real game nothing is framed, and a near miss still scores a little: the right spot with the wrong umbrella, or the right umbrella at the wrong spot.\n\nThe flash gets shorter as you get better. Later levels bring more umbrellas, two-colored ones, and passers-by in the square.",
		},
	]

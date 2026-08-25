extends RefCounted

# Mother Snake's coached tutorial. See docs/tutorials.md for the step schema.
#
# This game asks for one thing and one thing only: keep your head level with hers. But learning an
# unfamiliar control and keeping up with a rhythm at the same time is one thing too many, and with
# her on screen every fumbled movement is also a failure to match her.
#
# So the mother is INTRODUCED, then sent away. With the screen to themselves the player learns the
# three things they can do — up, down, and hold — each on its own step, judged on their own movement
# and nothing else. Only then does she come back, and the last ask is a few seconds of trying to go
# with her: a timeout, not a test.
#
# Two things a first-timer does not work out on their own, and both get said out loud:
#
#   1. **Your finger does not have to touch the snake.** Dragging anywhere on the screen moves the
#      child. Players who thought they had to grab the little snake spent the first session poking
#      at a moving head.
#   2. **A hold is doing nothing.** The flat stretches at the top and bottom are part of the
#      pattern, not gaps between the parts — and the way to perform one is to stop moving and,
#      on a touch screen, lift off. It is the action nobody performs unless asked, which is why it
#      gets a step of its own.
#
# The tutorial runs in Guided 4-2-4-2 (`selected_mode = 2`), forced in main.gd. Active mode has no
# mother at all, which makes every caption here meaningless, and the User preset is built from the
# player's own past sessions, which a first-timer does not have.
#
# Freezing is free in this game: `_process` returns early on `game.paused()`, so a caption stops
# the mother, the scroll and the session clock together, and none of them jump when it closes.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var mother_spot: Callable = func():
		var p: Vector2 = level.tutorial_mother_pos()
		if p == Vector2.ZERO:
			return null
		return p
	var child_spot: Callable = func():
		var p: Vector2 = level.tutorial_child_pos()
		if p == Vector2.ZERO:
			return null
		return p
	# Both heads are worth keeping out from under the caption even when only one is being pointed
	# at — they are the only two things on screen that matter, and they move.
	var heads_clear: Array = [mother_spot, child_spot]

	return [
		{
			"title": "Mother Snake",
			"text": "The mother snake breathes, and you breathe with her.\n\nThat is the whole game.",
			"keep_clear": heads_clear,
		},
		{
			"text": "This is the mother.\n\nShe rises while she breathes in, flattens out while she holds, and sinks while she breathes out.",
			"spot": mother_spot,
			"spot_radius": level.tutorial_head_radius(),
			"spot_pad": 0.0,
			"keep_clear": heads_clear,
		},
		{
			# She goes away here. Learning an unfamiliar control and keeping up with a rhythm at
			# the same time is one thing too many — and with her on screen every attempt at a
			# movement is also a failure to match her.
			"setup": func(): level.tutorial_set_mother_visible(false),
			"text": "Let us send her off for a minute, so you can get the hang of moving.",
			"spot": child_spot,
			"spot_radius": level.tutorial_head_radius(),
			"spot_pad": 0.0,
			"keep_clear": heads_clear,
		},
		{
			"text": "The little one is you.\n\nSlide your finger anywhere on the screen to move it — you never have to touch the snake itself.",
			"spot": child_spot,
			"spot_radius": level.tutorial_head_radius(),
			"spot_pad": 0.0,
			"keep_clear": heads_clear,
		},
		{
			"setup": func(): level.tutorial_mark_move_baseline(),
			"text": "Breathe in, and take yourself up.",
			"await": {"event": "moved_up", "timeout": 300.0},
			"hint_after": 12.0,
			"hint": "Slide upward and keep sliding — on a keyboard, hold the UP arrow.",
			"keep_clear": heads_clear,
		},
		{
			"setup": func(): level.tutorial_mark_move_baseline(),
			"text": "Now breathe out, and go back down.",
			"await": {"event": "moved_down", "timeout": 300.0},
			"hint_after": 12.0,
			"hint": "Slide downward and keep sliding — on a keyboard, hold the DOWN arrow.",
			"keep_clear": heads_clear,
		},
		{
			# The third action, and the one nobody performs, because doing nothing does not feel
			# like playing. It gets its own step for exactly that reason.
			"setup": func(): level.tutorial_mark_move_baseline(),
			"text": "And the third one: hold.\n\nStop moving, lift your finger off, and stay level for a moment.",
			"await": {"event": "held", "timeout": 300.0},
			"hint_after": 12.0,
			"hint": "Let go of everything — a hold is done by doing nothing.",
			"keep_clear": heads_clear,
		},
		{
			"setup": func(): level.tutorial_set_mother_visible(true),
			"text": "Up, down and hold. That is everything you can do.\n\nHere she is again.",
			"spot": mother_spot,
			"spot_radius": level.tutorial_head_radius(),
			"spot_pad": 0.0,
			"keep_clear": heads_clear,
		},
		{
			"text": "In, hold, out, hold — and this is how long each one lasts, in seconds.",
			"spot": func(): return level.tutorial_goal_label(),
			"keep_clear": heads_clear,
		},
		{
			"text": "This tells you which part of the breath she is in, if you lose her.",
			"spot": func(): return level.tutorial_phase_label(),
			"keep_clear": heads_clear,
		},
		{
			# A few seconds of trying, not a test. The timeout is the point: if they cannot hold a
			# whole breath level with her yet, the tutorial still ends kindly rather than parking
			# them on a step they cannot pass.
			"text": func():
				if not level.tutorial_is_with_mother():
					return "Now go with her.\n\nGet level with her first — then stay there."
				var pct: int = int(level.tutorial_follow_progress() * 100.0)
				return "Now go with her.\n\nTogether so far: %d%%" % pct,
			"await": {"event": "cycle_followed", "timeout": 30.0},
			"hint_after": 12.0,
			"hint": "Match her turns rather than her exact height.",
			"keep_clear": heads_clear,
		},
		{
			"title": "Ready",
			"text": func():
				if level.tutorial_is_with_mother():
					return "That is it — breathe with her until the time runs out.\n\nYour score is how closely your rhythm matched hers, and how quickly you turned when she did."
				return "It takes a few breaths to settle into. Keep at it until the time runs out.\n\nYour score is how closely your rhythm matched hers, and how quickly you turned when she did.",
			"keep_clear": heads_clear,
		},
	]

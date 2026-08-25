extends RefCounted

# Crack the Safe's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-timer gets wrong, in order of damage:
#
# 1. THEY FLICK. The instructions say "swipe UP", and everywhere else in this app — and on every
#    phone — a swipe is a fast flick. Here it is the opposite: the finger keeps sliding for as
#    long as the inhale lasts, four whole seconds, because the DURATION of the slide is the thing
#    being measured. A player who flicks sees a game that does nothing, which is the report that
#    prompted this tutorial. Two steps are spent on it, one of them a drawn demonstration, because
#    no wording of "swipe" survives contact with what players already believe a swipe is.
# 2. THEY DO NOT KNOW A HOLD IS AN ACTION. Stopping is the third and fourth beat of the pattern,
#    not a pause between beats. Lifting the finger is how you perform it.
# 3. THE ORDER IS A SEQUENCE, NOT FOUR SEPARATE MOVES. up, hold, down, hold — anything out of
#    order silently resets it (`_reset_seq`), with no feedback at all, so a confused player gets
#    no signal that they are confused.
# 4. ALL FOUR HAVE TO LAND. `_try_score` requires every one of the four durations to be within
#    TIMING_THRESHOLD_MS of its target; three out of four scores nothing.
#
# The tutorial forces a guided preset. In the shipped default (`selected_mode = 0`, "Active")
# `_try_score` returns immediately and NOTHING can ever open the safe — teaching the unlock in
# that mode would be teaching something that cannot happen.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var hud_spot: Callable = func():
		return level.tutorial_hud_rect()
	var score_spot: Callable = func():
		return level.tutorial_score_rect()
	var demo_up: Callable = func():
		return level.tutorial_demo_up()
	var demo_down: Callable = func():
		return level.tutorial_demo_down()

	# Quote the live preset instead of hard-coding 4-1-4-1: the tutorial picks the preset, but the
	# numbers still come from the game, so a change to GUIDED_PRESETS cannot leave this lying.
	var d: Array = CrackG.get_guided_durations()
	var s_in: String = "%.0f" % (float(d[0]) / 1000.0)
	var s_ht: String = "%.0f" % (float(d[1]) / 1000.0)
	var s_out: String = "%.0f" % (float(d[2]) / 1000.0)
	var s_hb: String = "%.0f" % (float(d[3]) / 1000.0)
	var thr_s: String = "%.0f" % (CrackG.TIMING_THRESHOLD_MS / 1000.0)

	return [
		{
			"title": "Crack the Safe",
			"text": "The lock opens to a breathing pattern.\n\nBreathe it accurately and the safe swings open.",
		},
		{
			"title": "The combination",
			"text": "In for %s seconds.\nHold for %s.\nOut for %s seconds.\nHold for %s." % [s_in, s_ht, s_out, s_hb],
			"spot": hud_spot,
		},
		{
			"title": "Not a flick",
			"text": "Your finger slides for as long as the breath lasts — all %s seconds of it.\n\n"
				% s_in + "Slowly, like this. A quick flick does nothing.",
			"demo_path": demo_up,
			"demo_hand_only": true,
		},
		{
			"text": "Try it: breathe in, sliding your finger up the whole time.",
			"await": {"event": "inhaled", "timeout": 180.0},
			"hint_after": 12.0,
			"hint": "Press down and keep sliding upward without lifting. On a keyboard, hold the UP arrow.",
			"demo_path": demo_up,
			"demo_hand_only": true,
		},
		{
			"text": "The slide ended when you stopped moving.\n\nThat is your inhale, and its length is what counts.",
			"spot": hud_spot,
		},
		{
			"title": "Holding is a move",
			"text": "Lift your finger off.\n\nThat pause is part of the pattern.",
		},
		{
			"text": "Now breathe out, sliding your finger down all the way.",
			"await": {"event": "exhaled", "timeout": 180.0},
			"hint_after": 14.0,
			"hint": "Press down and keep sliding downward without lifting. On a keyboard, hold the DOWN arrow.",
			"demo_path": demo_down,
			"demo_hand_only": true,
		},
		{
			"title": "When the lock listens",
			"text": "One beat is left: the hold at the bottom.\n\n"
				+ "It ends when you START your next breath in — and that is the moment the lock "
				+ "judges all four.",
		},
		{
			"text": "So: lift off, hold for %s second, then begin your next breath in." % s_hb,
			"await": {"event": "held_bottom", "timeout": 180.0},
			"hint_after": 14.0,
			"hint": "Lift your finger, pause, then start sliding up again.",
		},
		{
			"title": "Four in a row",
			"text": "In, hold, out, hold — in that order.\n\n"
				+ "Break the order and it starts over from the beginning, quietly.",
		},
		{
			"text": "Each one has to land within %s second of its target. All four, or nothing." % thr_s
				+ "\n\nThis line is what you just did. The one below it is what to aim for.",
			"spot": hud_spot,
		},
		{
			"text": "Now a whole pattern, in rhythm, to open it.",
			"await": {"event": "unlocked", "timeout": 240.0},
			"hint_after": 20.0,
			"hint": "In for %s, hold %s, out for %s, hold %s. Watch the timings above the dial." % [s_in, s_ht, s_out, s_hb],
		},
		{
			"text": "Open.\n\nEvery pattern you get right counts once more.",
			"spot": score_spot,
		},
		{
			"title": "Ready",
			"text": "Keep breathing the pattern until the time runs out.\n\n"
				+ "The menu has other patterns, and an Active mode that just records your own.",
		},
	]

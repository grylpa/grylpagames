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
	var goal_spot: Callable = func():
		return level.tutorial_goal_rect()
	# One continuous animation of the whole pattern, with a caption that changes in step with it.
	var demo_seq: Callable = func(el): return level.tutorial_demo_sequence(el)
	var demo_caption: Callable = func(): return level.tutorial_demo_caption()
	var demo_zone: Callable = func(): return level.tutorial_demo_rect()
	var demo_over: Callable = func(): return level.tutorial_demo_finished()

	# Quote the live preset instead of hard-coding 4-2-4-2: the tutorial picks the preset, but the
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
			"text": "In for %s seconds.\nHold for %s.\nOut for %s seconds.\nHold for %s.\n\nIt is written on the door." % [s_in, s_ht, s_out, s_hb],
			"spot": goal_spot,
		},
		{
			# ONE step, not five. The pattern is a rhythm; chopping it into tap-gated stills loses
			# the timing, which is the only thing being taught. The caption is a live Callable that
			# follows the animation, so picture and words stay together on their own.
			#
			# A side caption because the animation runs down the board: a full-width panel docked
			# at the bottom sits on the very thing being watched. On the LEFT, with the line just
			# beside it -- a caption on the far side of the screen from the gesture means reading
			# and watching cannot happen at once, and this step needs both. The hand is tilted so
			# its body falls down-and-right, away from the words.
			"title": "Watch",
			"text": demo_caption,
			"demo_hand": demo_seq,
			"caption_side": "left",
			"keep_clear": [demo_zone],
			"advance_when": demo_over,
			"setup": func():
				level.tutorial_demo_end(),
		},
		{
			"title": "That was 3 sequences",
			"text": "A whole round is that, over and over, until the time runs out.\n\n"
				+ "Here is what you get at the end of one.",
		},
		{
			"title": "The summary",
			"text": "Shows how close you were to the target, and the shape of "
				+ "every breath you took.",
			"setup": func():
				level.tutorial_show_summary(),
		},
		{
			"title": "Ready",
			"text": "The menu has other patterns, and an Active mode that just records your own.",
		},
	]

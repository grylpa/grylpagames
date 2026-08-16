extends RefCounted

# Udbr's coached tutorial. See docs/tutorials.md for the step schema.
#
# THE TEXT COMES FROM THE GAME'S OWN "I" INSTRUCTIONS SCREEN (udbr/scripts/main.gd), which is
# accurate. Three earlier versions of this file were wrong because they described a model I had
# derived myself from scripts/main.gd instead:
#
#   I read the hysteresis block (scripts/main.gd:311-321) but not _process_vertical_steps (:381),
#   which does `swipe_accum.y -= sign(swipe_accum.y) * 50`. That makes swipe_accum a ROLLING
#   displacement wrapping every 50px, not the absolute distance from where the finger landed. From
#   that omission came an "anchor" model — direction decided by where your finger IS relative to
#   where it touched down — which does not exist. With the wrap, continuing to slide upward keeps
#   the up-latch engaged, which is exactly what the instructions screen says: swipe up WHILE
#   inhaling.
#
# So: keep this text in step with udbr/scripts/main.gd's set_instructions() — with ONE known
# exception, confirmed by the user against the running game:
#
#   The instructions screen says "Keep touching while holding your breath between inhaling and
#   exhaling." You do NOT have to. The finger only needs to be down while you are actually
#   breathing IN or OUT; during a hold you can lift it off. That also matches the code: releasing
#   clears both direction flags (scripts/main.gd:206-209) and the ball stops dead, which is what a
#   hold should look like in the trace. Keeping the finger down instead leaves the last direction
#   latched and the ball drifting until it clamps at the end of the lane.
#
# The instructions screen has not been changed — that is the user's copy to decide on.
#
# Captions are short on purpose. They are rendered in a narrow right-hand column
# (runner.caption_side = "right" in main.gd), because the lane is vertical and centered and a
# full-width caption at the bottom covers the ball.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	# The live inhale counter, so step 4 points at the thing that just changed.
	var counter_spot: Callable = func():
		return level._inhale_label if level._inhale_label != null else null

	return [
		{
			"title": "Up Down Breathe",
			"text": "Breathe at your own pace.\n\nYour finger follows your breath.",
		},
		{
			"text": "Touch the screen while you breathe.\n\nYour finger only needs to be down while you are actually breathing in or out.",
		},
		{
			"text": "Breathe IN.\n\nSlide your finger UP as you do — all the way through the inhale.",
			# Waits for the ball to reach the TOP, not for the direction latch. The latch engages
			# within a frame of the first few pixels, so waiting on `inhaled` ended this step —
			# and froze the screen for the next one — before the ball had visibly moved.
			"await": {"event": "reached_top", "timeout": 120.0},
			"hint_after": 12.0,
			"hint": "Keep sliding upward, without lifting. On a keyboard, hold the UP arrow.",
		},
		{
			"text": "That is one full inhale.\n\nNow lift your finger off while you hold your breath at the top.",
			"spot": counter_spot,
		},
		{
			"text": "Put your finger back down and breathe OUT.\n\nSlide all the way back DOWN.",
			"await": {"event": "reached_bottom", "timeout": 120.0},
			"hint_after": 12.0,
			"hint": "Keep sliding downward, still without lifting. On a keyboard, hold the DOWN arrow.",
		},
		{
			"text": "All the way down.\n\nLift off again while you hold your breath at the bottom.",
		},
		{
			"title": "The rhythm",
			"text": "In, hold, out, hold.\n\nFinger down while you breathe, off while you hold.",
		},
		{
			"title": "Rather be led?",
			"text": "In the menu, change Mode from Active to one of the Guided ones.\n\nThe ball then moves by itself — in, hold, out, hold, on a fixed count — and you just breathe with it .",
		},
		{
			"title": "That is all of it",
			"text": "Breathe like that until the time is up, and you will get your rhythm and how steady it was.",
		},
	]

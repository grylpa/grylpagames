extends RefCounted

# Udbr's coached tutorial. See docs/tutorials.md for the step schema.
#
# THIS ONE IS ALL TALKING STEPS, deliberately. Every other tutorial in the app waits for the player
# to perform the action it just described. Udbr cannot: it has no discrete action to wait for, and
# the events it does emit are not trustworthy enough to congratulate anybody on.
#
# How the input actually works (scripts/main.gd, digitized-swipe branch, + _process_kbd here):
#   * Touching down sets an ANCHOR. `swipe_accum` measures displacement from that point, not
#     velocity, and is reset on every new touch.
#   * Hold your finger above the anchor and `is_in_digitized_swipe_up` latches on; below it (by
#     more than a 30px hysteresis) it flips to down. So the direction is WHERE YOUR FINGER IS
#     relative to where you put it down — not which way you are currently moving it.
#   * The flags are only recomputed on DRAG events. Stop moving and the last direction stays
#     latched, so the ball keeps traveling until it reaches the end of the lane. "Hold still to
#     hold your breath" — which this tutorial used to say — is therefore wrong.
#   * `_inhale_count` increments the instant the up-latch engages, which a single pixel of upward
#     drag is enough to do. Waiting on `inhaled` and then announcing "that is one inhale" told
#     players they had done something they had not.
#
# So the tutorial explains the anchor and leaves the doing to the session. If udbr's input is ever
# reworked (a real hold state, a sensible movement threshold), this can become a doing tutorial
# like the others — the `inhaled` / `exhaled` hooks in level.gd are already there.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(_level: Node, _game) -> Array:
	return [
		{
			"title": "Up Down Breathe",
			"text": "A breathing exercise. You breathe at your own pace, and the app follows your finger and measures how steady you were.",
		},
		{
			"title": "The important bit",
			"text": "Put your finger on the screen and LEAVE IT THERE for the whole session.\n\nWhere you first touch becomes your middle. Everything after that is measured from that spot.",
		},
		{
			"text": "Hold your finger ABOVE that spot and the ball climbs — that is you breathing in.\n\nBring it BELOW and the ball falls — that is you breathing out.",
		},
		{
			"title": "You are not drawing",
			"text": "You do not have to keep moving. Once you are above the middle the ball keeps rising on its own, and it keeps falling once you are below.\n\nSo it is one slow move up and one slow move down per breath, not constant stroking.",
		},
		{
			"text": "Lift your finger and the session stops reading you, so keep it down from beginning to end.",
		},
		{
			"title": "Nothing to lose",
			"text": "There is no way to fail here and nothing chasing you, so do not wait to be told you are doing it wrong — you will not be.\n\nAt the end you get your rhythm, how steady it was, and a trace of the whole session.",
		},
		{
			"title": "The easier way in",
			"text": "In the menu you can turn on a GUIDED session. The ball then moves by itself through a set pattern — something like 4-2-6-2 seconds — and the label names each part: Inhale, Hold, Exhale, Hold.\n\nYou just keep your finger on the ball and breathe with it. If this is your first time, start there.",
		},
		{
			"title": "Ready",
			"text": "Finger down, and breathe.\n\nNothing you did here was recorded — your real session starts from the menu.",
		},
	]

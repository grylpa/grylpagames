extends RefCounted

# Breathe's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-timer gets wrong, in order of damage:
#
# 1. WHERE IN THE BREATH THE TAP GOES. This is the whole game and it is the one thing the written
#    instructions state in half a line ("Tap once at the end of each exhale"). The score is the
#    standard deviation of the gaps BETWEEN taps, so a player who taps at a random point in each
#    cycle -- sometimes mid-inhale, sometimes after the exhale -- produces a scattered set of
#    intervals and a poor number, while breathing perfectly steadily. The tutorial spends three
#    steps on this and nothing else matters as much.
# 2. That there is no target to hit. The big circle looks like a button, and it is not: the tap
#    lands anywhere on the screen.
# 3. That nothing on screen is pacing them. The circle is deliberately static (BREATH_ANIMATION is
#    false, see docs/design.md) precisely so it cannot become a pacer -- but a player who expects
#    to be led will sit waiting for it to lead.
# 4. That fast breathing is not better breathing. The score is steadiness only; 4 s and 12 s
#    cycles both reach 100 if they are held evenly.
#
# The session is a real one and it is running while all of this is read, which is fine -- the
# tutorial sets a long duration so it cannot end mid-lesson, and nothing here is scored.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	# Live state, so the captions quote the game rather than paraphrasing it.
	var circle_spot: Callable = func():
		return level.tutorial_circle_rect()
	var counter_spot: Callable = func():
		return level._breath_label if level._breath_label != null else null
	var gap_text: Callable = func():
		var sec: float = level.tutorial_last_interval_sec()
		if sec <= 0.0:
			return "That is one interval measured."
		return "That gap was %.1f seconds.\n\nThe next one should be about the same." % sec

	return [
		{
			"title": "Breathe",
			"text": "This does not tell you how to breathe.\n\n"
				+ "It measures how STEADY your own breathing is.",
		},
		{
			"text": "Breathe however is comfortable. Slow or quick, it makes no difference here.",
		},
		{
			"text": "You mark each breath with one tap.\n\nAnywhere on the screen — there is nothing to aim at.",
		},
		{
			"text": "The circle does not lead you.\n\nThe rhythm has to be yours.",
			"spot": circle_spot,
		},
		{
			"text": "Take a breath in, let it out, and tap as the exhale ends.",
			"await": {"event": "tapped", "timeout": 120.0},
			"hint_after": 15.0,
			"hint": "Tap anywhere. On a keyboard, press SPACE.",
		},
		{
			"text": "That is one breath counted.",
			"spot": counter_spot,
		},
		{
			"title": "The part that matters",
			"text": "Every tap should land at the SAME moment in the breath — the end of each exhale.\n\n"
				+ "What is measured is the gap between your taps,",
		},
		{
			"text": "Again: breathe out fully, and tap exactly as it ends.",
			"await": {"event": "tapped", "timeout": 120.0},
			"hint_after": 15.0,
			"hint": "At the end of the exhale, not the start of the next breath in.",
		},
		{
			"text": gap_text,
			"spot": counter_spot,
		},
		{
			"text": "Once more, to the same beat.",
			"await": {"event": "tapped", "timeout": 120.0},
			"hint_after": 15.0,
			"hint": "End of the exhale again.",
		},
		{
			"title": "That is it",
			"text": "Keep going until the time runs out.\n\n"
				+ "Then you get your rhythm, how steady it was, and any breaths you missed.",
		},
	]

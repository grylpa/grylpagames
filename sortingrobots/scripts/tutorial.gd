extends RefCounted

# Sorting Robots' coached tutorial. See docs/tutorials.md for the step schema.
#
# Two things make this game confusing on first contact:
#   1. The framed item is judged against the rule of the belt IT is on — not against whichever of
#      the two rules the player happens to be reading. With a rule at each belt head, checking the
#      wrong one is the natural mistake.
#   2. The rules disappear. Six rounds in, exactly when the player has settled, both labels fade
#      out; without warning that reads as the game breaking rather than as the point of it.
#
# So this names the belt and reads its rule out at the moment the frame appears, and then makes the
# labels vanish deliberately with the coach present to say what just happened.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var left_rule: Callable = func():
		return level.tutorial_rule_label(0)
	var right_rule: Callable = func():
		return level.tutorial_rule_label(1)
	var window_spot: Callable = func():
		return level.tutorial_window_panel()

	return [
		{
			"title": "Sorting Robots",
			"text": "Two belts, and a robot working each one. Every robot sorts by its own rule, and the robots cannot read.\n\nYou are the one who decides what they keep.",
		},
		{
			"text": func(): return "The left belt asks: %s" % level.tutorial_rule_text(0),
			"spot": left_rule,
		},
		{
			"text": func(): return "The right belt asks something else: %s" % level.tutorial_rule_text(1),
			"spot": right_rule,
		},
		{
			# window_SETTLED, not window_opened: the frame slides in from above the belt, so at the
			# moment it opens it is sitting over the rule label and looks like it is framing THAT.
			# The level runs the belts on until the item is clear of the label, then stops them.
			# First judgment is a MATCH, so the player picks something up and sees the claw work.
			"setup": func() -> void: level.tutorial_want_truth = 1,
			"text": "Every so often a frame closes around one item.",
			"await": {"event": "window_settled", "timeout": 45.0},
		},
		{
			"title": "Its own belt's rule",
			"text": func(): return "This one is on the %s belt, so the only question is: %s\n\nNot the other belt's rule — the item is judged where it sits." % [
				level.tutorial_belt_name(level.tutorial_window_belt()),
				level.tutorial_rule_text(level.tutorial_window_belt())],
			"spot": window_spot,
		},
		{
			"text": func(): return ("It matches, so it belongs here.\n\nSwipe RIGHT to pick it up."
				if level.tutorial_window_truth()
				else "It does not match, so it does not belong here.\n\nSwipe LEFT to leave it."),
			"spot": window_spot,
			"await": "judged",
			"hint_after": 12.0,
			"hint": "Swipe across the screen, or use the left and right arrow keys.",
		},
		{
			# Second is deliberately a non-match, so they also practise leaving one alone. Left to
			# itself the picker only balances yes/no across a whole level, so both could be takes.
			#
			# The caption does NOT say so: it is written before the item has even been chosen, and a
			# promise made ahead of the game is one the tutorial should not be making. The player
			# judges it for themselves; the staging only makes sure they meet both answers.
			"setup": func() -> void: level.tutorial_want_truth = 0,
			"text": "Another one. Judge it by the rule of the belt it is on.",
			"await": {"event": "window_settled", "timeout": 60.0},
		},
		{
			"spot": window_spot,
			"text": func(): return "%s belt: %s\n\nRIGHT to pick it up, LEFT to leave it." % [
				level.tutorial_belt_name(level.tutorial_window_belt()).capitalize(),
				level.tutorial_rule_text(level.tutorial_window_belt())],
			"await": "judged",
			"hint_after": 12.0,
			"hint": "Right to pick up, left to leave.",
		},
		{
			"title": "And then this happens",
			"setup": func() -> void:
				level.tutorial_want_truth = -1
				level.tutorial_hide_labels_now(),
			"text": "The rules are gone.\n\nA few rounds into every level they fade out, and from then on you carry both of them in your head. That is the game.",
		},
		{
			"title": "Ready",
			"text": "Judge each framed item before its time runs out. Later levels draw harder rules, swap which belt they sit on, and take the labels away sooner.",
		},
	]

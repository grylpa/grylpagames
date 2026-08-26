extends RefCounted

# Apprentice's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time Apprentice player actually gets wrong, in order of damage:
#   1. They do not realise there IS a hidden rule. The robot picking things up looks like scenery
#      until the question arrives out of nowhere and asks what the rule was — by which point they
#      have watched five judgements without paying attention to any of them.
#   2. Every item is a PAIR of objects and the rule applies to only ONE of them. Working out which
#      half matters is most of the game, and nothing on screen says so.
#   3. The ✓/✗ shows before the robot acts (robot_answer_time, 5.8s on level 1) — the answer, then
#      the action. Players read the pull as the decision and miss the mark entirely.
#
# So the tutorial names the game as a guessing game FIRST, points at one item and says it is two
# things, and then walks one ✓ and one ✗ with the belt stopped. `tutorial_force_truth` picks which
# of the two comes next, so both are taught on demand rather than whenever the shuffle obliges.
#
# The belts need no explicit freeze: level._process returns early on game.paused(), so a talking
# step stops the belt, the window and the ✓/✗ timing together.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var window_spot: Callable = func():
		var r: Rect2 = level.tutorial_window_rect()
		if r.size.x <= 0.0:
			return null
		return r

	return [
		{
			"title": "Apprentice",
			"text": "A robot sorts things coming down a conveyor belt.\n\nIt follows one secret rule, and never tells you what it is. Working that out is the whole game.",
		},
		{
			"text": "This is the belt. Items ride down it, and the robot judges them one at a time.",
			"spot": func():
				var r: Rect2 = level.tutorial_belt_rect()
				if r.size.x <= 0.0:
					return null
				return r,
			"spot_pad": 4.0,
		},
		{
			"title": "Two things, not one",
			"text": "Look closely: every item is a PAIR.\n\nThe rule only cares about one of the two. Which one is part of the puzzle.",
			"spot": func():
				var r: Rect2 = level.tutorial_an_item_rect()
				if r.size.x <= 0.0:
					return null
				return r,
			"spot_pad": 8.0,
		},
		{
			# Force a match, so the very first thing taught is a clean ✓.
			# window_ready, not window_opened: the window opens on an item still entering from
			# above the belt, where the belt's clipping leaves nothing to point at.
			"setup": func(): level.tutorial_force_truth = 1,
			"await": {"event": "window_ready", "timeout": 60.0},
		},
		{
			"title": "It picked one",
			"text": "The yellow frame means the robot is about to judge this item.\n\nWatch what it decides.",
			"spot": window_spot,
			"spot_pad": 4.0,
		},
		{
			"await": {"event": "marked_yes", "timeout": 60.0},
		},
		{
			"title": "Yes — a match",
			"text": "A ✓ means this item obeys the secret rule, and the robot takes it off the belt.\n\nThe answer always appears before the robot moves.",
			"spot": window_spot,
			"spot_pad": 4.0,
		},
		{
			# ...and now force a non-match, so ✗ follows immediately instead of several items later.
			"setup": func(): level.tutorial_force_truth = 0,
			"await": {"event": "marked_no", "timeout": 60.0},
		},
		{
			"title": "No — not a match",
			"text": "A ✗ means this one breaks the rule. The robot leaves it, and it rides on past.\n\nBoth answers are evidence. You need some of each.",
			"spot": window_spot,
			"spot_pad": 4.0,
		},
		{
			"setup": func(): level.tutorial_force_truth = -1,
			"title": "Now watch",
			"text": "A few more will go past. Compare what it takes against what it leaves — the difference IS the rule.",
			"await": {"event": "question_shown", "timeout": 180.0},
		},
		{
			"title": "So — what was it?",
			"text": "Pick the rule the robot was using.\n\nGuessing wrong costs a little, so think about what you saw.",
			"await": {"event": "question_answered", "timeout": 180.0},
			"hint_after": 20.0,
			"hint": "Think about the items it TOOK, and what they all had in common.",
		},
		{
			"title": "Ready",
			"text": "Later levels run two belts at once, each with its own secret rule — and the rules change every round.",
		},
	]

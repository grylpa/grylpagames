extends RefCounted

# Sorting Robots' coached tutorial (Quality Control, 2026-11-15). See docs/tutorials.md for the schema.
#
# Two things make this game confusing on first contact:
#   1. A parcel is judged by the rule of the belt IT is on -- not by whichever rule the player happens
#      to be reading. With a rule at each belt head, checking the wrong one is the natural mistake.
#   2. Letting a parcel ride is an answer too. A player who taps everything, or nothing, has not
#      understood that the scanner asks a question about every parcel.
# So the belts STOP with a parcel at the scanner (`tutorial_hold_at_scanner`): once with one to grab,
# once with one to let ride, the coach naming the belt and reading its rule. Then the labels fade.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var left_rule: Callable = func():
		return level.tutorial_rule_label(0)
	var right_rule: Callable = func():
		return level.tutorial_rule_label(1)
	var held_spot: Callable = func():
		return level.tutorial_held_parcel()
	var held_belt_rule: Callable = func() -> String:
		var b: int = level.tutorial_held_belt()
		return "%s belt: %s" % [level.tutorial_belt_name(b).capitalize(), level.tutorial_rule_text(b)]

	return [
		{
			"title": "Sorting Robots",
			"text": "Quality control at the depot. Two belts, a robot at each, and each belt has its own rule.\n\nYou tell the robots what to grab.",
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
			"setup": func() -> void:
				level.tutorial_want_truth = 1
				level.tutorial_hold_at_scanner = true,
			"text": "Each belt runs through a scanner in its middle. The parcel inside the scanner is the one to judge.",
			"await": {"event": "qc_held", "timeout": 45.0},
		},
		{
			"title": "Grab it",
			"text": func(): return "%s\n\nIt matches, so tap this belt to grab it." % held_belt_rule.call(),
			"spot": held_spot,
			"await": "judged",
			"hint_after": 12.0,
			"hint": "Tap the belt it is on (or press the left or right arrow key).",
		},
		{
			"setup": func() -> void:
				level.tutorial_want_truth = 0
				level.tutorial_hold_at_scanner = true,
			"text": "Another one.",
			"await": {"event": "qc_held", "timeout": 45.0},
		},
		{
			"title": "Let it ride",
			"text": func(): return "%s\n\nThis one doesn't match. Don't tap: let it ride on through." % held_belt_rule.call(),
			"spot": held_spot,
		},
		{
			"setup": func() -> void: level.tutorial_release(),
			"text": "Letting a parcel ride is an answer too.",
			"await": {"event": "qc_rode", "timeout": 20.0},
		},
		{
			"title": "The rules fade",
			"setup": func() -> void:
				level.tutorial_want_truth = -1
				level.tutorial_hide_labels_now(),
			"text": "The rules are gone.\n\nPart way into every level they fade out, and from then on you have to remember both.",
		},
		{
			"title": "Ready",
			"text": "Parcels keep coming on both belts, faster as you get better. Judge each one by its own belt's rule. Later levels draw harder rules and swap them between the belts.",
		},
	]

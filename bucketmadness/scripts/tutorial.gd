extends RefCounted

# Bucket Madness's coached tutorial. See docs/tutorials.md for the step schema.
#
# The instruction text is six lines of rules with nothing demonstrated, and it leaves out the two
# things that actually confuse a first-timer:
#
#   1. **An item is TWO objects, and only one of them can ever match a rule.** The other is
#      generated to fail on purpose (see `_next_round`'s cross-rule constraint). So the job is not
#      "does this item match" but "which of these two matches, and whose rule is it".
#   2. **The rules fade out after a few rounds.** They still apply. Players who did not notice this
#      coming read it as the game breaking.
#
# The item falls on a Tween, and landing answers "dumpster" for you and scores it. Throughout the
# tutorial the level holds each item in mid-air (`tutorial_hold_fall`) once it is far enough down
# to be seen, so nothing is ever lost to reading time — and the last caption says plainly that in
# the real game it keeps falling.
#
# Level 1 is forced in main.gd: its rules pool is exactly [digit, square], so the pair is fixed and
# the captions below can talk about "digits" and "squares" without checking. They read the live
# labels anyway (`tutorial_rule_text`), because a pool is a pool.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var item_spot: Callable = func():
		var r: Rect2 = level.tutorial_item_rect()
		return null if r.size.x <= 0.0 else r
	# The three buckets and the two rule labels are the board. Handing the placer each one
	# separately beats one merged box: it can slip a caption between them.
	var board_clear: Array = [
		func(): return level.tutorial_left_bucket(),
		func(): return level.tutorial_right_bucket(),
		func(): return level.tutorial_dumpster(),
		func(): return level.tutorial_left_rule_label(),
		func(): return level.tutorial_right_rule_label(),
	]
	var all_clear: Array = board_clear + [item_spot]

	return [
		{
			"title": "Bucket Madness",
			"text": "Things fall. You have two buckets, a dumpster between them, and about two seconds to choose.",
			"keep_clear": all_clear,
		},
		{
			# "item_ready", not "item_dropped": the latter fires as the round starts, with the item
			# still a full item-height ABOVE the fall area, where clip_contents hides it. The
			# caption after this one frames it, and framed empty space above the trapezoid is
			# exactly what that looked like.
			"await": {"event": "item_ready", "timeout": 60.0},
		},
		{
			"text": "Here comes one.\n\nEvery item is two objects side by side — and only one of them can ever match a rule.",
			"spot": item_spot,
			"spot_pad": 8.0,
			"keep_clear": board_clear,
		},
		{
			"text": func():
				return "The left bucket takes anything matching this rule:\n\n%s" % level.tutorial_rule_text(0),
			"spot": func(): return level.tutorial_left_rule_label(),
			"keep_clear": all_clear,
		},
		{
			"text": func():
				return "The right bucket takes this one:\n\n%s" % level.tutorial_rule_text(1),
			"spot": func(): return level.tutorial_right_rule_label(),
			"keep_clear": all_clear,
		},
		{
			"text": "And whatever matches neither rule goes in the dumpster, in the middle.\n\nTwo buckets, one dumpster.",
			"spot": func(): return level.tutorial_dumpster(),
			"keep_clear": all_clear,
		},
		{
			# Descriptive, not imperative: the board is frozen while a caption is up, so an
			# instruction here cannot be obeyed and the attempt just dismisses the step. The ask
			# comes next.
			"text": "Each bucket has a direction. A left swipe or ← sends the item to the left bucket, a right swipe or → to the right one, and a downward swipe or ↓ to the dumpster.",
			"keep_clear": all_clear,
		},
		{
			# First ask, with the answer named. Reactive: a wrong swipe sends the item away and a
			# fresh one drops, so the caption has to carry the player through that rather than sit
			# there pointing at an item that is gone.
			"text": func():
				if not level.tutorial_has_item():
					return "Here comes another one."
				var rule: String = level.tutorial_matching_rule()
				var where: String = level.tutorial_bucket_name(level.tutorial_correct_bucket())
				if rule.is_empty():
					return "This one matches neither rule.\n\nSend it to the dumpster."
				return "One of these two matches:\n\n%s\n\nSend it to the %s." % [rule, where],
			"spot": item_spot,
			"spot_pad": 8.0,
			"await": {"event": "answered_right", "timeout": 300.0},
			"hint_after": 15.0,
			"hint": "A swipe anywhere on the screen counts — you do not have to touch the item. ← ↓ → work too.",
			"keep_clear": board_clear,
		},
		{
			# Again: wait for it to be visible, not merely to exist.
			"await": {"event": "item_ready", "timeout": 60.0},
		},
		{
			# Second ask, this time without being told. Same event, so a wrong answer keeps the
			# step and the next item is another chance.
			"text": func():
				if not level.tutorial_has_item():
					return "Here comes another one."
				return "Your turn.\n\nRead the two objects, find the one that matches a rule, and send it where it belongs.",
			"spot": item_spot,
			"spot_pad": 8.0,
			"await": {"event": "answered_right", "timeout": 300.0},
			"hint_after": 20.0,
			"hint": func():
				var rule: String = level.tutorial_matching_rule()
				if rule.is_empty():
					return "Neither rule fits this one."
				return "One of them matches: %s" % rule,
			"keep_clear": board_clear,
		},
		{
			"text": "The quicker you answer, the more it scores — and your average time is up here.",
			"spot": func(): return level.tutorial_avg_label(),
			"keep_clear": all_clear,
		},
		{
			# The twist. Named before it happens, because meeting it cold reads as a bug.
			"text": "One more thing: after a few rounds these two labels fade away.\n\nThe rules still apply. You have to keep them in your head.",
			"spot": func(): return level.tutorial_rules_row(),
			"spot_pad": 6.0,
			"keep_clear": board_clear,
		},
		{
			"title": "Ready",
			"text": "Nothing has been falling while we talked. From here it does — and an item that lands on its own counts as a dumpster answer.",
			"keep_clear": all_clear,
		},
	]

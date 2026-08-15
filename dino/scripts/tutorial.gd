extends RefCounted

# Dino's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time Dino player actually gets wrong, in order of damage:
#   1. "Seen" is read as "have I ever seen this dino", not "has this card come up in THIS round".
#      Everything else follows from getting this right, so it is taught first, restated with a
#      concrete repeat, and stated once more at the end.
#   2. The drain bar is not recognized as a deadline, so the first "Too slow" reads as a bug.
#      It is pointed at explicitly, after the player has already answered twice and can spare
#      the attention.
#   3. A hesitant drag falls under the 60px swipe threshold and silently does nothing. So the
#      buttons are taught FIRST as the answer that always works, and the drag is then taught as
#      its own lesson the player has to actually perform — waiting on
#      `answered_without_buttons`, so tapping New again does not satisfy it. Merely mentioning
#      the gesture in passing is what left players never discovering it worked.
#
# The opening three cards are scripted (new, new, repeat) by level.gd's `_forced_picks`, because
# the lesson needs a card the player has demonstrably seen before, and the adaptive picker would
# only get there by luck.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	# Spotlight targets are Callables so they are resolved fresh each frame — the card node is
	# replaced on every turn, so capturing it once would spotlight a freed node.
	# The card is a Node2D anchored at its TOP-CENTER (shared/scripts/card.gd), so its own
	# width/height are needed to build the box — the runner's default radius would spotlight a
	# small circle in the middle of it.
	var card_spot: Callable = func():
		var c = level._card
		if c == null or not is_instance_valid(c):
			return null
		var top_center: Vector2 = c.get_global_transform_with_canvas().origin
		var cw: float = c.card_width()
		return Rect2(top_center - Vector2(cw * 0.5, 0.0), Vector2(cw, c.card_height()))
	var bar_spot: Callable = func():
		return level._bar_track

	return [
		{
			"title": "Dino",
			"text": "Cards appear one at a time.\n\nEvery card asks you the same question: have I already seen this one?",
		},
		{
			"text": "Here comes the first card.",
			"await": {"event": "card_shown", "timeout": 8.0},
		},
		{
			"text": "This is the first card of the round, so you have not seen it yet. It is NEW.",
			"spot": card_spot,
		},
		{
			"text": "Answer with the New button.",
			"spot": func(): return level._btn_new,
		},
		{
			"text": "Go ahead — tap New.",
			"spot": func(): return level._btn_new,
			"await": "answered",
			"hint_after": 5.0,
			"hint": "Tap the New button at the bottom left.",
		},
		{
			"text": "That is it. The first time a card appears, it is always new.",
		},
		{
			"text": "Next card.",
			"await": {"event": "card_shown", "timeout": 8.0},
		},
		{
			"text": "A different dino. You have not seen this one either — New again.",
			"spot": card_spot,
			"await": "answered",
			"hint_after": 6.0,
			"hint": "Tap New.",
		},
		{
			"text": "Now watch this one carefully.",
			"await": {"event": "card_shown", "timeout": 8.0},
		},
		{
			"text": "This dino has already come up in this round.\n\nThat makes it SEEN.",
			"spot": card_spot,
		},
		{
			"text": "Answer with the Seen button.",
			"spot": func(): return level._btn_seen,
			"await": "answered",
			"hint_after": 6.0,
			"hint": "Tap the Seen button at the bottom right.",
		},
		{
			"title": "A faster way",
			"text": "You do not have to reach for the buttons.\n\nYou can answer the card itself: drag it LEFT for new, RIGHT for seen.",
		},
		{
			"text": "Here comes another card — try it with a drag this time.",
			"await": {"event": "card_shown", "timeout": 8.0},
		},
		{
			# Waits for a NON-button answer specifically, so the lesson is not satisfied by
			# tapping New again. Generous timeout, because a first drag often falls under the
			# 60px threshold and does nothing at all — which is the exact failure this teaches
			# around, and the hint names it.
			"text": "Drag the card sideways and let go.\n\nLeft if it is new, right if you have seen it.",
			"spot": card_spot,
			"await": {"event": "answered_without_buttons", "timeout": 40.0},
			"hint_after": 7.0,
			"hint": "Drag it a good distance before letting go — a small nudge does not count.",
		},
		{
			"text": "That is the whole game: the two buttons, or a drag either way.",
		},
		{
			"text": "This bar is your time for the current card.\n\nWhen it empties, the card counts as a miss — so answer before it runs out.",
			"spot": bar_spot,
		},
		{
			"title": "One last thing",
			"text": "SEEN means seen in THIS round.\n\nEvery new round starts with a clean memory, even if you have played these dinos a hundred times before.",
		},
		{
			"title": "Ready",
			"text": "New cards keep coming until the round timer runs out, and more dinos join as you go.\n\nNothing you did here was scored — your real game starts from the menu.",
		},
	]

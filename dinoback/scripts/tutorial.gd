extends RefCounted

# Dino N-Back's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time player actually gets wrong, in order of damage:
#   1. They play it as Dino — "have I seen this card before?". The design doc names this as the
#      central confusion, and it is fatal here: the pool is 4 cards, so EVERY card is one they have
#      seen. Familiarity answers nothing; only position in the stream does. The tutorial says this
#      outright, and says it late, once the player has felt it.
#   2. The priming cards. The first N cards have nothing to compare against, the buttons are dimmed
#      and answers are refused — which reads as the game being broken unless someone explains it.
#   3. The countdown bar is a deadline. No answer is a miss, scored like a wrong one.
#
# The stream is fully under the coach's control: `tutorial_hold_cards` stops the next card arriving
# behind a caption, and `tutorial_force_target` decides whether the next scored card IS a match, so
# a clean match and a clean non-match are each taught on demand.
#
# No freeze work is needed: level._can_play() requires `not game.paused()`, and the card deadline
# is measured in game.game_time, which excludes paused time — a caption stops the stream and the
# bar together.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var card_spot: Callable = func():
		var r: Rect2 = level.tutorial_card_rect()
		if r.size.x <= 0.0:
			return null
		return r

	return [
		{
			"title": "Dino N-Back",
			"text": "Cards come by one at a time.\n\nFor each one you answer a single question: is it the same as the card you saw a fixed number of steps ago?",
		},
		{
			"setup": func(): level.tutorial_hold_cards = false,
			"await": {"event": "priming_card", "timeout": 60.0},
		},
		{
			"setup": func(): level.tutorial_hold_cards = true,
			"title": func(): return "%d back" % level.tutorial_n_back(),
			# Deliberately ONE short line. Step 1 already stated the rule, so this step only has to
			# say why the first card is a freebie. The card is 427 px of a 748 px screen, which leaves
			# about 119 px of clear space above it — a caption any taller has nowhere to go and
			# ends up sitting on the card it is describing.
			"text": func():
				var n: int = level.tutorial_n_back()
				if n == 1:
					return "Nothing to compare this one with yet — just remember it."
				return "The first %d cards have nothing behind them. Remember them." % n,
			"spot": card_spot,
			"spot_pad": 6.0,
		},
		{
			# The first scored card is forced to be a match, so ✔ is taught on a clean example.
			"setup": func():
				level.tutorial_force_target = 1
				level.tutorial_release_cards(),
			"await": {"event": "scored_card", "timeout": 60.0},
		},
		{
			"setup": func(): level.tutorial_hold_cards = true,
			"title": "A match",
			"text": "This one IS the same as the card before it.",
			"spot": card_spot,
			"spot_pad": 6.0,
		},
		{
			# The instruction lives HERE, on the step that actually accepts it. On a talking step
			# the board is frozen, so a swipe does nothing except dismiss the caption.
			"setup": func(): level.tutorial_release_cards(),
			"text": "Swipe RIGHT to say match — or tap Match.",
			"spot": func():
				var r: Rect2 = level.tutorial_buttons_rect()
				if r.size.x <= 0.0:
					return null
				return r,
			"spot_pad": 6.0,
			"await": {"event": "answered", "timeout": 120.0},
			"hint_after": 10.0,
			"hint": "Swipe right across the card, or tap the Match button.",
		},
		{
			"title": "The bar",
			"text": "Your time for each card. Run out and it counts as a miss.",
			"spot": func():
				var r: Rect2 = level.tutorial_bar_rect()
				if r.size.x <= 0.0:
					return null
				return r,
			"spot_pad": 8.0,
		},
		{
			# ...and now a clean non-match, so ✘ is taught just as deliberately.
			"setup": func():
				level.tutorial_force_target = 0
				level.tutorial_release_cards(),
			"await": {"event": "scored_card", "timeout": 60.0},
		},
		{
			"setup": func(): level.tutorial_hold_cards = true,
			"title": "Not a match",
			"text": "This one is NOT the same as the card before it.",
			"spot": card_spot,
			"spot_pad": 6.0,
		},
		{
			"setup": func(): level.tutorial_release_cards(),
			"text": "Swipe LEFT to say no — or tap No.",
			"spot": func():
				var r: Rect2 = level.tutorial_buttons_rect()
				if r.size.x <= 0.0:
					return null
				return r,
			"spot_pad": 6.0,
			"await": {"event": "answered", "timeout": 120.0},
			"hint_after": 10.0,
			"hint": "Swipe left across the card, or tap the No button.",
		},
		{
			# The thing that actually trips people up, said once they have felt it.
			"setup": func():
				level.tutorial_force_target = -1
				level.tutorial_hold_cards = true,
			"title": "Not 'have I seen it'",
			"text": "Only a few cards are in play, so they all keep coming back. Recognizing one tells you nothing.\n\nOnly its position in the run counts.",
		},
		{
			"setup": func(): level.tutorial_release_cards(),
			"title": "Ready",
			"text": "Later levels reach further back, and some ask about COLOR rather than shape.\n\nEach one tells you which before it starts.",
		},
	]

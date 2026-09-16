extends RefCounted

# Ants' coached tutorial. See docs/tutorials.md for the step schema.
#
# THE CAPTIONS ARE SHORT ON PURPOSE. Two of these steps ask the player to WATCH a road form, and the
# balloon is sized by its text -- the first draft explained the mechanism in two paragraphs and then
# sat across the very thing it was pointing at. Anything that can be seen is not described.
#
# What a first-time player actually gets wrong, in order of damage:
#   1. They treat a wall as permanent. It is not: block the road and the colony wears a new one
#      round it inside a minute, so the game is not walling off a route once -- it is watching where
#      the next road is forming and getting there first. A player who never learns this places four
#      stones, watches them become scenery, and concludes the tools do not work.
#   2. They never discover that what they placed can be PICKED UP AND MOVED. That single action is
#      the whole loop; without it the stock is four decisions rather than four tools.
#   3. Bait reads as helping the enemy. Giving food to something you are trying to starve is not an
#      obvious move, and it is the strongest one available -- so it is shown working rather than
#      described.
#   4. They crush ants, which costs five times what a crumb does, and nothing on screen says so
#      until the number drops.
#   5. They never find the long press, so every tool stays a small picture of something.
#
# The spotlights are Callables returning screen-space Rect2s measured off the level (see
# level.tutorial_*_rect). Nothing here carries a radius: this game draws through a camera whose zoom
# depends on the device's creature scale, so an authored number is right on one machine and wrong on
# the next -- the mistake gorilla's tutorial made and had to be rebuilt to undo.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, game) -> Array:
	return [
		{
			"title": "Ants",
			"text": "A colony is carrying food home.\nKeep it out.",
		},
		{
			"text": "Their nest. Everything they pick up goes down that hole.",
			"spot": func(): return level.tutorial_nest_rect(),
			"spot_pad": 8.0,
		},
		{
			"text": "The food they are after.",
			"spot": func(): return level.tutorial_pile_rect(),
			"spot_pad": 8.0,
		},
		{
			# Watching the trail form is the single most useful thing a player can understand here,
			# and it cannot be told -- only watched. watch_only, so the board runs but the step does
			# not invite a tap, and no spotlight, because a spotlight says "act here".
			"title": "Watch",
			"text": "Nobody leads them. One finds the food, carries a crumb home, and lays a scent.\nOthers follow it. Watch the road appear.",
			# A narrow column in the TOP RIGHT. The nest is top left and the food bottom right, so
			# the whole story of these steps happens along that diagonal -- a full-width caption, or
			# even a centred side one, lies straight across the thing the player is being told to
			# watch.
			"caption_side": "right",
			"caption_side_align": "top",
			"watch_only": true,
			"await": {"event": "crumb_through", "timeout": 75.0},
		},
		{
			"text": "Every crumb home costs you one.\nRun out and you lose. Outlast the clock and you win.",
		},
		{
			"title": "Your tools",
			"text": "Tap the ground to see your tools.",
			"spot": func(): return level.tutorial_trail_rect(),
			"await": {"event": "menu_opened", "timeout": 60.0},
			"hint_after": 8.0,
			"hint": "Tap the ground, near their road.",
		},
		{
			"text": "HOLD a tool to read what it does.",
			"await": {"event": "tip_shown", "timeout": 60.0},
			"hint_after": 8.0,
			"hint": "Hold your finger on one of them, do not just tap it.",
		},
		{
			# The menu is OPENED for them and the one box being talked about is lit. A step that
			# names a tool and then leaves the player to find it among eight small pictures is
			# teaching the ring, not the twig -- and the ring was taught two steps ago.
			"setup": func(): level.tutorial_open_menu(),
			"text": "That is the twig. Tap it and it lands across their road.",
			"spot": func(): return level.tutorial_menu_cell_of(AntObstacle.Kind.TWIG),
			"spot_pad": 6.0,
			"await": {"event": "obstacle_placed", "timeout": 90.0},
			"hint_after": 10.0,
			"hint": "Tap the twig.",
		},
		{
			"title": "They will find a way round",
			"text": "Nothing stops them for good. Watch a new road appear past it.",
			# A narrow column in the TOP RIGHT. The nest is top left and the food bottom right, so
			# the whole story of these steps happens along that diagonal -- a full-width caption, or
			# even a centred side one, lies straight across the thing the player is being told to
			# watch.
			"caption_side": "right",
			"caption_side_align": "top",
			"watch_only": true,
			# A doing step, because the board has to RUN for the thing being watched to happen --
			# but it ends on the road re-forming rather than on any notification, so the awaited
			# event is deliberately one nothing emits. advance_when carries it; the timeout is the
			# floor if the colony is slow.
			"advance_when": func(): return level.tutorial_trail_strength() > 2.0,
			"await": {"event": "_watch_only_never_fires", "timeout": 30.0},
		},
		{
			# The action nobody discovers on their own, and the one the whole game runs on. Opened
			# ON the twig, because the red cross only exists in a menu raised over something.
			"setup": func(): level.tutorial_open_menu(true),
			"text": "You have few of each. That cross takes the twig back.",
			"spot": func(): return level.tutorial_menu_cell_of(-1),
			"spot_pad": 6.0,
			"await": {"event": "obstacle_removed", "timeout": 75.0},
			"hint_after": 10.0,
			"hint": "Tap the thing you placed, then choose the red cross.",
		},
		{
			"title": "Bait",
			"setup": func(): level.tutorial_open_menu(),
			"text": "This is bait: food you do not mind losing.\nDrop some on their road.",
			"spot": func(): return level.tutorial_menu_cell_of(AntObstacle.Kind.LURE),
			"spot_pad": 6.0,
			"await": {"event": "bait_placed", "timeout": 90.0},
			"hint_after": 12.0,
			"hint": "Tap the orange pile.",
		},
		{
			"text": "They will carry that home instead, for free.\nEvery such trip is one not spent on your pile.",
			# A narrow column in the TOP RIGHT. The nest is top left and the food bottom right, so
			# the whole story of these steps happens along that diagonal -- a full-width caption, or
			# even a centred side one, lies straight across the thing the player is being told to
			# watch.
			"caption_side": "right",
			"caption_side_align": "top",
			"watch_only": true,
			"await": {"event": "bait_taken", "timeout": 75.0},
		},
		{
			"text": "Never drop anything on an ant.\nCrushing one costs five times a crumb.",
		},
		{
			"title": "Go on then",
			"text": "Keep them off it until the clock runs out.",
		},
	]

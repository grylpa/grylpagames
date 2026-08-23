extends RefCounted

# Nudge's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time Nudge player actually gets wrong, in order of damage:
#   1. They try to drag the tool by its colored disc — the part that looks like the handle. The
#      grab point is the ring BELOW it (level._grab_at), deliberately, so the finger stays off the
#      disc and out of the ball's way. A player who never finds it concludes the tool is scenery.
#   2. They ignore color. A tool only collides with balls of its own color (color = physics layer);
#      pushing a red ball with the blue tool does nothing at all, which reads as a broken game
#      rather than as the rule it is.
#   3. They push a ball up into the basket from underneath and are baffled that it did not count.
#      A ball only scores if it came in over the rim from above (the "armed" flag in level._process).
#
# Nothing here is left to the spawn timer: level.tutorial_hold_spawn is on for the whole tutorial
# and every ball is placed by a step (tutorial_spawn_ball / tutorial_ensure_ball). A ball arriving
# on its own in the middle of a caption is the game free-running when it matters.

const LEVEL_ID: int = 1
const RED: int = 0
const BLUE: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var ball_spot: Callable = func():
		return level.tutorial_ball_pos() if level.tutorial_has_ball() else null

	return [
		{
			"title": "Nudge",
			"text": "Colored balls fall from the top.\n\nEvery ball belongs in the basket of its own color.",
		},
		{
			"text": "These are the baskets — one per color, down the sides.",
			"spot": func(): return level.tutorial_all_baskets_rect(),
			"spot_pad": 6.0,
		},
		{
			"title": "Your tool",
			"text": "This is the red tool. There is one for each color.\n\nIt pushes red balls, and only red balls — every other color falls straight through it.",
			"spot": func(): return level.tutorial_tool_rect(RED),
			"spot_pad": 10.0,
		},
		{
			# The one thing a player cannot guess: the handle is the ring, not the disc.
			"text": "Hold it by the ring underneath, and drag.\n\nTake hold of it now.",
			"spot": func(): return level.tutorial_tool_loop(RED),
			"spot_radius": 54.0,
			"await": {"event": "tool_grabbed", "timeout": 60.0},
			"hint_after": 8.0,
			"hint": "Press on the small ring below the disc.",
		},
		{
			"setup": func():
				level.tutorial_release_drag()
				level.tutorial_spawn_ball(RED),
			"title": "Here it comes",
			"text": "A red ball.\n\nIt falls slowly — you have time.",
			"spot": ball_spot,
			"spot_radius": 60.0,
		},
		{
			"setup": func(): level.tutorial_release_drag(),
			"text": "Push it across and drop it into the red basket, over the rim from above.",
			"await": {"event": "ball_scored", "timeout": 180.0},
			# A ball missed or wedged while the player is still finding the controls would leave
			# nothing on screen to practise on, so quietly put another one up.
			"tick": func(): level.tutorial_ensure_ball(RED),
			"hint_after": 15.0,
			"hint": "Slide the disc under the ball and lift it up and over.",
		},
		{
			"title": "Over the rim",
			"text": "A ball only counts if it drops in from above.\n\nShoving one up through the bottom of a basket does nothing.",
			"spot": func(): return level.tutorial_basket_rect(RED),
			"spot_pad": 8.0,
		},
		{
			"setup": func():
				level.tutorial_release_drag()
				level.tutorial_spawn_ball(BLUE),
			"text": "A blue ball. The red tool cannot touch it at all.\n\nUse the blue tool, and put it away in the blue basket.",
			"spot": func(): return level.tutorial_tool_rect(BLUE),
			"spot_pad": 10.0,
			"await": {"event": "ball_scored", "timeout": 180.0},
			"tick": func(): level.tutorial_ensure_ball(BLUE),
			"hint_after": 15.0,
			"hint": "The blue tool, by its ring — the red one goes right through this ball.",
		},
		{
			# No spotlight. It framed the strip of floor a ball is lost through — which is empty
			# space with nothing in it, so the ring read as pointing at nothing at all. The
			# sentence says the whole thing on its own.
			"title": "Don't drop them",
			"text": "A ball that reaches the floor is lost, and costs you points.",
		},
		{
			"title": "Ready",
			"text": "Sort every ball before the clock runs out.\n\nThe balls come faster, and there are more colors, as you go.",
		},
	]

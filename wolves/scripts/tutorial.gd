extends RefCounted

# Wolves' coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time Wolves player actually gets wrong, in order of damage:
#   1. They do not know they can DRAW a path. Wolves and storm are the only two games in the app
#      where MainGlobals.draw_path_mode is on, so nothing the player has learned elsewhere
#      suggests it — everywhere else a finger drag is a flick, a swipe answer, or a drag of an
#      object. It is taught first, and the player has to actually draw one.
#   2. They try to push or herd the sheep. You never touch them: you get NEAR them and they
#      startle back where they belong. Nothing on screen says so.
#   3. They guard the wolves and forget the fence. Most sheep are lost to gaps in the fence,
#      not to wolves.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var dog_spot: Callable = func():
		return level.player if level.player != null and is_instance_valid(level.player) else null

	# An animated finger-trail starting at the dog, so the gesture is SHOWN rather than described:
	# a hand traces the route, then the dog follows the same line. "Draw a path" is a sentence
	# nobody has had to act on anywhere else in the app, and words alone were not getting it
	# across. The route comes from the game's own pathfinder (tutorial_demo_route), so it is one
	# the dog could really walk — an invented zig-zag pointed straight through the fence.
	var demo_path: Callable = func():
		return level.tutorial_demo_route()

	return [
		{
			"title": "Wolves",
			"text": "You are the dog.\n\nKeep the sheep inside the compound.",
		},
		{
			"text": "Draw a route with your finger and the dog walks it — like this.\n\nArrow keys work too: one sets the dog going that way until something stops it.",
			"spot": dog_spot,
			"spot_radius": 70.0,
			"demo_path": demo_path,
		},
		{
			"text": "Trace a route by drawing it with your finger.",
			"await": {"event": "path_drawn", "timeout": 60.0},
			"demo_path": demo_path,
			"hint_after": 10.0,
			"hint": "Press down, drag along the route without lifting, then let go.",
		},
		{
			"title": "The flock",
			"text": "The fence keeps breaking, and sheep wander out through the gaps.\n\nA sheep that strays too far is gone for good.",
		},
		{
			"title": "Herding",
			"text": "You never push a sheep. Get close, the dog barks, and the sheep runs back where it belongs.",
		},
		{
			"text": "Try it. Walk up to a stray.",
			"await": {"event": "scared_one", "timeout": 90.0},
			"hint_after": 15.0,
			"hint": "Draw a route ending right beside a sheep that is outside the fence.",
		},
		{
			"title": "Wolves",
			"text": "Wolves come for the flock, and run off the same way if you get close.\n\nBut a wolf that reaches a sheep first eats it.",
		},
		{
			"title": "Ready",
			"text": "Watch the fence, not just the wolves. Most sheep are lost through the gaps.",
		},
	]

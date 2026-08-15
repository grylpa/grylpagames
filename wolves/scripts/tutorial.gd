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
			"text": "You are the dog guarding a sheep compound.",
		},
		{
			"text": "This is you.",
			"spot": dog_spot,
			"spot_radius": 70.0,
		},
		{
			"title": "Drawing a path",
			"text": "Here you can DRAW where you want the dog to go.\n\nPut your finger down and trace a route without lifting — like this — and let go. The dog walks the whole line on its own.",
			"spot": dog_spot,
			"spot_radius": 70.0,
			"demo_path": demo_path,
		},
		{
			"text": "Your turn — trace a route across the ground.",
			"await": {"event": "path_drawn", "timeout": 60.0},
			"demo_path": demo_path,
			"hint_after": 10.0,
			"hint": "Press down anywhere on the grass, drag along the route you want WITHOUT lifting your finger, then let go.",
		},
		{
			"text": "That is how you get about, and it is much quicker than steering.\n\nThe arrow keys work too, but differently: an arrow sets the dog walking that way and it keeps going until something stops it.",
		},
		{
			"title": "The flock",
			"text": "Sheep belong inside the compound. The fence is old, and pieces of it keep falling away — so sheep wander out through the gaps.\n\nA sheep that strays too far is gone for good.",
		},
		{
			"title": "How you herd",
			"text": "You never push a sheep.\n\nYou get CLOSE to it, the dog barks, and the sheep startles back where it belongs.",
		},
		{
			"text": "Go and startle a stray sheep back in — just walk up close to one.",
			"await": {"event": "scared_one", "timeout": 90.0},
			"hint_after": 15.0,
			"hint": "Draw a path that ends right next to a sheep that is outside the fence.",
		},
		{
			"text": "That is the whole job.",
		},
		{
			"title": "And the wolves",
			"text": "Wolves come for the flock. Get close and they run off the same way.\n\nBut if a wolf reaches a sheep before you do, that sheep is eaten — so it is worth heading them off early.",
		},
		{
			"title": "Ready",
			"text": "Watch the fence, not just the wolves. Most sheep are lost through the gaps.\n\nNothing you did here was scored — your real game starts from the menu.",
		},
	]

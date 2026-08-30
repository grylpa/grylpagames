extends RefCounted

# Storm's coached tutorial. See docs/tutorials.md for the step schema.
#
# Storm is the densest game in the app to teach, and the four things below are all invisible:
#   1. You can only act on a leak you are STANDING NEXT TO. Tapping one from across the room does
#      nothing whatsoever — no message, no sound — so the first thing a player learns is that the
#      game ignores them. Taught before anything else, and the level reports `tapped_too_far` so
#      the coach can explain the silence at the exact moment it happens.
#   2. Movement is a DRAWN PATH. Storm and wolves are the only two games in the app where
#      MainGlobals.draw_path_mode is on, so nothing learned elsewhere suggests it. Since reaching
#      a leak in time is the whole game, walking badly is losing.
#   3. The score starts at 100 and only ever falls. A number counting down with no explanation
#      reads as a bug or a timer.
#   4. Tools fill up. A bucket left under a leak stops working and starts costing you, and it has
#      to be carried to a drain — taught last, because it only bites after a minute of play.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var player_spot: Callable = func():
		return level.player if level.player != null and is_instance_valid(level.player) else null

	# Same demo as wolves — storm is the only other game with drawn paths — and for the same
	# reason it uses the game's own pathfinder rather than an invented shape: a made-up zig-zag
	# runs straight through walls and furniture.
	var demo_path: Callable = func():
		return level.tutorial_demo_route()

	return [
		{
			"title": "Storm",
			"text": "The roof leaks.\n\nKeep the water off your things.",
		},
		{
			"text": "Draw a route with your finger or mouse and you walk it — like this.\n\nArrow keys work too: one sets you going that way until something stops you.",
			"spot": player_spot,
			"spot_radius": 70.0,
			"demo_path": demo_path,
		},
		{
			"text": "Your turn. Trace a route.",
			"await": {"event": "path_drawn", "timeout": 60.0},
			"demo_path": demo_path,
			"hint_after": 10.0,
			"hint": "Press down, drag along the route without lifting, then let go.",
		},
		{
			"text": "Here comes the first leak.",
			"await": {"event": "leak_started", "timeout": 40.0},
		},
		{
			"title": "You must be beside it",
			"text": "Tapping a leak from across the room does nothing at all — no message, no sound.\n\nWalk to it, tap it, and pick something to catch the water.",
			"await": {"event": "tool_placed", "timeout": 120.0},
			"hint_after": 20.0,
			"hint": "Draw a route ending right next to the water, THEN tap it.",
		},
		{
			"title": "Your score",
			"text": "It starts at 100 and only falls. It is what is left of your belongings, not points you are earning.",
		},
		{
			"title": "Buckets fill",
			"text": "A full one stops catching and the water gets through again.\n\nYou tap it, carry it to a drain, and empty it there.",
		},
		{
			"title": "Ready",
			"text": "Keep moving, and keep ahead of the leaks.",
		},
	]

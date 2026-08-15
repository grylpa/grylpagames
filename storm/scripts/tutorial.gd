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
			"text": "A storm is coming, and the roof is not what it was.\n\nYour job is to keep the water off your things.",
		},
		{
			"text": "This is you.",
			"spot": player_spot,
			"spot_radius": 70.0,
		},
		{
			"title": "Getting about",
			"text": "You move by DRAWING a path.\n\nPut your finger down and trace where you want to go without lifting — like this — then let go. You walk the whole line on your own.",
			"spot": player_spot,
			"spot_radius": 70.0,
			"demo_path": demo_path,
		},
		{
			"text": "Your turn — trace a route across the floor.",
			"await": {"event": "path_drawn", "timeout": 60.0},
			"demo_path": demo_path,
			"hint_after": 10.0,
			"hint": "Press down anywhere on the floor, drag along the route you want WITHOUT lifting, then let go.",
		},
		{
			"text": "The arrow keys work too, but differently: an arrow sets you walking that way until something stops you.",
		},
		{
			"text": "Good. Getting somewhere quickly is most of this game.",
		},
		{
			"text": "Now let's wait for the roof to start leaking.",
			"await": {"event": "leak_started", "timeout": 40.0},
		},
		{
			"title": "The catch",
			"text": "There is water coming in.\n\nBut you cannot deal with a leak from across the room — you have to be standing right beside it.",
		},
		{
			"text": "Walk over to a leak, then tap it.\n\nTapping one you are not next to does nothing at all — no message, nothing. That silence is the single most confusing thing in this game, so remember it.",
			"await": {"event": "tool_placed", "timeout": 120.0},
			"hint_after": 20.0,
			"hint": "Draw a path so you end up right next to the water, THEN tap it and pick something from the panel.",
		},
		{
			"text": "That is the loop: get there, tap, put something under it.",
		},
		{
			"title": "Your things",
			"text": "Water that is not caught ruins whatever it lands on, and that is what costs you.\n\nYour score starts at 100 and only ever goes DOWN — it is what is left of your belongings, not points you are earning.",
		},
		{
			"title": "One more thing",
			"text": "Buckets fill up. A full one stops catching anything and the water starts getting through again.\n\nTap a full one to pick it up, carry it to a drain, and empty it there.",
		},
		{
			"title": "Ready",
			"text": "Keep moving, and keep ahead of the leaks.\n\nNothing you did here was scored — your real game starts from the menu.",
		},
	]

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
#   3. The score starts at 100, and what you lose costs its value: a screen 20, a flower or a rug 5,
#      so what to protect first is a choice. Then the HUD's "Worst: N%" -- the wettest room, and the
#      line (the level's room_ruin) at which it loses the round.
#   4. Tools fill up. A bucket left under a leak stops working and costs a point when it runs over,
#      and it has to be carried to a drain; emptying one more than half full earns 5 -- taught late,
#      because it only bites after a minute of play. The last card says what a won round is worth.
#
# The numbers in the captions are the game's own (level.gd's `furniture`, DRAIN_POINTS, WIN_POINTS,
# the tutorial level's room_ruin), so the lesson cannot drift from the scoring.

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

	# The HUD's "Worst: N%" label, which spans the strip: spotlit at the middle, where its text is.
	var worst_spot: Callable = func():
		var lbl = level.get_parent().get("_flood_label")
		if lbl == null or not is_instance_valid(lbl):
			return null
		return (lbl as Control).get_global_rect().get_center()

	# From the tutorial level's own row: new_game() applies it only after its build wait, so here
	# room_ruin() could still be the level the player was on.
	var line_pct: int = int(round(float(StormLevelConfig.get_level(LEVEL_ID).get("room_ruin", 0.4)) * 100.0))
	var worth: Dictionary = level.furniture
	var screen_pts: int = int(worth["screen"][1])
	var small_pts: int = int(worth["flower"][1])

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
			"text": "It starts at 100. A ruined belonging costs its value: the screen %d, a flower or a rug %d.\n\nSave the valuable ones first." % [screen_pts, small_pts],
		},
		{
			"title": "Worst",
			"text": "This is your wettest room. If it reaches %d%% under water, the room is lost, and so is the round." % line_pct,
			"spot": worst_spot,
			"spot_radius": 80.0,
		},
		{
			"title": "Buckets fill",
			"text": "A full one stops catching, and the water running over it costs you %d %s.\n\nYou tap it, carry it to a drain, and empty it there: +%d if it was more than half full." % [level.OVERFLOW_POINTS, "point" if level.OVERFLOW_POINTS == 1 else "points", level.DRAIN_POINTS],
		},
		{
			"title": "Ready",
			"text": "Get through the storm for +%d, plus a point for every percent your wettest room stayed under %d%%.\n\nKeep moving, and keep ahead of the leaks." % [level.WIN_POINTS, line_pct],
		},
	]

extends RefCounted

# Lighthouse's coached tutorial. See docs/tutorials.md for the step schema.
#
# Four things the dark hides, taught in the order a player meets them:
#   1. What can be seen at all: only what a light is on -- the lighthouse's turning beam and the
#      boat's own light -- and the green light that marks the jetty, the goal.
#   2. Movement is a DRAWN ROUTE, sailed as drawn (never snapped to anything), with a tap on the sea
#      to go straight somewhere and a tap on the boat to stop. Shown with a demo first.
#   3. Crashes: the HUD's lifebuoys count them down, and the crash that reaches the level's maximum
#      loses the round.
#   4. Memory: on many levels the sea is the same every round, so what the light showed is worth
#      remembering. Said last, once the player has seen the beam reveal things.
#
# The tutorial plays level 1 for real (tutorial_mode: nothing is saved, the level's clock does not
# run, and a lost round simply starts again), and ends when the boat reaches the jetty.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var boat_spot: Callable = func():
		return level.boat_pos
	var lighthouse_spot: Callable = func():
		return level._lh_pos
	var jetty_spot: Callable = func():
		return (level._pier as Rect2).grow(14.0)
	var lives_spot: Callable = func():
		var hud: Node = level.get_parent().get_node_or_null("HUD")
		var box = hud.get_node_or_null("LivesContainer") if hud != null else null
		return (box as Control).get_global_rect() if box != null else null
	var demo_path: Callable = func():
		return level.tutorial_demo_route()
	# Captions keep off what they are teaching: the demo route with the boat and its light, or just
	# the boat and the sea ahead of it.
	var demo_zone: Callable = func():
		return level.tutorial_demo_rect()
	var boat_zone: Callable = func():
		return level.tutorial_boat_rect()
	var lighthouse_zone: Callable = func():
		return Rect2(level._lh_pos, Vector2.ZERO).grow(float(level._lh_r) * 3.0)
	var jetty_zone: Callable = func():
		return (level._pier as Rect2).grow(30.0)
	var lives: int = int(LighthouseLevelConfig.get_level(LEVEL_ID).get("max_crashes", 3))

	return [
		{
			"title": "Lighthouse",
			"text": "Sail your boat across the sea at night, from the bottom to the jetty at the top.",
		},
		{
			"text": "The lighthouse turns its beam round and round. Rocks and wrecks show only while a light is on them.",
			"spot": lighthouse_spot,
			"spot_radius": 60.0,
		},
		{
			"text": "That green light at the top marks the jetty. Touch the jetty with your boat to finish the crossing.",
			"spot": jetty_spot,
		},
		{
			"text": "Draw a route from your boat, and it sails it, like this.\n\nYour boat carries a small light of its own, ahead of it.",
			"spot": boat_spot,
			"spot_radius": 50.0,
			"demo_path": demo_path,
			"keep_clear": [demo_zone],
		},
		{
			"text": "Your turn. Draw a route from the boat.",
			"await": {"event": "route", "timeout": 60.0},
			"demo_path": demo_path,
			"keep_clear": [demo_zone],
			"hint_after": 10.0,
			"hint": "Press down near the boat, drag where it should go, then let go.",
		},
		{
			"text": "Tap the boat to stop it.",
			"spot": boat_spot,
			"spot_radius": 50.0,
			"await": {"event": "stopped", "timeout": 40.0},
			"keep_clear": [boat_zone],
			"hint_after": 10.0,
			"hint": "A quick tap right on the boat.",
		},
		{
			"text": "A tap on the sea sends it straight there. Try it.",
			"await": {"event": "route", "timeout": 40.0},
			"keep_clear": [boat_zone],
			"hint_after": 10.0,
			"hint": "Tap anywhere on the sea.",
		},
		{
			"title": "Crashes",
			"text": "These lifebuoys count your crashes. Each crash costs one, and this round is lost at %d crashes.\n\nWhen the sea is the same every round, each round allows one crash fewer." % lives,
			"spot": lives_spot,
			"spot_radius": 50.0,
		},
		{
			"title": "A whole crossing",
			"text": "Now a whole crossing, from the boat, around the lighthouse, to the green light at the top.\n\nIf the light shows a rock in your way, you can draw a new route around it at any time.",
		},
		{
			"text": "Sail to the jetty.",
			"await": {"event": "round_won", "timeout": 240.0},
			"keep_clear": [boat_zone, lighthouse_zone, jetty_zone],
			"hint_after": 40.0,
			"hint": "Press near the boat and drag all the way up to the green light, passing beside the lighthouse.",
		},
		{
			"title": "Ready",
			"text": "On many levels the sea is the same every round, so remember what the light showed you, and the crossings get faster.",
		},
	]

extends RefCounted

# Mind Palace's coached tutorial (store and fetch, 2026-11-15). See docs/tutorials.md for the step schema.
#
# Two things are not obvious on sight: that a vault is opened by walking INTO it, and that the round's
# real test comes later, on a plain map -- you must know where in the castle each room is. So the coach
# spots the first vault while saying "remember which room", asks the player to notice the way to
# the second, and stays with them through both questions on the map.
#
# The castle is the smallest the game can build (two rooms, so two objects), and nothing hunts the
# player; see level.gd::_tutorial_setup.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var player_spot: Callable = func():
		var r: Rect2 = level.tutorial_player_rect()
		return r if r.size.x > 0.0 else null
	var pedestal_spot: Callable = func():
		var r: Rect2 = level.tutorial_pedestal_here_rect()
		return r if r.size.x > 0.0 else null

	return [
		{
			"title": "Mind Palace",
			"text": "A castle of rooms joined by corridors. You'll store things in its rooms, then come back for them.",
		},
		{
			# No caption: the castle is still being built behind the opening card when a quick reader
			# taps on, and the next step points at the player, who does not exist yet. The game runs
			# here and the step ends itself the moment the player is on the board.
			"await": {"event": "castle_built", "timeout": 30.0},
			"advance_when": func() -> bool: return level.tutorial_player_rect().size.x > 0.0,
		},
		{
			"text": "This is you. Swipe in a direction and you keep walking that way until you turn. The arrow keys work too.\n\nTry it.",
			"spot": player_spot,
			"spot_radius": 70.0,
			"await": "player_moved",
			"hint_after": 10.0,
			"hint": "A swipe up, down, left or right.",
		},
		{
			"setup": func() -> void: level.tutorial_halt_player(),
			"title": "Vaults",
			"text": "Each room has a vault with something inside. Walk into this one to open it, and remember which room it's in.",
			"spot": pedestal_spot,
			"spot_pad": 18.0,
			"await": "found",
			"hint_after": 12.0,
			"hint": "Walk straight into the vault.",
		},
		{
			"text": func(): return "The %s is in this room.\n\nNow find the other vault: through the corridor, and notice the way you go." % level.tutorial_last_found_name(),
			"await": {"event": "found", "timeout": 120.0},
			"hint_after": 15.0,
			"hint": "Follow the corridor to the other room, and walk into its vault.",
		},
		{
			"text": "That was the last vault. Now the castle is shown from above, as a plain map.",
			"await": {"event": "asked", "timeout": 30.0},
		},
		{
			"title": "The map",
			"text": func(): return "Where is the %s?\n\nEvery room is gray here, so think of where it is in the castle, and tap that room. A wrong room costs a point and shows what's in it." % level.tutorial_request_name(),
			"await": {"event": "room_answered", "timeout": 180.0},
			"hint_after": 20.0,
			"hint": "Which way did you walk after leaving it?",
		},
		{
			"text": func(): return "Right. And the %s?" % level.tutorial_request_name(),
			"await": {"event": "room_answered", "timeout": 180.0},
			"hint_after": 20.0,
			"hint": "Tap the other room.",
		},
		{
			"title": "Ready",
			"text": "That's a round.\n\nLater levels have more rooms, so more vaults and a bigger castle to keep in your head. There are also bombs in the rooms and enemies walking around them. Touching either one ends the round.",
		},
	]

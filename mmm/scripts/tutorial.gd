extends RefCounted

# Mind Palace's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time player actually gets wrong is not a control — it is that the goal is DEFERRED.
# Nothing on screen while you explore says you are being tested on the floor colors, so a newcomer
# collects the coins happily, the map appears, and they are asked a question they had no reason to
# prepare for. By then it is unanswerable: you cannot go back and look.
#
# So the test is announced BEFORE the first coin, with the floor spotlit while it is said, and again
# on the second room. Everything else in the game — the coins, the walking, the corridors — is
# obvious on sight and gets one line each.
#
# The castle is the smallest the game can build (two rooms), the decoy colors are off, and nothing
# hunts the player; see level.gd::_tutorial_setup.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var player_spot: Callable = func():
		return level.player if level.player != null and is_instance_valid(level.player) else null
	# A patch of floor by the player, not the whole room: a room fills most of the screen, so a
	# caption has nowhere to stand that is not on top of it.
	# Captured when the step opens rather than recomputed every frame: the marker is in screen
	# space, and the camera is still gliding after the player stops, so a live rect drifts under a
	# caption that is standing still.
	var coin_spot: Callable = func():
		var r: Rect2 = level.tutorial_coin_here_rect()
		return r if r.size.x > 0.0 else null

	return [
		{
			"title": "Mind Palace",
			"text": "You are in a castle of rooms joined by corridors. There is one coin in each room.",
		},
		{
			"text": "This is you. Swipe a direction and you keep walking that way until you turn — arrow keys too.\n\nTry it.",
			"spot": player_spot,
			"spot_radius": 70.0,
			"await": "player_moved",
			"hint_after": 10.0,
			"hint": "A swipe up, down, left or right.",
		},
		{
			"setup": func() -> void: level.tutorial_halt_player(),
			"title": "The part nobody expects",
			"text": "Look at this room's floor color.\n\nWhen the coins are gone you will be shown the map and asked, room by room, which color each one was. You cannot come back to check.",
		},
		{
			"text": "Take the coin.",
			"spot": coin_spot,
			# Stand the frame well clear of the coin: hugging it looked like a glitch, not a pointer.
			"spot_pad": 18.0,
			"await": "coin_taken",
			"hint_after": 12.0,
			"hint": "Walk onto it.",
		},
		{
			"text": "One room done. Remember its color!\n\nNow find the other one, through the corridor.",
			"await": "room_entered",
			"hint_after": 15.0,
			"hint": "Follow the corridor out of this room.",
		},
		{
			# NO marker. A patch of floor beside the player points at nothing they are being asked
			# to do, and the coin — the thing they ARE being asked for — is usually off screen when
			# this step opens, since they have just walked in and the room is bigger than the view.
			# By now they have taken one coin already and know what to do with the next.
			"setup": func() -> void: level.tutorial_halt_player(),
			"text": "This floor is a different color. Remember this one too, and take its coin.",
			"await": "coin_taken",
			"hint_after": 15.0,
			"hint": "Walk onto the coin in this room.",
		},
		{
			"text": "That was the last coin, so now you are asked.",
			"await": {"event": "map_shown", "timeout": 60.0},
		},
		{
			"title": "The map",
			"text": "Every room you visited is here, with a strip of colors on it.\n\nTap a room's strip, then choose the color that room's floor was. A wrong pick costs a point and leaves the room open, so you can try again.",
			"await": {"event": "room_answered", "timeout": 180.0},
			"hint_after": 20.0,
			"hint": "The swatches are drawn on the room itself.",
		},
		{
			"text": "That room is named and its floor has filled in.\n\nNow the other one — the round is not over until every room has been answered.",
			"await": {"event": "room_answered", "timeout": 180.0},
			"hint_after": 20.0,
			"hint": "Tap the other room's strip, then its color.",
		},
		{
			"title": "Ready",
			"text": "That is a full round.\n\nLater levels give you more rooms to hold, and the strips start including colors that were never in the castle — so elimination will not save you.\n\nBombs sit in the rooms and enemies patrol them. Touching either one ends the round at once.",
		},
	]

extends RefCounted

# Gorilla's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time Gorilla player actually gets wrong, in order of damage:
#   1. They treat it as a coin-collecting game and simply do not notice the gorillas, because
#      nothing on screen ever asks them to look. Then the count question at the end arrives out
#      of nowhere.
#   2. A gorilla runs the whole way across in a few seconds. A player who is reading a caption
#      misses it entirely and has no idea what they were meant to be looking at — so the tutorial
#      does NOT rely on catching one in flight. It holds one still in the center of its lane
#      (level.tutorial_hold_gorilla_midscreen) and points at it while the game is frozen.
#   3. Monsters. They are switched off for the whole tutorial (num_inside_monsters = 0) so nobody
#      is killed halfway through a lesson — but a player who is never shown one meets their first
#      at full speed with no warning, which is the very complaint tutorials exist to fix. So one
#      is spawned on the last teaching step, named, and pointed at, with the game frozen.
#   4. Movement, which is announced nowhere. This game does NOT have the drawn-path movement
#      wolves and storm use (MainGlobals.draw_path_mode is never set here): a quick swipe sets a
#      direction and you keep walking that way until you turn or stop. Saying "draw a path" here
#      would be plainly wrong, and "flick" on its own means nothing to most people.
#
# Monsters are switched off (num_inside_monsters = 0) and two gorillas are scheduled early — see
# level.gd's _tutorial_setup. Being killed halfway through a lesson teaches nothing.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var player_spot: Callable = func():
		return level.player if level.player != null and is_instance_valid(level.player) else null
	var gorilla_spot: Callable = func():
		for g in level.peripheral_gorillas:
			if is_instance_valid(g):
				return g
		return null
	var monster_spot: Callable = func():
		for a in level.agents:
			if is_instance_valid(a):
				return a
		return null

	return [
		{
			"title": "Gorilla",
			"text": "You are in a walled room with coins all over the floor.\n\nCollect every one of them.",
		},
		{
			"text": "This is you. You walk by yourself, and keep going the same way until you turn.",
			"spot": player_spot,
			"spot_radius": 70.0,
		},
		{
			"text": "Swipe in a direction to turn that way. Arrow keys do the same.\n\nTry it.",
			"await": {"event": "player_steered", "timeout": 60.0},
			"hint_after": 10.0,
			"hint": "A quick swipe up, down, left or right.",
		},
		{
			"setup": func():
				level.tutorial_spawn_gorilla()
				level.tutorial_hold_gorilla_midscreen(),
			"title": "The second job",
			"text": "Gorillas walk past outside the wall — like this one.\n\nCount them. They only ever pass along the edges, one at a time.",
			"spot": gorilla_spot,
			"spot_radius": 95.0,
		},
		{
			"title": "Two things at once",
			"text": "Clear the coins, and keep count.\n\nThe coins hold your eyes in the center of the room; the gorillas only ever appear round the outside.",
		},
		{
			"setup": func(): level.tutorial_show_a_monster(),
			"title": "Monsters",
			"text": "Monsters share the room and chase you. Being caught costs a life.",
			"spot": monster_spot,
			"spot_radius": 60.0,
		},
		{
			"title": "Ready",
			"text": "When the coins are gone, or the time is up, you are asked how many gorillas went past.\n\nGet it right for a bonus.",
		},
	]

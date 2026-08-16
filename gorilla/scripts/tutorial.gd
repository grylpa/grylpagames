extends RefCounted

# Gorilla's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time Gorilla player actually gets wrong, in order of damage:
#   1. They treat it as a coin-collecting game and simply do not notice the gorillas, because
#      nothing on screen ever asks them to look. Then the count question at the end arrives out
#      of nowhere.
#   2. A gorilla runs the whole way across in a few seconds. A player who is reading a caption
#      misses it entirely and has no idea what they were meant to be looking at — so the tutorial
#      does NOT rely on catching one in flight. It holds one still in the middle of its lane
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
			"text": "You are inside a walled room, and the floor is covered in coins.",
		},
		{
			"text": "This is you.",
			"spot": player_spot,
			"spot_radius": 70.0,
		},
		{
			"title": "You are already walking",
			"text": "Notice you did not have to start. You walk by yourself, and you keep going in the same direction until you turn.\n\nWalking over a coin picks it up.",
			"spot": player_spot,
			"spot_radius": 70.0,
		},
		{
			# Waits for a real steer, not a coin. The player is ALWAYS walking
			# (GorillaG.always_moving), so a "collect a coin" step gets satisfied by the game
			# wandering into one on its own — and the coach then congratulates you for nothing.
			"text": "So all you do is steer. Swipe in a direction — a short, fast drag anywhere on the screen — and you turn that way. Arrow keys work too.\n\nTry turning now.",
			"await": {"event": "player_steered", "timeout": 60.0},
			"hint_after": 10.0,
			"hint": "A quick swipe up, down, left or right — or tap an arrow key.",
		},
		{
			"text": "That is the steering. Your first job is to clear ALL the coins in the room.\n\nThe round ends when the last one is gone, or when the time runs out.",
		},
		{
			# Spawn AND hold in one step, with no `await`.
			#
			# These were two steps: one that spawned a gorilla and waited for `gorilla_appeared`,
			# and one that talked about it. But the spawn fires that event synchronously, so the
			# waiting step was satisfied during its own setup and advanced immediately — displayed
			# for zero frames, which is what made the stage numbers skip (6/13 then 8/13).
			# The wait was pointless anyway: the gorilla exists the moment the setup returns.
			#
			# The gorilla is asked for here rather than left to the level's timed schedule because
			# on the schedule one ran past while the coach was still talking about coins, and a
			# different one was held up later — which read as a gorilla appearing from nowhere.
			# Holding it mid-lane matters too: otherwise the coach describes one that has already
			# run off the edge.
			"setup": func():
				level.tutorial_spawn_gorilla()
				level.tutorial_hold_gorilla_midscreen(),
			"title": "There is a second job",
			"text": "While you are collecting, gorillas walk past OUTSIDE the room — like this one.\n\nIt is frozen so you can get a proper look. In the real game it walks straight past in seconds.",
			"spot": gorilla_spot,
			"spot_radius": 95.0,
		},
		{
			"text": "Gorillas like that one are what you have to COUNT.\n\nThey only ever walk along the edges, outside the wall, and only one at a time.",
			"spot": gorilla_spot,
			"spot_radius": 95.0,
		},
		{
			"title": "Two things at once",
			"text": "So: clear every coin, and keep a running count of the gorillas.\n\nThe coins pull your eyes into the middle of the room. The gorillas only ever appear round the outside. That is the whole difficulty.",
		},
		{
			"text": "When the coins are gone or the time is up, you will be asked how many gorillas went past.\n\nGet the number right and you take a bonus.",
		},
		{
			# Monsters are off for the whole tutorial so nobody is killed mid-lesson, but a player
			# who has never been shown one meets their first at full speed with no warning.
			"setup": func(): level.tutorial_show_a_monster(),
			"title": "One thing you have been spared",
			"text": "This is a monster. In a real round there are some of these in the room with you, and they chase you.",
			"spot": monster_spot,
			"spot_radius": 60.0,
		},
		{
			"text": "Let one catch you and it costs you a life. They have been switched off for this tutorial — from now on they will not be.",
			"spot": monster_spot,
			"spot_radius": 60.0,
		},
		{
			"title": "Ready",
			"text": "Collect, and count.\n\nNothing you did here was scored — your real game starts from the menu.",
		},
	]

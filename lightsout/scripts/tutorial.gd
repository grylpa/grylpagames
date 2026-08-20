extends RefCounted

# Lights Out's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time player actually gets wrong:
#   1. They do not realise the board is about to GO DARK. It is lit for five seconds and then the
#      targets, the doors and most of the maze disappear — a player who spent those seconds reading
#      the HUD instead of the board is left walking blind with nothing memorized.
#   2. They do not know which target is theirs. Several are on the board; only the receiver
#      carrying their transaction counts, and the rest include bombs.
#   3. They try to move while the lights are on. The first input is what puts them out, so the
#      look-phase and the walk-phase are the same button — nothing says "you are spending your
#      memorising time".
#
# So the coach holds the lights ON (level.tutorial_hold_lights), names the three things worth
# memorising — you, your target, a bomb — and only then puts them out.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var me: Callable = func():
		var p: Vector2 = level.tutorial_player_pos()
		return null if p == Vector2.ZERO else p
	var goal: Callable = func():
		var p: Vector2 = level.tutorial_goal_pos()
		return null if p == Vector2.ZERO else p

	return [
		{
			"title": "Lights Out",
			"text": "A maze, a destination, and a few bombs.\n\nThe lights are about to go out.",
		},
		{
			"text": "This is you.",
			"spot": me,
			"spot_radius": 60.0,
		},
		{
			"text": "And this is where you are going. Only this one counts — the other markers are not yours.",
			"spot": goal,
			"spot_radius": 60.0,
		},
		{
			"text": "A bomb. The run ends if you touch one, so it is worth remembering where they are.",
			"spot": func():
				var p: Vector2 = level.tutorial_bomb_pos()
				return null if p == Vector2.ZERO else p,
			"spot_radius": 60.0,
		},
		{
			# Short on purpose: the caption has to share the screen with the player, the target and
			# a bomb, all three of which the step is asking to be memorized.
			"title": "Learn the way",
			"text": "This is your one look at the board. In a real round it lasts five seconds.",
			"spot": goal,
			"spot_radius": 60.0,
		},
		{
			# Only NOW do the lights go out — and only now may a caption ask for movement.
			"setup": func(): level.tutorial_lights_out(),
			# Descriptive only — the board is frozen while this is up. The instruction to move is
			# on the next step, which is the one that accepts it.
			"title": "Lights out",
			"text": "The markers are gone and the maze has dimmed.",
			"spot": me,
			"spot_radius": 60.0,
		},
		{
			# Reactive: walking into a bomb is survivable here, but silence would leave the player
			# wondering what just happened and why they are still going.
			"text": func():
				if level.tutorial_bomb_was_hit():
					return "That was a bomb. In a real round it would have ended your run right there.\n\nKeep going — your target is still out there."
				return "Swipe, or use the arrow keys, to walk — you keep going until you turn.\n\nFind your target from memory.",
			"await": {"event": "delivered", "timeout": 300.0},
			"hint_after": 25.0,
			"hint": "Lost? Tap Clue for a glimpse of the board — it costs a point.",
		},
		{
			# The real board also carries obstacle agents on the pipes (add_random_static_agents),
			# which the tutorial board deliberately does not — one wandering into the player would
			# kill them over a hazard no step had taught. Say they exist, so meeting one later is
			# not a surprise.
			"title": "Ready",
			"text": "Real boards also have obstacles sitting in the maze — just as bad to walk into.\n\nBigger mazes, more bombs, less time to look. Clue relights the board for an instant whenever you need it.",
		},
	]

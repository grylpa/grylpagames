extends RefCounted

# Pneumo's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time player actually gets wrong:
#   1. They try to steer the capsule. It rides the tubes by itself; the only control is the DOORS,
#      and a turned door deflects whatever passes through it.
#   2. They do not know capsules are MATCHED. Several receivers sit on the board and a capsule only
#      counts at the one carrying its own color — passing any other does nothing at all.
#   3. They ignore the second rule entirely. Two capsules touching destroys both, and both have to
#      be sent again. That is the whole reason you cannot simply open every door and walk away —
#      and with one capsule on screen there is nothing to hint at it.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	# 1.5 tiles across. A fixed pixel radius swallows a cluster of junctions and doors, so the frame
	# stops naming one thing. Derived from tile_size so it holds for whatever board a level builds;
	# steps() runs after the board exists. spot_pad is zeroed on each of these because the runner's
	# default pad is added ON TOP of the radius.
	var frame_r: float = maxf(12.0, level.game.tile_size * 0.75)
	var capsule: Callable = func():
		var p: Vector2 = level.tutorial_capsule_pos()
		return null if p == Vector2.ZERO else p
	var door: Callable = func():
		var p: Vector2 = level.tutorial_next_door_pos()
		return null if p == Vector2.ZERO else p

	return [
		{
			"title": "Pneumo",
			"text": "Capsules ride the pneumatic tubes.\n\nEach one belongs at a particular receiver, and it is your job to get it there.",
		},
		{
			"await": {"event": "capsule_sent", "timeout": 60.0},
		},
		{
			"setup": func(): level.tutorial_hold_new_capsules(true),
			"text": "Here is one. It travels by itself — you never push it along.",
			"spot": capsule,
			"spot_radius": frame_r,
			"spot_pad": 0.0,
		},
		{
			"text": "This is the receiver it belongs to. Any other one will simply ignore it.",
			"spot": func():
				var p: Vector2 = level.tutorial_receiver_pos()
				return null if p == Vector2.ZERO else p,
			"spot_radius": frame_r,
			"spot_pad": 0.0,
		},
		{
			# Freeze the capsules: the next step is an ACTION step, so the game is unpaused and a
			# capsule would glide off the very door being pointed at while the player looks for it.
			"setup": func(): level.tutorial_freeze_capsules(true),
			"title": "The doors",
			"text": "Doors sit at the junctions, and a turned one sends a capsule off sideways.\n\nThey are the only thing you control.",
			"spot": door,
			"spot_radius": frame_r,
			"spot_pad": 0.0,
		},
		{
			"text": "Tap this door to turn it.",
			"spot": door,
			"spot_radius": frame_r,
			"spot_pad": 0.0,
			"await": {"event": "door_turned", "timeout": 120.0},
			"hint_after": 12.0,
			"hint": "Tap the framed door.",
		},
		{
			"setup": func():
				level.tutorial_freeze_capsules(false)
				level.tutorial_hold_new_capsules(false),
			# Reactive: a collision is the one thing that can go wrong here, and it needs naming
			# the moment it happens rather than in the abstract.
			"text": func():
				if level.tutorial_has_capsule():
					return "Now set the doors so it reaches its own receiver."
				return "Both capsules were destroyed. They will be sent again — that is what a collision costs.",
			"await": {"event": "delivered", "timeout": 300.0},
			"hint_after": 25.0,
			"hint": "Turn the doors ahead of it. It delivers by passing alongside its receiver.",
		},
		{
			"title": "Two at once",
			"text": "More capsules follow, and they share the tubes.\n\nLet two touch and both are destroyed — so the doors have to keep them apart as well as on course.",
		},
		{
			"title": "Ready",
			"text": "Longer runs, more capsules, and less time between them.",
		},
	]

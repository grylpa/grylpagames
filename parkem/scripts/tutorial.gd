extends RefCounted

# Parkem's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time player actually gets wrong:
#   1. They play it as a delivery game. Every other game in this family is about GETTING something
#      somewhere; here the creatures drive themselves to their own parking spots and the player's
#      whole job is to stop them arriving. Nothing on screen says the goal is inverted.
#   2. They do not know the doors are the controls, or that a door is a TOGGLE with a timer — one
#      tap swings it shut, and it springs back open after four seconds on its own.
#   3. They wait for something to happen to the creature. Nothing does: a creature that is kept
#      away simply gives up after ten seconds. Turning it aside IS the win, and it is quiet.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	# 1.5 tiles across, measured. A fixed pixel radius came out around 3x3 tiles on this board,
	# which swallows a whole cluster of junctions and hatches — the frame stops naming one thing.
	# Derived from tile_size so it holds for whatever size board a level builds; steps() runs after
	# the board exists. Every one of these steps also sets spot_pad to 0: the runner's default pad
	# is added on top of the radius, which is what turned an intended 1.5 tiles into 2.
	var frame_r: float = maxf(12.0, level.game.tile_size * 0.75)
	var creature: Callable = func():
		var p: Vector2 = level.tutorial_creature_pos()
		if p == Vector2.ZERO:
			return null
		return p
	var door: Callable = func():
		var p: Vector2 = level.tutorial_next_door_pos()
		if p == Vector2.ZERO:
			return null
		return p

	return [
		{
			"title": "Parkem",
			"text": "Creatures are looking for their parking spots.\n\nYour job is the opposite of helping: keep them from ever getting there.",
		},
		{
			"await": {"event": "agent_dispatched", "timeout": 60.0},
		},
		{
			"setup": func(): level.tutorial_hold_new_creatures(true),
			"text": "Here comes one. It drives itself — you never steer it.",
			"spot": creature,
			"spot_radius": frame_r,
			"spot_pad": 0.0,
		},
		{
			"text": "And that is the spot it is heading for — its own color. Let it park and you have lost that one.",
			"spot": func():
				var p: Vector2 = level.tutorial_spot_pos()
				if p == Vector2.ZERO:
					return null
				return p,
			"spot_radius": frame_r,
			"spot_pad": 0.0,
		},
		{
			# Almost every door starts OPEN, and an open one is a flat hatch in the tube rather
			# than anything door-shaped — so the caption has to say what is inside the frame.
			# Freeze the creatures: the next two steps are ACTION steps, so the game is unpaused
			# and the creature would drive on — off the very hatch being pointed at — while the
			# player is still looking for it.
			"setup": func(): level.tutorial_freeze_creatures(true),
			"title": "The doors",
			"text": "Every junction has a hatch. This one is open, so creatures pass straight over it.\n\nA tap swings one shut, and it turns aside whatever arrives next.",
			"spot": door,
			"spot_radius": frame_r,
			"spot_pad": 0.0,
		},
		{
			"text": "Tap the framed hatch to swing it shut.",
			"spot": door,
			"spot_radius": frame_r,
			"spot_pad": 0.0,
			"await": {"event": "door_turned", "timeout": 120.0},
			"hint_after": 12.0,
			"hint": "Tap the framed door.",
		},
		{
			"title": "It does not last",
			"text": "A shut hatch springs open again after a few seconds, and the creature will try once more.\n\nSo keep shutting hatches in front of it.",
			"spot": door,
			"spot_radius": frame_r,
			"spot_pad": 0.0,
		},
		{
			"setup": func():
				level.tutorial_freeze_creatures(false)
				level.tutorial_hold_new_creatures(false),
			# Reactive: the quiet win is the whole lesson, and so is the quiet loss.
			"text": func():
				if level.tutorial_creatures_stopped() > 0:
					return "That is the job. Keep them wandering and they give up."
				return "Keep it away from its spot. After about ten seconds it gives up — and that is your point.",
			"await": {"event": "creature_stopped", "timeout": 300.0},
			"hint_after": 25.0,
			"hint": "Shut the door it is heading for. It only has to be kept busy, not destroyed.",
		},
		{
			"title": "Ready",
			"text": "More creatures, arriving faster, each with its own spot.\n\nThey also crash into each other and into hazards — which counts for you just as well.",
		},
	]

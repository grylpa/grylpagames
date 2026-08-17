extends RefCounted

# Guidem's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time Guidem player actually gets wrong:
#   1. They wait for a car to reach a junction and then try to steer it. The cars never stop, and a
#      door turned under one is already too late — the game is setting the road up AHEAD of them.
#   2. The junction doors do not look interactive, and they CYCLE through three positions rather
#      than toggling, so a single tap often appears to do nothing useful.
#   3. Nobody tells them cars can crash into each other (check_agent_collisions -> game.collided()),
#      so the first collision reads as the game misbehaving rather than as their mistake.
#
# Kept deliberately short. The first version ran to ten steps of prose, called the cars "little
# people", and pointed at "one of your walkers" — which regularly highlighted nothing, because cars
# are dispatched at the board edges and are not necessarily in view when the step opens. Only fixed
# things are spotlighted here: the doors, which do not move.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var door_spot: Callable = func():
		for d in level.doors:
			if is_instance_valid(d):
				return d
		return null

	return [
		{
			"title": "Guidem",
			"text": "Cars drive out on their own.\n\nGet every one of them to a green exit.",
		},
		{
			"text": "Here comes the first. It never stops.",
			"await": {"event": "walker_dispatched", "timeout": 30.0},
		},
		{
			"text": "You steer them with the doors at the junctions.\n\nTap this one.",
			"spot": door_spot,
			"spot_radius": 60.0,
			"await": {"event": "door_turned", "timeout": 60.0},
			"hint_after": 10.0,
			"hint": "Tap directly on the door.",
		},
		{
			"text": "Again — a door cycles through three positions, so keep tapping until it points where you want.",
			"spot": door_spot,
			"spot_radius": 60.0,
			"await": {"event": "door_turned", "timeout": 60.0},
			"hint_after": 10.0,
			"hint": "Tap the same door once more.",
		},
		{
			"title": "Work ahead",
			"text": "Set the door a car is heading FOR, not the one it is already on.",
		},
		{
			"title": "Keep them apart",
			"text": "Two cars that run into each other crash, and it costs you.\n\nA door set right for one car can send the next one into it.",
		},
		{
			"title": "Ready",
			"text": "Steer every car to a green exit, and no crashes.",
		},
	]

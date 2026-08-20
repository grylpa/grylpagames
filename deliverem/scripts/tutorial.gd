extends RefCounted

# Deliverem's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time player actually gets wrong, in order of damage:
#   1. They try to STEER the truck. You cannot: it drives itself along the pipes, forever. What you
#      control is the DOORS — tapping one rotates it, and a rotated door deflects a passing truck
#      ninety degrees. Nothing on screen says the doors are the controls, so a player who never
#      taps one watches the truck loop the yard until the clock runs out.
#   2. The delivery list is a QUEUE. "Deliver to 3,1" means dock 3 first; rolling past dock 1 while
#      3 is still aboard does nothing at all, silently.
#   3. Docks are not enterable (can_go_to rejects istarget). You deliver by passing ALONGSIDE one.
#
# This is Delem FP's yard seen whole — no zoom, no memorisation. The lesson is entirely about the
# doors, so the tutorial spends its middle on one door and one turn.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var truck: Callable = func():
		var p: Vector2 = level.tutorial_agent_pos()
		return null if p == Vector2.ZERO else p
	var door: Callable = func():
		var p: Vector2 = level.tutorial_next_door_pos()
		return null if p == Vector2.ZERO else p

	return [
		{
			"title": "Deliverem",
			"text": "You run the delivery yard.\n\nA truck arrives loaded with packets, and every packet belongs to a numbered dock.",
		},
		{
			# One dock, not all of them: the full set spans the whole yard, so framing it says
			# nothing and leaves the caption nowhere to sit clear of it.
			"text": func(): return "Numbered docks sit around the edge of the yard — this is dock %d. The truck reaches them along the roads." % level.tutorial_a_dock_id(),
			"spot": func():
				var p: Vector2 = level.tutorial_dock_pos(level.tutorial_a_dock_id())
				return null if p == Vector2.ZERO else p,
			"spot_radius": 55.0,
		},
		{
			"text": "And this is your truck. It drives itself — you never steer it directly.",
			"spot": truck,
			"spot_radius": 70.0,
		},
		{
			# The whole game, in one caption. Read the numbers off the truck itself so the text
			# cannot disagree with the load.
			"title": "In this order",
			"text": func():
				var a = level.tutorial_agent()
				if a == null or a.body_ids.is_empty():
					return "The dispatcher lists the docks to visit — and the order matters."
				var ids: Array = []
				for i in a.body_ids:
					ids.append(str(i))
				return "The dispatcher wants dock %s.\n\nIn that order. Only the packet at the front of the list can come off, so dock %s first — no other dock will take anything yet." % [
					", then ".join(ids), str(a.body_ids[0])],
			"spot": func(): return level.tutorial_dispatch_label(),
			"spot_pad": 8.0,
		},
		{
			"setup": func(): level.tutorial_hide_dispatch(),
			"title": func(): return "Dock %d first" % level.tutorial_next_dock_id(),
			"text": "Pull up alongside it — you cannot drive in.",
			"spot": func():
				var p: Vector2 = level.tutorial_next_dock_pos()
				return null if p == Vector2.ZERO else p,
			"spot_radius": 55.0,
		},
		{
			# Pin the door AND stop the trucks. The next step is an action step, so the game runs
			# and the truck would drive on while the player hunts for the door — and since the
			# target is otherwise recomputed from the truck's heading, the frame would hop from
			# door to door as it went.
			"setup": func():
				level.tutorial_hold_trucks = true
				level.tutorial_lock_next_door(),
			"title": "The doors",
			"text": "These are your controls. A door sits at a junction, and a truck driving through a turned door is deflected sideways.",
			"spot": door,
			"spot_radius": 46.0,
		},
		{
			"text": "Tap this door to turn it. Each tap cycles it: open, one diagonal, the other.\n\nThe truck is waiting — try it.",
			"spot": door,
			"spot_radius": 46.0,
			"await": {"event": "door_turned", "timeout": 120.0},
			"hint_after": 12.0,
			"hint": "Tap the framed door.",
		},
		{
			"setup": func():
				level.tutorial_unlock_door()
				level.tutorial_hold_trucks = false,
			"title": "That is the whole job",
			"text": func(): return "Set the doors so the truck is carried to dock %d, then to the next one on its list.\n\nIt never stops, so you can keep changing them as it drives." % level.tutorial_next_dock_id(),
			"spot": truck,
			"spot_radius": 60.0,
		},
		{
			"text": func(): return "Get it to dock %d." % level.tutorial_next_dock_id(),
			"await": {"event": "packet_delivered", "timeout": 300.0},
			"hint_after": 30.0,
			"hint": "Turn the doors ahead of it. Passing alongside the dock is what delivers.",
		},
		{
			"title": "Delivered",
			"text": func():
				var nxt: int = level.tutorial_next_dock_id()
				if nxt < 0:
					return "One down. Finish the run."
				return "One down. Now dock %d." % nxt,
			"await": {"event": "packet_delivered", "timeout": 300.0},
			"hint_after": 30.0,
			"hint": "Tap Clue if you lose track of the order.",
		},
		{
			"title": "Ready",
			"text": "Bigger yards, more packets — and more than one truck at a time, each with its own list.",
		},
	]

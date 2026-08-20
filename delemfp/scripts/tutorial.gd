extends RefCounted

# Delem FP's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time Delem FP player actually gets wrong, in order of damage:
#   1. The list is a QUEUE. "Deliver to 3,1" means dock 3 first — drive past dock 1 while 3 is
#      still on board and absolutely nothing happens, with no sound and no message. Players
#      conclude the delivery is broken rather than that they are out of order.
#   2. You do not drive the truck, you steer it. A press sets the direction it will take at the
#      next junction (move_dir -> next_agent_dir); it keeps its heading otherwise and turns by
#      itself at a dead end.
#   3. Docks are not enterable (can_go_to rejects istarget). You deliver by pulling up ALONGSIDE
#      one, which is a strange thing to guess.
#   4. The camera. Five seconds after the truck is dispatched the view snaps to a 2x camera locked
#      on it, and the yard the player was looking at is gone. Nobody says that is coming, so the
#      five seconds are not spent memorising anything.
#
# The camera is held back (level.tutorial_hold_camera) so those five seconds become a step the
# player leaves by tapping, and the yard is cut to four docks so the maze can be read in one look.
#
# Steering is NOT taught before the zoom, even though showing it on the open board is tempting.
# Zoomed out, `DelemfpG.freeze` is true and the truck cannot be steered at all — that is the game's
# rule and its printed instructions say so ("You cannot move while zoomed out"). A tutorial that
# drives on the open board would be demonstrating a state the game does not have, and directly
# contradicting the instructions. So: memorise the roads, take the zoom, THEN steer — and hand over
# both escape hatches (Zoom and Clue) before asking for the first delivery, so nobody is stranded.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	# 1.5 tiles across, so a frame names ONE thing rather than swallowing a cluster of junctions.
	#
	# Two sizes, because this tutorial spans the zoom: steps before the countdown see the whole
	# yard at 1x, and everything after it is viewed through create_camera()'s 2x camera, where a
	# tile is twice as wide on screen. Using the far value throughout would draw a postage stamp
	# once the view closes in.
	#
	# spot_pad is zeroed on each of these: the runner adds its default 10px pad ON TOP of the
	# radius, which is what turns an intended 1.5 tiles into more.
	var r_far: float = maxf(12.0, level.game.tile_size * 0.75)
	var r_near: float = r_far * 2.0
	var truck: Callable = func():
		var p: Vector2 = level.tutorial_agent_pos()
		return null if p == Vector2.ZERO else p

	return [
		{
			"title": "Delem FP",
			"text": "You run the delivery yard.\n\nA truck arrives loaded with packets, and every packet belongs to a numbered dock.",
		},
		{
			"text": "These are the docks. They sit around the edge of the yard, and the truck can only reach them along the roads.",
			"spot": func(): return level.tutorial_all_docks_rect(),
			"spot_pad": 10.0,
		},
		{
			"text": "And this is your truck. It carries one packet per delivery, nose to tail.",
			"spot": truck,
			"spot_radius": r_far,
			"spot_pad": 0.0,
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
			# Deliberately ONE short caption. The truck always sits at the depot (340, 260) and the
			# dock is random; when the dock lands directly below it there is only a ~170px gap
			# between them, and a taller caption has nowhere to go that does not bury one or the
			# other — the very things this step needs both of.
			"setup": func(): level.tutorial_hide_dispatch(),
			"title": func(): return "Dock %d first" % level.tutorial_next_dock_id(),
			"text": "Pull up alongside it — you cannot drive in.",
			"spot": func(): return level.tutorial_next_dock_pos(),
			"spot_radius": r_far,
			"spot_pad": 0.0,
		},
		{
			# The countdown is started here but the game is PAUSED while this caption is up, and
			# the HUD's countdown timer skips a tick whenever it is — so the 5 sits there, frozen
			# and pointed at, until the player taps. Without this the freeze before the zoom is
			# unexplained, and a first-timer reads it as the game not responding.
			"setup": func(): level.tutorial_start_countdown(),
			"title": "Five seconds",
			"text": "Every run starts with this countdown, and you cannot move until it reaches zero.\n\nIt is your one look at the whole yard — use it to learn the route.",
			"spot": func(): return level.tutorial_countdown_label(),
			"spot_pad": 10.0,
		},
		{
			"text": func(): return "Trace the route to dock %d in your head.\n\nYou cannot move yet — the truck is locked until the countdown ends." % level.tutorial_next_dock_id(),
			"spot": func(): return level.tutorial_next_dock_pos(),
			"spot_radius": r_far,
			"spot_pad": 0.0,
			"await": {"event": "zoomed_in", "timeout": 60.0},
		},
		{
			# The truck is parked here and stays parked through the next two steps, so this caption
			# must NOT ask for steering: the player would swipe, get nothing, and conclude the
			# controls are broken. The steering instruction lives on the step that releases it.
			"setup": func(): level.tutorial_hold_truck(true),
			"title": "The view closes in",
			"text": "From here you only see what is around your truck.\n\nIt is parked for a moment — two things first.",
			"spot": truck,
			"spot_radius": r_near,
			"spot_pad": 0.0,
		},
		{
			"setup": func(): level.tutorial_mark_step(),
			"title": "Lost?",
			"text": "Tap Zoom to pull back and see the whole yard. You cannot drive while zoomed out.\n\nIt costs 2 points and 10 seconds. Try it.",
			"spot": func(): return level.tutorial_bottom_button("ZoomButton"),
			"spot_pad": 6.0,
			"await": {"event": "unzoomed", "timeout": 90.0},
			"tick": func():
				if level.tutorial_step_elapsed_sec() > 20.0:
					level.zoom_unzoom(),
			"hint_after": 8.0,
			"hint": "The zoom button, on the bar along the bottom of the screen. I will show you if you like — just wait.",
		},
		{
			"setup": func(): level.tutorial_mark_step(),
			"title": "Forgot the list?",
			"text": "Tap Clue to see what is still aboard, in order.\n\nSame price: 2 points and 10 seconds. Try it.",
			"spot": func(): return level.tutorial_bottom_button("ClueButton"),
			"spot_pad": 6.0,
			"await": {"event": "reminder_shown", "timeout": 90.0},
			"tick": func():
				if level.tutorial_step_elapsed_sec() > 20.0:
					level.display_reminder(),
			"hint_after": 8.0,
			"hint": "The clue button, on the bar along the bottom of the screen. I will show you if you like — just wait.",
		},
		{
			"setup": func():
				# Zoom's 4-second look may still be running, and movement is refused while zoomed
				# out — so end it here rather than asking for steering the game will not accept.
				level.tutorial_end_zoom_out()
				level.tutorial_hold_truck(false),
			"title": "Now you drive",
			"text": func(): return "Swipe, or use the arrow keys, to set which way it turns next. It keeps going otherwise, and turns by itself at a dead end.\n\nTake it to dock %d." % level.tutorial_next_dock_id(),
			"spot": truck,
			"spot_radius": r_near,
			"spot_pad": 0.0,
			"await": {"event": "packet_delivered", "timeout": 300.0},
			"hint_after": 25.0,
			"hint": "Drive right past the dock — you don't turn into it. Zoom out if you lose your bearings.",
		},
		{
			"title": "Delivered",
			"text": func():
				var nxt: int = level.tutorial_next_dock_id()
				if nxt < 0:
					return "One down. Finish the run."
				var left: int = level.tutorial_packets_left()
				if left <= 1:
					return "One down. Now dock %d, and the run is finished." % nxt
				return "One down, %d to go. Dock %d is next." % [left, nxt],
			"spot": truck,
			"spot_radius": r_near,
			"spot_pad": 0.0,
			"await": {"event": "packet_delivered", "timeout": 300.0},
			"hint_after": 30.0,
			"hint": "Use Clue and Zoom if you need them — they cost, but being lost costs more.",
		},
		{
			"title": "Ready",
			"text": "Bigger yards, more packets, more docks.\n\nRemember your routes.",
		},
	]

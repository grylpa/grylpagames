extends RefCounted

# Taxi's coached tutorial. See docs/tutorials.md for the step schema.
#
# Taxi has the longest instruction text in the app — eight numbered rules — and almost none of it
# can be seen by playing a round:
#   1. Money IS the score. It starts at 5000 and every move spends it; at zero the game is over.
#      Players read the number as points and cheerfully drive taxis around empty.
#   2. Fuel burns per tile AND while idling with the motor running, and a taxi that empties is
#      stranded for the rest of the game. That one is normally learned by losing a taxi.
#   3. Select-then-send is two taps on two different things, and tapping an already-busy taxi
#      CANCELS its job rather than re-selecting it.
# So the tutorial teaches the money first, then the two-tap gesture on a real fare, then fuel with
# a tank that is actually low.
#
# Customers arrive only when this asks for one (level.tutorial_hold_dispatch); on the level-1 timer
# one turns up every 5 s and buries the lesson.
#
# The city is given a SINGLE taxi (level._tutorial_setup). A taxi blocked by another taxi mid-fare
# deadlocked the whole lesson — traffic jams are rule 3 and are not taught until the last step, so
# the player had no reason to know they must select the blocker and drive it out of the way. With
# one taxi that cannot arise at all: can_go_to() only refuses a tile held by another taxi. The
# `unblock` tick below stays as a net for the case where the player buys a second taxi mid-tutorial.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

# `main` is passed too, because two of the things this tutorial has to point at — the money and
# the buy-taxi button — live on the HUD and the action bar, not in the level.
static func steps(level: Node, game, main: Node) -> Array:
	var ctx: Dictionary = {"taxi": null, "asked_ms": -100000, "unblock_ms": -100000}

	var a_taxi: Callable = func():
		for t in level.taxis:
			if is_instance_valid(t) and not t.out_of_gas:
				return t
		return null
	# The taxi this tutorial is about, kept still across steps.
	var lock_taxi: Callable = func() -> void:
		ctx["taxi"] = a_taxi.call()
	var taxi_spot: Callable = func():
		var t = ctx["taxi"]
		if t == null or not is_instance_valid(t):
			t = a_taxi.call()
		if t == null:
			return null
		return t
	# Whoever is waiting for a ride right now.
	var customer_spot: Callable = func():
		for a in level.agents:
			if is_instance_valid(a) and not a.is_taxi and a.assigned_to_taxi == null:
				return a
		return null
	var gas_spot: Callable = func():
		return level.tutorial_gas_station()
	var dest_spot: Callable = func():
		return level.tutorial_active_receiver()
	var money_spot: Callable = func():
		if main == null or not is_instance_valid(main):
			return null
		return main.hud.get_node_or_null("Score")
	var buy_spot: Callable = func():
		if main == null or not is_instance_valid(main):
			return null
		return main.buy_taxi_btn

	# Ask for a customer, and keep asking if the city had no free kerb the first time.
	var want_customer: Callable = func() -> void:
		ctx["asked_ms"] = Time.get_ticks_msec()
		level.tutorial_request_customer()
	var nudge_customer: Callable = func() -> void:
		for a in level.agents:
			if is_instance_valid(a) and not a.is_taxi and a.assigned_to_taxi == null:
				return
		var now_ms: int = Time.get_ticks_msec()
		if now_ms - int(ctx["asked_ms"]) < 2000:
			return
		ctx["asked_ms"] = now_ms
		level.tutorial_request_customer()

	# An IDLE taxi, never the one still delivering: that one keeps driving, burns the little it was
	# left with and strands, and a stranded taxi cannot be tapped at all.
	# A jam during the fare deadlocks the lesson: blocking is rule 3 and is not taught until the
	# end, so the player has no reason to know they must move the blocker themselves. Clear it for
	# them, no faster than once a second so a taxi that is merely waiting its turn gets the chance.
	var unblock: Callable = func() -> void:
		var now_ms: int = Time.get_ticks_msec()
		if now_ms - int(ctx["unblock_ms"]) < 1000:
			return
		ctx["unblock_ms"] = now_ms
		level.tutorial_unblock()

	var drain: Callable = func() -> void:
		var t = level.tutorial_idle_taxi()
		if t == null:
			t = a_taxi.call()
		ctx["taxi"] = t
		level.tutorial_drain_taxi(t)

	return [
		{
			"title": "Taxi",
			"text": func(): return "You run the station. This is your money, not points — you start with $%d and the game ends if it reaches zero." % game.initial_score,
			"spot": money_spot,
		},
		{
			"text": "Customers pay when they arrive. Everything else — every tile driven, every minute idling, every new taxi — costs.",
		},
		{
			"setup": lock_taxi,
			"text": "This is one of your taxis. Tap it.",
			"spot": taxi_spot,
			"await": "taxi_selected",
			"hint_after": 8.0,
			"hint": "Tap the taxi itself.",
		},
		{
			"setup": want_customer,
			"tick": func() -> void:
				nudge_customer.call()
				unblock.call(),
			"text": "Someone is waiting. With the taxi selected, tap them.",
			"spot": customer_spot,
			"await": "customer_assigned",
			"hint_after": 10.0,
			"hint": "Two taps: the taxi, then the customer. Tapping a taxi that already has a job cancels it.",
		},
		{
			"tick": unblock,
			"text": "It drives over and picks them up.",
			"await": "picked_up",
			"hint_after": 20.0,
			# TEMPORARY DIAGNOSTIC — remove once the "taxi never sets off" report is understood.
			# It has been reported on a phone and never reproduced here, so the hint reads the live
			# state out instead of guessing: whether the taxi is blocked, whether it is standing on
			# its own path (tick() moves it only if it is), and what the next cell on that path
			# refuses.
			"hint": func():
				var t = level.tutorial_assigned_taxi()
				if t == null:
					return "Nothing to do — watch it work."
				return "Nothing to do — watch it work.\n\n" + level.tutorial_taxi_state(t),
		},
		{
			"tick": unblock,
			"text": "Now it takes them where they are going. They pay on arrival.",
			"spot": dest_spot,
			"await": "delivered",
			"hint_after": 25.0,
			"hint": "Still nothing to do — the fare finishes itself.",
		},
		{
			"title": "Fuel",
			"setup": drain,
			"text": "Fuel burns by the tile, and idling with the motor running burns it too. This one is nearly dry.",
			"spot": taxi_spot,
		},
		{
			"text": "Send it to fill up: tap the taxi, then the pump. A taxi that runs dry is stranded for the rest of the game.",
			"spot": gas_spot,
			"await": "sent_to_gas",
			"hint_after": 12.0,
			"hint": "Tap the taxi first, then the gas station.",
		},
		{
			"text": "It drives over and fills up. A taxi turns green while it is at the pump, and filling costs money too.",
			"spot": taxi_spot,
			"await": {"event": "gas_filled", "timeout": 180.0},
			"hint_after": 30.0,
			"hint": "Nothing to do — it fills itself.",
		},
		{
			"title": "Two more things",
			"text": "Customers give up if they wait too long, so do not leave one waiting.\n\nAnd taxis cannot drive through each other: if yours is stuck behind another, tap the one in front and send it somewhere out of the way.",
		},
		{
			"title": "Ready",
			"text": "This buys another taxi, once you can afford one.",
			"spot": buy_spot,
		},
	]

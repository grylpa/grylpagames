extends RefCounted

# Aliens' coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time Aliens player actually gets wrong, in order of damage:
#   1. The two rings look like decoration. They are the whole interface: an alien parks itself in
#      the OUTER ring and waits, and the player moves it either INTO the inner circle or back out
#      to the field. Taught first, and taught as a place rather than as a rule.
#   2. Evicting a non-matching alien feels like giving up, so players leave it sitting there. It
#      is a correct call worth the same as boarding one, and the tutorial says so outright.
#   3. Nobody connects a full ring with losing points. Every alien turned away from a full ring
#      is a miss, which is why the ring has to be kept clear rather than treated as a queue.
#
# The steps wait on `alien_parked_matching` / `alien_parked_mismatching` rather than on a plain
# "an alien arrived". That way the coach only starts talking once the exact situation it is about
# to describe is on screen, so its wording can never disagree with what the player is looking at.
# `_tutorial_last_parked` on the level names which alien that was, so the spotlight lands on it.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	# `_tutorial_last_parked` is overwritten by EVERY later arrival, so reading it live made the
	# spotlight hop from one alien to the next while the caption still described the first — and
	# it would land on aliens that plainly did match the pass during the "this one does not match"
	# step. Steps that say "this one" therefore LOCK the alien at step entry and keep pointing at
	# that one alone. `ctx` is captured by both lambdas, which is how the lock is shared.
	var ctx: Dictionary = {"al": null, "want": true, "asked_ms": -100000}

	# Lock the alien this step is about, VALIDATED: still parked in the ring, and still on the
	# side of the pass the caption is about to claim. Trusting `_tutorial_last_parked` blindly
	# marked a non-matching alien out in the field whenever the wait step timed out, or the alien
	# had wandered off, or _recycle had reused it with fresh traits — and the drag it then asked
	# for was one the rules do not allow.
	var lock_match: Callable = func() -> void:
		ctx["want"] = true
		ctx["asked_ms"] = -100000
		ctx["al"] = level.tutorial_parked_alien(true, level._tutorial_last_parked)
		level.tutorial_hold_arrivals = true      # no new arrivals until this one is dealt with
	var lock_mismatch: Callable = func() -> void:
		ctx["want"] = false
		ctx["asked_ms"] = -100000
		ctx["al"] = level.tutorial_parked_alien(false, level._tutorial_last_parked)
		level.tutorial_hold_arrivals = true

	# The player can always do the OPPOSITE of what the step asks: told to drag a matching alien
	# into the ring, they drag it out instead. That leaves the step waiting on an event that can
	# never arrive now, pointing at an alien which is no longer parked but wandering the field —
	# and because arrivals are held for the duration of the step, nothing else can reach the ring
	# either. So every frame: if the alien this step is about is no longer waiting at the gate,
	# lock onto another of the same kind, and if there is none, send one.
	var relock: Callable = func() -> void:
		# Hands off while the player is holding an alien. A dragged alien is in DRAGGED state, not
		# PARKED_OUTER, which reads exactly like "it left the gate" — so the frame was handed to a
		# different alien mid-drag, while the player was still carrying the one it had marked.
		# Whatever they do with it resolves the moment they let go, and this runs again then.
		if level._drag_alien != null and is_instance_valid(level._drag_alien):
			return
		var al = ctx["al"]
		if al != null and is_instance_valid(al) and al.state == level.AState.PARKED_OUTER 				and level._gate_wants(al, al.area_idx) == bool(ctx["want"]):
			return
		var replacement = level.tutorial_parked_alien(bool(ctx["want"]))
		if replacement != null:
			ctx["al"] = replacement
			return
		ctx["al"] = null
		# Requesting spawns or re-routes an alien, so do not do it every frame while one walks over.
		var now_ms: int = Time.get_ticks_msec()
		if now_ms - int(ctx["asked_ms"]) < 1500:
			return
		ctx["asked_ms"] = now_ms
		level.tutorial_request_arrival(bool(ctx["want"]))
	var release_hold: Callable = func() -> void:
		level.tutorial_hold_arrivals = false
	# Send one of the required kind to the gate, so the wait step resolves promptly instead of
	# relying on the arrival mix (and on its timeout).
	var last_nudge: Dictionary = {"ms": -100000}
	var want_match_arrival: Callable = func() -> void:
		last_nudge["ms"] = Time.get_ticks_msec()
		level.tutorial_request_arrival(true)
	var want_mismatch_arrival: Callable = func() -> void:
		last_nudge["ms"] = Time.get_ticks_msec()
		level.tutorial_request_arrival(false)

	# A requested arrival does not always make it: the walk can be interrupted, the alien recycled,
	# the reservation lost. The wait step then sits out its full timeout with an empty ring, which
	# is what "no alien enters the outer ring" looks like from the player's side. So ask again,
	# occasionally, until one is actually waiting.
	var nudge_for: Callable = func(want: bool) -> void:
		if level.tutorial_parked_alien(want) != null:
			return
		var now_ms: int = Time.get_ticks_msec()
		if now_ms - int(last_nudge["ms"]) < 4000:
			return
		last_nudge["ms"] = now_ms
		level.tutorial_request_arrival(want)
	var nudge_match: Callable = func() -> void:
		nudge_for.call(true)
	var nudge_mismatch: Callable = func() -> void:
		nudge_for.call(false)

	# The alien this step is talking about — the locked one, not whoever arrived most recently.
	var locked_spot: Callable = func():
		var al = ctx["al"]
		if al == null or not is_instance_valid(al):
			return null
		# Not parked and not in the player's hand means it has wandered off, and the mark must not
		# follow it. Being dragged is different: it is under their finger, and dropping the mark
		# there looks like the game lost track of what they are carrying.
		if al.state != level.AState.PARKED_OUTER and al != level._drag_alien:
			return null
		var r: float = float(al.radius) * 1.35
		return Rect2(al.sim_pos - Vector2(r, r), Vector2(r, r) * 2.0)

	# For steps that just want "whoever is waiting right now".
	var parked_spot: Callable = func():
		var al = level._tutorial_last_parked
		if al == null or not is_instance_valid(al):
			return null
		var r: float = float(al.radius) * 1.35
		return Rect2(al.sim_pos - Vector2(r, r), Vector2(r, r) * 2.0)
	var gate_spot: Callable = func():
		if level._areas.is_empty():
			return null
		var c: Vector2 = Vector2(level._areas[0]["center"])
		var r: float = float(level._areas[0]["r_out"])
		return Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
	var inner_spot: Callable = func():
		if level._areas.is_empty():
			return null
		var c: Vector2 = Vector2(level._areas[0]["center"])
		var r: float = float(level._areas[0]["r_in"])
		return Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
	var pass_spot: Callable = func():
		if level._rule_labels.is_empty():
			return null
		return level._rule_labels[0]

	# The gate's pass in words, read from the live level. Every line that talks about matching
	# quotes it, so the caption and the chip on screen cannot disagree — which is exactly what
	# went wrong when the coach called a blue alien a match for a GREEN pass.
	var pass_text: Callable = func() -> String:
		if level._areas.is_empty():
			return "the pass"
		return level._pass_label(level._areas[0].get("pass", {}), false)

	return [
		{
			"title": "Aliens",
			"text": "You work a spaceport gate.\n\nAliens queue up at it, and you decide who boards.",
		},
		{
			"text": func(): return "This is the gate's pass: %s.\n\nOnly aliens that match it may board." % pass_text.call(),
			"spot": pass_spot,
		},
		{
			"text": "Aliens walk into the outer ring by themselves and wait there.",
			"spot": gate_spot,
		},
		{
			"text": "The inner circle is the ship. Nothing gets in except by your hand.",
			"spot": inner_spot,
		},
		{
			"setup": want_match_arrival,
			"tick": nudge_match,
			"text": "One is on its way to the gate.",
			"await": {"event": "alien_parked_matching", "timeout": 60.0},
		},
		{
			"setup": lock_match,
			"tick": relock,
			"text": func(): return "This one matches %s.\n\nDrag it into the inner circle." % pass_text.call(),
			"spot": locked_spot,
			"await": {"event": "promoted", "timeout": 60.0},
			"hint_after": 8.0,
			"hint": "Press the alien and drag it to the middle of the gate.",
		},
		{
			"setup": func() -> void:
				release_hold.call()
				want_mismatch_arrival.call(),
			"tick": nudge_mismatch,
			"text": "Another one is on its way.",
			"await": {"event": "alien_parked_mismatching", "timeout": 60.0},
		},
		{
			"setup": lock_mismatch,
			"tick": relock,
			"text": func(): return "This one does not match %s.\n\nDrag it out to the open field." % pass_text.call(),
			"spot": locked_spot,
			"await": {"event": "evicted", "timeout": 60.0},
			"hint_after": 8.0,
			"hint": "Drag it clear of the rings, onto the open ground.",
		},
		{
			"setup": release_hold,
			"title": "Both count",
			"text": "Turning the wrong alien away scores as much as boarding the right one.\n\nLeaving it in the ring scores nothing — and while the ring is full, everyone who walks up is turned away and costs you.",
		},
		{
			"title": "Ready",
			"text": "Later the pass comes down after a few seconds and you have to remember it, and a second gate opens.",
		},
	]

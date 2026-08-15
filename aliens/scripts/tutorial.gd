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
	var ctx: Dictionary = {"al": null}

	# Lock the alien this step is about, VALIDATED: still parked in the ring, and still on the
	# side of the pass the caption is about to claim. Trusting `_tutorial_last_parked` blindly
	# marked a non-matching alien out in the field whenever the wait step timed out, or the alien
	# had wandered off, or _recycle had reused it with fresh traits — and the drag it then asked
	# for was one the rules do not allow.
	var lock_match: Callable = func() -> void:
		ctx["al"] = level.tutorial_parked_alien(true, level._tutorial_last_parked)
		level.tutorial_hold_arrivals = true      # no new arrivals until this one is dealt with
	var lock_mismatch: Callable = func() -> void:
		ctx["al"] = level.tutorial_parked_alien(false, level._tutorial_last_parked)
		level.tutorial_hold_arrivals = true
	var release_hold: Callable = func() -> void:
		level.tutorial_hold_arrivals = false
	# Send one of the required kind to the gate, so the wait step resolves promptly instead of
	# relying on the arrival mix (and on its timeout).
	var want_match_arrival: Callable = func() -> void:
		level.tutorial_request_arrival(true)
	var want_mismatch_arrival: Callable = func() -> void:
		level.tutorial_request_arrival(false)

	# The alien this step is talking about — the locked one, not whoever arrived most recently.
	var locked_spot: Callable = func():
		var al = ctx["al"]
		if al == null or not is_instance_valid(al):
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
			"text": "You are working a spaceport gate.\n\nAliens wander about outside, and you decide which of them get to board.",
		},
		{
			"text": func(): return "This is the gate's PASS. Right now it says:\n\n%s\n\nOnly aliens that match it may board." % pass_text.call(),
			"spot": pass_spot,
		},
		{
			"text": "This is the gate. Aliens walk up to the outer ring on their own and wait there for you.",
			"spot": gate_spot,
		},
		{
			"text": "And this inner circle is the ship. Nothing gets in here except by your hand.",
			"spot": inner_spot,
		},
		{
			"text": "Let's wait for someone to come up to the gate.",
			"await": {"event": "alien_parked", "timeout": 30.0},
		},
		{
			"text": "There. This one is waiting on your decision.",
			"spot": parked_spot,
		},
		{
			"text": func(): return "Look it over, and look at the pass: %s." % pass_text.call(),
			"spot": pass_spot,
		},
		{
			"title": "The decision",
			"text": func(): return "Compare the alien with the pass — %s.\n\nDoes it match? Drag it INTO the inner circle.\nDoes it not? Drag it OUT to the open field." % pass_text.call(),
		},
		{
			"setup": want_match_arrival,
			"text": "Let's wait for one the pass accepts.",
			"await": {"event": "alien_parked_matching", "timeout": 60.0},
		},
		{
			"setup": lock_match,
			"text": func(): return "This one matches the pass — %s.\n\nDrag it into the inner circle." % pass_text.call(),
			"spot": locked_spot,
			"await": {"event": "promoted", "timeout": 60.0},
			"hint_after": 8.0,
			"hint": "Press on the alien and drag it to the middle of the gate.",
		},
		{
			"setup": release_hold,
			"text": "Aboard. That is one correct call.",
		},
		{
			"setup": want_mismatch_arrival,
			"text": "Now let's wait for one it does not.",
			"await": {"event": "alien_parked_mismatching", "timeout": 60.0},
		},
		{
			"setup": lock_mismatch,
			"text": func(): return "This one does NOT match %s.\n\nDrag it out to the open field." % pass_text.call(),
			"spot": locked_spot,
			"await": {"event": "evicted", "timeout": 60.0},
			"hint_after": 8.0,
			"hint": "Drag it right out of the rings, anywhere on the open ground.",
		},
		{
			"setup": release_hold,
			"title": "Both count",
			"text": "Turning the wrong alien away scores exactly as much as boarding the right one.\n\nLeaving it standing there scores nothing at all.",
		},
		{
			"text": "Which matters, because the outer ring only holds a few.\n\nWhile it is full, every alien that walks up is turned away — and each one of those costs you.",
			"spot": gate_spot,
		},
		{
			"title": "Later on",
			"text": "As you go up the levels the pass comes down after a few seconds and you have to hold it in your head.\n\nWith two gates, an alien is only ever judged against the gate it walked into.",
		},
		{
			"title": "Ready",
			"text": "Keep the ring moving until the timer runs out.\n\nNothing you did here was scored — your real game starts from the menu.",
		},
	]

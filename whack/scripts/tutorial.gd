extends RefCounted

# Whack's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time player actually gets wrong, in order of damage:
#   1. They cannot tell the real target from a decoy that shares its color. This is the whole
#      reason the tutorial exists. A same-color decoy is the SAME orange as the target and differs
#      only by the white dot in the center: `_spawn_round()` gives decoys
#      `"draw_dot": not round_same_color`, while the real target is always drawn with one. Nothing
#      in the game says so, and "avoid the decoys" in the instructions does not help when the
#      decoy looks identical.
#   2. They assume every round has something to hit. It does not — `no_real_chance` is 0.1 at
#      level 1 and 0.2 at level 2, so a fifth of rounds are decoys only. Tapping a decoy costs 5
#      points and a mistake; waiting costs nothing.
#   3. They read "avoid the decoys" as "avoid the OTHER color", learn to hunt for orange, and are
#      then beaten by the same-color round. So the differently-colored decoys are taught first and
#      the dot is introduced as the rule that always works, rather than color.
#   4. They aim roughly. Accuracy is scored as distance from the center, which is what the dot is
#      for — it is an aiming guide, not just a badge.
#
# The rounds are staged rather than waited for: `level.tutorial_rounds` queues exactly the four
# situations above, so the lesson never depends on the dice. `tutorial_no_timeout` holds each one
# on screen while the coach talks, and is released only for the empty round, which can be taught
# only by letting it expire.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var target_spot: Callable = func():
		return level.tutorial_target_rect()
	var decoy_spot: Callable = func():
		return level.tutorial_decoy_rect(0)

	# Queue one round, then let it appear. Used by every "doing" step below.
	# Every staged round is confined to the lower third of the field ("band": [0.68, 1.0]), so the
	# caption always
	# has clear space at the top. Left to spawn anywhere the circles can span the whole field, and
	# the balloon is then forced to sit on one of them: measured across runs, a decoy was buried
	# 59% at first, 49% with the band at 0.42 and 46% at 0.55 -- the caption is tall enough at the
	# top of the screen to reach a long way down. 0.68 keeps the worst seen in ten runs to 13%,
	# with nothing ever passing the 50% at which the runner would re-place the caption anyway.
	# The closing step tells the player that real targets use the whole screen.
	var stage: Callable = func(spec: Dictionary, hold: bool):
		level.tutorial_no_timeout = hold
		level.tutorial_stage_now(spec)

	return [
		{
			"title": "Whack",
			"text": "A target appears somewhere on the screen.\n\n"
				+ "Tap it as fast as you can — and as close to its center as you can.",
		},
		{
			"text": "That is the target: orange, with a white dot in the center.\n\n"
				+ "The dot is where you are aiming. Tap it.",
			"setup": func(): stage.call({"real": true, "decoys": 0, "mode": "blue", "band": [0.68, 1.0]}, true),
			"spot": target_spot,
			"await": {"event": "hit_target", "timeout": 60.0},
			"hint_after": 6.0,
			"hint": "Tap the orange circle.",
		},
		{
			"text": "Good. The closer to the dot you tap, the better the score.\n\n"
				+ "Now it gets harder — other circles turn up too.",
		},
		{
			"text": "Only the ORANGE one is the target.\n\n"
				+ "The blue ones cost you points if you tap them. Tap only the orange one.",
			"setup": func(): stage.call({"real": true, "decoys": 2, "mode": "blue", "band": [0.68, 1.0]}, true),
			"await": {"event": "hit_target", "timeout": 60.0},
			"spot": target_spot,
			"hint_after": 8.0,
			"hint": "The orange one is the target — leave the blue ones alone.",
		},
		{
			"text": "Decoys are not always blue. They can be any color.\n\n"
				+ "Tap only the orange one.",
			"setup": func(): stage.call({"real": true, "decoys": 3, "mode": "multi", "band": [0.68, 1.0]}, true),
			"await": {"event": "hit_target", "timeout": 60.0},
			"spot": target_spot,
			"hint_after": 8.0,
			"hint": "Ignore every color except orange.",
		},
		{
			# Frozen, with the round already on screen, so the difference can be looked at before
			# anything is asked of the player.
			"text": "These decoys are the SAME orange as the target.\n\n"
				+ "Look for the white dot — only the real target has one.",
			"setup": func(): stage.call({"real": true, "decoys": 2, "mode": "same", "band": [0.68, 1.0]}, true),
		},
		{
			"text": "This is the one with the dot. Tap it.",
			"spot": target_spot,
			"await": {"event": "hit_target", "timeout": 90.0},
			"hint_after": 8.0,
			"hint": "The circles without a dot in the center are decoys.",
		},
		{
			# watch_only: the board has to keep running for the ring to deplete, so this cannot be
			# a frozen step — but the player is being asked to watch, not act. The runner dims and
			# swallows input for it, so it LOOKS as inert as every talking step rather than looking
			# like an invitation to tap.
			#
			# tutorial_ignore_taps backs it up at the level. The two guard different layers: the
			# dim stops a real finger reaching the board, the flag stops anything that gets past it
			# — and the flag is the one the harness can exercise, since a probe calling
			# _on_draw_area_input() directly bypasses the overlay entirely.
			#
			# Both matter because the failure is a dead end: hitting this target ends the round, so
			# the ring never reaches halfway and half_gone never arrives.
			# No spot on purpose. A spotlight punches a bright hole in the dim and frames it, and
			# that framing is how the app says "act here" — which is wrong for a step that asks
			# the player to watch. The round has a single circle on a dimmed board, so there is
			# nothing to disambiguate. This is the same treatment as the "SAME orange" step.
			"watch_only": true,
			"text": "One more thing. Watch the ring around this one.",
			"setup": func():
				stage.call({"real": true, "decoys": 0, "mode": "blue",
					"band": [0.68, 1.0], "show_ms": 7000.0}, false)
				level.tutorial_ignore_taps = true,
			"await": {"event": "half_gone", "timeout": 20.0},
		},
		{
			"setup": func(): level.tutorial_ignore_taps = false,
			"text": "That ring is your time, and half of it has already gone.\n\n"
				+ "If it shrinks away to nothing, the target will go and this will be considered a miss.",
			"spot": target_spot,
		},
		{
			# The only hit_target step whose round can expire: the others are staged with
			# tutorial_no_timeout so they wait indefinitely, but this lesson has to let the ring
			# actually run out. A miss would otherwise leave nothing to hit and a step still
			# waiting for a hit, so a miss re-stages the same round and the player gets another.
			"setup": func():
				level.tutorial_retry_spec = {"real": true, "decoys": 0, "mode": "blue",
					"band": [0.68, 1.0], "show_ms": 7000.0},
			"text": "Tap it before the ring runs out.",
			"spot": target_spot,
			"await": {"event": "hit_target", "timeout": 60.0},
			"hint_after": 4.0,
			"hint": "Tap it now, before the ring is gone.",
		},
		{
			# Explained on a FROZEN step, then watched on the next one. As a single doing step the
			# caption vanished the instant the round expired, so it was gone before it was read.
			"text": "Sometimes there is no target at all.\n\n"
				+ "Only decoys. Do not tap them. Just wait.\n"
				+ "Tapping a decoy will cost you points.",
			"setup": func():
				level.tutorial_retry_spec = {}     # the ring lesson is over; let this one expire
				stage.call({"real": false, "decoys": 2, "mode": "multi",
					"band": [0.68, 1.0], "show_ms": 4000.0}, false),
		},
		{
			"text": "Here it is. Nothing to hit — just let it go.",
			"await": {"event": "round_gone", "timeout": 30.0},
		},
		{
			"text": "That is it.\n\n"
				+ "Orange with a dot: tap it, fast and central.\n"
				+ "Anything else, or nothing at all: leave it.\n\n"
				+ "In a real game they use the whole screen, and they get smaller and quicker.",
		},
	]

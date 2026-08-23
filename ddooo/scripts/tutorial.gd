extends RefCounted

# Witness's coached tutorial. See docs/tutorials.md for the step schema.
#
# One event, two questions — that is the whole game, and it is the thing a first-timer does not
# see coming:
#   1. A shape appears in the center. While they are busy looking at it, a dot flashes somewhere
#      out at the edge, 150 ms later and gone in under a second. Nothing warns them it is coming,
#      so they never see it — and then they are asked which way it was.
#   2. Getting the shape right is only half. Both answers have to be right for the round to count,
#      which is not obvious when the first question is answered and a second one appears.
#
# So the coach names the second question BEFORE it is asked: watch the center, but keep the edges
# in the corner of your eye.
#
# Every timeout in this game is measured in game.game_time, which excludes paused time — so a
# caption holds the flash, the candidates and the direction buttons on screen indefinitely.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	return [
		{
			"title": "Witness",
			"text": "You watch something happen, then answer two questions about it.\n\nBoth have to be right for the round to count.",
		},
		{
			"await": {"event": "model_shown", "timeout": 60.0},
		},
		{
			"setup": func(): level.tutorial_freeze_board(true),
			"title": "Question one",
			"text": "A shape appears in the center. Remember it — shape and color.",
			"spot": func():
				var p: Vector2 = level.tutorial_model_pos()
				if p == Vector2.ZERO:
					return null
				return p,
			"spot_radius": level.tutorial_frame_radius(),
			"spot_pad": 0.0,
		},
		{
			"setup": func(): level.tutorial_freeze_board(false),
			"await": {"event": "periph_flashed", "timeout": 60.0},
		},
		{
			# The whole trick of the game, named while it is still on screen — in a real round this
			# is gone in well under a second, and nobody warns you it is coming.
			"setup": func(): level.tutorial_freeze_board(true),
			"title": "And question two",
			"text": func():
				var d: String = level.tutorial_periph_dir_name()
				if d.is_empty():
					return "While you were looking at the center, a dot flashed out at the edge.\n\nYou will be asked which way it was."
				return "While you were looking at the center, a dot flashed out at the edge — %s, this time.\n\nYou will be asked which way it was." % d,
			"spot": func():
				var p: Vector2 = level.tutorial_periph_pos()
				if p == Vector2.ZERO:
					return null
				return p,
			"spot_radius": level.tutorial_frame_radius(),
			"spot_pad": 0.0,
		},
		{
			"setup": func(): level.tutorial_freeze_board(false),
			"await": {"event": "alts_shown", "timeout": 60.0},
		},
		{
			"setup": func(): level.tutorial_freeze_board(true),
			"title": "The shape first",
			"text": "One of these is the shape you saw in the center.",
			"spot": func():
				var r: Rect2 = level.tutorial_candidates_rect()
				if r.size.x <= 0.0:
					return null
				return r,
			"spot_pad": 10.0,
		},
		{
			# Waits for the RIGHT shape. A wrong pick still lets the round play out — the direction
			# question appears, the round ends without counting, and a fresh one begins — so the
			# caption walks the player through that instead of silently accepting the mistake.
			#
			# The freeze follows the board rather than the step: frozen while there is something to
			# answer, released whenever the board is empty, or the next round could never arrive.
			"setup": func(): level.tutorial_freeze_board(level.tutorial_has_candidates()),
			"tick": func(): level.tutorial_freeze_board(
				level.tutorial_has_candidates() or level.tutorial_dirs_active()),
			"text": func():
				if level.tutorial_has_candidates():
					return "Tap the one that matches."
				if level.tutorial_dirs_active():
					return "That was not the shape.\n\nFinish the round by picking a direction, and we will go again."
				return "Watch for the next shape in the center — and the flash at the edge.",
			# Needs TWO facts, so it waits on the event that carries both: the shape was right,
			# and the direction buttons now exist. "shape_right" fires a few lines before they are
			# built, so the next caption — which points at one — would open with nothing to frame
			# and lay itself out over the very dots it describes. Plain "dirs_shown" fires for a
			# WRONG shape too, since the direction question is asked either way, and would let the
			# player through without ever matching a shape.
			"await": {"event": "dirs_after_right", "timeout": 300.0},
			"hint_after": 15.0,
			"hint": "Same shape, same color as the one that was in the center.",
		},
		{
			# Descriptive only: the board is frozen while a caption is up, so an instruction here
			# cannot be obeyed and the attempt just dismisses the step. The ask is on the next one.
			#
			# There is deliberately no wait-step before this one: it would be satisfied the instant
			# it opened (the whole chain runs in one call) — displayed for zero frames, with its
			# number skipped in the footer. The previous step's await carries the guarantee
			# instead: by the time this caption opens, the buttons it points at exist.
			"setup": func(): level.tutorial_freeze_board(true),
			"title": "Now the direction",
			"text": func():
				var d: String = level.tutorial_periph_dir_name()
				if d.is_empty():
					return "These eight dots are the directions — one for each way the flash could have been."
				return "These eight dots are the directions.\n\nThe flash was %s, and that one is framed." % d,
			"spot": func():
				var p: Vector2 = level.tutorial_correct_dir_pos()
				if p == Vector2.ZERO:
					return null
				return p,
			"spot_radius": level.tutorial_frame_radius(),
			"spot_pad": 0.0,
		},
		{
			# Waits for the RIGHT dot. A wrong one ends the question and clears every button, so the
			# caption has to carry the player through the fresh round that follows rather than sit
			# there telling them to tap dots that no longer exist.
			"setup": func(): level.tutorial_freeze_board(level.tutorial_dirs_active()),
			"tick": func(): level.tutorial_freeze_board(
				level.tutorial_dirs_active() or level.tutorial_has_candidates()),
			"text": func():
				var d: String = level.tutorial_periph_dir_name()
				if level.tutorial_dirs_active():
					return "Tap it." if d.is_empty() else "Tap the %s dot." % d
				if level.tutorial_has_candidates():
					return "Not that way — round over.\n\nHere is another: pick the shape from the center first."
				return "Watch the center, and watch for the flash at the edge.",
			"await": {"event": "dir_right", "timeout": 300.0},
			"hint_after": 15.0,
			"hint": "The framed dot is the one — it is the way the flash was.",
		},
		{
			"setup": func(): level.tutorial_freeze_board(false),
			"title": "Ready",
			"text": "Both answers have to be right for a round to count — one alone is not enough.\n\nFrom here nobody tells you where the flash was. Watch the center, and keep the edges in the corner of your eye.",
		},
	]

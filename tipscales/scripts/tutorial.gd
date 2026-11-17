extends RefCounted

# Tip the Scales' coached tutorial. See docs/tutorials.md for the step schema.
#
# The real game on a board smaller than any level's (2 colors of 3 crates, TipscalesLevelConfig.TUTORIAL),
# one FIXED puzzle of three scales (level.gd: a seeded generator in tutorial mode), coached a move at a
# time; it ends when that one puzzle is solved. What is invisible and has to be said:
#   1. the slate on a crate is what it MAY still weigh -- the game is narrowing those down;
#   2. a scale names crates by color and letter, and tapping it shows them on the board;
#   3. working on a crate is the workbench: tap a weight to rub it off (and again to bring it back), and a
#      crate down to one weight gets its plate; nothing is checked as you go -- a wrong rub-off shows only
#      when a crate is left with nothing or the scales do not balance at the end;
#   4. Hint SHOWS one step and says why, and the player makes it -- the way to learn the reasoning, not a
#      give-away -- and points out a weight rubbed off by mistake before anything else.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func steps(level: Node, _game) -> Array:
	var board_spot: Callable = func():
		var r: Rect2 = level.tutorial_board_rect()
		return r if r.size.x > 0.0 else null
	var ticket_spot: Callable = func():
		var r: Rect2 = level.tutorial_ticket_rect(0)
		return r if r.size.x > 0.0 else null
	var focus_crates: Callable = func():
		var r: Rect2 = level.tutorial_focus_crates_rect()
		return r if r.size.x > 0.0 else null
	var bench_spot: Callable = func():
		var r: Rect2 = level.tutorial_bench_rect()
		return r if r.size.x > 0.0 else null
	var hint_spot: Callable = func():
		var r: Rect2 = level.tutorial_hint_rect()
		return r if r.size.x > 0.0 else null
	var keep: Array = [board_spot, bench_spot]
	return [
		{
			"title": "Tip the Scales",
			"text": "Every crate in this weigh-house has a weight, and you have no scale that reads numbers.\n\nOnly balance scales.",
		},
		{
			# No caption: the first puzzle is still being stacked behind the opening card when a quick reader
			# taps on. The step ends itself the moment the crates are on the shelves (its event is never sent;
			# the timeout is a backstop).
			"await": {"event": "puzzle_ready", "timeout": 20.0},
			"advance_when": func() -> bool: return level.tutorial_board_rect().size.x > 0.0,
		},
		{
			"text": "Two colors of crates. The crates of one color weigh 1, 2 and 3 kg, each weight once.\n\nThe chalk on a crate's slate is what it may still weigh.",
			"spot": board_spot,
		},
		{
			"text": "Down here are the scales, and every one of them is true. Tap this one.",
			"spot": ticket_spot,
			"await": {"event": "focused", "timeout": 60.0},
			"keep_clear": [board_spot],
			"hint_after": 12.0,
			"hint": "Tap the paper.",
		},
		{
			"text": "Its crates light up on the shelves. Tap one of them to put it on the workbench.",
			"spot": focus_crates,
			"await": {"event": "selected", "timeout": 60.0},
			"keep_clear": [ticket_spot],
			"hint_after": 12.0,
			"hint": "Tap a crate with a colored glow.",
		},
		{
			"text": "Its weights are on the workbench. Tap one the scales rule out, and it is rubbed off the slate. Tap it again to bring it back.\n\nNobody checks you as you go: rub off a weight a crate really has, and the scales won't balance at the end.",
			"spot": bench_spot,
			"await": {"event": "crossed", "timeout": 120.0},
			"keep_clear": [board_spot],
			"hint_after": 20.0,
			"hint": "Not sure yet? That is what Hint is for: close the workbench and try it.",
		},
		{
			# the workbench is put away first: the Hint button shows only without a crate on it, and the
			# spot used to land on the bench's small x with nothing saying so (the user: unclear how to go on)
			"setup": func() -> void: level.tutorial_close_bench(),
			"text": "When a crate is down to one weight, it gets a brass plate, and that weight is gone from the rest of its color.\n\nStuck? Tap Hint: it shows you one step and says why, and you make it. If you rubbed off a weight by mistake, it points that out first.",
			"spot": hint_spot,
			"await": {"event": "hinted", "timeout": 90.0},
			"keep_clear": [board_spot],
			"hint_after": 8.0,
			"hint": "Tap the Hint button. (With a crate on the workbench, close it first with the x.)",
		},
		{
			"text": "Read why, under the workbench, and make that move yourself. Then weigh up the rest of the crates.",
			"await": {"event": "solved", "timeout": 600.0},
			"keep_clear": keep,
			"hint_after": 45.0,
			"hint": "Here hints are free. In a real game a level has only three, and each costs points.",
		},
		{
			"title": "Balanced!",
			"text": "That is the whole game. Each level is three puzzles, bigger and with weaker scales as you go.\n\nSolve two of them with at most one mistake and no hint to move on.",
		},
	]

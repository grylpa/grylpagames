extends RefCounted

# Change's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time Change player actually gets wrong, in order of damage:
#   1. They look for a running total of what is in the tray. There isn't one, and that is the
#      whole game — so the tutorial says so out loud rather than letting them hunt for it.
#   2. At higher overlap, coins are almost entirely buried and players never realize there are
#      more coins than they can see. Taught on a board that is deliberately piled up.
#   3. "In the tray" means the coin's CENTER is inside it. The glow already says so; nobody
#      knows to read it until it is pointed at.
#
# The boards are fixed here rather than left to the random generator, so the amount the coach
# names and the coins actually on screen can never drift apart. level.gd pulls them via
# tutorial_boards() in _tutorial_setup().
#
# Two things keep the named amount actually payable:
#   - The payment steps wait for `paid_correct`, not `paid`. `paid` fires on a wrong payment too,
#     so the coach sailed on to the next pile the moment the player pressed PAY with the wrong
#     coins in — the amount it had just named never got paid at all.
#   - The tray is emptied before the first payment step. Step 4 tells the player to drag A coin in;
#     if that was the 5c, paying the named 35c came to 40c and was rejected. They followed the
#     instruction exactly and were marked wrong.
# level.gd re-queues a missed board during a tutorial, so waiting for `paid_correct` cannot hang:
# the same pile comes back and the player tries again.

const LEVEL_ID: int = 1

# Board 1: no overlap, three coins, an easy two-coin answer — learn drag, tray, Pay.
# Board 2: piled up, five coins, a three-coin answer — learn that coins hide under each other.
const BOARD1_VALUES: Array = [0.25, 0.10, 0.05]
const BOARD1_TARGET: float = 0.35     # 0.25 + 0.10
const BOARD2_VALUES: Array = [0.25, 0.25, 0.10, 0.05, 0.50]
const BOARD2_TARGET: float = 0.60     # 0.25 + 0.25 + 0.10

static func tutorial_level_id() -> int:
	return LEVEL_ID

static func tutorial_boards() -> Array:
	return [
		{"values": BOARD1_VALUES, "target": BOARD1_TARGET, "overlap": "none"},
		{"values": BOARD2_VALUES, "target": BOARD2_TARGET, "overlap": "max"},
	]

static func _money(v: float) -> String:
	if v >= 1.0:
		return "$%.2f" % v
	return "%d cents" % int(round(v * 100.0))

static func steps(level: Node, _game) -> Array:
	var tray_spot: Callable = func():
		return level._basket_rect
	var pile_spot: Callable = func():
		return level._pile_rect

	return [
		{
			"title": "Change",
			"text": "You are shown an amount and a pile of coins.\n\nPay it exactly.",
		},
		{
			"text": "Here is the first pile.",
			"await": {"event": "board_shown", "timeout": 8.0},
		},
		{
			"text": "This is what you owe.",
			"spot": func(): return level._target_label,
		},
		{
			"text": "Drag a coin into the tray.",
			"spot": tray_spot,
			"await": {"event": "coin_in_tray", "timeout": 45.0},
			"hint_after": 8.0,
			"hint": "Press a coin, drag it onto the tray, let go.",
		},
		{
			"text": "The glow means it counts.\n\nDrag it back out.",
			"spot": tray_spot,
			"await": {"event": "coin_out_of_tray", "timeout": 45.0},
			"hint_after": 8.0,
			"hint": "Drag it off the tray and the glow goes out.",
		},
		{
			"title": "No total",
			"text": "Nothing on screen adds the tray up. Doing that yourself is the game.\n\nPut in exactly %s, then press PAY." % _money(BOARD1_TARGET),
			"setup": func(): level.tutorial_clear_tray(),
			"spot": func(): return level._pay_btn,
			"await": {"event": "paid_correct", "timeout": 150.0},
			"hint_after": 15.0,
			"hint": "%s is %s and %s." % [_money(BOARD1_TARGET), _money(BOARD1_VALUES[0]),
				_money(BOARD1_VALUES[1])],
		},
		{
			"text": "Another pile.",
			"await": {"event": "board_shown", "timeout": 12.0},
		},
		{
			"title": "Look underneath",
			"text": "This one is heaped up. There are more coins here than you can see — drag the top ones aside.",
			"spot": pile_spot,
		},
		{
			"text": "Pay %s from this pile." % _money(BOARD2_TARGET),
			"spot": pile_spot,
			"await": {"event": "paid_correct", "timeout": 200.0},
			"hint_after": 20.0,
			"hint": "%s is %s, %s and %s. Two are buried." % [_money(BOARD2_TARGET),
				_money(BOARD2_VALUES[0]), _money(BOARD2_VALUES[1]), _money(BOARD2_VALUES[2])],
		},
		{
			"title": "Ready",
			"text": "This bar is your time for the pile.\n\nOne fresh pile per round, until the level timer runs out.",
			"spot": func(): return level._bar_track,
		},
	]

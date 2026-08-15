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
			"text": "You are shown an amount to pay, and a handful of coins.\n\nYour job is to pay it exactly.",
		},
		{
			"text": "Here is your first pile.",
			"await": {"event": "board_shown", "timeout": 8.0},
		},
		{
			"text": "This is the amount you have to pay.",
			"spot": func(): return level._target_label,
		},
		{
			"text": "These are your coins. Each one shows what it is worth.",
			"spot": pile_spot,
		},
		{
			"text": "And this is the tray. Coins you drag in here are the ones you are paying with.",
			"spot": tray_spot,
		},
		{
			"text": "Drag any coin into the tray now.",
			"spot": pile_spot,
			"await": {"event": "coin_in_tray", "timeout": 45.0},
			"hint_after": 8.0,
			"hint": "Press on a coin, drag it onto the tray, and let go.",
		},
		{
			"text": "See the glow around it? That means it counts.\n\nA coin only counts when its center is inside the tray.",
			"spot": tray_spot,
		},
		{
			"title": "The catch",
			"text": "There is no running total anywhere on screen, and there never will be.\n\nAdding the coins up yourself is the game.",
		},
		{
			"text": "So: put exactly %s in the tray." % _money(BOARD1_TARGET),
			"spot": tray_spot,
		},
		{
			"text": "Then press PAY.",
			"spot": func(): return level._pay_btn,
			"await": {"event": "paid", "timeout": 90.0},
			"hint_after": 15.0,
			"hint": "%s is %s and %s. Drag both in, then press PAY." % [
				_money(BOARD1_TARGET), _money(BOARD1_VALUES[0]), _money(BOARD1_VALUES[1])],
		},
		{
			"text": "PAY checks the tray against the amount. Exactly right scores; anything else does not.\n\nIf you got it wrong just now, no harm done — none of this is being recorded.",
		},
		{
			"text": "Here comes another pile.",
			"await": {"event": "board_shown", "timeout": 12.0},
		},
		{
			"title": "Look underneath",
			"text": "This time the coins are heaped on top of each other.\n\nThere are more coins here than you can see.",
			"spot": pile_spot,
		},
		{
			"text": "This bar is your time for the pile. When it empties the pile is gone and counts as a miss.",
			"spot": func(): return level._bar_track,
		},
		{
			# The pile was previously only DESCRIBED, across two frozen talking steps — so the
			# player was shown a heap they were told to dig through and then given no chance to
			# touch it (the board is frozen while the coach talks). This hands it over: a real
			# board, paid unaided, with coins that genuinely have to be moved aside to be found.
			"text": "Your turn. Pay %s out of this pile — drag the top coins aside to see what is under them." % _money(BOARD2_TARGET),
			"spot": pile_spot,
			"await": {"event": "paid", "timeout": 150.0},
			"hint_after": 20.0,
			"hint": "%s is %s, %s and %s. Two of them are buried — move the coins on top out of the way first, then press PAY." % [
				_money(BOARD2_TARGET), _money(BOARD2_VALUES[0]), _money(BOARD2_VALUES[1]),
				_money(BOARD2_VALUES[2])],
		},
		{
			"title": "Ready",
			"text": "That is the whole game. Each round gives you one fresh pile and one amount to make — pay it, and the next pile comes up.\n\nThey keep coming until the level timer at the top runs out.\n\nNothing you did here was scored; your real game starts from the menu.",
		},
	]

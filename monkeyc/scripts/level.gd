extends CanvasLayer

var game: GenericGameUtil
var current_level_id: int = 1

# Level config
var num_rounds_per_level: int = 3
var num_options: int = 3
var num_belts: int = 1
var min_examples: int = 4
var robot_answer_time: float = 1.5  # seconds the ✓/✗ answer is shown BEFORE the robot takes the
                                    # item; the take itself always lands within the h/2..3h/4 band
                                    # (per-level difficulty knob — longer = answer shown sooner/longer)
var scroll_speed: float = 55.0

# Scoring
var rounds_done: int = 0
var total_rounds: int = 0
var total_corrects: int = 0
var times_to_answer: Array = []

var current_pair: Array = []
var question_correct_keys: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Endless conveyor — same dimensions as sorting robots
var pair_font_size: int = 32
var item_h: float = 72.0
# Claw pick-up timing: the item is first popped slightly larger (the claw closing and lifting it
# off the belt), and only then yanked off the side.
const _GRAB_SCALE: float = 1.18
const _GRAB_TIME: float = 0.14
const _PULL_TIME: float = 0.55

const CLAW_SCRIPT: GDScript = preload("res://monkeyc/scripts/claw.gd")

var belt_items: Array = [[], []]
var belt_initialized: bool = false

# Window / robot state
var window_panel: Panel = null
var window_belt: int = -1
var window_open: bool = false
var window_target_item: Control = null
var window_target_truth: bool = false
var window_timer: float = 0.0
var next_window_timer: float = 1.5
var _window_item_l: Variant = null   # raw objects of the windowed item, logged when it is marked
var _window_item_r: Variant = null
var _take_top: float = 0.0     # item-top y at which the robot takes/leaves it (within h/2..3h/4)
var _mark_top: float = 0.0     # item-top y at which the ✓/✗ answer first appears
var _window_marked: bool = false

# Phase state
var _demo_phase: bool = false
var _showing_demo_action: bool = false
var examples_per_belt: Array = [0, 0]
var _yes_per_belt: Array = [0, 0]  # picked-up (matched) demos per belt; need >=3 before asking
var _no_per_belt: Array = [0, 0]   # left (unmatched) demos per belt; need >=2 before asking
# Every demo the player was shown this round, per belt: {item_l, item_r, verdict}. Cleared with the
# rules each round. _build_options tests candidate rules against this to guarantee every offered
# wrong answer was actually ruled out by the demos.
var _demo_log: Array = [[], []]

# Question phase
# --- tutorial staging (all inert outside tutorial_mode) ---------------------
# The coach chooses whether the next judged item will be a pick-up or a leave, so ✓ and ✗ can each
# be taught on demand instead of waiting for the shuffle to produce one.
var tutorial_force_truth: int = -1
var _tutorial_window_entered: bool = false

var _question_phase: bool = false
var _question_answered: bool = false
var _question_start_time: float = 0.0
var question_panel: Control = null
var waiting_for_input: bool = false

var _primes: Array = [2, 3, 5, 7, 11, 13, 17, 19, 23]
var _non_primes: Array = [1, 4, 6, 8, 9, 10, 12, 14, 15, 16, 18, 20, 21, 22, 24, 25]
var _straight_letters: Array = ["A", "E", "F", "H", "I", "K", "L", "M", "N", "T", "V", "W", "X", "Y", "Z"]
var _curved_letters: Array = ["B", "C", "D", "G", "J", "O", "P", "Q", "R", "S", "U"]
var _color_names: Array = ["RED", "BLUE", "GREEN", "YELLOW", "PURPLE"]
var _color_values: Dictionary = {
	"RED": Color.RED, "BLUE": Color.BLUE, "GREEN": Color(0.0, 0.75, 0.0),
	"YELLOW": Color.YELLOW, "PURPLE": Color(0.6, 0.0, 0.9),
}
var _all_modality_keys: Array = ["digit", "square", "even_odd", "vowel", "prime", "filled", "hollow", "stroop", "color_shape", "lines"]

# The pool of rule keys allowed for the CURRENT level (from level_config "rules"). Each round the
# pair of shown attributes AND the multiple-choice options are drawn from this pool, so the rules
# vary from round to round instead of being fixed.
var _level_rules_pool: Array = []

# The rule pair used last time, so the next pick can avoid repeating it.
var _last_pair_keys: Array = []

# Two rules may only be shown together if NO single object can satisfy both — otherwise an item
# would legitimately belong to both sides and the "correct" answer is arbitrary. The pairs below
# genuinely overlap:
#   digit/even_odd/prime — "4" is a digit AND even; "3" is a digit AND prime AND odd
#   vowel/lines          — A, E, I are vowels AND straight-line letters
#   square/filled/color_shape — a ■ is a square AND filled; colored shapes are all filled glyphs
# (hollow is absent on purpose: hollow glyphs are disjoint from square, filled and color_shape.)
const _CONFUSABLE_WITH: Dictionary = {
	"digit": ["even_odd", "prime"],
	"even_odd": ["digit", "prime"],
	"prime": ["digit", "even_odd"],
	"vowel": ["lines"],
	"lines": ["vowel"],
	"square": ["filled", "color_shape"],
	"filled": ["square", "color_shape"],
	"color_shape": ["square", "filled"],
}

var correct_audio = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var wrong_audio = preload("res://art/sounds/swoosh.mp3")

signal sig_level_is_done(didwin: bool)
signal started_playing

func _ready() -> void:
	game = MonkeyCG.game
	game.sig_time_over.connect(_on_time_over)
	game.add_sound(self, "correct", correct_audio)
	game.add_sound(self, "wrong", wrong_audio)
	var layout: MarginContainer = $MainLayout
	layout.offset_top = 148.0 if MainGlobals.is_mobile() else 192.0
	layout.offset_bottom = -(MainGlobals.footer_height + 15.0)
	if MainGlobals.is_mobile():
		pair_font_size = 48
		item_h = 100.0
		%LeftRuleLabel.add_theme_font_size_override("font_size", 32)
		%RightRuleLabel.add_theme_font_size_override("font_size", 32)
		%AvgTimeLabel.add_theme_font_size_override("font_size", 36)
		$MainLayout/VBox/ContentVBox/BoxesRow/LeftSide/LeftBox.custom_minimum_size = Vector2(220, 500)
		$MainLayout/VBox/ContentVBox/BoxesRow/RightSide/RightBox.custom_minimum_size = Vector2(220, 500)
	var f: Font = MainGlobals.get_system_sans_font()
	%AvgTimeLabel.add_theme_font_override("font", f)
	%FeedbackLabel.add_theme_font_override("font", f)
	%LeftRuleLabel.add_theme_font_override("font", f)
	%RightRuleLabel.add_theme_font_override("font", f)
	# Reserve a 2-line height on both rule labels so a 1-line and a 2-line rule occupy the
	# same space, keeping the two belts vertically aligned (see sortingrobots).
	var rule_fs: int = 32 if MainGlobals.is_mobile() else 22
	var two_line_h: float = f.get_height(rule_fs) * 2.0 + 12.0
	%LeftRuleLabel.custom_minimum_size = Vector2(0, two_line_h)
	%RightRuleLabel.custom_minimum_size = Vector2(0, two_line_h)
	%LeftRuleLabel.add_theme_constant_override("line_spacing", -8)
	%RightRuleLabel.add_theme_constant_override("line_spacing", -8)
	%LeftRuleLabel.modulate.a = 0.0
	%RightRuleLabel.modulate.a = 0.0
	%LeftItemsContainer.clip_contents = true
	%RightItemsContainer.clip_contents = true
	set_process(false)

# --- Modality building ---

# Every modality carries a "test" callable alongside its generator: given ONE displayed object it
# returns 1 (satisfies the rule), 0 (does not), or -1 (rule doesn't apply to this kind of object).
# The test is what lets _build_options prove a candidate option was actually ruled out by the demos
# (see _is_distinguishable) instead of trusting a hardcoded overlap table. It must stay in sync with
# the matching "gen" — including per-instance randomness like even_odd's even/odd choice, which is
# why the test is baked into the same dictionary as the label the player is offered.
func _build_modality(key: String) -> Dictionary:
	match key:
		"digit":
			return {"key": key, "label": "Is it a digit?",
				"gen": func(ok): return _gen_digit_or_letter(ok),
				"test": func(item): return _test_digit(item),
				"make": func(item): return _make_text(item)}
		"square":
			return {"key": key, "label": "Is it a square?",
				"gen": func(ok): return _gen_shape(ok, ["■"], ["●", "▲", "★"]),
				"test": func(item): return _test_glyph_in(item, ["■"]),
				"make": func(item): return _make_text(item)}
		"even_odd":
			var use_even: bool = rng.randi_range(0, 1) == 0
			return {"key": key, "label": "Is it even?" if use_even else "Is it odd?",
				"gen": func(ok): return _gen_even_odd(ok if use_even else !ok),
				"test": func(item): return _test_even_odd(item, use_even),
				"make": func(item): return _make_text(item)}
		"vowel":
			return {"key": key, "label": "Is it a vowel?",
				"gen": func(ok): return _gen_vowel_consonant(ok),
				"test": func(item): return _test_letter_in(item, ["A","E","I","O","U"]),
				"make": func(item): return _make_text(item)}
		"prime":
			return {"key": key, "label": "Is it prime?",
				"gen": func(ok): return _gen_prime_or_not(ok),
				"test": func(item): return _test_prime(item),
				"make": func(item): return _make_text(item)}
		"filled":
			return {"key": key, "label": "Is it a filled shape?",
				"gen": func(ok): return _gen_shape(ok, ["■","●","▲","★"], ["□","○","△","☆"]),
				"test": func(item): return _test_glyph_in(item, ["■","●","▲","★"]),
				"make": func(item): return _make_text(item)}
		"hollow":
			return {"key": key, "label": "Is it a hollow shape?",
				"gen": func(ok): return _gen_shape(ok, ["□","○","△","☆"], ["■","●","▲","★"]),
				"test": func(item): return _test_glyph_in(item, ["□","○","△","☆"]),
				"make": func(item): return _make_text(item)}
		"stroop":
			return {"key": key, "label": "Color = text color?",
				"gen": func(ok): return _gen_stroop(ok),
				"test": func(item): return _test_stroop(item),
				"make": func(item): return _make_stroop(item)}
		"color_shape":
			return {"key": key, "label": "Shape is blue or red?",
				"gen": func(ok): return _gen_colored_shape(ok),
				"test": func(item): return _test_colored_shape(item),
				"make": func(item): return _make_colored_shape(item)}
		"lines":
			return {"key": key, "label": "Letter is straight lines?",
				"gen": func(ok): return _gen_straight_letter(ok),
				"test": func(item): return _test_letter_in(item, _straight_letters),
				"make": func(item): return _make_text(item)}
	return {}

# --- Rule tests: 1 = satisfies, 0 = does not, -1 = rule does not apply to this object ---
# -1 matters: an object the rule can't even be applied to is NOT evidence either way, so it must
# never be counted as agreement or disagreement when judging whether an option was ruled out.

const _SHAPE_GLYPHS: Array = ["■", "●", "▲", "★", "□", "○", "△", "☆"]

# The glyph a plain-text object shows, or "" when the object isn't a single glyph/letter/digit.
func _glyph_of(item: Variant) -> String:
	if typeof(item) == TYPE_DICTIONARY:
		return str(item.get("shape", ""))   # colored shapes are still shapes
	var s: String = str(item)
	return s if s.length() == 1 else ""

func _test_digit(item: Variant) -> int:
	if typeof(item) == TYPE_DICTIONARY:
		return -1
	var s: String = str(item)
	if s.length() != 1:
		return -1                      # multi-digit numbers read as numbers, not "a digit"
	if s >= "0" and s <= "9":
		return 1
	if s >= "A" and s <= "Z":
		return 0
	return -1

func _test_glyph_in(item: Variant, wanted: Array) -> int:
	var g: String = _glyph_of(item)
	if g == "" or not _SHAPE_GLYPHS.has(g):
		return -1
	return 1 if wanted.has(g) else 0

func _test_letter_in(item: Variant, wanted: Array) -> int:
	if typeof(item) == TYPE_DICTIONARY:
		return -1
	var s: String = str(item)
	if s.length() != 1 or s < "A" or s > "Z":
		return -1
	return 1 if wanted.has(s) else 0

func _test_even_odd(item: Variant, use_even: bool) -> int:
	if typeof(item) == TYPE_DICTIONARY:
		return -1
	var s: String = str(item)
	if not s.is_valid_int():
		return -1
	var n: int = int(s)
	return 1 if ((n % 2 == 0) == use_even) else 0

func _test_prime(item: Variant) -> int:
	if typeof(item) == TYPE_DICTIONARY:
		return -1
	var s: String = str(item)
	if not s.is_valid_int():
		return -1
	return 1 if _primes.has(int(s)) else 0

func _test_stroop(item: Variant) -> int:
	if typeof(item) != TYPE_DICTIONARY or not item.has("text"):
		return -1
	return 1 if item["color"] == _color_values.get(item["text"], null) else 0

func _test_colored_shape(item: Variant) -> int:
	if typeof(item) != TYPE_DICTIONARY or not item.has("shape"):
		return -1
	var c: Color = item["color"]
	return 1 if (c == Color.BLUE or c == Color.RED) else 0

# Verdict a rule gives for a whole belt item (a PAIR of objects): true when EITHER object satisfies
# it, which is how the player reads it — they scan both glyphs for one the rule accepts.
# A rule that applies to neither object yields false, not "unknown": an item with no letters on it
# simply is not a vowel. That matters, because the demo gating guarantees at least one pick-up, so
# an inapplicable rule genuinely contradicts that pick-up and is fair to offer (if obviously weak).
func _rule_verdict(mod: Dictionary, entry: Dictionary) -> bool:
	for obj in [entry.get("item_l"), entry.get("item_r")]:
		if mod["test"].call(obj) == 1:
			return true
	return false

# A candidate option is only FAIR if the player could have ruled it out: on at least one item the
# robot demonstrated, this rule disagrees with the verdict the robot showed. A rule that agrees
# with every demo explains everything the player saw just as well as the real rule, so offering it
# would mark a perfectly sound answer wrong. This is what makes num_options safe to raise: it
# catches structural overlaps (■ is square AND filled) and accidental ones (the demoed digits all
# happened to be prime) alike, with no hardcoded table to maintain.
func _is_distinguishable(mod: Dictionary, belt_idx: int) -> bool:
	for entry in _demo_log[belt_idx]:
		if _rule_verdict(mod, entry) != bool(entry["verdict"]):
			return true
	return false

func _u(text: String) -> String:
	return text.to_upper() if MonkeyCG.use_uppercase else text

func _gen_digit_or_letter(is_correct: bool) -> String:
	if is_correct:
		return str(rng.randi_range(1, 9))
	var letters: String = "ABCDEFGHJKLMNPQRSTUVWXYZ"
	return str(letters[rng.randi_range(0, letters.length() - 1)])

func _gen_even_odd(is_correct: bool) -> String:
	var n: int = rng.randi_range(1, 25)
	return str(n * 2 if is_correct else n * 2 - 1)

func _gen_vowel_consonant(is_correct: bool) -> String:
	var pool: String = "AEIU" if is_correct else "BCDFGHJKLMNPQRSTVWXYZ"
	return str(pool[rng.randi_range(0, pool.length() - 1)])

func _gen_prime_or_not(is_correct: bool) -> String:
	var pool: Array = _primes if is_correct else _non_primes
	return str(pool[rng.randi_range(0, pool.size() - 1)])

func _gen_shape(is_correct: bool, correct_shapes: Array, wrong_shapes: Array) -> String:
	var pool: Array = correct_shapes if is_correct else wrong_shapes
	return pool[rng.randi_range(0, pool.size() - 1)]

func _gen_straight_letter(is_correct: bool) -> String:
	var pool: Array = _straight_letters if is_correct else _curved_letters
	return pool[rng.randi_range(0, pool.size() - 1)]

func _gen_stroop(is_correct: bool) -> Dictionary:
	var word: String = _color_names[rng.randi_range(0, _color_names.size() - 1)]
	if is_correct:
		return {"text": word, "color": _color_values[word]}
	var others: Array = _color_names.filter(func(c): return c != word)
	return {"text": word, "color": _color_values[others[rng.randi_range(0, others.size() - 1)]]}

func _gen_colored_shape(is_correct: bool) -> Dictionary:
	var shapes: Array = ["■", "●", "▲", "★"]
	var shape: String = shapes[rng.randi_range(0, shapes.size() - 1)]
	if is_correct:
		return {"shape": shape, "color": [Color.BLUE, Color.RED][rng.randi_range(0, 1)]}
	var others: Array = [Color(0.0, 0.75, 0.0), Color.YELLOW, Color(0.6, 0.0, 0.9), Color.WHITE, Color.ORANGE]
	return {"shape": shape, "color": others[rng.randi_range(0, others.size() - 1)]}

func _make_text(item: Variant) -> Label:
	var lbl: Label = Label.new()
	lbl.text = _u(str(item))
	lbl.add_theme_font_size_override("font_size", pair_font_size)
	lbl.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

func _make_stroop(item: Dictionary) -> Label:
	var lbl: Label = Label.new()
	lbl.text = _u(item["text"])
	lbl.add_theme_font_size_override("font_size", 40)
	lbl.add_theme_color_override("font_color", item["color"])
	lbl.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

func _make_colored_shape(item: Dictionary) -> Label:
	var lbl: Label = Label.new()
	lbl.text = item["shape"]
	lbl.add_theme_font_size_override("font_size", pair_font_size)
	lbl.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.modulate = item["color"]
	return lbl

func _make_pair_control(item_l: Variant, mod_l: Dictionary, item_r: Variant, mod_r: Dictionary, bw: float) -> Control:
	var c: Control = Control.new()
	var lbl_l: Label = mod_l["make"].call(item_l)
	var lbl_r: Label = mod_r["make"].call(item_r)
	var shares: Array = _share_pair_widths(lbl_l, lbl_r, bw, pair_font_size)
	lbl_l.size = Vector2(shares[0], item_h)
	lbl_l.position = Vector2(0.0, 0.0)
	lbl_r.size = Vector2(shares[1], item_h)
	lbl_r.position = Vector2(shares[0] + _PAIR_GAP, 0.0)
	c.add_child(lbl_l)
	c.add_child(lbl_r)
	return c

# --- Pair layout ---
# Objects are sized to FIT. A stroop word ("YELLOW") is many times wider than a glyph, so splitting
# the item width 50/50 made the word spill over its half and collide with the other object. Instead
# the two objects share the width in proportion to how wide they actually are, and each font is
# shrunk until its text fits the share it got.

const _PAIR_GAP: float = 8.0
const _MIN_PAIR_FONT: int = 12

func _text_width(lbl: Label, font_size: int) -> float:
	var f: Font = lbl.get_theme_font("font")
	if f == null:
		f = MainGlobals.get_system_sans_font()
	return f.get_string_size(lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

# Shrink the label's font until its text fits max_w. Returns the size actually used.
func _fit_label_width(lbl: Label, max_w: float, start_size: int) -> int:
	var fs: int = start_size
	while fs > _MIN_PAIR_FONT and _text_width(lbl, fs) > max_w:
		fs -= 1
	lbl.add_theme_font_size_override("font_size", fs)
	return fs

# Give each label a share of `total_w` proportional to its natural width, then fit its font to that
# share. Returns [width_l, width_r] — laid out with _PAIR_GAP between them.
func _share_pair_widths(lbl_l: Label, lbl_r: Label, total_w: float, base_size: int) -> Array:
	var avail: float = maxf(total_w - _PAIR_GAP, 20.0)
	var wl: float = _text_width(lbl_l, base_size)
	var wr: float = _text_width(lbl_r, base_size)
	var alloc_l: float = avail * 0.5
	var alloc_r: float = avail * 0.5
	if wl + wr > 0.0:
		# proportional share, but never starve one side below a readable sliver
		alloc_l = clampf(avail * (wl / (wl + wr)), avail * 0.18, avail * 0.82)
		alloc_r = avail - alloc_l
	_fit_label_width(lbl_l, alloc_l, base_size)
	_fit_label_width(lbl_r, alloc_r, base_size)
	return [alloc_l, alloc_r]

# --- Belt helpers ---

func _containers() -> Array:
	return [%LeftItemsContainer, %RightItemsContainer]

func _spawn_belt_item(si: int, y: float, bw: float) -> Dictionary:
	var truth_l: bool = rng.randi_range(0, 1) == 1
	var truth_r: bool = rng.randi_range(0, 1) == 1
	var item_l: Variant = current_pair[0]["gen"].call(truth_l)
	var item_r: Variant = current_pair[1]["gen"].call(truth_r)
	var swapped: bool = rng.randi_range(0, 1) == 1
	var ctrl: Control
	if swapped:
		ctrl = _make_pair_control(item_r, current_pair[1], item_l, current_pair[0], bw)
	else:
		ctrl = _make_pair_control(item_l, current_pair[0], item_r, current_pair[1], bw)
	ctrl.size = Vector2(bw, item_h)
	ctrl.position = Vector2(0.0, y)
	_containers()[si].add_child(ctrl)
	# item_l/item_r keep the RAW generated objects (not just the truth flags) so a demonstrated
	# item can later be re-tested against candidate rules — see _is_distinguishable.
	return {"ctrl": ctrl, "truth_l": truth_l, "truth_r": truth_r, "item_l": item_l, "item_r": item_r}

func _init_belts() -> void:
	for si in num_belts:
		var container: Control = _containers()[si]
		var h: float = container.size.y
		var bw: float = container.size.x
		if h <= 0.0 or bw <= 0.0:
			return
		var y_offset: float = 0.0 if si == 0 else rng.randf_range(40.0, 75.0)
		var y: float = -item_h - y_offset
		while y < h + item_h:
			belt_items[si].append(_spawn_belt_item(si, y, bw))
			y += rng.randf_range(80.0, 130.0)
	belt_initialized = true

func _scroll_belts(delta: float) -> void:
	for si in num_belts:
		var container: Control = _containers()[si]
		var h: float = container.size.y
		var bw: float = container.size.x
		if h <= 0.0 or bw <= 0.0:
			continue
		var items: Array = belt_items[si]
		for entry in items:
			entry["ctrl"].position.y += scroll_speed * delta
		var i: int = items.size() - 1
		while i >= 0:
			if items[i]["ctrl"].position.y >= h:
				items[i]["ctrl"].queue_free()
				items.remove_at(i)
			i -= 1
		var top_y: float = h
		for entry in items:
			if entry["ctrl"].position.y < top_y:
				top_y = entry["ctrl"].position.y
		while top_y > -item_h:
			top_y -= rng.randf_range(80.0, 130.0)
			items.append(_spawn_belt_item(si, top_y, bw))

func _clear_belts() -> void:
	for si in 2:
		for entry in belt_items[si]:
			if entry["ctrl"] != null and is_instance_valid(entry["ctrl"]):
				entry["ctrl"].queue_free()
		belt_items[si] = []
	_discard_window()

# --- Window / robot ---

func _process(delta: float) -> void:
	if game.paused() or game.level_is_done:
		return
	if not belt_initialized:
		_init_belts()
		return
	_scroll_belts(delta)
	# Keep window panel glued to its item at all times (including during robot action)
	if window_panel != null and is_instance_valid(window_panel) \
			and window_target_item != null and is_instance_valid(window_target_item):
		window_panel.position.y = window_target_item.position.y - 4.0
	if not _demo_phase:
		return
	if window_open and not _showing_demo_action:
		if window_target_item == null or not is_instance_valid(window_target_item):
			_discard_window()
			next_window_timer = 0.5
		else:
			var item_y: float = window_target_item.position.y
			var h: float = _containers()[window_belt].size.y
			if item_y >= h:
				_discard_window()
				next_window_timer = 0.3
			else:
				# The window deliberately opens on an item still ENTERING (item_y < 0) so the
				# highlight slides in with it — but the belt clips its contents, so until the item
				# is inside there is nothing on screen to point at. A coach told about the window
				# at `window_opened` framed empty space above the belt.
				if not _tutorial_window_entered and item_y >= 0.0:
					_tutorial_window_entered = true
					game.tutorial_notify("window_ready")
					if game.tutorial_mode:
						# Let the coach talk about the framed item before the ✓/✗ lands on it.
						# _mark_top can be 0 (robot_answer_time is longer than the run-in on easy
						# levels), so without this the answer appears in this very frame.
						return
				# show the ✓/✗ answer at _mark_top, then take/leave the item at _take_top (always
				# within h/2..3h/4). robot_answer_time sets how far apart those two points are.
				if not _window_marked and item_y >= _mark_top:
					_mark_item()
				if _window_marked and item_y >= _take_top:
					_take_item()
	elif not window_open and not _showing_demo_action:
		next_window_timer -= delta
		if next_window_timer <= 0.0:
			_open_demo_window()

func _open_demo_window() -> void:
	var candidates: Array = []
	for bi in num_belts:
		# keep opening windows until the belt has enough demos AND enough of BOTH answers
		# (>=3 picked-up, >=2 left) — otherwise the demo could stall and the belt runs forever
		if examples_per_belt[bi] < min_examples or _yes_per_belt[bi] < 3 or _no_per_belt[bi] < 2:
			candidates.append(bi)
	if candidates.is_empty():
		return
	var si: int = candidates[rng.randi_range(0, candidates.size() - 1)]
	var container: Control = _containers()[si]
	var h: float = container.size.y
	var bw: float = container.size.x
	# prefer an item whose outcome is the one we still need (>=3 yes first, then >=2 no) so the
	# demo reliably reaches both answers instead of possibly stalling on random truths
	var need_truth: int = -1
	if _yes_per_belt[si] < 3:
		need_truth = 1
	elif _no_per_belt[si] < 2:
		need_truth = 0
	if tutorial_force_truth >= 0:
		need_truth = tutorial_force_truth
	# open the window on an item still ENTERING from the top so the highlight slides in gradually
	# with it (clip_contents hides it while above the belt); the robot then reacts once the item
	# reaches the belt center (see _process), never mid-entry
	var target_y: float = -item_h * 0.5
	var best_entry: Variant = null
	var best_dist: float = INF
	var any_entry: Variant = null
	var any_dist: float = INF
	for entry in belt_items[si]:
		var item_y: float = entry["ctrl"].position.y
		if item_y >= 0.0 or item_y < -item_h * 4.0:
			continue
		var dist: float = abs(item_y - target_y)
		if dist < any_dist:
			any_dist = dist
			any_entry = entry
		var t: bool = entry["truth_l"] if si == 0 else entry["truth_r"]
		if (need_truth == -1 or int(t) == need_truth) and dist < best_dist:
			best_dist = dist
			best_entry = entry
	if best_entry == null:
		best_entry = any_entry
	if best_entry == null:
		next_window_timer = 0.3
		return
	window_belt = si
	window_target_item = best_entry["ctrl"]
	window_target_truth = best_entry["truth_l"] if si == 0 else best_entry["truth_r"]
	# keep the raw objects so _mark_item can log exactly what the player was shown
	_window_item_l = best_entry["item_l"]
	_window_item_r = best_entry["item_r"]
	var pad: float = 4.0
	var panel: Panel = Panel.new()
	panel.z_index = 2
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.85, 0.0, 0.18)
	sb.set_border_width_all(3)
	sb.border_color = Color(1.0, 0.9, 0.0, 1.0)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	panel.size = Vector2(bw, item_h + pad * 2.0)
	panel.position = Vector2(0.0, window_target_item.position.y - pad)
	container.add_child(panel)
	window_panel = panel
	window_open = true
	_tutorial_window_entered = false
	game.tutorial_notify("window_opened")   # no-op outside tutorial mode
	# the robot TAKES the item when it's between h/2 and 3h/4; the ✓/✗ answer appears
	# robot_answer_time earlier (clamped so it never shows before the item is fully inside)
	var take_center: float = rng.randf_range(h * 0.5, h * 0.75)
	_take_top = take_center - item_h * 0.5
	_mark_top = maxf(0.0, _take_top - robot_answer_time * scroll_speed)
	_window_marked = false

# Show the ✓/✗ answer on the highlighted item (when it reaches _mark_top). No pull yet.
func _mark_item() -> void:
	_window_marked = true
	var picks_up: bool = window_target_truth
	examples_per_belt[window_belt] += 1
	if picks_up:
		_yes_per_belt[window_belt] += 1
	else:
		_no_per_belt[window_belt] += 1
	# Log what the player just saw demonstrated — this is the evidence _build_options uses to
	# prove an offered option was genuinely ruled out.
	_demo_log[window_belt].append(
		{"item_l": _window_item_l, "item_r": _window_item_r, "verdict": picks_up})
	# (gating: the question waits until every belt has shown >=3 picked-up and >=2 left demos)
	if window_panel != null and is_instance_valid(window_panel):
		var sb: StyleBoxFlat = window_panel.get_theme_stylebox("panel") as StyleBoxFlat
		var indicator: Label = Label.new()
		indicator.add_theme_font_override("font", MainGlobals.get_system_sans_font())
		indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		indicator.size = window_panel.size
		if picks_up:
			indicator.text = "✓"
			indicator.add_theme_font_size_override("font_size", 36)
			indicator.add_theme_color_override("font_color", Color.GREEN)
			if sb != null:
				sb.border_color = Color.GREEN
				sb.bg_color = Color(0.0, 0.7, 0.0, 0.25)
		else:
			indicator.text = "✗"
			indicator.add_theme_font_size_override("font_size", 36)
			indicator.add_theme_color_override("font_color", Color(1.0, 0.35, 0.0))
			if sb != null:
				sb.border_color = Color(1.0, 0.35, 0.0)
				sb.bg_color = Color(1.0, 0.15, 0.0, 0.2)
		window_panel.add_child(indicator)
	game.tutorial_notify("item_marked")
	game.tutorial_notify("marked_yes" if picks_up else "marked_no")

# Take (pull) or leave the item once it reaches _take_top (within the h/2..3h/4 band).
func _take_item() -> void:
	_showing_demo_action = true
	var picks_up: bool = window_target_truth
	if picks_up and window_target_item != null and is_instance_valid(window_target_item):
		var target_ctrl: Control = window_target_item
		var bi: int = window_belt
		# remove from belt tracking, then the claw reparents & pulls the real item off the
		# nearest side (single belt → right). _discard_window then frees the highlight panel.
		var idx: int = belt_items[bi].size() - 1
		while idx >= 0:
			if belt_items[bi][idx]["ctrl"] == target_ctrl:
				belt_items[bi].remove_at(idx)
				break
			idx -= 1
		var to_right: bool = true if num_belts < 2 else (window_belt == 1)
		_claw_pull(to_right)
	_discard_window()
	_showing_demo_action = false
	game.tutorial_notify("item_resolved")
	if game.level_is_done:
		return
	var all_done: bool = true
	for bi in num_belts:
		# need enough of BOTH answers so the rule is inferable: >=3 picked-up, >=2 left
		if examples_per_belt[bi] < min_examples or _yes_per_belt[bi] < 3 or _no_per_belt[bi] < 2:
			all_done = false
	if all_done:
		_demo_phase = false
		_question_phase = true
		await get_tree().create_timer(_GRAB_TIME + _PULL_TIME).timeout
		await _ask_all_rules()
	else:
		next_window_timer = rng.randf_range(0.8, 1.5)

func _discard_window() -> void:
	window_open = false
	if window_panel != null and is_instance_valid(window_panel):
		window_panel.queue_free()
		window_panel = null
	window_belt = -1
	window_target_item = null

func _claw_pull(to_right: bool) -> void:
	# Reparent the ACTUAL item (unchanged — looks exactly as on the belt) into a flyer, keep the
	# highlight RECTANGLE around it (border only, transparent fill, no ✓ overlay), and let a claw
	# grip its edge. The claw first POPS the item a little larger so the pick-up reads as physical,
	# and only then yanks it off the nearest side. It never freezes — the grab is a brief beat.
	var item: Control = window_target_item
	if item == null or not is_instance_valid(item):
		return
	var item_gpos: Vector2 = item.global_position
	var item_size: Vector2 = item.size
	if item_size.x < 1.0 or item_size.y < 1.0:
		item_size = Vector2(item_h, item_h)
	# The flyer's ORIGIN sits at the item's center so scaling it grows the item in place; with the
	# origin at (0,0) the scale-up would drag the item toward the canvas corner instead.
	var item_center: Vector2 = item_gpos + item_size * 0.5
	var flyer: Node2D = Node2D.new()
	flyer.z_index = 80
	flyer.position = item_center
	add_child(flyer)
	var panel: Panel = window_panel
	if panel != null and is_instance_valid(panel):
		for ch in panel.get_children():
			if ch is Label:
				ch.queue_free()  # drop the ✓/✗ so nothing covers the item
		var psb: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if psb != null:
			psb.border_color = Color(0.2, 0.9, 0.3)  # correct pick-up → green frame
			psb.bg_color = Color(psb.bg_color.r, psb.bg_color.g, psb.bg_color.b, 0.0)
		panel.reparent(flyer, true)  # keep the (green) border rectangle around the item
		window_panel = null
	item.reparent(flyer, true)  # keep global transform so the item doesn't jump/change
	var claw: Node2D = CLAW_SCRIPT.new()
	claw.side = 1 if to_right else -1
	claw.box_size = item_size
	claw.position = item_gpos - item_center  # claw origin = box top-left, in flyer-local space
	flyer.add_child(claw)
	var sw: float = float(MainGlobals.screen_size.x)
	var dx: float = (sw + item_size.x + 80.0 - item_gpos.x) if to_right else (-(item_gpos.x + item_size.x + 560.0))
	var tw: Tween = flyer.create_tween()
	# 1) grip and lift — a quick pop, slightly overshooting, so it reads as being picked up
	tw.tween_property(flyer, "scale", Vector2(_GRAB_SCALE, _GRAB_SCALE), _GRAB_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 2) then yank it off the side, still held at the lifted size
	tw.tween_property(flyer, "position:x", flyer.position.x + dx, _PULL_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(flyer.queue_free)

# --- Question phase ---

func _ask_all_rules() -> void:
	for belt_idx in num_belts:
		if game.level_is_done or game.paused():
			return
		await _ask_for_rule(belt_idx)
	_question_phase = false
	rounds_done += 1
	_update_avg_label()
	if game.tutorial_mode:
		# One round is the whole lesson. Starting another (or ending the level, which drops a
		# "level completed" popup) would land on top of the coach's closing caption.
		return
	if rounds_done >= num_rounds_per_level:
		_level_done()
	else:
		_refresh_rules()
		examples_per_belt = [0, 0]
		_yes_per_belt = [0, 0]
		_demo_log = [[], []]
		_no_per_belt = [0, 0]
		_clear_belts()
		belt_initialized = false
		_demo_phase = true
		next_window_timer = 1.5

func _ask_for_rule(belt_idx: int) -> void:
	var belt_name: String = "LEFT" if belt_idx == 0 else "RIGHT"
	var question_text: String = "What was the rule?" if num_belts == 1 \
		else "What was the %s belt rule?" % belt_name
	var correct_key: String = question_correct_keys[belt_idx]
	var options: Array = _build_options(correct_key, belt_idx)
	question_panel = Control.new()
	question_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	question_panel.z_index = 10
	add_child(question_panel)
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.07, 0.0, 0.93)
	question_panel.add_child(bg)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.anchor_left = 0.08
	vbox.anchor_top = 0.12
	vbox.anchor_right = 0.92
	vbox.anchor_bottom = 0.92
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	question_panel.add_child(vbox)
	var q_lbl: Label = Label.new()
	q_lbl.text = question_text
	q_lbl.add_theme_font_size_override("font_size", 36 if MainGlobals.is_mobile() else 28)
	q_lbl.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	q_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3, 1.0))
	q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(q_lbl)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 16.0)
	vbox.add_child(spacer)
	var f: Font = MainGlobals.get_system_sans_font()
	for opt in options:
		var btn: Button = Button.new()
		btn.text = _u(opt["label"])
		btn.set_meta("opt_key", opt["key"])
		btn.add_theme_font_override("font", f)
		btn.add_theme_font_size_override("font_size", 30 if MainGlobals.is_mobile() else 22)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0.0, 72.0 if MainGlobals.is_mobile() else 56.0)
		btn.pressed.connect(_on_option_pressed.bind(opt["key"], correct_key, vbox))
		vbox.add_child(btn)
	_question_answered = false
	_question_start_time = game.game_time
	waiting_for_input = true
	game.tutorial_notify("question_shown")
	while not _question_answered:
		await get_tree().process_frame
	times_to_answer.append(game.game_time - _question_start_time)
	while times_to_answer.size() > 20:
		times_to_answer.remove_at(0)
	if question_panel != null and is_instance_valid(question_panel):
		question_panel.queue_free()
		question_panel = null

func _on_option_pressed(chosen_key: String, correct_key: String, vbox: VBoxContainer) -> void:
	if not waiting_for_input:
		return
	waiting_for_input = false
	total_rounds += 1
	var is_right: bool = chosen_key == correct_key
	if is_right:
		total_corrects += 1
		game.add_score_and_time(10, 0)
		game.add_correct_or_mistake(1, 0)
		game.play_sound("correct")
	else:
		var penalty: int = min(3, game.score)
		game.add_score_and_time(-penalty, 0)
		game.add_correct_or_mistake(0, 1)
		game.play_sound("wrong")
	if is_instance_valid(vbox):
		for child in vbox.get_children():
			if child is Button:
				var btn: Button = child as Button
				var key: String = btn.get_meta("opt_key", "")
				if key == correct_key:
					btn.modulate = Color.GREEN
				elif key == chosen_key and not is_right:
					btn.modulate = Color.RED
				# don't disable (that dims the buttons) — keep every option clearly readable;
				# only the green/red marks show the result. Interaction is already blocked by
				# waiting_for_input, so no need to disable.
				btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.tutorial_notify("question_answered")
	await get_tree().create_timer(1.0).timeout
	_question_answered = true

# Build the multiple-choice options for a belt. EVERY wrong answer offered must be one the demos
# actually ruled out (_is_distinguishable) — otherwise the player could pick a rule that explains
# everything they saw and still be marked wrong. Candidates are tried in preference order:
#   1. the other visible attribute — the tempting guess, so the player must reason, not eliminate
#   2. the rest of this level's rules pool
#   3. any remaining modality, so num_options can exceed the pool size and still be safe
# If too few candidates survive, FEWER options are shown. That is deliberate: a smaller honest
# question beats a full-size one containing an unanswerable option.
func _build_options(correct_key: String, belt_idx: int) -> Array:
	var correct_mod: Dictionary = _build_modality(correct_key)
	var tried: Array = [correct_key]
	var candidates: Array = []
	for m in current_pair:
		if not tried.has(m["key"]):
			tried.append(m["key"])
			candidates.append(m["key"])
	var pool_extra: Array = _level_rules_pool.filter(func(k): return not tried.has(k))
	pool_extra.shuffle()
	for k in pool_extra:
		tried.append(k)
		candidates.append(k)
	var others: Array = _all_modality_keys.filter(func(k): return not tried.has(k))
	others.shuffle()
	candidates.append_array(others)

	var options: Array = [{"key": correct_key, "label": correct_mod.get("label", correct_key)}]
	for k in candidates:
		if options.size() >= num_options:
			break
		# build the modality ONCE and validate that exact instance: even_odd picks even-vs-odd per
		# build, so the label offered must be the one that was tested.
		var mod: Dictionary = _build_modality(k)
		if mod.is_empty() or not _is_distinguishable(mod, belt_idx):
			continue
		options.append({"key": k, "label": mod.get("label", k)})
	options.shuffle()
	return options

# --- Game flow ---

func new_game(from_scratch: bool = true) -> void:
	game.level_is_done = false
	times_to_answer.clear()
	if from_scratch:
		total_rounds = 0
		total_corrects = 0
		MonkeyCG.reset_queue_from(MonkeyCG.starting_level_id)
	game.need_to_increase_level = false
	current_level_id = MonkeyCG.pop_next_level_id()
	_load_level(current_level_id)
	rounds_done = 0
	_demo_phase = false
	_question_phase = false
	_showing_demo_action = false
	examples_per_belt = [0, 0]
	_yes_per_belt = [0, 0]
	_demo_log = [[], []]
	_no_per_belt = [0, 0]
	waiting_for_input = false
	_question_answered = false
	belt_initialized = false
	window_open = false
	window_belt = -1
	window_target_item = null
	next_window_timer = 1.5
	if question_panel != null and is_instance_valid(question_panel):
		question_panel.queue_free()
		question_panel = null
	_clear_belts()
	%FeedbackLabel.modulate.a = 0.0
	%AvgTimeLabel.text = "Watch the robot..."
	var right_side: Node = _containers()[1].get_parent().get_parent()
	if right_side != null:
		right_side.visible = num_belts == 2
	if game.tutorial_mode:
		_tutorial_setup()
	game.level_is_ready = true
	started_playing.emit()
	set_process(true)
	await get_tree().process_frame
	if game.tutorial_mode and not belt_initialized:
		# The belts are normally filled by the first _process tick, but _process returns early on
		# game.paused() and the coach's opening captions pause the game — so without this the belt
		# is still empty when the tutorial points at "one of these items".
		_init_belts()
	_demo_phase = true

func _load_level(id: int) -> void:
	var def: Dictionary = MonkeyCLevelConfig.get_level(id)
	num_rounds_per_level = def.get("rounds", 3)
	num_options = def.get("num_options", 3)
	num_belts = def.get("num_belts", 1)
	min_examples = def.get("min_examples", 4)
	robot_answer_time = float(def.get("robot_answer_time", 1.5))
	scroll_speed = float(def.get("belt_spd", 55.0))
	_level_rules_pool = def.get("rules", ["digit", "square"]).duplicate()
	_pick_pair_from_pool()
	game.level_label_changed("Level " + str(def.get("name", id)))

func _refresh_rules() -> void:
	_pick_pair_from_pool()

# True if the two rule keys can be confused (one's demos could also be explained by the other),
# so they must never be the two shown attributes at once.
func _are_confusable(a: String, b: String) -> bool:
	return _CONFUSABLE_WITH.get(a, []).has(b) or _CONFUSABLE_WITH.get(b, []).has(a)

# Pick this round's shown pair from the level's rule pool: two DISTINCT, non-confusable rules.
# For 1 belt the first is the hidden rule and the second is a decoy attribute; for 2 belts both
# are hidden rules (one per belt). Because it re-picks every round, the rules vary within a level.
func _pick_pair_from_pool() -> void:
	var pool: Array = _level_rules_pool.duplicate()
	if pool.is_empty():
		pool = _all_modality_keys.duplicate()   # empty "rules" in level_config = use every rule
	if pool.size() < 2:
		pool = ["digit", "square"]
	pool.shuffle()
	# Prefer a pair different from last time so replaying a level (or wrapping around the
	# progression order) doesn't serve up the same two rules again; fall back to repeating only
	# when the pool offers no alternative.
	var chosen: Array = _find_rule_pair(pool, true)
	if chosen.is_empty():
		chosen = _find_rule_pair(pool, false)
	if chosen.is_empty():
		# every rule in the pool overlaps every other — author error; fall back rather than hang
		push_warning("level rule pool has no non-overlapping pair: %s" % str(pool))
		chosen = [pool[0], pool[1]]
	_last_pair_keys = [chosen[0], chosen[1]]
	current_pair = [_build_modality(chosen[0]), _build_modality(chosen[1])]
	question_correct_keys = [current_pair[0]["key"]]
	if num_belts == 2:
		question_correct_keys.append(current_pair[1]["key"])

# Search the shuffled pool for a legal pair (no single object may satisfy both rules). When
# `avoid_last` is set, the pair used last time is skipped regardless of order.
func _find_rule_pair(pool: Array, avoid_last: bool) -> Array:
	for i in pool.size():
		for j in pool.size():
			if i == j or _are_confusable(pool[i], pool[j]):
				continue
			if avoid_last and _last_pair_keys.has(pool[i]) and _last_pair_keys.has(pool[j]):
				continue
			return [pool[i], pool[j]]
	return []

# The status line only ever tells the player what to do. The mean option-selection time is NOT
# shown here — it measures how fast the player names the rule, which has nothing to do with the
# belt they're watching and just reads as noise mid-level. It is still tracked in
# `times_to_answer` for the score row (POS_SCORE_MEAN_TIME_MS) and the level-end popup.
func _update_avg_label() -> void:
	%AvgTimeLabel.text = "Watch the robot..."

func _level_done() -> void:
	set_process(false)
	game.level_is_done = true
	MonkeyCG.record_level_result(current_level_id, pct_correct())
	game.sig_level_is_done.emit(true)
	MainGlobals.global_level_is_done(true)
	if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
		MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
	var extra: String = "\n\nAccuracy: %d%%\nMean time: %s" % [
		pct_correct(),
		("%d ms" % mean_response_time_ms()) if not times_to_answer.is_empty() else "N/A"
	]
	game.show_level_done_popup(self, "", extra, 0, "")

func _on_level_done_popup_closed() -> void:
	sig_level_is_done.emit(true)

func _on_time_over() -> void:
	pass

func mean_response_time_ms() -> int:
	if times_to_answer.is_empty():
		return 9999
	var s: float = 0.0
	for t in times_to_answer:
		s += t
	return roundi(s / times_to_answer.size())

func pct_correct() -> int:
	if total_rounds == 0:
		return 0
	return roundi(100.0 * float(total_corrects) / float(total_rounds))

func tick() -> void:
	pass

# --- tutorial staging -------------------------------------------------------
#
# The belts need no explicit freeze: _process returns early on game.paused(), so a talking step
# stops the belts, the window and the ✓/✗ timing all by itself.

func _tutorial_setup() -> void:
	tutorial_force_truth = -1

# --- things for the coach to point at (all in SCREEN coordinates) -----------

func tutorial_belt_rect() -> Rect2:
	var c: Control = _containers()[0]
	return c.get_global_rect() if c != null and is_instance_valid(c) else Rect2()

# The visible part of the highlight the robot puts on the item it is about to judge.
#
# The belt is clip_contents, so a panel whose item is still entering (or already leaving) is
# partly or entirely off it. Returning the raw panel rect framed empty space above the belt.
func tutorial_window_rect() -> Rect2:
	if window_panel == null or not is_instance_valid(window_panel) or not window_open:
		return Rect2()
	var r: Rect2 = window_panel.get_global_rect()
	if window_belt >= 0:
		var c: Control = _containers()[window_belt]
		if c != null and is_instance_valid(c):
			r = r.intersection(c.get_global_rect())
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return Rect2()
	return r

# An item to point at for "each of these is a PAIR of things". Picks the one nearest the MIDDLE of
# the belt, not the one furthest down: the lowest item is often half off the end of the belt, and
# the spotlight then lands below the screen entirely.
func tutorial_an_item_rect() -> Rect2:
	var container: Control = _containers()[0]
	if container == null or not is_instance_valid(container):
		return Rect2()
	var mid: float = container.size.y * 0.5
	var best: Control = null
	var best_d: float = INF
	for entry in belt_items[0]:
		var c: Control = entry["ctrl"]
		if not is_instance_valid(c):
			continue
		# fully inside the belt, top and bottom
		if c.position.y < 0.0 or c.position.y + item_h > container.size.y:
			continue
		var d: float = absf(c.position.y + item_h * 0.5 - mid)
		if d < best_d:
			best_d = d
			best = c
	return best.get_global_rect() if best != null else Rect2()

func tutorial_window_is_open() -> bool:
	return window_open and window_panel != null and is_instance_valid(window_panel)

# Whether the item under the window will be taken (✓) or left (✗), so the caption can say which
# without waiting to be told.
func tutorial_window_truth() -> bool:
	return window_target_truth

# The multiple-choice panel, so the caption can stay off the options.
func tutorial_question_rect() -> Rect2:
	if question_panel == null or not is_instance_valid(question_panel):
		return Rect2()
	for c in question_panel.get_children():
		if c is VBoxContainer:
			return (c as VBoxContainer).get_global_rect()
	return Rect2()

func tutorial_question_open() -> bool:
	return question_panel != null and is_instance_valid(question_panel)


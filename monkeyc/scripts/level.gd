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
var _take_top: float = 0.0     # item-top y at which the robot takes/leaves it (within h/2..3h/4)
var _mark_top: float = 0.0     # item-top y at which the ✓/✗ answer first appears
var _window_marked: bool = false

# Phase state
var _demo_phase: bool = false
var _showing_demo_action: bool = false
var examples_per_belt: Array = [0, 0]
var _yes_per_belt: Array = [0, 0]  # picked-up (matched) demos per belt; need >=3 before asking
var _no_per_belt: Array = [0, 0]   # left (unmatched) demos per belt; need >=2 before asking

# Question phase
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

# Rules whose demonstrations can ALSO be explained by another rule — never offer that other
# rule as a wrong-answer option (it would be a valid guess yet get marked wrong). E.g. a ■ is
# both a square and a filled shape, so "filled"/"hollow" must not be offered when the rule is
# "square", and "square" must not be offered when the rule is "filled"/"hollow". Extend as
# other overlaps are found.
const _CONFUSABLE_WITH: Dictionary = {
	"square": ["filled", "hollow"],
	"filled": ["square"],
	"hollow": ["square"],
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

func _build_modality(key: String) -> Dictionary:
	match key:
		"digit":
			return {"key": key, "label": "Is it a digit?",
				"gen": func(ok): return _gen_digit_or_letter(ok),
				"make": func(item): return _make_text(item)}
		"square":
			return {"key": key, "label": "Is it a square?",
				"gen": func(ok): return _gen_shape(ok, ["■"], ["●", "▲", "★"]),
				"make": func(item): return _make_text(item)}
		"even_odd":
			var use_even: bool = rng.randi_range(0, 1) == 0
			return {"key": key, "label": "Is it even?" if use_even else "Is it odd?",
				"gen": func(ok): return _gen_even_odd(ok if use_even else !ok),
				"make": func(item): return _make_text(item)}
		"vowel":
			return {"key": key, "label": "Is it a vowel?",
				"gen": func(ok): return _gen_vowel_consonant(ok),
				"make": func(item): return _make_text(item)}
		"prime":
			return {"key": key, "label": "Is it prime?",
				"gen": func(ok): return _gen_prime_or_not(ok),
				"make": func(item): return _make_text(item)}
		"filled":
			return {"key": key, "label": "Is it a filled shape?",
				"gen": func(ok): return _gen_shape(ok, ["■","●","▲","★"], ["□","○","△","☆"]),
				"make": func(item): return _make_text(item)}
		"hollow":
			return {"key": key, "label": "Is it a hollow shape?",
				"gen": func(ok): return _gen_shape(ok, ["□","○","△","☆"], ["■","●","▲","★"]),
				"make": func(item): return _make_text(item)}
		"stroop":
			return {"key": key, "label": "Color = text color?",
				"gen": func(ok): return _gen_stroop(ok),
				"make": func(item): return _make_stroop(item)}
		"color_shape":
			return {"key": key, "label": "Shape is blue or red?",
				"gen": func(ok): return _gen_colored_shape(ok),
				"make": func(item): return _make_colored_shape(item)}
		"lines":
			return {"key": key, "label": "Letter is straight lines?",
				"gen": func(ok): return _gen_straight_letter(ok),
				"make": func(item): return _make_text(item)}
	return {}

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
	var half_w: float = bw * 0.5
	var lbl_l: Label = mod_l["make"].call(item_l)
	lbl_l.add_theme_font_size_override("font_size", pair_font_size)
	lbl_l.size = Vector2(half_w, item_h)
	lbl_l.position = Vector2(0.0, 0.0)
	var lbl_r: Label = mod_r["make"].call(item_r)
	lbl_r.add_theme_font_size_override("font_size", pair_font_size)
	lbl_r.size = Vector2(half_w, item_h)
	lbl_r.position = Vector2(half_w, 0.0)
	c.add_child(lbl_l)
	c.add_child(lbl_r)
	return c

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
	return {"ctrl": ctrl, "truth_l": truth_l, "truth_r": truth_r}

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
	# open the window on an item still ENTERING from the top so the highlight slides in gradually
	# with it (clip_contents hides it while above the belt); the robot then reacts once the item
	# reaches the belt centre (see _process), never mid-entry
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
		await get_tree().create_timer(0.5).timeout
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
	# grip its edge and yank it off the nearest side. It never freezes — it moves as it's pulled.
	var item: Control = window_target_item
	if item == null or not is_instance_valid(item):
		return
	var item_gpos: Vector2 = item.global_position
	var item_size: Vector2 = item.size
	if item_size.x < 1.0 or item_size.y < 1.0:
		item_size = Vector2(item_h, item_h)
	var flyer: Node2D = Node2D.new()
	flyer.z_index = 80
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
	claw.position = item_gpos
	flyer.add_child(claw)
	var sw: float = float(MainGlobals.screen_size.x)
	var dx: float = (sw + item_size.x + 80.0 - item_gpos.x) if to_right else (-(item_gpos.x + item_size.x + 560.0))
	var tw: Tween = flyer.create_tween()
	tw.tween_property(flyer, "position:x", dx, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
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
	if rounds_done >= num_rounds_per_level:
		_level_done()
	else:
		_refresh_rules()
		examples_per_belt = [0, 0]
		_yes_per_belt = [0, 0]
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
	var options: Array = _build_options(correct_key)
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
	await get_tree().create_timer(1.0).timeout
	_question_answered = true

func _build_options(correct_key: String) -> Array:
	var correct_mod: Dictionary = _build_modality(correct_key)
	var banned: Array = _CONFUSABLE_WITH.get(correct_key, [])
	# Distractors are drawn from THIS LEVEL'S rule pool (the "rules we allow as options"), not from
	# every modality. The other visible attribute(s) are forced in first — they are the tempting
	# wrong guess, so the player must actually reason rather than pick the only shown alternative.
	var wrong_keys: Array = []
	for m in current_pair:
		var dk: String = m["key"]
		if dk != correct_key and not banned.has(dk) and not wrong_keys.has(dk):
			wrong_keys.append(dk)
	var pool_extra: Array = _level_rules_pool.filter(
		func(k): return k != correct_key and not banned.has(k) and not wrong_keys.has(k))
	pool_extra.shuffle()
	for k in pool_extra:
		if wrong_keys.size() >= num_options - 1:
			break
		wrong_keys.append(k)
	wrong_keys = wrong_keys.slice(0, num_options - 1)
	var options: Array = [{"key": correct_key, "label": correct_mod.get("label", correct_key)}]
	for k in wrong_keys:
		var mod: Dictionary = _build_modality(k)
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
	game.level_is_ready = true
	started_playing.emit()
	set_process(true)
	await get_tree().process_frame
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
	if pool.size() < 2:
		pool = ["digit", "square"]
	pool.shuffle()
	var chosen: Array = [pool[0]]
	for k in pool.slice(1):
		if not _are_confusable(chosen[0], k):
			chosen.append(k)
			break
	if chosen.size() < 2:
		# pool too confusable to find a clean partner — fall back to the first two keys
		chosen = [pool[0], pool[1]]
	current_pair = [_build_modality(chosen[0]), _build_modality(chosen[1])]
	question_correct_keys = [current_pair[0]["key"]]
	if num_belts == 2:
		question_correct_keys.append(current_pair[1]["key"])

func _update_avg_label() -> void:
	if times_to_answer.is_empty():
		%AvgTimeLabel.text = "Watch the robot..."
	else:
		%AvgTimeLabel.text = "Average time : %d ms" % mean_response_time_ms()

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

extends CanvasLayer

var game: GenericGameUtil
var current_level_id: int = 1

var rounds_before_hide: int = 6
var num_rounds_per_level: int = 10

var active_box: int = 0  # 0=left, 1=right
var ground_truth: bool = false
var round_start_ms: int = 0
var labels_hidden: bool = false
var rounds_done: int = 0
var waiting_for_input: bool = false

var times_to_answer: Array = []  # response times (ms) for correct answers only
var total_rounds: int = 0
var total_corrects: int = 0

# Built per level: [left_modality_dict, right_modality_dict]
var current_pair: Array = []

# The pool of rule keys allowed for the CURRENT level (from level_config "rules"). The two shown
# rules are drawn from it at random each time the level loads, so which rules appear — and which
# side each one lands on — varies from play to play instead of always being the same two.
var _level_rules_pool: Array = []

# Rules whose items can ALSO be explained by another rule — never show both at once (e.g. a ■ is
# both a square AND a filled shape, so one item would belong on both sides). Extend as other
# overlaps are found.
const _CONFUSABLE_WITH: Dictionary = {
	"square": ["filled", "hollow"],
	"filled": ["square"],
	"hollow": ["square"],
}

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _primes: Array = [2, 3, 5, 7, 11, 13, 17, 19, 23]
var _non_primes: Array = [1, 4, 6, 8, 9, 10, 12, 14, 15, 16, 18, 20, 21, 22, 24, 25]
var _straight_letters: Array = ["A", "E", "F", "H", "I", "K", "L", "M", "N", "T", "V", "W", "X", "Y", "Z"]
var _curved_letters: Array = ["B", "C", "D", "G", "J", "O", "P", "Q", "R", "S", "U"]
var _color_names: Array = ["RED", "BLUE", "GREEN", "YELLOW", "PURPLE"]
var _color_values: Dictionary = {
	"RED": Color.RED,
	"BLUE": Color.BLUE,
	"GREEN": Color(0.0, 0.75, 0.0),
	"YELLOW": Color.YELLOW,
	"PURPLE": Color(0.6, 0.0, 0.9),
}

var correct_audio = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var wrong_audio = preload("res://art/sounds/swoosh.mp3")

signal sig_level_is_done(didwin: bool)
signal started_playing

func _ready() -> void:
	game = RlmadnressG.game
	game.sig_time_over.connect(_on_time_over)
	game.add_sound(self, "correct", correct_audio)
	game.add_sound(self, "wrong", wrong_audio)
	var layout: MarginContainer = $MainLayout
	layout.offset_top = MainGlobals.header_height + 15.0
	layout.offset_bottom = -(MainGlobals.footer_height + 15.0)
	var f: Font = MainGlobals.get_system_sans_font()
	%LeftRuleLabel.add_theme_font_override("font", f)
	%RightRuleLabel.add_theme_font_override("font", f)
	%AvgTimeLabel.add_theme_font_override("font", f)
	%FeedbackLabel.add_theme_font_override("font", f)
	%LeftItemsContainer.clip_contents = true
	%RightItemsContainer.clip_contents = true
	%WrongButton.button_down.connect(func(): %WrongButton.modulate = Color(0.6, 0.6, 0.6))
	%WrongButton.button_up.connect(func(): %WrongButton.modulate = Color.WHITE)
	%CorrectButton.button_down.connect(func(): %CorrectButton.modulate = Color(0.6, 0.6, 0.6))
	%CorrectButton.button_up.connect(func(): %CorrectButton.modulate = Color.WHITE)

# --- Modality building ---

# Build a modality dict for the given key.
# Called at the start of each level so even_odd can randomly pick framing.
func _build_modality(key: String) -> Dictionary:
	match key:
		"digit":
			return {
				"label": "Is it a digit?",
				"gen": func(ok): return _gen_digit_or_letter(ok),
				"make": func(item): return _make_text(item)
			}
		"square":
			return {
				"label": "Is it a square?",
				"gen": func(ok): return _gen_shape(ok, ["■"], ["●", "▲", "★"]),
				"make": func(item): return _make_text(item)
			}
		"even_odd":
			var use_even: bool = rng.randi_range(0, 1) == 0
			return {
				"label": "Is it even?" if use_even else "Is it odd?",
				"gen": func(ok): return _gen_even_odd(ok if use_even else !ok),
				"make": func(item): return _make_text(item)
			}
		"vowel":
			return {
				"label": "Is it a vowel?",
				"gen": func(ok): return _gen_vowel_consonant(ok),
				"make": func(item): return _make_text(item)
			}
		"prime":
			return {
				"label": "Is it prime?",
				"gen": func(ok): return _gen_prime_or_not(ok),
				"make": func(item): return _make_text(item)
			}
		"filled":
			return {
				"label": "Is it a filled shape?",
				"gen": func(ok): return _gen_shape(ok, ["■", "●", "▲", "★"], ["□", "○", "△", "☆"]),
				"make": func(item): return _make_text(item)
			}
		"hollow":
			return {
				"label": "Is it a hollow shape?",
				"gen": func(ok): return _gen_shape(ok, ["□", "○", "△", "☆"], ["■", "●", "▲", "★"]),
				"make": func(item): return _make_text(item)
			}
		"stroop":
			return {
				"label": "Color = text color?",
				"gen": func(ok): return _gen_stroop(ok),
				"make": func(item): return _make_stroop(item)
			}
		"color_shape":
			return {
				"label": "Shape is\nblue or red?",
				"gen": func(ok): return _gen_colored_shape(ok),
				"make": func(item): return _make_colored_shape(item)
			}
		"lines":
			return {
				"label": "Letter is\nstraight lines?",
				"gen": func(ok): return _gen_straight_letter(ok),
				"make": func(item): return _make_text(item)
			}
	return {}

# --- Generation ---

func _gen_digit_or_letter(is_correct: bool) -> String:
	if is_correct:
		return str(rng.randi_range(1, 9))
	var letters: String = "ABCDEFGHJKLMNPQRSTUVWXYZ"
	return str(letters[rng.randi_range(0, letters.length() - 1)])

func _gen_even_odd(is_correct: bool) -> String:
	var n: int = rng.randi_range(1, 25)
	return str(n * 2 if is_correct else n * 2 - 1)

func _gen_vowel_consonant(is_correct: bool) -> String:
	var vowels: String = "AEIU"
	var consonants: String = "BCDFGHJKLMNPQRSTVWXYZ"
	var pool: String = vowels if is_correct else consonants
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
	var other: String = others[rng.randi_range(0, others.size() - 1)]
	return {"text": word, "color": _color_values[other]}

func _gen_colored_shape(is_correct: bool) -> Dictionary:
	var shapes: Array = ["■", "●", "▲", "★"]
	var shape: String = shapes[rng.randi_range(0, shapes.size() - 1)]
	if is_correct:
		return {"shape": shape, "color": [Color.BLUE, Color.RED][rng.randi_range(0, 1)]}
	var others: Array = [Color(0.0, 0.75, 0.0), Color.YELLOW, Color(0.6, 0.0, 0.9), Color.WHITE, Color.ORANGE]
	return {"shape": shape, "color": others[rng.randi_range(0, others.size() - 1)]}

# --- Rendering ---

const ITEM_FONT_SIZE: int = 90

func _u(text: String) -> String:
	return text.to_upper() if RlmadnressG.use_uppercase else text

func _make_text(item: Variant) -> Label:
	var lbl: Label = Label.new()
	lbl.text = _u(str(item))
	lbl.add_theme_font_size_override("font_size", ITEM_FONT_SIZE)
	lbl.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	return lbl

func _make_stroop(item: Dictionary) -> Label:
	var lbl: Label = Label.new()
	lbl.text = _u(item["text"])
	lbl.add_theme_font_size_override("font_size", 38)
	lbl.add_theme_color_override("font_color", item["color"])
	lbl.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	lbl.set_meta("outer_corner", true)
	return lbl

func _make_colored_shape(item: Dictionary) -> Label:
	var lbl: Label = Label.new()
	lbl.text = item["shape"]
	lbl.add_theme_font_size_override("font_size", ITEM_FONT_SIZE)
	lbl.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	lbl.modulate = item["color"]
	return lbl

# Place two labels diagonally in a container, both touching the container center.
# Each label fills one quadrant; text alignment pushes it toward the inner corner.
func _place_diagonal(container: Control, lbl_a: Label, lbl_b: Label) -> void:
	# Each array: [al, at, ar, ab, h_inner, v_inner, h_outer, v_outer]
	var q_tl: Array = [0.0, 0.0, 0.5, 0.5, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM, HORIZONTAL_ALIGNMENT_LEFT,  VERTICAL_ALIGNMENT_TOP]
	var q_br: Array = [0.5, 0.5, 1.0, 1.0, HORIZONTAL_ALIGNMENT_LEFT,  VERTICAL_ALIGNMENT_TOP,    HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM]
	var q_tr: Array = [0.5, 0.0, 1.0, 0.5, HORIZONTAL_ALIGNMENT_LEFT,  VERTICAL_ALIGNMENT_BOTTOM, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_TOP]
	var q_bl: Array = [0.0, 0.5, 0.5, 1.0, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_TOP,    HORIZONTAL_ALIGNMENT_LEFT,  VERTICAL_ALIGNMENT_BOTTOM]

	var flip: bool = rng.randi_range(0, 1) == 1
	var qa: Array = q_tl if not flip else q_tr
	var qb: Array = q_br if not flip else q_bl
	_apply_quad(container, lbl_a, qa)
	_apply_quad(container, lbl_b, qb)

func _apply_quad(container: Control, lbl: Label, q: Array) -> void:
	var outer: bool = lbl.get_meta("outer_corner", false)
	# outer_corner labels use full container width so single-line text never escapes the box
	lbl.anchor_left   = 0.0 if outer else q[0]
	lbl.anchor_top    = q[1]
	lbl.anchor_right  = 1.0 if outer else q[2]
	lbl.anchor_bottom = q[3]
	lbl.offset_left   = 0.0
	lbl.offset_top    = 0.0
	lbl.offset_right  = 0.0
	lbl.offset_bottom = 0.0
	lbl.horizontal_alignment = q[6] if outer else q[4]
	lbl.vertical_alignment   = q[7] if outer else q[5]
	container.add_child(lbl)

# --- Game flow ---

func new_game(from_scratch: bool = true) -> void:
	game.level_is_done = false
	times_to_answer.clear()
	if from_scratch:
		total_rounds = 0
		total_corrects = 0
		RlmadnressG.reset_queue_from(RlmadnressG.starting_level_id)
	game.need_to_increase_level = false
	current_level_id = RlmadnressG.pop_next_level_id()
	_load_level(current_level_id)
	rounds_done = 0
	labels_hidden = false
	waiting_for_input = false
	_show_labels()
	_update_avg_label()
	_clear_boxes()
	game.level_is_ready = true
	started_playing.emit()
	_next_round()

func _load_level(id: int) -> void:
	var def: Dictionary = RlmLevelConfig.get_level(id)
	rounds_before_hide = def.get("hide_after", 5)
	num_rounds_per_level = def.get("rounds", 12)
	_level_rules_pool = def.get("rules", ["digit", "square"]).duplicate()
	_pick_pair_from_pool()
	var level_name: String = def.get("name", "Level %d" % id)
	game.level_label_changed(level_name)

# True if the two rule keys can be confused (an item could satisfy both), so they must never be
# the two shown rules at once.
func _are_confusable(a: String, b: String) -> bool:
	return _CONFUSABLE_WITH.get(a, []).has(b) or _CONFUSABLE_WITH.get(b, []).has(a)

# Pick this level's two shown rules from its pool: two DISTINCT, non-confusable rules in RANDOM
# order, so a given rule shows up on the left side sometimes and on the right side other times.
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

func _next_round() -> void:
	_clear_boxes()

	if rounds_done >= rounds_before_hide and not labels_hidden:
		labels_hidden = true
		_hide_labels()

	active_box = rng.randi_range(0, 1)
	ground_truth = rng.randi_range(0, 1) == 1

	var left_mod: Dictionary = current_pair[0]
	var right_mod: Dictionary = current_pair[1]
	var relevant_mod: Dictionary = left_mod if active_box == 0 else right_mod
	var distractor_mod: Dictionary = right_mod if active_box == 0 else left_mod

	var relevant_item = relevant_mod["gen"].call(ground_truth)
	var distractor_item = distractor_mod["gen"].call(rng.randi_range(0, 1) == 1)

	var container: Control = %LeftItemsContainer if active_box == 0 else %RightItemsContainer
	var lbl_relevant: Label = relevant_mod["make"].call(relevant_item)
	var lbl_distractor: Label = distractor_mod["make"].call(distractor_item)
	if rng.randi_range(0, 1) == 0:
		_place_diagonal(container, lbl_relevant, lbl_distractor)
	else:
		_place_diagonal(container, lbl_distractor, lbl_relevant)

	round_start_ms = MainGlobals.timems()
	waiting_for_input = true

func _update_avg_label() -> void:
	if times_to_answer.is_empty():
		%AvgTimeLabel.text = "Average time : —"
	else:
		%AvgTimeLabel.text = "Average time : %d ms" % mean_response_time_ms()

func _clear_boxes() -> void:
	for child in %LeftItemsContainer.get_children():
		child.queue_free()
	for child in %RightItemsContainer.get_children():
		child.queue_free()
	%FeedbackLabel.modulate.a = 0.0

func _show_labels() -> void:
	%LeftRuleLabel.text = _u(current_pair[0]["label"])
	%RightRuleLabel.text = _u(current_pair[1]["label"])
	%LeftRuleLabel.modulate.a = 1.0
	%RightRuleLabel.modulate.a = 1.0

func _hide_labels() -> void:
	%LeftRuleLabel.modulate.a = 0.0
	%RightRuleLabel.modulate.a = 0.0

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left") or event.is_action_pressed("ui_left"):
		%WrongButton.modulate = Color(0.6, 0.6, 0.6)
		_evaluate_answer(false)
		await get_tree().create_timer(0.2).timeout
		%WrongButton.modulate = Color.WHITE
	elif event.is_action_pressed("right") or event.is_action_pressed("ui_right"):
		%CorrectButton.modulate = Color(0.6, 0.6, 0.6)
		_evaluate_answer(true)
		await get_tree().create_timer(0.2).timeout
		%CorrectButton.modulate = Color.WHITE

func _on_correct_pressed() -> void:
	_evaluate_answer(true)

func _on_wrong_pressed() -> void:
	_evaluate_answer(false)

func _evaluate_answer(user_says_correct: bool) -> void:
	if not waiting_for_input or game.paused() or game.level_is_done:
		return
	waiting_for_input = false

	var elapsed: int = MainGlobals.timems() - round_start_ms
	var is_right: bool = user_says_correct == ground_truth

	total_rounds += 1
	rounds_done += 1

	if is_right:
		total_corrects += 1
		times_to_answer.append(float(elapsed))
		while times_to_answer.size() > 20:
			times_to_answer.remove_at(0)
		var speed_bonus: int = max(0, 20 - elapsed / 100)
		game.add_score_and_time(10 + speed_bonus, 0)
		game.add_correct_or_mistake(1, 0)
		game.play_sound("correct")
		%FeedbackLabel.text = "✓"
		%FeedbackLabel.modulate = Color.GREEN
		_update_avg_label()
	else:
		var penalty: int = min(3, game.score)
		game.add_score_and_time(-penalty, 0)
		game.add_correct_or_mistake(0, 1)
		game.play_sound("wrong")
		%FeedbackLabel.text = "✗"
		%FeedbackLabel.modulate = Color.RED

	%FeedbackLabel.modulate.a = 1.0

	await get_tree().create_timer(0.5).timeout

	if game.level_is_done or game.paused():
		return

	if rounds_done >= num_rounds_per_level:
		_level_done()
	else:
		_next_round()

func _level_done() -> void:
	game.level_is_done = true
	RlmadnressG.record_level_result(current_level_id, pct_correct())
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
	return roundi(100.0 * total_corrects / total_rounds)

func tick() -> void:
	pass

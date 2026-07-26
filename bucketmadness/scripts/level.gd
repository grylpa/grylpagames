extends CanvasLayer

var game: GenericGameUtil
var current_level_id: int = 1

var rounds_before_hide: int = 6
var num_rounds_per_level: int = 10
var fall_duration: float = 2.5
var preview_time: float = 4.0

# category: 0=matches left rule, 1=matches right rule, 2=neither (dumpster)
# correct_bucket: 0=left, 1=center(dumpster), 2=right
var active_category: int = 0
var correct_bucket: int = 0

var fall_item_node: Control = null
var fall_tween: Tween = null
var item_answered: bool = false

var round_start_ms: float = 0.0
var labels_hidden: bool = false
var rounds_done: int = 0
var waiting_for_input: bool = false

var times_to_answer: Array = []
var total_rounds: int = 0
var total_corrects: int = 0

var current_pair: Array = []

# The pool of rule keys allowed for the CURRENT level (from level_config "rules"). The two shown
# rules are drawn from it at random each time the level loads, so which rules appear — and which
# bucket each one lands on — varies from play to play instead of always being the same two.
var _level_rules_pool: Array = []

# Rules whose items can ALSO be explained by another rule — never show both at once (e.g. a ■ is
# both a square AND a filled shape, so one item would belong in both buckets). Extend as other
# overlaps are found.
const _CONFUSABLE_WITH: Dictionary = {
	"square": ["filled", "hollow"],
	"filled": ["square"],
	"hollow": ["square"],
}

var _bucket_tex: Texture2D = preload("res://bucketmadness/art/bucket_open_2.png")
var _dumpster_tex: Texture2D = preload("res://bucketmadness/art/dumpster_half_open.png")

var _trap_poly: Polygon2D = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _primes: Array = [2, 3, 5, 7, 11, 13, 17, 19, 23]
var _non_primes: Array = [1, 4, 6, 8, 9, 10, 12, 14, 15, 16, 18, 20, 21, 22, 24, 25]
var _straight_letters: Array = ["A", "E", "F", "H", "I", "K", "L", "M", "N", "T", "V", "W", "X", "Y", "Z"]
var _curved_letters: Array = ["B", "C", "D", "G", "J", "O", "P", "Q", "R", "S", "U"]
var _color_names: Array = ["RED", "BLUE", "GREEN", "YELLOW", "PURPLE"]
var _color_values: Dictionary = {
	"RED": Color.RED, "BLUE": Color.BLUE, "GREEN": Color(0.0, 0.75, 0.0),
	"YELLOW": Color.YELLOW, "PURPLE": Color(0.6, 0.0, 0.9),
}

var item_font_size: int = 52
var pair_font_size: int = 36
var item_w: float = 140.0
var item_h: float = 88.0

var correct_audio = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var wrong_audio = preload("res://art/sounds/swoosh.mp3")

var _swipe_start: Vector2 = Vector2.ZERO
var _swipe_tracking: bool = false

signal sig_level_is_done(didwin: bool)
signal started_playing

func _ready() -> void:
	game = BucketMadnessG.game
	game.sig_time_over.connect(_on_time_over)
	game.add_sound(self, "correct", correct_audio)
	game.add_sound(self, "wrong", wrong_audio)
	var layout: MarginContainer = $MainLayout
	layout.offset_top = 100.0 if MainGlobals.is_mobile() else 150.0
	layout.offset_bottom = -(MainGlobals.footer_height + 15.0)
	if MainGlobals.is_mobile():
		item_font_size = 68
		pair_font_size = 48
		item_w = 180.0
		item_h = 110.0
		%LeftRuleLabel.add_theme_font_size_override("font_size", 26)
		%RightRuleLabel.add_theme_font_size_override("font_size", 26)
		%DumpsterLabel.add_theme_font_size_override("font_size", 26)
		%AvgTimeLabel.add_theme_font_size_override("font_size", 36)
	var f: Font = MainGlobals.get_system_sans_font()
	%LeftRuleLabel.add_theme_font_override("font", f)
	%RightRuleLabel.add_theme_font_override("font", f)
	%DumpsterLabel.add_theme_font_override("font", f)
	%AvgTimeLabel.add_theme_font_override("font", f)
	%FeedbackLabel.add_theme_font_override("font", f)
	%FallArea.clip_contents = true
	_trap_poly = Polygon2D.new()
	_trap_poly.color = Color(0.0, 0.08, 0.0, 0.85)
	%FallArea.add_child(_trap_poly)
	%FallArea.move_child(_trap_poly, 0)
	%FallArea.resized.connect(_update_trapezoid)
	call_deferred("_update_trapezoid")
	_setup_bucket_images()
	set_process(true)

func _update_trapezoid() -> void:
	if _trap_poly == null or not is_instance_valid(_trap_poly):
		return
	var sz: Vector2 = %FallArea.size
	if sz.x < 10.0 or sz.y < 10.0:
		return
	var w: float = sz.x
	var h: float = sz.y
	var top_inset: float = maxf((w - item_w - 20.0) * 0.5, 10.0)
	_trap_poly.polygon = PackedVector2Array([
		Vector2(top_inset, 0.0),
		Vector2(w - top_inset, 0.0),
		Vector2(w, h),
		Vector2(0.0, h)
	])

func _process(_delta: float) -> void:
	if fall_tween == null:
		return
	if game.paused():
		fall_tween.pause()
	else:
		fall_tween.play()

func _setup_bucket_images() -> void:
	var sides: Array = [
		$MainLayout/VBox/ContentVBox/BucketsRow/LeftBucketSide,
		$MainLayout/VBox/ContentVBox/BucketsRow/CenterBucketSide,
		$MainLayout/VBox/ContentVBox/BucketsRow/RightBucketSide
	]
	var textures: Array = [_bucket_tex, _dumpster_tex, _bucket_tex]
	var min_heights: Array = [125, 160, 125]
	for i in 3:
		var _tr: TextureRect = TextureRect.new()
		_tr.texture = textures[i]
		_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tr.custom_minimum_size = Vector2(0, min_heights[i])
		sides[i].add_child(_tr)
		sides[i].move_child(_tr, 0)

# --- Modality building (same as rlmadness) ---

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
			return {"key": key, "label": "Shape is\nblue or red?",
				"gen": func(ok): return _gen_colored_shape(ok),
				"make": func(item): return _make_colored_shape(item)}
		"lines":
			return {"key": key, "label": "Letter is\nstraight lines?",
				"gen": func(ok): return _gen_straight_letter(ok),
				"make": func(item): return _make_text(item)}
	return {}

func _u(text: String) -> String:
	return text.to_upper() if BucketMadnessG.use_uppercase else text

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
	lbl.add_theme_font_size_override("font_size", item_font_size)
	lbl.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

func _make_stroop(item: Dictionary) -> Label:
	var lbl: Label = Label.new()
	lbl.text = _u(item["text"])
	lbl.add_theme_font_size_override("font_size", 44)
	lbl.add_theme_color_override("font_color", item["color"])
	lbl.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

func _make_colored_shape(item: Dictionary) -> Label:
	var lbl: Label = Label.new()
	lbl.text = item["shape"]
	lbl.add_theme_font_size_override("font_size", item_font_size)
	lbl.add_theme_font_override("font", MainGlobals.get_system_sans_font())
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.modulate = item["color"]
	return lbl

func _make_pair_control(item_a: Variant, mod_a: Dictionary, item_b: Variant, mod_b: Dictionary) -> Control:
	var c: Control = Control.new()
	var half_w: float = item_w * 0.5
	var lbl_a: Label = mod_a["make"].call(item_a)
	lbl_a.add_theme_font_size_override("font_size", pair_font_size)
	lbl_a.size = Vector2(half_w, item_h)
	lbl_a.position = Vector2(0.0, 0.0)
	var lbl_b: Label = mod_b["make"].call(item_b)
	lbl_b.add_theme_font_size_override("font_size", pair_font_size)
	lbl_b.size = Vector2(half_w, item_h)
	lbl_b.position = Vector2(half_w, 0.0)
	c.add_child(lbl_a)
	c.add_child(lbl_b)
	return c

# --- Game flow ---

func new_game(from_scratch: bool = true) -> void:
	game.level_is_done = false
	times_to_answer.clear()
	if from_scratch:
		total_rounds = 0
		total_corrects = 0
		BucketMadnessG.reset_queue_from(BucketMadnessG.starting_level_id)
	game.need_to_increase_level = false
	current_level_id = BucketMadnessG.pop_next_level_id()
	_load_level(current_level_id)
	rounds_done = 0
	labels_hidden = false
	waiting_for_input = false
	item_answered = false
	_show_labels()
	_update_avg_label()
	_clear_fall_area()
	game.level_is_ready = true
	started_playing.emit()
	await get_tree().process_frame
	await _run_preview()
	_next_round()

func _run_preview() -> void:
	var secs: int = roundi(preview_time)
	for i in secs:
		%AvgTimeLabel.text = "Starting in %d..." % (secs - i)
		await get_tree().create_timer(1.0).timeout
		if game.level_is_done or game.paused():
			break
	%AvgTimeLabel.text = "Average time : —"

func _load_level(id: int) -> void:
	var def: Dictionary = BucketMadnessLevelConfig.get_level(id)
	rounds_before_hide = def.get("hide_after", 5)
	num_rounds_per_level = def.get("rounds", 10)
	fall_duration = def.get("fall_duration", 2.5)
	preview_time = float(def.get("preview", 4))
	_level_rules_pool = def.get("rules", ["digit", "square"]).duplicate()
	_pick_pair_from_pool()
	game.level_label_changed("Level " + str(def.get("name", id)))

# True if the two rule keys can be confused (an item could satisfy both), so they must never be
# the two shown rules at once.
func _are_confusable(a: String, b: String) -> bool:
	return _CONFUSABLE_WITH.get(a, []).has(b) or _CONFUSABLE_WITH.get(b, []).has(a)

# Pick this level's two shown rules from its pool: two DISTINCT, non-confusable rules in RANDOM
# order, so a given rule shows up on the left bucket sometimes and on the right bucket other times.
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

func _clear_fall_area() -> void:
	for child in %FallArea.get_children():
		if child != _trap_poly:
			child.queue_free()
	fall_item_node = null
	if fall_tween != null:
		fall_tween.kill()
		fall_tween = null
	%FeedbackLabel.modulate.a = 0.0

func _next_round() -> void:
	if game.level_is_done or game.paused():
		return

	if rounds_done >= rounds_before_hide and not labels_hidden:
		labels_hidden = true
		_hide_labels()

	_clear_fall_area()
	item_answered = false

	var fall_area: Control = %FallArea
	var h: float = max(fall_area.size.y, 280.0)
	var w: float = max(fall_area.size.x, 300.0)

	# Pick category: 0=matches left rule, 1=matches right rule, 2=neither (dumpster)
	active_category = rng.randi_range(0, 2)
	correct_bucket = [0, 2, 1][active_category]

	# Generate two objects with cross-rule constraint: only one can match one rule
	var item_a: Variant
	var item_b: Variant
	var mod_a: Dictionary
	var mod_b: Dictionary
	if active_category == 0:
		item_a = current_pair[0]["gen"].call(true)
		item_b = current_pair[1]["gen"].call(false)
		mod_a = current_pair[0]
		mod_b = current_pair[1]
	elif active_category == 1:
		item_a = current_pair[1]["gen"].call(true)
		item_b = current_pair[0]["gen"].call(false)
		mod_a = current_pair[1]
		mod_b = current_pair[0]
	else:
		item_a = current_pair[0]["gen"].call(false)
		item_b = current_pair[1]["gen"].call(false)
		mod_a = current_pair[0]
		mod_b = current_pair[1]

	# Shuffle display order so matching object isn't always on same side
	if rng.randi_range(0, 1) == 1:
		var tmp_item: Variant = item_a
		var tmp_mod: Dictionary = mod_a
		item_a = item_b
		mod_a = mod_b
		item_b = tmp_item
		mod_b = tmp_mod

	fall_item_node = _make_pair_control(item_a, mod_a, item_b, mod_b)
	fall_item_node.custom_minimum_size = Vector2(item_w, item_h)
	fall_item_node.size = Vector2(item_w, item_h)
	fall_item_node.position = Vector2((w - item_w) * 0.5, -(item_h + 10.0))
	fall_area.add_child(fall_item_node)

	fall_tween = create_tween()
	fall_tween.tween_property(fall_item_node, "position:y", h - item_h - 30.0, fall_duration)
	fall_tween.tween_callback(_on_fall_reached_bottom)

	round_start_ms = game.game_time
	waiting_for_input = true

func _on_fall_reached_bottom() -> void:
	fall_tween = null  # prevent _process from restarting it
	if not item_answered:
		_evaluate_answer(1)  # timeout → dumpster (center)

func _evaluate_answer(bucket: int) -> void:
	if not waiting_for_input or game.level_is_done or item_answered:
		return
	waiting_for_input = false
	item_answered = true

	if fall_tween != null:
		fall_tween.kill()
		fall_tween = null

	var elapsed: int = int(game.game_time - round_start_ms)
	var is_right: bool = bucket == correct_bucket

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

	# Animate item to selected bucket
	if fall_item_node != null and is_instance_valid(fall_item_node):
		var fall_area: Control = %FallArea
		var h: float = max(fall_area.size.y, 280.0)
		var w: float = max(fall_area.size.x, 300.0)
		var fracs: Array = [0.1, 0.5, 0.9]
		var target_x: float = w * fracs[bucket] - item_w * 0.5
		var slide_tween: Tween = create_tween().set_parallel(true)
		slide_tween.tween_property(fall_item_node, "position:x", target_x, 0.3)
		slide_tween.tween_property(fall_item_node, "position:y", h + 20.0, 0.35)

	await get_tree().create_timer(0.7).timeout
	%FeedbackLabel.modulate.a = 0.0

	if game.level_is_done:
		return
	# If a "return to menu?" dialog was open and the player said no, wait until unpaused
	while game.paused():
		await get_tree().process_frame
	if game.level_is_done:
		return

	if rounds_done >= num_rounds_per_level:
		_level_done()
		return

	_next_round()

func _update_avg_label() -> void:
	if times_to_answer.is_empty():
		%AvgTimeLabel.text = "Average time : —"
	else:
		%AvgTimeLabel.text = "Average time : %d ms" % mean_response_time_ms()

func _show_labels() -> void:
	if current_pair.size() >= 2:
		%LeftRuleLabel.text = _u(current_pair[0].get("label", ""))
		%RightRuleLabel.text = _u(current_pair[1].get("label", ""))
	%LeftRuleLabel.modulate.a = 1.0
	%RightRuleLabel.modulate.a = 1.0

func _hide_labels() -> void:
	%LeftRuleLabel.modulate.a = 0.0
	%RightRuleLabel.modulate.a = 0.0

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe_start = event.position
			_swipe_tracking = true
		else:
			_swipe_tracking = false
	elif event is InputEventScreenDrag and _swipe_tracking:
		var delta: Vector2 = event.position - _swipe_start
		if delta.length() > 60.0:
			_swipe_tracking = false
			MainGlobals.swipe_was_drag = true
			if abs(delta.x) >= abs(delta.y) * 1.2:
				_evaluate_answer(0 if delta.x < 0.0 else 2)  # left or right bucket
			else:
				_evaluate_answer(1)  # down swipe = dumpster
	if event.is_action_pressed("left") or event.is_action_pressed("ui_left"):
		_evaluate_answer(0)
	elif event.is_action_pressed("right") or event.is_action_pressed("ui_right"):
		_evaluate_answer(2)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_accept"):
		_evaluate_answer(1)

func _level_done() -> void:
	game.level_is_done = true
	BucketMadnessG.record_level_result(current_level_id, pct_correct())
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

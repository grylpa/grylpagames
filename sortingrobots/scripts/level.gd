extends CanvasLayer

var game: GenericGameUtil
var current_level_id: int = 1

# Level-defined
var rounds_before_hide: int = 6
var num_rounds_per_level: int = 10
var window_duration: float = 2.5
var scroll_speed: float = 75.0

# Scoring / progress
var labels_hidden: bool = false
var rounds_done: int = 0
var total_rounds: int = 0
var total_corrects: int = 0
var times_to_answer: Array = []
var round_start_ms: float = 0.0
var _showing_feedback: bool = false

var current_pair: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Endless conveyor
var pair_font_size: int = 32
var item_h: float = 72.0
const ITEM_SPACING: float = 95.0

var belt_items: Array = [[], []]  # each entry: {ctrl, truth_l, truth_r}
var belt_initialized: bool = false

# Window (highlight box that enters and exits from top/bottom with its item)
var window_panel: Panel = null
var window_belt: int = -1
var window_open: bool = false        # accepting input
var window_rolling_out: bool = false # answered/timed-out but still scrolling to exit
var window_target_item: Control = null
var window_target_truth: bool = false
var window_timer: float = 0.0
var next_window_timer: float = 2.0

var _swipe_start: Vector2 = Vector2.ZERO
var _swipe_tracking: bool = false

var _primes: Array = [2, 3, 5, 7, 11, 13, 17, 19, 23]
var _non_primes: Array = [1, 4, 6, 8, 9, 10, 12, 14, 15, 16, 18, 20, 21, 22, 24, 25]
var _straight_letters: Array = ["A", "E", "F", "H", "I", "K", "L", "M", "N", "T", "V", "W", "X", "Y", "Z"]
var _curved_letters: Array = ["B", "C", "D", "G", "J", "O", "P", "Q", "R", "S", "U"]
var _color_names: Array = ["RED", "BLUE", "GREEN", "YELLOW", "PURPLE"]
var _color_values: Dictionary = {
	"RED": Color.RED, "BLUE": Color.BLUE, "GREEN": Color(0.0, 0.75, 0.0),
	"YELLOW": Color.YELLOW, "PURPLE": Color(0.6, 0.0, 0.9),
}

var correct_audio = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var wrong_audio = preload("res://art/sounds/swoosh.mp3")

signal sig_level_is_done(didwin: bool)
signal started_playing

func _ready() -> void:
	game = SortingRobotsG.game
	game.sig_time_over.connect(_on_time_over)
	game.add_sound(self, "correct", correct_audio)
	game.add_sound(self, "wrong", wrong_audio)
	var layout: MarginContainer = $MainLayout
	layout.offset_top = 100.0 if MainGlobals.is_mobile() else 150.0
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
	%LeftRuleLabel.add_theme_font_override("font", f)
	%RightRuleLabel.add_theme_font_override("font", f)
	%AvgTimeLabel.add_theme_font_override("font", f)
	%FeedbackLabel.add_theme_font_override("font", f)
	# Fix both rule labels to a 2-line height so a 1-line and a 2-line rule
	# occupy the same space (bottom-aligned), keeping the two belts aligned.
	var rule_fs: int = 32 if MainGlobals.is_mobile() else 22
	var two_line_h: float = f.get_height(rule_fs) * 2.0 + 12.0
	%LeftRuleLabel.custom_minimum_size = Vector2(0, two_line_h)
	%RightRuleLabel.custom_minimum_size = Vector2(0, two_line_h)
	%LeftRuleLabel.add_theme_constant_override("line_spacing", -8)
	%RightRuleLabel.add_theme_constant_override("line_spacing", -8)
	%LeftItemsContainer.clip_contents = true
	%RightItemsContainer.clip_contents = true
	_add_belt_edges()
	set_process(false)

func _add_belt_edges() -> void:
	var edge_script: Script = load("res://sortingrobots/scripts/belt_edge.gd")
	var boxes: Array = [
		$MainLayout/VBox/ContentVBox/BoxesRow/LeftSide/LeftBox,
		$MainLayout/VBox/ContentVBox/BoxesRow/RightSide/RightBox,
	]
	for box in boxes:
		# Zero the panel's content margins so children fill the full belt rect — the
		# edge strips then span the full belt width and meet the belt with no overlap.
		var sb: StyleBox = box.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			var sbf: StyleBoxFlat = sb as StyleBoxFlat
			sbf.content_margin_left = 0.0
			sbf.content_margin_top = 0.0
			sbf.content_margin_right = 0.0
			sbf.content_margin_bottom = 0.0
		var edge: Control = Control.new()
		edge.set_script(edge_script)
		box.add_child(edge)

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
			return {"key": key, "label": "Shape is\nblue or red?",
				"gen": func(ok): return _gen_colored_shape(ok),
				"make": func(item): return _make_colored_shape(item)}
		"lines":
			return {"key": key, "label": "Letter is\nonly straight lines?",
				"gen": func(ok): return _gen_straight_letter(ok),
				"make": func(item): return _make_text(item)}
	return {}

func _u(text: String) -> String:
	return text.to_upper() if SortingRobotsG.use_uppercase else text

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

func _containers() -> Array:
	return [%LeftItemsContainer, %RightItemsContainer]

# --- Endless conveyor ---

func _process(delta: float) -> void:
	if game.paused() or game.level_is_done:
		return
	if not belt_initialized:
		_init_belts()
		return
	_scroll_belts(delta)
	if window_open and not _showing_feedback:
		if window_target_item != null and is_instance_valid(window_target_item):
			var h: float = _containers()[window_belt].size.y
			var item_y: float = window_target_item.position.y
			if item_y >= h:
				# Item scrolled off while window still open — instant timeout
				window_open = false
				_discard_window()
				_score_answer(false, true)
			else:
				if window_panel != null and is_instance_valid(window_panel):
					window_panel.position.y = item_y - 4.0
	elif window_rolling_out:
		_update_rolling_window()
	elif not window_open and not _showing_feedback and not window_rolling_out:
		next_window_timer -= delta
		if next_window_timer <= 0.0 and rounds_done < num_rounds_per_level:
			_open_window()

func _scroll_belts(delta: float) -> void:
	for si in 2:
		var container: Control = _containers()[si]
		var h: float = container.size.y
		var bw: float = container.size.x
		if h <= 0.0 or bw <= 0.0:
			continue
		var items: Array = belt_items[si]
		for entry in items:
			entry["ctrl"].position.y += scroll_speed * delta
		# Remove items that scrolled off the bottom
		var i: int = items.size() - 1
		while i >= 0:
			if items[i]["ctrl"].position.y >= h:
				items[i]["ctrl"].queue_free()
				items.remove_at(i)
			i -= 1
		# Find topmost item; add new items above with random spacing
		var top_y: float = h
		for entry in items:
			if entry["ctrl"].position.y < top_y:
				top_y = entry["ctrl"].position.y
		while top_y > -item_h:
			top_y -= rng.randf_range(80.0, 130.0)
			items.append(_spawn_belt_item(si, top_y, bw))

func _init_belts() -> void:
	for si in 2:
		var container: Control = _containers()[si]
		var h: float = container.size.y
		var bw: float = container.size.x
		if h <= 0.0 or bw <= 0.0:
			return
		# Right belt starts with a vertical offset so the two belts are never aligned
		var y: float = -item_h if si == 0 else -item_h - rng.randf_range(40.0, 75.0)
		while y < h + item_h:
			belt_items[si].append(_spawn_belt_item(si, y, bw))
			y += rng.randf_range(80.0, 130.0)
	belt_initialized = true

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

func _open_window() -> void:
	var si: int = rng.randi_range(0, 1)
	var container: Control = _containers()[si]
	var h: float = container.size.y
	var bw: float = container.size.x
	# Only pick items that are still ABOVE the viewport (position.y < 0).
	# This ensures the window always enters from the top with its item.
	var target_y: float = -item_h * 0.5
	var best_entry: Variant = null
	var best_dist: float = INF
	for entry in belt_items[si]:
		var item_y: float = entry["ctrl"].position.y
		if item_y >= 0.0:
			continue  # already visible — skip, would just appear without entering
		if item_y < -item_h * 4.0:
			continue  # too far above, would wait too long
		var dist: float = abs(item_y - target_y)
		if dist < best_dist:
			best_dist = dist
			best_entry = entry
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
	sb.bg_color = Color(1.0, 1.0, 0.0, 0.18)
	sb.set_border_width_all(3)
	sb.border_color = Color(1.0, 0.9, 0.0, 1.0)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	panel.size = Vector2(bw, item_h + pad * 2.0)
	# Position exactly with the item — clip_contents hides it while above the container
	panel.position = Vector2(0.0, window_target_item.position.y - pad)
	container.add_child(panel)
	window_panel = panel
	window_open = true
	window_timer = window_duration
	round_start_ms = game.game_time

func _discard_window() -> void:
	window_open = false
	window_rolling_out = false
	if window_panel != null and is_instance_valid(window_panel):
		window_panel.queue_free()
		window_panel = null
	window_belt = -1
	window_target_item = null

func _update_rolling_window() -> void:
	if window_target_item == null or not is_instance_valid(window_target_item):
		# Item was freed (scrolled off via belt scroll) — score as timeout
		_discard_window()
		_score_answer(false, true)
		return
	if window_panel == null or not is_instance_valid(window_panel):
		window_rolling_out = false
		window_target_item = null
		window_belt = -1
		return
	var h: float = _containers()[window_belt].size.y
	var item_y: float = window_target_item.position.y
	if item_y >= h:
		# Window has fully exited — score the timeout now
		_discard_window()
		_score_answer(false, true)
		return
	window_panel.position.y = item_y - 4.0

func _clear_belts() -> void:
	for si in 2:
		for entry in belt_items[si]:
			if entry["ctrl"] != null and is_instance_valid(entry["ctrl"]):
				entry["ctrl"].queue_free()
		belt_items[si] = []
	if window_panel != null and is_instance_valid(window_panel):
		window_panel.queue_free()
		window_panel = null
	window_belt = -1
	window_open = false
	window_rolling_out = false
	window_target_item = null

# --- Game flow ---

func new_game(from_scratch: bool = true) -> void:
	game.level_is_done = false
	times_to_answer.clear()
	if from_scratch:
		total_rounds = 0
		total_corrects = 0
		SortingRobotsG.reset_queue_from(SortingRobotsG.starting_level_id)
	game.need_to_increase_level = false
	current_level_id = SortingRobotsG.pop_next_level_id()
	_load_level(current_level_id)
	rounds_done = 0
	labels_hidden = false
	_showing_feedback = false
	window_open = false
	window_rolling_out = false
	window_belt = -1
	next_window_timer = 2.0
	belt_initialized = false
	_clear_belts()
	_show_labels()
	_update_avg_label()
	%FeedbackLabel.modulate.a = 0.0
	game.level_is_ready = true
	started_playing.emit()
	set_process(true)

func _load_level(id: int) -> void:
	var def: Dictionary = SortingRobotsLevelDefs.get_level(id)
	rounds_before_hide = def.get("hide_after", 5)
	num_rounds_per_level = def.get("rounds", 12)
	window_duration = float(def.get("window_dur", 2.5))
	scroll_speed = float(def.get("belt_spd", 75))
	current_pair = [
		_build_modality(def.get("left", "digit")),
		_build_modality(def.get("right", "square"))
	]
	game.level_label_changed("Level " + str(def.get("name", id)))

func _evaluate_answer(user_picks_up: bool) -> void:
	if not window_open or _showing_feedback or game.paused() or game.level_is_done:
		return
	window_open = false
	_discard_window()  # remove immediately when player answers
	_score_answer(user_picks_up, false)

func _score_answer(user_picks_up: bool, is_timeout: bool) -> void:
	if _showing_feedback or game.level_is_done:
		return
	_showing_feedback = true
	var elapsed: int = int(game.game_time - round_start_ms)
	var is_right: bool = not is_timeout and (user_picks_up == window_target_truth)
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
	if rounds_done >= rounds_before_hide and not labels_hidden:
		labels_hidden = true
		_hide_labels()
	await get_tree().create_timer(0.4).timeout
	%FeedbackLabel.modulate.a = 0.0
	_showing_feedback = false
	if game.level_is_done or game.paused():
		return
	if rounds_done >= num_rounds_per_level:
		_level_done()
		return
	next_window_timer = rng.randf_range(1.2, 2.5)

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
			if abs(delta.x) >= abs(delta.y):
				_evaluate_answer(delta.x > 0.0)
	if event.is_action_pressed("right") or event.is_action_pressed("ui_right"):
		_evaluate_answer(true)
	elif event.is_action_pressed("left") or event.is_action_pressed("ui_left"):
		_evaluate_answer(false)

func _level_done() -> void:
	set_process(false)
	game.level_is_done = true
	SortingRobotsG.record_level_result(current_level_id, pct_correct())
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

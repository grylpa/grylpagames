extends CanvasLayer

var game: GenericGameUtil

var level: int = 1
var max_difficulty: int = MovingCardsLevelConfig.LEVELS.size()
var num_cards: int = 2
var rounds_done_this_level: int = 0
var rounds_correct_this_level: int = 0
var _score_at_level_start: int = 0
var _rollback_score_on_next_level: bool = false
var current_level_cfg: Dictionary = {}

var expected_card_idx_clicked: int = 0
var card_to_move: int = 0
var can_start_clicking: bool = false
var in_card_moving_mode: bool = false
var _round_id: int = 0
var score_if_successful: int = 5
var card_click_order: Array = []
var cards: Array = []
var move_order: Array = []

# The shared HUD's top strip: score and the correct/wrong counters at y 0..60, and the per-round
# instruction line ("ORDER: 3,1,2") below them at y 65..115. A card's top edge starts at
# TOP_MARGIN + pad - CARD_SIZE/2, so this clears the line with a 21px gap.
const TOP_MARGIN: float = 130.0
const BOTTOM_MARGIN: float = 80.0
const CARD_SIZE: float = 80.0
const MIN_TRAVEL_DIST: float = 180.0

@export var card_scene: PackedScene = load("res://movingcards/scenes/card.tscn")

var ambient_audios: Array = [
	preload("res://art/sounds/ocean-waves-2.mp3"),
	preload("res://art/sounds/ocean-waves-3.mp3"),
	preload("res://art/sounds/ocean-waves-4.mp3"),
]

signal sig_can_start_clicking
# passed, the accuracy that decided it, and the bonus a pass is worth.
signal sig_level_is_done(passed: bool, pct: int, bonus: int)
signal sig_message(text: String, autohide: bool)
signal update_score(score: int)

func _ready() -> void:
	game = MovingCardsG.game
	MovingCardsG.init_globals()
	level = MovingCardsG.starting_level

func new_game(from_scratch: bool = true) -> void:
	show()
	if from_scratch:
		level = MovingCardsG.starting_level
		rounds_done_this_level = 0
	_load_level_cfg()
	if from_scratch:
		rounds_correct_this_level = 0
	game.corrects = 0
	game.mistakes = 0
	_score_at_level_start = game.score
	_start_round()
	ambient_audios.shuffle()
	# Registered fresh each time: the list is shuffled, so which track "ambient" refers to changes
	# from game to game. add_sound() updates the stream of a name it already knows.
	game.add_sound(self, "ambient", ambient_audios[0], true)
	game.play_sound("ambient")

func _load_level_cfg() -> void:
	var idx: int = clamp(level - 1, 0, MovingCardsLevelConfig.LEVELS.size() - 1)
	current_level_cfg = MovingCardsLevelConfig.LEVELS[idx]
	num_cards = int(current_level_cfg["num_cards"])
	MovingCardsG.card_move_speed = 200.0 * float(current_level_cfg["speed_scale"])
	score_if_successful = 5 + 2 * level

func _start_round() -> void:
	_round_id += 1
	expected_card_idx_clicked = 0
	card_to_move = 0
	can_start_clicking = false
	in_card_moving_mode = false
	create_board()
	var display_sec: float = float(int(current_level_cfg["display_time_ms"])) / 1000.0
	if bool(current_level_cfg["random_order"]):
		sig_message.emit("ORDER: " + (",".join(card_click_order.map(str))), false)
	else:
		sig_message.emit("Remember the cards", false)
	$ShowCardsTimer.wait_time = display_sec
	$ShowCardsTimer.start()

func _input(event: InputEvent) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if event.is_action_pressed("mainmenu"):
		game.stop_sound("ambient")
	elif event.is_action_pressed("clue"):
		show_clue()

func _process(delta: float) -> void:
	if in_card_moving_mode:
		var c = find_card(move_order[card_to_move])
		if c != null:
			c.z_index = 1
			if !c.move_card(delta):
				c.z_index = 0
				card_to_move += 1
				if card_to_move >= num_cards:
					enter_start_clicking_mode()
		else:
			enter_start_clicking_mode()

func enter_start_clicking_mode() -> void:
	in_card_moving_mode = false
	can_start_clicking = true
	sig_message.emit("", false)
	# if bool(current_level_cfg["random_order"]):
	# 	sig_message.emit("ORDER: " + (",".join(card_click_order.map(str))), true)
	# else:
	# 	sig_message.emit("Click in order", true)
	sig_can_start_clicking.emit()

# ---- Fixed position arrays (board-coordinate units, indexed by num_cards - 2) ----

var _start_positions_stationary: Array = [
	[Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	[Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(0, 0)],
	[Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(-0.5, 0), Vector2(0.5, 0)],
	[Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(0, 0), Vector2(0, -2), Vector2(0, 2)],
	[Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)],
	[Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, 0)],
]

var _start_positions_moving: Array = [
	[Vector2(-2, -1), Vector2(2, 1)],
	[Vector2(-2, -1), Vector2(1, -2), Vector2(2, 1)],
	[Vector2(-2, -1), Vector2(1, -2), Vector2(-1, 2), Vector2(2, 1)],
	[Vector2(-2, -1), Vector2(1, -2), Vector2(0, 0), Vector2(-1, 2), Vector2(2, 1)],
	[Vector2(-2, -1), Vector2(1, -2), Vector2(-1, 2), Vector2(2, 1), Vector2(-0.5, 0), Vector2(0.5, 0)],
	[Vector2(-2, -1), Vector2(1, -2), Vector2(-1, 2), Vector2(2, 1), Vector2(0, 0), Vector2(0, -2), Vector2(0, 2)],
	[Vector2(-2, -1), Vector2(1, -2), Vector2(-1, 2), Vector2(2, 1), Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)],
	[Vector2(-2, -1), Vector2(1, -2), Vector2(-1, 2), Vector2(2, 1), Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, 0)],
]

var _end_positions_moving: Array = [
	[Vector2(1, -1), Vector2(-1, 1)],
	[Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)],
	[Vector2(1, -1), Vector2(1, 1), Vector2(-1, -1), Vector2(-1, 1)],
	[Vector2(1, -1), Vector2(1, 1), Vector2(1, 0), Vector2(-1, -1), Vector2(-1, 1)],
	[Vector2(1, -1), Vector2(1, 1), Vector2(-1, -1), Vector2(-1, 1), Vector2(1.5, 0), Vector2(-1.5, 0)],
	[Vector2(1, -1), Vector2(1, 1), Vector2(-1, -1), Vector2(-1, 1), Vector2(1, 0), Vector2(0, 1), Vector2(0, -1)],
	[Vector2(1, -1), Vector2(1, 1), Vector2(-1, -1), Vector2(-1, 1), Vector2(0, 2), Vector2(0, -2), Vector2(2, 0), Vector2(-2, 0)],
	[Vector2(1, -1), Vector2(1, 1), Vector2(-1, -1), Vector2(-1, 1), Vector2(0, 2), Vector2(0, -2), Vector2(2, 0), Vector2(-2, 0), Vector2(0, 0)],
]

# ---- Board creation ----

func create_board() -> void:
	while !cards.is_empty():
		cards.pop_back().queue_free()

	var moving: bool = bool(current_level_cfg["moving_cards"])
	var use_random_style: bool = current_level_cfg["movement_style"] == "random"

	if bool(current_level_cfg["random_order"]):
		card_click_order = range(1, 10)
		card_click_order.shuffle()
		card_click_order = card_click_order.slice(0, num_cards)
	else:
		card_click_order = range(1, num_cards + 1)

	var area_size: Vector2 = MainGlobals.screen_size
	var start_pxs: Array = []
	var end_pxs: Array = []

	if use_random_style:
		start_pxs = _gen_random_positions(num_cards, area_size)
		if not start_pxs.is_empty():
			end_pxs = _gen_end_positions_for(start_pxs, area_size)
			if not end_pxs.is_empty():
				end_pxs = _optimize_crossings(start_pxs, end_pxs)
		if start_pxs.is_empty() or end_pxs.is_empty():
			use_random_style = false  # fall back to fixed

	if not use_random_style:
		var arr_idx: int = clamp(num_cards - 2, 0, _start_positions_moving.size() - 1)
		if moving:
			for bp in _start_positions_moving[arr_idx]:
				start_pxs.append(MovingCardsG.board_to_px(bp))
			for bp in _end_positions_moving[arr_idx]:
				end_pxs.append(MovingCardsG.board_to_px(bp))
		else:
			for bp in _start_positions_stationary[arr_idx]:
				var px: Vector2 = MovingCardsG.board_to_px(bp)
				start_pxs.append(px)
				end_pxs.append(px)

	var count: int = min(num_cards, start_pxs.size())
	var indices: Array = range(0, count)
	indices.shuffle()
	for i in range(count):
		add_card_at(start_pxs[indices[i]], end_pxs[indices[i]], card_click_order[i], moving)

	if moving:
		move_order = card_click_order.duplicate()
		move_order.shuffle()

func _gen_random_positions(count: int, area_size: Vector2) -> Array:
	var result: Array = []
	var pad: float = CARD_SIZE / 2.0 + 6.0
	var min_sep: float = CARD_SIZE + 32.0
	var x_min: float = pad
	var x_max: float = area_size.x - pad
	var y_min: float = TOP_MARGIN + pad
	var y_max: float = area_size.y - BOTTOM_MARGIN - pad
	if x_max <= x_min or y_max <= y_min:
		return result
	for _i in range(count):
		var placed: bool = false
		for _attempt in range(300):
			var pos: Vector2 = Vector2(randf_range(x_min, x_max), randf_range(y_min, y_max))
			var ok: bool = true
			for existing in result:
				if pos.distance_to(existing) < min_sep:
					ok = false
					break
			if ok:
				result.append(pos)
				placed = true
				break
		if not placed:
			result.clear()
			return result
	return result

# Generate end positions paired with starts: each end is >= MIN_TRAVEL_DIST from its own start
# and does not overlap any other end position or any start position
func _gen_end_positions_for(starts: Array, area_size: Vector2) -> Array:
	var ends: Array = []
	var pad: float = CARD_SIZE / 2.0 + 6.0
	var min_sep: float = CARD_SIZE + 32.0
	var x_min: float = pad
	var x_max: float = area_size.x - pad
	var y_min: float = TOP_MARGIN + pad
	var y_max: float = area_size.y - BOTTOM_MARGIN - pad
	if x_max <= x_min or y_max <= y_min:
		return []
	for i in range(starts.size()):
		var placed: bool = false
		for _attempt in range(500):
			var pos: Vector2 = Vector2(randf_range(x_min, x_max), randf_range(y_min, y_max))
			if pos.distance_to(starts[i]) < MIN_TRAVEL_DIST:
				continue
			var ok: bool = true
			for existing in ends:
				if pos.distance_to(existing) < min_sep:
					ok = false
					break
			if ok:
				for s in starts:
					if pos.distance_to(s) < min_sep:
						ok = false
						break
			if ok:
				ends.append(pos)
				placed = true
				break
		if not placed:
			return []
	return ends

# Greedily swap end positions between pairs to maximize path crossings.
# Only swaps when travel distance, end-end separation, and end-start separation are all met.
func _optimize_crossings(starts: Array, ends: Array) -> Array:
	var min_sep: float = CARD_SIZE + 32.0
	var best_ends: Array = ends.duplicate()
	var improved: bool = true
	while improved:
		improved = false
		for i in range(starts.size()):
			for j in range(i + 1, starts.size()):
				var ei: Vector2 = best_ends[i]
				var ej: Vector2 = best_ends[j]
				# Reject if travel distance not met after swap
				if starts[i].distance_to(ej) < MIN_TRAVEL_DIST:
					continue
				if starts[j].distance_to(ei) < MIN_TRAVEL_DIST:
					continue
				# Reject if swapped ends would overlap any start
				var sep_ok: bool = true
				for k in range(starts.size()):
					if k != i and ej.distance_to(starts[k]) < min_sep:
						sep_ok = false
						break
					if k != j and ei.distance_to(starts[k]) < min_sep:
						sep_ok = false
						break
				if not sep_ok:
					continue
				var before: int = _count_crossings(starts, best_ends)
				best_ends[i] = ej
				best_ends[j] = ei
				if _count_crossings(starts, best_ends) <= before:
					best_ends[i] = ei
					best_ends[j] = ej
				else:
					improved = true
	return best_ends

func _count_crossings(starts: Array, ends: Array) -> int:
	var count: int = 0
	for i in range(starts.size()):
		for j in range(i + 1, starts.size()):
			if _segments_cross(starts[i], ends[i], starts[j], ends[j]):
				count += 1
	return count

func _segments_cross(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> bool:
	var d: Vector2 = a2 - a1
	var e: Vector2 = b2 - b1
	var denom: float = d.cross(e)
	if abs(denom) < 0.001:
		return false
	var f: Vector2 = b1 - a1
	var t: float = f.cross(e) / denom
	var u: float = f.cross(d) / denom
	return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0

func add_card_at(start_px: Vector2, end_px: Vector2, card_id: int, will_move: bool) -> void:
	var card = card_scene.instantiate()
	var target: Vector2 = end_px if will_move else start_px
	card.set_id(card_id)
	add_child(card)
	cards.append(card)
	card.position = start_px
	card.begin_move(start_px, target, _bow_for(start_px, target))
	card.card_pressed.connect(_on_card_pressed)

# How far the arc bows, and which way. Proportional to the trip so a short hop is not a loop, and
# clamped so the deepest point of the arc still clears the header, the bottom bar and the sides —
# the placement code guarantees the ENDPOINTS are inside, and the bow is the only thing that can
# take a card outside them.
func _bow_for(from: Vector2, to: Vector2) -> float:
	var span: float = from.distance_to(to)
	if span < 1.0:
		return 0.0
	var amount: float = clampf(span * 0.13, 10.0, 40.0) * (1.0 if randf() < 0.5 else -1.0)
	var side: Vector2 = (to - from).normalized().orthogonal()
	var apex: Vector2 = from.lerp(to, 0.5) + side * amount
	var pad: float = CARD_SIZE / 2.0 + 4.0
	var area: Vector2 = MainGlobals.screen_size
	var room: Rect2 = Rect2(pad, TOP_MARGIN + pad,
		area.x - pad * 2.0, area.y - BOTTOM_MARGIN - TOP_MARGIN - pad * 2.0)
	if room.has_point(apex):
		return amount
	# bowing that way leaves the field; try the other side, and give up on a bow if it also does
	apex = from.lerp(to, 0.5) - side * amount
	return -amount if room.has_point(apex) else 0.0

func find_card(card_id: int):
	for c in cards:
		if c.id == card_id:
			return c
	return null

# Every round counts, won or lost. Getting it wrong used to just restart the round without
# counting it, so `num_rounds` measured successes and the level always ended in a win.
func _finish_round(was_correct: bool) -> void:
	rounds_done_this_level += 1
	if was_correct:
		rounds_correct_this_level += 1
	game.add_correct_or_mistake(1 if was_correct else 0, 0 if was_correct else 1)
	MainGlobals.global_update_hud()
	if rounds_done_this_level < int(current_level_cfg["num_rounds"]):
		_start_round()
		return
	game.playing = false
	can_start_clicking = false
	var pct: int = int(100.0 * float(rounds_correct_this_level) / float(rounds_done_this_level))
	var passed: bool = pct >= int(current_level_cfg.get("pass_pct", 66))
	MainGlobals.global_level_is_done(passed)
	sig_level_is_done.emit(passed, pct, score_if_successful)

# Called by main.gd once the player has closed the level card: the next level, or this one again.
func continue_after_level(passed: bool) -> void:
	if _rollback_score_on_next_level:
		_rollback_score_on_next_level = false
		game.score = _score_at_level_start
	rounds_done_this_level = 0
	rounds_correct_this_level = 0
	# The counters belong to the level being graded, so they start clean whether the next level is
	# the next one or this one again.
	game.corrects = 0
	game.mistakes = 0
	if passed:
		level = min(level + 1, max_difficulty)
	_load_level_cfg()
	_score_at_level_start = game.score
	MainGlobals.global_update_hud()
	_start_round()

func level_name() -> int:
	return level

func is_last_level() -> bool:
	return level >= max_difficulty

func mark_score_rollback() -> void:
	_rollback_score_on_next_level = true

func score_at_level_start() -> int:
	return _score_at_level_start

# ---- Input handling ----

func _on_card_pressed(_p: Vector2, _card_id: int) -> void:
	if !can_start_clicking:
		return
	game.play_sound("tap")
	var c = find_card(_card_id)
	if _card_id != card_click_order[expected_card_idx_clicked]:
		# Wrong card
		game.play_sound("wrong")
		if c != null:
			c.reveal_card()
			c.clicked(false)
		can_start_clicking = false
		game.playing = false
		for _c in cards:
			_c.reveal_card()
		sig_message.emit("Wrong!", false)
		var rid: int = _round_id
		await MainGlobals.sleep(1.5)
		if _round_id != rid or not is_visible():
			return
		_finish_round(false)
	else:
		# Correct card
		if c != null:
			c.reveal_card()
			if game.playing:
				c.clicked(true)
				update_score.emit(2)
		if _card_id == card_click_order[-1]:
			# All cards clicked correctly — enjoy for 2 seconds then loop/advance
			game.play_sound("correct")
			can_start_clicking = false
			game.playing = false
			for _c in cards:
				_c.reveal_card()
			await MainGlobals.sleep(2.0)
			if not is_visible():
				return
			_finish_round(true)
		else:
			expected_card_idx_clicked += 1
			var rid: int = _round_id
			await MainGlobals.sleep(0.7)
			if _round_id != rid:
				return
			for _c in cards:
				_c.hide_card()

func _on_show_cards_timer_timeout() -> void:
	for c in cards:
		c.hide_card()
	if bool(current_level_cfg["moving_cards"]):
		in_card_moving_mode = true
		var c = find_card(move_order[card_to_move])
		if c != null:
			c.z_index = 1
		# sig_message.emit("Concentrate", false)
	else:
		enter_start_clicking_mode()

func show_clue() -> void:
	if !can_start_clicking:
		return
	var c = find_card(card_click_order[expected_card_idx_clicked])
	if c != null:
		update_score.emit(-2)
		c.reveal_card()
		await MainGlobals.sleep(0.4)
		c.hide_card()

extends CanvasLayer

var game: GenericGameUtil

var level: int = 1
var max_difficulty: int = MovingCardsLevelConfig.LEVELS.size()
var num_cards: int = 2
var rounds_done_this_level: int = 0
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

const TOP_MARGIN: float = 120.0
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
signal sig_level_is_done(didwin: bool, score: int)
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
	_start_round()
	ambient_audios.shuffle()
	$AmbientAudio.stream = ambient_audios[0]
	ambient_audios[0].loop = true
	$AmbientAudio.play()

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
		$AmbientAudio.stop()
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
	card.end_pixel_pos = end_px if will_move else start_px
	card.set_id(card_id)
	add_child(card)
	cards.append(card)
	card.position = start_px
	card.card_pressed.connect(_on_card_pressed)

func find_card(card_id: int):
	for c in cards:
		if c.id == card_id:
			return c
	return null

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
		sig_message.emit("Wrong! Try again", false)
		var rid: int = _round_id
		await MainGlobals.sleep(1.5)
		if _round_id != rid or not is_visible():
			return
		_start_round()
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
			rounds_done_this_level += 1
			if rounds_done_this_level >= int(current_level_cfg["num_rounds"]):
				# Difficulty level complete
				rounds_done_this_level = 0
				if level >= max_difficulty:
					# Last level: loop silently, save score without game-over popup
					update_score.emit(score_if_successful)
					game.save_ongoing_score([])
				else:
					level = min(level + 1, max_difficulty)
					sig_level_is_done.emit(true, score_if_successful)
					MainGlobals.global_level_is_done(true)
					_load_level_cfg()
					sig_message.emit("Level %d!" % level, true)
			_start_round()
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

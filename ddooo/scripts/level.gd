extends CanvasLayer

var game: GenericGameUtil

class OneCell:
	var ispipe := false
	var agent = null
	var pipe

var max_difficulty := 8
var board: Array
var agents = []              # main question agents (model + alternatives)
var periph_dir_buttons: Array = []  # 8 direction Area2D buttons during periph question
var periph_flash_agent = null
var pipes = []               # main game pipe nodes
var agent_start_positions = []
var agent_start_directions = []
var level := 0

var agent_time_to_hide_model_ms := 2000
var agent_time_to_hide_alternatives_ms := 2500
var agent_time_to_show_alternatives_after_model := 500
var agent_time_to_show_model_after_alternatives := 500

var agent_model_color = null
var agent_model_texture_idx := 0
var agent_can_use_two_colors := 0
var agent_same_color_for_alts := 0
var agent_use_same_color_for_all := 0
var agent_use_same_shape_for_alternatives := 0
var num_alternatives := 2
var num_corrects_for_next_level := 5
var num_corrects_in_level_so_far := 0

var times_to_answer := []

# Peripheral mechanic
var periph_dir_idx: int = -1        # direction index 0-7; -1 = no flash this round
var periph_time_visible_ms := 800
var periph_question_time_limit_ms := 4000
var periph_question_active := false
var time_shown_periph_question_ms := 0.0
var periph_need_to_show_flash := false
var periph_time_to_show_flash_ms := 0.0
var pending_main_correct := false   # center was correct; awaiting periph resolution

# 8 directions: up, down, left, right, TL, TR, BL, BR
const DIR_POSITIONS: Array = [
	Vector2i(3, 0),  # 0: up
	Vector2i(3, 6),  # 1: down
	Vector2i(0, 3),  # 2: left
	Vector2i(6, 3),  # 3: right
	Vector2i(0, 0),  # 4: TL
	Vector2i(6, 0),  # 5: TR
	Vector2i(0, 6),  # 6: BL
	Vector2i(6, 6),  # 7: BR
]

@export var pipe_scene: PackedScene = load("res://ddooo/scenes/pipe.tscn")
@export var agent_scene: PackedScene = load("res://ddooo/scenes/agent.tscn")

var dispatch_audio := preload("res://art/sounds/kenney/Audio/impactBell_heavy_003.ogg")
var delivery_audio := preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var swoosh_audio := preload("res://art/sounds/swoosh.mp3")

var ambient_audios := [
	preload("res://art/sounds/ocean-waves-2.mp3"),
	preload("res://art/sounds/ocean-waves-3.mp3"),
	preload("res://art/sounds/ocean-waves-4.mp3")
]

signal started_playing
signal sig_level_is_done(didwin: bool)
signal sig_periph_active(active: bool)

func _ready() -> void:
	game = DdoooG.game
	game.sig_time_over.connect(on_time_over)
	level = DdoooG.starting_level
	increase_difficulty(false)
	game.add_sound(self, "dispatch", dispatch_audio)
	game.add_sound(self, "delivery", delivery_audio)
	game.add_sound(self, "swoosh", swoosh_audio)
	if not MainGlobals.sig_game_popup_closed.is_connected(_on_game_popup_closed):
		MainGlobals.sig_game_popup_closed.connect(_on_game_popup_closed)

func _on_game_popup_closed() -> void:
	if not game.level_is_done and not game.level_is_ready:
		game.level_is_ready = true
		need_to_show_model = true
		time_to_show_model_ms = game.game_time + 500
		started_playing.emit()

func new_game(from_scratch = true):
	sig_periph_active.emit(false)
	game.level_is_ready = false
	if from_scratch:
		level = DdoooG.starting_level
	increase_difficulty(game.need_to_increase_level)
	game.need_to_increase_level = false
	game.level_label_changed("Level %d" % level)
	pos_last_dispatch = Vector2i(-1, -1)
	create_board()
	ambient_audios.shuffle()
	game.add_sound(self, "ambient", ambient_audios[0], true)
	game.play_sound("ambient")
	# Show level-start info popup; game begins when user dismisses it
	var lvl: Dictionary = DdoooLevelConfig.get_level(level)
	game.show_game_popup(self, "Level %d" % level,
		"Center visible: %d ms\nPeriphery flash: %d ms" % [lvl["center_ms"], lvl["periph_ms"]])

func use_b12(b):
	return b == 1 or (b == 2 and game.rng.randi() % 2 == 0)

func add_pipe(p):
	board[p.y][p.x].ispipe = true
	var pipe = pipe_scene.instantiate()
	board[p.y][p.x].pipe = pipe
	pipe.board_pos = p
	pipe.position = game.board_to_px(p)
	add_child(pipe)
	pipes.append(pipe)
	pipe.pipe_pressed.connect(_on_pipe_pressed)

func add_agent_pos_dir(p):
	var q = p
	var dir := 0
	if p.x == 0: q.x += 1
	if p.x == game.board_size.x - 1:
		q.x -= 1
		dir = 2
	if p.y == 0:
		q.y += 1
		dir = 1
	if p.y == game.board_size.y - 1:
		q.y -= 1
		dir = 3
	agent_start_positions.append(q)
	agent_start_directions.append(dir)
	return q

var model_pos := Vector2i(3, 3)

func create_board() -> void:
	board.clear()
	for _row_index in game.board_size.y:
		var row: Array[OneCell]
		row.resize(game.board_size.x)
		for col_index in game.board_size.x:
			row[col_index] = OneCell.new()
		board.append(row)
	for c in pipes:
		c.queue_free()
	for c in agents:
		c.queue_free()
	for c in periph_dir_buttons:
		if is_instance_valid(c):
			c.queue_free()
	if periph_flash_agent != null and is_instance_valid(periph_flash_agent):
		periph_flash_agent.queue_free()
		periph_flash_agent = null
	pipes.clear()
	agents.clear()
	periph_dir_buttons.clear()
	periph_question_active = false
	periph_need_to_show_flash = false
	periph_dir_idx = -1
	pending_main_correct = false
	agent_start_positions = []
	agent_start_directions = []

	if num_alternatives == 2:
		model_pos = Vector2i(3, 3)
		add_agent_pos_dir(Vector2i(2, 3))
		add_agent_pos_dir(Vector2i(4, 3))
		add_pipe(model_pos)
		for a in agent_start_positions:
			add_pipe(a)
	elif num_alternatives == 3:
		model_pos = Vector2i(3, 3)
		add_agent_pos_dir(Vector2i(1, 3))
		add_agent_pos_dir(Vector2i(3, 3))
		add_agent_pos_dir(Vector2i(5, 3))
		add_pipe(model_pos)
		for a in agent_start_positions:
			if a != model_pos:
				add_pipe(a)
	elif num_alternatives == 4:
		model_pos = Vector2i(3, 3)
		add_agent_pos_dir(Vector2i(1, 3))
		add_agent_pos_dir(Vector2i(2, 3))
		add_agent_pos_dir(Vector2i(4, 3))
		add_agent_pos_dir(Vector2i(5, 3))
		add_pipe(model_pos)
		for a in agent_start_positions:
			add_pipe(a)
	for pipe_node in pipes:
		if pipe_node.board_pos != model_pos:
			pipe_node.hide()

	need_to_show_model = true
	time_to_show_model_ms = game.game_time + agent_time_to_show_model_after_alternatives
	num_corrects_in_level_so_far = 0
	create_camera(min(6.0, 1.0 / game.get_board_part_of_width()))
	# game.level_is_ready is set in _on_game_popup_closed, not here

var next_agent_id := 1
var use_same_shape = false
var use_same_color = false
var pos_last_dispatch = Vector2i(-1, -1)

func _add_main_agent(p: Vector2i, direction: int, color, is_model = false, is_correct = false):
	var agent = agent_scene.instantiate()
	if is_model:
		agent.agent_textures.shuffle()
		use_same_shape = use_b12(agent_use_same_shape_for_alternatives)
		use_same_color = use_b12(agent_use_same_color_for_all)
		if use_same_color and use_same_shape:
			var selector = game.rng.randi() % 2 == 0
			use_same_color = use_same_color and selector
			use_same_shape = use_same_shape and (not selector)
	agent.time_to_hide_ms = agent_time_to_hide_model_ms if is_model else agent_time_to_hide_alternatives_ms
	agent.is_model = is_model
	agent.is_correct = is_correct
	agent.id = next_agent_id
	next_agent_id += 1
	agent.board_pos = p
	add_child(agent)
	agent.agent_pressed.connect(on_main_agent_pressed)
	agent.need_to_remove_agent.connect(on_main_agent_removed)
	board[p.y][p.x].agent = agent
	agents.append(agent)
	var cell_pipe = board[p.y][p.x].pipe
	if cell_pipe != null and is_instance_valid(cell_pipe):
		cell_pipe.show()
	agent.set_pos(game.board_to_px(p), direction)
	agent.set_colors(color)
	return agent

func _get_color_for_agent(use_two_colors):
	if use_two_colors:
		return [game.next_color(), game.next_color()]
	else:
		var c = game.next_color()
		return [c, c]

func _dispatch_new_main_agent(is_model = false, is_correct = false):
	if game.paused():
		return
	var p
	var dir
	var got_p = false
	var shuffled_idx = range(0, agent_start_positions.size())
	var forced_color = null
	var skip_color = null
	var forced_texture_idx = -1
	var use_two_colors = use_b12(agent_can_use_two_colors)
	if not is_model:
		if is_correct:
			forced_color = agent_model_color.duplicate(true)
			forced_texture_idx = agent_model_texture_idx
		elif agent_same_color_for_alts:
			# Same colors as model, shape guaranteed different by set_rand_texture
			forced_color = agent_model_color.duplicate(true)
		else:
			if use_same_shape:
				forced_texture_idx = agent_model_texture_idx
			if use_same_color:
				forced_color = agent_model_color.duplicate(true)
			else:
				skip_color = agent_model_color.duplicate(true)
	shuffled_idx.shuffle()
	for idx in shuffled_idx:
		if is_model:
			p = model_pos
			dir = 0
		else:
			p = agent_start_positions[idx]
			dir = agent_start_directions[idx]
			if board[p.y][p.x].agent != null:
				continue
		got_p = true
		var color = forced_color.duplicate(true) if forced_color != null else _get_color_for_agent(use_two_colors)
		while color == skip_color:
			color = _get_color_for_agent(use_two_colors)
		var agent = _add_main_agent(p, dir, color, is_model, is_correct)
		if is_model:
			agent_model_color = color.duplicate(true)
			agent_model_texture_idx = agent.set_rand_texture()
			game.play_sound("dispatch")
			periph_need_to_show_flash = true
			periph_time_to_show_flash_ms = game.game_time + 150
			for pipe_node in pipes:
				if is_instance_valid(pipe_node) and pipe_node.board_pos != model_pos:
					pipe_node.hide()
		else:
			if forced_texture_idx >= 0:
				agent.set_texture(forced_texture_idx)
			else:
				agent.set_rand_texture(agent_model_texture_idx)
		break
	if got_p:
		pos_last_dispatch = p

func _dispatch_periph_flash() -> void:
	periph_dir_idx = game.rng.randi() % 8
	var edge_px: Vector2 = game.board_to_px(DIR_POSITIONS[periph_dir_idx])
	var center_px: Vector2 = game.board_to_px(game.get_board_center())
	var t: float = game.rng.randf_range(0.8, 1.0)
	var flash_px: Vector2 = center_px.lerp(edge_px, t)
	# Peripheral flash is always single-color
	var c = game.next_color()
	var color = [c, c]
	var agent = agent_scene.instantiate()
	agent.time_to_hide_ms = periph_time_visible_ms
	agent.is_model = false
	agent.is_correct = false
	agent.id = -999
	agent.board_pos = DIR_POSITIONS[periph_dir_idx]
	add_child(agent)
	agent.set_pos(flash_px, 0)
	agent.set_colors(color)
	agent.set_rand_texture()
	agent.scale *= 0.55
	agent.need_to_remove_agent.connect(func(_a):
		if is_instance_valid(_a):
			_a.queue_free()
		periph_flash_agent = null
	)
	periph_flash_agent = agent

func _dispatch_periph_question() -> void:
	for p in pipes:
		p.hide()
	for dir_idx in 8:
		periph_dir_buttons.append(_create_dir_button(dir_idx))

func _create_dir_button(dir_idx: int) -> Area2D:
	var center_px: Vector2 = game.board_to_px(game.get_board_center())
	var edge_px: Vector2 = game.board_to_px(DIR_POSITIONS[dir_idx])
	var px: Vector2 = center_px.lerp(edge_px, 0.7)
	var area: Area2D = Area2D.new()
	area.position = px
	area.z_index = 20

	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = float(game.tile_size) * 0.5
	shape.shape = circle
	area.add_child(shape)

	# Small dot to mark the tap target
	var bg: Polygon2D = Polygon2D.new()
	bg.color = Color(0.9, 0.85, 0.2, 0.9)
	var pts: PackedVector2Array = PackedVector2Array()
	var r: float = float(game.tile_size) * 0.35
	for i in 12:
		var angle: float = 2.0 * PI * i / 12.0
		pts.append(Vector2(cos(angle), sin(angle)) * r)
	bg.polygon = pts
	area.add_child(bg)

	area.input_event.connect(func(_v, ev, _si):
		if ev.is_action_pressed("lclick"):
			_on_dir_button_pressed(dir_idx)
	)
	add_child(area)
	return area

func _on_dir_button_pressed(dir_idx: int) -> void:
	if not periph_question_active or game.paused() or game.level_is_done:
		return
	var is_correct: bool = (dir_idx == periph_dir_idx)
	if is_correct:
		game.play_sound("delivery")
	else:
		game.play_sound("swoosh")
	_flash_at(DIR_POSITIONS[dir_idx], is_correct)
	_show_score_popup(DIR_POSITIONS[dir_idx], "+1" if is_correct else "-1", is_correct)
	_finish_periph_question(is_correct, false)

var need_to_show_alternatives := false
var time_to_show_alternatives_ms := 0.0
var need_to_show_model := false
var time_to_show_model_ms := 0.0
var time_shown_alternatives_ms := 0.0

func _process(_delta: float) -> void:
	if not game.paused() and not game.level_is_done and game.level_is_ready:
		if need_to_show_alternatives and game.game_time > time_to_show_alternatives_ms:
			need_to_show_alternatives = false
			_dispatch_new_main_agent(false, true)
			for _i in range(num_alternatives - 1):
				_dispatch_new_main_agent(false, false)
			time_shown_alternatives_ms = game.game_time
		if need_to_show_model and game.game_time > time_to_show_model_ms:
			need_to_show_model = false
			_dispatch_new_main_agent(true, false)
		if periph_need_to_show_flash and game.game_time > periph_time_to_show_flash_ms:
			periph_need_to_show_flash = false
			_dispatch_periph_flash()
		if periph_question_active and game.game_time > time_shown_periph_question_ms + periph_question_time_limit_ms:
			_finish_periph_question(false, true)

func on_main_agent_removed(agent):
	if agent.timed_out and not agent.is_model and agent.is_correct:
		game.add_score_and_time(-1, -5)
		game.play_sound("swoosh")
		game.add_correct_or_mistake(0, 1)
	for i in range(agents.size() - 1, -1, -1):
		if agents[i].id == agent.id:
			board[agents[i].board_pos.y][agents[i].board_pos.x].agent = null
			agents[i].queue_free()
			agents.remove_at(i)
			if agent.is_model:
				need_to_show_alternatives = true
				time_to_show_alternatives_ms = game.game_time + agent_time_to_show_alternatives_after_model
				var mp = board[model_pos.y][model_pos.x].pipe
				if mp != null and is_instance_valid(mp):
					mp.hide()
			break
	if agents.size() == 0 and not agent.is_model:
		_on_main_question_done()

func _on_main_question_done():
	if game.level_is_done:
		return
	for p in pipes:
		if is_instance_valid(p) and p.board_pos != model_pos:
			p.hide()
	if periph_dir_idx >= 0:
		periph_question_active = true
		time_shown_periph_question_ms = game.game_time
		sig_periph_active.emit(true)
		_dispatch_periph_question()
	else:
		if pending_main_correct:
			pending_main_correct = false
			game.add_correct_or_mistake(1, 0)
			num_corrects_in_level_so_far += 1
			if num_corrects_in_level_so_far >= num_corrects_for_next_level:
				level_is_done(true)
				return
		need_to_show_model = true
		time_to_show_model_ms = game.game_time + agent_time_to_show_model_after_alternatives

func on_main_agent_pressed(agent):
	if agent.is_model or game.paused():
		return
	if agent.is_correct:
		var time_since_shown = game.game_time - time_shown_alternatives_ms
		var score_to_add = max(1, int(10 - time_since_shown / 200))
		_add_time_to_answer_ms(time_since_shown)
		game.add_score_and_time(score_to_add, 15)
		game.play_sound("delivery")
		pending_main_correct = true
		_flash_at(agent.board_pos, true)
		_show_score_popup(agent.board_pos, "+" + str(score_to_add), true)
	else:
		game.add_score_and_time(-1, -5)
		game.add_correct_or_mistake(0, 1)
		game.play_sound("swoosh")
		_flash_at(agent.board_pos, false)
		_show_score_popup(agent.board_pos, "-1", false)
	var ntries := 0
	while agents.size() > 0 and ntries < 100:
		on_main_agent_removed(agents[0])
		ntries += 1

func _finish_periph_question(is_correct: bool, _timed_out: bool) -> void:
	if not periph_question_active:
		return
	periph_question_active = false
	sig_periph_active.emit(false)

	for c in periph_dir_buttons:
		if is_instance_valid(c):
			c.queue_free()
	periph_dir_buttons.clear()
	periph_dir_idx = -1

	# Restore model pipe for next round
	for p in pipes:
		if is_instance_valid(p):
			if p.board_pos == model_pos:
				p.show()
			else:
				p.hide()

	# Scoring: center wrong was already counted in on_main_agent_pressed.
	# Here we add: center correct (if pending) + periph correct/wrong.
	# Max 2 correct, max 2 wrong per round.
	var both_correct: bool = pending_main_correct and is_correct
	var corrects: int = (1 if pending_main_correct else 0) + (1 if is_correct else 0)
	var periph_wrongs: int = 0 if is_correct else 1
	pending_main_correct = false

	if not game.level_is_done:
		if is_correct:
			game.add_score_and_time(5, 10)
		else:
			game.add_score_and_time(-1, -5)
		game.add_correct_or_mistake(corrects, periph_wrongs)
		if both_correct:
			num_corrects_in_level_so_far += 1
			if num_corrects_in_level_so_far >= num_corrects_for_next_level:
				level_is_done(true)
				return
		need_to_show_model = true
		time_to_show_model_ms = game.game_time + agent_time_to_show_model_after_alternatives

func on_time_over():
	game.stop_sound("ambient")

func tick():
	if game.level_is_done or !game.level_is_ready or game.paused():
		return

func _on_level_done_popup_closed():
	sig_level_is_done.emit(true)

func level_is_done(didwin: bool):
	game.level_is_done = true
	game.sig_level_is_done.emit(didwin)
	game.stop_sound("ambient")
	if didwin:
		MainGlobals.global_level_is_done(true)
		if level >= max_difficulty:
			sig_level_is_done.emit(true)
		else:
			game.need_to_increase_level = true
			if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
				MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
			var textadd = "\n\nAverage time: %d ms" % mean_time_to_answer_ms()
			game.show_level_done_popup(self, "", "", level, textadd)
	else:
		sig_level_is_done.emit(didwin)

func increase_difficulty(increase = true):
	if game == null:
		return
	if increase:
		level += 1
	level = clamp(level, 1, DdoooLevelConfig.MAX_LEVEL)
	var lvl: Dictionary = DdoooLevelConfig.get_level(level)
	var s: int = 7
	game.max_board_size = Vector2i(s, s)
	game.forced_board_size = Vector2i(s, s)
	agent_time_to_hide_model_ms = lvl["center_ms"]
	agent_time_to_hide_alternatives_ms = 2500
	agent_time_to_show_alternatives_after_model = 500
	agent_time_to_show_model_after_alternatives = 500
	periph_time_visible_ms = lvl["periph_ms"]
	periph_question_time_limit_ms = 4000
	num_alternatives = lvl["num_alts"]
	agent_can_use_two_colors = 1 if lvl["two_colors"] else 0
	agent_same_color_for_alts = 1 if lvl["same_color_alts"] else 0
	agent_use_same_shape_for_alternatives = 2
	agent_use_same_color_for_all = 2
	num_corrects_for_next_level = lvl["rounds"]
	game.init_sizes()

const FEEDBACK_OK_TEXT_COLOR := Color(0.3, 1.0, 0.3)
const FEEDBACK_BAD_TEXT_COLOR := Color(1.0, 0.4, 0.4)

func _flash_at(board_pos: Vector2i, is_correct: bool) -> void:
	var rect = ColorRect.new()
	var col = Color(0.0, 0.9, 0.0, 0.55) if is_correct else Color(0.9, 0.0, 0.0, 0.55)
	rect.color = col
	var sz = float(game.tile_size) * 1.1
	rect.size = Vector2(sz, sz)
	rect.position = game.board_to_px(board_pos) - Vector2(sz * 0.5, sz * 0.5)
	rect.z_index = 5
	add_child(rect)
	var tween = create_tween()
	tween.tween_property(rect, "color:a", 0.0, 0.35)
	tween.tween_callback(rect.queue_free)

func _show_score_popup(board_pos: Vector2i, text: String, is_correct: bool) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", FEEDBACK_OK_TEXT_COLOR if is_correct else FEEDBACK_BAD_TEXT_COLOR)
	label.add_theme_font_size_override("font_size", 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(game.tile_size * 3, 0)
	var px = game.board_to_px(board_pos)
	label.position = px - Vector2(game.tile_size * 1.5, game.tile_size * 0.5)
	label.z_index = 10
	add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "position:y", px.y - game.tile_size * 2.5, 0.65)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.65)
	tween.tween_callback(label.queue_free)

func is_texture_used(tex_idx):
	for a in agents:
		if a.texture_idx == tex_idx:
			return true
	return false

func _is_cell_empty(_board_pos):
	var cell = board[_board_pos.y][_board_pos.x]
	var full = cell.agent != null or !cell.ispipe
	return not full

func _on_pipe_pressed(_board_pos):
	if !_is_cell_empty(_board_pos):
		return

func mean_time_to_answer_ms() -> int:
	var N = times_to_answer.size()
	if N == 0:
		return min(9999, 2 * agent_time_to_hide_alternatives_ms)
	var s := 0
	for t in times_to_answer:
		s += t
	return roundi(float(s) / N)

func _add_time_to_answer_ms(t_ms: int):
	if t_ms <= 0:
		return
	times_to_answer.append(t_ms)
	while times_to_answer.size() > 10:
		times_to_answer.remove_at(0)

var agent_cam = null

func create_camera(camscale):
	follow_viewport_enabled = true
	if agent_cam == null:
		agent_cam = Camera2D.new()
		add_child(agent_cam)
	agent_cam.make_current()
	agent_cam.zoom = Vector2(camscale, camscale)
	agent_cam.enabled = true
	agent_cam.set_anchor_mode(Camera2D.ANCHOR_MODE_DRAG_CENTER)
	agent_cam.set_offset(game.board_to_px(game.get_board_center()))

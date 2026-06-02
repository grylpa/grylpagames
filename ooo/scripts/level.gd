extends CanvasLayer

var game: GenericGameUtil

class OneCell:
	var ispipe := false
	var agent = null
	var pipe

var max_difficulty := 8	
var board: Array
var agents = []
var pipes = []
var agent_start_positions = []
var agent_start_directions = []
var time_increased_difficulty_ms = 0
var level := 0
var agent_time_to_hide_model_ms := 2000
var agent_time_to_hide_alternatives_ms := 2000
var agent_time_to_show_alternatives_after_model := 1000
var agent_time_to_show_model_after_alternatives := 1000

var agent_model_color = null
var agent_model_texture_idx := 0
var agent_can_use_two_colors := 0
var agent_use_same_color_for_all := 0
var agent_use_same_shape_for_alternatives := 0
var num_alternatives := 2
var num_corrects_for_next_level := 5
var num_corrects_in_level_so_far := 0

var times_to_answer := []

@export var pipe_scene: PackedScene = load("res://ooo/scenes/pipe.tscn")
@export var agent_scene: PackedScene = load("res://ooo/scenes/agent.tscn")

var dispatch_audio := preload("res://art/sounds/kenney/Audio/impactBell_heavy_003.ogg")
var delivery_audio := preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var swoosh_audio := preload("res://art/sounds/swoosh.mp3")

var ambient_audios := [ 
	preload("res://art/sounds/ocean-waves-2.mp3"), 
	preload("res://art/sounds/ocean-waves-3.mp3"), 
	preload("res://art/sounds/ocean-waves-4.mp3")
]

signal started_playing
signal sig_level_is_done(didwin:bool)

func _ready() -> void:
	game = OooG.game
	game.sig_time_over.connect(on_time_over)
	level = OooG.starting_level
	increase_difficulty(false)

	game.add_sound(self, "dispatch", dispatch_audio)
	game.add_sound(self, "delivery", delivery_audio)
	game.add_sound(self, "swoosh", swoosh_audio)

func new_game(from_scratch=true):
	game.level_is_ready = false
	if from_scratch:
		level = OooG.starting_level

	increase_difficulty(game.need_to_increase_level)
	game.need_to_increase_level = false
	game.level_label_changed("Level %d" % level)
	pos_last_dispatch = Vector2i(-1,-1)
	create_board()

	ambient_audios.shuffle()
	game.add_sound(self, "ambient", ambient_audios[0], true)
	game.play_sound("ambient")

	started_playing.emit()
	BE.upsert_game_state("OOO", 
		{"state":"new","starting_level": level})

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
	# add_pipe(q)
	return q

var model_pos := Vector2i(3,1)

func create_board() -> void:
	board.clear()
	for row_index in game.board_size.y:
		var row: Array[OneCell]
		row.resize(game.board_size.x)
		for col_index in game.board_size.x:
			row[col_index] = OneCell.new()
		board.append(row)
	for c in pipes:
		c.queue_free()
	for c in agents:
		c.queue_free()
	pipes.clear()
	agents.clear()

	agent_start_positions = []
	agent_start_directions = []

	if num_alternatives == 2:
		model_pos = Vector2i(3,2)
		add_agent_pos_dir(Vector2i(2,4))
		add_agent_pos_dir(Vector2i(4,4))
		add_pipe(model_pos)
		for a in agent_start_positions:
			add_pipe(a)
	elif num_alternatives == 3:
		model_pos = Vector2i(3,2)
		add_agent_pos_dir(Vector2i(1,4))
		add_agent_pos_dir(Vector2i(3,4))
		add_agent_pos_dir(Vector2i(5,4))
		add_pipe(model_pos)
		for a in agent_start_positions:
			add_pipe(a)
	elif num_alternatives == 4:
		model_pos = Vector2i(3,1)
		add_agent_pos_dir(Vector2i(2,3))
		add_agent_pos_dir(Vector2i(4,3))
		add_agent_pos_dir(Vector2i(2,5))
		add_agent_pos_dir(Vector2i(4,5))
		add_pipe(model_pos)
		for a in agent_start_positions:
			add_pipe(a)
					
	need_to_show_model = true
	time_to_show_model_ms = game.game_time + agent_time_to_show_model_after_alternatives
		
	num_corrects_in_level_so_far = 0
	create_camera(min(6.0, 1.0 / game.get_board_part_of_width()))
	game.level_is_ready = true


var next_agent_id := 1
func add_agent_at(p: Vector2i, direction: int, color, is_model = false, is_correct = false):
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
	agent.agent_pressed.connect(on_agent_pressed)	
	board[p.y][p.x].agent = agent
	agent.need_to_remove_agent.connect(on_agent_need_to_remove_agent)
	agents.append(agent)
	agent.set_pos(game.board_to_px(p), direction)
	agent.set_colors(color)
	return agent
			
var last_major_tick := 0.0
var last_one_sec_tick := 0.0

func tick():
	if game.level_is_done or !game.level_is_ready or game.paused():
		return
							
func _on_level_done_popup_closed():
	sig_level_is_done.emit(true)

func level_is_done(didwin: bool):	
	game.level_is_done = true
	game.sig_level_is_done.emit(didwin)
	game.stop_sound("ambient")
	BE.send_event("level_done", "OOO", {
		"level": level,
		"didwin": int(didwin),
	})
	if didwin:
		MainGlobals.global_level_is_done(true)
		if level >= max_difficulty:
			sig_level_is_done.emit(true)
		else:
			game.need_to_increase_level = true
			if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
				MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
			var textadd = "\n\nAverage time: %d ms" % mean_time_to_answer_ms()
			game.show_level_done_popup(self, "","", level, textadd)
	else:
		# MainGlobals.sleep(1.0)
		sig_level_is_done.emit(didwin)

func increase_difficulty(increase=true):
	if game == null:
		return
	if increase:
		level += 1
	level = clamp(level, 1, max_difficulty)
	var s = 7
	game.max_board_size = Vector2i(s,s)
	game.forced_board_size = Vector2i(s,s)
	agent_time_to_hide_model_ms = max(500, 1000 - (level - 1) * 250)
	agent_time_to_hide_alternatives_ms = max(1000, 2000 - (level - 1) * 500)
	agent_time_to_show_alternatives_after_model = 1000 + (level - 1) * 250
	match  level:
		1:	# one color, same shape, 2 alternatives
			agent_can_use_two_colors = 0
			agent_use_same_shape_for_alternatives = 1
			agent_use_same_color_for_all = 0
			num_alternatives = 2
			num_corrects_for_next_level = 5
		2:	# one color, different shapes, 2 alternatives, all same color
			agent_can_use_two_colors = 0
			agent_use_same_shape_for_alternatives = 0
			agent_use_same_color_for_all = 1
			num_alternatives = 2
			num_corrects_for_next_level = 10
		3:	# two colors, same shapes, 2 alternatives
			agent_can_use_two_colors = 1
			agent_use_same_shape_for_alternatives = 1
			agent_use_same_color_for_all = 0
			num_alternatives = 2
			num_corrects_for_next_level = 5
		4:	# one color, different shape, 3 alternatives, all same color
			agent_can_use_two_colors = 0
			agent_use_same_shape_for_alternatives = 0
			agent_use_same_color_for_all = 1
			num_alternatives = 3
			num_corrects_for_next_level = 20
		5:	# one color, same or different shapes, 3 alternatives, all same color or different colors
			agent_can_use_two_colors = 0
			agent_use_same_shape_for_alternatives = 2
			agent_use_same_color_for_all = 2
			num_alternatives = 3
			num_corrects_for_next_level = 20
		6:	# one color, same or different shapes, 4 alternatives, all same color or different colors
			agent_can_use_two_colors = 0
			agent_use_same_shape_for_alternatives = 2
			agent_use_same_color_for_all = 2
			num_alternatives = 4
			num_corrects_for_next_level = 20
		7:	# two colors, same shape, 4 alternatives, fast
			agent_can_use_two_colors = 1
			agent_use_same_shape_for_alternatives = 1
			agent_use_same_color_for_all = 2
			num_alternatives = 4
			num_corrects_for_next_level = 20
			agent_time_to_hide_model_ms = 250
		8:	# one color, same or different shapes, 4 alternatives, all same color or different colors
			agent_can_use_two_colors = 0
			agent_use_same_shape_for_alternatives = 2
			agent_use_same_color_for_all = 2
			num_alternatives = 4
			num_corrects_for_next_level = 500
		
	# if MainGlobals.is_mobile():
	# 	var bsh = 0
	# 	var bsv = 2
	# 	game.max_board_size += Vector2i(bsh,bsv)
	# 	game.forced_board_size += Vector2i(bsh, bsv)
	game.init_sizes()

func _get_color_for_agent(use_two_colors):
	if use_two_colors:
		return [game.next_color(), game.next_color()]		
	else:
		var c = game.next_color()
		return [c,c]

func is_texture_used(tex_idx):
	for a in agents:
		if a.texture_idx == tex_idx:
			return true
	return false

var use_same_shape = false
var use_same_color = false
var pos_last_dispatch = Vector2i(-1,-1)
func _dispatch_new_agent(is_model=false, is_correct=false):
	if !game.paused():
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
			if true:
				got_p = true
				var color = forced_color.duplicate(true) if forced_color != null else _get_color_for_agent(use_two_colors)
				while color == skip_color:
					color = _get_color_for_agent(use_two_colors)
				var agent = add_agent_at(p, dir, color, is_model, is_correct)
				if is_model:
					agent_model_color = color.duplicate(true)
					agent_model_texture_idx = agent.set_rand_texture()
					game.play_sound("dispatch")
				else:
					# if is_correct or use_b12(agent_use_same_shape_for_alternatives):
					# 	agent.set_texture(agent_model_texture_idx)
					if forced_texture_idx >= 0:
						agent.set_texture(forced_texture_idx)
					else:
						agent.set_rand_texture(agent_model_texture_idx)
				break
		if got_p:
			pos_last_dispatch = p

var need_to_show_alternatives := false
var time_to_show_alternatives_ms := 0.0

var need_to_show_model := false
var time_to_show_model_ms := 0.0

var time_shown_alternatives_ms := 0.0

func _process(_delta: float) -> void:
	if not game.paused() and not game.level_is_done and game.level_is_ready:
		if need_to_show_alternatives and game.game_time > time_to_show_alternatives_ms:
			need_to_show_alternatives = false
			_dispatch_new_agent(false, true)
			for i in range(num_alternatives - 1):
				_dispatch_new_agent(false, false)
			time_shown_alternatives_ms = game.game_time
		if need_to_show_model and game.game_time > time_to_show_model_ms:
			need_to_show_model = false
			_dispatch_new_agent(true, false)
			
func on_agent_need_to_remove_agent(agent):	
	if agent.timed_out and not agent.is_model and agent.is_correct:
		game.add_score_and_time(-1,-5)
		game.play_sound("swoosh")
		game.add_correct_or_mistake(0,1)
	for i in range(agents.size() - 1, -1, -1):
		if agents[i].id == agent.id:
			board[agents[i].board_pos.y][agents[i].board_pos.x].agent = null
			agents[i].queue_free()
			agents.remove_at(i)
			if agent.is_model:				
				# agent_model_color = agent.color.duplicate(true)
				need_to_show_alternatives = true
				time_to_show_alternatives_ms = game.game_time + agent_time_to_show_alternatives_after_model
			break
	if agents.size() == 0:
		if not agent.is_model:
			need_to_show_model = true
			time_to_show_model_ms = game.game_time + agent_time_to_show_model_after_alternatives

func on_agent_pressed(agent):
	if !agent.is_model and !game.paused():
		if agent.is_correct:
			var time_since_shown_alternatives_ms = game.game_time - time_shown_alternatives_ms
			var score_to_add = max(1, int(10 - time_since_shown_alternatives_ms / 200))
			_add_time_to_answer_ms(time_since_shown_alternatives_ms)
			game.add_score_and_time(score_to_add,15)
			game.add_correct_or_mistake(1,0)
			num_corrects_in_level_so_far += 1
			game.play_sound("delivery")
			if num_corrects_in_level_so_far >= num_corrects_for_next_level:
				level_is_done(true)
		else:
			game.add_score_and_time(-1,-5)
			game.add_correct_or_mistake(0,1)
			game.play_sound("swoosh")
		var ntries := 0
		while agents.size() > 0 and ntries < 100:
			on_agent_need_to_remove_agent(agents[0])
			ntries += 1

func on_time_over():
	game.stop_sound("ambient")

var agent_cam = null

func create_camera(camscale):
	follow_viewport_enabled = true
	if agent_cam == null:
		agent_cam = Camera2D.new()
		add_child(agent_cam)
	agent_cam.make_current()
	agent_cam.zoom = Vector2(camscale,camscale)
	agent_cam.enabled = true
	agent_cam.set_anchor_mode(Camera2D.ANCHOR_MODE_DRAG_CENTER)
	agent_cam.set_offset(game.board_to_px(game.get_board_center()))
	
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
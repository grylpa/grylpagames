extends CanvasLayer

var game: GenericGameUtil

class OneCell:
	var ispipe: bool = false
	var agent = null
	var pipe

var max_difficulty: int = 8	
var board: Array
var agents = []
var pipes = []
var empties = []
var agent_start_positions = []
var agent_start_directions = []
var time_increased_difficulty_ms = 0
var level: int = 0
var agent_time_to_hide_model_ms: int = 2000
var agent_time_to_hide_alternatives_ms: int = 2000
var agent_time_to_show_alternatives_after_model: int = 1000
var agent_time_to_show_model_after_alternatives: int = 1000

var agent_model_color = null
var agent_model_texture_idx: int = 0
var agent_can_use_two_colors: int = 0
var agent_use_same_color_for_all: int = 0
var agent_use_same_shape_for_alternatives: int = 0
var num_alternatives: int = 2
var num_corrects_for_next_level: int = 5

# --- tutorial staging (all inert outside tutorial_mode) ---------------------
# Whether the board on screen was built FOR a tutorial. Captured at board-creation time: a level
# can be completed after the coach has finished, when tutorial_mode has already gone false.
var _tutorial_board: bool = false
# Freezes the board for a lesson: nothing times out, and no new model or lineup is dispatched.
# The tutorial's ACTION steps run unpaused, so game_time alone does not protect them.
var tutorial_hold_board: bool = false
var num_corrects_in_level_so_far: int = 0

var times_to_answer: Array = []

@export var pipe_scene: PackedScene = load("res://pop/scenes/pipe.tscn")
@export var empty_scene: PackedScene = load("res://pop/scenes/empty_space.tscn")
@export var agent_scene: PackedScene = load("res://pop/scenes/agent.tscn")

var dispatch_audio = preload("res://art/sounds/kenney/Audio/impactBell_heavy_003.ogg")
var delivery_audio = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var swoosh_audio = preload("res://art/sounds/swoosh.mp3")

var ambient_audios = [ 
	preload("res://art/sounds/ocean-waves-2.mp3"), 
	preload("res://art/sounds/ocean-waves-3.mp3"), 
	preload("res://art/sounds/ocean-waves-4.mp3")
]

signal started_playing
signal sig_level_is_done(didwin:bool)

# What the score was when this level began. A level that misses the gate gives its points
# back (see the level-done function): without that, failing forever is a way to earn forever
# — every attempt banked its points and the retry cost nothing.
var _score_at_level_start: int = 0
var _rollback_score_on_next_level: bool = false

func _ready() -> void:
	game = PopG.game
	game.sig_time_over.connect(on_time_over)
	level = PopG.starting_level
	increase_difficulty(false)

	game.add_sound(self, "dispatch", dispatch_audio)
	game.add_sound(self, "delivery", delivery_audio)
	game.add_sound(self, "swoosh", swoosh_audio)
	_fit_ground_to_board()

func new_game(from_scratch=true):
	# The failed level's points go back HERE, on Continue, together with everything else that is
	# cleared — so the summary card was still read against the score the player had while playing.
	if _rollback_score_on_next_level:
		_rollback_score_on_next_level = false
		game.score = _score_at_level_start
	_score_at_level_start = game.score
	# A replay has to be a FRESH attempt. The gate reads these, so a retry that inherited the
	# misses which failed the level could not pass it even played perfectly; and the summary's
	# timing average would fold in the attempt the player is being made to redo.
	game.corrects = 0
	game.mistakes = 0
	times_to_answer.clear()
	_tutorial_board = game.tutorial_mode
	game.level_is_ready = false
	if from_scratch:
		level = PopG.starting_level

	increase_difficulty(game.need_to_increase_level)
	game.need_to_increase_level = false
	game.level_label_changed("Level %d" % level)
	pos_last_dispatch = Vector2i(-1,-1)
	create_board()

	ambient_audios.shuffle()
	game.add_sound(self, "ambient", ambient_audios[0], true)
	game.play_sound("ambient")

	started_playing.emit()
	BE.upsert_game_state("Pop", 
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

func add_empty(p):
	var e = empty_scene.instantiate()
	e.board_pos = p
	e.position = game.board_to_px(p)
	add_child(e)
	empties.append(e)
	
func show_hide_walls():
	for e in empties:
		e.show_hide_walls(board)

func add_agent_pos_dir(p):
	var q = p
	var dir: int = 0
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

func dist_to_agent_positions(p:Vector2):
	var min_d: float = 10000.0
	for ap in agent_start_positions:
		min_d = min(min_d,p.distance_to(ap))
	return min_d

func create_board() -> void:
	_fit_ground_to_board()
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
	for c in empties:
		c.queue_free()
	pipes.clear()
	empties.clear()
	agents.clear()

	agent_start_positions = []
	agent_start_directions = []

	var target_rows = range(2,game.board_size.y-1,2)
	var target_cols = range(2,game.board_size.x-1,2)
	for row in target_rows:
		add_agent_pos_dir(Vector2i(0,row))
		add_agent_pos_dir(Vector2i(game.board_size.x-1,row))
	for col in target_cols:
		add_agent_pos_dir(Vector2i(col,0))
		add_agent_pos_dir(Vector2i(col,game.board_size.y-1))

	# for a in agent_start_positions:
	# 	add_pipe(a)
	for row in range(1,game.board_size.y-1):
		for col in range(1,game.board_size.x-1):
			# add_pipe(Vector2i(col,row))
			if (row % 2 == 0 or col % 2 == 0) and dist_to_agent_positions(Vector2i(col,row)) < 1.5:
				add_pipe(Vector2i(col,row))
			# if row % 2 == 0 or col % 2 == 0 or (row > 2 and col > 2 and 
			# 	row < game.board_size.y-2 and col < game.board_size.x-2):
					# add_pipe(Vector2i(col,row))
	
	for row in game.board_size.y:
		for col in game.board_size.x:
			if !board[row][col].ispipe:
				add_empty(Vector2i(col,row))

	show_hide_walls()
				
	for pipe in pipes:
		pipe.set_rot(board)

	need_to_show_model = true
	time_to_show_model_ms = game.game_time + agent_time_to_show_model_after_alternatives
	
	num_corrects_in_level_so_far = 0
	create_camera(min(2.0, 1.0 / game.get_board_part_of_width()))
	game.level_is_ready = true


var next_agent_id: int = 1
func add_agent_at(p: Vector2i, direction: int, color, is_model = false, is_correct = false):
	var agent = agent_scene.instantiate()
	if is_model:
		agent.agent_textures.shuffle()
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
	game.tutorial_notify("model_shown" if is_model else "candidate_shown")   # no-op outside a tutorial
	return agent
			
var last_major_tick: float = 0.0
var last_one_sec_tick: float = 0.0

func tick():
	if game.level_is_done or !game.level_is_ready or game.paused():
		return
							
func _on_level_done_popup_closed():
	sig_level_is_done.emit(true)

func level_is_done(didwin: bool):
	if game.tutorial_mode or _tutorial_board:
		# A level-done popup landing on the coach's closing caption is the failure mmm taught us to
		# guard against; _tutorial_board keeps it holding once tutorial_mode has gone false.
		return	
	game.level_is_done = true
	# The gate is decided BEFORE the level's score row is written: main.gd saves that row on
	# game.sig_level_is_done, and it has to carry the score the player actually KEEPS, or
	# failing the same level over and over is a way to farm the score list.
	#
	# Passing is a RESULT, not a formality: below this level's accuracy the SAME level comes
	# round again. The bar rises with the level, from 60% to at most 80%.
	var need: int = mini(60 + 5 * (level - 1), 80)
	var pct: int = game.session_pct_correct()
	var passed: bool = true
	if didwin and level < max_difficulty:
		passed = pct >= need
		_rollback_score_on_next_level = not passed
	if passed:
		game.sig_level_is_done.emit(didwin)
	else:
		# The kept value is put in place just for the save. The SCREEN keeps showing the score
		# the player had while playing, because watching it drop out from under a summary you
		# are still reading is alarming; the visible rollback lands on Continue, in new_game().
		var earned_this_level: int = game.score
		game.score = _score_at_level_start
		game.sig_level_is_done.emit(didwin)
		game.score = earned_this_level
	game.stop_sound("ambient")
	BE.send_event("level_done", "Pop", {
		"level": level,
		"didwin": int(didwin),
	})
	if didwin:
		# No fanfare for a level that was not passed.
		MainGlobals.global_level_is_done(passed)
		if level >= max_difficulty:
			sig_level_is_done.emit(true)
		else:
			game.need_to_increase_level = passed
			if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
				MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
			var textadd = "\n\nAverage time: %d ms\nAccuracy: %d%%\n\n%s" % [mean_time_to_answer_ms(), pct, _progress_line(passed, need)]
			game.show_level_done_popup(self, "", "", level, textadd, passed)
	else:
		# MainGlobals.sleep(1.0)
		sig_level_is_done.emit(didwin)

func increase_difficulty(increase=true):
	if game == null:
		return
	if increase:
		level += 1
	level = clamp(level, 1, max_difficulty)
	var s = 9# + int(level/2) * 2
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
				var use_same_shape = use_b12(agent_use_same_shape_for_alternatives)
				var use_same_color = use_b12(agent_use_same_color_for_all)
				if use_same_color and use_same_shape:
					var selector = game.rng.randi() % 2 == 0
					use_same_color = use_same_color and selector
					use_same_shape = use_same_shape and (not selector)
				if use_same_shape:
					forced_texture_idx = agent_model_texture_idx
				if use_same_color:
					forced_color = agent_model_color.duplicate(true)
				else:
					skip_color = agent_model_color.duplicate(true)

		shuffled_idx.shuffle()
		for idx in shuffled_idx:
			p = agent_start_positions[idx]
			dir = agent_start_directions[idx]
			if board[p.y][p.x].agent != null:
				continue
			if (pos_last_dispatch - p).length() > 4:
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

var need_to_show_alternatives: bool = false
var time_to_show_alternatives_ms: float = 0.0

var need_to_show_model: bool = false
var time_to_show_model_ms: float = 0.0

var time_shown_alternatives_ms: float = 0.0

func _process(_delta: float) -> void:
	if tutorial_hold_board:
		return
	if not game.paused() and not game.level_is_done and game.level_is_ready:
		if need_to_show_alternatives and game.game_time > time_to_show_alternatives_ms:
			need_to_show_alternatives = false
			_dispatch_new_agent(false, true)
			for i in range(num_alternatives - 1):
				_dispatch_new_agent(false, false)
			time_shown_alternatives_ms = game.game_time
			game.tutorial_notify("lineup_shown")
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
			game.tutorial_notify("answered_right")
			if num_corrects_in_level_so_far >= num_corrects_for_next_level:
				level_is_done(true)
		else:
			game.add_score_and_time(-1,-5)
			game.add_correct_or_mistake(0,1)
			game.play_sound("swoosh")
			game.tutorial_notify("answered_wrong")
		var ntries: int = 0
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
	var s: int = 0
	for t in times_to_answer:
		s += t
	return roundi(float(s) / N)

func _add_time_to_answer_ms(t_ms: int):
	if t_ms <= 0:
		return
	times_to_answer.append(t_ms)
	while times_to_answer.size() > 10:
		times_to_answer.remove_at(0)

# --- tutorial staging -------------------------------------------------------
#
# No freeze work is needed: an agent's own timeout is measured in game.game_time (see agent.gd),
# which excludes paused time — so a caption holds the model, and later the lineup, on screen.

func _screen_of(n) -> Vector2:
	if n == null or not is_instance_valid(n):
		return Vector2.ZERO
	return (n as Node2D).get_global_transform_with_canvas().origin

# --- things for the coach to point at (all in SCREEN coordinates) -----------

func tutorial_model():
	for a in agents:
		if is_instance_valid(a) and a.is_model:
			return a
	return null

func tutorial_model_pos() -> Vector2:
	return _screen_of(tutorial_model())

func tutorial_has_model() -> bool:
	return tutorial_model() != null

func tutorial_correct_pos() -> Vector2:
	for a in agents:
		if is_instance_valid(a) and not a.is_model and a.is_correct:
			return _screen_of(a)
	return Vector2.ZERO

func tutorial_has_lineup() -> bool:
	for a in agents:
		if is_instance_valid(a) and not a.is_model:
			return true
	return false

# The candidates INDIVIDUALLY, so the caption placer can find the gap between them.
#
# Handing it the merged rect is useless here: the candidates ring the board, so their bounding box
# is most of the screen and "avoid this" becomes unsatisfiable — which is why the caption ended up
# sitting straight on top of them. As separate small obstacles they leave an obvious hole in the
# center of the board, which is exactly where the caption should go.
func tutorial_candidate_rect_at(i: int) -> Rect2:
	var found: int = 0
	for a in agents:
		if not is_instance_valid(a) or a.is_model:
			continue
		if found == i:
			var c: Vector2 = _screen_of(a)
			var fr: float = tutorial_frame_radius()
			return Rect2(c - Vector2(fr, fr), Vector2(fr, fr) * 2.0)
		found += 1
	return Rect2()

func tutorial_lineup_rect() -> Rect2:
	var res: Rect2 = Rect2()
	for a in agents:
		if not is_instance_valid(a) or a.is_model:
			continue
		var c: Vector2 = _screen_of(a)
		var r: Rect2 = Rect2(c - Vector2(game.tile_size, game.tile_size) * 0.5,
			Vector2(game.tile_size, game.tile_size))
		res = r if res.size.x <= 0.0 else res.merge(r)
	return res

# 1.5 board tiles, so a frame names one thing rather than a cluster. The camera zooms
# (create_camera), so the on-screen tile is tile_size * zoom.
func tutorial_frame_radius() -> float:
	var z: float = 1.0
	if agent_cam != null and is_instance_valid(agent_cam):
		z = agent_cam.zoom.x
	return maxf(12.0, game.tile_size * z * 0.75)

# Freeze everything on screen: existing agents stop counting down, and no new ones arrive.
func tutorial_freeze_board(hold: bool) -> void:
	tutorial_hold_board = hold
	for a in agents:
		if is_instance_valid(a):
			a.tutorial_hold = hold


# What the player gets next, in words. An accuracy figure alone does not say whether they are
# moving on, which is the only thing they want to know at that moment.
func _progress_line(passed: bool, need: int) -> String:
	if not passed:
		return "You need at least %d%% accuracy to pass to the next level." % need
	return "Level passed — on to level %d." % (level + 1)

# The lawn: ONE continuous field over the whole board (scripts/grass_field.gd), with the per-cell
# grass sprites hidden. Tiling — plain, rotated or drawn — is a mosaic of one image however it is
# arranged, and this game's cells were half of it.
#
# Called from _ready() once the board's geometry exists, and again at the START of create_board()
# so a level that changes the board size has its lawn before the cells go down. GrassField.fit()
# only re-sows when that size actually changed.
# The ground node is looked up with get_node_or_null because this script is not only on the
# level scene: storm's blackout.tscn carries a copy of it too, and a hard $ path there throws.
func _fit_ground_to_board() -> void:
	GrassField.fit(self, get_node_or_null("TextureRect") as CanvasItem, game, 18)

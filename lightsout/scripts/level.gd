extends CanvasLayer

enum Dirs {right=0,down=1,left=2,up=3}
enum DoorTypes {open=0, backslash=1, slash=2}
const DirArray = [Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0), Vector2i(0,-1)]

var rng = RandomNumberGenerator.new()		

var game: GenericGameUtil

# score rules:
# success: +10
# bomb (bomb or wall bomb): -1
# new game: -1
# timeout: -1
# clue: -1

# each level 3 times before increasing difficulty

class OneCell:
	var ispipe: bool = false
	var door_type: int = -1
	var has_agent: bool = false
	var istarget: bool = false
	
var rounds_per_level: int = 3
var start_dispatch: bool = false
var time_between_dispatches_ms = 5000
var board: Array
var agents = []
var targets = []
var target_positions = []
var target_lobbies = []
var pipes = []
var empties = []
var doors = []
var transaction_ids = []
var next_transaction_id_idx = 0
var agent_start_positions = []
var agent_start_directions = []
var time_started_level_ms = 0
var time_increased_difficulty_ms = 0
var level: int = 0
var round_in_level: int = 0

# Set when the level's last round has been judged, so the next new_game() knows it is
# starting a LEVEL and not just the next round.
var _level_is_over: bool = false
# What the score was when this level began; a level that misses the gate goes back to it.
var _score_at_level_start: int = 0
var _rollback_score_on_next_level: bool = false
var num_more_packets = 0
var player = null
var max_speed_scale = 1.0
var next_player_dir = -1
var time_to_hide: int = 0
var lights_are_off: bool = false
var play_start_sound: bool = true
var last_level_was_a_win: bool = true
var times_to_answer: Array = []
var _round_start_ms: int = 0

var num_bomb_agents_to_add: int = 3

# --- tutorial staging (all inert outside tutorial_mode) ---------------------
# The lights normally go out on a 5-second timer. During a tutorial the coach decides when: a
# player still reading the first caption must not be plunged into the dark mid-sentence.
var tutorial_hold_lights: bool = false
# Whether the board currently on screen was built FOR a tutorial. Captured when the board is made,
# not read at call time: the win is reported from the player's arrival animation callback, which
# lands after the coach has finished and tutorial_mode has already gone false — so a
# `if game.tutorial_mode` guard there is checked too late and the round-complete popup gets
# through anyway. (mmm taught us this one.)
var _tutorial_board: bool = false
# Bombs already walked into during a lesson, so the bang and the flash happen once each rather
# than on every tick the player spends standing beside one.
var _tutorial_bombs_hit: Dictionary = {}
@export var pipe_scene: PackedScene = load("res://lightsout/scenes/pipe.tscn")
@export var empty_scene: PackedScene = load("res://lightsout/scenes/empty_space.tscn")
@export var agent_scene: PackedScene = load("res://lightsout/scenes/agent.tscn")
@export var door_scene: PackedScene = load("res://lightsout/scenes/door.tscn")
@export var target_scene: PackedScene = load("res://lightsout/scenes/target.tscn")
@export var player_scene: PackedScene = load("res://lightsout/scenes/player.tscn")

var explosion_audio = preload("res://art/sounds/car-crash-1.mp3")
var motor_audio = preload("res://art/sounds/car-ambient-driving.ogg")
var feet_audio = preload("res://art/sounds/kenney/Audio/footstep_grass_001.ogg")
var delivered_audio = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var start_audio = preload("res://art/sounds/click-2.mp3")

signal started_playing
signal sig_level_is_done(didwin:bool)
signal delivered_one
signal collision
signal update_score(score:int)

func _ready() -> void:
	game = LightsG.game
	game.sig_time_over.connect(on_time_over)
	game.sig_lives_depleted.connect(on_lives_depleted)
	level = LightsG.starting_level
	round_in_level = 0
	_apply_level()
	game.add_sound(self, "explosion", explosion_audio, false)
	game.add_sound(self, "delivered", delivered_audio, false)
	game.add_sound(self, "start", start_audio, false)
	
	motor_audio.loop = true
	game.add_sound(self, "motor", motor_audio, true)

	feet_audio.loop = true
	game.add_sound(self, "feet", feet_audio, true)

	if not MainGlobals.sig_game_popup_closed.is_connected(_on_game_popup_closed):
		MainGlobals.sig_game_popup_closed.connect(_on_game_popup_closed)
	if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
		MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
	
func reset():
	start_dispatch = false
	next_player_dir = -1
	time_to_hide = 0
	lights_are_off = false
	play_start_sound = true

	if player != null:
		player.queue_free()
		player = null

	for c in pipes:
		c.queue_free()
	for c in agents:
		c.queue_free()
	for c in doors:
		c.queue_free()
	for c in targets:
		c.queue_free()
	for c in empties:
		c.queue_free()
	pipes.clear()
	empties.clear()
	agents.clear()
	doors.clear()
	targets.clear()
	target_positions.clear()
	target_lobbies.clear()

	transaction_ids = []
	next_transaction_id_idx = 0
	agent_start_positions = []
	agent_start_directions = []
	time_started_level_ms = 0
	num_more_packets = 0

func new_game(from_scratch=true):
	_tutorial_board = game.tutorial_mode
	_tutorial_bombs_hit.clear()
	reset()
	if from_scratch:
		level = LightsG.starting_level
		round_in_level = 0
		# The first level of a session starts clean and stamps its own starting score; every later
		# level does the same from _advance_if_needed().
		_level_is_over = false
		_rollback_score_on_next_level = false
		game.corrects = 0
		game.mistakes = 0
		_score_at_level_start = game.score
		game.time_scale = 0.5

	_advance_if_needed()
	game.need_to_increase_level = false
	time_last_dispatch = -10000
	pos_last_dispatch = Vector2i(-1,-1)
	create_board()
	time_started_level_ms = MainGlobals.timems()
	time_increased_difficulty_ms = time_started_level_ms
	started_playing.emit()
	if not game.tutorial_mode:
		BE.upsert_game_state("Lightsout",
			{"state":"new","level": level, "round_in_level": round_in_level,
			"num_packets": LightsG.num_packets})

func _input(event) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if event.is_action_pressed("new_board"):
		update_score.emit(-1)
	elif event.is_action_pressed("clue"):
		show_clue()
	elif event.is_action_pressed("right") or event.is_action_pressed("ui_right"):
		move_dir(0)
	elif event.is_action_pressed("down") or event.is_action_pressed("ui_down"):
		move_dir(1)
	elif event.is_action_pressed("left") or event.is_action_pressed("ui_left"):
		move_dir(2)
	elif event.is_action_pressed("up") or event.is_action_pressed("ui_up"):
		move_dir(3)

func move_dir(dir):
	if player == null or !game.level_is_ready:
		return
	if tutorial_hold_lights and !lights_are_off:
		# The coach has not put the lights out yet, so a stray swipe must not do it for them.
		return
	game.tutorial_notify("player_moved")
	if !lights_are_off:
		_start_playing()
		MainGlobals.global_start_countdown(-1)
	if lights_are_off:
		next_player_dir = dir
		if player != null:
			player.is_moving = true
		if abs(dir - player.direction) == 2:
			player.last_major_tick_ms = 0
			tick(true)

func _start_playing():
	game.tutorial_notify("lights_off")   # no-op outside tutorial mode
	if play_start_sound:
		play_start_sound = false
		if true:
			game.play_sound("start")
		if player != null:
			player.play()
	turn_lights_off()

func _process(_delta: float) -> void:
	if player != null and !player.was_hit:
		if time_to_hide > 0 and MainGlobals.timems() >= time_to_hide:
			_start_playing()
		check_agent_collisions()
	
func add_pipe(p):
	board[p.y][p.x].ispipe = true
	var pipe = pipe_scene.instantiate()
	pipe.board_pos = p
	pipe.position = game.board_to_px(p)
	add_child(pipe)
	pipes.append(pipe)

func add_empty(p):
	var e = empty_scene.instantiate()
	e.board_pos = p
	e.position = game.board_to_px(p)
	add_child(e)
	empties.append(e)
	
func add_target(p, id, show_id=false):
	board[p.y][p.x].istarget = true
	var target = target_scene.instantiate()
	target.position = game.board_to_px(p)
	target.board_pos = p
	target.set_id(id, show_id)
	target.z_index = 100
	add_child(target)
	# target.target_pressed.connect(on_clicked_target)
	targets.append(target)
	target_positions.append(p)
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
	target_lobbies.append(q)
	# agent_start_positions.append(p)
	agent_start_positions.append(q)
	target.set_img_rot(dir * PI/2.0)
	agent_start_directions.append(dir)
	if !board[q.y][q.x].ispipe:
		add_pipe(q)
	return q

func dist_from_agents(p):
	var mind = 1e6
	for a in agents:
		var d = (p - a.board_pos).length()
		if d < mind:
			mind = d
	return mind

func dist_from_array(p, arr):
	var mind = 1e6
	for a in arr:
		var d = (p - a).length()
		if d < mind:
			mind = d
	return mind
	
func show_hide_walls():
	for e in empties:
		e.show_hide_walls(board)

var agent_cam = null

func create_camera(camscale):
	if agent_cam == null:
		agent_cam = Camera2D.new()
		add_child(agent_cam)
	agent_cam.make_current()
	agent_cam.zoom = Vector2(camscale,camscale)
	# agent_cam.position_smoothing_enabled = true
	# agent_cam.position_smoothing_speed = 10
	agent_cam.enabled = true
	agent_cam.set_anchor_mode(Camera2D.ANCHOR_MODE_DRAG_CENTER)
	# agent_cam.set_offset(MainGlobals.screen_size/2)
	agent_cam.set_offset(game.board_to_px(game.get_board_center()))
	
func create_board() -> void:
	start_dispatch = false
	board.clear()
	for row_index in game.board_size.y:
		var row: Array[OneCell]
		row.resize(game.board_size.x)
		for col_index in game.board_size.x:
			row[col_index] = OneCell.new()
		board.append(row)
	var target_rows = range(2,game.board_size.y-1,2)
	var target_cols = range(2,game.board_size.x-1,2)
	var ntargets = target_rows.size() * 2 + target_cols.size() * 2
	var targetids = range(1, ntargets+1)
	targetids.shuffle()
	var targetidx = 0
	var show_ids = false
	for row in target_rows:
		add_target(Vector2i(0,row), targetids[targetidx], show_ids)
		targetidx += 1
		add_target(Vector2i(game.board_size.x-1,row), targetids[targetidx], show_ids)
		targetidx += 1
	for col in target_cols:
		add_target(Vector2i(col,0), targetids[targetidx], show_ids)
		targetidx += 1
		add_target(Vector2i(col,game.board_size.y-1), targetids[targetidx], show_ids)
		targetidx += 1

	transaction_ids = range(1, ntargets+1)
	transaction_ids.shuffle()

	for row in range(1,game.board_size.y-1):
		for col in range(1,game.board_size.x-1):
			if row % 2 == 0 or col % 2 == 0:
				if !board[row][col].ispipe:
					add_pipe(Vector2i(col,row))
	
	for row in game.board_size.y:
		for col in game.board_size.x:
			if !board[row][col].ispipe:
				add_empty(Vector2i(col,row))
				
	show_hide_walls()
				
	for pipe in pipes:
		pipe.set_rot(board)

	if false:
		# add doors			
		var door
		for row in game.board_size.y:
			for col in game.board_size.x:
				var p = Vector2i(col,row)
				if board[p.y][p.x].ispipe:
					var nbranches = 0
					for d in DirArray:
						var q = p+d
						if game.in_board(q) and board[q.y][q.x].ispipe:
							nbranches += 1
					if nbranches > 2:
						var door_type
						if !game.in_board(p,2) or game.is_corner(p,3):
							door_type = 0
						else:
							door_type = 0#rng.randi_range(0,2)
							
						board[p.y][p.x].door_type = door_type
						door = door_scene.instantiate()
						door.position = game.board_to_px(p)
						door.set_board_pos(p)
						#door.rotate(door_type * PI/4.0)
						add_child(door)
						door.set_rot(door_type)
						door.door_pressed.connect(on_clicked_door)
						doors.append(door)					

	add_player()				

	var ntarget_bombs: int = 0
	var ntries: int = 0
	while ntarget_bombs < 1 and ntries < 100:
		ntries += 1
		for target in targets:
			if target.transaction_id != player.transaction_id:
				var r = randi_range(0,3)
				if r == 0:
					ntarget_bombs += 1
					target.set_bomb(Color(0.8,0.1,0.1))
	# start_dispatch = true

	add_random_static_agents()

	if game.tutorial_mode:
		# No countdown and no auto-hide: the coach shows the board, names what is on it, and only
		# then turns the lights out.
		tutorial_hold_lights = true
		time_to_hide = 0
	else:
		time_to_hide = MainGlobals.timems() + 5000
		MainGlobals.global_start_countdown(5)

	create_camera(min(2.0, 1.0 / game.get_board_part_of_width(), 1.0 / game.get_board_part_of_height()))
	game.level_is_ready = true
		
func find_path_to_target():
	var p0:Vector2i = player.board_pos
	var p1:Vector2i
	#make sure board is not istarget or has_agent
	for t in targets:		
		if t.is_receiver and t.transaction_id == player.transaction_id:
			p1 = t.board_pos
	
	var astar = AStarGrid2D.new()
	astar.region = Rect2i(Vector2i.ZERO, game.board_size)
	astar.cell_size = Vector2(1, 1)
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	# (Optional) if you want step cost to be something else:
	# astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER

	astar.update()
	for y in astar.region.size.y:
		for x in astar.region.size.x:
			if board[y][x].istarget or board[y][x].has_agent or !board[y][x].ispipe:
				astar.set_point_solid(Vector2i(x, y), true)

	var start = p0
	var goal = p1

	astar.set_point_solid(start, false)
	astar.set_point_solid(goal, false)

	var path = astar.get_id_path(start, goal)
	# var path = astar.get_point_path(start, goal)

	# print(path)
	return path

	
func add_random_static_agents():
	if game.tutorial_mode:
		# The lesson is about the lights, the target and the bombs. Other movers are never
		# mentioned, and one wandering into the player kills them — a hazard the player was not
		# taught, ending a step that is waiting for them to walk somewhere.
		return
	var n = num_bomb_agents_to_add
	# var n := int((game.board_size.x - 7) / 2)
	var retries: int = 1000
	for i in n:
		var allocated: bool = false
		while !allocated and retries > 0:
			retries -= 1
			var p = Vector2i(randi_range(3,game.board_size.x-3), randi_range(2,game.board_size.y-3))
			if !board[p.y][p.x].has_agent:
				var t = find_closest_target(p)
				if t.transaction_id == player.transaction_id and t.is_receiver:
					var dboard = t.board_pos - p
					if dboard.length() <= 2.1:
						continue
				if board[p.y][p.x].ispipe:
					var d_to_player = (p - player.board_pos).length()
					var d_to_agents = dist_from_agents(p)
					if d_to_player > 2 and d_to_agents > 2:
						board[p.y][p.x].has_agent = true
						var path = find_path_to_target()
						if path.size() == 0:
							board[p.y][p.x].has_agent = false
						else:
							add_agent_at(p, 0)
							allocated = true

func find_closest_target(p):
	var d = 100
	var target
	for t in targets:
		var this_d = t.board_pos.distance_to(p)
		if this_d < d:
			d = this_d
			target = t
	return target

func find_farthest_target(p:Vector2i):
	var max_t_p = Vector2i.ZERO
	for t in targets:
		max_t_p.x = max(max_t_p.x, t.board_pos.x)
		max_t_p.y = max(max_t_p.y, t.board_pos.y)
	var candidates = []
	if p.x == 1:
		#target will be on the right vertical wall
		for t in targets:
			if t.board_pos.x == max_t_p.x:
				candidates.append(t)
				if t.board_pos.y > 1 or t.board_pos.y < max_t_p.y - 2:
					candidates.append(t)
	elif p.x == max_t_p.x-1:
		#target will be on the left vertical wall
		for t in targets:
			if t.board_pos.x == 0:
				candidates.append(t)
				if t.board_pos.y > 1 or t.board_pos.y < max_t_p.y - 2:
					candidates.append(t)
	elif p.y == 1:
		#target will be on the bottom horizontal wall
		for t in targets:
			if t.board_pos.y == max_t_p.y:
				candidates.append(t)
				if t.board_pos.x > 1 or t.board_pos.x < max_t_p.x - 2:
					candidates.append(t)
	elif p.y == max_t_p.y-1:
		#target will be on the top horizontal wall
		for t in targets:
			if t.board_pos.y == 0:
				candidates.append(t)
				if t.board_pos.x > 1 or t.board_pos.x < max_t_p.x - 2:
					candidates.append(t)
	candidates.shuffle()
	return candidates[0]
	# var d = 0
	# var target
	# for t in targets:
	# 	var this_d = t.board_pos.distance_to(p) * get_target_preference(t)
	# 	if this_d > d:
	# 		d = this_d
	# 		target = t
	# return target

var next_agent_id: int = 1
func _record_answer_time():
	var t = MainGlobals.timems() - _round_start_ms
	if t > 0 and t < 60000:
		times_to_answer.append(t)
		while times_to_answer.size() > 20:
			times_to_answer.remove_at(0)

func mean_time_to_answer_ms() -> int:
	if times_to_answer.is_empty(): return 9999
	var s: int = 0
	for t in times_to_answer: s += t
	return roundi(float(s) / times_to_answer.size())

func add_agent_at(p: Vector2i, direction: int, agent_type: int = 1):
	_round_start_ms = MainGlobals.timems()
	var agent = agent_scene.instantiate()
	agent.direction = direction
	agent.board_pos = p
	agent.body_ids = range(1, LightsG.num_packets+1+num_more_packets)
	# var rng = RandomNumberGenerator.new()
	agent.speed_scale = rng.randf_range(0.8, max_speed_scale)
	add_child(agent)
	agent.set_type(agent_type)
	agent.set_id(next_agent_id)
	next_agent_id += 1
	# agent.agent_pressed.connect(on_agent_pressed)
	board[p.y][p.x].has_agent = true
	# agent.hit.connect(on_agent_hit)
	agent.remove_agent.connect(on_agent_remove_agent)
	agents.append(agent)
	agent.set_pos(game.board_to_px(p), direction)
	var sender = find_closest_target(p)
	var receiver = null
	var taridxs = range(0, targets.size())
	taridxs.shuffle()
	for i in taridxs:
		var t = targets[i]
		if t.board_pos != sender.board_pos and !t.is_receiver and !t.is_sender:
			receiver = t
	if receiver != null:
		var color = game.next_color()
		var transaction_id = transaction_ids[next_transaction_id_idx]
		next_transaction_id_idx = (next_transaction_id_idx + 1) % transaction_ids.size()
		# receiver.set_receiver(true, color, transaction_id)
		# sender.set_sender(true, color, transaction_id)
		agent.transaction_id = transaction_id
		agent.set_color(color)

	if not game.is_sound_playing("motor"):
		game.play_sound("motor")
		
	return agent
			
func on_player_is_really_moving(is_moving: bool):
	if is_moving:
		if not game.is_sound_playing("feet"):
			game.play_sound("feet")
	else:
		game.stop_sound("feet")

func on_clicked_door(pos: Vector2i):
	for i in doors.size():
		var door = doors[i]
		if door.board_pos == pos:
			var current = door.rot_idx
			var newdir = (current + 1) % 3
			door.set_rot(newdir)
			board[pos.y][pos.x].door_type = newdir
			break

func can_go_to(p):
	if !game.in_board(p):
		return false
	var cond = board[p.y][p.x].ispipe
	cond = cond and !board[p.y][p.x].istarget
	return cond
	
func all_agents_done():
	if agents.size() == 0:
		return false
	for agent in agents:
		if !agent.arrived:
			return false
	return true
	
func check_player_on_target(q):
	for i in target_positions.size():
		var target = targets[i]
		var p = target_positions[i]
		var d = (p-q).length()
		if abs(d-1) < 1e-3:
			if player.transaction_id == target.transaction_id and target.is_receiver:
				time_to_hide = 0
				turn_lights_on()
				game.play_sound("delivered")
				player.mark_arrived()
				_record_answer_time()
				game.tutorial_notify("delivered")
				delivered_one.emit()
				return true
			elif !target.is_receiver and !target.is_sender and target.is_bomb:
				time_to_hide = 0
				if not game.tutorial_mode:
					turn_lights_on()
				if game.tutorial_mode:
					# In a real round a bomb ends it: mark_hit() starts an animation whose callback
					# FREES the player, stranding whatever step waits on them. So the lesson lets
					# them walk on.
					#
					# It must return FALSE, not true: move_player_on_tick() treats true as "stop
					# here", and since the player is still standing beside the bomb it would get
					# true again on every following tick — the player could never move again.
					if not _tutorial_bombs_hit.has(target):
						_tutorial_bombs_hit[target] = true
						game.tutorial_notify("hit_bomb")
						game.play_sound("explosion")
						# A FLASH, not a reveal. In a real round the lights come up because the run
						# is over; here it continues, so leaving them on would hand the player the
						# whole board and end the memory task.
						turn_lights_on()
						MainGlobals.do_after(0.35, turn_lights_off)
					return false
				game.tutorial_notify("hit_bomb")
				game.play_sound("explosion")
				collision.emit()
				player.mark_hit()
				return true
	return false

func move_player_on_tick(force: bool):
	if player == null or !player.is_moving:
		return
	if !player.reached_target_pos and !force:
		return
	# if next_player_dir < 0:
	# 	return
	if !player.need_to_major_tick():
		return
	player.set_major_tick_now()
	var p = player.board_pos
	if player.arrived or player.was_hit:
		return	
	var stop_at_target = check_player_on_target(p)
	if stop_at_target:
		return
	# var adj_tar_id = get_adjacent_target_id(p, player)
	# if adj_tar_id >= 0:
	# 	# delivered_transaction(player.transaction_id)
	# 	player.mark_arrived()
	# 	delivered_one.emit()
	# 	# MainGlobals.do_after(2, func(): level_is_done(true))
	# 	return
	if game.in_board(p):
		var used_next_dir = next_player_dir >= 0
		var dir = next_player_dir if next_player_dir >= 0 else player.direction
		var vdir = DirArray[dir]
		var q = p + vdir
		if !can_go_to(q) and next_player_dir >= 0:
			dir = player.direction
			vdir = DirArray[dir]
			q = p + vdir
			used_next_dir = false
		if !can_go_to(q):
			var nextdir1 = (dir + 1) % 4
			var nextvdir1 = DirArray[nextdir1]
			var q1 = p + nextvdir1
			var nextdir2 = (dir + 3) % 4
			var nextvdir2 = DirArray[nextdir2]
			var q2 = p + nextvdir2
			if can_go_to(q1) and !can_go_to(q2):
				q = q1
				dir = nextdir1
			elif can_go_to(q2) and !can_go_to(q1):
				q = q2
				dir = nextdir2
			else:
				return
		vdir = DirArray[dir]
		q = p + vdir
		if can_go_to(q):
			player.direction = dir
			var new_player_pos = game.board_to_px(q)
			var actual_tick_time = player.set_target_pos(new_player_pos)
			if used_next_dir:
				next_player_dir = -1
			player.last_major_tick_ms = MainGlobals.timems() + actual_tick_time - game.major_tick_time_ms * game.time_scale
			player.board_pos = q
			board[q.y][q.x].has_agent = true
			board[p.y][p.x].has_agent = false
			# if next_player_dir == dir and player.is_moving:
			# 	next_player_dir = -1
			# 	player.is_moving = false

# var last_major_tick_ms = -10000.0
func tick(force: bool = false):
	if game.level_is_done or !game.level_is_ready:
		return
	# var now = MainGlobals.timems()
	# if now - last_major_tick_ms < game.major_tick_time_ms * game.time_scale:
	# 	return
	# last_major_tick_ms = now
	# if now - time_increased_difficulty_ms > game.time_to_increase_difficulty_s * 1000:
	# 	increase_difficulty()
	# 	time_increased_difficulty_ms = now

	# if all_agents_done():
	# 	level_is_done(true)
	# 	return
	
	move_player_on_tick(force)

	var removed_agents = []
	for iagent in agents.size():
		var agent = agents[iagent]
		if agent.need_to_major_tick():
			agent.set_major_tick_now()
			var p = agent.board_pos
			if agent.arrived or agent.was_hit:
				continue
			var adj_tar_id = get_adjacent_target_id(p, agent)
			if adj_tar_id >= 0:
				delivered_transaction(agent.transaction_id)
				agent.mark_arrived()
				delivered_one.emit()
				# removed_agents.append(iagent)
				continue
			# var _removed_body_part = false
			# if adj_tar_id >= 0:
			# 	_removed_body_part = agent.remove_body_if_first(adj_tar_id)
			if game.in_board(p):
				var dir = agent.direction
				var origdir = dir
				var vdir = DirArray[dir]
				var door_type = board[p.y][p.x].door_type
				var q = p + vdir
				if door_type >= 0:
					if door_type == 1:
						if dir == 0 or dir == 2:
							dir += 1
						elif dir == 1 or dir == 3:
							dir = (dir + 3) % 4
					elif door_type == 2:
						if dir == 0 or dir == 2:
							dir = (dir + 3) % 4						
						elif dir == 1 or dir == 3:
							dir = (dir + 1) % 4
				else:		# if not a door
					if !can_go_to(q):
						for diradd in [1,3]:
							var nextdir = (dir + diradd) % 4
							var nextvdir = DirArray[nextdir]
							q = p + nextvdir
							if can_go_to(q):
								dir = nextdir
								break
				vdir = DirArray[dir]
				q = p + vdir
				if !can_go_to(q):
					dir = (origdir + 2) % 4
					vdir = DirArray[dir]
					q = p + vdir
				agent.direction = dir
				var new_agent_pos = game.board_to_px(q)
				var cell = board[q.y][q.x]
				var d = int(game.tile_size/4.0)
				if cell.door_type == 1:
					if dir == 0 or dir == 3:
						new_agent_pos += Vector2(-d,d)
					elif dir == 2 or dir == 1:
						new_agent_pos += Vector2(d,-d)
				elif cell.door_type == 2:
					if dir == 0 or dir == 1:
						new_agent_pos += Vector2(-d,-d)
					elif dir == 2 or dir == 3:
						new_agent_pos += Vector2(d,d)
				agent.set_target_pos(new_agent_pos)
				agent.board_pos = q
				board[q.y][q.x].has_agent = true
				board[p.y][p.x].has_agent = false			

	for iremove in removed_agents.size():
		agents[iremove].queue_free()
		agents.remove_at(iremove)
		delivered_one.emit()

func delivered_transaction(transaction_id):
	for t in targets:
		if t.transaction_id == transaction_id:
			if t.is_receiver:
				t.set_receiver(false, Color.WHITE, transaction_id)
			elif t.is_sender:
				t.set_sender(false, Color.WHITE, transaction_id)
				
# func get_adjacent_target_id(q):
# 	for i in target_positions.size():
# 		var p = target_positions[i]
# 		var d = (p-q).length()
# 		if abs(d-1) < 1e-3:
# 			var target = targets[i]
# 			var target_id = target.id
# 			return target_id
# 	return -1

func get_adjacent_target_id(q, agent):
	for i in target_positions.size():
		var target = targets[i]
		if target.transaction_id >= 0 and target.is_receiver:
			var p = target_positions[i]
			var d = (p-q).length()
			if abs(d-1) < 1e-3:
				if agent.transaction_id == target.transaction_id:
					var target_id = target.id
					return target_id
				else:
					break
	return -1

func _on_game_popup_closed():
	sig_level_is_done.emit(last_level_was_a_win)

func _on_level_done_popup_closed():
	sig_level_is_done.emit(true)

func level_is_done(didwin: bool):
	last_level_was_a_win = didwin
	game.level_is_done = true
	game.stop_sound("motor")
	game.stop_sound("feet")
	if game.tutorial_mode or _tutorial_board:
		# "Round 1 of Level 1 completed" landing on (or just after) the coach's closing caption is
		# the failure mmm taught us to guard against. _tutorial_board is what makes this hold: the
		# win arrives from a tween callback, by which time tutorial_mode is already false.
		return
	BE.send_event("level_done", "Lightsout", {
		"level": level,
		"round_in_level": round_in_level,
		"didwin": int(didwin),
	})
	start_dispatch = false
	# EVERY round counts toward the level now, won or lost. Before this, round_in_level only
	# moved when need_to_increase_level had been set, which happened on a WIN — so a lost
	# round did not count at all and a level could be postponed forever but never failed.
	game.add_correct_or_mistake(1 if didwin else 0, 0 if didwin else 1)
	round_in_level += 1
	if round_in_level >= rounds_per_level:
		_finish_level()
		return
	if didwin:
		reset()
		await get_tree().process_frame
		game.show_game_popup(self, "Well done!", "Round %d\nof\nLevel %d\n\ncompleted" % [round_in_level, level])
	else:
		game.show_game_popup(self, "Oh no!", "Round %d\nof\nLevel %d\n\nnot completed" % [round_in_level, level])

# A level is `rounds_per_level` rounds, and it is PASSED on the share of them won.
func _finish_level() -> void:
	var need: int = LightsoutLevelConfig.pass_pct_for(level)
	var pct: int = game.session_pct_correct()
	var passed: bool = pct >= need
	var is_last: bool = level >= LightsoutLevelConfig.LEVELS.size()
	game.need_to_increase_level = passed and not is_last
	_rollback_score_on_next_level = not passed
	_level_is_over = true
	# No fanfare over a level that was not passed.
	MainGlobals.global_level_is_done(passed)
	var textadd: String = "\n\nRounds won: %d of %d\nAccuracy: %d%%\n\n%s" % [
		game.corrects, rounds_per_level, pct, _progress_line(passed, need, is_last)]
	game.show_level_done_popup(self, "", "", level, textadd, passed)

# What the player gets next, in words. An accuracy figure alone does not say whether they are
# moving on, which is the only thing they want to know at that moment.
func _progress_line(passed: bool, need: int, is_last: bool) -> String:
	if not passed:
		return "You need to win at least %d%% of the rounds to pass to the next level." % need
	if is_last:
		return "Level passed — this is the last one, so it comes round again."
	return "Level passed — on to level %d." % (level + 1)

# Counting the rounds is level_is_done's job now; this only acts on the gate's verdict, and
# only at a level boundary.
func _advance_if_needed() -> void:
	if game == null:
		return
	if _level_is_over:
		_level_is_over = false
		round_in_level = 0
		# A replay has to be a FRESH attempt: the gate reads these, so a retry that inherited
		# the losses which failed the level could not pass it even played perfectly.
		game.corrects = 0
		game.mistakes = 0
		# The failed level's points go back HERE, on Continue, so the summary card was still
		# read against the score the player had while playing it.
		if _rollback_score_on_next_level:
			_rollback_score_on_next_level = false
			game.score = _score_at_level_start
		_score_at_level_start = game.score
		if game.need_to_increase_level:
			level += 1
			game.add_life()
	_apply_level()

func _apply_level() -> void:
	if game == null:
		return
	var cfg: Dictionary = LightsoutLevelConfig.LEVELS[min(level, LightsoutLevelConfig.LEVELS.size()) - 1]
	# How many rounds this level is judged over — the gate reads it, so it has to come from the
	# config rather than staying at whatever the member was initialised to.
	rounds_per_level = int(cfg.get("rounds", rounds_per_level))
	var s: int = cfg.get("board_size", 9)
	game.max_board_size = Vector2i(s, s)
	game.forced_board_size = game.max_board_size
	num_bomb_agents_to_add = cfg.get("num_bombs", 2)
	time_between_dispatches_ms = cfg.get("dispatch_ms", 5000)
	num_more_packets = 0
	max_speed_scale = 1.0
	game.init_sizes()

func add_player_at(p: Vector2i, direction: int):
	if player != null:
		player.queue_free()
	player = player_scene.instantiate()
	add_child(player)
	player.reset()
	player.direction = direction
	player.board_pos = p
	player.body_ids = []#range(1, LightsG.num_packets+1+num_more_packets)
	player.speed_scale = rng.randf_range(0.8, max_speed_scale)
	# player.player_pressed.connect(on_agent_pressed)
	player.sig_is_really_moving.connect(on_player_is_really_moving)
	board[p.y][p.x].has_agent = true
	# agent.hit.connect(on_agent_hit)
	player.remove_player.connect(on_player_remove_player)
	player.set_pos(game.board_to_px(p), direction)
	var sender = find_closest_target(p)
	var receiver = find_farthest_target(p)

	var color = Color(0.1,0.5,0.99) #game.next_color()
	var transaction_id = transaction_ids[next_transaction_id_idx]
	next_transaction_id_idx = (next_transaction_id_idx + 1) % transaction_ids.size()
	receiver.set_receiver(true, color, transaction_id)
	sender.set_sender(true, color, transaction_id)
	player.transaction_id = transaction_id
	player.set_color(color)

func add_player():
	var shuffled_idx = range(0, agent_start_positions.size())
	var ntries_center: int = 3
	for i in range(ntries_center):
		shuffled_idx.shuffle()
		var idx = shuffled_idx[0]
		var p = agent_start_positions[idx]
		if i == ntries_center-1 or abs(p.x - game.board_size.x/2) <= 2 or abs(p.y - game.board_size.y/2) <= 2:
			var dir = agent_start_directions[idx]
			add_player_at(p, dir)
			return

var time_last_dispatch = -10000
var pos_last_dispatch = Vector2i(-1,-1)
func _on_agent_dispatch_timer_timeout() -> void:
	if start_dispatch and game.playing and not game.paused():
		var tm = MainGlobals.timems()
		if tm - time_last_dispatch >= time_between_dispatches_ms:
			time_last_dispatch = tm
			var p
			var dir
			var got_p = false
			var shuffled_idx = range(0, agent_start_positions.size())
			shuffled_idx.shuffle()
			for idx in shuffled_idx:
				if start_dispatch and game.playing and not game.paused():
					# var idx = rng.randi_range(0,agent_start_positions.size()-1)
					p = agent_start_positions[idx]
					dir = agent_start_directions[idx]
					if board[p.y][p.x].has_agent:
						continue
					if (pos_last_dispatch - p).length() > 4:
						var t = find_closest_target(p)
						if t.is_receiver or t.is_sender:
							continue
						got_p = true
						break
				else:
					break
			if got_p:
				pos_last_dispatch = p
				add_agent_at(p, dir, 1)

func on_agent_remove_agent(agent_id):
	for i in agents.size():
		if agents[i].agent_id == agent_id:
			board[agents[i].board_pos.y][agents[i].board_pos.x].has_agent = false
			agents[i].queue_free()
			agents.remove_at(i)
			break

func on_player_remove_player(arrived: bool):		
	if player != null:
		player.queue_free()
		player = null
	level_is_done(arrived)
	# MainGlobals.do_after(2, func(): level_is_done(true))

# func on_agent_hit(agent_id):
# 	var ref_agent
# 	var ref_pos
# 	for agent in agents:
# 		if agent.agent_id == agent_id:
# 			ref_agent = agent
# 			ref_pos = ref_agent.board_pos
# 			break	
# 	for agent in agents:
# 		if agent.agent_id != agent_id:
# 			var d = (ref_pos - agent.board_pos).length()
# 			if d < 1e-3:
# 				print("agent %d hit %d" % [agent_id, agent.agent_id])
# 				agent.mark_hit()
# 				ref_agent.mark_hit()
# 				break
	
func check_agent_collisions():
	for i in agents.size():
		var a1 = agents[i]
		var d_p_to_a = (a1.board_pos - player.board_pos).length()
		if d_p_to_a < 0.5:
			turn_lights_on()
			a1.mark_hit()
			if game.tutorial_mode:
				# Same reason as the bomb: player.mark_hit() starts an animation whose callback
				# FREES the player, stranding whatever step is waiting on them.
				game.tutorial_notify("hit_agent")
				return
			collision.emit()
			player.mark_hit()
			if not game.is_sound_playing("explosion"):
				game.play_sound("explosion")
			return
		if !a1.was_hit and !a1.arrived:
			for j in agents.size():
				if i != j:
					var a2 = agents[j]
					if !a2.was_hit and !a2.arrived:
						var d = a1.distance_to(a2)
						if d < game.tile_size/4.0:
							# print("agent %d hit %d" % [a1.agent_id, a2.agent_id])
							a1.mark_hit()
							a2.mark_hit()
							collision.emit()

# func activate_transaction(transaction_id):
# 	var receiver = null
# 	var sender = null
# 	for t in targets:
# 		if t.transaction_id == transaction_id:
# 			if t.is_receiver:
# 				receiver = t
# 			if t.is_sender:
# 				sender = t
# 	if receiver:
# 		receiver.flash()
# 	if sender:
# 		sender.flash()
# 	for agent in agents:
# 		if agent != null and agent.transaction_id == transaction_id:
# 			agent.is_moving = true
# 			if not game.is_sound_playing("motor"):
# 				game.play_sound("motor")
# 			break

# func on_agent_pressed(transaction_id, _agent_board_pos):
# 	activate_transaction(transaction_id)

# func on_clicked_target(target_id, _target_board_pos):
# 	var target = null
# 	for t in targets:
# 		if t.id == target_id:
# 			target = t
# 			break
# 	if target:
# 		activate_transaction(target.transaction_id)

func turn_lights_off():
	time_to_hide = 0
	for target in targets:
		target.hide()
	for door in doors:
		door.hide()
	for pipe in pipes:
		pipe.set_modulate(Color(1,1,1,0.7))
		#pipe.set_modulate(Color(0.7,0.7,0.7,1))
		# pipe.hide()
	for empty in empties:
		empty.set_modulate(Color(1,1,1,0.3))
	for agent in agents:
		agent.hide()
	lights_are_off = true

func show_clue():
	game.tutorial_notify("clue_used")
	turn_lights_on()
	MainGlobals.do_after(0.1, turn_lights_off)
	update_score.emit(-1)

func turn_lights_on():
	lights_are_off = false
	time_to_hide = 0
	for target in targets:
		target.show()
	for door in doors:
		door.show()
	for pipe in pipes:
		pipe.set_modulate(Color(1,1,1,1))
	for empty in empties:
		empty.set_modulate(Color(1,1,1,1))
	for agent in agents:
		agent.show()

func on_time_over():
	turn_lights_on()

func on_lives_depleted():
	turn_lights_on()

# --- tutorial staging -------------------------------------------------------

# Put the lights out on the coach's word rather than on the 5-second timer.
func tutorial_lights_out() -> void:
	tutorial_hold_lights = false
	if not lights_are_off:
		_start_playing()

# True once the player has walked into a bomb during this lesson, so the coach can say so instead
# of leaving them to wonder why nothing happened.
func tutorial_bomb_was_hit() -> bool:
	return not _tutorial_bombs_hit.is_empty()

func tutorial_lights_are_off() -> bool:
	return lights_are_off

# --- things for the coach to point at (all in SCREEN coordinates) -----------

func _screen_of(n) -> Vector2:
	if n == null or not is_instance_valid(n):
		return Vector2.ZERO
	return (n as Node2D).get_global_transform_with_canvas().origin

func tutorial_player_pos() -> Vector2:
	return _screen_of(player)

func tutorial_has_player() -> bool:
	return player != null and is_instance_valid(player)

# The one target this run is FOR: the receiver carrying the player's transaction.
func tutorial_goal_target():
	if player == null or not is_instance_valid(player):
		return null
	for t in targets:
		if is_instance_valid(t) and t.is_receiver and t.transaction_id == player.transaction_id:
			return t
	return null

func tutorial_goal_pos() -> Vector2:
	return _screen_of(tutorial_goal_target())

# Any bomb, so the coach can point at one concrete example rather than describing them.
func tutorial_bomb_pos() -> Vector2:
	var best = null
	var best_d: float = 1e9
	for t in targets:
		if not is_instance_valid(t) or not t.is_bomb:
			continue
		if player != null and is_instance_valid(player):
			var d: float = Vector2(t.board_pos - player.board_pos).length()
			if d < best_d:
				best_d = d
				best = t
		elif best == null:
			best = t
	return _screen_of(best)

func tutorial_has_bomb() -> bool:
	return tutorial_bomb_pos() != Vector2.ZERO

func tutorial_bottom_button(node_name: String) -> Control:
	var b = get_tree().root.find_child(node_name, true, false)
	return b if b is Control and (b as Control).is_visible_in_tree() else null


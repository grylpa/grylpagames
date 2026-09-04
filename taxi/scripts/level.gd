extends CanvasLayer

var game: GenericGameUtil

class OneCell:
	var ispipe := false
	var door_type := -1
	var agent = null
	var istarget := false
	var isbomb := false
	var target
	var pipe

	# func get_state() -> Dictionary:
	# 	return {
	# 		"ispipe": ispipe,
	# 		"door_type": door_type,
	# 		"agent_id": agent.agent_id if agent != null else -1,
	# 		"istarget": istarget,
	# 		"isbomb": isbomb,
	# 		"target_id": target.target_id if target != null else -1,
	# 	}

	# func set_state(data: Dictionary) -> void:
	# 	ispipe = data.get("ispipe", false)
	# 	door_type = data.get("door_type", -1)
	# 	var _agent_id = data.get("agent_id", -1)
	# 	ispipe = data.get("ispipe", false)
	# 	istarget = data.get("istarget", false)
	# 	isbomb = data.get("isbomb", false)
	# 	var _target_id = data.get("target_id", -1)
	
var num_of_taxis := 6
var num_of_gas_stations := 2
var allow_draw_path := false
var start_dispatch := false
var time_between_dispatches_ms = 5000
var board: Array
var agents = []
var taxis = []
var targets = []
var gas_stations = []
var target_positions = []
var target_lobbies = []
var pipes = []
var empties = []
var doors = []
var bombs = []
var next_transaction_id = 1
var agent_start_positions = []
var agent_start_directions = []
var time_increased_difficulty_ms = 0
var level := 0
var start_with_state := {}
var can_use_state := false

var dict_tran_id_to_target = {}

@export var pipe_scene: PackedScene = load("res://taxi/scenes/pipe.tscn")
@export var empty_scene: PackedScene = load("res://taxi/scenes/empty_space.tscn")
@export var agent_scene: PackedScene = load("res://taxi/scenes/agent.tscn")
@export var door_scene: PackedScene = load("res://taxi/scenes/door.tscn")
@export var target_scene: PackedScene = load("res://taxi/scenes/target.tscn")
# @export var bomb_scene: PackedScene = load("res://scenes/bomb_scene.tscn")

var dispatch_audio := preload("res://art/sounds/kenney/Audio/impactBell_heavy_003.ogg")
var delivery_audio := preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var motor_audio := preload("res://art/sounds/car-ambient-driving.ogg")
var swoosh_audio := preload("res://art/sounds/swoosh.mp3")
var honk_audio := preload("res://art/sounds/honk-4.mp3")
var gaveup_audio := preload("res://art/sounds/bump-sound-7.mp3")
var breakdown_audio := preload("res://art/sounds/clash-1.mp3")
# var door_audio := preload("res://art/sounds/door-open-sound-1.mp3")
# var explosion_audio := preload("res://art/sounds/car-crash-1.mp3")

signal started_playing
signal sig_level_is_done(didwin:bool)

func _ready() -> void:
	game = TaxiG.game
	game.time_to_auto_start_moving_ms = 500
	game.sig_time_over.connect(on_time_over)
	level = TaxiG.starting_level
	increase_difficulty(false)

	game.add_sound(self, "honk", honk_audio)
	game.add_sound(self, "dispatch", dispatch_audio)
	game.add_sound(self, "delivery", delivery_audio)
	game.add_sound(self, "swoosh", swoosh_audio)
	game.add_sound(self, "motor", motor_audio, true)
	game.add_sound(self, "customer_gaveup",gaveup_audio)
	game.add_sound(self, "breakdown",breakdown_audio)
	_fit_ground_to_board()

func new_game(from_scratch=true):
	# Re-baseline the tick stamps to the freshly-reset game clock. game.reset() puts game_time back
	# to ~0, but these keep the (larger) value from the previous session, and `now - last_major_tick`
	# is then NEGATIVE — so no taxi moves at all until game_time climbs back past it. That is the
	# "it drives over and picks them up" step sitting there doing nothing and then, minutes later,
	# suddenly working. It needed a previous play to show up, which is why it never reproduced on a
	# fresh run. generic_game_hud.restart_time_left_timer() documents the same trap for the clock.
	last_major_tick = 0.0
	last_one_sec_tick = 0.0
	time_last_dispatch = 0.0
	game.level_is_ready = false
	game.count_lives = true
	game._reset_lives_val = num_of_taxis
	game.reset_lives()
	TaxiG.num_delivered_passengers_in_this_level = 0
	# Log.dbg("start_with_state: ", start_with_state)
	if start_with_state != null and start_with_state.size() > 0:
		level = int(start_with_state.get("level", 1))
		game.score = start_with_state.get("score", game.score)
		game.time_left_sec = start_with_state.get("time_left", game.time_left_sec)
		game.time_scale = start_with_state.get("time_scale", 0.5)
	else:
		if from_scratch:
			level = TaxiG.starting_level
			game.time_scale = 0.5

	var force_new_taxis_and_stations := game.need_to_increase_level

	increase_difficulty(game.need_to_increase_level)
	game.need_to_increase_level = false
	time_last_dispatch = -10000
	pos_last_dispatch = Vector2i(-1,-1)
	if game.tutorial_mode:
		# BEFORE create_board: that is what places the taxis and sets the life count from
		# num_of_taxis, so the tutorial's fleet size has to be decided first.
		_tutorial_setup()
	create_board(force_new_taxis_and_stations)
	# $HUD.new_game()
	started_playing.emit()
	BE.upsert_game_state("Taxi", 
		{"state":"new","starting_level": level})
	game.play_sound("motor")

# func _input(event) -> void:
# 	if MainGlobals.ignore_keyboard_actions:
# 		return
# 	game.handle_event(event,self)

func _process(_delta: float) -> void:
	pass
	
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
	
func add_target(p, id, show_id=false):
	board[p.y][p.x].istarget = true
	var target = target_scene.instantiate()
	board[p.y][p.x].target = target
	target.position = game.board_to_px(p)
	target.board_pos = p
	target.set_id(id, show_id)
	target.z_index = 100
	add_child(target)
	target.target_pressed.connect(on_clicked_target)
	targets.append(target)
	target_positions.append(p)
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
	target_lobbies.append(q)
	target.lobby_pos = q
	target.dropoff_pos = game.next_board_pos(q, dir)
	# agent_start_positions.append(p)
	agent_start_positions.append(q)
	target.set_img_rot(dir * PI/2.0)
	agent_start_directions.append(dir)
	add_pipe(q)
	return q

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
			
func create_board(force_new_taxis_and_stations:bool) -> void:
	_fit_ground_to_board()
	start_dispatch = false
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
	for c in doors:
		c.queue_free()
	for c in bombs:
		c.queue_free()
	for c in targets:
		c.queue_free()
	for c in empties:
		c.queue_free()
	for c in taxis:
		c.queue_free()
	pipes.clear()
	taxis.clear()
	empties.clear()
	agents.clear()
	doors.clear()
	bombs.clear()
	targets.clear()
	gas_stations.clear()
	target_positions.clear()
	target_lobbies.clear()
	dict_tran_id_to_target.clear()

	agent_start_positions = []
	agent_start_directions = []

	var saved_taxis = null
	var saved_gas_stations = null
	if !force_new_taxis_and_stations and start_with_state != null and start_with_state.size() > 0:
		saved_taxis = start_with_state.get("taxis", null)
		saved_gas_stations = start_with_state.get("gas_stations", null)

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

	if saved_gas_stations != null and saved_gas_stations.size() > 0:
		for g in saved_gas_stations:
			var gbp = SaveManager.d_v2i(g["board_pos"])
			for t in targets:
				if t.board_pos == gbp:
					t.set_gas_station()
					gas_stations.append(t)
					for i in 2:	# try twice in case this was a corner
						var idx = agent_start_positions.find(t.lobby_pos)
						if idx >= 0:
							agent_start_positions.remove_at(idx)
							agent_start_directions.remove_at(idx)
	else:
		var ngstations = num_of_gas_stations	
		while ngstations > 0:
			ngstations -= 1
			var gidx = game.rng.randi_range(0, targets.size()-1)
			var gas_station = targets[gidx]
			if gas_station.is_gas_station:
				continue
			gas_station.set_gas_station()
			gas_stations.append(gas_station)
			for i in 2:	# try twice in case this was a corner
				var idx = agent_start_positions.find(gas_station.lobby_pos)
				if idx >= 0:
					agent_start_positions.remove_at(idx)
					agent_start_directions.remove_at(idx)

	for row in range(1,game.board_size.y-1):
		for col in range(1,game.board_size.x-1):
			if row % 2 == 0 or col % 2 == 0 or (row > 2 and col > 2 and 
				row < game.board_size.y-2 and col < game.board_size.x-2):
					add_pipe(Vector2i(col,row))
	
	for row in game.board_size.y:
		for col in game.board_size.x:
			if !board[row][col].ispipe:
				add_empty(Vector2i(col,row))

	show_hide_walls()
				
	for pipe in pipes:
		pipe.set_rot(board)

	for t in targets:
		var p = t.lobby_pos
		board[p.y][p.x].pipe.show_lobby(true)

	if saved_taxis != null and saved_taxis.size() > 0:
		game._reset_lives_val = saved_taxis.size()		
		var n_alive := 0
		for t in saved_taxis:
			var fuel = t.get("fuel", -1)
			var p = SaveManager.d_v2i(t.get("board_pos", {}))
			var dir = t.get("dir",-1)
			if fuel >= 0 and p != Vector2i.ZERO and dir >= 0:
				var taxi = add_taxi_at(p, dir)
				taxi.set_fuel_level(fuel)
				if fuel > 0:
					n_alive += 1
		game.lives_left = n_alive
	else:
		game._reset_lives_val = num_of_taxis
		game.reset_lives()
		MainGlobals.sig_global_update_hud.emit()
		var ntaxis = num_of_taxis
		var shuffled_idx = range(0, agent_start_positions.size())
		shuffled_idx.shuffle()
		while ntaxis > 0 and shuffled_idx.size() > 0:
			var idx = shuffled_idx.pop_front()
			var dir = agent_start_directions[idx]
			var p = game.next_board_pos(agent_start_positions[idx], dir)
			if board[p.y][p.x].agent != null:
				continue
			var can_use_this := true
			for t in targets:
				if t.is_gas_station and (t.lobby_pos == p or t.dropoff_pos == p):
					can_use_this = false
					break
			if can_use_this:
				add_taxi_at(p, (dir+1)%4)
				ntaxis -= 1

	start_dispatch = true
	time_last_dispatch = game.game_time
	create_camera(min(2.0, 1.0 / game.get_board_part_of_width()))
	game.level_is_ready = true
	can_use_state = true

func add_door_at(p, door_type):
	if board[p.y][p.x].door_type >= 0:
		return
	board[p.y][p.x].door_type = door_type
	var door = door_scene.instantiate()
	door.position = game.board_to_px(p)
	door.set_board_pos(p)
	add_child(door)
	door.set_rot(door_type)
	door.door_pressed.connect(on_clicked_door)
	door.door_type_changed.connect(on_door_type_changed)
	doors.append(door)					

func find_closest_target(p, can_be_gas_station):
	var d = 100
	var target
	for t in targets:
		var this_d = t.board_pos.distance_to(p)
		if this_d < d and (can_be_gas_station or !t.is_gas_station):
			d = this_d
			target = t
	return target

func find_closest_non_allocated_target(p):
	var d = 100
	var target
	for t in targets:
		if t.transaction_id < 0:
			var this_d = t.board_pos.distance_to(p)
			if this_d <= d:
				d = this_d
				target = t
	return target

var next_agent_id := 1
func add_taxi_at(p: Vector2i, direction: int):
	var agent = agent_scene.instantiate()
	agent.direction = direction
	agent.board_pos = p
	agent.is_taxi = true
	add_child(agent)
	agent.set_id(next_agent_id)
	next_agent_id += 1
	agent.agent_pressed.connect(on_taxi_pressed)
	# agent.sig_agent_started_moving.connect(on_taxi_started_moving)
	board[p.y][p.x].agent = agent
	agent.remove_agent.connect(on_agent_remove_agent)
	agents.append(agent)
	taxis.append(agent)
	agent.set_pos(game.board_to_px(p), direction)
	agent.sig_out_of_gas.connect(on_out_of_gas)
	agent.sig_finished_filling_gas.connect(on_finished_filling_gas)
	return agent

func add_agent_at(p: Vector2i, direction: int, color, sender, receiver):
	var agent = agent_scene.instantiate()
	agent.direction = direction
	agent.scale = Vector2(0.8,0.8)
	agent.board_pos = p
	agent.waiting_pos = game.next_board_pos(p, direction)
	add_child(agent)
	agent.set_id(next_agent_id)
	next_agent_id += 1
	agent.agent_pressed.connect(on_agent_pressed)	
	agent.sig_agent_timeout.connect(_on_agent_timeout)
	board[p.y][p.x].agent = agent
	# agent.hit.connect(on_agent_hit)
	agent.remove_agent.connect(on_agent_remove_agent)
	agents.append(agent)
	agent.set_pos(game.board_to_px(p), direction)
	agent.transaction_id = sender.transaction_id
	agent.set_color(color)
	agent.dropoff_pos = receiver.dropoff_pos
	agent.sig_agent_finished_arriving.connect(on_agent_finished_arriving)
			
# func reset_sender_receiver(transaction_id):
# 	for t in targets:
# 		if t.transaction_id == transaction_id:
# 			t.reset_sender_receiver()

func on_door_type_changed(pos: Vector2i):
	for i in doors.size():
		var door = doors[i]
		if door.board_pos == pos:
			board[pos.y][pos.x].door_type = door.rot_idx

func on_clicked_door(pos: Vector2i):
	for i in doors.size():
		var door = doors[i]
		if door.board_pos == pos:
			var current = door.rot_idx
			var newdir = (current + 1) % 3
			door.set_rot(newdir,3000)
			board[pos.y][pos.x].door_type = newdir
			$DoorAudio.stop()
			$DoorAudio.play()
			break
	for taxi in taxis:
		taxi_recalc_path(taxi)

func taxi_recalc_path(taxi):
	if taxi.going_to_fill_gas and taxi.path.size() > 0:
		send_taxi_to(taxi, taxi.path[-1])
	elif taxi.goal_pos.size() > 0:
		# Log.dbg("recalc to ", taxi.goal_pos[0])
		send_taxi_to(taxi, taxi.goal_pos[0])
	else:
		# Log.dbg("recalc set not blocked")
		taxi.set_blocked(false)

func can_go_to(p, trans_id:int):
	if !game.in_board(p):
		return false
	var cell = board[p.y][p.x]
	var cond = cell.ispipe
	cond = cond and (!cell.istarget or cell.target.transaction_id == trans_id)
	cond = cond and (cell.agent == null or !cell.agent.is_taxi)
	return cond
		
func find_agent_path_index(agent):
	var idx := -1
	for i in range(agent.path.size()):
		if agent.board_pos.distance_to(agent.path[i]) == 0:
			idx = i
	return idx

var last_major_tick := 0.0
var last_one_sec_tick := 0.0

func tick():
	if game.level_is_done or !game.level_is_ready or game.paused():
		return

	if TaxiG.num_delivered_passengers_in_this_level >= TaxiG.num_delivered_passengers_for_next_level:
		level_is_done(true)
		return

	var now = game.game_time
	var is_one_sec_tick:bool = now - last_one_sec_tick > 1000
	if is_one_sec_tick:
		last_one_sec_tick = now
		var any_active := false
		for t in taxis:
			if !t.out_of_gas:
				any_active = true
				break
		if !any_active:
			game.add_score_and_time(-1,-4)

	var is_major_tick = now - last_major_tick > game.major_tick_time_ms * game.time_scale
	if !is_major_tick:
		return
	last_major_tick = now
	for agent in agents:
		if agent.is_embarking:
			continue
		if agent.is_taxi:
			if agent.out_of_gas:
				continue
			if agent.is_blocked:
				score_idle_one_tick()
				taxi_recalc_path(agent)
				continue
			var p = agent.board_pos
			var path_idx = find_agent_path_index(agent)
			var path_dir := -1
			if path_idx >= 0:
				if path_idx+1 < agent.path.size():
					var path_q = agent.path[path_idx+1]
					agent.path = agent.path.slice(path_idx+1)
					path_dir = game.dt_to_dir(path_q - agent.board_pos)
					if (path_dir + 2) % 4 == agent.direction:
						path_dir = agent.direction
					if !can_go_to(path_q,agent.transaction_id):
						agent.set_blocked(true)						
						game.play_sound("honk")
						continue
					agent.direction = path_dir
					agent.set_rot(path_dir)
					agent.set_board_pos(path_q)
					board[p.y][p.x].agent = null
					board[path_q.y][path_q.x].agent = agent
					score_moved_one_pos()
					continue
			check_taxi(agent)	
		else:	# not a taxi
			if agent.transaction_id >= 0 and agent.board_pos == agent.dropoff_pos:
				agent.mark_arrived()
				
				
# func taxi_is_just_stopped(taxi):
# 	taxi.is_moving = false
# 	if taxi.transaction_id >= 0:
# 		taxi.set_blocked(true)
# 		# taxi_recalc_path(taxi)

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
			
func _on_level_done_popup_closed():
	sig_level_is_done.emit(true)

func level_is_done(didwin: bool):
	game.level_is_done = true
	game.stop_sound("motor")
	BE.send_event("level_done", "Taxi", {
		"level": level,
		"didwin": int(didwin),
	})
	start_dispatch = false
	if didwin:
		MainGlobals.global_level_is_done(true)
		game.need_to_increase_level = true
		num_of_taxis += 1
		if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
			MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
		game.show_level_done_popup(self, "","", level)
	else:
		# MainGlobals.sleep(1.0)
		sig_level_is_done.emit(didwin)

func increase_difficulty(increase=true):
	if game == null:
		return
	if increase and level < 9:
		level += 1
	var s = 29 + level * 2
	game.max_board_size = Vector2i(s,s)
	if level == 1:
		time_between_dispatches_ms = 5000
		game.forced_board_size = Vector2i(21,21)
		num_of_taxis = 4
	elif level == 2:
		time_between_dispatches_ms = 2500
		game.forced_board_size = Vector2i(23,23)
	elif level == 3:
		time_between_dispatches_ms = 3500
		game.forced_board_size = Vector2i(25,25)
	elif level == 4:
		time_between_dispatches_ms = 2500
		game.forced_board_size = Vector2i(27,27)
	elif level == 5:
		time_between_dispatches_ms = 3000
		game.forced_board_size = Vector2i(29,29)
	elif level == 6:
		time_between_dispatches_ms = 3000
		game.forced_board_size = Vector2i(31,31)
	elif level == 7:
		time_between_dispatches_ms = 3000
		game.forced_board_size = Vector2i(31,31)
	elif level == 8:
		time_between_dispatches_ms = 2000
		game.forced_board_size = Vector2i(31,31)
	elif level >= 9:
		time_between_dispatches_ms = 2000
		game.forced_board_size = Vector2i(31,31)
	if MainGlobals.is_mobile():
		var bsh = 10
		var bsv = 6
		game.max_board_size -= Vector2i(bsh,bsv)
		game.forced_board_size -= Vector2i(bsh, bsv)
	game.init_sizes()

func add_mission(p, dir):
	var sender = find_closest_target(p, false)	
	var receiver = null
	var taridxs = range(0, targets.size())
	taridxs.shuffle()
	for i in taridxs:
		var t = targets[i]
		if t.board_pos != sender.board_pos and !t.is_receiver and !t.is_sender and !t.is_gas_station:
			receiver = t
			var color = game.next_color()
			var transaction_id = next_transaction_id
			next_transaction_id += 1
			receiver.set_receiver(true, color, transaction_id)
			sender.set_sender(true, color, transaction_id)
			sender.modulate = Color(1,1,1,1)
			receiver.modulate = Color(1,1,1,1)
			dict_tran_id_to_target[transaction_id] = receiver
			game.play_sound("dispatch")
			sender.flash(1)
			add_agent_at(p, dir, color, sender, receiver)
			return

var time_last_dispatch = -10000
var pos_last_dispatch = Vector2i(-1,-1)
# While a tutorial runs, customers arrive only when the coach asks for one. On the level-1 timer a
# customer turns up every 5 s, which buries a lesson in arrivals it never asked for and leaves the
# board in a state the next step cannot talk about.
var tutorial_hold_dispatch: bool = false

# Everything the automatic dispatch does, on demand. Returns false if the city had no free start
# tile to use, so a caller can try again rather than assume a customer is now waiting.
func tutorial_request_customer() -> bool:
	var shuffled_idx: Array = range(0, agent_start_positions.size())
	shuffled_idx.shuffle()
	for idx in shuffled_idx:
		var p = agent_start_positions[idx]
		var dir = agent_start_directions[idx]
		if board[p.y][p.x].agent != null:
			continue
		var t = find_closest_target(p, false)
		if t == null or t.is_receiver or t.is_sender:
			continue
		add_mission(p, dir)
		time_last_dispatch = game.game_time
		pos_last_dispatch = p
		return true
	return false

# A tank the fuel lesson can actually point at. Left near empty rather than empty: out_of_gas
# latches and that taxi is stranded for good, which is the thing being taught, not demonstrated on
# the player's own taxi mid-lesson.
func tutorial_drain_taxi(taxi, level_frac: float = 0.3) -> void:
	if taxi == null or not is_instance_valid(taxi):
		return
	taxi.set_fuel_level(level_frac)
	taxi.disp_gas_level()

# A taxi that is doing nothing: no fare, nobody aboard, not already heading for a pump. The fuel
# lesson has to use one of these. Draining whichever taxi came first could hit the one still
# delivering the fare from the previous step, which then burns the little fuel it was left with and
# strands mid-street — out_of_gas taxis cannot even be tapped, so the lesson became impossible.
func tutorial_idle_taxi():
	for t in taxis:
		if not is_instance_valid(t) or t.out_of_gas:
			continue
		if t.transaction_id >= 0 or t.going_to_fill_gas:
			continue
		if t.passangers.size() > 0:
			continue
		return t
	return null

# The fare's counterparts, so the coach can keep its caption off them: who is waiting, where they
# were picked up, and where they are going.
func tutorial_waiting_customer():
	for a in agents:
		if is_instance_valid(a) and not a.is_taxi and a.assigned_to_taxi == null:
			return a
	return null

func tutorial_active_customer():
	for a in agents:
		if is_instance_valid(a) and not a.is_taxi:
			return a
	return null

func tutorial_active_sender():
	for t in targets:
		if is_instance_valid(t) and t.is_sender:
			return t
	return null

func tutorial_active_receiver():
	for t in targets:
		if is_instance_valid(t) and t.is_receiver:
			return t
	return null

# Traffic jams are rule 3 of the game and the tutorial does not teach them until the very end — so
# a taxi blocked by another one mid-fare simply deadlocks the lesson, and the player has to work
# out for themselves that they must select the blocker and drive it away. Here the coach clears it
# instead: whatever is sitting on the next tile gets sent somewhere else, using the game's own
# dispatch, so the jam resolves the way it would if a player had done it.
# Returns true when something was actually moved.
func tutorial_unblock() -> bool:
	for t in taxis:
		if not is_instance_valid(t) or t.out_of_gas or not t.is_blocked:
			continue
		var idx: int = find_agent_path_index(t)
		if idx < 0 or idx + 1 >= t.path.size():
			continue
		var q = t.path[idx + 1]
		var blocker = board[q.y][q.x].agent
		if blocker == null or not is_instance_valid(blocker) or blocker == t:
			continue
		if not blocker.is_taxi or blocker.out_of_gas or blocker.transaction_id >= 0:
			continue
		var idxs: Array = range(0, agent_start_positions.size())
		idxs.shuffle()
		for i in idxs:
			var p = agent_start_positions[i]
			if board[p.y][p.x].agent != null:
				continue
			if p == q or p == t.board_pos:
				continue
			var path = send_taxi_to(blocker, p)
			if path.size() > 1:
				return true
	return false

# A taxi the coach can point at or keep its caption off. Skips stranded ones: they cannot be
# tapped at all (on_taxi_pressed returns early when out_of_gas).
func tutorial_any_taxi():
	for t in taxis:
		if is_instance_valid(t) and not t.out_of_gas:
			return t
	return null

# The nearest gas station to a taxi, for the step that says to send it refuelling.
func tutorial_gas_station():
	for t in targets:
		if t.is_gas_station:
			return t
	return null

# increase_difficulty() only resets num_of_taxis on level 1, so a tutorial that leaves it at 1
# hands the player a one-taxi city on their next real game. Stashed here and put back by
# tutorial_restore(), which main.gd calls on both exit paths.
var _tutorial_saved_num_taxis: int = -1

func tutorial_restore() -> void:
	if _tutorial_saved_num_taxis >= 0:
		num_of_taxis = _tutorial_saved_num_taxis
		_tutorial_saved_num_taxis = -1
	tutorial_hold_dispatch = false

func _tutorial_setup() -> void:
	tutorial_hold_dispatch = true
	if _tutorial_saved_num_taxis < 0:
		_tutorial_saved_num_taxis = num_of_taxis
	# ONE taxi. can_go_to() only refuses a tile occupied by another taxi, so a single taxi cannot
	# be blocked by anything — customers do not block. A jam mid-fare deadlocked the lesson: the
	# player had to work out for themselves that they must select the blocker and drive it away,
	# which is rule 3 and is not taught until the very end. One taxi also makes "this is one of
	# your taxis" unambiguous, and it is the same taxi for the fare, the fuel and the pump.
	num_of_taxis = 1

func _on_agent_dispatch_timer_timeout() -> void:
	if tutorial_hold_dispatch:
		return
	if start_dispatch and !game.paused():
		var tm = game.game_time
		if tm - time_last_dispatch >= time_between_dispatches_ms:
			time_last_dispatch = tm
			var p
			var dir
			var got_p = false
			var shuffled_idx = range(0, agent_start_positions.size())
			shuffled_idx.shuffle()
			for idx in shuffled_idx:
				p = agent_start_positions[idx]
				dir = agent_start_directions[idx]
				if board[p.y][p.x].agent != null:
					continue
				if (pos_last_dispatch - p).length() > 4:
					var t = find_closest_target(p, false)
					if t.is_receiver or t.is_sender:
						continue
					got_p = true
					break
			if got_p:
				pos_last_dispatch = p
				add_mission(p, dir)
		
func on_agent_remove_agent(agent_id, arrived):	
	for i in range(agents.size() - 1, -1, -1):
		if agents[i].agent_id == agent_id:
			board[agents[i].board_pos.y][agents[i].board_pos.x].agent = null
			if !agents[i].is_taxi:
				for t in taxis:
					if agents[i] in t.passangers:
						t.passangers.erase(agents[i])
						# Log.dbg("erasing from passenger list")
			agents[i].queue_free()
			agents.remove_at(i)
			if not arrived:
				pass
			break	
	for i in range(taxis.size() - 1, -1, -1):
		if taxis[i].agent_id == agent_id:
			taxis.remove_at(i)

func drop_off(taxi, agent):
	taxi.assign_customer(null)
	var receiver = dict_tran_id_to_target.get(taxi.transaction_id, null)
	if receiver != null:
		if taxi.board_pos == receiver.dropoff_pos:
			score_delivered_passenger()
			TaxiG.num_delivered_passengers_in_this_level += 1
			game.play_sound("delivery")
			taxi.remove_child(agent)
			taxi.passangers.erase(agent)
			taxi.set_blocked(false)
			add_child(agent)

			agent.position = game.board_to_px(taxi.board_pos)
			taxi.is_embarking = true
			agent.is_embarking = true
			var dt = game.major_tick_time_ms * game.time_scale / 1000.0
			var tween_pos = MainGlobals.make_tween()
			tween_pos.tween_property(agent, "position", game.board_to_px(receiver.board_pos), dt)
			tween_pos.tween_callback(func(): finish_drop_off(taxi,agent))
			var tween_scale = MainGlobals.make_tween()
			tween_scale.tween_property(agent, "scale", Vector2(1,1), dt)

func finish_drop_off(taxi, agent):
	# var receiver = dict_tran_id_to_target.get(taxi.transaction_id, null)
	# agent.scale = Vector2(1,1)
	taxi.is_embarking = false
	agent.is_embarking = false
	agent.being_carried = false
	# agent.set_rot(game.dt_to_dir(receiver.board_pos - receiver.lobby_pos))
	# agent.position = game.board_to_px(receiver.lobby_pos)
	# agent.set_board_pos(receiver.lobby_pos)
	board[agent.board_pos.y][agent.board_pos.x].agent = agent
	taxi.assign(-1)
	agent.assign_taxi(null)
	agent.mark_arrived()
	# agent.set_target_pos(game.board_to_px(receiver.board_pos))
	agent.speed_scale = 0.2

func on_agent_finished_arriving(agent):
	for t in targets:
		if t.transaction_id == agent.transaction_id:
			t.reset_sender_receiver()

func pick_up(taxi, agent):
	taxi.assign_customer(null)
	agent.life_time_ms = 0
	taxi.is_embarking = true
	agent.is_embarking = true
	# finish_pick_up(taxi,agent)
	var dt = game.major_tick_time_ms * game.time_scale / 1000.0
	var tween_pos = MainGlobals.make_tween()
	tween_pos.tween_property(agent, "position", game.board_to_px(taxi.board_pos), dt)
	tween_pos.tween_callback(func(): finish_pick_up(taxi,agent))
	var tween_scale = MainGlobals.make_tween()
	var oldscale = agent.scale
	tween_scale.tween_property(agent, "scale", oldscale * 0.6, dt)
	game.play_sound("swoosh")

func finish_pick_up(taxi, agent):
	if taxi == null or taxi.out_of_gas or agent == null:
		return
	taxi.is_embarking = false
	agent.is_embarking = false
	var receiver = dict_tran_id_to_target.get(agent.transaction_id, null)
	if receiver != null:
		receiver.flash(4)
	board[agent.board_pos.y][agent.board_pos.x].agent = null
	remove_child(agent)
	taxi.add_child(agent)
	taxi.dropoff_pos = agent.dropoff_pos
	agent.set_rot(taxi.direction)
	score_picked_passenger()
	game.tutorial_notify("picked_up")           # no-op outside tutorial mode
	agent.being_carried = true
	taxi.passangers.append(agent)
	agent.position = Vector2.ZERO
	# agent.scale = Vector2(0.4,0.4)
	if taxi.goal_pos.size() > 0:
		var end = taxi.goal_pos[0]
		if end == taxi.board_pos:
			return
		var path = send_taxi_to(taxi,end)
		if path.size() <= 1:
			var p = end
			var a = board[p.y][p.x].agent
			if a != null and a.is_taxi:
				var save_agent = board[p.y][p.x].agent
				board[p.y][p.x].agent = null
				path = send_taxi_to(taxi,p)
				board[p.y][p.x].agent = save_agent
		if path.size() <= 1:
			taxi.set_blocked(true)
			game.play_sound("honk")
	else:
		taxi.set_blocked(false)

# func check_agent_collisions():
# 	for i in agents.size():
# 		var a1 = agents[i]
# 		if !a1.was_hit and !a1.arrived:set_blocked(false)
# 			var p1 = a1.board_pos
# 			if board[a1.board_pos.y][a1.board_pos.x].isbomb:
# 				a1.mark_hit()
# 				if !$ExplosionAudio.playing:
# 					$ExplosionAudio.play()
# 				collision.emit()
# 			for j in agents.size():
# 				if i != j:
# 					var a2 = agents[j]
# 					if !a2.was_hit and !a2.arrived:
# 						var p2 = a2.board_pos
# 						if p1.distance_to(p2) < game.tile_size * 3:
# 							var d = a1.distance_to(a2)
# 							if d < game.tile_size/4.0:
# 								a1.mark_hit()
# 								a2.mark_hit()
# 								if !$ExplosionAudio.playing:
# 									$ExplosionAudio.play()
# 								collision.emit()

func on_taxi_started_moving(_transaction_id):
	pass

func on_agent_started_moving(_transaction_id):	
	pass
	
func find_selected_taxi():
	for a in agents:
		if a.is_taxi and a.is_selected:
			return a
	return null

func on_taxi_pressed(taxi):
	if taxi.out_of_gas or taxi.is_filling_gas:
		return
	if taxi.transaction_id >= 0:
		if taxi.passangers.size() == 0:
			# Pressing an assigned taxi that has not picked anyone up CANCELS the job. That is the
			# clearest signal available here of a plan the player had to undo.
			game.record_count("jobs_cancelled")
			for a in agents:
				if !a.is_taxi and a.transaction_id == taxi.transaction_id:
					a.assign_taxi(null)
					break
			taxi.assign(-1)
		return
	if taxi.is_selected:
		taxi.set_selected(false)
	else:
		for a in taxis:
			if a.is_selected and a != taxi:
				a.set_selected(false)
		taxi.set_selected(true)
		game.tutorial_notify("taxi_selected")   # no-op outside tutorial mode

func on_agent_pressed(agent):
	# Log.dbg("pressed agent at ", agent.board_pos)
	if agent.assigned_to_taxi == null:
		var taxi = find_selected_taxi()
		if taxi != null:
			move_taxi_to_agent(taxi, agent)

func move_taxi_to_agent(taxi, agent):
	game.record_count("jobs_assigned")
	agent.assign_taxi(taxi)
	taxi.assign_customer(agent)
	var trans_id = agent.transaction_id
	taxi.set_selected(false)
	taxi.assign(trans_id)
	var added_to_goals := 1
	taxi.goal_pos.append(agent.waiting_pos)
	var receiver = dict_tran_id_to_target.get(trans_id, null)
	if receiver != null:
		taxi.goal_pos.append(receiver.dropoff_pos)
		added_to_goals += 1
	var start = taxi.board_pos
	var end = taxi.goal_pos[0]
	if start == end:
		taxi.goal_pos.pop_front()
		game.tutorial_notify("customer_assigned")   # no-op outside tutorial mode
		pick_up(taxi,agent)
		return
	var path = send_taxi_to(taxi,end)
	if path.size() <= 1:
		var p = end
		var a = board[p.y][p.x].agent
		if a != null and a.is_taxi:
			var save_agent = board[p.y][p.x].agent
			board[p.y][p.x].agent = null
			path = send_taxi_to(taxi,p)
			board[p.y][p.x].agent = save_agent
	if path.size() <= 1:
		taxi.assign(-1)
		taxi.assign_customer(null)
		agent.assign_taxi(null)
		taxi.goal_pos.pop_back()
		if added_to_goals > 1:
			taxi.goal_pos.pop_back()
	taxi.set_selected(false)

	# Only once the assignment has actually stuck: above, a taxi with no route to the customer has
	# its transaction rolled back, and a coach told to wait for the pickup would wait forever.
	if path.size() > 1:
		game.tutorial_notify("customer_assigned")   # no-op outside tutorial mode

	draw_path(path)	
	return path

func on_time_over():
	can_use_state = false
	game.stop_sound("motor")

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

func draw_path(path):
	if allow_draw_path:
		for p in path:
			if board[p.y][p.x].ispipe:
				board[p.y][p.x].pipe.show_path(1)

func calc_cost_to_move_to(prev_pos: Vector2i, from: Vector2i, to:Vector2i, transaction_id: int, _goal: Vector2i):
	# Log.dbg("to ",to, " in_board ",game.in_board(to), " ispipe ", board[to.y][to.x].ispipe)
	if !game.in_board(to) or !board[to.y][to.x].ispipe:
		return -1
	var cost_to_return_if_ok = 1
	if prev_pos == to:
		cost_to_return_if_ok = 500
	var tocell = board[to.y][to.x]
	if tocell.istarget:
		var trans_id = tocell.target.transaction_id
		if trans_id != transaction_id:
			return -1
	if tocell.agent != null:
		if tocell.agent.transaction_id < 0 or tocell.agent.transaction_id != transaction_id:
			return -1
	if board[from.y][from.x].door_type == 1:	#door slanted from topleft to bottomright
		if prev_pos.x > from.x:		# comes from the right
			return -1 if to.y >= from.y else 1
		elif prev_pos.x < from.x:	# comes from the left
			return -1 if to.y <= from.y else 1
		elif prev_pos.y < from.y:	# comes from top to bottm
			return -1 if to.x <= from.x else 1
		else:						# comes from bottom to top
			return -1 if to.x >= from.x else 1
	elif board[from.y][from.x].door_type == 2:	#door slanted from topright to bottomleft
		if prev_pos.x > from.x:		# comes from the right
			return -1 if to.y <= from.y else 1
		elif prev_pos.x < from.x:	# comes from the left
			return -1 if to.y >= from.y else 1
		elif prev_pos.y < from.y:	# comes from top to bottm
			return -1 if to.x >= from.x else 1
		else:						# comes from bottom to top
			return -1 if to.x <= from.x else 1
	return cost_to_return_if_ok
	
func _on_agent_timeout(_agent):
	for t in targets:
		if t.transaction_id == _agent.transaction_id:
			t.reset_sender_receiver()
	game.play_sound("customer_gaveup")
	score_passenger_gave_up()

func _is_cell_empty(_board_pos):
	var cell = board[_board_pos.y][_board_pos.x]
	var full = cell.agent != null or cell.target != null or cell.isbomb or !cell.ispipe
	return not full

func _is_one_way(p):
	var n := -1		# start with -1 to consider center point
	for dv in game.DirArray:
		var q = p + dv
		if game.in_board(q) and board[q.y][q.x].ispipe:
			n += 1
	return n <= 1

func _on_pipe_pressed(_board_pos):
	if !_is_cell_empty(_board_pos):
		return
	# Log.dbg("pipe pressed at board pos ", _board_pos, " screen pos ", game.board_to_px(_board_pos))
	var taxi = find_selected_taxi()
	if taxi != null:
		if _is_one_way(_board_pos):
			return
		for l in target_lobbies:
			if l == _board_pos:
				return
		send_taxi_to(taxi, _board_pos)
		# Log.dbg("_on_pipe_pressed: unselecting taxi")

func send_taxi_to(taxi, _board_pos):
	var start = taxi.board_pos
	var end = _board_pos
	var prev_pos = game.next_board_pos(start, (taxi.direction + 2) % 4)
	var agent = board[end.y][end.x].agent
	board[end.y][end.x].agent = null
	var path = game.astar(start, end, Callable(self, "calc_cost_to_move_to"), taxi.transaction_id, prev_pos)
	board[end.y][end.x].agent = agent
	taxi.path = path
	taxi.set_selected(false)
	if path.size() > 1:
		draw_path(path)
		if path.size() > 2 or agent == null:
			taxi.set_blocked(false)
	return path

func score_delivered_passenger():	
	game.add_score_and_time(200,10)	
	game.tutorial_notify("delivered")           # no-op outside tutorial mode

func score_moved_one_pos():
	game.add_score_and_time(-2,0)

func score_idle_one_tick():
	game.add_score_and_time(-1,0)

func score_bought_gas():
	game.add_score_and_time(-100,0)

func score_bought_taxi():
	game.add_score_and_time(-TaxiG.prices_for_taxi,0)

func score_taxi_ran_out_of_gas():
	game.add_score_and_time(-500,0)

func score_passenger_gave_up():
	game.add_score_and_time(-50,0)

func score_picked_passenger():
	game.add_score_and_time(20,0)

func on_out_of_gas(taxi):
	game.play_sound("breakdown")
	if taxi.is_selected:
		taxi.set_selected(false)
	if taxi.is_blocked:
		taxi.set_blocked(false)
	var lost_score = 1000
	if taxi.passangers.size() > 0:
		lost_score += 50
	game.add_score_and_time(-lost_score,0)
	game.kill_and_did_lives_run_out()
	MainGlobals.global_update_hud()
	for t in taxis:
		if !t.out_of_gas:
			return
	if game.score > TaxiG.prices_for_taxi:
		return
	game.game_is_done(false, false)

func on_clicked_target(target):
	if target: 
		if target.is_gas_station:
			var taxi = find_selected_taxi()
			if taxi != null:
				taxi.going_to_fill_gas = true
				send_taxi_to(taxi, target.dropoff_pos)
				game.tutorial_notify("sent_to_gas")   # no-op outside tutorial mode
		elif target.is_sender:
			for a in agents:
				if !a.is_taxi and a.transaction_id == target.transaction_id:
					on_agent_pressed(a)
					return

# TEMPORARY DIAGNOSTIC — see taxi/scripts/tutorial.gd. Reports why a taxi with a job is not
# advancing: tick() moves one only when it is unblocked, standing ON its own path, and the next
# cell of that path is drivable.
func tutorial_assigned_taxi():
	for t in taxis:
		if is_instance_valid(t) and t.transaction_id >= 0:
			return t
	return null

func tutorial_taxi_state(taxi) -> String:
	var idx: int = find_agent_path_index(taxi)
	var bits: Array = []
	bits.append("blocked=%s" % str(taxi.is_blocked))
	bits.append("gas=%.0f%%" % (float(taxi.fuel_level) * 100.0))
	bits.append("path=%d idx=%d" % [taxi.path.size(), idx])
	if idx < 0:
		bits.append("NOT ON ITS PATH")
	elif idx + 1 >= taxi.path.size():
		bits.append("AT PATH END")
	else:
		var q = taxi.path[idx + 1]
		var cell = board[q.y][q.x]
		var why: String = "ok"
		if not cell.ispipe:
			why = "no road"
		elif cell.istarget and cell.target.transaction_id != taxi.transaction_id:
			why = "another job's gate"
		elif cell.agent != null and cell.agent.is_taxi:
			why = "another taxi"
		bits.append("next %s: %s" % [str(q), why])
	return "  ".join(bits)

func check_taxi(taxi):
	if !taxi.is_taxi:
		return
	if taxi.transaction_id >= 0:
		var agent = taxi.assigned_to_customer
		if agent != null:
			if agent.transaction_id == taxi.transaction_id and agent.waiting_pos == taxi.board_pos:
				taxi.goal_pos.pop_front()
				pick_up(taxi, agent)
		elif taxi.passangers.size() > 0:
			agent = taxi.passangers[0]
			if agent != null and agent.being_carried and agent.transaction_id == taxi.transaction_id and\
				agent.dropoff_pos == taxi.board_pos:
				taxi.goal_pos.pop_front()
				drop_off(taxi, agent)		
		# if taxi.goal_pos.size() > 0:
		# 	var p1 = taxi.position
		# 	var p2 = game.board_to_px(taxi.goal_pos[0])
		# 	if p1.distance_to(p2) < game.tile_size/32.0:
		# 		for agent in agents:
		# 			if !agent.is_taxi and agent.transaction_id == taxi.transaction_id:
		# 				taxi.goal_pos.pop_front()
		# 				if agent.being_carried:
		# 					drop_off(taxi, agent)
		# 				elif agent.waiting_pos == taxi.board_pos:
		# 					pick_up(taxi, agent)
	else:
		if !taxi.going_to_fill_gas:
			taxi.set_blocked(false)
		if taxi.going_to_fill_gas and taxi.path.size() <= 1:
			for g in gas_stations:
				if g.dropoff_pos == taxi.board_pos:
					taxi.start_filling_gas(g)
					break

func on_finished_filling_gas(_taxi, percentage_filled):
	var full_tank_price = 100
	game.add_score_and_time(ceili(-full_tank_price * percentage_filled), 0)
	game.tutorial_notify("gas_filled")   # no-op outside tutorial mode
	# Log.dbg("done filling gas")

func buy_taxi():
	if game.score > TaxiG.prices_for_taxi:
		var shuffled_idx = range(0, agent_start_positions.size())
		var retries = 1000
		shuffled_idx.shuffle()
		while retries > 0:
			retries -= 1
			var idx = shuffled_idx.pop_front()
			var dir = agent_start_directions[idx]
			var p = game.next_board_pos(agent_start_positions[idx], dir)
			if board[p.y][p.x].agent != null:
				continue
			var can_use_this := true
			for t in targets:
				if t.is_gas_station and (t.lobby_pos == p or t.dropoff_pos == p):
					can_use_this = false
					break
			if can_use_this:
				add_taxi_at(p, (dir+1)%4)
				# game._reset_lives_val += 1
				game.lives_left += 1
				score_bought_taxi()
				MainGlobals.global_update_hud()
				return

# func get_board_state() -> Array:
# 	var result: Array = []
# 	for row: Array in board:
# 		var row_state: Array = []
# 		for cell: OneCell in row:
# 			row_state.append(cell.get_state())
# 		result.append(row_state)
# 	return result

# func set_board_state(_state: Array) -> void:
# 	for y in _state.size():
# 		for x in _state[y].size():
# 			board[y][x].set_state(_state[y][x])

func get_state() -> Dictionary:
	if !can_use_state:
		start_with_state = {}
		return {}
	var taxi_states = []
	for t in taxis:
		taxi_states.append({
			"fuel": t.fuel_level,
			"board_pos": SaveManager.v2i_d(t.board_pos),
			"dir": t.direction,			
		})
	var gas_station_states = []
	for g in gas_stations:
		gas_station_states.append({
			"board_pos": SaveManager.v2i_d(g.board_pos),
		})
	var s = {
		"score": game.score,
		"time_left": game.time_left_sec,
		"level": level,
		"taxis": taxi_states,
		"gas_stations": gas_station_states,
		"time_scale": game.time_scale,
	}
	start_with_state = s
	return s

func set_state(_state: Dictionary):
	start_with_state = _state
	if _state.size() == 0:
		can_use_state = false

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
	GrassField.fit(self, get_node_or_null("TextureRect") as CanvasItem, game, 20)

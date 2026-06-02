extends CanvasLayer

enum Dirs {right=0,down=1,left=2,up=3}
enum DoorTypes {open=0, backslash=1, slash=2}

var rng = RandomNumberGenerator.new()		

var game: GenericGameUtil

class OneCell:
	var ispipe := false
	var door_type := -1
	var has_agent := false
	var istarget := false
	var isbomb := false
	var target
	var pipe
	
var allow_show_path := false
var start_dispatch := false
var time_between_dispatches_ms = 5000
var board: Array
var agents = []
var targets = []
var target_positions = []
var target_lobbies = []
var pipes = []
var empties = []
var doors = []
var bombs = []
# var transaction_ids = []
# var next_transaction_id_idx = 0
var agent_start_positions = []
var agent_start_directions = []
var time_started_level_ms = 0
var time_increased_difficulty_ms = 0
var level := 0
var num_more_packets = 0
var max_speed_scale = 1.0
var num_parking_types := 3
var num_bombs_to_use := 3
var num_blocks := 20

var dict_tran_id_to_target = {}

@export var pipe_scene: PackedScene = load("res://parkem/scenes/pipe.tscn")
@export var empty_scene: PackedScene = load("res://parkem/scenes/empty_space.tscn")
@export var agent_scene: PackedScene = load("res://parkem/scenes/agent.tscn")
@export var door_scene: PackedScene = load("res://parkem/scenes/door.tscn")
@export var target_scene: PackedScene = load("res://parkem/scenes/target.tscn")
@export var bomb_scene: PackedScene = load("res://scenes/bomb_scene.tscn")

var dispatch_audio := preload("res://art/sounds/kenney/Audio/impactBell_heavy_003.ogg")
var parked_audio := preload("res://art/sounds/bump-sound-7.mp3")
var delivery_audio := preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var door_audio := preload("res://art/sounds/door-open-sound-1.mp3")
var motor_audio := preload("res://art/sounds/car-ambient-driving.ogg")
var explosion_audio := preload("res://art/sounds/car-crash-1.mp3")
var swoosh_audio := preload("res://art/sounds/swoosh.mp3")

signal started_playing
signal sig_level_is_done(didwin:bool)
signal delivered_one
signal collision

func _ready() -> void:
	game = ParkemG.game
	game.time_to_auto_start_moving_ms = 500
	game.sig_time_over.connect(on_time_over)
	level = ParkemG.starting_level
	increase_difficulty(false)

	$DoorAudio.stream = door_audio
	$MotorAudio.stream = motor_audio
	motor_audio.loop = true

	$DispatchAudio.stream = dispatch_audio
	$DeliveryAudio.stream = delivery_audio
	$ParkedAudio.stream = parked_audio
	$ExplosionAudio.stream = explosion_audio
	$SwooshAudio.stream = swoosh_audio

func new_game(from_scratch=true):
	game.level_is_ready = false
	if from_scratch:
		level = ParkemG.starting_level
	increase_difficulty(game.need_to_increase_level)
	game.need_to_increase_level = false
	time_last_dispatch = -10000
	pos_last_dispatch = Vector2i(-1,-1)
	create_board()
	time_started_level_ms = MainGlobals.timems()
	time_increased_difficulty_ms = time_started_level_ms
	# $HUD.new_game()
	started_playing.emit()
	BE.upsert_game_state("Parkem", 
		{"state":"new","starting_level": level, "num_packets": ParkemG.num_packets})
	if !$MotorAudio.playing:
		$MotorAudio.play()

# func _input(event) -> void:
# 	if MainGlobals.ignore_keyboard_actions:
# 		return
# 	game.handle_event(event,self)

func _process(_delta: float) -> void:
	check_agent_collisions()
	
func add_pipe(p):
	board[p.y][p.x].ispipe = true
	var pipe = pipe_scene.instantiate()
	board[p.y][p.x].pipe = pipe
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
				
func _is_cell_empty(_board_pos):
	var cell = board[_board_pos.y][_board_pos.x]
	if !cell.ispipe:
		return false
	var full = cell.has_agent or cell.istarget or cell.isbomb or cell.pipe.blocked
	return not full

func create_board() -> void:
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
	pipes.clear()
	empties.clear()
	agents.clear()
	doors.clear()
	bombs.clear()
	targets.clear()
	target_positions.clear()
	target_lobbies.clear()

	agent_start_positions = []
	agent_start_directions = []

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

	# transaction_ids = range(0, num_parking_types)
	# transaction_ids.shuffle()

	dict_tran_id_to_target = {}
	var found_targets := 0
	var minx = 1000
	var miny = 1000
	var receivers = []
	var retries := 0
	while found_targets < num_parking_types and retries < 1000:
		retries += 1
		var trans_id = found_targets
		var p:Vector2i = Vector2i(game.board_size.x-1, game.board_size.y-1)
		var dp:Vector2i = Vector2i(int((trans_id + 1) / 2), int((trans_id) / 2))
		var t = find_closest_non_allocated_target(p-dp)
		t.set_receiver(true, game.color_by_index(trans_id), trans_id)
		receivers.append(t)
		minx = min(t.board_pos.x, minx)
		miny = min(t.board_pos.y, miny)
		dict_tran_id_to_target[trans_id] = t
		found_targets += 1

	for row in range(1,game.board_size.y-1):
		for col in range(1,game.board_size.x-1):
			if row % 2 == 0 or col % 2 == 0 or (row > 2 and col > 2 and 
				row < game.board_size.y-2 and col < game.board_size.x-2):
				add_pipe(Vector2i(col,row))
	
	for row in game.board_size.y:
		for col in game.board_size.x:
			if !board[row][col].ispipe:
				add_empty(Vector2i(col,row))
	
	for e in empties:
		e.show_hide_walls(board)
				
	for pipe in pipes:
		pipe.set_rot(board)

	var r
	var c
	if false:
		var nbombs = num_bombs_to_use + 2
		while nbombs > 0:
			if nbombs == 1:
				r = rng.randi_range(4, int(miny/2)-2)*2+1
				c = game.board_size.x-3
			elif nbombs == 2:
				c = rng.randi_range(4, int(minx/2)-2)*2+1
				r = game.board_size.y-3
			else:
				var m = 3
				r = rng.randi_range(m, game.board_size.y-m-1)
				c = rng.randi_range(m, game.board_size.x-m-1)
			var px = game.board_to_px(Vector2i(c,r))
			var bomb = bomb_scene.instantiate()
			bombs.append(bomb)
			add_child(bomb)
			board[r][c].isbomb = true
			bomb.z_index = 101
			bomb.modulate = Color(1,0,0,1)
			bomb.find_child("AnimatedSprite2D").play("default")
			bomb.position = px
			nbombs -= 1		

	num_blocks = 10 if MainGlobals.is_mobile() else 20
	var th_blocks_on_sides = 2 if MainGlobals.is_mobile() else 10
	retries = 0
	var nblocks := num_blocks
	var mar := 2
	var mar_in := 4
	var block_pos = []
	while nblocks > 0 and retries < 1000:
		retries += 1
		var horiz = game.rng.randi_range(0,1)
		var row:int
		var col:int
		if nblocks > th_blocks_on_sides:
			if horiz == 0:
				col = game.rng.randi_range(mar+1,game.board_size.x-2-mar) | 1
				row = game.rng.randi_range(0,1) * (game.board_size.y-1 - 2*mar) + mar
			else:
				row = game.rng.randi_range(mar+1,game.board_size.y-2-mar) | 1
				col = game.rng.randi_range(0,1) * (game.board_size.x-1 - 2*mar) + mar

			var all_far := true
			for _p in block_pos:
				if _p.distance_to(Vector2i(col,row)) < 2:
					all_far = false
					break
			if !all_far:
				continue
		else:
			row = game.rng.randi_range(mar_in+1,game.board_size.y-2-mar_in)
			col = game.rng.randi_range(mar_in+1,game.board_size.x-2-mar_in)
		var cell = board[row][col]
		if _is_cell_empty(Vector2i(col,row)) and cell.door_type <= 0:			
			cell.pipe.set_blocked(true)
			block_pos.append(Vector2i(col,row))
			nblocks -= 1

	# add doors			
	for row in game.board_size.y:
		for col in game.board_size.x:
			var p = Vector2i(col,row)
			if board[p.y][p.x].ispipe and _is_cell_empty(p):
				var nbranches = 0
				for d in game.DirArray:
					var q = p+d
					if game.in_board(q) and board[q.y][q.x].ispipe:
						nbranches += 1
				if nbranches > 2:
					var door_type = 0
					if game.in_board(p,3):
						door_type = max(0,rng.randi_range(-15,2))
					# if !game.in_board(p,2) or game.is_corner(p,3):
					# 	door_type = 0
					# else:
					# 	door_type = 0#rng.randi_range(0,2)
					add_door_at(p, door_type)	
										
	start_dispatch = true
	game.create_fill_screen_camera(self)
	game.level_is_ready = true

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

func find_closest_target(p):
	var d = 100
	var target
	for t in targets:
		var this_d = t.board_pos.distance_to(p)
		if this_d < d:
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
func add_agent_at(p: Vector2i, direction: int):
	var agent = agent_scene.instantiate()
	agent.body_ids = range(1, ParkemG.num_packets+1+num_more_packets)
	agent.direction = direction
	agent.board_pos = p
	# var rng = RandomNumberGenerator.new()
	# agent.speed_scale = rng.randf_range(0.8, max_speed_scale)
	add_child(agent)
	# agent.set_type(agent_type)
	agent.set_id(next_agent_id)
	next_agent_id += 1
	agent.agent_pressed.connect(on_agent_pressed)
	agent.sig_agent_started_moving.connect(on_agent_started_moving)
	agent.sig_agent_timeout.connect(_on_agent_timeout)
	board[p.y][p.x].has_agent = true
	# agent.hit.connect(on_agent_hit)
	agent.remove_agent.connect(on_agent_remove_agent)
	agents.append(agent)
	agent.set_pos(game.board_to_px(p), direction)
	var sender = find_closest_target(p)
	var transaction_id = rng.randi_range(0,num_parking_types-1)
	var color = game.color_by_index(transaction_id)
	sender.set_sender(true, color, transaction_id)
	# sender.modulate = Color(1,1,1,1)
	agent.transaction_id = transaction_id
	agent.set_color(color)
	agent.speed_scale = (max_speed_scale - 0.8) * transaction_id / (num_parking_types - 1) + 0.8
	if !$DispatchAudio.playing:
		$DispatchAudio.play()

	agent.path = find_agent_path(agent)
	if agent.path.size() > 1:
		var dt = agent.path[1] - agent.path[0]
		var dir = game.dt_to_dir(dt)
		if dir >= 0:
			agent.direction = dir
			
# func reset_sender_receiver(transaction_id):
# 	for t in targets:
# 		if t.transaction_id == transaction_id:
# 			t.reset_sender_receiver()

func on_door_type_changed(pos: Vector2i):
	for i in doors.size():
		var door = doors[i]
		if door.board_pos == pos:
			board[pos.y][pos.x].door_type = door.rot_idx
	for agent in agents:
		agent.path = find_agent_path(agent)

func on_clicked_door(pos: Vector2i):
	for i in doors.size():
		var door = doors[i]
		if door.board_pos == pos:
			var current = door.rot_idx
			var newdir = (current + 1) % 3
			if newdir == 0:
				newdir = 1
			door.set_rot(newdir,4000)
			board[pos.y][pos.x].door_type = newdir
			$DoorAudio.stop()
			$DoorAudio.play()
			break
	# for agent in agents:
	# 	agent.path = find_agent_path(agent)

func can_go_to(p, trans_id:int):
	if !game.in_board(p):
		return false
	var cell = board[p.y][p.x]
	var cond = cell.ispipe and !cell.pipe.blocked
	cond = cond and (!cell.istarget or cell.target.transaction_id == trans_id)
	return cond
	
func all_agents_done():
	if agents.size() == 0:
		return false
	for agent in agents:
		if !agent.arrived:
			return false
	return true
	
func find_agent_path_index(agent):
	var idx := -1
	for i in range(agent.path.size()):
		if agent.board_pos.distance_to(agent.path[i]) == 0:
			idx = i
	return idx
	# if idx < 0 or idx >= agent.path.size()-1:
	# 	return -1
	# return game.dt_to_dir(agent.path[idx+1]-agent.path[idx])

var last_major_tick_ms = -10000.0
func tick():
	if game.level_is_done:
		return
	var now = MainGlobals.timems()
	last_major_tick_ms = now
	if !game.level_is_ready:
		return

	var removed_agents = []
	for agent in agents:
		if agent.need_to_major_tick():
			agent.set_major_tick_now()
			var p = agent.board_pos
			if agent.arrived or agent.was_hit:
				continue
			var adj_tar_id = get_adjacent_target_id(p, agent)
			if adj_tar_id >= 0:
				game.inc_packet()
				game.add_score_and_time(-5,-10)
				MainGlobals.sig_global_update_hud.emit()
				delivered_transaction(agent.transaction_id)
				agent.mark_arrived()
				if !$ParkedAudio.playing:
					$ParkedAudio.play()
				continue
			if game.in_board(p):
				var dir = agent.direction
				var origdir = dir
				var vdir = game.DirArray[dir]
				var door_type = board[p.y][p.x].door_type
				var q = p + vdir
				var path_idx = find_agent_path_index(agent)
				var need_to_refind_path := false
				var path_q:Vector2i
				var path_dir := -1
				if path_idx >= 0 and path_idx < agent.path.size()-1:
					path_q = agent.path[path_idx+1]
					path_dir = game.dt_to_dir(path_q - agent.board_pos)
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
					if path_dir >= 0:
						if path_dir != dir and door_type != 0:
							need_to_refind_path = true
						else:
							q = path_q
							dir = path_dir
				else:		# if not a door
					if path_dir >= 0:
						q = path_q
						dir = path_dir
					if !can_go_to(q,agent.transaction_id):
						for diradd in [1,3]:
							var nextdir = (dir + diradd) % 4
							var nextvdir = game.DirArray[nextdir]
							q = p + nextvdir
							if can_go_to(q,agent.transaction_id):
								dir = nextdir
								break
				vdir = game.DirArray[dir]
				q = p + vdir
				if !can_go_to(q,agent.transaction_id):
					dir = (origdir + 2) % 4
					vdir = game.DirArray[dir]
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
				if need_to_refind_path:
					agent.path = find_agent_path(agent)

	for iremove in removed_agents.size():
		agents[iremove].queue_free()
		agents.remove_at(iremove)
		delivered_one.emit()

func delivered_transaction(transaction_id):
	for t in targets:
		if t.transaction_id == transaction_id:
			# if t.is_receiver:
			# 	t.set_receiver(false, Color.WHITE, transaction_id)
			if t.is_sender:
				t.set_sender(false, Color.WHITE, transaction_id)
				
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
	$MotorAudio.stop()	
	BE.send_event("level_done", "Parkem", {
		"level": level,
		"didwin": int(didwin),
	})
	start_dispatch = false
	if didwin:
		MainGlobals.global_level_is_done(true)
		game.need_to_increase_level = true
		if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
			MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
		game.show_level_done_popup(self, "","", level)
	else:
		# MainGlobals.sleep(1.0)
		sig_level_is_done.emit(didwin)

func increase_difficulty(increase=true):
	if game == null:
		return
	if increase:
		level += 1
		# MainGlobals.global_level_is_done(true)
		game.add_life()
	var s = 23#19 + level * 2
	game.max_board_size = Vector2i(s,s)
	if level == 1:
		time_between_dispatches_ms = 5000
		num_more_packets = 4
		max_speed_scale = 2.0
		num_bombs_to_use = 3
		game.set_num_packets(10)
	elif level == 2:
		time_between_dispatches_ms = 3500
		num_more_packets = 2
		max_speed_scale = 2.5
		num_bombs_to_use = 5
		game.set_num_packets(15)
	elif level == 3:
		time_between_dispatches_ms = 2500
		num_more_packets = 0
		max_speed_scale = 3.0
		num_bombs_to_use = 6
		game.set_num_packets(20)
	elif level == 4:
		time_between_dispatches_ms = 2500
		num_more_packets = 0
		max_speed_scale = 3.5
		num_bombs_to_use = 7
		game.set_num_packets(25)
	elif level == 5:
		time_between_dispatches_ms = 2000
		num_more_packets = 0
		max_speed_scale = 4.0
		num_bombs_to_use = 8
		game.set_num_packets(3000)
	# elif level == 6:
	# 	time_between_dispatches_ms = 3000
	# 	num_more_packets = 0
	# 	max_speed_scale = 3.5
	# 	num_bombs_to_use = 9
	# 	game.set_num_packets(35)
	# elif level == 7:
	# 	time_between_dispatches_ms = 3000
	# 	num_more_packets = 0
	# 	max_speed_scale = 3.5
	# 	num_bombs_to_use = 9
	# 	game.set_num_packets(40)
	# elif level == 8:
	# 	time_between_dispatches_ms = 2000
	# 	num_more_packets = 0
	# 	max_speed_scale = 3.5
	# 	num_bombs_to_use = 9
	# 	game.set_num_packets(50)
	# elif level >= 9:
	# 	time_between_dispatches_ms = 2000
	# 	num_more_packets = 0
	# 	max_speed_scale = 3.5
	# 	num_bombs_to_use = 10
	# 	game.set_num_packets(3000)
	if MainGlobals.is_mobile():
		var bsh = 12
		var bsv = 8
		game.max_board_size -= Vector2i(bsh,bsv)
	game.init_sizes()

var time_last_dispatch = -10000
var pos_last_dispatch = Vector2i(-1,-1)
func _on_agent_dispatch_timer_timeout() -> void:
	if start_dispatch and !game.paused():
		var tm = MainGlobals.timems()
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
				if board[p.y][p.x].has_agent:
					continue
				if (pos_last_dispatch - p).length() > 4:
					var t = find_closest_target(p)
					if t.is_receiver or t.is_sender:
						continue
					got_p = true
					break
			if got_p:
				pos_last_dispatch = p
				add_agent_at(p, dir)
		
func on_agent_remove_agent(agent_id, arrived):
	for i in agents.size():
		if agents[i].agent_id == agent_id:
			board[agents[i].board_pos.y][agents[i].board_pos.x].has_agent = false
			agents[i].queue_free()
			agents.remove_at(i)
			if not arrived:
				game.dec_packet()
				if !$DeliveryAudio.playing:
					$DeliveryAudio.play()
				delivered_one.emit()
				if game.packets_left == 0:
					level_is_done(true)
			break

func check_agent_collisions():
	for i in agents.size():
		var a1 = agents[i]
		if !a1.was_hit and !a1.arrived:
			if board[a1.board_pos.y][a1.board_pos.x].isbomb:
				a1.mark_hit()
				if !$ExplosionAudio.playing:
					$ExplosionAudio.play()
				collision.emit()
			for j in agents.size():
				if i != j:
					var a2 = agents[j]
					if !a2.was_hit and !a2.arrived:
						var d = a1.distance_to(a2)
						if d < game.tile_size/4.0:
							a1.mark_hit()
							a2.mark_hit()
							if !$ExplosionAudio.playing:
								$ExplosionAudio.play()
							collision.emit()

func on_agent_started_moving(transaction_id):	
	activate_transaction(transaction_id)
	
func activate_transaction(transaction_id):
	$SwooshAudio.play()
	for t in targets:
		if t.transaction_id == transaction_id:
			# if t.is_receiver:
			# 	t.flash()
			if t.is_sender:
				t.flash_and_reset()
	for agent in agents:
		if agent.transaction_id == transaction_id:
			agent.is_moving = true

func on_agent_pressed(transaction_id, _agent_board_pos):
	activate_transaction(transaction_id)

func on_clicked_target(target_id, _target_board_pos):
	var target = null
	for t in targets:
		if t.id == target_id:
			target = t
			break
	if target:
		activate_transaction(target.transaction_id)

func on_time_over():
	$MotorAudio.stop()

func draw_path(path):
	if !allow_show_path:
		return
	for p in path:
		if board[p.y][p.x].ispipe:
			board[p.y][p.x].pipe.show_path(1000)

func find_agent_path(agent):
	var trans_id = agent.transaction_id
	if not trans_id in dict_tran_id_to_target:
		return []
	var target = dict_tran_id_to_target[trans_id]
	var start = agent.board_pos
	var end = target.lobby_pos
	var prev_pos = game.next_board_pos(start, (agent.direction + 2) % 4)
	var path = game.astar(start, end, Callable(self, "calc_cost_to_move_to"), trans_id,prev_pos)
	draw_path(path)	
	return path

func calc_cost_to_move_to(prev_pos: Vector2i, from: Vector2i, to:Vector2i, id: int, _goal: Vector2i):
	if !game.in_board(to):
		return -1
	var tocell = board[to.y][to.x]
	if !tocell.ispipe or tocell.pipe.blocked:
		return -1
	if tocell.istarget:
		var trans_id = tocell.target.transaction_id
		if trans_id != id:
			return -1
	var fromcell = board[from.y][from.x]
	if fromcell.door_type == 1:	#door slanted from topleft to bottomright
		if prev_pos.x > from.x:		# comes from the right
			return -1 if to.y >= from.y else 1
		elif prev_pos.x < from.x:	# comes from the left
			return -1 if to.y <= from.y else 1
		elif prev_pos.y < from.y:	# comes from top to bottm
			return -1 if to.x <= from.x else 1
		else:						# comes from bottom to top
			return -1 if to.x >= from.x else 1
	elif fromcell.door_type == 2:	#door slanted from topright to bottomleft
		if prev_pos.x > from.x:		# comes from the right
			return -1 if to.y <= from.y else 1
		elif prev_pos.x < from.x:	# comes from the left
			return -1 if to.y >= from.y else 1
		elif prev_pos.y < from.y:	# comes from top to bottm
			return -1 if to.x >= from.x else 1
		else:						# comes from bottom to top
			return -1 if to.x <= from.x else 1
	return 1
	
func _on_agent_timeout(_agent):
	pass
	# game.add_score_and_time(5, 10)
	# $DeliveryAudio.play()
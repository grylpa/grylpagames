extends CanvasLayer

enum Dirs {right=0,down=1,left=2,up=3}
enum DoorTypes {open=0, backslash=1, slash=2}

var game: GenericGameUtil

class OneCell:
	var ispipe := false
	var door_type := -1
	var has_agent := false
	var istarget := false
	var isreceiver := false
	
var times_to_answer := []
var _round_start_ms := 0

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
var agent_start_positions = []
var time_started_level_ms = 0
var time_increased_difficulty_ms = 0
var level := 0
var num_more_packets = 0
var max_speed_scale = 1.0
@export var pipe_scene: PackedScene = load("res://guidem/scenes/pipe.tscn")
@export var empty_scene: PackedScene = load("res://guidem/scenes/empty_space.tscn")
@export var agent_scene: PackedScene = load("res://guidem/scenes/agent.tscn")
@export var door_scene: PackedScene = load("res://guidem/scenes/door.tscn")
@export var target_scene: PackedScene = load("res://guidem/scenes/target.tscn")

var dispatch_audio := preload("res://art/sounds/kenney/Audio/impactBell_heavy_003.ogg")
var delivery_audio := preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var door_audio := preload("res://art/sounds/door-open-sound-1.mp3")
var motor_audio := preload("res://art/sounds/engine-pulling-something.mp3")
var explosion_audio := preload("res://art/sounds/car-crash-1.mp3")

# signal game_over(didwin:bool)
signal started_playing
signal sig_level_is_done(didwin:bool)
signal delivered_one
signal collision

func _ready() -> void:
	game = GuidemG.game
	game.sig_time_over.connect(on_time_over)
	level = GuidemG.starting_level
	increase_difficulty(false)

	$DoorAudio.stream = door_audio
	$MotorAudio.stream = motor_audio
	motor_audio.loop = true

	$DispatchAudio.stream = dispatch_audio
	$DeliveryAudio.stream = delivery_audio
	$ExplosionAudio.stream = explosion_audio
	
func new_game(from_scratch=true):
	game.level_is_ready = false
	if from_scratch:
		level = GuidemG.starting_level
	increase_difficulty(game.need_to_increase_level)
	game.need_to_increase_level = false
	time_last_dispatch = -10000
	pos_last_dispatch = Vector2i(-1,-1)
	create_board()
	time_started_level_ms = MainGlobals.timems()
	time_increased_difficulty_ms = time_started_level_ms
	# $HUD.new_game()	
	started_playing.emit()
	BE.upsert_game_state("Guidem", 
		{"state":"new","starting_level": level, "num_packets": GuidemG.num_packets})

func _input(event) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if event.is_action_pressed("mainmenu"):
		$MotorAudio.stop()

func _process(_delta: float) -> void:
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
	
func add_target(p, id, show_id=false, destination_type=0):
	board[p.y][p.x].istarget = true
	board[p.y][p.x].isreceiver = destination_type > 0
	var target = target_scene.instantiate()
	target.position = game.board_to_px(p)
	target.set_id(id, show_id, destination_type)
	target.z_index = 100
	add_child(target)
	targets.append(target)
	target_positions.append(p)
	var q = p
	if p.x == 0: q.x += 1
	if p.x == game.board_size.x - 1: 
		q.x -= 1
		target.set_img_rot(PI)
	if p.y == 0: 
		q.y += 1
		target.set_img_rot(PI/2.0)
	if p.y == game.board_size.y - 1: 
		q.y -= 1
		target.set_img_rot(-PI/2.0)
	if destination_type == 0:
		target_lobbies.append(q)
	if destination_type == 0:
		agent_start_positions.append(p)
		# agent_start_positions.append(q)
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
	agent_start_positions.clear()

	var dest_y = ceili(game.board_size.y / 2)
	var dest_x = ceili(game.board_size.x / 2)
	var targetid = 1
	for row in range(2,game.board_size.y-1,2):
		targetid += 1
		add_target(Vector2i(0,row), targetid, false, 0)
		targetid += 1
		add_target(Vector2i(game.board_size.x-1,row), targetid, false, 1 if row > dest_y else 0)
	for col in range(2,game.board_size.x-1,2):
		targetid += 1
		add_target(Vector2i(col,0), targetid, false, 0)
		targetid += 1
		add_target(Vector2i(col,game.board_size.y-1), targetid, false, 1 if col > dest_x else 0)

	for row in range(1,game.board_size.y-1):
		for col in range(1,game.board_size.x-1):
			if row % 2 == 0 or col % 2 == 0:
				add_pipe(Vector2i(col,row))
	
	for row in game.board_size.y:
		for col in game.board_size.x:
			if !board[row][col].ispipe:
				add_empty(Vector2i(col,row))
	show_hide_walls()
				
	for pipe in pipes:
		pipe.set_rot(board)

	var rng = RandomNumberGenerator.new()		
	# add doors			
	var door
	for row in game.board_size.y:
		for col in game.board_size.x:
			var p = Vector2i(col,row)
			if board[p.y][p.x].ispipe:
				var nbranches = 0
				for d in game.DirArray:
					var q = p+d
					if game.in_board(q) and board[q.y][q.x].ispipe:
						nbranches += 1
				if nbranches > 2:
					var door_type
					if !game.in_board(p,2) or game.is_corner(p,3):
						door_type = 0
					else:
						door_type = rng.randi_range(0,2)
						
					board[p.y][p.x].door_type = door_type
					door = door_scene.instantiate()
					door.position = game.board_to_px(p)
					door.set_board_pos(p)
					#door.rotate(door_type * PI/4.0)
					add_child(door)
					door.set_rot(door_type)
					door.door_pressed.connect(on_clicked_door)
					doors.append(door)					
					
	start_dispatch = true
	create_camera(min(2.0, 1.0 / game.get_board_part_of_width()))
	game.level_is_ready = true
		
var next_agent_id := 1
func _record_answer_time():
	var t := MainGlobals.timems() - _round_start_ms
	if t > 0 and t < 60000:
		times_to_answer.append(t)
		while times_to_answer.size() > 20:
			times_to_answer.remove_at(0)

func mean_time_to_answer_ms() -> int:
	if times_to_answer.is_empty(): return 9999
	var s := 0
	for t in times_to_answer: s += t
	return roundi(float(s) / times_to_answer.size())

func add_agent_at(p: Vector2i, direction: int, agent_type: int = 1):
	_round_start_ms = MainGlobals.timems()
	var agent = agent_scene.instantiate()
	agent.direction = direction
	agent.board_pos = p
	agent.body_ids = range(1, GuidemG.num_packets+1+num_more_packets)
	var rng = RandomNumberGenerator.new()
	agent.speed_scale = rng.randf_range(0.8, max_speed_scale)
	agent.set_id(next_agent_id)
	next_agent_id += 1
	add_child(agent)
	agent.set_type(agent_type)
	# agent.hit.connect(on_agent_hit)
	agent.remove_agent.connect(on_agent_remove_agent)
	agents.append(agent)
	game.tutorial_notify("walker_dispatched")   # no-op outside tutorial mode
	agent.set_pos(game.board_to_px(p), direction)
	if not $DispatchAudio.playing:
		$DispatchAudio.play()
	if not $MotorAudio.playing:
		MainGlobals.do_after(0.5, func(): $MotorAudio.play())
			
func on_clicked_door(pos: Vector2i):
	#if board[pos.y][pos.x].has_agent:
		#return
	for i in doors.size():
		var door = doors[i]
		if door.board_pos == pos:
			var current = door.rot_idx
			var newdir = (current + 1) % 3
			door.set_rot(newdir)
			#door.rotate(PI/4.0)
			board[pos.y][pos.x].door_type = newdir
			$DoorAudio.stop()
			$DoorAudio.play()
			game.tutorial_notify("door_turned")   # no-op outside tutorial mode
			break

func can_go_to(p):
	if !game.in_board(p):
		return false
	var cond = board[p.y][p.x].ispipe
	cond = cond and !board[p.y][p.x].istarget
	# if board[p.y][p.x].isreceiver:
	# 	cond = true
	# cond = cond and !(p in target_lobbies)
	return cond
		
var last_major_tick_ms = -10000.0
func tick():
	if game.level_is_done:
		return
	var now = MainGlobals.timems()
	# if now - last_major_tick_ms < game.major_tick_time_ms * game.time_scale:
	# 	return
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
			var adj_tar_id = get_adjacent_target_id(p, agent.agent_type)
			if adj_tar_id >= 0:
				game.dec_packet()
				agent.mark_arrived()
				game.tutorial_notify("delivered")
				delivered_one.emit()
				if !$DeliveryAudio.playing:
					$DeliveryAudio.play()
				if game.packets_left == 0:
					_record_answer_time()
					level_is_done(true)
					return
				# removed_agents.append(iagent)
				continue
			# var _removed_body_part = false
			# if adj_tar_id >= 0:
			# 	_removed_body_part = agent.remove_body_if_first(adj_tar_id)
			if game.in_board(p):
				var dir = agent.direction
				var origdir = dir
				var vdir = game.DirArray[dir]
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
							var nextvdir = game.DirArray[nextdir]
							q = p + nextvdir
							if can_go_to(q):
								dir = nextdir
								break
				vdir = game.DirArray[dir]
				q = p + vdir
				if !can_go_to(q):
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

	for iremove in removed_agents.size():
		agents[iremove].queue_free()
		agents.remove_at(iremove)
		delivered_one.emit()

func get_adjacent_target_id(q, agent_type):
	for i in target_positions.size():
		var target = targets[i]
		if target.destination_type > 0:
			var p = target_positions[i]
			var d = (p-q).length()
			if abs(d-1) < 1e-3:
				if agent_type == target.destination_type:
					var target_id = target.id
					return target_id
				else:
					break
	return -1
			
func _on_level_done_popup_closed():
	sig_level_is_done.emit(true)

func level_is_done(didwin: bool):
	game.level_is_done = true
	game.level_is_ready = false	
	$MotorAudio.stop()
	BE.send_event("level_done", "Guidem", {
		"level": level,
		"didwin": int(didwin),
	})
	start_dispatch = false
	if didwin:
		game.need_to_increase_level = true
		MainGlobals.global_level_is_done(true)
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
	var s = 7 + level * 2
	game.max_board_size = Vector2i(s,s)
	if level == 1:
		time_between_dispatches_ms = 5000
		num_more_packets = 0
		max_speed_scale = 1.0
		game.set_num_packets(3)
	elif level == 2:
		time_between_dispatches_ms = 2500
		num_more_packets = 0
		max_speed_scale = 1.5
		game.set_num_packets(3)
	elif level == 3:
		time_between_dispatches_ms = 3500
		num_more_packets = 1
		max_speed_scale = 2.0
		game.set_num_packets(3)
	elif level == 4:
		time_between_dispatches_ms = 2500
		num_more_packets = 1
		max_speed_scale = 2.0
		game.set_num_packets(3)
	elif level == 5:
		time_between_dispatches_ms = 3000
		num_more_packets = 2
		max_speed_scale = 2.0
		game.set_num_packets(3)
	elif level == 6:
		time_between_dispatches_ms = 3000
		num_more_packets = 3
		max_speed_scale = 3.0
		game.set_num_packets(4)
	elif level == 7:
		time_between_dispatches_ms = 3000
		num_more_packets = 4
		max_speed_scale = 3.0
		game.set_num_packets(4)
	elif level == 8:
		time_between_dispatches_ms = 2000
		num_more_packets = 5
		max_speed_scale = 3.0
		game.set_num_packets(5)
	elif level >= 9:
		time_between_dispatches_ms = 2000
		num_more_packets = 6
		max_speed_scale = 4.0
		game.set_num_packets(200)
	# if MainGlobals.is_mobile():
	# 	var bs = 0		
	# 	# game.forced_board_size -= Vector2i(bs, bs)
	# 	game.max_board_size -= Vector2i(bs,bs)
	game.init_sizes()

var time_last_dispatch = -10000
var pos_last_dispatch = Vector2i(-1,-1)
func _on_agent_dispatch_timer_timeout() -> void:
	if start_dispatch and !game.paused():
		var tm = MainGlobals.timems()
		if tm - time_last_dispatch >= time_between_dispatches_ms:
			time_last_dispatch = tm
			var rng = RandomNumberGenerator.new()
			var p
			while true:
				var idx = rng.randi_range(0,agent_start_positions.size()-1)
				p = agent_start_positions[idx]
				if time_between_dispatches_ms > 3000 or (pos_last_dispatch - p).length() > 4:
					break
			pos_last_dispatch = p
			add_agent_at(p, 1)
		
func on_agent_remove_agent(agent_id):
	for i in agents.size():
		if agents[i].agent_id == agent_id:
			board[agents[i].board_pos.y][agents[i].board_pos.x].has_agent = false
			agents[i].queue_free()
			agents.remove_at(i)
			break

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
							$ExplosionAudio.play()
							collision.emit()
				
func on_time_over():
	$MotorAudio.stop()

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

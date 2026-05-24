extends CanvasLayer

var game: GenericGameUtil

class OneCell:
	var ispipe := false
	var has_agent := false
	var istarget := false
	
var times_to_answer := []
var _round_start_ms := 0

var halt := false
var start_dispatch := false
var time_between_dispatches_ms = 5000
var board: Array
var ntargets := 7
var agents = []
var targets = []
var target_positions = []
var target_lobbies = []
var pipes = []
var empties = []
var agent_positions = []
var num_more_packets = 0
var time_started_level = 0
var level: int = 1
var player

@export var player_scene: PackedScene = load("res://delemfp/scenes/player.tscn")
@export var pipe_scene: PackedScene = load("res://delemfp/scenes/pipe.tscn")
@export var empty_scene: PackedScene = load("res://delemfp/scenes/empty_space.tscn")
@export var agent_scene: PackedScene = load("res://delemfp/scenes/agent.tscn")
@export var target_scene: PackedScene = load("res://delemfp/scenes/target.tscn")

var dispatch_audio := preload("res://art/sounds/kenney/Audio/impactBell_heavy_003.ogg")
var delivery_audio := preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var motor_audio := preload("res://art/sounds/back-hoe-tractor-20083.mp3")

signal game_over(didwin:bool)
signal started_playing
signal new_packet_message(text, isdispatch)
signal show_reminder(text)
signal sig_level_is_done(didwin:bool)
signal update_score_time(add_score, add_time)

func _ready() -> void:
	game = DelemfpG.game
	DelemfpG.freeze = true
	game.sig_time_over.connect(on_time_over)
	level = DelemfpG.starting_level
	increase_difficulty(false)	
	player = player_scene.instantiate()
	add_child(player)

	$MotorAudio.stream = motor_audio
	motor_audio.loop = true

	$DispatchAudio.stream = dispatch_audio
	$DeliveryAudio.stream = delivery_audio

	MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
	
func new_game(from_scratch: bool):
	if from_scratch:
		level = DelemfpG.starting_level
	time_to_start_camera = -1
	increase_difficulty(false)
	halt = false
	time_last_dispatch = -10000
	player.reset()
	create_board()
	time_started_level = MainGlobals.timems()
	started_playing.emit()
	BE.upsert_game_state("Delemfp", 
		{"state":"new","level": level, "num_packets": DelemfpG.num_packets})

func _input(event):
	if MainGlobals.ignore_keyboard_actions:
		return
	if event.is_action_pressed("reminder") or event.is_action_pressed("clue"):
		display_reminder()
	elif event.is_action_pressed("stop"):
		if game.playing and start_dispatch:
			halt_or_resume()
	elif event.is_action_pressed("zoom"):
		update_score_time.emit(-2, -10)
		zoom_unzoom()
	elif event.is_action_pressed("mainmenu"):
		$MotorAudio.stop()		
	elif !DelemfpG.freeze:
		if event.is_action_pressed("right") or event.is_action_pressed("ui_right"):
			move_dir(0)
		elif event.is_action_pressed("down") or event.is_action_pressed("ui_down"):
			move_dir(1)
		elif event.is_action_pressed("left") or event.is_action_pressed("ui_left"):
			move_dir(2)
		elif event.is_action_pressed("up") or event.is_action_pressed("ui_up"):
			move_dir(3)
	
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
	
func add_target(p, id):
	board[p.y][p.x].istarget = true
	var target = target_scene.instantiate()
	target.position = game.board_to_px(p)
	target.set_id(id)
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
	target_lobbies.append(q)
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
	DelemfpG.freeze = true
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
	for c in targets:
		c.queue_free()
	for c in empties:
		c.queue_free()
	pipes.clear()
	empties.clear()
	agents.clear()
	targets.clear()
	target_positions.clear()
	target_lobbies.clear()
	agent_positions.clear()
	add_pipe(player.board_pos)
	var rng = RandomNumberGenerator.new()
	var wall = rng.randi_range(0,3)
	for i in ntargets:
		var target_pos = Vector2i.ZERO
		var added_target = false
		while not added_target:
			if wall == 0 or wall == 2:
				for _i in 20:
					target_pos = Vector2i(int(wall / 2)*(game.board_size.x-1), \
						rng.randi_range(2, game.board_size.y-3) & ~1)
					if dist_from_array(target_pos, target_positions) > 1 and \
						!game.is_corner(target_pos):
						added_target = true
						break
			elif wall == 1:
				for _i in 20:
					target_pos = Vector2i(rng.randi_range(2, game.board_size.x-3) & ~1, \
						game.board_size.y-1)
					if dist_from_array(target_pos, target_positions) > 1 and \
						!game.is_corner(target_pos):
						added_target = true
						break
			else:
				for _i in 20:
					target_pos = Vector2i(rng.randi_range(2, game.board_size.x-3) & ~1, 0)
					if dist_from_array(target_pos, target_positions) > 1 and \
						(target_pos - player.board_pos).length() > 3 and \
						!game.is_corner(target_pos):
						added_target = true
						break
			wall = (wall + 1) % 4
		var lobby_pos = add_target(target_pos, i+1)
				
		var from = player.board_pos		
		var to = lobby_pos
		var done = false
		var count = 0
		var q
		var p
		from += Vector2i(0,1)
		add_pipe(from)
		from += Vector2i(0,1)
		add_pipe(from)
		var stack = [from]
		p = from
		while not done and count < 50000:
			count += 1
			var add_idx = rng.randi_range(0,3)
			var add_v = game.DirArray[add_idx]
			q = p + add_v
			var qidx = stack.find(q)
			if qidx >= 0:
				while stack.size() > qidx+1:	# remove loop
					stack.pop_back()
				p = q
			elif game.in_board(q, 2) and \
				(q.x % 2 == 0 or q.y % 2 == 0):# and \
				#(not game.on_border(q, 2) or q == to):
				stack.push_back(q)
				p = q
				if abs((q-to).length() - 1) < 1e-03:
					done = true
		if done:
			for ppos in stack:
				if !board[ppos.y][ppos.x].ispipe:
					add_pipe(ppos)				
	
	for row in game.board_size.y:
		for col in game.board_size.x:
			if !board[row][col].ispipe:
				add_empty(Vector2i(col,row))

	var mx = roundi(game.board_size.x/2)
	var my = roundi(game.board_size.y/2)
	for row in range(1,my+1):
		for col in range(-mx, game.board_size.x + mx + 1):
			add_empty(Vector2i(col,-row))
			add_empty(Vector2i(col,game.board_size.y+row-1))
	for row in range(-my, game.board_size.y + my + 1):
		for col in range(1,mx+1):
			add_empty(Vector2i(-col,row))
			add_empty(Vector2i(game.board_size.x+col-1,row))
	
	show_hide_walls()

	for pipe in pipes:
		pipe.set_rot(board)		
				
	for _i in DelemfpG.num_agents:
		# var p = game.get_agent_start_pos()
		var p = game.get_player_start_pos() + Vector2i(0, 1)
		agent_positions.append(p)

	start_dispatch = true
		
var time_to_start_camera := -1

func _process(_delta: float) -> void:
	if time_to_start_camera > 0 and MainGlobals.timems() >= time_to_start_camera:
		time_to_start_camera = -1
		create_camera()

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

func add_agent_at(p: Vector2i, direction: int):
	var agent = agent_scene.instantiate()
	agent.direction = direction
	agent.board_pos = p
	var possibles = range(1, ntargets+1)
	possibles.shuffle()
	agent.body_ids = possibles.slice(0, DelemfpG.num_packets+num_more_packets)
	var text = "Deliver to " + ",".join(agent.body_ids)	
	new_packet_message.emit(text, true)
	add_child(agent)
	agents.append(agent)
	agent.set_pos(game.board_to_px(p), direction)
	if not $DispatchAudio.playing:
		$DispatchAudio.play()
	if not $MotorAudio.playing:
		MainGlobals.do_after(0.5, func(): $MotorAudio.play())
	time_to_start_camera = MainGlobals.timems() + 5000
	MainGlobals.global_start_countdown(5)
	MainGlobals.sig_global_countdown_finished.connect(_on_sig_global_countdown_finished)
	# await MainGlobals.sleep(5)
	# create_camera()
	
func _on_sig_global_countdown_finished():
	halt = false

func display_reminder():
	var text = ""
	for agent in agents:
		text += ",".join(agent.body_ids)# + "\n"
	text = text.strip_edges()
	show_reminder.emit(text)
		
func can_go_to(p):
	var cond = game.in_board(p) and board[p.y][p.x].ispipe
	cond = cond and !board[p.y][p.x].istarget
	#cond = cond and !board[p.y][p.x].has_agent
	cond = cond and p != player.board_pos
	return cond
	
func all_agents_done():
	if !game.playing:
		return false
	if agents.size() == 0:
		return false
	for agent in agents:
		if agent.body_ids.size() > 0:
			return false
	return true
	
var last_major_tick_ms = -10000.0
func tick():
	if game.level_is_done:
		return
	var t = MainGlobals.timems()
	if t - last_major_tick_ms < game.major_tick_time_ms * game.time_scale:
		return
	last_major_tick_ms = t
	if all_agents_done():
		level_is_done(true)
		return
	if DelemfpG.freeze:
		return
	for agent in agents:
		var p = agent.board_pos
		var adj_tar_id = get_adjacent_target_id(p)
		var _removed_body_part = false
		if adj_tar_id >= 0:
			_removed_body_part = agent.remove_body_if_first(adj_tar_id)
			if _removed_body_part:
				$DeliveryAudio.play()
				game.delivered_one()
				if agent.body_ids.is_empty():
					_record_answer_time()
		if !halt && game.in_board(p):
			var dir = next_agent_dir if next_agent_dir >= 0 else agent.direction
			var vdir = game.DirArray[dir]
			var q = p + vdir
			if !can_go_to(q) and next_agent_dir >= 0:
				dir = agent.direction
				vdir = game.DirArray[dir]
				q = p + vdir
			if !can_go_to(q):
				var nextdir1 = (dir + 1) % 4
				var nextvdir1 = game.DirArray[nextdir1]
				var q1 = p + nextvdir1
				var nextdir2 = (dir + 3) % 4
				var nextvdir2 = game.DirArray[nextdir2]
				var q2 = p + nextvdir2
				if can_go_to(q1) and !can_go_to(q2):
					q = q1
					dir = nextdir1
				elif can_go_to(q2) and !can_go_to(q1):
					q = q2
					dir = nextdir2
				else:
					break
			vdir = game.DirArray[dir]
			q = p + vdir
			if can_go_to(q):
				agent.direction = dir
				var new_agent_pos = game.board_to_px(q)
				var actual_tick_time = agent.set_target_pos(new_agent_pos)
				last_major_tick_ms = t + actual_tick_time - game.major_tick_time_ms * game.time_scale
				agent.board_pos = q
				board[q.y][q.x].has_agent = true
				board[p.y][p.x].has_agent = false
				if next_agent_dir == dir:
					next_agent_dir = -1

func get_adjacent_target_id(q):
	for i in target_positions.size():
		var p = target_positions[i]
		var d = (p-q).length()
		if abs(d-1) < 1e-3:
			var target = targets[i]
			var target_id = target.id
			return target_id
	return -1
			
func level_is_done(didwin: bool):
	game.level_is_done = true
	$MotorAudio.stop()
	BE.send_event("level_done", "Delemfp", {
		"level": level,
		"didwin": int(didwin),
		"num_packets": DelemfpG.num_packets
	})
	start_dispatch = false
	if agent_cam and agent_cam.enabled:
		agent_cam.enabled = false
		DelemfpG.freeze = true
	if didwin:
		MainGlobals.global_level_is_done(true)
		if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
			MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
		game.show_level_done_popup(self, "","", level)
		increase_difficulty()
		# MainGlobals.sleep(1.0)
		# sig_level_is_done.emit(didwin)
	else:
		game_over.emit(false)
	
func _on_level_done_popup_closed():
	sig_level_is_done.emit(true)

func increase_difficulty(increase=true):
	if increase:
		level += 1
	var s = 7 + level * 2
	game.max_board_size = Vector2i(s,s)
	num_more_packets = max(0, min(7, level - 1))
	game.init_sizes()

var time_last_dispatch = -10000
func _on_agent_dispatch_timer_timeout() -> void:
	if start_dispatch and !game.paused():
		var tm = MainGlobals.timems()
		if tm - time_last_dispatch >= time_between_dispatches_ms and agents.size() < agent_positions.size():
			time_last_dispatch = tm
			var p = agent_positions[agents.size()]
			add_agent_at(p, 1)
			if agents.size() == agent_positions.size():
				start_dispatch = false

func halt_or_resume():
	halt = !halt

var next_agent_dir = -1
func move_dir(dir):
	if halt:
		return
	next_agent_dir = dir
	if agents.size() > 0:
		var agent = agents[0]
		if abs(dir - agent.direction) == 2:
			last_major_tick_ms = 0
			tick()

var agent_cam = null
func create_camera():
	_round_start_ms = MainGlobals.timems()
	if agents.size() == 0:
		return
	agent_cam = Camera2D.new()
	var agent = agents[0]
	agent.add_child(agent_cam)
	agent_cam.zoom = Vector2(2,2)
	agent_cam.position_smoothing_enabled = true
	agent_cam.position_smoothing_speed = 10
	DelemfpG.freeze = false

func zoom_unzoom():
	if agent_cam:
		if agent_cam.enabled:
			agent_cam.enabled = false
			DelemfpG.freeze = true
			# show_reminder.emit("")
			await MainGlobals.sleep(4)
			# show_reminder.emit("")
		DelemfpG.freeze = false
		if agent_cam:
			agent_cam.enabled = true

func on_time_over():
	$MotorAudio.stop()
extends CanvasLayer

enum Dirs {right=0,down=1,left=2,up=3}
enum DoorTypes {open=0, backslash=1, slash=2}

var rng = RandomNumberGenerator.new()		

var game: GenericGameUtil

class OneCell:
	var ispipe: bool = false
	var door_type: int = -1
	var has_agent: bool = false
	var istarget: bool = false
	
var start_dispatch: bool = false

# --- tutorial staging (all inert outside tutorial_mode) ---------------------
# Whether the board on screen was built FOR a tutorial. Captured at board-creation time: a win can
# be reported after the coach has finished, when tutorial_mode has already gone false.
var _tutorial_board: bool = false
# Holds the dispatcher, so a second capsule does not arrive behind a caption about the first — and
# cannot collide with it while the player is still being told what a collision costs.
var tutorial_hold_dispatch: bool = false
# Stops the capsules dead. The door steps are ACTION steps, so the game is unpaused and a capsule
# would glide on — off the very door the coach is pointing at — while the player looks for it.
var tutorial_hold_capsules: bool = false
var time_between_dispatches_ms = 5000
var board: Array
var agents = []
var targets = []
var target_positions = []
var target_lobbies = []
var pipes = []
var empties = []
var doors = []
# Transaction ids are handed out from a counter that only ever goes up, and is deliberately NOT
# reset between levels. They used to come from a shuffled pool of `ntargets` ids cycled by index,
# which meant an id could be live twice at once -- and `reset_sender_receiver(id)` clears EVERY
# target holding that id, two seconds after a delivery. A capsule still in flight could therefore
# have its receiver wiped by someone else's delivery, after which the freed target was picked up by
# the next transaction and changed color while the original capsule was still on the board.
var next_transaction_id: int = 1
var agent_start_positions = []
var agent_start_directions = []
var time_started_level_ms = 0
var time_increased_difficulty_ms = 0
var level: int = 0
var num_more_packets = 0
var max_speed_scale = 1.0
@export var pipe_scene: PackedScene = load("res://pneumo/scenes/pipe.tscn")
@export var empty_scene: PackedScene = load("res://pneumo/scenes/empty_space.tscn")
@export var agent_scene: PackedScene = load("res://pneumo/scenes/agent.tscn")
@export var door_scene: PackedScene = load("res://pneumo/scenes/door.tscn")
@export var target_scene: PackedScene = load("res://pneumo/scenes/target.tscn")

var dispatch_audio = preload("res://art/sounds/kenney/Audio/impactBell_heavy_003.ogg")
var delivery_audio = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var door_audio = preload("res://art/sounds/door-open-sound-1.mp3")
var motor_audio = preload("res://art/sounds/car-ambient-driving.ogg")
var explosion_audio = preload("res://art/sounds/car-crash-1.mp3")
var swoosh_audio = preload("res://art/sounds/swoosh.mp3")

signal started_playing
signal sig_level_is_done(didwin:bool)
signal delivered_one
signal collision

func _ready() -> void:
	game = PneumoG.game
	game.sig_time_over.connect(on_time_over)
	level = PneumoG.starting_level
	increase_difficulty(false)

	game.add_sound(self, "door", door_audio, false)
	game.add_sound(self, "motor", motor_audio, true)

	game.add_sound(self, "dispatch", dispatch_audio, false)
	game.add_sound(self, "delivery", delivery_audio, false)
	game.add_sound(self, "explosion", explosion_audio, false)
	game.add_sound(self, "swoosh", swoosh_audio, false)

func new_game(from_scratch=true):
	_tutorial_board = game.tutorial_mode
	game.level_is_ready = false
	if from_scratch:
		level = PneumoG.starting_level
	increase_difficulty(game.need_to_increase_level)
	game.need_to_increase_level = false
	time_last_dispatch = -10000
	pos_last_dispatch = Vector2i(-1,-1)
	create_board()
	time_started_level_ms = MainGlobals.timems()
	time_increased_difficulty_ms = time_started_level_ms
	# $HUD.new_game()
	started_playing.emit()
	if not game.tutorial_mode:
		BE.upsert_game_state("Pneumo", 
			{"state":"new","starting_level": level, "num_packets": PneumoG.num_packets})
	if !game.is_sound_playing("motor"):
		game.play_sound("motor")

func _input(event) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if event.is_action_pressed("mainmenu"):
		game.stop_sound("motor")

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
	
func add_target(p, id, show_id=false):
	board[p.y][p.x].istarget = true
	var target = target_scene.instantiate()
	target.position = game.board_to_px(p)
	target.board_pos = p
	target.set_id(id, show_id)
	target.z_index = 100
	add_child(target)
	target.target_pressed.connect(on_clicked_target)
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
					
	if game.tutorial_mode:
		_tutorial_setup()
	start_dispatch = true
	game.create_fill_screen_camera(self)
	game.level_is_ready = true
		
# The closest target to `p`. With only_free the search skips targets that are already the sender
# or receiver of a live transaction.
#
# Dispatch MUST use only_free. It used to take simply the closest target as the new sender, which
# could be the live RECEIVER of a capsule still in flight: set_sender() then overwrote that
# target's transaction id and marking, so the capsule's id matched no receiver any more and it
# could never be delivered, and the gate fell back to plain unassigned once the new transaction
# ended. That is a blue capsule watching its receiver go orange while it is still on the board.
func find_closest_target(p, only_free: bool = false):
	var d = 100
	var target
	for t in targets:
		if only_free and (t.is_sender or t.is_receiver):
			continue
		var this_d = t.board_pos.distance_to(p)
		if this_d < d:
			d = this_d
			target = t
	return target

var next_agent_id: int = 1
func add_agent_at(p: Vector2i, direction: int, agent_type: int = 1):
	var agent = agent_scene.instantiate()
	agent.body_ids = range(1, PneumoG.num_packets+1+num_more_packets)
	agent.direction = direction
	agent.board_pos = p
	# var rng = RandomNumberGenerator.new()
	agent.speed_scale = rng.randf_range(0.8, max_speed_scale)
	add_child(agent)
	agent.set_type(agent_type)
	agent.set_id(next_agent_id)
	next_agent_id += 1
	agent.agent_pressed.connect(on_agent_pressed)
	agent.sig_agent_started_moving.connect(on_agent_started_moving)
	board[p.y][p.x].has_agent = true
	# agent.hit.connect(on_agent_hit)
	agent.remove_agent.connect(on_agent_remove_agent)
	agents.append(agent)
	# At the cell's center, on the board — where the capsule is mostly OUT of the gate with just
	# its tail overlapping. The agent draws itself behind the gates until it is clear (see
	# Z_IN_GATE), so that tail is hidden by the gate rather than drawn on top of it. Dispatching it
	# half a tile further back was tried, to buy the first turn more run-up: it put most of the
	# capsule inside the gate, which is not what a capsule about to be thrown should look like.
	agent.set_pos(game.board_to_px(p), direction)
	var sender = find_closest_target(p, true)
	var receiver = null
	var taridxs = range(0, targets.size())
	taridxs.shuffle()
	for i in taridxs:
		var t = targets[i]
		if t.board_pos != sender.board_pos and !t.is_receiver and !t.is_sender:
			receiver = t
	if receiver != null and sender != null:
		var color = game.next_color()
		var transaction_id = next_transaction_id
		next_transaction_id += 1
		receiver.set_receiver(true, color, transaction_id)
		sender.set_sender(true, color, transaction_id)
		sender.modulate = Color(1,1,1,1)
		receiver.modulate = Color(1,1,1,1)
		agent.transaction_id = transaction_id
		agent.set_color(color)
	if !game.is_sound_playing("dispatch"):
		game.play_sound("dispatch")
			
	game.tutorial_notify("capsule_sent")   # no-op outside tutorial mode

func reset_sender_receiver(transaction_id):
	for t in targets:
		if t.transaction_id == transaction_id:
			t.reset_sender_receiver()

func on_clicked_door(pos: Vector2i):
	for i in doors.size():
		var door = doors[i]
		if door.board_pos == pos:
			var current = door.rot_idx
			var newdir = (current + 1) % 3
			door.set_rot(newdir)
			board[pos.y][pos.x].door_type = newdir
			game.stop_sound("door")
			game.play_sound("door")
			game.tutorial_notify("door_turned")   # no-op outside tutorial mode
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
	
var last_major_tick_ms = -10000.0
func tick():
	if game.level_is_done:
		return
	if tutorial_hold_capsules:
		return
	var now = MainGlobals.timems()
	# if now - last_major_tick_ms < game.major_tick_time_ms * game.time_scale:
	# 	return
	last_major_tick_ms = now
	# if now - time_increased_difficulty_ms > PneumoG.time_to_increase_difficulty_s * 1000:
	# 	increase_difficulty()
	# 	time_increased_difficulty_ms = now

	# if all_agents_done():
	# 	level_is_done(true)
	# 	return

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
				game.dec_packet()
				delivered_transaction(agent.transaction_id)
				var aid = agent.transaction_id
				MainGlobals.do_after(2, func(): reset_sender_receiver(aid))
				agent.mark_arrived()
				if !game.is_sound_playing("delivery"):
					game.play_sound("delivery")
				game.tutorial_notify("delivered")
				delivered_one.emit()
				if game.packets_left == 0:
					level_is_done(true)
					return
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
					# Nowhere to go — a wrong receiver, or a wall. It comes back the way it came,
					# and takes the impact: the agent compresses along the axis it was traveling
					# and springs out again rather than simply turning round on the spot.
					dir = (origdir + 2) % 4
					vdir = game.DirArray[dir]
					q = p + vdir
					agent.start_bounce(Vector2(game.DirArray[origdir]))
				agent.direction = dir
				# Tile CENTERS, with no diagonal offset. The old ±tile/4 nudge at a door put the
				# capsule off the row it was traveling along, so it ran at odd angles between
				# doors and every corner became three joints instead of one.
				var new_agent_pos = game.board_to_px(q)
				var cell = board[q.y][q.x]
				# What the door in q will do to this capsule when it arrives, worked out HERE so
				# the agent can take the whole corner as one arc through the door tile instead of
				# turning on the spot. Same rules as the deflection above, applied to `dir` — the
				# direction it will be traveling in when it gets there.
				var turn_dir: int = -1
				if cell.door_type == 1:
					turn_dir = (dir + 1) % 4 if (dir == 0 or dir == 2) else (dir + 3) % 4
				elif cell.door_type == 2:
					turn_dir = (dir + 3) % 4 if (dir == 0 or dir == 2) else (dir + 1) % 4
				# Only if it can actually leave that way; otherwise it will bounce, and a rounded
				# corner into a wall would just be a wrong prediction drawn on screen.
				if turn_dir >= 0 and not can_go_to(q + Vector2i(game.DirArray[turn_dir])):
					turn_dir = -1
				agent.set_target_pos(new_agent_pos, turn_dir)
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
	if game.tutorial_mode or _tutorial_board:
		# A level-done popup landing on (or just after) the coach's closing caption is the failure
		# mmm taught us to guard against; _tutorial_board is what makes it hold once the coach has
		# finished and tutorial_mode has gone false.
		return
	BE.send_event("level_done", "Pneumo", {
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
	var s = 9 + level * 2
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
		game.set_num_packets(4)
	elif level == 3:
		time_between_dispatches_ms = 3500
		num_more_packets = 1
		max_speed_scale = 2.0
		game.set_num_packets(5)
	elif level == 4:
		time_between_dispatches_ms = 2500
		num_more_packets = 1
		max_speed_scale = 2.0
		game.set_num_packets(6)
	elif level == 5:
		time_between_dispatches_ms = 3000
		num_more_packets = 2
		max_speed_scale = 2.0
		game.set_num_packets(7)
	elif level == 6:
		time_between_dispatches_ms = 3000
		num_more_packets = 3
		max_speed_scale = 3.0
		game.set_num_packets(8)
	elif level == 7:
		time_between_dispatches_ms = 3000
		num_more_packets = 4
		max_speed_scale = 3.0
		game.set_num_packets(9)
	elif level == 8:
		time_between_dispatches_ms = 2000
		num_more_packets = 5
		max_speed_scale = 3.0
		game.set_num_packets(10)
	elif level >= 9:
		time_between_dispatches_ms = 2000
		num_more_packets = 6
		max_speed_scale = 4.0
		game.set_num_packets(3000)
	if MainGlobals.is_mobile():
		var bsh = 2
		var bsv = 2
		game.max_board_size -= Vector2i(bsh,bsv)
	game.init_sizes()

var time_last_dispatch = -10000
var pos_last_dispatch = Vector2i(-1,-1)
func _on_agent_dispatch_timer_timeout() -> void:
	if tutorial_hold_dispatch:
		return
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
							var tid1 = a1.transaction_id
							var tid2 = a2.transaction_id
							a1.mark_hit()
							a2.mark_hit()
							if !game.is_sound_playing("explosion"):
								game.play_sound("explosion")
							game.tutorial_notify("capsules_collided")
							collision.emit()
							MainGlobals.do_after(2, func(): 
								reset_sender_receiver(tid1)
								reset_sender_receiver(tid2)
							)

func on_agent_started_moving(transaction_id):	
	activate_transaction(transaction_id)
	
func activate_transaction(transaction_id):
	game.play_sound("swoosh")
	var receiver = null
	var sender = null
	for t in targets:
		if t.transaction_id == transaction_id:
			if t.is_receiver:
				receiver = t
			if t.is_sender:
				sender = t
	if receiver:
		receiver.flash()
	if sender:
		sender.flash()
		var tween_color = MainGlobals.make_tween()
		tween_color.tween_property(sender, "modulate", Color(1.0,1.0,1.0,0.4), 1.7)
		# tween_color.tween_callback(func(): sender.hide())
	for agent in agents:
		if agent.transaction_id == transaction_id:
			agent.is_moving = true
			break

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
	game.stop_sound("motor")

# --- tutorial staging -------------------------------------------------------

func _tutorial_setup() -> void:
	tutorial_hold_dispatch = false

# Freeze every capsule where it is, including any dispatched later.
func tutorial_freeze_capsules(hold: bool) -> void:
	tutorial_hold_capsules = hold
	for a in agents:
		if is_instance_valid(a):
			a.tutorial_hold = hold

# Stop new capsules arriving while the coach is talking about the one already in the tubes.
func tutorial_hold_new_capsules(hold: bool) -> void:
	tutorial_hold_dispatch = hold

# --- things for the coach to point at (all in SCREEN coordinates) -----------

func _screen_of(n) -> Vector2:
	if n == null or not is_instance_valid(n):
		return Vector2.ZERO
	return (n as Node2D).get_global_transform_with_canvas().origin

func tutorial_capsule():
	for a in agents:
		if is_instance_valid(a) and not a.arrived and not a.was_hit:
			return a
	return null

func tutorial_capsule_pos() -> Vector2:
	return _screen_of(tutorial_capsule())

func tutorial_has_capsule() -> bool:
	return tutorial_capsule() != null

# The receiver this capsule is FOR — matched by transaction_id, read off the board so the caption
# cannot disagree with where it actually has to go.
func tutorial_receiver():
	var a = tutorial_capsule()
	if a == null:
		return null
	for t in targets:
		if is_instance_valid(t) and t.is_receiver and t.transaction_id == a.transaction_id:
			return t
	return null

func tutorial_receiver_pos() -> Vector2:
	return _screen_of(tutorial_receiver())

# The next door along the capsule's current heading — the one worth turning. Falls back to the
# nearest, so the coach always has something real to point at.
func tutorial_next_door_pos() -> Vector2:
	var a = tutorial_capsule()
	if a == null or doors.is_empty():
		return Vector2.ZERO
	var p: Vector2i = a.board_pos
	var step: Vector2i = Vector2i(game.DirArray[int(a.direction)])
	for _i in 40:
		p += step
		if not game.in_board(p):
			break
		for d in doors:
			if is_instance_valid(d) and d.board_pos == p:
				return _screen_of(d)
	var best = null
	var best_d: float = 1e9
	for d2 in doors:
		if not is_instance_valid(d2):
			continue
		var dist: float = Vector2(d2.board_pos - a.board_pos).length()
		if dist < best_d:
			best_d = dist
			best = d2
	return _screen_of(best)

func tutorial_has_door() -> bool:
	return tutorial_next_door_pos() != Vector2.ZERO

extends CanvasLayer

enum Dirs {right=0,down=1,left=2,up=3}
enum DoorTypes {open=0, backslash=1, slash=2}
const DirArray = [Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0), Vector2i(0,-1)]

var game: GenericGameUtil

class OneCell:
	var ispipe: bool = false
	var door_type: int = -1
	var has_agent: bool = false
	var istarget: bool = false
	
var times_to_answer: Array = []
var _round_start_ms: int = 0

var start_dispatch: bool = false
var time_between_dispatches_ms = 5000
var board: Array
var ntargets: int = 7
var agents = []
var targets = []
var target_positions = []
var target_lobbies = []
var pipes = []
var empties = []
var doors = []
var agent_positions = []
var time_started_level = 0
var num_more_packets = 0
var num_more_agents = 0

# --- tutorial staging (all inert outside tutorial_mode) ---------------------
# The dispatch timer refuses to fire while game.paused(), and a coached tutorial is paused for
# every caption — so the coach dispatches the truck itself instead of waiting for the timer.
var tutorial_hold_dispatch: bool = false
# Stops the trucks between ticks. The door lesson is an ACTION step, so the game is unpaused and
# the truck would drive on while the player hunts for the door being pointed at.
var tutorial_hold_trucks: bool = false
# The door the coach is pointing at, pinned. Without this the target is recomputed from the truck's
# heading every frame, so the frame hops from door to door as it drives.
var tutorial_locked_door: Vector2i = Vector2i(-1, -1)
var level: int = 1

@export var player_scene: PackedScene = load("res://deliverem/scenes/player.tscn")
@export var pipe_scene: PackedScene = load("res://deliverem/scenes/pipe.tscn")
@export var empty_scene: PackedScene = load("res://deliverem/scenes/empty_space.tscn")
@export var agent_scene: PackedScene = load("res://deliverem/scenes/agent.tscn")
@export var door_scene: PackedScene = load("res://deliverem/scenes/door.tscn")
@export var target_scene: PackedScene = load("res://deliverem/scenes/target.tscn")

var dispatch_audio = preload("res://art/sounds/kenney/Audio/impactBell_heavy_003.ogg")
var delivery_audio = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var door_audio = preload("res://art/sounds/door-open-sound-1.mp3")
var motor_audio = preload("res://art/sounds/engine-pulling-something.mp3")

var player

signal game_over(didwin:bool)
signal started_playing
signal new_packet_message(text, isdispatch, col)
signal show_reminder(text)
signal sig_level_is_done(didwin:bool)
# signal update_score_time(add_score, add_time)

func _ready() -> void:
	game = DeliveremG.game
	game.sig_time_over.connect(on_time_over)
	level = DeliveremG.starting_level
	increase_difficulty(false)
	player = player_scene.instantiate()
	add_child(player)

	game.add_sound(self, "door", door_audio, false)
	game.add_sound(self, "motor", motor_audio, true)

	game.add_sound(self, "dispatch", dispatch_audio, false)
	game.add_sound(self, "delivery", delivery_audio, false)

	# new_game()
	
func new_game(from_scratch=true):
	if from_scratch:
		level = DeliveremG.starting_level
	if game.tutorial_mode:
		_tutorial_setup()
	increase_difficulty(false)
	time_last_dispatch = -10000
	player.reset()
	create_board()
	time_started_level = MainGlobals.timems()
	if game.tutorial_mode:
		tutorial_dispatch_now()
	started_playing.emit()
	if not game.tutorial_mode:
		BE.upsert_game_state("Deliverem", 
			{"state":"new","level": level, "num_agents": DeliveremG.num_agents, "num_packets": DeliveremG.num_packets})

func _input(event) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if event.is_action_pressed("reminder") or event.is_action_pressed("clue"):
		display_reminder()
	elif event.is_action_pressed("mainmenu"):
		game.stop_sound("motor")
	
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
			var add_v = DirArray[add_idx]
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
	show_hide_walls()
				
	for pipe in pipes:
		pipe.set_rot(board)
		
	# add doors			
	var door
	for row in game.board_size.y:
		for col in game.board_size.x:
			var p = Vector2i(col,row)
			if board[p.y][p.x].ispipe and p != player.board_pos:
				var nbranches = 0
				for d in DirArray:
					var q = p+d
					var inside = q.x >= 0 and q.y >= 0 and q.x < game.board_size.x and \
						q.y < game.board_size.y
					if inside and board[q.y][q.x].ispipe:
						nbranches += 1
				if nbranches > 2:
					var door_type
					#if p == player.board_pos + Vector2i(0,2):
					if (p - player.board_pos).length() < 5:
						door_type = 0
					else:
						door_type = rng.randi_range(0,2)
						
					if door_type == 0 and p.x == player.board_pos.x and \
						p.y - player.board_pos.y < 5:
							if !board[p.y+1][p.x].ispipe:
								door_type = rng.randi_range(1,2)

					board[p.y][p.x].door_type = door_type
					door = door_scene.instantiate()
					door.position = game.board_to_px(p)
					door.set_board_pos(p)
					#door.rotate(door_type * PI/4.0)
					add_child(door)
					door.set_rot(door_type)
					door.door_pressed.connect(on_clicked_door)
					doors.append(door)					
					
	for _i in DeliveremG.num_agents + num_more_agents:
		# var p = game.get_agent_start_pos()
		var p = Vector2i(game.board_size.x / 2, 1)
		agent_positions.append(p)

	game.create_fill_screen_camera(self)
	start_dispatch = true
		
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

func add_agent_at(p: Vector2i, direction: int):
	_round_start_ms = MainGlobals.timems()
	var agent = agent_scene.instantiate()
	agent.direction = direction
	agent.board_pos = p
	var possibles = range(1, ntargets+1)
	possibles.shuffle()
	agent.body_ids = possibles.slice(0, DeliveremG.num_packets+num_more_packets)
	var text = "Deliver to " + ",".join(agent.body_ids)
	add_child(agent)
	agents.append(agent)
	agent.set_pos(game.board_to_px(p), direction)
	# AFTER add_child: agent.color is assigned in the agent's _ready(), so announcing the order
	# any earlier sends a null color and the line falls back to the theme's fixed yellow.
	# Carrying the truck's own color is what says WHICH truck an order belongs to when several
	# are out at once — the clue list has always been color-coded this way.
	new_packet_message.emit(text, true, agent.color)
	game.tutorial_notify("agent_dispatched")   # no-op outside tutorial mode
	if not game.is_sound_playing("dispatch"):
		game.play_sound("dispatch")
	if not game.is_sound_playing("motor"):
		MainGlobals.do_after(0.5, func(): game.play_sound("motor"))
	
func display_reminder():
	game.tutorial_notify("reminder_shown")
	var text = []
	for agent in agents:
		text.append([",".join(agent.body_ids), agent.color])
	# var text = ""
	# for agent in agents:
	# 	text += ",".join(agent.body_ids) + "\n"
	# text = text.strip_edges()
	show_reminder.emit(text)
		
func on_clicked_door(pos: Vector2i):
	# A door is an Area2D and its input is not pause-gated, so without this a click lands while a
	# caption, the help screen or a popup is up — and during a tutorial it would satisfy the very
	# step that is still explaining what doors are.
	if game.paused() or not game.playing:
		return
	#if board[pos.y][pos.x].has_agent:
		#return
	var any_changed: bool = false
	for i in doors.size():
		var door = doors[i]
		if door.board_pos == pos:
			var current = door.rot_idx
			var newdir = (current + 1) % 3
			door.set_rot(newdir)
			#door.rotate(PI/4.0)
			board[pos.y][pos.x].door_type = newdir
			any_changed = true
			break
	if any_changed:
		game.play_sound("door")
		game.tutorial_notify("door_turned")

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
	game.stop_sound("motor")
	return true
	
var last_major_tick_ms = -10000.0
func tick():
	if game.level_is_done:
		return
	if tutorial_hold_trucks:
		return
	var t = MainGlobals.timems()
	if t - last_major_tick_ms < game.major_tick_time_ms * game.time_scale:
		return
	last_major_tick_ms = t
	if all_agents_done():
		if game.tutorial_mode:
			return
		level_is_done(true)
		return
	for agent in agents:
		if MainGlobals.timems() - agent.time_created < 2000:
			continue
		var p = agent.board_pos
		var adj_tar_id = get_adjacent_target_id(p)
		var _removed_body_part = false
		if adj_tar_id >= 0:
			_removed_body_part = agent.remove_body_if_first(adj_tar_id)
			if _removed_body_part:
				game.play_sound("delivery")
				game.delivered_one()
				game.tutorial_notify("packet_delivered")
				if agent.body_ids.is_empty():
					_record_answer_time()
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

	if all_agents_done():
		level_is_done(true)

func get_adjacent_target_id(q):
	for i in target_positions.size():
		var p = target_positions[i]
		var d = (p-q).length()
		if abs(d-1) < 1e-3:
			var target = targets[i]
			var target_id = target.id
			return target_id
	return -1

func _on_level_done_popup_closed():
	sig_level_is_done.emit(true)

func level_is_done(didwin: bool):
	game.level_is_done = true
	game.stop_sound("motor")
	BE.send_event("level_done", "Deliverem", {
		"level": level,
		"didwin": int(didwin),
		"num_agents": DeliveremG.num_agents,
		"num_packets": DeliveremG.num_packets
	})
	start_dispatch = false
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

func increase_difficulty(increase=true):
	if increase:
		level += 1
	var s = 17
	game.max_board_size = Vector2i(s,s)
	if level == 1:
		num_more_packets = 0
		num_more_agents = 0
	elif level == 2:
		num_more_packets = 1
	elif level == 3:
		num_more_packets = 2
	elif level == 4:
		num_more_packets = 3
	elif level == 5:
		num_more_packets = 3
	elif level == 6:
		num_more_packets = 0
		num_more_agents = 1
	elif level == 7:
		num_more_packets = 1
		num_more_agents = 1
	elif level == 8:
		num_more_packets = 2
		num_more_agents = 2
	elif level >= 9:
		num_more_packets = 3
		num_more_agents = 3
	if MainGlobals.is_mobile():
		var bsh = 4
		var bsv = 0
		game.max_board_size -= Vector2i(bsh,bsv)
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
		
func on_time_over():
	game.stop_sound("motor")

# --- tutorial staging -------------------------------------------------------

func _tutorial_setup() -> void:
	# A smaller yard than the real level 1: four docks instead of seven, so the maze the player is
	# asked to read is a yard rather than a wall of pipes.
	ntargets = 4
	tutorial_hold_dispatch = true

# _on_agent_dispatch_timer_timeout() only dispatches while the game is UNPAUSED, and a coached
# tutorial is paused for every caption — so left to the timer the truck would not appear until the
# first step that hands control back, several captions after the coach starts pointing at it.
func tutorial_dispatch_now() -> void:
	if not agents.is_empty() or agent_positions.is_empty():
		return
	add_agent_at(agent_positions[0], 1)
	start_dispatch = false

# --- things for the coach to point at (all in SCREEN coordinates) -----------

func tutorial_agent():
	for a in agents:
		if is_instance_valid(a):
			return a
	return null

func tutorial_agent_pos() -> Vector2:
	var a = tutorial_agent()
	if a == null:
		return Vector2.ZERO
	return (a as Node2D).get_global_transform_with_canvas().origin

# The dock the truck must visit NEXT — the head of its queue, and the only one that will take
# anything. Skips ids whose removal is still animating (see delemfp: body_ids does not shrink
# until final_remove_body runs from a tween callback, ~0.5s after the delivery).
func tutorial_next_dock_id() -> int:
	var a = tutorial_agent()
	if a == null:
		return -1
	for id in a.body_ids:
		if not (id in a._pending_remove_ids):
			return int(id)
	return -1

func tutorial_packets_left() -> int:
	var a = tutorial_agent()
	if a == null:
		return 0
	return maxi(0, a.body_ids.size() - a._pending_remove_ids.size())

func tutorial_dock_pos(dock_id: int) -> Vector2:
	for i in targets.size():
		if is_instance_valid(targets[i]) and int(targets[i].id) == dock_id:
			return (targets[i] as Node2D).get_global_transform_with_canvas().origin
	return Vector2.ZERO

func tutorial_next_dock_pos() -> Vector2:
	return tutorial_dock_pos(tutorial_next_dock_id())

# ONE dock, for "this is a dock". Framing all four spans practically the whole screen, which
# tells the player nothing and leaves the caption nowhere to sit that does not overlap it.
func tutorial_a_dock_id() -> int:
	var best: int = -1
	for t in targets:
		if not is_instance_valid(t):
			continue
		if best < 0 or int(t.id) < best:
			best = int(t.id)
	return best

func tutorial_all_docks_rect() -> Rect2:
	var res: Rect2 = Rect2()
	for t in targets:
		if not is_instance_valid(t):
			continue
		var c: Vector2 = (t as Node2D).get_global_transform_with_canvas().origin
		var r: Rect2 = Rect2(c - Vector2(26, 26), Vector2(52, 52))
		res = r if res.size.x <= 0.0 else res.merge(r)
	return res

# The door the truck will reach next along its current heading — the one the player would actually
# want to turn. Falls back to the nearest door, so the coach always has something real to point at.
func tutorial_next_door_pos() -> Vector2:
	if tutorial_locked_door.x >= 0:
		for d in doors:
			if is_instance_valid(d) and d.board_pos == tutorial_locked_door:
				return (d as Node2D).get_global_transform_with_canvas().origin
	var a = tutorial_agent()
	if a == null or doors.is_empty():
		return Vector2.ZERO
	var p: Vector2i = a.board_pos
	var step: Vector2i = Vector2i(DirArray[int(a.direction)])
	for _i in 40:
		p += step
		if not game.in_board(p):
			break
		for d in doors:
			if is_instance_valid(d) and d.board_pos == p:
				return (d as Node2D).get_global_transform_with_canvas().origin
	var best = null
	var best_d: float = 1e9
	for d in doors:
		if not is_instance_valid(d):
			continue
		var dist: float = Vector2(d.board_pos - a.board_pos).length()
		if dist < best_d:
			best_d = dist
			best = d
	return (best as Node2D).get_global_transform_with_canvas().origin if best != null else Vector2.ZERO

# Pin the door the coach will talk about, so the frame stays where it was put.
func tutorial_lock_next_door() -> void:
	tutorial_locked_door = Vector2i(-1, -1)
	var a = tutorial_agent()
	if a == null:
		return
	var p: Vector2i = a.board_pos
	var step: Vector2i = Vector2i(DirArray[int(a.direction)])
	for _i in 40:
		p += step
		if not game.in_board(p):
			break
		for d in doors:
			if is_instance_valid(d) and d.board_pos == p:
				tutorial_locked_door = p
				return
	# nothing straight ahead: pin the nearest door instead, so there is always a real target
	var best_d: float = 1e9
	for d2 in doors:
		if not is_instance_valid(d2):
			continue
		var dist: float = Vector2(d2.board_pos - a.board_pos).length()
		if dist < best_d:
			best_d = dist
			tutorial_locked_door = d2.board_pos

func tutorial_unlock_door() -> void:
	tutorial_locked_door = Vector2i(-1, -1)

func tutorial_has_door() -> bool:
	return tutorial_next_door_pos() != Vector2.ZERO

# The HUD line the dispatcher wrote the order on ("Deliver to 3,1"). Set by main.start_tutorial;
# the level has no HUD of its own.
var tutorial_hud: Node = null

func tutorial_dispatch_label() -> Control:
	if tutorial_hud == null or not is_instance_valid(tutorial_hud):
		return null
	var lbl = tutorial_hud.get_node_or_null("Dispatch")
	return lbl if lbl is Control and (lbl as Control).is_visible_in_tree() else null

func tutorial_hide_dispatch() -> void:
	var lbl = tutorial_dispatch_label()
	if lbl != null:
		lbl.hide()

func tutorial_bottom_button(node_name: String) -> Control:
	var b = get_tree().root.find_child(node_name, true, false)
	return b if b is Control and (b as Control).is_visible_in_tree() else null


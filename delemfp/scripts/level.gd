extends CanvasLayer

var game: GenericGameUtil

class OneCell:
	var ispipe: bool = false
	var has_agent: bool = false
	var istarget: bool = false
	
var times_to_answer: Array = []
var _round_start_ms: int = 0

var halt: bool = false
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
var agent_positions = []
var num_more_packets = 0
var time_started_level = 0
var level: int = 1
var player

# --- tutorial staging (all inert outside tutorial_mode) ---------------------
# The coach decides when the camera drops onto the truck, so the memorisation window is not a
# 5-second timer running under a caption the player is still reading.
var tutorial_hold_camera: bool = false
var tutorial_hud: Node = null
var _tutorial_countdown_running: bool = false
var _tutorial_countdown_seen: bool = false

@export var player_scene: PackedScene = load("res://delemfp/scenes/player.tscn")
@export var pipe_scene: PackedScene = load("res://delemfp/scenes/pipe.tscn")
@export var empty_scene: PackedScene = load("res://delemfp/scenes/empty_space.tscn")
@export var agent_scene: PackedScene = load("res://delemfp/scenes/agent.tscn")
@export var target_scene: PackedScene = load("res://delemfp/scenes/target.tscn")

var dispatch_audio = preload("res://art/sounds/kenney/Audio/impactBell_heavy_003.ogg")
var delivery_audio = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var motor_audio = preload("res://art/sounds/engine-pulling-something.mp3")

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
	if game.tutorial_mode:
		_tutorial_setup()
	time_to_start_camera = -1
	increase_difficulty(false)
	halt = false
	time_last_dispatch = -10000
	player.reset()
	create_board()
	time_started_level = MainGlobals.timems()
	started_playing.emit()
	if game.tutorial_mode:
		tutorial_dispatch_now()
	if not game.tutorial_mode:
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
		
var time_to_start_camera: int = -1

func _process(_delta: float) -> void:
	if time_to_start_camera > 0 and MainGlobals.timems() >= time_to_start_camera:
		time_to_start_camera = -1
		create_camera()
	_tutorial_watch_countdown()

# Zoom in when the countdown the PLAYER can see reaches zero.
#
# MainGlobals.sig_global_countdown_finished cannot be used for this. Two HUDs listen to the global
# countdown: this game's, and the spare GenericGameHUD in the app root. The root's has no `game`
# reference, so its `if game and game.paused()` guard never fires and it keeps counting in real
# time under a tutorial caption — reaching zero, and emitting the finished signal, while the
# visible countdown is still frozen at 5. That is what zoomed the camera in mid-caption and then
# left the truck driving with the countdown still ticking down on screen.
#
# The visible label is the source of truth: the HUD hides it exactly when it hits zero.
func _tutorial_watch_countdown() -> void:
	if not _tutorial_countdown_running:
		return
	if tutorial_countdown_label() != null:
		_tutorial_countdown_seen = true
		return
	if not _tutorial_countdown_seen:
		return   # not shown yet; do not mistake "not started" for "finished"
	_tutorial_countdown_running = false
	halt = false
	if agent_cam == null:
		create_camera()

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
	game.tutorial_notify("agent_dispatched")   # no-op outside tutorial mode
	if tutorial_hold_camera:
		# No 5-second countdown and no zoom yet: the coach shows the board, names the list, and
		# only then hands over the controls.
		return
	time_to_start_camera = MainGlobals.timems() + 5000
	MainGlobals.global_start_countdown(5)
	MainGlobals.sig_global_countdown_finished.connect(_on_sig_global_countdown_finished)
	# await MainGlobals.sleep(5)
	# create_camera()
	
func _on_sig_global_countdown_finished():
	halt = false

func display_reminder():
	game.tutorial_notify("reminder_shown")
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
		if game.tutorial_mode:
			return
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
				game.tutorial_notify("packet_delivered")
				if agent.body_ids.is_empty():
					_record_answer_time()
			elif not agent.body_ids.is_empty():
				# Drove past a dock and nothing came off it: either it is not on the list at all,
				# or it is not first yet. The one rule of the game, seen from the wrong side.
				game.tutorial_notify("passed_dock")
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
	if not game.tutorial_mode:
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
	game.tutorial_notify("steered")
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
	game.tutorial_notify("zoomed_in")   # no-op outside tutorial mode

func zoom_unzoom():
	game.tutorial_notify("unzoomed")
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

# --- tutorial staging -------------------------------------------------------

func _tutorial_setup() -> void:
	# A smaller yard than the real level 1: four docks instead of seven, so the maze the player is
	# asked to read in one look is a yard rather than a wall of pipes.
	ntargets = 4
	tutorial_hold_camera = true

# _on_agent_dispatch_timer_timeout() only dispatches while the game is unpaused, and a coached
# tutorial is paused for every caption — so left to the timer the truck would not appear until the
# first step that hands control back, four captions after the coach starts pointing at it.
func tutorial_dispatch_now() -> void:
	if not agents.is_empty() or agent_positions.is_empty():
		return
	add_agent_at(agent_positions[0], 1)
	start_dispatch = false

# Run the real dispatch sequence: whole map and delivery order visible, a five-second countdown,
# and only when it reaches zero does the camera drop onto the truck and the controls unlock. The
# HUD's countdown timer skips a tick while game.paused(), so a caption holds it frozen at 5 — which
# is how the coach can point at it and explain it before it starts running.
#
# The camera is taken off the countdown-finished signal rather than off `time_to_start_camera`,
# whose wall-clock comparison in _process is NOT pause-aware and would zoom in mid-caption.
func tutorial_start_countdown() -> void:
	_tutorial_countdown_running = true
	_tutorial_countdown_seen = false
	MainGlobals.global_start_countdown(5)

# --- step timing, for steps that demonstrate themselves if the player cannot ----------------
# A tutorial step must never be a dead end. These two are the only ones that depend on a control
# OUTSIDE the game's own scene (the app's bottom bar), which is the one thing a game's tutorial
# cannot fully account for. If the press does not come, the coach performs it instead and the
# lesson still lands — the player sees what the button does and the tutorial moves on.
var _tutorial_step_started_ms: int = 0

func tutorial_mark_step() -> void:
	_tutorial_step_started_ms = MainGlobals.timems()

func tutorial_step_elapsed_sec() -> float:
	return float(MainGlobals.timems() - _tutorial_step_started_ms) / 1000.0

# End a zoom-out immediately instead of waiting out zoom_unzoom()'s 4-second sleep.
#
# That sleep holds DelemfpG.freeze true — movement is refused while zoomed out, by design. A step
# that says "now steer" can arrive inside those 4 seconds, and then the controls genuinely do
# nothing for a moment, which is exactly what a player reads as a broken game. The coroutine will
# set both of these again when it resumes; doing it early is harmless.
func tutorial_end_zoom_out() -> void:
	if agent_cam != null and is_instance_valid(agent_cam):
		agent_cam.enabled = true
	DelemfpG.freeze = false

# Park the truck. Between the zoom and the "take it to dock N" step the game is UNPAUSED (those
# steps wait on a button press), so the truck would drive off on its own — and if it happened to
# roll past the right dock it would deliver a packet the coach was not waiting for. The runner
# holds one pending event, so a delivery spent there is a delivery the last step waits for forever.
# `halt` is the game's own mechanism for this: it stops the truck and blocks move_dir.
func tutorial_hold_truck(hold: bool) -> void:
	halt = hold

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

# The dock number the truck must visit NEXT — the head of the queue, and the only one that will
# accept anything.
# Skips ids that are mid-removal, for the same reason tutorial_packets_left() subtracts them:
# body_ids does not shrink until final_remove_body runs from a tween callback ~0.5s after the
# delivery. Reading body_ids[0] in that window names the dock the player has JUST served, so the
# coach sent them back to the one they had already done.
func tutorial_next_dock_id() -> int:
	var a = tutorial_agent()
	if a == null:
		return -1
	for id in a.body_ids:
		if not (id in a._pending_remove_ids):
			return int(id)
	return -1

# body_ids does NOT shrink when a packet is delivered: remove_body() starts a shrink tween and the
# id is only dropped in final_remove_body, ~0.5s later from the tween callback. Reading the raw
# size right after a delivery therefore still counts the packet just handed over — which is how the
# coach came to say "one down, 2 to go" on a two-packet run. _pending_remove_ids holds exactly the
# ones in flight.
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

# All the docks at once, for "these are the loading docks".
func tutorial_all_docks_rect() -> Rect2:
	var res: Rect2 = Rect2()
	for t in targets:
		if not is_instance_valid(t):
			continue
		var c: Vector2 = (t as Node2D).get_global_transform_with_canvas().origin
		var r: Rect2 = Rect2(c - Vector2(26, 26), Vector2(52, 52))
		res = r if res.size.x <= 0.0 else res.merge(r)
	return res

# A button on the app's bottom bar, so the coach can point at the control it is talking about
# rather than describing where it is. Lives in the root scene, not in this game's tree.
func tutorial_bottom_button(node_name: String) -> Control:
	var b = get_tree().root.find_child(node_name, true, false)
	return b if b is Control and (b as Control).is_visible_in_tree() else null

# The big number the countdown draws, so the coach can point at it instead of describing where it
# is. Lives in the shared HUD, not in this game's tree.
func tutorial_countdown_label() -> Control:
	if tutorial_hud == null or not is_instance_valid(tutorial_hud):
		return null
	var lbl = tutorial_hud.get_node_or_null("CountdownLabel")
	return lbl if lbl is Control and (lbl as Control).is_visible_in_tree() else null

func tutorial_hide_dispatch() -> void:
	var lbl = tutorial_dispatch_label()
	if lbl != null:
		lbl.hide()

# The HUD line the dispatcher wrote the order on ("Deliver to 3,1"). Set by main.start_tutorial;
# the level has no HUD of its own.
func tutorial_dispatch_label() -> Control:
	if tutorial_hud == null or not is_instance_valid(tutorial_hud):
		return null
	var lbl = tutorial_hud.get_node_or_null("Dispatch")
	return lbl if lbl is Control and (lbl as Control).is_visible_in_tree() else null


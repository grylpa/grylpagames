extends CanvasLayer

enum Dirs {right=0,down=1,left=2,up=3}
enum DoorTypes {open=0, backslash=1, slash=2}
const DirArray = [Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0), Vector2i(0,-1)]

var rng = RandomNumberGenerator.new()		

var game: GenericGameUtil

class OneCell:
	var ispipe := false
	var door_type := -1
	var has_agent := false
	var room_id := -1
	var color_idx := -1
	var pipe = null
	var is_corridor = false

	func is_fillable() -> bool:
		return ispipe && door_type < 0 && !has_agent && pipe.can_fill()
	
var times_to_answer := []
var _round_start_ms := 0

var rounds_per_level: int = 3
var start_dispatch := false
var time_between_dispatches_ms = 5000
var board: Array
var agents = []
var pipes = []
var empties = []
var doors = []
var coins = {}
var agent_start_positions = []
var agent_start_directions = []
var time_started_level_ms = 0
var time_increased_difficulty_ms = 0
var level: int = 0
var round_in_level: int = 0

# Set when the level's last round has been judged, so the next new_game() knows it is
# starting a LEVEL and not just the next round.
var _level_is_over: bool = false
# The level gate counts FULLY CORRECT rounds: every room named right, first try, and the round
# survived. It cannot ride on game.corrects / game.mistakes the way the other gated games do,
# because here those two already count ROOM ANSWERS and the HUD shows them.
var _rounds_played: int = 0
var _rounds_fully_correct: int = 0
var _round_had_wrong_answer: bool = false
# What the score was when this level began; a level that misses the gate goes back to it.
var _score_at_level_start: int = 0
var _rollback_score_on_next_level: bool = false
var num_more_packets = 0
var num_rooms := 4
var num_distracting_colors := 0
var player = null
var player_max_speed_scale = 1.5
var agent_max_speed_scale = 1.0
var next_player_dir = -1
var time_to_hide := 0
var play_start_sound := true
var num_bomb_agents_to_add := 3
var num_bricks_per_room := 2
var MAX_POSSIBLE_ROOMS := 12
var MAX_COLORS_TO_USE := 12
var last_level_was_a_win := true
var in_answring_mode := false
@export var pipe_scene: PackedScene = load("res://mmm/scenes/pipe.tscn")
@export var empty_scene: PackedScene = load("res://mmm/scenes/empty_space.tscn")
@export var agent_scene: PackedScene = load("res://mmm/scenes/agent.tscn")
@export var door_scene: PackedScene = load("res://mmm/scenes/door.tscn")
@export var player_scene: PackedScene = load("res://mmm/scenes/player.tscn")

var explosion_audio := preload("res://art/sounds/car-crash-1.mp3")
var motor_audio := preload("res://art/sounds/car-ambient-driving.ogg")
var feet_audio := preload("res://art/sounds/kenney/Audio/footstep_grass_001.ogg")
var delivered_audio := preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var start_audio := preload("res://art/sounds/click-2.mp3")
var swoosh_audio := preload("res://art/sounds/swoosh.mp3")
var dispatch_audio := preload("res://art/sounds/kenney/Audio/impactBell_heavy_003.ogg")
var gaveup_audio := preload("res://art/sounds/bump-sound-7.mp3")

signal started_playing
signal sig_level_is_done(didwin:bool)

var _field: Control = null

signal delivered_one
signal collision
signal update_score(score:int)

func _ready() -> void:
	game = MmmG.game
	game.sig_time_over.connect(on_time_over)
	game.sig_lives_depleted.connect(on_lives_depleted)
	level = MmmG.starting_level
	round_in_level = 0
	_apply_level()
	# After _apply_level(), which is what sets the board's geometry: the lawn exists before anything
	# is shown, so the first thing on screen is grass rather than the window's clear colour.
	_fit_ground_to_board()

	game.add_sound(self, "explosion", explosion_audio)
	game.add_sound(self, "motor", motor_audio, true)
	game.add_sound(self, "feet", feet_audio, true)
	game.add_sound(self, "delivery", delivered_audio)
	game.add_sound(self, "start", start_audio)
	game.add_sound(self, "swoosh", swoosh_audio)
	game.add_sound(self, "dispatch", dispatch_audio)	
	game.add_sound(self, "gaveup", gaveup_audio)	

	MAX_COLORS_TO_USE = min(MAX_COLORS_TO_USE, game.colors.size())
	if not MainGlobals.sig_game_popup_closed.is_connected(_on_game_popup_closed):
		MainGlobals.sig_game_popup_closed.connect(_on_game_popup_closed)
	if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
		MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
	MainGlobals.sig_path_drawn.connect(_on_path_drawn)  
	
func reset():
	start_dispatch = false
	next_player_dir = -1
	time_to_hide = 0
	play_start_sound = true

	if player != null:
		player.queue_free()
		player = null
	player_cam = null

	if game_cam != null:
		game_cam.queue_free()
		game_cam = null

	for c in pipes:
		c.queue_free()
	for c in agents:
		c.queue_free()
	for c in doors:
		c.queue_free()
	for c in empties:
		c.queue_free()
	for c in small_popups.keys():
		small_popups[c].queue_free()
	pipes.clear()
	empties.clear()
	agents.clear()
	doors.clear()
	small_popups.clear()
	coins.clear()

	agent_start_positions = []
	agent_start_directions = []
	time_started_level_ms = 0
	num_more_packets = 0

func new_game(from_scratch=true):
	reset()
	$BuildingLabel.show()
	await get_tree().process_frame
	if from_scratch:
		level = MmmG.starting_level
		round_in_level = 0
		# The first level of a session starts clean and stamps its own starting score; every later
		# level does the same from _advance_if_needed().
		_level_is_over = false
		_rollback_score_on_next_level = false
		_rounds_played = 0
		_rounds_fully_correct = 0
		_round_had_wrong_answer = false
		_score_at_level_start = game.score
		game.time_scale = 0.5
	_advance_if_needed()
	game.need_to_increase_level = false
	time_last_dispatch = -10000
	pos_last_dispatch = Vector2i(-1,-1)
	in_answring_mode = false
	create_board()
	time_started_level_ms = MainGlobals.timems()
	time_increased_difficulty_ms = time_started_level_ms
	started_playing.emit()
	BE.upsert_game_state("Mmm",
		{"state":"new","level": level, "round_in_level": round_in_level})

func _input(event) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if event.is_action_pressed("new_board"):
		update_score.emit(-1)
	# elif event.is_action_pressed("clue"):
	# 	show_clue()
	elif event.is_action_pressed("right") or event.is_action_pressed("ui_right"):
		move_dir(0)
	elif event.is_action_pressed("down") or event.is_action_pressed("ui_down"):
		move_dir(1)
	elif event.is_action_pressed("left") or event.is_action_pressed("ui_left"):
		move_dir(2)
	elif event.is_action_pressed("up") or event.is_action_pressed("ui_up"):
		move_dir(3)
	elif event.is_action_pressed("stop"):
		next_player_dir = -1
		if player != null:
			player.path.clear()

func move_dir(dir):
	if player == null or !game.level_is_ready:
		return
	game.tutorial_notify("player_moved")   # no-op outside tutorial mode
	player.path.clear()

	next_player_dir = dir
	if abs(dir - player.direction) == 2:
		player.last_major_tick_ms = 0
		tick(true)

func _start_playing():
	if play_start_sound:
		play_start_sound = false
		game.play_sound("start")
		if player != null:
			player.play()

func _process(_delta: float) -> void:
	if player != null and !player.was_hit:
		if time_to_hide > 0 and MainGlobals.timems() >= time_to_hide:
			_start_playing()
		check_agent_collisions()
	
func add_pipe(p, room_id := -1):
	if board[p.y][p.x].ispipe:
		if room_id >= 0:
			board[p.y][p.x].room_id = room_id
		return
	board[p.y][p.x].ispipe = true
	var pipe = pipe_scene.instantiate()
	board[p.y][p.x].pipe = pipe
	pipe.board_pos = p
	pipe.position = game.board_to_px(p)
	board[p.y][p.x].room_id = room_id
	add_child(pipe)
	pipes.append(pipe)
	pipe.pipe_pressed.connect(_on_pipe_pressed)

func _check_if_all_rooms_answered():
	for rid in rooms.size():
		if not answered_rooms.has(rid):
			return false
	# game.play_sound("delivery")
	_record_answer_time()
	# Decided HERE, not inside level_is_done: this is deferred by a second, and by the time it fires
	# the player has usually tapped through the closing caption and the tutorial has ended — so a
	# guard that reads tutorial_mode at that moment sees false and shows the panel anyway. That is
	# exactly how "Round 1 of Level 1 completed" kept appearing after the tutorial.
	var during_tutorial: bool = game.tutorial_mode
	MainGlobals.do_after(1, func():
		if during_tutorial:
			return
		level_is_done(true))
	return true

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

func answered(correct: bool):
	if correct:
		# Only a CORRECT answer moves the coach on. A wrong pick leaves the palette open and the
		# room unnamed, so the player should stay on the step and try again rather than be told
		# "now do the other room" while this one is still unanswered.
		game.tutorial_notify("room_answered")   # no-op outside tutorial mode
		game.add_score_and_time(1,5)
		game.add_correct_or_mistake(1,0)
		game.play_sound("delivery")
		_check_if_all_rooms_answered()
	else:
		game.add_score_and_time(-1,-5)
		game.add_correct_or_mistake(0,1)
		# One wrong pick is enough: the round can still be finished (the palette stays open and the
		# player tries again) but it is no longer a fully correct one, and that is what the level
		# gate counts.
		_round_had_wrong_answer = true
		game.play_sound("gaveup")

func _on_pipe_pressed(_board_pos):
	var cell = board[_board_pos.y][_board_pos.x]
	if in_answring_mode and cell.room_id >= 0:
	# if cell.color_idx >= 0:
		var did_answer:bool = answered_rooms.get(cell.room_id,false)
		if not did_answer:
			create_color_selection_popup(cell.room_id, false)
		# if cell.color_idx == cell.room_id:
		# 	answered_rooms[cell.room_id] = true
		# 	var room = rooms[cell.room_id]
		# 	for row in range(room.position.y, room.end.y):
		# 		for col in range(room.position.x, room.end.x):
		# 			var p = Vector2i(col,row)
		# 			if board[p.y][p.x].ispipe:
		# 				board[p.y][p.x].color_idx = cell.room_id
		# 				board[p.y][p.x].pipe.set_rot(board)
		# 	answered(true)
		# else:
		# 	answered(false)
			

func add_empty(p):
	var e = empty_scene.instantiate()
	e.board_pos = p
	e.position = game.board_to_px(p)
	add_child(e)
	empties.append(e)

func dist_from_agents_and_player(p):
	var d = dist_from_agents(p)
	return min(d, (p - player.board_pos).length())

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
	
var room_min_size = 5
var room_max_size = 10
var board_margin = 5

#region create_rooms

func _carve_room(pos: Vector2i, size: Vector2i, room_id:int) -> void:
	for y in range(pos.y, pos.y + size.y):
		for x in range(pos.x, pos.x + size.x):
			add_pipe(Vector2i(x, y), room_id)

var rooms:Array[Rect2i] = []
var rooms_checked_connections = {}
var visited_rooms = {}
var answered_rooms = {}

func did_visit_all_rooms() -> bool:
	for rid in rooms.size():
		if not visited_rooms.has(rid):
			return false
	return true

func create_rooms(nrooms := 4, margin := 5, RD := 5, PAD := 3) -> void:
	# RD: how "spread" placements can be around an anchor (bigger = looser)
	# PAD: minimum gap between rooms (1 = one tile gap; 0 = can touch)
	var center = game.board_size / 2

	rooms.clear()
	rooms_checked_connections.clear()
	visited_rooms.clear()
	answered_rooms.clear()

	var w0 = rng.randi_range(room_min_size, room_max_size) | 1
	var h0 = rng.randi_range(room_min_size, room_max_size) | 1
	var p0 = center - Vector2i(w0 / 2, h0 / 2)

	# Clamp room 0 into bounds
	p0.x = clamp(p0.x, margin, game.board_size.x - margin - w0)
	p0.y = clamp(p0.y, margin, game.board_size.y - margin - h0)

	var next_room_id = 0
	rooms.append(Rect2i(p0, Vector2i(w0, h0)))
	_carve_room(p0, Vector2i(w0, h0), next_room_id)
	next_room_id += 1

	RD = clamp(RD, 2, 5)

	for k in range(1, nrooms):
		var placed = false

		for attempt in range(900):
			var rw = (rng.randi_range(room_min_size, room_max_size) | 1)
			var rh = (rng.randi_range(room_min_size, room_max_size) | 1)
			var rsize = Vector2i(rw, rh)

			# --- Pick an anchor room to cluster around ---
			# Early attempts prefer lower IDs (usually nearer center); later attempts allow any
			var anchor_idx = 0
			if rooms.size() > 1:
				if attempt < 350:
					anchor_idx = rng.randi_range(0, min(rooms.size() - 1, 1))
				elif attempt < 700:
					anchor_idx = rng.randi_range(0, min(rooms.size() - 1, 2))
				else:
					anchor_idx = rng.randi_range(0, rooms.size() - 1)

			var anchor = rooms[anchor_idx]
			var apos: Vector2i = anchor.position
			var asz: Vector2i = anchor.size

			# --- Place near a side of the anchor, with small jitter ---
			var side = rng.randi_range(0, 3) # 0=up,1=right,2=down,3=left

			# Gap keeps rooms close; PAD prevents touching
			var gap = PAD + rng.randi_range(0, RD)

			var rpos = Vector2i.ZERO
			if side == 0: # above
				rpos.x = (apos.x + asz.x / 2) - rsize.x / 2 + rng.randi_range(-RD, RD)
				rpos.y = apos.y - gap - rsize.y
			elif side == 2: # below
				rpos.x = (apos.x + asz.x / 2) - rsize.x / 2 + rng.randi_range(-RD, RD)
				rpos.y = apos.y + asz.y + gap
			elif side == 1: # right
				rpos.x = apos.x + asz.x + gap
				rpos.y = (apos.y + asz.y / 2) - rsize.y / 2 + rng.randi_range(-RD, RD)
			else: # left
				rpos.x = apos.x - gap - rsize.x
				rpos.y = (apos.y + asz.y / 2) - rsize.y / 2 + rng.randi_range(-RD, RD)

			# Clamp into bounds
			rpos.x = clamp(rpos.x, margin, game.board_size.x - margin - rsize.x)
			rpos.y = clamp(rpos.y, margin, game.board_size.y - margin - rsize.y)

			if not game.rect_in_board(rpos, rsize, margin):
				continue

			# Enforce minimal spacing (PAD), not big RD
			var ok = true
			for r in rooms:
				if Rect2i(rpos, rsize).grow(PAD).intersects(r.grow(PAD)):
					ok = false
					break
			if not ok:
				continue

			rooms.append(Rect2i(rpos, rsize))
			_carve_room(rpos, rsize, next_room_id)
			next_room_id += 1

			placed = true
			break

		if not placed:
			break
	
	# for r in rooms:
	# 	print("room ", str(r))
	add_corridors()

func _try_corridor_L(pstart: Vector2i, pend: Vector2i, start_dir: Vector2i) -> Array:
	var d = pend - pstart
	var path = [pstart]
	var has_bend = true
	if d.x == 0:
		has_bend = false
		for y in range(min(pstart.y, pend.y), max(pstart.y, pend.y)):
			var p = Vector2i(pstart.x, y)
			if board[p.y][p.x].ispipe or board[p.y][p.x-1].ispipe or board[p.y][p.x+1].ispipe:
				return []
			path.append(p)		
	elif d.y == 0:
		has_bend = false
		for x in range(min(pstart.x, pend.x), max(pstart.x, pend.x)):
			var p = Vector2i(x, pstart.y)
			if board[p.y][p.x].ispipe or board[p.y-1][p.x].ispipe or board[p.y+1][p.x].ispipe:
				return []
			path.append(p)

	if has_bend:
		var bend:Vector2i
		if start_dir.x != 0:
			bend = Vector2i(pend.x, pstart.y)
		else:
			bend = Vector2i(pstart.x, pend.y)
		if board[bend.y][bend.x].ispipe:
			return []

		var path_seg1 = _try_corridor_L(pstart, bend, start_dir)
		if path_seg1.size() == 0:
			return []
		var path_seg2 = _try_corridor_L(bend, pend, start_dir)
		if path_seg2.size() == 0:
			return []
		path = path_seg1
		path.append_array(path_seg2)

	path.append(pend)
	return path

func find_closest_unconnected_room(room_id: int, rooms_to_check:Array) -> int:
	var min_d = 1e6
	var min_idx = -1
	var c0 = rooms[room_id].get_center()
	for i in rooms_to_check:
		if not rooms_checked_connections.has(Vector2i(room_id,i)):
			var d = c0.distance_squared_to(rooms[i].get_center())
			if d < min_d:
				min_d = d
				min_idx = i
	return min_idx

# main a list of what room is connected to what room
# first try each room to its closest room then only the other pairs
func add_corridors():
	var add_ins = [0,1,-1]
	for i in rooms.size()-1:
		add_ins.shuffle()
		var r1 = rooms[i]
		var s1 = r1.size
		var p1tl = r1.position
		var p1br = p1tl + s1
		var c1 = p1tl + s1 / 2 + Vector2i(add_ins[0], add_ins[1])
		var rooms_to_check = range(i+1,rooms.size())
		# rooms_to_check.erase(i)
		
		while rooms_to_check.size() > 0:
			var j = find_closest_unconnected_room(i, rooms_to_check)
			if j < 0:
				# j = rooms_to_check.pop_front()
				break
			else:
				rooms_to_check.erase(j)
			if rooms_checked_connections.has(Vector2i(j,i)):
				continue
			add_ins.shuffle()
			var r2 = rooms[j]
			var s2 = r2.size
			var p2tl = r2.position
			var p2br = p2tl + s2
			var c2 = p2tl + s2 / 2 + Vector2i(add_ins[0], add_ins[1])

			var exit_walls = ["L","R","T","B"]
			var entrance_walls = ["L","R","T","B"]

			var path_bounding_rect = (r1.merge(r2)).grow(3)
			var shortest_path = []

			# print("connecting room ", i, " to ", j)
			for ew in exit_walls:
				for iw in entrance_walls:
					var pprev = c1
					var pstart = c1
					var pend = c2
					if ew == "L":
						pstart.x = p1tl.x - 1
						pprev.x = p1tl.x
					elif ew == "R":
						pstart.x = p1br.x
						pprev.x = p1tl.x
					elif ew == "T":
						pstart.y = p1tl.y - 1
						pprev.y = p1tl.y
					else: # B
						pstart.y = p1br.y
						pprev.y = p1tl.y

					if iw == "L":
						pend.x = p2tl.x - 1
					elif iw == "R":
						pend.x = p2br.x
					elif iw == "T":
						pend.y = p2tl.y - 1
					else: # B
						pend.y = p2br.y

					var path = _try_corridor_L(pstart, pend, pstart - pprev)
					if path.size() > 0:
						shortest_path = path
						break
					# if path.size() > 0 and (shortest_path.size() == 0 or path.size() < shortest_path.size()):
					# 	shortest_path = path
				if shortest_path.size() > 0:
					break

			if shortest_path.size() == 0:
				for ew in exit_walls:
					for iw in entrance_walls:
						var pprev = c1
						var pstart = c1
						var pend = c2
						if ew == "L":
							pstart.x = p1tl.x - 1
							pprev.x = p1tl.x
						elif ew == "R":
							pstart.x = p1br.x
							pprev.x = p1tl.x
						elif ew == "T":
							pstart.y = p1tl.y - 1
							pprev.y = p1tl.y
						else: # B
							pstart.y = p1br.y
							pprev.y = p1tl.y

						if iw == "L":
							pend.x = p2tl.x - 1
						elif iw == "R":
							pend.x = p2br.x
						elif iw == "T":
							pend.y = p2tl.y - 1
						else: # B
							pend.y = p2br.y

						var path = game.astar(pstart, pend, Callable(self, "calc_cost_to_move_to"), 0, pprev, path_bounding_rect)
						if path.size() > 0 and (shortest_path.size() == 0 or path.size() < shortest_path.size()):
							shortest_path = path

			rooms_checked_connections[Vector2i(i,j)] = true
			rooms_checked_connections[Vector2i(j,i)] = true
			if shortest_path.size() > 1:
				# print("connected room ", i, " to ", j)
				add_door_at(shortest_path[0] - (shortest_path[1] - shortest_path[0]))
				add_door_at(shortest_path[-1] - (shortest_path[-2] - shortest_path[-1]))
			# else:
			# 	print("failed connecting room ", i, " to ", j)

			for p in shortest_path:
				add_pipe(p)
				board[p.y][p.x].is_corridor = true

func calc_cost_to_move_to(prev_pos: Vector2i, from: Vector2i, to:Vector2i, _id: int, goal: Vector2i):
	var isgoal = to == goal
	if !game.in_board(to, board_margin) and not isgoal:
		return -1

	var tocell = board[to.y][to.x]
	if tocell.ispipe and not isgoal:
		return -1
	
	# var _fromcell = board[from.y][from.x]
	var dir_prev = from - prev_pos
	var dir = to - from
	
	if not isgoal:
		var tdir = Vector2i(dir.y, dir.x)
		var cands = [to + tdir, to - tdir, to + dir]
		for c in cands:
			if game.in_board(c) and board[c.y][c.x].ispipe and c != goal:
				return -1
	
	if dir != dir_prev:
		return 20
	return 1

#endregion create_rooms


func create_board() -> void:
	# BEFORE the cells: a level change resizes the board, and the lawn under it has to be right from
	# the first frame of "building board", not after it.
	_fit_ground_to_board()
	if game.tutorial_mode:
		# BEFORE create_rooms() below reads num_rooms, and before the hazard counts are used.
		_tutorial_setup()
	# rng = RandomNumberGenerator.new()
	# rng.seed = 1110

	game.colors.shuffle()

	start_dispatch = false
	board.clear()
	for row_index in game.board_size.y:
		var row: Array[OneCell]
		row.resize(game.board_size.x)
		for col_index in game.board_size.x:
			row[col_index] = OneCell.new()
		board.append(row)

	await get_tree().process_frame

	# if get_tree():
	# 	get_tree().reload_current_scene()

	create_rooms(num_rooms, board_margin)
	# for row in range(board_margin,game.board_size.y-board_margin):
	# 	for col in range(board_margin,game.board_size.x-board_margin):
	# 		add_pipe(Vector2i(col,row))
	
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
	zoom_camera(true)

	add_coins()
	add_bricks()
	add_bomb_agents()
	add_moving_agents()

	# time_to_hide = MainGlobals.timems() + 1000
	# MainGlobals.global_start_countdown(1)

	# zoom_camera(false)
	$BuildingLabel.hide()
	game.level_is_ready = true	
	_start_playing()

func close_to_corridor(p:Vector2i, dist:int):
	for add_r in range(-dist,dist+1):
		for add_c in range(-dist,dist+1):
			var q = p + Vector2i(add_c,add_r)
			if game.in_board(q) and board[q.y][q.x].is_corridor:
				return true
	return false

func add_coins():
	for r in rooms:
		var p = MainGlobals.pick_one_cell(r.position.x, r.position.y, r.end.x-1, r.end.y-1, 
			func(x,y):
				var _p = Vector2i(x,y)
				return !close_to_corridor(_p,2) and board[y][x].is_fillable() and dist_from_agents_and_player(_p) >= 1)
		if p.x >= 0:
			var cell = board[p.y][p.x]
			if p.x == r.position.x or p.y == r.position.y or p.x == r.end.x-1 or p.y == r.end.y - 1:
				cell.pipe.has_coin = 2
			else:
				cell.pipe.has_coin = 1
			cell.pipe.set_rot(board)
			coins[p] = true

func add_bricks():
	var brick0 = game.rng.randi_range(0,2)
	for r in rooms:
		brick0 += 1
		for nb in range(num_bricks_per_room):
			var p = MainGlobals.pick_one_cell(r.position.x+1, r.position.y+1, r.end.x-2, r.end.y-2, 
				func(x,y):
					var cell = board[y][x]
					if cell.is_fillable(): 
						var d_to_player = (Vector2i(x,y) - player.board_pos).length()
						var d_to_agents = dist_from_agents(Vector2i(x,y))
						if d_to_player >= 1 and d_to_agents >= 1:
							return true
					return false)

			if p.x >= 0:
				var cell = board[p.y][p.x]
				cell.pipe.has_brick = brick0
				cell.pipe.set_rot(board)

var player_cam = null
var game_cam = null

func zoom_camera(zoom_in: bool):
	# var current_cam_scale = player_cam.zoom.x if player_cam != null else 1.0

	game.zoomed_in = zoom_in
	for pipe in pipes:
		pipe.set_rot(board)

	if zoom_in:
		var player_camscale = game.get_tiles_in_screen_width() / float(room_max_size+2)
		if player_cam != null:
			player_cam.zoom = Vector2(player_camscale,player_camscale)
			player_cam.enabled = true
			if game_cam != null:
				game_cam.enabled = false
			return
		else:
			create_player_camera(player_camscale)
	else:
		var bbox:Rect2 = Rect2(rooms[0])
		for r in rooms:
			bbox = bbox.merge(Rect2(r))
		var game_camscale = min(game.get_tiles_in_screen_width() / float(bbox.size.x+4), game.get_tiles_in_screen_height() / float(bbox.size.y+4))
		var game_center = game.board_to_px(bbox.get_center()) - Vector2(game.tile_size / 2,game.tile_size / 2)
		# var game_camscale = min(2.0, 1.0 / game.get_board_part_of_width(-board_margin+1))
		# var game_center = game.board_to_px(game.get_board_center())
		# var game_camscale = min(game.get_tiles_in_screen_width() / float(game.board_size.x+2), game.get_tiles_in_screen_height() / float(game.board_size.y+2))
		# var game_center = game.board_to_px(game.get_board_center()) + Vector2(0,game.tile_size / 2)
		if game_cam != null:
			game_cam.zoom = Vector2(game_camscale,game_camscale)
			game_cam.position = game_center
			game_cam.enabled = true
			if player_cam != null:
				player_cam.enabled = false
			return
		else:
			create_game_camera(game_camscale, game_center)
	

func create_game_camera(game_camscale, game_center):
	game_cam = Camera2D.new()
	add_child(game_cam)
	game_cam.zoom = Vector2(game_camscale,game_camscale)
	game_cam.position_smoothing_enabled = false
	# game_cam.position_smoothing_speed = 10
	game_cam.position = game_center
	game_cam.enabled = true
	if player_cam != null:
		player_cam.enabled = false

func create_player_camera(player_camscale):
	if player == null:
		return
	player_cam = Camera2D.new()
	player.add_child(player_cam)

	player_cam.zoom = Vector2(player_camscale,player_camscale)
	player_cam.position_smoothing_enabled = false
	# player_cam.position_smoothing_speed = 10
	player_cam.enabled = true
	player_cam.limit_left = game.board_to_px(Vector2i(0,0)).x
	player_cam.limit_top = game.board_to_px(Vector2i(0,0)).y
	player_cam.limit_right = game.board_to_px(Vector2i(game.board_size.x-1,0)).x
	player_cam.limit_bottom = game.board_to_px(Vector2i(0,game.board_size.y-1)).y
	if game_cam != null:
		game_cam.enabled = false

# Nothing hunts the player during a tutorial. Being killed mid-lesson ends the round outright
# (check_agent_collisions -> mark_hit -> level_is_done(false)) and teaches nothing but frustration.
var tutorial_no_movers: bool = false

func _tutorial_setup() -> void:
	tutorial_no_movers = true
	num_bomb_agents_to_add = 0
	# The smallest castle the game can make, and a palette with no decoy colors in it: the lesson is
	# "you will be asked what color each room was", not "pick it out of a dozen you never saw".
	num_rooms = 2
	num_distracting_colors = 0
	# No bricks either. They are harmless — they only block a tile — but the tutorial never
	# mentions them, and an unexplained object in a room the coach is talking about is one more
	# thing for a first-timer to wonder about. _apply_level puts the count back for real play.
	num_bricks_per_room = 0

# --- spotlight helpers. Rooms and coins are board coordinates, not nodes, so they are converted to
# SCREEN space here; the runner takes a Rect2 as already being in screen space.
func _screen_rect_for_cells(p0: Vector2i, p1: Vector2i) -> Rect2:
	if not game.in_board(p0) or not game.in_board(p1):
		return Rect2()
	var c0 = board[p0.y][p0.x]
	var c1 = board[p1.y][p1.x]
	if c0.pipe == null or c1.pipe == null:
		return Rect2()
	var t: Transform2D = get_viewport().get_canvas_transform()
	var a: Vector2 = t * c0.pipe.global_position
	var b: Vector2 = t * c1.pipe.global_position
	# Tile positions are points, so a single cell came out as a zero-size rect and the frame drawn
	# round it was 20px — smaller than the coin inside it, which reads as a rendering glitch rather
	# than as "look here". Grow by half a tile on each side so one cell frames one tile.
	# Tile size from the camera, NOT from a neighbouring tile: add_coins() puts some coins on a
	# room's edge, where the tile to the right is a wall with no pipe to measure against. That made
	# the frame collapse to a fixed 8px inset there, so the same marker came out about two tiles
	# wide in the middle of a room and about one on its edge.
	var half: float = game.tile_size * t.get_scale().x * 0.5
	var lo: Vector2 = Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(half, half)
	return Rect2(lo, (b - a).abs() + Vector2(half, half) * 2.0).grow(6.0)

func tutorial_room_rect(room_id: int) -> Rect2:
	if room_id < 0 or room_id >= rooms.size():
		return Rect2()
	var r = rooms[room_id]
	return _screen_rect_for_cells(r.position, r.end - Vector2i(1, 1))

# The room the player is standing in, so a caption about "this room" points at the right one.
func tutorial_current_room() -> int:
	if player == null or not is_instance_valid(player):
		return -1
	return bcell(player.board_pos).room_id

func tutorial_current_room_rect() -> Rect2:
	return tutorial_room_rect(tutorial_current_room())

# A room that has not been entered yet — where the coach sends them next.
func tutorial_unvisited_room_rect() -> Rect2:
	for rid in rooms.size():
		if not visited_rooms.has(rid):
			return tutorial_room_rect(rid)
	return Rect2()

# A PATCH of floor beside the player, not the whole room. A room rect is most of the screen, so a
# caption cannot get out of its way — it ended up sitting on the very floor it was telling the
# player to look at.
# Movement is continuous: one swipe and you keep going. So a step that says "look at THIS room"
# has to stop the player first, or the freeze catches them halfway down a corridor and the caption
# is talking about a floor they have already left.
func tutorial_halt_player() -> void:
	next_player_dir = -1
	if player != null and is_instance_valid(player):
		player.path.clear()

# The ROOM still waiting for an answer. Used only to keep the caption off it; nothing is drawn on
# it (framing a room was tried and rejected, see docs/design.md).
#
# The whole room, not just its color strip: with the rooms stacked vertically, dodging the strip
# alone moved the caption straight onto the room it belonged to — 67%% of it covered — and the
# player could not see which room they were being asked about.
#
# Only while answering. During the walk there are no answers pending, and reserving a whole room
# then left the caption nowhere to stand but on the player.
func tutorial_unanswered_room_rect() -> Rect2:
	if not in_answring_mode:
		return Rect2()
	# Only once ONE room is left. While several are still open the player can start with whichever
	# they can see, so reserving one of them means nothing — and with two rooms filling the map, a
	# full-width caption cannot clear both anyway.
	var pending: Array = []
	for rid in rooms.size():
		if not answered_rooms.get(rid, false):
			pending.append(rid)
	if pending.size() != 1:
		return Rect2()
	return tutorial_room_rect(int(pending[0]))

func tutorial_coin_rect() -> Rect2:
	for p in coins.keys():
		return _screen_rect_for_cells(p, p)
	return Rect2()

# The coin in the room the player is in, if there is one — better to point at that than at whichever
# coin happens to come first in the dictionary.
func tutorial_coin_here_rect() -> Rect2:
	var here: int = tutorial_current_room()
	for p in coins.keys():
		if here >= 0 and bcell(p).room_id == here:
			return _screen_rect_for_cells(p, p)
	return tutorial_coin_rect()

func add_moving_agents():
	if tutorial_no_movers:
		return
	var n := 0
	for r in rooms:
		var candidates = [r.position, r.position + Vector2i(r.size.x-1,0), r.position + Vector2i(0,r.size.y-1), r.position + Vector2i(r.size.x-1,r.size.y-1)]
		candidates.shuffle()
		for p in candidates:
			if board[p.y][p.x].is_fillable():
				if dist_from_agents_and_player(p) >= 2:
					board[p.y][p.x].has_agent = true
					add_agent_at(p, n % 2, 1)
					n += 1
					break

func add_bomb_agents():
	# Setting num_bomb_agents_to_add to 0 does NOT mean "no bombs": nloops divides by it, and the
	# "have I placed enough?" check happens AFTER the first one is placed — so a count of 0 still
	# left exactly one bomb on the board, usually in the first room. Hazards are off for the
	# tutorial, so leave outright.
	if tutorial_no_movers:
		return
	var n = 0
	var nloops = int((rooms.size() + num_bomb_agents_to_add - 1.0) / num_bomb_agents_to_add)
	for i in range(nloops):
		for r in rooms:
			var p = MainGlobals.pick_one_cell(r.position.x+1, r.position.y+1, r.end.x-2, r.end.y-2, 
				func(x,y): return board[y][x].is_fillable() and dist_from_agents_and_player(Vector2i(x,y)) >= 1)
			if p.x >= 0:
				board[p.y][p.x].has_agent = true
				add_agent_at(p, 0, 0)
				n += 1
				if n >= num_bomb_agents_to_add:
					return

var next_agent_id := 1
func add_agent_at(p: Vector2i, direction: int, agent_type: int = 1):
	var agent = agent_scene.instantiate()
	agent.direction = direction
	agent.board_pos = p
	agent.body_ids = range(1, num_more_packets)
	agent.speed_scale = agent_max_speed_scale * rng.randf_range(0.8, 2.0)
	agent.set_type(agent_type)
	add_child(agent)
	agent.set_id(next_agent_id)
	if agent_type != 0:
		agent.is_moving = true
		agent.set_color(next_agent_id)
	next_agent_id += 1
	# agent.agent_pressed.connect(on_agent_pressed)
	board[p.y][p.x].has_agent = true
	# agent.hit.connect(on_agent_hit)
	agent.remove_agent.connect(on_agent_remove_agent)
	agents.append(agent)
	agent.set_pos(game.board_to_px(p), direction)
		
	return agent
			
func on_player_is_really_moving(is_moving: bool):
	if is_moving:
		game.play_sound("feet")
	else:
		game.stop_sound("feet")

func on_clicked_door(_pos: Vector2i):
	pass
	# for i in doors.size():
	# 	var door = doors[i]
	# 	if door.board_pos == pos:
	# 		var current = door.rot_idx
	# 		var newdir = (current + 1) % 3
	# 		door.set_rot(newdir)
	# 		board[pos.y][pos.x].door_type = newdir
	# 		break

func can_go_to(p):
	if !game.in_board(p, board_margin):
		return false
	var cell = board[p.y][p.x]
	var cond = cell.ispipe && cell.pipe.has_brick < 0
	return cond
	
func all_agents_done():
	if agents.size() == 0:
		return false
	for agent in agents:
		if !agent.arrived:
			return false
	return true
	
func bcell(p:Vector2i) -> OneCell:
	return board[p.y][p.x]

func move_player_on_tick(force:bool = false):
	if player == null:
		return
	if !player.need_to_major_tick() and !force:
		return
	var cell = board[player.board_pos.y][player.board_pos.x]
	if cell.pipe != null and cell.pipe.has_coin >= 0:
		game.add_score_and_time(cell.pipe.has_coin, 0)
		game.play_sound("delivery")
		game.tutorial_notify("coin_taken")   # no-op outside tutorial mode
		cell.pipe.has_coin = -1
		cell.pipe.set_rot(board)
		coins.erase(player.board_pos)

	player.set_major_tick_now()

	# if player.need_to_stop:
	# 	player.need_to_stop = false
	# 	player.is_moving = false

	if player.arrived or player.was_hit:
		return	

	if did_visit_all_rooms() and len(coins) == 0:
		for agent in agents:
			agent.is_moving = false
		game.play_sound("swoosh")
		player.mark_arrived()
		return

	var p = player.board_pos

	if player.path.size() > 0:
		var q = player.path[0]
		if !can_go_to(q):
			next_player_dir = -1
			return
			# player.path.clear()
		else:
			q = player.path.pop_front()
			var vdir = q - p
			var dir = game.dt_to_dir(vdir)
			player.direction = dir
			next_player_dir = dir
			player.set_board_pos(q, board)			
			mark_visited_room(bcell(q).room_id)
			if player.path.size() == 0:
				if bcell(q).room_id < 0:
					next_player_dir = dir
				else:
					next_player_dir = -1
			return

	if game.in_board(p) and next_player_dir >= 0:
		var dir = next_player_dir
		var vdir = DirArray[dir]
		var q = p + vdir
		if !can_go_to(q) and cell.room_id < 0:
			dir = (next_player_dir + 1) % 4
			vdir = DirArray[dir]
			q = p + vdir
			if !can_go_to(q):
				dir = (next_player_dir + 3) % 4
				vdir = DirArray[dir]
				q = p + vdir
		if can_go_to(q):
			player.direction = dir
			mark_visited_room(bcell(q).room_id)
			player.set_board_pos(q, board)
			if true or bcell(q).room_id < 0:	# continuous movement
				next_player_dir = dir
				return
	next_player_dir = -1

# var last_major_tick_ms = -10000.0
func tick(force:bool = false):
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
		
func _on_level_done_popup_closed():
	sig_level_is_done.emit(true)

func _on_game_popup_closed():
	sig_level_is_done.emit(last_level_was_a_win)

func level_is_done(didwin: bool):
	last_level_was_a_win = didwin
	game.level_is_done = true
	game.stop_sound("motor")
	game.stop_sound("feet")
	BE.send_event("level_done", "Mmm", {
		"level": level,
		"round_in_level": round_in_level,
		"didwin": int(didwin),
	})
	start_dispatch = false
	# A tutorial round ends the same way a real one does, but none of the celebration belongs here:
	# the coach still has its closing caption to show, and a "Level 1 completed" panel lands on top
	# of it. Every branch below ends in a popup, so leave before any of them. Nothing is lost —
	# scoring and level progression are suppressed in tutorial_mode anyway.
	if game.tutorial_mode:
		return
	# EVERY round counts toward the level now, won or lost. Before this, round_in_level only
	# moved when need_to_increase_level had been set, which happened on a WIN — so a lost
	# round did not count at all and a level could be postponed forever but never failed.
	_rounds_played += 1
	if didwin and not _round_had_wrong_answer:
		_rounds_fully_correct += 1
	_round_had_wrong_answer = false
	round_in_level += 1
	if didwin:
		# The speed bonus is for a round that was won; it used to sit before the win/lose branch
		# only because there was nothing else in front of it.
		var time_from_start_s = (MainGlobals.timems() - time_started_level_ms) / 1000
		var score_add = min(5, 60 - time_from_start_s)
		var time_add = min(10, 60 - time_from_start_s)
		game.add_score_and_time(score_add,time_add)
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
	var need: int = MmmLevelConfig.pass_pct_for(level)
	var pct: int = 0 if _rounds_played <= 0 else int(round(100.0 * float(_rounds_fully_correct) / float(_rounds_played)))
	var passed: bool = pct >= need
	var is_last: bool = level >= MmmLevelConfig.LEVELS.size()
	game.need_to_increase_level = passed and not is_last
	_rollback_score_on_next_level = not passed
	_level_is_over = true
	# No fanfare over a level that was not passed.
	MainGlobals.global_level_is_done(passed)
	var textadd: String = "\n\nRounds fully right: %d of %d\nAccuracy: %d%%\n\n%s" % [
		_rounds_fully_correct, _rounds_played, pct, _progress_line(passed, need, is_last)]
	game.show_level_done_popup(self, "", "", level, textadd, passed)

# What the player gets next, in words. An accuracy figure alone does not say whether they are
# moving on, which is the only thing they want to know at that moment.
func _progress_line(passed: bool, need: int, is_last: bool) -> String:
	if not passed:
		return "You need at least %d%% of the rounds fully right to pass to the next level." % need
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
		# A replay has to be a FRESH attempt: the gate reads these, so a retry that inherited the
		# rounds which failed the level could not pass it even played perfectly. game.corrects /
		# game.mistakes are deliberately NOT touched — they are the session's room answers and the
		# HUD shows them.
		_rounds_played = 0
		_rounds_fully_correct = 0
		_round_had_wrong_answer = false
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
	var s: int = 51 + level * 2
	# How many rounds this level is judged over — the gate reads it, so it has to come from the
	# config rather than staying at whatever the member was initialised to.
	for lv: Dictionary in MmmLevelConfig.LEVELS:
		if int(lv["level"]) == level:
			rounds_per_level = int(lv["rounds"])
			break
	num_rooms = min(MAX_POSSIBLE_ROOMS, MAX_COLORS_TO_USE, 1 + level)
	num_distracting_colors = level - 1 + round_in_level
	game.forced_board_size = Vector2i(s, s)
	num_more_packets = 0
	player_max_speed_scale = 1.5
	agent_max_speed_scale = min(0.4 + 0.2 * (level - 1), 2)
	num_bomb_agents_to_add = 3
	num_bricks_per_room = 2
	game.init_sizes()

func add_player_at(p: Vector2i, direction: int):
	if player != null:
		player.queue_free()
		player_cam = null
	player = player_scene.instantiate()
	add_child(player)
	player.reset()
	player.direction = direction
	player.board_pos = p
	player.body_ids = []
	# player.speed_scale = rng.randf_range(0.8, player_max_speed_scale)
	player.speed_scale = player_max_speed_scale
	# player.player_pressed.connect(on_agent_pressed)
	player.sig_is_really_moving.connect(on_player_is_really_moving)
	board[p.y][p.x].has_agent = true
	# agent.hit.connect(on_agent_hit)
	player.remove_player.connect(on_player_remove_player)
	player.set_pos(game.board_to_px(p), direction)
	mark_visited_room(bcell(p).room_id)

	var color = Color(0.1,0.5,0.99) #game.next_color()
	player.set_color(color)

func mark_visited_room(room_id):
	if room_id >= 0 and not visited_rooms.has(room_id):
		game.tutorial_notify("room_entered")   # no-op outside tutorial mode
	visited_rooms[room_id] = true

func add_player():
	var p = game.get_board_center()
	add_player_at(p, 1)

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
					p = agent_start_positions[idx]
					dir = agent_start_directions[idx]
					if board[p.y][p.x].has_agent:
						continue
					if (pos_last_dispatch - p).length() > 4:
						got_p = true
						break
				else:
					break
			if got_p:
				pos_last_dispatch = p
				add_agent_at(p, dir, 1)

func on_agent_remove_agent(agent_id, _good_remove: bool):
	for i in agents.size():
		if agents[i].agent_id == agent_id:
			board[agents[i].board_pos.y][agents[i].board_pos.x].has_agent = false
			agents[i].queue_free()
			agents.remove_at(i)
			break

var colors_for_popup: Array = []
func on_player_remove_player(_arrived: bool):		
	if _arrived:
		for agent in agents:
			agent.queue_free()
		agents.clear()
		in_answring_mode = true
		_round_start_ms = MainGlobals.timems()
		zoom_camera(false)
		await get_tree().process_frame
		# num_distracting_colors = 22		# for debug
		var n:int = min(MAX_POSSIBLE_ROOMS, MAX_COLORS_TO_USE, rooms.size() + num_distracting_colors)
		var rndn = range(0, n)
		rndn.shuffle()
		colors_for_popup = rndn.duplicate()
		for room_id in range(rooms.size()):
			create_color_selection_popup(room_id, true)
		game.tutorial_notify("map_shown")   # no-op outside tutorial mode
	else:	
		level_is_done(false)
	# if player != null:
	# 	player.queue_free()
	# 	player = null
	# 	player_cam = null
	# level_is_done(arrived)

func check_agent_collisions():
	for i in agents.size():
		var a1 = agents[i]
		# var d_p_to_a = (a1.board_pos - player.board_pos).length()
		var d_p_to_a = (a1.position - player.position).length()
		if d_p_to_a < 0.5 * game.tile_size:
			a1.mark_hit()
			collision.emit()
			player.mark_hit()
			game.play_sound("explosion")
			return
		if !a1.was_hit and !a1.arrived:
			for j in agents.size():
				if i != j:
					var a2 = agents[j]
					if !a2.was_hit and !a2.arrived:
						var d = a1.distance_to(a2)
						if d < game.tile_size/4.0:
							a1.mark_hit()
							a2.mark_hit()
							collision.emit()

# func show_clue():
# 	update_score.emit(-1)

func on_time_over():
	pass

func on_lives_depleted():
	pass

func add_door_at(p):
	if not game.in_board(p):
		return
	var door_type = 0
	if board[p.y][p.x].door_type >= 0:
		return
	board[p.y][p.x].door_type = door_type
	var door = door_scene.instantiate()
	door.position = game.board_to_px(p)
	door.set_board_pos(p)
	add_child(door)
	door.set_rot(door_type)
	door.hide()
	doors.append(door)					

var popup:PopupPanel = null

func _unhandled_input(event: InputEvent) -> void:
	if popup == null or not is_instance_valid(popup) or not popup.visible:
		return

	if event.is_action_pressed("ui_cancel"):
		_close_popup()
		get_viewport().set_input_as_handled()

const swatch_tex: Texture2D = preload("res://art/floor2.png")
const color_layouts = [
	[],[],	# for 0,1
	[1,1],
	[1,1,1],
	[2,2],
	[1,3,1],
	[2,2,2],
	[2,3,2],
	[2,2,2,2],
	[3,3,3],
	[2,3,3,2],
	[2,3,3,3],
	[3,3,3,3]
]

var small_popups = {}

func create_color_selection_popup(room_id: int, small_version: bool) -> void:
	var color_indices = colors_for_popup
	var room = rooms[room_id]
	var p0 = room.position
	var p1 = room.end - Vector2i(1,1)

	var screen_pos: Vector2

	var small_popup:PanelContainer

	var vbox_container := VBoxContainer.new()
	vbox_container.alignment = BoxContainer.ALIGNMENT_CENTER
	var sep := 1
	vbox_container.add_theme_constant_override("separation", 0)#sep)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT#(0.1, 0.1, 0.1, 0.0)
	# sb.set_border_width_all(sep)
	# sb.border_color = Color(0.1, 0.1, 0.1, 1.0)

	var actual_pipe_w := 0
	if small_version:
		var p0g = board[p0.y][p0.x].pipe.position
		var p1g = board[p1.y][p1.x].pipe.position
		actual_pipe_w = (board[p0.y+1][p0.x+1].pipe.position - p0g).x
		p0g = game.board_to_px(p0)
		p1g = game.board_to_px(p1)
		var pcg = (p0g + p1g) / 2.0

		# print("room id %d pcg %s" % [room_id, str(pcg)])
		screen_pos = pcg
		small_popup = PanelContainer.new()
		add_child(small_popup)
		small_popups[room_id] = small_popup
		small_popup.add_child(vbox_container)
		small_popup.add_theme_stylebox_override("panel", sb)
	else:
		var p0g = board[p0.y][p0.x].pipe.global_position
		var p1g = board[p1.y][p1.x].pipe.global_position
		var p01g = board[p0.y+1][p0.x+1].pipe.global_position
		var pcg = (p0g + p1g) / 2.0
		var p_transform = get_viewport().get_canvas_transform()
		screen_pos = p_transform * pcg
		actual_pipe_w = int((p_transform * p01g - p_transform * p0g).x)

		if popup != null and is_instance_valid(popup):
			popup.queue_free()
			popup = null
		popup = PopupPanel.new()
		add_child(popup)
		popup.unresizable = true
		popup.add_child(vbox_container)
		popup.add_theme_stylebox_override("panel", sb)

	var n = color_indices.size()
	var w: int = max(1, floori(sqrt(n)))
	var h: int = max(1, ceili(float(n) / float(w))) # IMPORTANT

	var layout = [0]
	if n < color_layouts.size():
		layout.append_array(color_layouts[n])
		w = MainGlobals.array_max(layout)
		h = layout.size()
	else:
		for i in range(h):
			layout.append(w)
	MainGlobals.cumsum_inplace(layout)

	var box_w := actual_pipe_w * 2
	if small_version:
		box_w = int(actual_pipe_w / 1.1)

	if small_version:
		small_popup.size = Vector2i(box_w * w + (w+1)*sep, box_w * h + (h+1)*sep)
		small_popup.position = screen_pos - small_popup.size/2.0#(MainGlobals.clamp_popup_rect(screen_pos - small_popup.size/2.0, small_popup.size, 20)).position
	else:
		popup.size = Vector2i(box_w * w + (w+1)*sep, box_w * h + (h+1)*sep)
		var rect := MainGlobals.clamp_popup_rect(screen_pos - popup.size/2.0, popup.size, 20)
		popup.popup(rect)

	_build_palette(vbox_container, layout, room_id, sep, box_w, small_popup)

func _build_palette(vbox_container:VBoxContainer, layout, room_id, sep, box_w, small_version):
	var color_indices = colors_for_popup
	var hbox_container: HBoxContainer = null
	
	var n = layout[-1]
	for i in range(n):
		var is_correct = color_indices[i] == room_id
		# var col: int = i % w
		# if col == 0:
		if i in layout:
			hbox_container = HBoxContainer.new()
			vbox_container.add_child(hbox_container)
			hbox_container.add_theme_constant_override("separation", 0)#sep)
			hbox_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


		var panel := PanelContainer.new()
		panel.set_custom_minimum_size(Vector2(box_w + 2*sep, box_w + 2*sep))
		var sbs := StyleBoxFlat.new()
		sbs.bg_color = Color.TRANSPARENT
		sbs.set_border_width_all(sep)
		sbs.border_color = Color(0.1, 0.1, 0.1, 1.0)
		panel.add_theme_stylebox_override("panel", sbs)

		var swatch := TextureRect.new()
		swatch.texture = swatch_tex
		swatch.modulate = game.color_by_index(color_indices[i])
		swatch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		swatch.stretch_mode = TextureRect.STRETCH_SCALE
		swatch.set_custom_minimum_size(Vector2(box_w, box_w))
		swatch.mouse_filter = Control.MOUSE_FILTER_STOP
		if small_version:
			swatch.set_meta("room_id", room_id)
			swatch.gui_input.connect(_on_small_color_rect_input.bind(swatch))
		else:
			swatch.set_meta("is_correct", is_correct)
			swatch.set_meta("room_id", room_id)
			swatch.gui_input.connect(_on_color_rect_input.bind(swatch))
		panel.add_child(swatch)
		hbox_container.add_child(panel)

func _on_small_color_rect_input(event, rect: Control):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var room_id: int = int(rect.get_meta("room_id"))		
		create_color_selection_popup(room_id, false)

# func _on_color_rect_input(event, rect: ColorRect):
func _on_color_rect_input(event, rect: Control):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# var selected_color: Color = rect.color
		var is_correct: int = int(rect.get_meta("is_correct"))
		if is_correct:
			var room_id: int = int(rect.get_meta("room_id"))
			answered_rooms[room_id] = true
			if room_id in small_popups:
				small_popups[room_id].queue_free()
				small_popups.erase(room_id)
			var room = rooms[room_id]
			for row in range(room.position.y, room.end.y):
				for col in range(room.position.x, room.end.x):
					var p = Vector2i(col,row)
					if board[p.y][p.x].ispipe:
						board[p.y][p.x].color_idx = room_id
						board[p.y][p.x].pipe.set_rot(board)
			answered(true)
			_close_popup()
		else:
			_flash_wrong(rect)
			answered(false)

# Say NO where the player is looking — at the swatch they just tapped. The score ticking down at
# the top of the screen is easy to miss entirely, and was the only sign that a pick was wrong.
func _flash_wrong(rect: Control) -> void:
	if rect == null or not is_instance_valid(rect):
		return
	var back: Color = rect.modulate
	rect.modulate = Color(1.0, 0.25, 0.25, 1.0)
	var tw: Tween = MainGlobals.make_tween()
	tw.tween_property(rect, "modulate", back, 0.45)
	var start_x: float = rect.position.x
	var shake: Tween = MainGlobals.make_tween()
	shake.tween_property(rect, "position:x", start_x - 5.0, 0.05)
	shake.tween_property(rect, "position:x", start_x + 5.0, 0.09)
	shake.tween_property(rect, "position:x", start_x, 0.05)

func _close_popup():
	popup.hide()
	popup.queue_free()
	popup = null

func _on_path_drawn(_path: Array[Vector2i]) -> void: 
	var path = game.get_player_path(player, _path, 9, Callable(self, "calc_cost_to_move_player_to"))
	if path.size() > 0:
		player.path = path.duplicate()

func calc_cost_to_move_player_to(prev_pos: Vector2i, from: Vector2i, to:Vector2i, _id: int, goal: Vector2i):
	var isgoal = to == goal
	if !game.in_board(to, board_margin-1) and not isgoal:
		return -1

	var tocell = bcell(to)
	if !tocell.ispipe and not isgoal:
		return -1
	if tocell.ispipe and tocell.pipe.has_brick >= 0:
		return -1	
	if is_wall_between(from,to):
		return -1
	# if tocell.room_id < 0:
	# 	return -1
	
	var dir_prev = from - prev_pos
	var dir = to - from	
	if dir != dir_prev:
		return 20
	return 1

func is_wall_between(p, q, also_check_brick:bool = true):
	var to = bcell(q)
	var from = bcell(p)

	if !to.ispipe || !from.ispipe:
		return true

	if also_check_brick and (to.pipe.has_brick >= 0 || from.pipe.has_brick >= 0):
		return true

	return false

# The lawn: ONE continuous field over the whole board (scripts/grass_field.gd), with the per-cell
# grass sprites hidden. Tiling — plain, rotated or drawn — is a mosaic of one image however it is
# arranged, and the cells are half of it.
#
# What it must get right is SCALE. The board is drawn through a camera zoomed to `player_camscale`,
# so its cells appear at `tile x zoom`; a ground tiled in screen space appears at `tile`, and the
# two are visibly different grass the moment the player camera takes over. That is what "the
# background changes once the board is built" was. So the ground lives in the WORLD: its layer
# follows the viewport and its rect covers the whole board, which also means it cannot run out at
# the sides the way a screen-sized ground in a following layer did.
# The ground node is looked up with get_node_or_null because this script is not only on the
# level scene: storm's blackout.tscn carries a copy of it too, and a hard $ path there throws.
func _fit_ground_to_board() -> void:
	GrassField.fit(get_node_or_null("BgLayer"), get_node_or_null("BgLayer/TextureRect") as CanvasItem, game, 7)

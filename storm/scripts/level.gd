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
	var action:CAction

	func is_fillable() -> bool:
		return ispipe && door_type < 0 && !has_agent && pipe.can_fill()

class CAction:
	var name:String
	var id:int
	var level:float
	var overflow_level:float

	func _init(_name:String, _id:int, _level:float = 0, _overflow_level:float = 1):
		name = _name
		id = _id
		level = _level
		overflow_level = _overflow_level

var available_actions = [
	CAction.new("bucket",0),
]

var action_textures = {
	"bucket":[preload("res://storm/art/bucket.png"), preload("res://storm/art/bucket_mask.png")],
	"rag":[preload("res://storm/art/rag.png"), preload("res://storm/art/rag_mask.png") ],
	"fix":[preload("res://storm/art/fix.png"), preload("res://storm/art/fix.png")],
	"cup":[preload("res://storm/art/cup.png"), preload("res://storm/art/cup_mask.png")],
	"plate":[preload("res://storm/art/plate.png"), preload("res://storm/art/plate_mask.png") ],
	"drain":[preload("res://storm/art/drain.png")],
	# "pickup":[preload("res://storm/art/drain.png")],
}

var furniture = {
	"flower": [preload("res://storm/art/flower.png"), 5, Color(1,0.3,0.3,0.3)],
	"screen": [preload("res://storm/art/screen.png"), 20, Color(1,1,1,0.3)],
	"rug": [preload("res://storm/art/rug.png"), 5, Color(0.7,0.2,0.1,0.3)],
}
	
var rounds_per_level: int = 3
var board: Array
var pipes = []
var empties = []
var doors = []
var time_started_level_ms = 0
var level: int = 0
var round_in_level: int = 0
var num_rooms := 4
var player = null
var player_max_speed_scale = 1.5
var next_player_dir = -1
var play_start_sound_once := true
var num_bricks_per_room := 2
var MAX_POSSIBLE_ROOMS := 12
var last_level_was_a_win := true
var last_time_added_leak := 0.0
var next_duration_for_leak_ms := 1000.0
var last_time_showed_blackout := 0.0
var next_blackout_duration_s := 10.0
var last_time_played_water_drop := 0.0
var next_water_drop_duration_s := 5.0
var storm_duration_s := 60.0 * 2.0
var started_sounds := false
var round_items_lost: int = 0

@export var pipe_scene: PackedScene = load("res://storm/scenes/pipe.tscn")
@export var empty_scene: PackedScene = load("res://storm/scenes/empty_space.tscn")
@export var agent_scene: PackedScene = load("res://storm/scenes/agent.tscn")
@export var player_scene: PackedScene = load("res://storm/scenes/player.tscn")
@export var door_scene: PackedScene = load("res://storm/scenes/door.tscn")

var action_scene: PackedScene = load("res://storm/scenes/action_panel.tscn")

var explosion_audio := preload("res://art/sounds/car-crash-sound-376882.mp3")
# var motor_audio := preload("res://art/sounds/car-driving-ambience-6365.ogg")
var feet_audio := preload("res://art/sounds/kenney/Audio/footstep_grass_001.ogg")
var delivered_audio := preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var start_audio := preload("res://art/sounds/click-2.mp3")
var tap_audio := preload("res://art/sounds/tap-1.mp3")
var swoosh_audio := preload("res://art/sounds/swoosh.mp3")
var dispatch_audio := preload("res://art/sounds/kenney/Audio/impactBell_heavy_003.ogg")
var gaveup_audio := preload("res://art/sounds/bump-7-92964.mp3")
var water_pour_audio := preload("res://art/sounds/water_pour_3.ogg")
var water_drop_audio := [ 
	preload("res://art/sounds/FreeSFX/GameSFX/Blops/Retro Blop 18.ogg"),
	preload("res://art/sounds/FreeSFX/GameSFX/Blops/Retro Blop 22.ogg") ]
var rain_audio := [
	# preload("res://art/sounds/rain_1_louder.ogg"),
	# preload("res://art/sounds/rain_2_louder.ogg"),
	# preload("res://art/sounds/rain_3_louder.ogg"),
	# preload("res://art/sounds/rain_4_louder.ogg"),
	preload("res://art/sounds/rain_1.ogg"),
	preload("res://art/sounds/rain_2.ogg"),
	preload("res://art/sounds/rain_3.ogg"),
	preload("res://art/sounds/rain_4.ogg"),
]
var thunder_audio := [
	preload("res://art/sounds/thunder_1.mp3"),
	preload("res://art/sounds/thunder_2.mp3"),
	preload("res://art/sounds/thunder_3.mp3"),
	preload("res://art/sounds/thunder_4.mp3"),
]


signal started_playing
signal sig_level_is_done(didwin:bool)
signal update_score(score:int)
signal sig_blackout

func _ready() -> void:
	game = StormG.game
	game.sig_time_over.connect(on_time_over)
	game.sig_lives_depleted.connect(on_lives_depleted)
	level = StormG.starting_level
	round_in_level = 0
	_apply_level()

	game.add_sound(self, "explosion", explosion_audio)
	# game.add_sound(self, "motor", motor_audio, true)
	game.add_sound(self, "feet", feet_audio, true)
	game.add_sound(self, "delivery", delivered_audio)
	game.add_sound(self, "start", start_audio)
	game.add_sound(self, "swoosh", swoosh_audio)
	game.add_sound(self, "dispatch", dispatch_audio)	
	game.add_sound(self, "gaveup", gaveup_audio)	
	game.add_sound(self, "water_drop", water_drop_audio)
	game.add_sound(self, "rain", rain_audio, true)
	game.add_sound(self, "thunder", thunder_audio)
	game.add_sound(self, "tap", tap_audio)
	game.add_sound(self, "water_pour", water_pour_audio)

	if not MainGlobals.sig_game_popup_closed.is_connected(_on_game_popup_closed):
		MainGlobals.sig_game_popup_closed.connect(_on_game_popup_closed)
	if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
		MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
	MainGlobals.sig_path_drawn.connect(_on_path_drawn)  
	
func reset():
	round_items_lost = 0
	next_player_dir = -1
	play_start_sound_once = true
	started_sounds = true

	if player != null:
		player.queue_free()
		player = null
	player_cam = null

	if game_cam != null:
		game_cam.queue_free()
		game_cam = null

	for c in pipes:
		c.queue_free()
	for c in empties:
		c.queue_free()
	for c in doors:
		c.queue_free()
	pipes.clear()
	empties.clear()
	doors.clear()

	time_started_level_ms = 0

func new_game(from_scratch=true):
	game.pause(true)
	reset()
	$BuildingLabel.show()
	await get_tree().process_frame
	if from_scratch:
		level = StormG.starting_level
		round_in_level = 0
		game.time_scale = 0.5

	_advance_if_needed()
	game.need_to_increase_level = false
	create_board()
	time_started_level_ms = game.game_time
	started_playing.emit()
	BE.upsert_game_state("Storm",
		{"state":"new","level": level, "round_in_level": round_in_level})

func _input(event) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if event.is_action_pressed("new_board"):
		update_score.emit(-1)
	# elif event.is_action_pressed("clue"):
	# 	show_clue()
	elif event.is_action_pressed("right", true) or event.is_action_pressed("ui_right", true):
		move_dir(0)
	elif event.is_action_pressed("down", true) or event.is_action_pressed("ui_down", true):
		move_dir(1)
	elif event.is_action_pressed("left", true) or event.is_action_pressed("ui_left", true):
		move_dir(2)
	elif event.is_action_pressed("up", true) or event.is_action_pressed("ui_up", true):
		move_dir(3)
	elif event.is_action_pressed("stop"):
		if player != null:
			player.path.clear()

func move_dir(dir):
	if player == null or !game.level_is_ready:
		return
	player.path.clear()
	
	next_player_dir = dir
	if abs(dir - player.direction) == 2:
		player.last_major_tick_ms = 0
		tick()

func _start_playing():
	time_started_level_ms = game.game_time
	if play_start_sound_once:
		play_start_sound_once = false
		game.play_sound("start")
		if player != null:
			player.play()
		game.set_time_left(0,0,storm_duration_s)
		game.pause(false)

func _process(_delta: float) -> void:
	pass
	
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
	pipe.sig_leak_overflow.connect(_on_pipe_leak_overflow)

# func _check_if_all_rooms_answered():
# 	for rid in rooms.size():
# 		if not answered_rooms.has(rid):
# 			return false		
# 	# game.play_sound("delivery")
# 	MainGlobals.do_after(1, func(): level_is_done(true))
# 	return true

func answered(correct: bool):
	if correct:
		game.add_score_and_time(1,5)
		game.add_correct_or_mistake(1,0)
		game.play_sound("delivery")
		# _check_if_all_rooms_answered()
	else:
		game.add_score_and_time(-1,-5)
		game.add_correct_or_mistake(0,1)
		game.play_sound("gaveup")

func _on_pipe_pressed(_board_pos):	
	var cell = bcell(_board_pos)
	if !cell.ispipe or cell.pipe.has_brick >= 0:
		return
	if cell.room_id >= 0:
		create_actions_popup(_board_pos)
			

func add_empty(p):
	var e = empty_scene.instantiate()
	e.board_pos = p
	e.position = game.board_to_px(p)
	add_child(e)
	empties.append(e)

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
	
var room_min_size = 9
var room_max_size = 12
var board_margin = 5

#region create_rooms

func _carve_room(pos: Vector2i, size: Vector2i, room_id:int) -> void:
	for y in range(pos.y, pos.y + size.y):
		for x in range(pos.x, pos.x + size.x):
			add_pipe(Vector2i(x, y), room_id)

var rooms:Array[Rect2i] = []
var rooms_checked_connections = {}
var visited_rooms = {}

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

func add_door_at(p):
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
	# rng = RandomNumberGenerator.new()
	# rng.seed = 1110

	game.colors.shuffle()

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

	add_player()
	zoom_camera(true)

	add_bricks()
	add_drains()
	add_furniture()

	# zoom_camera(false)
	$BuildingLabel.hide()

	var ppp = MainGlobals.generic_text_popup()
	add_child(ppp)
	# get_window().add_child(ppp)
	# var win := get_tree().root.get_window()
	# win.add_child(ppp)
	ppp.closed.connect(_on_closed_intro_popup)

	var timestr = MainGlobals.round_duration_str(storm_duration_s)
	var roomsstr = "one room" if rooms.size() == 1 else "%d rooms" % rooms.size()
	ppp.popup_text("You have\n%s\nto protect\n\nThe storm\nwill last\n%s" % [roomsstr, timestr], true, 120)

	game.play_sound("rain")
	started_sounds = true

func _on_closed_intro_popup():
	game.level_is_ready = true
	_start_playing()

func close_to_corridor(p:Vector2i, dist:int):
	for add_r in range(-dist,dist+1):
		for add_c in range(-dist,dist+1):
			var q = p + Vector2i(add_c,add_r)
			if game.in_board(q) and board[q.y][q.x].is_corridor:
				return true
	return false

func dist_to_player(p:Vector2i):
	return (p - player.board_pos).length()

func add_furniture():
	var flist = furniture.keys()
	flist.shuffle()
	while flist.size() > 0:
		for r in rooms:
			var f = furniture.get(flist.pop_front(), [])
			if f.size() > 0:
				var p = MainGlobals.pick_one_cell(r.position.x, r.position.y, r.end.x-1, r.end.y-1, 
					func(x,y): return board[y][x].is_fillable())
				if p.x >= 0:
					var cell = board[p.y][p.x]
					cell.pipe.set_furniture(f[0], f[1], f[2])
			if flist.is_empty():
				return

func add_bricks():
	var brick0 = game.rng.randi_range(0,2)
	for r in rooms:
		brick0 += 1
		for nb in range(num_bricks_per_room):
			var p = MainGlobals.pick_one_cell(r.position.x+1, r.position.y+1, r.end.x-2, r.end.y-2, 
				func(x,y): return board[y][x].is_fillable() and dist_to_player(Vector2i(x,y)) >= 1)

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

			
func on_player_is_really_moving(is_moving: bool):
	if is_moving:
		game.play_sound("feet")
	else:
		game.stop_sound("feet")

func can_go_to(p):
	if !game.in_board(p, board_margin):
		return false
	var cell = board[p.y][p.x]
	var cond = cell.ispipe && cell.pipe.has_brick < 0
	return cond
	
func move_player_on_tick():
	if player == null:
		return
	if !player.need_to_major_tick():
		return

	var cell = bcell(player.board_pos)
	if cell.pipe != null and cell.pipe.has_coin >= 0:
		game.add_score_and_time(cell.pipe.has_coin, 0)
		game.play_sound("delivery")
		cell.pipe.has_coin = -1
		cell.pipe.set_rot(board)

	player.set_major_tick_now()

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
			mark_visited_room(board[q.y][q.x].room_id)
			player.set_board_pos(q, board)
			if bcell(q).room_id < 0:
				next_player_dir = dir
				return
	next_player_dir = -1

var last_major_tick_ms = -10000.0
func tick():
	if game.level_is_done:
		return

	if game.game_time - last_time_showed_blackout > next_blackout_duration_s * 1000 and started_sounds:
		sig_blackout.emit()
		last_time_showed_blackout = game.game_time
		next_blackout_duration_s = rng.randf_range(10,20)

	if !game.level_is_ready:
		return

	var now = game.game_time
	if now - last_time_added_leak > next_duration_for_leak_ms:
		add_leak()
		last_time_added_leak = now
	if now - last_major_tick_ms > game.major_tick_time_ms * game.time_scale:
		last_major_tick_ms = now
		var po = pct_overflow()
		if po > 30:
			level_is_done(false)

	# if all_agents_done():
	# 	level_is_done(true)
	# 	return
	
	move_player_on_tick()

	if game.game_time - last_time_played_water_drop > next_water_drop_duration_s * 1000:
		game.play_sound("water_drop")
		last_time_played_water_drop = game.game_time
		next_water_drop_duration_s = game.rng.randf_range(2, 8)

	# if game.game_time - time_started_level_ms >= storm_duration_s * 1000:
	# 	level_is_done(true)

func add_leak():
	next_duration_for_leak_ms = game.rng.randf_range(2000, 4000)
	for i in range(100):
		var room_id = game.rng.randi_range(0, rooms.size()-1)
		var r = rooms[room_id]
		var p = MainGlobals.pick_one_cell(r.position.x, r.position.y, r.end.x-1, r.end.y-1, func(x,y): return board[y][x].is_fillable())

		if p.x >= 0:
			var cell = board[p.y][p.x]
			cell.pipe.start_leak()
			game.play_sound("swoosh")
			return

func _on_level_done_popup_closed():
	sig_level_is_done.emit(true)

func _on_game_popup_closed():
	sig_level_is_done.emit(last_level_was_a_win)

func level_is_done(didwin: bool):
	last_level_was_a_win = didwin
	game.level_is_done = true
	game.stop_sound("rain")
	game.stop_sound("feet")
	BE.send_event("level_done", "Storm", {
		"level": level,
		"round_in_level": round_in_level,
		"didwin": int(didwin),
	})
	var time_from_start_s: float = (game.game_time - time_started_level_ms) / 1000.0
	var stats: Dictionary = count_round_stats()
	var stats_str: String = "\nScore: %d  |  Time: %ds\nSaved: %d  Lost: %d  Flooded: %d" % [
		game.score, int(time_from_start_s), stats["saved"], round_items_lost, stats["flooded"]]
	if didwin:
		var score_add: int = min(5, 60 - time_from_start_s)
		var time_add: int = min(10, 60 - time_from_start_s)
		game.add_score_and_time(score_add, time_add)
		game.need_to_increase_level = true
		if need_to_increase_level():
			MainGlobals.global_level_is_done(true)
			game.show_level_done_popup(self, "", "", level)
		else:
			var cur_round: int = round_in_level + 1
			reset()
			await get_tree().process_frame
			game.show_game_popup(self, "Well done!", "Round %d of Level %d\ncompleted%s" % [cur_round, level, stats_str])
	else:
		var cur_round: int = round_in_level + 1
		game.show_game_popup(self, "Oh no!", "House flooded!\nRound %d of Level %d%s" % [cur_round, level, stats_str])

func need_to_increase_level() -> bool:
	return round_in_level >= rounds_per_level - 1

func _advance_if_needed() -> void:
	if game == null:
		return
	if game.need_to_increase_level:
		round_in_level += 1
		if round_in_level >= rounds_per_level:
			round_in_level = 0
			level += 1
			game.add_life()
	_apply_level()

func _apply_level() -> void:
	if game == null:
		return
	var s: int = 51 + level * 2
	num_rooms = min(MAX_POSSIBLE_ROOMS, 0 + level)
	game.forced_board_size = Vector2i(s, s)
	player_max_speed_scale = 1.5
	num_bricks_per_room = 2
	storm_duration_s = 60.0 * (1.0 + level)
	# storm_duration_s = 10.0 * (0.0 + level)	# for debug mode
	game.set_time_left(0, 0, storm_duration_s)
	available_actions = []
	var amounts: Array = [
		["bucket",	min(3, 1 + level), 1.0],
		["rag",		min(3, 1 + level), 1.0],
		["fix",		min(3, 1 + level), 0],
		["cup",		4, 0.55],
		["plate",	4, 9.0/40.0]
	]
	var id: int = 0
	for action in amounts:
		for _n in range(action[1]):
			id += 1
			available_actions.append(CAction.new(action[0], id, 0, action[2]))
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
	# player.remove_player.connect(on_player_remove_player)
	player.set_pos(game.board_to_px(p), direction)
	mark_visited_room(board[p.y][p.x].room_id)

	var color = Color(0.1,0.5,0.99) #game.next_color()
	# var color = Color(0.99,0.5,0.19) #game.next_color()
	player.set_color(color)

func mark_visited_room(room_id):
	visited_rooms[room_id] = true

func add_player():
	var p = game.get_board_center()
	add_player_at(p, 1)


var colors_for_popup: Array = []
func on_player_remove_player(_arrived: bool):		
	if _arrived:
		zoom_camera(false)
		await get_tree().process_frame
		# var n:int = min(MAX_POSSIBLE_ROOMS, rooms.size())
	else:	
		level_is_done(false)
	# if player != null:
	# 	player.queue_free()
	# 	player = null
	# 	player_cam = null
	# level_is_done(arrived)

func on_time_over():
	level_is_done(true)

func on_lives_depleted():
	pass

func _on_pipe_leak_overflow(_pipe):
	var val = _pipe.furniture_value if _pipe.furniture_value > 0 else 2
	if _pipe.furniture_value > 0:
		round_items_lost += 1
	game.add_score_and_time(-val,0)

var popup:PopupPanel = null

func _unhandled_input(event: InputEvent) -> void:
	if popup == null or not is_instance_valid(popup) or not popup.visible:
		return

	if event.is_action_pressed("ui_cancel"):
		_close_popup()
		get_viewport().set_input_as_handled()

# 	# Mouse / touch press outside popup: close AND consume
# 	if event is InputEventMouseButton and event.pressed:
# 		if not _event_is_inside_popup(event.position):
# 			_close_popup()
# 			get_viewport().set_input_as_handled()
# 		return

# 	if event is InputEventScreenTouch and event.pressed:
# 		if not _event_is_inside_popup(event.position):
# 			_close_popup()
# 			get_viewport().set_input_as_handled()
# 		return

# 	# Important: if a drag happens while popup is open, consume it
# 	# (prevents your swipe code from seeing the motion)
# 	if event is InputEventMouseMotion:
# 		get_viewport().set_input_as_handled()
# 		return

# 	if event is InputEventScreenDrag:
# 		get_viewport().set_input_as_handled()
# 		return


# func _event_is_inside_popup(screen_pos:Vector2) -> bool:
# 	# PopupPanel is a Window in Godot 4; this works reliably:
# 	var r := Rect2(popup.position, popup.size)
# 	return r.has_point(screen_pos)

var layout = []

static func _v_sort(a: Array, b:Array):
	if a[1] < b[1]: return true
	if b[1] < a[1]: return false
	return a[0] < b[0]

static func _dist_sort(a : Array, b : Array):
	var da = a[0]*a[0] + a[1]*a[1]
	var db = b[0]*b[0] + b[1]*b[1]
	return da < db

func hamming_d_to_player(p: Vector2i) -> int:
	if player == null:
		return -1

	var d = (p - player.board_pos).abs()
	return max(d.x, d.y)

func create_actions_popup(_board_pos: Vector2i) -> void:
	var d_to_player:int = hamming_d_to_player(_board_pos)
	if d_to_player < 0 or d_to_player > 1:
		return

	var cell = board[_board_pos.y][_board_pos.x]
	if !cell.pipe.water_active and !cell.pipe.is_drain:
		return

	if cell.action != null and cell.action.name != "drain" and cell.pipe.action_full:
		game.play_sound("tap")
		cell.action.level = cell.pipe.action_level
		available_actions.append(cell.action)
		cell.action = null
		cell.pipe.set_action("", [], 0, 0)
		sort_available_actions()
		return

	var room_id = cell.room_id
	var room = rooms[room_id]
	var p0 = room.position

	var sep := 1

	var border_w = sep*4
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT		# must be transparent for the center pipe to show
	# sb.bg_color = Color(1, 1, 1, 0.5)
	# sb.bg_color = Color(0.9, 0.9, 0.4, 1.0)
	sb.set_border_width_all(border_w)
	sb.border_color = Color(0.9, 0.9, 0.4, 1.0).darkened(1)

	var p0g = board[p0.y][p0.x].pipe.global_position
	var p01g = board[p0.y+1][p0.x+1].pipe.global_position
	var pcg = cell.pipe.global_position
	var p_transform = get_viewport().get_canvas_transform()
	var screen_pos: Vector2 = p_transform * pcg
	var actual_pipe_w = int((p_transform * p01g - p_transform * p0g).x)
	var box_w :int = actual_pipe_w * 1 + 4

	if popup != null and is_instance_valid(popup):
		MainGlobals.set_popup_open(false)
		popup.queue_free()
		popup = null

	popup = PopupPanel.new()
	add_child(popup)
	popup.unresizable = true
	popup.add_theme_stylebox_override("panel", sb)

	var canvas := Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.offset_left = 0
	canvas.offset_top = 0
	canvas.offset_right = 0
	canvas.offset_bottom = 0
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(canvas)
	canvas.add_theme_stylebox_override("panel", sb)

	var origin := Control.new()
	origin.anchor_left = 0.5
	origin.anchor_top = 0.5
	origin.anchor_right = 0.5
	origin.anchor_bottom = 0.5
	origin.offset_left = 0
	origin.offset_top = 0
	origin.offset_right = 0
	origin.offset_bottom = 0
	origin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(origin)
	# origin.add_theme_stylebox_override("panel", sb)

	var is_on_drain:bool = cell.action != null and cell.action.name == "drain"
	var use_th = 1e-4 if is_on_drain else -1e-6
	var actions_to_use:Array = []
	for a in available_actions:
		if a.level >= use_th:
			actions_to_use.append(a)
	if actions_to_use.size() > 24:
		actions_to_use = actions_to_use.slice(0,24)
	var n = actions_to_use.size()

	var swatch_color = Color(0.2, 0.7, 0.8, 1.0)
	if is_on_drain:
		# swatch_color = Color(0.2, 0.6, 0.2, 1.0)
		swatch_color = Color(0.9, 0.4, 0.0, 1.0)
	var empty_color = swatch_color

	var d_vals = [-1,0,1] if n <= 8 else [-2,-1,0,1,2]

	var w = d_vals.size()
	var h = w

	popup.size = Vector2i(box_w * w + (w+0)*2*sep + 2*border_w, box_w * h + (h+0)*2*sep + 2*border_w)
	var rect := MainGlobals.clamp_popup_rect(screen_pos - popup.size/2.0, popup.size, 20)
	popup.popup(rect)
	MainGlobals.set_popup_open(true)
	if not popup.popup_hide.is_connected(MainGlobals.set_popup_open.bind(false)):
		popup.popup_hide.connect(MainGlobals.set_popup_open.bind(false))
	
	if layout.size() != w * h:
		layout = []
		for r in d_vals:
			for c in d_vals:
				if r != 0 or c != 0:
					layout.append([c,r])
		layout.sort_custom(_dist_sort)
		var layoutn = layout.slice(0, n)
		layoutn.sort_custom(_v_sort)
		layout = layoutn + layout.slice(n, layout.size())
		layout.append([0,0])

	for i in range(w * h):
		var rel_p = layout[i]
		var panel := action_scene.instantiate()
		# swatch_color = game.color_by_index(1).lightened(0.5)
		# swatch_color = Color(0.2, 0.7, 0.3, 1.0)
		if i < n:
			var action = actions_to_use[i]
			var action_texture = action_textures.get(action.name, [])
			var swatch = panel.init(box_w, sep, swatch_color, action.name.to_upper()[0], "", action_texture, action.level)
			swatch.set_meta("target_pos", _board_pos)
			swatch.set_meta("action_id", action.id)
			swatch.gui_input.connect(_on_action_pressed.bind(swatch))
		else:
			var swatch = panel.init(box_w, sep, Color.TRANSPARENT if i == w*h-1 else empty_color)
			swatch.set_meta("target_pos", _board_pos)
			swatch.set_meta("action_id", -1)
			swatch.gui_input.connect(_on_action_pressed.bind(swatch))

		origin.add_child(panel)

		panel.anchor_left = 0
		panel.anchor_top = 0
		panel.anchor_right = 0
		panel.anchor_bottom = 0

		panel.size_flags_horizontal = 0
		panel.size_flags_vertical = 0

		panel.position = Vector2(rel_p[0] - 0.5,rel_p[1] - 0.5) * (box_w + 2*sep)

func get_action_by_id(action_id:int, pop:bool):
	for a_idx in range(available_actions.size()):
		if available_actions[a_idx].id == action_id:
			var a = available_actions[a_idx]
			if pop:
				available_actions.remove_at(a_idx)
			return a
	return null

func sort_available_actions():
	available_actions.sort_custom(func(a: CAction, b:CAction): return a.id <= b.id)
	
func _on_action_pressed(event, rect: Control):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target_pos: Vector2i = rect.get_meta("target_pos")
		var action_id: int = rect.get_meta("action_id")
		if game.in_board(target_pos):
			var cell = board[target_pos.y][target_pos.x]
			if !cell.ispipe:
				return
			var prev_action:CAction = cell.action
			if action_id == -1:	# pickup
				if prev_action != null and prev_action.name != "drain":
					game.play_sound("tap")
					prev_action.level = cell.pipe.action_level
					available_actions.append(prev_action)
					cell.action = null
					cell.pipe.set_action("", [], 0, 0)
			else:
				var new_action = get_action_by_id(action_id, false)

				if prev_action != null and prev_action.name == "drain":
					new_action.level = 0
					game.play_sound("water_pour")
					game.add_score_and_time(5,0)
				else:
					game.play_sound("tap")
					var pipe = cell.pipe
					if prev_action != null:
						prev_action.level = pipe.action_level
						available_actions.append(prev_action)
					get_action_by_id(action_id, true)

					cell.action = new_action
					var action_texture = action_textures.get(new_action.name, [])
					pipe.set_action(new_action.name, action_texture, new_action.level, new_action.overflow_level)
					game.add_score_and_time(2,0)
		
		sort_available_actions()
		MainGlobals.swipe_was_drag = true
		_close_popup()

func _close_popup():
	MainGlobals.set_popup_open(false)
	popup.hide()
	popup.queue_free()
	popup = null

func count_round_stats() -> Dictionary:
	var flooded: int = 0
	var saved: int = 0
	for r in rooms:
		for row in range(r.position.y, r.end.y):
			for col in range(r.position.x, r.end.x):
				var p = board[row][col].pipe
				if p.water_overflowed:
					flooded += 1
				elif p.furniture_value > 0:
					saved += 1
	return {"flooded": flooded, "saved": saved}

func pct_overflow():
	var n_overflow:int = 0
	var n_total:int = 0
	for r in rooms:
		n_total += r.get_area()
		for row in range(r.position.y, r.end.y):
			for col in range(r.position.x, r.end.x):
				if board[row][col].pipe.water_overflowed:
					n_overflow += 1
	return 100.0 * n_overflow / n_total

func add_drains():
	for r in rooms:
		var p = MainGlobals.pick_one_cell(r.position.x, r.position.y, r.end.x-1, r.end.y-1, 
			func(x,y): return board[y][x].is_fillable())

		if p.x >= 0:
			var cell = board[p.y][p.x]
			cell.action = CAction.new("drain",-1)
			cell.pipe.set_action("drain", action_textures["drain"], 0, 0)
		
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

func bcell(p:Vector2i, margin=0) -> OneCell:
	if !game.in_board(p, margin):
		return null
	else:
		return board[p.y][p.x]

func is_wall_between(p, q, also_check_brick:bool = true):
	var to = bcell(q)
	var from = bcell(p)

	if !to.ispipe || !from.ispipe:
		return true

	if also_check_brick and (to.pipe.has_brick >= 0 || from.pipe.has_brick >= 0):
		return true

	return false

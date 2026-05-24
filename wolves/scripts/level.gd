extends CanvasLayer

enum Dirs {right=0,down=1,left=2,up=3}
const DirArray = [Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0), Vector2i(0,-1)]

var rng = RandomNumberGenerator.new()		

var game: GenericGameUtil

class OneCell:
	var ispipe := false
	var has_agent := false
	var room_id := -1
	var color_idx := -1
	var color = null
	var pipe = null
	var agent = null
	var is_corridor = false
	var is_field = false
	var is_outside = false

	func clear():
		ispipe = false
		has_agent = false
		room_id = -1
		color_idx = -1
		color = null
		pipe = null
		agent = null
		is_corridor = false
		is_field = false
		is_outside = false

	func is_fillable() -> bool:
		return ispipe && !has_agent && pipe.can_fill()

	var fences:Array: get = get_fences

	func get_fences() -> Array:
		return pipe.fences if pipe != null else [false,false,false,false]
	
var times_to_answer := []
# var _round_start_ms := 0
var _dist_to_scare := 2

var _cfg: Dictionary = {}
var board: Array
var agents = []
var pipes = []
var empties = []
var outsides = []
var farm_openings = []
var farm_openings_outside = []
var agent_start_positions = []
var agent_start_directions = []
var time_started_level_ms = 0
var time_increased_difficulty_ms = 0
var level: int = 0
var num_more_packets = 0
var num_rooms := 4
var player = null
var player_max_speed_scale = 1.7
var agent_max_speed_scale = 1.0
var next_player_dir = -1
var time_to_hide := 0
var play_start_sound := true
var pct_sheep_to_add := 0.3
var num_bricks_per_room := 2
var num_bricks_in_farm := 4
var MAX_POSSIBLE_ROOMS := 1
var MAX_COLORS_TO_USE := 12
var last_level_was_a_win := true
var in_answring_mode := false
@export var pipe_scene: PackedScene = load("res://wolves/scenes/pipe.tscn")
@export var empty_scene: PackedScene = load("res://wolves/scenes/empty_space.tscn")
@export var agent_scene: PackedScene = load("res://wolves/scenes/agent.tscn")
@export var player_scene: PackedScene = load("res://wolves/scenes/player.tscn")

var ambient_audio := preload("res://wolves/art/audio/delon_boomkin-sheep-bells-ringing-457441.mp3")
var feet_audio := preload("res://art/sounds/kenney/Audio/footstep_grass_001.ogg")
var start_audio := preload("res://art/sounds/click-2.mp3")
var swoosh_audio := preload("res://art/sounds/swoosh.mp3")

var sheep_audios := [
	preload("res://wolves/art/audio/freesound_community-sheep-2-106164.mp3"),
	preload("res://wolves/art/audio/freesound_community-sheep-3-89230.mp3"),
	preload("res://wolves/art/audio/stu9-sheep-352668.mp3"),
	preload("res://wolves/art/audio/universfield-sheep-122256.mp3"),
]

var dog_audios := [
	preload("res://wolves/art/audio/dragon-studio-dog-bark-382732.mp3"),
	preload("res://wolves/art/audio/dragon-studio-free-dog-bark-419014.mp3"),
]

var wolf_audios := [
	preload("res://wolves/art/audio/dragon-studio-spooky-wolf-howl-410547.mp3"),
	preload("res://wolves/art/audio/freesound_community-wolf-howl-6310.mp3"),
	preload("res://wolves/art/audio/dragon-studio-wolf-howl-2-359870.mp3"),
]

signal started_playing
signal sig_level_is_done(didwin:bool)
signal update_score(score:int)

func _ready() -> void:
	game = WolvesG.game
	game.sig_time_over.connect(on_time_over)
	game.sig_lives_depleted.connect(on_lives_depleted)
	level = WolvesG.starting_level
	_apply_level()

	game.add_sound(self, "ambient", ambient_audio, true)
	game.add_sound(self, "feet", feet_audio, true)
	game.add_sound(self, "start", start_audio)
	game.add_sound(self, "swoosh", swoosh_audio)

	game.add_sound(self, "sheep", sheep_audios)
	game.add_sound(self, "bark", dog_audios)
	game.add_sound(self, "wolf", wolf_audios)

	MAX_COLORS_TO_USE = min(MAX_COLORS_TO_USE, game.colors.size())
	if not MainGlobals.sig_game_popup_closed.is_connected(_on_game_popup_closed):
		MainGlobals.sig_game_popup_closed.connect(_on_game_popup_closed)
	if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
		MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
	MainGlobals.sig_path_drawn.connect(_on_path_drawn)  
	
func reset():
	next_player_dir = -1
	time_to_hide = 0
	play_start_sound = true

	if player != null:
		player.queue_free()
		player = null
	# player_cam = null

	if game_cam != null:
		game_cam.queue_free()
		game_cam = null

	for c in pipes:
		c.queue_free()
	for c in agents:
		c.queue_free()
	for c in empties:
		c.queue_free()
	pipes.clear()
	empties.clear()
	agents.clear()

	agent_start_positions = []
	agent_start_directions = []
	time_started_level_ms = 0
	num_more_packets = 0

func new_game(from_scratch=true):
	reset()
	# $BuildingLabel.show()
	$BuildingLabel.hide()
	await get_tree().process_frame
	if from_scratch:
		level = WolvesG.starting_level
		game.time_scale = 0.5

	_advance_if_needed()
	game.level_label_changed("Level %d" % level)
	_load_cfg()
	game.need_to_increase_level = false
	in_answring_mode = false
	$TextureRect.modulate = Color(0.7,0.6,0.3,1)
	create_board()
	time_started_level_ms = MainGlobals.timems()
	time_increased_difficulty_ms = time_started_level_ms
	started_playing.emit()
	BE.upsert_game_state("Wolves",
		{"state":"new","level": level})

func bcell(p:Vector2i, margin=0) -> OneCell:
	if !game.in_board(p, margin):
		return null
	else:
		return board[p.y][p.x]

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
		if player != null:
			player.path.clear()
			if player.is_moving:
				player.need_to_stop = true

func move_dir(dir):
	if player == null:
		return
	if !player.reached_target_pos and player.direction == dir:
	# if player.velocity.length() > 1e-3 and player.direction == dir:
		return
	player.path.clear()
	player.need_to_move = true
	player.need_to_stop = false
	if !game.level_is_ready:
		return
	next_player_dir = dir
	player.is_moving = true
	if abs(dir - player.direction) == 2:
		player.last_major_tick_ms = 0
		tick(true)

func _start_playing():
	if play_start_sound:
		play_start_sound = false
		game.play_sound("start")
		game.play_sound("ambient")
		if player != null:
			player.play()

var time_to_remove_compund_fence:float = 0
var time_to_remove_farm_fence:float = 0
var time_to_next_wolf:float = 0
var time_to_play_wolf:float = 0

func _process(_delta: float) -> void:
	if player != null and !player.was_hit:
		if time_to_hide > 0 and MainGlobals.timems() >= time_to_hide:
			_start_playing()

	if game.playing and game.level_is_ready:
		var now = game.game_time
		if now >= time_to_remove_compund_fence:
			if rooms.size() > 0 and remove_one_compund_fence(rooms[0]):
				var interval = _cfg.get("compund_fence_interval", 5000)
				time_to_remove_compund_fence = now + interval + rng.randi_range(-500, 500)

		if now >= time_to_remove_farm_fence:
			if remove_one_farm_fence():
				var interval = _cfg.get("farm_fence_interval", 8000)
				time_to_remove_farm_fence = now + interval + rng.randi_range(-500, 500)

		if now >= time_to_next_wolf:			
			var interval = _cfg.get("wolves_interval", 8000)
			time_to_next_wolf = now + interval + rng.randi_range(-500, 500)
			dispatch_new_wolf()
		
		if now >= time_to_play_wolf:
			if time_to_play_wolf > 1:
				game.play_sound("wolf")
			time_to_play_wolf = now + 10000 + rng.randi_range(-3000,3000)
	
func add_pipe(p, room_id := -1, is_grass := false):
	var cell = board[p.y][p.x]	
	if cell.ispipe:
		if room_id >= 0:
			cell.room_id = room_id
		return
	cell.ispipe = true
	var pipe = pipe_scene.instantiate()
	cell.pipe = pipe
	pipe.board_pos = p
	pipe.position = game.board_to_px(p)
	cell.room_id = room_id
	pipe.is_grass = is_grass
	if room_id >= 0:
		board[p.y][p.x].color_idx = _cfg.get("color_idx",-1)
		board[p.y][p.x].color = _cfg.get("color",null)
	add_child(pipe)
	pipes.append(pipe)
	pipe.pipe_pressed.connect(_on_pipe_pressed)

func _on_pipe_pressed(_board_pos):
	pass		

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
	
var board_margin = 3

#region create_rooms

func _carve_room(pos: Vector2i, size: Vector2i, room_id:int) -> void:
	for y in range(pos.y, pos.y + size.y):
		for x in range(pos.x, pos.x + size.x):
			var p := Vector2i(x,y)
			add_pipe(p, room_id)
			var c = bcell(p)
			if x == pos.x:
				c.pipe.fences[2] = true
				room_outsizes.append(p + Vector2i(-1,0))
			if y == pos.y + size.y-1:
				c.pipe.fences[1] = true
				room_outsizes.append(p + Vector2i(0,1))
			if x == pos.x + size.x-1:
				c.pipe.fences[0] = true
				room_outsizes.append(p + Vector2i(1,0))
			if y == pos.y:
				c.pipe.fences[3] = true
				room_outsizes.append(p + Vector2i(0,-1))
	room_outsizes.append(Vector2i(pos.x-1,pos.y-1))
	room_outsizes.append(Vector2i(pos.x-1,pos.y+size.y))
	room_outsizes.append(Vector2i(pos.x+size.x,pos.y-1))
	room_outsizes.append(Vector2i(pos.x+size.x,pos.y+size.y))

var rooms:Array[Rect2i] = []
var rooms_checked_connections = {}
var visited_rooms = {}
var answered_rooms = {}
var room_outsizes:Array[Vector2i] = []

func did_visit_all_rooms() -> bool:
	for rid in rooms.size():
		if not visited_rooms.has(rid):
			return false
	return true

func create_rooms(_nrooms := 4, margin := 5, RD := 5, _PAD := 3) -> void:
	# RD: how "spread" placements can be around an anchor (bigger = looser)
	# PAD: minimum gap between rooms (1 = one tile gap; 0 = can touch)
	var center = game.board_size / 2

	rooms.clear()
	room_outsizes.clear()
	rooms_checked_connections.clear()
	visited_rooms.clear()
	answered_rooms.clear()

	var w0 = _cfg.get("w", 9)
	var h0 = _cfg.get("h", w0)
	var p0 = center - Vector2i(w0 / 2, h0 / 2)

	# Clamp room 0 into bounds
	p0.x = clamp(p0.x, margin, game.board_size.x - margin - w0)
	p0.y = clamp(p0.y, margin, game.board_size.y - margin - h0)

	var next_room_id = 0
	rooms.append(Rect2i(p0, Vector2i(w0, h0)))
	_carve_room(p0, Vector2i(w0, h0), next_room_id)

	next_room_id += 1

	RD = clamp(RD, 2, 5)

	#region create more rooms
	# for k in range(1, nrooms):
	# 	var placed = false

	# 	for attempt in range(900):
	# 		var rw = (rng.randi_range(room_min_size, room_max_size) | 1)
	# 		var rh = (rng.randi_range(room_min_size, room_max_size) | 1)
	# 		var rsize = Vector2i(rw, rh)

	# 		# --- Pick an anchor room to cluster around ---
	# 		# Early attempts prefer lower IDs (usually nearer center); later attempts allow any
	# 		var anchor_idx = 0
	# 		if rooms.size() > 1:
	# 			if attempt < 350:
	# 				anchor_idx = rng.randi_range(0, min(rooms.size() - 1, 1))
	# 			elif attempt < 700:
	# 				anchor_idx = rng.randi_range(0, min(rooms.size() - 1, 2))
	# 			else:
	# 				anchor_idx = rng.randi_range(0, rooms.size() - 1)

	# 		var anchor = rooms[anchor_idx]
	# 		var apos: Vector2i = anchor.position
	# 		var asz: Vector2i = anchor.size

	# 		# --- Place near a side of the anchor, with small jitter ---
	# 		var side = rng.randi_range(0, 3) # 0=up,1=right,2=down,3=left

	# 		# Gap keeps rooms close; PAD prevents touching
	# 		var gap = PAD + rng.randi_range(0, RD)

	# 		var rpos = Vector2i.ZERO
	# 		if side == 0: # above
	# 			rpos.x = (apos.x + asz.x / 2) - rsize.x / 2 + rng.randi_range(-RD, RD)
	# 			rpos.y = apos.y - gap - rsize.y
	# 		elif side == 2: # below
	# 			rpos.x = (apos.x + asz.x / 2) - rsize.x / 2 + rng.randi_range(-RD, RD)
	# 			rpos.y = apos.y + asz.y + gap
	# 		elif side == 1: # right
	# 			rpos.x = apos.x + asz.x + gap
	# 			rpos.y = (apos.y + asz.y / 2) - rsize.y / 2 + rng.randi_range(-RD, RD)
	# 		else: # left
	# 			rpos.x = apos.x - gap - rsize.x
	# 			rpos.y = (apos.y + asz.y / 2) - rsize.y / 2 + rng.randi_range(-RD, RD)

	# 		# Clamp into bounds
	# 		rpos.x = clamp(rpos.x, margin, game.board_size.x - margin - rsize.x)
	# 		rpos.y = clamp(rpos.y, margin, game.board_size.y - margin - rsize.y)

	# 		if not game.rect_in_board(rpos, rsize, margin):
	# 			continue

	# 		# Enforce minimal spacing (PAD), not big RD
	# 		var ok = true
	# 		for r in rooms:
	# 			if Rect2i(rpos, rsize).grow(PAD).intersects(r.grow(PAD)):
	# 				ok = false
	# 				break
	# 		if not ok:
	# 			continue

	# 		rooms.append(Rect2i(rpos, rsize))
	# 		_carve_room(rpos, rsize, next_room_id)
	# 		next_room_id += 1

	# 		placed = true
	# 		break

	# 	if not placed:
	# 		break
	#endregion create more rooms

#endregion create_rooms

var farm_borders:Array = [[],[],[],[]]

func clear_board_array():
	if board.size() == game.board_size.y and board[0].size() == game.board_size.x:
		for y in game.board_size.y:
			for x in game.board_size.x:
				board[y][x].clear()
	else:
		board.clear()
		for row_index in game.board_size.y:
			var row: Array[OneCell]
			row.resize(game.board_size.x)
			for col_index in game.board_size.x:
				row[col_index] = OneCell.new()
			board.append(row)

func create_board() -> void:
	clear_board_array()

	zoom_camera(false)

	time_to_remove_compund_fence = game.game_time + 2000
	time_to_remove_farm_fence = game.game_time + 10000

	create_rooms(num_rooms, board_margin)
	
	outsides = []
	farm_openings = []
	farm_openings_outside = []
	farm_borders = [[],[],[],[]]
	for y in range(board_margin,game.board_size.y-board_margin):
		for x in range(board_margin,game.board_size.x-board_margin):
			var p = Vector2i(x,y)
			var c = bcell(p)
			if !c.ispipe:
				c.is_field = true
				add_pipe(Vector2i(x,y), -1, true)
				if x == board_margin:
					c.pipe.fences[2] = true
					farm_borders[2].append(p)
					outsides.append(Vector2i(x-1,y))
				if y == game.board_size.y-board_margin - 1:
					c.pipe.fences[1] = true
					farm_borders[1].append(p)
					outsides.append(Vector2i(x,y+1))
				if x == game.board_size.x-board_margin - 1:
					c.pipe.fences[0] = true
					farm_borders[0].append(p)
					outsides.append(Vector2i(x+1,y))
				if y == board_margin:
					c.pipe.fences[3] = true
					farm_borders[3].append(p)
					outsides.append(Vector2i(x,y-1))
	outsides.append(Vector2i(board_margin-1,board_margin-1))
	outsides.append(Vector2i(game.board_size.x-board_margin,board_margin-1))
	outsides.append(Vector2i(board_margin-1,game.board_size.y-board_margin))
	outsides.append(Vector2i(game.board_size.x-board_margin,game.board_size.y-board_margin))
		
	for p in outsides:
		bcell(p).is_outside = true
		if !bcell(p).pipe:
			add_pipe(p, -1, false)
			bcell(p).pipe.modulate = Color(1,0,0,0)

	for p in outsides + room_outsizes:
		if !bcell(p).ispipe:
			add_pipe(p, -1, false)
			bcell(p).pipe.modulate = Color(1,0,0,0)
		add_empty(p)

	# for y in board_margin-1:
	# 	for x in game.board_size.x:
	# 		if !board[y][x].ispipe:
	# 			add_pipe(Vector2i(x,y), -1, false)
	# 		if !board[game.board_size.y-y-1][x].ispipe:
	# 			add_pipe(Vector2i(x,game.board_size.y-y-1), -1, false)
	# for y in game.board_size.y:
	# 	for x in board_margin-1:
	# 		if !board[y][x].ispipe:
	# 			add_pipe(Vector2i(x,y), -1, false)
	# 		if !board[y][game.board_size.x-x-1].ispipe:
	# 			add_pipe(Vector2i(game.board_size.x-x-1,y), -1, false)


	# 		if !board[y][x].ispipe || board[y][x].is_field || board[y][x].is_outside:
	# 			if !board[y][x].ispipe:
	# 				add_pipe(Vector2i(x,y), -1, false)
	# 				# board[y][x].pipe.modulate = Color(1,0,0,0.4)
	# 			add_empty(Vector2i(x,y))
				
	show_hide_walls()
				
	for pipe in pipes:
		pipe.set_rot(board)

	await get_tree().process_frame
	await get_tree().process_frame

	add_player()
	# zoom_camera(true)
	# zoom_camera(false)

	add_bricks()
	add_sheep()

	$BuildingLabel.hide()
	game.level_is_ready = true	
	_start_playing()
	MainGlobals.draw_path_mode = true

func close_to_corridor(p:Vector2i, dist:int):
	for add_r in range(-dist,dist+1):
		for add_c in range(-dist,dist+1):
			var q = p + Vector2i(add_c,add_r)
			if game.in_board(q) and board[q.y][q.x].is_corridor:
				return true
	return false

func add_bricks():
	var brick0 = game.rng.randi_range(0,2)
	for r in rooms:
		brick0 += 1
		var p:Vector2i
		for nb in range(num_bricks_per_room):
			p = MainGlobals.pick_one_cell(r.position.x+1, r.position.y+1, r.end.x-2, r.end.y-2, 
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
	
	brick0 += 1
	for nb in range(num_bricks_in_farm):
		var p = MainGlobals.pick_one_cell(board_margin + 2, board_margin + 2, game.board_size.x - board_margin - 2, game.board_size.y - board_margin - 2,
			func(x,y):
				var cell = board[y][x]
				if cell.is_fillable() and cell.is_field and !adjacent_to_room(Vector2i(x,y)): 
					var d_to_player = (Vector2i(x,y) - player.board_pos).length()
					var d_to_agents = dist_from_agents(Vector2i(x,y))
					if d_to_player >= 1 and d_to_agents >= 1:
						return true
				return false)

		if p.x >= 0:
			var cell = board[p.y][p.x]
			cell.pipe.has_brick = brick0
			cell.pipe.set_rot(board)

func adjacent_to_room(p: Vector2i) -> bool:
	for dir in DirArray:
		var q = p + dir
		if game.in_board(q) and bcell(q).room_id >= 0:
			return true
	return false
	
# var player_cam = null
var game_cam = null

func zoom_camera(zoom_in: bool):
	# var current_cam_scale = player_cam.zoom.x if player_cam != null else 1.0

	game.zoomed_in = zoom_in
	for pipe in pipes:
		pipe.set_rot(board)

	if zoom_in:
		pass
		# var player_camscale = game.get_tiles_in_screen_width() / float(room_max_size+2)
		# if player_cam != null:
		# 	player_cam.zoom = Vector2(player_camscale,player_camscale)
		# 	player_cam.enabled = true
		# 	if game_cam != null:
		# 		game_cam.enabled = false
		# 	return
		# else:
		# 	create_player_camera(player_camscale)
	else:
		var game_camscale = min(game.get_tiles_in_screen_width() / float(game.board_size.x-4), game.get_tiles_in_screen_height() / float(game.board_size.y-5))
		var game_center = game.get_viewport_center()# game.board_to_px(game.get_board_center())# - Vector2(game.tile_size / 2,game.tile_size / 2)
		if !MainGlobals.is_mobile():
			game_center -= Vector2(0,30)		# to account for level # label
		if game_cam != null:
			game_cam.zoom = Vector2(game_camscale,game_camscale)
			game_cam.position = game_center
			game_cam.enabled = true
			# if player_cam != null:
			# 	player_cam.enabled = false
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
	# if player_cam != null:
	# 	player_cam.enabled = false

# func create_player_camera(player_camscale):
# 	if player == null:
# 		return
# 	player_cam = Camera2D.new()
# 	player.add_child(player_cam)

# 	player_cam.zoom = Vector2(player_camscale,player_camscale)
# 	player_cam.position_smoothing_enabled = false
# 	# player_cam.position_smoothing_speed = 10
# 	player_cam.enabled = true
# 	player_cam.limit_left = game.board_to_px(Vector2i(0,0)).x
# 	player_cam.limit_top = game.board_to_px(Vector2i(0,0)).y
# 	player_cam.limit_right = game.board_to_px(Vector2i(game.board_size.x-1,0)).x
# 	player_cam.limit_bottom = game.board_to_px(Vector2i(0,game.board_size.y-1)).y
# 	if game_cam != null:
# 		game_cam.enabled = false

func find_sorted_farm_openings(p, inside:bool = true):
	var openings = farm_openings if inside else farm_openings_outside
	var sorted := openings.duplicate()
	sorted.sort_custom(func(a, b):
		return (a - p).length_squared() < (b - p).length_squared()
	)	
	return sorted

func find_closest_free_sheep(p):
	var maxd = 1000000
	var closest_p:Vector2i = Vector2i(-1,-1)
	for a in agents:
		if a.agent_type == 0:
			var q = a.board_pos
			var cell = bcell(q)
			if cell.room_id < 0:
				var d = (q - p).length()
				if d < maxd:
					maxd = d
					closest_p = q
	return closest_p

func num_wolves():
	var n = 0
	for a in agents:
		if a.agent_type == 1:
			n += 1
	return n

func find_path_to_closest_opening(agent, inside:bool, ignore_closest:bool):
	var p = agent.board_pos
	var sorted = find_sorted_farm_openings(p, inside)
	if sorted.size() == 0:
		return false

	# var npopped = 0
	if ignore_closest:
		sorted.pop_front()
		# npopped += 1
	while sorted.size() > 0:
		var target = sorted.pop_front()
		# npopped += 1
		if target.x >= 0:
			var pstart = p
			var pend = target
			var path = game.astar(pstart, pend, Callable(self, "calc_cost_to_move_wolf_to"), agent.agent_id, pstart)
			while path.size() > 0 and path[0] == pstart:
				path.pop_front()
			if path.size() > 0:
				agent.path = path
				draw_path(agent.path)
				# if npopped > 1:
				# 	print("popped %d paths" % npopped)
				return true
	return false

func dispatch_new_wolf():
	if farm_openings.size() == 0:
		return
	if num_wolves() >= _cfg.get("max_wolves", 5):
		return	
	for i in range(1000):
		outsides.shuffle()
		var p = outsides[0]
		var c = bcell(p)
		if c.is_fillable():
			var agent = add_agent_at(p, rng.randi_range(0,3), 1)
			agent.trying_to_enter = true
			return

func find_path_to_free_sheep(agent):
	var p = agent.board_pos
	var target = find_closest_free_sheep(p)
	if target.x >= 0:
		var pstart = p
		var pend = target
		var path = game.astar(pstart, pend, Callable(self, "calc_cost_to_move_wolf_to"), agent.agent_id, pstart)
		while path.size() > 0 and path[0] == pstart:
			path.pop_front()
		if path.size() > 0:
			agent.path = path
			draw_path(agent.path)
			return true
	return false

func dist_to_player(p):
	return (p - player.board_pos).length()

func calc_cost_to_move_wolf_to(prev_pos: Vector2i, from: Vector2i, to:Vector2i, _id: int, goal: Vector2i):
	var isgoal = to == goal
	if !game.in_board(to, board_margin-1) and not isgoal:
		return -1

	var tocell = bcell(to)
	if !tocell.ispipe and not isgoal:
		return -1
	if tocell.has_agent and (tocell.agent == player or tocell.agent.agent_type == 1):
		return -1
	if tocell.ispipe and tocell.pipe.has_brick >= 0:
		return -1
	
	if is_wall_between(from,to):
		return -1

	var fromcell = bcell(from)
	if fromcell.is_outside and !tocell.is_outside and !isgoal:
		return -1
	
	if !fromcell.is_outside and dist_to_player(to) < 3:
		return 10
	
	var dir_prev = from - prev_pos
	var dir = to - from	
	if dir != dir_prev:
		return 20
	return 1

func remove_one_compund_fence(room) -> bool:
	for i in range(1000):
		var wall = game.rng.randi_range(0,3)
		if wall == 0:
			var x = room.position.x
			var y = game.rng.randi_range(room.position.y, room.end.y-1)
			if board[y][x].pipe.fences[2]:
				board[y][x].pipe.fences[2] = false
				show_hide_walls()
				return true
		if wall == 2:
			var x = room.end.x-1
			var y = game.rng.randi_range(room.position.y, room.end.y-1)
			if board[y][x].pipe.fences[0]:
				board[y][x].pipe.fences[0] = false
				show_hide_walls()
				return true
		if wall == 1:
			var y = room.position.y
			var x = game.rng.randi_range(room.position.x, room.end.x-1)
			if board[y][x].pipe.fences[3]:
				board[y][x].pipe.fences[3] = false
				show_hide_walls()
				return true
		if wall == 3:
			var y = room.end.y-1
			var x = game.rng.randi_range(room.position.x, room.end.x-1)
			if board[y][x].pipe.fences[1]:
				board[y][x].pipe.fences[1] = false
				show_hide_walls()
				return true
	return false

var next_farm_wall_to_remove:Array = []

func remove_one_farm_fence() -> bool:
	if next_farm_wall_to_remove.size() == 0:
		next_farm_wall_to_remove = range(4)
		next_farm_wall_to_remove.shuffle()
	for i in range(1000):
		var wall = next_farm_wall_to_remove.pop_front()
		if next_farm_wall_to_remove.size() == 0:
			next_farm_wall_to_remove = range(4)
			next_farm_wall_to_remove.shuffle()
		var v = farm_borders[wall]
		if v.size() > 0:
			v.shuffle()
			var p = v.pop_front()
			var c = bcell(p)
			c.fences[wall] = false
			farm_openings.append(p)
			if wall == 1:
				p.y += 1
			elif wall == 3:
				p.y -= 1 
			elif wall == 0:
				p.x += 1
			elif wall == 2:
				p.x -= 1 
			farm_openings_outside.append(p)
			show_hide_walls()
			return true
	return false	

func add_sheep():
	var n = 0
	var _pct = _cfg.get("pct_sheep", pct_sheep_to_add)
	for r in rooms:
		var n_in_room = 0
		var roomsz = r.get_area()
		var num_sheep = int(roomsz * _pct)
		# num_sheep = 1
		var nloops = num_sheep * 10
		for i in range(nloops):
			var p = MainGlobals.pick_one_cell(r.position.x, r.position.y, r.end.x-1, r.end.y-1,
				func(x,y): return board[y][x].is_fillable() and board[y][x].room_id >= 0)
				# func(x,y): return board[y][x].is_fillable() and board[y][x].room_id >= 0 and dist_from_agents_and_player(Vector2i(x,y)) >= 1)
			if p.x >= 0:
				board[p.y][p.x].has_agent = true
				board[p.y][p.x].agent = add_agent_at(p, rng.randi_range(0,3), 0)
				n_in_room += 1
				if n_in_room >= num_sheep:
					break
		n += n_in_room
	game.lives_left = n
	MainGlobals.global_update_hud()

var next_agent_id := 1
func add_agent_at(p: Vector2i, direction: int, agent_type: int = 1):
	var agent = agent_scene.instantiate()
	agent.direction = direction
	agent.board_pos = p
	if agent_type != 0:
		agent.speed_scale = min(agent_max_speed_scale * rng.randf_range(0.8, 2.0), player.speed_scale - 0.1)
	else:
		agent.speed_scale = min(agent_max_speed_scale * rng.randf_range(0.8, 2.0) * _cfg.get("sheep_speed", 0.2), player.speed_scale - 0.2)
	agent.set_type(agent_type)
	add_child(agent)
	agent.set_id(next_agent_id)
	if agent_type == 1:
		# agent.set_color_idx(next_agent_id)
		agent.set_color(Color("#ffe119"))
	next_agent_id += 1
	# agent.agent_pressed.connect(on_agent_pressed)
	board[p.y][p.x].has_agent = true
	board[p.y][p.x].agent = agent
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

func is_wall_between(p, q, also_check_brick:bool = true):
	var to = bcell(q)
	var from = bcell(p)

	if !to.ispipe || !from.ispipe:
		return true

	if also_check_brick and (to.pipe.has_brick >= 0 || from.pipe.has_brick >= 0):
		return true

	var qfences = to.pipe.fences
	var pfences = from.pipe.fences

	return (q.x < p.x and (qfences[0] || pfences[2])) or (q.x > p.x and (qfences[2] || pfences[0])) or \
		(q.y < p.y and (qfences[1] || pfences[3])) or (q.y > p.y and (qfences[3] || pfences[1]))

func cell_has_partial_agent(p: Vector2i, agent_to_ignore):
	var c = bcell(p)
	if c.has_agent:
		return true
	var topx = game.board_to_px(p)
	var th = game.tile_size * game.tile_size / 4.0
	for a in agents:
		if a != agent_to_ignore and (topx - a.position).length_squared() < th:
			return true
	return false

func can_player_go_to(p):
	if !game.in_board(p, board_margin):
		return false
	if (player.board_pos - p).length_squared() > 1.1:
		return false
	var cell = bcell(p)
	return cell.is_field && cell.room_id < 0 && !is_wall_between(player.board_pos, p) && !cell_has_partial_agent(p, player)

func can_agent_go_to(agent,q):
	var mar = max(0, board_margin - 2)
	if !game.in_board(q, mar):
		return false
	if (agent.board_pos - q).length_squared() > 1.1:
		return false
	var to = bcell(q)
	if !to.ispipe || to.pipe.has_brick >= 0:
		return false
	if cell_has_partial_agent(q,agent) or is_wall_between(agent.board_pos,q):
		return false
	if agent.agent_type == 1 and to.room_id >= 0:
		return false

	return true

func all_agents_done():
	if agents.size() == 0:
		return false
	for agent in agents:
		if !agent.arrived:
			return false
	return true
	
func move_player_on_tick(force: bool):
	if player == null:
		return

	for agent in agents:
		var c = bcell(agent.board_pos)
		if (player.position - agent.position).length() < game.tile_size * _dist_to_scare and !agent.scared:
			if (agent.agent_type == 1 and !c.is_outside) or (agent.agent_type == 0 and c.room_id < 0):
				game.play_sound("sheep" if agent.agent_type == 0 else "bark")
				player.bark_towards(agent.position)
				agent.mark_scared()
				if agent.agent_type == 1:
					agent.to_sheep = false
					agent.trying_to_enter = false
				agent.path.clear()

	var p = player.board_pos
	if player.path.size() > 0:
		if player.is_moving and !player.need_to_major_tick():
			return
		var q = player.path[0]
		if !can_player_go_to(q):
			return
			# player.path.clear()
		else:
			q = player.path.pop_front()
			player.need_to_move = true
			player.need_to_stop = player.path.size() == 0
			player.is_moving = true
			player.last_major_tick_ms = 0
			var vdir = q - p
			var dir = game.dt_to_dir(vdir)
			player.direction = dir
			var new_player_pos = game.board_to_px(q)
			var actual_tick_time = player.set_target_pos(new_player_pos)
			next_player_dir = dir
			player.last_major_tick_ms = MainGlobals.timems() + actual_tick_time - game.major_tick_time_ms * game.time_scale
			player.board_pos = q
			board[q.y][q.x].agent = player
			board[q.y][q.x].has_agent = true
			board[p.y][p.x].has_agent = false
			return

	if !player.is_moving || (!player.reached_target_pos and !force) || !player.need_to_major_tick():
		return

	player.set_major_tick_now()

	# if player.need_to_stop:
	# 	player.need_to_stop = false
	# 	player.is_moving = false

	if player.arrived or player.was_hit:
		return	

	if player.need_to_stop and !player.need_to_move:
		return

	if game.in_board(p):
		player.need_to_move = false
		var used_next_dir = next_player_dir >= 0
		var dir = next_player_dir if next_player_dir >= 0 else player.direction
		var vdir = DirArray[dir]
		var q = p + vdir
		if !can_player_go_to(q):
			player.need_to_stop = true
			return
		player.direction = dir
		var new_player_pos = game.board_to_px(q)
		var actual_tick_time = player.set_target_pos(new_player_pos)
		if used_next_dir:
			next_player_dir = -1
		player.last_major_tick_ms = MainGlobals.timems() + actual_tick_time - game.major_tick_time_ms * game.time_scale
		player.board_pos = q
		mark_visited_room(board[q.y][q.x].room_id)
		board[q.y][q.x].agent = player
		board[q.y][q.x].has_agent = true
		board[p.y][p.x].has_agent = false

# var last_major_tick_ms = -10000.0
func tick(force: bool = false):
	if game.level_is_done or !game.level_is_ready:
		return
	
	move_player_on_tick(force)

	var removed_agents = []
	for iagent in agents.size():
		var agent = agents[iagent]
		if agent.can_set_target_pos():
			var acell = bcell(agent.board_pos)
			if agent.scared and (agent.agent_type == 0 and acell.room_id >= 0 or agent.agent_type == 1 and acell.is_outside):
				agent.mark_scared(false)
				game.add_score_and_time(10,0)
				if agent.agent_type == 1:
					agent.trying_to_enter = true
					find_path_to_closest_opening(agent, true, true)
			if agent.agent_type == 1 and agent.trying_to_enter and !acell.is_outside:
				agent.trying_to_enter = false
				agent.to_sheep = true
				agent.path.clear()

			if !game.level_is_done and check_if_sheep_is_lost(agent):
				removed_agents.append(agent)
				continue
			if agent.was_removed:
				continue
			var p = agent.board_pos
			if game.in_board(p):
				var dir = agent.direction
				var vdir = DirArray[dir]
				var q = p + vdir

				if agent.agent_type == 1:
					check_if_near_sheep(agent)
					if agent.path.size() > 0:
						q = agent.path.pop_front()
						if !can_agent_go_to(agent,q):
							agent.path.clear()
							continue
						vdir = q - p
						dir = game.dt_to_dir(vdir)
					else:
						if !agent.scared and !agent.trying_to_enter and !agent.to_sheep:
							var cell = bcell(p)
							if cell.is_outside:
								agent.trying_to_enter = true
								print("wolf had no mode. set to trying_to_enter")
							else:
								agent.to_sheep = true
								print("wolf had no mode. set to to_sheep")

						if agent.scared:
							if !find_path_to_closest_opening(agent, false, false):
								continue
						elif agent.trying_to_enter:
							if !find_path_to_closest_opening(agent, true, false):
								continue
						elif agent.to_sheep:
							if !find_path_to_free_sheep(agent):
								continue
						else:
							continue

						q = agent.path.pop_front()
						vdir = q - p
						dir = game.dt_to_dir(vdir)
						if !can_agent_go_to(agent,q):
							agent.path.clear()
							continue

				elif agent.agent_type == 0:
					if agent.path.size() > 0:
						q = agent.path.pop_front()
						if !can_agent_go_to(agent,q):
							agent.path.clear()
							continue
						vdir = q - p
						dir = game.dt_to_dir(vdir)
					elif agent.scared:
						var pstart = p
						var pend = rooms[0].get_center()
						var pprev = p - vdir
						var path = game.astar(pstart, pend, Callable(self, "calc_cost_to_move_sheep_to"), 0, pprev)#, path_bounding_rect)
						while path.size() > 0 and path[0] == pstart:
							path.pop_front()
						if path.size() > 0:
							agent.path = path
							q = agent.path.pop_front()
							vdir = q - p
							dir = game.dt_to_dir(vdir)
							draw_path(agent.path)
						else:
							continue
						vdir = q - p
						dir = game.dt_to_dir(vdir)
						if !can_agent_go_to(agent,q):
							agent.path.clear()
							continue					

				if !can_agent_go_to(agent,q):
					var turn_dirs = [1,3,2]
					for diradd in turn_dirs:
						var nextdir = (agent.direction + diradd) % 4
						var nextvdir = DirArray[nextdir]
						q = p + nextvdir
						if can_agent_go_to(agent,q):
							dir = nextdir
							break
				agent.direction = dir
				if can_agent_go_to(agent, q):
					# var new_agent_pos = game.board_to_px(q)
					agent.board_pos = q
					board[q.y][q.x].agent = agent
					board[q.y][q.x].has_agent = true
					board[p.y][p.x].has_agent = false

	for agent in removed_agents:
		if !game.level_is_done:
			agent.mark_removed()
			game.add_score_and_time(-1,0)
		
func check_if_near_sheep(wolf):
	if !wolf.to_sheep or wolf.eating:
		return null
	var p = wolf.board_pos
	for agent in agents:
		if agent.agent_type == 0 and !game.level_is_done:
			if bcell(agent.board_pos).room_id < 0 and (p - agent.board_pos).length_squared() < 1.1 and !is_wall_between(p, agent.board_pos) and !agent.eaten:
				wolf.mark_eating(game.board_to_px(agent.board_pos))
				game.play_sound("sheep")
				agent.mark_eaten(game.board_to_px(p))
				game.add_score_and_time(-5,0)
				wolf.path.clear()
				return agent
	return null

var allow_show_path = false
func draw_path(path):
	if !allow_show_path:
		return
	for p in path:
		if board[p.y][p.x].ispipe:
			board[p.y][p.x].pipe.show_path(1000)

func calc_cost_to_move_sheep_to(prev_pos: Vector2i, from: Vector2i, to:Vector2i, _id: int, goal: Vector2i):
	var isgoal = to == goal
	if !game.in_board(to, board_margin) and not isgoal:
		return -1

	var tocell = bcell(to)
	if !tocell.ispipe and not isgoal:
		return -1
	if tocell.has_agent:
		if tocell.agent == player || tocell.agent.agent_type == 1:
			return -1
		if tocell.agent.agent_type == 0 and tocell.agent.scared and tocell.agent.path.size() == 0:
			return -1
	if tocell.ispipe and tocell.pipe.has_brick >= 0 and tocell.room_id < 0:
		return -1
	
	if is_wall_between(from,to, tocell.room_id < 0):
		return -1
	
	var dir_prev = from - prev_pos
	var dir = to - from	
	if dir != dir_prev:
		return 20
	return 1

func get_num_sheep_left():
	var n = 0
	for agent in agents:
		if agent.agent_type == 0 and !agent.was_removed:
			n += 1
	return n

func check_if_no_sheep_left():
	var n = get_num_sheep_left()
	game.lives_left = n
	MainGlobals.global_update_hud()
			
	if n == 0:
		level_is_done(false)

# return true if sheep is lost
func check_if_sheep_is_lost(agent):
	if agent.agent_type != 0 || agent.was_removed:
		return false
	var c = bcell(agent.board_pos)
	var is_lost: bool = c == null or (!c.is_field and c.room_id < 0)
	return is_lost

func _on_level_done_popup_closed():
	sig_level_is_done.emit(true)

func _on_game_popup_closed():
	sig_level_is_done.emit(last_level_was_a_win)

func level_is_done(didwin: bool):
	last_level_was_a_win = didwin
	game.level_is_done = true
	game.stop_sound("ambient")
	game.stop_sound("feet")
	BE.send_event("level_done", "Wolves", {
		"level": level,
		"didwin": int(didwin),
	})
	if didwin:
		# var time_from_start_s = (MainGlobals.timems() - time_started_level_ms) / 1000
		game.add_score_and_time(50, 0)
		game.need_to_increase_level = true
		MainGlobals.global_level_is_done(true)
		var text: String = "You have\ncompleted\nlevel %d\nwith %d sheep\n\nTotal score: %d" % [level, get_num_sheep_left(), game.score]
		game.show_level_done_popup(self, "", text)
		return
	else:
		game.show_game_popup(self, "Oh no!", "Level %d\n\nnot completed" % [level])
		return

func need_to_increase_level() -> bool:
	return true

func _advance_if_needed() -> void:
	if game == null:
		return
	if game.need_to_increase_level:
		var n_levels: int = WolvesLevelConfig.LEVELS.size()
		level = min(level + 1, n_levels)
		game.add_life()
	_apply_level()

func _apply_level() -> void:
	if game == null:
		return
	var n_levels: int = WolvesLevelConfig.LEVELS.size()
	var clamped_level: int = min(level, n_levels)
	var s: int = 25
	num_rooms = min(MAX_POSSIBLE_ROOMS, MAX_COLORS_TO_USE, clamped_level)
	game.forced_board_size = Vector2i(s, s)
	num_more_packets = 0
	player_max_speed_scale = 1.7
	agent_max_speed_scale = min(0.4 + 0.2 * (clamped_level - 1), 2)
	num_bricks_per_room = 2
	num_bricks_in_farm = 4
	game.init_sizes()

# start from zoom out and stay at zoom out

func add_player_at(p: Vector2i, direction: int):
	if player != null:
		player.queue_free()
		# player_cam = null
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
	board[p.y][p.x].agent = player
	# agent.hit.connect(on_agent_hit)
	player.set_pos(game.board_to_px(p), direction)
	mark_visited_room(board[p.y][p.x].room_id)

	var color = Color(0.1,0.5,0.99) #game.next_color()
	player.set_color(color)

func mark_visited_room(room_id):
	visited_rooms[room_id] = true

func add_player():
	var p = game.get_board_center()
	p.y = board_margin
	add_player_at(p, 1)

func on_agent_remove_agent(agent_id, _good_remove: bool):
	for i in agents.size():
		if agents[i].agent_id == agent_id and !game.level_is_done:
			var p = agents[i].board_pos
			bcell(p).has_agent = false
			bcell(p).agent = null
			agents[i].queue_free()
			agents.remove_at(i)
			break
	check_if_no_sheep_left()

func on_time_over():
	level_is_done(true)

func on_lives_depleted():
	pass

var popup:PopupPanel = null

func _unhandled_input(event: InputEvent) -> void:
	if popup == null or not is_instance_valid(popup) or not popup.visible:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()

func _load_cfg() -> void:
	var n_levels: int = WolvesLevelConfig.LEVELS.size()
	var clamped_level: int = min(level, n_levels)
	_cfg = WolvesLevelConfig.LEVELS[clamped_level - 1]
	_dist_to_scare = _cfg.get("dist_to_scare", 3)
	var _level_time = _cfg.get("level_time", 300)
	game.set_reset_time_left(_level_time)
	game.reset_time_left()

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
	if tocell.is_outside or tocell.room_id >= 0:
		return -1
	
	var dir_prev = from - prev_pos
	var dir = to - from	
	if dir != dir_prev:
		return 20
	return 1
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
# A ROUND IS LOST WHEN A ROOM IS RUINED, and won by getting through the storm without that. A room
# is ruined when the level's room_ruin of its floor is covered -- each tile counting as covered once it holds
# FILM of water, and in part below that, the same measure the water is drawn by -- and with several
# rooms, one ruined room loses the round. _check_floods() runs every major tick.
#
# It replaced two rules. "More than 30% of the room tiles overflowed" stopped firing once water
# leveled out instead of piling up, because a tile now rarely fills to the brim. And the "rain
# caught" bar -- a share of leaked water that had to be kept off the floor -- existed only so that
# an empty house would lose; it does now anyway, by flooding a room, and one rule is easier to say
# and to show. The share is still worked out (rain_stats) and shown on the round card.
var _ruined_room: int = -1
var _fill_rate: float = 1.0
# Each room's covered share as of the last check, indexed like `rooms` -- read by main.gd's HUD line.
var room_shares: Array = []
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

var explosion_audio := preload("res://art/sounds/car-crash-1.mp3")
# var motor_audio := preload("res://art/sounds/car-ambient-driving.ogg")
var feet_audio := preload("res://art/sounds/kenney/Audio/footstep_grass_001.ogg")
var delivered_audio := preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var start_audio := preload("res://art/sounds/click-2.mp3")
var tap_audio := preload("res://art/sounds/tap-1.mp3")
var swoosh_audio := preload("res://art/sounds/swoosh.mp3")
var dispatch_audio := preload("res://art/sounds/kenney/Audio/impactBell_heavy_003.ogg")
var gaveup_audio := preload("res://art/sounds/bump-sound-7.mp3")
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
	game.sig_card_shown.connect(close_inventory)
	MainGlobals.sig_need_to_close_info_popups.connect(close_inventory)
	visibility_changed.connect(func() -> void:
		if not visible:
			close_inventory())
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

	MainGlobals.sig_path_drawn.connect(_on_path_drawn)  
	_fit_ground_to_board()
	
func reset():
	close_inventory()
	# Every one of these is a baseline in game_time, and game_time RESTARTS at zero on each round
	# (main.gd -> game.reset() -> _game_start_ms = now). Carried over from the round before, they
	# sit far in the future: "now - last_time_added_leak" stays negative for the whole round, so
	# no leak, blackout or water drop ever fires again. That is the "no new leaks after the first
	# round" bug.
	last_time_added_leak = 0.0
	next_duration_for_leak_ms = 1000.0
	last_time_showed_blackout = 0.0
	next_blackout_duration_s = 10.0
	last_time_played_water_drop = 0.0
	next_water_drop_duration_s = 5.0
	last_major_tick_ms = -10000.0

	round_items_lost = 0
	_ruined_room = -1
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

# THE BRIEFING GOES UP AT ONCE, HELD, WHILE THE BOARD IS BUILT BEHIND IT. It shows only "Building
# world" and no Start button (game_popup.hold()), laid out at its final size with the real text hidden
# underneath, so nothing moves when the text comes in. When the board is ready -- and at least
# BRIEF_HOLD_MS after the card went up, so the hold never flickers past as a glitch -- the real text,
# with the rooms the board actually got, and the Start button appear (_release_brief()).
#
# Before this, a yellow "Building level" notice flashed up on its own while the board was made, and
# then the card said how many rooms there were from the plan and corrected itself once the board
# existed, since create_rooms() can place fewer than planned.
const BRIEF_HOLD_MS: int = 1000
var _board_ready: bool = false
var _brief = null
var _brief_shown_ms: int = 0

func _brief_text(n_rooms: int) -> String:
	var roomsstr: String = "one room" if n_rooms == 1 else "%d rooms" % n_rooms
	return "You have %s to protect.\n\nStorm lasts: %s" % [roomsstr,
		MainGlobals.round_duration_str(storm_duration_s)]

func new_game(from_scratch=true):
	while _building:
		await get_tree().process_frame
	game.pause(true)
	reset()
	_board_ready = false
	if from_scratch:
		level = StormG.starting_level
		round_in_level = 0
		game.time_scale = 0.5

	_advance_if_needed()
	game.need_to_increase_level = false
	if not game.tutorial_mode:
		# Each card is followed through ITS OWN `closed` signal. The app-wide "a card closed" signal
		# cannot tell this briefing from the round card, or either from a card left over from before.
		# Laid out with the planned count: the same lines as the real text, so the card is already
		# its final size, and hidden until released.
		var brief = game.show_game_popup(self, "Level %d" % level, _brief_text(num_rooms))
		brief.hold("Building world")
		brief.closed.connect(_on_closed_intro_popup)
		_brief = brief
		_brief_shown_ms = Time.get_ticks_msec()
	# Let the card draw before the board is built behind it.
	await get_tree().process_frame
	await get_tree().process_frame
	create_board()
	time_started_level_ms = game.game_time
	started_playing.emit()
	BE.upsert_game_state("Storm",
		{"state":"new","level": level, "round_in_level": round_in_level})

func _input(event) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if event.is_action_pressed("new_board"):
		# Not during a tutorial: there N restarts the lesson (main.gd), and docking a point for it
		# would be penalising the coach's own board.
		if not game.tutorial_mode:
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
	
# The color under a board cell, for the drawn-path overlay. The floor of a room is painted
# `color_by_index(room_id).lightened(0.5)` in pipe.gd, so the path is told the same thing and
# picks black or white against it -- a fixed orange line vanished over the warmer rooms.
func path_color_at(bp: Vector2i) -> Color:
	if bp.x < 0 or bp.y < 0 or bp.y >= board.size() or bp.x >= board[bp.y].size():
		return Color(1, 1, 1)
	var rid: int = board[bp.y][bp.x].room_id
	if rid < 0:
		return Color(1, 1, 1)
	return game.color_by_index(rid).lightened(0.5)

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
	pipe.water_rate_factor = pipe.BASE_WATER_RATE * _fill_rate
	board[p.y][p.x].room_id = room_id
	add_child(pipe)
	pipes.append(pipe)
	pipe.pipe_pressed.connect(_on_pipe_pressed)

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
	# The board is built across several frames now (see _breathe), and taps are taken in between.
	if not _board_ready:
		return
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
		await _breathe()
		e.show_hide_walls(board)
	
var room_min_size = 9
var room_max_size = 12
var board_margin = 5

#region create_rooms

func _carve_room(pos: Vector2i, sz: Vector2i, room_id:int) -> void:
	for y in range(pos.y, pos.y + sz.y):
		for x in range(pos.x, pos.x + sz.x):
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
			await _breathe()
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
	await add_corridors()

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
			await _breathe()
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

						await _breathe()
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


# THE BOARD IS BUILT IN SLICES. Building it in one go froze the game: the briefing card could not
# take the Start press until the build was done -- about 0.13 s on level 1 and 2.2 s on level 12 on a
# desktop (mostly placing the rooms and finding their corridors), longer on a slower machine. Every
# loop of the build now calls _breathe(), which hands the frame back once BUILD_SLICE_US of work has
# gone by, so input is taken between slices.
const BUILD_SLICE_US: int = 8000
var _slice_start: int = 0
# A build in progress. A new round waits for it (new_game): two builds interleaving across frames
# would share one board.
var _building: bool = false

func _breathe() -> void:
	if Time.get_ticks_usec() - _slice_start > BUILD_SLICE_US:
		await get_tree().process_frame
		_slice_start = Time.get_ticks_usec()

func create_board() -> void:
	_building = true
	_slice_start = Time.get_ticks_usec()
	_fit_ground_to_board()
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

	await create_rooms(num_rooms, board_margin)
	# for row in range(board_margin,game.board_size.y-board_margin):
	# 	for col in range(board_margin,game.board_size.x-board_margin):
	# 		add_pipe(Vector2i(col,row))
	
	for row in game.board_size.y:
		await _breathe()
		for col in game.board_size.x:
			if !board[row][col].ispipe:
				add_empty(Vector2i(col,row))
				
	await show_hide_walls()
				
	for pipe in pipes:
		await _breathe()
		pipe.set_rot(board)

	add_player()
	zoom_camera(true)

	add_bricks()
	add_drains()
	add_furniture()
	_add_flood_layer()
	room_shares = []

	# zoom_camera(false)
	_building = false
	_board_ready = true
	if game.tutorial_mode:
		# The tutorial teaches all of this by doing it: no briefing, straight in.
		_on_closed_intro_popup()
	else:
		_release_brief()

	game.play_sound("rain")
	started_sounds = true

# The real briefing and its Start button, once the board is built and the card has been up at least
# BRIEF_HOLD_MS. The room count is the board's own, not the plan's.
func _release_brief() -> void:
	var brief = _brief
	# Checked against the clock each frame: a timer is only looked at once a frame and let the hold
	# end a few milliseconds short.
	while Time.get_ticks_msec() - _brief_shown_ms < BRIEF_HOLD_MS:
		await get_tree().process_frame
	if brief == null or not is_instance_valid(brief) or brief != _brief:
		return      # a newer round has replaced this card
	brief.release(_brief_text(rooms.size()))

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

# furniture_per_room pieces in every room (StormLevelConfig). The kinds are dealt in a shuffled
# order, going round them again when a room wants more than there are kinds.
func add_furniture():
	var per_room: int = int(_cfg.get("furniture_per_room", 1))
	var kinds: Array = furniture.keys()
	kinds.shuffle()
	var next_kind: int = 0
	for r in rooms:
		for _i in per_room:
			var f = furniture[kinds[next_kind % kinds.size()]]
			next_kind += 1
			var p = MainGlobals.pick_one_cell(r.position.x, r.position.y, r.end.x-1, r.end.y-1,
				func(x,y): return board[y][x].is_fillable())
			if p.x >= 0:
				board[p.y][p.x].pipe.set_furniture(f[0], f[1], f[2])

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

# A route the player could ACTUALLY walk, in screen coordinates, for the tutorial's drag demo.
# Asks the game's own pathfinder rather than inventing a shape, so the demonstrated route respects
# walls and furniture instead of pointing straight through them.
func tutorial_demo_route() -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if player == null or not is_instance_valid(player):
		return out
	var start: Vector2i = player.board_pos
	var best: Array = []
	for radius in [4, 3, 5, 2]:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if absi(dx) + absi(dy) != radius or dx == 0 or dy == 0:
					continue
				var q: Vector2i = start + Vector2i(dx, dy)
				if not can_go_to(q):
					continue
				var path: Array = game.astar(start, q,
					Callable(self, "calc_cost_to_move_player_to"), 0, start)
				if path.size() >= 3:
					best = path
					break
			if not best.is_empty():
				break
		if not best.is_empty():
			break
	if best.is_empty():
		return out
	var to_screen: Transform2D = player.get_global_transform_with_canvas() \
		* player.get_global_transform().affine_inverse()
	for cell in best:
		out.append(to_screen * game.board_to_px(cell))
	return _smoothed_demo(out)

# Round the grid corners off so the trail curves the way a finger does.
func _smoothed_demo(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out: PackedVector2Array = PackedVector2Array()
	out.append(pts[0])
	for i in range(1, pts.size() - 1):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var c: Vector2 = pts[i + 1]
		out.append(a.lerp(b, 0.75))
		out.append(b.lerp(c, 0.25))
	out.append(pts[pts.size() - 1])
	return out

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
		var dark: Array = _cfg.get("blackout_every_sec", [10, 20])
		next_blackout_duration_s = rng.randf_range(float(dark[0]), float(dark[1]))

	if !game.level_is_ready:
		return

	var now = game.game_time
	if now - last_time_added_leak > next_duration_for_leak_ms:
		add_leak()
		last_time_added_leak = now
	if now - last_major_tick_ms > game.major_tick_time_ms * game.time_scale:
		last_major_tick_ms = now
		_check_floods()

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
	# Leaks appearing and leaks overflowing are the two events worth counting: the share that
	# overflowed says how well the player kept up, in a way the score cannot.
	game.record_count("leaks_appeared")
	var every: Array = _cfg.get("leak_every_ms", [2000, 4000])
	next_duration_for_leak_ms = game.rng.randf_range(float(every[0]), float(every[1]))
	for i in range(100):
		var room_id = game.rng.randi_range(0, rooms.size()-1)
		var r = rooms[room_id]
		var p = MainGlobals.pick_one_cell(r.position.x, r.position.y, r.end.x-1, r.end.y-1, func(x,y): return board[y][x].is_fillable())

		if p.x >= 0:
			var cell = board[p.y][p.x]
			cell.pipe.start_leak()
			game.play_sound("swoosh")
			game.tutorial_notify("leak_started")
			return

# ONLY OUR OWN CARD MOVES THE GAME ON. The game used to listen to the app-wide "a card closed"
# signals, which fire for EVERY card -- so with two cards up (see level_is_done's guard), closing
# the top one started the next round and its "Level N" briefing opened over the card still showing.
# Each card is now followed through its own `closed` signal.
func _on_round_card_closed() -> void:
	sig_level_is_done.emit(last_level_was_a_win)

# A ROUND ENDS ONCE. Nothing used to stop a second call, and there were several ways to make one:
# the HUD re-sends sig_time_over on every score change once the clock is at zero, and a WON round
# frees the board and waits a frame before its card goes up -- a countdown tick in that frame ended
# the round again and put up a second card.
func level_is_done(didwin: bool):
	if game.level_is_done:
		return
	close_inventory()
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
	# One fact per line: the card sets them as a table, so the "  |  " and double-space packing
	# that squeezed five numbers onto two lines is no longer buying anything.
	var rain: Dictionary = rain_stats()
	var stats_str: String = "\n\nRain caught: %d%%\nWorst room: %d%% flooded\nScore: %d\nTime: %d s\nSaved: %d\nRuined: %d" % [
		int(round(float(rain["caught"]) * 100.0)), int(round(float(stats["worst"]) * 100.0)),
		game.score, int(time_from_start_s), stats["saved"], round_items_lost]
	if didwin:
		var score_add: int = min(5, 60 - time_from_start_s)
		var time_add: int = min(10, 60 - time_from_start_s)
		game.add_score_and_time(score_add, time_add)
		game.need_to_increase_level = true
		if need_to_increase_level():
			MainGlobals.global_level_is_done(true)
			var done_card = game.show_level_done_popup(self, "", "", level)
			done_card.closed.connect(_on_round_card_closed)
		else:
			var cur_round: int = round_in_level + 1
			reset()
			await get_tree().process_frame
			var won_card = game.show_game_popup(self, "Well done!", "Round %d of Level %d\ncompleted%s" % [cur_round, level, stats_str])
			won_card.closed.connect(_on_round_card_closed)
	else:
		var cur_round: int = round_in_level + 1
		var why: String = "A room flooded!" if _ruined_room >= 0 else "House flooded!"
		var lost_card = game.show_game_popup(self, "Oh no!", "%s\nRound %d of Level %d%s" % [why, cur_round, level, stats_str])
		lost_card.closed.connect(_on_round_card_closed)

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

# Each tool's capacity, in tile-fulls; how MANY of each is a level setting (StormLevelConfig "tools").
# Tape holds nothing: it stops the leak. Also the order the tools are dealt and numbered in.
const TOOL_CAPACITY: Array = [["bucket", 1.0], ["rag", 1.0], ["fix", 0.0], ["cup", 0.55], ["plate", 9.0 / 40.0]]
# This level's row of StormLevelConfig -- every difficulty setting comes from here.
var _cfg: Dictionary = {}

func _apply_level() -> void:
	if game == null:
		return
	_cfg = StormLevelConfig.get_level(level)
	var board_n: int = int(_cfg["board"])
	game.forced_board_size = Vector2i(board_n, board_n)
	num_rooms = mini(MAX_POSSIBLE_ROOMS, int(_cfg["rooms"]))
	room_min_size = int(_cfg["room_size"][0])
	room_max_size = int(_cfg["room_size"][1])
	rounds_per_level = int(_cfg["rounds"])
	player_max_speed_scale = float(_cfg["player_speed"])
	num_bricks_per_room = int(_cfg["bricks_per_room"])
	storm_duration_s = float(_cfg["storm_sec"])
	game.set_time_left(0, 0, storm_duration_s)
	available_actions = []
	var tools: Dictionary = _cfg["tools"]
	var id: int = 0
	for tc in TOOL_CAPACITY:
		for _n in range(int(tools.get(tc[0], 0))):
			id += 1
			available_actions.append(CAction.new(tc[0], id, 0, tc[1]))
	_fill_rate = float(_cfg["fill_rate"])
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

# The water on the floor, drawn once for the whole board (see flood_layer.gd). Added after every
# tile so that, at the same z as the tiles' floors, it draws over them by tree order.
var _flood: StormFloodLayer = null

func _add_flood_layer() -> void:
	if _flood != null and is_instance_valid(_flood):
		_flood.queue_free()
	_flood = StormFloodLayer.new()
	add_child(_flood)
	var top_left: Vector2 = game.board_to_px(Vector2i.ZERO) - Vector2.ONE * float(game.tile_size) * 0.5
	_flood.setup(self, board, game.board_size, float(game.tile_size), top_left)

# EVERY LEAK MAKES ITS OWN PUDDLE: A CIRCLE THAT KEEPS GROWING. Its area is the water that leak has
# poured onto the floor (pipe.floored_total -- everything it dripped with no tool under it, or with a
# full one) spread PUDDLE_DEPTH deep, so the radius grows as the square root of time: endlessly, and
# slower and slower as the same trickle has more floor to cover. A tool or tape under the leak stops
# its circle growing. Puddles do not interact: where two meet they simply overlap. A puddle stays in
# its own room, and walls, bricks, drains and doors cut it at their tile edges.
#
# This replaced a simulation of water flowing between tiles (spill from full tiles, then leveling,
# then diagonal flow to stop it growing as a "+"). It was built one fix at a time and never did the
# one thing wanted: a leak left alone spread to about a 3x3 block and stopped, because water only
# moved while a tile held more than a film of it.
const PUDDLE_DEPTH: float = 0.3     # a tile-full of water covers 1 / PUDDLE_DEPTH tiles of floor
# A tile's floor counts as covered by how many of four sample points in it lie in its room's puddles.
const _SAMPLES: Array = [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.25, 0.75), Vector2(0.75, 0.75)]
# Furniture is ruined when this much of its tile is under water: a leak can start right on a rug, and
# that must leave time to get a tool under it (about 12 s at level 1's rate).
const FURNITURE_RUIN: float = 0.75
# Water a leak must have put on the floor before it counts as "reached the floor" in the stats.
const PUDDLE_SEEN: float = 0.02

# Every puddle: {center (tiles), r (tiles), room, drip}. The one source for the drawing and the
# rules alike, so what counts is exactly what is shown.
func puddles() -> Array:
	var out: Array = []
	for p in pipes:
		if p == null or not is_instance_valid(p) or not p.water_active or p.floored_total <= 0.0:
			continue
		var bp: Vector2i = p.board_pos
		var r: float = sqrt(p.floored_total / PUDDLE_DEPTH / PI)
		out.append({"center": Vector2(bp) + Vector2(0.5, 0.5) + p.drip_offset(), "r": r,
			"room": int(board[bp.y][bp.x].room_id), "drip": p.is_dripping()})
	return out

# Floor water can lie on: a tile of a room with nothing standing on it -- not a wall, a brick or a
# drain. A DOORWAY IS FLOOR. Its door is drawn hidden, so the tile looks like any other, and leaving it
# out left one dry tile at the mouth of every corridor. Corridors belong to no room, so a room's
# water still never runs out into one.
func _is_floor(cell) -> bool:
	return cell.ispipe and cell.pipe != null and cell.pipe.can_fill()

# How much of one floor tile the puddles in its own room cover, 0..1.
func tile_coverage(x: int, y: int, pds: Array) -> float:
	var cell = board[y][x]
	if not _is_floor(cell):
		return 0.0
	var room: int = int(cell.room_id)
	var hit: int = 0
	for sp: Vector2 in _SAMPLES:
		var pt: Vector2 = Vector2(x, y) + sp
		for pd: Dictionary in pds:
			if int(pd["room"]) == room and pt.distance_to(pd["center"]) < float(pd["r"]):
				hit += 1
				break
	return float(hit) / float(_SAMPLES.size())

func on_time_over():
	# Before the board exists, or once the round is over, "time over" means nothing here.
	if game.level_is_done or not game.level_is_ready:
		return
	# Through the storm without a ruined room: _check_floods() would already have ended it.
	level_is_done(true)

# How much of each room's floor is covered, 0..1, indexed like `rooms`. A tile counts once it
# holds FILM of water, and in part below that -- the same measure the water is drawn by. Walls,
# bricks, drains and doors are not floor and do not count either way.
func room_flood() -> Array:
	var pds: Array = puddles()
	var out: Array = []
	for i in rooms.size():
		var r: Rect2i = rooms[i]
		var covered: float = 0.0
		var n: int = 0
		for row in range(r.position.y, r.end.y):
			for col in range(r.position.x, r.end.x):
				if not _is_floor(board[row][col]):
					continue
				n += 1
				covered += tile_coverage(col, row, pds)
		out.append(covered / float(n) if n > 0 else 0.0)
	return out

# Furniture under water, and rooms past room_ruin(). Run every major tick while the round is live.
func _check_floods() -> void:
	var pds: Array = puddles()
	for p in pipes:
		if p == null or not is_instance_valid(p):
			continue
		# "Water reached the floor" in the stats: once per leak, when its puddle first shows.
		if p.water_active and not p.counted_on_floor and p.floored_total >= PUDDLE_SEEN:
			p.counted_on_floor = true
			game.record_count("overflows")
		if p.furniture_value > 0 and not p.furniture_ruined \
				and tile_coverage(p.board_pos.x, p.board_pos.y, pds) >= FURNITURE_RUIN:
			p.ruin_furniture()
			round_items_lost += 1
			game.record_count("items_ruined")
			game.add_score_and_time(-p.furniture_value, 0)
	var shares: Array = room_flood()
	room_shares = shares
	for i in shares.size():
		if float(shares[i]) >= room_ruin():
			_ruined_room = i
			level_is_done(false)
			return

# The share of a room's floor under water that ruins it, 0..1: this level's `room_ruin`.
func room_ruin() -> float:
	return float(_cfg.get("room_ruin", 0.4))

# The most flooded room's share, 0..1 -- the number that decides the round, shown in the HUD.
func worst_room_share() -> float:
	var worst: float = 0.0
	for sh in room_shares:
		worst = maxf(worst, float(sh))
	return worst

# caught: the share of all leaked water that did not reach the floor (a statistic, on the round
# card; it no longer decides anything).
func rain_stats() -> Dictionary:
	var leaks: Array = []
	var total: float = 0.0
	var floored: float = 0.0
	for p in pipes:
		if p == null or not is_instance_valid(p) or not p.water_active:
			continue
		leaks.append(p)
		total += p.leaked_total
		floored += p.floored_total
	if total <= 1e-9:
		return {"caught": 1.0, "leaks": 0}
	return {"caught": 1.0 - floored / total, "leaks": leaks.size()}

func on_lives_depleted():
	pass

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
		# Tapping out of reach does nothing at all, which is the single most confusing thing in
		# this game. Tell a running tutorial, so it can say why rather than leaving the player
		# tapping a leak that ignores them.
		game.tutorial_notify("tapped_too_far")
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
			var swatch = panel.init(box_w, sep, swatch_color, action.name.to_upper()[0], "", action_texture, action.level,
				action.name, action.level / action.overflow_level if action.overflow_level > 1e-3 else 0.0)
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
					game.tutorial_notify("tool_placed")
		
		sort_available_actions()
		MainGlobals.swipe_was_drag = true
		_close_popup()

func _close_popup():
	MainGlobals.set_popup_open(false)
	popup.hide()
	popup.queue_free()
	popup = null

# THE INVENTORY CLOSES WHENEVER SOMETHING ELSE TAKES OVER. It is a PopupPanel -- a separate window
# drawn above everything -- so nothing that happens around it hides it: it stayed open on top of
# "Oh no!", the level summary and the next round. Closed on any card (game.sig_card_shown), at the end
# of a round, on a new board, when the level is hidden, when help opens, and on the app's
# sig_need_to_close_info_popups. Safe to call with nothing open.
func close_inventory() -> void:
	if popup != null and is_instance_valid(popup):
		_close_popup()
	popup = null

# saved: furniture still dry. worst: the most flooded room's share, 0..1.
func count_round_stats() -> Dictionary:
	var saved: int = 0
	for p in pipes:
		if p != null and is_instance_valid(p) and p.furniture_value > 0 and not p.furniture_ruined:
			saved += 1
	var worst: float = 0.0
	for sh in room_flood():
		worst = maxf(worst, float(sh))
	return {"saved": saved, "worst": worst}

func add_drains():
	var per_room: int = int(_cfg.get("drains_per_room", 1))
	for r in rooms:
		for _i in per_room:
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
		game.tutorial_notify("path_drawn")   # no-op outside tutorial mode

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
	GrassField.fit(get_node_or_null("BgLayer"), get_node_or_null("BgLayer/TextureRect") as CanvasItem, game, 19)

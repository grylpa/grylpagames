extends CanvasLayer

signal started_playing
signal sig_level_is_done(didwin: bool)
signal collision
signal update_score(score: int)

enum Dirs {right = 0, down = 1, left = 2, up = 3}
const DirArray: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var game: GenericGameUtil

class OneCell:
	var ispipe: bool = false
	var has_agent: bool = false
	var has_player: bool = false
	var room_id: int = -1
	var color_idx: int = -1
	var pipe = null

	func is_fillable() -> bool:
		return ispipe and not has_agent and not has_player and pipe != null and pipe.has_brick < 0

var board: Array = []
var pipes: Array = []
var agents: Array = []
var coins: Dictionary = {}
var player = null
var next_player_dir: int = -1
var play_start_sound: bool = true

# Room
var room_rect: Rect2i = Rect2i()

# Peripheral gorillas
var peripheral_gorillas: Array = []
var empty_spaces: Array = []
var num_gorillas_spawned: int = 0
var gorilla_spawn_times: Array[float] = []  # pre-planned spawn times in seconds from level start
var gorilla_spawn_index: int = 0
var level_start_ms: int = 0

const GorillaFigure = preload("res://gorilla/scripts/peripheral_gorilla.gd")   # for its half-extents
# Gorilla body height, in tiles. Kept near one tile: bigger than this and the clearance rule below
# has no band left to place it in once the room grows to 11x11.
const GORILLA_TILES: float = 1.05
# The gorilla's OUTLINE must clear the room floor by this much on every side, so it never walks
# over the board or its wall ring. On an 11x11 room this is an exact fit rather than a comfortable
# one — there are only ~2.5 tiles between the room and the screen edge. See docs/design.md.
const GORILLA_BOARD_GAP_TILES: float = 1.0

const PLAYER_COLOR: Color = Color(0.1, 0.5, 0.99)
# Indices into game.colors that agents may use — excludes blue(3) and white(12)
const AGENT_COLOR_INDICES: Array[int] = [0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11]

# Level params
var rounds_per_level: int = 2
var level: int = 0
var round_in_level: int = 0
var room_size: int = 7
var num_inside_monsters: int = 1
var num_bricks: int = 4
var extra_passages: int = 5
var directed_chance: float = 0.0
var gorilla_speed_px: float = 180.0
var agent_speed_min: float = 0.5
var agent_speed_max: float = 1.2
var powers_in_level: int = 3

# Answering
var in_answering_mode: bool = false
var last_level_was_a_win: bool = false

@export var pipe_scene: PackedScene
@export var agent_scene: PackedScene
@export var player_scene: PackedScene
@export var peripheral_gorilla_scene: PackedScene
@export var empty_space_scene: PackedScene

var explosion_audio: AudioStream = preload("res://art/sounds/car-crash-1.mp3")
var feet_audio: AudioStream = preload("res://art/sounds/kenney/Audio/footstep_grass_001.ogg")
var delivered_audio: AudioStream = preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg")
var start_audio: AudioStream = preload("res://art/sounds/click-2.mp3")
var swoosh_audio := preload("res://art/sounds/swoosh.mp3")
func _ready() -> void:
	game = GorillaG.game
	game.zoomed_in = true
	game.sig_time_over.connect(on_time_over)
	game.sig_lives_depleted.connect(on_lives_depleted)
	level = GorillaG.starting_level
	round_in_level = 0
	_apply_level()

	game.add_sound(self, "explosion", explosion_audio)
	game.add_sound(self, "feet", feet_audio, true)
	game.add_sound(self, "delivery", delivered_audio)
	game.add_sound(self, "start", start_audio)
	game.add_sound(self, "swoosh", swoosh_audio)

	if not MainGlobals.sig_game_popup_closed.is_connected(_on_game_popup_closed):
		MainGlobals.sig_game_popup_closed.connect(_on_game_popup_closed)

func _on_game_popup_closed():
	sig_level_is_done.emit(last_level_was_a_win)

func reset():
	in_answering_mode = false
	next_player_dir = -1
	play_start_sound = true

	if player != null:
		player.queue_free()
		player = null

	for c in agents:
		c.queue_free()
	agents.clear()

	for g in peripheral_gorillas:
		if is_instance_valid(g):
			g.queue_free()
	peripheral_gorillas.clear()

	for e in empty_spaces:
		e.queue_free()
	empty_spaces.clear()

	for c in pipes:
		c.queue_free()
	pipes.clear()

	board.clear()
	coins.clear()
	num_gorillas_spawned = 0
	gorilla_spawn_times.clear()
	gorilla_spawn_index = 0

func new_game(from_scratch: bool = true):
	reset()
	$BuildingLabel.show()
	$UILayer/AnswerOverlay.hide()
	await get_tree().process_frame
	if from_scratch:
		level = GorillaG.starting_level
		round_in_level = 0
	_advance_if_needed()
	game.need_to_increase_level = false
	in_answering_mode = false

	if game.tutorial_mode:
		num_inside_monsters = 0      # nothing may kill the player mid-lesson
	create_board()
	_plan_gorilla_spawns()
	if game.tutorial_mode:
		_tutorial_setup()
	started_playing.emit()

# Put one monster on the board, far from the player, purely so the tutorial can point at it. The
# tutorial otherwise runs with num_inside_monsters = 0 — being killed halfway through a lesson
# teaches nothing — but a player who is never shown a monster meets their first one unprepared,
# which is exactly the complaint the tutorials exist to fix. Called on the LAST teaching step, so
# it is seen and named but never gets a chance to reach anyone.
func tutorial_show_a_monster() -> bool:
	if not agents.is_empty():
		return true
	return _spawn_agent(0, true)

# Slide the live gorilla to the center of its own lane. A gorilla spawns fully OFF screen and the
# coach's freeze stops it wherever it happens to be — which, at the moment it is first reported, is
# still outside the visible area. Without this the tutorial talks about a gorilla the player never
# actually sees, then unfreezes and lets it run off while they are still reading.
func tutorial_hold_gorilla_midscreen() -> void:
	for g in peripheral_gorillas:
		if not is_instance_valid(g):
			continue
		var sr: Rect2 = g.screen_rect
		if absf(g.velocity.x) >= absf(g.velocity.y):
			g.position.x = sr.position.x + sr.size.x * 0.5
		else:
			g.position.y = sr.position.y + sr.size.y * 0.5
		return

# No automatic gorillas during a tutorial. On the timed schedule one ran past while the coach was
# still talking about coins — wasted, and confusing when the lesson about them arrived later and a
# DIFFERENT gorilla was suddenly held up. The tutorial asks for one exactly when it wants it.
func _tutorial_setup() -> void:
	gorilla_spawn_times = []
	gorilla_spawn_index = 0
	level_start_ms = MainGlobals.timems()

# Called by the tutorial step that is about to talk about gorillas.
func tutorial_spawn_gorilla() -> void:
	if not peripheral_gorillas.is_empty():
		return
	_spawn_peripheral_gorilla(true)

func create_board():
	time_to_spawn_agent = 0
	for r in game.board_size.y:
		var row = []
		for c in game.board_size.x:
			row.append(OneCell.new())
		board.append(row)

	var center = game.board_size / 2
	var half = room_size / 2
	var room_pos = Vector2i(center.x - half, center.y - half)
	room_rect = Rect2i(room_pos, Vector2i(room_size, room_size))

	var room_color_idx: int = AGENT_COLOR_INDICES[rng.randi_range(0, AGENT_COLOR_INDICES.size() - 1)]

	# game.tile_size = 38
	for ry in range(room_rect.position.y, room_rect.end.y):
		for rx in range(room_rect.position.x, room_rect.end.x):
			var p = Vector2i(rx, ry)
			board[ry][rx].ispipe = true
			board[ry][rx].room_id = room_color_idx
			var pipe = pipe_scene.instantiate()
			board[ry][rx].pipe = pipe
			pipe.board_pos = p
			pipe.position = game.board_to_px(p)
			add_child(pipe)
			pipes.append(pipe)

	for pipe in pipes:			
		pipe.set_rot(board)

	var player_pos = Vector2i(room_rect.position.x + room_size / 2, room_rect.position.y + room_size / 2)
	_create_player(player_pos)
	_reapply_level_after_player_created()

	# _add_bricks()

	_fill_coins()
	_create_maze()
	for i in num_inside_monsters:
		_spawn_agent(i)

	_create_empty_spaces()

	$BuildingLabel.hide()
	create_camera()
	game.level_is_ready = true

	# for x in game.board_size.x:
	# 	bcell(Vector2i(x,0)).pipe.modulate=Color(1,0,0,1)
	# 	bcell(Vector2i(x,1)).pipe.modulate=Color(1,1,0,1)
	# 	bcell(Vector2i(x,2)).pipe.modulate=Color(0,0,1,1)
	# 	bcell(Vector2i(x,game.board_size.y-1)).pipe.modulate=Color(1,0,0,1)
	# 	bcell(Vector2i(x,game.board_size.y-2)).pipe.modulate=Color(1,1,0,1)
	# 	bcell(Vector2i(x,game.board_size.y-3)).pipe.modulate=Color(0,0,1,1)

func _create_empty_spaces():
	var x0: int = max(0, room_rect.position.x - 1)
	var y0: int = max(0, room_rect.position.y - 1)
	var x1: int = min(game.board_size.x - 1, room_rect.end.x)
	var y1: int = min(game.board_size.y - 1, room_rect.end.y)
	for ry in range(y0, y1 + 1):
		for rx in range(x0, x1 + 1):
			if room_rect.has_point(Vector2i(rx, ry)):
				continue
			var e = empty_space_scene.instantiate()
			e.board_pos = Vector2i(rx, ry)
			e.position = game.board_to_px(Vector2i(rx, ry))
			add_child(e)
			empty_spaces.append(e)
	for e in empty_spaces:
		e.show_hide_walls(board)

func _is_wall_between(p, q):
	# check if there is a wall between board pos p and board pos q, either from the pipe of p or from the pipe of q
	# this will be used later for the can_go_to function
	var diff: Vector2i = q - p
	var dir: int = DirArray.find(diff)
	if dir < 0:
		return false
	var opp_dir: int = (dir + 2) % 4
	var pcell: OneCell = bcell(p)
	var qcell: OneCell = bcell(q)
	if pcell != null and pcell.pipe != null and pcell.pipe.fences[dir]:
		return true
	if qcell != null and qcell.pipe != null and qcell.pipe.fences[opp_dir]:
		return true
	return false

func _remove_maze_wall(p: Vector2i, q: Vector2i, dir_p_to_q: int):
	var opp: int = (dir_p_to_q + 2) % 4
	if board[p.y][p.x].pipe != null:
		board[p.y][p.x].pipe.show_fence(dir_p_to_q, false)
	if board[q.y][q.x].pipe != null:
		board[q.y][q.x].pipe.show_fence(opp, false)

func _would_create_2x2(p: Vector2i, q: Vector2i, dir: int) -> bool:
	# Returns true if removing the wall between p and q (in direction dir) would produce
	# a fully open 2x2 area, by checking both perpendicular neighboring squares.
	for perp_dir in [(dir + 1) % 4, (dir + 3) % 4]:
		var perp: Vector2i = DirArray[perp_dir]
		var a: Vector2i = p + perp
		var b: Vector2i = q + perp
		if not room_rect.has_point(a) or not room_rect.has_point(b):
			continue
		# Square is {p, q, a, b}. The edge p-q is about to be removed.
		# If the other three edges are all open, removing p-q creates a full 2x2 opening.
		if not _is_wall_between(p, a) and not _is_wall_between(q, b) and not _is_wall_between(a, b):
			return true
	return false

func _create_maze():
	# Place interior walls on canonical sides (right=0, bottom=1) between adjacent room cells.
	for ry in range(room_rect.position.y, room_rect.end.y):
		for rx in range(room_rect.position.x, room_rect.end.x):
			var p: Vector2i = Vector2i(rx, ry)
			for dir in [0, 1]:
				var np: Vector2i = p + DirArray[dir]
				if room_rect.has_point(np) and board[p.y][p.x].pipe != null:
					board[p.y][p.x].pipe.show_fence(dir, true)

	# Carve a spanning tree with randomized DFS from the player start position,
	# guaranteeing every cell is reachable (player can reach all coins, monsters have no dead pocket).
	var player_start: Vector2i = room_rect.position + Vector2i(room_size / 2, room_size / 2)
	var visited: Dictionary = {}
	var stack: Array[Vector2i] = [player_start]
	visited[player_start] = true

	while not stack.is_empty():
		var p: Vector2i = stack.back()
		var dirs: Array[int] = [0, 1, 2, 3]
		for i in range(3, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: int = dirs[i]
			dirs[i] = dirs[j]
			dirs[j] = tmp
		var found: bool = false
		for dir in dirs:
			var np: Vector2i = p + DirArray[dir]
			if room_rect.has_point(np) and not visited.has(np):
				_remove_maze_wall(p, np, dir)
				visited[np] = true
				stack.push_back(np)
				found = true
				break
		if not found:
			stack.pop_back()

	# Remove extra_passages extra walls to add loops, making it easier to escape monsters.
	# Walls that would create a fully open 2x2 area are skipped.
	var extra_walls: Array = []
	for ry in range(room_rect.position.y, room_rect.end.y):
		for rx in range(room_rect.position.x, room_rect.end.x):
			var p: Vector2i = Vector2i(rx, ry)
			if board[p.y][p.x].pipe == null:
				continue
			for dir in [0, 1]:
				var np: Vector2i = p + DirArray[dir]
				if room_rect.has_point(np) and board[p.y][p.x].pipe.fences[dir]:
					extra_walls.append([p, dir])
	for i in range(extra_walls.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Array = extra_walls[i]
		extra_walls[i] = extra_walls[j]
		extra_walls[j] = tmp
	var removed: int = 0
	for wall in extra_walls:
		if removed >= extra_passages:
			break
		var p: Vector2i = wall[0]
		var dir: int = wall[1]
		if not _would_create_2x2(p, p + DirArray[dir], dir):
			_remove_maze_wall(p, p + DirArray[dir], dir)
			removed += 1

	_patch_wall_corners()

# The wall art leaves the corner square open where a wall runs right from a corner and another runs
# down from it — see pipe.gd show_corner_patch(). A cell owns the patch for its OWN top-left corner,
# which needs a wall along its top edge (the bottom fence of the cell above) and one along its left
# edge (the right fence of the cell to its left). Must run after every fence is final.
func _patch_wall_corners() -> void:
	for ry in range(room_rect.position.y, room_rect.end.y):
		for rx in range(room_rect.position.x, room_rect.end.x):
			var pipe = board[ry][rx].pipe
			if pipe == null:
				continue
			var above = board[ry - 1][rx].pipe if ry > room_rect.position.y else null
			var left = board[ry][rx - 1].pipe if rx > room_rect.position.x else null
			var diag = null
			if ry > room_rect.position.y and rx > room_rect.position.x:
				diag = board[ry - 1][rx - 1].pipe
			# Only a bare elbow leaves a hole. If a wall CONTINUES past the corner — to the left (the
			# diagonal cell's bottom fence) or upward (its right fence) — that bar already covers the
			# square, and patching it again repaints those 2 px slightly off, which is what made a T
			# look like its stem poked above the head.
			var elbow: bool = above != null and above.fences[1] and left != null and left.fences[0]
			var continues: bool = diag != null and (diag.fences[1] or diag.fences[0])
			pipe.show_corner_patch(elbow and not continues)

func _add_bricks():
	var brick_type: int = rng.randi_range(0, 2)

	# One brick per wall at the wall's center with a random ±1 shift along the wall axis.
	# Prevents monsters from just marching along walls without turning.
	var half: int = room_size / 2
	var wall_positions: Array[Vector2i] = [
		Vector2i(room_rect.position.x + half + rng.randi_range(-1, 1), room_rect.position.y),    # top
		Vector2i(room_rect.position.x + half + rng.randi_range(-1, 1), room_rect.end.y - 1),     # bottom
		Vector2i(room_rect.position.x,          room_rect.position.y + half + rng.randi_range(-1, 1)),  # left
		Vector2i(room_rect.end.x - 1,           room_rect.position.y + half + rng.randi_range(-1, 1)),  # right
	]
	for wp: Vector2i in wall_positions:
		if board[wp.y][wp.x].is_fillable():
			board[wp.y][wp.x].pipe.has_brick = brick_type
			board[wp.y][wp.x].pipe.set_rot(board)

	for _i in num_bricks:
		var p: Vector2i = MainGlobals.pick_one_cell(
			room_rect.position.x + 1, room_rect.position.y + 1,
			room_rect.end.x - 2, room_rect.end.y - 2,
			func(x, y):
				var cell: OneCell = board[y][x]
				return cell.is_fillable() and _dist_from_agents_and_player(Vector2i(x, y)) >= 2)
		if p.x >= 0:
			board[p.y][p.x].pipe.has_brick = brick_type
			board[p.y][p.x].pipe.set_rot(board)

	_ensure_room_connected()

func _create_player(p: Vector2i):
	player = player_scene.instantiate()
	player.direction = 0
	player.board_pos = p
	player.speed_scale = 1.5
	player.is_moving = GorillaG.always_moving
	player.sig_is_really_moving.connect(_on_player_is_really_moving)
	player.remove_player.connect(_on_player_removed)
	add_child(player)
	board[p.y][p.x].has_player = true
	player.set_color(PLAYER_COLOR)
	player.set_pos(game.board_to_px(p), 0)
	player.play()

func _on_player_is_really_moving(is_moving: bool):
	if is_moving:
		game.play_sound("feet")
	else:
		game.stop_sound("feet")

func _on_player_removed(arrived: bool):
	if arrived:
		return
	# Player was hit — level fails
	_level_done(false)

const MIN_ESCAPE_DIST: int = 4  # cells required if monster spawns facing the player

var next_agent_id: int = 1
func _spawn_agent(index:int,_far:bool = false) -> bool:
	var p:Vector2i
	if _far:
		var player_pos: Vector2i = Vector2i(room_rect.position.x + room_size / 2, room_rect.position.y + room_size / 2) if player == null else player.board_pos
		# Rank the 4 walls by perpendicular distance from the player and pick the 2 farthest.
		# Wall ids: 0=top, 1=bottom, 2=left, 3=right
		var wall_dists: Array = [
			[player_pos.y - room_rect.position.y,      0],
			[room_rect.end.y - 1 - player_pos.y,       1],
			[player_pos.x - room_rect.position.x,      2],
			[room_rect.end.x - 1 - player_pos.x,       3],
		]
		wall_dists.sort_custom(func(wa, wb): return wa[0] > wb[0])
		var far_wall_ids: Array = [wall_dists[0][1], wall_dists[1][1]]
		for inside in 3:
			var left: int = room_rect.position.x + inside
			var top: int = room_rect.position.y + inside
			var right: int = room_rect.end.x - 1 - inside
			var bottom: int = room_rect.end.y - 1 - inside
			var candidates: Array[Vector2i] = []
			for wall_id in far_wall_ids:
				if wall_id == 0:
					for col in range(left, right + 1):
						candidates.append(Vector2i(col, top))
				elif wall_id == 1:
					for col in range(left, right + 1):
						candidates.append(Vector2i(col, bottom))
				elif wall_id == 2:
					for row in range(top, bottom + 1):
						candidates.append(Vector2i(left, row))
				else:
					for row in range(top, bottom + 1):
						candidates.append(Vector2i(right, row))
			candidates = candidates.filter(func(bp): return board[bp.y][bp.x].is_fillable() and _dist_from_agents(bp) >= 2)
			if candidates.is_empty():
				continue
			p = candidates[rng.randi_range(0, candidates.size() - 1)]
			break
	else:
		for inside in 3:
			p = MainGlobals.pick_one_cell_on_borders(
				room_rect.position.x+inside, room_rect.position.y+inside,
				room_rect.end.x-1-inside, room_rect.end.y-1-inside,
				func(x, y):
					if not board[y][x].is_fillable() or _dist_from_agents(Vector2i(x, y)) < 2:
						return false
					# At least one direction must be valid: either not toward player, or far enough
					if player == null:
						return true
					var dist: float = float((Vector2i(x, y) - player.board_pos).length())
					for d in 4:
						var next: Vector2i = Vector2i(x, y) + DirArray[d]
						var toward: bool = (next - player.board_pos).length() < dist
						if not toward or dist >= MIN_ESCAPE_DIST:
							return true
					return false)
			if p.x >= 0:
				break

	if p.x < 0:
		return false

	var agent = agent_scene.instantiate()
	# Pick direction randomly; if toward player and too close, pick a different one
	var dist_to_player: float = 999.0 if player == null else float((p - player.board_pos).length())
	var valid_dirs: Array = []
	for d in 4:
		var next: Vector2i = p + DirArray[d]
		var toward: bool = player != null and (next - player.board_pos).length() < dist_to_player
		if not toward or dist_to_player >= MIN_ESCAPE_DIST:
			valid_dirs.append(d)
	agent.direction = valid_dirs[rng.randi_range(0, valid_dirs.size() - 1)]
	agent.board_pos = p
	agent.body_ids = []
	var t: float = min(1,float(index) / max(1, num_inside_monsters - 1))
	agent.speed_scale = lerp(agent_speed_min, agent_speed_max, t)	# this is already capped below player speed scale in _apply_level
	agent.set_type(1)
	add_child(agent)
	agent.set_id(next_agent_id)
	next_agent_id += 1
	agent.is_moving = true
	agent.set_color(AGENT_COLOR_INDICES[next_agent_id % AGENT_COLOR_INDICES.size()])
	board[p.y][p.x].has_agent = true
	agents.append(agent)
	agent.set_pos(game.board_to_px(p), agent.direction)
	return true

func _fill_coins():
	var pipe_coins = []
	for ry in range(room_rect.position.y, room_rect.end.y):
		for rx in range(room_rect.position.x, room_rect.end.x):
			var p: Vector2i = Vector2i(rx, ry)
			var c: OneCell = bcell(p)
			if c.is_fillable():
				c.pipe.has_coin = 1
				c.pipe.set_rot(board)
				coins[p] = true
				pipe_coins.append(c.pipe)

	var pc
	pipe_coins.shuffle()
	for i in powers_in_level:
		pc = pipe_coins.pop_front()
		pc.has_coin = 1000
		pc.set_rot(board)

	var wh1 = pipe_coins.pop_front()
	wh1.has_coin = 2000
	wh1.set_rot(board)
	coins.erase(wh1.board_pos)

	var maxd = 0
	var besti = 0
	for i in pipe_coins.size():
		var d = (pipe_coins[i].board_pos - wh1.board_pos).length_squared()
		if d > maxd:
			maxd = d
			besti = i
	var wh2 = pipe_coins.pop_at(besti)
	wh2.has_coin = 2002
	wh2.set_rot(board)
	coins.erase(wh2.board_pos)
	
	wh1.warp_to_pos = wh2.board_pos
	wh2.warp_to_pos = wh1.board_pos
	

# The slice of the WORLD that is visible between the header and the bottom bar. The camera zoom is
# not 1 — it scales the board to fit the screen — so world pixels and screen pixels are different
# units. Placing a lane straight from MainGlobals.screen_size pushes it off-screen at zoom > 1 and
# leaves a gap at zoom < 1, which is why everything peripheral is measured through here.
func _playfield_world_rect() -> Rect2:
	var vp: Vector2 = Vector2(MainGlobals.screen_size)
	var z: float = 1.0
	var c: Vector2 = vp * 0.5
	if game_cam != null and is_instance_valid(game_cam):
		z = game_cam.zoom.x
		c = game_cam.position
	var tl: Vector2 = c + (Vector2(0.0, float(game.header_height)) - vp * 0.5) / z
	var br: Vector2 = c + (Vector2(vp.x, vp.y - float(game.buttons_height)) - vp * 0.5) / z
	return Rect2(tl, br - tl)

func _plan_gorilla_spawns():
	var play: Rect2 = _playfield_world_rect()
	# Worst-case travel distance: the longer of a horizontal / vertical crossing. Must match the
	# off-screen margin `_spawn_peripheral_gorilla()` starts and ends at, or the slots under-estimate.
	var edge: float = 2.0 * game.tile_size * GORILLA_TILES * GorillaFigure.HALF_ALONG
	var max_dist: float = max(play.size.x + edge, play.size.y + edge)
	var travel_time: float = max_dist / gorilla_speed_px
	# Each slot is 2×travel_time wide. A gorilla spawns near the slot center,
	# so it always finishes before the next slot's gorilla could start — even for adjacent slots.
	var slot_duration: float = travel_time * 2.0
	var earliest: float = 3.0
	var n_slots: int = int((float(game.time_left_sec) - earliest) / slot_duration)
	if n_slots <= 0:
		return
	var count: int = rng.randi_range(2 + level, 5 + level)
	count = min(count, n_slots)
	# Pick `count` distinct slot indices from [0..n_slots-1].
	var pool = range(n_slots)
	pool.shuffle()
	var chosen = pool.slice(0, count)
	chosen.sort()
	for slot in chosen:
		var center: float = earliest + (slot + 0.5) * slot_duration
		gorilla_spawn_times.append(center + rng.randf_range(-travel_time * 0.4, travel_time * 0.4))
	level_start_ms = MainGlobals.timems()

# force_horizontal: the tutorial always wants a left/right runner. A vertical one held mid-lane
# sits in the center of the screen edge and reads oddly, and phones only ever get horizontal lanes
# anyway, so the tutorial should teach the case everyone actually sees.
func _spawn_peripheral_gorilla(force_horizontal: bool = false):
	var play: Rect2 = _playfield_world_rect()
	var ts: float = float(game.tile_size)
	var bh: float = ts * GORILLA_TILES
	var gap: float = ts * GORILLA_BOARD_GAP_TILES

	# "The board" the gorilla must stay off is the room floor, in pixels.
	var half_tile: Vector2 = Vector2(ts, ts) * 0.5
	var room_tl: Vector2 = game.board_to_px(room_rect.position) - half_tile
	var room_br: Vector2 = game.board_to_px(room_rect.end - Vector2i.ONE) + half_tile

	# Half-extent of the figure ACROSS its direction of travel: a horizontal lane is placed by the
	# side view's height, a vertical lane by the front view's width. Measured from the drawing, so
	# the clearance below is the FIGURE's clearance, not its center point's.
	var half_h: float = bh * GorillaFigure.HALF_ACROSS_SIDE
	var half_w: float = bh * GorillaFigure.HALF_ACROSS_FRONT

	# Per side, the band the gorilla's center may sit in: clear of the room by `gap` on the inner
	# edge, inside the playfield on the outer one. An empty band means that side has no room.
	var lo: Array[float] = [
		play.position.y + half_h,
		room_br.y + gap + half_h,
		play.position.x + half_w,
		room_br.x + gap + half_w,
	]
	var hi: Array[float] = [
		room_tl.y - gap - half_h,
		play.end.y - half_h,
		room_tl.x - gap - half_w,
		play.end.x - half_w,
	]

	var sides: Array[int] = []
	for s in 4:
		# Left/right lanes stay desktop-only, as before: a phone has no columns to spare.
		if s >= 2 and MainGlobals.is_mobile():
			continue
		if lo[s] <= hi[s]:
			sides.append(s)
	if force_horizontal:
		# Prefer a left/right runner, but do NOT insist: on a screen where the top and bottom
		# bands do not fit, insisting produced no gorilla at all — and the tutorial then sat
		# waiting out its timeout for one that was never coming.
		var horiz: Array[int] = []
		for s2 in sides:
			if s2 <= 1:
				horiz.append(s2)
		if not horiz.is_empty():
			sides = horiz
	if sides.is_empty():
		return

	var side: int = sides[rng.randi_range(0, sides.size() - 1)]
	var lane: float = rng.randf_range(lo[side], hi[side])
	var go_positive: bool = rng.randi() % 2 == 0
	var off: float = bh * GorillaFigure.HALF_ALONG   # far enough out for the whole figure to be hidden

	var start_pos: Vector2
	var vel: Vector2
	var sr: Rect2
	if side <= 1:
		var x0: float = play.position.x - off
		var x1: float = play.end.x + off
		start_pos = Vector2(x0, lane) if go_positive else Vector2(x1, lane)
		vel = Vector2(gorilla_speed_px if go_positive else -gorilla_speed_px, 0.0)
		sr = Rect2(x0, lane - half_h, x1 - x0, 2.0 * half_h)
	else:
		var y0: float = play.position.y - off
		var y1: float = play.end.y + off
		start_pos = Vector2(lane, y0) if go_positive else Vector2(lane, y1)
		vel = Vector2(0.0, gorilla_speed_px if go_positive else -gorilla_speed_px)
		sr = Rect2(lane - half_w, y0, 2.0 * half_w, y1 - y0)

	# Skip if the gorilla can't cross the full screen before time runs out
	var travel_dist: float = sr.size.x if side <= 1 else sr.size.y
	if game.time_left_sec * gorilla_speed_px < travel_dist:
		return

	var g = peripheral_gorilla_scene.instantiate()
	g.game = game            # so it stops when the game does (pause, popup, tutorial caption)
	g.velocity = vel
	g.screen_rect = sr
	g.position = start_pos
	g.body_height = bh
	# No modulate: the gorilla draws its own fur, saddle and face, and a tint would flatten the
	# silverback back into the body color and cost the figure its main contrast.
	g.exited_screen.connect(func(): peripheral_gorillas.erase(g))
	add_child(g)
	peripheral_gorillas.append(g)
	num_gorillas_spawned += 1
	game.tutorial_notify("gorilla_appeared")   # no-op outside tutorial mode

func _dist_from_agents_and_player(p: Vector2i) -> float:
	var d: float = _dist_from_agents(p)
	if player != null:
		d = min(d, float((p - player.board_pos).length()))
	return d

func _dist_from_agents(p: Vector2i) -> float:
	var mind: float = 1e6
	for a in agents:
		var d: float = float((p - a.board_pos).length())
		if d < mind:
			mind = d
	return mind

func _flood_fill(start: Vector2i) -> Dictionary:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for d: Vector2i in DirArray:
			var n: Vector2i = p + d
			if game.in_board(n) and board[n.y][n.x].ispipe \
					and board[n.y][n.x].pipe != null and board[n.y][n.x].pipe.has_brick < 0 \
					and not visited.has(n):
				visited[n] = true
				queue.append(n)
	return visited

func _ensure_room_connected():
	# Player always starts at room center — all non-brick room cells must be reachable from there.
	# Remove border bricks one at a time until the room is fully connected.
	var player_start: Vector2i = room_rect.position + Vector2i(room_size / 2, room_size / 2)
	for _attempt in 20:
		var reachable: Dictionary = _flood_fill(player_start)
		# Collect non-brick room cells that are NOT reachable
		var blocked: Array[Vector2i] = []
		for ry in range(room_rect.position.y, room_rect.end.y):
			for rx in range(room_rect.position.x, room_rect.end.x):
				var p: Vector2i = Vector2i(rx, ry)
				if board[ry][rx].ispipe and board[ry][rx].pipe != null \
						and board[ry][rx].pipe.has_brick < 0 and not reachable.has(p):
					blocked.append(p)
		if blocked.is_empty():
			break
		# Find a brick that sits between the reachable set and a blocked cell, and remove it
		var removed: bool = false
		for rp: Vector2i in reachable.keys():
			for d: Vector2i in DirArray:
				var n: Vector2i = rp + d
				if not game.in_board(n) or not board[n.y][n.x].ispipe or board[n.y][n.x].pipe == null:
					continue
				if board[n.y][n.x].pipe.has_brick < 0:
					continue
				# n is a brick adjacent to a reachable cell — check if it also borders a blocked cell
				for d2: Vector2i in DirArray:
					var n2: Vector2i = n + d2
					if blocked.has(n2):
						board[n.y][n.x].pipe.has_brick = -1
						board[n.y][n.x].pipe.set_rot(board)
						removed = true
						break
				if removed:
					break
			if removed:
				break

func bcell(p:Vector2i):
	if game.in_board(p):
		return board[p.y][p.x]
	else:
		return null

func can_go_to(p: Vector2i, q:Vector2i) -> bool:
	var qcell = bcell(q)
	var pcell = bcell(p)
	if pcell == null or qcell == null or !pcell.ispipe or !qcell.ispipe or _is_wall_between(p,q):
		return false
	return qcell.pipe.has_brick < 0

func _can_agent_go_to(p: Vector2i, q:Vector2i) -> bool:
	var qcell = bcell(q)
	var pcell = bcell(p)
	if pcell == null or qcell == null or !pcell.ispipe or !qcell.ispipe or _is_wall_between(p,q):
		return false

	if qcell.pipe.is_wormhole and player.warping:
		return false

	return not qcell.has_agent and qcell.pipe.has_brick < 0

func _input(event: InputEvent) -> void:
	if in_answering_mode or MainGlobals.ignore_keyboard_actions:
		return
	if event.is_action_pressed("right") or event.is_action_pressed("ui_right"):
		_move_dir(0)
	elif event.is_action_pressed("down") or event.is_action_pressed("ui_down"):
		_move_dir(1)
	elif event.is_action_pressed("left") or event.is_action_pressed("ui_left"):
		_move_dir(2)
	elif event.is_action_pressed("up") or event.is_action_pressed("ui_up"):
		_move_dir(3)
	elif event.is_action_pressed("stop"):
		if not GorillaG.always_moving and player != null and player.is_moving:
			player.need_to_stop = true

func _move_dir(dir: int):
	if player == null:
		return
	# Only ever called from _input, so this is a real player action — unlike coin pickups, which
	# happen on their own because the player is always walking (GorillaG.always_moving).
	game.tutorial_notify("player_steered")
	if not player.reached_target_pos and player.direction == dir:
		return
	player.need_to_move = true
	player.need_to_stop = false
	if not game.level_is_ready:
		return
	next_player_dir = dir
	player.is_moving = true	
	player.look_towards_next_dir(dir)
	if abs(dir - player.direction) == 2:
		player.last_major_tick_ms = 0
		tick(true)

func _start_playing():
	if play_start_sound:
		play_start_sound = false
		game.play_sound("start")
		if player != null:
			player.play()

var time_to_spawn_agent:int = 0

func _process(_delta: float) -> void:
	if player != null and not player.was_hit:
		_start_playing()
		_check_agent_collisions()

		if time_to_spawn_agent != 0 and MainGlobals.timems() > time_to_spawn_agent:
			time_to_spawn_agent = 0
			_spawn_agent(num_inside_monsters-1)

func _check_agent_collisions():
	if player == null or player.was_hit:
		return
	for a in agents:
		if a.was_hit:
			continue
		var d:float = (a.position - player.position).length()
		if d < 0.5 * game.tile_size:			
			if player.has_power:
				a.mark_hit()
				player.stop_power()
				time_to_spawn_agent = MainGlobals.timems() + 1000
				game.add_score_and_time(10, 0)
			else:
				player.mark_hit()
				collision.emit()
				game.play_sound("explosion")
			return

func tick(force: bool = false):
	if game.level_is_done or not game.level_is_ready:
		return

	_move_player_on_tick(force)
	_move_agents_on_tick()

	if coins.is_empty() and not in_answering_mode:
		on_time_over()
		return

	if gorilla_spawn_index < gorilla_spawn_times.size() and peripheral_gorillas.is_empty():
		var elapsed_sec: float = float(MainGlobals.timems() - level_start_ms) / 1000.0
		if elapsed_sec >= gorilla_spawn_times[gorilla_spawn_index]:
			_spawn_peripheral_gorilla()
			gorilla_spawn_index += 1

func _move_player_on_tick(force: bool):
	if player == null or not player.is_moving:
		return
	if not player.reached_target_pos and not force:
		return
	if not player.need_to_major_tick():
		return
	player.hide_hand()
	player.set_major_tick_now()

	if player.warping:
		return
	var cell: OneCell = bcell(player.board_pos)
	if cell.pipe != null and cell.pipe.has_coin >= 0:
		var cpipe = cell.pipe
		var is_power_coin = cpipe.is_power_coin()
		var is_wormhole = cpipe.is_wormhole()
		if is_wormhole:
			#print("source active ", cpipe.is_wormhole_active(), " warping ", cpipe.warping, "  player warping ", player.warping)
			var qpipe = bcell(cpipe.warp_to_pos).pipe
			#print("target active ", qpipe.is_wormhole_active(), " warping ", qpipe.warping, "  has agent ", bcell(cpipe.warp_to_pos).has_agent)
			if cpipe.is_wormhole_active() and !player.warping and !cpipe.warping:
				var tocell = bcell(cpipe.warp_to_pos)
				if !tocell.has_agent:
					player.warp_to(tocell.pipe.board_pos, board)
					return
		else:
			var coin_score: int = 1
			game.add_score_and_time(coin_score, 0)
			game.play_sound("delivery")
			cell.pipe.remove_coin()
			cell.pipe.set_rot(board)
			coins.erase(player.board_pos)
			game.tutorial_notify("coin_taken")   # no-op outside tutorial mode
			if is_power_coin:
				player.ate_power()
			update_score.emit(coin_score)

	if player.arrived or player.was_hit:
		return
	if player.need_to_stop and not player.need_to_move:
		return

	var p: Vector2i = player.board_pos
	if game.in_board(p):
		player.need_to_move = false
		var used_next_dir: bool = next_player_dir >= 0
		var dir: int = next_player_dir if next_player_dir >= 0 else player.direction
		var vdir: Vector2i = DirArray[dir]
		var q: Vector2i = p + vdir

		if not can_go_to(p,q) and used_next_dir:
			dir = player.direction
			vdir = Vector2i(DirArray[dir])
			q = p + vdir
			used_next_dir = false

		# if not can_go_to(q) and GorillaG.always_moving:
		# 	for diradd in [1, 3, 2]:
		# 		var altdir: int = (dir + diradd) % 4
		# 		var altq: Vector2i = p + Vector2i(DirArray[altdir])
		# 		if can_go_to(altq):
		# 			dir = altdir
		# 			q = altq
		# 			break

		if can_go_to(p,q):
			player.direction = dir
			var actual_tick_time: float = float(player.set_target_pos(game.board_to_px(q)))
			if used_next_dir:
				next_player_dir = -1
			player.last_major_tick_ms = MainGlobals.timems() + actual_tick_time - game.major_tick_time_ms * game.time_scale
			player.set_board_pos(q, board)

func _move_agents_on_tick():
	for agent in agents:
		if not agent.need_to_major_tick():
			continue
		if agent.was_hit or agent.arrived:
			continue
		agent.set_major_tick_now()

		var p: Vector2i = agent.board_pos
		var dir: int = -1

		if rng.randf() < directed_chance and player != null:
			var dp: Vector2i = player.board_pos - p
			if abs(dp.x) >= abs(dp.y):
				dir = 0 if dp.x > 0 else 2
			else:
				dir = 1 if dp.y > 0 else 3
			if not _can_agent_go_to(p, p + Vector2i(DirArray[dir])):
				dir = -1

		if dir < 0:
			# Keep current direction unless blocked
			if agent.direction >= 0 and _can_agent_go_to(p,p + Vector2i(DirArray[agent.direction])):
				dir = agent.direction
			else:
				var valid_dirs: Array = []
				for d in 4:
					if _can_agent_go_to(p,p + Vector2i(DirArray[d])):
						valid_dirs.append(d)
				if valid_dirs.is_empty():
					continue
				dir = valid_dirs[rng.randi_range(0, valid_dirs.size() - 1)]

		var q: Vector2i = p + Vector2i(DirArray[dir])
		# Final guard: another agent may have claimed this cell earlier in the same tick
		if board[q.y][q.x].has_agent:
			continue
		agent.direction = dir
		agent.board_pos = q
		agent.set_target_pos(game.board_to_px(q))
		board[q.y][q.x].has_agent = true
		board[p.y][p.x].has_agent = false

func on_time_over():
	if in_answering_mode:
		return
	in_answering_mode = true
	game.tutorial_notify("answer_time")
	game.level_is_ready = false

	if player != null:
		player.is_moving = false
		player.need_to_stop = true
	for a in agents:
		a.is_moving = false
	game.stop_sound("feet")

	_show_answer_popup()

func _show_answer_popup():
	var true_count: int = num_gorillas_spawned
	var raw_choices: Array[int] = []
	for i in range(-2, 3):
		var v: int = max(0, true_count + i)
		if not v in raw_choices:
			raw_choices.append(v)
	raw_choices.shuffle()

	var buttons: Array = $UILayer/AnswerOverlay/Panel/VBox/ButtonsBox.get_children()
	for i in buttons.size():
		if i < raw_choices.size():
			buttons[i].text = str(raw_choices[i])
			buttons[i].show()
			var choice_val: int = raw_choices[i]
			# Disconnect previous connections first
			if buttons[i].pressed.is_connected(_on_answer_selected.bind(0, 0)):
				pass  # handled by CONNECT_ONE_SHOT below
			buttons[i].pressed.connect(func(): _on_answer_selected(choice_val, true_count), CONNECT_ONE_SHOT)
		else:
			buttons[i].hide()

	$UILayer/AnswerOverlay.show()

func _on_answer_selected(chosen: int, true_count: int):
	game.tutorial_notify("answered")
	$UILayer/AnswerOverlay.hide()
	var error: int = abs(chosen - true_count)
	game.add_correct_or_mistake(error, 1)
	if error == 0:
		game.add_score_and_time(20, 0)
		game.need_to_increase_level = true

	last_level_was_a_win = true
	game.level_is_done = true

	var popup_text: String
	if error == 0:
		popup_text = "Correct!\n+20 bonus"
	elif error == 1:
		popup_text = "Off by 1\nThere were %d gorillas" % true_count
	else:
		popup_text = "Off by %d\nThere were %d gorillas" % [error, true_count]
	game.show_game_popup(self, "Time's up!", popup_text)

func on_lives_depleted():
	_level_done(false)

func _level_done(didwin: bool):
	last_level_was_a_win = didwin
	game.level_is_done = true
	game.stop_sound("feet")
	sig_level_is_done.emit(didwin)

func _advance_if_needed() -> void:
	if game.need_to_increase_level:
		round_in_level += 1
		if round_in_level >= rounds_per_level:
			round_in_level = 0
			level += 1
	_apply_level()

func _reapply_level_after_player_created() -> void:
	var n_levels: int = GorillaLevelConfig.LEVELS.size()
	var cfg: Dictionary = GorillaLevelConfig.LEVELS[min(level, n_levels) - 1]
	agent_speed_max = cfg["agent_speed_max"] if player == null else min(cfg["agent_speed_max"], player.speed_scale - 0.2)

func _apply_level() -> void:
	var n_levels: int = GorillaLevelConfig.LEVELS.size()
	var cfg: Dictionary = GorillaLevelConfig.LEVELS[min(level, n_levels) - 1]
	room_size = cfg["room_size"]
	num_inside_monsters = cfg["num_inside_monsters"]
	num_bricks = cfg["num_bricks"]
	extra_passages = cfg["extra_passages"]
	agent_speed_min = cfg["agent_speed_min"]
	agent_speed_max = cfg["agent_speed_max"] if player == null else min(cfg["agent_speed_max"], player.speed_scale - 0.2)
	gorilla_speed_px = cfg["gorilla_speed_px"]
	directed_chance = cfg["directed_chance"]
	rounds_per_level = cfg["rounds"]
	powers_in_level = cfg["powers"]	
	var mx = 3
	var my = 3
	if MainGlobals.is_mobile():
		mx = 0
		my = 3
	game.forced_board_size = Vector2i(room_size+2*mx, room_size + 2*my)
	game.init_sizes()

var game_cam = null
func create_camera():
	var game_camscale:float = -0.0+min(game.get_tiles_in_screen_width() / float(game.board_size.x), game.get_tiles_in_screen_height() / float(game.board_size.y))
	# game_camscale = int(game_camscale * 2 + 0.5) / 2.0
	# if abs(game_camscale - 1) < 0.2:
	# 	game_camscale = 1
	var game_center = game.get_viewport_center()
	if !MainGlobals.is_mobile():
		game_center -= Vector2(0,30)		# to account for level # label

	# Reuse one camera for the whole run. Making a new Camera2D per board leaked one every level and,
	# worse, left the FIRST one current: Godot only auto-promotes a Camera2D when the viewport has no
	# current one, so the zoom stayed frozen at whatever the STARTING level needed and never followed
	# the room size again.
	if game_cam == null or not is_instance_valid(game_cam):
		game_cam = Camera2D.new()
		game_cam.position_smoothing_enabled = false
		add_child(game_cam)
	game_cam.zoom = Vector2(game_camscale, game_camscale)
	game_cam.position = game_center
	game_cam.enabled = true
	game_cam.make_current()

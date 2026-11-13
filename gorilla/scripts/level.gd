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

var empty_spaces: Array = []

# THE EVENTS (2026-11-09). The maze fills the screen, and while the player eats in one part of it
# things happen in another, which they have to notice and go and deal with:
#   * a LOST BABY GORILLA appears far away, quietly, and wanders. After `hunt_ms` the nearest
#     monster starts hunting it. Reach it first and it is rescued; let a monster reach it and it is
#     lost. This is what the level is judged on.
#   * a BUNCH OF BANANAS lies somewhere for `banana_ms`: a bonus, gone if nobody gets there.
# There is no question at the end any more: noticing is measured by what the player DOES -- how
# soon they get to the baby (rescue_times) and how many they save.
const BabyScript = preload("res://gorilla/scripts/baby_gorilla.gd")
const BananaScript = preload("res://gorilla/scripts/banana_art.gd")
const MotherScript = preload("res://gorilla/scripts/mother_gorilla.gd")
# THE MOTHER'S SWORD (2026-11-09). Each rescue brings a grown gorilla out somewhere else in the maze,
# holding out a sword, for `gift_ms`. Reach her and take it: it works exactly as the super-food did
# (player.ate_power -- the same timer ring and colors, the monsters run from you and can be eaten
# until it runs out). It REPLACED the super-food, so the power is now earned by noticing, twice:
# the baby, then its mother somewhere else.
const MOTHER_TILES: float = 1.25
var mother = null
var mother_cell: Vector2i = Vector2i(-1, -1)
var _mother_born_ms: float = 0.0
var _next_mother_ms: float = -1.0
var gift_ms: float = 8000.0
var gifts_taken: int = 0
var gifts_missed: int = 0
const BABY_TILES: float = 0.80         # the baby's size, in tiles (its drawing is mostly head)
const BABY_STEP_MS: float = 1100.0     # how often a wandering baby moves to the next cell
const FIRST_EVENT_MS: float = 5000.0   # nothing happens in the first seconds of a round
var baby = null
var baby_cell: Vector2i = Vector2i(-1, -1)
var baby_born_ms: float = 0.0
var _baby_dist: int = 0                # walking distance from the player when it appeared
var _baby_next_step_ms: float = 0.0
var hunter = null
var _babies_spawned: int = 0
var _next_baby_ms: float = 0.0
var rescue_times: Array = []           # ms from a baby's appearance to its rescue, this level
var _rescued_in_round: int = 0
var _lost_in_round: int = 0
var _bananas: Array = []               # [{node, cell, born}]
var _bananas_spawned: int = 0
var _next_banana_ms: float = 0.0
var bananas_taken: int = 0
var bananas_missed: int = 0

const PLAYER_COLOR: Color = Color(0.1, 0.5, 0.99)
# Indices into game.colors that agents may use — excludes blue(3) and white(12)
const AGENT_COLOR_INDICES: Array[int] = [0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11]

# Level params
var rounds_per_level: int = 2
var level: int = 0
var round_in_level: int = 0

# game.corrects / game.mistakes count BABIES: rescued, lost. The level gate reads them.
# (The counting error that used to live here went with the count question.)
# Set when the level's last round has been answered, so the next new_game() knows it is starting a
# LEVEL and not just the next round.
var _level_is_over: bool = false
# What the score was when this level began; a level that misses the gate goes back to it.
var _score_at_level_start: int = 0
var _rollback_score_on_next_level: bool = false
var cols: int = 11
var apples_in_round: int = 34
var round_sec: int = 75
var babies_per_round: int = 2
var baby_far: float = 0.5
var hunt_ms: float = 6000.0
var hunt_chance: float = 0.6
var bananas_per_round: int = 2
var banana_ms: float = 6000.0
var num_inside_monsters: int = 1
var num_bricks: int = 4
var extra_passages: int = 5
var directed_chance: float = 0.0
var smart_chase: float = 0.0     # the shortest way to the player (level_config.gd)
var agent_speed_min: float = 0.5
var agent_speed_max: float = 1.2
var powers_in_level: int = 3

# Set once the round is over (time up, or every apple eaten and every baby dealt with)
var in_answering_mode: bool = false
var last_level_was_a_win: bool = false

@export var pipe_scene: PackedScene
@export var agent_scene: PackedScene
@export var player_scene: PackedScene
@export var peripheral_gorilla_scene: PackedScene
@export var empty_space_scene: PackedScene

# Made for this game (devtools/make_action_sounds.py), names in code kept: `explosion` caught (a soft
# thump; was a car crash), `delivery` an apple eaten (a crunch; was an arcade coin), `start` a short
# whistle (was a click), `swoosh` through a portal (a rising warp), `feet` knuckle-walking on leaf litter (was a Kenney grass
# footstep).
const ForestFloor = preload("res://gorilla/scripts/forest_floor.gd")
var explosion_audio: AudioStream = preload("res://art/sounds/gorilla_oof.ogg")
var feet_audio: AudioStream = preload("res://art/sounds/gorilla_steps.ogg")
var delivered_audio: AudioStream = preload("res://art/sounds/gorilla_crunch.ogg")
var start_audio: AudioStream = preload("res://art/sounds/gorilla_start.ogg")
var swoosh_audio := preload("res://art/sounds/gorilla_warp.ogg")
# a monster eaten while the power is on (a chomp and a sparkle); it used to pass in silence
var gulp_audio: AudioStream = preload("res://art/sounds/gorilla_gulp.ogg")
# a baby rescued (a bright little rising figure) and a baby lost (two falling notes):
# devtools/make_gorilla_baby_sounds.py
var rescue_audio: AudioStream = preload("res://art/sounds/gorilla_rescue.ogg")
var lost_audio: AudioStream = preload("res://art/sounds/gorilla_lost.ogg")
# the sword taken: a bright metallic ring (devtools/make_gorilla_baby_sounds.py)
var gift_audio: AudioStream = preload("res://art/sounds/gorilla_gift.ogg")
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
	game.add_sound(self, "gulp", gulp_audio)
	game.add_sound(self, "rescue", rescue_audio)
	game.add_sound(self, "lost", lost_audio)
	game.add_sound(self, "gift", gift_audio)

	if not MainGlobals.sig_game_popup_closed.is_connected(_on_game_popup_closed):
		MainGlobals.sig_game_popup_closed.connect(_on_game_popup_closed)
	_fit_ground_to_board()

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

	_clear_events()

	for e in empty_spaces:
		e.queue_free()
	empty_spaces.clear()

	for c in pipes:
		c.queue_free()
	pipes.clear()

	board.clear()
	coins.clear()
	_babies_spawned = 0
	_bananas_spawned = 0
	_rescued_in_round = 0
	_lost_in_round = 0

func new_game(from_scratch: bool = true):
	reset()
	$BuildingLabel.show()
	$UILayer/AnswerOverlay.hide()
	await get_tree().process_frame
	# A round is one run at the room; a LEVEL is `rounds_per_level` of them. Only a level boundary clears
	# the counters, because the gate is judged over the whole level.
	var level_starts: bool = from_scratch or _level_is_over
	if from_scratch:
		level = GorillaG.starting_level
		bananas_taken = 0
		bananas_missed = 0
		gifts_taken = 0
		gifts_missed = 0
	if _level_is_over and _rollback_score_on_next_level:
		# The failed level's points go back HERE, on Continue, so the summary card was still read
		# against the score the player had while playing it.
		game.score = _score_at_level_start
	_rollback_score_on_next_level = false
	_level_is_over = false
	if level_starts:
		round_in_level = 0
		# A replay has to be a FRESH attempt: the gate reads these, so a retry that inherited the
		# misses which failed the level could not pass it even played perfectly.
		game.corrects = 0
		game.mistakes = 0
		_score_at_level_start = game.score
		rescue_times.clear()
	_advance_if_needed()
	game.need_to_increase_level = false
	in_answering_mode = false

	if game.tutorial_mode:
		num_inside_monsters = 0      # nothing may kill the player mid-lesson
	create_board()
	_plan_events()
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

# No automatic events during a tutorial: the coach asks for a baby when it wants one.
func _tutorial_setup() -> void:
	_next_baby_ms = 1.0e12
	_next_banana_ms = 1.0e12
	# the one baby the coach places is the round's only one, so the round can end once it is saved
	babies_per_round = 1
	bananas_per_round = 0

# Called by the tutorial step that talks about bananas; in the lesson the bunch waits.
func tutorial_spawn_banana() -> void:
	if _bananas.is_empty():
		banana_ms = 1.0e9
		_spawn_banana(game.game_time)

# Called by the tutorial step that talks about the mother and her sword; in the lesson she waits.
func tutorial_spawn_mother() -> void:
	if mother == null:
		gift_ms = 1.0e9
		_spawn_mother(game.game_time)

# Called by the tutorial step that is about to talk about the lost baby.
func tutorial_spawn_baby() -> void:
	if baby == null:
		_spawn_baby(game.game_time)

func create_board():
	_fit_ground_to_board()
	time_to_spawn_agent = 0
	for r in game.board_size.y:
		var row = []
		for c in game.board_size.x:
			row.append(OneCell.new())
		board.append(row)

	# THE MAZE IS THE WHOLE BOARD, and the board fills the screen (_apply_level)
	room_rect = Rect2i(Vector2i.ZERO, game.board_size)

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
	_add_wall_shade()
	ForestFloor.plant(get_node_or_null("BgLayer"), board, game, 13)

	var player_pos: Vector2i = _room_center()
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
	# The clock starts with the round, not with the first coin: standing still from the word
	# go has to cost something too.
	_restart_hunger()

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
	var player_start: Vector2i = _room_center()
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
	_add_temple_walls()

# THE TEMPLE'S WALLS (2026-11-12): every wall of the maze -- a cell edge with a fence on either side of it
# -- drawn as a thick wall of mossy stone blocks along the edge, its top lit from the top left, a dark
# face on its far side, and a soft shadow on the floor down and to the right. Each runs on past both ends
# by half its thickness, so walls meeting at a corner close it. Moss grows on top in patches and now and
# then a vine hangs down a side. They replaced thin white bar sprites. One node over the whole maze,
# drawn once, after the maze is carved.
const TEMPLE_WALL: float = 6.0       # (13 hid the paths and what was on them: "waaaaay too thick")
var _temple_walls: Node2D = null
var _temple_shadow: Node2D = null

func _add_temple_walls() -> void:
	for n in [_temple_walls, _temple_shadow]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_temple_shadow = Node2D.new()
	_temple_shadow.z_index = 0        # over the floor (z -1), drawn just before the walls
	_temple_shadow.draw.connect(_draw_temple_walls.bind(true, _temple_shadow))
	add_child(_temple_shadow)
	_temple_walls = Node2D.new()
	_temple_walls.draw.connect(_draw_temple_walls.bind(false, _temple_walls))
	add_child(_temple_walls)
	move_child(_temple_shadow, 0)
	move_child(_temple_walls, 1)

func _temple_edges() -> Array:
	# each wall once: [a, b] corner points of the edge in pixels, and whether it runs across (x)
	var seen: Dictionary = {}
	var out: Array = []
	var t: float = float(game.tile_size)
	for y in board.size():
		for x in board[y].size():
			var cell = board[y][x]
			if cell == null or cell.pipe == null:
				continue
			var c: Vector2 = game.board_to_px(Vector2i(x, y))
			for dir in 4:
				if not cell.pipe.fences[dir]:
					continue
				var n: Vector2 = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP][dir]
				var mid: Vector2 = c + n * t * 0.5
				var key: Vector2i = Vector2i(roundi(mid.x * 2.0), roundi(mid.y * 2.0))
				if seen.has(key):
					continue
				seen[key] = true
				var side: Vector2 = Vector2(-n.y, n.x)
				out.append([mid + side * t * 0.5, mid - side * t * 0.5, absf(n.y) > 0.5])
	return out

# (handed its own node: an old node drawing after a rebuild must not draw on the new one)
func _draw_temple_walls(shadow: bool, node: Node2D) -> void:
	var h: float = TEMPLE_WALL * 0.5
	var wall_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	wall_rng.seed = 777
	for e: Array in _temple_edges():
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var horiz: bool = e[2]
		var lo: Vector2 = Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(h, h)
		var hi: Vector2 = Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(h, h)
		var r: Rect2 = Rect2(lo, hi - lo)
		if shadow:
			node.draw_rect(Rect2(r.position + Vector2(2.0, 3.0), r.size), Color(0.0, 0.0, 0.0, 0.55))
			continue
		var stone: Color = Color(0.86, 0.83, 0.75)       # pale, bleached stone: well above the floor
		node.draw_rect(r, stone)
		# the blocks: joints across the wall every block's length, each block its own tone
		var length: float = r.size.x if horiz else r.size.y
		var nb: int = maxi(1, int(round(length / 11.0)))
		var bl: float = length / float(nb)
		for i in nb:
			var k: float = wall_rng.randf_range(-0.05, 0.05)
			var br: Rect2 = Rect2(r.position + (Vector2(float(i) * bl, 0) if horiz else Vector2(0, float(i) * bl)),
				Vector2(bl, r.size.y) if horiz else Vector2(r.size.x, bl))
			node.draw_rect(br.grow(-0.6), Color(stone.r + k, stone.g + k, stone.b + k * 0.8))
		# lit top and left edges, dark bottom and right
		node.draw_rect(Rect2(r.position, Vector2(r.size.x, 1.3)), Color(0.97, 0.95, 0.89))
		node.draw_rect(Rect2(r.position, Vector2(1.0, r.size.y)), Color(0.66, 0.62, 0.53))
		node.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1.4), Vector2(r.size.x, 1.4)), Color(0.50, 0.46, 0.38))
		node.draw_rect(Rect2(r.position + Vector2(r.size.x - 1.0, 0), Vector2(1.0, r.size.y)), Color(0.52, 0.48, 0.40))
		# a fine dark outline all round, so the edge is crisp against the floor
		node.draw_rect(r, Color(0.14, 0.11, 0.08, 0.9), false, 0.9)
		# moss on top in patches, and now and then a vine hanging down a side
		var patches: int = wall_rng.randi_range(0, 2)
		for p in patches:
			var u: float = wall_rng.randf_range(0.15, 0.85)
			var pc: Vector2 = r.position + (Vector2(u * r.size.x, r.size.y * 0.5) if horiz else Vector2(r.size.x * 0.5, u * r.size.y))
			var pr: float = wall_rng.randf_range(1.6, 2.6)
			node.draw_circle(pc, pr, Color(0.26, 0.40, 0.16, 0.9))
			node.draw_circle(pc + Vector2(-0.8, -0.8), pr * 0.6, Color(0.38, 0.54, 0.22, 0.9))
		if wall_rng.randf() < 0.18:
			var u2: float = wall_rng.randf_range(0.2, 0.8)
			var top: Vector2 = r.position + (Vector2(u2 * r.size.x, r.size.y) if horiz else Vector2(r.size.x, u2 * r.size.y))
			var dirv: Vector2 = Vector2(0, 1) if horiz else Vector2(1, 0)
			var pts: PackedVector2Array = PackedVector2Array()
			for k2 in 6:
				var f: float = float(k2) / 5.0
				pts.append(top + dirv * f * 6.0 + Vector2(dirv.y, dirv.x) * sin(f * 5.0) * 1.0)
			node.draw_polyline(pts, Color(0.20, 0.36, 0.14), 1.4, true)
			for k3 in [2, 4]:
				node.draw_circle(pts[k3] + Vector2(dirv.y, dirv.x) * 1.1, 1.0, Color(0.30, 0.50, 0.20))

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
	var half: int = room_rect.size.x / 2
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
	_lose_life("Caught!\nThat round is lost")

# ONE LIFE, ONE ROUND. Being caught used to end the whole LEVEL outright, while the three
# lives in the constructor were never spent by anything — the HUD showed hearts that could not
# go down beside a rule where one touch wiped a level.
#
# Now a life is the currency of a round: lose one and that round is failed and scored as a
# miss, and the run ends only when the last one goes. A correct count hands one back, so paying
# attention to the edge of the screen is what keeps you alive.
const LIFE_PENALTY: int = -15

func _lose_life(why: String) -> void:
	if game.level_is_done or not game.level_is_ready:
		return
	game.add_score_and_time(LIFE_PENALTY, 0)
	if game.kill_and_did_lives_run_out():
		game.mark_lives_depleted()          # -> on_lives_depleted -> the run is over
		return
	MainGlobals.global_update_hud()
	# A round you never finished is a fact about the session, not just a lost life: it is the
	# main task failing, which is the other half of what this game is for.
	game.record_count("rounds_lost")
	# a baby out at the time is lost with the round
	if baby != null:
		_baby_lost(game.game_time, false)
	_clear_events()
	game.level_is_done = true
	last_level_was_a_win = false
	round_in_level += 1
	if round_in_level >= rounds_per_level:
		_finish_level(why)
	else:
		game.show_game_popup(self, "Oh no!", why)

const MIN_ESCAPE_DIST: int = 4  # cells required if monster spawns facing the player

var next_agent_id: int = 1
func _spawn_agent(idx:int,_far:bool = false) -> bool:
	var p:Vector2i
	if _far:
		var player_pos: Vector2i = _room_center() if player == null else player.board_pos
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
	var t: float = min(1,float(idx) / max(1, num_inside_monsters - 1))
	agent.speed_scale = lerp(agent_speed_min, agent_speed_max, t)	# this is already capped below player speed scale in _apply_level
	agent.set_type(1)
	# An eaten monster shrinks and then asks to be removed (agent.mark_hit -> remove_agent). Nothing
	# listened, so it stayed on the board for the rest of the round at a tenth of its size -- a tiny
	# dark thing that walking over did nothing to -- still holding its cell against other monsters.
	agent.remove_agent.connect(_on_remove_agent.bind(agent))
	add_child(agent)
	agent.set_id(next_agent_id)
	next_agent_id += 1
	agent.is_moving = true
	agent.set_color(AGENT_COLOR_INDICES[next_agent_id % AGENT_COLOR_INDICES.size()])
	board[p.y][p.x].has_agent = true
	agents.append(agent)
	agent.set_pos(game.board_to_px(p), agent.direction)
	return true

# APPLES ARE SCATTERED, `apples_in_round` of them, not one on every cell: the maze fills the
# screen now, and a full board could not be eaten in a round.
func _on_remove_agent(_id, _arrived, agent) -> void:
	if not is_instance_valid(agent):
		return
	if game.in_board(agent.board_pos):
		board[agent.board_pos.y][agent.board_pos.x].has_agent = false
	agents.erase(agent)
	if hunter == agent:
		hunter = null
	agent.queue_free()

func _fill_coins():
	var cells: Array = []
	for ry in range(room_rect.position.y, room_rect.end.y):
		for rx in range(room_rect.position.x, room_rect.end.x):
			var c: OneCell = bcell(Vector2i(rx, ry))
			if c.is_fillable():
				cells.append(c)
	cells.shuffle()
	var pipe_coins = []
	for c in cells.slice(0, mini(cells.size(), apples_in_round + powers_in_level + 2)):
		c.pipe.has_coin = 1
		c.pipe.set_rot(board)
		coins[c.pipe.board_pos] = true
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
	

# --- the events -----------------------------------------------------------------

func _plan_events() -> void:
	var now: float = game.game_time
	_next_baby_ms = now + FIRST_EVENT_MS + rng.randf_range(0.0, 3000.0)
	# bananas are spread over the round, starting a little after the first baby could
	_next_banana_ms = now + FIRST_EVENT_MS + rng.randf_range(4000.0, 9000.0)

func _clear_events() -> void:
	if mother != null and is_instance_valid(mother):
		mother.queue_free()
	mother = null
	_next_mother_ms = -1.0
	if baby != null and is_instance_valid(baby):
		baby.queue_free()
	baby = null
	hunter = null
	for b in _bananas:
		if is_instance_valid(b["node"]):
			(b["node"] as Node).queue_free()
	_bananas.clear()

func _tick_events(now: float) -> void:
	if in_answering_mode or game.level_is_done:
		return
	if baby == null and _babies_spawned < babies_per_round and now >= _next_baby_ms:
		_spawn_baby(now)
	if baby != null:
		# after hunt_ms the nearest monster sets off after it
		if hunter == null and now - baby_born_ms >= hunt_ms:
			hunter = _nearest_agent(baby_cell)
			baby.scared = hunter != null
		if now >= _baby_next_step_ms:
			_baby_next_step_ms = now + BABY_STEP_MS
			_baby_wander()
	if _next_mother_ms >= 0.0 and now >= _next_mother_ms:
		_next_mother_ms = -1.0
		_spawn_mother(now)
	if mother != null and now - _mother_born_ms >= gift_ms:
		gifts_missed += 1
		mother.leave()
		mother = null
	if _bananas_spawned < bananas_per_round and now >= _next_banana_ms:
		_spawn_banana(now)
		_next_banana_ms = now + rng.randf_range(9000.0, 16000.0)
	for b in _bananas.duplicate():
		var node: Node2D = b["node"]
		node.set("now_ms", now)
		node.queue_redraw()
		if now - float(b["born"]) >= banana_ms:
			bananas_missed += 1
			node.queue_free()
			_bananas.erase(b)

# Walking distance from `from` to every cell, through the maze's walls (monsters do not block).
func _bfs_from(from: Vector2i) -> Dictionary:
	var dist: Dictionary = {from: 0}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for d in DirArray:
			var q: Vector2i = p + d
			if not dist.has(q) and can_go_to(p, q):
				dist[q] = int(dist[p]) + 1
				queue.append(q)
	return dist

# The step from p to the open neighbor nearest to (or, `away`, farthest from) whatever `dist` was
# measured from, or -1. A monster only; it must be a cell it may enter.
func _step_by_distance(p: Vector2i, dist: Dictionary, away: bool) -> int:
	var best: int = -1
	var best_d: int = -1 if away else (1 << 30)
	for k in 4:
		var q: Vector2i = p + DirArray[k]
		if not dist.has(q) or not _can_agent_go_to(p, q):
			continue
		var d: int = int(dist[q])
		if (away and d > best_d) or (not away and d < best_d):
			best_d = d
			best = k
	return best

# The direction of the first step on the shortest way from p to `to`, or -1.
func _step_toward(p: Vector2i, to: Vector2i) -> int:
	var dist: Dictionary = _bfs_from(to)
	var best: int = -1
	var best_d: int = 1 << 30
	for k in 4:
		var q: Vector2i = p + DirArray[k]
		if dist.has(q) and can_go_to(p, q) and int(dist[q]) < best_d:
			best_d = int(dist[q])
			best = k
	return best

func _nearest_agent(cell: Vector2i):
	var dist: Dictionary = _bfs_from(cell)
	var best = null
	var best_d: int = 1 << 30
	for a in agents:
		if a.was_hit or not dist.has(a.board_pos):
			continue
		if int(dist[a.board_pos]) < best_d:
			best_d = int(dist[a.board_pos])
			best = a
	return best

# A LOST BABY appears FAR from the player (`baby_far` of the farthest walking distance), on an empty
# floor cell not next to a monster, and arrives silently.
func _spawn_baby(now: float) -> void:
	if player == null:
		return
	var dist: Dictionary = _bfs_from(player.board_pos)
	var maxd: int = 0
	for v in dist.values():
		maxd = maxi(maxd, int(v))
	var cands: Array = []
	for c in dist.keys():
		var cell: Vector2i = c
		if int(dist[cell]) < int(float(maxd) * baby_far):
			continue
		var oc: OneCell = bcell(cell)
		if oc == null or not oc.is_fillable() or oc.pipe.is_wormhole():
			continue
		if _dist_from_agents(cell) < 3.0:
			continue
		cands.append(cell)
	if cands.is_empty():
		_next_baby_ms = now + 1500.0
		return
	baby_cell = cands[rng.randi_range(0, cands.size() - 1)]
	_baby_dist = int(dist[baby_cell])
	baby = BabyScript.new()
	baby.game = game
	baby.body_height = float(game.tile_size) * BABY_TILES
	baby.step_speed = float(game.tile_size) / (BABY_STEP_MS / 1000.0) * 0.9
	baby.position = game.board_to_px(baby_cell)
	baby.z_index = 3
	add_child(baby)
	baby_born_ms = now
	_baby_next_step_ms = now + BABY_STEP_MS
	hunter = null
	_babies_spawned += 1
	game.tutorial_notify("baby_appeared")

# The baby toddles to a neighboring cell now and then, never into a monster, and once it is being
# hunted it shies away from the hunter.
func _baby_wander() -> void:
	var opts: Array = []
	for k in 4:
		var q: Vector2i = baby_cell + DirArray[k]
		if not can_go_to(baby_cell, q):
			continue
		var oc: OneCell = bcell(q)
		if oc.has_agent:
			continue
		if hunter != null and float((q - hunter.board_pos).length()) < float((baby_cell - hunter.board_pos).length()):
			continue
		opts.append(q)
	if opts.is_empty() or rng.randf() < 0.35:
		return
	baby_cell = opts[rng.randi_range(0, opts.size() - 1)]
	baby.head_to(game.board_to_px(baby_cell))

func _check_mother_contact() -> void:
	if mother == null or not is_instance_valid(mother) or player == null or player.was_hit:
		return
	if player.position.distance_to(mother.position) < float(game.tile_size) * 0.8 or player.board_pos == mother_cell:
		gifts_taken += 1
		mother.leave()
		mother = null
		if not player.has_power:
			player.ate_power()
		game.play_sound("gift")
		game.tutorial_notify("gift_taken")

# The mother appears far from the player, like a baby, on an empty cell away from the monsters.
func _spawn_mother(now: float) -> void:
	var cell: Vector2i = _far_free_cell(0.40)
	if cell.x < 0:
		return
	mother_cell = cell
	mother = MotherScript.new()
	mother.game = game
	mother.body_height = float(game.tile_size) * MOTHER_TILES
	mother.life_ms = gift_ms
	mother.position = game.board_to_px(cell)
	mother.z_index = 3
	add_child(mother)
	_mother_born_ms = now
	game.tutorial_notify("mother_appeared")

# A free floor cell at least `far` of the farthest walking distance from the player, not a portal,
# not next to a monster, not where the baby is; (-1,-1) if there is none.
func _far_free_cell(far: float) -> Vector2i:
	if player == null:
		return Vector2i(-1, -1)
	var dist: Dictionary = _bfs_from(player.board_pos)
	var maxd: int = 0
	for v in dist.values():
		maxd = maxi(maxd, int(v))
	var cands: Array = []
	for c in dist.keys():
		var cell: Vector2i = c
		if int(dist[cell]) < int(float(maxd) * far) or cell == baby_cell:
			continue
		var oc: OneCell = bcell(cell)
		if oc == null or not oc.is_fillable() or oc.pipe.is_wormhole() or _dist_from_agents(cell) < 3.0:
			continue
		cands.append(cell)
	if cands.is_empty():
		return Vector2i(-1, -1)
	return cands[rng.randi_range(0, cands.size() - 1)]

func _check_baby_contact(now: float) -> void:
	if baby == null or not is_instance_valid(baby):
		return
	# a generous reach: touching the baby at all, or arriving in its cell, rescues it
	var reach: float = float(game.tile_size) * 0.75
	if player != null and not player.was_hit and (player.position.distance_to(baby.position) < reach or player.board_pos == baby_cell):
		_baby_rescued(now)
		return
	for a in agents:
		if not a.was_hit and a.position.distance_to(baby.position) < float(game.tile_size) * 0.5:
			_baby_lost(now, true)
			return

func _baby_rescued(now: float) -> void:
	var t: float = now - baby_born_ms
	rescue_times.append(t)
	game.record_trial({"dist": _baby_dist, "rescued": true, "ms": int(t)})
	_rescued_in_round += 1
	game.add_correct_or_mistake(1, 0)
	game.add_score_and_time(15, 0)
	game.play_sound("rescue")
	_float_text(baby.position, "Rescued! +15", Color(0.55, 1.0, 0.55))
	game.tutorial_notify("baby_rescued")
	# its mother comes out somewhere else, holding out a sword
	if mother == null and not game.tutorial_mode:
		_next_mother_ms = now + 700.0
	_end_baby(now)

func _baby_lost(now: float, taken: bool) -> void:
	_lost_in_round += 1
	game.record_trial({"dist": _baby_dist, "rescued": false, "ms": int(now - baby_born_ms)})
	game.add_correct_or_mistake(0, 1)
	if taken:
		game.play_sound("lost")
		_float_text(baby.position, "Lost!", Color(1.0, 0.5, 0.45))
	_end_baby(now)

func _end_baby(now: float) -> void:
	MainGlobals.global_update_hud()
	if baby != null and is_instance_valid(baby):
		baby.queue_free()
	baby = null
	hunter = null
	_next_baby_ms = now + rng.randf_range(4000.0, 8000.0)

func _spawn_banana(now: float) -> void:
	if player == null:
		return
	var dist: Dictionary = _bfs_from(player.board_pos)
	var maxd: int = 0
	for v in dist.values():
		maxd = maxi(maxd, int(v))
	var cands: Array = []
	for c in dist.keys():
		var cell: Vector2i = c
		if int(dist[cell]) < maxd / 3:
			continue
		var oc: OneCell = bcell(cell)
		if oc == null or not oc.is_fillable() or oc.pipe.has_coin >= 0 or cell == baby_cell:
			continue
		cands.append(cell)
	if cands.is_empty():
		return
	var cell2: Vector2i = cands[rng.randi_range(0, cands.size() - 1)]
	var node = BananaScript.new()
	node.size = float(game.tile_size) * 0.8
	node.life_ms = banana_ms
	node.born_ms = now
	node.now_ms = now
	node.position = game.board_to_px(cell2)
	node.z_index = 2
	add_child(node)
	_bananas.append({"node": node, "cell": cell2, "born": now})
	_bananas_spawned += 1

func _check_banana_contact() -> void:
	if player == null:
		return
	for b in _bananas.duplicate():
		var node: Node2D = b["node"]
		if player.position.distance_to(node.position) < float(game.tile_size) * 0.5:
			bananas_taken += 1
			game.add_score_and_time(5, 0)
			game.play_sound("delivery")
			_float_text(node.position, "Full!", Color(1.0, 0.92, 0.4))
			_restart_hunger(true)
			game.tutorial_notify("banana_taken")
			node.queue_free()
			_bananas.erase(b)

# A word that rises and fades where something happened.
func _float_text(at: Vector2, text: String, col: Color) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_theme_font_size_override("font_size", int(float(game.tile_size) * 0.55))
	lbl.z_index = 50
	add_child(lbl)
	lbl.reset_size()
	lbl.position = at - Vector2(lbl.size.x * 0.5, float(game.tile_size) * 0.9)
	var tw: Tween = create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - float(game.tile_size) * 0.8, 1.1)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.1).set_delay(0.4)
	tw.tween_callback(lbl.queue_free)

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
	var player_start: Vector2i = _room_center()
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

func _room_center() -> Vector2i:
	return room_rect.position + room_rect.size / 2

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
		_tick_hunger()

		if time_to_spawn_agent != 0 and MainGlobals.timems() > time_to_spawn_agent:
			time_to_spawn_agent = 0
			_spawn_agent(num_inside_monsters-1)
		if game.level_is_ready and not game.level_is_done and not in_answering_mode and not game.paused():
			_check_baby_contact(game.game_time)
			_check_mother_contact()
			_check_banana_contact()

# HUNGER: the player must keep eating, so the main task cannot be abandoned.
#
# The whole point of this game is what you notice at the EDGE of your attention while your hands
# are busy. Nothing used to keep them busy: a player could park in a corner, watch the gorillas
# and answer perfectly, and the count stopped measuring divided attention at all.
#
# The allowance is set from the BOARD, not from a clock. It is the walking time to the nearest
# remaining coin plus a base, so four coins in four corners at the end of a round give four
# generous windows rather than four death sentences. Set when a coin is eaten and never
# shortened afterwards — walking away from the nearest coin is the player's own choice, not a
# moving goalpost.
# ONE RING, ONE DEATH. An expired clock used to get a second chance, re-measured from where the
# player stood -- which meant the ring filled TWICE before a death, and a gauge that quietly
# restarts is worse than a tight one: it makes the whole graphic mean nothing. The allowance is
# generous instead, which is the honest way to be kind.
#
# The player walks a tile in `major_tick_time_ms / speed_scale` = 400ms, and crossing a 7x7 room
# is a dozen steps. Five seconds plus three times the walking time means anyone heading for food
# will reach it; standing still for six seconds will not.
const HUNGER_BASE_MS: int = 5000
# A BANANA fills the ring right up and buys at least this long, so the player can afford a trip far
# from the apples -- to a lost baby, or to its mother and her sword. (2026-11-09: the bananas were a
# five-point bonus with no purpose of their own.)
const BANANA_FULL_MS: int = 16000
# Manhattan distance under-counts a path that has to go round a wall, so the walking time is
# multiplied out. Generous on purpose: this is meant to keep the player moving, not to catch
# them out.
const HUNGER_SLACK: float = 3.0

var _hunger_started_ms: int = 0
var _hunger_window_ms: int = 0
var _hunger_paused_ms: int = 0
var _hunger_pause_began_ms: int = 0
var _was_warping: bool = false

func _step_ms() -> float:
	var scl: float = player.speed_scale if player != null else 1.0
	return float(game.major_tick_time_ms) * game.time_scale / maxf(scl, 0.01)

func _steps_to_nearest_coin() -> int:
	if player == null or coins.is_empty():
		return 0
	var best: int = 1 << 30
	for p: Vector2i in coins.keys():
		best = mini(best, absi(p.x - player.board_pos.x) + absi(p.y - player.board_pos.y))
	return 0 if best == (1 << 30) else best

# `full`: a banana -- the allowance is at least BANANA_FULL_MS, whatever the nearest apple.
func _restart_hunger(full: bool = false) -> void:
	_hunger_paused_ms = 0
	_hunger_pause_began_ms = 0
	if coins.is_empty():
		_hunger_window_ms = 0
		return
	_hunger_window_ms = HUNGER_BASE_MS \
		+ int(float(_steps_to_nearest_coin()) * _step_ms() * HUNGER_SLACK)
	if full:
		_hunger_window_ms = maxi(_hunger_window_ms, BANANA_FULL_MS)
	_hunger_started_ms = int(game.game_time)

# THE CLOCK ONLY RUNS WHILE THE PLAYER CAN ACTUALLY EAT.
#
# Two things stop it, and both are cases where the player has no way to reach a coin:
#
#   power    you are chasing monsters, not collecting, and a power coin that starved you would
#            be a trap rather than a reward.
#   warping  _move_player_on_tick() returns immediately while `player.warping`, so a coin cannot
#            be eaten at all — and a warp shrinks the player to a point, so it LOOKS like the
#            player is gone. Without this the first long warp near the end of a round starved
#            the player while they were mid-flight and the count question never arrived. The
#            power clock has always been paused across a warp for the same reason
#            (pause_power_clock); this one was not, which was the bug.
func _tick_hunger() -> void:
	if player == null or not is_instance_valid(player) or player.was_hit or player.arrived:
		return
	if game.level_is_done or not game.level_is_ready or in_answering_mode or game.paused():
		return
	if _hunger_window_ms <= 0 or coins.is_empty():
		player.set_hunger(1.0, false)
		return
	if player.has_power or player.warping:
		if _hunger_pause_began_ms == 0:
			_hunger_pause_began_ms = int(game.game_time)
		_was_warping = _was_warping or player.warping
	else:
		if _hunger_pause_began_ms > 0:
			_hunger_paused_ms += int(game.game_time) - _hunger_pause_began_ms
			_hunger_pause_began_ms = 0
		if _was_warping:
			# MEASURED FROM WHERE YOU LANDED. board_pos is still the near end while warp_to is
			# running, so the allowance can only be taken once the flight is over -- the coin
			# nearest the far end is a different coin, and a warp across the room would
			# otherwise leave someone else's walking time on the clock.
			_was_warping = false
			_restart_hunger()
			return

	var paused: int = _hunger_paused_ms
	if _hunger_pause_began_ms > 0:
		paused += int(game.game_time) - _hunger_pause_began_ms
	var elapsed: int = int(game.game_time) - _hunger_started_ms - paused
	var left: float = clampf(1.0 - float(elapsed) / float(_hunger_window_ms), 0.0, 1.0)
	player.set_hunger(left, true)
	if left <= 0.0:
		_lose_life("Starved!\nKeep eating. You can't stand still")

func _check_agent_collisions():
	if player == null or player.was_hit:
		return
	for a in agents:
		if a.was_hit:
			continue
		var d:float = (a.position - player.position).length()
		if d < 0.5 * game.tile_size:			
			if player.has_power:
				# Eating a monster does NOT spend the power. The power is a five-second window and
				# nothing but the clock closes it, so a well-timed run through a crowd is worth
				# more than one kill — which is the whole reason to chase the coin.
				a.mark_hit()
				time_to_spawn_agent = MainGlobals.timems() + 1000
				game.add_score_and_time(10, 0)
				game.play_sound("gulp")
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

	_tick_events(game.game_time)
	# The round is over when every apple is eaten AND every baby has been dealt with: a baby must
	# never be lost to the round simply ending under it. (The clock running out ends it regardless.)
	if coins.is_empty() and baby == null and _babies_spawned >= babies_per_round and not in_answering_mode:
		on_time_over()
		return

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
			var _qpipe = bcell(cpipe.warp_to_pos).pipe
			#print("target active ", _qpipe.is_wormhole_active(), " warping ", _qpipe.warping, "  has agent ", bcell(cpipe.warp_to_pos).has_agent)
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
			_restart_hunger()
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
	# walking distances from the player, worked out once per tick and only if a monster needs them
	var from_player: Dictionary = {}
	var have_from_player: bool = false
	for agent in agents:
		if not agent.need_to_major_tick():
			continue
		if agent.was_hit or agent.arrived:
			continue
		agent.set_major_tick_now()

		var p: Vector2i = agent.board_pos
		var dir: int = -1

		# the hunter goes for the baby, by the shortest way, most of the time
		if agent == hunter and baby != null and rng.randf() < hunt_chance:
			dir = _step_toward(p, baby_cell)
			if dir >= 0 and not _can_agent_go_to(p, p + DirArray[dir]):
				dir = -1
		elif player != null and rng.randf() < smart_chase:
			# A REAL CHASE (2026-11-11): the shortest way to the player through the maze, as the hunter
			# goes for a baby. Before this every monster's "chase" was the loose lean below, which a
			# wall stopped dead -- no level ever pursued the player. WHILE THE SWORD'S POWER IS ON it is
			# the other way round: the farthest step away (they never fled at all, and a real chase
			# would have walked them onto the sword).
			if not have_from_player:
				from_player = _bfs_from(player.board_pos)
				have_from_player = true
			dir = _step_by_distance(p, from_player, player.has_power)
		elif player != null and player.has_power:
			pass        # no loose lean toward a player who can eat you: wander
		elif rng.randf() < directed_chance and player != null:
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
	# a baby still out when the clock stops was not saved
	if baby != null:
		_baby_lost(game.game_time, false)
	_clear_events()

	var popup_text: String = _round_text()
	last_level_was_a_win = true
	game.level_is_done = true
	if game.tutorial_mode:
		game.show_game_popup(self, "Round over", popup_text)
		return
	round_in_level += 1
	if round_in_level >= rounds_per_level:
		_finish_level(popup_text)
	else:
		game.show_game_popup(self, "Round over", popup_text)

func _round_text() -> String:
	var n: int = _rescued_in_round + _lost_in_round
	if n == 0:
		return "No baby got lost this round"
	if _lost_in_round == 0:
		return "You rescued every baby!\n%d of %d" % [_rescued_in_round, n]
	return "Babies rescued: %d of %d" % [_rescued_in_round, n]

# A level is `rounds_per_level` rounds, and it is PASSED on the share of them counted exactly
# right. Below the bar the same level comes round again.
#
# Before this, a wrong answer simply did not count toward the level at all — round_in_level only
# advanced when need_to_increase_level had been set, which happened on an exact count. So the
# level could not be failed, only postponed, and the accuracy the player was shown decided
# nothing.
func _finish_level(round_text: String) -> void:
	var need: int = GorillaLevelConfig.pass_pct_for(level)
	var pct: int = game.session_pct_correct()
	var passed: bool = pct >= need
	var is_last: bool = level >= GorillaLevelConfig.LEVELS.size()
	game.need_to_increase_level = passed and not is_last
	_rollback_score_on_next_level = not passed
	_level_is_over = true
	# No fanfare over a level that was not passed.
	MainGlobals.global_level_is_done(passed)
	if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
		MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
	# The last round's verdict still gets said — it is the answer the player just gave — and then
	# the level's own tally underneath it.
	var textadd: String = "\n\n%s\n\nBabies rescued: %d of %d\nAverage time to a rescue: %s\n\n%s" % [
		round_text, game.corrects, game.corrects + game.mistakes,
		("%.1f s" % (float(mean_rescue_ms()) / 1000.0)) if not rescue_times.is_empty() else "-",
		_progress_line(passed, need, is_last)]
	game.show_level_done_popup(self, "", "", level, textadd, passed)

func _on_level_done_popup_closed() -> void:
	sig_level_is_done.emit(true)

# What the player gets next, in words. An accuracy figure alone does not say whether they are
# moving on, which is the only thing they want to know at that moment.
func _progress_line(passed: bool, need: int, is_last: bool) -> String:
	if not passed:
		return "You need to rescue at least %d%% of the babies to pass to the next level." % need
	if is_last:
		return "Level passed. This is the last level, so you'll play it again."
	return "Level passed. On to level %d." % (level + 1)

# Mean time from a baby's appearance to its rescue, this level (ms); 9999 when none was rescued.
func mean_rescue_ms() -> int:
	if rescue_times.is_empty():
		return 9999
	var t: float = 0.0
	for v in rescue_times:
		t += float(v)
	return roundi(t / float(rescue_times.size()))

func rescue_pct() -> int:
	var n: int = game.corrects + game.mistakes
	return 0 if n == 0 else roundi(100.0 * float(game.corrects) / float(n))

func on_lives_depleted():
	_level_done(false)

func _level_done(didwin: bool):
	last_level_was_a_win = didwin
	game.level_is_done = true
	game.stop_sound("feet")
	sig_level_is_done.emit(didwin)

# Counting the rounds is _on_answer_selected's job now; this only acts on the gate's verdict.
func _advance_if_needed() -> void:
	if game.need_to_increase_level:
		level = min(level + 1, GorillaLevelConfig.LEVELS.size())
	_apply_level()

func _reapply_level_after_player_created() -> void:
	var n_levels: int = GorillaLevelConfig.LEVELS.size()
	var cfg: Dictionary = GorillaLevelConfig.LEVELS[min(level, n_levels) - 1]
	agent_speed_max = cfg["agent_speed_max"] if player == null else min(cfg["agent_speed_max"], player.speed_scale - 0.2)

func _apply_level() -> void:
	var n_levels: int = GorillaLevelConfig.LEVELS.size()
	var cfg: Dictionary = GorillaLevelConfig.LEVELS[min(level, n_levels) - 1]
	cols = int(cfg["cols"])
	apples_in_round = int(cfg["apples"])
	round_sec = int(cfg["round_sec"])
	babies_per_round = int(cfg["babies"])
	baby_far = float(cfg["baby_far"])
	hunt_ms = float(cfg["hunt_ms"])
	hunt_chance = float(cfg["hunt_chance"])
	bananas_per_round = int(cfg["bananas"])
	banana_ms = float(cfg["banana_ms"])
	num_inside_monsters = cfg["num_inside_monsters"]
	extra_passages = cfg["extra_passages"]
	agent_speed_min = cfg["agent_speed_min"]
	agent_speed_max = cfg["agent_speed_max"] if player == null else min(cfg["agent_speed_max"], player.speed_scale - 0.2)
	directed_chance = cfg["directed_chance"]
	smart_chase = float(cfg.get("smart_chase", 0.0))
	rounds_per_level = cfg["rounds"]
	# the super-food apples were replaced by the mother's sword (2026-11-09)
	powers_in_level = 0
	gift_ms = float(cfg.get("gift_ms", 8000))	
	# THE MAZE FILLS THE SCREEN: `cols` across, and as many rows as the screen's shape gives at the
	# same cell size (desktop keeps a strip at the top for the level label).
	var vis_w: float = float(MainGlobals.screen_size.x)
	var vis_h: float = float(MainGlobals.screen_size.y - game.header_height - game.buttons_height) - (0.0 if MainGlobals.is_mobile() else 34.0)
	var rows: int = maxi(cols, int(floor(float(cols) * vis_h / vis_w)))
	game.forced_board_size = Vector2i(cols, rows)
	game.init_sizes()
	game.set_reset_time_left(round_sec)
	game.set_time_left(0, 0, round_sec)

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

# The lawn: ONE continuous field over the whole board (scripts/grass_field.gd), with the per-cell
# grass sprites hidden. Tiling — plain, rotated or drawn — is a mosaic of one image however it is
# arranged, and this game's cells were half of it.
#
# Called from _ready() once the board's geometry exists, and again at the START of create_board()
# so a level that changes the board size has its lawn before the cells go down. GrassField.fit()
# only re-sows when that size actually changed.
# The ground node is looked up with get_node_or_null because this script is not only on the
# level scene: storm's blackout.tscn carries a copy of it too, and a hard $ path there throws.
# (2026-10-30) The lawn's blades are then covered by a RAINFOREST FLOOR (forest_floor.gd): the field
# itself stays, sized and sown as before.
func _fit_ground_to_board() -> void:
	GrassField.fit(get_node_or_null("BgLayer"), get_node_or_null("BgLayer/BackgroundRect") as CanvasItem, game, 13)
	ForestFloor.lay(get_node_or_null("BgLayer"), 13)

# THE BOARD'S EDGE CASTS A SOFT SHADOW INWARD: a band along every side where floor meets anything that
# is not floor, fading out over WALL_SHADE of a tile, so the room reads as enclosed rather than a flat
# tile sheet on the lawn. On the floors' z (-1, pipe.gd), added after every tile: over the floor, under
# the apples and fences. Loops over the board array, not game.board_size (a rebuild resizes first).
const WALL_SHADE: float = 0.35
var _wall_shade: Node2D = null

func _add_wall_shade() -> void:
	if _wall_shade != null and is_instance_valid(_wall_shade):
		_wall_shade.queue_free()
	_wall_shade = Node2D.new()
	_wall_shade.z_index = -1
	_wall_shade.draw.connect(_draw_wall_shade.bind(_wall_shade))
	add_child(_wall_shade)
	if _rim != null and is_instance_valid(_rim):
		_rim.queue_free()
	_rim = Node2D.new()
	_rim.draw.connect(_draw_rim.bind(_rim))
	add_child(_rim)

# THE BOARD'S RIM: the temple's OUTER WALL (2026-11-12) -- the same mossy stone as the inner walls
# (_draw_temple_walls), centered on the edge where floor meets anything that is not floor, so it also
# covers the inner walls' ends where they meet it. It was a thin white bar (the old wall art's).
# The SAME thickness as the inner walls, shaded on all four sides like them (2026-11-12): at 8 against
# their 6, and with its sides left flat pale, the border read as twice as heavy as the maze inside it.
const RIM_W: float = TEMPLE_WALL  # (16, with walls of 13, was far too heavy; then 8, still too heavy)
var _rim: Node2D = null

func _draw_rim(node: Node2D) -> void:
	var t: float = float(game.tile_size)
	var h: float = RIM_W * 0.5
	var stone: Color = Color(0.82, 0.79, 0.71)
	var rim_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rim_rng.seed = 991
	for pass_i in 2:
		for y in board.size():
			for x in board[y].size():
				var cell: OneCell = board[y][x]
				if cell == null or not cell.ispipe:
					continue
				var c: Vector2 = game.board_to_px(Vector2i(x, y))
				for dv: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = Vector2i(x, y) + dv
					if q.y >= 0 and q.y < board.size() and q.x >= 0 and q.x < board[q.y].size() and board[q.y][q.x] != null and board[q.y][q.x].ispipe:
						continue
					var n: Vector2 = Vector2(dv)
					var side: Vector2 = Vector2(-n.y, n.x)
					var mid: Vector2 = c + n * t * 0.5
					var a0: Vector2 = mid + side * (t * 0.5 + h)
					var a1: Vector2 = mid - side * (t * 0.5 + h)
					var lo: Vector2 = Vector2(minf(a0.x, a1.x), minf(a0.y, a1.y)) - Vector2(absf(n.x), absf(n.y)) * h
					var hi: Vector2 = Vector2(maxf(a0.x, a1.x), maxf(a0.y, a1.y)) + Vector2(absf(n.x), absf(n.y)) * h
					var r: Rect2 = Rect2(lo, hi - lo)
					if pass_i == 0:
						node.draw_rect(Rect2(r.position + Vector2(2.0, 3.0), r.size), Color(0, 0, 0, 0.42))
						continue
					var k: float = rim_rng.randf_range(-0.04, 0.04)
					node.draw_rect(r, Color(stone.r + k, stone.g + k, stone.b + k))
					# a joint across it at the cell boundary, lit top and left, dark bottom and right
					node.draw_line(mid - side * t * 0.5 - n * h, mid - side * t * 0.5 + n * h, Color(0.30, 0.27, 0.22), 1.0)
					node.draw_rect(Rect2(r.position, Vector2(r.size.x, 1.4)), Color(0.96, 0.94, 0.88))
					node.draw_rect(Rect2(r.position, Vector2(1.0, r.size.y)), Color(0.66, 0.62, 0.53))
					node.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1.6), Vector2(r.size.x, 1.6)), Color(0.48, 0.44, 0.36))
					node.draw_rect(Rect2(r.position + Vector2(r.size.x - 1.0, 0), Vector2(1.0, r.size.y)), Color(0.52, 0.48, 0.40))
					node.draw_rect(r, Color(0.14, 0.11, 0.08, 0.9), false, 0.9)
					if rim_rng.randf() < 0.35:
						var pc: Vector2 = mid + side * rim_rng.randf_range(-t * 0.4, t * 0.4)
						node.draw_circle(pc, rim_rng.randf_range(1.8, 3.0), Color(0.26, 0.40, 0.16, 0.9))

func _draw_wall_shade(node: Node2D) -> void:
	var t: float = float(game.tile_size)
	var d: float = t * WALL_SHADE
	var dark: Color = Color(0.0, 0.0, 0.05, 0.28)
	var clear: Color = Color(0.0, 0.0, 0.05, 0.0)
	var shade_cols: PackedColorArray = PackedColorArray([dark, dark, clear, clear])
	for y in board.size():
		for x in board[y].size():
			var cell: OneCell = board[y][x]
			if cell == null or not cell.ispipe:
				continue
			var c: Vector2 = game.board_to_px(Vector2i(x, y))
			for dv: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + dv
				if q.y >= 0 and q.y < board.size() and q.x >= 0 and q.x < board[q.y].size() and board[q.y][q.x] != null and board[q.y][q.x].ispipe:
					continue
				var n: Vector2 = Vector2(dv)
				var side: Vector2 = Vector2(-n.y, n.x)
				var e0: Vector2 = c + n * t * 0.5 + side * t * 0.5
				var e1: Vector2 = c + n * t * 0.5 - side * t * 0.5
				node.draw_polygon(PackedVector2Array([e0, e1, e1 - n * d, e0 - n * d]), shade_cols)

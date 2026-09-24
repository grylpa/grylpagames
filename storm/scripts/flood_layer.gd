class_name StormFloodLayer
extends Node2D

# THE WATER ON THE FLOOR: one layer, not divided into tiles.
#
# Each leak's puddle (level.puddles(): one growing circle per leak) is drawn as a plain circle, every
# frame, at its current radius -- exact and smooth by construction. Per room:
#
#   Pool (CanvasGroup)   renders its children together into one layer before blending, so overlapping
#     Circles            circles merge into one body of water rather than stacking darker.
#   Rings                the drop rings at each leak dripping onto the floor.
#
# scenes/water.gdshader, on each Pool, colors the merged layer, finds its shoreline -- and keeps it
# to its ROOM'S FLOOR: every pixel looks up which tile it is on in `floor_mask` (one texel per tile:
# the room id + 1 where the tile is floor, 0 anywhere water can never be -- walls, bricks and drains,
# level._is_floor(); a doorway is floor), and anything but this room's floor is dropped. So the water stops exactly
# at their edges and never reaches another room. The shader knows each pixel's tile from the group's
# own geometry, so the camera moving needs nothing from here.
#
# The mask is in the shader, not a clip node, for a measured reason: a room's floor drawn as a
# clip_children parent around the CanvasGroup was copied INTO the group's layer, so the group read the
# floor as water and filled its bounding square -- a circle of radius 3.2 reached 4.6 tiles on the
# diagonals.
#
# It replaced a shader that tested circles per pixel through a per-tile lookup texture. That lookup
# was the source of every problem the water had -- circles drawn as polygons, dry notches where three
# puddles met, growth in steps -- and each fix added another layer to it.
#
# Added after every tile, at z -1: the tiles' floor sprites are z -1 too and draw first by tree
# order; everything standing on the floor (bricks, furniture, tools, doors, the player) is above.

const WATER: Color = Color(0.15, 0.45, 0.95, 0.85)
const RING: Color = Color(0.9, 0.96, 1.0)
const DROP_SLOT: float = 1.6        # seconds: each slot holds one drop or, a third of the time, none
const RING_LIFE: float = 1.1
const RING_SPEED: float = 0.42      # tiles a second

var _level: Node = null
var _board: Array = []
var _tiles: Vector2i = Vector2i.ONE
var _tile_px: float = 40.0
var _rooms: Dictionary = {}         # room id -> {"clip", "circles", "rings"}
var _pds: Array = []

func setup(level: Node, board: Array, tiles: Vector2i, tile_px: float, top_left: Vector2) -> void:
	_level = level
	_board = board
	_tiles = tiles
	_tile_px = tile_px
	z_index = -1
	position = top_left
	var shader: Shader = load("res://storm/scenes/water.gdshader")
	var mask: Image = Image.create_empty(tiles.x, tiles.y, false, Image.FORMAT_R8)
	for y in tiles.y:
		for x in tiles.x:
			var cell = board[y][x]
			var v: int = 0
			if level.call("_is_floor", cell) and int(cell.room_id) >= 0:
				v = int(cell.room_id) + 1
			mask.set_pixel(x, y, Color8(v, 0, 0))
	var mask_tex: ImageTexture = ImageTexture.create_from_image(mask)
	for room in floor_rooms():
		var pool: CanvasGroup = CanvasGroup.new()
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("water_color", WATER)
		mat.set_shader_parameter("floor_mask", mask_tex)
		mat.set_shader_parameter("room_code", float(room + 1))
		mat.set_shader_parameter("board_tiles", Vector2(tiles))
		mat.set_shader_parameter("tile_px", tile_px)
		pool.material = mat
		# Room for the shoreline shader to look a few pixels past the water's edge.
		pool.fit_margin = 8.0
		pool.clear_margin = 8.0
		add_child(pool)
		var circles: Node2D = Node2D.new()
		var rid: int = room
		circles.draw.connect(func() -> void: _draw_circles(circles, rid))
		pool.add_child(circles)
		var rings: Node2D = Node2D.new()
		rings.draw.connect(func() -> void: _draw_rings(rings, rid))
		add_child(rings)
		_rooms[room] = {"pool": pool, "circles": circles, "rings": rings}

# Every room that has floor.
func floor_rooms() -> Array:
	var out: Array = []
	for y in _tiles.y:
		for x in _tiles.x:
			var cell = _board[y][x]
			if _level.call("_is_floor", cell) and int(cell.room_id) >= 0 and not out.has(int(cell.room_id)):
				out.append(int(cell.room_id))
	return out

# The floor of one room as rects in this node's space, a row of floor tiles at a time -- exactly the
# tiles water may cover. Anything that is not floor is left out, so it is left dry.
func room_floor_rects(room: int) -> Array:
	var out: Array = []
	for y in _tiles.y:
		var run: int = -1
		for x in _tiles.x + 1:
			var ok: bool = false
			if x < _tiles.x:
				var cell = _board[y][x]
				ok = _level.call("_is_floor", cell) and int(cell.room_id) == room
			if ok and run < 0:
				run = x
			elif not ok and run >= 0:
				out.append(Rect2(Vector2(run, y) * _tile_px, Vector2(x - run, 1) * _tile_px))
				run = -1
	return out

func _process(_delta: float) -> void:
	_pds = _level.call("puddles") if _level != null else []
	visible = not _pds.is_empty()
	for room in _rooms:
		(_rooms[room]["circles"] as Node2D).queue_redraw()
		(_rooms[room]["rings"] as Node2D).queue_redraw()

func _draw_circles(ci: Node2D, room: int) -> void:
	for pd: Dictionary in _pds:
		if int(pd["room"]) != room:
			continue
		ci.draw_circle((pd["center"] as Vector2) * _tile_px, float(pd["r"]) * _tile_px, Color.WHITE, true, -1.0, true)

# Single drops with pauses, not a wave, each drip on its own rhythm; kept to the leak's own tile.
func _draw_rings(ci: Node2D, room: int) -> void:
	var t: float = StormG.game.game_time / 1000.0 if StormG.game != null else 0.0
	for pd: Dictionary in _pds:
		if int(pd["room"]) != room or not bool(pd["drip"]):
			continue
		var ctr: Vector2 = (pd["center"] as Vector2) * _tile_px
		var sd: float = _hash(ctr.x * 3.7 + ctr.y * 11.3) * 40.0
		var tt: float = t + sd * 1.7
		var k: float = floor(tt / DROP_SLOT)
		for i in 2:
			var kk: float = k - float(i)
			if _hash(kk * 1.31 + sd) < 0.33:
				continue        # a slot with no drop in it: the pause
			var age: float = tt - (kk * DROP_SLOT + _hash(kk + sd * 7.1) * (DROP_SLOT - 0.3))
			if age <= 0.0 or age >= RING_LIFE:
				continue
			var life: float = 1.0 - age / RING_LIFE
			var col: Color = RING
			col.a = 0.55 * life
			ci.draw_arc(ctr, age * RING_SPEED * _tile_px, 0.0, TAU, 32, col, 1.5, true)
			col.a = 0.3 * life
			ci.draw_arc(ctr, age * RING_SPEED * 0.62 * _tile_px, 0.0, TAU, 24, col, 1.2, true)
			if age < 0.25:
				col.a = 0.6 * (1.0 - age / 0.25)
				ci.draw_circle(ctr, 0.035 * _tile_px, col)

func _hash(n: float) -> float:
	var v: float = sin(n * 12.9898) * 43758.5453
	return v - floor(v)

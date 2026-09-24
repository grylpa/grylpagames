extends Area2D

signal pipe_pressed(_board_pos)

var board_pos := Vector2i.ZERO
var game:GenericGameUtil
var has_brick := -1
var has_coin := -1
var time_started_water:float = 0
var water_active := false
var water_rate:float = 1.0
# How fast the leak pours, in tiles a second: BASE_WATER_RATE times the level's fill_rate
# (StormLevelConfig), set by level.gd when the tile is made. Tools fill at the same rate.
const BASE_WATER_RATE: float = 0.01
var water_rate_factor:float = BASE_WATER_RATE
var action:String = ""
var bricks:Array[Sprite2D] = []
var active_brick = null
var water_color:Color = Color.from_rgba8(0,148,255,255)
var action_texture:Array = []
var overflow_level:float = 0
var action_level:float = 0
var action_full := false
var is_drain := false

var furniture_value:int = 0
# FURNITURE IS RUINED WHEN A PUDDLE COVERS MOST OF ITS TILE (level.FURNITURE_RUIN), not the moment
# the floor is damp: a leak can start right on a rug, and that must leave time to get a tool under
# it. See level._check_floods().
var furniture_ruined: bool = false
# Where this leak's water went, in tile-fulls. Every active leak drips at the same rate; what it
# drips either lands in a tool (or is stopped by tape) or reaches the floor, and that split is what
# decides the round -- see level.gd's rain_stats().
var leaked_total: float = 0.0
var floored_total: float = 0.0
# Counted once in the stats as "water reached the floor", when this leak's puddle first shows.
var counted_on_floor: bool = false
# THE WATER IS NOT DRAWN HERE. It is drawn by the board-wide StormFloodLayer, one puddle per leak,
# from the levels of the wet tiles around it. It used to be a sprite on this tile, clipped to it, so
# a puddle could only grow into this square before any of it showed next door.
var _drip_offset: Vector2 = Vector2.ZERO
# The five tools StormToolArt draws stand on the tile as this, instead of %ActionTexture.
var _tool_draw: Node2D = null
var _tool_fill_drawn: float = -1.0

func _ready() -> void:
	game = StormG.game
	bricks = [$PipeBrick1, $PipeBrick2, $PipeBrick3]
	_drip_offset = Vector2(randf_range(-0.14, 0.14), randf_range(-0.14, 0.14))
	# The floor goes UNDER the flood layer (z -1, drawn after every tile), and everything standing on
	# the floor -- bricks, furniture, tools, coins -- stays above it at z 0.
	for n: Node2D in [$PipeImageLR, $PipeImageNoDir, $PipeImage4, $PipeImageURD, $PipeImageRD,
			$PipeFloor1, $PipeFloor2]:
		n.z_index = -1
	_tool_draw = Node2D.new()
	_tool_draw.visible = false
	_tool_draw.draw.connect(func() -> void:
		if action == "drain":
			StormToolArt.draw_drain(_tool_draw, Vector2.ZERO, float(game.tile_size))
		else:
			StormToolArt.draw_tool(_tool_draw, action, Vector2.ZERO, 38.0, _tool_fill()))
	add_child(_tool_draw)

func can_fill():
	return has_brick < 0 and has_coin < 0 and !is_drain

func set_coin():
	if has_coin < 0:
		$PipeCoin1.hide()
	else:
		$PipeCoin1.show()
		var coin_text = str(has_coin)
		%CoinLabelShadow.text = coin_text
		%CoinLabelText.text = coin_text

func start_leak():
	if !water_active:
		time_started_water = game.game_time
		water_active = true

# Where this leak's drip lands, in tiles from the tile's center: a little off the middle. The flood
# layer centers the leak's puddle here.
func drip_offset() -> Vector2:
	return _drip_offset

# A drip is landing on the floor here: a leak with nothing catching it.
func is_dripping() -> bool:
	if not water_active:
		return false
	return action.is_empty() or action_full

func disp_water():
	if water_active:
		var mat: ShaderMaterial = null
		if _tool_draw != null and _tool_draw.visible and absf(_tool_fill() - _tool_fill_drawn) > 0.004:
			_tool_fill_drawn = _tool_fill()
			_tool_draw.queue_redraw()
		if action_texture != null and action_texture.size() > 0 and %ActionTexture.visible:
			mat = %ActionTexture.material as ShaderMaterial
			mat.set_shader_parameter("fill_amount", clamp(action_level, 0.0, overflow_level))

var last_game_time:float = 0.0

func _process(_delta):
	var dt:float = 0
	if last_game_time > 1e-6:
		dt = game.game_time - last_game_time
	last_game_time = game.game_time
	pour(dt * water_rate * water_rate_factor / 1000.0)
	disp_water()

# `amount` of water from this leak, in tile-fulls: into the tool under it, or onto the floor.
func pour(amount: float) -> void:
	var dt: float = amount
	if water_active:
		leaked_total += dt
		if action.is_empty() or (action_level >= overflow_level - 1e-6 and overflow_level > 1e-3):
			# Water on the floor: this leak's puddle (level.puddles()) is sized from it.
			floored_total += dt
			if not action.is_empty() and overflow_level > 1e-3 and not action_full:
				action_full = true
				game.add_score_and_time(-1, 0)
		else:
			if action in ["fix", "drain"]:
				action_level = 0
			else:
				action_level = min(overflow_level, dt + action_level)

func set_rot(board):
	var p = board_pos
	set_coin()
	if board[p.y][p.x].room_id >= 0:
		# var color = Color.from_rgba8(165,165,165,255)
		var color = game.color_by_index(board[p.y][p.x].room_id).lightened(0.5)
		$PipeFloor2.modulate = color
	else:
		$PipeFloor1.hide()
		$PipeFloor2.hide()
		$PipeImageNoDir.show()

	if has_brick >= 0 and !bricks.is_empty():
		if active_brick == null:
			seed(MainGlobals.timeus())
			active_brick = bricks[has_brick % bricks.size()]
			_fill_tile(active_brick)
			active_brick.show()

# A BRICK FILLS ITS TILE. The water stops at the edge of a tile it cannot enter, and the brick art
# has a margin inside its 40 px, so a strip of floor showed between the two. The art is shared with
# other games and left alone: this crops the sprite to the part of the image actually drawn
# (Image.get_used_rect, measured here at runtime) and stretches that to the whole tile, a hair over
# so no seam shows against the water.
func _fill_tile(sp: Sprite2D) -> void:
	if sp.texture == null:
		return
	var img: Image = sp.texture.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return
	var tile: float = float(game.tile_size) + 0.6
	sp.region_enabled = true
	sp.region_rect = Rect2(used)
	sp.scale = Vector2(tile / float(used.size.x), tile / float(used.size.y))

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_released("lclick") and not MainGlobals.swipe_was_drag:
		pipe_pressed.emit(board_pos)

func _tool_fill() -> float:
	return action_level / overflow_level if overflow_level > 1e-3 else 0.0

func set_action(_action:String, _texture:Array, _action_level:float, _overflow_level:float):
	action_full = false
	action = _action
	action_texture = _texture
	var drawn: bool = StormToolArt.draws(_action) or _action == "drain"
	if _tool_draw != null:
		_tool_draw.visible = drawn
	if drawn:
		action_level = _action_level
		overflow_level = _overflow_level
		%ActionTexture.hide()
		_tool_fill_drawn = -1.0
		if _tool_draw != null:
			_tool_draw.queue_redraw()
	elif _texture != null and _texture.size() > 0:
		action_level = _action_level
		%ActionTexture.visible = true
		%ActionTexture.texture = action_texture[0]
		%ActionTexture.material = %ActionTexture.material.duplicate()
		var mat = %ActionTexture.material as ShaderMaterial
		mat.set_shader_parameter("mask_tex", action_texture[1] if action_texture.size() > 1 else action_texture[0])
	else:
		%ActionTexture.hide()
	
	if _action.is_empty():
		%Text.hide()
		%Text.text = ""
	else:
		%Text.text = _action.to_upper()[0]
		%Text.visible = _texture == null
		time_started_water = game.game_time
		overflow_level = _overflow_level
		if action == "drain":
			is_drain = true

func set_furniture(_texture:Texture2D, _val:int, _modulate:Color):
	$Furniture.show()
	$Furniture.texture = _texture
	$Furniture.modulate = _modulate
	furniture_value = _val

# Soaked through: dark and dull, so it reads as lost from across the room.
func ruin_furniture() -> void:
	furniture_ruined = true
	var m: Color = $Furniture.modulate
	var grey: float = (m.r + m.g + m.b) / 3.0
	$Furniture.modulate = Color(lerpf(m.r, grey, 0.7) * 0.45, lerpf(m.g, grey, 0.7) * 0.45,
		lerpf(m.b, grey, 0.7) * 0.5, maxf(m.a, 0.75))
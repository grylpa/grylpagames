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
			StormToolArt.draw_tool(_tool_draw, action, Vector2.ZERO, 38.0, _tool_fill(), true))
	add_child(_tool_draw)
	# the floor tile and the furniture are drawn (room_art.gd); their sprites stay for visibility,
	# placement and the room's tint, with their own pixels hidden
	# the room's floor (room_floor.gdshader): this tile's own copy of the material, told its cell and the
	# room's kind in set_rot; the room's color is the sprite's tint
	if _floor_mat_base == null:
		_floor_mat_base = ShaderMaterial.new()
		_floor_mat_base.shader = preload("res://storm/scripts/room_floor.gdshader")
	_floor_mat = _floor_mat_base.duplicate() as ShaderMaterial
	$PipeFloor2.material = _floor_mat
	_furniture_art = Node2D.new()
	_furniture_art.draw.connect(func() -> void:
		StormRoomArt.draw_furniture(_furniture_art, _furniture_kind, furniture_ruined))
	_furniture_art.visible = false
	_furniture_art.scale = Vector2(1.3, 1.3)     # most of the tile, so a piece reads at a glance
	add_child(_furniture_art)
	move_child(_furniture_art, $Furniture.get_index() + 1)

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
	# Redrawn on ANY change of fill, not only under a leak: a towel soaks up a puddle with no leak of
	# its own over it (level._soak_towels).
	if _tool_draw != null and _tool_draw.visible and absf(_tool_fill() - _tool_fill_drawn) > 0.004:
		_tool_fill_drawn = _tool_fill()
		_tool_draw.queue_redraw()
	if water_active:
		var mat: ShaderMaterial = null
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
				# A tool left to overflow: -1, kept with the round's other score parts (level._add_points).
				var lvl: Node = get_parent()
				if lvl != null and lvl.has_method("_add_points"):
					lvl.call("_add_points", "overflowed", -int(lvl.get("OVERFLOW_POINTS")))
				else:
					game.add_score_and_time(-1, 0)
		else:
			if action in ["fix", "drain"]:
				action_level = 0
			else:
				action_level = min(overflow_level, dt + action_level)

const CORRIDOR_STONE: Color = Color(0.46, 0.44, 0.41)
# [kind, checker] per room, in turn: marble, ceramic, marble, terracotta, CHECKER marble, ceramic
const FLOOR_PLAN: Array = [[0, 0], [1, 0], [0, 0], [2, 0], [0, 1], [1, 0]]
static var _floor_mat_base: ShaderMaterial = null
var _floor_mat: ShaderMaterial = null
var _floor_kind: int = -1          # the room's floor (room_floor.gdshader kind); -1 a corridor

func set_rot(board):
	var p = board_pos
	set_coin()
	# the room's floor, by room: mostly even MARBLE, glazed CERAMIC and TERRACOTTA; a CHECKER of marble
	# in one room in six (room_floor.gdshader)
	var rid: int = int(board[p.y][p.x].room_id)
	var kind: int = int(FLOOR_PLAN[posmod(rid, FLOOR_PLAN.size())][0]) if rid >= 0 else -1
	var checker: float = float(FLOOR_PLAN[posmod(rid, FLOOR_PLAN.size())][1]) if rid >= 0 else 0.0
	_floor_kind = kind
	if _floor_mat != null:
		_floor_mat.set_shader_parameter("cell", Vector2(p))
		_floor_mat.set_shader_parameter("kind", maxi(kind, 0))
		_floor_mat.set_shader_parameter("checker", checker)
	if board[p.y][p.x].room_id >= 0:
		# var color = Color.from_rgba8(165,165,165,255)
		# DEEP like Mind Palace's (darkened, not lightened): on pastel floors (lightened(0.5)) the marble's
		# pale veins, bevels and sheen hardly showed, and the same shader looked flat ("why are Mind
		# Palace's floors so much prettier?"). level.floor_color_at() is told the same.
		var color = game.color_by_index(board[p.y][p.x].room_id).darkened(0.2)
		$PipeFloor2.modulate = color
	else:
		# a CORRIDOR: the same marble in warm gray, as Mind Palace's (it was a photo of gray marble)
		$PipeFloor1.hide()
		$PipeFloor2.show()
		$PipeFloor2.modulate = CORRIDOR_STONE
		$PipeImageNoDir.hide()

	# a "brick" is drawn as household furniture: a bookcase, an armchair or a cabinet (home_prop.gd),
	# filling its tile; the brick sprites stay hidden
	if has_brick >= 0 and active_brick == null:
		var prop: StormHomeProp = StormHomeProp.new()
		prop.kind = has_brick % 3
		prop.z_index = 2
		add_child(prop)
		active_brick = prop

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

var _furniture_art: Node2D = null
var _furniture_kind: String = ""

func set_furniture(_texture:Texture2D, _val:int, _modulate:Color):
	# drawn (room_art.gd) from which picture this is; the sprite only carries the texture
	$Furniture.texture = _texture
	$Furniture.modulate = _modulate
	$Furniture.hide()
	_furniture_kind = _texture.resource_path.get_file().get_basename()
	_furniture_art.visible = true
	_furniture_art.queue_redraw()
	furniture_value = _val

# Soaked through: dark and dull, so it reads as lost from across the room.
func ruin_furniture() -> void:
	furniture_ruined = true
	if _furniture_art != null:
		_furniture_art.queue_redraw()
	var m: Color = $Furniture.modulate
	var grey: float = (m.r + m.g + m.b) / 3.0
	$Furniture.modulate = Color(lerpf(m.r, grey, 0.7) * 0.45, lerpf(m.g, grey, 0.7) * 0.45,
		lerpf(m.b, grey, 0.7) * 0.5, maxf(m.a, 0.75))
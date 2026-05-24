extends Area2D

signal pipe_pressed(_board_pos)
signal sig_leak_overflow(_pipe)

var board_pos := Vector2i.ZERO
var game:GenericGameUtil
var has_brick := -1
var has_coin := -1
var water_level:float = 0
var time_started_water:float = 0
var water_active := false
var water_rate:float = 1.0
var water_rate_factor:float = 0.01
var water_overflowed := false
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

var water_mask := preload("res://storm/art/rect_water_white.png")

@onready var water := $Water

func _ready() -> void:
	game = StormG.game
	bricks = [$PipeBrick1, $PipeBrick2, $PipeBrick3]
	water.material = water.material.duplicate()
	# %Water.modulate = water_color

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

func disp_water():
	if water_active:		
		%Water.visible = true		
		var mat := water.material as ShaderMaterial
		mat.set_shader_parameter("fill_amount", clamp(water_level, 0.05, 1.0))
		if action_texture != null and action_texture.size() > 0:
			mat = %ActionTexture.material as ShaderMaterial
			mat.set_shader_parameter("fill_amount", clamp(action_level, 0.0, overflow_level))

		# var w = game.tile_size * water_level
		# var r = Rect2(0, 0, game.tile_size, w)
		# %Water.region_rect = r
		if water_level >= 1.0 - 1e-6 and !water_overflowed:
			water_overflowed = true
			sig_leak_overflow.emit(self)

var last_game_time:float = 0.0

func _process(_delta):
	var dt:float = 0
	if last_game_time > 1e-6:
		dt = game.game_time - last_game_time
	last_game_time = game.game_time
	dt *= water_rate * water_rate_factor / 1000.0
	if water_active:
		if action.is_empty() or (action_level >= overflow_level - 1e-6 and overflow_level > 1e-3):
			if not action.is_empty() and overflow_level > 1e-3 and not action_full:
				action_full = true
				game.add_score_and_time(-1, 0)
			water_level = min(1.0, dt + water_level)
		else:
			if action in ["fix", "drain"]:
				action_level = 0
			else:
				action_level = min(overflow_level, dt + action_level)
	disp_water()

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
			active_brick.show()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_released("lclick") and not MainGlobals.swipe_was_drag:
		pipe_pressed.emit(board_pos)

func set_action(_action:String, _texture:Array, _action_level:float, _overflow_level:float):
	action_full = false
	action = _action
	action_texture = _texture
	if _texture != null and _texture.size() > 0:
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
			%ActionTexture.rotation = game.rng.randf_range(0, 6.28)

func set_furniture(_texture:Texture2D, _val:int, _modulate:Color):
	$Furniture.show()
	$Furniture.texture = _texture
	$Furniture.modulate = _modulate
	furniture_value = _val
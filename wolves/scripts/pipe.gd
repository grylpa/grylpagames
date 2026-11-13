extends Area2D

signal pipe_pressed(_board_pos)

var board_pos := Vector2i.ZERO
var game:GenericGameUtil
var has_brick := -1
var has_coin := -1
var is_grass := false
var fences := [false, false, false, false]	# right,bottom,left,top

var bricks:Array[Sprite2D] = []

var active_brick = null

static var _pasture: ShaderMaterial = null

func _ready() -> void:
	game = WolvesG.game
	bricks = [$PipeBrick1, $PipeBrick2, $PipeBrick3]
	# the field is a mown pasture (pasture.gdshader); the compound keeps its per-level color
	if _pasture == null:
		_pasture = ShaderMaterial.new()
		_pasture.shader = preload("res://wolves/scripts/pasture.gdshader")
	$PipeImageNoDir.material = _pasture
	# the mown squares are laid on the cells (pasture.gdshader): where cell (0, 0) begins, and its size
	var t: float = float(game.tile_size)
	_pasture.set_shader_parameter("origin", game.board_to_px(Vector2i.ZERO) - Vector2(t, t) * 0.5)
	_pasture.set_shader_parameter("tile", t)
	# the sheep pen's floor (pen_floor.gdshader): this tile's own material, told its cell in set_rot
	var pm: ShaderMaterial = ShaderMaterial.new()
	pm.shader = preload("res://wolves/scripts/pen_floor.gdshader")
	$PipeFloor2.material = pm

# Inside the fence the ground is a flat WASH over the lawn, not a grass sprite.
#
# The lawn behind the whole board is one continuous field (scripts/grass_field.gd). This cell used
# to lay a randomly ROTATED copy of the same grass.png on top of it and tint it green, which is a
# mosaic twice over: the rotation breaks the tile's own seamless wrap, and the tile is the thing
# the field replaced. All the tint was ever saying is "this side of the fence is the farm", so
# that is all that is left — a translucent green over the real grass, which reads as shade rather
# than as a second, differently-lit lawn.
#
# Drawn by the pipe itself so it sits UNDER the bricks, coins and fences, which are its children.
const FIELD_WASH: Color = Color(0.13, 0.35, 0.14, 0.30)

func _draw() -> void:
	if not is_grass:
		return
	var t: float = float(game.tile_size)
	draw_rect(Rect2(-t * 0.5, -t * 0.5, t, t), FIELD_WASH)

func can_fill():
	return has_brick < 0 and has_coin < 0

func set_coin():
	if has_coin < 0:
		$PipeCoin1.hide()
	else:
		$PipeCoin1.show()
		var coin_text = str(has_coin)
		%CoinLabelShadow.text = coin_text
		%CoinLabelText.text = coin_text

func set_rot(board):
	var p = board_pos
	set_coin()
	if board[p.y][p.x].room_id >= 0:
		# the pen: trampled earth and straw (pen_floor.gdshader); it was a flat square in a color per level
		$PipeFloor2.modulate = Color.WHITE
		if $PipeFloor2.material is ShaderMaterial:
			($PipeFloor2.material as ShaderMaterial).set_shader_parameter("cell", Vector2(p))
		# if active_brick != null:
		# 	active_brick.hide()
		# return
	else:
		$PipeFloor1.hide()
		$PipeFloor2.hide()
		$PipeImageNoDir.show()

	# a "brick" is drawn as a farm thing: a hay bale, a boulder or a water trough (farm_prop.gd); the
	# brick sprites stay hidden. Still a brick to the game.
	if has_brick >= 0 and active_brick == null:
		var prop: WolvesFarmProp = WolvesFarmProp.new()
		prop.kind = game.rng.randi_range(0, 2)
		prop.seed_v = p.x * 31 + p.y * 7
		add_child(prop)
		active_brick = prop

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		pipe_pressed.emit(board_pos)

func show_path(_timeout_ms := 3000):
	$PipeCoin1.show()
	await MainGlobals.sleep(_timeout_ms / 1000)
	$PipeCoin1.hide()

extends Area2D

signal pipe_pressed(_board_pos)

var board_pos := Vector2i.ZERO
var game:GenericGameUtil
var has_brick := -1
var has_coin := -1

var bricks:Array[Sprite2D] = []

var active_brick = null

# The palace's floor (2026-11-12, castle_floor.gdshader): ONE material for every room and corridor tile,
# the room's color its tint. Corridors are the same stone in warm gray.
static var _floor_mat: ShaderMaterial = null
var _mat: ShaderMaterial = null
const CORRIDOR_STONE: Color = Color(0.44, 0.42, 0.40)      # (0.60 stood out pale against the rooms)

func _ready() -> void:
	game = MmmG.game
	bricks = [$PipeBrick1, $PipeBrick2, $PipeBrick3]
	# The floor itself one step down, so the level's wall shading (level._add_wall_shade) can lie
	# over the floor and under the coin and the bricks.
	for fl: Sprite2D in [$PipeImageLR, $PipeImageNoDir, $PipeImage4, $PipeImageURD, $PipeImageRD, $PipeFloor1, $PipeFloor2]:
		fl.z_index = -1
	# its OWN copy of the material: the shader is told this tile's board cell (set_rot), and lays its
	# pattern from that -- see castle_floor.gdshader for why not from the node's matrix
	if _floor_mat == null:
		_floor_mat = ShaderMaterial.new()
		_floor_mat.shader = preload("res://mmm/scripts/castle_floor.gdshader")
	_mat = _floor_mat.duplicate() as ShaderMaterial
	$PipeFloor2.material = _mat
	$PipeImageNoDir.material = _mat

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
	if _mat != null:
		_mat.set_shader_parameter("cell", Vector2(board_pos))
	set_coin()
	if board[p.y][p.x].room_id >= 0:
		if game != null and game.zoomed_in:
			$PipeFloor2.modulate = game.color_by_index(board[p.y][p.x].room_id).darkened(0.3)
		else:
			if board[p.y][p.x].color_idx >= 0:
				$PipeFloor2.modulate = game.color_by_index(board[p.y][p.x].color_idx)
			else:
				$PipeFloor2.modulate = Color.from_rgba8(65,65,65,255)
			if active_brick != null:
				active_brick.hide()
			# $PipeCoin1.hide()
			return
	else:
		$PipeFloor1.hide()
		$PipeFloor2.hide()
		$PipeImageNoDir.show()
		$PipeImageNoDir.modulate = CORRIDOR_STONE

	# a "brick" is drawn as a castle prop: a pillar, a barrel or a crate (castle_prop.gd); the brick
	# sprites stay hidden
	if has_brick >= 0:
		if active_brick == null:
			var prop: MmmCastleProp = MmmCastleProp.new()
			prop.kind = has_brick % 3
			add_child(prop)
			active_brick = prop
	# modulate = Color.from_rgba8(65,65,65,255)

	# var r = p.x+1 < game.board_size.x and board[p.y][p.x+1].ispipe
	# var d = p.y+1 < game.board_size.y and board[p.y+1][p.x].ispipe
	# var l = p.x > 0 and board[p.y][p.x-1].ispipe
	# var u = p.y > 0 and board[p.y-1][p.x].ispipe
	# $PipeImageLR.show()
	# if d and u and r and l:
	# 	$PipeImageLR.hide()
	# 	$PipeImage4.show()
	# elif d and r and l:
	# 	$PipeImageLR.hide()
	# 	$PipeImageURD.show()
	# 	$PipeImageURD.rotation = PI/2.0
	# elif d and r and u:
	# 	$PipeImageLR.hide()
	# 	$PipeImageURD.show()
	# 	$PipeImageURD.rotation = 0
	# elif u and r and l:
	# 	$PipeImageLR.hide()
	# 	$PipeImageURD.show()
	# 	$PipeImageURD.rotation = -PI/2.0
	# elif d and l and u:
	# 	$PipeImageLR.hide()
	# 	$PipeImageURD.show()
	# 	$PipeImageURD.rotation = PI		
	# elif d and u:
	# 	$PipeImageLR.rotation = PI/2.0
	# elif r and l:
	# 	$PipeImageLR.rotation = 0
	# elif d and r:
	# 	$PipeImageLR.hide()
	# 	$PipeImageRD.show()
	# 	$PipeImageRD.rotation = 0
	# elif d and l:
	# 	$PipeImageLR.hide()
	# 	$PipeImageRD.show()
	# 	$PipeImageRD.rotation = PI/2.0
	# elif u and l:
	# 	$PipeImageLR.hide()
	# 	$PipeImageRD.show()
	# 	$PipeImageRD.rotation = PI
	# elif u and r:
	# 	$PipeImageLR.hide()
	# 	$PipeImageRD.show()
	# 	$PipeImageRD.rotation = -PI/2.0
	# elif d or u:
	# 	$PipeImageLR.rotation = PI/2.0
	# elif r or l:
	# 	$PipeImageLR.rotation = 0


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		pipe_pressed.emit(board_pos)

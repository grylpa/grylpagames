extends Area2D

signal pipe_pressed(_board_pos)

var board_pos := Vector2i.ZERO
var game:GenericGameUtil
var has_brick := -1
var has_coin := -1

var bricks:Array[Sprite2D] = []

var active_brick = null

func _ready() -> void:
	game = MmmG.game
	bricks = [$PipeBrick1, $PipeBrick2, $PipeBrick3]

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

	if has_brick >= 0 and !bricks.is_empty():
		if active_brick == null:
			seed(MainGlobals.timeus())
			active_brick = bricks[has_brick % bricks.size()]
			active_brick.show()
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

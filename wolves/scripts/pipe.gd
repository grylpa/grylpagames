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

func _ready() -> void:
	game = WolvesG.game
	bricks = [$PipeBrick1, $PipeBrick2, $PipeBrick3]
	if is_grass:
		%PipeGrass.rotation = game.rng.randi_range(0,3)*PI/2.0
		%PipeGrass.show()
		%PipeGrass.modulate = Color(0.5,0.8,0.5,1)

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
		if board[p.y][p.x].color_idx >= 0:
			$PipeFloor2.modulate = game.color_by_index(board[p.y][p.x].color_idx)
		elif board[p.y][p.x].color != null:
			$PipeFloor2.modulate = board[p.y][p.x].color
		else:
			$PipeFloor2.modulate = Color.from_rgba8(65,65,65,255)
		# if active_brick != null:
		# 	active_brick.hide()
		# return
	else:
		$PipeFloor1.hide()
		$PipeFloor2.hide()
		$PipeImageNoDir.show()

	if has_brick >= 0 and !bricks.is_empty():
		if active_brick == null:
			# seed(MainGlobals.timeus())
			var brick_idx = game.rng.randi_range(0, bricks.size()-1)
			active_brick = bricks[brick_idx % bricks.size()]
			# active_brick = bricks[has_brick % bricks.size()]
			active_brick.show()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		pipe_pressed.emit(board_pos)

func show_path(_timeout_ms := 3000):
	$PipeCoin1.show()
	await MainGlobals.sleep(_timeout_ms / 1000)
	$PipeCoin1.hide()

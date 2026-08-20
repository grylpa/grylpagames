extends Area2D

var board_pos = Vector2i.ZERO
var game:GenericGameUtil
func _ready() -> void:
	# var rng = RandomNumberGenerator.new()
	# $PipeImageLR.rotation = rng.randi_range(0,3)*PI/2.0
	game = LightsG.game

func set_rot(board):
	var p = board_pos
	var r = p.x+1 < game.board_size.x and board[p.y][p.x+1].ispipe
	var d = p.y+1 < game.board_size.y and board[p.y+1][p.x].ispipe
	var l = p.x > 0 and board[p.y][p.x-1].ispipe
	var u = p.y > 0 and board[p.y-1][p.x].ispipe
	$PipeImageLR.hide()
	$PipeImage4.hide()
	$PipeImageURD.hide()
	$PipeImageRD.hide()
	if d and u and r and l:
		$PipeImage4.show()
	elif d and r and l:
		$PipeImageURD.show()
		$PipeImageURD.rotation = PI/2.0
	elif d and r and u:
		$PipeImageURD.show()
		$PipeImageURD.rotation = 0
	elif u and r and l:
		$PipeImageURD.show()
		$PipeImageURD.rotation = -PI/2.0
	elif d and l and u:
		$PipeImageURD.show()
		$PipeImageURD.rotation = PI		
	elif d and u:
		$PipeImageLR.show()
		$PipeImageLR.rotation = PI/2.0
	elif r and l:
		$PipeImageLR.show()
		$PipeImageLR.rotation = 0
	elif d and r:
		$PipeImageRD.show()
		$PipeImageRD.rotation = 0
	elif d and l:
		$PipeImageRD.show()
		$PipeImageRD.rotation = PI/2.0
	elif u and l:
		$PipeImageRD.show()
		$PipeImageRD.rotation = PI
	elif u and r:
		$PipeImageRD.show()
		$PipeImageRD.rotation = -PI/2.0
	elif d or u:
		$PipeImageLR.show()
		$PipeImageLR.rotation = PI/2.0
	elif r or l:
		$PipeImageLR.show()
		$PipeImageLR.rotation = 0


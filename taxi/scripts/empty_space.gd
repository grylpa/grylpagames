extends Area2D

var board_pos := Vector2i.ZERO
var game: GenericGameUtil
func _ready() -> void:
	game = TaxiG.game
	# The grass tile is left ALONE — not rotated, not flipped.
	#
	# Measured, `res://art/grass.png` tiles SEAMLESSLY: its left column matches its right (0.034)
	# and its top matches its bottom (0.030) more closely than two random interior columns match
	# each other (0.043). Laid out plainly, the 40-unit grid is invisible because the texture wraps
	# across it.
	#
	# Turning or flipping a cell breaks that wrap, so every cell boundary becomes a seam and the
	# field gains a grid of them — which is the "still looks tiled" this code used to cause. A
	# per-cell random rotation was here from the start and was making things worse, not better.

func show_hide_walls(board):
	var p = board_pos

	$Wall0.visible = p.x+1 < game.board_size.x and board[p.y][p.x+1].ispipe
	$Wall1.visible = p.y+1 < game.board_size.y and board[p.y+1][p.x].ispipe
	$Wall2.visible = p.x > 0 and board[p.y][p.x-1].ispipe
	$Wall3.visible = p.y > 0 and board[p.y-1][p.x].ispipe
	
	$Wall4.visible = p.x+1 < game.board_size.x and p.y+1 < game.board_size.y and board[p.y+1][p.x+1].ispipe
	$Wall5.visible = p.y+1 < game.board_size.y and p.x > 0 and board[p.y+1][p.x-1].ispipe
	$Wall6.visible = p.x > 0 and p.y > 0 and board[p.y-1][p.x-1].ispipe
	$Wall7.visible = p.y > 0 and p.x+1 < game.board_size.x and board[p.y-1][p.x+1].ispipe

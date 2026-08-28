extends Area2D

var board_pos = Vector2i.ZERO
var game: GenericGameUtil
func _ready() -> void:
	game = PneumoG.game
	# NO grass sprite on a cell. The lawn is one continuous field drawn behind the whole board — see
	# scripts/grass_field.gd — and a per-cell tile on top of it would put the mosaic straight back.
	#
	# (Its own tile does wrap seamlessly, measured: left-to-right 0.034 and top-to-bottom 0.030 against
	# an interior baseline of 0.043. So the grid was invisible until something turned the cells — which
	# a per-cell random rotation in here did, from the start.)
	$Grass.hide()

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

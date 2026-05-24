extends Area2D

var board_pos := Vector2i.ZERO

func _ready() -> void:
	var rng = RandomNumberGenerator.new()
	$Grass.rotation = rng.randi_range(0, 3) * PI / 2.0

func show_hide_walls(board):
	var p = board_pos

	$Wall0.visible = p.x + 1 < GorillaG.game.board_size.x and board[p.y][p.x + 1].ispipe
	$Wall1.visible = p.y + 1 < GorillaG.game.board_size.y and board[p.y + 1][p.x].ispipe
	$Wall2.visible = p.x > 0 and board[p.y][p.x - 1].ispipe
	$Wall3.visible = p.y > 0 and board[p.y - 1][p.x].ispipe

	$Wall4.visible = p.x + 1 < GorillaG.game.board_size.x and p.y + 1 < GorillaG.game.board_size.y and board[p.y + 1][p.x + 1].ispipe
	$Wall5.visible = p.y + 1 < GorillaG.game.board_size.y and p.x > 0 and board[p.y + 1][p.x - 1].ispipe
	$Wall6.visible = p.x > 0 and p.y > 0 and board[p.y - 1][p.x - 1].ispipe
	$Wall7.visible = p.y > 0 and p.x + 1 < GorillaG.game.board_size.x and board[p.y - 1][p.x + 1].ispipe

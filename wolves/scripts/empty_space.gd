extends Area2D

var board_pos := Vector2i.ZERO

func _ready() -> void:
	var rng = RandomNumberGenerator.new()
	$Grass.rotation = rng.randi_range(0,3)*PI/2.0

func show_hide_walls(board):
	var p = board_pos
	var sz = WolvesG.game.board_size
	if p.x == 0 || p.y == 0 || p.x == sz.x - 1 || p.y == sz.y - 1:
		return

	var c = board[p.y][p.x]
	
	var r = board[p.y][p.x+1]
	var l = board[p.y][p.x-1]
	var t = board[p.y-1][p.x]
	var b = board[p.y+1][p.x]

	var _tr = board[p.y-1][p.x+1]		# tr is reserved
	var tl = board[p.y-1][p.x-1]
	var br = board[p.y+1][p.x+1]
	var bl = board[p.y+1][p.x-1]

	if c.is_field:
		$Grass.hide()

	for wall in [$Wall0, $Wall1, $Wall2, $Wall3, $Wall4, $Wall5, $Wall6, $Wall7]:
		wall.modulate = Color(0.99, 0.79, 0.3,1)

	$Wall0.visible = r.fences[2]
	$Wall1.visible = b.fences[3]
	$Wall2.visible = l.fences[0]
	$Wall3.visible = t.fences[1]
	
	$Wall4.visible = !$Wall0.visible and !$Wall1.visible and br.fences[2] && br.fences[3]
	$Wall5.visible = !$Wall2.visible and !$Wall1.visible and bl.fences[0] && bl.fences[3]
	$Wall6.visible = !$Wall2.visible and !$Wall3.visible and tl.fences[1] && tl.fences[0]
	$Wall7.visible = !$Wall3.visible and !$Wall0.visible and _tr.fences[1] && _tr.fences[2]

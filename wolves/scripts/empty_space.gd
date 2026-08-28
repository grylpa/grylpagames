extends Area2D

var board_pos := Vector2i.ZERO

# NO grass sprite on a cell. The lawn is one continuous field drawn behind the whole board — see
# scripts/grass_field.gd — and a per-cell tile on top of it would put the mosaic straight back.
#
# (Its own tile does wrap seamlessly, measured: left-to-right 0.034 and top-to-bottom 0.030 against
# an interior baseline of 0.043. So the grid was invisible until something turned the cells — which
# a per-cell random rotation in here did, from the start.)
func _ready() -> void:
	$Grass.hide()

func show_hide_walls(board):
	var p = board_pos
	var sz = WolvesG.game.board_size
	if p.x == 0 || p.y == 0 || p.x == sz.x - 1 || p.y == sz.y - 1:
		return

	var r = board[p.y][p.x+1]
	var l = board[p.y][p.x-1]
	var t = board[p.y-1][p.x]
	var b = board[p.y+1][p.x]

	var _tr = board[p.y-1][p.x+1]		# tr is reserved
	var tl = board[p.y-1][p.x-1]
	var br = board[p.y+1][p.x+1]
	var bl = board[p.y+1][p.x-1]

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

extends Area2D

var board_pos := Vector2i.ZERO

# The grass tile is left ALONE — not rotated, not flipped.
#
# Measured, `res://art/grass.png` tiles SEAMLESSLY: its left column matches its right (0.034) and
# its top matches its bottom (0.030) more closely than two random interior columns match each other
# (0.043). Laid out plainly, the 40-unit grid is invisible because the texture wraps across it.
#
# Turning or flipping a cell breaks that wrap, so every cell boundary becomes a seam and the field
# gains a grid of them — which is the "still looks tiled" this used to cause. A per-cell random
# rotation was here from the start and was making things worse, not better.

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

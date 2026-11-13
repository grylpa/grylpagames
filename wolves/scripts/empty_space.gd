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

func show_hide_walls(_board):
	var p = board_pos
	var sz = WolvesG.game.board_size
	if p.x == 0 || p.y == 0 || p.x == sz.x - 1 || p.y == sz.y - 1:
		return

	# The fences are DRAWN by the level (level._draw_fences: wooden post-and-rail, 2026-11-12); this cell's
	# old yellow bar sprites stay hidden.
	for wall in [$Wall0, $Wall1, $Wall2, $Wall3, $Wall4, $Wall5, $Wall6, $Wall7]:
		wall.visible = false

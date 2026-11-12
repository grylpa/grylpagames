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

# The palace's walls are drawn by the level (level._draw_castle_walls, 2026-11-12) along every floor
# edge; this cell's old wall sprites stay hidden.
func show_hide_walls(_board) -> void:
	for i in 8:
		get_node("Wall%d" % i).visible = false

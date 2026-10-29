extends Area2D

var board_pos = Vector2i.ZERO

# NO grass sprite on a cell. The lawn is one continuous field drawn behind the whole board — see
# scripts/grass_field.gd — and a per-cell tile on top of it would put the mosaic straight back.
#
# (Its own tile does wrap seamlessly, measured: left-to-right 0.034 and top-to-bottom 0.030 against
# an interior baseline of 0.043. So the grid was invisible until something turned the cells — which
# a per-cell random rotation in here did, from the start.)
func _ready() -> void:
	$Grass.hide()

# The dark rim where this cell meets the road is DRAWN (scripts/road_corners.gd): it follows the
# road's rounded inside corners, which cut into this cell; the square wall sprites could not.
const RIM: Color = Color8(29, 45, 30)
var _rim: Node2D = null
var _board: Array = []

func show_hide_walls(board):
	for k in 8:
		get_node("Wall%d" % k).hide()
	_board = board
	if _rim == null:
		_rim = Node2D.new()
		_rim.draw.connect(func() -> void: RoadCorners.draw_empty_rim(_rim, _board, board_pos, 20.0, RIM, 4.0))
		add_child(_rim)
	_rim.queue_redraw()

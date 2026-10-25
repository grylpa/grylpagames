extends Area2D

var board_pos = Vector2i.ZERO

# THE TUBES LOOK LIKE TUBES: the shared road art is painted over (tube.gdshader) and each side with
# no tube beyond it gets a WALL (_draw_walls): a dark metal edge, a bright line of light along the
# glass just inside it, and the glass shading toward the wall. They used to read as roads -- asphalt
# gray with a dashed yellow center line.
static var _glass: ShaderMaterial = null
var _open: Array = [true, true, true, true]       # r, d, l, u: is there tube that way
var _diag: Array = [true, true, true, true]       # tube at the corner between side i and side i+1
var _walls: Node2D = null

func _ready() -> void:
	if _glass == null:
		_glass = ShaderMaterial.new()
		_glass.shader = preload("res://pneumo/scripts/tube.gdshader")
	for sp: Sprite2D in [$PipeImageLR, $PipeImage4, $PipeImageURD, $PipeImageRD]:
		sp.material = _glass
	_walls = Node2D.new()
	_walls.draw.connect(_draw_walls)
	add_child(_walls)
	move_child(_walls, $PipeImageRD.get_index() + 1)

# The walls JOIN at every corner. Each closed side gets a strip (3.0 px) along its edge and a
# shadow (8.0 px) falling onto the tube. Where two closed sides meet on one tile (a bend) the strips are
# MITERED -- each ends on the 45-degree diagonal -- so they meet without overlapping; where two open
# sides meet but the tile across the corner is not tube (the inside corner of a junction or a bend
# seen from outside), this tile draws the small corner piece that joins its two neighbors' strips,
# with the lit edge and the shadow carried round it. Drawn first as plain full-length strips, they
# overlapped on bends and left a square hole at every inside corner.
func _draw_walls() -> void:
	var t: float = 20.0
	var cw: float = 3.0
	var sh: float = 8.0
	var stone: Color = Color(0.55, 0.58, 0.62)
	var lit: Color = Color(0.85, 0.92, 1.0, 0.55)
	var shade: Color = Color(0.05, 0.08, 0.12, 0.45)
	var clear: Color = Color(shade, 0.0)
	var shade_cols: PackedColorArray = PackedColorArray([shade, shade, clear, clear])
	var dirs: Array = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	for i in 4:
		if _open[i]:
			continue
		var n: Vector2 = dirs[i]
		var side: Vector2 = dirs[(i + 1) % 4]
		var ka: float = 0.0 if _open[(i + 1) % 4] else 1.0     # the side at end a closed too: miter
		var kb: float = 0.0 if _open[(i + 3) % 4] else 1.0
		var a: Vector2 = n * t + side * t
		var b: Vector2 = n * t - side * t
		var ai: Vector2 = a - n * cw - side * cw * ka
		var bi: Vector2 = b - n * cw + side * cw * kb
		var ao: Vector2 = a - n * (cw + sh) - side * (cw + sh) * ka
		var bo: Vector2 = b - n * (cw + sh) + side * (cw + sh) * kb
		_walls.draw_polygon(PackedVector2Array([ai, bi, bo, ao]), shade_cols)
		_walls.draw_colored_polygon(PackedVector2Array([a, b, bi, ai]), stone)
		_walls.draw_line(ai, bi, lit, 1.0)
	for i in 4:
		var j: int = (i + 1) % 4
		if not _open[i] or not _open[j] or _diag[i]:
			continue
		var e1: Vector2 = dirs[i]
		var e2: Vector2 = dirs[j]
		var c: Vector2 = (e1 + e2) * t
		var p1: Vector2 = c - e1 * cw
		var p2: Vector2 = c - e2 * cw
		var pin: Vector2 = c - (e1 + e2) * cw
		var pout: Vector2 = pin - (e1 + e2) * sh
		_walls.draw_polygon(PackedVector2Array([p1, pin, pout, p1 - e1 * sh]), shade_cols)
		_walls.draw_polygon(PackedVector2Array([p2, pin, pout, p2 - e2 * sh]), shade_cols)
		_walls.draw_colored_polygon(PackedVector2Array([c, p1, pin, p2]), stone)
		_walls.draw_line(p1, pin, lit, 1.0)
		_walls.draw_line(p2, pin, lit, 1.0)

func set_rot(board):
	var p = board_pos
	var r = p.x+1 < PneumoG.game.board_size.x and board[p.y][p.x+1].ispipe
	var d = p.y+1 < PneumoG.game.board_size.y and board[p.y+1][p.x].ispipe
	var l = p.x > 0 and board[p.y][p.x-1].ispipe
	var u = p.y > 0 and board[p.y-1][p.x].ispipe
	_open = [r, d, l, u]
	_diag = []
	for i in 4:
		var q: Vector2i = p + [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP][i] \
			+ [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP][(i + 1) % 4]
		_diag.append(q.y >= 0 and q.y < board.size() and q.x >= 0 and q.x < board[q.y].size() and board[q.y][q.x].ispipe)
	if _walls != null:
		_walls.queue_redraw()
	if d and u and r and l:
		$PipeImageLR.hide()
		$PipeImage4.show()
	elif d and r and l:
		$PipeImageLR.hide()
		$PipeImageURD.show()
		$PipeImageURD.rotation = PI/2.0
	elif d and r and u:
		$PipeImageLR.hide()
		$PipeImageURD.show()
		$PipeImageURD.rotation = 0
	elif u and r and l:
		$PipeImageLR.hide()
		$PipeImageURD.show()
		$PipeImageURD.rotation = -PI/2.0
	elif d and l and u:
		$PipeImageLR.hide()
		$PipeImageURD.show()
		$PipeImageURD.rotation = PI		
	elif d and u:
		$PipeImageLR.rotation = PI/2.0
	elif r and l:
		$PipeImageLR.rotation = 0
	elif d and r:
		$PipeImageLR.hide()
		$PipeImageRD.show()
		$PipeImageRD.rotation = 0
	elif d and l:
		$PipeImageLR.hide()
		$PipeImageRD.show()
		$PipeImageRD.rotation = PI/2.0
	elif u and l:
		$PipeImageLR.hide()
		$PipeImageRD.show()
		$PipeImageRD.rotation = PI
	elif u and r:
		$PipeImageLR.hide()
		$PipeImageRD.show()
		$PipeImageRD.rotation = -PI/2.0
	elif d or u:
		$PipeImageLR.rotation = PI/2.0
	elif r or l:
		$PipeImageLR.rotation = 0


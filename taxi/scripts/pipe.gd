extends Area2D

signal pipe_pressed(_board_pos)

var board_pos := Vector2i.ZERO

# The road is asphalt (asphalt.gdshader, one material shared by every road sprite) with a concrete
# CURB wherever it meets something that is not road (_draw_curb, from the neighbors set_rot finds).
# It was flat gray squares, each with a yellow dot, straight onto the lawn.
static var _asphalt: ShaderMaterial = null
var _open: Array = [true, true, true, true]       # r, d, l, u: is there road that way
var _diag: Array = [true, true, true, true]       # road at the corner between side i and side i+1
var _curb: Node2D = null

func _ready() -> void:
	if _asphalt == null:
		_asphalt = ShaderMaterial.new()
		_asphalt.shader = preload("res://taxi/scripts/asphalt.gdshader")
	for sp: Sprite2D in [$PipeImageLR, $PipeImage4, $PipeImageURD, $PipeImageRD]:
		sp.material = _asphalt
	_curb = Node2D.new()
	_curb.draw.connect(_draw_curb)
	add_child(_curb)
	move_child(_curb, $PipeImageRD.get_index() + 1)

# The curbs JOIN at every corner. Each closed side gets a strip (4.0 px) along its edge and a
# shadow (5.0 px) falling onto the road. Where two closed sides meet on one tile (a bend) the strips are
# MITERED -- each ends on the 45-degree diagonal -- so they meet without overlapping; where two open
# sides meet but the tile across the corner is not road (the inside corner of a junction or a bend
# seen from outside), this tile draws the small corner piece that joins its two neighbors' strips,
# with the lit edge and the shadow carried round it. Drawn first as plain full-length strips, they
# overlapped on bends and left a square hole at every inside corner.
func _draw_curb() -> void:
	var t: float = 20.0
	var cw: float = 4.0
	var sh: float = 5.0
	var stone: Color = Color(0.66, 0.65, 0.62)
	var lit: Color = Color(0.85, 0.84, 0.80)
	var shade: Color = Color(0, 0, 0, 0.30)
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
		_curb.draw_polygon(PackedVector2Array([ai, bi, bo, ao]), shade_cols)
		_curb.draw_colored_polygon(PackedVector2Array([a, b, bi, ai]), stone)
		_curb.draw_line(ai, bi, lit, 1.0)
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
		_curb.draw_polygon(PackedVector2Array([p1, pin, pout, p1 - e1 * sh]), shade_cols)
		_curb.draw_polygon(PackedVector2Array([p2, pin, pout, p2 - e2 * sh]), shade_cols)
		_curb.draw_colored_polygon(PackedVector2Array([c, p1, pin, p2]), stone)
		_curb.draw_line(p1, pin, lit, 1.0)
		_curb.draw_line(p2, pin, lit, 1.0)

func show_path(timeout_sec = 3):
	$PipePathImage.show()
	if timeout_sec > 0:
		await MainGlobals.sleep(timeout_sec)
		$PipePathImage.hide()

func show_lobby(_show: bool):
	$LobbyImage.visible = _show

func set_rot(board):
	var p = board_pos
	var r = p.x+1 < TaxiG.game.board_size.x and board[p.y][p.x+1].ispipe
	var d = p.y+1 < TaxiG.game.board_size.y and board[p.y+1][p.x].ispipe
	var l = p.x > 0 and board[p.y][p.x-1].ispipe
	var u = p.y > 0 and board[p.y-1][p.x].ispipe
	_open = [r, d, l, u]
	_diag = []
	for i in 4:
		var q: Vector2i = p + [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP][i] \
			+ [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP][(i + 1) % 4]
		_diag.append(q.y >= 0 and q.y < board.size() and q.x >= 0 and q.x < board[q.y].size() and board[q.y][q.x].ispipe)
	if _curb != null:
		_curb.queue_redraw()
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

func _on_input_event(_viewport:Node, event:InputEvent, _shape_idx:int) -> void:
	if event.is_action_pressed("lclick"):
		pipe_pressed.emit(board_pos)

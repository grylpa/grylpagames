extends Area2D

signal pipe_pressed(_board_pos)

var board_pos := Vector2i.ZERO

# The road is asphalt (asphalt.gdshader, one material shared by every road sprite) with a soft
# shadow wherever it meets something that is not road (_draw_curb, from the neighbors set_rot finds).
# It was flat gray squares, each with a yellow dot, straight onto the lawn.
static var _asphalt: ShaderMaterial = null
var _open: Array = [true, true, true, true]       # r, d, l, u: is there road that way
var _diag: Array = [true, true, true, true]       # road at the corner between side i and side i+1
var _curb: Node2D = null
var _fill: Node2D = null
var _mat: ShaderMaterial = null
var _convex: Array = []                           # rounded OUTER corners (scripts/road_corners.gd)
var _fillets: Array = []                          # rounded inside corners (scripts/road_corners.gd)
var _trim: Array = [[false, false], [false, false], [false, false], [false, false]]

func _ready() -> void:
	if _asphalt == null:
		_asphalt = ShaderMaterial.new()
		_asphalt.shader = preload("res://taxi/scripts/asphalt.gdshader")
	# this tile's own copy: its outer corners are rounded by a uniform (RoadCorners.convex)
	_mat = _asphalt.duplicate()
	for sp: Sprite2D in [$PipeImageLR, $PipeImage4, $PipeImageURD, $PipeImageRD]:
		sp.material = _mat
	_curb = Node2D.new()
	_curb.draw.connect(_draw_curb)
	add_child(_curb)
	move_child(_curb, $PipeImageRD.get_index() + 1)
	# above every road surface: a curved curb's ends lie over the neighboring tiles, and a neighbor
	# drawn later used to cover them (the breaks in the outline)
	_curb.z_index = 1
	# the asphalt a rounded inside corner adds (scripts/road_corners.gd), in the road's own material
	_fill = Node2D.new()
	_fill.material = _asphalt
	_fill.draw.connect(_draw_fillets)
	add_child(_fill)
	move_child(_fill, _curb.get_index())

# NO CURB: the lot meets the lawn with only a soft shadow (3.0 px) falling onto the asphalt along
# each closed side. A 4 px stone curb with a lit edge used to run round the lot; it served no purpose
# in a parking lot and read as walls (user, 2026-10-25). The shadows still JOIN at every corner: on a
# bend each ends on the 45-degree diagonal (mitered), and at an inside corner (two open sides, no
# road across the corner) this tile draws the small corner piece that carries the shadow round.
func _draw_fillets() -> void:
	for i: int in _fillets:
		_fill.draw_colored_polygon(RoadCorners.polygon(i, 20.0), Color.WHITE)

func _draw_curb() -> void:
	var t: float = 20.0
	var cw: float = 0.0
	var sh: float = 3.0
	var stone: Color = Color(0.66, 0.65, 0.62)
	var lit: Color = Color(0, 0, 0, 0)
	var shade: Color = Color(0, 0, 0, 0.25)
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
		if _convex.has(i):
			a -= side * RoadCorners.R
			ka = 0.0
		if _convex.has((i + 3) % 4):
			b += side * RoadCorners.R
			kb = 0.0
		if _trim[i][0]:
			a -= side * RoadCorners.R
		if _trim[i][1]:
			b += side * RoadCorners.R
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
		if _fillets.has(i):
			RoadCorners.draw_arc_curb(_curb, i, t, cw, sh, stone, lit, shade)
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
	for i: int in _convex:
		RoadCorners.draw_convex(_curb, i, t, cw, sh, stone, lit, shade)


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
	# a road end that runs into a dock is open for the curbs: the dock covers it, and a curb across
	# it showed as a light line at the dock's edge
	for k in 4:
		var nq: Vector2i = p + [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP][k]
		if not _open[k] and RoadCorners.kind(board, nq) == 2:
			_open[k] = true
	_diag = []
	for i in 4:
		var q: Vector2i = p + [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP][i] \
			+ [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP][(i + 1) % 4]
		_diag.append(q.y >= 0 and q.y < board.size() and q.x >= 0 and q.x < board[q.y].size() and board[q.y][q.x].ispipe)
	_fillets = RoadCorners.corners(board, p)
	_trim = RoadCorners.trims(board, p)
	_convex = RoadCorners.convex(board, p)
	if _mat != null:
		var rc: Vector4 = Vector4.ZERO
		for i: int in _convex:
			rc[i] = 1.0
		_mat.set_shader_parameter("round_corners", rc)
		_mat.set_shader_parameter("round_r", RoadCorners.R)
	if _curb != null:
		_curb.queue_redraw()
	if _fill != null:
		_fill.queue_redraw()
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

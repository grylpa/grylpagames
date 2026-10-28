extends Area2D

var board_pos = Vector2i.ZERO
var game: GenericGameUtil
func _ready() -> void:
	game = PneumoG.game
	# NO grass sprite on a cell. The lawn is one continuous field drawn behind the whole board — see
	# scripts/grass_field.gd — and a per-cell tile on top of it would put the mosaic straight back.
	#
	# (Its own tile does wrap seamlessly, measured: left-to-right 0.034 and top-to-bottom 0.030 against
	# an interior baseline of 0.043. So the grid was invisible until something turned the cells — which
	# a per-cell random rotation in here did, from the start.)
	$Grass.hide()

# The dark rim round an empty cell, where it meets a tube, is DRAWN, not the shared wall sprites:
# it has to follow the tubes' rounded inside corners (pipe.gd `fillet_corners`), which cut into
# this cell. A side gets the rim when a tube runs along it; a corner a tube rounds gets it as an
# arc; a corner touched only by a diagonal tube gets a small square, as its sprite had.
const RIM: Color = Color(0.06, 0.10, 0.07)
const RIM_W: float = 4.0
const STEPS: Array = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const DIRS: Array = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]

var _side: Array = [false, false, false, false]     # a tube across side i
var _round: Array = [false, false, false, false]    # corner i (between side i and i+1) rounded
var _dot: Array = [false, false, false, false]      # corner i touched only by a diagonal tube
var _rim: Node2D = null

func _is_pipe(board: Array, q: Vector2i) -> bool:
	return game.in_board(q) and board[q.y][q.x].ispipe

func show_hide_walls(board):
	var p: Vector2i = board_pos
	for k in 8:
		get_node("Wall%d" % k).hide()
	for i in 4:
		_side[i] = _is_pipe(board, p + STEPS[i])
	for i in 4:
		var j: int = (i + 1) % 4
		var diag: bool = _is_pipe(board, p + STEPS[i] + STEPS[j])
		_round[i] = _side[i] and _side[j] and diag
		_dot[i] = diag and not _side[i] and not _side[j]
	if _rim == null:
		_rim = Node2D.new()
		_rim.draw.connect(_draw_rim)
		add_child(_rim)
	_rim.queue_redraw()

func _draw_rim() -> void:
	var h: float = float(game.tile_size) * 0.5
	var r: float = PneumoPipe.FILLET_R
	var inset: float = RIM_W * 0.5
	for i in 4:
		var n: Vector2 = DIRS[i]
		var sa: Vector2 = DIRS[(i + 1) % 4]
		var sb: Vector2 = DIRS[(i + 3) % 4]
		if _side[i]:
			# from the corner toward side i-1 (end b) to the corner toward side i+1 (end a)
			var a: Vector2 = n * (h - inset) + sa * (h - (r if _round[i] else 0.0))
			var b: Vector2 = n * (h - inset) + sb * (h - (r if _round[(i + 3) % 4] else 0.0))
			_rim.draw_line(b, a, RIM, RIM_W)
		if _round[i]:
			var m: Vector2 = (n + sa) * (h - r)
			var pts: PackedVector2Array = PackedVector2Array()
			for k in PneumoPipe.ARC_SEGS + 1:
				pts.append(m + n.slerp(sa, float(k) / float(PneumoPipe.ARC_SEGS)) * (r - inset))
			_rim.draw_polyline(pts, RIM, RIM_W, true)
		elif _dot[i]:
			var c: Vector2 = (n + sa) * h
			_rim.draw_rect(Rect2(c, -(n + sa) * RIM_W).abs(), RIM)

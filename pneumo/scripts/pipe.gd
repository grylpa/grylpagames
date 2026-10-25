extends Area2D

var board_pos = Vector2i.ZERO

# THE TUBES ARE DRAWN AS TUBES (_draw_tube): a glass tube shaded round across its width -- dark at
# both walls, brightening to a highlight along its axis -- with a coupling ring wherever it joins the
# next tile, a smooth quarter-circle at a bend, a rounded cap at a dead end, and a metal junction
# box where three or four tubes meet (a capsule turns there; the doors sit on it). The shared road
# art underneath is kept for its shape only and made invisible. Before this the tubes were the road
# art painted a flat gray with thin walls along the closed sides -- "just blocks of gray" -- and
# before that asphalt with a dashed yellow line and thick stone walls.
var _open: Array = [true, true, true, true]       # r, d, l, u: is there tube that way
var _diag: Array = [true, true, true, true]       # tube at the corner between side i and side i+1
var _tube: Node2D = null

const T: float = 20.0                                  # half a tile
const EDGE: Color = Color(0.13, 0.17, 0.22)
const MID: Color = Color(0.36, 0.45, 0.53)
const LIGHT: Color = Color(0.60, 0.70, 0.78)
const SHINE: Color = Color(0.86, 0.93, 0.97)
const RING: Color = Color(0.10, 0.13, 0.17)
const RING_LIT: Color = Color(0.70, 0.78, 0.85, 0.8)
const BOX: Color = Color(0.27, 0.31, 0.37)
const DIRS: Array = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
# the profile ACROSS a tube, from one wall (-1) to the other (+1): symmetric, so tiles meet without a
# seam whichever way each one turns
const PROFILE_U: Array = [-1.0, -0.78, -0.45, -0.14, 0.0, 0.14, 0.45, 0.78, 1.0]

func _profile_color(k: int) -> Color:
	return [EDGE, MID, LIGHT, LIGHT.lerp(SHINE, 0.6), SHINE, LIGHT.lerp(SHINE, 0.6), LIGHT, MID, EDGE][k]

func _ready() -> void:
	for sp: Sprite2D in [$PipeImageLR, $PipeImage4, $PipeImageURD, $PipeImageRD]:
		sp.self_modulate = Color(1, 1, 1, 0)
	_tube = Node2D.new()
	_tube.draw.connect(_draw_tube)
	add_child(_tube)
	move_child(_tube, $PipeImageRD.get_index() + 1)

# A straight half-tube from the center out through side i.
func _half(i: int, from: float) -> void:
	var n: Vector2 = DIRS[i]
	var side: Vector2 = DIRS[(i + 1) % 4]
	for k in PROFILE_U.size() - 1:
		var s0: float = float(PROFILE_U[k]) * T
		var s1: float = float(PROFILE_U[k + 1]) * T
		var c0: Color = _profile_color(k)
		var c1: Color = _profile_color(k + 1)
		_tube.draw_polygon(PackedVector2Array([n * from + side * s0, n * T + side * s0, n * T + side * s1, n * from + side * s1]),
			PackedColorArray([c0, c0, c1, c1]))

# A bend from side i to side j = i+1: the tube curves round the tile's corner between them.
func _bend(i: int) -> void:
	var e1: Vector2 = DIRS[i]
	var e2: Vector2 = DIRS[(i + 1) % 4]
	var c: Vector2 = (e1 + e2) * T
	var a0: float = (-e1).angle()
	var a1: float = (-e2).angle()
	if absf(angle_difference(a0, a1)) < 0.01:
		return
	var steps: int = 10
	for k in PROFILE_U.size() - 1:
		var r0: float = (float(PROFILE_U[k]) + 1.0) * T
		var r1: float = (float(PROFILE_U[k + 1]) + 1.0) * T
		var c0: Color = _profile_color(k)
		var c1: Color = _profile_color(k + 1)
		for q in steps:
			var b0: float = a0 + angle_difference(a0, a1) * float(q) / float(steps)
			var b1: float = a0 + angle_difference(a0, a1) * float(q + 1) / float(steps)
			var p00: Vector2 = c + Vector2.from_angle(b0) * r0
			var p01: Vector2 = c + Vector2.from_angle(b1) * r0
			var p10: Vector2 = c + Vector2.from_angle(b0) * r1
			var p11: Vector2 = c + Vector2.from_angle(b1) * r1
			_tube.draw_polygon(PackedVector2Array([p00, p01, p11, p10]), PackedColorArray([c0, c0, c1, c1]))

# The coupling where this tile's tube meets the next: a dark band across it with a lit edge.
func _ring(i: int) -> void:
	var n: Vector2 = DIRS[i]
	var side: Vector2 = DIRS[(i + 1) % 4]
	var at: float = T - 1.5
	_tube.draw_line(n * at + side * T, n * at - side * T, RING, 3.0)
	_tube.draw_line(n * (at - 2.0) + side * T * 0.92, n * (at - 2.0) - side * T * 0.92, RING_LIT, 1.0)

func _draw_tube() -> void:
	var open: Array = []
	for i in 4:
		if _open[i]:
			open.append(i)
	if open.size() >= 3:
		# a junction box: a plate, bevelled, with a round port in the middle
		for i: int in open:
			_half(i, T * 0.55)
		var r: Rect2 = Rect2(-T * 0.78, -T * 0.78, T * 1.56, T * 1.56)
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = BOX
		sb.set_corner_radius_all(6)
		sb.border_color = BOX.lightened(0.22)
		sb.border_width_top = 2
		sb.border_width_left = 2
		sb.border_width_bottom = 0
		sb.border_width_right = 0
		_tube.draw_style_box(sb, r)
		_tube.draw_circle(Vector2.ZERO, T * 0.50, EDGE, true, -1.0, true)
		_tube.draw_circle(Vector2(-1, -1), T * 0.42, MID, true, -1.0, true)
		_tube.draw_circle(Vector2(-2, -2), T * 0.20, LIGHT.lerp(SHINE, 0.4), true, -1.0, true)
		_tube.draw_arc(Vector2.ZERO, T * 0.50, 0.0, TAU, 24, RING, 1.5, true)
	elif open.size() == 2 and absi(int(open[0]) - int(open[1])) == 2:
		_half(open[0], 0.0)
		_half(open[1], 0.0)
	elif open.size() == 2:
		var first: int = open[0] if (int(open[0]) + 1) % 4 == int(open[1]) else open[1]
		_bend(first)
	elif open.size() == 1:
		# a dead end: the half-tube, closed by a rounded cap
		_half(open[0], 0.0)
		var steps: int = PROFILE_U.size() - 1
		for k in range(steps, -1, -1):
			var rr: float = absf(float(PROFILE_U[k])) * T
			if float(PROFILE_U[k]) < 0.0:
				continue
			_tube.draw_circle(Vector2.ZERO, rr, _profile_color(k), true, -1.0, true)
	for i: int in open:
		_ring(i)

func set_rot(board):
	var p = board_pos
	var r = p.x+1 < PneumoG.game.board_size.x and board[p.y][p.x+1].ispipe
	var d = p.y+1 < PneumoG.game.board_size.y and board[p.y+1][p.x].ispipe
	var l = p.x > 0 and board[p.y][p.x-1].ispipe
	var u = p.y > 0 and board[p.y-1][p.x].ispipe
	_open = [r, d, l, u]
	# a tube's dead end next to a sender or receiver runs on into it, so it is drawn open that way,
	# not capped (drawing only; this changes nothing a capsule does)
	var n_open: int = 0
	for k in 4:
		n_open += 1 if _open[k] else 0
	if n_open == 1:
		for k in 4:
			var q: Vector2i = p + [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP][k]
			if not PneumoG.game.in_board(q) or board[q.y][q.x].istarget:
				_open[k] = true
	_diag = []
	for i in 4:
		var q: Vector2i = p + [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP][i] \
			+ [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP][(i + 1) % 4]
		_diag.append(q.y >= 0 and q.y < board.size() and q.x >= 0 and q.x < board[q.y].size() and board[q.y][q.x].ispipe)
	if _tube != null:
		_tube.queue_redraw()
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


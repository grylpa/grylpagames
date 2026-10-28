class_name PneumoPipe
extends Area2D

var board_pos = Vector2i.ZERO

# THE TUBES ARE CLEAR GLASS GUIDES (_draw_tube): the floor shows through a faint tint, and only the
# walls are drawn -- a thin bright line along each side with no tube beyond it, and a soft sheen just
# inside it, as the edge of a glass tube catches the light. The fill is the whole tile, so tiles join
# into one continuous tube with no seams; where two walls meet on a bend they are mitered, and an
# inside corner gets its small joining piece. The shared road art underneath is kept for its shape
# only and made invisible. History: asphalt with a dashed line and thick stone walls; flat gray with
# thin walls ("just blocks of gray"); shaded opaque tubes with couplings and junction boxes ("way too
# distracting -- we need to remember the game", user 2026-10-25).
#
# EVERY INSIDE CORNER IS ROUNDED, outward: where two tubes meet and the cell between them is empty,
# the corner is cut by an arc of FILLET_R into that empty cell (`fillet_corners`), so the tube
# widens into the empty side and never loses any of its own width. The tile that owns the corner
# draws the arc and the bit of glass it adds; its two neighbors stop their straight walls FILLET_R
# short of the corner (`_trim`). The level's floor plates leave the same bits plain
# (`_draw_plant_floor`) and the empty cell's shadow strips stop short too (empty_space.gd).
var _open: Array = [true, true, true, true]       # r, d, l, u: is there tube that way
var _diag: Array = [true, true, true, true]       # tube at the corner between side i and side i+1
var _tube: Node2D = null
var _fillet: Array = [false, false, false, false]   # inside corner i (between side i and i+1) rounded
# per side: [end a, end b] of its wall stops short, because a neighbor rounds the corner there
var _trim: Array = [[false, false], [false, false], [false, false], [false, false]]

const T: float = 20.0                                  # half a tile
const GLASS: Color = Color(0.70, 0.88, 1.0, 0.16)
const WALL: Color = Color(0.88, 0.96, 1.0, 0.60)
const SHEEN: Color = Color(0.78, 0.90, 1.0, 0.20)
const STRIPE_SOFT: Color = Color(0.85, 0.95, 1.0, 0.07)
const STRIPE_LINE: Color = Color(0.92, 0.98, 1.0, 0.16)
const STRIPE_OFS: float = 4.0
const DIRS: Array = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
const STEPS: Array = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const FILLET_R: float = 6.0
const ARC_SEGS: int = 10

static func _kind(board: Array, q: Vector2i) -> int:
	if q.y < 0 or q.y >= board.size() or q.x < 0 or q.x >= board[q.y].size():
		return -1
	if board[q.y][q.x].ispipe:
		return 1
	return 2 if board[q.y][q.x].istarget else 0

# The inside corners of tube cell `p` that are rounded: corner i lies between side i and side i+1,
# and is rounded when the tube runs both ways from it and the cell across the corner is plain
# empty floor (not tube, not a dock, not off the board).
static func fillet_corners(board: Array, p: Vector2i) -> Array:
	var out: Array = []
	for i in 4:
		var j: int = (i + 1) % 4
		if _kind(board, p + STEPS[i]) == 1 and _kind(board, p + STEPS[j]) == 1 \
				and _kind(board, p + STEPS[i] + STEPS[j]) == 0:
			out.append(i)
	return out

# The plain bit a rounded corner adds, outside the owner's own tile: from the corner point along
# both walls by FILLET_R, and back along the arc. Local to the owning tile's center.
static func fillet_polygon(i: int, half: float) -> PackedVector2Array:
	var e1: Vector2 = DIRS[i]
	var e2: Vector2 = DIRS[(i + 1) % 4]
	var c: Vector2 = (e1 + e2) * half
	var m: Vector2 = c + (e1 + e2) * FILLET_R
	var pts: PackedVector2Array = PackedVector2Array([c])
	for k in ARC_SEGS + 1:
		var t: float = float(k) / float(ARC_SEGS)
		var v: Vector2 = (-e2).slerp(-e1, t)
		pts.append(m + v * FILLET_R)
	return pts

func _ready() -> void:
	for sp: Sprite2D in [$PipeImageLR, $PipeImage4, $PipeImageURD, $PipeImageRD]:
		sp.self_modulate = Color(1, 1, 1, 0)
	_tube = Node2D.new()
	_tube.draw.connect(_draw_tube)
	add_child(_tube)
	move_child(_tube, $PipeImageRD.get_index() + 1)

func _draw_tube() -> void:
	_tube.draw_rect(Rect2(-T, -T, T * 2.0, T * 2.0), GLASS, true)
	# A tube's glass catches the light in a stripe along its axis, a little toward the light (top
	# left): a broad soft band and a thin bright line in it, from the center out along each open
	# side. This is what makes a duct read as a round tube rather than a flat lane.
	for i in 4:
		if not _open[i]:
			continue
		var d: Vector2 = DIRS[i]
		var lit: Vector2 = Vector2(-1.0, -1.0) * STRIPE_OFS
		var off: Vector2 = Vector2(lit.x * absf(d.y), lit.y * absf(d.x))  # across the axis only
		_tube.draw_line(off, off + d * T, STRIPE_SOFT, 9.0)
		_tube.draw_line(off, off + d * T, STRIPE_LINE, 2.0)
	var cw: float = 1.5
	var sh: float = 6.0
	var clear: Color = Color(SHEEN, 0.0)
	var sheen_cols: PackedColorArray = PackedColorArray([SHEEN, SHEEN, clear, clear])
	for i in 4:
		if _open[i]:
			continue
		var n: Vector2 = DIRS[i]
		var side: Vector2 = DIRS[(i + 1) % 4]
		var ka: float = 0.0 if _open[(i + 1) % 4] else 1.0     # the side at end a closed too: miter
		var kb: float = 0.0 if _open[(i + 3) % 4] else 1.0
		var a: Vector2 = n * T + side * T
		var b: Vector2 = n * T - side * T
		if _trim[i][0]:
			a -= side * FILLET_R
		if _trim[i][1]:
			b += side * FILLET_R
		var ai: Vector2 = a - n * cw - side * cw * ka
		var bi: Vector2 = b - n * cw + side * cw * kb
		var ao: Vector2 = a - n * (cw + sh) - side * (cw + sh) * ka
		var bo: Vector2 = b - n * (cw + sh) + side * (cw + sh) * kb
		_tube.draw_polygon(PackedVector2Array([ai, bi, bo, ao]), sheen_cols)
		_tube.draw_colored_polygon(PackedVector2Array([a, b, bi, ai]), WALL)
	for i in 4:
		var j: int = (i + 1) % 4
		if not _open[i] or not _open[j] or _diag[i]:
			continue
		if _fillet[i]:
			_draw_fillet(i, cw, sh)
			continue
		var e1: Vector2 = DIRS[i]
		var e2: Vector2 = DIRS[j]
		var c: Vector2 = (e1 + e2) * T
		var p1: Vector2 = c - e1 * cw
		var p2: Vector2 = c - e2 * cw
		var pin: Vector2 = c - (e1 + e2) * cw
		var pout: Vector2 = pin - (e1 + e2) * sh
		_tube.draw_polygon(PackedVector2Array([p1, pin, pout, p1 - e1 * sh]), sheen_cols)
		_tube.draw_polygon(PackedVector2Array([p2, pin, pout, p2 - e2 * sh]), sheen_cols)
		_tube.draw_colored_polygon(PackedVector2Array([c, p1, pin, p2]), WALL)

# The rounded corner: the glass it adds, the wall along the arc, and the sheen just inside it,
# fading toward the tube's middle like the straight walls' sheen.
func _draw_fillet(i: int, cw: float, sh: float) -> void:
	var e1: Vector2 = DIRS[i]
	var e2: Vector2 = DIRS[(i + 1) % 4]
	var m: Vector2 = (e1 + e2) * (T + FILLET_R)
	_tube.draw_colored_polygon(fillet_polygon(i, T), GLASS)
	var clear: Color = Color(SHEEN, 0.0)
	for k in ARC_SEGS:
		var v0: Vector2 = (-e2).slerp(-e1, float(k) / float(ARC_SEGS))
		var v1: Vector2 = (-e2).slerp(-e1, float(k + 1) / float(ARC_SEGS))
		var r0: float = FILLET_R
		var r1: float = FILLET_R + cw
		var r2: float = FILLET_R + cw + sh
		_tube.draw_polygon(PackedVector2Array([m + v0 * r1, m + v1 * r1, m + v1 * r2, m + v0 * r2]),
			PackedColorArray([SHEEN, SHEEN, clear, clear]))
		_tube.draw_colored_polygon(PackedVector2Array([m + v0 * r0, m + v1 * r0, m + v1 * r1,
			m + v0 * r1]), WALL)

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
	_fillet = [false, false, false, false]
	for i in fillet_corners(board, p):
		_fillet[i] = true
	# A closed side's wall stops short at an end where the neighbor along it rounds the corner: that
	# neighbor's tube runs on across the closed side's cell (see fillet_corners, seen from there).
	for i in 4:
		var n: Vector2i = STEPS[i]
		var sa: Vector2i = STEPS[(i + 1) % 4]
		var sb: Vector2i = STEPS[(i + 3) % 4]
		var plain: bool = _kind(board, p + n) == 0
		_trim[i] = [plain and _kind(board, p + sa) == 1 and _kind(board, p + sa + n) == 1,
			plain and _kind(board, p + sb) == 1 and _kind(board, p + sb + n) == 1]
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


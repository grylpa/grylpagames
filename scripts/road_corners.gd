class_name RoadCorners
extends RefCounted

# ROUNDED INSIDE CORNERS for the road games (Valet, Dispatch, Headlights, Lights Out, taxi), the
# same idea as pneumo's ducts (pneumo/scripts/pipe.gd). Where two roads meet and the cell between
# them is plain empty ground, the corner is cut by an arc of R into that empty cell, so the road
# widens into the empty side and never loses any of its own width.
#  - the road tile that owns the corner (`corners`) draws the extra asphalt (`polygon`, with the
#    road's own shader, which works in world coordinates and so continues seamlessly) and the curb
#    along the arc (`draw_arc_curb`)
#  - its two neighbors stop their straight curbs R short of the corner (`trims`)
#  - the empty cell draws its dark rim along the arc instead of the square wall sprites
#    (`draw_empty_rim`)
#  - an OUTER corner -- both sides and the cell across it are empty ground, as on the outside of a
#    bend or the end of a road -- is rounded with the same R (`convex`): the tile's asphalt is cut
#    there by its shader, and `draw_convex` draws the curb, its shadow and the dark grass rim round
#    the curve; the straight curbs and the grass cells' rims stop short of it.
# Each game's board is an Array of rows of cells with `ispipe` and `istarget`.

const R: float = 8.0
const RIM: Color = Color(29.0 / 255.0, 45.0 / 255.0, 30.0 / 255.0)   # the dark band round the grass
const RIM_W: float = 4.0
const SEGS: int = 10
const DIRS: Array = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
const STEPS: Array = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]


# -1 off the board, 1 road, 2 a dock, 0 plain empty ground
static func kind(board: Array, q: Vector2i) -> int:
	if q.y < 0 or q.y >= board.size() or q.x < 0 or q.x >= board[q.y].size():
		return -1
	if board[q.y][q.x].has_meta("under_dock"):
		return 2      # a road cell a dock stands on (the depot) is drawn as a dock: the road runs
		              # square up under it, as it does into every other dock
	if board[q.y][q.x].ispipe:
		return 1
	return 2 if board[q.y][q.x].istarget else 0


# The corners of road tile `p` that are rounded: corner i lies between side i and side i+1.
static func corners(board: Array, p: Vector2i) -> Array:
	var out: Array = []
	for i in 4:
		var j: int = (i + 1) % 4
		if kind(board, p + STEPS[i]) == 1 and kind(board, p + STEPS[j]) == 1 \
				and kind(board, p + STEPS[i] + STEPS[j]) == 0:
			out.append(i)
	return out


static func _ground(board: Array, q: Vector2i) -> bool:
	var k: int = kind(board, q)
	return k == 0 or k == -1


# The OUTER corners of road tile `p` that are rounded: both sides of the corner and the cell across
# it are empty ground (a dock beside it keeps the corner square: the road runs into the dock).
static func convex(board: Array, p: Vector2i) -> Array:
	var out: Array = []
	for i in 4:
		var j: int = (i + 1) % 4
		if _ground(board, p + STEPS[i]) and _ground(board, p + STEPS[j]) \
				and _ground(board, p + STEPS[i] + STEPS[j]):
			out.append(i)
	return out


# A rounded outer corner, drawn by its road tile: the curb strip just inside the arc with its lit
# edge and the shadow falling onto the road, and the dark rim of the grass just outside it.
static func draw_convex(ci: CanvasItem, i: int, half: float, cw: float, sh: float, stone: Color,
		lit: Color, shade: Color) -> void:
	var e1: Vector2 = DIRS[i]
	var e2: Vector2 = DIRS[(i + 1) % 4]
	var m: Vector2 = (e1 + e2) * (half - R)
	var clear: Color = Color(shade, 0.0)
	var inner: PackedVector2Array = PackedVector2Array()
	for k in SEGS:
		var v0: Vector2 = e1.slerp(e2, float(k) / float(SEGS))
		var v1: Vector2 = e1.slerp(e2, float(k + 1) / float(SEGS))
		ci.draw_colored_polygon(PackedVector2Array([m + v0 * R, m + v1 * R, m + v1 * (R + RIM_W),
			m + v0 * (R + RIM_W)]), RIM)
		if cw > 0.0:
			ci.draw_colored_polygon(PackedVector2Array([m + v0 * (R - cw), m + v1 * (R - cw), m + v1 * R,
				m + v0 * R]), stone)
		if sh > 0.0:
			ci.draw_polygon(PackedVector2Array([m + v0 * (R - cw), m + v1 * (R - cw), m + v1 * (R - cw - sh),
				m + v0 * (R - cw - sh)]), PackedColorArray([shade, shade, clear, clear]))
		inner.append(m + v0 * (R - cw))
	inner.append(m + e2 * (R - cw))
	if lit.a > 0.0:
		ci.draw_polyline(inner, lit, 1.0, true)


# Per closed side i of road tile `p`: whether its curb stops short at end a (toward side i+1) and
# at end b (toward side i-1), because a neighbor rounds the corner there.
static func trims(board: Array, p: Vector2i) -> Array:
	var out: Array = []
	for i in 4:
		var n: Vector2i = STEPS[i]
		var sa: Vector2i = STEPS[(i + 1) % 4]
		var sb: Vector2i = STEPS[(i + 3) % 4]
		var plain: bool = kind(board, p + n) == 0
		out.append([plain and kind(board, p + sa) == 1 and kind(board, p + sa + n) == 1,
			plain and kind(board, p + sb) == 1 and kind(board, p + sb + n) == 1])
	return out


# The asphalt a rounded corner adds, local to the owning tile's center (`half` = half a tile).
static func polygon(i: int, half: float) -> PackedVector2Array:
	var e1: Vector2 = DIRS[i]
	var e2: Vector2 = DIRS[(i + 1) % 4]
	var c: Vector2 = (e1 + e2) * half
	var m: Vector2 = c + (e1 + e2) * R
	var pts: PackedVector2Array = PackedVector2Array([c])
	for k in SEGS + 1:
		pts.append(m + (-e2).slerp(-e1, float(k) / float(SEGS)) * R)
	return pts


# The curb along a rounded corner's arc, matching the straight curbs: a strip `cw` wide in `stone`
# with its lit inner edge, and a shadow `sh` wide falling onto the road.
static func draw_arc_curb(ci: CanvasItem, i: int, half: float, cw: float, sh: float, stone: Color,
		lit: Color, shade: Color) -> void:
	var e1: Vector2 = DIRS[i]
	var e2: Vector2 = DIRS[(i + 1) % 4]
	var m: Vector2 = (e1 + e2) * (half + R)
	var clear: Color = Color(shade, 0.0)
	var edge: PackedVector2Array = PackedVector2Array()
	for k in SEGS:
		var v0: Vector2 = (-e2).slerp(-e1, float(k) / float(SEGS))
		var v1: Vector2 = (-e2).slerp(-e1, float(k + 1) / float(SEGS))
		if sh > 0.0:
			ci.draw_polygon(PackedVector2Array([m + v0 * (R + cw), m + v1 * (R + cw), m + v1 * (R + cw + sh),
				m + v0 * (R + cw + sh)]), PackedColorArray([shade, shade, clear, clear]))
		if cw > 0.0:
			ci.draw_colored_polygon(PackedVector2Array([m + v0 * R, m + v1 * R, m + v1 * (R + cw),
				m + v0 * (R + cw)]), stone)
		edge.append(m + v0 * (R + cw))
	edge.append(m + (-e1) * (R + cw))
	if lit.a > 0.0:
		ci.draw_polyline(edge, lit, 1.0, true)


# The dark rim round empty cell `p` where it meets the road: along each side with road across it,
# along the arc where a corner is rounded, and a small square where only a diagonal touches.
static func draw_empty_rim(ci: CanvasItem, board: Array, p: Vector2i, half: float, col: Color,
		w: float) -> void:
	var side: Array = []
	for i in 4:
		side.append(kind(board, p + STEPS[i]) == 1)
	var round_c: Array = []
	var dot: Array = []
	var plain: bool = kind(board, p) == 0
	for i in 4:
		var j: int = (i + 1) % 4
		var diag: bool = kind(board, p + STEPS[i] + STEPS[j]) == 1
		round_c.append(plain and side[i] and side[j] and diag)
		# a diagonal road's corner here is rounded (and its rim drawn by it) when this cell and the
		# two beside both are empty ground
		dot.append(diag and not side[i] and not side[j] and not (plain and _ground(board, p + STEPS[i])
			and _ground(board, p + STEPS[j])))
	var inset: float = w * 0.5
	for i in 4:
		var n: Vector2 = DIRS[i]
		var sa: Vector2 = DIRS[(i + 1) % 4]
		var sb: Vector2 = DIRS[(i + 3) % 4]
		if side[i]:
			# stop short where the road's own outer corner there is rounded (draw_convex draws the
			# rim round it): that corner's sides are this cell and the one beside both of them
			var ni: Vector2i = STEPS[i]
			var cut_a: bool = plain and _ground(board, p + ni + STEPS[(i + 1) % 4]) \
				and _ground(board, p + STEPS[(i + 1) % 4])
			var cut_b: bool = plain and _ground(board, p + ni + STEPS[(i + 3) % 4]) \
				and _ground(board, p + STEPS[(i + 3) % 4])
			var a: Vector2 = n * (half - inset) + sa * (half - (R if round_c[i] or cut_a else 0.0))
			var b: Vector2 = n * (half - inset) + sb * (half - (R if round_c[(i + 3) % 4] or cut_b else 0.0))
			ci.draw_line(b, a, col, w)
		if round_c[i]:
			var m: Vector2 = (n + sa) * (half - R)
			var pts: PackedVector2Array = PackedVector2Array()
			for k in SEGS + 1:
				pts.append(m + n.slerp(sa, float(k) / float(SEGS)) * (R - inset))
			ci.draw_polyline(pts, col, w, true)
		elif dot[i]:
			var c: Vector2 = (n + sa) * half
			ci.draw_rect(Rect2(c, -(n + sa) * w).abs(), col)

extends Control
class_name BucketStage

# THE NEAR END OF THE POOL TABLE in bucketmadness, and its three pockets (2026-11-02): the near rail
# across the bottom of the felt (the felt itself is scripts/chute_view.gd, in a clipped area, so the
# end of the table is drawn here, on an unclipped overlay under everything else), a CORNER POCKET at
# each end -- the two rule targets -- and in the middle a STRING NET hanging from the rail: the
# "dumpster", for what neither rule wants, a different kind of pocket so it reads as the odd one out.
# The balls (scripts/ball_art.gd) are reparented here when they are sent, so they are drawn over the
# holes and visibly drop into them (BallArt.sink_into).
#
# It was the shelf three buckets stood on, then a rail joining three pockets drawn as a row of
# containers under the table -- which still read as buckets.
#
# The level feeds `table` (the felt's rect in this control's space) and `opens` (each pocket's rim
# light, 0..1) every frame; it reads the pocket centres back with pocket_center().

const WOOD: Color = Color(0.420, 0.200, 0.085)
const WOOD_DARK: Color = Color(0.200, 0.085, 0.035)
const WOOD_LIT: Color = Color(0.700, 0.410, 0.200)
const CUSHION: Color = Color(0.060, 0.300, 0.165)
const LEATHER: Color = Color(0.230, 0.130, 0.070)
const LEATHER_LIT: Color = Color(0.420, 0.260, 0.150)
const HOLE: Color = Color(0.020, 0.015, 0.012)
const NET: Color = Color(0.900, 0.860, 0.760)
const GLOW: Color = Color(1.0, 0.85, 0.45)
const SPARK: Color = Color(1.0, 0.95, 0.85)
const RAIL_H: float = 22.0

var table: Rect2 = Rect2():
	set(v):
		if v != table:
			table = v
			queue_redraw()

var opens: Array = [0.0, 0.0, 0.0]:
	set(v):
		if v != opens:
			opens = v
			queue_redraw()

# Kept for the old caller; the pockets come from `table` now.
var rects: Array = []

var _puffs: Array = []          # {"at": Vector2, "age": float}
var _t: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_t += delta
	for i in range(_puffs.size() - 1, -1, -1):
		_puffs[i]["age"] = float(_puffs[i]["age"]) + delta
		if float(_puffs[i]["age"]) > 0.55:
			_puffs.remove_at(i)
	queue_redraw()

func pocket_radius() -> float:
	return clampf(table.size.x * 0.05, 16.0, 34.0)

# Pocket centres, this control's space: 0 left corner, 1 the net (middle), 2 right corner.
func pocket_center(idx: int) -> Vector2:
	var r: float = pocket_radius()
	match idx:
		0:
			return Vector2(table.position.x + r * 1.35, table.end.y + r * 0.05)
		2:
			return Vector2(table.end.x - r * 1.35, table.end.y + r * 0.05)
		_:
			# a side pocket in the middle of the near rail's edge, like the corner ones
			return Vector2(table.get_center().x, table.end.y + r * 0.05)

# A marker control over pocket idx -- for the tutorial's spotlight (bucketmadness tutorial_*_bucket).
var _spots: Array = []

func pocket_spot(idx: int) -> Control:
	while _spots.size() < 3:
		var c: Control = Control.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		_spots.append(c)
	var r: float = pocket_radius()
	var at: Vector2 = pocket_center(idx)
	var ext: Vector2 = Vector2(r * 1.6, r * (2.6 if idx == 1 else 1.4))
	var sp: Control = _spots[idx]
	sp.position = at - Vector2(ext.x, r * 1.0)
	sp.size = Vector2(ext.x * 2.0, ext.y + r)
	return sp

# A ball dropped into pocket idx.
func thump(idx: int) -> void:
	if table.size.x <= 0.0:
		return
	_puffs.append({"at": pocket_center(idx), "age": 0.0})
	queue_redraw()

func _draw() -> void:
	if table.size.x < 20.0:
		return
	var r: float = pocket_radius()
	var x0: float = table.position.x
	var x1: float = table.end.x
	var y0: float = table.end.y - 2.0
	# the table's two near legs, turned wood, going down to the floor (behind the rule plaques)
	for lx in [x0 + r * 0.9, x1 - r * 0.9]:
		_leg(Vector2(lx, y0 + RAIL_H), table.size.y * 0.30)
	# the net, hanging under the rail in the middle, behind it
	var nc: Vector2 = pocket_center(1)
	# its net hangs from a brass ring fixed UNDER the rail, so it is that pocket's bag
	var ring_c: Vector2 = Vector2(nc.x, y0 + RAIL_H + 2.0)
	_draw_net(ring_c, r * 0.85)
	# the near rail: polished wood, its cushion along the felt, rounding into the side rails
	draw_rect(Rect2(x0 - 4.0, y0 + RAIL_H, x1 - x0 + 8.0, 8.0), Color(0, 0, 0, 0.35))
	draw_polygon(PackedVector2Array([Vector2(x0 - 4.0, y0), Vector2(x1 + 4.0, y0), Vector2(x1 + 4.0, y0 + RAIL_H), Vector2(x0 - 4.0, y0 + RAIL_H)]),
		PackedColorArray([WOOD_LIT, WOOD_LIT, WOOD_DARK, WOOD_DARK]))
	draw_line(Vector2(x0, y0 + 1.0), Vector2(x1, y0 + 1.0), CUSHION, 3.0)
	draw_line(Vector2(x0 - 4.0, y0 + 4.0), Vector2(x1 + 4.0, y0 + 4.0), WOOD_LIT.lightened(0.3), 1.2)
	for k in 4:
		var dx: float = lerpf(x0, x1, (float(k) + 1.0) / 5.0)
		if absf(dx - nc.x) > r * 1.4:
			_diamond(Vector2(dx, y0 + RAIL_H * 0.6), 3.4)
	# a cube of blue chalk left on the rail, between the net and the right pocket
	var ch: Vector2 = Vector2(lerpf(nc.x, x1, 0.55), y0 + RAIL_H * 0.30)
	var cs: float = 9.0
	draw_rect(Rect2(ch + Vector2(2.0, 3.0), Vector2(cs, cs * 0.75)), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(ch, Vector2(cs, cs * 0.45)), Color(0.35, 0.58, 0.88))
	draw_rect(Rect2(ch + Vector2(0, cs * 0.45), Vector2(cs, cs * 0.30)), Color(0.18, 0.36, 0.66))
	draw_circle(ch + Vector2(cs * 0.5, cs * 0.22), cs * 0.22, Color(0.14, 0.30, 0.58))
	# the net's ring under the rail, and the two brass straps that hold it to the rail
	var brass: Color = Color(0.780, 0.600, 0.280)
	for sx in [-1.0, 1.0]:
		draw_line(Vector2(nc.x + sx * r * 0.62, y0 + RAIL_H - 3.0), Vector2(nc.x + sx * r * 0.74, ring_c.y + 2.0), brass.darkened(0.25), 3.0, true)
	_ring(ring_c, r * 0.85, r * 0.22, brass, 3.0)
	# the side pocket itself, cut into the rail's edge like the corners, trimmed in brass
	_ellipse(nc, r + 6.0, r * 0.78 + 5.0, LEATHER)
	_ellipse(nc, r + 3.0, r * 0.78 + 2.5, brass)
	_ellipse(nc, r, r * 0.78, HOLE)
	_arc(nc, r * 0.9, r * 0.7, PI * 1.1, PI * 1.9, Color(1, 1, 1, 0.10), 2.0)
	_glow(nc, r + 6.0, r * 0.78 + 5.0, float(opens[1]) if opens.size() > 1 else 0.0)
	# the two corner pockets: cut through the corner of the rails, a leather rim round a black hole
	for idx in [0, 2]:
		var pc: Vector2 = pocket_center(idx)
		_ellipse(pc, r + 6.0, r * 0.78 + 5.0, LEATHER)
		_ellipse(pc, r + 3.0, r * 0.78 + 2.5, LEATHER_LIT)
		_ellipse(pc, r, r * 0.78, HOLE)
		_arc(pc, r * 0.9, r * 0.7, PI * 1.1, PI * 1.9, Color(1, 1, 1, 0.10), 2.0)
		_glow(pc, r + 6.0, r * 0.78 + 5.0, float(opens[idx]) if opens.size() > idx else 0.0)
	# a little sparkle where a ball has just gone in
	for p in _puffs:
		var t: float = clampf(float(p["age"]) / 0.55, 0.0, 1.0)
		var at: Vector2 = p["at"]
		for k2 in 6:
			var ang: float = float(k2) / 6.0 * TAU + t * 1.2
			var pos: Vector2 = at + Vector2(cos(ang), sin(ang) * 0.6) * (r * 0.6 + t * r * 0.9)
			draw_circle(pos, 2.6 * (1.0 - t) + 0.8, Color(SPARK.r, SPARK.g, SPARK.b, (1.0 - t) * 0.8))

# A string pocket: a bag of knotted cord hanging below the rail, its diamond mesh narrowing to the
# bottom, swaying very slightly.
func _draw_net(c: Vector2, r: float) -> void:
	var top: float = c.y
	var depth: float = r * 2.3
	var sway: float = sin(_t * 1.3) * r * 0.05
	var cols: int = 7
	var rows: int = 5
	var pts: Array = []
	for j in rows + 1:
		var fy: float = float(j) / float(rows)
		var half: float = r * lerpf(0.95, 0.35, fy * fy)
		var row: Array = []
		for i in cols + 1:
			var fx: float = float(i) / float(cols) * 2.0 - 1.0
			row.append(Vector2(c.x + fx * half + sway * fy, top + fy * depth))
		pts.append(row)
	# the bag's shadow inside, so it reads as hollow
	var left_side: PackedVector2Array = PackedVector2Array()
	for j3 in rows + 1:
		left_side.append(pts[j3][0])
	var bag_outline: PackedVector2Array = PackedVector2Array()
	for j4 in rows + 1:
		bag_outline.append(pts[j4][cols])
	for j5 in range(rows, -1, -1):
		bag_outline.append(pts[j5][0])
	draw_colored_polygon(bag_outline, Color(0, 0, 0, 0.45))
	# the mesh: cords running diagonally both ways between the rows
	for j6 in rows:
		for i3 in cols:
			var a: Vector2 = pts[j6][i3]
			var b: Vector2 = pts[j6 + 1][i3 + 1]
			var c2: Vector2 = pts[j6][i3 + 1]
			var d: Vector2 = pts[j6 + 1][i3]
			draw_line(a, b, Color(NET.r, NET.g, NET.b, 0.8), 1.3, true)
			draw_line(c2, d, Color(NET.r, NET.g, NET.b, 0.8), 1.3, true)
	draw_polyline(left_side, Color(NET.r, NET.g, NET.b, 0.9), 1.6, true)
	var right_side: PackedVector2Array = PackedVector2Array()
	for j7 in rows + 1:
		right_side.append(pts[j7][cols])
	draw_polyline(right_side, Color(NET.r, NET.g, NET.b, 0.9), 1.6, true)

# A turned table leg from `top` down `ln`: a block under the rail, a long bulbous turning, a foot.
func _leg(top: Vector2, ln: float) -> void:
	var prof: Array = [[0.00, 44.0], [0.16, 44.0], [0.18, 31.0], [0.30, 37.0], [0.52, 48.0], [0.70, 34.0], [0.86, 27.0], [0.92, 36.0], [1.0, 36.0]]
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	for pr in prof:
		var y: float = top.y + float(pr[0]) * ln
		var hw: float = float(pr[1]) * 0.5
		left.append(Vector2(top.x - hw, y))
		right.append(Vector2(top.x + hw, y))
	var outline: PackedVector2Array = left.duplicate()
	var rr: PackedVector2Array = right.duplicate()
	rr.reverse()
	outline.append_array(rr)
	# its shadow on the carpet first, then the leg in mid-tone wood -- a lit side, a shaded side and a
	# dark outline -- so it stands out from the dark carpet behind it
	_ellipse(Vector2(top.x + 6.0, top.y + ln + 2.0), 30.0, 7.0, Color(0, 0, 0, 0.45))
	var cols: PackedColorArray = PackedColorArray()
	for k in outline.size():
		cols.append(WOOD_LIT if k < left.size() else WOOD_DARK)
	draw_polygon(outline, cols)
	var rim: PackedVector2Array = outline.duplicate()
	rim.append(outline[0])
	draw_polyline(rim, Color(0.08, 0.03, 0.01), 2.0, true)
	var lit: PackedVector2Array = PackedVector2Array()
	for p2 in left:
		lit.append(p2.lerp(Vector2(top.x, p2.y), 0.40))
	draw_polyline(lit, Color(1.0, 0.82, 0.58, 0.55), 2.5, true)

func _glow(c: Vector2, rx: float, ry: float, amount: float) -> void:
	if amount <= 0.0:
		return
	for g in 3:
		_ring(c, rx + 3.0 * float(g), ry + 2.0 * float(g), Color(GLOW.r, GLOW.g, GLOW.b, 0.5 * amount / float(g + 1)), 3.0)

func _diamond(c: Vector2, r: float) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0)]),
		Color(0.950, 0.920, 0.840))

func _ell_pts(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 32:
		var a: float = TAU * float(k) / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	draw_colored_polygon(_ell_pts(c, rx, ry), col)

func _ring(c: Vector2, rx: float, ry: float, col: Color, wdt: float) -> void:
	var pts: PackedVector2Array = _ell_pts(c, rx, ry)
	pts.append(pts[0])
	draw_polyline(pts, col, wdt, true)

func _arc(c: Vector2, rx: float, ry: float, a0: float, a1: float, col: Color, wdt: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 17:
		var a: float = lerpf(a0, a1, float(k) / 16.0)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, wdt, true)

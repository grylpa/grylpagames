extends Control
class_name FactoryFloor

# The floor of a factory, seen FROM ABOVE.
#
# Sorting Robots and Apprentice are top-down: the belts are conveyors viewed from overhead, with items
# traveling down them. The first factory backdrop drew a wall meeting a floor at a horizon, which
# is a side-on view — against top-down belts it read as a conveyor standing upright against a wall.
# A top-down room has no horizon and no vanishing point: every seam is parallel, and the only depth
# comes from light and wear.
#
# (Bucketmadness keeps the side-on backdrop, because there things fall DOWN a chute into buckets
# standing on the ground — that view really does have a floor and a wall.)

# A PARCEL DEPOT (2026-11-02): the parcels (scripts/parcel_art.gd) needed somewhere that is about
# parcels. Dark warm concrete with saw-cut joints, scuffs and the odd stain; worn yellow lane lines
# painted round each belt (the game hands its belt rects in, `belts`); and pallets stacked with real
# 3-D boxes -- rendered by the parcels' own renderer -- standing in the free floor beside the belts,
# only where there is room for them. Before it the floor was dark wooden boards (a "workshop at
# night"), and before that cold steel plates.
const CONCRETE: Color = Color(0.205, 0.190, 0.175)
const JOINT: Color = Color(0.090, 0.082, 0.075, 0.85)
const JOINT_LIT: Color = Color(0.330, 0.310, 0.290, 0.35)
const PAINT: Color = Color(0.840, 0.640, 0.150)
const HAZARD: Color = Color(0.580, 0.443, 0.161, 0.38)
const LAMP: Color = Color(1.0, 0.702, 0.380, 0.17)
const VIGNETTE: Color = Color(0.0, 0.0, 0.0, 0.48)
const SLAB: float = 170.0

# Where the lamps hang, as fractions of the floor: over the belts. A game with one belt in the
# middle (MonkeyC) sets one.
var lamps: Array = [Vector2(0.37, 0.48), Vector2(0.63, 0.52)]:
	set(v):
		lamps = v
		queue_redraw()

# The belts' rects in this control's coordinates, from the game (each frame; redrawn only on change).
var belts: Array = []:
	set(v):
		if v != belts:
			belts = v
			queue_redraw()

var _props_pending: bool = true

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	resized.connect(queue_redraw)

# Polls until the pallet pictures exist (rendered once, a few frames), then stops.
func _process(_delta: float) -> void:
	if _props_pending:
		queue_redraw()
	else:
		set_process(false)

func _hash01(a: int, b: int) -> float:
	var hv: int = (a * 73856093) ^ (b * 19349663)
	return float(absi(hv) % 1000) / 1000.0

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 8.0 or h < 8.0:
		return
	draw_rect(Rect2(0.0, 0.0, w, h), CONCRETE)
	# mottling: soft lighter and darker patches, the way poured concrete cures unevenly
	for i in 70:
		var c: Vector2 = Vector2(_hash01(i, 1) * w, _hash01(i, 2) * h)
		var rr: float = 30.0 + _hash01(i, 3) * 90.0
		var lighter: bool = _hash01(i, 4) < 0.5
		_blob(c, rr, rr * (0.5 + _hash01(i, 5) * 0.5), _hash01(i, 6) * PI,
			Color(1, 0.95, 0.88, 0.025) if lighter else Color(0, 0, 0, 0.04))
	# a couple of old stains
	for i2 in 3:
		var sc: Vector2 = Vector2(_hash01(i2, 11) * w, _hash01(i2, 12) * h)
		for g in 3:
			_blob(sc, 12.0 + 8.0 * float(g) + _hash01(i2, 13) * 14.0, 9.0 + 6.0 * float(g), _hash01(i2, 14) * PI, Color(0.05, 0.04, 0.03, 0.06))
	# saw-cut joints between the slabs
	var x: float = SLAB * 0.6
	while x < w:
		draw_line(Vector2(x, 0.0), Vector2(x, h), JOINT, 2.0)
		draw_line(Vector2(x + 1.5, 0.0), Vector2(x + 1.5, h), JOINT_LIT, 1.0)
		x += SLAB
	var y: float = SLAB * 0.4
	while y < h:
		draw_line(Vector2(0.0, y), Vector2(w, y), JOINT, 2.0)
		draw_line(Vector2(0.0, y + 1.5), Vector2(w, y + 1.5), JOINT_LIT, 1.0)
		y += SLAB
	# scuffs: faint curved trolley-wheel marks
	for i3 in 6:
		var a0: float = _hash01(i3, 21) * TAU
		var cc: Vector2 = Vector2(_hash01(i3, 22) * w, _hash01(i3, 23) * h)
		draw_arc(cc, 60.0 + _hash01(i3, 24) * 120.0, a0, a0 + 0.6 + _hash01(i3, 25) * 0.8, 24, Color(0, 0, 0, 0.07), 3.0, true)
	# Painted hazard bands down both edges, the way a walkway is marked off from a machine run.
	_hazard_band(Rect2(0.0, 0.0, 16.0, h))
	_hazard_band(Rect2(w - 16.0, 0.0, 16.0, h))
	# the lane lines round each belt, worn: paint coming and going along them
	for r: Rect2 in belts:
		var g2: Rect2 = r.grow(10.0)
		_worn_line(Vector2(g2.position.x, g2.position.y), Vector2(g2.position.x, g2.end.y))
		_worn_line(Vector2(g2.end.x, g2.position.y), Vector2(g2.end.x, g2.end.y))
	_draw_litter(w, h)
	_draw_props(w)
	# The rest of the floor in shadow first, then the lamps lifting the belts out of it.
	_vignette(w, h)
	for lp: Vector2 in lamps:
		var lc: Vector2 = Vector2(w * lp.x, h * lp.y)
		var rings: int = 14
		for k2 in range(rings, 0, -1):
			var t: float = float(k2) / float(rings)
			_pool(lc, w * 0.30 * t, h * 0.50 * t, Color(LAMP.r, LAMP.g, LAMP.b, LAMP.a * (1.0 - t) * 0.55))

# THE DEPOT'S LITTER (2026-11-02): stamped envelopes that missed a sack, a dropped shipping label, torn
# strips of parcel tape -- lying flat on the concrete, each turned its own way, never on a belt or its
# lane. Placed by a fixed hash, so they stay put frame to frame and game to game.
const PAPER: Array = [Color(0.93, 0.91, 0.86), Color(0.86, 0.80, 0.68), Color(0.78, 0.64, 0.45), Color(0.90, 0.88, 0.92)]
const STAMP: Array = [Color(0.78, 0.18, 0.15), Color(0.18, 0.36, 0.66), Color(0.20, 0.52, 0.30), Color(0.85, 0.62, 0.15)]

func _free_spot(p: Vector2, pad: float) -> bool:
	for r: Rect2 in belts:
		if r.grow(pad + 16.0).has_point(p):
			return false
	return true

func _draw_litter(w: float, h: float) -> void:
	if belts.is_empty():
		return
	# Only on the floor beside and below the belts' tops: above them are the signs and the HUD text.
	var top_y: float = INF
	for r: Rect2 in belts:
		top_y = minf(top_y, r.position.y)
	var placed: int = 0
	var tries: int = 0
	while placed < 14 and tries < 120:
		tries += 1
		var p: Vector2 = Vector2(lerpf(26.0, w - 26.0, _hash01(tries, 31)), lerpf(top_y + 10.0, h * 0.95, _hash01(tries, 32)))
		if not _free_spot(p, 26.0):
			continue
		var ang: float = (_hash01(tries, 33) - 0.5) * 1.8
		var kind: float = _hash01(tries, 34)
		draw_set_transform(p, ang, Vector2.ONE)
		if kind < 0.68:
			_envelope(tries)
		elif kind < 0.85:
			_label(tries)
		else:
			_tape_strip(tries)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		placed += 1

# An envelope seen from above, lying back-up or front-up: the flap's V, or a stamp, a postmark and
# the address lines.
func _envelope(i: int) -> void:
	var ew: float = 38.0 + _hash01(i, 41) * 12.0
	var eh: float = ew * (0.58 + _hash01(i, 42) * 0.12)
	var paper: Color = PAPER[int(_hash01(i, 43) * PAPER.size()) % PAPER.size()]
	var r: Rect2 = Rect2(-ew * 0.5, -eh * 0.5, ew, eh)
	draw_rect(Rect2(r.position + Vector2(2.0, 3.0), r.size), Color(0, 0, 0, 0.30))
	draw_rect(r, paper)
	draw_rect(r, paper.darkened(0.25), false, 1.0)
	if _hash01(i, 44) < 0.35:
		# its back: the flap
		draw_polyline(PackedVector2Array([r.position, Vector2(0.0, eh * 0.08), Vector2(r.end.x, r.position.y)]), paper.darkened(0.22), 1.2, true)
		draw_line(Vector2(r.position.x, r.end.y), Vector2(-ew * 0.12, 0.0), paper.darkened(0.15), 1.0, true)
		draw_line(Vector2(r.end.x, r.end.y), Vector2(ew * 0.12, 0.0), paper.darkened(0.15), 1.0, true)
		return
	# the stamp, perforated
	var sw: float = ew * 0.20
	var sr: Rect2 = Rect2(r.end.x - sw - 3.0, r.position.y + 3.0, sw, sw * 1.2)
	draw_rect(sr, Color(0.97, 0.96, 0.92))
	draw_rect(sr.grow(-1.5), STAMP[int(_hash01(i, 45) * STAMP.size()) % STAMP.size()])
	for k in 4:
		var t: float = (float(k) + 0.5) / 4.0
		draw_circle(Vector2(lerpf(sr.position.x, sr.end.x, t), sr.position.y), 0.7, paper)
		draw_circle(Vector2(lerpf(sr.position.x, sr.end.x, t), sr.end.y), 0.7, paper)
	# the postmark over its edge: a ring and wavy cancel lines
	var pm: Vector2 = Vector2(sr.position.x - sw * 0.2, sr.get_center().y + 1.0)
	draw_arc(pm, sw * 0.55, 0.0, TAU, 20, Color(0.15, 0.15, 0.18, 0.55), 1.0, true)
	for k2 in 3:
		var wy: float = pm.y - sw * 0.35 + float(k2) * sw * 0.35
		var wave: PackedVector2Array = PackedVector2Array()
		for q in 7:
			wave.append(Vector2(pm.x - sw * 1.6 + float(q) * sw * 0.32, wy + sin(float(q) * 1.6) * 1.2))
		draw_polyline(wave, Color(0.15, 0.15, 0.18, 0.45), 1.0, true)
	# the address, as lines of ink
	for k3 in 3:
		var ly: float = eh * 0.02 + float(k3) * eh * 0.15
		draw_line(Vector2(-ew * 0.20, ly), Vector2(-ew * 0.20 + ew * (0.42 - 0.08 * float(k3)), ly), Color(0.12, 0.12, 0.20, 0.55), 1.3)

# A shipping label peeled off a box: a white rectangle with a barcode and a bold strip.
func _label(i: int) -> void:
	var lw: float = 26.0 + _hash01(i, 51) * 8.0
	var lh: float = lw * 0.72
	var r: Rect2 = Rect2(-lw * 0.5, -lh * 0.5, lw, lh)
	draw_rect(Rect2(r.position + Vector2(1.5, 2.0), r.size), Color(0, 0, 0, 0.25))
	draw_rect(r, Color(0.96, 0.96, 0.94))
	draw_rect(Rect2(r.position.x, r.position.y, lw, lh * 0.22), Color(0.80, 0.20, 0.15) if _hash01(i, 52) < 0.5 else Color(0.15, 0.15, 0.18))
	var bx: float = r.position.x + 3.0
	while bx < r.end.x - 3.0:
		var bw: float = 0.8 + _hash01(int(bx * 7.0), i) * 1.6
		draw_rect(Rect2(bx, r.end.y - lh * 0.38, bw, lh * 0.28), Color(0.08, 0.08, 0.08))
		bx += bw + 0.8 + _hash01(int(bx * 3.0), i + 1) * 1.2

# A torn strip of brown parcel tape, a little curled.
func _tape_strip(i: int) -> void:
	var tl: float = 30.0 + _hash01(i, 61) * 26.0
	var tw: float = 7.0
	var pts: PackedVector2Array = PackedVector2Array([Vector2(-tl * 0.5, -tw * 0.5), Vector2(tl * 0.5, -tw * 0.5 + 1.5),
		Vector2(tl * 0.5 - 2.0, 0.0), Vector2(tl * 0.5, tw * 0.5), Vector2(-tl * 0.5, tw * 0.5 - 1.0), Vector2(-tl * 0.5 + 2.0, 0.0)])
	draw_colored_polygon(pts, Color(0.76, 0.58, 0.32, 0.85))
	draw_line(Vector2(-tl * 0.45, -tw * 0.15), Vector2(tl * 0.45, -tw * 0.1), Color(1, 0.95, 0.85, 0.35), 1.0, true)

func _worn_line(a: Vector2, b: Vector2) -> void:
	var n: int = maxi(1, int(a.distance_to(b) / 14.0))
	for k in n:
		var p0: Vector2 = a.lerp(b, float(k) / float(n))
		var p1: Vector2 = a.lerp(b, float(k + 1) / float(n))
		var wear: float = 0.30 + 0.45 * _hash01(int(p0.x), int(p0.y))
		draw_line(p0, p1, Color(PAINT.r, PAINT.g, PAINT.b, wear), 4.0)

# Pallets in the free floor beside each belt: outside its outer edge (and, with one belt, both
# sides), toward its top and bottom, where the robot arms (at mid-height) are not. Skipped where the
# margin is too narrow for one to read as a pallet.
func _draw_props(w: float) -> void:
	_props_pending = false
	if belts.is_empty():
		_props_pending = true
		return
	var spots: Array = []                     # [rect, variant]
	for bi in belts.size():
		var r: Rect2 = belts[bi]
		var sides: Array = [-1, 1] if belts.size() == 1 else ([-1] if bi == 0 else [1])
		for sd: int in sides:
			var x0: float = 20.0 if sd < 0 else r.end.x + 16.0
			var x1: float = r.position.x - 16.0 if sd < 0 else w - 20.0
			var room: float = x1 - x0
			if room < 100.0:          # narrower and a pallet reads as a toy
				continue
			# NOT ORGANIZED: one or two props a side, each at its own height, size and place in the
			# margin, and each its own kind of pile (the four identical pallets in the four corners read
			# as staged).
			var seed_side: int = bi * 2 + (0 if sd < 0 else 1)
			var count: int = 1 if _hash01(seed_side, 71) < 0.45 else 2
			var used_y: Array = []
			for k in count:
				var side_px: float = minf(room, 150.0) * (0.62 + 0.38 * _hash01(seed_side * 5 + k, 72))
				var fy: float = 0.10 + 0.80 * _hash01(seed_side * 5 + k, 73)
				for uy: float in used_y:
					if absf(fy - uy) < 0.30:
						fy = fposmod(fy + 0.45, 0.80) + 0.10
				used_y.append(fy)
				var cx: float = lerpf(x0 + side_px * 0.5, x1 - side_px * 0.5, _hash01(seed_side * 5 + k, 74))
				var cy: float = r.position.y + r.size.y * fy
				spots.append([Rect2(cx - side_px * 0.5, cy - side_px * 0.5, side_px, side_px), int(_hash01(seed_side * 5 + k, 75) * 6.0)])
	for si in spots.size():
		var sp: Rect2 = spots[si][0]
		var variant: int = spots[si][1]
		var px: int = int(clampf(sp.size.x * clampf(get_viewport().get_final_transform().get_scale().x, 1.0, 3.0), 64.0, 400.0))
		px = int(px / 32) * 32
		var tex: Texture2D = ParcelArt.prop_texture(self, "pallet", variant, px)
		if tex == null:
			_props_pending = true
			continue
		# its shadow on the concrete, thrown toward the viewer like the parcels'
		_blob(sp.get_center() + Vector2(0.0, sp.size.y * 0.12), sp.size.x * 0.42, sp.size.y * 0.30, 0.0, Color(0, 0, 0, 0.22))
		draw_texture_rect(tex, sp, false)
	if _props_pending:
		set_process(true)

func _blob(c: Vector2, rx: float, ry: float, ang: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 20:
		var a: float = TAU * float(k) / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(ang))
	draw_colored_polygon(pts, col)

func _pool(c: Vector2, rx: float, ry: float, col: Color) -> void:
	if rx <= 0.5 or ry <= 0.5 or col.a <= 0.001:
		return
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 32:
		var a: float = float(i) / 32.0 * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

func _hazard_band(r: Rect2) -> void:
	var step: float = 20.0
	var yy: float = r.position.y - step
	while yy < r.end.y:
		draw_polygon(
			PackedVector2Array([Vector2(r.position.x, yy), Vector2(r.end.x, yy - step * 0.5),
				Vector2(r.end.x, yy + step * 0.5 - 1.0), Vector2(r.position.x, yy + step - 1.0)]),
			PackedColorArray([HAZARD, HAZARD, HAZARD, HAZARD]))
		yy += step * 2.0

func _vignette(w: float, h: float) -> void:
	var clear: Color = Color(0, 0, 0, 0)
	var bv: float = h * 0.18
	var bh: float = w * 0.20
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, bv), Vector2(0, bv)]),
		PackedColorArray([VIGNETTE, VIGNETTE, clear, clear]))
	draw_polygon(
		PackedVector2Array([Vector2(0, h - bv), Vector2(w, h - bv), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([clear, clear, VIGNETTE, VIGNETTE]))
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(bh, 0), Vector2(bh, h), Vector2(0, h)]),
		PackedColorArray([VIGNETTE, clear, clear, VIGNETTE]))
	draw_polygon(
		PackedVector2Array([Vector2(w - bh, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - bh, h)]),
		PackedColorArray([clear, VIGNETTE, VIGNETTE, clear]))

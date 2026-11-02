extends Control
class_name FactoryBackdrop

# The room the sorting games happen in: a factory.
#
# They shipped with a tiled grass texture over a grass-green clear color — a field, in three games
# about machines sorting objects on conveyors. It is the largest single thing on screen, so no
# amount of restyling the widgets on top of it changes what the screen looks like.
#
# Drawn rather than an image: it scales to any screen with no new asset, the palette stays with the
# rest of the look, and the horizon can be moved per game so the machines stand at the right depth.
#
# A WORKSHOP AT NIGHT since 2026-11-02 (see Sleek): warm dark wood, brass trim, hanging amber lamps.
#
# Everything here is deliberately LOW CONTRAST. It is a room, and a room that competes with the
# objects the player is reading is worse than a flat color.

# Where the table's near rail ends, in this control's space (from the game, each frame): the carpet runs
# back under the table to just above it, so the table hides its far edge. -1 until known.
var table_bottom: float = -1.0:
	set(v):
		if absf(v - table_bottom) > 0.5:
			table_bottom = v
			queue_redraw()

# The felt's rect and how far in its far end starts (from the game, each frame): the carpet shares the
# table's perspective -- its sides run to the same vanishing point as the table's rails.
var table_rect: Rect2 = Rect2():
	set(v):
		if v != table_rect:
			table_rect = v
			queue_redraw()
var table_inset: float = 0.0:
	set(v):
		if absf(v - table_inset) > 0.5:
			table_inset = v
			queue_redraw()

# A small framed picture on the back wall (the game hands its own chooser icon in), or none.
var picture: Texture2D = null:
	set(v):
		picture = v
		queue_redraw()

# Where the wall meets the floor, as a fraction of height.
@export var horizon: float = 0.62

# A BILLIARD ROOM since the pool table (2026-11-02): dark green damask walls above a wood wainscot,
# a dark wooden floor, and over the table the classic billiard lamp -- a brass bar with green glass
# shades -- casting warm cones down onto the felt. (It was a factory wall, then a workshop at night.)
const WALL_TOP: Color = Color(0.050, 0.095, 0.070)
const WALL_BOT: Color = Color(0.085, 0.150, 0.110)
const DAMASK: Color = Color(0.120, 0.200, 0.150, 0.35)
const WAINSCOT: Color = Color(0.230, 0.110, 0.045)
const WAINSCOT_DARK: Color = Color(0.120, 0.055, 0.022)
const WAINSCOT_LIT: Color = Color(0.520, 0.300, 0.140)
const FLOOR_NEAR: Color = Color(0.090, 0.050, 0.030)
const FLOOR_FAR: Color = Color(0.160, 0.090, 0.050)
const BRASS: Color = Color(0.780, 0.600, 0.280)
const SHADE: Color = Color(0.090, 0.360, 0.190)
const SHADE_LIT: Color = Color(0.300, 0.650, 0.380)
const LIGHT: Color = Color(1.0, 0.880, 0.620, 0.075)
const VIGNETTE: Color = Color(0.0, 0.0, 0.0, 0.45)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	resized.connect(queue_redraw)

# Redrawn until the 3-D props (the bridge) have rendered, then idle.
var _props_pending: bool = false

func _process(_delta: float) -> void:
	if _props_pending:
		queue_redraw()
	else:
		set_process(false)

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 8.0 or h < 8.0:
		return
	_props_pending = false
	var hy: float = h * horizon
	_draw_wall(w, hy)
	_draw_floor(w, h, hy)
	_draw_rug_and_stool(w, h, hy)
	_draw_room_props(w, h, hy)
	_draw_lamp(w, h)
	_draw_vignette(w, h)

func _draw_wall(w: float, hy: float) -> void:
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, hy), Vector2(0, hy)]),
		PackedColorArray([WALL_TOP, WALL_TOP, WALL_BOT, WALL_BOT]))
	# damask: faint repeating motifs in vertical stripes -- a wallpaper, not a pattern to read
	var col_w: float = 46.0
	var row_h: float = 58.0
	var cx: float = col_w * 0.5
	var row: int = 0
	while cx < w:
		var cy: float = row_h * (0.5 if row % 2 == 0 else 1.0)
		while cy < hy - 20.0:
			_motif(Vector2(cx, cy), 9.0)
			cy += row_h
		draw_line(Vector2(cx + col_w * 0.5, 0.0), Vector2(cx + col_w * 0.5, hy), Color(0, 0, 0, 0.10), 1.0)
		cx += col_w
		row += 1
	# the wainscot: a dado rail and panelling up to it
	var dado: float = hy - maxf(hy * 0.20, 40.0)
	draw_polygon(PackedVector2Array([Vector2(0, dado), Vector2(w, dado), Vector2(w, hy), Vector2(0, hy)]),
		PackedColorArray([WAINSCOT, WAINSCOT, WAINSCOT_DARK, WAINSCOT_DARK]))
	draw_rect(Rect2(0.0, dado - 5.0, w, 6.0), WAINSCOT_DARK)
	draw_line(Vector2(0.0, dado - 5.0), Vector2(w, dado - 5.0), WAINSCOT_LIT, 1.5)
	var panels: int = 6
	for i in panels:
		var px: float = w * (float(i) + 0.08) / float(panels)
		var pw: float = w * 0.84 / float(panels)
		var pr: Rect2 = Rect2(px, dado + 8.0, pw, hy - dado - 16.0)
		if pr.size.y > 6.0:
			draw_rect(pr, Color(0, 0, 0, 0.18), false, 2.0)
			draw_line(pr.position + Vector2(0, pr.size.y), pr.end, Color(WAINSCOT_LIT.r, WAINSCOT_LIT.g, WAINSCOT_LIT.b, 0.35), 1.0)

func _motif(c: Vector2, r: float) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.4), c + Vector2(r, 0), c + Vector2(0, r * 1.4), c + Vector2(-r, 0)]), DAMASK)
	draw_circle(c + Vector2(0, -r * 1.7), r * 0.28, DAMASK)
	draw_circle(c + Vector2(0, r * 1.7), r * 0.28, DAMASK)

func _draw_floor(w: float, h: float, hy: float) -> void:
	draw_polygon(PackedVector2Array([Vector2(0, hy), Vector2(w, hy), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([FLOOR_FAR, FLOOR_FAR, FLOOR_NEAR, FLOOR_NEAR]))
	var vp: Vector2 = Vector2(w * 0.5, hy - h * 0.06)
	var boards: int = 9
	for i in range(boards + 1):
		var fx: float = w * float(i) / float(boards)
		draw_line(vp.lerp(Vector2(fx, hy), 0.92), Vector2(lerpf(w * 0.5, fx, 1.9), h), Color(0, 0, 0, 0.25), 1.0, true)

# IN FRONT OF THE TABLE (2026-11-02): a patterned carpet under it in perspective, its far edge hidden
# under the table, and a leather bar stool by the right-hand corner.
func _draw_rug_and_stool(w: float, h: float, hy: float) -> void:
	# Not until the game has told us where the table is: before that the perspective collapses (the
	# carpet's polygons had no area and failed to triangulate on the first frame).
	if table_rect.size.y <= 1.0 or table_bottom <= 0.0:
		return
	# its far edge runs back under the table, to just above where the table's near rail ends, so the
	# table hides it (on every layout: the game tells us where the table ends)
	var top: float = (table_bottom - 26.0) if table_bottom > 0.0 else hy
	# THE TABLE'S PERSPECTIVE: the vanishing point is where the felt's two slanted rails meet, and the
	# carpet's sides run to it; a step into the distance is shorter on screen the further it is (screen
	# height above the vanishing point goes as 1 / depth). Its near edge lies below the table by a share
	# of the table's own height, so it keeps its proportions to the table on every layout.
	var felt: Rect2 = table_rect if table_rect.size.y > 1.0 else Rect2(0.0, hy - h * 0.45, w, h * 0.45)
	var inset: float = maxf(table_inset, 1.0)
	var vp: Vector2 = Vector2(felt.get_center().x, felt.end.y - felt.size.x * felt.size.y / (2.0 * inset))
	var tb: float = table_bottom if table_bottom > 0.0 else felt.end.y
	var near: float = tb + felt.size.y * 0.58
	var half_top: float = (w * 0.40) * 1.0
	if top - vp.y < 2.0 or near <= top + 2.0:
		return
	var z_near: float = (top - vp.y) / maxf(near - vp.y, 1.0)          # depth at the near edge, top = 1
	var at: Callable = func(u: float, v: float) -> Vector2:
		var z: float = lerpf(1.0, z_near, v)
		var y: float = vp.y + (top - vp.y) / z
		var half: float = half_top * (y - vp.y) / (top - vp.y)
		return Vector2(vp.x + (u - 0.5) * 2.0 * half, y)
	var rug_c: Array = [at.call(0.0, 0.0), at.call(1.0, 0.0), at.call(1.0, 1.0), at.call(0.0, 1.0)]
	var band: Callable = func(i0: float, i1: float, col: Color) -> void:
		var outer: PackedVector2Array = PackedVector2Array([at.call(i0, i0), at.call(1.0 - i0, i0), at.call(1.0 - i0, 1.0 - i0), at.call(i0, 1.0 - i0)])
		var inner: PackedVector2Array = PackedVector2Array([at.call(i1, i1), at.call(1.0 - i1, i1), at.call(1.0 - i1, 1.0 - i1), at.call(i1, 1.0 - i1)])
		# not along the far edge (e 0): that end runs under the table, and its border showed below the
		# near rail on a phone
		for e in range(1, 4):
			draw_colored_polygon(PackedVector2Array([outer[e], outer[(e + 1) % 4], inner[(e + 1) % 4], inner[e]]), col)
	var wine: Color = Color(0.30, 0.06, 0.07)
	var navy: Color = Color(0.09, 0.12, 0.24)
	var gold: Color = Color(0.62, 0.45, 0.18)
	draw_colored_polygon(PackedVector2Array([rug_c[0], rug_c[1], rug_c[2], rug_c[3]]), wine)
	band.call(0.0, 0.035, navy)
	band.call(0.035, 0.05, gold)
	band.call(0.05, 0.085, navy.lightened(0.05))
	band.call(0.085, 0.095, gold.darkened(0.2))
	# the field: a lattice of small diamonds, alternating navy and gold, growing toward the viewer
	var rows: int = 9
	var cols: int = 11
	for rr in rows:
		for cc in cols:
			var u2: float = 0.12 + 0.76 * (float(cc) + (0.5 if rr % 2 == 0 else 0.0)) / float(cols)
			var v2: float = 0.13 + 0.74 * (float(rr) + 0.5) / float(rows)
			if u2 > 0.88:
				continue
			var cpt: Vector2 = at.call(u2, v2)
			var du: Vector2 = (at.call(u2 + 0.022, v2) as Vector2) - cpt
			var dv: Vector2 = (at.call(u2, v2 + 0.030) as Vector2) - cpt
			var col: Color = Color(navy.r, navy.g, navy.b, 0.55) if (rr + cc) % 2 == 0 else Color(gold.r, gold.g, gold.b, 0.40)
			draw_colored_polygon(PackedVector2Array([cpt - dv, cpt + du, cpt + dv, cpt - du]), col)
	# the medallion: nested filled lozenges
	# in front of the table, where the floor shows
	# the medallion in the middle (in depth) of the part in front of the table
	var mv: float = 0.62
	var mlay: Array = [[0.16, 0.20, navy], [0.12, 0.15, gold], [0.08, 0.10, wine.lightened(0.08)], [0.04, 0.05, navy]]
	for m in mlay:
		var hu: float = float(m[0])
		var hv: float = float(m[1])
		draw_colored_polygon(PackedVector2Array([at.call(0.5, mv - hv), at.call(0.5 + hu, mv), at.call(0.5, mv + hv), at.call(0.5 - hu, mv)]), m[2])
	# wear: faint lighter scuffs where people stand to play
	for i2 in 30:
		var wp: Vector2 = at.call(0.1 + 0.8 * _hash01(i2, 3), 0.1 + 0.8 * _hash01(i2, 4))
		draw_circle(wp, 3.0 + 6.0 * _hash01(i2, 5), Color(1, 0.9, 0.8, 0.025))
	# the stool, by the right-hand corner in front: a padded leather seat, a chrome ring, three legs
	var sr: float = maxf(w * 0.065, 26.0)
	var sc: Vector2 = Vector2(w * 0.88, minf(near - sr * 0.6, h - sr * 2.1))
	for lg in [-0.8, 0.0, 0.8]:
		var foot: Vector2 = sc + Vector2(lg * sr * 0.9, sr * 1.9)
		var head: Vector2 = sc + Vector2(lg * sr * 0.45, sr * 0.2)
		draw_line(head + Vector2(3, 2), foot + Vector2(3, 2), Color(0, 0, 0, 0.40), 5.0, true)
		draw_line(head, foot, Color(0.58, 0.60, 0.64), 5.0, true)
		draw_line(head + Vector2(-1.2, 0), foot + Vector2(-1.2, 0), Color(0.92, 0.94, 0.97, 0.7), 1.4, true)
		draw_circle(foot, 3.0, Color(0.15, 0.15, 0.16))
	draw_arc(sc + Vector2(0, sr * 1.15), sr * 0.62, 0.0, PI, 16, Color(0.85, 0.87, 0.90), 3.0, true)
	var seat: PackedVector2Array = PackedVector2Array()
	for a2 in 28:
		var ang2: float = TAU * float(a2) / 28.0
		seat.append(sc + Vector2(cos(ang2) * sr, sin(ang2) * sr * 0.38))
	var seat_side: PackedVector2Array = seat.duplicate()
	for i in seat_side.size():
		seat_side[i] += Vector2(0, sr * 0.22)
	draw_colored_polygon(seat_side, Color(0.34, 0.14, 0.07))
	draw_colored_polygon(seat, Color(0.62, 0.28, 0.14))
	var seat_rim: PackedVector2Array = seat.duplicate()
	seat_rim.append(seat[0])
	draw_polyline(seat_rim, Color(0.10, 0.04, 0.02), 1.5, true)
	draw_arc(sc + Vector2(-sr * 0.2, -sr * 0.08), sr * 0.45, PI * 1.1, PI * 1.7, 12, Color(1, 0.88, 0.72, 0.55), 2.5, true)

func _hash01(a: int, b: int) -> float:
	var hv: int = (a * 73856093) ^ (b * 19349663)
	return float(absi(hv) % 1000) / 1000.0

# THE ROOM'S THINGS (2026-11-02): cues leaning against the walls on both sides, a wooden triangle
# rack hanging on a hook, and a bead scoring wire -- out at the sides, where the table (drawn over
# this) leaves the walls showing.
func _draw_room_props(w: float, h: float, hy: float) -> void:
	var floor_y: float = hy + (h - hy) * 0.35
	_cue(Vector2(w * 0.035, floor_y), Vector2(w * 0.085, h * 0.18), 9.0, 3.6)
	_cue(Vector2(w * 0.075, floor_y + 6.0), Vector2(w * 0.105, h * 0.22), 8.5, 3.4)
	_cue(Vector2(w * 0.965, floor_y), Vector2(w * 0.912, h * 0.19), 9.0, 3.6)
	# the triangle rack on its hook, on the right wall
	var hook: Vector2 = Vector2(w * 0.86, h * 0.27)
	draw_circle(hook, 2.5, BRASS)
	var side: float = maxf(w * 0.07, 26.0)
	var tri: PackedVector2Array = PackedVector2Array([hook + Vector2(0, 3), hook + Vector2(side * 0.58, side + 3.0), hook + Vector2(-side * 0.58, side + 3.0), hook + Vector2(0, 3)])
	var shadow: PackedVector2Array = PackedVector2Array()
	for p2 in tri:
		shadow.append(p2 + Vector2(3, 4))
	draw_polyline(shadow, Color(0, 0, 0, 0.35), 6.0, true)
	draw_polyline(tri, WAINSCOT, 6.0, true)
	draw_polyline(tri, WAINSCOT_LIT, 1.5, true)
	# the mechanical bridge (the "rake" for out-of-reach shots) standing against the right wall like a
	# cue, its 3-D wire head at the top (scripts/bridge_art.gd)
	var b_foot: Vector2 = Vector2(w * 0.775, h * 0.58)     # hidden behind the table on both layouts (its near rail ends above the wall's foot)
	var b_top: Vector2 = Vector2(w * 0.805, h * 0.155)
	var btex: Texture2D = BridgeArt.texture(self, 512)
	if btex == null:
		_props_pending = true
		set_process(true)
	else:
		var dirv: Vector2 = b_top - b_foot
		var bh: float = dirv.length() / (7.55 / BridgeArt.VIEW_H)
		var bw: float = bh * BridgeArt.ASPECT
		var ang: float = atan2(dirv.x, -dirv.y)
		draw_set_transform(b_foot + Vector2(5, 3), ang, Vector2.ONE)
		draw_texture_rect(btex, Rect2(-bw * 0.5, -bh * BridgeArt.FOOT_Y, bw, bh), false, Color(0, 0, 0, 0.30))
		draw_set_transform(b_foot, ang, Vector2.ONE)
		draw_texture_rect(btex, Rect2(-bw * 0.5, -bh * BridgeArt.FOOT_Y, bw, bh), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# a small picture on the left of the back wall, in a gilt frame with a cream mat, hung by a wire
	# from a nail and just a touch askew
	if picture != null:
		var pw: float = maxf(w * 0.075, 32.0)
		var pc: Vector2 = Vector2(w * 0.205, h * 0.215)
		var nail: Vector2 = pc + Vector2(0.0, -pw * 0.78)
		draw_line(nail, pc + Vector2(-pw * 0.38, -pw * 0.48), Color(0.55, 0.50, 0.40, 0.8), 1.0, true)
		draw_line(nail, pc + Vector2(pw * 0.38, -pw * 0.48), Color(0.55, 0.50, 0.40, 0.8), 1.0, true)
		draw_circle(nail, 1.8, BRASS)
		draw_set_transform(pc, -0.035, Vector2.ONE)
		var outer: Rect2 = Rect2(-pw * 0.5, -pw * 0.5, pw, pw)
		draw_rect(Rect2(outer.position + Vector2(3, 4), outer.size), Color(0, 0, 0, 0.40))
		draw_rect(outer, Color(0.62, 0.46, 0.18))
		draw_rect(outer.grow(-pw * 0.06), Color(0.82, 0.66, 0.30))
		draw_rect(outer.grow(-pw * 0.09), Color(0.50, 0.36, 0.13))
		draw_line(outer.position + Vector2(1, 1), Vector2(outer.end.x - 1, outer.position.y + 1), Color(1, 0.92, 0.6, 0.6), 1.2)
		var mat: Rect2 = outer.grow(-pw * 0.11)
		draw_rect(mat, Color(0.92, 0.89, 0.80))
		var art: Rect2 = mat.grow(-pw * 0.07)
		draw_texture_rect(picture, art, false)
		draw_rect(art, Color(0, 0, 0, 0.35), false, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the scoring wire on the left wall: a brass wire with beads, some slid over to one end
	var wy: float = h * 0.30
	var wx0: float = w * 0.13
	var wx1: float = w * 0.30
	draw_line(Vector2(wx0, wy), Vector2(wx1, wy), BRASS, 1.5)
	for e in [wx0, wx1]:
		draw_rect(Rect2(e - 2.0, wy - 5.0, 4.0, 10.0), WAINSCOT_DARK)
	for k in 9:
		var bx: float = (wx0 + 6.0 + float(k) * 7.0) if k < 5 else (wx1 - 6.0 - float(8 - k) * 7.0)
		draw_circle(Vector2(bx + 1.0, wy + 1.5), 3.4, Color(0, 0, 0, 0.35))
		draw_circle(Vector2(bx, wy), 3.4, Color(0.70, 0.12, 0.10) if k % 2 == 0 else Color(0.90, 0.85, 0.72))
		draw_circle(Vector2(bx - 1.0, wy - 1.2), 1.0, Color(1, 1, 1, 0.5))

# A cue leaning on the wall from the floor at `a` to its tip at `b`, tapering from w0 to w1: the dark
# butt with its wrap, the inlaid points of the forearm, the long maple shaft, the white ferrule and
# the blue tip -- and its shadow on the wall.
func _cue(a: Vector2, b: Vector2, w0: float, w1: float) -> void:
	var d: Vector2 = (b - a).normalized()
	var n: Vector2 = d.orthogonal()
	draw_line(a + Vector2(4, 2), b + Vector2(5, 3), Color(0, 0, 0, 0.28), w0 * 0.8, true)
	var parts: Array = [[0.00, 0.22, Color(0.22, 0.09, 0.04)], [0.22, 0.32, Color(0.08, 0.07, 0.07)],
		[0.32, 0.46, Color(0.30, 0.13, 0.05)], [0.46, 0.965, Color(0.86, 0.74, 0.52)],
		[0.965, 0.985, Color(0.96, 0.95, 0.92)], [0.985, 1.0, Color(0.20, 0.38, 0.70)]]
	for pt in parts:
		var t0: float = float(pt[0])
		var t1: float = float(pt[1])
		var p0: Vector2 = a.lerp(b, t0)
		var p1: Vector2 = a.lerp(b, t1)
		var hw0: float = lerpf(w0, w1, t0) * 0.5
		var hw1: float = lerpf(w0, w1, t1) * 0.5
		draw_colored_polygon(PackedVector2Array([p0 + n * hw0, p1 + n * hw1, p1 - n * hw1, p0 - n * hw0]), pt[2])
	# the forearm's points: pale inlays running up into the shaft
	for sgn in [-1.0, 1.0]:
		var base: Vector2 = a.lerp(b, 0.34)
		var tip: Vector2 = a.lerp(b, 0.47)
		var hw: float = lerpf(w0, w1, 0.34) * 0.5
		draw_colored_polygon(PackedVector2Array([base + n * hw * 0.9 * sgn, base, tip + n * hw * 0.2 * sgn]), Color(0.88, 0.78, 0.58))
	# a lit edge down its length
	draw_line(a + n * w0 * 0.3, b + n * w1 * 0.3, Color(1, 1, 1, 0.22), 1.0, true)

# The billiard lamp over the table: a brass bar on two chains, three green glass shades, each throwing
# a warm cone down the screen toward the felt.
func _draw_lamp(w: float, h: float) -> void:
	var bar_y: float = h * 0.075
	var x0: float = w * 0.22
	var x1: float = w * 0.78
	var sw: float = maxf(w * 0.075, 24.0)
	var sh: float = sw * 0.55
	for k in 3:
		var lx: float = lerpf(x0 + sw * 0.6, x1 - sw * 0.6, float(k) / 2.0)
		var mouth: float = bar_y + 6.0 + sh
		draw_polygon(PackedVector2Array([Vector2(lx - sw * 0.5, mouth), Vector2(lx + sw * 0.5, mouth),
			Vector2(lx + w * 0.13, h * 0.52), Vector2(lx - w * 0.13, h * 0.52)]),
			PackedColorArray([Color(LIGHT.r, LIGHT.g, LIGHT.b, 0.13), Color(LIGHT.r, LIGHT.g, LIGHT.b, 0.13),
				Color(LIGHT.r, LIGHT.g, LIGHT.b, 0.0), Color(LIGHT.r, LIGHT.g, LIGHT.b, 0.0)]))
	for cx in [x0, x1]:
		draw_line(Vector2(cx, 0.0), Vector2(cx, bar_y), Color(BRASS.r, BRASS.g, BRASS.b, 0.6), 1.5)
	draw_rect(Rect2(x0 - 6.0, bar_y - 2.0, x1 - x0 + 12.0, 5.0), BRASS.darkened(0.3))
	draw_line(Vector2(x0 - 6.0, bar_y - 2.0), Vector2(x1 + 6.0, bar_y - 2.0), BRASS.lightened(0.25), 1.5)
	for k2 in 3:
		var lx2: float = lerpf(x0 + sw * 0.6, x1 - sw * 0.6, float(k2) / 2.0)
		var top: float = bar_y + 4.0
		draw_line(Vector2(lx2, bar_y), Vector2(lx2, top), BRASS, 2.0)
		var shade: PackedVector2Array = PackedVector2Array([Vector2(lx2 - sw * 0.16, top), Vector2(lx2 + sw * 0.16, top),
			Vector2(lx2 + sw * 0.5, top + sh), Vector2(lx2 - sw * 0.5, top + sh)])
		draw_polygon(shade, PackedColorArray([SHADE_LIT, SHADE_LIT, SHADE, SHADE]))
		draw_line(Vector2(lx2 - sw * 0.5, top + sh), Vector2(lx2 + sw * 0.5, top + sh), BRASS, 2.0)
		for g in 3:
			draw_circle(Vector2(lx2, top + sh + 2.0), sw * (0.30 - 0.08 * float(g)), Color(1.0, 0.92, 0.70, 0.12 + 0.12 * float(g)))

func _draw_vignette(w: float, h: float) -> void:
	var clear: Color = Color(0, 0, 0, 0)
	var bv: float = h * 0.20
	var bh: float = w * 0.22
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, bv), Vector2(0, bv)]),
		PackedColorArray([VIGNETTE, VIGNETTE, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, h - bv), Vector2(w, h - bv), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([clear, clear, VIGNETTE, VIGNETTE]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(bh, 0), Vector2(bh, h), Vector2(0, h)]),
		PackedColorArray([VIGNETTE, clear, clear, VIGNETTE]))
	draw_polygon(PackedVector2Array([Vector2(w - bh, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - bh, h)]),
		PackedColorArray([clear, VIGNETTE, VIGNETTE, clear]))

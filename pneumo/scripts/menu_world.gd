extends "res://scripts/menu_poster.gd"

# PNEUMO'S OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): THE PNEUMATIC POST ROOM.
# A wall of deep teal glazed tiles under a hanging lamp, and across it GLASS TUBES with brass collars: one
# feed comes in from the left, runs to a brass JUNCTION with a glass-faced dial, and three tubes run on down to
# three RECEIVERS standing on an oak counter, each with its colored lamp and plate. Capsules -- steel-capped
# canisters in the game's way (capsule_art.gd: shaded as cylinders, a light label band, dark seal rings) --
# shoot along the feed one after another; before each one reaches the junction its dial TURNS (eased) to that
# capsule's receiver, the capsule takes that branch, drops into its receiver and the lamp there flashes: the
# game's doors, as a picture. All of it is seen square-on (the wall faces us), the tubes and the receivers
# shaded as cylinders lit from the upper left. A pressure gauge with a trembling needle, a valve wheel and a
# vent breathing steam. Everything follows one clock (`t`), so nothing pops and the loop never jumps.
# Made up, never the board: the menu also opens mid-game.

const GAP: float = 1.3               # seconds between capsules
const SPEED: float = 340.0           # screen units a second
const R: float = 21.0                # a tube's outer radius
const CAP_L: float = 60.0            # a capsule's length
const CAP_W: float = 30.0
# which receiver each capsule in turn is bound for (0 left, 1 center, 2 right)
const ROUTE: Array = [1, 0, 2, 2, 1, 0, 1, 2, 0]
const HUES: Array = [Color(0.88, 0.30, 0.26), Color(0.26, 0.62, 0.70), Color(0.94, 0.68, 0.22)]
const LIP_R: float = 29.0           # a receiver's bell: the radius of its lip
const LIP_DROP: float = 8.0         # the lip above the tube's end
const BRASS: Color = Color(0.78, 0.60, 0.28)
const BRASS_DARK: Color = Color(0.40, 0.28, 0.10)
const BRASS_LIT: Color = Color(1.0, 0.90, 0.62)

var _wall: Control = null
var _back: Control = null
var _caps: Control = null
var _front: Control = null
var _over: Control = null
var _feed: PackedVector2Array = PackedVector2Array()
var _branches: Array = []            # three PackedVector2Array, from the junction to each receiver's mouth
var _feed_len: float = 1.0
var _branch_len: Array = [1.0, 1.0, 1.0]
var _junction: Vector2 = Vector2.ZERO
var _recv: Array = []                # receivers' mouths
var _for_bottom: float = -2.0

func _setup() -> void:
	# WHAT NEVER MOVES IS BAKED (menu_poster.gd `add_still`): the wall, the tubes' backs and the receivers' mouths,
	# the glass, the junction's housing, the receivers, the gauge and the valve -- all of it was redrawn every frame
	# (a heavy frame on a phone). Live: the capsules, and over everything the dial's pointer, the gauge's needle,
	# the receivers' lamps when they flash, the steam
	_wall = add_still(func(d: Control) -> void: _draw_wall(d))
	_back = add_still(func(d: Control) -> void: _draw_back(d))
	_caps = _mk(func(d: Control) -> void: _draw_capsules(d))
	_front = add_still(func(d: Control) -> void: _draw_front(d))
	# over everything: in three parts (2026-11-19, redrawn whole every frame it cost a phone ~12 ms) -- what turns and
	# points (live), the brass and the wheel's rim (drawn once), what flashes and drifts (live)
	_over = _mk(func(d: Control) -> void: _draw_over(d, 0))
	_over_still = cached_layer(func(d: Control) -> void: _draw_over(d, 1))
	_over2 = _mk(func(d: Control) -> void: _draw_over(d, 2))

var _over_still: Control = null
var _over2: Control = null

func _mk(fn: Callable) -> Control:
	var c: Control = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.draw.connect(fn.bind(c))
	add_child(c)
	return c

# --- the layout ------------------------------------------------------------------------------------------

# THE LAYOUT FOLLOWS THE ROOM THERE IS: the receivers as tall as the height allows, the junction between
# the feed and their mouths, and every branch DROPPING all the way -- down out of the junction, across, and
# straight down into its mouth. (On a short desktop menu the bends had been placed above the junction and below
# the mouth: the tube came up into the receiver from beneath, and an arriving capsule went on up out of it.)
func _lay() -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var top: float = 250.0 if mobile else 165.0
	var counter_y: float = bottom - 26.0
	# a little lower where the height allows, so the gauge above it clears the title
	var feed_y: float = top + (56.0 if counter_y - top > 340.0 else 22.0)
	var recv_h: float = clampf((counter_y - feed_y) * 0.30, 58.0, 92.0)
	var mouth_y: float = counter_y - recv_h
	_junction = Vector2(full.x * 0.52, feed_y + (mouth_y - feed_y) * 0.36)
	_feed = _rounded([Vector2(-40.0, feed_y), Vector2(_junction.x, feed_y), _junction], 46.0)
	_feed_len = _length(_feed)
	_recv.clear()
	_branches.clear()
	var drop: float = mouth_y - _junction.y
	var xs: Array = [full.x * 0.18, full.x * 0.52, full.x * 0.84]
	for b in 3:
		var m: Vector2 = Vector2(xs[b], mouth_y)
		_recv.append(m)
		var br: PackedVector2Array = PackedVector2Array([_junction, m])
		if b != 1:
			# down out of the junction (past the dial), across and down, then straight down into the mouth
			var y1: float = _junction.y + drop * 0.30
			var y2: float = _junction.y + drop * 0.55
			br = _rounded([_junction, Vector2(_junction.x, y1), Vector2(m.x, y2), m], minf(40.0, drop * 0.25))
		_branches.append(br)
		_branch_len[b] = _length(br)

# a polyline through `pts` with each corner rounded by an arc of radius `rad`, sampled finely
func _rounded(pts: Array, rad: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	out.append(pts[0])
	for i in range(1, pts.size() - 1):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var c: Vector2 = pts[i + 1]
		var d0: Vector2 = (a - b).normalized()
		var d1: Vector2 = (c - b).normalized()
		var r2: float = minf(rad, minf(a.distance_to(b), c.distance_to(b)) * 0.45)
		var p0: Vector2 = b + d0 * r2
		var p1: Vector2 = b + d1 * r2
		for k in 13:
			var u: float = float(k) / 12.0
			out.append(p0.lerp(b, u).lerp(b.lerp(p1, u), u))
	out.append(pts[pts.size() - 1])
	return out

func _length(pl: PackedVector2Array) -> float:
	var sum: float = 0.0
	for i in range(1, pl.size()):
		sum += pl[i].distance_to(pl[i - 1])
	return sum

# the point and the direction at a distance along a polyline
func _at(pl: PackedVector2Array, s: float) -> Array:
	var acc: float = 0.0
	for i in range(1, pl.size()):
		var seg: float = pl[i].distance_to(pl[i - 1])
		if acc + seg >= s or i == pl.size() - 1:
			var u: float = clampf((s - acc) / maxf(seg, 0.001), 0.0, 1.0)
			return [pl[i - 1].lerp(pl[i], u), (pl[i] - pl[i - 1]).normalized()]
		acc += seg
	return [pl[pl.size() - 1], Vector2.DOWN]

func _tick(_delta: float) -> void:
	if absf(scene_bottom - _for_bottom) > 0.5:
		_for_bottom = scene_bottom
		_lay()
		_wall.queue_redraw()
		_back.queue_redraw()
		_front.queue_redraw()
		_over_still.queue_redraw()
	_caps.queue_redraw()
	_over.queue_redraw()
	_over2.queue_redraw()

# --- the wall: tiles, the lamp's light, the counter, decorative pipework: drawn once ------------------------

func _draw_wall(d: Control) -> void:
	if _feed.is_empty():
		_lay()
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var counter_y: float = bottom - 26.0
	d.draw_rect(Rect2(Vector2.ZERO, full), Color(0.05, 0.16, 0.16))
	# glazed tiles in a running bond, each with a bevel: lit top-left edge, dark bottom-right, a glaze sheen
	var tw: float = 58.0
	var th: float = 29.0
	var row: int = 0
	var y: float = 0.0
	while y < counter_y:
		var x: float = -tw * 0.5 * float(row % 2)
		var k: int = 0
		while x < full.x:
			var tone: float = 0.9 + 0.2 * h01(row * 41 + k)
			var r: Rect2 = Rect2(x + 1.5, y + 1.5, tw - 3.0, th - 3.0)
			d.draw_rect(r, Color(0.08 * tone, 0.30 * tone, 0.30 * tone))
			d.draw_line(r.position, Vector2(r.end.x, r.position.y), Color(0.40, 0.70, 0.66, 0.35), 1.5)
			d.draw_line(r.position, Vector2(r.position.x, r.end.y), Color(0.40, 0.70, 0.66, 0.22), 1.5)
			d.draw_line(Vector2(r.position.x, r.end.y), r.end, Color(0, 0, 0, 0.35), 1.5)
			d.draw_line(Vector2(r.end.x, r.position.y), r.end, Color(0, 0, 0, 0.25), 1.5)
			d.draw_rect(Rect2(r.position + Vector2(4, 3), Vector2(r.size.x * 0.4, 3)), Color(1, 1, 1, 0.06))
			x += tw
			k += 1
		y += th
		row += 1
	# the lamp's warm pool from above, and the corners falling into shade
	for k in 22:
		d.draw_circle(Vector2(full.x * 0.5, -40.0), full.x * (1.05 - 0.045 * float(k)), Color(1.0, 0.80, 0.48, 0.022))
	for side in [0.0, 1.0]:
		var x0: float = side * full.x
		var x1: float = x0 + (full.x * 0.25 if side == 0.0 else -full.x * 0.25)
		d.draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, full.y), Vector2(x0, full.y)]),
			PackedColorArray([Color(0, 0, 0, 0.40), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.40)]))
	# a thin steam pipe along the wall behind everything, with its valve wheel
	var py: float = _feed[0].y           # at the feed's height, on the right where the wall is clear
	# THE AIR SUPPLY: a silver pipe in from the right at the feed's height, past its valve wheel, bending down
	# and into the junction's housing from the side (it ended in mid-wall)
	var air: PackedVector2Array = _rounded([Vector2(full.x + 20.0, py), Vector2(_junction.x + 110.0, py), Vector2(_junction.x + 110.0, _junction.y), Vector2(_junction.x + R * 1.8, _junction.y)], 26.0)
	for i in range(1, air.size()):
		_pipe(d, air[i - 1], air[i] + (air[i] - air[i - 1]).normalized() * 0.8, 7.0, Color(0.46, 0.44, 0.42))
	# a flange where it meets the housing, and the vent's stub on top near the right
	_cyl(d, Vector2(_junction.x + R * 1.8 + 6.0, _junction.y - 11.0), Vector2(_junction.x + R * 1.8 + 6.0, _junction.y + 11.0), 4.0, Color(0.2, 0.2, 0.22), Color(0.55, 0.53, 0.5), Color(0.9, 0.9, 0.9))
	_cyl(d, Vector2(full.x * 0.95, py - 7.0), Vector2(full.x * 0.95, py - 20.0), 3.5, Color(0.2, 0.2, 0.22), Color(0.46, 0.44, 0.42), Color(0.85, 0.85, 0.85))
	# the oak counter the receivers stand on
	var top_r: Rect2 = Rect2(0.0, counter_y, full.x, 14.0)
	d.draw_polygon(PackedVector2Array([top_r.position, Vector2(top_r.end.x, top_r.position.y), top_r.end, Vector2(0, top_r.end.y)]),
		PackedColorArray([Color(0.62, 0.40, 0.20), Color(0.62, 0.40, 0.20), Color(0.42, 0.26, 0.12), Color(0.42, 0.26, 0.12)]))
	d.draw_line(top_r.position, Vector2(full.x, counter_y), Color(0.92, 0.72, 0.46), 2.0)
	d.draw_rect(Rect2(0.0, counter_y + 14.0, full.x, full.y - counter_y), Color(0.30, 0.18, 0.08))
	for k in 9:
		var gx: float = full.x * h01(k + 60)
		d.draw_line(Vector2(gx, counter_y + 18.0), Vector2(gx + 60.0, counter_y + 18.0 + 4.0 * h01(k + 61)), Color(0.20, 0.11, 0.04, 0.5), 1.0)

# THE ROUND SHADING (the user: "things that are supposed to look like rounded cylinders divided into
# noticeable stripes"): a cylinder side-on is shaded by the angle round it, so it is laid out in strips at
# EVEN ANGLES (narrow at the edges, as a real one foreshortens) whose colors are given AT THEIR EDGES and
# blended across -- one smooth turn, no bands. Lit from the upper left; a soft specular streak on the lit side.
func _shade(m: float, dark: Color, mid: Color, lit: Color) -> Color:
	# m: -1 the side away from the light .. +1 the side toward it
	var lam: float = clampf(0.5 + 0.5 * (m * 0.7 + sqrt(maxf(0.0, 1.0 - m * m)) * 0.55), 0.0, 1.0)
	var col: Color = dark.lerp(mid, clampf(lam * 1.6, 0.0, 1.0))
	var spec: float = exp(-pow((m - 0.45) / 0.16, 2.0))
	return col.lerp(lit, spec * 0.85)

# a cylinder of radius r along a -> b, side-on
func _cyl(d: CanvasItem, a: Vector2, b: Vector2, r: float, dark: Color, mid: Color, lit: Color) -> void:
	var dir: Vector2 = (b - a).normalized()
	var n: Vector2 = dir.orthogonal()
	# n points to the light's side: up, or left on an upright one
	if n.y > 0.01 or (absf(n.y) <= 0.01 and n.x > 0.0):
		n = -n
	var steps: int = 18
	for k in steps:
		var th0: float = -PI * 0.5 + PI * float(k) / float(steps)
		var th1: float = -PI * 0.5 + PI * float(k + 1) / float(steps)
		var f0: float = sin(th0)
		var f1: float = sin(th1)
		var c0: Color = _shade(f0, dark, mid, lit)
		var c1: Color = _shade(f1, dark, mid, lit)
		d.draw_polygon(PackedVector2Array([a + n * r * f0, b + n * r * f0, b + n * r * f1, a + n * r * f1]), PackedColorArray([c0, c0, c1, c1]))

# a plain metal pipe, shaded as a cylinder across its width
func _pipe(d: CanvasItem, a: Vector2, b: Vector2, r: float, col: Color) -> void:
	_cyl(d, a, b, r, col.darkened(0.6), col, col.lightened(0.5))

# --- the tubes: the glass's back (behind the capsules) and front (over them) ------------------------------

func _tube_lines() -> Array:
	var all: Array = [_feed]
	for br in _branches:
		all.append(br)
	return all

# UNDER the tubes and the capsules: each receiver's shadow on the wall and the BACK of its bell -- the far
# half of its lip and the dark inside of its mouth -- so a tube goes down INTO the mouth and a capsule drops
# in behind the near lip (the whole bell drawn over them hid both: "nothing actually enters them")
func _draw_back(d: Control) -> void:
	if _feed.is_empty():
		_lay()
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var counter_y: float = bottom - 26.0
	for b in _recv.size():
		var m: Vector2 = _recv[b]
		d.draw_rect(Rect2(m.x - R * 1.4 + 6.0, m.y + 8.0, R * 2.8, counter_y - m.y - 8.0), Color(0, 0, 0, 0.25))
		var bt: float = m.y - LIP_DROP
		var kl: float = _ring_k(bt)
		_ell(d, Vector2(m.x, bt), LIP_R, LIP_R * kl, BRASS.darkened(0.25))
		_ell(d, Vector2(m.x, bt), LIP_R - 4.0, (LIP_R - 4.0) * kl, Color(0.06, 0.05, 0.03))
	_draw_tubes(d, false)

func _draw_tubes(d: Control, front: bool) -> void:
	for pl in _tube_lines():
		var line: PackedVector2Array = pl
		if not front:
			# a soft shadow on the wall below, then the inside of the tube: dim, the tiles seen through glass
			# filled as outlines (a thick polyline notched at every bend)
			_band(d, _offset(line, Vector2(4, 7)), R, -R, Color(0, 0, 0, 0.28))
			_band(d, line, R, -R, Color(0.08, 0.19, 0.19))
			_band(d, line, R * 0.7, -R * 0.7, Color(0.13, 0.28, 0.27))
		else:
			# the glass: dark rims at both edges, a bright streak along the upper third, a fainter one low
			d.draw_polyline(_side(line, R - 1.5), Color(0.02, 0.06, 0.06, 0.8), 3.0, true)
			d.draw_polyline(_side(line, -(R - 1.5)), Color(0.02, 0.06, 0.06, 0.8), 3.0, true)
			d.draw_polyline(_lit_side(line, R * 0.5), Color(1, 1, 1, 0.38), 3.0, true)
			d.draw_polyline(_lit_side(line, R * 0.62), Color(1, 1, 1, 0.12), 6.0, true)
			d.draw_polyline(_lit_side(line, -R * 0.62), Color(0.7, 0.95, 0.9, 0.10), 2.0, true)
			# brass collars along it
			var ln: float = _length(line)
			var k: int = 1
			while float(k) * 120.0 < ln - 40.0:
				var a: Array = _at(line, float(k) * 120.0)
				_collar(d, a[0], a[1])
				k += 1

# the strip between two offsets of a line, as one polygon
func _band(d: CanvasItem, line: PackedVector2Array, off_a: float, off_b: float, col: Color) -> void:
	var a: PackedVector2Array = _side(line, off_a)
	var b: PackedVector2Array = _side(line, off_b)
	b.reverse()
	var poly: PackedVector2Array = a + b
	if Geometry2D.triangulate_polygon(poly).size() > 0:
		d.draw_colored_polygon(poly, col)

# the line moved to one side of itself, the SAME side all along (it flipped to the lit side point by point,
# and through a bend the two edges crossed: the tube twisted into a thin dark pipe there)
func _side(line: PackedVector2Array, off: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i in line.size():
		var a: Vector2 = line[maxi(i - 1, 0)]
		var b: Vector2 = line[mini(i + 1, line.size() - 1)]
		out.append(line[i] + (b - a).normalized().orthogonal() * off)
	return out

# a line along the glass on the side facing the light, wherever the tube turns: its place across the tube
# follows the light smoothly round a bend (on top of a level run, on the left of an upright one)
func _lit_side(line: PackedVector2Array, off: float) -> PackedVector2Array:
	var light: Vector2 = Vector2(-0.6, -0.8)
	var out: PackedVector2Array = PackedVector2Array()
	for i in line.size():
		var a: Vector2 = line[maxi(i - 1, 0)]
		var b: Vector2 = line[mini(i + 1, line.size() - 1)]
		var n: Vector2 = (b - a).normalized().orthogonal()
		out.append(line[i] + n * off * clampf(n.dot(light) / 0.6, -1.0, 1.0))
	return out

func _offset(line: PackedVector2Array, o: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p in line:
		out.append(p + o)
	return out

# a brass collar round the tube: a short band across it, shaded as a cylinder, with two bolts
func _collar(d: CanvasItem, p: Vector2, dir: Vector2) -> void:
	var n: Vector2 = dir.orthogonal()
	if n.y > 0.0:
		n = -n
	# a short brass band round the glass: across the tube it is the tube's own round, so shaded as a cylinder
	# whose axis runs ACROSS -- from one side of the tube to the other
	_cyl(d, p - n * (R + 3.0), p + n * (R + 3.0), 6.0, BRASS_DARK, BRASS, BRASS_LIT)
	# and its turn round the tube: darker toward both edges of the tube, where it curves away
	for e in [-1.0, 1.0]:
		d.draw_polygon(PackedVector2Array([p + n * e * (R + 3.0) - dir * 6.0, p + n * e * (R + 3.0) + dir * 6.0, p + n * e * R * 0.4 + dir * 6.0, p + n * e * R * 0.4 - dir * 6.0]),
			PackedColorArray([Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
	_knob(d, p + n * (R + 0.5), 1.9, BRASS)
	_knob(d, p - n * (R + 0.5), 1.9, BRASS)

# --- the capsules ------------------------------------------------------------------------------------------

func _draw_capsules(d: Control) -> void:
	if _feed.is_empty():
		return
	var n0: int = int(floor(t / GAP)) - 4
	for i in range(n0, n0 + 6):
		var born: float = float(i) * GAP
		var s: float = (t - born) * SPEED
		if s < 0.0:
			continue
		var b: int = ROUTE[posmod(i, ROUTE.size())]
		var where: Array = []
		if s < _feed_len:
			where = _at(_feed, s)
		elif s - _feed_len < float(_branch_len[b]) + CAP_L:
			where = _at(_branches[b], s - _feed_len)
			if s - _feed_len > float(_branch_len[b]):
				# on into the receiver (it is drawn over, so the capsule goes in out of sight)
				where = [Vector2(where[0]) + Vector2(where[1]) * (s - _feed_len - float(_branch_len[b])), where[1]]
		else:
			continue
		_capsule(d, where[0], where[1], HUES[b], s)

# one canister, side-on along its direction: a cylinder in its color shaded across its width, a lighter
# label band that drifts round as it rolls, steel caps with dark seals, a glint along its length
func _capsule(d: CanvasItem, p: Vector2, dir: Vector2, hue: Color, s: float) -> void:
	var n: Vector2 = dir.orthogonal()
	if n.y > 0.01 or (absf(n.y) <= 0.01 and n.x > 0.0):
		n = -n
	var hl: float = CAP_L * 0.5
	var hw: float = CAP_W * 0.5
	var steel: Color = Color(0.70, 0.73, 0.78)
	# the body, smooth round
	_cyl(d, p - dir * (hl - 8.0), p + dir * (hl - 8.0), hw, hue.darkened(0.6), hue, hue.lightened(0.55))
	# the end caps: domed steel -- strips at even angles, each as long as the dome is deep there
	for e in [-1.0, 1.0]:
		var base: Vector2 = p + dir * e * (hl - 8.0)
		var steps: int = 18
		for k in steps:
			var th0: float = -PI * 0.5 + PI * float(k) / float(steps)
			var th1: float = -PI * 0.5 + PI * float(k + 1) / float(steps)
			var f0: float = sin(th0)
			var f1: float = sin(th1)
			var l0: float = 8.0 * cos(th0)
			var l1: float = 8.0 * cos(th1)
			var c0: Color = _shade(f0, steel.darkened(0.6), steel, Color(1, 1, 1))
			var c1: Color = _shade(f1, steel.darkened(0.6), steel, Color(1, 1, 1))
			d.draw_polygon(PackedVector2Array([base + n * hw * 0.9 * f0, base + dir * e * l0 + n * hw * 0.9 * f0, base + dir * e * l1 + n * hw * 0.9 * f1, base + n * hw * 0.9 * f1]),
				PackedColorArray([c0, c0, c1, c1]))
		# the dark seal ring between cap and body
		d.draw_line(base + n * hw, base - n * hw, Color(0.10, 0.10, 0.12), 2.5)
	# the label band, wrapping round: it drifts across the width as the canister rolls, foreshortened toward
	# the edges and out of sight round the back
	var ang: float = fposmod(s * 0.004, 1.0) * TAU
	if cos(ang) > 0.0:
		d.draw_line(p - dir * (hl - 12.0) + n * hw * sin(ang), p + dir * (hl - 12.0) + n * hw * sin(ang), Color(hue.lightened(0.6), 0.75), maxf(6.0 * cos(ang), 0.5))

# --- in front: the glass, the junction and its dial, the receivers, the feed's flange, the gauge, steam ----

func _draw_front(d: Control) -> void:
	if _feed.is_empty():
		return
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var counter_y: float = bottom - 26.0
	_draw_tubes(d, true)
	# THE JUNCTION: a round brass housing, a glass face, the dial's pointer turned to the next capsule's tube
	var jr: float = R * 2.3
	d.draw_circle(_junction + Vector2(4, 7), jr, Color(0, 0, 0, 0.3))
	_brass_disc(d, _junction, jr)
	d.draw_circle(_junction, jr * 0.70, Color(0.95, 0.92, 0.82))
	for k in 3:
		var dir_k: Vector2 = (_at(_branches[k], 60.0)[1] as Vector2)
		d.draw_circle(_junction + dir_k * jr * 0.52, 4.0, HUES[k])
	# (the pointer is live: _draw_over)
	# THE RECEIVERS: a brass bell over each mouth, a body down to the counter, a lamp that flashes on arrival
	for b in 3:
		var m: Vector2 = _recv[b]
		_receiver(d, m, counter_y, HUES[b], 0.0)
	var fy: float = _feed[0].y
	# a PRESSURE GAUGE on the feed, its needle trembling round its mark
	# on the wall above the feed -- only where there is room under the title (a short desktop menu has none)
	var gc: Vector2 = Vector2(full.x * 0.27, fy - R - 36.0)
	if counter_y - fy < 300.0:
		gc = Vector2(-200.0, -200.0)
	_brass_disc(d, gc, 28.0)
	d.draw_circle(gc, 21.0, Color(0.96, 0.93, 0.84))
	for k in 9:
		var ta: float = PI * 0.8 + PI * 1.4 * float(k) / 8.0
		d.draw_line(gc + Vector2.from_angle(ta) * 15.0, gc + Vector2.from_angle(ta) * 19.0, Color(0.2, 0.2, 0.2), 1.2)
	d.draw_arc(gc, 17.0, PI * 0.8 + PI * 1.4 * 0.78, PI * 2.2, 8, Color(0.85, 0.2, 0.15), 2.5)
	# (the needle is live: _draw_over)
	# (the steam pipe's valve wheel is live: _draw_over turns it)

# WHAT MOVES, over the baked front: the dial's pointer, the gauge's needle (and the glass over each), a receiver's
# lamp when it flashes, the vent's steam
# `part` 0: the dial's pointer, the wheel's spokes, the gauge's needle (live); 1: the brass knobs and the gauge's and
# dial's glass, the wheel's rim (still); 2: the mark on the rim, the receivers' lamps flashing, the steam (live)
func _draw_over(d: Control, part: int) -> void:
	if _feed.is_empty():
		return
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var counter_y: float = bottom - 26.0
	var jr: float = R * 2.3
	var vw: Vector2 = Vector2(full.x * 0.86, _feed[0].y)
	var red: Color = Color(0.70, 0.16, 0.12)
	var cu: float = fmod(t, 7.0)
	var turn: float = 2.2 * (smoothstep(0.0, 2.2, cu) - smoothstep(3.5, 5.7, cu))
	var fy: float = _feed[0].y
	var gauge: bool = counter_y - fy >= 300.0
	var gc: Vector2 = Vector2(full.x * 0.27, fy - R - 36.0)
	if part == 0:
		var tipv: Vector2 = Vector2.from_angle(_dial_angle())
		d.draw_colored_polygon(PackedVector2Array([_junction + tipv * jr * 0.46, _junction + tipv.orthogonal() * 4.0, _junction - tipv * jr * 0.16, _junction - tipv.orthogonal() * 4.0]), Color(0.12, 0.10, 0.10))
		# the steam pipe's VALVE WHEEL: a cast rim of round section, four spokes, a domed hub -- each shaded round. A
		# hand is working it: a turn one way, a pause, back the other way, a pause
		for k in 4:
			var sa: float = TAU * float(k) / 4.0 + 0.4 + turn
			_cyl(d, vw + Vector2.from_angle(sa) * 3.0, vw + Vector2.from_angle(sa) * 15.0, 2.2, red.darkened(0.6), red, red.lightened(0.5))
		if gauge:
			var na: float = PI * 0.8 + PI * 1.4 * (0.58 + 0.03 * sin(t * 2.3) + 0.015 * sin(t * 7.1))
			d.draw_line(gc, gc + Vector2.from_angle(na) * 17.0, Color(0.12, 0.10, 0.10), 2.0, true)
		return
	if part == 1:
		_knob(d, _junction, 5.0, BRASS)
		d.draw_arc(_junction, jr * 0.70, PI * 1.05, PI * 1.55, 16, Color(1, 1, 1, 0.45), 3.0, true)
		_torus(d, vw, 15.5, 3.0, red.darkened(0.65), red, red.lightened(0.55))
		_knob(d, vw, 5.0, BRASS)
		if gauge:
			_knob(d, gc, 2.8, BRASS)
			d.draw_arc(gc, 21.0, PI * 1.05, PI * 1.5, 12, Color(1, 1, 1, 0.5), 2.5, true)
		return
	# a mark cast on the rim, so the turn reads
	d.draw_circle(vw + Vector2.from_angle(turn - 0.6) * 15.5, 1.4, red.lightened(0.7))
	for b in 3:
		var fl: float = _flash(b)
		if fl <= 0.0:
			continue
		var m: Vector2 = _recv[b]
		var body: Rect2 = Rect2(m.x - R * 1.4, m.y + 10.0, R * 2.8, counter_y - m.y - 10.0)
		var lc: Vector2 = Vector2(m.x, body.position.y + minf(44.0, body.size.y * 0.45))
		var hue: Color = HUES[b]
		for k in 10:
			d.draw_circle(lc, 12.0 + 40.0 * (1.0 - float(k) / 10.0), Color(hue.lightened(0.3), 0.05 * fl))
		_knob(d, lc, 7.5, hue.darkened(0.35).lerp(hue.lightened(0.45), fl))
	var vent: Vector2 = Vector2(full.x * 0.95, _feed[0].y - 22.0)
	for k in 8:
		var su: float = fposmod(t * 0.22 + float(k) / 8.0, 1.0)
		var sp: Vector2 = vent + Vector2(-su * 40.0 + 8.0 * sin(t * 0.8 + float(k)), -su * 110.0)
		d.draw_circle(sp, 6.0 + su * 26.0, Color(0.92, 0.95, 0.96, 0.10 * sin(su * PI)))

# where the junction's dial points: at the branch of the next capsule to reach it, turning (eased) in the
# quiet between the last one clearing the junction and the next arriving
func _dial_angle() -> float:
	var reach: float = _feed_len / SPEED                          # seconds from the feed's start to the junction
	var i: int = int(floor((t - reach) / GAP)) + 1                 # the next capsule to arrive
	var prev_a: float = _branch_angle(ROUTE[posmod(i - 1, ROUTE.size())])
	var next_a: float = _branch_angle(ROUTE[posmod(i, ROUTE.size())])
	var since: float = t - (float(i - 1) * GAP + reach)            # since the last one reached the junction
	var turn: float = smoothstep(0.35, 0.95, since)
	return lerp_angle(prev_a, next_a, turn)

func _branch_angle(b: int) -> float:
	return (_at(_branches[b], 60.0)[1] as Vector2).angle()

# a receiver's lamp: bright the moment a capsule goes in, fading over a second
func _flash(b: int) -> float:
	var best: float = 0.0
	var n0: int = int(floor(t / GAP)) - 4
	for i in range(n0, n0 + 6):
		if ROUTE[posmod(i, ROUTE.size())] != b:
			continue
		var arrive: float = float(i) * GAP + (_feed_len + float(_branch_len[b])) / SPEED
		var since: float = t - arrive
		if since >= 0.0 and since < 1.4:
			best = maxf(best, 1.0 - since / 1.4)
	return best

func _receiver(d: CanvasItem, m: Vector2, counter_y: float, hue: Color, flash: float) -> void:
	var body: Rect2 = Rect2(m.x - R * 1.4, m.y + 10.0, R * 2.8, counter_y - m.y - 10.0)
	# its FOOT on the counter first (the body stands in front of its far half): a wider short drum, its top a
	# ring seen a little from above, a contact shadow
	var foot_r: float = R * 1.6
	_ell(d, Vector2(m.x + 4.0, counter_y + 2.0), foot_r * 1.1, foot_r * 1.1 * _ring_k(counter_y) + 2.0, Color(0, 0, 0, 0.35))
	_brass_cyl(d, Rect2(m.x - foot_r, counter_y - 9.0, foot_r * 2.0, 9.0))
	_ell(d, Vector2(m.x, counter_y - 9.0), foot_r, foot_r * _ring_k(counter_y - 9.0), BRASS.darkened(0.1))
	# the body: a brass cylinder from the bell down to the foot, shaded round, two bands
	_brass_cyl(d, body)
	for by in [body.position.y + 14.0, body.end.y - 12.0]:
		_brass_cyl(d, Rect2(body.position.x - 3.0, by, body.size.x + 6.0, 7.0), true)
	# THE BELL where the tube goes in: a flare widening upward, shaded round; its top edge is the NEAR half of
	# the lip's ellipse, so the far half and the mouth (drawn under the tubes) show above it
	var bt: float = m.y - LIP_DROP
	var bb: float = m.y + 12.0
	var steps: int = 18
	for k in steps:
		var th0: float = -PI * 0.5 + PI * float(k) / float(steps)
		var th1: float = -PI * 0.5 + PI * float(k + 1) / float(steps)
		var c0: Color = _shade(sin(th0), BRASS_DARK, BRASS, BRASS_LIT)
		var c1: Color = _shade(sin(th1), BRASS_DARK, BRASS, BRASS_LIT)
		var wb: float = R * 1.4
		var kl: float = _ring_k(bt) * LIP_R
		var kbb: float = _ring_k(bb) * wb
		d.draw_polygon(PackedVector2Array([Vector2(m.x - LIP_R * sin(th0), bt + cos(th0) * kl), Vector2(m.x - LIP_R * sin(th1), bt + cos(th1) * kl),
			Vector2(m.x - wb * sin(th1), bb + cos(th1) * kbb), Vector2(m.x - wb * sin(th0), bb + cos(th0) * kbb)]), PackedColorArray([c0, c1, c1, c0]))
	# the near lip: a rolled edge along that front curve, lit along its top
	var lip: PackedVector2Array = PackedVector2Array()
	for k in 25:
		var a: float = PI * float(k) / 24.0
		lip.append(Vector2(m.x + cos(a) * LIP_R, bt + sin(a) * LIP_R * _ring_k(bt)))
	d.draw_polyline(lip, BRASS_LIT.darkened(0.05), 3.0, true)
	d.draw_polyline(_offset(lip, Vector2(0, 2.0)), Color(BRASS_DARK, 0.6), 1.0, true)
	# the lamp: a glass dome in the receiver's color, lit when a capsule arrives
	var lc: Vector2 = Vector2(m.x, body.position.y + minf(44.0, body.size.y * 0.45))
	if flash > 0.0:
		for k in 10:
			d.draw_circle(lc, 12.0 + 40.0 * (1.0 - float(k) / 10.0), Color(hue.lightened(0.3), 0.05 * flash))
	_torus(d, lc, 9.0, 2.0, BRASS_DARK, BRASS, BRASS_LIT)
	_knob(d, lc, 7.5, hue.darkened(0.35).lerp(hue.lightened(0.45), flash))
	# a brass plate with the receiver's dot
	var plate: Rect2 = Rect2(m.x - 16.0, body.position.y + 70.0, 32.0, 16.0)
	if plate.end.y < counter_y - 14.0:
		d.draw_rect(plate, BRASS_LIT.darkened(0.15))
		d.draw_rect(plate, BRASS_DARK, false, 1.0)
		d.draw_circle(plate.get_center(), 4.0, hue)

# how far a level ring at height y opens (its depth over its width): nothing at the eye's height (the
# junction), more the lower it is -- the same rule for every lip, band and foot (the lips were opened more
# than the feet below them, the wrong way round)
func _ring_k(y: float) -> float:
	return clampf((y - _junction.y) / 1700.0, 0.0, 0.3)

func _brass_cyl(d: CanvasItem, r: Rect2, band: bool = false) -> void:
	# an upright cylinder, lit from the left; its top and bottom edges curve down a little (seen from above)
	var dark: Color = BRASS_DARK.darkened(0.12) if band else BRASS_DARK
	var mid: Color = BRASS.darkened(0.12) if band else BRASS
	var cx: float = r.get_center().x
	var hw: float = r.size.x * 0.5
	var steps: int = 18
	for k in steps:
		var th0: float = -PI * 0.5 + PI * float(k) / float(steps)
		var th1: float = -PI * 0.5 + PI * float(k + 1) / float(steps)
		var x0: float = cx - hw * sin(th0)
		var x1: float = cx - hw * sin(th1)
		var c0: Color = _shade(sin(th0), dark, mid, BRASS_LIT)
		var c1: Color = _shade(sin(th1), dark, mid, BRASS_LIT)
		var kt: float = _ring_k(r.position.y) * hw
		var kb: float = _ring_k(r.end.y) * hw
		d.draw_polygon(PackedVector2Array([Vector2(x0, r.position.y + cos(th0) * kt), Vector2(x1, r.position.y + cos(th1) * kt), Vector2(x1, r.end.y + cos(th1) * kb), Vector2(x0, r.end.y + cos(th0) * kb)]),
			PackedColorArray([c0, c1, c1, c0]))

func _brass_disc(d: CanvasItem, c: Vector2, r: float) -> void:
	# a round housing facing us with a rolled rim: lit on the upper left, in shadow on the lower right, blended
	# all the way round; the face inside a little dished; domed bolt heads
	_torus(d, c, r * 0.90, r * 0.10, BRASS_DARK, BRASS, BRASS_LIT)
	d.draw_circle(c, r * 0.80, BRASS.darkened(0.15))
	for k in 8:
		_knob(d, c + Vector2.from_angle(TAU * float(k) / 8.0 + 0.2) * r * 0.76, 2.0, BRASS)

# a ring of round section (a rolled rim, a wheel): each short piece colored by how its surface faces the
# light -- bright toward the upper left, dark toward the lower right -- blended along and across
func _torus(d: CanvasItem, c: Vector2, ring_r: float, tube_r: float, dark: Color, mid: Color, lit: Color) -> void:
	var n: int = 64
	var light: Vector2 = Vector2(-0.6, -0.8)
	for k in n:
		var a0: float = TAU * float(k) / float(n)
		var a1: float = TAU * float(k + 1) / float(n)
		for half in 2:
			var sgn: float = 1.0 if half == 0 else -1.0
			var f0: float = (Vector2.from_angle(a0) * sgn).dot(light)
			var f1: float = (Vector2.from_angle(a1) * sgn).dot(light)
			var e0: Color = _shade(clampf(f0 * 0.9, -1.0, 1.0), dark, mid, lit).darkened(0.25)
			var e1: Color = _shade(clampf(f1 * 0.9, -1.0, 1.0), dark, mid, lit).darkened(0.25)
			var k0: Color = _shade(clampf(f0 * 0.5 + 0.2, -1.0, 1.0), dark, mid, lit)
			var k1: Color = _shade(clampf(f1 * 0.5 + 0.2, -1.0, 1.0), dark, mid, lit)
			var r_edge: float = ring_r + sgn * tube_r
			d.draw_polygon(PackedVector2Array([c + Vector2.from_angle(a0) * ring_r, c + Vector2.from_angle(a1) * ring_r, c + Vector2.from_angle(a1) * r_edge, c + Vector2.from_angle(a0) * r_edge]),
				PackedColorArray([k0, k1, e1, e0]))

# a knob or a bolt head: a dome facing us, shaded smoothly from its lit upper left to its dark lower right
func _knob(d: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var n: int = 14
	for k in n:
		var f: float = float(k) / float(n - 1)
		d.draw_circle(c + Vector2(-0.3, -0.35) * r * f, r * (1.0 - 0.85 * f), col.darkened(0.55).lerp(col.lightened(0.45), f))
	d.draw_circle(c + Vector2(-0.35, -0.4) * r, r * 0.18, Color(1, 1, 1, 0.6))

func _ell(d: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	d.draw_set_transform(c, 0.0, Vector2(1.0, ry / maxf(rx, 0.001)))
	d.draw_circle(Vector2.ZERO, rx, col)
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Pneumo", "Manage your pneumatic tubes deliveries", Color(1.0, 0.86, 0.52), Color(0.10, 0.06, 0.02),
		Color(1.0, 0.80, 0.40, 0.25))

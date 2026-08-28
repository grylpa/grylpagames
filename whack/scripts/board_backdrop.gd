extends RefCounted
class_name WhackBoardBackdrop

# Whack's board, seen FROM ABOVE — because that is how the game is seen. The targets are circles
# lying on a surface with a countdown ring around each; there is no horizon and no depth in this
# game, so a backdrop with a horizon in it is a different picture from the one being played.
#
# It is a fairground whack-a-mole box looked down into: a striped fairground rail around the four
# sides, mown turf inside it, scattered earth where things have been coming up, and the stall lamp
# overhead as a pool of light on the grass.
#
# Two earlier attempts, both worth not repeating:
#
#  - **A shooting range** — concentric rings and crosshairs at 3% alpha. Technically on-topic, and
#    wallpaper: a dark screen with some faint lines on it. Faintness is not what keeps scenery out
#    of a game's way.
#  - **The same stall from the SIDE** — awning overhead, posts at the sides, earth along the bottom.
#    It read well as a picture and it was the wrong projection: a booth seen side-on behind targets
#    that are lying flat.
#
# What keeps it clear of the game is placement and shape, not faintness:
#
#  - **Nothing filled and circular.** A filled circle on this board is a target and the player is
#    being timed against it. The earth is drawn as irregular polygons, the lamp is a soft texture.
#  - **The middle is the quietest part.** The rail is at the edges, the earth patches hug them, and
#    the center carries the lamp pool and the mown bands and nothing else.
#  - **Nothing moves fast.** The lamp breathes over five seconds and the pollen drifts. A sweep or
#    a flash would pull the eye at exactly the moment the game is measuring where it went.

const TURF_A: Color = Color(0.153, 0.239, 0.153)
const TURF_B: Color = Color(0.129, 0.208, 0.133)
const TURF_EDGE: Color = Color(0.086, 0.141, 0.098)
const EARTH: Color = Color(0.235, 0.176, 0.125)
const RAIL_A: Color = Color(0.706, 0.196, 0.216)
const RAIL_B: Color = Color(0.914, 0.855, 0.725)
const LAMP: Color = Color(1.0, 0.87, 0.58)

const RAIL_W: float = 20.0       # the fairground rail around the box, on desktop
const RAIL_SEG: float = 44.0     # one painted segment of it
const RAIL_BULGE: float = 0.25   # how far a segment's arc swells inward, as a share of the width
const MOWN_H: float = 56.0       # a mower's width

# Every number in this file is in the project's own units, not device pixels: the window stretches
# `canvas_items` from a 680x788 viewport, so the board is 680 units wide on a desktop and on a
# phone alike and none of this needs to know what it is being drawn on.
#
# `_k()` is not correcting for a coordinate difference — there is not one. It is correcting for
# APPARENT size: 20 units of rail that frame the board in a desktop window are a hairline on a
# phone held at arm's length. It is the same adjustment every font in this app makes
# (`36 if is_mobile() else 22` and so on), applied to scenery instead of type.
static func _k() -> float:
	return 1.75 if MainGlobals.is_mobile() else 1.0

static func attach(parent: Control) -> Control:
	var bg: Control = parent.get_node_or_null("BoardBackdrop") as Control
	if bg == null:
		bg = Control.new()
		bg.name = "BoardBackdrop"
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		parent.add_child(bg)
		parent.move_child(bg, 0)
	return bg

static func draw(bg: Control, t: float) -> void:
	var w: float = bg.size.x
	var h: float = bg.size.y
	if w < 4.0 or h < 4.0:
		return
	_turf(bg, w, h)
	_earth(bg, w, h)
	_lamp(bg, w, h, t)
	_rail(bg, w, h)
	_vignette(bg, w, h)

# Mown grass, in bands the width of a mower. Straight horizontal bands are the plainest thing that
# says "a lawn from above" and the least like anything the player has to hit.
static func _turf(bg: Control, w: float, h: float) -> void:
	bg.draw_rect(Rect2(0.0, 0.0, w, h), TURF_A, true)
	var y: float = 0.0
	var i: int = 0
	while y < h:
		if i % 2 == 1:
			bg.draw_rect(Rect2(0.0, y, w, minf(MOWN_H, h - y)), TURF_B, true)
		y += MOWN_H
		i += 1
	# The grass darkens toward the rail, which is what gives the box a floor rather than a flat fill.
	var band: float = 150.0
	var clear: Color = Color(TURF_EDGE.r, TURF_EDGE.g, TURF_EDGE.b, 0.0)
	bg.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, band), Vector2(0, band)]),
		PackedColorArray([TURF_EDGE, TURF_EDGE, clear, clear]))
	bg.draw_polygon(PackedVector2Array([Vector2(0, h - band), Vector2(w, h - band), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([clear, clear, TURF_EDGE, TURF_EDGE]))

# Where things have been coming up. Irregular polygons, never discs: a disc here is a target.
# They hug the edges, leaving the middle of the board — where the player's eye is being timed —
# carrying nothing.
static func _earth(bg: Control, w: float, h: float) -> void:
	var scale_up: float = _k()
	var spots: Array = [
		[0.13, 0.14, 46.0], [0.86, 0.20, 38.0], [0.09, 0.62, 40.0],
		[0.91, 0.72, 44.0], [0.28, 0.90, 36.0], [0.72, 0.06, 34.0],
	]
	for spot: Array in spots:
		var c: Vector2 = Vector2(w * float(spot[0]), h * float(spot[1]))
		var r: float = float(spot[2]) * scale_up
		var pts: PackedVector2Array = PackedVector2Array()
		var cols: PackedColorArray = PackedColorArray()
		var n: int = 11
		for k in n:
			var ang: float = TAU * float(k) / float(n)
			# Every vertex pulled in or out by a fixed, repeatable amount: a ragged patch of soil,
			# and never twice the same shape.
			var wobble: float = 0.62 + 0.38 * fmod(float(k) * 2.7 + r, 1.0)
			pts.append(c + Vector2(cos(ang), sin(ang) * 0.62) * r * wobble)
			cols.append(EARTH.lightened(0.06 * fmod(float(k), 2.0)))
		bg.draw_polygon(pts, cols)

# The stall lamp, overhead. From above a lamp is a pool on the ground, not a cone in the air.
static func _lamp(bg: Control, w: float, h: float, t: float) -> void:
	var breath: float = 0.5 + 0.5 * sin(t * TAU / 5.0)
	var glow: Texture2D = MainGlobals.menu_glow_texture()
	if glow != null:
		var d: float = maxf(w, h) * 1.35
		bg.draw_texture_rect(glow, Rect2(w * 0.5 - d * 0.5, h * 0.5 - d * 0.5, d, d), false,
			Color(LAMP.r, LAMP.g, LAMP.b, 0.10 + 0.035 * breath))
	# Pollen over the grass. Few, small, slow.
	for i in 11:
		var seed_f: float = float(i) * 1.6180339
		var speed: float = 6.0 + fmod(seed_f * 29.0, 7.0)
		var y: float = h - fposmod(fmod(seed_f * 173.0, h) + t * speed, h)
		var x: float = fmod(seed_f * 401.0, w) + sin(t * 0.28 + seed_f * 5.0) * 22.0
		bg.draw_circle(Vector2(x, y), 1.5, Color(LAMP.r, LAMP.g, LAMP.b, 0.10 + 0.07 * breath))

# The fairground rail around the box: painted segments, alternating, all four sides. A striped rail
# is the one mark that says "fair" and still works looked at from directly above.
static func _rail(bg: Control, w: float, h: float) -> void:
	var k: float = _k()
	var rw: float = RAIL_W * k
	var seg_len: float = RAIL_SEG * k
	var bulge: float = rw * RAIL_BULGE

	# The rail's shadow on the grass, drawn FIRST — it is a rail lying ON the board, not paint.
	#
	# It has to go under the segments, not over them. Drawn last it fell across the beads, which
	# swell into exactly the band it covers, and every bead came out darker than the stripe it
	# belongs to. They are the same color; the shadow was what made them look different.
	var d: float = 14.0 * k
	var dark: Color = Color(0.0, 0.0, 0.0, 0.30)
	var clear: Color = Color(0.0, 0.0, 0.0, 0.0)
	bg.draw_polygon(PackedVector2Array([Vector2(rw, rw), Vector2(w - rw, rw),
		Vector2(w - rw, rw + d), Vector2(rw, rw + d)]),
		PackedColorArray([dark, dark, clear, clear]))
	bg.draw_polygon(PackedVector2Array([Vector2(rw, rw), Vector2(rw + d, rw),
		Vector2(rw + d, h - rw), Vector2(rw, h - rw)]),
		PackedColorArray([dark, clear, clear, dark]))
	bg.draw_polygon(PackedVector2Array([Vector2(w - rw - d, rw), Vector2(w - rw, rw),
		Vector2(w - rw, h - rw), Vector2(w - rw - d, h - rw)]),
		PackedColorArray([clear, dark, dark, clear]))

	var i: int = 0
	var x: float = 0.0
	while x < w:
		var seg: float = minf(seg_len, w - x)
		var col: Color = RAIL_A if i % 2 == 0 else RAIL_B
		bg.draw_rect(Rect2(x, 0.0, seg, rw), col, true)
		_bulge(bg, Vector2(x, rw), Vector2(x + seg, rw), bulge, col)
		var bcol: Color = col.darkened(0.10)
		bg.draw_rect(Rect2(x, h - rw, seg, rw), bcol, true)
		_bulge(bg, Vector2(x + seg, h - rw), Vector2(x, h - rw), bulge, bcol)
		x += seg_len
		i += 1
	i = 0
	var y: float = 0.0
	while y < h:
		var seg: float = minf(seg_len, h - y)
		var col: Color = (RAIL_B if i % 2 == 0 else RAIL_A).darkened(0.06)
		bg.draw_rect(Rect2(0.0, y, rw, seg), col, true)
		_bulge(bg, Vector2(rw, y + seg), Vector2(rw, y), bulge, col)
		bg.draw_rect(Rect2(w - rw, y, rw, seg), col, true)
		_bulge(bg, Vector2(w - rw, y), Vector2(w - rw, y + seg), bulge, col)
		y += seg_len
		i += 1

# The swell on a rail segment: a shallow circular arc bulging INWARD off the segment's inner edge,
# so each painted piece reads as a rounded bead rather than a flat stripe. `a` -> `b` is the chord,
# and the arc bulges to its LEFT — the callers order the two ends to aim it into the board.
#
# The radius is derived from the chord and the sagitta, R = (L^2/4 + s^2) / 2s, which is what keeps
# the bulge shallow: a small sagitta on a long chord is a very large circle, so the bead swells a
# few units into the grass instead of ballooning across it.
static func _bulge(bg: Control, a: Vector2, b: Vector2, sag: float, col: Color) -> void:
	var chord: Vector2 = b - a
	var length: float = chord.length()
	if length < 2.0 or sag <= 0.0:
		return
	# A short chord — the last, part-width segment before a corner — would otherwise take the same
	# sagitta as a full one and come out as a near-semicircular blob rather than a shallow bead.
	sag = minf(sag, length * 0.18)
	var dir: Vector2 = chord / length
	var normal: Vector2 = Vector2(-dir.y, dir.x)
	var r: float = (length * length * 0.25 + sag * sag) / (2.0 * sag)
	var center: Vector2 = a + dir * (length * 0.5) - normal * (r - sag)
	var half: float = asin(clampf(length * 0.5 / r, -1.0, 1.0))
	var mid_ang: float = (a + dir * (length * 0.5) + normal * sag - center).angle()
	var pts: PackedVector2Array = PackedVector2Array()
	var cols: PackedColorArray = PackedColorArray()
	var steps: int = 10
	for i in steps + 1:
		var ang: float = mid_ang - half + 2.0 * half * float(i) / float(steps)
		pts.append(center + Vector2(cos(ang), sin(ang)) * r)
		cols.append(col)
	pts.append(a)
	cols.append(col)
	bg.draw_polygon(pts, cols)

static func _vignette(bg: Control, w: float, h: float) -> void:
	var vw: float = 110.0
	var dark: Color = Color(0.0, 0.0, 0.0, 0.26)
	var clear: Color = Color(0.0, 0.0, 0.0, 0.0)
	bg.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vw, 0), Vector2(vw, h), Vector2(0, h)]),
		PackedColorArray([dark, clear, clear, dark]))
	bg.draw_polygon(PackedVector2Array([Vector2(w - vw, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - vw, h)]),
		PackedColorArray([clear, dark, dark, clear]))

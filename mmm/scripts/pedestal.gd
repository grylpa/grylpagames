extends Node2D

# A ROOM'S VAULT (2026-11-16, Mind Palace -- see level.gd): a SAFE DOOR seen straight on, the way Crack
# the Safe shows its safe (its drawing copied here and scaled to a tile: games do not share scripts) --
# a brushed-steel door, beveled, four hex bolts, a big chrome combination dial with a black face and
# silver ticks, a three-spoke handle, and a small lamp: RED for a safe not opened yet, GREEN for one
# opened. One per room, at the spot that used to hold the room's coin.
#   COVERED  shut, an object inside
#   OPEN     the door swung aside on its hinges, the object in the dark compartment (opened by walking
#            into it, and on the map)
#   EMPTY    drawn shut (not used by the round any more)
# IT STANDS OUT ON EVERY FLOOR ("make it stand out no matter the background"): a soft light halo behind
# it, a thick BLACK outline and a bright GOLD frame inside that -- the black carries it on the light
# floors (kitchen, ballroom, bathroom), the gold and the halo on the dark ones (library, cellar) -- and a
# deep shadow. Steel alone matched neither.
# BEACON: rings spreading out round a safe not opened yet, so the ones still to find stand out from
# across a room. Drawn by a child that redraws every frame; the door itself is drawn only when its state
# changes (many shapes per actor every frame is what costs a phone its frame rate).
#
# Tried and dropped the same day: a brass dome on a round plinth (read as a serving dish), a flat drawn
# strongbox in three-quarter view ("much less contrasting and visible ... much less nice"), and a real 3-D
# strongbox ("this 3-D almost front view doesn't match any other item in the game").

enum State { EMPTY, COVERED, OPEN }

const BADGE: Script = preload("res://mmm/scripts/object_badge.gd")

const STEEL_HI: Color = Color(0.58, 0.60, 0.64)
const STEEL_LO: Color = Color(0.28, 0.29, 0.33)
const CHROME_HI: Color = Color(0.92, 0.93, 0.96)
const CHROME_MID: Color = Color(0.62, 0.64, 0.68)
const CHROME_LO: Color = Color(0.30, 0.31, 0.34)
const DIAL_FACE: Color = Color(0.08, 0.08, 0.10)
const GOLD: Color = Color(0.98, 0.78, 0.30)
const LIGHT_DIR: Vector2 = Vector2(-0.6, -0.8)
const SIDE: float = 1.12                   # the door's side, in tiles: a little over a tile, it is what you look for

var state: int = State.EMPTY
var symbol: String = ""
var obj_color: Color = Color.WHITE
var opened_once: bool = false             # the lamp: red until first opened, then green
var big: bool = false                     # the final reveal: the object about 2x2 cells, over its safe
var tile: float = 40.0
var beacon: bool = false:
	set(v):
		if v != beacon:
			beacon = v
			if _rings != null:
				_rings.visible = v
var _t: float = 0.0
var _rings: Node2D = null

func _ready() -> void:
	_rings = Node2D.new()
	_rings.show_behind_parent = true
	_rings.visible = beacon
	_rings.draw.connect(_draw_rings)
	add_child(_rings)

func set_state(s: int, sym: String = "", col: Color = Color.WHITE) -> void:
	state = s
	symbol = sym
	obj_color = col
	if s == State.OPEN:
		opened_once = true
	# open, over everything round it: the compartment and the object stand where the player may be
	z_index = 30 if s == State.OPEN else 2
	queue_redraw()

func _process(delta: float) -> void:
	if beacon and _rings != null:
		_t += delta
		_rings.queue_redraw()

func _draw_rings() -> void:
	var r: float = tile * SIDE * 0.66
	for k in 2:
		var u: float = fposmod(_t * 0.9 + float(k) * 0.5, 1.0)
		_rings.draw_arc(Vector2.ZERO, r * (1.0 + 1.1 * u), 0.0, TAU, 48,
			Color(1.0, 0.82, 0.40, 0.85 * (1.0 - u)), 4.0 * (1.0 - u) + 1.0, true)

func _draw() -> void:
	var s: float = tile * SIDE
	var door: Rect2 = Rect2(-s * 0.5, -s * 0.5, s, s)
	# a soft light halo behind it, then a deep shadow
	for k in 4:
		draw_rect(door.grow(s * (0.16 - 0.035 * float(k))), Color(1.0, 0.95, 0.80, 0.07))
	draw_rect(Rect2(door.position + Vector2(s * 0.06, s * 0.08), door.size), Color(0, 0, 0, 0.55))
	if state == State.OPEN:
		_draw_open(door)
	else:
		_draw_door(door)
	# the frame that carries it on any floor: gold inside, black outside
	draw_rect(door.grow(s * 0.035), Color(0.02, 0.02, 0.03), false, s * 0.05)
	draw_rect(door, GOLD, false, s * 0.035)

# THE DOOR: brushed steel lit from the top left, beveled, a recessed panel, hex bolts in the corners,
# the dial in the middle, the handle at the right, the lamp above the dial.
func _draw_door(door: Rect2) -> void:
	var s: float = door.size.x
	draw_polygon(PackedVector2Array([door.position, Vector2(door.end.x, door.position.y), door.end,
		Vector2(door.position.x, door.end.y)]), PackedColorArray([STEEL_HI, STEEL_HI.lerp(STEEL_LO, 0.4),
		STEEL_LO, STEEL_HI.lerp(STEEL_LO, 0.6)]))
	_brushing(door)
	_bevel(door.grow(-s * 0.02), maxf(1.0, s * 0.03), true)
	var panel: Rect2 = door.grow(-s * 0.10)
	draw_rect(panel, Color(0, 0, 0, 0.14))
	_bevel(panel, maxf(1.0, s * 0.02), false)
	# bolts
	var br: float = s * 0.045
	var m: float = s * 0.13
	for bp in [door.position + Vector2(m, m), Vector2(door.end.x - m, door.position.y + m),
			Vector2(door.position.x + m, door.end.y - m), door.end - Vector2(m, m)]:
		var hexp: PackedVector2Array = PackedVector2Array()
		for i in 6:
			hexp.append(bp + Vector2.from_angle(TAU * float(i) / 6.0 + 0.5) * br)
		draw_circle(bp + Vector2(br * 0.2, br * 0.3), br, Color(0, 0, 0, 0.35))
		draw_colored_polygon(hexp, STEEL_LO.lerp(STEEL_HI, 0.5))
		draw_circle(bp + Vector2(-br * 0.25, -br * 0.25), br * 0.45, Color(1, 1, 1, 0.22))
	# the dial: chrome bezel rings, a black face, silver ticks, a gold pointer, a chrome knob
	var dc: Vector2 = Vector2(-s * 0.06, s * 0.04)
	var dr: float = s * 0.26
	var bez: float = dr + s * 0.05
	draw_circle(dc + Vector2(s * 0.02, s * 0.035), bez + s * 0.02, Color(0, 0, 0, 0.45))
	for rg: Array in [[1.00, CHROME_LO], [0.80, CHROME_HI], [0.55, CHROME_MID], [0.20, CHROME_LO]]:
		draw_circle(dc, dr + (bez - dr) * float(rg[0]) + 0.5, rg[1])
	draw_arc(dc, dr + (bez - dr) * 0.75, PI * 0.95, PI * 1.55, 20, Color(1, 1, 1, 0.55), maxf(1.0, s * 0.012), true)
	draw_circle(dc, dr, DIAL_FACE)
	draw_circle(dc, dr * 0.88, DIAL_FACE.lightened(0.06))
	for i in 40:
		var a: float = TAU * float(i) / 40.0
		var dir: Vector2 = Vector2.from_angle(a)
		var major: bool = i % 5 == 0
		draw_line(dc + dir * dr * (0.70 if major else 0.78), dc + dir * dr * 0.88,
			Color(0.80, 0.82, 0.86) if major else Color(0.55, 0.57, 0.60), maxf(1.0, s * (0.012 if major else 0.007)), true)
	draw_colored_polygon(PackedVector2Array([dc + Vector2(-s * 0.025, -bez - s * 0.01),
		dc + Vector2(s * 0.025, -bez - s * 0.01), dc + Vector2(0.0, -dr * 0.86)]), Color(0.95, 0.78, 0.08))
	_knob(dc, dr * 0.50)
	# the handle: three spokes with ball ends round a beveled hub
	var hc: Vector2 = Vector2(door.end.x - s * 0.17, dc.y)
	var hr: float = s * 0.11
	for i in 3:
		var tip: Vector2 = hc + Vector2.from_angle(-PI / 2.0 + TAU * float(i) / 3.0) * hr
		draw_line(hc + Vector2(1.0, 1.5), tip + Vector2(1.0, 1.5), Color(0, 0, 0, 0.30), hr * 0.22, true)
		draw_line(hc, tip, CHROME_MID, hr * 0.18, true)
		_shaded_disc(tip, hr * 0.20, CHROME_LO, CHROME_HI)
	_shaded_disc(hc, hr * 0.40, CHROME_LO.darkened(0.3), CHROME_HI.lightened(0.3))
	_shaded_disc(hc, hr * 0.30, CHROME_MID.darkened(0.08), CHROME_MID.lightened(0.10))
	# the lamp above the dial: red until first opened, then green
	var lamp: Vector2 = Vector2(dc.x, door.position.y + s * 0.15)
	var lc: Color = Color(0.30, 0.95, 0.45) if opened_once else Color(0.95, 0.25, 0.20)
	draw_circle(lamp, s * 0.055, Color(lc, 0.25))
	draw_circle(lamp, s * 0.035, Color(0.08, 0.08, 0.09))
	draw_circle(lamp, s * 0.027, lc)
	draw_circle(lamp + Vector2(-s * 0.008, -s * 0.008), s * 0.009, Color(1, 1, 1, 0.7))

# OPEN: the compartment (dark, a steel lip round it) with the object in it, and the door swung aside on
# its hinges at the left -- seen nearly edge-on, a narrow steel slab with the dial's edge on it.
func _draw_open(door: Rect2) -> void:
	var s: float = door.size.x
	draw_rect(door, STEEL_LO)
	var hole: Rect2 = door.grow(-s * 0.09)
	draw_rect(hole, Color(0.03, 0.03, 0.04))
	draw_rect(Rect2(hole.position, Vector2(hole.size.x, hole.size.y * 0.16)), Color(0.08, 0.08, 0.09))
	_bevel(hole, maxf(1.0, s * 0.02), false)
	var slab: PackedVector2Array = PackedVector2Array([door.position, door.position + Vector2(-s * 0.26, -s * 0.10),
		Vector2(door.position.x - s * 0.26, door.end.y + s * 0.10), Vector2(door.position.x, door.end.y)])
	draw_polygon(slab, PackedColorArray([STEEL_HI, STEEL_HI.lightened(0.1), STEEL_LO, STEEL_LO.lerp(STEEL_HI, 0.3)]))
	var edge: PackedVector2Array = slab.duplicate()
	edge.append(slab[0])
	draw_polyline(edge, Color(0.02, 0.02, 0.03), maxf(1.0, s * 0.03), true)
	draw_circle(door.position + Vector2(-s * 0.15, s * 0.52), s * 0.06, CHROME_MID)
	if big:
		# the final reveal: the object large, centered on its safe (the safe is never next to the room's
		# wall, so two cells across stay inside the room)
		BADGE.draw(self, hole.get_center(), tile * 0.98, symbol, obj_color)
	else:
		BADGE.draw(self, hole.get_center(), s * 0.36, symbol, obj_color)

func _brushing(r: Rect2) -> void:
	var step: float = maxf(2.0, r.size.y / 18.0)
	var y: float = r.position.y + step
	var i: int = 0
	while y < r.end.y - 1.0:
		var h: float = fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		var x0: float = r.position.x + r.size.x * 0.6 * h
		var run: float = r.size.x * (0.25 + 0.5 * fposmod(h * 7.0, 1.0))
		draw_line(Vector2(x0, y), Vector2(minf(r.end.x - 1.0, x0 + run), y),
			Color(1, 1, 1, 0.05) if i % 2 == 0 else Color(0, 0, 0, 0.06), 1.0)
		y += step
		i += 1

func _bevel(r: Rect2, wdt: float, raised: bool) -> void:
	var lite: Color = Color(1, 1, 1, 0.30)
	var dark: Color = Color(0, 0, 0, 0.45)
	var a: Color = lite if raised else dark
	var b: Color = dark if raised else lite
	draw_line(r.position, Vector2(r.end.x, r.position.y), a, wdt)
	draw_line(r.position, Vector2(r.position.x, r.end.y), a, wdt)
	draw_line(Vector2(r.position.x, r.end.y), r.end, b, wdt)
	draw_line(Vector2(r.end.x, r.position.y), r.end, b, wdt)

# A disc shaded in one piece from `dark` (bottom right) to `light` (top left).
func _shaded_disc(at: Vector2, r: float, dark: Color, light: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var cols: PackedColorArray = PackedColorArray()
	for i in 24:
		var dir: Vector2 = Vector2.from_angle(TAU * float(i) / 24.0)
		pts.append(at + dir * r)
		cols.append(dark.lerp(light, clampf(dir.dot(LIGHT_DIR) * 0.5 + 0.5, 0.0, 1.0)))
	draw_polygon(pts, cols)

# The knob: a turned-metal grip from above -- grip ridges catching the light, a bevel, a smooth cap, a
# notch at 0.
func _knob(at: Vector2, knob_r: float) -> void:
	draw_circle(at + Vector2(knob_r * 0.1, knob_r * 0.16), knob_r * 1.08, Color(0, 0, 0, 0.35))
	draw_circle(at, knob_r, CHROME_LO.darkened(0.25))
	var cap_r: float = knob_r * 0.78
	for i in 30:
		var dir: Vector2 = Vector2.from_angle(TAU * float(i) / 30.0)
		var lit: float = clampf(dir.dot(LIGHT_DIR) * 0.5 + 0.5, 0.0, 1.0)
		draw_line(at + dir * cap_r, at + dir * (knob_r - 0.5), CHROME_LO.lerp(CHROME_HI, lit * lit), maxf(1.0, knob_r * 0.08), true)
	_shaded_disc(at, cap_r * 1.06, CHROME_LO.darkened(0.2), Color(0.97, 0.98, 1.0))
	_shaded_disc(at, cap_r, CHROME_MID.darkened(0.15), CHROME_HI)
	draw_line(at + Vector2(0, -cap_r * 0.40), at + Vector2(0, -cap_r * 0.86), Color(0.12, 0.12, 0.14, 0.9), maxf(1.0, knob_r * 0.10), true)

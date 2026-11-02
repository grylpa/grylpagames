extends Control
class_name ChuteView

# THE POOL TABLE the balls roll down in bucketmadness (2026-11-02), seen from the player's end: the
# trapezoid is the table in perspective -- narrow far end at the top, wide near end at the bottom,
# where the three pockets are (scripts/bucket_view.gd). Green felt lit by the lamp over it, rubber
# cushions and polished wooden rails with pearl diamonds down both sides, and the far rail across the
# top, drawn OVER the balls so they roll out from under it.
#
# It was a dark chute with drifting chevrons when the items were tiles; the items are billiard balls
# now (scripts/ball_art.gd) and everything round them had to be a billiard table to match.

const FELT: Color = Color(0.118, 0.440, 0.250)
const FELT_DARK: Color = Color(0.045, 0.215, 0.120)
const CUSHION: Color = Color(0.060, 0.300, 0.165)
const WOOD: Color = Color(0.420, 0.200, 0.085)
const WOOD_DARK: Color = Color(0.200, 0.085, 0.035)
const WOOD_LIT: Color = Color(0.700, 0.410, 0.200)
const PEARL: Color = Color(0.950, 0.920, 0.840)
const LAMP_GLOW: Color = Color(1.0, 0.92, 0.70, 0.10)

const RAIL_W: float = 15.0
const CUSHION_W: float = 8.0

# Set by the level: how far in from each side the chute's mouth starts.
var top_inset: float = 40.0:
	set(v):
		top_inset = v
		queue_redraw()
		if _mouth != null:
			_mouth.queue_redraw()

# THE MOUTH IS DRAWN OVER THE ITEMS. The lip and the shadow under it are on their own child, raised
# above the falling item (z_index), so an item slides out from UNDER the top edge into the light. They
# were part of the chute's own drawing, under everything, and an item sliding down covered them.
var _mouth: Control = null
const MOUTH_Z: int = 20

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mouth = Control.new()
	_mouth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mouth.z_index = MOUTH_Z
	_mouth.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mouth.draw.connect(_draw_mouth)
	add_child(_mouth)

func _ready() -> void:
	resized.connect(queue_redraw)
	resized.connect(_mouth.queue_redraw)

# Left and right wall x at a given depth 0..1, following the trapezoid.
func _edges(t: float) -> Vector2:
	return Vector2(lerpf(top_inset, 0.0, t), lerpf(size.x - top_inset, size.x, t))

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 10.0 or h < 10.0:
		return
	# The felt, darker toward the far end and the sides, lit in the middle by the lamp over the table.
	var bands: int = 6
	for b in range(bands):
		var f0: float = float(b) / float(bands)
		var f1: float = float(b + 1) / float(bands)
		var e0: Vector2 = _edges(f0)
		var e1: Vector2 = _edges(f1)
		var c0: Color = FELT_DARK.lerp(FELT, 0.35 + 0.65 * f0)
		var c1: Color = FELT_DARK.lerp(FELT, 0.35 + 0.65 * f1)
		draw_polygon(PackedVector2Array([Vector2(e0.x, h * f0), Vector2(e0.y, h * f0), Vector2(e1.y, h * f1), Vector2(e1.x, h * f1)]),
			PackedColorArray([c0, c0, c1, c1]))
	# THREE POOLS OF LIGHT, one under each shade of the lamp over the table (factory_backdrop.gd
	# _draw_lamp): each lies where that shade's cone lands, so the light on the cloth visibly comes from
	# the lamp. It was one big pool in the middle under three lamps, which did not match.
	var vw: float = get_viewport_rect().size.x
	var sw: float = maxf(vw * 0.075, 24.0)
	for lk in 3:
		var gx: float = lerpf(vw * 0.22 + sw * 0.6, vw * 0.78 - sw * 0.6, float(lk) / 2.0)
		# Felt is MATTE: a soft, broad lift of the cloth, never bright rings that read as a shine.
		var pc: Vector2 = Vector2(gx - global_position.x, h * 0.42)
		for k in range(18, 0, -1):
			var f: float = float(k) / 18.0
			_ellipse(pc, w * 0.22 * f, h * 0.38 * f, Color(LAMP_GLOW.r, LAMP_GLOW.g, LAMP_GLOW.b, 0.018 * (1.0 - f * f)))
	# the nap of the cloth: faint specks, never a pattern
	for i in 220:
		var t: float = _hash01(i, 1)
		var e: Vector2 = _edges(t)
		var p: Vector2 = Vector2(lerpf(e.x, e.y, _hash01(i, 2)), t * h)
		draw_circle(p, 0.8, Color(1, 1, 1, 0.035) if i % 2 == 0 else Color(0, 0, 0, 0.05))
	# the head spot, where a rack would sit, a third of the way down
	var sp: Vector2 = Vector2(w * 0.5, h * 0.30)
	_ellipse(sp, 3.0, 2.0, Color(1, 1, 1, 0.35))
	# cushions and rails down both sides, the rails with their diamonds
	var t0: Vector2 = _edges(0.0)
	var t1: Vector2 = _edges(1.0)
	_rail(Vector2(t0.x, 0.0), Vector2(t1.x, h), 1.0)
	_rail(Vector2(t0.y, 0.0), Vector2(t1.y, h), -1.0)
	# beer bottles left standing on the side rails (scripts/bottle_art.gd, real 3-D): two far up the
	# table, small, at different depths, and two nearer the front, bigger, also staggered
	_bottles_pending = false
	for spec: Array in [[0.10, -1.0, 0, 0.145], [0.21, 1.0, 1, 0.16], [0.60, 1.0, 2, 0.21], [0.74, -1.0, 3, 0.27]]:
		var t: float = float(spec[0])
		var e: Vector2 = _edges(t)
		var on_left: bool = float(spec[1]) < 0.0
		var rail_x: float = (e.x + lerpf(RAIL_W * 0.7, RAIL_W, t) * 0.45) if on_left else (e.y - lerpf(RAIL_W * 0.7, RAIL_W, t) * 0.45)
		_bottle_3d(Vector2(rail_x, t * h), int(spec[2]), h * float(spec[3]))
	# blue chalk cubes left on the side rails, smaller up the table
	for cspec: Array in [[0.33, -1.0, 11.0], [0.50, 1.0, 13.5]]:
		var tc: float = float(cspec[0])
		var ec: Vector2 = _edges(tc)
		var cleft: bool = float(cspec[1]) < 0.0
		var rw: float = lerpf(RAIL_W * 0.7, RAIL_W, tc)
		var cx: float = (ec.x + rw * 0.5) if cleft else (ec.y - rw * 0.5)
		_chalk(Vector2(cx, tc * h), float(cspec[2]))
	# the near edge: the cloth turns down over the end into the pockets' rail (bucket_stage.gd)
	draw_line(Vector2(t1.x, h - 1.0), Vector2(t1.y, h - 1.0), Color(0, 0, 0, 0.35), 2.0)

# A cube of blue chalk on a rail, seen a little from above: its lit top with the worn hollow where the
# cue tip is twisted into it, and its shaded front.
func _chalk(c: Vector2, cs: float) -> void:
	draw_rect(Rect2(c + Vector2(-cs * 0.5 + 2.0, -cs * 0.30 + 3.0), Vector2(cs, cs * 0.75)), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(c + Vector2(-cs * 0.5, -cs * 0.30), Vector2(cs, cs * 0.45)), Color(0.35, 0.58, 0.88))
	draw_rect(Rect2(c + Vector2(-cs * 0.5, cs * 0.15), Vector2(cs, cs * 0.30)), Color(0.18, 0.36, 0.66))
	_ellipse(c + Vector2(0.0, -cs * 0.08), cs * 0.24, cs * 0.12, Color(0.14, 0.30, 0.58))

var _bottles_pending: bool = true

func _process(_delta: float) -> void:
	if _bottles_pending:
		queue_redraw()
	else:
		set_process(false)

# A rendered bottle of `kind` standing on a rail at `base`, `bh` tall, with its shadow on the wood.
func _bottle_3d(base: Vector2, kind: int, bh: float) -> void:
	var tex: Texture2D = BottleArt.texture(self, kind, 256)
	if tex == null:
		_bottles_pending = true
		set_process(true)
		return
	var bw: float = bh * BottleArt.ASPECT
	_ellipse(base + Vector2(bh * 0.05, 1.0), bh * 0.16, bh * 0.05, Color(0, 0, 0, 0.45))
	# the render's frame has a little room under the base: put the base on the rail
	draw_texture_rect(tex, Rect2(base.x - bw * 0.5, base.y - bh * 0.93, bw, bh), false)

func _hash01(a: int, b: int) -> float:
	var hv: int = (a * 73856093) ^ (b * 19349663)
	return float(absi(hv) % 1000) / 1000.0

func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	if rx <= 0.5 or ry <= 0.5 or col.a <= 0.001:
		return
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 28:
		var a: float = TAU * float(k) / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

# The far rail across the top, over the balls: polished wood with its cushion and a shadow on the felt
# below it, so a ball rolls out from under it -- drawn on _mouth.
func _draw_mouth() -> void:
	var h: float = size.y
	if size.x < 10.0 or h < 10.0:
		return
	var t0: Vector2 = _edges(0.0)
	var rail_h: float = maxf(h * 0.04, 10.0)
	_mouth.draw_polygon(PackedVector2Array([Vector2(t0.x, rail_h), Vector2(t0.y, rail_h),
		Vector2(_edges(0.10).y, h * 0.10), Vector2(_edges(0.10).x, h * 0.10)]),
		PackedColorArray([Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0)]))
	_mouth.draw_polygon(PackedVector2Array([Vector2(t0.x - RAIL_W, -1.0), Vector2(t0.y + RAIL_W, -1.0),
		Vector2(t0.y + 2.0, rail_h), Vector2(t0.x - 2.0, rail_h)]),
		PackedColorArray([WOOD_LIT, WOOD_LIT, WOOD_DARK, WOOD_DARK]))
	_mouth.draw_line(Vector2(t0.x, rail_h), Vector2(t0.y, rail_h), CUSHION, 3.0)
	_mouth.draw_line(Vector2(t0.x - RAIL_W, 0.5), Vector2(t0.y + RAIL_W, 0.5), WOOD_LIT.lightened(0.3), 1.5)
	for k in 3:
		var dx: float = lerpf(t0.x, t0.y, (float(k) + 1.0) / 4.0)
		_diamond(_mouth, Vector2(dx, rail_h * 0.45), 3.0)

func _diamond(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0)]), PEARL)

# A side: the rubber cushion along the felt, and outside it the wooden rail, wider toward the viewer
# (perspective), lit along its top edge, with pearl diamonds set in it.
func _rail(top: Vector2, bot: Vector2, inward: float) -> void:
	var rw_top: float = RAIL_W * 0.7
	var rw_bot: float = RAIL_W
	var cw_top: float = CUSHION_W * 0.7
	var cw_bot: float = CUSHION_W
	var r_in_top: Vector2 = top + Vector2(rw_top * inward, 0.0)
	var r_in_bot: Vector2 = bot + Vector2(rw_bot * inward, 0.0)
	draw_polygon(PackedVector2Array([top, r_in_top, r_in_bot, bot]),
		PackedColorArray([WOOD_LIT, WOOD, WOOD, WOOD_DARK]))
	draw_line(top, bot, WOOD_DARK, 2.0, true)
	draw_line(r_in_top, r_in_bot, WOOD_LIT.lightened(0.2), 1.5, true)
	var c_in_top: Vector2 = r_in_top + Vector2(cw_top * inward, 0.0)
	var c_in_bot: Vector2 = r_in_bot + Vector2(cw_bot * inward, 0.0)
	draw_polygon(PackedVector2Array([r_in_top, c_in_top, c_in_bot, r_in_bot]),
		PackedColorArray([CUSHION.darkened(0.3), CUSHION, CUSHION, CUSHION.darkened(0.3)]))
	draw_line(c_in_top, c_in_bot, Color(0, 0, 0, 0.30), 2.0, true)
	for k in 3:
		var t: float = (float(k) + 1.0) / 4.0
		var p: Vector2 = top.lerp(bot, t) + Vector2(lerpf(rw_top, rw_bot, t) * 0.5 * inward, 0.0)
		_diamond(self, p, 2.6 + 1.2 * t)

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
# Everything here is deliberately LOW CONTRAST. It is a room, and a room that competes with the
# objects the player is reading is worse than a flat color.

# Where the wall meets the floor, as a fraction of height.
@export var horizon: float = 0.62

const WALL_TOP: Color = Color(0.129, 0.145, 0.192)
const WALL_BOT: Color = Color(0.180, 0.204, 0.259)
const SEAM: Color = Color(0.086, 0.098, 0.129, 0.85)
const RIVET: Color = Color(0.290, 0.325, 0.396, 0.55)
const BEAM: Color = Color(0.106, 0.122, 0.161)
const BEAM_LIP: Color = Color(0.325, 0.365, 0.443, 0.75)
const FLOOR_NEAR: Color = Color(0.094, 0.106, 0.137)
const FLOOR_FAR: Color = Color(0.153, 0.173, 0.220)
const FLOOR_LINE: Color = Color(0.239, 0.271, 0.333, 0.55)
const HAZARD_A: Color = Color(0.514, 0.435, 0.161, 0.60)
const HAZARD_B: Color = Color(0.129, 0.137, 0.157, 0.7)
const LIGHT: Color = Color(0.612, 0.694, 0.851, 0.055)
const VIGNETTE: Color = Color(0.0, 0.0, 0.0, 0.34)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 8.0 or h < 8.0:
		return
	var hy: float = h * horizon

	_draw_wall(w, hy)
	_draw_floor(w, h, hy)
	_draw_lights(w, h, hy)
	_draw_vignette(w, h)

func _draw_wall(w: float, hy: float) -> void:
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, hy), Vector2(0, hy)]),
		PackedColorArray([WALL_TOP, WALL_TOP, WALL_BOT, WALL_BOT]))

	# Panel seams with a rivet at each end: the cheapest thing that reads as sheet metal.
	var panels: int = 6
	for i in range(1, panels):
		var x: float = w * float(i) / float(panels)
		draw_line(Vector2(x, 0.0), Vector2(x, hy), SEAM, 2.0)
		draw_line(Vector2(x + 1.5, 0.0), Vector2(x + 1.5, hy), RIVET, 1.0)

	# A structural beam across the top, and the wall's own bottom rail.
	var beam_h: float = maxf(hy * 0.13, 16.0)
	draw_rect(Rect2(0.0, 0.0, w, beam_h), BEAM)
	draw_line(Vector2(0.0, beam_h), Vector2(w, beam_h), BEAM_LIP, 2.0)
	var bolts: int = 10
	for i in range(bolts):
		var bx: float = w * (float(i) + 0.5) / float(bolts)
		draw_circle(Vector2(bx, beam_h * 0.5), 2.4, RIVET)

func _draw_floor(w: float, h: float, hy: float) -> void:
	draw_polygon(
		PackedVector2Array([Vector2(0, hy), Vector2(w, hy), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([FLOOR_FAR, FLOOR_FAR, FLOOR_NEAR, FLOOR_NEAR]))

	# Perspective: floor seams converging on a vanishing point at eye level, so the floor recedes
	# instead of being a second flat band.
	var vp: Vector2 = Vector2(w * 0.5, hy - h * 0.06)
	var lanes: int = 7
	for i in range(lanes + 1):
		var fx: float = w * float(i) / float(lanes)
		var far: Vector2 = vp.lerp(Vector2(fx, hy), 0.92)
		draw_line(far, Vector2(lerpf(w * 0.5, fx, 1.9), h), FLOOR_LINE, 1.0, true)
	# Cross seams, spaced closer as they recede.
	var rows: int = 5
	for i in range(1, rows + 1):
		var t: float = pow(float(i) / float(rows), 1.7)
		var y: float = lerpf(hy, h, t)
		draw_line(Vector2(0.0, y), Vector2(w, y), FLOOR_LINE, 1.0)

	# Hazard stripes along the front edge of the working area.
	var band_y: float = hy + 4.0
	var band_h: float = 7.0
	var step: float = 22.0
	var x: float = -step
	while x < w + step:
		draw_polygon(
			PackedVector2Array([Vector2(x, band_y), Vector2(x + step * 0.5, band_y),
				Vector2(x + step * 0.5 - band_h, band_y + band_h), Vector2(x - band_h, band_y + band_h)]),
			PackedColorArray([HAZARD_A, HAZARD_A, HAZARD_A, HAZARD_A]))
		x += step
	draw_line(Vector2(0.0, band_y), Vector2(w, band_y), HAZARD_B, 1.0)

func _draw_lights(w: float, h: float, hy: float) -> void:
	# Two overhead lamps throwing soft pools down the wall and onto the floor.
	for i in range(2):
		var cx: float = w * (0.28 + 0.44 * float(i))
		var rings: int = 9
		for r in range(rings, 0, -1):
			var t: float = float(r) / float(rings)
			_ellipse(Vector2(cx, hy * 0.92), w * 0.30 * t, h * 0.34 * t,
				Color(LIGHT.r, LIGHT.g, LIGHT.b, LIGHT.a * (1.0 - t)))

func _draw_vignette(w: float, h: float) -> void:
	var clear: Color = Color(0, 0, 0, 0)
	var bv: float = h * 0.20
	var bh: float = w * 0.22
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

func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	if rx <= 0.5 or ry <= 0.5 or col.a <= 0.001:
		return
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 26
	for i in range(steps):
		var a: float = float(i) / float(steps) * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

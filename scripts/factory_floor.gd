extends Control
class_name FactoryFloor

# The floor of a factory, seen FROM ABOVE.
#
# Sorting Robots and Monkey C are top-down: the belts are conveyors viewed from overhead, with items
# traveling down them. The first factory backdrop drew a wall meeting a floor at a horizon, which
# is a side-on view — against top-down belts it read as a conveyor standing upright against a wall.
# A top-down room has no horizon and no vanishing point: every seam is parallel, and the only depth
# comes from light and wear.
#
# (Bucketmadness keeps the side-on backdrop, because there things fall DOWN a chute into buckets
# standing on the ground — that view really does have a floor and a wall.)

const PLATE_A: Color = Color(0.153, 0.169, 0.204)
const PLATE_B: Color = Color(0.133, 0.149, 0.184)
const SEAM: Color = Color(0.078, 0.086, 0.110, 0.9)
const SEAM_LIP: Color = Color(0.271, 0.298, 0.353, 0.35)
const BOLT: Color = Color(0.310, 0.341, 0.400, 0.6)
const BOLT_DARK: Color = Color(0.063, 0.071, 0.090, 0.7)
const HAZARD: Color = Color(0.478, 0.404, 0.153, 0.42)
const LAMP: Color = Color(0.647, 0.714, 0.851, 0.055)
const VIGNETTE: Color = Color(0.0, 0.0, 0.0, 0.30)

# Steel plates, in a grid. Big enough that the seams read as structure rather than texture.
const PLATE: float = 118.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	resized.connect(queue_redraw)

# Deterministic per-plate variation, so the floor is not a perfect repeat and does not shimmer
# between frames the way rng in _draw would.
func _plate_tint(ix: int, iy: int) -> Color:
	var h: int = (ix * 73856093) ^ (iy * 19349663)
	var t: float = float(absi(h) % 1000) / 1000.0
	return PLATE_A.lerp(PLATE_B, t)

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 8.0 or h < 8.0:
		return

	var cols: int = int(ceil(w / PLATE)) + 1
	var rows: int = int(ceil(h / PLATE)) + 1
	for iy in range(rows):
		for ix in range(cols):
			var r: Rect2 = Rect2(float(ix) * PLATE, float(iy) * PLATE, PLATE, PLATE)
			draw_rect(r, _plate_tint(ix, iy))

	# Seams: parallel, both ways. A lit lip on the near side of each gives the plates thickness
	# without implying a viewing angle.
	var x: float = PLATE
	while x < w:
		draw_line(Vector2(x, 0.0), Vector2(x, h), SEAM, 3.0)
		draw_line(Vector2(x + 2.0, 0.0), Vector2(x + 2.0, h), SEAM_LIP, 1.0)
		x += PLATE
	var y: float = PLATE
	while y < h:
		draw_line(Vector2(0.0, y), Vector2(w, y), SEAM, 3.0)
		draw_line(Vector2(0.0, y + 2.0), Vector2(w, y + 2.0), SEAM_LIP, 1.0)
		y += PLATE

	# Bolts at the plate corners.
	for iy in range(rows):
		for ix in range(cols):
			var c: Vector2 = Vector2(float(ix) * PLATE, float(iy) * PLATE)
			for off in [Vector2(11.0, 11.0), Vector2(PLATE - 11.0, 11.0),
					Vector2(11.0, PLATE - 11.0), Vector2(PLATE - 11.0, PLATE - 11.0)]:
				var p: Vector2 = c + off
				if p.x < w and p.y < h:
					draw_circle(p + Vector2(0.0, 1.0), 2.6, BOLT_DARK)
					draw_circle(p, 2.6, BOLT)

	# Painted hazard bands down both edges, the way a walkway is marked off from a machine run.
	_hazard_band(Rect2(0.0, 0.0, 16.0, h))
	_hazard_band(Rect2(w - 16.0, 0.0, 16.0, h))

	# Overhead lamps: circular pools, because from above a lamp is a circle.
	for i in range(2):
		var cx: float = w * (0.30 + 0.40 * float(i))
		var cy: float = h * (0.28 + 0.44 * float(i))
		var rings: int = 10
		for k in range(rings, 0, -1):
			var t: float = float(k) / float(rings)
			_disc(Vector2(cx, cy), minf(w, h) * 0.62 * t,
				Color(LAMP.r, LAMP.g, LAMP.b, LAMP.a * (1.0 - t)))

	_vignette(w, h)

func _hazard_band(r: Rect2) -> void:
	var step: float = 20.0
	var yy: float = r.position.y - step
	while yy < r.end.y:
		draw_polygon(
			PackedVector2Array([Vector2(r.position.x, yy), Vector2(r.end.x, yy - step * 0.5),
				Vector2(r.end.x, yy + step * 0.5 - 1.0), Vector2(r.position.x, yy + step - 1.0)]),
			PackedColorArray([HAZARD, HAZARD, HAZARD, HAZARD]))
		yy += step * 2.0

func _disc(c: Vector2, rad: float, col: Color) -> void:
	if rad <= 0.5 or col.a <= 0.001:
		return
	draw_circle(c, rad, col)

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

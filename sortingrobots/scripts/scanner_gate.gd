extends Node2D

# THE SCANNER on one belt (2026-11-15, Quality Control): a gate fixed at the belt's middle that every
# parcel rides through -- a housing on each side of the belt with an indicator light, and a thin beam
# across the belt where the parcels go in and where they come out, so the parcel inside stays fully in
# view. The parcel inside is the one in question; the player taps the machine (or its belt) when it
# matches. The user's picture was an airport scanner, not an X-ray: a fixed decision point you can see.
#
# The light is CONSTANT (2026-11-15): the gate's opening always lit and its lamps always on, so the
# scanner is a steady, fixed place to act. A light that came on as a parcel entered (and flashed green
# or red after a judgment) was tried and dropped: it started too early, and a reacting light was not
# what the user pictured. The verdict is the stamp on the parcel. Drawn over the belt, in the level's
# own layer (the belt clips its parcels, and the housings stand outside its edges). level.gd places it
# every frame (`place`).

const HOUSING_W: float = 16.0             # a side housing's width outside the belt, at most...
const HOUSING_IN: float = 4.0             # ...and how far it reaches over the belt's edge
const BEAM_H: float = 12.0
const LAMP: Color = Color(1.0, 0.72, 0.25)
const SWEEP_S: float = 2.2                # one pass of the scanning sweep, top to bottom

var belt: Rect2 = Rect2()                 # the belt, in this layer's coordinates
var zone_top: float = 0.0
var zone_h: float = 0.0
var room: Vector2 = Vector2(16.0, 16.0)   # free space outside the belt's left and right edges

# The light is ADDED to what is under it (a child with an additive material), so the opening and the
# parcel inside are BRIGHTENED, as under a lamp. Drawn as an ordinary wash it fogged the parcel instead
# -- at a strength that read as lit, the parcel looked washed out.
var _wash: Node2D = null

func _ready() -> void:
	_wash = Node2D.new()
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_wash.material = mat
	_wash.show_behind_parent = true
	_wash.draw.connect(_draw_wash)
	add_child(_wash)

func _draw_wash() -> void:
	if belt.size.x <= 0.0 or zone_h <= 0.0:
		return
	# a warm light over the whole opening, brightest along its middle
	_wash.draw_rect(Rect2(belt.position.x, zone_top, belt.size.x, zone_h), Color(0.22, 0.15, 0.05))
	for k in 6:
		var band_h: float = zone_h * (1.0 - float(k) / 6.0)
		_wash.draw_rect(Rect2(belt.position.x, zone_top + (zone_h - band_h) * 0.5, belt.size.x, band_h),
			Color(0.05, 0.04, 0.02))
	# THE SWEEP (2026-11-15): a soft band of extra light moving down through the opening, slowly and
	# steadily, so the machine reads as scanning. Not a flicker: over a whole level a flicker becomes
	# irritating and can bother people sensitive to it. Soft-edged, faint, the same every pass.
	var t: float = fposmod(float(Time.get_ticks_msec()) / 1000.0 / SWEEP_S, 1.0)
	var band: float = zone_h * 0.30
	var cy: float = zone_top - band * 0.5 + t * (zone_h + band)
	for j in 4:
		var hh: float = band * (1.0 - float(j) / 4.0)
		var y_top: float = clampf(cy - hh * 0.5, zone_top, zone_top + zone_h)
		var y_bot: float = clampf(cy + hh * 0.5, zone_top, zone_top + zone_h)
		if y_bot > y_top:
			_wash.draw_rect(Rect2(belt.position.x, y_top, belt.size.x, y_bot - y_top), Color(0.035, 0.03, 0.015))

func _process(_delta: float) -> void:
	if _wash != null:
		_wash.queue_redraw()

# `side_room`: how wide each housing may be (x left, y right) -- the level gives each inner housing just
# under half the gap between the two belts, so the two gates never meet in the middle.
func place(belt_rect: Rect2, top: float, h: float, side_room: Vector2) -> void:
	if belt_rect != belt or top != zone_top or h != zone_h or side_room != room:
		belt = belt_rect
		zone_top = top
		zone_h = h
		room = side_room
		queue_redraw()
		if _wash != null:
			_wash.queue_redraw()

func _draw() -> void:
	if belt.size.x <= 0.0 or zone_h <= 0.0:
		return
	var metal: Color = Color(0.20, 0.21, 0.24)
	var rim: Color = Color(0.42, 0.44, 0.48)
	var light: Color = LAMP
	var y0: float = zone_top - BEAM_H
	var y1: float = zone_top + zone_h + BEAM_H
	# (the opening's light is _wash's, added to what is under it -- see above)
	# the beams across the belt, in and out
	# hazard-striped, so the gate reads as a machine's mouth rather than two lines
	for by in [zone_top - BEAM_H, zone_top + zone_h]:
		draw_rect(Rect2(belt.position.x, by, belt.size.x, BEAM_H), Color(0.12, 0.12, 0.13))
		var stripe: float = 14.0
		var x: float = belt.position.x - BEAM_H
		while x < belt.end.x:
			var p0: Vector2 = Vector2(x, by + BEAM_H)
			var pts: PackedVector2Array = PackedVector2Array([p0, p0 + Vector2(stripe * 0.5, 0.0),
				p0 + Vector2(stripe * 0.5 + BEAM_H, -BEAM_H), p0 + Vector2(BEAM_H, -BEAM_H)])
			var clipped: Array = Geometry2D.intersect_polygons(pts, PackedVector2Array([
				Vector2(belt.position.x, by), Vector2(belt.end.x, by), Vector2(belt.end.x, by + BEAM_H),
				Vector2(belt.position.x, by + BEAM_H)]))
			for poly in clipped:
				draw_colored_polygon(poly, Color(0.86, 0.68, 0.16))
			x += stripe
		draw_rect(Rect2(belt.position.x, by, belt.size.x, BEAM_H), Color(0.05, 0.05, 0.06), false, 1.5)
	# the housings on both sides, each with its light
	for side in 2:
		var w_out: float = clampf(room.x if side == 0 else room.y, 2.0, HOUSING_W)
		var x: float = belt.position.x - w_out if side == 0 else belt.end.x - HOUSING_IN
		var r: Rect2 = Rect2(x, y0 - 4.0, w_out + HOUSING_IN, (y1 - y0) + 8.0)
		draw_rect(Rect2(r.position + Vector2(3.0, 4.0), r.size), Color(0, 0, 0, 0.35))   # its shadow
		draw_rect(r, metal)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), rim)
		draw_rect(r, Color(0.05, 0.05, 0.06), false, 1.5)
		for k in 2:
			draw_circle(Vector2(r.get_center().x, r.position.y + 8.0 + float(k) * (r.size.y - 16.0)), 2.0, rim)
		var lc: Vector2 = r.get_center()
		var lr: float = minf(6.0, r.size.x * 0.40)
		draw_circle(lc, lr * 2.0, Color(light.r, light.g, light.b, 0.25))
		draw_circle(lc, lr, light)
		draw_circle(lc + Vector2(-lr * 0.3, -lr * 0.3), lr * 0.32, Color(1, 1, 1, 0.6))

class_name CargoTrainArt
extends Node2D

# The drawn look of the route games' vehicles (Headlights `delemfp`, Dispatch `deliverem`,
# Guidem): an engine at the front, a flatbed cart per packet with its load on it, and a
# closed van at the back. Drawn top-down, facing +x, sized for the 40 px tile.
#
# It replaces the old sprites (a face for the head, flat tinted shapes for the packets and a wheel
# sprite for the tail) WITHOUT touching how the agent moves them: the agent still positions and
# turns its `Head`, its bodies and its `Tail`, and a part with `follow` set copies that node every
# frame (at a raised process_priority, so after the agent has moved it -- the same trick as
# `line_backing.gd`). The followed sprite is made invisible with its self_modulate, so its own
# show()/hide() still decides whether the part is drawn.
#
# Shading is lit from the SCREEN's top-left whatever the vehicle's heading: the light direction is
# taken back into local space every redraw, and the drop shadow falls the same way on screen.

enum Kind { ENGINE, WAGON, VAN }

const CARGO_KINDS: int = 4    # parcel, crate, drums, sack

const RUBBER: Color = Color(0.10, 0.10, 0.11)
const STEEL: Color = Color(0.40, 0.43, 0.47)
const GLASS: Color = Color(0.30, 0.47, 0.60)
const LAMP: Color = Color(1.0, 0.95, 0.75)
const TAIL_LAMP: Color = Color(0.95, 0.15, 0.12)
const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.17)
const LIGHT_DIR: Vector2 = Vector2(-0.45, -0.9)     # toward the light, in screen space
const SHADOW_OFS: Vector2 = Vector2(2.2, 3.2)       # screen space

var kind: int = Kind.WAGON
var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()
var cargo: int = 0
# When set, this part sits exactly where `follow` is (see the header). `follow_scale` maps the
# followed sprite's scale onto ours: the old sprites were drawn at 0.25.
var follow: Node2D = null
var follow_scale: float = 4.0
var follow_pose: bool = true

var _last_rot: float = INF
var _light: Vector2 = LIGHT_DIR.normalized()


# The drawbar between the parts: the train's own color, so it reads on the dark road (a steel
# gray link was all but invisible), over a dark backing.
# The train's own color moved well away from itself -- lighter, or darker for a train that is
# already light -- for the parts that were white (cab, van roof, tape, rings, tie): they still
# carry the train's color but stand apart from its body.
static func accent(c: Color) -> Color:
	return c.darkened(0.35) if c.get_luminance() > 0.7 else c.lightened(0.5)


static func link_color(c: Color) -> Color:
	return c.lightened(0.12)


func _init(_kind: int = Kind.WAGON, _color: Color = Color.WHITE, _cargo: int = 0) -> void:
	kind = _kind
	color = _color
	cargo = _cargo
	process_priority = 100


# `pose` false: copy only visibility, scale and z, and leave position and rotation to the owner
# (the route games pose their parts on a smoothed trail).
func set_follow(node: Node2D, pose: bool = true) -> void:
	follow = node
	follow_pose = pose
	z_index = node.z_index
	node.self_modulate = Color(1.0, 1.0, 1.0, 0.0)


func _process(_delta: float) -> void:
	if follow != null and is_instance_valid(follow):
		visible = follow.visible
		if follow_pose:
			global_position = follow.global_position
			rotation = follow.rotation
		scale = follow.scale * follow_scale
		z_index = follow.z_index
	if not is_visible_in_tree():
		return
	# only the lighting depends on where the part points, so redraw on a turn alone
	var gr: float = global_rotation
	if gr == _last_rot:
		return
	_last_rot = gr
	queue_redraw()


# --- Drawing kit ------------------------------------------------------------------------------

func _rrect(r: Rect2, rad: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var rr: float = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var corners: Array = [
		[Vector2(r.end.x - rr, r.position.y + rr), -PI * 0.5],
		[Vector2(r.end.x - rr, r.end.y - rr), 0.0],
		[Vector2(r.position.x + rr, r.end.y - rr), PI * 0.5],
		[Vector2(r.position.x + rr, r.position.y + rr), PI],
	]
	for c: Array in corners:
		var ctr: Vector2 = c[0]
		var a0: float = c[1]
		for k in 5:
			var a: float = a0 + PI * 0.5 * float(k) / 4.0
			pts.append(ctr + Vector2(cos(a), sin(a)) * rr)
	return pts


func _circle(ctr: Vector2, rad: float, n: int = 16) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in n:
		var a: float = TAU * float(k) / float(n)
		pts.append(ctr + Vector2(cos(a), sin(a)) * rad)
	return pts


# Fills `pts` with `base`, lit across the shape from the light: the side facing it lighter, the far
# side darker. `ctr`/`half` say where the shape's middle is and how far its edge reaches.
func _shaded(pts: PackedVector2Array, base: Color, ctr: Vector2, half: Vector2,
		amount: float = 1.0) -> void:
	var cols: PackedColorArray = PackedColorArray()
	for p: Vector2 in pts:
		var d: Vector2 = (p - ctr) / Vector2(maxf(half.x, 0.01), maxf(half.y, 0.01))
		var t: float = clampf(d.dot(_light), -1.0, 1.0) * amount
		cols.append(base.lightened(0.30 * t) if t > 0.0 else base.darkened(-0.38 * t))
	draw_polygon(pts, cols)


func _rim(pts: PackedVector2Array, col: Color, w: float = 1.0) -> void:
	var closed: PackedVector2Array = pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, col, w, true)


# A box in color, shaded and rimmed. Returns its outline for anything that wants to draw over it.
func _panel(r: Rect2, rad: float, base: Color, amount: float = 1.0) -> PackedVector2Array:
	var pts: PackedVector2Array = _rrect(r, rad)
	_shaded(pts, base, r.get_center(), r.size * 0.5, amount)
	_rim(pts, base.darkened(0.55), 1.0)
	return pts


# A soft shadow: the shape twice, a little apart and faint, so its edge fades instead of cutting.
func _shadow(r: Rect2, rad: float, ofs: Vector2) -> void:
	draw_colored_polygon(_rrect(Rect2(r.position + ofs, r.size), rad), SHADOW)
	draw_colored_polygon(_rrect(Rect2(r.position + ofs * 0.5, r.size), rad), SHADOW)


# A tire seen from above. Plain on purpose: tread bars that rolled with the distance driven
# strobed into a flicker along the vehicle's sides at phone size.
func _wheel(ctr: Vector2, length: float, width: float) -> void:
	draw_colored_polygon(_rrect(Rect2(ctr - Vector2(length, width) * 0.5, Vector2(length, width)),
		width * 0.45), RUBBER)


func _draw() -> void:
	# The light and the shadow are fixed on SCREEN; bring both into this part's frame.
	var inv: Transform2D = get_global_transform().affine_inverse()
	_light = inv.basis_xform(LIGHT_DIR).normalized()
	var ofs: Vector2 = inv.basis_xform(SHADOW_OFS)
	match kind:
		Kind.ENGINE:
			_draw_engine(ofs)
		Kind.VAN:
			_draw_van(ofs)
		_:
			_draw_wagon(ofs)


func _draw_engine(ofs: Vector2) -> void:
	# Not a tractor or any real vehicle: the shape only has to say "this pulls". Few, big shapes, so it
	# still reads at phone size: a broad body in the vehicle's color, a lighter cab block of the same
	# color, a dark windshield band and two big lamps. NO white or cream areas anywhere on the train
	# (`accent` instead):
	# at phone size they outweighed the color, and a cart stopped reading as part of its train.
	var body: Rect2 = Rect2(-13.0, -11.5, 29.0, 23.0)
	_shadow(body, 6.0, ofs)
	for x: float in [-7.0, 9.0]:
		for sy: float in [-1.0, 1.0]:
			_wheel(Vector2(x, 12.2 * sy), 8.0, 4.0)
	_panel(body, 6.0, color)
	_panel(Rect2(-11.0, -8.5, 13.5, 17.0), 4.0, accent(color), 0.6)
	draw_colored_polygon(_rrect(Rect2(2.5, -8.5, 4.5, 17.0), 1.5), GLASS.darkened(0.25))
	draw_line(Vector2(3.6, -6.5), Vector2(3.6, -1.0), Color(1, 1, 1, 0.5), 1.2, true)
	draw_line(Vector2(9.0, 0.0), Vector2(13.0, 0.0), color.lightened(0.45), 3.0, true)
	for sy: float in [-1.0, 1.0]:
		draw_colored_polygon(_circle(Vector2(13.0, 7.0 * sy), 2.7, 14), color.darkened(0.6))
		draw_colored_polygon(_circle(Vector2(13.0, 7.0 * sy), 2.0, 14), LAMP)


func _draw_wagon(ofs: Vector2) -> void:
	var bed: Rect2 = Rect2(-12.0, -11.0, 24.0, 22.0)
	_shadow(bed, 3.0, ofs)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			_wheel(Vector2(7.0 * sx, 11.6 * sy), 6.0, 3.6)
	_panel(bed, 3.0, color.darkened(0.45), 0.6)
	match cargo % CARGO_KINDS:
		0:
			_cargo_parcel()
		1:
			_cargo_crate()
		2:
			_cargo_drums()
		_:
			_cargo_sack()


# A taped cardboard parcel, in the truck's color.
func _cargo_parcel() -> void:
	var r: Rect2 = Rect2(-10.0, -9.0, 20.0, 18.0)
	_panel(r, 2.0, color)
	draw_colored_polygon(_rrect(Rect2(-9.5, -2.0, 19.0, 4.0), 0.5), accent(color))


# A slatted crate.
func _cargo_crate() -> void:
	var r: Rect2 = Rect2(-10.0, -9.0, 20.0, 18.0)
	_panel(r, 1.5, color)
	for x: float in [-3.4, 3.4]:
		draw_line(Vector2(x, -8.5), Vector2(x, 8.5), color.darkened(0.5), 1.6, true)


# Two drums standing up, seen from above.
func _cargo_drums() -> void:
	for cx: float in [-5.0, 5.0]:
		var c: Vector2 = Vector2(cx, 0.0)
		var pts: PackedVector2Array = _circle(c, 5.6, 22)
		_shaded(pts, color, c, Vector2(5.6, 5.6))
		_rim(pts, color.darkened(0.55), 1.5)
		_rim(_circle(c, 3.4, 18), accent(color), 1.6)


# A tied sack.
func _cargo_sack() -> void:
	var r: Rect2 = Rect2(-10.0, -9.0, 18.0, 18.0)
	_panel(r, 8.0, color)
	# The gathered neck and its tie, at the front.
	draw_colored_polygon(_rrect(Rect2(7.0, -3.0, 4.0, 6.0), 2.0), color.darkened(0.15))
	draw_line(Vector2(7.8, -3.2), Vector2(7.8, 3.2), accent(color), 1.8, true)


func _draw_van(ofs: Vector2) -> void:
	var body: Rect2 = Rect2(-11.0, -11.0, 22.0, 22.0)
	_shadow(body, 4.0, ofs)
	for sy: float in [-1.0, 1.0]:
		_wheel(Vector2(-3.0, 11.8 * sy), 8.0, 4.0)
	_panel(body, 4.0, color)
	_panel(Rect2(-8.5, -8.5, 17.0, 17.0), 3.0, accent(color), 0.6)
	for sy: float in [-1.0, 1.0]:
		draw_colored_polygon(_rrect(Rect2(-12.0, 7.0 * sy - 2.0, 2.6, 4.0), 0.8), TAIL_LAMP)

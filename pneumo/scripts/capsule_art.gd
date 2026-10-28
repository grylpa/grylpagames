class_name PneumoCapsuleArt
extends Node2D

# The drawn look of pneumo's capsules: pneumatic-post canisters seen from above, facing +x. They
# were one 30x25 sprite sheet (art/tube_anim_frames.png) tinted per capsule, for the lead capsule
# and its packets alike.
#
#  - a cylinder in the capsule's color: shaded across its width with a highlight along its length,
#    toward the light (the screen's top left, whatever way it faces)
#  - steel end caps with dark seal rings, as the real ones have to seal against the tube
#  - a label band in a light shade of its color, that drifts slowly round the canister with the
#    distance it travels (rolling, without the strobing a pattern of stripes gives at phone size)
#  - the LEAD capsule: a domed nose with two small lamps instead of a front cap, so the front of
#    each train reads at a glance
#
# It follows a carrier the agent already moves, turns, squashes and tints (the Head sprite, or a
# packet's TubeAnimation node): a SIBLING that copies its transform, visibility, z and color every
# frame, after it has moved (raised process_priority). The carrier's own sprite is hidden with
# self_modulate. So the bounce squash, the arc turning and set_color() all still apply untouched.

const LEN: float = 15.0          # half length, along x
const RAD: float = 10.5          # half width
const CAP: float = 4.0
const LIGHT_DIR: Vector2 = Vector2(-0.45, -0.9)
const SHADOW_OFS: Vector2 = Vector2(1.6, 2.4)
const STEEL: Color = Color(0.70, 0.73, 0.78)
const SEAL: Color = Color(0.10, 0.10, 0.12)
const LAMP: Color = Color(1.0, 0.95, 0.75)
const ROLL_PER_PX: float = 0.035     # label band turns per unit traveled

var carrier: Node2D = null
var sprite: CanvasItem = null       # the carrier's own picture, hidden
var lead: bool = false
var _roll: float = 0.0
var _last_pos: Vector2 = Vector2.INF


static func attach(_carrier: Node2D, _sprite: CanvasItem, _lead: bool) -> PneumoCapsuleArt:
	var art: PneumoCapsuleArt = PneumoCapsuleArt.new()
	art.carrier = _carrier
	art.sprite = _sprite
	art.lead = _lead
	art.process_priority = 100
	art._roll = randf()
	_sprite.self_modulate = Color(1, 1, 1, 0)
	var host: Node = _carrier.get_parent()
	host.add_child(art)
	host.move_child(art, _carrier.get_index() + 1)
	art._follow()
	return art


func _follow() -> void:
	visible = carrier.visible
	position = carrier.position
	rotation = carrier.rotation
	scale = carrier.scale
	z_index = carrier.z_index
	z_as_relative = carrier.z_as_relative


func _process(_delta: float) -> void:
	if not is_instance_valid(carrier):
		queue_free()
		return
	_follow()
	if not is_visible_in_tree():
		return
	var gp: Vector2 = global_position
	if _last_pos != Vector2.INF:
		_roll = fposmod(_roll + gp.distance_to(_last_pos) * ROLL_PER_PX, 1.0)
	_last_pos = gp
	queue_redraw()


func _hue() -> Color:
	var c: Color = carrier.modulate
	return Color(c.r, c.g, c.b, 1.0)


func _stadium(half_len: float, rad: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var st: float = half_len - rad
	for k in 13:
		var a: float = -PI * 0.5 + PI * float(k) / 12.0
		pts.append(Vector2(st + cos(a) * rad, sin(a) * rad))
	for k in 13:
		var a: float = PI * 0.5 + PI * float(k) / 12.0
		pts.append(Vector2(-st + cos(a) * rad, sin(a) * rad))
	return pts


func _draw() -> void:
	var hue: Color = _hue()
	var ink: Color = hue.darkened(0.65)
	var inv: Transform2D = get_global_transform().affine_inverse()
	var light: Vector2 = inv.basis_xform(LIGHT_DIR).normalized()
	var ofs: Vector2 = inv.basis_xform(SHADOW_OFS)
	# which side of the cylinder faces the light: +1 when local -y is toward it
	var lit_side: float = -signf(light.y) if absf(light.y) > 0.05 else -1.0
	var body: PackedVector2Array = _stadium(LEN, RAD * 0.92)
	var sh: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in body:
		sh.append(p + ofs)
	draw_colored_polygon(sh, Color(0, 0, 0, 0.25))
	# the cylinder: shaded ACROSS its width (a round tube lit from one side)
	var cols: PackedColorArray = PackedColorArray()
	for p: Vector2 in body:
		var t: float = clampf(-p.y / RAD * lit_side, -1.0, 1.0)
		cols.append(hue.lightened(0.25 * t) if t > 0.0 else hue.darkened(-0.35 * t))
	draw_polygon(body, cols)
	# the label band, rolling round the canister: its middle runs across the visible width as the
	# capsule travels, narrowing toward the edges where the cylinder turns away
	var band_y: float = sin(_roll * TAU) * RAD * 0.75
	var band_w: float = 3.2 * sqrt(maxf(0.05, 1.0 - pow(band_y / RAD, 2.0)))
	if cos(_roll * TAU) > -0.2:     # on the far side half the time: hidden there
		var x0: float = -LEN + CAP + 2.5
		var x1: float = LEN - CAP - 2.5
		draw_rect(Rect2(x0, band_y - band_w * 0.5, x1 - x0, band_w), Color(hue.lightened(0.55), 0.85))
	# the highlight along the length, toward the light
	var hy: float = -RAD * 0.45 * lit_side
	draw_line(Vector2(-LEN + CAP + 2.0, hy), Vector2(LEN - CAP - 2.0, hy),
		Color(1, 1, 1, 0.35), 1.8, true)
	# the rear cap, and the front: a cap on a packet, a steel nose with two lamps on the lead
	# capsule -- both cut from the canister's own outline, so they never stick out of it
	_cap(body, -LEN - 1.0, -LEN + CAP, lit_side)
	if lead:
		_cap(body, LEN - CAP, LEN + 1.0, lit_side)     # the same size as the rear cap: the body centered
		for sy: float in [-1.0, 1.0]:
			draw_circle(Vector2(LEN - 2.0, 3.0 * sy), 1.3, LAMP, true, -1.0, true)
	else:
		_cap(body, LEN - CAP, LEN + 1.0, lit_side)
	var closed: PackedVector2Array = body.duplicate()
	closed.append(body[0])
	draw_polyline(closed, ink, 1.4, true)


# A steel end cap: the part of the canister outline between x0 and x1, shaded like the body, with a
# dark seal ring on its inner edge.
func _cap(body: PackedVector2Array, x0: float, x1: float, lit_side: float) -> void:
	var strip: PackedVector2Array = PackedVector2Array([Vector2(x0, -RAD * 2.0), Vector2(x1, -RAD * 2.0),
		Vector2(x1, RAD * 2.0), Vector2(x0, RAD * 2.0)])
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(body, strip):
		var cols: PackedColorArray = PackedColorArray()
		for p: Vector2 in piece:
			var t: float = clampf(-p.y / RAD * lit_side, -1.0, 1.0)
			cols.append(STEEL.lightened(0.3 * t) if t > 0.0 else STEEL.darkened(-0.4 * t))
		draw_polygon(piece, cols)
	var inner: float = x1 if x0 < 0.0 else x0
	var h: float = RAD * 0.92 - 0.6
	draw_line(Vector2(inner, -h), Vector2(inner, h), SEAL, 1.3, true)

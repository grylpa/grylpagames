class_name DockArt
extends Node2D

# ONE look for every dock in every route game -- the senders, receivers, numbered docks and depots
# of taxi, Detour (parkem), Valet (guidem), pneumo, Lights Out, Storm, Wolves, Mind Palace,
# Headlights (delemfp) and Dispatch (deliverem). They used six trapezoid images, each with its own
# colors, so an arrow could be dark brown on one dock, gray on another and white on a third.
#
# A dock is a BEACON PAD: a lit pill lying ACROSS the end of the road, wider than the road, joined
# to it by a short neck. What it carries says what it is:
#   - a sender, receiver or plain dock: three chevrons in a row, pointing the way things flow (into
#     the board for a sender, out of it for a receiver -- its node is turned half round). On an
#     ACTIVE dock (a tinted sender/receiver) they light up one after another, running the way
#     things flow, like runway lights -- a step brighter, never glaring; on an idle dock they stand still, so a board full of idle
#     docks stays calm and the live ones are the ones that move.
#   - a numbered dock: the game's own number Label straight on the pad, in a deep shade of the
#     dock's hue (a dark display panel behind it was dropped: the number alone reads better).
#   - the depot: a roll-up door, three slats.
# It is NOT the trapezoid with a round badge and a chevron any more, nor a bay with a badge: both
# read as the old art redrawn (user, 2026-10-28: "be more original").
#
# THE COLOR: one hue per dock -- the sprite's tint for a tinted image, the color the image had
# baked in otherwise (`TEXTURES`) -- in real colors, not grays multiplied by a tint, so the pad can
# carry a white rim light and lit chevrons can glow past the body's color. Body, neck, chevrons, number
# and glow are all shades of that one hue.
#
# HOW IT GETS THERE: nothing in the games calls this. `MainGlobals` watches nodes entering the tree
# and hands every Sprite2D whose texture is one of `TEXTURES` to `dress()`, which hides the
# sprite's pixels (self_modulate) and adds this as its SIBLING, which then copies the sprite's
# visibility, position, rotation, z and tint every frame. So each game's code still drives its
# docks exactly as before, and a game added later with the same art is dressed too. A sibling, not
# a child: a child would inherit the sprite's tint (no white rim light possible) and its scale (taxi
# draws its docks at 0.8, which made them no wider than its road).
#
# A FADED DOCK (some games show one half see-through): every layer would show through the one
# above, so the glow -- the one layer not covered edge to edge -- is left out.

enum Kind { FLOW, NUMBER, DEPOT }

# texture -> [kind, baked hue (white = take the sprite's tint), animated when shown]
const TEXTURES: Dictionary = {
	"res://art/target-4x.png": [Kind.FLOW, Color(1.0, 0.58, 0.10), false],
	"res://art/target-no-arrow-4x.png": [Kind.NUMBER, Color(1.0, 0.58, 0.10), false],
	"res://art/receiver-w-circle-4x.png": [Kind.FLOW, Color.WHITE, true],
	"res://art/receiver-w-grad-4x.png": [Kind.FLOW, Color.WHITE, true],
	"res://art/receiver_torquise-4x.png": [Kind.FLOW, Color(0.13, 0.66, 0.60), true],
	"res://art/receiver_torquise-no-arrow-4x.png": [Kind.DEPOT, Color(0.13, 0.66, 0.60), false],
}

# Nodes their game turns half round (rot + PI): +x points OUT of the board for them, so the neck
# goes on -x while the chevrons still point +x (out: a receiver takes things in from the board).
const REVERSED_NAMES: Array = ["ReceiverImage", "DestinationImage"]

const PAD_HALF_ALONG: float = 17.0      # along the road: room for three chevrons
# The pad sits this far toward the board from the dock's node: centered on it, its outer half ran
# off the screen where a game puts its docks at the very edge (taxi).
const PAD_SHIFT: float = 6.0
const PAD_HALF_ACROSS: float = 27.0     # across it: wider than any road
const NECK_HALF: float = 13.0
const NECK_TO: float = 24.0             # the neck reaches into the road's first cell
const CHEVRONS: Array = [-8.5, 0.0, 8.5]
const RUN_HZ: float = 1.6               # running-light sweeps per second
const LIGHT_DIR: Vector2 = Vector2(-0.45, -0.9)
const SHADOW_OFS: Vector2 = Vector2(1.8, 2.6)
const LABEL_SIZE: int = 23

var kind: int = Kind.FLOW
var base_hue: Color = Color.WHITE
var animated: bool = false
var reversed: bool = false
var sprite: Sprite2D = null
var _label: Label = null
var _last_key: String = ""


static func dress(spr: Sprite2D) -> void:
	if spr.texture == null or spr.has_meta("dock_art"):
		return
	var spec: Array = TEXTURES.get(spr.texture.resource_path, [])
	if spec.is_empty():
		return
	spr.set_meta("dock_art", true)
	_attach.call_deferred(spr, spec)


static func _attach(spr: Sprite2D, spec: Array) -> void:
	if not is_instance_valid(spr) or spr.get_parent() == null:
		return
	var art: DockArt = DockArt.new()
	art.name = String(spr.name) + "Art"
	art.kind = spec[0]
	art.base_hue = spec[1]
	art.animated = spec[2]
	art.sprite = spr
	art.reversed = String(spr.name) in REVERSED_NAMES
	spr.self_modulate = Color(1, 1, 1, 0)
	var parent: Node = spr.get_parent()
	parent.add_child(art)
	parent.move_child(art, spr.get_index() + 1)
	if art.kind == Kind.NUMBER:
		art._label = parent.get_node_or_null("TargetText") as Label
		if art._label != null:
			art._fit_label()
	art._follow()


# The number is the game's own Label, a sibling: it sat at the node's corner at font size 30 and
# spilled off its dock. Center it on the pad, size it to fit, ink it in a deep shade of the dock's hue.
func _fit_label() -> void:
	# taller than the digit: a box shorter than the font's line height pushes the digit down
	var box: Vector2 = Vector2(30.0, 34.0)
	_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_label.size = box
	_label.position = -box * 0.5
	_label.pivot_offset = box * 0.5
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", LABEL_SIZE)
	_label.add_theme_constant_override("outline_size", 0)


func _hue() -> Color:
	var t: Color = sprite.modulate
	return Color(base_hue.r * t.r, base_hue.g * t.g, base_hue.b * t.b, t.a)


func _follow() -> void:
	visible = sprite.visible
	position = sprite.position
	rotation = sprite.rotation
	z_index = sprite.z_index
	z_as_relative = sprite.z_as_relative
	modulate = Color(1, 1, 1, sprite.modulate.a)
	if _label != null and is_instance_valid(_label):
		_label.add_theme_color_override("font_color", _hue().darkened(0.72))
		var side: float = -1.0 if reversed else 1.0
		_label.position = position + Vector2(PAD_SHIFT * side, 0.0).rotated(rotation) - _label.size * 0.5


func _process(_delta: float) -> void:
	if not is_instance_valid(sprite):
		queue_free()
		return
	_follow()
	if not is_visible_in_tree():
		return
	var key: String = "%s|%.3f|%s|%s" % [str(_hue()), global_rotation, str(_faded()),
		str(_label != null and _label.visible)]
	if animated or key != _last_key:
		_last_key = key
		queue_redraw()


func _faded() -> bool:
	var a: float = 1.0
	var n: Node = self
	while n is CanvasItem:
		a *= (n as CanvasItem).modulate.a
		n = n.get_parent()
	return a < 0.99


func _pill(half_along: float, half_across: float, ctr: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	# A stadium lying across the road: straight along y, round at both ends of y.
	var pts: PackedVector2Array = PackedVector2Array()
	var r: float = half_along
	var straight: float = half_across - r
	for k in 13:
		var a: float = PI * float(k) / 12.0
		pts.append(ctr + Vector2(cos(a) * r, straight + sin(a) * r))
	for k in 13:
		var a: float = PI + PI * float(k) / 12.0
		pts.append(ctr + Vector2(cos(a) * r, -straight + sin(a) * r))
	return pts


func _rrect(r: Rect2, rad: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var rr: float = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var cs: Array = [[Vector2(r.end.x - rr, r.position.y + rr), -PI * 0.5],
		[Vector2(r.end.x - rr, r.end.y - rr), 0.0], [Vector2(r.position.x + rr, r.end.y - rr), PI * 0.5],
		[Vector2(r.position.x + rr, r.position.y + rr), PI]]
	for c: Array in cs:
		for k in 5:
			var a: float = float(c[1]) + PI * 0.5 * float(k) / 4.0
			pts.append(Vector2(c[0]) + Vector2(cos(a), sin(a)) * rr)
	return pts


func _shaded_at(pts: PackedVector2Array, base: Color, light: Vector2, ctr: Vector2, half: Vector2) -> void:
	var moved: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in pts:
		moved.append(p - ctr)
	var cols: PackedColorArray = PackedColorArray()
	for p: Vector2 in moved:
		var t: float = clampf((p / half).dot(light), -1.0, 1.0)
		cols.append(base.lightened(0.25 * t) if t > 0.0 else base.darkened(-0.30 * t))
	draw_polygon(pts, cols)


func _shaded(pts: PackedVector2Array, base: Color, light: Vector2, half: Vector2, amount: float) -> void:
	var cols: PackedColorArray = PackedColorArray()
	for p: Vector2 in pts:
		var t: float = clampf((p / half).dot(light), -1.0, 1.0) * amount
		cols.append(base.lightened(0.25 * t) if t > 0.0 else base.darkened(-0.30 * t))
	draw_polygon(pts, cols)


func _outline(pts: PackedVector2Array, col: Color, w: float) -> void:
	var closed: PackedVector2Array = pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, col, w, true)


func _draw() -> void:
	var hue: Color = _hue()
	hue.a = 1.0
	var inv: Transform2D = get_global_transform().affine_inverse()
	var light: Vector2 = inv.basis_xform(LIGHT_DIR).normalized()
	var ofs: Vector2 = inv.basis_xform(SHADOW_OFS)
	var faded: bool = _faded()
	var ink: Color = hue.darkened(0.62)
	var side: float = -1.0 if reversed else 1.0
	var pc: Vector2 = Vector2(PAD_SHIFT * side, 0.0)
	var pad: PackedVector2Array = _pill(PAD_HALF_ALONG, PAD_HALF_ACROSS, pc)
	# a soft glow round a live dock
	if animated and not faded:
		for k in 3:
			var g: PackedVector2Array = _pill(PAD_HALF_ALONG + 3.0 + 3.0 * k, PAD_HALF_ACROSS + 3.0 + 3.0 * k, pc)
			draw_colored_polygon(g, Color(hue, 0.10 - 0.03 * k))
	# the neck, joining the pad to the road
	var neck: PackedVector2Array = _rrect(Rect2(Vector2((PAD_SHIFT + 4.0) * side, -NECK_HALF),
		Vector2((NECK_TO - PAD_SHIFT - 4.0) * side, NECK_HALF * 2.0)).abs(), 3.0)
	if not faded:
		var sh: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pad:
			sh.append(p + ofs)
		draw_colored_polygon(sh, Color(0, 0, 0, 0.28))
	_shaded(neck, hue.darkened(0.35), light, Vector2(NECK_TO, NECK_HALF), 0.6)
	_outline(neck, ink, 1.5)
	for y: float in [-NECK_HALF + 3.5, NECK_HALF - 3.5]:
		draw_line(Vector2((PAD_SHIFT + 8.0) * side, y), Vector2((NECK_TO - 2.0) * side, y), Color(hue.lightened(0.3), 0.6),
			1.2, true)
	# the pad: lit across, a crisp rim
	_shaded_at(pad, hue, light, pc, Vector2(PAD_HALF_ALONG, PAD_HALF_ACROSS))
	# a rim of light just inside the edge, all the way round: an off-center gloss read as a stray
	# ellipse on some docks
	_outline(_pill(PAD_HALF_ALONG - 2.5, PAD_HALF_ACROSS - 2.5, pc), Color(1, 1, 1, 0.22), 1.4)
	_outline(pad, ink, 2.0)
	match kind:
		Kind.NUMBER:
			if _label != null and is_instance_valid(_label) and _label.visible:
				pass    # the number itself is the dock's mark
			else:
				_draw_chevrons(hue, ink, false, pc.x)
		Kind.DEPOT:
			for k in 3:
				var y: float = -12.0 + 12.0 * k
				var slat: PackedVector2Array = _rrect(Rect2(pc + Vector2(-7.0, y - 3.0), Vector2(14.0, 6.0)), 2.0)
				draw_colored_polygon(slat, hue.lightened(0.35))
				_outline(slat, ink, 1.0)
		_:
			_draw_chevrons(hue, ink, animated and visible, pc.x)


# Three chevrons along the road, pointing +x (the way things flow; a receiver's node is turned half
# round). Running: each lights in turn, so the light sweeps the way things flow.
func _draw_chevrons(hue: Color, ink: Color, running: bool, cx: float) -> void:
	var phase: float = fposmod(float(Time.get_ticks_msec()) * 0.001 * RUN_HZ, 1.0) * 3.6
	for k in CHEVRONS.size():
		var x: float = cx + float(CHEVRONS[k])
		var lit: float = 0.0
		if running:
			lit = clampf(1.0 - absf(phase - float(k) - 0.5) * 1.4, 0.0, 1.0)
		# the lit one only a step brighter than the others: near-white was too distracting
		var col: Color = ink.lerp(hue, 0.4 * lit)
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(x - 3.0, -7.0), Vector2(x + 3.0, 0.0), Vector2(x - 3.0, 7.0)])
		draw_polyline(pts, col, 3.2, true)

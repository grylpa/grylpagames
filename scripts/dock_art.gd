class_name DockArt
extends Node2D

# ONE look for every dock in every route game -- the senders, receivers, numbered docks and depots
# of taxi, Detour (parkem), Valet (guidem), pneumo, Lights Out, Storm, Wolves, Mind Palace,
# Headlights (delemfp) and Dispatch (deliverem). They used six trapezoid images, each with its own
# colors, so an arrow could be dark brown on one dock, gray on another and white on a third.
#
# A dock is now a BAY: rounded on its outer side, a dark mouth slot on the side that opens into the
# board, and a round badge in the middle carrying an arrow (a sender's or a target's points in, a
# receiver's points out) or nothing, for a dock whose number is a label laid over it.
#
# THE COLOR RULE: everything is drawn in grays and multiplied by the dock's one color, so the body,
# the badge and the arrow are always the same hue -- the badge the full color, the body a shade
# below it, the arrow and the mouth deep shades of it. A tinted sprite passes its tint down (the art
# is its child); an image that had its color baked in gets that color here (`HUES`).
#
# A FADED DOCK: some games show a dock half see-through (taxi's waiting docks, a dimmed receiver),
# and every drawn layer then shows through the one above it. So nothing is drawn OFFSET under
# anything else -- the badge had a drop shadow that read as a second, off-center circle -- and the
# dock's own drop shadow is left out while it is faded (`_faded`). Not a CanvasGroup: that applied
# the dock's color twice (to the drawing and again to the group) and every dock came out too dark.
#
# HOW IT GETS THERE: nothing in the games calls this. `MainGlobals` watches nodes entering the tree
# and hands every Sprite2D whose texture is one of `TEXTURES` to `dress()`, which hides the
# sprite's own pixels (self_modulate) and adds this as its child. So the sprite still decides
# visibility, rotation, scale and tint, exactly as each game's code already drives it, and a game
# added later with the same art is dressed too. The number label next to it (`TargetText`) is
# re-set to sit on the badge in the dock's deep shade.

const TEXTURES: Dictionary = {
	"res://art/target-4x.png": [true, Color(1.0, 0.58, 0.10)],
	"res://art/target-no-arrow-4x.png": [false, Color(1.0, 0.58, 0.10)],
	"res://art/receiver-w-circle-4x.png": [true, Color.WHITE],
	"res://art/receiver-w-grad-4x.png": [true, Color.WHITE],
	"res://art/receiver_torquise-4x.png": [true, Color(0.13, 0.66, 0.60)],
	"res://art/receiver_torquise-no-arrow-4x.png": [false, Color(0.13, 0.66, 0.60)],
}
# Nodes drawn turned half round by their game (rot + PI): their mouth is on the other side.
const REVERSED_NAMES: Array = ["ReceiverImage", "DestinationImage"]

const BODY: float = 0.93
const MOUTH: float = 0.26
const INK: float = 0.30
const RING: float = 0.62
const BADGE_R: float = 15.0
const LIGHT_DIR: Vector2 = Vector2(-0.45, -0.9)
const SHADOW_OFS: Vector2 = Vector2(2.0, 3.0)
const LABEL_SIZE: int = 19
# The bay sits 5 toward the board from the cell's center, and its badge with it.
const BADGE_SHIFT: float = 4.0

var arrow: bool = true
var reversed: bool = false
var _last_rot: float = INF
var _last_faded: bool = false
var _pen: Node2D = null
var _label: Label = null        # a numbered dock's number, kept on the badge (_place_label)


func _ready() -> void:
	_pen = Node2D.new()
	_pen.draw.connect(_draw_dock)
	add_child(_pen)


static func dress(sprite: Sprite2D) -> void:
	if sprite.texture == null or sprite.has_node("DockArt"):
		return
	var spec: Array = TEXTURES.get(sprite.texture.resource_path, [])
	if spec.is_empty():
		return
	var art: DockArt = DockArt.new()
	art.name = "DockArt"
	art.arrow = spec[0]
	art.modulate = spec[1]
	art.reversed = String(sprite.name) in REVERSED_NAMES
	# drawn in the 56 units the 224 px images were shown at (sprite scale 0.25)
	art.scale = Vector2.ONE * (float(sprite.texture.get_width()) / 56.0)
	sprite.self_modulate = Color(1, 1, 1, 0)
	sprite.add_child(art)
	_fit_label.call_deferred(sprite, spec[1])


# The number on a numbered dock is the game's own Label, a sibling of the sprite. It sat at the
# node's corner at font size 30 and spilled off the badge; center it on the badge, size it to fit
# and ink it in the dock's deep shade.
static func _fit_label(sprite: Sprite2D, hue: Color) -> void:
	if not is_instance_valid(sprite) or sprite.get_parent() == null:
		return
	var lbl: Label = sprite.get_parent().get_node_or_null("TargetText") as Label
	if lbl == null or lbl.has_meta("dock_fitted"):
		return
	lbl.set_meta("dock_fitted", true)
	var box: Vector2 = Vector2(BADGE_R, BADGE_R) * 2.0
	lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	lbl.size = box
	var art: DockArt = sprite.get_node_or_null("DockArt") as DockArt
	if art != null:
		art._label = lbl
		art._place_label()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", LABEL_SIZE)
	lbl.add_theme_color_override("font_color", Color(hue.r * INK, hue.g * INK, hue.b * INK))
	lbl.add_theme_constant_override("outline_size", 0)


func _process(_delta: float) -> void:
	var gr: float = global_rotation
	var faded: bool = _faded()
	if gr != _last_rot or faded != _last_faded:
		_last_rot = gr
		_last_faded = faded
		if _pen != null:
			_pen.queue_redraw()
		_place_label()


# The label is the sprite's sibling and never turns; the badge sits off the node's center toward the
# board, which is a different screen direction for each dock and can change when a game turns one.
func _place_label() -> void:
	if _label == null or not is_instance_valid(_label):
		return
	var sprite: Node2D = get_parent() as Node2D
	var side: float = -1.0 if reversed else 1.0
	var c: Vector2 = sprite.transform * (transform * Vector2(BADGE_SHIFT * side, 0.0))
	_label.position = c - _label.size * 0.5


func _faded() -> bool:
	var a: float = 1.0
	var n: Node = self
	while n is CanvasItem:
		a *= (n as CanvasItem).modulate.a
		n = n.get_parent()
	return a < 0.99


func _g(v: float, a: float = 1.0) -> Color:
	return Color(v, v, v, a)


func _rounded_bay(side: float) -> PackedVector2Array:
	# Flat on the board side (x = side * 26), round on the outer side; 56 across, the old trapezoid's wide end (taxi shows its docks at 0.8,
	# where anything narrower came out narrower than its road). The outer side stops
	# 5 short of the dock cell's outer edge, which is the board's edge and often the screen's or
	# the header's: the trapezoid reached 8 px past it and was cut off -- unnoticed on a straight
	# edge, glaring on a round one -- and a dock flush with the edge read as running under it.
	var pts: PackedVector2Array = PackedVector2Array()
	var h: float = 28.0
	var flat: float = 26.0 * side
	var back: float = -15.0 * side
	var rr: float = 14.0
	pts.append(Vector2(flat, -h))
	pts.append(Vector2(flat, h))
	# outer corners rounded with radius rr
	for k in 9:
		var a: float = PI * 0.5 * float(k) / 8.0
		pts.append(Vector2(back + side * rr - side * rr * sin(a), h - rr + rr * cos(a)))
	for k in 9:
		var a: float = PI * 0.5 * float(k) / 8.0
		pts.append(Vector2(back + side * rr - side * rr * cos(a), -h + rr - rr * sin(a)))
	return pts


func _draw_dock() -> void:
	var inv: Transform2D = get_global_transform().affine_inverse()
	var light: Vector2 = inv.basis_xform(LIGHT_DIR).normalized()
	var ofs: Vector2 = inv.basis_xform(SHADOW_OFS)
	var side: float = -1.0 if reversed else 1.0
	var bay: PackedVector2Array = _rounded_bay(side)
	# soft shadow
	var sh: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in bay:
		sh.append(p + ofs)
	if not _faded():
		_pen.draw_colored_polygon(sh, Color(0, 0, 0, 0.22))
	# the body, lit from the screen's top left
	var cols: PackedColorArray = PackedColorArray()
	for p: Vector2 in bay:
		var t: float = clampf((p / 24.0).dot(light), -1.0, 1.0)
		cols.append(_g(minf(1.0, BODY + 0.07 * t)))
	_pen.draw_polygon(bay, cols)
	var closed: PackedVector2Array = bay.duplicate()
	closed.append(bay[0])
	_pen.draw_polyline(closed, _g(INK), 2.0, true)
	# the mouth: a dark slot along the board side, where things go in and out
	var mx: float = (26.0 - 4.0) * side
	_pen.draw_line(Vector2(mx, -17.0), Vector2(mx, 17.0), _g(MOUTH), 5.0, true)
	for y: float in [-17.0, 17.0]:
		_pen.draw_circle(Vector2(mx, y), 2.5, _g(MOUTH), true, -1.0, true)
	# the badge: a ring and a domed face, the full color
	var c: Vector2 = Vector2(BADGE_SHIFT * side, 0.0)
	_pen.draw_circle(c, BADGE_R, _g(RING), true, -1.0, true)
	_pen.draw_circle(c, BADGE_R - 2.5, _g(0.92), true, -1.0, true)
	if not _faded():     # off-center, so it would show through a faded dock
		_pen.draw_circle(c + light * 3.0, BADGE_R - 6.5, _g(1.0), true, -1.0, true)
	if arrow:
		# a sender's or target's arrow points into the board (+x); a receiver's, turned half
		# round with its node, points out -- either way it is drawn along +x here
		var pts: PackedVector2Array = PackedVector2Array([
			c + Vector2(-4.0, -7.5), c + Vector2(4.0, 0.0), c + Vector2(-4.0, 7.5)])
		_pen.draw_polyline(pts, _g(INK), 4.2, true)
		for p: Vector2 in pts:
			_pen.draw_circle(p, 2.1, _g(INK), true, -1.0, true)

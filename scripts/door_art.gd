class_name DoorArt
extends Node2D

# The drawn look of the route games' DOORS (Valet, Dispatch, Headlights, pneumo, Lights Out, taxi,
# Storm, Mind Palace, Detour): any Sprite2D showing a door_diag.png or door_open.png. They were flat
# green bars and brackets. The language is kept -- green means door, a diagonal bar is shut, corner
# marks (or, in Detour and taxi, a small ring) mean open -- but drawn with form:
#  - SHUT: a swing gate across the junction -- a rounded bar with a light stripe along it and a dark
#    edge, a steel bolt at each end and the pivot hub in the middle it swings on, over a soft shadow
#  - OPEN: the corner brackets with rounded ends, a lit edge and a shadow; or the pivot ring alone
# Hooked like DockArt: `MainGlobals` hands every Sprite2D entering the tree to `dress()`; the art is
# the sprite's CHILD, so the door's own rotation and visibility drive it, and the sprite's pixels
# are hidden. Drawn in the sprite's pixels; the light and shadow stay fixed on screen.

const GREEN: Color = Color(0.49, 0.77, 0.52)
const INK: Color = Color(0.10, 0.24, 0.13)
const STEEL: Color = Color(0.78, 0.80, 0.84)
const LIGHT_DIR: Vector2 = Vector2(-0.45, -0.9)

# file name ending -> [kind, half extent in the picture's pixels]
const KINDS: Dictionary = {
	"res://art/door_diag.png": ["gate", 19.0],
	"res://art/door_open.png": ["brackets", 19.0],
	"res://parkem/art/door_diag.png": ["gate", 12.5],
	"res://parkem/art/door_open.png": ["ring", 12.5],
	"res://taxi/art/door_diag.png": ["gate", 12.5],
	"res://taxi/art/door_open.png": ["ring", 12.5],
}

var kind: String = "gate"
var half: float = 19.0
var _last_rot: float = INF


static func dress(spr: Sprite2D) -> void:
	if spr.texture == null or spr.has_node("DoorArt"):
		return
	var spec: Array = KINDS.get(spr.texture.resource_path, [])
	if spec.is_empty():
		return
	var art: DoorArt = DoorArt.new()
	art.name = "DoorArt"
	art.kind = spec[0]
	art.half = spec[1]
	spr.self_modulate = Color(1, 1, 1, 0)
	spr.add_child(art)


func _process(_delta: float) -> void:
	var gr: float = global_rotation
	if gr != _last_rot:
		_last_rot = gr
		queue_redraw()


func _draw() -> void:
	var inv: Transform2D = get_global_transform().affine_inverse()
	var light: Vector2 = inv.basis_xform(LIGHT_DIR).normalized()
	var ofs: Vector2 = inv.basis_xform(Vector2(1.2, 1.8))
	match kind:
		"gate":
			_draw_gate(light, ofs)
		"ring":
			_draw_ring(ofs, half * 0.32)
		_:
			_draw_brackets(light, ofs)


func _bar(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	draw_line(a, b, col, w, true)
	draw_circle(a, w * 0.5, col, true, -1.0, true)
	draw_circle(b, w * 0.5, col, true, -1.0, true)


func _draw_gate(light: Vector2, ofs: Vector2) -> void:
	# the picture's bar runs top-left to bottom-right
	var d: Vector2 = Vector2(1.0, 1.0).normalized()
	var reach: float = half * 1.30
	var a: Vector2 = -d * reach
	var b: Vector2 = d * reach
	var w: float = half * 0.30
	_bar(a + ofs, b + ofs, w + 1.0, Color(0, 0, 0, 0.30))
	_bar(a, b, w + 1.6, INK)
	_bar(a, b, w, GREEN)
	# a light stripe along the side of the bar that faces the light
	var n: Vector2 = Vector2(-d.y, d.x)
	if n.dot(light) < 0.0:
		n = -n
	_bar(a + n * w * 0.22 + d * w * 0.4, b + n * w * 0.22 - d * w * 0.4, w * 0.28, GREEN.lightened(0.45))
	# bolts at the ends, and the pivot hub
	for p: Vector2 in [a + d * w * 0.15, b - d * w * 0.15]:
		draw_circle(p, w * 0.24, STEEL, true, -1.0, true)
		draw_circle(p, w * 0.24, INK, false, 0.8, true)
	_draw_ring(Vector2.ZERO, w * 0.62)


func _draw_ring(ofs: Vector2, r: float) -> void:
	draw_circle(ofs * 0.6, r + 1.0, Color(0, 0, 0, 0.25), true, -1.0, true)
	draw_circle(Vector2.ZERO, r + 0.8, INK, true, -1.0, true)
	draw_circle(Vector2.ZERO, r, GREEN.darkened(0.15), true, -1.0, true)
	draw_circle(Vector2.ZERO, r * 0.55, STEEL, true, -1.0, true)
	draw_circle(Vector2(-r * 0.15, -r * 0.18), r * 0.22, Color(1, 1, 1, 0.7), true, -1.0, true)


func _draw_brackets(light: Vector2, ofs: Vector2) -> void:
	var arm: float = half * 0.30     # short: longer arms made an open door look like a closed cage
	var w: float = half * 0.17
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var c: Vector2 = Vector2(sx, sy) * (half - w * 0.5)
			var p1: Vector2 = c - Vector2(sx, 0.0) * arm
			var p2: Vector2 = c - Vector2(0.0, sy) * arm
			var pts: PackedVector2Array = PackedVector2Array([p1, c, p2])
			var sh: PackedVector2Array = PackedVector2Array([p1 + ofs, c + ofs, p2 + ofs])
			draw_polyline(sh, Color(0, 0, 0, 0.30), w + 1.0, true)
			draw_polyline(pts, INK, w + 1.4, true)
			for e: Vector2 in [p1, p2]:
				draw_circle(e, (w + 1.4) * 0.5, INK, true, -1.0, true)
			draw_polyline(pts, GREEN, w, true)
			for e: Vector2 in [p1, p2, c]:
				draw_circle(e, w * 0.5, GREEN, true, -1.0, true)
			# lit edge on the side toward the light
			var lift: Vector2 = Vector2(0.0, -w * 0.22) if light.y < 0.0 else Vector2(0.0, w * 0.22)
			draw_line(p1 + lift, c + lift, Color(1, 1, 1, 0.35), w * 0.25, true)

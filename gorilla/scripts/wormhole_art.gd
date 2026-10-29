extends Node2D

# The drawn WORMHOLE (Gorilla): a vortex turning in the ground -- a rim of soft violet light, a
# darker well inside, spiral arms wheeling slowly into a black center, a few motes being drawn in.
# It replaces art/black_hole.png, a flat black disc. A child of the coin sprite that shows it, drawn
# in the 36 units the 256 px picture covered, and visible only while that sprite IS the wormhole
# (the same sprite shows the apples' super-foods).

const R: float = 17.0
const RIM: Color = Color(0.62, 0.42, 1.0)
const WELL: Color = Color(0.10, 0.05, 0.20)
const ARM: Color = Color(0.55, 0.40, 0.95)

var hole_texture: Texture2D = null


func _ready() -> void:
	var spr: Sprite2D = get_parent() as Sprite2D
	if spr != null and spr.texture != null:
		scale = Vector2.ONE * (float(spr.texture.get_width()) / (R * 2.0 + 2.0))


func _process(_delta: float) -> void:
	var spr: Sprite2D = get_parent() as Sprite2D
	var on: bool = spr != null and spr.texture == hole_texture
	visible = on
	if spr != null:
		spr.self_modulate.a = 0.0 if on else 1.0
	if on:
		queue_redraw()


func _draw() -> void:
	var t: float = float(Time.get_ticks_msec()) * 0.001
	# soft glow and rim, then the darkening well
	for k in 4:
		draw_circle(Vector2.ZERO, R + 3.0 - float(k), Color(RIM, 0.10 + 0.05 * float(k)), true, -1.0, true)
	draw_circle(Vector2.ZERO, R - 1.0, RIM.darkened(0.35), true, -1.0, true)
	for k in 6:
		var f: float = float(k) / 6.0
		draw_circle(Vector2.ZERO, (R - 2.0) * (1.0 - f * 0.85), RIM.darkened(0.4).lerp(WELL, f + 0.15), true, -1.0, true)
	# spiral arms, wheeling inward
	for arm in 3:
		var pts: PackedVector2Array = PackedVector2Array()
		for k in 24:
			var u: float = float(k) / 23.0
			var a: float = float(arm) * TAU / 3.0 + u * 4.2 - t * 1.6
			pts.append(Vector2(cos(a), sin(a)) * (R - 3.0) * (1.0 - u * 0.92))
		draw_polyline(pts, Color(ARM, 0.75), 1.6, true)
	# motes being pulled in
	for m in 5:
		var ph: float = fposmod(t * 0.35 + float(m) * 0.21, 1.0)
		var a2: float = float(m) * 1.9 + ph * 5.0 - t
		var p: Vector2 = Vector2(cos(a2), sin(a2)) * (R - 2.0) * (1.0 - ph)
		draw_circle(p, 0.9 * (1.0 - ph) + 0.3, Color(1, 0.95, 1.0, 0.85 * (1.0 - ph)), true, -1.0, true)
	draw_circle(Vector2.ZERO, 2.2, Color(0.02, 0.0, 0.04), true, -1.0, true)
	draw_arc(Vector2.ZERO, R - 1.0, 0.0, TAU, 40, RIM.lightened(0.35), 1.2, true)

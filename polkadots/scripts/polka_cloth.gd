class_name PolkaCloth
extends Control

# CLOTH (2026-11-12, the dressmaker's table): laid under the dot panel and under each option tile, over
# their own fill, so they read as a square of fabric and as cloth labels. A faint weave, a STITCHED seam
# just inside the edge, and -- on the dot panel -- a pin through each corner. The panel's COLOR is the
# level's and part of the stimulus: it is never changed; the weave is a few percent either way and the
# stitches are the same color a step darker, so the color seen is the color set. Never takes input.

var cloth: Color = Color.WHITE        # the panel's color (level.gd sets it)
var pins: bool = false                # the dot panel is pinned to the table
var inset: float = 7.0                # how far in from the edge the seam runs


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func set_cloth(c: Color) -> void:
	cloth = c
	queue_redraw()


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	if r.size.x < 20.0 or r.size.y < 20.0:
		return
	var light: Color = Color(1, 1, 1, 0.035)
	var dark: Color = Color(0, 0, 0, 0.035)
	# the weave: fine threads one way and the other, light and dark in turn
	var step: float = 3.0
	var y: float = r.position.y + 2.0
	var k: int = 0
	while y < r.end.y - 2.0:
		draw_line(Vector2(r.position.x + 2.0, y), Vector2(r.end.x - 2.0, y), light if k % 2 == 0 else dark, 1.0)
		y += step
		k += 1
	var x: float = r.position.x + 2.0
	k = 0
	while x < r.end.x - 2.0:
		draw_line(Vector2(x, r.position.y + 2.0), Vector2(x, r.end.y - 2.0), dark if k % 2 == 0 else light, 1.0)
		x += step
		k += 1
	# the seam: short stitches with gaps, a step darker than the cloth, with a faint light thread beside
	var seam: Rect2 = r.grow(-inset)
	var thread: Color = Color(cloth.darkened(0.35), 0.85)
	var hi: Color = Color(cloth.lightened(0.35), 0.35)
	var corners: Array = [seam.position, Vector2(seam.end.x, seam.position.y), seam.end, Vector2(seam.position.x, seam.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var length: float = a.distance_to(b)
		var dir: Vector2 = (b - a) / maxf(length, 0.001)
		var t: float = 0.0
		while t < length:
			var e: float = minf(t + 5.0, length)
			draw_line(a + dir * t, a + dir * e, thread, 1.6)
			draw_line(a + dir * t + Vector2(0.8, 0.8), a + dir * e + Vector2(0.8, 0.8), hi, 0.8)
			t += 8.0
	if pins:
		for c: Vector2 in [r.position + Vector2(inset, inset) * 1.4, Vector2(r.end.x, r.position.y) + Vector2(-inset, inset) * 1.4,
				r.end - Vector2(inset, inset) * 1.4, Vector2(r.position.x, r.end.y) + Vector2(inset, -inset) * 1.4]:
			# a dressmaker's pin pushed through: its shaft lying across the corner, a round glass head
			var shaft_end: Vector2 = c + (r.get_center() - c).normalized() * 24.0
			draw_line(c + Vector2(1.5, 2.0), shaft_end + Vector2(1.5, 2.0), Color(0, 0, 0, 0.25), 1.4)
			draw_line(c, shaft_end, Color(0.80, 0.82, 0.86), 1.6)
			draw_circle(c + Vector2(1.8, 2.4), 6.5, Color(0, 0, 0, 0.30))
			draw_circle(c, 6.5, Color(0.95, 0.80, 0.25))
			draw_circle(c + Vector2(-1.8, -1.8), 2.2, Color(1, 1, 1, 0.8))

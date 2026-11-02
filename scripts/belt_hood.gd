extends Control
class_name BeltHood

# THE ENDS OF A SORTING-GAME BELT: a dark housing with a brass lip across the top and the bottom of the
# belt, drawn OVER the items, with a soft shadow on the belt under its edge -- so a parcel comes out
# from under the top housing and goes back under the bottom one, the way a conveyor runs into a
# machine (2026-11-02).
#
# Before it, the two games disagreed: Sorting Robots zeroed its belt panel's content margins (for
# fade strips at the belt's ends), so its items slid in OVER the belt's top frame, while MonkeyC
# clipped them inside it. Both now build the belt the same way and add this on top.
#
# Usage: added as the LAST child of the belt's PanelContainer (which stretches it over the belt),
# so it draws after the items.

const HOUSING_H: float = 24.0
const HOUSING_TOP: Color = Color(0.300, 0.235, 0.185)
const HOUSING_BOT: Color = Color(0.105, 0.080, 0.065)
const LIP: Color = Color(0.780, 0.584, 0.298)
const SHADOW_H: float = 24.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 4.0 or h < HOUSING_H * 3.0:
		return
	var clear: Color = Color(0, 0, 0, 0)
	var shade: Color = Color(0, 0, 0, 0.65)
	# top housing: lit along its top, dark where it meets the belt, a brass lip on its lower edge
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, HOUSING_H), Vector2(0, HOUSING_H)]),
		PackedColorArray([HOUSING_TOP, HOUSING_TOP, HOUSING_BOT, HOUSING_BOT]))
	draw_polygon(PackedVector2Array([Vector2(0, HOUSING_H), Vector2(w, HOUSING_H), Vector2(w, HOUSING_H + SHADOW_H), Vector2(0, HOUSING_H + SHADOW_H)]),
		PackedColorArray([shade, shade, clear, clear]))
	draw_line(Vector2(0, HOUSING_H - 1.5), Vector2(w, HOUSING_H - 1.5), LIP, 3.0)
	draw_line(Vector2(0, 1.0), Vector2(w, 1.0), Color(1.0, 0.85, 0.6, 0.35), 1.5)
	# bottom housing, mirrored: the shadow falls on the belt above it
	var by: float = h - HOUSING_H
	draw_polygon(PackedVector2Array([Vector2(0, by - SHADOW_H), Vector2(w, by - SHADOW_H), Vector2(w, by), Vector2(0, by)]),
		PackedColorArray([clear, clear, shade, shade]))
	draw_polygon(PackedVector2Array([Vector2(0, by), Vector2(w, by), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([HOUSING_BOT, HOUSING_BOT, HOUSING_TOP, HOUSING_TOP]))
	draw_line(Vector2(0, by + 1.5), Vector2(w, by + 1.5), LIP, 3.0)
	# a few bolts along each housing
	for yy: float in [HOUSING_H * 0.45, by + HOUSING_H * 0.55]:
		for k in 3:
			var x: float = w * (0.2 + 0.3 * float(k))
			draw_circle(Vector2(x, yy + 0.8), 2.6, Color(0, 0, 0, 0.5))
			draw_circle(Vector2(x, yy), 2.6, Color(LIP.r, LIP.g, LIP.b, 0.9))

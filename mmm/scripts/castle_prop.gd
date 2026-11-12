class_name MmmCastleProp
extends Node2D

# WHAT BLOCKS A TILE IN THE PALACE (2026-11-12): the three brick types became three things a castle has
# standing about -- a STONE PILLAR, a BARREL, a wooden CRATE -- seen from above like everything else,
# lit from the top left (the board's light), each on a soft shadow. A pile of bricks on a palace floor
# read as a prop from another game. pipe.gd puts one on a tile that `has_brick` (kind = has_brick % 3);
# the game logic is unchanged: it is still a brick, and blocks the tile the same way.

enum Kind { PILLAR, BARREL, CRATE }

var kind: int = Kind.PILLAR

const LIGHT: Vector2 = Vector2(-0.45, -0.9)
const SHADOW_OFS: Vector2 = Vector2(3.5, 5.0)


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	match kind:
		Kind.PILLAR:
			_draw_pillar()
		Kind.BARREL:
			_draw_barrel()
		_:
			_draw_crate()


# A round thing lit from the top left: discs stepping from dark to light, each a little smaller and
# moved toward the light.
func _shaded_disc(c: Vector2, r: float, dark: Color, light: Color, steps: int = 12) -> void:
	var to_light: Vector2 = LIGHT.normalized()
	for i in steps:
		var k: float = float(i) / float(steps - 1)
		draw_circle(c + to_light * r * 0.32 * k, r * (1.0 - 0.72 * k), dark.lerp(light, k))


func _draw_pillar() -> void:
	# the square plinth it stands on, then the round shaft seen end-on, and a ring of its capital
	draw_rect(Rect2(Vector2(-15, -15) + SHADOW_OFS, Vector2(30, 30)), Color(0, 0, 0, 0.32))
	var plinth: Rect2 = Rect2(-15, -15, 30, 30)
	draw_rect(plinth, Color(0.42, 0.41, 0.44))
	draw_rect(Rect2(-15, -15, 30, 3), Color(0.58, 0.57, 0.60))       # lit top edge
	draw_rect(Rect2(-15, -15, 3, 30), Color(0.53, 0.52, 0.55))       # lit left edge
	draw_rect(Rect2(-15, 12, 30, 3), Color(0.30, 0.29, 0.32))        # shaded bottom edge
	draw_rect(Rect2(12, -15, 3, 30), Color(0.33, 0.32, 0.35))        # shaded right edge
	draw_circle(Vector2(1.5, 2.0), 12.8, Color(0, 0, 0, 0.28))       # the shaft's shadow on the plinth
	# the column's top is FLAT (shaded like a ball it read as one): an even stone face, its rim lit
	# toward the light and dark away from it, and the ring of the abacus inside
	draw_circle(Vector2.ZERO, 12.0, Color(0.66, 0.65, 0.68))
	draw_circle(Vector2.ZERO, 9.0, Color(0.71, 0.70, 0.73))
	draw_arc(Vector2.ZERO, 11.2, PI * 0.85, PI * 1.75, 24, Color(0.90, 0.89, 0.92), 1.6, true)
	draw_arc(Vector2.ZERO, 11.2, -PI * 0.25, PI * 0.85, 24, Color(0.40, 0.39, 0.42), 1.6, true)
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 32, Color(0.48, 0.47, 0.50, 0.7), 0.9, true)
	draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 40, Color(0.24, 0.23, 0.26, 0.9), 1.1, true)


func _draw_barrel() -> void:
	draw_circle(SHADOW_OFS, 14.0, Color(0, 0, 0, 0.32))
	# the stave ends round the rim, dark wood, and the lid inside it
	draw_circle(Vector2.ZERO, 14.0, Color(0.30, 0.18, 0.10))
	_shaded_disc(Vector2.ZERO, 11.5, Color(0.42, 0.27, 0.15), Color(0.66, 0.46, 0.27), 10)
	# the lid's boards: lines across it, clipped to its circle
	for k in [-6.0, -2.0, 2.0, 6.0]:
		var hw: float = sqrt(maxf(0.0, 11.5 * 11.5 - k * k))
		draw_line(Vector2(k, -hw), Vector2(k, hw), Color(0.25, 0.15, 0.08, 0.75), 0.9, true)
	# the iron hoop, lit along its top-left
	draw_arc(Vector2.ZERO, 12.7, 0.0, TAU, 44, Color(0.24, 0.24, 0.27), 2.2, true)
	draw_arc(Vector2.ZERO, 12.7, PI * 0.95, PI * 1.6, 20, Color(0.70, 0.70, 0.74, 0.8), 1.0, true)
	draw_circle(Vector2(3.5, 4.0), 1.6, Color(0.20, 0.12, 0.06))       # the bung
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 44, Color(0.14, 0.08, 0.04, 0.9), 1.0, true)


func _draw_crate() -> void:
	draw_rect(Rect2(Vector2(-15, -15) + SHADOW_OFS, Vector2(30, 30)), Color(0, 0, 0, 0.32))
	var wood: Color = Color(0.62, 0.45, 0.26)
	draw_rect(Rect2(-15, -15, 30, 30), wood.darkened(0.12))
	# the lid's boards, each its own shade, with gaps between
	var tones: Array = [0.0, 0.07, -0.04, 0.05, -0.02]
	for i in 5:
		var y: float = -11.0 + float(i) * 4.4
		var t: float = float(tones[i])
		draw_rect(Rect2(-11, y, 22, 3.6), wood.lightened(t) if t > 0.0 else wood.darkened(-t))
	# the frame: four boards round the edge, lit top and left
	draw_rect(Rect2(-15, -15, 30, 4), wood.lightened(0.16))
	draw_rect(Rect2(-15, -15, 4, 30), wood.lightened(0.08))
	draw_rect(Rect2(-15, 11, 30, 4), wood.darkened(0.25))
	draw_rect(Rect2(11, -15, 4, 30), wood.darkened(0.20))
	# the diagonal brace across it
	draw_line(Vector2(-11, 10), Vector2(10, -11), wood.darkened(0.30), 4.6, true)
	draw_line(Vector2(-11, 9), Vector2(9, -11), wood.lightened(0.05), 2.6, true)
	# nails at the frame's corners, and the outline
	for c in [Vector2(-13, -13), Vector2(13, -13), Vector2(-13, 13), Vector2(13, 13)]:
		draw_circle(c, 1.0, Color(0.20, 0.20, 0.22))
	draw_rect(Rect2(-15, -15, 30, 30), Color(0.20, 0.12, 0.06, 0.9), false, 1.0)

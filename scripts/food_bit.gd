extends Node2D
class_name FoodBit

# One apple, drawn.
#
# Gorilla's floor used to be strewn with COINS, and coins are treasure: you pick them up because
# they are worth something, and leaving one behind costs you a prize. The game now asks the player
# to keep eating or starve, and treasure is the wrong object for that rule — nobody starves for
# want of a coin.
#
# Drawn, for the same reason GrassField and ShapeLabel are drawn: the project has no food art.
#
# WHAT MAKES IT AN APPLE IS THE SILHOUETTE, NOT THE COLOUR.
#
# A first attempt tried to earn contrast by choosing a hue that stood off every floor, which meant
# giving up the stalk and the leaf. What was left was a yellow disc — barely different from the
# coin it replaced, and food only if you were told so. The identifying marks are back: two lobes
# with a dip between them, a stalk, and a leaf.
#
# CONTRAST IS THE OUTLINE'S JOB, WHICH IS WHY THE COLOUR CAN BE FREE.
#
# The room floor is `color_by_index(room_id).darkened(0.3)` with the index drawn at random from
# eleven of the shared palette, so no hue is safe: red vanishes on the dark red floor, green on
# the green and olive ones. A TWO-TONE outline — dark outside, light inside — separates the shape
# from all of them, because a mid-dark floor cannot be close to both. Measured across the whole
# palette, the weaker of the two still manages 4.48 contrast at worst, and probe_gorilla keeps it
# that way.
const RIM_DARK: Color = Color(0.078, 0.043, 0.031)
const RIM_LIGHT: Color = Color(1.0, 0.949, 0.886)
const BODY: Color = Color(1.0, 0.388, 0.278)
const BODY_SHADE: Color = Color(0.78, 0.22, 0.16)
const SHINE: Color = Color(1.0, 0.93, 0.86, 0.9)
const STALK: Color = Color(0.36, 0.22, 0.11)
const LEAF: Color = Color(0.66, 0.85, 0.29)

var radius: float = 5.5

# The apple's body as three overlapping circles: two lobes with the dip between them, and one
# below to round the bottom off. `grow` inflates every circle by the same number of PIXELS, which
# is what makes the outline an even width rather than a scaled copy.
func _lobes(grow: float, col: Color) -> void:
	var r: float = radius
	draw_circle(Vector2(-r * 0.30, r * 0.04), r * 0.70 + grow, col)
	draw_circle(Vector2(r * 0.30, r * 0.04), r * 0.70 + grow, col)
	draw_circle(Vector2(0.0, r * 0.30), r * 0.62 + grow, col)

func _draw() -> void:
	var r: float = radius
	# Stalk and leaf go down FIRST with the dark rim behind them, so the outline wraps the whole
	# silhouette and not just the body.
	var stalk_top: Vector2 = Vector2(r * 0.06, -r * 1.30)
	draw_line(Vector2(0.0, -r * 0.55), stalk_top, RIM_DARK, maxf(r * 0.34, 2.0))
	var leaf: PackedVector2Array = PackedVector2Array([
		Vector2(r * 0.10, -r * 1.15),
		Vector2(r * 1.00, -r * 1.50),
		Vector2(r * 0.55, -r * 0.82),
	])
	var leaf_rim: PackedVector2Array = PackedVector2Array([
		Vector2(r * 0.02, -r * 1.18),
		Vector2(r * 1.14, -r * 1.60),
		Vector2(r * 0.62, -r * 0.70),
	])
	draw_colored_polygon(leaf_rim, RIM_DARK)

	_lobes(maxf(r * 0.22, 2.0), RIM_DARK)
	_lobes(maxf(r * 0.11, 1.0), RIM_LIGHT)
	_lobes(0.0, BODY_SHADE)
	# The lit half, offset up and left like every other light in this game.
	draw_circle(Vector2(-r * 0.12, -r * 0.10), r * 0.62, BODY)
	draw_circle(Vector2(-r * 0.28, -r * 0.30), r * 0.20, SHINE)

	draw_line(Vector2(0.0, -r * 0.55), stalk_top, STALK, maxf(r * 0.18, 1.0))
	draw_colored_polygon(leaf, LEAF)

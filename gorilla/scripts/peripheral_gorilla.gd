extends Node2D

# A knuckle-walking gorilla, drawn in code rather than sprited.
#
# This figure is the whole point of the game and yet it is never looked at directly: the player is
# collecting coins in the room while it crosses the edge of the screen. So the SILHOUETTE has to
# carry the entire read at about one tile tall, out of the corner of the eye — a heavy hunched
# mass, a small head sunk into the shoulders with a crest and a heavy brow, long arms reaching the
# ground on their knuckles, short legs, and a silverback saddle (both the most recognizable gorilla
# marking and the only light value on a near-black animal against dark grass).
#
# THREE VIEWS, picked from the direction of travel. A side-on figure translating up or down the
# screen reads as sliding, not walking, so the vertical lanes get their own drawing instead:
#
#   * horizontal travel -> side view, mirrored to face the way it is going
#   * downward travel   -> front view, walking toward the player (face visible)
#   * upward travel     -> rear view, walking away (no face; the saddle fills the back)
#
# Every dimension is a fraction of `body_height`, so the figure follows the board's tile size and
# there are no magic pixel numbers to retune when the room size changes.

signal exited_screen

enum View {SIDE, FRONT, REAR}

const FUR: Color = Color(0.2, 0.17, 0.16)
const FUR_FAR: Color = Color(0.13, 0.11, 0.11)   # far-side limbs, pushed back by being darker
const SADDLE: Color = Color(0.58, 0.58, 0.61)
const MUZZLE: Color = Color(0.35, 0.28, 0.24)
const EYE_LIGHT: Color = Color(0.88, 0.82, 0.72)
const DARK: Color = Color(0.07, 0.06, 0.06)

const CADENCE: float = 6.5       # limb swings per second at REF_SPEED
const REF_SPEED: float = 200.0   # px/s the cadence is tuned for; faster gorillas step faster

# Half-extents of the drawn figure in units of `body_height`, published so the spawner can place it
# clear of the board without duplicating the drawing's numbers. Both views are ~1.0 tall; the side
# view is the wider one along travel, the upright views the wider one across it.
const HALF_ACROSS_SIDE: float = 0.52    # half HEIGHT — how a horizontal lane is placed
const HALF_ACROSS_FRONT: float = 0.46   # half WIDTH — how a vertical lane is placed
const HALF_ALONG: float = 0.8           # generous: how far off-screen it must start and end

var velocity: Vector2 = Vector2.ZERO
var screen_rect: Rect2 = Rect2()
var body_height: float = 50.0

var _view: int = View.SIDE
var _facing: float = 1.0
var _phase: float = 0.0

func _ready() -> void:
	if absf(velocity.x) >= absf(velocity.y):
		_view = View.SIDE
		_facing = 1.0 if velocity.x >= 0.0 else -1.0
	elif velocity.y > 0.0:
		_view = View.FRONT
	else:
		_view = View.REAR

func _process(delta: float) -> void:
	position += velocity * delta
	_phase += delta * CADENCE * maxf(0.25, velocity.length() / REF_SPEED)
	queue_redraw()
	if  velocity.x < 0 and position.x < screen_rect.position.x or \
		velocity.y < 0 and position.y < screen_rect.position.y or \
		velocity.x > 0 and position.x > screen_rect.end.x or \
		velocity.y > 0 and position.y > screen_rect.end.y:
		exited_screen.emit()
		queue_free()

func _draw() -> void:
	var u: float = body_height
	var ground: float = 0.48 * u
	# The body bobs on every second step; the ground contacts do NOT, which is what sells the weight.
	var bob: float = -0.02 * u * (0.5 + 0.5 * cos(2.0 * _phase))
	if _view == View.SIDE:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(_facing, 1.0))
		_draw_side(u, ground, bob)
	else:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_upright(u, ground, bob, _view == View.FRONT)

# ---------------------------------------------------------------------------------------------
# Side view — used by the horizontal (above / below the board) lanes.
# ---------------------------------------------------------------------------------------------

func _draw_side(u: float, ground: float, bob: float) -> void:
	var shoulder: Vector2 = Vector2(0.22 * u, -0.14 * u + bob)
	var hip: Vector2 = Vector2(-0.24 * u, -0.02 * u + bob)
	var head: Vector2 = Vector2(0.46 * u, -0.27 * u + bob)

	# Far side of the body first, so the near limbs later overlap it and give the figure depth.
	_draw_side_arm(shoulder, ground, u, _phase + PI, FUR_FAR)
	_draw_side_leg(hip, ground, u, _phase, FUR_FAR)

	# Torso: rump + barrel + shoulder hump. Three overlapping ellipses rather than one, because the
	# hump is what puts the shoulders above the hips and makes the back arch.
	_polygon(_ellipse(hip + Vector2(-0.02 * u, 0.0), Vector2(0.24 * u, 0.22 * u), 0.0), FUR)
	_polygon(_ellipse((hip + shoulder) * 0.5, Vector2(0.4 * u, 0.25 * u), (shoulder - hip).angle()), FUR)
	_polygon(_ellipse(shoulder + Vector2(-0.02 * u, -0.04 * u), Vector2(0.25 * u, 0.23 * u), 0.0), FUR)

	# Silverback saddle, sized and tilted to stay inside the back's outline at both ends.
	_polygon(_ellipse(Vector2(0.0, -0.21 * u + bob), Vector2(0.25 * u, 0.055 * u), -0.22), SADDLE)

	# Head. The crest sits on top and the head overlaps the hump, so there is no neck at all.
	_disc(head + Vector2(-0.02 * u, -0.1 * u), 0.085 * u, FUR)
	_disc(head, 0.155 * u, FUR)
	_disc(head + Vector2(-0.1 * u, 0.01 * u), 0.05 * u, FUR)
	_polygon(_ellipse(head + Vector2(0.09 * u, -0.015 * u), Vector2(0.055 * u, 0.085 * u), 0.0), DARK)
	_polygon(_ellipse(head + Vector2(0.115 * u, 0.07 * u), Vector2(0.09 * u, 0.07 * u), 0.0), MUZZLE)
	_disc(head + Vector2(0.175 * u, 0.055 * u), 0.016 * u, DARK)
	_disc(head + Vector2(0.085 * u, 0.005 * u), 0.022 * u, EYE_LIGHT)
	_disc(head + Vector2(0.088 * u, 0.005 * u), 0.011 * u, DARK)

	# Near side, drawn over the torso.
	_draw_side_leg(hip, ground, u, _phase + PI, FUR)
	_draw_side_arm(shoulder, ground, u, _phase, FUR)

# Long, heavy arm ending in the fist the animal walks on.
func _draw_side_arm(shoulder: Vector2, ground: float, u: float, ph: float, col: Color) -> void:
	var lift: float = maxf(0.0, sin(ph)) * 0.1 * u
	var knuckle: Vector2 = Vector2(0.3 * u + 0.2 * u * sin(ph), ground - 0.09 * u - lift)
	var elbow: Vector2 = shoulder.lerp(knuckle, 0.52) + Vector2(0.07 * u, 0.0)
	draw_line(shoulder, elbow, col, 0.16 * u, true)
	draw_line(elbow, knuckle, col, 0.14 * u, true)
	_disc(shoulder, 0.09 * u, col)
	_disc(elbow, 0.08 * u, col)
	_disc(knuckle, 0.095 * u, col)

# Short bent leg, mostly hidden by the barrel — the other half of the knuckle-walk stance.
func _draw_side_leg(hip: Vector2, ground: float, u: float, ph: float, col: Color) -> void:
	var lift: float = maxf(0.0, sin(ph)) * 0.07 * u
	var foot: Vector2 = Vector2(-0.26 * u + 0.16 * u * sin(ph), ground - 0.07 * u - lift)
	var knee: Vector2 = hip.lerp(foot, 0.5) + Vector2(0.09 * u, 0.0)
	draw_line(hip, knee, col, 0.19 * u, true)
	draw_line(knee, foot, col, 0.16 * u, true)
	_disc(hip, 0.1 * u, col)
	_disc(knee, 0.085 * u, col)
	_polygon(_ellipse(foot + Vector2(0.02 * u, 0.0), Vector2(0.11 * u, 0.065 * u), 0.0), col)

# ---------------------------------------------------------------------------------------------
# Front / rear view — used by the vertical (left / right of the board) lanes.
# ---------------------------------------------------------------------------------------------

# Head height, shoulder width and ground line are matched to the side view, so a gorilla does not
# appear to change size when it happens to cross a vertical lane instead of a horizontal one.
func _draw_upright(u: float, ground: float, bob: float, show_face: bool) -> void:
	# Side-to-side lean is what makes a front-on walk legible: there is no forward motion to see.
	var sway: float = 0.035 * u * sin(_phase)
	var hx: float = sway * 1.2
	var head_y: float = -0.3 * u + bob
	var sh_y: float = -0.13 * u + bob
	var hip_y: float = 0.12 * u + bob

	# Legs first — they sit behind the belly.
	_draw_upright_leg(Vector2(sway * 0.6 - 0.115 * u, hip_y), -0.135 * u, ground, u, _phase)
	_draw_upright_leg(Vector2(sway * 0.6 + 0.115 * u, hip_y), 0.135 * u, ground, u, _phase + PI)

	# Torso: a deep chest over a narrower belly.
	_polygon(_ellipse(Vector2(sway * 0.6, 0.1 * u + bob), Vector2(0.22 * u, 0.17 * u), 0.0), FUR)
	_polygon(_ellipse(Vector2(sway, -0.1 * u + bob), Vector2(0.3 * u, 0.2 * u), 0.0), FUR)

	if show_face:
		# From the front only the top edge of the saddle shows, riding over the shoulders.
		_polygon(_ellipse(Vector2(sway, -0.245 * u + bob), Vector2(0.265 * u, 0.045 * u), 0.0), SADDLE)
	else:
		# From behind the saddle IS the animal — this is the classic silverback back.
		_polygon(_ellipse(Vector2(sway, -0.14 * u + bob), Vector2(0.255 * u, 0.13 * u), 0.0), SADDLE)

	_disc(Vector2(sway - 0.28 * u, sh_y), 0.115 * u, FUR)
	_disc(Vector2(sway + 0.28 * u, sh_y), 0.115 * u, FUR)

	# Head, sunk into the shoulders with no neck showing.
	_disc(Vector2(hx, head_y - 0.105 * u), 0.085 * u, FUR)
	_disc(Vector2(hx - 0.16 * u, head_y), 0.048 * u, FUR)
	_disc(Vector2(hx + 0.16 * u, head_y), 0.048 * u, FUR)
	_disc(Vector2(hx, head_y), 0.155 * u, FUR)

	if show_face:
		_polygon(_ellipse(Vector2(hx, head_y - 0.045 * u), Vector2(0.135 * u, 0.042 * u), 0.0), DARK)
		_disc(Vector2(hx - 0.062 * u, head_y - 0.012 * u), 0.024 * u, EYE_LIGHT)
		_disc(Vector2(hx + 0.062 * u, head_y - 0.012 * u), 0.024 * u, EYE_LIGHT)
		_disc(Vector2(hx - 0.06 * u, head_y - 0.01 * u), 0.012 * u, DARK)
		_disc(Vector2(hx + 0.064 * u, head_y - 0.01 * u), 0.012 * u, DARK)
		_polygon(_ellipse(Vector2(hx, head_y + 0.085 * u), Vector2(0.105 * u, 0.08 * u), 0.0), MUZZLE)
		_disc(Vector2(hx - 0.032 * u, head_y + 0.06 * u), 0.015 * u, DARK)
		_disc(Vector2(hx + 0.032 * u, head_y + 0.06 * u), 0.015 * u, DARK)
		draw_line(Vector2(hx - 0.05 * u, head_y + 0.125 * u), Vector2(hx + 0.05 * u, head_y + 0.125 * u), DARK, 0.018 * u, true)

	# Arms last: they hang outside the body and reach the ground in front of it.
	_draw_upright_arm(Vector2(sway - 0.27 * u, sh_y), -0.335 * u, ground, u, _phase + PI)
	_draw_upright_arm(Vector2(sway + 0.27 * u, sh_y), 0.335 * u, ground, u, _phase)

func _draw_upright_arm(shoulder: Vector2, knuckle_x: float, ground: float, u: float, ph: float) -> void:
	var lift: float = maxf(0.0, sin(ph)) * 0.12 * u
	var knuckle: Vector2 = Vector2(knuckle_x, ground - 0.09 * u - lift)
	var elbow: Vector2 = shoulder.lerp(knuckle, 0.5) + Vector2(signf(knuckle_x) * 0.05 * u, 0.0)
	draw_line(shoulder, elbow, FUR, 0.155 * u, true)
	draw_line(elbow, knuckle, FUR, 0.14 * u, true)
	_disc(shoulder, 0.1 * u, FUR)
	_disc(elbow, 0.075 * u, FUR)
	_disc(knuckle, 0.095 * u, FUR)

func _draw_upright_leg(hip: Vector2, foot_x: float, ground: float, u: float, ph: float) -> void:
	var lift: float = maxf(0.0, sin(ph)) * 0.06 * u
	var foot: Vector2 = Vector2(foot_x, ground - 0.06 * u - lift)
	var knee: Vector2 = hip.lerp(foot, 0.5) + Vector2(signf(foot_x) * 0.025 * u, 0.0)
	draw_line(hip, knee, FUR, 0.18 * u, true)
	draw_line(knee, foot, FUR, 0.155 * u, true)
	_disc(knee, 0.08 * u, FUR)
	_polygon(_ellipse(foot, Vector2(0.09 * u, 0.06 * u), 0.0), FUR)

# ---------------------------------------------------------------------------------------------

func _ellipse(c: Vector2, r: Vector2, rot: float, steps: int = 22) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in steps:
		var a: float = TAU * float(i) / float(steps)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	return pts

func _polygon(pts: PackedVector2Array, col: Color) -> void:
	draw_colored_polygon(pts, col)

func _disc(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c, r, col, true, -1.0, true)

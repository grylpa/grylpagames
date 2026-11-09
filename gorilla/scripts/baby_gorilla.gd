extends "res://gorilla/scripts/peripheral_gorilla.gd"

# A LOST BABY GORILLA in the maze (2026-11-09), walking from cell to cell on the level's say-so.
#
# DRAWN AS A BABY, in its own right: a big round head with a pale face, large dark eyes, small ears,
# a round belly, short legs and little arms -- the proportions that read as "baby" at a glance. The
# first version reused the old adult figure (silverback and all) at a smaller size, and players
# took it for a grown gorilla. It still extends the old figure for its views and walk cycle: the
# face looks the way it walks (side), toward you (front) or away (rear).
#
# It appears QUIETLY: no sound, a short fade in. The game is about noticing it out of the corner of
# the eye while eating somewhere else, so its arrival must not announce itself. Once a monster has
# started hunting it, it trembles a little -- something to catch the eye if you are already looking.

var target: Vector2 = Vector2.ZERO
var step_speed: float = 60.0      # px per second between cells
var scared: bool = false
var _age: float = 0.0
const FADE_IN: float = 0.6

func _ready() -> void:
	_view = View.FRONT
	modulate.a = 0.0
	target = position

# Face the way it is about to walk: the side view for left/right, front for down, rear for up.
func head_to(p: Vector2) -> void:
	target = p
	var d: Vector2 = p - position
	if d.length() < 0.5:
		return
	if absf(d.x) >= absf(d.y):
		_view = View.SIDE
		_facing = 1.0 if d.x >= 0.0 else -1.0
	elif d.y > 0.0:
		_view = View.FRONT
	else:
		_view = View.REAR

func _process(delta: float) -> void:
	if game != null and game.paused():
		return
	_age += delta
	modulate.a = clampf(_age / FADE_IN, 0.0, 1.0)
	var d: Vector2 = target - position
	var step: float = step_speed * delta
	if d.length() > step:
		position += d.normalized() * step
		_phase += delta * CADENCE
	else:
		position = target
		_phase += delta * 1.2       # breathing, standing
	queue_redraw()

const BFUR: Color = Color(0.30, 0.22, 0.18)
const BFUR_DARK: Color = Color(0.20, 0.15, 0.12)
const BFACE: Color = Color(0.80, 0.64, 0.54)
const BBELLY: Color = Color(0.52, 0.40, 0.32)

func _draw() -> void:
	var u: float = body_height
	var shake: float = sin(_age * 40.0) * u * 0.025 if scared else 0.0
	var walking_now: bool = position.distance_to(target) > 0.5
	var bob: float = -absf(sin(_phase * 0.5)) * u * 0.05 if walking_now else sin(_age * 2.0) * u * 0.01
	draw_set_transform(Vector2(shake, bob), 0.0, Vector2.ONE)
	var f: float = _facing if _view == View.SIDE else 0.0
	var swing: float = sin(_phase * 0.5) * (1.0 if walking_now else 0.0)
	# its shadow, then the legs, the body with its belly, the arms
	draw_set_transform(Vector2(shake, 0.0), 0.0, Vector2.ONE)
	_oval_fill(Vector2(0, u * 0.47), u * 0.30, u * 0.07, Color(0, 0, 0, 0.30))
	draw_set_transform(Vector2(shake, bob), 0.0, Vector2.ONE)
	for side in [-1.0, 1.0]:
		var lx: float = side * u * 0.13 + swing * side * u * 0.03
		_oval_fill(Vector2(lx, u * 0.36), u * 0.09, u * 0.11, BFUR_DARK)
		_oval_fill(Vector2(lx + f * u * 0.03, u * 0.45), u * 0.09, u * 0.04, BFACE.darkened(0.25))
	_oval_fill(Vector2(0, u * 0.14), u * 0.29, u * 0.26, BFUR)
	if _view != View.REAR:
		_oval_fill(Vector2(f * u * 0.06, u * 0.18), u * 0.17, u * 0.16, BBELLY)
	for side in [-1.0, 1.0]:
		var sway: float = -swing * side * u * 0.05
		var sh: Vector2 = Vector2(side * u * 0.24, u * 0.0)
		var hand: Vector2 = Vector2(side * u * 0.31 + sway, u * 0.32)
		draw_line(sh, hand, BFUR_DARK if side * f < 0.0 else BFUR, u * 0.12)
		draw_circle(hand, u * 0.065, BFACE.darkened(0.30))
	# the head: big, round, a tuft on top, small ears
	var hc: Vector2 = Vector2(f * u * 0.03, -u * 0.22)
	for side in [-1.0, 1.0]:
		if _view == View.SIDE and side * f > 0.0:
			continue
		draw_circle(hc + Vector2(side * u * 0.25, -u * 0.01), u * 0.075, BFUR)
		draw_circle(hc + Vector2(side * u * 0.25, -u * 0.01), u * 0.04, BFACE.darkened(0.2))
	draw_circle(hc, u * 0.27, BFUR)
	draw_circle(hc + Vector2(-u * 0.04, -u * 0.27), u * 0.05, BFUR)
	draw_circle(hc + Vector2(u * 0.03, -u * 0.28), u * 0.045, BFUR)
	if _view == View.REAR:
		return
	# the face: a pale heart-shaped mask, big eyes with a highlight, a broad nose, a small mouth
	var fc: Vector2 = hc + Vector2(f * u * 0.07, u * 0.03)
	var mask_w: float = u * (0.15 if _view == View.SIDE else 0.20)
	_oval_fill(fc + Vector2(0, -u * 0.02), mask_w, u * 0.16, BFACE)
	_oval_fill(fc + Vector2(-mask_w * 0.45, -u * 0.09), mask_w * 0.55, u * 0.08, BFACE)
	_oval_fill(fc + Vector2(mask_w * 0.45, -u * 0.09), mask_w * 0.55, u * 0.08, BFACE)
	var eyes: Array = [-1.0, 1.0] if _view == View.FRONT else [f]
	var ew: float = u * (0.058 if scared else 0.050)
	for side in eyes:
		var ec: Vector2 = fc + Vector2(side * u * (0.085 if _view == View.FRONT else 0.04), -u * 0.07)
		draw_circle(ec, ew, Color(0.12, 0.08, 0.06))
		draw_circle(ec + Vector2(-u * 0.015, -u * 0.018), ew * 0.35, Color(1, 1, 1, 0.9))
		if scared:
			draw_line(ec + Vector2(-side * u * 0.05, -u * 0.08), ec + Vector2(side * u * 0.02, -u * 0.06), BFUR_DARK, u * 0.025)
	_oval_fill(fc + Vector2(f * u * 0.02, u * 0.02), u * 0.055, u * 0.035, BFACE.darkened(0.45))
	draw_arc(fc + Vector2(f * u * 0.02, u * 0.07), u * 0.045, 0.3 if not scared else PI + 0.4, PI - 0.3 if not scared else TAU - 0.4, 8, BFUR_DARK, u * 0.018)

func _oval_fill(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 20:
		var a: float = TAU * float(k) / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

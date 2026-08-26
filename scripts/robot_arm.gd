extends Control
class_name RobotBay

# The robots. Both games are named after them; neither had one on screen.
#
# The only "robot" that ever existed was a transient gripper (`claw.gd`) spawned for the half-second
# of a successful pick-up and thrown away again. A first attempt at standing arms beside the belts
# was worse than nothing: they sat there looking pleasant, unconnected to anything, while a separate
# claw did the actual picking — decoration competing with the board.
#
# So: the base is bolted to the SCREEN EDGE, clear of the belts, and this arm IS the claw. On a
# pick-up it reaches out to the item, closes on it, and is dragged along with it as it goes, because
# it tracks the flying item's real position every frame rather than playing an animation next to it.
#
# Drawn top-down, like the belts and the floor.

const BASE: Color = Color(0.263, 0.294, 0.361)
const BASE_RIM: Color = Color(0.400, 0.443, 0.529)
const ARM: Color = Color(0.325, 0.361, 0.435)
const ARM_LIP: Color = Color(0.478, 0.522, 0.608)
const JOINT: Color = Color(0.157, 0.176, 0.222)
const JAW: Color = Color(0.588, 0.627, 0.706)
const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.28)
const LAMP_IDLE: Color = Color(0.478, 0.361, 0.161)
const LAMP_BUSY: Color = Color(0.353, 0.847, 0.475)

# Bays: [{"rect": belt rect in this control's space, "side": -1 left / +1 right}, ...]
var bays: Array = []

var _t: float = 0.0
# Per bay: the flying item this robot is holding, or null.
var _held: Array = []
# Per bay: 0 idle .. 1 fully committed, eased so the reach and the release both have weight.
var _reach: Array = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ensure(n: int) -> void:
	while _held.size() < n:
		_held.append(null)
	while _reach.size() < n:
		_reach.append(0.0)

# The robot on `bay` takes `item` off the belt and keeps hold of it until it is freed.
func hold(bay: int, item: Node2D) -> void:
	_ensure(bay + 1)
	_held[bay] = item
	_reach[bay] = maxf(float(_reach[bay]), 0.35)

func _process(delta: float) -> void:
	_t += delta
	_ensure(bays.size())
	for i in range(_reach.size()):
		var busy: bool = _held[i] != null and is_instance_valid(_held[i])
		if not busy:
			_held[i] = null
		var target: float = 1.0 if busy else 0.0
		_reach[i] = move_toward(float(_reach[i]), target, delta * (6.0 if busy else 2.6))
	queue_redraw()

# Where the gripper should be for this bay, in local space.
func _tip_for(i: int, base: Vector2, side: int) -> Vector2:
	var held = _held[i] if i < _held.size() else null
	if held != null and is_instance_valid(held):
		return (held as Node2D).global_position - global_position
	# Idle: tucked against the edge, just off the base, drifting gently. Never over the belt.
	var d: float = float(side)
	var sway: float = sin(_t * 1.5 + float(i) * 2.1) * 7.0
	return base + Vector2(-d * 26.0, 42.0 + sway)

func _draw() -> void:
	_ensure(bays.size())
	for i in range(bays.size()):
		var b: Dictionary = bays[i]
		var r: Rect2 = b["rect"]
		if r.size.x < 10.0 or r.size.y < 10.0:
			continue
		_draw_robot(i, r, int(b["side"]))

func _draw_robot(i: int, belt: Rect2, side: int) -> void:
	var d: float = float(side)
	var base_r: float = 22.0
	# Bolted to the screen edge, level with the top third of the belt it serves. Clear of the belt
	# entirely — the previous version stood in the gap beside it and crowded the board.
	var bx: float = (size.x - base_r - 4.0) if d > 0.0 else (base_r + 4.0)
	var base: Vector2 = Vector2(bx, belt.position.y + belt.size.y * 0.28)
	var tip: Vector2 = _tip_for(i, base, side)

	# Two-bone IK, so the elbow bends the way a real arm does instead of following a fixed offset.
	var l1: float = size.x * 0.30
	var l2: float = size.x * 0.30
	var elbow: Vector2 = _elbow(base, tip, l1, l2, -d)

	var busy: float = float(_reach[i])
	var off: Vector2 = Vector2(0.0, 6.0)
	_limb(base + off, elbow + off, 12.0, SHADOW, SHADOW)
	_limb(elbow + off, tip + off, 9.0, SHADOW, SHADOW)
	_limb(base, elbow, 12.0, ARM, ARM_LIP)
	_limb(elbow, tip, 9.0, ARM, ARM_LIP)
	draw_circle(elbow, 7.0, JOINT)
	draw_circle(elbow, 4.2, ARM_LIP)

	# Jaws: open while reaching, closed once it has the item.
	var spread: float = lerpf(11.0, 4.0, busy)
	var along: Vector2 = (tip - elbow).normalized()
	if along == Vector2.ZERO:
		along = Vector2(-d, 0.0)
	var across: Vector2 = Vector2(-along.y, along.x)
	for s in [-1.0, 1.0]:
		var root: Vector2 = tip + across * spread * s
		draw_line(root, root + along * 12.0, JAW, 4.0, true)

	# Base last, so the arm reads as emerging from under it.
	draw_circle(base + Vector2(0.0, 4.0), base_r, SHADOW)
	draw_circle(base, base_r, BASE)
	draw_arc(base, base_r - 1.0, 0.0, TAU, 24, BASE_RIM, 2.0, true)
	for k in range(6):
		var a: float = float(k) / 6.0 * TAU + 0.4
		draw_circle(base + Vector2(cos(a), sin(a)) * (base_r * 0.66), 1.9, BASE_RIM)
	draw_circle(base, base_r * 0.30, LAMP_BUSY if busy > 0.05 else LAMP_IDLE)

# Elbow of a two-bone chain from `base` to `tip`. `bend` picks which side it flexes toward, so both
# robots bend away from the belt rather than one of them folding across it.
func _elbow(base: Vector2, tip: Vector2, l1: float, l2: float, bend: float) -> Vector2:
	var to: Vector2 = tip - base
	var dist: float = clampf(to.length(), 0.001, l1 + l2 - 0.001)
	var dir: Vector2 = to.normalized() if to.length() > 0.001 else Vector2(1, 0)
	# Distance along the base->tip line to the elbow's projection, by the law of cosines.
	var a: float = (dist * dist + l1 * l1 - l2 * l2) / (2.0 * dist)
	var hsq: float = l1 * l1 - a * a
	var hgt: float = sqrt(hsq) if hsq > 0.0 else 0.0
	var perp: Vector2 = Vector2(-dir.y, dir.x) * signf(bend if bend != 0.0 else 1.0)
	return base + dir * a + perp * hgt

func _limb(a: Vector2, b: Vector2, w: float, body: Color, lip: Color) -> void:
	draw_line(a, b, body, w, true)
	var n: Vector2 = (b - a).normalized()
	var perp: Vector2 = Vector2(-n.y, n.x) * (w * 0.28)
	draw_line(a + perp, b + perp, lip, maxf(w * 0.22, 1.0), true)

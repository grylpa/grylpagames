extends Area2D

signal door_pressed(p)

var rot_idx: int = 0

var board_pos: Vector2i

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_rot(0)

func set_board_pos(p):
	board_pos = p

# A right angle in 0.035 s -- about two frames at 60 fps.
#
# Deliberately NOT the capsule heads' rate (agent.gd::TURN_SPEED, 0.12 s). Only one of the three
# taps animates at all: open->diagonal and diagonal->open swap sprites and are instant, so a
# diagonal->diagonal swing that took 0.12 s was the odd one out, and it lagged behind its own
# logic. `rot_idx` routes a capsule the instant the door is tapped, so a long swing left a window
# where the door sent capsules one way while still drawn pointing the other. Keep this short
# enough to read as a flick rather than a movement.
const TURN_SPEED: float = PI * 0.5 / 0.035

var _target_rot: float = 0.0
var _turning: bool = false

func set_rot(_rot_idx):
	# The LOGIC changes at once — rot_idx is what routes a capsule — and only the drawing eases,
	# the same split the agents use for their heads.
	var was_diagonal: bool = rot_idx != 0
	rot_idx = _rot_idx
	_target_rot = PI / 2.0 if rot_idx == 2 else 0.0
	if rot_idx == 0:
		$DoorOpen.show()
		$DoorDiag.hide()
	else:
		$DoorOpen.hide()
		$DoorDiag.show()
	# Swinging from one diagonal to the other is the same flap moving, so it is worth animating.
	# Coming from OPEN swaps to a different sprite, where a rotation would just look like a glitch.
	_turning = was_diagonal and rot_idx != 0
	if not _turning:
		rotation = _target_rot

func _process(delta: float) -> void:
	if not _turning:
		return
	var diff: float = wrapf(_target_rot - rotation, -PI, PI)
	var step: float = TURN_SPEED * delta
	if absf(diff) <= step:
		rotation = _target_rot
		_turning = false
	else:
		rotation += signf(diff) * step

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		door_pressed.emit(board_pos)

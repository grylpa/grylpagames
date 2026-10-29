extends Area2D

signal door_pressed(p)
signal door_type_changed(p)

var rot_idx: int = 0

var board_pos: Vector2i

# THE DOOR IS DRAWN (_draw), not the two sprites: shut, it is a RAISED BAR across the junction's
# diagonal -- a soft shadow on the floor, a dark base, a pale-green lit top and a post at each end --
# so it reads as the solid thing a creature turns away from; open, it is the bar's pivot alone, a
# small stud. It was a 2 px pale line and a hollow ring, which on the flagstone floor did not look
# like anything a creature could bump into ("where are the walls?", user, 2026-10-25).
const BAR: Color = Color(0.447, 0.702, 0.471)          # door_diag.png's green
const BAR_BASE: Color = Color(0.20, 0.33, 0.22)
const BAR_LIT: Color = Color(0.70, 0.90, 0.72)
const STUD: Color = Color(0.55, 0.62, 0.56)

# SHUT, it is the shared drawn gate (scripts/door_art.gd, the same as Valet's and the other route
# games'): a green bar with a light stripe, a bolt at each end and the pivot hub in the middle. Open,
# it stays this game's own single stud (_draw).
var _gate: DoorArt = null

func _ready() -> void:
	$DoorOpen.hide()
	$DoorDiag.hide()
	_gate = DoorArt.new()
	_gate.kind = "gate"
	_gate.half = 16.0          # a little longer and thicker than the old bar (+-12), nearer Valet's
	add_child(_gate)
	set_rot(0)

func _draw() -> void:
	# the light comes from the top left of the SCREEN whatever way the door is turned
	var down: Vector2 = Vector2(1.2, 2.0).rotated(-rotation)
	if rot_idx == 0:      # open: the stud; shut, the gate (_gate) draws
		draw_circle(down * 0.6, 3.4, Color(0, 0, 0, 0.30))
		draw_circle(Vector2.ZERO, 3.0, STUD.darkened(0.35))
		draw_circle(Vector2(-0.6, -0.6).rotated(-rotation), 2.0, STUD)

func set_board_pos(p):
	board_pos = p

var time_to_reset_ms = 0
func set_rot(_rot_idx, dtime_to_reset_ms = -1):
	rot_idx = _rot_idx
	rotation = PI / 2.0 if rot_idx == 2 else 0.0
	modulate = Color(1,1,1,1)
	if _gate != null:
		_gate.visible = rot_idx != 0
	queue_redraw()
	if rot_idx == 0:
		time_to_reset_ms = 0
	else:
		if dtime_to_reset_ms > 0:
			time_to_reset_ms = MainGlobals.timems() + dtime_to_reset_ms
	
func _process(_delta: float) -> void:
	if time_to_reset_ms > 0:
		if MainGlobals.timems() >= time_to_reset_ms:
			set_rot(0)		
			time_to_reset_ms = 0
			door_type_changed.emit(board_pos)
			modulate = Color(1,1,1,1)
		else:
			var dt = time_to_reset_ms - MainGlobals.timems()
			if dt < 1000:
				modulate = Color(1,1,1,0.2 + 0.8 * dt / 1000.0)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		door_pressed.emit(board_pos)

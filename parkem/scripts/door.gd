extends Area2D

signal door_pressed(p)
signal door_type_changed(p)

var rot_idx: int = 0

var board_pos: Vector2i

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_rot(0)

func set_board_pos(p):
	board_pos = p

var time_to_reset_ms = 0
func set_rot(_rot_idx, dtime_to_reset_ms = -1):
	rot_idx = _rot_idx
	rotation = PI / 2.0 if rot_idx == 2 else 0.0
	modulate = Color(1,1,1,1)
	if rot_idx == 0:
		$DoorOpen.show()
		$DoorDiag.hide()
		time_to_reset_ms = 0
	else:
		$DoorOpen.hide()
		$DoorDiag.show()
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

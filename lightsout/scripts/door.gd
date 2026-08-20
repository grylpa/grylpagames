extends Area2D

signal door_pressed(p)

var rot_idx: int = 0

var board_pos: Vector2i

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_rot(0)

func set_board_pos(p):
	board_pos = p

func set_rot(_rot_idx):
	rot_idx = _rot_idx
	rotation = PI / 2.0 if rot_idx == 2 else 0.0
	if rot_idx == 0:
		$DoorOpen.show()
		$DoorDiag.hide()
	else:
		$DoorOpen.hide()
		$DoorDiag.show()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass		

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		door_pressed.emit(board_pos)

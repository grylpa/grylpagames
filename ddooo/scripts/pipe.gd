extends Area2D

signal pipe_pressed(_board_pos)

var board_pos = Vector2i.ZERO

func _ready() -> void:
	pass

func _on_input_event(_viewport:Node, event:InputEvent, _shape_idx:int) -> void:
	if event.is_action_pressed("lclick"):
		pipe_pressed.emit(board_pos)

extends Area2D

signal mouse_click

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		mouse_click.emit()

extends Control

func _draw() -> void:
	var level: Node = get_parent()
	if level != null:
		level._do_draw(self)

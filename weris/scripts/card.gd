extends Node2D

signal card_pressed(person_idx: int)

var person_idx := 0
var scale_factor := 1.0

const UNSCALED_W = 236.0
const UNSCALED_H = 334.0

func setup(idx: int, show_name: bool):
	person_idx = idx
	%TextureRect.texture = WerisG.get_person_image(idx)
	var full_name = WerisG.get_person_name(idx)
	%NameLabel.text = full_name.split(" ")[0] if " " in full_name else full_name
	%NameLabel.visible = show_name

func set_width(width: float):
	scale_factor = width / UNSCALED_W
	scale = Vector2(scale_factor, scale_factor)

func scaled_h() -> float:
	return UNSCALED_H * scale_factor

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var sw = UNSCALED_W * scale_factor
			var sh = UNSCALED_H * scale_factor
			var rect = Rect2(position.x - sw / 2.0, position.y, sw, sh)
			if rect.has_point(event.position):
				card_pressed.emit(person_idx)
				get_viewport().set_input_as_handled()

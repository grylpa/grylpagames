@tool
extends Control

signal button_pressed

@export var close_icon: Texture2D:
	set(value):
		close_icon = value
		if is_inside_tree():
			_update_theme()

@export var icon_color: Color = Color.WHITE:
	set(value):
		icon_color = value
		if is_inside_tree():
			_update_theme()

@export var disabled_icon_color: Color = Color.GRAY:
	set(value):
		disabled_icon_color = value
		if is_inside_tree():
			_update_theme()
						
@export var text_color: Color = Color.WHITE:
	set(value):
		text_color = value
		if is_inside_tree():
			_update_theme()

@export var font_size: int = 32:
	set(value):
		font_size = value
		if is_inside_tree():
			_update_theme()

@onready var button_node: Button = %ButtonX

func _ready():
	_update_theme()

func _update_theme():
	if !is_instance_valid(button_node):
		return

	button_node.add_theme_color_override("font_color", text_color)
	button_node.add_theme_font_size_override("font_size", font_size)

	if close_icon:
		button_node.icon = close_icon
	button_node.add_theme_color_override("icon_normal_color", icon_color)
	button_node.add_theme_color_override("icon_hover_color", icon_color)
	button_node.add_theme_color_override("icon_pressed_color", icon_color)
	button_node.add_theme_color_override("icon_disabled_color", disabled_icon_color)


func set_tap_height(h: float) -> void:
	$MarginContainer.offset_bottom = h

func _on_button_x_pressed() -> void:
	button_pressed.emit()


func _on_margin_container_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		button_node.pressed.emit()

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
	# The X is the other end of the screen's header, and the title beside it is scaled on mobile.
	# Left at its desktop size it shrinks against everything around it — and this runs from _ready(),
	# AFTER the app's automatic type pass, so a plain override here would undo that pass as well.
	if Engine.is_editor_hint():
		button_node.add_theme_font_size_override("font_size", font_size)
	else:
		MainGlobals.set_font_size(button_node, font_size)
		# The X the player sees is an ICON (art/x32.png, 32x32 native), which no type scale reaches,
		# and it sat in a 48x48 button looking small beside a title that had grown.
		#
		# `expand_icon` fills the box it already has — 32 to 48, half again as big — WITHOUT changing
		# any geometry. Growing custom_minimum_size instead put the button past its anchored 56-unit
		# slot and off the right edge of the screen.
		button_node.expand_icon = MainGlobals.is_mobile()

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

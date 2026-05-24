extends CanvasLayer

func _ready():
	MainGlobals.set_visible("instructions",true)
	MainGlobals.sig_need_to_close_info_popups.connect(close_window)

func close_window() -> void:
	MainGlobals.set_visible("instructions",false)
	queue_free()

func set_title(title):
	%Title.text = title

func set_text(text):
	%Text.text = text

func _on_x_close_scene_button_pressed() -> void:
	close_window()

func _input(event) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("esc"):
		close_window()
		get_viewport().set_input_as_handled()
		return
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()
		return

func set_font_size(_font_size:int):
	if _font_size > 0:
		%Text.add_theme_font_size_override("font_size", _font_size)

func _on_background_panel_gui_input(_event: InputEvent) -> void:
	pass
	# if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or \
	# 	(event is InputEventScreenTouch and event.pressed):
	# 	close_window()
	# 	get_viewport().set_input_as_handled()
	# 	return


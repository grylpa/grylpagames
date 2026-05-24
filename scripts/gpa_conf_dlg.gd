extends CanvasLayer

func _ready():
	$Window.size = MainGlobals.full_screen_size
	$Window.position = Vector2.ZERO
	$Window.unresizable = true
	$Window.borderless = true
	MainGlobals.set_visible("gpa_conf_dlg",true)

	if MainGlobals.is_mobile():
		%OkButton.add_theme_font_size_override("font_size", 60)
		%CancelButton.add_theme_font_size_override("font_size", 60)
		%ButtonsHBoxContainer.add_theme_constant_override("separation", 60)

func _on_x_close_scene_button_pressed() -> void:
	_on_cancel_button_pressed()

func _on_window_window_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel")  or event.is_action_pressed("esc"):
		get_viewport().set_input_as_handled()
		_on_cancel_button_pressed()

func _on_ok_button_pressed() -> void:
	MainGlobals.set_visible("gpa_conf_dlg",false)
	queue_free()
	if _on_ok_callback != null and _on_ok_callback.is_valid():
		_on_ok_callback.call()

func _on_cancel_button_pressed() -> void:
	MainGlobals.set_visible("gpa_conf_dlg",false)
	queue_free()
	if _on_cancel_callback != null and _on_cancel_callback.is_valid():
		_on_cancel_callback.call()

var _on_ok_callback = null
var _on_cancel_callback = null

func set_all(title, text, ok_text, cancel_text, ok_func, cancel_func):
	%Title.text = title
	%Text.text = text
	if ok_text != null and ok_text.length() > 0:
		%OkButton.text = ok_text
	if cancel_text != null and cancel_text.length() > 0:
		%CancelButton.text = cancel_text
	_on_ok_callback = ok_func
	_on_cancel_callback = cancel_func

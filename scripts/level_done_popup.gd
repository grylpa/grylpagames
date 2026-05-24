extends CanvasLayer

var _closing := false

func _ready():
	MainGlobals.set_visible("level_done",true)
	MainGlobals.sig_need_to_close_info_popups.connect(close_window)


func close_window() -> void:
	if _closing:
		return
	_closing = true

	MainGlobals.set_visible("level_done", false)
	visible = false
	await get_tree().process_frame
	if has_node("MarginContainer"):
		$MarginContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_close_async()

func _close_async() -> void:
	await get_tree().process_frame
	MainGlobals.global_level_done_popup_closed()
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

func _on_margin_container_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or \
		(event is InputEventScreenTouch and event.pressed):
		close_window()
		get_viewport().set_input_as_handled()
		return

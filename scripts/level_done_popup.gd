extends CanvasLayer

# The card shown when a LEVEL ends — the summary with the score, accuracy and what happens next.
# Every game uses it (~25 call sites via GenericGameUtil.show_level_done_popup), so it is the one
# screen a player sees in all of them. The card itself is ResultCard; this file is only the part
# that is specific to a level ending: a check badge, and "Continue".
#
# `set_title()` and `set_text()` are still the only two entry points, and the popup still frees
# itself through MainGlobals.global_level_done_popup_closed().

var _closing: bool = false
var _parts: Dictionary = {}

func _ready() -> void:
	MainGlobals.set_visible("level_done", true)
	MainGlobals.sig_need_to_close_info_popups.connect(close_window)
	_parts = ResultCard.build(self, ResultCard.ACCENT, true, "Continue", close_window)

func set_title(title) -> void:
	if _parts.has("title") and is_instance_valid(_parts["title"]):
		_parts["title"].text = str(title)

func set_text(text) -> void:
	ResultCard.set_body(_parts, str(text), ResultCard.ACCENT)

func close_window() -> void:
	if _closing:
		return
	_closing = true
	MainGlobals.set_visible("level_done", false)
	visible = false
	await get_tree().process_frame
	_close_async()

func _close_async() -> void:
	await get_tree().process_frame
	MainGlobals.global_level_done_popup_closed()
	queue_free()

func _input(event) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("esc") \
			or event.is_action_pressed("ui_accept"):
		close_window()
		get_viewport().set_input_as_handled()
		return
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()
		return

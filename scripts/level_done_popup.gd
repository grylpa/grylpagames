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
# Most games cannot fail a level — reaching the end IS finishing it — so this stays true unless a
# gated game says otherwise.
var _passed: bool = true

func _ready() -> void:
	MainGlobals.set_visible("level_done", true)
	MainGlobals.sig_need_to_close_info_popups.connect(close_window)

# Must be called before set_title/set_text, which is where the card gets built.
func set_passed(passed: bool) -> void:
	_passed = passed

func _accent() -> Color:
	return ResultCard.ACCENT if _passed else ResultCard.ALERT

func _build() -> void:
	if _parts.is_empty():
		# No check badge on a level that was not passed: a tick over "you need at least 70%" is
		# the card congratulating the player for failing.
		_parts = ResultCard.build(self, _accent(), _passed, "Continue", close_window)

func set_title(title) -> void:
	_build()
	_parts["title"].text = str(title)

func set_text(text) -> void:
	_build()
	ResultCard.set_body(_parts, str(text), _accent())

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

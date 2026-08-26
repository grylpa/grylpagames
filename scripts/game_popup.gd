extends CanvasLayer

# The card shown BETWEEN rounds and before a level starts — "Level 3", "Well done!", "Oh no!",
# "Time's up!". Same card as the level summary (ResultCard); a player meets the two back to back,
# so they have to look like the same app.
#
# Unlike the level summary, this one is not always good news, and it is sometimes not news at all —
# a "Level 3" briefing is about what is ABOUT to happen. All three used to be the same gold panel
# with the same "Continue" on the button. ResultCard.tone_for reads which one this is off the
# title: a briefing gets the cool panel and "Start", a win the gold panel and a check, a loss the
# warm one.

var _closing: bool = false
var _parts: Dictionary = {}
var _accent: Color = ResultCard.ACCENT

func _ready() -> void:
	MainGlobals.set_visible("game_popup", true)
	MainGlobals.sig_need_to_close_info_popups.connect(close_window)

func set_title(title) -> void:
	var text: String = str(title)
	# The card is built HERE and not in _ready because its accent and badge depend on the title,
	# and the caller sets that immediately after instantiating (see GenericGameUtil.show_game_popup).
	if _parts.is_empty():
		_accent = ResultCard.accent_for(text)
		_parts = ResultCard.build(self, _accent, ResultCard.has_badge(text),
			ResultCard.button_for(text), close_window)
	_parts["title"].text = text

func set_text(text) -> void:
	if _parts.is_empty():
		_parts = ResultCard.build(self, _accent, false, "Start", close_window)
	ResultCard.set_body(_parts, str(text), _accent)

func close_window() -> void:
	if _closing:
		return
	_closing = true
	MainGlobals.set_visible("game_popup", false)
	visible = false
	await get_tree().process_frame
	_close_async()

func _close_async() -> void:
	await get_tree().process_frame
	MainGlobals.global_game_popup_closed()
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

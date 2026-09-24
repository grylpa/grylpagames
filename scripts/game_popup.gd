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

# THIS card closed. MainGlobals.sig_game_popup_closed says only that SOME card closed, which a game
# with more than one card up cannot tell apart -- Storm started a new round on the wrong one.
signal closed

var _closing: bool = false
# HELD: the card is up but not ready -- see hold().
var _held: bool = false
var _hold_label: Label = null
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

# HOLD THE CARD while the game gets ready behind it. The body -- already set to the real text, so the
# card is laid out at its final size -- is hidden and `message` shown in its place, and the button is
# hidden and takes no clicks. Nothing closes a held card: not its button, not a tap outside it, not Enter or
# Escape, not sig_need_to_close_info_popups. release() shows the real body and the button.
# Storm uses it for "Building world" while its board is built; the text given to set_text() before
# hold() must have the same number of lines as the text given to release(), so nothing moves.
func hold(message: String) -> void:
	if _parts.is_empty():
		return
	_held = true
	var rows: Control = _parts["rows"]
	rows.modulate.a = 0.0
	var foot: Control = _parts["foot"]
	foot.modulate.a = 0.0
	# Not disabled: a disabled button is drawn in another style, 20 px shorter, and the card shrank by
	# that much and grew back on release. It only stops taking the mouse; close_window() refuses a
	# held card anyway.
	for b in foot.find_children("*", "Button", true, false):
		(b as Button).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hold_label = Label.new()
	_hold_label.text = message
	_hold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hold_label.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(_hold_label, 22)
	_hold_label.add_theme_color_override("font_color", _accent)
	_hold_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Over the body, in the same box: the body's parent is a MarginContainer, which stacks its
	# children, so the message sits exactly where the text will be.
	rows.get_parent().add_child(_hold_label)

func release(text: String) -> void:
	if _parts.is_empty():
		return
	set_text(text)
	if _hold_label != null and is_instance_valid(_hold_label):
		_hold_label.queue_free()
	_hold_label = null
	(_parts["rows"] as Control).modulate.a = 1.0
	var foot: Control = _parts["foot"]
	foot.modulate.a = 1.0
	for b in foot.find_children("*", "Button", true, false):
		(b as Button).mouse_filter = Control.MOUSE_FILTER_STOP
	_held = false

func is_held() -> bool:
	return _held

func close_window() -> void:
	if _closing or _held:
		return
	_closing = true
	MainGlobals.set_visible("game_popup", false)
	visible = false
	await get_tree().process_frame
	_close_async()

func _close_async() -> void:
	await get_tree().process_frame
	closed.emit()
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

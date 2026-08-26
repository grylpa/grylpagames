extends CanvasLayer

# "Are you sure?" — leaving a game, starting a new board, resetting scores, logging out, changing
# game. Every one of them throws something away, which is why they ask at all.
#
# It used to be an OS `Window` (a real sub-window, sized to the screen and made borderless to hide
# that fact) wearing the same tiled grass as the old level dialogs, with two identical buttons. Now
# it is the card the rest of the app uses (ResultCard), on the ALERT tone.
#
# Two things about it are deliberate and must not be "improved":
#
# - **It covers the screen completely.** This dialog is reachable mid-play, so a
#   see-through one is a free pause: hold the board, study it through the scrim, then cancel. That
#   is why the original was full-screen, and why ResultCard.build_confirm asks for an OPAQUE
#   backdrop rather than the scrim the summary cards use.
# - **Cancel is on the left, confirm on the right**, where they have always been. Muscle memory on
#   a dialog that throws a game away is not worth redesigning. The two are told apart by weight
#   instead: the safe one is filled, the one that loses your progress is a ghost button.
#
# `set_all()` is unchanged, so all six call sites are untouched.

var _on_ok_callback = null
var _on_cancel_callback = null
var _answered: bool = false
var _parts: Dictionary = {}

func _ready() -> void:
	MainGlobals.set_visible("gpa_conf_dlg", true)

func set_all(title, text, ok_text, cancel_text, ok_func, cancel_func) -> void:
	_on_ok_callback = ok_func
	_on_cancel_callback = cancel_func
	var ok: String = str(ok_text) if ok_text != null and str(ok_text).length() > 0 else "Yes"
	var cancel: String = str(cancel_text) if cancel_text != null and str(cancel_text).length() > 0 else "Oops, No"
	# One of the callers passes an empty cancel label to mean "there is nothing to cancel here"
	# (main_menu's second Reset Scores call, which is really just a notice). Then the only way out
	# is the one button, and it must not be the ghost.
	if cancel_text != null and str(cancel_text).length() == 0:
		_parts = ResultCard.build(self, ResultCard.ALERT, false, ok, _on_ok)
	else:
		_parts = ResultCard.build_confirm(self, ok, cancel, _on_ok, _on_cancel)
	_parts["title"].text = str(title)
	ResultCard.set_body(_parts, str(text), ResultCard.ALERT)

func _on_ok() -> void:
	if _answered:
		return
	_answered = true
	MainGlobals.set_visible("gpa_conf_dlg", false)
	var cb = _on_ok_callback
	queue_free()
	if cb != null and cb is Callable and cb.is_valid():
		cb.call()

func _on_cancel() -> void:
	if _answered:
		return
	_answered = true
	MainGlobals.set_visible("gpa_conf_dlg", false)
	var cb = _on_cancel_callback
	queue_free()
	if cb != null and cb is Callable and cb.is_valid():
		cb.call()

func _input(event: InputEvent) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	# Escape cancels. Enter is deliberately NOT bound: the confirming button is the destructive one
	# here, and a stray Return should never be what throws a game away.
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("esc"):
		get_viewport().set_input_as_handled()
		_on_cancel()
		return
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()

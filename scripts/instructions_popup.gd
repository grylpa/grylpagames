extends CanvasLayer

var _tutorial_host: Node = null
var _tutorial_game = null

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

# "Interactive tutorial" — offered where a player already goes when they have forgotten how a game
# works. Named for what it is rather than for what it does for you: it sits directly under a wall
# of instructions, and the useful distinction to draw there is that this one is played, not read. This is the app's only tutorial entry besides the game's own main menu, since the
# chooser's "How to play" picker is gone: a game with a tutorial teaches itself on the first run,
# and after that the offer belongs next to the text it replaces.
#
# `host` is the game's main scene. Whether it HAS a tutorial is read off the scene — if its main.gd
# defines start_tutorial(), it has one — the same test main_menu.gd uses, so no game opts in and a
# game that gains a tutorial later gets the button for free.
func offer_tutorial(host: Node, game_util) -> void:
	if host == null or not host.has_method("start_tutorial"):
		return
	_tutorial_host = host
	_tutorial_game = game_util
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 12)
	var btn: Button = Button.new()
	btn.text = "Interactive tutorial"
	btn.add_theme_font_size_override("font_size", 40 if MainGlobals.is_mobile() else 24)
	btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = Vector2(240, 0)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(_on_tutorial_pressed)
	margin.add_child(btn)
	%Title.get_parent().get_parent().add_child(margin)

func _on_tutorial_pressed() -> void:
	var host: Node = _tutorial_host
	if host == null or not is_instance_valid(host) or not host.has_method("start_tutorial"):
		return
	# Close FIRST: this popup registers itself with MainGlobals.set_visible("instructions"), which
	# is one of the things game.paused() reads — a tutorial started underneath it would begin
	# frozen, and its own freeze/unfreeze would then be fighting a screen the player cannot see.
	close_window()
	if _tutorial_game != null:
		MainGlobals.note_tutorial_started(_tutorial_game.file_names_prefix)
	# Deferred so the tutorial starts on a clean frame, after this popup has actually gone.
	host.call_deferred("start_tutorial")

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


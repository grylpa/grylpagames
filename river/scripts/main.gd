extends Node

var game: GenericGameUtil
var main_menu
var _did_per_level_save: bool = false

func _ready() -> void:
	game = RiverG.game
	MainGlobals.digitized_swipe_mode = true
	RiverG.load_settings()
	main_menu = game.create_main_menu(self)

	main_menu.sig_start_game.connect(_on_main_menu_start_game)
	main_menu.sig_slider_changed.connect(_on_menu_slider_changed)
	main_menu.sig_option_changed.connect(_on_menu_option_changed)
	main_menu.add_entry(1, "Duration (min)", 1, 30, false)
	main_menu.add_option_entry(2, "Mode", _build_mode_options())
	refresh_menu()
	show_main_menu()

	$Help.set_texts({"N": "New session"})
	$Help.close_help.connect(_on_help_close)

	game.set_instructions("River",
		"Follow the river channel as it scrolls past.\n\n" +
		"Move UP during inhale, stay level during holds,\n" +
		"move DOWN during exhale.\n\n" +
		"If you drift into the bank you'll walk on land\n" +
		"until the channel comes back to you.\n\n" +
		"No score — just breathe and relax.\n\n" +
		"On desktop: press ↑ to inhale, press ↓ to exhale,\n" +
		"release to hold.",
		36 if MainGlobals.is_mobile() else 22)
	if not game.shown_instructions:
		game.show_instructions(self)
		RiverG.save_settings()

	main_menu.show_continue_and_start_new(false)
	game.progress_score_label = "Accuracy"
	game.show_scores_level = false
	game.show_scores_time = false

	$Level.sig_session_done.connect(_on_level_session_done)
	$Level.sig_show_main_menu.connect(_on_level_show_main_menu)

func show_main_menu() -> void:
	main_menu.show_continue_and_start_new(false)
	main_menu.show()
	$Level.hide()
	MainGlobals.update_bottom_bar(["help", "mute", "scores"])
	MainGlobals.add_action_button(null)

func show_level() -> void:
	get_viewport().gui_release_focus()
	$Level.show()
	main_menu.hide()
	MainGlobals.update_bottom_bar(["menu", "mute"])
	MainGlobals.add_action_button(null)

func new_game() -> void:
	_did_per_level_save = false
	game.reset(true)
	show_level()
	$Level.new_game()

func _on_level_session_done() -> void:
	_did_per_level_save = true
	game.convert_ongoing_score_to_permanent()

func _on_level_show_main_menu() -> void:
	game.playing = false
	show_main_menu()
	if _did_per_level_save:
		game.clear_ongoing_score()
	else:
		game.convert_ongoing_score_to_permanent()

func _on_main_menu_start_game(_start_new: bool) -> void:
	RiverG.save_settings()
	new_game()

func _fv(v) -> String:
	var r: float = round(float(v) * 2.0) / 2.0
	if r == int(r):
		return str(int(r))
	var whole: int = int(r)
	return ("" if whole == 0 else str(whole)) + "½"

func _build_mode_options() -> Array:
	var opts: Array = []
	for p in RiverG.GUIDED_PRESETS:
		opts.append("Guided %s-%s-%s-%s" % [_fv(p[0]), _fv(p[1]), _fv(p[2]), _fv(p[3])])
	return opts

func refresh_menu() -> void:
	main_menu.update_val(1, RiverG.duration_min)
	main_menu.update_option(2, RiverG.selected_mode)

func _on_menu_slider_changed(id: int, val: float) -> void:
	if id == 1:
		RiverG.duration_min = roundi(val)
		refresh_menu()

func _on_menu_option_changed(id: int, idx: int) -> void:
	if id == 2:
		RiverG.selected_mode = idx
		RiverG.save_settings()

func _on_help_close() -> void:
	game.pause(false)
	$Help.hide()

func _input(event: InputEvent) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if game.handle_main_menu(self, event, _on_level_show_main_menu):
		pass
	elif event.is_action_pressed("help"):
		$Help.show()
	elif event.is_action_pressed("esc"):
		if $Help.is_visible():
			_on_help_close()
	elif event.is_action_pressed("new_board"):
		new_game()
	elif event.is_action_pressed("lost_focus"):
		game.in_focus = false
	elif event.is_action_pressed("resumed_focus"):
		game.in_focus = true
	else:
		game.handle_event(event, self)

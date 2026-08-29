extends Node

var game: GenericGameUtil
var main_menu
var _did_per_level_save: bool = false

func _ready() -> void:
	game = TypitG.game
	TypitG.load_settings()
	main_menu = game.create_main_menu(self)

	main_menu.sig_start_game.connect(_on_main_menu_start_game)
	main_menu.sig_slider_changed.connect(_on_menu_slider_changed)
	main_menu.add_entry(1, "Level", 1, TypitG.num_levels(), false)
	refresh_menu()
	show_main_menu()

	$Help.set_texts({"N": "New session"})
	$Help.close_help.connect(_on_help_close)

	game.set_instructions("Typit",
		"Type the text shown on screen.\n\n" +
		"Tap the on-screen keyboard — every tap is measured:\n" +
		"where exactly you touched, how fast, how many mistakes.\n\n" +
		"Press Done when you're finished.\n\n" +
		"After the session: heat map, speed, accuracy.\n" +
		"Stats screen shows charts and per-key analysis.\n\n" +
		"Higher levels = smaller keys.",
		34 if MainGlobals.is_mobile() else 20)
	if not game.shown_instructions:
		game.show_instructions(self)
		TypitG.save_settings()

	main_menu.show_continue_and_start_new(false)
	# Score = speed cpm → "Score" chart tab shows speed over time
	game.progress_score_label = "Speed"
	game.show_scores_level = true
	game.show_scores_time = false
	game.progress_level_pos = 4
	# Chart metric 1 (Time tab): distance % — [9] = int(dist_pct)
	game.progress_time_pos = 9
	game.progress_time_label = "Distance"
	game.progress_time_format = "%d"
	# progress_time_is_pct intentionally NOT set: let chart auto-scale (avoids overflow rendering)
	# Chart metric 2 (Pct tab): mistake rate % — [10] = mistakes*100/total
	game.progress_pct_pos = 10
	game.progress_pct_label = "Mistake rate"
	game.progress_pct_format = "%d%%"

	game.scores_callback = func(row: Array) -> Array:
		if row.size() <= 7:
			return []
		return [str(int(row[5])), str(int(row[7]))]

	# Custom scores scene = standard scores_list + a Keys tab (inherited scene).
	# Set as game.scores_scene so the normal scores-button path opens exactly one screen.
	game.scores_scene = load("res://typit/scenes/typit_scores.tscn")

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
	TypitG.save_settings()
	new_game()

func refresh_menu() -> void:
	main_menu.update_val(1, TypitG.selected_level)

func _on_menu_slider_changed(id: int, val: float) -> void:
	if id == 1:
		TypitG.selected_level = roundi(val)
	refresh_menu()
	TypitG.save_settings()

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
		# During a tutorial this restarts the LESSON — new_game() alone would rebuild the board
		# under the running coach and wedge it. See GenericGameUtil.restart_tutorial().
		if not game.restart_tutorial():
			new_game()
	elif event.is_action_pressed("lost_focus"):
		game.in_focus = false
	elif event.is_action_pressed("resumed_focus"):
		game.in_focus = true
	else:
		game.handle_event(event, self)

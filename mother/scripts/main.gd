extends Node

var game: GenericGameUtil
var main_menu
var _did_per_level_save: bool = false

func _ready() -> void:
	game = MotherG.game
	MainGlobals.digitized_swipe_mode = true
	MotherG.load_settings()
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

	game.set_instructions("Mother Snake",
		"Follow the mother snake as she breathes.\n\n" +
		"Move UP when she rises (inhale),\n" +
		"stay level during holds,\n" +
		"move DOWN when she descends (exhale).\n\n" +
		"Your score is how closely your breathing\n" +
		"matched the target pattern.\n\n" +
		"On desktop: press ↑ to inhale, press ↓ to exhale,\n" +
		"release to hold.",
		36 if MainGlobals.is_mobile() else 22)
	if not game.shown_instructions:
		game.show_instructions(self)
		MotherG.save_settings()

	main_menu.show_continue_and_start_new(false)
	game.progress_score_label = "Accuracy"
	game.show_scores_level = false
	game.show_scores_time = true
	game.scores_time_col_name = "React Time"
	game.progress_time_pos = 8
	game.progress_time_label = "React Time"
	game.progress_time_format = "%d ms"
	game.scores_callback = func(row: Array) -> Array:
		if row.size() > 8 and int(row[8]) > 0:
			return ["", "%d ms" % int(row[8])]
		return ["", ""]

	$Level.sig_session_done.connect(_on_level_session_done)
	$Level.sig_show_main_menu.connect(_on_level_show_main_menu)

	# Teach instead of showing the menu when the player asked for the tutorial from the chooser's
	# "How to play", OR when this is their first ever run of this game.
	if MainGlobals.take_pending_tutorial("mother") \
			or MainGlobals.take_auto_tutorial("mother", game.shown_instructions):
		call_deferred("start_tutorial")

var _tutorial_saved_mode: int = -1
var _tutorial_saved_duration: int = -1

# The real session with the real input, recorded by nobody: TutorialRunner puts the game into
# tutorial_mode, which suppresses every write in generic_game_util.gd until the tutorial ends.
func start_tutorial() -> void:
	var tut: Script = load("res://mother/scripts/tutorial.gd")
	# BEFORE new_game(): new_game() -> game.reset(true) -> convert_ongoing_score_to_permanent(),
	# which would commit and upload the player's unfinished real session.
	game.begin_tutorial()
	# Guided 4-2-4-2. Active mode has no mother at all, which makes every caption meaningless, and
	# the User preset is built from sessions a first-timer has not had yet. Neither this nor the
	# duration below is part of the GenericGameUtil snapshot, so both are restored by hand.
	_tutorial_saved_mode = MotherG.selected_mode
	MotherG.selected_mode = 2
	# The default session is one minute; the tutorial outlasts that easily, and the results panel
	# opening over the coach mid-lesson is not something a player can make sense of.
	_tutorial_saved_duration = MotherG.duration_min
	MotherG.duration_min = 30
	new_game()
	var runner: TutorialRunner = TutorialRunner.new()
	runner.run(self, tut.steps($Level, game), game, Callable(self, "_on_tutorial_done"))

func _on_tutorial_done(_completed: bool) -> void:
	_restore_tutorial_globals()
	game.playing = false
	game.level_is_ready = false
	refresh_menu()
	show_main_menu()

# Also called from _exit_tree: leaving the game mid-tutorial frees the scene, and the runner's own
# _exit_tree does not invoke this callback — so without it the stashed values stay applied to the
# player's real settings.
func _restore_tutorial_globals() -> void:
	if _tutorial_saved_mode >= 0:
		MotherG.selected_mode = _tutorial_saved_mode
		_tutorial_saved_mode = -1
	if _tutorial_saved_duration >= 0:
		MotherG.duration_min = _tutorial_saved_duration
		_tutorial_saved_duration = -1

func _exit_tree() -> void:
	_restore_tutorial_globals()

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
	$Level.active_mode = not MotherG.guided_mode
	$Level.new_game()

func _on_level_session_done() -> void:
	# A tutorial session must not become the player's own breathing pattern. It holds the session
	# open for 30 minutes, so a player working through it slowly can genuinely reach the end of
	# one — and the Active branch below writes MotherG.learned_* and has_user_session, which the
	# "User" mode preset is built from. save_score and MotherG.save_settings are both suppressed in
	# tutorial mode, but those are plain in-memory globals: nothing hits disk here, and then the
	# next legitimate save persists the tutorial's numbers as the player's own pattern.
	if game.tutorial_mode:
		return
	_did_per_level_save = true
	if MotherG.guided_mode:
		game.save_score($Level.get_session_score(true, false))
	else:
		var phases: Array = $Level.get_computed_phases()
		if phases[0] + phases[2] > 100.0:
			MotherG.learned_inhale_ms = phases[0]
			MotherG.learned_hold_top_ms = phases[1]
			MotherG.learned_exhale_ms = phases[2]
			MotherG.learned_hold_bottom_ms = phases[3]
			MotherG.has_user_session = true
			MotherG.save_settings()
			_rebuild_mode_options()

func _on_level_show_main_menu() -> void:
	game.playing = false
	show_main_menu()
	if _did_per_level_save:
		game.clear_ongoing_score()
	else:
		game.convert_ongoing_score_to_permanent()

func _on_main_menu_start_game(_start_new: bool) -> void:
	MotherG.save_settings()
	new_game()

func _fv(v) -> String:
	var r: float = round(float(v) * 2.0) / 2.0
	if r == int(r):
		return str(int(r))
	var whole: int = int(r)
	return ("" if whole == 0 else str(whole)) + "½"

func _build_mode_options() -> Array:
	var opts: Array = ["Active"]
	if MotherG.has_user_session:
		opts.append("User %s-%s-%s-%s" % [
			_fv(MotherG.learned_inhale_ms / 1000.0),
			_fv(MotherG.learned_hold_top_ms / 1000.0),
			_fv(MotherG.learned_exhale_ms / 1000.0),
			_fv(MotherG.learned_hold_bottom_ms / 1000.0)])
	for p in MotherG.GUIDED_PRESETS:
		opts.append("%s-%s-%s-%s" % [_fv(p[0]), _fv(p[1]), _fv(p[2]), _fv(p[3])])
	return opts

func _mode_to_option_idx() -> int:
	if MotherG.selected_mode == 0:
		return 0
	if not MotherG.has_user_session:
		if MotherG.selected_mode == 1:
			return 0
		return MotherG.selected_mode - 1
	return MotherG.selected_mode

func _option_idx_to_mode(idx: int) -> int:
	if idx == 0:
		return 0
	if MotherG.has_user_session:
		return idx
	return idx + 1

func _rebuild_mode_options() -> void:
	main_menu.set_option_items(2, _build_mode_options())
	main_menu.update_option(2, _mode_to_option_idx())

func refresh_menu() -> void:
	main_menu.update_val(1, MotherG.duration_min)
	main_menu.update_option(2, _mode_to_option_idx())

func _on_menu_slider_changed(id: int, val: float) -> void:
	if id == 1:
		MotherG.duration_min = roundi(val)
		refresh_menu()

func _on_menu_option_changed(id: int, idx: int) -> void:
	if id == 2:
		MotherG.selected_mode = _option_idx_to_mode(idx)
		MotherG.save_settings()

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

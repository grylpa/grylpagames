extends Node

var game: GenericGameUtil
var main_menu
var _did_per_level_save: bool = false

func _ready() -> void:
	game = CrackG.game
	MainGlobals.digitized_swipe_mode = true
	CrackG.load_settings()
	main_menu = game.create_main_menu(self)

	main_menu.sig_start_game.connect(_on_main_menu_start_game)
	main_menu.sig_slider_changed.connect(_on_menu_slider_changed)
	main_menu.sig_option_changed.connect(_on_menu_option_changed)
	main_menu.add_entry(1, "Duration (min)", 1, 20, false)
	main_menu.add_option_entry(2, "Mode", _build_mode_options())
	refresh_menu()
	show_main_menu()

	$Help.set_texts({"N": "New session"})
	$Help.close_help.connect(_on_help_close)

	game.set_instructions("Crack the Safe",
		"Breathe in rhythm to crack the combination lock.\n\n" +
		"Swipe UP (inhale) → hold → swipe DOWN (exhale) → hold.\n\n" +
		"The dial shows your recent timings vs. the target.\n" +
		"When all four phases match — the safe opens!\n\n" +
		"On desktop: press ↑ to inhale, press ↓ to exhale,\n" +
		"release to hold.",
		36 if MainGlobals.is_mobile() else 22)
	# Teach instead of showing the instructions wall when the tutorial was asked for, or on a
	# first run. Consumed before the `shown_instructions` check, which would otherwise put a page
	# of text in front of the lesson that replaces it.
	var _teaching: bool = MainGlobals.take_pending_tutorial("crack") \
		or MainGlobals.take_auto_tutorial("crack", game.shown_instructions)
	if _teaching:
		call_deferred("start_tutorial")
	elif not game.shown_instructions:
		game.show_instructions(self)
		CrackG.save_settings()

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
	$Level.active_mode = not CrackG.guided_mode
	$Level.new_game()

func _on_level_session_done() -> void:
	_did_per_level_save = true
	game.convert_ongoing_score_to_permanent()
	if not CrackG.guided_mode:
		var phases: Array = $Level.get_computed_phases()
		if phases[0] + phases[2] > 100.0:
			CrackG.learned_inhale_ms = phases[0]
			CrackG.learned_hold_top_ms = phases[1]
			CrackG.learned_exhale_ms = phases[2]
			CrackG.learned_hold_bottom_ms = phases[3]
			CrackG.has_user_session = true
			CrackG.save_settings()
			_rebuild_mode_options()

func _on_level_show_main_menu() -> void:
	game.playing = false
	show_main_menu()
	if _did_per_level_save:
		game.clear_ongoing_score()
	else:
		game.convert_ongoing_score_to_permanent()

func _on_main_menu_start_game(_start_new: bool) -> void:
	CrackG.save_settings()
	new_game()

func _fv(v) -> String:
	var r: float = round(float(v) * 2.0) / 2.0
	if r == int(r):
		return str(int(r))
	var whole: int = int(r)
	return ("" if whole == 0 else str(whole)) + "½"

func _build_mode_options() -> Array:
	var opts: Array = ["Active"]
	if CrackG.has_user_session:
		opts.append("User %s-%s-%s-%s" % [
			_fv(CrackG.learned_inhale_ms / 1000.0),
			_fv(CrackG.learned_hold_top_ms / 1000.0),
			_fv(CrackG.learned_exhale_ms / 1000.0),
			_fv(CrackG.learned_hold_bottom_ms / 1000.0)])
	for p in CrackG.GUIDED_PRESETS:
		opts.append("%s-%s-%s-%s" % [_fv(p[0]), _fv(p[1]), _fv(p[2]), _fv(p[3])])
	return opts

func _mode_to_option_idx() -> int:
	if CrackG.selected_mode == 0:
		return 0
	if not CrackG.has_user_session:
		if CrackG.selected_mode == 1:
			return 0
		return CrackG.selected_mode - 1
	return CrackG.selected_mode

func _option_idx_to_mode(idx: int) -> int:
	if idx == 0:
		return 0
	if CrackG.has_user_session:
		return idx
	return idx + 1

func _rebuild_mode_options() -> void:
	main_menu.set_option_items(2, _build_mode_options())
	main_menu.update_option(2, _mode_to_option_idx())

func refresh_menu() -> void:
	main_menu.update_val(1, CrackG.duration_min)
	main_menu.update_option(2, _mode_to_option_idx())

func _on_menu_slider_changed(id: int, val: float) -> void:
	if id == 1:
		CrackG.duration_min = roundi(val)
		refresh_menu()

func _on_menu_option_changed(id: int, idx: int) -> void:
	if id == 2:
		CrackG.selected_mode = _option_idx_to_mode(idx)
		CrackG.save_settings()

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


# --- tutorial ---------------------------------------------------------------------------------

var _tutorial_saved_mode: int = -1
var _tutorial_saved_duration: int = -1

# begin_tutorial() BEFORE new_game(): new_game() runs game.reset(true), which calls
# convert_ongoing_score_to_permanent() and would commit the player's unfinished real session.
func start_tutorial() -> void:
	var tut: Script = load("res://crack/scripts/tutorial.gd")
	game.begin_tutorial()
	# Force a guided preset. Active mode ("Active"), which the player may have selected, is one in which
	# _try_score() returns immediately -- the safe can NEVER open, so the tutorial's whole payoff
	# step would wait forever on an `unlocked` that the game is incapable of sending. 2 is the
	# first entry of GUIDED_PRESETS. Assign `selected_mode`, not `guided_mode`: the latter is a
	# getter-only computed property and assigning to it does nothing.
	_tutorial_saved_mode = CrackG.selected_mode
	CrackG.selected_mode = 2
	# Crack runs on its own session clock (`_duration_ms`), not the game util's, so
	# TutorialRunner.TUTORIAL_MINUTES does not reach it. The default session is 1 minute and this
	# tutorial asks for two full breathing cycles at four seconds a phase -- it would be cut off
	# by the results panel partway through. Neither value is in the GenericGameUtil snapshot, so
	# both are restored by hand below.
	_tutorial_saved_duration = CrackG.duration_min
	CrackG.duration_min = 20
	new_game()
	var runner: TutorialRunner = TutorialRunner.new()
	# The tutorial ends on the real summary screen, and a summary nobody can read is worse than
	# none: the overlay dims the whole board on a talking step. Null while the panel is hidden, so
	# no earlier step gets a bright hole where it will eventually appear.
	runner.never_dim = [func(): return $Level.tutorial_results_rect()]
	runner.run(self, tut.steps($Level, game), game, Callable(self, "_on_tutorial_done"))

func _on_tutorial_done(_completed: bool) -> void:
	_restore_tutorial_globals()
	game.playing = false
	game.level_is_ready = false
	refresh_menu()
	show_main_menu()

# Also called from _exit_tree: leaving the game mid-tutorial frees the scene, and the runner's own
# _exit_tree does not invoke this callback -- so without it the tutorial's stashed mode and
# duration stayed applied to the player's real settings.
func _restore_tutorial_globals() -> void:
	if _tutorial_saved_mode >= 0:
		CrackG.selected_mode = _tutorial_saved_mode
		_tutorial_saved_mode = -1
	if _tutorial_saved_duration >= 0:
		CrackG.duration_min = _tutorial_saved_duration
		_tutorial_saved_duration = -1

func _exit_tree() -> void:
	_restore_tutorial_globals()

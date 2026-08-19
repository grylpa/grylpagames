extends Node

@onready var hud = $HUD
var game: GenericGameUtil = null
var main_menu = null
var _did_per_level_save: bool = false

var POS_SCORE_DIFFICULTY: int = 6
var POS_SCORE_MEAN_TIME_MS: int = 7
var POS_SCORE_PCT_CORRECT: int = 8

func _ready() -> void:
	game = DidiG.game
	game.initial_score = 100

	randomize()
	RenderingServer.set_default_clear_color(Color.hex(0x3C5D3EFF))
	DidiG.load_settings()
	main_menu = game.create_main_menu(self)

	main_menu.sig_start_game.connect(_on_main_menu_menu_start_game)
	main_menu.sig_option_changed.connect(_on_menu_option_changed)
	main_menu.add_option_entry(1, "Starting level", DidiLevelConfig.level_names())
	refresh_menu()
	show_main_menu()
	$Help.set_texts({
		"N": "New game",
	})
	$Help.close_help.connect(_on_help_close_help)
	hud.set_game(game)
	hud.show()
	hud.show_corrects_mistakes()
	hud.update_all()
	game.game_over_on_zero_score = true
	game.sig_game_is_done.connect(on_game_is_done)
	$Level.sig_level_is_done.connect(_on_level_sig_level_is_done)
	$Level.started_playing.connect(_on_level_started_playing)

	var ins_font_sz: int = 36 if MainGlobals.is_mobile() else 22
	game.set_instructions("Pinpoint",		
		"A shape flashes briefly at the center and a dot flashes somewhere else.\n" +
		"Then, find the location where the dot flashed and tap the shape that appeared in the center.",
		ins_font_sz)
	if not game.shown_instructions:
		game.show_instructions(self)
		DidiG.save_settings()
	main_menu.show_continue_and_start_new(false)
	game.scores_callback = Callable(self, "add_score_line_vals")
	game.show_scores_level = true
	game.progress_level_pos = POS_SCORE_DIFFICULTY
	game.progress_time_pos = POS_SCORE_MEAN_TIME_MS
	game.progress_pct_pos = POS_SCORE_PCT_CORRECT
	for lvl in DidiLevelConfig.LEVELS:
		game.progress_level_names[lvl["id"]] = DidiLevelConfig.level_header(lvl["id"])
	game.sig_level_is_done.connect(_on_game_sig_level_is_done)

	# Launched from the chooser's "How to play"? Then teach instead of showing the menu.
	if MainGlobals.take_pending_tutorial("didi"):
		call_deferred("start_tutorial")

var _tutorial_saved_level: int = -1

# The real game with the real rules, recorded by nobody: TutorialRunner puts the game into
# tutorial_mode, which suppresses every write in generic_game_util.gd until the tutorial ends.
func start_tutorial() -> void:
	var tut: Script = load("res://didi/scripts/tutorial.gd")
	# BEFORE new_game(): new_game() -> game.reset(true) -> convert_ongoing_score_to_permanent(),
	# which would commit and upload the player's unfinished real session.
	game.begin_tutorial()
	# starting_level lives on DidiG, not the game util, so the snapshot does not cover it.
	_tutorial_saved_level = DidiG.starting_level
	DidiG.starting_level = tut.tutorial_level_id()
	new_game()
	var runner: TutorialRunner = TutorialRunner.new()
	# The caption must not cover the shape it is talking about, the dot, or the decoy it points at —
	# and the dot in particular can flash anywhere around the board.
	runner.keep_clear = [
		func(): return $Level.tutorial_model_agent(),
		func(): return $Level.tutorial_periph_agent(),
		func(): return $Level.tutorial_decoy_agent(),
		func(): return $Level.tutorial_correct_agent(),
	]
	runner.run(self, tut.steps($Level, game), game, Callable(self, "_on_tutorial_done"))

func _on_tutorial_done(_completed: bool) -> void:
	_restore_tutorial_globals()
	game.playing = false
	show_main_menu()

# Also called from _exit_tree: leaving the game mid-tutorial frees the scene, and the runner's own
# _exit_tree does not invoke this callback, so the stashed level would stay applied.
func _restore_tutorial_globals() -> void:
	$Level.tutorial_only_correct_taps = false
	$Level.tutorial_hold_round = false
	if _tutorial_saved_level >= 0:
		DidiG.starting_level = _tutorial_saved_level
		_tutorial_saved_level = -1

func _exit_tree() -> void:
	_restore_tutorial_globals()

func _on_game_sig_level_is_done(_didwin: bool) -> void:
	_did_per_level_save = true
	game.save_score(get_game_score(_didwin, false))

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
	MainGlobals.update_bottom_bar(["help", "mute"])
	MainGlobals.add_action_button(null)

func new_game(from_scratch: bool = true) -> void:
	if from_scratch:
		_did_per_level_save = false
	show_level()
	hud.new_game(from_scratch)
	game.reset(from_scratch)
	$Level.new_game(from_scratch)
	hud.update_all()

func _on_level_started_playing() -> void:
	game.playing = true
	hud.restart_time_left_timer()

func _on_game_tick_timeout() -> void:
	game.tick_game_time()
	if game.playing and not game.paused():
		$Level.tick()
	if game.time_since_saved_ongoing_score_sec() >= 60:
		_save_ongoing_score()

func _on_level_sig_level_is_done(_didwin: bool) -> void:
	if game.playing:
		new_game(false)

func _on_main_menu_menu_start_game(_start_new: bool) -> void:
	DidiG.save_settings()
	new_game()
	show_level()

func _on_menu_option_changed(id: int, idx: int) -> void:
	if id == 1:
		DidiG.starting_level = DidiLevelConfig.LEVELS[idx]["id"]
		DidiG.save_settings()

func _on_level_show_main_menu() -> void:
	game.playing = false
	show_main_menu()
	if _did_per_level_save:
		game.clear_ongoing_score()
	else:
		_save_ongoing_score()
		game.convert_ongoing_score_to_permanent()

func close_help_window() -> void:
	game.pause(false)
	$Help.hide()

func _on_help_close_help() -> void:
	close_help_window()

func _on_level_show_help() -> void:
	if $Help.is_visible():
		close_help_window()
	else:
		$Help.show()

func _on_level_pressed_esc() -> void:
	if $Help.is_visible():
		close_help_window()

func _on_hud_help_button_pressed() -> void:
	$Help.show()

func _on_hud_start_game() -> void:
	new_game(true)

func get_game_score(_didwin, _wasaborted) -> Array:
	var last_level: int = $Level.level
	var total: int = game.corrects + game.mistakes
	var pct: int = 100 if total == 0 else int(100.0 * game.corrects / total)
	return [_didwin, _wasaborted, last_level, $Level.mean_time_to_answer_ms(), pct]

func on_game_is_done(_didwin: bool, _wasaborted: bool) -> void:
	game.save_score(get_game_score(_didwin, _wasaborted))

func add_score_line_vals(score_row: Array) -> Array:
	var res: Array = []
	if score_row.size() > POS_SCORE_DIFFICULTY:
		res.append("%d" % score_row[POS_SCORE_DIFFICULTY])
	if score_row.size() > POS_SCORE_MEAN_TIME_MS:
		res.append(str(int(score_row[POS_SCORE_MEAN_TIME_MS])))
	if score_row.size() > POS_SCORE_PCT_CORRECT:
		res.append("%d" % score_row[POS_SCORE_PCT_CORRECT])
	return res

func _save_ongoing_score() -> void:
	game.save_ongoing_score(get_game_score(false, false))

func _on_pressed_new_board() -> void:
	new_game()

func _input(event: InputEvent) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if game.handle_new_board(self, event, _on_pressed_new_board):
		pass
	elif game.handle_main_menu(self, event, _on_level_show_main_menu):
		pass
	elif event.is_action_pressed("help"):
		_on_level_show_help()
	elif event.is_action_pressed("esc"):
		_on_level_pressed_esc()
	elif event.is_action_pressed("lost_focus"):
		_on_changed_focus(false)
	elif event.is_action_pressed("resumed_focus"):
		_on_changed_focus(true)
	else:
		game.handle_event(event, self)

func refresh_menu() -> void:
	main_menu.update_option(1, DidiLevelConfig.id_to_index(DidiG.starting_level))

func _on_changed_focus(_gained_focus: bool) -> void:
	game.in_focus = _gained_focus

extends Node

@onready var hud = $HUD
var game: GenericGameUtil
var main_menu
var _did_per_level_save: bool = false

var POS_SCORE_DIFFICULTY: int = 6
var POS_SCORE_MEAN_TIME_MS: int = 7
var POS_SCORE_PCT_CORRECT: int = 8

func _ready() -> void:
	game = DdoooG.game
	game.initial_score = 100

	randomize()
	RenderingServer.set_default_clear_color(Color.hex(0x3C5D3EFF))
	DdoooG.load_settings()
	main_menu = game.create_main_menu(self)

	main_menu.sig_start_game.connect(_on_main_menu_menu_start_game)
	main_menu.sig_option_changed.connect(_on_menu_option_changed)
	main_menu.add_option_entry(1, "Starting level", DdoooLevelConfig.level_names())
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
	# sig_periph_active is connected via main.tscn scene connection

	var _ins_font_sz = 36 if MainGlobals.is_mobile() else 22
	game.set_instructions("Witness",
		"A shape briefly flashes at the center AND a dot flashes in one of 8 directions.\n" +
		"Remember both!\n" +
		"First pick the matching center shape from the alternatives.\n" +
		"Then tap the direction arrow where you saw the peripheral flash.\n" +
		"Both must be correct to advance.",
		_ins_font_sz)
	if !game.shown_instructions:
		game.show_instructions(self)
		DdoooG.save_settings()
	main_menu.show_continue_and_start_new(false)
	game.scores_callback = Callable(self, "add_score_line_vals")
	game.show_scores_level = true
	game.progress_level_pos = POS_SCORE_DIFFICULTY
	game.progress_time_pos = POS_SCORE_MEAN_TIME_MS
	game.progress_pct_pos = POS_SCORE_PCT_CORRECT
	for lvl in DdoooLevelConfig.LEVELS:
		game.progress_level_names[lvl["id"]] = DdoooLevelConfig.level_header(lvl["id"])
	game.sig_level_is_done.connect(_on_game_sig_level_is_done)

func _on_game_sig_level_is_done(_didwin: bool) -> void:
	_did_per_level_save = true
	game.save_score(get_game_score(_didwin, false))

func show_main_menu():
	main_menu.show_continue_and_start_new(false)
	main_menu.show()
	$Level.hide()
	MainGlobals.update_bottom_bar(["help", "mute", "scores"])
	MainGlobals.add_action_button(null)

func show_level():
	get_viewport().gui_release_focus()
	$Level.show()
	main_menu.hide()
	MainGlobals.update_bottom_bar(["help", "mute"])
	MainGlobals.add_action_button(null)

func new_game(from_scratch = true):
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

func _on_level_new_packet_message(text: String, isdispatch: bool) -> void:
	if isdispatch:
		hud.dispatch(text, true)
	else:
		hud.disp(text, true)

func _on_level_pressed_new_game() -> void:
	new_game()

func _on_level_sig_level_is_done(_didwin: bool) -> void:
	if game.playing:
		new_game(false)

func _on_main_menu_menu_start_game(_start_new: bool) -> void:
	DdoooG.save_settings()
	new_game()
	show_level()

func _on_menu_option_changed(id: int, idx: int) -> void:
	if id == 1:
		DdoooG.starting_level = DdoooLevelConfig.LEVELS[idx]["id"]
		DdoooG.save_settings()

func _on_level_show_main_menu() -> void:
	game.playing = false
	show_main_menu()
	if _did_per_level_save:
		game.clear_ongoing_score()
	else:
		_save_ongoing_score()
		game.convert_ongoing_score_to_permanent()

func close_help_window():
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

func _on_level_sig_periph_active(active: bool) -> void:
	%PeriQLabel.visible = active

func get_game_score(_didwin, _wasaborted):
	var last_level = $Level.level
	if $Level.num_corrects_in_level_so_far == 0:
		last_level = max(1, last_level - 1)
	var total = game.corrects + game.mistakes
	var pct: int = 100 if total == 0 else int(100.0 * game.corrects / total)
	return [_didwin, _wasaborted, last_level, $Level.mean_time_to_answer_ms(), pct]

func on_game_is_done(_didwin: bool, _wasaborted: bool):
	game.save_score(get_game_score(_didwin, _wasaborted))

func add_score_line_vals(score_row):
	var res = []
	if score_row.size() > POS_SCORE_DIFFICULTY:
		res.append("%d" % score_row[POS_SCORE_DIFFICULTY])
	if score_row.size() > POS_SCORE_MEAN_TIME_MS:
		res.append(str(int(score_row[POS_SCORE_MEAN_TIME_MS])))
	if score_row.size() > POS_SCORE_PCT_CORRECT:
		res.append("%d" % score_row[POS_SCORE_PCT_CORRECT])
	return res

func _save_ongoing_score():
	game.save_ongoing_score(get_game_score(false, false))

func _on_pressed_new_board():
	new_game()

func _input(event) -> void:
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

func refresh_menu():
	main_menu.update_option(1, DdoooLevelConfig.id_to_index(DdoooG.starting_level))

func _on_changed_focus(_gained_focus: bool):
	game.in_focus = _gained_focus

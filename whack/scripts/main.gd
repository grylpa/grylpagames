extends Node

@onready var hud = $HUD
var game: GenericGameUtil
var main_menu
var _did_per_level_save: bool = false

func _ready() -> void:
	game = WhackG.game
	game.initial_score = 100
	game.game_over_on_zero_score = true

	randomize()
	RenderingServer.set_default_clear_color(Color.hex(0x3C5D3EFF))  # fallback only; grass.png covers it
	WhackG.load_settings()
	main_menu = game.create_main_menu(self)

	main_menu.sig_start_game.connect(_on_main_menu_menu_start_game)
	main_menu.sig_slider_changed.connect(_on_menu_slider_changed)
	main_menu.add_entry(1, "Level", 1, WhackLevelConfig.LEVELS.size(), false)
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
	game.sig_game_is_done.connect(on_game_is_done)
	$Level.sig_level_is_done.connect(_on_level_sig_level_is_done)
	$Level.started_playing.connect(_on_level_started_playing)

	var _ins_font_sz: int = 36 if MainGlobals.is_mobile() else 22
	game.set_instructions("Whack",
		"A red target will appear on screen.\n" +
		"Tap it as fast as possible!\n" +
		"The closer to the target center, the better.\n" +
		"Avoid the decoy targets!\n" +
		"Targets shrink at higher levels.\n",
		_ins_font_sz)
	if not game.shown_instructions:
		game.show_instructions(self)
		WhackG.save_settings()
	main_menu.show_continue_and_start_new(false)
	game.scores_callback = Callable(self, "add_score_line_vals")
	game.show_scores_level = true
	game.progress_level_pos = POS_SCORE_DIFFICULTY
	game.progress_time_pos = POS_SCORE_MEAN_REACTION_MS
	game.progress_pct_pos = POS_SCORE_MEAN_DIST_PX
	game.progress_pct_label = "Avg Dist"
	game.progress_pct_format = "%d px"
	game.sig_level_is_done.connect(_on_game_sig_level_is_done)

func _on_game_sig_level_is_done(_didwin: bool) -> void:
	_did_per_level_save = true
	game.save_score(get_game_score(_didwin, false))

func show_main_menu() -> void:
	main_menu.show_continue_and_start_new(false)
	main_menu.show()
	$Level.hide()
	MainGlobals.update_bottom_bar(["help","mute","scores"])
	MainGlobals.add_action_button(null)

func show_level() -> void:
	get_viewport().gui_release_focus()
	$Level.show()
	main_menu.hide()
	MainGlobals.update_bottom_bar(["help","mute"])
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
	WhackG.save_settings()
	new_game()
	show_level()

func _on_level_show_main_menu() -> void:
	game.playing = false
	show_main_menu()
	if _did_per_level_save:
		game.clear_ongoing_score()
	else:
		game.save_ongoing_score(get_game_score(false, true))
		game.convert_ongoing_score_to_permanent()

func close_help_window() -> void:
	game.pause(false)
	$Help.hide()

func _on_help_close_help() -> void:
	close_help_window()

func _on_hud_help_button_pressed() -> void:
	$Help.show()

func _on_hud_start_game() -> void:
	new_game(true)

var POS_SCORE_DIFFICULTY: int = 6
var POS_SCORE_MEAN_REACTION_MS: int = 7
var POS_SCORE_MEAN_DIST_PX: int = 8

func get_game_score(_didwin: bool, _wasaborted: bool) -> Array:
	var last_level: int = $Level.level
	if $Level.num_corrects_in_level_so_far == 0:
		last_level = max(1, last_level - 1)
	return [_didwin, _wasaborted, last_level, $Level.mean_reaction_ms(_wasaborted), $Level.mean_distance_px(_wasaborted)]

func on_game_is_done(_didwin: bool, _wasaborted: bool) -> void:
	game.save_score(get_game_score(_didwin, _wasaborted))

func add_score_line_vals(score_row: Array) -> Array:
	var res: Array = []
	if score_row.size() > POS_SCORE_DIFFICULTY:
		var lvl = score_row[POS_SCORE_DIFFICULTY]
		res.append(str(int(lvl)) if not lvl is String else lvl)
	if score_row.size() > POS_SCORE_MEAN_REACTION_MS:
		res.append(str(int(score_row[POS_SCORE_MEAN_REACTION_MS])))
	if score_row.size() > POS_SCORE_MEAN_DIST_PX:
		res.append(str(score_row[POS_SCORE_MEAN_DIST_PX]) + " px")
	return res

func _save_ongoing_score() -> void:
	game.save_ongoing_score(get_game_score(false, false))

func _on_pressed_new_board() -> void:
	new_game()

func refresh_menu() -> void:
	main_menu.update_val(1, WhackG.starting_level)

func _on_menu_slider_changed(id: int, val: float) -> void:
	if id == 1:
		WhackG.starting_level = roundi(val)

func _input(event: InputEvent) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if game.handle_new_board(self, event, _on_pressed_new_board):
		pass
	elif game.handle_main_menu(self, event, _on_level_show_main_menu):
		pass
	elif event.is_action_pressed("help"):
		$Help.show()
	elif event.is_action_pressed("esc"):
		if $Help.is_visible():
			close_help_window()
	elif event.is_action_pressed("lost_focus"):
		game.in_focus = false
	elif event.is_action_pressed("resumed_focus"):
		game.in_focus = true
	else:
		game.handle_event(event, self)

extends Node

# Positions in the stored score row:
# [0:datetime, 1:score, 2:corrects, 3:mistakes, 4:didwin, 5:wasaborted, 6:level, 7:avg_time_ms, 8:pct_correct]
const POS_LEVEL: int = 6
const POS_TIME_MS: int = 7
const POS_PCT: int = 8

var game: GenericGameUtil
var _main_menu: Node = null
var _did_save: bool = false

func _ready() -> void:
	game = PolkadotsG.game
	randomize()
	RenderingServer.set_default_clear_color(Color.hex(0x3C5D3EFF))
	PolkadotsG.load_settings()
	PolkadotsG.init_globals()

	_main_menu = game.create_main_menu(self)
	_main_menu.sig_start_game.connect(_on_main_menu_start_game)
	_main_menu.sig_option_changed.connect(_on_menu_option_changed)
	var level_names: Array = []
	for cfg in PolkadotsLevelConfig.LEVELS:
		level_names.append("Level " + str(cfg["level"]))
	_main_menu.add_option_entry(1, "Level", level_names)
	refresh_menu()
	show_main_menu()

	$HUD.set_game(game)
	$HUD.show()
	$HUD.show_corrects_mistakes()

	$Level.sig_level_is_done.connect(_on_level_sig_level_is_done)
	$Level.update_score.connect(_on_level_update_score)

	game.add_sound(self, "correct", preload("res://art/sounds/FreeSFX/GameSFX/PickUp/Retro PickUp Coin 07.ogg"))
	game.add_sound(self, "wrong", preload("res://art/sounds/swoosh.mp3"))
	game.set_instructions("Polka Dots",
		"Look at the dot pattern\n\n" +
		"The dots outline a letter or number\n\n" +
		"Tap the correct character from the options on the right")
	$Help.set_texts({"N": "New game"})

	game.game_over_on_time_out = false
	game.scores_callback = Callable(self, "_score_row_extra")
	game.progress_level_pos = POS_LEVEL
	game.progress_time_pos = POS_TIME_MS
	game.progress_pct_pos = POS_PCT
	game.progress_level_names = {}
	for cfg in PolkadotsLevelConfig.LEVELS:
		game.progress_level_names[cfg["level"]] = str(cfg["level"])
	game.progress_pct_label = "% Correct"
	game.progress_pct_format = "%d"

func show_main_menu() -> void:
	_main_menu.show()
	$Level.hide()
	MainGlobals.update_bottom_bar(["help", "mute", "scores"])
	MainGlobals.add_action_button(null)

func show_level() -> void:
	get_viewport().gui_release_focus()
	$Level.show()
	_main_menu.hide()
	MainGlobals.update_bottom_bar(["help", "mute"])
	MainGlobals.add_action_button(null)

func new_game(from_scratch: bool = true, keep_stats: bool = false) -> void:
	if from_scratch:
		_did_save = false
	else:
		if game.need_to_increase_level:
			$Level.advance_level()
			game.need_to_increase_level = false
	show_level()
	$HUD.new_game(from_scratch)
	game.reset(from_scratch)
	$Level.new_game(from_scratch, keep_stats)
	game.level_label_changed("Level %d" % $Level.get_level())

func refresh_menu() -> void:
	_main_menu.update_option(1, PolkadotsG.starting_level - 1)

func _on_main_menu_start_game(_start_new: bool) -> void:
	PolkadotsG.save_settings()
	new_game(true)

func _on_menu_option_changed(id: int, idx: int) -> void:
	if id == 1:
		PolkadotsG.starting_level = idx + 1
		PolkadotsG.save_settings()

func _on_level_show_main_menu() -> void:
	game.playing = false
	show_main_menu()
	if _did_save:
		game.clear_ongoing_score()

func _on_level_sig_level_is_done(level_id: int, avg_time_ms: int, pct_correct: int) -> void:
	_did_save = true
	game.score_was_changed = true
	game.save_score([false, false, level_id, avg_time_ms, pct_correct])
	MainGlobals.global_level_is_done(true)
	if level_id >= PolkadotsLevelConfig.LEVELS.size():
		# Last level: loop indefinitely, keeping cumulative stats so each save
		# reflects a running average over all rounds played at this level
		new_game(false, true)
		return
	game.need_to_increase_level = true
	if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
		MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
	var text_add: String = "\n\nAvg response: %d ms\n%d%% correct" % [avg_time_ms, pct_correct]
	game.show_level_done_popup(self, "", "", level_id, text_add)

func _on_level_done_popup_closed() -> void:
	new_game(false)

func _on_level_update_score(delta: int) -> void:
	game.add_score_and_time(delta, 0)
	game.add_correct_or_mistake(1 if delta > 0 else 0, 1 if delta <= 0 else 0)
	$HUD.update_all()

func _score_row_extra(score_row: Array) -> Array:
	var res: Array = []
	if score_row.size() > POS_LEVEL:
		var lvl = score_row[POS_LEVEL]
		res.append(str(int(lvl)) if not lvl is String else lvl)
	if score_row.size() > POS_TIME_MS:
		res.append(str(int(score_row[POS_TIME_MS])))
	return res

func close_help_window() -> void:
	game.pause(false)
	$Level.pause_round(false)
	$Help.hide()

func _on_help_close_help() -> void:
	close_help_window()

func _on_hud_start_game() -> void:
	new_game(true)

func _input(event: InputEvent) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if game.handle_new_board(self, event, Callable(self, "new_game")):
		pass
	elif game.handle_main_menu(self, event, Callable(self, "_on_level_show_main_menu")):
		pass
	elif game.test_open_scores_screen(event, self):
		pass
	elif event.is_action_pressed("help"):
		$Level.pause_round(true)
		$Help.show()
	elif event.is_action_pressed("esc"):
		if $Help.is_visible():
			close_help_window()

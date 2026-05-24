extends Node

@onready var hud = $HUD

var game:GenericGameUtil

var main_menu
var _did_per_level_save: bool = false

func _ready() -> void:
	game = DelemfpG.game
	randomize()
	RenderingServer.set_default_clear_color(Color.hex(0x3C5D3EFF))
	DelemfpG.speed = game.tile_size * 1000.0 / game.major_tick_time_ms
	DelemfpG.body_delay_sec = 32.0 / DelemfpG.speed
	DelemfpG.load_settings()
	main_menu = game.create_main_menu(self)	
	main_menu.sig_slider_changed.connect(on_menu_slider_changed)
	main_menu.sig_start_game.connect(_on_main_menu_menu_start_game)
	main_menu.add_entry(1, "Level", 1, DelemfpLevelConfig.LEVELS.size(), false)
	refresh_menu()
	show_main_menu()
	$Help.set_texts({
		"F":"Faster",
		"L":"sLower",
		"R":"Reminder",
		"Z":"Unzoom",
		"N":"New game",
	})
	$Help.close_help.connect(_on_help_close_help)
	hud.set_game(game)
	hud.show()
	$Level.update_score_time.connect(on_update_score_time)
	game.sig_game_is_done.connect(on_game_is_done)

	game.set_instructions("DelemFP", 
		"Deliver all packets in the order you are told\n\n" + 
		"Use arrow keys or drag on your mobile touch screen to move\n\n" +
		"You cannot move while zoomed out")
	if !game.shown_instructions:
		game.show_instructions(self)
		DelemfpG.save_settings()
	game.show_scores_level = true
	game.scores_callback = Callable(self, "add_score_line_vals")
	game.progress_level_pos = 6
	game.sig_level_is_done.connect(_on_game_sig_level_is_done)

func show_main_menu():
	main_menu.show()
	$Level.hide()
	MainGlobals.update_bottom_bar(["help","mute","scores"])

func show_level():
	get_viewport().gui_release_focus()
	$Level.show()
	main_menu.hide()
	MainGlobals.update_bottom_bar(["help","mute","fast","slow","clue","zoom"])

func new_game(from_scratch=true):
	if from_scratch:
		_did_per_level_save = false
	show_level()
	hud.new_game(from_scratch)
	game.reset(from_scratch)
	$Level.new_game(from_scratch)
	if from_scratch:
		DelemfpG.save_settings()
		# Log.info("started game %s %d times" % [game.name, game.times_run])		

func _on_level_started_playing() -> void:
	game.playing = true
	hud.restart_time_left_timer()

func _on_level_new_packet_message(text: String, isdispatch: bool) -> void:
	if isdispatch:
		hud.dispatch(text, true)
	else:
		hud.disp(text, true)

func _on_level_show_reminder(text: Variant) -> void:
	if hud.reminder(text, true):
		hud.add_score_and_time(-2, -10)

func _on_level_pressed_new_game() -> void:
	new_game()

func _on_level_sig_level_is_done(_didwin: bool) -> void:
	if game.playing:
		new_game(false)

func _on_main_menu_menu_start_game(_start_new: bool) -> void:
	new_game()

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
		_save_ongoing_score()
		$Help.show()

func _on_level_pressed_esc() -> void:
	if $Help.is_visible():
		close_help_window()

func _on_hud_help_button_pressed() -> void:
	_save_ongoing_score()
	$Help.show()

func _on_hud_start_game() -> void:
	new_game(true)

func on_update_score_time(score_add, time_add):
	hud.add_score_and_time(score_add, time_add)

func _on_game_sig_level_is_done(_didwin: bool) -> void:
	_did_per_level_save = true
	game.save_score(get_game_score(_didwin, false))

func get_game_score(_didwin, _wasaborted):
	return [_didwin, _wasaborted, $Level.level, $Level.mean_time_to_answer_ms()]

func on_game_is_done(_didwin:bool, _wasaborted:bool):
	game.save_score(get_game_score(_didwin, _wasaborted))

func _save_ongoing_score():
	game.save_ongoing_score(get_game_score(false, false))

func _on_game_tick_timeout() -> void:
	game.tick_game_time()
	if game.playing and not game.paused():
		$Level.tick()
	if game.time_since_saved_ongoing_score_sec() >= 60:
		_save_ongoing_score()

func _input(event) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if game.handle_new_board(self, event, new_game):
		pass
	elif game.handle_main_menu(self, event, _on_level_show_main_menu):
		pass
	elif event.is_action_pressed("help"):
		_on_level_show_help()
	elif event.is_action_pressed("esc"):
		_on_level_pressed_esc()
	else:
		game.handle_event(event,self)

func refresh_menu():
	main_menu.update_val(1, DelemfpG.starting_level)

func on_menu_slider_changed(id, val):
	if id == 1:
		DelemfpG.starting_level = roundi(val)
func add_score_line_vals(score_row: Array) -> Array:
	if score_row.size() > 6:
		var val = score_row[6]
		return [str(int(val)) if not val is String else val]
	return []

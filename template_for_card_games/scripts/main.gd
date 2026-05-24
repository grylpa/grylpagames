extends Node

@onready var hud = $HUD
var game:GenericGameUtil
var main_menu

func _ready() -> void:
	game = FriendsG.game
	game.initial_score = 100
	game.forced_board_size = Vector2i(11,11)	

	randomize()
	RenderingServer.set_default_clear_color(Color.hex(0x3C5D3EFF))
	FriendsG.load_settings()
	FriendsG.load_people()
	main_menu = game.create_main_menu(self)	
	main_menu.sig_start_game.connect(_on_main_menu_menu_start_game)
	main_menu.hide_frame()
	refresh_menu()
	show_main_menu()
	$Help.set_texts({
		"N": "New game",
		# "P": "Pause",
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

	var _ins_font_sz = 36 if MainGlobals.is_mobile() else 22
	game.set_instructions("Friends", 
		"You will briefly see an image.\n" + 
		"After some time, you will see a few images.\n" + 
		"Out of these, you need to select the matching image \n" + 
		"as quickly as possible\n", 
		_ins_font_sz)
	if !game.shown_instructions:
		game.show_instructions(self)
		FriendsG.save_settings()
	main_menu.show_continue_and_start_new(false)
	game.scores_callback = Callable(self, "add_score_line_vals")
	game.show_scores_level = true
	game.sig_level_is_done.connect(_on_game_sig_level_is_done)
	
func _on_game_sig_level_is_done(_didwin: bool) -> void:
	game.save_ongoing_score(get_game_score(_didwin, false))

func show_main_menu():
	main_menu.show_continue_and_start_new(false)
	main_menu.show()
	$Level.hide()
	MainGlobals.update_bottom_bar(["help","mute","scores"])
	MainGlobals.add_action_button(null)

func show_level():
	$Level.show()
	main_menu.hide()
	MainGlobals.update_bottom_bar(["help","mute"])
	MainGlobals.add_action_button(null)
		
func new_game(from_scratch=true):
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
	FriendsG.save_settings()
	new_game()
	show_level()

func _on_level_show_main_menu() -> void:
	game.playing = false
	show_main_menu()
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

var POS_SCORE_DIFFICULTY := 6
var POS_SCORE_MEAN_TIME_MS := 7
func get_game_score(_didwin, _wasaborted):
	var last_level = $Level.difficulty
	if $Level.num_corrects_in_level_so_far == 0:
		last_level = max(1, last_level - 1)
	return [_didwin, _wasaborted, last_level, $Level.mean_time_to_answer_ms()]

func on_game_is_done(_didwin:bool, _wasaborted:bool):
	game.save_score(get_game_score(_didwin, _wasaborted))

func add_score_line_vals(score_row):
	var res = []
	if score_row.size() > POS_SCORE_DIFFICULTY:
		res.append(str(score_row[POS_SCORE_DIFFICULTY]))
	if score_row.size() > POS_SCORE_MEAN_TIME_MS:
		res.append(str(int(score_row[POS_SCORE_MEAN_TIME_MS])))
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
		game.handle_event(event,self)

func refresh_menu():
	main_menu.update_val(1, FriendsG.starting_difficulty)

func _on_changed_focus(_gained_focus: bool):
	game.in_focus = _gained_focus

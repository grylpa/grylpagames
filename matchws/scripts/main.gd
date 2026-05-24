extends Node2D

var score = 0

@onready var main_menu = $MainMenu

func _ready() -> void:
	randomize()
	RenderingServer.set_default_clear_color(MatchwsG.bkcolor)
	MatchwsG.load_settings()
	# MatchwsG.words = Words.new()
	Log.dbg("requesting data for words")
	if !MatchwsG.words.load_all():
		MatchwsG.words.request_global_data()
	MatchwsG.words.words_ready.connect(_on_words_ready)
	MatchwsG.words.collections_ready.connect(_on_collections_ready)
	if MatchwsG.words.all_words.size() > 0:
		MatchwsG.words.create_words_from_collection()
		_on_words_ready(true)
	$Level.pressed_pause.connect(on_pressed_pause)
	$Level.sig_can_start_clicking.connect(_on_level_sig_can_start_clicking)
	$Level.sig_add_score.connect(_on_level_sig_add_score)
	MatchwsG.words.stats_ready.connect(_on_stats_ready)
	$MainMenu.refresh()
	main_menu.sig_slider_changed.connect(on_menu_slider_changed)
	main_menu.add_entry(1, "Difficulty", 1, 4, false)
	main_menu.add_entry(2, "Moving", 0, 1, true)
	main_menu.add_entry(3, "Fast Mode", 0, 1, true)
	refresh_menu()
	show_main_menu()
	# $FullScreenMessage.set_opaque_color(MatchwsG.bkcolor)
	$FullScreenMessage.set_opaque_modulation(Color(0.9,0.9,0.9))
	# $FullScreenMessage.use_small_shadow_message(true)
	$FullScreenMessage.set_transparent_color(Color(0,0,0,0))
	$Help.set_texts({
		"N": "New game",
		"P": "Pause",
	})
	$Help.close_help.connect(_on_help_close_help)
	# $Help.help_key.connect(_on_help_button)
	$FullScreenMessage.message_pressed.connect(_on_full_screen_message_pressed)
	$MainMenu.sig_show_add_new_words.connect(_on_show_add_new_words)
	
	
func show_main_menu():
	$MainMenu.show()
	$Level.hide()
	MainGlobals.update_bottom_bar("ht")

func show_level():
	get_viewport().gui_release_focus()
	$Level.show()
	$MainMenu.hide()
	MainGlobals.update_bottom_bar("htp")

func new_game():
	show_level()
	# $HUD.new_game()	
	MatchwsG.reset()
	# $FullScreenMessage.hide()
	$Level.new_game()

# func _on_hud_new_game(_was_success: bool) -> void:
# 	new_game(false)#!_was_success)

# func _on_level_game_over(didwin: bool) -> void:
# 	MatchwsG.game.playing = false;
# 	$HUD.game_over(didwin)

func _on_level_pressed_new_game() -> void:
	close_help_window()
	new_game()

func _on_level_sig_level_is_done(_didwin: bool) -> void:
	MatchwsG.game.playing = false;
	# if didwin:
	# 	score += score_if_sucessful
	# 	$HUD.update_score(score)
	new_game()
	# $HUD.game_over(didwin)

func _on_main_menu_menu_start_game() -> void:
	MatchwsG.save_settings()
	$Level.difficulty = MatchwsG.starting_difficulty
	new_game()

func _on_level_show_main_menu() -> void:
	# print("show main menu")
	$Help.hide()
	$StatisticsScene.hide()
	var prepause = MatchwsG.game.paused()
	MatchwsG.game.pause(false)
	$FullScreenMessage.hide()
	if prepause != MatchwsG.game.paused():
		updated_pause_state()
	MatchwsG.game.playing = false
	show_main_menu()

func close_help_window():
	var prepause = MatchwsG.game.paused()
	MatchwsG.game.pause(false)
	$Help.hide()
	if prepause != MatchwsG.game.paused():
		updated_pause_state()

func _on_help_close_help() -> void:
	close_help_window()

func _on_level_show_help() -> void:
	if $Help.is_visible():
		close_help_window()
	else:
		var prepause = MatchwsG.game.paused()
		MatchwsG.game.pause(true)
		$Help.show()
		if prepause != MatchwsG.game.paused():
			$Level.pause_state_changed()
		# updated_pause_state()

func _on_level_pressed_esc() -> void:
	if $Help.is_visible():
		close_help_window()

func _on_hud_help_button_pressed() -> void:
	var prepause = MatchwsG.game.paused()
	MatchwsG.game.pause(true)
	$Help.show()
	if prepause != MatchwsG.game.paused():
		updated_pause_state()

func _on_level_sig_can_start_clicking() -> void:
	MatchwsG.game.playing = true

func _on_level_sig_message(text: String, autohide: bool) -> void:
	if text == null or text.is_empty():
		$HUD.hide_message()
	else:
		$HUD.disp(text, autohide)

# func _on_level_update_score(_score: int) -> void:
# 	score = max(0, score + _score)
# 	$HUD.update_score(score)

func _on_level_update_time(time: float) -> void:
	# $HUD.update_time(str(roundi(time)))
	$HUD.update_time(str(ceili(time)))

func _on_words_ready(actually_got:bool):
	if actually_got:
		MatchwsG.words.save_all()
		$MainMenu.do_on_got_words()
		$MainMenu.refresh()
	else:
		$MainMenu.do_failed_getting_words()
		$MatchwsG.words.get_words_per_langs()
	Log.dbg("Got words ready signal. actually got:", actually_got)

func save_collections():
	MatchwsG.words.save_collections()

func save_words():
	if MatchwsG.words.has_got_words():
		MatchwsG.words.save_words()

func _on_collections_ready():
	$MainMenu.refresh()
	Log.dbg("Got collections ready signal")

func _on_requests_check_timer_timeout() -> void:
	BE.check_requests()

func on_pressed_pause() -> void:
	if $Help.visible:
		if MatchwsG.game.playing:
			var prepause = MatchwsG.game.paused()
			MatchwsG.game.pause(true)
			$Help.hide()
			if prepause != MatchwsG.game.paused():
				updated_pause_state()
	elif MatchwsG.game.playing or MatchwsG.game.paused():
		MatchwsG.game.pause(!MatchwsG.game.paused())
		updated_pause_state()

func updated_pause_state():
	# if !MatchwsG.game.playing and !MatchwsG.game.paused():
	# 	return
	$FullScreenMessage.disp("Paused    ⯈")
	$FullScreenMessage.use_opaque_bk()
	$FullScreenMessage.visible = MatchwsG.game.paused()
	# $FullScreenMessage.show_msg(!$Help.visible)
	$Level.pause_state_changed()

func _on_level_sig_add_score(_score: int):
	score += _score
	$HUD.update_score(score)

func _on_stats_ready(actually_got:bool):
	MatchwsG.save_settings()
	Log.dbg("Got stats ready signal. actually got:", actually_got)
	$StatisticsScene.show()
	$StatisticsScene.create_graph()

func _on_show_add_new_words():
	$EnterWords.start()
	
# func _on_help_button(key):
# 	match key:
# 		"N":
# 			_on_level_pressed_new_game()			
# 		"M":
# 			_on_level_show_main_menu()
# 		"H":
# 			_on_level_show_help()
# 		"P":
# 			on_pressed_pause()

func _on_full_screen_message_pressed():
	if MatchwsG.game.paused() and $FullScreenMessage.visible:
		on_pressed_pause()

func _input(event):
	if !MatchwsG.game.playing:
		return
	if event.is_action_pressed("lost_focus"):
		if !MatchwsG.game.paused():
			on_pressed_pause()
			# print("lost_focus")
	# elif event.is_action_pressed("resumed_focus"):
	# 	if MatchwsG.game.paused():
	# 		on_pressed_pause()
	# 		# print("resumed_focus")

func refresh_menu():
	main_menu.update_val(1, MatchwsG.starting_difficulty)
	main_menu.update_val(2, 1 if MatchwsG.moving else 0)
	main_menu.update_val(3, 1 if MatchwsG.speed_mode else 0)

func on_menu_slider_changed(id, val):
	match id:
		1: MatchwsG.starting_difficulty = roundi(val)
		2: MatchwsG.moving = val > 0.5
		3: MatchwsG.speed_mode = val > 0.5
		
	MatchwsG.save_settings()
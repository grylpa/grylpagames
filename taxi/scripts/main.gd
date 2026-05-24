extends Node

@onready var hud = $HUD
var game:GenericGameUtil
var main_menu

# var taxi_tex: Texture2D = preload("res://taxi//art//taxi_head1.png")
var taxi_tex: Texture2D = preload("res://art/taxi-clean-1.png")
var buy_taxi_btn = null
var _did_per_level_save: bool = false

func _ready() -> void:
	game = TaxiG.game
	game.initial_score = 5000
	game.forced_board_size = Vector2i(31,31)	
	# game.init_sizes()
	game.score_for_collision = [0, 0]
	game.score_for_deliver_one = [10, 10]
	randomize()
	RenderingServer.set_default_clear_color(Color.hex(0x3C5D3EFF))
	TaxiG.load_settings()
	main_menu = game.create_main_menu(self)	
	main_menu.sig_slider_changed.connect(on_menu_slider_changed)
	main_menu.sig_start_game.connect(_on_main_menu_menu_start_game)
	main_menu.add_entry(1, "Level", 1, TaxiLevelConfig.LEVELS.size(), false)
	refresh_menu()
	show_main_menu()
	$Help.set_texts({
		"F": "Faster",
		"L": "sLower",
		"N": "New game",
	})
	$Help.close_help.connect(_on_help_close_help)
	hud.set_lives_icon(taxi_tex, Vector2(0.2,0.2))
	hud.set_game(game)
	hud.show_lives()
	hud.show()
	hud.update_all()
	game.game_over_on_zero_score = true
	game.sig_game_is_done.connect(on_game_is_done)
	game.sig_no_more_packets.connect(on_game_no_more_packets)	
	game.sig_save_game.connect(_on_save_game)
	$Level.sig_level_is_done.connect(_on_level_sig_level_is_done)

	var _ins_font_sz = 36 if MainGlobals.is_mobile() else 22
	game.set_instructions("Taxi", 
		"You are the owner of a taxi station\n" + 
		"1. To move a taxi, select it and then its destination\n" + 
		"2. When a customer appears, send a taxi to pick them up\n" + 
		"3. When one taxi is blocking another, you need to move the blocking taxi\n" + 
		"4. Fuel can run out. You need to keep an eye and send taxis to refuel before it does\n" + 
		"5. A taxi that ran out of gas is stranded forever\n" +
		"6. Fuel is expensive and you will pay for the distance that each taxi moves. Idle motor time also costs\n" + 
		"7. Customers pay upon reaching their destination\n" +
		"8. A customer will eventually give up if waiting too long\n", 
		_ins_font_sz)
	if !game.shown_instructions:
		game.show_instructions(self)
		TaxiG.save_settings()
	var _saved_level_state = load_game_state()
	$Level.set_state(_saved_level_state)
	main_menu.show_continue_and_start_new(_saved_level_state != null and _saved_level_state.size() > 0)
	
func show_main_menu():
	var _saved_level_state = load_game_state()
	main_menu.show_continue_and_start_new(_saved_level_state != null and _saved_level_state.size() > 0)
	main_menu.show()
	$Level.hide()
	MainGlobals.update_bottom_bar(["help","mute","scores"])
	buy_taxi_btn = null
	MainGlobals.add_action_button(null)

func show_level():
	get_viewport().gui_release_focus()
	$Level.show()
	main_menu.hide()
	MainGlobals.update_bottom_bar(["help","mute","fast", "slow"])
	MainGlobals.add_action_button(null)
	var btnsz = 100 if MainGlobals.is_mobile() else 50
	buy_taxi_btn = MainGlobals.add_action_button("res://taxi/art/buy1_w_taxi.png", Vector2(btnsz,btnsz))
	buy_taxi_btn.pressed.connect(_on_buy_taxi)
	check_buy_taxi_button()
		
func new_game(from_scratch=true):
	if from_scratch:
		_did_per_level_save = false
	show_level()
	hud.new_game(from_scratch)
	game.reset(from_scratch)
	$Level.new_game(from_scratch)
	hud.update_all()
	check_buy_taxi_button()

func _on_level_started_playing() -> void:
	game.playing = true
	hud.restart_time_left_timer()

var _last_time_saved_state := MainGlobals.timems()
func _on_game_tick_timeout() -> void:
	game.tick_game_time()
	if game.playing and not game.paused():
		$Level.tick()
		check_buy_taxi_button()
		var now = MainGlobals.timems()
		if now - _last_time_saved_state > TaxiG.dtime_to_save_state_ms:
			save_game_state()			
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
		save_game_state()
		new_game(false)

func _on_main_menu_menu_start_game(_start_new: bool) -> void:
	if _start_new:
		clear_saved()
	TaxiG.save_settings()
	new_game()
	show_level()

func _on_level_show_main_menu() -> void:
	save_game_state()
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
	save_game_state()
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
	clear_saved()
	new_game(true)

func get_game_score(_didwin, _wasaborted):
	return [_didwin, _wasaborted, $Level.level]

func on_game_is_done(_didwin:bool, _wasaborted:bool):
	_did_per_level_save = true
	$Level.can_use_state = false
	clear_saved()
	game.save_score(get_game_score(_didwin, _wasaborted))

func _save_ongoing_score():
	game.save_ongoing_score(get_game_score(false, false))

func on_game_no_more_packets():
	hud.update_all()

func _on_pressed_new_board():
	clear_saved()
	new_game()

func _input(event) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if game.handle_new_board(self, event, _on_pressed_new_board):
		pass
	elif event.is_action_pressed("help"):
		_on_level_show_help()
	elif event.is_action_pressed("esc"):
		_on_level_pressed_esc()
	elif event.is_action_pressed("lost_focus"):
		_on_changed_focus(false)
	elif event.is_action_pressed("resumed_focus"):
		_on_changed_focus(true)
	elif game.handle_main_menu(self, event, _on_level_show_main_menu):
		pass
	else:
		game.handle_event(event,self)

func refresh_menu():
	main_menu.update_val(1, TaxiG.starting_level)

func on_menu_slider_changed(id: int, val: float) -> void:
	if id == 1:
		TaxiG.starting_level = roundi(val)
		TaxiG.save_settings()

func _on_buy_taxi():
	if buy_taxi_btn and !buy_taxi_btn.disabled:
		$Level.buy_taxi()
	
func check_buy_taxi_button():
	if buy_taxi_btn != null:
		if game.score > TaxiG.prices_for_taxi:
			# buy_taxi_btn.modulate = Color(1,1,1,1)
			buy_taxi_btn.disabled = false
			buy_taxi_btn.get_node("DisabledTexture").hide()
		else:
			# buy_taxi_btn.modulate = Color(0.5,0.2,0.2,1)
			buy_taxi_btn.disabled = true
			buy_taxi_btn.get_node("DisabledTexture").show()

var _last_saved_state := {"stub": "initial_diffferent_value"}

func save_game_state():
	if !game.playing or game.paused():
		return
	var level_state = $Level.get_state()
	if level_state == _last_saved_state:
		return
	_last_saved_state = level_state.duplicate(true)
	SaveManager.save_game(game.saved_game_name(), level_state)
	_last_time_saved_state = MainGlobals.timems()
	return level_state

func load_game_state():
	var level_state = SaveManager.load_game(game.saved_game_name())
	return level_state

func clear_saved():
	$Level.set_state({})
	save_game_state()

func _on_save_game():
	save_game_state()

func _on_changed_focus(_gained_focus: bool):
	if !_gained_focus:
		save_game_state()
	game.in_focus = _gained_focus

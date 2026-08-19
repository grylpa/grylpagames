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

	# Launched from the chooser's "How to play"? Then teach instead of showing the menu.
	if MainGlobals.take_pending_tutorial("taxi"):
		call_deferred("start_tutorial")

var _tutorial_saved_level: int = -1
var _tutorial_saved_idle_sec: float = -1.0
var _tutorial_saved_tiles: int = -1
var _tutorial_saved_giveup_ms: int = -1

# The real game with the real rules, recorded by nobody: TutorialRunner puts the game into
# tutorial_mode, which suppresses every write in generic_game_util.gd — and save_game_state()
# below refuses to run, which is the part GenericGameUtil cannot cover.
func start_tutorial() -> void:
	var tut: Script = load("res://taxi/scripts/tutorial.gd")
	# BEFORE new_game(): new_game() -> game.reset(true) -> convert_ongoing_score_to_permanent(),
	# which would commit and upload the player's unfinished real session.
	game.begin_tutorial()
	# starting_level lives on TaxiG, not the game util, so the tutorial snapshot does not cover it.
	_tutorial_saved_level = TaxiG.starting_level
	TaxiG.starting_level = tut.tutorial_level_id()
	# A parked taxi with its motor running empties in 60 seconds. That is the real game and the
	# tutorial says so out loud — but a player reading the captions at their own pace would have
	# the whole fleet strand itself mid-lesson, teaching the rule by taking their taxis away. Idle
	# burn is effectively switched off for the duration; the fuel step stages a low tank explicitly
	# (level.tutorial_drain_taxi) so there is still something real to point at.
	# Fuel does not move at all during a tutorial: the tank is set low once, on purpose, and then
	# stays there however long the player takes. Idle burn alone was not enough — driving to the
	# pump burns by the tile, so a slow player could still strand the very taxi the lesson is
	# about, and a stranded taxi cannot even be tapped.
	_tutorial_saved_idle_sec = TaxiG.time_to_empty_fuel_tank_on_idle_sec
	TaxiG.time_to_empty_fuel_tank_on_idle_sec = 100000.0
	_tutorial_saved_tiles = TaxiG.num_tiles_for_empty_fuel_tank
	TaxiG.num_tiles_for_empty_fuel_tank = 100000000
	# Same reasoning for the fare itself: a customer gives up after 30 seconds, so the one the
	# coach just told the player to collect could walk off while they are still reading. The last
	# step tells them this happens; it must not happen TO them here.
	_tutorial_saved_giveup_ms = TaxiG.time_for_customer_to_give_up_ms
	TaxiG.time_for_customer_to_give_up_ms = 100000000
	# Teach on a fresh city, not on top of whatever game they had going. set_state() is used
	# directly rather than clear_saved(), which would write the empty state to disk.
	$Level.set_state({})
	new_game()
	var runner: TutorialRunner = TutorialRunner.new()
	# "Tap the taxi, then the pump" needs BOTH visible: the spotlight can only mark one, so the
	# other goes in keep_clear. Honored on player-action steps only, which is exactly where the
	# player has to reach them.
	runner.keep_clear = [
		func(): return $Level.tutorial_any_taxi(),
		func(): return $Level.tutorial_gas_station(),
		func(): return $Level.tutorial_active_customer(),
		func(): return $Level.tutorial_active_sender(),
		func(): return $Level.tutorial_active_receiver(),
	]
	runner.run(self, tut.steps($Level, game, self), game, Callable(self, "_on_tutorial_done"))

func _on_tutorial_done(_completed: bool) -> void:
	_restore_tutorial_globals()
	game.playing = false
	show_main_menu()

# Also called from _exit_tree: leaving the game mid-tutorial frees the scene, and the runner's own
# _exit_tree does not invoke this callback — so without it the tutorial's starting level, and the
# emptied level state, would stay applied to the player's real game.
func _restore_tutorial_globals() -> void:
	$Level.tutorial_restore()
	if _tutorial_saved_giveup_ms > 0:
		TaxiG.time_for_customer_to_give_up_ms = _tutorial_saved_giveup_ms
		_tutorial_saved_giveup_ms = -1
	if _tutorial_saved_idle_sec > 0.0:
		TaxiG.time_to_empty_fuel_tank_on_idle_sec = _tutorial_saved_idle_sec
		_tutorial_saved_idle_sec = -1.0
	if _tutorial_saved_tiles > 0:
		TaxiG.num_tiles_for_empty_fuel_tank = _tutorial_saved_tiles
		_tutorial_saved_tiles = -1
	if _tutorial_saved_level >= 0:
		TaxiG.starting_level = _tutorial_saved_level
		_tutorial_saved_level = -1
		# Put their own game back in front of the level, so Continue still resumes it.
		var saved = load_game_state()
		if saved != null:
			$Level.set_state(saved)

func _exit_tree() -> void:
	_restore_tutorial_globals()
	
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
	# Taxi is the only game that persists a whole mid-game board, through SaveManager rather than
	# GenericGameUtil — so none of the tutorial write-guards in generic_game_util.gd cover it. The
	# periodic tick save alone would overwrite the player's real game with the tutorial's city
	# within 30 seconds of starting one.
	if game.tutorial_mode:
		return
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

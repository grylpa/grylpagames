extends Node

@onready var hud = $HUD
var game:GenericGameUtil
var main_menu
var _did_per_level_save: bool = false

var lives_tex: Texture2D = preload("res://art/tube-1-4x.png")

func _ready() -> void:
	game = PneumoG.game
	randomize()
	RenderingServer.set_default_clear_color(Color.hex(0x3C5D3EFF))
	PneumoG.load_settings()
	main_menu = game.create_main_menu(self)	
	main_menu.sig_slider_changed.connect(on_menu_slider_changed)
	main_menu.sig_start_game.connect(_on_main_menu_menu_start_game)
	main_menu.add_entry(1, "Level", 1, PneumoLevelConfig.LEVELS.size(), false)
	refresh_menu()
	show_main_menu()
	$Help.set_texts({
		"F": "Faster",
		"L": "sLower",
		"N": "New game",
	})
	$Help.close_help.connect(_on_help_close_help)
	hud.set_packets_icon(lives_tex, 0.2)
	hud.set_game(game)
	hud.show_packets()
	hud.show()
	game.sig_game_is_done.connect(on_game_is_done)
	game.sig_no_more_packets.connect(on_game_no_more_packets)	
	$Level.sig_level_is_done.connect(_on_level_sig_level_is_done)

	game.set_instructions("Pneumo", 
		"Ensure each pneumatic tube reaches its designated receiver\n\n" + 
		"Don't allow the tubes to collide with each other")
	if !game.shown_instructions:
		game.show_instructions(self)
		PneumoG.save_settings()	
	_maybe_start_tutorial()

# Teach instead of showing the menu when the player asked for the tutorial from the
# chooser's "How to play", OR when this is their first ever run of this game.
func _maybe_start_tutorial() -> void:
	if MainGlobals.take_pending_tutorial("pneumo") \
			or MainGlobals.take_auto_tutorial("pneumo", game.shown_instructions):
		call_deferred("start_tutorial")

var _tutorial_saved_level: int = -1

# The real game with the real rules, recorded by nobody: TutorialRunner puts the game into
# tutorial_mode, which suppresses every write in generic_game_util.gd until the tutorial ends.
func start_tutorial() -> void:
	var tut: Script = load("res://pneumo/scripts/tutorial.gd")
	# BEFORE new_game(): new_game() -> game.reset(true) -> convert_ongoing_score_to_permanent(),
	# which would commit and upload the player's unfinished real session.
	game.begin_tutorial()
	_tutorial_saved_level = PneumoG.starting_level
	PneumoG.starting_level = tut.tutorial_level_id()
	new_game()
	var runner: TutorialRunner = TutorialRunner.new()
	# The caption must stay off the capsule, its receiver and the door being pointed at.
	runner.keep_clear = [
		func(): return _rect_or_null($Level.tutorial_capsule_pos(), 34.0),
		func(): return _rect_or_null($Level.tutorial_receiver_pos(), 30.0),
		func(): return _rect_or_null($Level.tutorial_next_door_pos(), 30.0),
	]
	runner.run(self, tut.steps($Level, game), game, Callable(self, "_on_tutorial_done"))

func _rect_or_null(p: Vector2, r: float):
	if p == Vector2.ZERO:
		return null
	return Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0)

func _on_tutorial_done(_completed: bool) -> void:
	_restore_tutorial_globals()
	game.playing = false
	_on_level_show_main_menu()

# Also called from _exit_tree: leaving the game mid-tutorial frees the scene, and the runner's own
# _exit_tree does not invoke this callback, so the stashed level would stay applied.
func _restore_tutorial_globals() -> void:
	if is_instance_valid($Level):
		$Level.tutorial_hold_dispatch = false
		$Level.tutorial_freeze_capsules(false)
	if _tutorial_saved_level >= 0:
		PneumoG.starting_level = _tutorial_saved_level
		_tutorial_saved_level = -1

func _exit_tree() -> void:
	_restore_tutorial_globals()

func show_main_menu():
	main_menu.show()
	$Level.hide()
	MainGlobals.update_bottom_bar(["help","mute","scores"])

func show_level():
	get_viewport().gui_release_focus()
	$Level.show()
	main_menu.hide()
	MainGlobals.update_bottom_bar("htfs")
		
func new_game(from_scratch=true):
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
	PneumoG.save_settings()
	new_game()
	show_level()

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

func _on_level_delivered_one() -> void:
	hud.delivered_one()

func _on_level_collision() -> void:
	hud.collided()

func _on_hud_start_game() -> void:
	new_game(true)

func get_game_score(_didwin, _wasaborted):
	return [_didwin, _wasaborted, $Level.level]

func on_game_is_done(_didwin:bool, _wasaborted:bool):
	_did_per_level_save = true
	game.save_score(get_game_score(_didwin, _wasaborted))

func _save_ongoing_score():
	game.save_ongoing_score(get_game_score(false, false))

func on_game_no_more_packets():
	hud.update_all()



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
	main_menu.update_val(1, PneumoG.starting_level)

func on_menu_slider_changed(id, val):
	if id == 1:
		PneumoG.starting_level = roundi(val)
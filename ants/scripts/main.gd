extends Node

# Ants orchestrator. The standard skeleton from how_to_add_a_new_game.txt, with one deliberate
# omission: nothing is saved.
#
# What this game asks of a PLAYER has not been decided, so it measures nothing and claims nothing.
# The crumb counter in the HUD is fed through add_score_and_time(..., is_actual_score = false),
# which leaves score_was_changed clear, and save_score() returns early on that flag -- so a session
# writes no row, the Scores screen stays empty, and the stats screen is never told this game
# measures something it does not. When the task exists, the wiring to turn on is marked below.

@onready var hud = $HUD
var game: GenericGameUtil
var main_menu
var _did_per_level_save: bool = false

func _ready() -> void:
	game = AntsG.game
	game.game_over_on_time_out = true

	randomize()
	RenderingServer.set_default_clear_color(Color.hex(0x1a120cff))
	AntsG.load_settings()
	main_menu = game.create_main_menu(self)

	main_menu.sig_start_game.connect(_on_main_menu_start_game)
	main_menu.sig_option_changed.connect(_on_menu_option_changed)
	main_menu.add_option_entry(1, "Starting level", AntsLevelConfig.level_names())
	refresh_menu()
	show_main_menu()

	hud.set_game(game)
	hud.show()
	hud.update_all()

	game.sig_game_is_done.connect(on_game_is_done)
	$Level.sig_level_is_done.connect(_on_level_sig_level_is_done)
	$Level.started_playing.connect(_on_level_started_playing)

	$Help.set_texts({"N": "New game", "M": "Main menu"})
	$Help.close_help.connect(_on_help_close_help)

	game.set_instructions("Ants",
		"Watch a colony solve a problem nobody told it how to solve.\n" +
		"The ants set out knowing only what is under their antennae.\n" +
		"When one stumbles on the food it carries a crumb home,\n" +
		"laying a scent as it goes; others smell it and follow,\n" +
		"and the more that follow the stronger the scent becomes.\n" +
		"The trail you end up seeing was never planned by anyone.\n" +
		"Drag to look around when the world is larger than the screen.", 24)
	if not game.shown_instructions:
		game.show_instructions(self)
		AntsG.save_settings()

	main_menu.show_continue_and_start_new(false)

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
	if game.time_since_saved_ongoing_score_sec() >= 60:
		_save_ongoing_score()

func _on_level_sig_level_is_done(didwin: bool) -> void:
	if game.playing:
		game.game_is_done(didwin, false)

func _on_main_menu_start_game(_start_new: bool) -> void:
	AntsG.save_settings()
	new_game()
	show_level()

func _on_menu_option_changed(id: int, idx: int) -> void:
	if id == 1:
		AntsG.starting_level_id = AntsLevelConfig.LEVELS[idx]["id"]
		AntsG.save_settings()

func _on_level_show_main_menu() -> void:
	game.playing = false
	show_main_menu()
	if _did_per_level_save:
		game.clear_ongoing_score()
	else:
		_save_ongoing_score()
		game.convert_ongoing_score_to_permanent()

# The level is here because the skeleton wants a row shape; no row is ever written while
# score_was_changed stays clear. When the game gets a task, this is where its numbers join --
# together with a SUMMARY_ROWS entry in scripts/game_instrument.gd, and not before.
func get_game_score(_didwin, _wasaborted):
	return [_didwin, _wasaborted, $Level.current_level_id]

func on_game_is_done(_didwin: bool, _wasaborted: bool) -> void:
	game.save_score(get_game_score(_didwin, _wasaborted))

func _save_ongoing_score() -> void:
	game.save_ongoing_score(get_game_score(false, false))

func _on_hud_start_game() -> void:
	new_game(true)

func _on_help_close_help() -> void:
	game.pause(false)
	$Help.hide()

func _input(event: InputEvent) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if game.handle_new_board(self, event, Callable(self, "new_game")):
		pass
	elif game.handle_main_menu(self, event, Callable(self, "_on_level_show_main_menu")):
		pass
	elif event.is_action_pressed("help"):
		$Help.show()
	elif event.is_action_pressed("esc"):
		if $Help.is_visible():
			_on_help_close_help()
	else:
		game.handle_event(event, self)

func refresh_menu() -> void:
	main_menu.update_option(1, AntsLevelConfig.id_to_index(AntsG.starting_level_id))

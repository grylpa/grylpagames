extends Node

@onready var hud = $HUD

var game: GenericGameUtil
var main_menu
var _did_per_level_save: bool = false

func _ready() -> void:
	game = GorillaG.game
	game.game_over_on_time_out = false
	randomize()
	RenderingServer.set_default_clear_color(Color.hex(0x3C5D3EFF))
	GorillaG.load_settings()
	main_menu = game.create_main_menu(self)
	main_menu.sig_slider_changed.connect(_on_menu_slider_changed)
	main_menu.sig_start_game.connect(_on_main_menu_start_game)
	main_menu.add_entry(1, "Level", 1, GorillaLevelConfig.LEVELS.size(), false)
	_refresh_menu()
	show_main_menu()
	$Help.set_texts({
		# "Drag": "Move",
		"F": "Faster", 
		"L": "sLower",
		"N": "New game",
		"M": "Main menu",
	})
	$Help.close_help.connect(_on_help_close_help)
	hud.set_game(game)
	hud.show()
	hud.show_lives()
	hud.update_all()
	game.sig_game_is_done.connect(_on_game_is_done)
	game.sig_add_life.connect(_on_add_life)

	game.set_instructions("Gorilla",
		"Collect all the coins while monsters chase you!\n\n" +
		"All along, gorillas walk past outside your room.\n\n" +
		"Once you collect all coins (or time runs out),\n" +
		"you will be asked:\n" +
		"How many gorillas did you count?\n\n" +
		"Avoid the monsters inside your room to survive!"
	)
	if not game.shown_instructions:
		game.show_instructions(self)
		GorillaG.save_settings()

	game.show_scores_level = true
	game.progress_time_pos = 7
	game.progress_time_label = "Avg Error"
	game.progress_time_format = "%d"
	game.progress_tab_name = "Error"
	game.sig_level_is_done.connect(_on_game_sig_level_is_done)

	# Launched from the chooser's "How to play"? Then teach instead of showing the menu.
	if MainGlobals.take_pending_tutorial("gorilla"):
		call_deferred("start_tutorial")

var _tutorial_saved_level: int = -1

# The real level with the real rules, scored by nobody: TutorialRunner puts the game into
# tutorial_mode, which suppresses every write in generic_game_util.gd until the tutorial ends.
func start_tutorial() -> void:
	var tut: Script = load("res://gorilla/scripts/tutorial.gd")
	# BEFORE new_game(): new_game() -> game.reset(true) -> convert_ongoing_score_to_permanent(),
	# which would commit and upload the player's unfinished real session.
	game.begin_tutorial()
	# starting_level lives on GorillaG, not the game util, so the snapshot does not cover it.
	_tutorial_saved_level = GorillaG.starting_level
	GorillaG.starting_level = tut.tutorial_level_id()
	new_game()
	var runner: TutorialRunner = TutorialRunner.new()
	runner.run(self, tut.steps($Level, game), game, Callable(self, "_on_tutorial_done"))

func _on_tutorial_done(_completed: bool) -> void:
	if _tutorial_saved_level >= 0:
		GorillaG.starting_level = _tutorial_saved_level
		_tutorial_saved_level = -1
	game.playing = false
	game.level_is_ready = false
	_refresh_menu()
	show_main_menu()
	game.scores_callback = Callable(self, "add_score_line_vals")

func show_main_menu():
	main_menu.show()
	$Level.hide()
	MainGlobals.update_bottom_bar(["help", "mute", "scores"])

func _show_level():
	get_viewport().gui_release_focus()
	$Level.show()
	main_menu.hide()
	MainGlobals.update_bottom_bar(["help","fast","slow","mute"])

func new_game(from_scratch := true):
	if from_scratch:
		_did_per_level_save = false
	_show_level()
	hud.new_game(from_scratch)
	game.reset(from_scratch)
	if not from_scratch:
		game.reset_time_left()
	$Level.new_game(from_scratch)

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

func _on_main_menu_start_game(_start_new: bool) -> void:
	GorillaG.save_settings()
	new_game()

func _on_level_show_main_menu() -> void:
	game.playing = false
	show_main_menu()
	if _did_per_level_save:
		game.clear_ongoing_score()
	else:
		_save_ongoing_score()
		game.convert_ongoing_score_to_permanent()

func _on_help_close_help() -> void:
	game.pause(false)
	$Help.hide()

func _on_level_show_help() -> void:
	if $Help.is_visible():
		game.pause(false)
		$Help.hide()
	else:
		game.pause(true)
		$Help.show()

func _on_level_pressed_esc() -> void:
	if $Help.is_visible():
		game.pause(false)
		$Help.hide()

func _on_level_collision() -> void:
	hud.collided()

func _on_level_update_score(_score_add: int):
	hud.update_all()

func _on_hud_start_game() -> void:
	new_game(true)

func _on_game_sig_level_is_done(_didwin: bool) -> void:
	_did_per_level_save = true
	game.save_score(get_game_score(_didwin, false))

func get_game_score(_didwin, _wasaborted):
	var num_questions: int = game.mistakes  # mistakes = question count
	var avg_error: int = int(round(float(game.corrects) / num_questions)) if num_questions > 0 else -1
	return [_didwin, _wasaborted, $Level.level, avg_error]

func _on_game_is_done(_didwin: bool, _wasaborted: bool):
	game.save_score(get_game_score(_didwin, _wasaborted))

func _save_ongoing_score():
	game.save_ongoing_score(get_game_score(false, false))

func _on_add_life():
	hud.add_life()

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
		game.handle_event(event, $Level)

func _refresh_menu():
	main_menu.update_val(1, GorillaG.starting_level)

func _on_menu_slider_changed(id, val):
	if id == 1:
		GorillaG.starting_level = roundi(val)
		GorillaG.save_settings()

func add_score_line_vals(score_row: Array) -> Array:
	if score_row.size() > 6:
		return [str(int(score_row[6]))]
	return []

func _on_main_menu_scores() -> void:
	game.test_open_scores_screen(null, self)

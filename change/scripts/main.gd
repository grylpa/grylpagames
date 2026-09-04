extends Node

@onready var hud = $HUD
var game: GenericGameUtil
var main_menu
var _did_per_level_save: bool = false

var POS_SCORE_LEVEL_ID: int = 6
var POS_SCORE_MEAN_TIME_MS: int = 7
var POS_SCORE_PCT_CORRECT: int = 8

func _ready() -> void:
	game = ChangeG.game
	# Time is a per-level budget that ends the LEVEL (advance), not the game.
	game.game_over_on_time_out = false

	randomize()
	RenderingServer.set_default_clear_color(Color.hex(0x2E4A34FF))  # green felt table
	ChangeG.load_settings()
	main_menu = game.create_main_menu(self)

	main_menu.sig_start_game.connect(_on_main_menu_start_game)
	main_menu.sig_option_changed.connect(_on_menu_option_changed)
	main_menu.add_option_entry(1, "Starting level", ChangeLevelConfig.level_names())
	refresh_menu()
	show_main_menu()

	hud.set_game(game)
	hud.show()
	hud.show_corrects_mistakes()
	hud.update_all()
	# move the level-number label down so the per-board timeout bar fits between the
	# header and it (the label defaults to y 60-104, right under the header).
	var level_label = hud.get_node_or_null("LevelLabel")
	if level_label != null:
		level_label.offset_top = 92.0
		level_label.offset_bottom = 132.0
		level_label.modulate.a = 1.0

	game.sig_game_is_done.connect(on_game_is_done)
	$Level.sig_level_is_done.connect(_on_level_sig_level_is_done)
	$Level.started_playing.connect(_on_level_started_playing)

	$Help.set_texts({"N": "New game", "M": "Main menu"})
	$Help.close_help.connect(_on_help_close_help)

	game.set_instructions("Change",
		"You are given an amount to pay. A pile of coins sits on the table." +
		"\n\n" +
		"Drag coins into the tray to make up the exact amount.", 28)
	if not game.shown_instructions:
		game.show_instructions(self)
		ChangeG.save_settings()

	main_menu.show_continue_and_start_new(false)
	game.scores_callback = Callable(self, "add_score_line_vals")
	game.show_scores_level = true
	game.show_scores_level_as_name = true
	game.progress_level_pos = POS_SCORE_LEVEL_ID
	game.progress_time_pos = POS_SCORE_MEAN_TIME_MS
	game.progress_pct_pos = POS_SCORE_PCT_CORRECT
	for lvl in ChangeLevelConfig.LEVELS:
		game.progress_level_names[lvl["id"]] = lvl["name"]
	game.sig_level_is_done.connect(_on_game_sig_level_is_done)

	# Teach instead of showing the menu when the player asked for the tutorial from the
	# chooser's "How to play", OR when this is their first ever run of this game.
	if MainGlobals.take_pending_tutorial("change") \
			or MainGlobals.take_auto_tutorial("change", game.shown_instructions):
		call_deferred("start_tutorial")

var _tutorial_saved_level: int = -1

# The real level with the real rules, scored by nobody: TutorialRunner puts the game into
# tutorial_mode, which suppresses every write in generic_game_util.gd until the tutorial ends.
func start_tutorial() -> void:
	var tut: Script = load("res://change/scripts/tutorial.gd")
	# BEFORE new_game(): new_game() -> game.reset(true) -> convert_ongoing_score_to_permanent(),
	# which would commit and upload the player's unfinished real session.
	game.begin_tutorial()
	# starting_level_id lives on ChangeG, not the game util, so the tutorial snapshot does not
	# cover it — save and restore it by hand.
	_tutorial_saved_level = ChangeG.starting_level_id
	ChangeG.starting_level_id = tut.tutorial_level_id()
	new_game()
	var runner: TutorialRunner = TutorialRunner.new()
	# The board fills the screen: pile, then tray, then PAY. A caption docked at the bottom sat on
	# 94%% of the tray on the step that says to put coins in it, so it could be neither seen nor
	# dragged into. Listing all three pushes the caption into the band above the pile.
	runner.keep_clear = [
		func(): return $Level._pile_rect,
		func(): return $Level._basket_rect,
		func(): return $Level._pay_btn,
	]
	runner.run(self, tut.steps($Level, game), game, Callable(self, "_on_tutorial_done"))

func _on_tutorial_done(_completed: bool) -> void:
	_restore_tutorial_globals()
	game.playing = false
	$Level.stop_level()
	refresh_menu()
	show_main_menu()

# Also called from _exit_tree: leaving the game mid-tutorial frees the scene, and the runner's
# own _exit_tree does not invoke this callback — so without it the tutorial's stashed values
# stayed applied to the player's real settings.
func _restore_tutorial_globals() -> void:
	if _tutorial_saved_level >= 0:
		ChangeG.starting_level_id = _tutorial_saved_level
		_tutorial_saved_level = -1

func _exit_tree() -> void:
	_restore_tutorial_globals()
func _on_game_sig_level_is_done(_didwin: bool) -> void:
	_did_per_level_save = true
	game.save_score(get_game_score(_didwin, false))

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

func _on_level_sig_level_is_done(_didwin: bool) -> void:
	if game.playing:
		new_game(false)

func _on_main_menu_start_game(_start_new: bool) -> void:
	ChangeG.save_settings()
	new_game()
	show_level()

func _on_menu_option_changed(id: int, idx: int) -> void:
	if id == 1:
		ChangeG.starting_level_id = ChangeLevelConfig.LEVELS[idx]["id"]
		ChangeG.save_settings()

func _on_level_show_main_menu() -> void:
	game.playing = false
	$Level.stop_level()
	show_main_menu()
	if _did_per_level_save:
		game.clear_ongoing_score()
	else:
		_save_ongoing_score()
		game.convert_ongoing_score_to_permanent()

func get_game_score(_didwin, _wasaborted):
	# Keep the WHOLE distribution, not just its mean: spread and drift are what move first.
	game.record_times($Level.times_to_answer, "rt")
	return [_didwin, _wasaborted, $Level.current_level_id,
		$Level.mean_response_time_ms(), $Level.pct_correct()]

func on_game_is_done(_didwin: bool, _wasaborted: bool) -> void:
	game.save_score(get_game_score(_didwin, _wasaborted))

func add_score_line_vals(score_row: Array) -> Array:
	var res: Array = []
	if score_row.size() > POS_SCORE_LEVEL_ID:
		var lvl: Dictionary = ChangeLevelConfig.get_level(score_row[POS_SCORE_LEVEL_ID])
		res.append(lvl.get("name", "?"))
	if score_row.size() > POS_SCORE_MEAN_TIME_MS:
		res.append(str(int(score_row[POS_SCORE_MEAN_TIME_MS])))
	return res

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
	main_menu.update_option(1, ChangeLevelConfig.id_to_index(ChangeG.starting_level_id))

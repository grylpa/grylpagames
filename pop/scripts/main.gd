extends Node

@onready var hud = $HUD
var game:GenericGameUtil
var main_menu
var _did_per_level_save: bool = false

func _ready() -> void:
	game = PopG.game
	game.initial_score = 100
	game.forced_board_size = Vector2i(11,11)	

	randomize()
	RenderingServer.set_default_clear_color(Color.hex(0x3C5D3EFF))
	PopG.load_settings()
	main_menu = game.create_main_menu(self)
	main_menu.sig_slider_changed.connect(on_menu_slider_changed)
	main_menu.sig_start_game.connect(_on_main_menu_menu_start_game)
	main_menu.add_entry(1, "Level", 1, PopLevelConfig.LEVELS.size(), false)
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
	game.set_instructions("Glimpse", 
		"You will briefly see an image somewhere.\n" + 
		"After some time, you will see a few images elsewhere.\n" + 
		"You need to select the matching image\n" + 
		"as quickly as possible\n", 
		_ins_font_sz)
	if !game.shown_instructions:
		game.show_instructions(self)
		PopG.save_settings()
	main_menu.show_continue_and_start_new(false)
	game.scores_callback = Callable(self, "add_score_line_vals")
	game.show_scores_level = true
	game.progress_level_pos = POS_SCORE_DIFFICULTY
	game.progress_time_pos = POS_SCORE_MEAN_TIME_MS
	game.progress_pct_pos = POS_SCORE_PCT_CORRECT
	game.sig_level_is_done.connect(_on_game_sig_level_is_done)
	_maybe_start_tutorial()
	
func _on_game_sig_level_is_done(_didwin: bool) -> void:
	_did_per_level_save = true
	game.save_score(get_game_score(_didwin, false))

# Teach instead of showing the menu when the player asked for the tutorial from the
# chooser's "How to play", OR when this is their first ever run of this game.
func _maybe_start_tutorial() -> void:
	if MainGlobals.take_pending_tutorial("pop") \
			or MainGlobals.take_auto_tutorial("pop", game.shown_instructions):
		call_deferred("start_tutorial")

var _tutorial_saved_level: int = -1

# The real game with the real rules, recorded by nobody: TutorialRunner puts the game into
# tutorial_mode, which suppresses every write in generic_game_util.gd until the tutorial ends.
func start_tutorial() -> void:
	var tut: Script = load("res://pop/scripts/tutorial.gd")
	# BEFORE new_game(): new_game() -> game.reset(true) -> convert_ongoing_score_to_permanent(),
	# which would commit and upload the player's unfinished real session.
	game.begin_tutorial()
	_tutorial_saved_level = PopG.starting_level
	PopG.starting_level = tut.tutorial_level_id()
	new_game()
	var runner: TutorialRunner = TutorialRunner.new()
	# The caption must stay off the flash while it is being memorized, and off the candidates the
	# player is comparing against it.
	# Each candidate listed separately, NOT as one merged rect. They ring the board, so their
	# bounding box is most of the screen and asking the placer to avoid it is unsatisfiable — the
	# caption then lands right on them. Individually they leave the middle of the board free, which
	# is where the caption belongs. Level 1 shows two; the spare entries cost nothing when absent.
	runner.keep_clear = [
		func():
			var p: Vector2 = $Level.tutorial_model_pos()
			if p == Vector2.ZERO:
				return null
			return Rect2(p - Vector2(30, 30), Vector2(60, 60)),
		func():
			var r: Rect2 = $Level.tutorial_candidate_rect_at(0)
			if r.size.x <= 0.0:
				return null
			return r,
		func():
			var r: Rect2 = $Level.tutorial_candidate_rect_at(1)
			if r.size.x <= 0.0:
				return null
			return r,
		func():
			var r: Rect2 = $Level.tutorial_candidate_rect_at(2)
			if r.size.x <= 0.0:
				return null
			return r,
		func():
			var r: Rect2 = $Level.tutorial_candidate_rect_at(3)
			if r.size.x <= 0.0:
				return null
			return r,
	]
	runner.run(self, tut.steps($Level, game), game, Callable(self, "_on_tutorial_done"))

func _on_tutorial_done(_completed: bool) -> void:
	_restore_tutorial_globals()
	game.playing = false
	_on_level_show_main_menu()

# Also called from _exit_tree: leaving the game mid-tutorial frees the scene, and the runner's own
# _exit_tree does not invoke this callback, so the stashed level would stay applied.
func _restore_tutorial_globals() -> void:
	if is_instance_valid($Level):
		$Level.tutorial_freeze_board(false)
	if _tutorial_saved_level >= 0:
		PopG.starting_level = _tutorial_saved_level
		_tutorial_saved_level = -1

func _exit_tree() -> void:
	_restore_tutorial_globals()

func show_main_menu():
	main_menu.show_continue_and_start_new(false)
	main_menu.show()
	$Level.hide()
	MainGlobals.update_bottom_bar(["help","mute","scores"])
	MainGlobals.add_action_button(null)

func show_level():
	get_viewport().gui_release_focus()
	$Level.show()
	main_menu.hide()
	MainGlobals.update_bottom_bar(["help","mute"])
	MainGlobals.add_action_button(null)
		
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
	PopG.save_settings()
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

func _on_hud_start_game() -> void:
	new_game(true)

var POS_SCORE_DIFFICULTY: int = 6
var POS_SCORE_MEAN_TIME_MS: int = 7
var POS_SCORE_PCT_CORRECT: int = 8
func get_game_score(_didwin, _wasaborted):
	var last_level = $Level.level
	if $Level.num_corrects_in_level_so_far == 0:
		last_level = max(1, last_level - 1)
	var total: int = game.corrects + game.mistakes
	var pct: int = 100 if total == 0 else int(100.0 * game.corrects / total)
	return [_didwin, _wasaborted, last_level, $Level.mean_time_to_answer_ms(), pct]

func on_game_is_done(_didwin:bool, _wasaborted:bool):
	game.save_score(get_game_score(_didwin, _wasaborted))

func add_score_line_vals(score_row):
	var res = []
	if score_row.size() > POS_SCORE_DIFFICULTY:
		var lvl = score_row[POS_SCORE_DIFFICULTY]
		res.append(str(int(lvl)) if not lvl is String else lvl)
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
	main_menu.update_val(1, PopG.starting_level)

func on_menu_slider_changed(id: int, val: float) -> void:
	if id == 1:
		PopG.starting_level = roundi(val)
		PopG.save_settings()

func _on_changed_focus(_gained_focus: bool):
	game.in_focus = _gained_focus

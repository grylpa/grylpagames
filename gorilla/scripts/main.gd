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
	# a sunny park tune with birds while the board is up, under the footsteps (devtools/make_ambient_sounds.py); stopped at the menu
	game.add_sound(self, "ambient", preload("res://art/sounds/gorilla_ambient.ogg"), true)
	game.set_sound_volume("ambient", -6.0)
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
		"Eat the apples in the maze while monsters chase you. " +
		"Keep eating: go too long without an apple and you starve. The ring around you shows how long you have.\n\n" +
		"Now and then a baby gorilla gets lost somewhere in the maze, far from you. " +
		"Get to it before a monster does and you rescue it. Soon after it appears, a monster starts hunting it.\n\n" +
		"Each rescue brings the baby's mother out somewhere else, holding a sword for a few seconds. " +
		"Take it, and for a while the monsters run from you and you can eat them.\n\n" +
		"Bananas turn up too, for a few seconds only. A bunch fills your ring right up, " +
		"so you can go far from the apples.\n\n" +
		"Rescue enough babies to pass the level. Being caught or starving costs a life."
	)
	if not game.shown_instructions:
		game.show_instructions(self)
		GorillaG.save_settings()

	game.show_scores_level = true
	game.scores_callback = Callable(self, "add_score_line_vals")
	# The row: the mean time to a rescue, then the share of babies rescued -- filed as `pct_correct`,
	# so every stats screen reads it as this game's accuracy. The answer-time metrics (rt_mean, rt_cv,
	# ...) come from record_times over the rescue times, and only when there were rescues; the
	# column keeps its own name so a round with none (9999) is never read as an answer time.
	# The counting game's rows (count_error, before 2026-11-09) are hidden from every screen by
	# GenericGameUtil.DATA_FORMATS.
	game.score_columns = ["didwin", "aborted", "level", "rescue_ms", "pct_correct"]
	# the level, so the tables and charts are split by level like every other game's (it was never
	# set here, and all of Gorilla's sessions were pooled into one)
	game.progress_level_pos = 6
	game.progress_time_pos = 7
	game.progress_time_label = "Time to a rescue"
	game.progress_time_format = "%d ms"
	game.progress_tab_name = "Rescue"
	game.progress_pct_pos = 8
	game.progress_pct_label = "% Rescued"
	game.sig_level_is_done.connect(_on_game_sig_level_is_done)

	# Teach instead of showing the menu when the player asked for the tutorial from the
	# chooser's "How to play", OR when this is their first ever run of this game.
	if MainGlobals.take_pending_tutorial("gorilla") \
			or MainGlobals.take_auto_tutorial("gorilla", game.shown_instructions):
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
	_restore_tutorial_globals()
	game.playing = false
	game.level_is_ready = false
	_refresh_menu()
	show_main_menu()

# Also called from _exit_tree: leaving the game mid-tutorial frees the scene, and the runner's
# own _exit_tree does not invoke this callback — so without it the tutorial's stashed values
# stayed applied to the player's real settings.
func _restore_tutorial_globals() -> void:
	if _tutorial_saved_level >= 0:
		GorillaG.starting_level = _tutorial_saved_level
		_tutorial_saved_level = -1

func _exit_tree() -> void:
	_restore_tutorial_globals()
func show_main_menu():
	game.stop_sound("ambient")
	main_menu.show()
	$Level.hide()
	MainGlobals.update_bottom_bar(["help", "mute", "scores"])

func _show_level():
	game.play_sound("ambient", false)
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
	# The time to a rescue and the share of babies rescued, from the level's own tally.
	game.record_times($Level.rescue_times, "rt")
	return [_didwin, _wasaborted, $Level.level, $Level.mean_rescue_ms(), $Level.rescue_pct()]

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

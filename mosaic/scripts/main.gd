extends Node

@onready var hud = $HUD
var game: GenericGameUtil
var main_menu
var _did_per_level_save: bool = false

# The saved row, in score_columns order (the scores screen reads it by position: the record's own
# fields come first, so column i is at i + 4).
var POS_SCORE_LEVEL_ID: int = 6
var POS_SCORE_LAST_ROUND_MS: int = 7
var POS_SCORE_FIRST_TRY_PCT: int = 8

func _ready() -> void:
	game = MosaicG.game
	game.game_over_on_time_out = false
	game.score_columns = ["didwin", "aborted", "level", "last_round_ms", "first_try_pct", "rounds_played",
		"moves", "failed_rounds"]

	randomize()
	RenderingServer.set_default_clear_color(Color(0.075, 0.09, 0.14))
	MosaicG.init_globals()
	MosaicG.load_settings()
	main_menu = game.create_main_menu(self)
	main_menu.sig_start_game.connect(_on_main_menu_start_game)
	main_menu.sig_option_changed.connect(_on_menu_option_changed)
	main_menu.add_option_entry(1, "Starting level", MosaicLevelConfig.level_names())
	show_main_menu()

	hud.set_game(game)
	hud.show()
	hud.update_all()
	# The level number goes below the round's time bar (it defaults to y 60-104, on top of it).
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

	game.set_instructions("Mosaic",
		"A picture is shown for a few seconds, then cut into pieces and shuffled." +
		"\n\n" +
		"Drag one piece onto another to swap them, until the picture is whole again." +
		"\n\n" +
		"On some levels the pieces are rotated too: tap a piece to rotate it." +
		"\n\n" +
		"The same picture comes back for several rounds, so you can get faster at it.")
	if not game.shown_instructions:
		game.show_instructions(self)
		MosaicG.save_settings()

	game.scores_callback = Callable(self, "add_score_line_vals")
	game.show_scores_level = true
	game.show_scores_level_as_name = true
	game.progress_level_pos = POS_SCORE_LEVEL_ID
	game.progress_time_pos = POS_SCORE_LAST_ROUND_MS
	game.progress_pct_pos = POS_SCORE_FIRST_TRY_PCT
	# Not an average: the LAST round's time, and only where that round was rebuilt (last_round_ms is 0
	# otherwise, which the Speed tab skips). In ms; the scores screen shows it in seconds, and adds
	# the unit to the name: "Last round (sec)".
	game.progress_time_label = "Last round"
	game.progress_time_format = "%d ms"
	game.progress_tab_name = "Speed"
	for lvl in MosaicLevelConfig.LEVELS:
		game.progress_level_names[lvl["id"]] = lvl["name"]
	game.sig_level_is_done.connect(_on_game_sig_level_is_done)

func _on_game_sig_level_is_done(_didwin: bool) -> void:
	_did_per_level_save = true
	game.save_score(get_game_score(_didwin, false))

func show_main_menu() -> void:
	main_menu.show_continue_and_start_new(false)
	# Read every time the menu shows, so it always shows the level Start will play.
	refresh_menu()
	main_menu.show()
	$Level.hide()
	MainGlobals.update_bottom_bar(["help", "mute", "scores"])
	MainGlobals.add_action_button(null)

func show_level() -> void:
	get_viewport().gui_release_focus()
	$Level.show()
	main_menu.hide()
	MainGlobals.update_bottom_bar(["help", "mute"], Color.YELLOW, true)
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

func _on_game_tick_timeout() -> void:
	game.tick_game_time()
	if game.time_since_saved_ongoing_score_sec() >= 60:
		_save_ongoing_score()

func _on_level_sig_level_is_done(_didwin: bool) -> void:
	if game.playing:
		new_game(false)

func _on_main_menu_start_game(_start_new: bool) -> void:
	# Start plays the level the menu is SHOWING.
	var shown: int = main_menu.get_option(1)
	if shown >= 0 and shown < MosaicLevelConfig.LEVELS.size():
		MosaicG.starting_level_id = int(MosaicLevelConfig.LEVELS[shown]["id"])
	MosaicG.save_settings()
	new_game()
	show_level()

func _on_menu_option_changed(id: int, idx: int) -> void:
	if id == 1:
		MosaicG.starting_level_id = int(MosaicLevelConfig.LEVELS[idx]["id"])
		MosaicG.save_settings()

func _on_level_show_main_menu() -> void:
	game.playing = false
	$Level.stop_level()
	show_main_menu()
	if _did_per_level_save:
		game.clear_ongoing_score()
	else:
		_save_ongoing_score()
		game.convert_ongoing_score_to_permanent()

# [didwin, aborted, level, last_round_ms, first_try_pct, rounds_played, moves, failed_rounds]
# last_round_ms is the LAST round's time when that round was rebuilt, else 0 (the Speed tab skips a
# 0). The same time goes in the metrics as solve_ms ONLY when there is one: the Summary row reads
# every record that has the key, and a 0 there would count as the fastest rebuild ever. Every round's time, and whether it was rebuilt, go in
# the metrics -- the same picture each round, so the list is the learning curve.
func get_game_score(_didwin, _wasaborted):
	var lv: Node = $Level
	var first_pct: int = int(lv.first_try_pct) if int(lv.first_try_pct) >= 0 else 0
	var solved_times: Array = []
	for k in (lv.round_times_ms as Array).size():
		if bool(lv.round_solved[k]):
			solved_times.append(lv.round_times_ms[k])
	game.record_times(solved_times, "round")
	game.record_metrics({"round_times_ms": (lv.round_times_ms as Array).duplicate(),
		"round_solved": (lv.round_solved as Array).duplicate(),
		"first_solve_ms": int(lv.first_solve_ms()), "faster_pct": int(lv.faster_pct()),
		"solved_rounds": int(lv.solved_rounds), "turns": int(lv.turns_made),
		"rounds_allowed": int(lv.max_rounds),
		"failed_rounds_level_total": MosaicG.failed_rounds(int(lv.current_level_id))})
	if int(lv.solve_ms()) > 0:
		game.record_metrics({"solve_ms": int(lv.solve_ms())})
	return [_didwin, _wasaborted, lv.current_level_id, lv.solve_ms(), first_pct, lv.round_index,
		lv.moves, lv.failed_rounds]

func on_game_is_done(_didwin: bool, _wasaborted: bool) -> void:
	game.save_score(get_game_score(_didwin, _wasaborted))

func add_score_line_vals(score_row: Array) -> Array:
	var res: Array = []
	if score_row.size() > POS_SCORE_LEVEL_ID:
		var lvl: Dictionary = MosaicLevelConfig.get_level(int(score_row[POS_SCORE_LEVEL_ID]))
		res.append(lvl.get("name", "?"))
	if score_row.size() > POS_SCORE_LAST_ROUND_MS:
		var last_ms: int = int(score_row[POS_SCORE_LAST_ROUND_MS])
		# a 0 is a last round that ran out: no time to show
		res.append("%d s" % int(round(last_ms / 1000.0)) if last_ms > 0 else "-")
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
	main_menu.update_option(1, MosaicLevelConfig.id_to_index(MosaicG.starting_level_id))

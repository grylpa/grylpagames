extends Node

@onready var hud = $HUD
var game: GenericGameUtil
var main_menu
var _did_per_level_save: bool = false
var _tutorial_saved_level: int = -1

# The saved row, in score_columns order (the scores screen reads it by position: the record's own
# fields come first, so column i is at i + 4).
var POS_SCORE_LEVEL_ID: int = 6
var POS_SCORE_LAST_ROUND_MS: int = 7
var POS_SCORE_COLLISIONS: int = 8

const HUD_ICON_PX: int = 32

func _ready() -> void:
	game = LighthouseG.game
	game.game_over_on_time_out = false
	game.score_columns = ["didwin", "aborted", "level", "last_round_ms", "collisions", "rounds_played",
		"rounds_won"]

	randomize()
	RenderingServer.set_default_clear_color(Color(0.02, 0.03, 0.06))
	LighthouseG.init_globals()
	LighthouseG.load_settings()
	main_menu = game.create_main_menu(self)
	main_menu.sig_start_game.connect(_on_main_menu_start_game)
	main_menu.sig_option_changed.connect(_on_menu_option_changed)
	main_menu.add_option_entry(1, "Starting level", LighthouseLevelConfig.level_names())
	show_main_menu()

	hud.set_game(game)
	hud.show()
	# The lives slot counts this round's crashes down as lifebuoys: each crash costs one, and the crash
	# that reaches the level's maximum loses the round. The icon is
	# baked at 64 px, so scale it to the strip's 32; Color.WHITE keeps its own red and white.
	hud.set_lives_icon(LighthouseG.buoy_icon(), Vector2.ONE * (float(HUD_ICON_PX) / float(LighthouseG.ICON_PX)), Color.WHITE)
	hud.show_lives()
	hud.update_all()
	# The level number goes below the level's time bar (it defaults to y 60-104, on top of it).
	var level_label = hud.get_node_or_null("LevelLabel")
	if level_label != null:
		level_label.offset_top = 92.0
		level_label.offset_bottom = 132.0
		level_label.modulate.a = 1.0

	game.sig_game_is_done.connect(on_game_is_done)
	$Level.sig_level_is_done.connect(_on_level_sig_level_is_done)
	$Level.started_playing.connect(_on_level_started_playing)
	$Level.lives_changed.connect(func() -> void: hud.update_lives())

	# Keys only: every entry is a button that presses its key. The arrow keys are on the instructions
	# screen -- an "Arrows" entry here was a button that did nothing.
	$Help.set_texts({"N": "New game", "M": "Main menu"})
	$Help.close_help.connect(_on_help_close_help)

	game.set_instructions("Lighthouse",
		"Sail the boat from the bottom of the sea to the jetty at the top, where the green light shines." +
		"\n\n" +
		"It is night. Only the lighthouse's turning beam and your boat's own light show the rocks and wrecks, and only while the light is on them." +
		"\n\n" +
		"Draw a route from the boat and it sails it. Tap the sea to go straight there, and tap the boat to stop. The arrow keys steer too." +
		"\n\n" +
		"Each round allows only a few crashes (the lifebuoys count them down) and has a time limit. On some levels the sea is the same every round, so remember what the light showed you: there, each round allows one crash fewer." +
		"\n\n" +
		"To pass a level, reach the jetty in every round.")
	if not game.shown_instructions:
		game.show_instructions(self)
		LighthouseG.save_settings()

	game.scores_callback = Callable(self, "add_score_line_vals")
	game.show_scores_level = true
	game.show_scores_level_as_name = true
	game.progress_level_pos = POS_SCORE_LEVEL_ID
	game.progress_time_pos = POS_SCORE_LAST_ROUND_MS
	# The LAST round's crossing time, only where it reached the pier (0 otherwise, which the Speed tab
	# skips). In ms; the scores screen shows it in seconds: "Last round (sec)".
	game.progress_time_label = "Last round"
	game.progress_time_format = "%d ms"
	game.progress_tab_name = "Speed"
	for lvl in LighthouseLevelConfig.LEVELS:
		game.progress_level_names[lvl["id"]] = lvl["name"]
	game.sig_level_is_done.connect(_on_game_sig_level_is_done)

	# Teach instead of showing the menu when the player asked for the tutorial from the chooser's
	# "How to play", OR when this is their first ever run of this game.
	if MainGlobals.take_pending_tutorial("lighthouse") \
			or MainGlobals.take_auto_tutorial("lighthouse", game.shown_instructions):
		call_deferred("start_tutorial")

func _on_game_sig_level_is_done(_didwin: bool) -> void:
	_did_per_level_save = true
	game.save_score(get_game_score(_didwin, false))

func show_main_menu() -> void:
	main_menu.show_continue_and_start_new(false)
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
	if shown >= 0 and shown < LighthouseLevelConfig.LEVELS.size():
		LighthouseG.starting_level_id = int(LighthouseLevelConfig.LEVELS[shown]["id"])
	LighthouseG.save_settings()
	new_game()
	show_level()

func _on_menu_option_changed(id: int, idx: int) -> void:
	if id == 1:
		LighthouseG.starting_level_id = int(LighthouseLevelConfig.LEVELS[idx]["id"])
		LighthouseG.save_settings()

func _on_level_show_main_menu() -> void:
	game.playing = false
	$Level.stop_level()
	show_main_menu()
	if _did_per_level_save:
		game.clear_ongoing_score()
	else:
		_save_ongoing_score()
		game.convert_ongoing_score_to_permanent()

# [didwin, aborted, level, last_round_ms, collisions, rounds_played, rounds_won]
# last_round_ms is the LAST round's crossing time when it reached the pier, else 0 (the Speed tab
# skips a 0). The same time goes in the metrics as crossing_ms ONLY when there is one: the Summary
# row reads every record that has the key, and a 0 there would be the fastest crossing ever. Every
# round's time and result go in the metrics too (round_times_ms / round_solved, the Rounds chart).
func get_game_score(_didwin, _wasaborted):
	var lv: Node = $Level
	var won_times: Array = []
	for k in (lv.round_times_ms as Array).size():
		if bool(lv.round_solved[k]):
			won_times.append(lv.round_times_ms[k])
	game.record_times(won_times, "round")
	game.record_metrics({"round_times_ms": (lv.round_times_ms as Array).duplicate(),
		"round_solved": (lv.round_solved as Array).duplicate(),
		"round_collisions": (lv.round_collisions as Array).duplicate(),
		"collisions_seen": int(lv.collisions_seen),
		"first_round_ms": int(lv.first_round_ms()),
		"rounds_allowed": int(lv.max_rounds)})
	if int(lv.last_round_ms()) > 0:
		game.record_metrics({"crossing_ms": int(lv.last_round_ms())})
	return [_didwin, _wasaborted, lv.current_level_id, lv.last_round_ms(), lv.collisions_total,
		lv.round_index, lv.rounds_won]

func on_game_is_done(_didwin: bool, _wasaborted: bool) -> void:
	game.save_score(get_game_score(_didwin, _wasaborted))

func add_score_line_vals(score_row: Array) -> Array:
	var res: Array = []
	if score_row.size() > POS_SCORE_LEVEL_ID:
		var lvl: Dictionary = LighthouseLevelConfig.get_level(int(score_row[POS_SCORE_LEVEL_ID]))
		res.append(lvl.get("name", "?"))
	if score_row.size() > POS_SCORE_LAST_ROUND_MS:
		var last_ms: int = int(score_row[POS_SCORE_LAST_ROUND_MS])
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

# The real level with the real rules, scored by nobody: TutorialRunner puts the game into
# tutorial_mode, which suppresses every write in generic_game_util.gd until the tutorial ends.
func start_tutorial() -> void:
	var tut: Script = load("res://lighthouse/scripts/tutorial.gd")
	# BEFORE new_game(): new_game() -> game.reset(true) -> convert_ongoing_score_to_permanent(),
	# which would commit and upload the player's unfinished real session.
	game.begin_tutorial()
	# starting_level_id lives on LighthouseG, not the game util, so the snapshot does not cover it.
	_tutorial_saved_level = LighthouseG.starting_level_id
	LighthouseG.starting_level_id = tut.tutorial_level_id()
	new_game()
	var runner: TutorialRunner = TutorialRunner.new()
	runner.run(self, tut.steps($Level, game), game, Callable(self, "_on_tutorial_done"))

func _on_tutorial_done(_completed: bool) -> void:
	_restore_tutorial_globals()
	game.playing = false
	game.level_is_ready = false
	$Level.stop_level()
	refresh_menu()
	show_main_menu()

# Also called from _exit_tree: leaving the game mid-tutorial frees the scene, and the runner's own
# _exit_tree does not invoke this callback.
func _restore_tutorial_globals() -> void:
	if _tutorial_saved_level >= 0:
		LighthouseG.starting_level_id = _tutorial_saved_level
		_tutorial_saved_level = -1

func _exit_tree() -> void:
	_restore_tutorial_globals()

func refresh_menu() -> void:
	main_menu.update_option(1, LighthouseLevelConfig.id_to_index(LighthouseG.starting_level_id))

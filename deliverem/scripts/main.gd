extends Node

@onready var hud = $HUD

var game:GenericGameUtil
var main_menu
var _did_per_level_save: bool = false

func _ready() -> void:
	game = DeliveremG.game
	randomize()
	RenderingServer.set_default_clear_color(Color.hex(0x3C5D3EFF))
	DeliveremG.speed = game.tile_size * 1000.0 / game.major_tick_time_ms
	DeliveremG.body_delay_sec = 32.0 / DeliveremG.speed
	DeliveremG.load_settings()
	main_menu = game.create_main_menu(self)	
	main_menu.sig_slider_changed.connect(on_menu_slider_changed)
	main_menu.sig_start_game.connect(_on_main_menu_menu_start_game)
	main_menu.add_entry(1, "Level", 1, DeliveremLevelConfig.LEVELS.size(), false)
	refresh_menu()

	show_main_menu()
	$Level.hide()
	$Help.set_texts({
		"F":"Faster",
		"L":"sLower",
		"R":"Reminder",
		"N":"New game",
	})
	$Help.close_help.connect(_on_help_close_help)
	hud.set_game(game)
	hud.show()
	game.sig_game_is_done.connect(on_game_is_done)
	# $Level.update_score_time.connect(on_update_score_time)

	game.set_instructions("Deliverem", 
		"Deliver all packets in the order you are told\n\n" + 
		"Click on junctions to open or rotate the doors\n\n" +
		"Do not allow the delivery guys to collide into each other")
	if !game.shown_instructions:
		game.show_instructions(self)
		DeliveremG.save_settings()
	game.show_scores_level = true
	game.scores_callback = Callable(self, "add_score_line_vals")
	game.progress_level_pos = 6
	game.sig_level_is_done.connect(_on_game_sig_level_is_done)

	# Teach instead of showing the menu when the player asked for the tutorial from the
	# chooser's "How to play", OR when this is their first ever run of this game.
	# MUST stay at the end of _ready, after show_instructions above: that call's suppression guard
	# asks whether a tutorial is pending, so consuming the flag earlier lets the text wall through.
	if MainGlobals.take_pending_tutorial("deliverem") \
			or MainGlobals.take_auto_tutorial("deliverem", game.shown_instructions):
		call_deferred("start_tutorial")

var _tutorial_saved_level: int = -1
var _tutorial_saved_packets: int = -1

# The real game with the real rules, recorded by nobody: TutorialRunner puts the game into
# tutorial_mode, which suppresses every write in generic_game_util.gd until the tutorial ends.
func start_tutorial() -> void:
	var tut: Script = load("res://deliverem/scripts/tutorial.gd")
	# BEFORE new_game(): new_game() -> game.reset(true) -> convert_ongoing_score_to_permanent(),
	# which would commit and upload the player's unfinished real session.
	game.begin_tutorial()
	# Both of these live on DeliveremG, not on the game util, so the snapshot does not cover them.
	_tutorial_saved_level = DeliveremG.starting_level
	_tutorial_saved_packets = DeliveremG.num_packets
	DeliveremG.starting_level = tut.tutorial_level_id()
	DeliveremG.num_packets = 2   # two docks to visit: one taught, one to finish
	$Level.tutorial_hud = hud
	new_game()
	var runner: TutorialRunner = TutorialRunner.new()
	# The caption must not cover the truck, the door it is asking the player to tap, the dock it is
	# sending the truck to, or the dispatch line it is reading out.
	runner.keep_clear = [
		func(): return _rect_or_null($Level.tutorial_agent_pos(), 46.0),
		func(): return _rect_or_null($Level.tutorial_next_door_pos(), 40.0),
		func(): return _rect_or_null($Level.tutorial_next_dock_pos(), 40.0),
		func(): return $Level.tutorial_dispatch_label(),
	]
	# The dispatcher's order line lives on the HUD (CanvasLayer 1) while the overlay dims from 120,
	# so without this it spends the whole tutorial unreadable except on the one step that points at
	# it — and part of learning the game is learning WHERE the order appears.
	runner.never_dim = [
		func(): return $Level.tutorial_dispatch_label(),
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
# _exit_tree does not invoke this callback, so the stashed settings would stay applied.
func _restore_tutorial_globals() -> void:
	if is_instance_valid($Level):
		$Level.tutorial_hold_dispatch = false
	if _tutorial_saved_level >= 0:
		DeliveremG.starting_level = _tutorial_saved_level
		_tutorial_saved_level = -1
	if _tutorial_saved_packets >= 0:
		DeliveremG.num_packets = _tutorial_saved_packets
		_tutorial_saved_packets = -1

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
	MainGlobals.update_bottom_bar("htfsc")
	MainGlobals.update_bottom_bar(["help","mute","fast","slow","clue"])

func new_game(from_scratch=true):
	if from_scratch:
		_did_per_level_save = false
	show_level()
	hud.new_game(from_scratch)
	game.reset(from_scratch)
	$Level.new_game(from_scratch)
	if from_scratch:
		DeliveremG.save_settings()
		# Log.info("started game %s %d times" % [game.name, game.times_run])		

func _on_level_started_playing() -> void:
	game.playing = true
	hud.restart_time_left_timer()

func _on_game_tick_timeout() -> void:
	game.tick_game_time()
	if game.time_since_saved_ongoing_score_sec() >= 60:
		_save_ongoing_score()

func _on_level_new_packet_message(text: String, isdispatch: bool, col = null) -> void:
	if isdispatch:
		# The line auto-hides after a few seconds in a real round; during the tutorial the coach
		# spends a whole step pointing at it, so it stays until the coach takes it down.
		# `col` is the truck's color, so several orders on screen stay tellable apart.
		hud.dispatch(text, not game.tutorial_mode, col)
	else:
		hud.disp(text, true)

func _on_level_show_reminder(text: Variant) -> void:
	if hud.reminder(text, true):
		hud.add_score_and_time(-2,-10)

func _on_level_pressed_new_game() -> void:
	new_game()

func _on_level_sig_level_is_done(_didwin: bool) -> void:
	if game.playing:
		new_game(false)

func _on_main_menu_menu_start_game(_start_new: bool) -> void:
	DeliveremG.save_settings()
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

func on_update_score_time(score_add, time_add):
	hud.add_score_and_time(score_add, time_add)

func _on_game_sig_level_is_done(_didwin: bool) -> void:
	_did_per_level_save = true
	game.save_score(get_game_score(_didwin, false))

func get_game_score(_didwin, _wasaborted):
	return [_didwin, _wasaborted, $Level.level, $Level.mean_time_to_answer_ms()]

func on_game_is_done(_didwin:bool, _wasaborted:bool):
	game.save_score(get_game_score(_didwin, _wasaborted))

func _save_ongoing_score():
	game.save_ongoing_score(get_game_score(false, false))


# The board's dispatch has to be checked every frame, not on the 0.05 s GameTick timer.
# `tick()` already gates itself on `major_tick_time_ms * time_scale`, so calling it more often
# changes no cadence -- but on the timer, a fire landing just short of the deadline (599.6 ms of
# a 600 ms leg) failed the gate and the next chance was a whole 50 ms later. The agent finished
# its tile and stood still for three frames at 60 fps before the next tile was handed to it,
# which is the intermittent jump players saw on a straight run. Measured in delemfp: 12-13 frozen
# frames per 228 in bursts of 3, down to none.
func _process(_delta: float) -> void:
	if game != null and game.playing and not game.paused():
		$Level.tick()

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
	main_menu.update_val(1, DeliveremG.starting_level)

func on_menu_slider_changed(id, val):
	if id == 1:
		DeliveremG.starting_level = roundi(val)
func add_score_line_vals(score_row: Array) -> Array:
	if score_row.size() > 6:
		var val = score_row[6]
		return [str(int(val)) if not val is String else val]
	return []

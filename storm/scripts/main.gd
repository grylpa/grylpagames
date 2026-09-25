extends Node

@onready var hud = $HUD

var game:GenericGameUtil
var main_menu
var _did_per_level_save: bool = false
# THE WORST ROOM, IN THE HUD STRIP: "Worst: 7%", centered on the strip, at the clock's size and on
# the same 56 px of grey. Storm leaves the strip's middle free (no lives, packets or paired counters). A round
# is lost the moment any room is ruined, so the number that decides it is in front of the player the
# whole time. It was a small label in each room's corner (easy to miss, and out of sight whenever that
# room was), then a line under the strip.
var _flood_label: Label = null
var _flood_accum: int = 0

func _ready() -> void:
	game = StormG.game
	game.initial_score = 100
	randomize()
	RenderingServer.set_default_clear_color(Color.hex(0x3C5D3EFF))
	StormG.load_settings()
	main_menu = game.create_main_menu(self)	
	main_menu.sig_slider_changed.connect(on_menu_slider_changed)
	main_menu.sig_start_game.connect(_on_main_menu_menu_start_game)
	main_menu.add_entry(1, "Level", 1, StormLevelConfig.LEVELS.size(), false)
	refresh_menu()
	show_main_menu()
	$Help.set_texts({
		"F": "Faster",
		"L": "sLower",
		"N": "New game",
	})
	$Help.close_help.connect(_on_help_close_help)
	hud.set_game(game)
	hud.show()
	# hud.show_corrects_mistakes()	
	hud.update_all()
	_flood_label = Label.new()
	# The HUD scene's sizes are phone-first, like every scene's, so this matches the clock's 26 as is.
	_flood_label.add_theme_font_size_override("font_size", 26)
	_flood_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_flood_label.add_theme_constant_override("outline_size", 4)
	_flood_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_flood_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The whole width of the strip, text centered in it.
	_flood_label.position = Vector2.ZERO
	_flood_label.size = Vector2(get_viewport().get_visible_rect().size.x, 56.0)
	_flood_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flood_label.hide()
	hud.add_child(_flood_label)
	game.game_over_on_time_out = false
	game.sig_game_is_done.connect(on_game_is_done)
	game.sig_add_life.connect(on_add_life)

	game.set_instructions("Storm", 
		"There is a storm outside and your old house is leaking badly!\n\n" +
		"You need to protect your belongings using containers and tape.\n\n" + 
		"Use the drains to empty filled containers.\n\n" + 
		"You can work on a problem only if it is close to you.\n\n" +
		"When you are close to a leak, click on it and select the tool to solve it, or click it again to take the filled container for emptying.\n\n" + 
		"When you are close to a drain, click on it and select the tool that needs emptying.\n\n" +
		"The top of the screen shows how much of your wettest room is under water. A round is lost if any room reaches the level's flood line (the level's opening card says where it is), and won when the storm has passed.\n\n" +
		"You start with 100 points. A ruined belonging costs its value: a screen %d, a flower or a rug %d. A container that runs over costs %d. Emptying one that is more than half full earns %d. Getting through the storm earns %d, plus a point for every percent your wettest room stayed under the line. Losing a round costs %d.\n\n" % [
			int($Level.furniture["screen"][1]), int($Level.furniture["flower"][1]), $Level.OVERFLOW_POINTS,
			$Level.DRAIN_POINTS, $Level.WIN_POINTS, $Level.LOSS_POINTS] +
		"Good luck!"
	)
	if !game.shown_instructions:
		game.show_instructions(self)
		StormG.save_settings()		
	game.show_scores_level = true
	game.scores_callback = Callable(self, "add_score_line_vals")

	# Teach instead of showing the menu when the player asked for the tutorial from the
	# chooser's "How to play", OR when this is their first ever run of this game.
	if MainGlobals.take_pending_tutorial("storm") \
			or MainGlobals.take_auto_tutorial("storm", game.shown_instructions):
		call_deferred("start_tutorial")
	MainGlobals.path_tile_size = game.tile_size                                                                                                                                                                                                                                                 
	MainGlobals.path_screen_offset = game.screen_offset                                                                                                                                                                                                                                         
	MainGlobals.path_board_size = game.board_size      
	# Storm's camera follows the player, so the board slides out from under the drawn line
	# the instant it is released. It is a confirmation of the gesture, not a marker.
	MainGlobals.path_fade_sec = 0.18
	$Blackout.hide()
	$Level.sig_blackout.connect(on_show_blackout)
	
func show_main_menu():
	main_menu.show()
	$Level.hide()
	if _flood_label != null:
		_flood_label.hide()
	MainGlobals.draw_path_mode = false
	MainGlobals.update_bottom_bar(["help","mute","scores"])

func show_level():
	get_viewport().gui_release_focus()
	$Level.show()
	main_menu.hide()
	MainGlobals.draw_path_mode = true
	MainGlobals.path_color_probe = $Level.path_color_at
	MainGlobals.update_bottom_bar(["help","fast","slow","mute"])

func new_game(from_scratch=true):
	if from_scratch:
		_did_per_level_save = false
	show_level()
	hud.new_game(from_scratch)
	game.reset(from_scratch)
	$Level.new_game(from_scratch)

func _update_flood_label() -> void:
	_flood_accum += 1
	if _flood_label == null or _flood_accum % 5 != 0:     # four times a second
		return
	var worst: float = $Level.worst_room_share()
	_flood_label.text = "Worst: %d%%" % int(round(worst * 100.0))
	# White while safe, warming toward red as it nears the line.
	var t: float = clampf(worst / $Level.room_ruin(), 0.0, 1.0)
	_flood_label.add_theme_color_override("font_color", Color(1.0, lerpf(1.0, 0.35, t), lerpf(1.0, 0.3, t)))
	_flood_label.show()

func _on_level_started_playing() -> void:
	game.playing = true
	hud.restart_time_left_timer()

func _on_game_tick_timeout() -> void:
	game.tick_game_time()
	if game.playing and not game.paused():
		$Level.tick()
		_update_flood_label()
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
	StormG.save_settings()
	new_game()

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
		$Level.close_inventory()
		$Help.show()

func _on_level_pressed_esc() -> void:
	if $Help.is_visible():
		close_help_window()

func _on_hud_help_button_pressed() -> void:
	$Level.close_inventory()
	$Help.show()

func _on_level_delivered_one() -> void:
	hud.delivered_one()

func _on_level_collision() -> void:
	hud.collided()

func _on_level_update_score(_score_add:int):
	hud.add_score_and_time(_score_add, 0)

func _on_hud_start_game() -> void:
	new_game(true)

func get_game_score(_didwin, _wasaborted):
	return [_didwin, _wasaborted, $Level.level]

func on_game_is_done(_didwin:bool, _wasaborted:bool):
	_did_per_level_save = true
	game.save_score(get_game_score(_didwin, _wasaborted))

func _save_ongoing_score():
	game.save_ongoing_score(get_game_score(false, false))

func on_add_life():
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
		game.handle_event(event,$Level)

var _tutorial_saved_level: int = -1

# The real level with the real rules, scored by nobody: TutorialRunner puts the game into
# tutorial_mode, which suppresses every write in generic_game_util.gd until the tutorial ends.
func start_tutorial() -> void:
	var tut: Script = load("res://storm/scripts/tutorial.gd")
	# BEFORE new_game(): new_game() -> game.reset(true) -> convert_ongoing_score_to_permanent(),
	# which would commit and upload the player's unfinished real session.
	game.begin_tutorial()
	# starting_level lives on StormG, not the game util, so the snapshot does not cover it.
	_tutorial_saved_level = StormG.starting_level
	StormG.starting_level = tut.tutorial_level_id()
	new_game()
	var runner: TutorialRunner = TutorialRunner.new()
	runner.run(self, tut.steps($Level, game), game, Callable(self, "_on_tutorial_done"))

func _on_tutorial_done(_completed: bool) -> void:
	_restore_tutorial_globals()
	game.playing = false
	game.level_is_ready = false
	refresh_menu()
	show_main_menu()

# Also called from _exit_tree: leaving the game mid-tutorial frees the scene, and the runner's
# own _exit_tree does not invoke this callback — so without it the tutorial's stashed values
# stayed applied to the player's real settings.
func _restore_tutorial_globals() -> void:
	if _tutorial_saved_level >= 0:
		StormG.starting_level = _tutorial_saved_level
		_tutorial_saved_level = -1

func _exit_tree() -> void:
	_restore_tutorial_globals()
func refresh_menu():
	main_menu.update_val(1, StormG.starting_level)

func on_menu_slider_changed(id, val):
	if id == 1:
		StormG.starting_level = roundi(val)
		StormG.save_settings()

func on_show_blackout():
	game.play_sound("thunder")
	$Blackout.show()
	await MainGlobals.sleep(0.03)
	$Blackout.hide()
	await MainGlobals.sleep(0.06)
	$Blackout.show()
	await MainGlobals.sleep(0.16)
	$Blackout.hide()

func add_score_line_vals(score_row: Array) -> Array:
	if score_row.size() > 6:
		var val = score_row[6]
		return [str(int(val)) if not val is String else val]
	return []

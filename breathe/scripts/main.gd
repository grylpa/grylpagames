extends Node

var game: GenericGameUtil
var main_menu
var _did_per_level_save: bool = false

const POS_DURATION_MIN: int = 6
const POS_MEAN_INTERVAL_MS: int = 7
const POS_BPM: int = 8
const POS_NUM_TAPS: int = 9
const POS_MISSED_BREATHS: int = 10

func _ready() -> void:
	game = BreatheG.game
	BreatheG.load_settings()
	main_menu = game.create_main_menu(self)

	main_menu.sig_start_game.connect(_on_main_menu_start_game)
	main_menu.sig_slider_changed.connect(_on_menu_slider_changed)
	main_menu.sig_option_changed.connect(_on_menu_option_changed)
	main_menu.add_entry(1, "Duration (min)", 1, 15, false)
	main_menu.add_option_entry(2, "Ambient", _build_ambient_options())
	refresh_menu()
	show_main_menu()

	$Help.set_texts({"N": "New session"})
	$Help.close_help.connect(_on_help_close)

	game.set_instructions("Breathe",
		"Tap once at the end of each exhale.\n" +
		"Try to keep a steady rhythm.\n" +	
		"When the session ends you'll see\n" +
		"your consistency stats.",
		36 if MainGlobals.is_mobile() else 22)
	if not game.shown_instructions:
		game.show_instructions(self)
		BreatheG.save_settings()

	main_menu.show_continue_and_start_new(false)
	game.scores_callback = Callable(self, "add_score_line_vals")
	game.progress_score_label = "Consistency"
	var level_names: Dictionary = {}
	for m: int in range(1, 16):
		level_names[m] = "%d min" % m
	game.progress_level_names = level_names
	game.show_scores_level = false
	game.show_scores_time = false
	game.progress_level_pos = POS_DURATION_MIN
	game.progress_time_pos = POS_MEAN_INTERVAL_MS
	game.progress_time_label = "Avg Interval"
	game.progress_time_format = "%d ms"
	game.progress_pct_pos = POS_MISSED_BREATHS
	game.progress_pct_label = "Missed"
	game.progress_pct_format = "%d"
	game.progress_pct_integer = true

	$Level.sig_session_done.connect(_on_level_session_done)
	$Level.sig_show_main_menu.connect(_on_level_show_main_menu)

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
	MainGlobals.update_bottom_bar(["menu", "mute"])
	MainGlobals.add_action_button(null)

func new_game(_from_scratch: bool = true) -> void:
	_did_per_level_save = false
	game.reset(true)
	show_level()
	$Level.new_game()
	_start_ambient_sound()

func _on_level_session_done() -> void:
	_did_per_level_save = true
	game.save_score($Level.get_session_score(true, false))

func _on_level_show_main_menu() -> void:
	game.playing = false
	game.stop_sound("ambient")
	show_main_menu()
	game.clear_ongoing_score()

func _on_main_menu_start_game(_start_new: bool) -> void:
	BreatheG.save_settings()
	new_game()

func _on_help_close() -> void:
	game.pause(false)
	$Help.hide()

func _on_hud_start_game() -> void:
	new_game()

func add_score_line_vals(score_row: Array) -> Array:
	var res: Array = []
	if score_row.size() > POS_DURATION_MIN:
		res.append("%d min" % [int(score_row[POS_DURATION_MIN])])
	if score_row.size() > POS_BPM:
		res.append("%.1f bpm" % [float(score_row[POS_BPM])])
	if score_row.size() > POS_MEAN_INTERVAL_MS:
		res.append("%.1f s" % [float(score_row[POS_MEAN_INTERVAL_MS]) / 1000.0])
	return res

func refresh_menu() -> void:
	main_menu.update_val(1, BreatheG.duration_min)
	main_menu.update_option(2, BreatheG.ambient_sound_idx)

func _build_ambient_options() -> Array:
	var opts: Array = []
	for entry in BreatheG.AMBIENT_SOUNDS:
		opts.append(entry[0])
	return opts

func _start_ambient_sound() -> void:
	var idx: int = BreatheG.ambient_sound_idx
	if idx <= 0 or idx >= BreatheG.AMBIENT_SOUNDS.size():
		return
	var path: String = BreatheG.AMBIENT_SOUNDS[idx][1]
	game.add_sound(self, "ambient", load(path), true)
	game.play_sound("ambient")

func _on_menu_option_changed(id: int, idx: int) -> void:
	if id == 2:
		BreatheG.ambient_sound_idx = idx
		BreatheG.save_settings()

func _on_menu_slider_changed(id: int, val: float) -> void:
	if id == 1:
		BreatheG.duration_min = roundi(val)
		refresh_menu()

func _input(event: InputEvent) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if game.handle_main_menu(self, event, _on_level_show_main_menu):
		pass
	elif event.is_action_pressed("help"):
		$Help.show()
	elif event.is_action_pressed("esc"):
		if $Help.is_visible():
			_on_help_close()
	elif event.is_action_pressed("new_board"):
		new_game()
	elif event.is_action_pressed("lost_focus"):
		game.in_focus = false
	elif event.is_action_pressed("resumed_focus"):
		game.in_focus = true
	else:
		game.handle_event(event, self)

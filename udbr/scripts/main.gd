extends Node

var game: GenericGameUtil
var main_menu
var _did_per_level_save: bool = false

const POS_DURATION_MIN: int = 6
const POS_MEAN_INTERVAL_MS: int = 7
const POS_BPM: int = 8
const POS_NUM_REVERSALS: int = 9
const POS_MISSED_CYCLES: int = 10

func _ready() -> void:
	game = UdbrG.game
	MainGlobals.digitized_swipe_mode = true
	UdbrG.load_settings()
	main_menu = game.create_main_menu(self)

	main_menu.sig_start_game.connect(_on_main_menu_start_game)
	main_menu.sig_slider_changed.connect(_on_menu_slider_changed)
	main_menu.sig_option_changed.connect(_on_menu_option_changed)
	main_menu.add_entry(1, "Duration (min)", 1, 15, false)
	main_menu.add_option_entry(2, "Mode", _build_mode_options())
	main_menu.add_option_entry(3, "Ambient", _build_ambient_options())
	refresh_menu()
	show_main_menu()

	$Help.set_texts({"N": "New session"})
	$Help.close_help.connect(_on_help_close)

	game.set_instructions("Up Down Breathe",
		"Swipe UP while inhaling.\n" +
		"Swipe DOWN while exhaling.\n" +
		"Keep touching while hold your breath between inhaling and exhaling.\n" +
		"Keep a steady, continuous rhythm.\n" +
		"When the session ends you'll see\n" +
		"your consistency stats and a trace\n" +
		"of your breathing pattern.\n\n" +
		"or\n\n" +
		"Activate a guided session and match your breathing to it.",
		36 if MainGlobals.is_mobile() else 22)
	if not game.shown_instructions:
		game.show_instructions(self)
		UdbrG.save_settings()

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
	game.progress_pct_pos = POS_MISSED_CYCLES
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
	$Level.guided_mode = UdbrG.guided_mode
	$Level.new_game()
	_start_ambient_sound()

func _on_level_session_done() -> void:
	_did_per_level_save = true
	game.save_score($Level.get_session_score(true, false))
	var saved: bool = false
	var kbd_phases: Array = $Level.get_kbd_phases()
	if kbd_phases.size() >= 4:
		UdbrG.learned_inhale_ms = kbd_phases[0]
		UdbrG.learned_hold_top_ms = kbd_phases[1]
		UdbrG.learned_exhale_ms = kbd_phases[2]
		UdbrG.learned_hold_bottom_ms = kbd_phases[3]
		saved = true
	else:
		var durations: Dictionary = $Level.get_mean_phase_durations()
		if durations.get("valid", false):
			UdbrG.learned_inhale_ms = durations["inhale_ms"]
			UdbrG.learned_exhale_ms = durations["exhale_ms"]
			UdbrG.learned_hold_top_ms = durations["hold_top_ms"]
			UdbrG.learned_hold_bottom_ms = durations["hold_bottom_ms"]
			saved = true
	if saved:
		UdbrG.has_user_session = true
		UdbrG.save_settings()
		_rebuild_mode_options()

func _on_level_show_main_menu() -> void:
	game.playing = false
	game.stop_sound("ambient")
	show_main_menu()
	game.clear_ongoing_score()

func _on_main_menu_start_game(_start_new: bool) -> void:
	UdbrG.save_settings()
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
	main_menu.update_val(1, UdbrG.duration_min)
	main_menu.update_option(2, _mode_to_option_idx())
	main_menu.update_option(3, UdbrG.ambient_sound_idx)

func _rebuild_mode_options() -> void:
	main_menu.set_option_items(2, _build_mode_options())
	main_menu.update_option(2, _mode_to_option_idx())

func _fv(v) -> String:
	var r: float = round(float(v) * 2.0) / 2.0
	if r == int(r):
		return str(int(r))
	var whole: int = int(r)
	return ("" if whole == 0 else str(whole)) + "½"

func _build_mode_options() -> Array:
	var opts: Array = ["Active"]
	if UdbrG.has_user_session:
		opts.append("User %s-%s-%s-%s" % [
			_fv(UdbrG.learned_inhale_ms / 1000.0),
			_fv(UdbrG.learned_hold_top_ms / 1000.0),
			_fv(UdbrG.learned_exhale_ms / 1000.0),
			_fv(UdbrG.learned_hold_bottom_ms / 1000.0)])
	for p in UdbrG.GUIDED_PRESETS:
		opts.append("Guided %s-%s-%s-%s" % [_fv(p[0]), _fv(p[1]), _fv(p[2]), _fv(p[3])])
	return opts

func _mode_to_option_idx() -> int:
	if UdbrG.selected_mode == 0:
		return 0
	if not UdbrG.has_user_session:
		if UdbrG.selected_mode == 1:
			return 0
		return UdbrG.selected_mode - 1
	return UdbrG.selected_mode

func _option_idx_to_mode(idx: int) -> int:
	if idx == 0:
		return 0
	if UdbrG.has_user_session:
		return idx
	return idx + 1

func _on_menu_slider_changed(id: int, val: float) -> void:
	if id == 1:
		UdbrG.duration_min = roundi(val)
		refresh_menu()

func _build_ambient_options() -> Array:
	var opts: Array = []
	for entry in UdbrG.AMBIENT_SOUNDS:
		opts.append(entry[0])
	return opts

func _start_ambient_sound() -> void:
	var idx: int = UdbrG.ambient_sound_idx
	if idx <= 0 or idx >= UdbrG.AMBIENT_SOUNDS.size():
		return
	var path: String = UdbrG.AMBIENT_SOUNDS[idx][1]
	game.add_sound(self, "ambient", load(path), true)
	game.play_sound("ambient")

func _on_menu_option_changed(id: int, idx: int) -> void:
	if id == 2:
		UdbrG.selected_mode = _option_idx_to_mode(idx)
		UdbrG.save_settings()
	elif id == 3:
		UdbrG.ambient_sound_idx = idx
		UdbrG.save_settings()

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

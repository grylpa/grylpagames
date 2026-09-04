class_name GenericGameUtil

var initial_score := 0
var score := 0
var score_was_changed := false
var playing := false
var _pause := false
var name := "Gpa"
var file_names_prefix := "gpa"
var times_run := 0
var _reset_lives_val := 3
var lives_left := _reset_lives_val
var count_lives := false
var level_is_ready := false
var need_to_increase_level := false
var level_is_done := false
var _reset_packets_left := 7
var packets_left := _reset_packets_left
var shown_instructions := false
# TUTORIAL MODE. While this is true, nothing the player does may reach the scores — not the local
# files, not the backend. Every write in this file is guarded on it (see `begin_tutorial`), which
# is why no game's main.gd has to know about it: the 33 copies of the 60s autosave tick and every
# save_score call site are covered at the choke point.
var tutorial_mode: bool = false
var _tutorial_snapshot: Dictionary = {}
# Set by the tutorial overlay while it runs, so `tutorial_notify` can reach it. Untyped because
# GenericGameUtil is a RefCounted and must not depend on a scene script.
var tutorial_runner = null
var sounds = {}
var sounds_resource_list = {}
var in_focus := true
var corrects := 0
var mistakes := 0
var show_scores_level := false
var show_scores_time := false
var show_scores_level_as_name := false
var scores_time_col_name: String = "Avg Time"
var progress_level_pos := -1
var progress_time_pos := -1
var progress_pct_pos := -1
var progress_level_names: Dictionary = {}
var progress_score_label: String = "Score"
var progress_pct_label: String = "% Correct"
var progress_pct_format: String = "%d"
var progress_pct_integer: bool = false
var progress_time_label: String = "Avg Time"
var progress_time_format: String = "%d"
var progress_time_is_pct: bool = false
var progress_tab_name: String = ""
# The monotonic "personal best" filter is the right frame for a SCORE and the wrong one for a
# breathing session: steadiness is not a record to beat, and presenting it as one pushes against
# what the four calm games are for. They set this false.
var show_monotonic_toggle: bool = true
var zoomed_in := false

var game_over_on_time_out := true
# A session clock only means something if the game RUNS it: `game.playing = true` plus
# `hud.restart_time_left_timer()`, after which it counts down and ends the session at zero (see
# whack). A game that never does that still gets the countdown drawn in the HUD and a "Time left"
# line in its summary — both frozen at the starting value, a number that looks like a limit and
# is not one. Such a game declares itself here instead.
var uses_session_clock: bool = true
var game_over_on_zero_score := false
var time_left_sec:int = 300
var _reset_time_left_sec := time_left_sec

# couples are score, time
var score_for_deliver_one := [10, 10]
var score_for_collision := [-1, -10]

var rng := RandomNumberGenerator.new()

var screen_size: Vector2i
var tile_size := 40
var board_size: Vector2i
var max_board_size := Vector2i(0,0)
var screen_offset := Vector2i(0,0)
var forced_board_size := Vector2i(0,0)
var header_height = 60
var buttons_height = 40

var next_color_idx := 0

var bkcolor := 0x3C5D3E
var major_tick_time_ms := 600
var time_to_increase_difficulty_s := 60
var time_scale := 1.0
var time_to_auto_start_moving_ms := 5000
var time_last_saved_ongoing_score := 0

# Every open scores window joins this group, so a second open can tell one is already up.
const SCORES_GROUP: StringName = &"scores_window"
var scores_scene = preload("res://scenes/scores_list.tscn")
var instructions_scene: PackedScene = load("res://scenes/instructions_popup.tscn")
var level_done_popup_scene: PackedScene = load("res://scenes/level_done_popup.tscn")
var game_popup_scene: PackedScene = load("res://scenes/game_popup.tscn")
var main_menu_scene: PackedScene = load("res://scenes/main_menu.tscn")
var conformation_dlg: PackedScene = load("res://scenes/gpa_conf_dlg.tscn")

signal sig_lives_depleted
signal sig_time_over
signal sig_game_is_done(_didwin:bool, _wasaborted:bool)
signal sig_add_life
signal sig_no_more_packets
signal sig_esc_pressed
signal sig_save_game
signal sig_level_is_done
signal sig_level_label_changed(level_text:String)

const DirArray = [Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0), Vector2i(0,-1)]

var kellys_colors: Array[Color] = [
	Color("#ffd600"), # Vivid Yellow
	Color("#800080"), # Strong Purple
	Color("#ff8000"), # Vivid Orange
	Color("#87cefa"), # Very Light Blue
	Color("#bf0026"), # Vivid Red
	Color("#c2b380"), # Grayish Yellow
	Color("#808080"), # Medium Gray
	Color("#008000"), # Vivid Green
	Color("#cc99cc"), # Light Purplish Pink
	Color("#0000ff"), # Strong Blue
	Color("#996633"), # High Saturation Brown
	Color("#ff4d4d"), # Vivid Purplish Red
	Color("#1a331a"), # Dark Olive Green
	Color("#ffbf66"), # Orangish Yellow
	Color("#66001a"), # Dark Purplish Red
	Color("#e6e600"), # Greenish Yellow
	Color("#803300"), # Reddish Brown
	Color("#99cc33"), # Vivid Greenish Yellow
	Color("#004d33"), # Deep Yellowish Green
	Color("#338080")  # Blue Green
]

# Sasha Trubetskoy's 12 High-Contrast Colors
var PALETTE_TRUBETSKOY: Array[Color] = [
	Color("#e6194b"), # Red
	Color("#3cb44b"), # Green
	Color("#ffe119"), # Yellow
	Color("#4363d8"), # Blue
	Color("#f58231"), # Orange
	Color("#911eb4"), # Purple
	Color("#42d4f4"), # Cyan
	Color("#f032e6"), # Magenta
	Color("#bfef45"), # Lime
	Color("#fabed4"), # Pink
	Color("#469990"), # Teal
	Color("#dcbeff")  # Lavender
]

# Paul Tol's Qualitative Palette (Extended to 12)
var PALETTE_PAUL_TOL: Array[Color] = [
	Color("#77AADD"), # Light Blue
	Color("#EE8866"), # Apricot
	Color("#EEDD88"), # Light Yellow
	Color("#FFAABB"), # Pink
	Color("#99DDFF"), # Light Cyan
	Color("#44BB99"), # Pear Green
	Color("#808000"), # Olive  (was #BBCC33: only dE2000 13.5 from Yellow, i.e. the same color)
	Color("#AAAA00"), # Ochre
	Color("#DDDDDD"), # Light Gray
	Color("#0077BB"), # Blue
	Color("#332288"), # Indigo
	Color("#882255")  # Wine
]

var simple_colors: Array[Color] = [
	Color("#ff4d4d"), # Soft Red
	Color("#00ff00"), # Pure Green
	Color("#9999ff"), # Soft Blue
	Color("#ffff00"), # Pure Yellow
	Color("#ff4dff"), # Magenta
	Color("#00ffff"), # Cyan
	Color("#80ff00"), # Lime Green
	Color("#ff8000"), # Orange
	Color("#009999"), # Dark Teal
	Color("#0080ff"), # Azure Blue
	Color("#ff0080"), # Rose
	Color("#8000ff")  # Violet
]

# Agent/room colors. Two of these can end up side by side — several trucks out at once in
# deliverem, adjacent rooms in mmm/gorilla/storm/wolves — so every pair has to be tellable apart.
# Measured with CIEDE2000, where under ~20 reads as "similar" and under ~12 as "the same color".
# The closest remaining pairs are Orange/Brown 20.3, Purple/Magenta 21.1, Blue/Purple 21.8: all
# distinguishable, all in a related hue family. Pushing higher means giving up recognizable colors
# for grays and neons, so it stops here.
var colors: Array[Color] = [
	Color("#e6194b"), # Red
	Color("#3cb44b"), # Green
	Color("#ffe119"), # Yellow
	Color("#4363d8"), # Blue
	Color("#f58231"), # Orange
	Color("#911eb4"), # Purple
	Color("#42d4f4"), # Cyan
	Color("#f032e6"), # Magenta
	Color("#fabed4"), # Pink
	Color("#BBCC33"), # Olive
	Color("#004d33"), # Deep Yellowish Green
	Color("#996633"), # High Saturation Brown
	Color("#ffffff"), # White
	# Color("#8D8D8D"), # Light Gray
	
]
func generate_contrast_colors(count: int) -> Array:
	var _colors = []
	var h = randf()
	var golden_ratio_conjugate = 0.618033988749895
	
	for i in range(count):
		h = fmod(h + golden_ratio_conjugate, 1.0)
		# We keep Saturation and Value high for "gamey" bright colors
		_colors.append(Color.from_hsv(h, 0.7, 0.9))
		
	return _colors

func generate_super_contrast_colors(count: int) -> Array:
	var _colors = []
	var h = 0.0 # Starting hue
	var golden_ratio_conjugate = 0.618033988749895
	
	for i in range(count):
		# 1. Shift Hue using Golden Ratio
		h = fmod(h + golden_ratio_conjugate, 1.0)
		
		# 2. Vary Saturation (High vs. Medium)
		# We alternate so adjacent hues look physically different
		var s = 0.85 if (i % 2 == 0) else 0.5
		
		# 3. Vary Value (Bright vs. Darker)
		# We use a pattern of 3 to ensure it doesn't sync perfectly with Saturation
		var v = 0.95 if (i % 3 != 0) else 0.6
		
		_colors.append(Color.from_hsv(h, s, v))
		
	return _colors

var stored_ongoing_score

func _init(_name, _file_names_prefix, h,m,s, player_lives_on_start:int = 0) -> void:
	name = _name
	file_names_prefix = _file_names_prefix
	set_time_left(h,m,s)
	_reset_time_left_sec = time_left_sec
	count_lives = player_lives_on_start > 0
	if count_lives:
		_reset_lives_val = player_lives_on_start
		lives_left = _reset_lives_val
	packets_left = _reset_packets_left
	next_color_idx = rng.randi() % colors.size()
	read_ongoing_score()

func time_since_saved_ongoing_score_sec():
	var t = MainGlobals.timems()
	return int((t - time_last_saved_ongoing_score) / 1000)

var file_ver = 5

func level_label_changed(level_text:String):
	sig_level_label_changed.emit(level_text)
	
func emit_sig_level_is_done(_didwin: bool) -> void:
	sig_level_is_done.emit(_didwin)
	
func add_life():
	sig_add_life.emit()
	
func get_settings_fname():
	var key: String = MainGlobals.user_file_key if MainGlobals != null else "guest"
	return "user://settings_v" + str(file_ver) + "_" + key + "_" + file_names_prefix + ".gpa"

# SCORES are versioned separately from settings on purpose.
#
# v6 changed a session from a positional array to a named dictionary, which the old history cannot
# be converted into — the fields it would need were never recorded. But `file_ver` also names the
# SETTINGS and game-data files, so bumping it would have thrown away every game's starting level and
# options too. The player agreed to lose score history, not their preferences, so scores carry their
# own number and settings stay on v5. See StatsMigration.
var scores_ver: int = 6

func get_scores_fname():
	var key: String = MainGlobals.user_file_key if MainGlobals != null else "guest"
	return "user://scores_v" + str(scores_ver) + "_" + key + "_" + file_names_prefix + ".gpa"

func get_ongoing_score_fname():
	var key: String = MainGlobals.user_file_key if MainGlobals != null else "guest"
	return "user://ongoing_score_v" + str(scores_ver) + "_" + key + "_" + file_names_prefix + ".gpa"

func get_uploaded_scores_fname() -> String:
	var key: String = MainGlobals.user_file_key if MainGlobals != null else "guest"
	return "user://uploaded_v5_" + key + "_" + file_names_prefix + ".gpa"

func read_uploaded_scores() -> Dictionary:
	var path: String = get_uploaded_scores_fname()
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data = file.get_var()
	file.close()
	if data is Dictionary:
		return data
	return {}

func mark_scores_uploaded(ts_list: Array) -> void:
	var uploaded: Dictionary = read_uploaded_scores()
	for ts in ts_list:
		uploaded[int(ts)] = true
	var path: String = get_uploaded_scores_fname()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_var(uploaded)
		file.close()

func get_game_data_fname():
	return "user://game_data_v" + str(file_ver) + "_" + file_names_prefix + ".gpa"

func _new_best_flag_path() -> String:
	var key: String = MainGlobals.user_file_key if MainGlobals != null else "guest"
	return "user://new_best_v1_" + key + "_" + file_names_prefix + ".gpa"

func reset_local_scores() -> void:
	stored_ongoing_score = null
	score_was_changed = false
	for path: String in [get_scores_fname(), get_ongoing_score_fname(), get_uploaded_scores_fname(), _new_best_flag_path()]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _write_new_best_flag(v: bool) -> void:
	if tutorial_mode:
		return
	var f = FileAccess.open(_new_best_flag_path(), FileAccess.WRITE)
	if f:
		f.store_8(1 if v else 0)
		f.close()

func has_new_best_flag() -> bool:
	if not FileAccess.file_exists(_new_best_flag_path()):
		return false
	var f = FileAccess.open(_new_best_flag_path(), FileAccess.READ)
	if not f:
		return false
	var v = f.get_8()
	f.close()
	return v == 1

func read_ongoing_score():
	if !name:
		return
	var path = get_ongoing_score_fname()
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file == null:
			return []
		var rec = file.get_var()
		file.close()
		# v6 writes a Dictionary. An Array here is a v5 leftover that StatsMigration should already
		# have removed, so it is ignored rather than trusted.
		if rec is Dictionary and not rec.is_empty():
			stored_ongoing_score = rec
			return rec
	return {}

func clear_ongoing_score():
	# In a tutorial this would erase a real session that is still in progress.
	if tutorial_mode:
		return
	stored_ongoing_score = {}
	# Log.dbg(name + ": clearing ongoing")
	var save_path = get_ongoing_score_fname()
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_var({})
		file.close()
		time_last_saved_ongoing_score = MainGlobals.timems()

func save_ongoing_score(score_array:Array):
	if tutorial_mode:
		return
	if not score_was_changed:
		return
	var save_path = get_ongoing_score_fname()
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		stored_ongoing_score = _build_session_record(score_array)
		# Log.dbg(name + ": saving ongoing: ", stored_ongoing_score)
		file.store_var(stored_ongoing_score)
		file.close()
		time_last_saved_ongoing_score = MainGlobals.timems()

func save_game_data(data: Dictionary):
	var save_path = get_game_data_fname()
	var f = FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_var(data)
		# f.store_string(JSON.stringify(data, "\t"))
		f.close()

func load_game_data() -> Dictionary:
	var path = get_game_data_fname()
	if FileAccess.file_exists(path):
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f == null:
			return {}
		var data = f.get_var()
		# var text: String = f.get_as_text()
		f.close()
		# var data: Variant = JSON.parse_string(text)
		if typeof(data) == TYPE_DICTIONARY:
			var dict: Dictionary = data
			return dict
	return {}
		
func strtime_compact(unixtime):
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unixtime)
	var strdt := "%04d%02d%02d_%02d%02d%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
	return strdt

func strtime(unixtime):
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unixtime)
	var strdt := "%04d/%02d/%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]
	return strdt

# The legacy positional view of the saved sessions.
#
# Sessions are stored as named dictionaries now (see _build_session_record), but the existing scores
# window reads rows by index. Rather than rewrite that screen and the storage in one step, this
# rebuilds the old shape from the new record — so the app keeps working at every point of the
# migration, and the screen can move to `read_sessions()` on its own schedule.
# A v6 record as the positional row the scores window and the per-game callbacks still expect.
func _legacy_row(rec: Dictionary) -> Array:
	var row: Array = [
		int(rec.get("ts", 0)),
		int(rec.get("score", 0)),
		int(rec.get("time_left", 0)),
		int(rec.get("times_run", 0)),
	]
	for col in score_columns:
		if not rec.has(col):
			break
		row.append(rec[col])
	return row

func read_scores():
	var scores: Array = []
	for rec: Dictionary in read_sessions():
		scores.append(_legacy_row(rec))
	return scores

func save_settings(settings_array:Array, version:int=1):
	# This file carries `times_run` and `shown_instructions` alongside the per-game settings, so a
	# tutorial must not write it. The "player has seen the tutorial offer" flag is app-level, kept
	# in MainGlobals.save_settings() instead.
	if tutorial_mode:
		return
	var save_path = get_settings_fname()
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_32(version)
		file.store_var(settings_array)
		file.store_32(times_run)
		file.store_32(int(shown_instructions))
		file.close()

func read_settings(version:int=1):
	var path = get_settings_fname()
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var settings_array = []
			var read_version = file.get_32()
			if read_version == version:
				settings_array = file.get_var()
				if not file.eof_reached() and file.get_position() < file.get_length():
					times_run = file.get_32()
				if not file.eof_reached() and file.get_position() < file.get_length():
					shown_instructions = bool(file.get_32())
			file.close()
			if not (settings_array is Array):
				return []
			if not shown_instructions and FileAccess.file_exists(get_scores_fname()):
				shown_instructions = true
				save_settings(settings_array)
			return settings_array
	if FileAccess.file_exists(get_scores_fname()):
		shown_instructions = true
	return []

func mark_time_over():
	sig_time_over.emit()

func mark_lives_depleted():
	sig_lives_depleted.emit()

func set_reset_time_left(_value_to_use:int):
	_reset_time_left_sec = _value_to_use

func reset_time_left():
	time_left_sec = _reset_time_left_sec

func paused() -> bool:
	var is_paused: bool = _pause or MainGlobals.any_screen_visible() or !in_focus or !playing
	if is_paused and _pause_start_ms == 0:
		_pause_start_ms = MainGlobals.timems()
	elif not is_paused and _pause_start_ms > 0:
		_total_paused_ms += MainGlobals.timems() - _pause_start_ms
		_pause_start_ms = 0
	return is_paused

# --- Tutorial mode ----------------------------------------------------------
#
# A tutorial plays the REAL game, so it mutates the same in-memory session state a real run does.
# Guarding the writes alone is not enough: the player may have a half-finished real session sitting
# in memory (and in the ongoing-score file) when they go take a tutorial, and it has to come back
# untouched. So begin/end snapshot and restore that state, and the guards make sure nothing leaked
# to disk in between.
#
# `stored_ongoing_score` is the important one in the snapshot — the two
# `convert_ongoing_score_to_permanent` call sites would otherwise commit and upload the player's
# last unfinished real session as a side effect of entering or leaving a tutorial.
const _TUTORIAL_SAVED_VARS: Array = [
	"score", "score_was_changed", "times_run", "corrects", "mistakes",
	"playing", "level_is_ready", "level_is_done", "need_to_increase_level",
	"time_left_sec", "_reset_time_left_sec", "lives_left", "_reset_lives_val",
	"packets_left", "_reset_packets_left", "game_over_on_time_out", "game_over_on_zero_score",
	"_pause", "time_scale", "shown_instructions", "stored_ongoing_score",
]

func begin_tutorial() -> void:
	if tutorial_mode:
		return
	_tutorial_snapshot = {}
	for var_name: String in _TUTORIAL_SAVED_VARS:
		_tutorial_snapshot[var_name] = get(var_name)
	tutorial_mode = true

func end_tutorial() -> void:
	if not tutorial_mode:
		return
	# Clear the flag first: restoring is plain assignment, but anything that runs off the back of
	# it should already see a normal game.
	tutorial_mode = false
	tutorial_runner = null
	for var_name: String in _TUTORIAL_SAVED_VARS:
		if _tutorial_snapshot.has(var_name):
			set(var_name, _tutorial_snapshot[var_name])
	_tutorial_snapshot = {}
	playing = false

# End a running tutorial from outside it — used when the player leaves the level for the main menu.
# Safe to call at any time: a no-op when nothing is running, and abort() is itself idempotent.
func abort_tutorial() -> void:
	if tutorial_runner != null and is_instance_valid(tutorial_runner):
		tutorial_runner.abort()

# Games call this at their existing decision points (e.g. right after an answer is judged) to tell
# a running tutorial that something happened. A no-op outside tutorial mode, so it is safe to leave
# in the normal gameplay path.
func tutorial_notify(event_name: String) -> void:
	if not tutorial_mode or tutorial_runner == null:
		return
	if not is_instance_valid(tutorial_runner):
		tutorial_runner = null
		return
	tutorial_runner.notify(event_name)

# Accuracy over the level just played, from the same two counters the HUD shows. Games that keep
# their own per-level tally have a pct_correct() of their own; this is for the ones that do not,
# so a level gate does not need bespoke bookkeeping in every game.
#
# Both counters are cleared at the start of each level by the games that gate on them, so this is
# the LEVEL's accuracy and not the session's.
func session_pct_correct() -> int:
	var total: int = corrects + mistakes
	if total <= 0:
		return 0
	return int(round(100.0 * float(corrects) / float(total)))

func reset(from_scratch:bool):
	playing = false
	_pause = false
	next_color_idx = rng.randi() % colors.size()
	level_is_ready = false
	level_is_done = false
	_game_start_ms = MainGlobals.timems()
	_total_paused_ms = 0
	_pause_start_ms = 0
	MainGlobals.kill_active_tweens()
	MainGlobals.reset_swipe_state()
	if from_scratch:
		score = initial_score
		score_was_changed = false
		reset_time_left()
		time_scale = 1.0
		# times_run is stamped into every future score row and into the settings file, so a
		# tutorial must not inflate it. (end_tutorial restores it too, belt and braces.)
		if not tutorial_mode:
			times_run += 1
		corrects = 0
		mistakes = 0
		need_to_increase_level = false
		# A new session starts with no carried-over measurements, and its clock starts here. Done
		# centrally so no game has to remember to do it — the previous session's numbers leaking
		# into the next one would be invisible and would quietly corrupt a trend.
		clear_session_metrics()
		clear_trials()
		mark_session_start()
		convert_ongoing_score_to_permanent()

func set_time_left(h,m,s):
	time_left_sec = (h * 60 + m) * 60 + s
	if MainGlobals:
		MainGlobals.sig_global_update_hud.emit()

func add_score_and_time(add_score: int, add_time: int, is_actual_score:bool = true):
	score = max(0, score + add_score)
	if is_actual_score:
		score_was_changed = true
	time_left_sec = max(0, time_left_sec + add_time)
	MainGlobals.sig_global_update_hud.emit()
	if game_over_on_zero_score and score <= 0:
		game_is_done(false, false)

func add_correct_or_mistake(_corrects:int, _mistakes:int):
	corrects += _corrects
	mistakes += _mistakes
	MainGlobals.sig_global_update_hud.emit()
	
func did_time_run_out():
	return time_left_sec <= 0

func kill_and_did_lives_run_out():
	if count_lives:
		if lives_left <= 1:
			lives_left = 0
			return true
		lives_left -= 1
	return false

func get_board_part_of_width(ntiles := 0):
	var actual_board_width_px:float = board_size.x * tile_size
	if ntiles > 0:
		actual_board_width_px = ntiles * tile_size
	elif ntiles < 0:
		actual_board_width_px = (board_size.x + ntiles*2) * tile_size
	return actual_board_width_px / MainGlobals.screen_size.x

func get_board_part_of_height(ntiles := 0, top_margin := 4, bottom_margin := 4):
	var m = top_margin + bottom_margin
	var actual_board_py:float = board_size.y * tile_size + m
	if ntiles > 0:
		actual_board_py = ntiles * tile_size + m
	elif ntiles < 0:
		actual_board_py = (board_size.y + ntiles*2) * tile_size + m
	return actual_board_py / get_visible_height()

func get_tiles_in_screen_height():
	return get_visible_height() / tile_size

func get_tiles_in_screen_width():
	return MainGlobals.screen_size.x / tile_size

func init_sizes():
	if has_new_best_flag():
		MainGlobals.sig_new_best_score.emit()
	screen_size = MainGlobals.screen_size
	board_size = Vector2i((screen_size - Vector2i(0,header_height + buttons_height)) / tile_size)
	var size_before_max = board_size
	if forced_board_size.length() > 0:
		board_size = forced_board_size
	else:
		if max_board_size.x > 0:
			board_size.x = min(board_size.x, max_board_size.x)
		if max_board_size.y > 0:
			board_size.y = min(board_size.y, max_board_size.y)
	screen_offset = (size_before_max - board_size) * tile_size / 2
	# screen_offset.y = 0
	# screen_offset.y = min(screen_offset.y, tile_size)
	if MainGlobals.path_tile_size > 0:
		MainGlobals.path_tile_size = tile_size
		MainGlobals.path_screen_offset = screen_offset
		MainGlobals.path_board_size = board_size

func get_visible_height():
	return screen_size.y - header_height - buttons_height

func get_viewport_center():
	return Vector2(screen_size.x, get_visible_height()) / 2.0 + Vector2(0, header_height)

func board_to_px(p):
	return (Vector2(p) + Vector2.ONE/2.0) * tile_size + Vector2(0, header_height) + Vector2(screen_offset)

func px_to_board(p):
	var fpos = (p - Vector2(screen_offset) - Vector2(0, header_height)) / tile_size - Vector2.ONE/2.0	
	return Vector2i(round(fpos.x), round(fpos.y))

func get_board_center():
	# return board_size / 2.0
	return Vector2i(board_size / 2)
	
func in_board(p, margin=0):
	return p.x >= margin and p.y >= margin and \
		p.x < board_size.x-margin and p.y < board_size.y-margin

func rect_in_board(p, sz, margin=0):
	return p.x >= margin and p.y >= margin and \
		p.x + sz.x <= board_size.x-margin and p.y + sz.y <= board_size.y-margin

func on_border(p, width=1):
	return p.x < width or p.y < width or p.x >= board_size.x-width or p.y >= board_size.y-width

func is_corner(p, width=1):
	return (p.x < width and p.y < width) or \
	(p.x < width and p.y >= board_size.y-width) or \
	(p.x >= board_size.x-width and p.y < width) or \
	(p.x >= board_size.x-width and p.y >= board_size.y - width)

func color_by_index(i):
	return colors[i % colors.size()]

# Palette entries this game must never hand out, by index. A game sets it when one of the shared
# colors is too close to its own background to be read as a distinct thing.
var skip_color_idxs: Array = []

func next_color():
	var guard: int = 0
	while skip_color_idxs.has(next_color_idx) and guard < colors.size():
		next_color_idx = (next_color_idx + 1) % colors.size()
		guard += 1
	var c = colors[next_color_idx]
	next_color_idx = (next_color_idx + 1) % colors.size()
	return c

func get_player_start_pos():
	return Vector2i(board_size.x / 2, 0)

func get_agent_start_pos():
	return get_player_start_pos()# + Vector2i(0, 1)

func delivered_one():
	add_score_and_time(score_for_deliver_one[0], score_for_deliver_one[1])

func collided():
	add_score_and_time(score_for_collision[0], score_for_collision[1])

func game_is_done(didwin:bool, _wasaborted:bool):
	sig_game_is_done.emit(didwin,_wasaborted)

func open_file_for_scores():
	var save_path = get_scores_fname()
	if not FileAccess.file_exists(save_path):
		return FileAccess.open(save_path, FileAccess.WRITE)
	else:
		var file = FileAccess.open(save_path, FileAccess.READ_WRITE)
		if file:
			file.seek_end()
			return file
	return null

func convert_ongoing_score_to_permanent():
	# Not gated on score_was_changed — this promotes a PRE-EXISTING ongoing row, so in a tutorial it
	# would commit and upload the player's last unfinished real session.
	if tutorial_mode:
		return
	if stored_ongoing_score:
		var file = open_file_for_scores()
		if file:
			# Log.dbg(name + ": converting ongoing to permanent: ", stored_ongoing_score)
			file.store_var(stored_ongoing_score)
			file.close()
			save_trials()
			BE.upload_game_score(file_names_prefix, stored_ongoing_score)
			clear_ongoing_score()
		_write_new_best_flag(true)
		MainGlobals.sig_new_best_score.emit()

func save_score(score_array:Array):
	# Return before the clear_ongoing_score() below — a tutorial must leave that file alone.
	if tutorial_mode:
		return
	if not score_was_changed:
		clear_ongoing_score()
		return
	var file = open_file_for_scores()
	if file:
		var to_save: Dictionary = _build_session_record(score_array)
		# Log.dbg(name + ": saving score: ", to_save)
		file.store_var(to_save)
		file.close()
		clear_ongoing_score()
		save_trials()
		BE.upload_game_score(file_names_prefix, to_save)
	_write_new_best_flag(true)
	MainGlobals.sig_new_best_score.emit()

const POS_SCORE_DATETIME 	:= 0
const POS_SCORE_SCORE 		:= 1
const POS_SCORE_TIME_LEFT 	:= 2
const POS_SCORE_TIMES_RUN 	:= 3

var scores_callback: Callable = Callable() 

func _internal_score_vars():
	var unixtime:int = int(Time.get_unix_time_from_system())
	return [unixtime, int(score), int(time_left_sec), times_run]

# --- v6 session record ------------------------------------------------------------------------

# The names of the columns a game passes to save_score(), in order.
#
# This is what turns 34 games' positional arrays into named records WITHOUT editing 34 games: the
# default covers the shape almost all of them already use — [didwin, aborted, level, rt_mean,
# pct_correct] — truncated to whatever length the game actually passes. A game whose array means
# something else overrides this in its main.gd (see gorilla, whack, typit, the breathing games).
#
# Games are then free to migrate to `session_metrics` at their own pace; both paths land in the same
# dictionary.
var score_columns: Array = ["didwin", "aborted", "level", "rt_mean", "pct_correct"]

# Named metrics a game accumulates during play. Merged into the record LAST, so anything set here
# wins over a positional column of the same name.
var session_metrics: Dictionary = {}

# The settings that define the task, for grouping sessions that were genuinely the same test.
# A level number is only an index into an editable table — see SessionStats.task_key.
var task_signature: Dictionary = {}

# Wall-clock start of the session, for `session_ms`.
var _session_started_ms: int = 0

func mark_session_start() -> void:
	_session_started_ms = MainGlobals.timems()

func set_task_signature(sig: Dictionary) -> void:
	task_signature = sig

# Record one named metric for this session. Games use this instead of widening their array.
func record_metric(key: String, value) -> void:
	session_metrics[key] = value

func record_metrics(d: Dictionary) -> void:
	for k in d.keys():
		session_metrics[k] = d[k]

# Convenience: the whole response-time block from an array of per-trial times the game already has.
func record_times(times_ms: Array, prefix: String = "rt") -> void:
	record_metrics(SessionStats.rt_block(times_ms, prefix))

func clear_session_metrics() -> void:
	session_metrics = {}
	task_signature = {}
	_session_started_ms = 0

# One yes/no answer, kept as FOUR counts rather than folded into a percentage.
#
#   tp  said yes, was yes      fp  said yes, was no   (a false alarm)
#   tn  said no,  was no       fn  said no,  was yes  (a miss)
#
# A percentage smears together two independent things — how well the player TELLS THE CASES APART,
# and how willing they are to SAY YES. Someone whose discrimination is slipping often compensates
# by saying yes more: tp rises, fp rises with it, and the percentage barely moves. The percentage
# then shows a steady player while these four counts show what is actually happening.
func record_answer(said_yes: bool, was_yes: bool) -> void:
	var key: String = ("tp" if was_yes else "fp") if said_yes else ("fn" if was_yes else "tn")
	session_metrics[key] = int(session_metrics.get(key, 0)) + 1

# A trial the player never answered. Deliberately NOT one of the four cells: no answer was given,
# so calling it a "no" would invent a decision and quietly inflate the miss count.
func record_no_answer() -> void:
	session_metrics["no_answer"] = int(session_metrics.get("no_answer", 0)) + 1

# --- general accumulators -----------------------------------------------------------------------
#
# The games that currently store nothing but a level number each need a handful of counts, a best,
# or a small distribution. These three cover all of them, so no game grows its own bookkeeping.

# Count an event. `record_count("leaks_missed")`.
func record_count(key: String, n: int = 1) -> void:
	session_metrics[key] = int(session_metrics.get(key, 0)) + n

# Keep the best value seen this session — a memory span, a longest streak.
func record_max(key: String, value: int) -> void:
	if not session_metrics.has(key) or value > int(session_metrics[key]):
		session_metrics[key] = value

# Append to a small distribution: where a sequence broke, how long each leak waited.
#
# BOUNDED, because a session record is written to disk on a 60-second autosave tick and a game with
# hundreds of events would otherwise grow the file without limit. The cap keeps the most RECENT
# values, which is what a within-session trend is read from.
const MAX_LIST_LEN: int = 200

func record_list(key: String, value) -> void:
	var arr: Array = session_metrics.get(key, [])
	arr.append(value)
	if arr.size() > MAX_LIST_LEN:
		arr.remove_at(0)
	session_metrics[key] = arr

# --- the per-trial log ---------------------------------------------------------------------------
#
# A few of the best measurements cannot be rebuilt from session totals, because they are about the
# SHAPE of something across trials rather than its average:
#
#   Dino    accuracy against how long ago a card was seen — the curve of forgetting
#   Weris   time against crowd size, whose slope is the cost of each extra face
#   Polka   which character was shown against which was chosen
#   Gorilla the coin rate with and without the counting task, side by side
#
# These live in their OWN file, never in the session row: they are far bigger, they are only read by
# one panel, and mixing them in would bloat every read of the score list. The file is capped at a
# few recent sessions, because it exists to draw a shape and not to be a permanent archive.

const TRIALS_VER: int = 1
const MAX_TRIALS_PER_SESSION: int = 600
const KEEP_TRIAL_SESSIONS: int = 5

var _trials: Array = []

func get_trials_fname() -> String:
	var key: String = MainGlobals.user_file_key if MainGlobals != null else "guest"
	return "user://trials_v%d_%s_%s.gpa" % [TRIALS_VER, key, file_names_prefix]

# One trial. Games pass whatever that trial means for them — {"lag": 7, "right": true} in Dino,
# {"crowd": 12, "ms": 2400} in Weris.
func record_trial(d: Dictionary) -> void:
	if tutorial_mode:
		return
	if _trials.size() >= MAX_TRIALS_PER_SESSION:
		return
	_trials.append(d)

func clear_trials() -> void:
	_trials = []

# Called at session end, alongside the score. Keeps only the most recent sessions so the file
# cannot grow without bound on a game someone plays every day for a year.
func save_trials() -> void:
	if tutorial_mode or _trials.is_empty():
		return
	var blocks: Array = read_trial_blocks()
	blocks.append({
		"ts": int(Time.get_unix_time_from_system()),
		"task_key": SessionStats.task_key(task_signature),
		"trials": _trials.duplicate(),
	})
	while blocks.size() > KEEP_TRIAL_SESSIONS:
		blocks.remove_at(0)
	var f: FileAccess = FileAccess.open(get_trials_fname(), FileAccess.WRITE)
	if f != null:
		for b: Dictionary in blocks:
			f.store_var(b)
		f.close()
	_trials = []

func read_trial_blocks() -> Array:
	var out: Array = []
	var path: String = get_trials_fname()
	if not FileAccess.file_exists(path):
		return out
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while f.get_position() < f.get_length():
		var b = f.get_var()
		if b is Dictionary and b.has("trials"):
			out.append(b)
	f.close()
	return out

# Every recorded trial across the kept sessions, flattened — what a panel actually draws.
func read_trials() -> Array:
	var out: Array = []
	for b: Dictionary in read_trial_blocks():
		for t in b.get("trials", []):
			out.append(t)
	return out

# One session as a named dictionary. Everything a trend needs travels with the row itself, so no
# reader ever has to know a column order or consult a level table that may since have been retuned.
func _build_session_record(score_array: Array) -> Dictionary:
	var rec: Dictionary = {
		"ts": int(Time.get_unix_time_from_system()),
		"score": int(score),
		"time_left": int(time_left_sec),
		"times_run": times_run,
	}
	rec.merge(SessionStats.local_time_block(), true)
	if _session_started_ms > 0:
		rec["session_ms"] = MainGlobals.timems() - _session_started_ms
	for i in score_array.size():
		if i < score_columns.size():
			rec[str(score_columns[i])] = score_array[i]
		else:
			rec["col%d" % i] = score_array[i]
	rec.merge(session_metrics, true)
	if not task_signature.is_empty():
		rec["task"] = task_signature.duplicate()
		rec["task_key"] = SessionStats.task_key(task_signature)
	return rec

# All saved sessions as dictionaries, newest last. This is the API the new stats screens use.
func read_sessions() -> Array:
	var out: Array = []
	var path: String = get_scores_fname()
	if not FileAccess.file_exists(path):
		return out
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	while file.get_position() < file.get_length():
		var rec = file.get_var()
		if rec is Dictionary and not rec.is_empty():
			out.append(rec)
	file.close()
	return out

func fill_scores_scene(instantiated_scores_scene):
	_write_new_best_flag(false)
	MainGlobals.sig_scores_viewed.emit()
	var scores = read_scores()
	var table = []
	var table_row
	for score_row in scores:
		table_row = [strtime(score_row[POS_SCORE_DATETIME]), int(score_row[POS_SCORE_SCORE])]
		if scores_callback.is_valid():
			table_row.append_array(scores_callback.call(score_row))
		table.insert(0,table_row)
	if stored_ongoing_score:
		var ongoing_row: Array = _legacy_row(stored_ongoing_score)
		table_row = [strtime(int(ongoing_row[POS_SCORE_DATETIME])),
			int(ongoing_row[POS_SCORE_SCORE])]
		if scores_callback.is_valid():
			table_row.append_array(scores_callback.call(ongoing_row))
		table.insert(0,table_row)
	# Log.dbg("scores: " + str(scores))
	instantiated_scores_scene.create_list(table)
	var raw := scores.duplicate()
	if stored_ongoing_score:
		raw.append(_legacy_row(stored_ongoing_score))
	instantiated_scores_scene.set_progress_data(raw, progress_level_pos, progress_time_pos, progress_pct_pos, progress_level_names, progress_pct_label, progress_pct_format, progress_time_label, progress_time_format, progress_time_is_pct, progress_tab_name, progress_score_label, progress_pct_integer)

func test_open_scores_screen(event, parent):
	if MainGlobals.ignore_keyboard_actions:
		return
	if event.is_action_pressed("scores"):
		# Already open? Then this press has been handled by another listener. A game's own _input
		# and the shared main menu's _input both call this, so without the guard one key press
		# builds two windows on top of each other.
		if parent != null and parent.is_inside_tree() \
				and not parent.get_tree().get_nodes_in_group(SCORES_GROUP).is_empty():
			return
		var _scores_scene = scores_scene.instantiate()
		_scores_scene.show_level = show_scores_level
		_scores_scene.show_time = show_scores_time
		_scores_scene.level_as_name = show_scores_level_as_name
		_scores_scene.time_col_name = scores_time_col_name
		_scores_scene.show_monotonic_toggle = show_monotonic_toggle
		_scores_scene.game_key = file_names_prefix
		var tab_pref = MainGlobals.progress_tab_by_game.get(file_names_prefix, "scores") if file_names_prefix != "" else "scores"
		if typeof(tab_pref) == TYPE_BOOL:
			tab_pref = "speed" if tab_pref else "scores"
		_scores_scene.initial_progress_mode = progress_level_pos >= 0 and tab_pref == "speed"
		_scores_scene.initial_chart_mode = tab_pref == "chart"
		parent.add_child(_scores_scene)
		fill_scores_scene(_scores_scene)

func reset_lives():
	lives_left = _reset_lives_val

func set_num_packets(npackets: int):
	_reset_packets_left = npackets
	packets_left = _reset_packets_left

func reset_packets():
	packets_left = _reset_packets_left

func dec_packet():
	var old_val = packets_left
	packets_left = max(0, packets_left-1)
	if old_val > packets_left and packets_left == 0:
		sig_no_more_packets.emit()

func inc_packet():
	packets_left += 1

#region astar

#region working old astar slow code
# # This dictionary stores the cost of moving from one position to another.
# # It uses a nested dictionary to store the path history.
# # For example, came_from[current_pos][prev_pos] = prev_pos
# var came_from: Dictionary = {}

# # This dictionary stores the cost of the cheapest path from the start node
# # to the current node. It's a nested dictionary where g_score[current_pos][prev_pos]
# # gives the cost of the path to 'current_pos' coming from 'prev_pos'.
# var g_score: Dictionary = {}

# # This dictionary stores the estimated total cost from the start to the goal.
# # Similar to g_score, it uses a nested dictionary.
# var f_score: Dictionary = {}

# # A simple list that functions as a priority queue. It stores nodes to be evaluated,
# # sorted by their f_score. Each element is a dictionary with 'pos' and 'prev_pos'.
# var open_set: Array = []


# # A helper function to reconstruct the path after the goal is found.
# # It works by backtracking from the goal to the start using the 'came_from' dictionary.
# # It requires the final node and its previous node to begin reconstruction.
# func _reconstruct_path(final_pos: Vector2i, final_prev_pos: Vector2i) -> Array[Vector2i]:
# 	var total_path: Array[Vector2i] = [final_pos]
# 	var current_pos = final_pos
# 	var prev_pos = final_prev_pos

# 	while came_from.has(current_pos) and came_from[current_pos].has(prev_pos):
# 		total_path.push_front(prev_pos)
		
# 		# Move back one step using the came_from dictionary
# 		var temp_pos = prev_pos
# 		prev_pos = came_from[current_pos][prev_pos]
# 		current_pos = temp_pos

# 	return total_path


# # A simple Manhattan distance heuristic for cost estimation.
# # It calculates the straight-line distance on a grid.
# func _heuristic(from: Vector2i, to: Vector2i) -> float:
# 	return float(abs(from.x - to.x) + abs(from.y - to.y))


# # The main A* algorithm function.
# # It takes the start and goal positions, a cost function callable, and a unique ID.
# # Returns an array of Vector2i positions representing the found path.
# # Returns an empty array if no path is found.
# #
# # Arguments:
# #   start:      The starting position as a Vector2i.
# #   goal:       The goal position as a Vector2i.
# #   cost_func:  A callable function that calculates the cost to move to a neighbor.
# #               It must have the signature:
# #               func calc_cost_to_move_to(prev_pos: Vector2i, from: Vector2i, to: Vector2i, id: int)
# #               and return -1 if the move is forbidden.
# #   id:         A unique integer ID for the pathfinding agent.
# #
# # Returns:
# #   Array[Vector2i]: The path from start to goal, or an empty array if no path is found.
# func astar(start: Vector2i, goal: Vector2i, cost_func: Callable, id: int, input_prev_pos:Vector2i, bounding_rect:Rect2i = Rect2i()) -> Array[Vector2i]:
# 	# Clear previous pathfinding data
# 	came_from.clear()
# 	g_score.clear()
# 	f_score.clear()
# 	open_set.clear()

# 	# Initialize scores for the starting node. We use a "dummy" previous position.
# 	g_score[start] = {}
# 	g_score[start][start] = 0.0 # Cost to reach start from start is 0
# 	f_score[start] = {}
# 	f_score[start][start] = _heuristic(start, goal)
# 	open_set.append({"pos": start, "prev_pos": start})

# 	var cost_to_initial = cost_func.call(start, start, input_prev_pos, id, goal)
# 	if cost_to_initial >= 0:
# 		cost_to_initial = 500

# 	while not open_set.is_empty():
# 		# Find the node in the open set with the lowest f_score
# 		var current_node_info = open_set[0]
# 		for node_info in open_set:
# 			if f_score.get(node_info.pos, {}).get(node_info.prev_pos, INF) < f_score.get(current_node_info.pos, {}).get(current_node_info.prev_pos, INF):
# 				current_node_info = node_info
		
# 		var current_node = current_node_info.pos
# 		var prev_node = current_node_info.prev_pos
		
# 		if current_node == goal:
# 			return _reconstruct_path(current_node, prev_node)
		
# 		# Move the current node from the open set to the "closed set" (by removing it)
# 		open_set.erase(current_node_info)
		
# 		# Define 4-directional neighbors
# 		var neighbors: Array = [
# 			Vector2i(current_node.x + 1, current_node.y),
# 			Vector2i(current_node.x - 1, current_node.y),
# 			Vector2i(current_node.x, current_node.y + 1),
# 			Vector2i(current_node.x, current_node.y - 1)
# 		]
# 		neighbors.shuffle()
		
# 		# var cost_to_initial = cost_func.call(current_node, current_node, input_prev_pos, id)
# 		# if cost_to_initial >= 0:
# 		# 	cost_to_initial = 500
# 		for candidate in neighbors:
# 			if bounding_rect.size.x != 0 and not bounding_rect.has_point(candidate):
# 				continue

# 			var cost:float
# 			if input_prev_pos == candidate:
# 				cost = cost_to_initial
# 			else:
# 				cost = cost_func.call(prev_node, current_node, candidate, id, goal)
			
# 			if cost == -1:
# 				continue
				
# 			var tentative_g_score: float = g_score.get(current_node, {}).get(prev_node, INF) + cost
			
# 			# If this is the first time we've seen this candidate from this direction,
# 			# or if we've found a better path to it from this direction...
# 			if not g_score.has(candidate):
# 				g_score[candidate] = {}
			
# 			if tentative_g_score < g_score[candidate].get(current_node, INF):
# 				# Update the path and scores for this specific incoming direction
# 				if not came_from.has(candidate):
# 					came_from[candidate] = {}
# 				came_from[candidate][current_node] = prev_node
				
# 				g_score[candidate][current_node] = tentative_g_score
# 				f_score[candidate] = g_score[candidate] # Store the g_score
# 				f_score[candidate][current_node] += _heuristic(candidate, goal) # Add the heuristic

# 				# Add the new state to the open set
# 				var new_node_info = {"pos": candidate, "prev_pos": current_node}
# 				if not open_set.has(new_node_info):
# 					open_set.append(new_node_info)
	
# 	return []
#endregion

#region possibly faster astar code

var _open_heap: Array = [] # heap of [f:float, state:int]
var _g: Dictionary = {}    # state -> float
var _came: Dictionary = {} # state -> prev_state
var _pos_of: Dictionary = {}  # state -> Vector2i (current position)
var _prevpos_of: Dictionary = {} # state -> Vector2i (prev position)
var _closed: Dictionary = {} # state -> true (optional but helps)

# 4-neighbor offsets (no shuffle)
const _N4 = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

func _heuristic(a: Vector2i, b: Vector2i) -> float:
	# Manhattan for 4-dir grids
	return float(abs(a.x - b.x) + abs(a.y - b.y))

func _heap_push(item: Array) -> void:
	# item = [f, state]
	_open_heap.append(item)
	var i = _open_heap.size() - 1
	while i > 0:
		var p = (i - 1) >> 1
		if _open_heap[p][0] <= item[0]:
			break
		_open_heap[i] = _open_heap[p]
		i = p
	_open_heap[i] = item

func _heap_pop() -> Array:
	# returns [f, state]
	var root = _open_heap[0]
	var last = _open_heap.pop_back()
	if not _open_heap.is_empty():
		var i = 0
		var n = _open_heap.size()
		while true:
			var l = i * 2 + 1
			if l >= n:
				break
			var r = l + 1
			var c = l
			if r < n and _open_heap[r][0] < _open_heap[l][0]:
				c = r
			if _open_heap[c][0] >= last[0]:
				break
			_open_heap[i] = _open_heap[c]
			i = c
		_open_heap[i] = last
	return root

func _state_key(prev: Vector2i, cur: Vector2i) -> int:
	# Packs (prev,cur) into a stable integer key based on board_size.
	# Assumes 0 <= x < board_size.x, 0 <= y < board_size.y.
	var w = board_size.x
	var h = board_size.y
	var a = prev.x + prev.y * w
	var b = cur.x + cur.y * w
	return a + b * (w * h)

func _reconstruct_from_state(state: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var s = state
	while true:
		out.append(_pos_of[s])
		if not _came.has(s):
			break
		s = _came[s]
	out.reverse()
	return out

func astar(start: Vector2i, goal: Vector2i, cost_func: Callable, id: int, input_prev_pos: Vector2i, bounding_rect: Rect2i = Rect2i()) -> Array[Vector2i]:
	_open_heap.clear()
	_g.clear()
	_came.clear()
	_pos_of.clear()
	_prevpos_of.clear()
	_closed.clear()

	# Precompute your special initial cost once
	var cost_to_initial = cost_func.call(start, start, input_prev_pos, id, goal)
	if cost_to_initial >= 0:
		cost_to_initial = 500.0

	var start_state = _state_key(start, start) # dummy prev=start
	_g[start_state] = 0.0
	_pos_of[start_state] = start
	_prevpos_of[start_state] = start
	_heap_push([_heuristic(start, goal), start_state])

	var size_xy = board_size

	while not _open_heap.is_empty():
		var top = _heap_pop()
		var state = int(top[1])

		if _closed.has(state):
			continue
		_closed[state] = true

		var cur: Vector2i = _pos_of[state]
		var prev: Vector2i = _prevpos_of[state]

		if cur == goal:
			return _reconstruct_from_state(state)

		# Expand 4 neighbors without allocations/shuffle
		for d in _N4:
			var cand = cur + d

			# Bounds / optional bounding rect
			if cand.x < 0 or cand.y < 0 or cand.x >= size_xy.x or cand.y >= size_xy.y:
				continue
			if bounding_rect.size.x != 0 and not bounding_rect.has_point(cand):
				continue

			# Direction-dependent cost: cost_func(prev, cur, cand, ...)
			var step_cost: float
			if input_prev_pos == cand:
				step_cost = cost_to_initial
			else:
				step_cost = float(cost_func.call(prev, cur, cand, id, goal))

			if step_cost == -1.0:
				continue

			var next_state = _state_key(cur, cand)

			# g(current) + step_cost
			var gcur = float(_g.get(state, INF))
			var gnew = gcur + step_cost
			var gold = float(_g.get(next_state, INF))

			if gnew < gold:
				_g[next_state] = gnew
				_came[next_state] = state
				_pos_of[next_state] = cand
				_prevpos_of[next_state] = cur

				var fnew = gnew + _heuristic(cand, goal)
				_heap_push([fnew, next_state])

	return []

#endregion


#endregion astar


func dt_to_dir(dt:Vector2i):
	dt /= dt.length()
	var idx = DirArray.find(dt)
	return idx

func next_board_pos(p:Vector2i, dir:int):
	var q = p
	if dir >= 0 and dir < 4:
		q += DirArray[dir]
	return q

var instructions_text:String
var instructions_title:String
var instructions_font_size:int

func set_instructions(title, text, _font_size := 0):
	instructions_text = text
	instructions_title = title
	instructions_font_size = _font_size

func show_instructions(parent, automatic: bool = true):
	# `automatic` = the first-run popup a game fires from its _ready. Pressing I or using the help
	# menu passes false and always gets the text.
	#
	# A game that HAS a tutorial never shows this automatically — not on the first run (the
	# tutorial runs instead) and not on any run after (the tutorial already taught it, and a wall
	# of text afterwards is just a repeat). For those games the text is reachable on demand only.
	# `file_names_prefix` is the game's folder name for every game — it is what names its save
	# files — which is what MainCfg.tutorials is keyed by.
	if tutorial_mode:
		return
	if automatic:
		if not MainGlobals.pending_tutorial.is_empty():
			return
		if MainCfg.has_tutorial(file_names_prefix):
			return
	shown_instructions = true
	var popup = instructions_scene.instantiate()
	parent.add_child(popup)
	popup.set_font_size(instructions_font_size)
	popup.set_title(instructions_title)
	# The game's own tile, beside its name in the title bar — same widget as the tutorial's opening
	# balloon. `parent` is the game's main scene, which is what names the folder.
	popup.set_game_icon(parent)
	popup.set_text(instructions_text)
	# A game with a tutorial offers it right here, under its own text. The chooser's "How to play"
	# picker is gone, so this and the game's main menu are the two ways back to a tutorial.
	popup.offer_tutorial(parent, self)
	# LAST, so "Got it" is the bottom row under the tutorial offer rather than above it.
	popup.add_close_button()

func handle_event(event, parent):
	if MainGlobals.ignore_keyboard_actions:
		return
	if event.is_action_pressed("faster"):
		time_scale = max(0.25, time_scale / 2.0)
	elif event.is_action_pressed("slower"):
		time_scale = min(4, time_scale * 2.0)
	elif event.is_action_pressed("instructions"):
		# Asked for explicitly, so it always shows — the suppression below is only about the
		# automatic first-run popup.
		show_instructions(parent, false)
	elif event.is_action_pressed("esc"):
		sig_esc_pressed.emit()
	elif event.is_action_pressed("lost_focus"):
		_on_changed_focus(false)
	elif event.is_action_pressed("resumed_focus"):
		_on_changed_focus(true)

var show_time_left_on_level_done := true

# `passed` defaults to TRUE because in most games reaching the end of a level IS completing it.
# The games with an accuracy gate (aliens, bucketmadness, sortingrobots, polkadots) can end a level
# WITHOUT passing it, and there "Level 3 complete!" over "you need at least 70%" congratulated the
# player for failing.
func show_level_done_popup(parent, title, text, level_id=0, text_add="", passed=true):
	if title == null or title == "":
		# The level number belongs in the title. It used to head the body as well ("You have /
		# completed / level 3" under a "Level complete!" banner), which spent the top third of the
		# card saying the same thing twice.
		if passed:
			title = "Level %d complete!" % level_id if level_id > 0 else "Level complete!"
		else:
			title = "Level %d not passed" % level_id if level_id > 0 else "Level not passed"
	if text == null or text == "":
		text = "Total score: %d" % score
		# Only worth saying when there was time to spare. In a game whose clock IS the level's
		# length, the level ends BECAUSE the clock hit zero, so the line would read "00:00:00"
		# every single time and tell the player nothing — and in a game with no running clock at
		# all it would read the starting value every single time, which is worse.
		if uses_session_clock and time_left_sec > 0:
			text += "\nTime left: %s" % time_left_str()
	text += text_add
	var ldp = level_done_popup_scene.instantiate()
	parent.add_child(ldp)
	# Before set_title: the card is built on the first of these calls, and whether the level was
	# passed decides its color and whether it gets a check badge.
	ldp.set_passed(passed)
	ldp.set_title(title)
	ldp.set_text(text)

func show_game_popup(parent, title, text, text_add=""):
	if title == null:
		title = ""
	if text == null:
		text = ""
	text += text_add
	var ldp = game_popup_scene.instantiate()
	parent.add_child(ldp)
	ldp.set_title(title)
	ldp.set_text(text)

# Storm-style intro/info popup: a centered yellow panel with dark-green, \n-formatted text
# (it sizes to the text, so use short lines and \n, not auto-wrap) and a "Tap anywhere to
# start" prompt. A full-screen blocker dismisses it on a tap anywhere (inside or outside);
# it emits `closed` once and frees itself. Returns the PopupText so the caller can
# `.closed.connect(...)`. Reusable by any game.
func show_text_popup(parent, title: String, text: String, vcenter: bool = true, top_px: float = 120.0) -> PopupText:
	var ppp: PopupText = MainGlobals.generic_text_popup()
	parent.add_child(ppp)
	ppp.popup_text(title, text, vcenter, top_px)
	return ppp

func time_left_str():
	var h:int = time_left_sec / 3600
	var m:int = (time_left_sec - h * 3600) / 60
	var s:int = time_left_sec - h * 3600 - m * 60
	return "%02d:%02d:%02d" % [h,m,s]

func add_sound(parent, _name, _resource_or_list, _loop := false):
	var _resource
	if _resource_or_list is Array:
		var i = rng.randi_range(0, _resource_or_list.size()-1)
		_resource = _resource_or_list[i]
		sounds_resource_list[_name] = _resource_or_list
	else:
		_resource = _resource_or_list
		sounds_resource_list.erase(_name)

	var s_exist = sounds.get(_name,null)
	if s_exist != null:
		s_exist.stream = _resource
		return
	var s = AudioStreamPlayer2D.new()
	parent.add_child(s)
	s.stream = _resource
	if _loop:
		if _resource is AudioStreamWAV:
			_resource.loop_mode = AudioStreamWAV.LOOP_FORWARD
			_resource.loop_begin = 0
			_resource.loop_end = int(_resource.get_length() * _resource.mix_rate)
		else:
			_resource.loop = true
	sounds[_name] = s

func play_sound(_name, from_start := true):
	var _resource_list = sounds_resource_list.get(_name, [])
	var s = sounds.get(_name,null)
	if s != null:
		if _resource_list.size() > 0:
			var i = rng.randi_range(0, _resource_list.size()-1)
			s.stream = _resource_list[i]

		if from_start:
			s.stop()
		if !s.playing:
			s.play()

func stop_sound(_name: String):
	if sounds.has(_name):
		sounds[_name].stop()

# Every registered sound, silenced. A tutorial calls this when it ends: several games start an
# ambient loop from new_game() (gorilla's rumble, storm's rain, taxi's motor), and finishing or
# skipping a tutorial used to leave it playing on and on over the main menu.
# Whether a registered sound is currently playing. Games used to ask their own AudioStreamPlayer
# node this ("if not $MotorAudio.playing: play()"); with the sound in the shared registry they ask
# here instead.
func is_sound_playing(_name: String) -> bool:
	var s = sounds.get(_name, null)
	return s != null and is_instance_valid(s) and s.playing

func stop_all_sounds() -> void:
	for key in sounds:
		var s = sounds[key]
		if s != null and is_instance_valid(s):
			s.stop()

func set_sound_volume(_name: String, volume_db: float):
	if sounds.has(_name):
		sounds[_name].volume_db = volume_db

func create_main_menu(parent):
	var main_menu = main_menu_scene.instantiate()
	parent.add_child(main_menu)	
	main_menu.set_game(self)
	return main_menu

func saved_game_name():
	return file_names_prefix + "_saved_game"

func save_game():
	sig_save_game.emit()

var _game_start_ms: int = 0
var _total_paused_ms: int = 0
var _pause_start_ms: int = 0

var game_time: float:
	get:
		var elapsed_ms: int = MainGlobals.timems() - _game_start_ms
		var ongoing_pause_ms: int = 0
		if paused():
			ongoing_pause_ms = MainGlobals.timems() - _pause_start_ms
		return float(max(0, elapsed_ms - _total_paused_ms - ongoing_pause_ms))

func tick_game_time():
	pass

func pause(_set_pause: bool):
	_pause = _set_pause
	if _set_pause and _pause_start_ms == 0:
		_pause_start_ms = MainGlobals.timems()

func _on_changed_focus(_gained_focus: bool):
	in_focus = _gained_focus
	# print("Focus changed: " + str(in_focus))

func show_yesno_dlg(parent, title, text, ok_text, cancel_text, ok_func, cancel_func):
	var dlg = conformation_dlg.instantiate()
	parent.add_child(dlg)
	dlg.set_all(title, text, ok_text, cancel_text, ok_func, cancel_func)

	# var dialog = ConfirmationDialog.new() 
	# dialog.title = title
	# dialog.dialog_text = text
	# dialog.get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# dialog.canceled.connect(_on_dialog_answered.bind(dialog, cancel_func))
	# dialog.confirmed.connect(_on_dialog_answered.bind(dialog, ok_func))
	# if ok_text != null and ok_text.length() > 0:
	# 	dialog.get_ok_button().text = ok_text
	# if cancel_text != null and cancel_text.length() > 0:
	# 	dialog.get_cancel_button().text = cancel_text
		
	# parent.add_child(dialog)	

	# dialog.title = ""
	# dialog.borderless = true

	# var header = HBoxContainer.new()
	# header.custom_minimum_size.y = 32

	# var title_label = Label.new()
	# title_label.text = title
	# title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# header.add_child(title_label)

	# dialog.get_vbox().add_child(header)
	# dialog.get_vbox().move_child(header, 0)

	# var panel := StyleBoxFlat.new()
	# panel.bg_color = Color(0.4,0.4,0.1,1)
	# panel.corner_radius_top_left = 10
	# panel.corner_radius_top_right = 10
	# panel.corner_radius_bottom_left = 10
	# panel.corner_radius_bottom_right = 10
	# panel.set_border_width_all(2)
	# panel.border_color = Color.BLACK

	# dialog.add_theme_stylebox_override("panel", panel)
	# dialog.popup_centered()

# func _on_dialog_answered(dialog:ConfirmationDialog, callable):
# 	dialog.queue_free()
# 	if callable != null and callable is Callable:
# 		callable.call()

func handle_main_menu(parent, event, callback):
	if event.is_action_pressed("mainmenu"):
		show_yesno_dlg(parent, "End game", 
			"Are you sure you want to lose your progress ?", "Yes", "Oops, No", 
			Callable(self,"_on_confirmed_dialog").bind(callback), Callable(self, "_on_cancelled_dialog"))
		return true
	return false

# "New game" during a TUTORIAL restarts the lesson, from its first step.
#
# It used to fall through to the ordinary "lose your progress?" dialog, and confirming called the
# game's new_game() underneath the running coach: the overlay and spotlight stayed up and the step
# the runner was waiting on could never fire again, because the board it was watching had been
# rebuilt. The tutorial sat there dead, with nothing on screen to say so.
#
# Restarting is what the key means here anyway — "give me a fresh one" — and it is the only reading
# that leaves a consistent state, because start_tutorial() does strictly more than new_game(): it
# snapshots the real session (begin_tutorial) and forces the tutorial's own starting level. Calling
# new_game() alone leaves that setup half-applied.
#
# No confirmation: there is no progress to lose, and a dialog asking whether to restart a lesson
# you are three steps into is more friction than the thing it guards.
func restart_tutorial() -> bool:
	if not tutorial_mode or tutorial_runner == null or not is_instance_valid(tutorial_runner):
		return false
	var host: Node = tutorial_runner.host()
	if host == null or not is_instance_valid(host) or not host.has_method("start_tutorial"):
		return false
	tutorial_runner.abort()
	# Deferred: abort() runs the game's own tutorial-done callback (menus, score restore) and then
	# queue_free()s the runner. Starting the next one from inside that would build it on top of a
	# teardown still in progress.
	host.call_deferred("start_tutorial")
	return true

func handle_new_board(parent, event, callback):
	if event.is_action_pressed("new_board"):
		if restart_tutorial():
			return true
		show_yesno_dlg(parent, "New game", 
			"Are you sure you want to start a new game and lose your progress ?", "Yes", "Oops, No", 
			Callable(self,"_on_confirmed_dialog").bind(callback), Callable(self, "_on_cancelled_dialog"))
		return true
	return false

func _on_cancelled_dialog():
	pause(false)

func _on_confirmed_dialog(callback):
	pause(false)
	if callback != null:
		callback.call()

var agent_cam = null

func create_fill_screen_camera(parent):
	var camscale = min(2.0, 1.0 / get_board_part_of_width())
	parent.follow_viewport_enabled = true
	if agent_cam == null:
		agent_cam = Camera2D.new()
		parent.add_child(agent_cam)
	agent_cam.make_current()
	agent_cam.zoom = Vector2(camscale,camscale)
	agent_cam.enabled = true
	agent_cam.set_anchor_mode(Camera2D.ANCHOR_MODE_DRAG_CENTER)
	if MainGlobals.is_mobile():		
		# var p0 = board_to_px(Vector2(-0.5,-0.5))
		# p0.y -= header_height
		# agent_cam.set_offset(board_to_px(get_board_center()) + Vector2(0, p0.y))
		agent_cam.set_offset(board_to_px(get_board_center()))
	else:
		agent_cam.set_offset(board_to_px(get_board_center()))

func get_player_path(player, path: Array[Vector2i], allowed_starting_dist_from_player:int, cost_func:Callable) -> Array[Vector2i]:
	if !playing or player == null or !level_is_ready:
		return []
	# print("got swipe path of len ", path.size())
	if path.size() > 1:
		if path[0] == player.board_pos:
			while path.size() > 0 and path[0] == player.board_pos:
				path.pop_front()
			# print("starting from player pos, with a path of len ", player.path.size())
			return path
		else:
			var d_to_player = (player.board_pos - path[0]).length()
			# print("d_to_player: ", d_to_player)
			if d_to_player <= allowed_starting_dist_from_player:
				var pstart = player.board_pos
				var pend = path[0]
				var path_pre = astar(pstart, pend, cost_func, -1, pstart)
				while path_pre.size() > 0 and path_pre[0] == pstart:
					path_pre.pop_front()
				while path_pre.size() > 0 and path_pre[-1] == pend:
					path_pre.pop_back()
				# print("starting from player pos dist of %d,%d", [player.board_pos.x - path[0].x,player.board_pos.y - path[0].y])
				return path_pre + path
	return []

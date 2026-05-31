extends Node

# const settings_name := "user://nomizo_settings.tres"

var screen_size: Vector2i
var full_screen_size: Vector2i
var header_height := 60
var footer_height := 40
var ignore_keyboard_actions := false
var mute := false
var show_monotonic_scores := true
var show_monotonic_speed := true
enum ViewMode { GRID = 0, LIST = 1, CATEGORIZED = 2 }
var game_chooser_view_mode: int = ViewMode.CATEGORIZED
var progress_tab_by_game: Dictionary = {}
var chart_x_mode_by_game: Dictionary = {}  # game_key -> 0=date, 1=index
var last_played_order: Array = []  # game folders in most-recently-played-first order

var visible_screens := {}

var game := GenericGameUtil.new("Main", "main", 0,5,0)
const LAST_PROFILE_HINT_PATH := "user://last_profile_key.txt"

var active_game = null
var popup_open: bool = false
var scores_last_synced_ts: int = 0
var user_file_key: String = "guest"
var guest_names_used: Array = []
var swipe_active: bool = false
var swipe_was_drag: bool = false
var _draw_path_mode: bool = false
var draw_path_mode: bool:
	get:
		return _draw_path_mode
	set(value):
		_draw_path_mode = value
		if not value:
			sig_path_clear.emit()
var path_tile_size: int = 40
var path_screen_offset: Vector2i = Vector2i.ZERO
var path_board_size: Vector2i = Vector2i.ZERO

var is_in_digitized_swipe_up:bool = false
var is_in_digitized_swipe_dn:bool = false
var digitized_swipe_mode:bool = false

signal sig_path_clear
@warning_ignore("unused_signal") signal sig_path_drawn(path: Array[Vector2i])
signal sig_need_to_close_info_popups
signal sig_stop_active_game
signal sig_global_help_button_pressed
signal sig_update_bottom_bar(buttonsstr_or_arr, color)

signal sig_generic_game_hud_add_score(add_val)
signal sig_generic_game_hud_add_time(add_val)
signal sig_generic_game_hud_game_over(did_win)
signal sig_generic_game_hud_new_game()
signal sig_generic_game_hud_show(_show)

signal sig_global_level_is_done(didwin)
signal sig_global_update_hud
signal sig_global_start_countdown(start_from)
signal sig_global_countdown_finished

signal sig_level_done_popup_closed
signal sig_game_popup_closed

@warning_ignore("unused_signal") signal sig_new_best_score
@warning_ignore("unused_signal") signal sig_scores_viewed

func _ready():
	# await get_tree().process_frame
	var sz
	if is_mobile():
		sz = Vector2(680,1200)
		_set_app_screen_size(sz)
	# else:
	# 	sz = Vector2(680,1000)
	# 	_set_app_screen_size(sz)

func global_need_to_close_info_popups():
	sig_need_to_close_info_popups.emit()
func global_level_done_popup_closed():
	sig_level_done_popup_closed.emit()
func global_game_popup_closed():
	sig_game_popup_closed.emit()
func global_start_countdown(start_from):
	sig_global_start_countdown.emit(start_from)
func global_countdown_finished():
	sig_global_countdown_finished.emit()
func global_level_is_done(didwin:bool):
	if didwin:
		sig_global_level_is_done.emit(didwin)
func global_update_hud():
	sig_global_update_hud.emit()	
func generic_game_hud_add_score(add_val):
	sig_generic_game_hud_add_score.emit(add_val)
func generic_game_hud_add_time(add_val):
	sig_generic_game_hud_add_time.emit(add_val)
func generic_game_hud_game_over(did_win):
	sig_generic_game_hud_game_over.emit(did_win)
func generic_game_hud_new_game():
	sig_generic_game_hud_new_game.emit()
func generic_game_hud_show(_show):
	sig_generic_game_hud_show.emit(_show)

func set_visible(screen_name, status):
	if !status:
		visible_screens.erase(screen_name)
	else:
		visible_screens[screen_name] = status
	# Log.dbg("visibilities ", visible_screens)

func any_screen_visible():
	return visible_screens.size() > 0

func is_screen_visible(screen_name):
	return screen_name in visible_screens

func _set_app_screen_size(sz: Vector2):
	get_window().content_scale_size = sz
	get_window().size = sz
	screen_size = sz
	full_screen_size = sz
	# Log.dbg("screen size in main globals _ready: " + str(screen_size))
	# DisplayServer.window_set_size(sz)
	# # get_tree().root.set_size_override(true, sz)
	# var vp = get_viewport()
	# # vp.scale = Vector2(0.8, 1.5)
	# vp.size = sz
	# var w = vp.get_window()
	# w.size = sz

func is_mobile():
	return OS.has_feature("mobile")

enum PlatformId { UNKNOWN = 0, DESKTOP = 1, PHONE = 2, TABLET = 3, WEB = 4 }

func get_platform_id() -> int:
	var os_name: String = OS.get_name()
	if os_name == "Web":
		return PlatformId.WEB
	if os_name in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD"]:
		return PlatformId.DESKTOP
	if os_name in ["Android", "iOS"]:
		var sz: Vector2 = Vector2(DisplayServer.screen_get_size())
		var dpi: float = DisplayServer.screen_get_dpi()
		if dpi > 0.0:
			var diag_inches: float = sqrt(sz.x * sz.x + sz.y * sz.y) / dpi
			return PlatformId.TABLET if diag_inches >= 7.0 else PlatformId.PHONE
		return PlatformId.PHONE
	return PlatformId.UNKNOWN

func stop_active_game():
	sig_stop_active_game.emit()

func global_help_button_pressed():
	sig_global_help_button_pressed.emit()

func save_settings():
	_save_last_profile_hint()
	# Keep slot 1 reserved for backward compatibility with older settings files that
	# stored a password there. New saves intentionally persist an empty string instead.
	game.save_settings([BE.stored_username, "", BE.stored_email, show_monotonic_scores, game_chooser_view_mode, progress_tab_by_game, show_monotonic_speed, last_played_order, chart_x_mode_by_game, scores_last_synced_ts, MainCfg.is_anonymous_user, user_file_key, guest_names_used])
	# var s:SavedGrylpaBrainSettings = SavedGrylpaBrainSettings.new()
	# s.username = BE.stored_username
	# s.email = BE.stored_email
	# ResourceSaver.save(s, settings_name)

func load_settings():
	var hinted_key: String = _load_last_profile_hint()
	if not hinted_key.is_empty():
		user_file_key = hinted_key
	var settings = game.read_settings()
	if settings.is_empty():
		# user_file_key starts as "guest" but the file may have been saved under the real email
		# key from a previous session. Scan for any matching main settings file.
		var dir: DirAccess = DirAccess.open("user://")
		if dir:
			dir.list_dir_begin()
			var fname: String = dir.get_next()
			while fname != "" and settings.is_empty():
				if fname.begins_with("settings_v5_") and fname.ends_with("_main.gpa") and fname != "settings_v5_guest_main.gpa":
					var key: String = fname.substr(12, fname.length() - 12 - 9)
					user_file_key = key
					settings = game.read_settings()
					if settings.is_empty():
						user_file_key = "guest"
				fname = dir.get_next()
			dir.list_dir_end()
	if settings.size() > 2:
		BE.stored_username = settings[0]
		BE.stored_email = settings[2]
	if settings.size() > 3:
		show_monotonic_scores = settings[3]
	if settings.size() > 4:
		var v4 = settings[4]
		if v4 is bool:
			game_chooser_view_mode = ViewMode.LIST if v4 else ViewMode.GRID
		elif v4 is int:
			game_chooser_view_mode = v4
	if settings.size() > 5 and settings[5] is Dictionary:
		progress_tab_by_game = settings[5]
	if settings.size() > 6:
		show_monotonic_speed = settings[6]
	if settings.size() > 7 and settings[7] is Array:
		last_played_order = settings[7]
	if settings.size() > 8 and settings[8] is Dictionary:
		chart_x_mode_by_game = settings[8]
		# Restore order: move from least recent to most recent so most recent ends at top
		for i in range(last_played_order.size() - 1, -1, -1):
			MainCfg.move_to_top(last_played_order[i])
	if settings.size() > 9:
		scores_last_synced_ts = settings[9]
	if settings.size() > 11 and settings[11] is String and not (settings[11] as String).is_empty():
		user_file_key = settings[11]
	else:
		set_user_file_key(BE.stored_email)  # fallback for old installs
	if settings.size() > 12 and settings[12] is Array:
		guest_names_used = settings[12]
	# if !ResourceLoader.exists(settings_name):
	# 	return
	# var s:SavedGrylpaBrainSettings = ResourceLoader.load(settings_name)
	# if s != null:
	# 	BE.stored_username = s.username
	# 	BE.stored_email = s.email

func do_after(t_sec, f):
	var scene_tree: SceneTree = get_tree()
	var timer: SceneTreeTimer = scene_tree.create_timer(t_sec)
	timer.timeout.connect(f)

func sleep(t_sec):
	await get_tree().create_timer(t_sec).timeout

func init_globals(_scr_sz):
	screen_size = Vector2i(_scr_sz)
	full_screen_size = screen_size
	screen_size.y -= footer_height
	_init_app_fonts()
	# Log.dbg("screen size in main globals init_globals: " + str(screen_size))
	# Log.dbg("detected screen size of " + str(screen_size))

func get_viewport_size():
	return Vector2(screen_size.x, screen_size.y - header_height)

func get_viewport_center():
	return get_viewport_size() / 2.0 + Vector2(0, header_height)

func rect_in_viewport(r):
	return r.position.x > 0 and r.position.y > header_height and \
		r.position.x + r.size.x < screen_size.x and r.position.y + r.size.y < screen_size.y

func rect_above_bottom(r):
	return r.position.y + r.size.y < screen_size.y

func rect_below_bottom(r):
	return r.position.y > screen_size.y

func point_in_viewport(p):
	return p.x > 0 and p.y > header_height and p.x < screen_size.x and p.y < screen_size.y

func timems() -> int:
	# return roundi(Time.get_unix_time_from_system() * 1000.0)
	return Time.get_ticks_msec()

func timeus() -> int:
	return Time.get_ticks_usec()

func cap_first_word(s) -> String:
	if not s is String:
		return str(s)
	if s.length() > 0:
		s = s.dedent()
		return s[0].to_upper() + s.substr(1)
	return s

func sim_action(act):
	var e = InputEventAction.new()
	e.action = act
	e.pressed = true
	Input.parse_input_event(e)

func YN(b: bool):
	return "Yes" if b else "No"

func find_id_in_option_button(lst: OptionButton, id: int) -> int:
	for i in range(lst.get_item_count()):
		if lst.get_item_id(i) == id:
			return i
	return -1

func update_bottom_bar(buttons_str_or_arr, _text_color: Color = Color.YELLOW):
	sig_update_bottom_bar.emit(buttons_str_or_arr, _text_color)

var _action_buttons_scene = null

func add_action_button(image, button_size: Vector2 = Vector2.ZERO):
	if _action_buttons_scene != null:
		return _action_buttons_scene.add_button(image, button_size)

func are_opposite(v1: Vector2, v2: Vector2, tolerance := 0.9) -> bool:
	if v1 == Vector2.ZERO or v2 == Vector2.ZERO:
		return false

	var d = v1.normalized().dot(v2.normalized())
	return d < -tolerance

var _active_tweens: = {}

func kill_active_tweens():
	for t in _active_tweens.keys():
		if t:
			t.kill()
	_active_tweens.clear()

func make_tween():
	var t = get_tree().root.create_tween()
	_active_tweens[t] = true
	t.finished.connect(func(): _active_tweens.erase(t))
	return t

func dist_from_array(p, arr):
	var mind = 1e6
	for a in arr:
		var d = (p - a).length()
		if d < mind:
			mind = d
	return mind
	
func clamp_popup_rect(pos: Vector2, size: Vector2, margin := 4) -> Rect2i:
	var vr: Rect2 = get_viewport().get_visible_rect()
	var vp_size := Vector2(vr.size)

	var x = clamp(pos.x, margin, vp_size.x - size.x - margin)
	var y = clamp(pos.y, margin, vp_size.y - size.y - margin)

	if size.x > vp_size.x - margin * 2:
		x = margin
	if size.y > vp_size.y - margin * 2:
		y = margin

	return Rect2(Vector2(x, y), size)

func cumsum(arr: Array) -> Array:
	var out := []
	out.resize(arr.size())

	var acc := 0
	for i in range(arr.size()):
		acc += arr[i]
		out[i] = acc

	return out

func cumsum_inplace(arr: Array) -> void:
	for i in range(1, arr.size()):
		arr[i] += arr[i - 1]

func array_max(arr: Array):
	if arr.is_empty():
		return null

	var m = arr[0]
	for v in arr:
		if v > m:
			m = v
	return m

var version:String: 
	get: return ProjectSettings.get_setting("application/config/version")

func set_popup_open(is_open: bool):
	swipe_active = false
	popup_open = is_open

func generic_text_popup() -> PopupText:
	return preload("res://scenes/popup_text.tscn").instantiate() as PopupText

func round_duration_str(time_sec:float):
	return "%.0f minutes" % (time_sec / 60.0) if time_sec > 59.9 else "%.0f seconds" % time_sec

func pick_one_cell(l:int, t:int, r:int, b:int, flt: Callable) -> Vector2i:
	var a : Array[Vector2i] = []
	for row in range(t, b+1):
		for col in range(l, r+1):
			if flt.call(col,row):
				a.append(Vector2i(col,row))
	if a.size() > 0:
		return a.pick_random()
	return Vector2i(-1,-1)

func pick_one_cell_on_borders(l:int, t:int, r:int, b:int, flt: Callable) -> Vector2i:
	var a: Array[Vector2i] = []
	for row in range(t, b+1):
		a.append(Vector2i(l,row))
		a.append(Vector2i(r,row))
	for col in range(l+1, r):
		a.append(Vector2i(col,t))
		a.append(Vector2i(col,b))
	var a2: Array[Vector2i] = []
	for _a in a:
		if flt.call(_a.x, _a.y):
			a2.append(_a)
	if a2.size() > 0:
		return a2.pick_random()
	return Vector2i(-1,-1)

func bring_to_front() -> void:
	var p := get_parent()
	if p:
		p.move_child(self, p.get_child_count() - 1)

func sum_dict_vals(d):
	var total := 0
	for v in d.values():
		total += v
	return total

var _system_sans_font: Font = null
func _init_app_fonts() -> void:
	var base: FontFile = ResourceLoader.load("res://art/fonts/OpenSans-SemiBold.ttf") as FontFile
	if base == null:
		return
	var symbols2: FontFile = ResourceLoader.load("res://art/fonts/NotoSansSymbols2-Regular.ttf") as FontFile
	var symbols: FontFile = ResourceLoader.load("res://art/fonts/NotoSansSymbols-Regular.ttf") as FontFile
	var fallbacks: Array = []
	if symbols2 != null:
		fallbacks.append(symbols2)
	if symbols != null:
		fallbacks.append(symbols)
	base.fallbacks = fallbacks
	_system_sans_font = base

func get_system_sans_font() -> Font:
	if _system_sans_font == null:
		var tmp: SystemFont = SystemFont.new()
		tmp.font_names = PackedStringArray(["Open Sans SemiBold", "Open Sans", "sans-serif"])
		tmp.font_weight = 600
		return tmp
	return _system_sans_font

# ---------- Per-user file isolation ----------

func set_user_file_key(email: String) -> void:
	if email.is_empty() or MainCfg.is_anonymous_user:
		user_file_key = "guest"
	else:
		user_file_key = email.to_lower().replace("@", "_").replace(".", "_").replace("+", "_").replace(" ", "_")

func sanitize_guest_name(raw: String) -> String:
	# Whitelist: keep only a-z and 0-9, collapse all other chars to a single underscore
	var lower: String = raw.to_lower()
	var result: String = ""
	for ch in lower:
		var code: int = ch.unicode_at(0)
		var is_allowed: bool = (code >= 97 and code <= 122) or (code >= 48 and code <= 57)
		if is_allowed:
			result += ch
		elif not result.is_empty() and not result.ends_with("_"):
			result += "_"
	# Trim trailing underscore, limit length
	while result.ends_with("_"):
		result = result.left(result.length() - 1)
	return result.left(20)

func is_guest_name_taken(raw: String) -> bool:
	var sanitized: String = sanitize_guest_name(raw)
	return sanitized.is_empty() or guest_names_used.has("guest_" + sanitized)

func has_named_guest() -> bool:
	return user_file_key.begins_with("guest_") and user_file_key.length() > 6

func register_guest_name(raw: String) -> void:
	var key: String = "guest_" + sanitize_guest_name(raw)
	user_file_key = key
	if not guest_names_used.has(key):
		guest_names_used.append(key)
	_save_last_profile_hint()

func _save_last_profile_hint() -> void:
	var file: FileAccess = FileAccess.open(LAST_PROFILE_HINT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(user_file_key)
	file.close()

func _load_last_profile_hint() -> String:
	if not FileAccess.file_exists(LAST_PROFILE_HINT_PATH):
		return ""
	var file: FileAccess = FileAccess.open(LAST_PROFILE_HINT_PATH, FileAccess.READ)
	if file == null:
		return ""
	var key: String = file.get_as_text().strip_edges()
	file.close()
	return key

func _rename_user_file_if_needed(dir: DirAccess, old_path: String, new_path: String) -> void:
	if old_path == new_path:
		return
	if not FileAccess.file_exists(old_path) or FileAccess.file_exists(new_path):
		return
	dir.rename(old_path.replace("user://", ""), new_path.replace("user://", ""))

func migrate_scores_to_user_key(old_key: String) -> void:
	if user_file_key == old_key or old_key.is_empty():
		return
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	var saved_key: String = user_file_key
	var main_gu: GenericGameUtil = GenericGameUtil.new("main", "main", 0, 5, 0)
	user_file_key = old_key
	var old_main_settings: String = main_gu.get_settings_fname()
	user_file_key = saved_key
	var new_main_settings: String = main_gu.get_settings_fname()
	_rename_user_file_if_needed(dir, old_main_settings, new_main_settings)
	for entry in MainCfg.games:
		var folder: String = entry[0]
		var gu: GenericGameUtil = GenericGameUtil.new(folder, folder, 0, 5, 0)
		user_file_key = old_key
		var old_scores: String = gu.get_scores_fname()
		var old_ongoing: String = gu.get_ongoing_score_fname()
		var old_uploaded: String = gu.get_uploaded_scores_fname()
		var old_settings: String = gu.get_settings_fname()
		var old_new_best: String = gu._new_best_flag_path()
		user_file_key = saved_key
		var new_scores: String = gu.get_scores_fname()
		var new_ongoing: String = gu.get_ongoing_score_fname()
		var new_uploaded: String = gu.get_uploaded_scores_fname()
		var new_settings: String = gu.get_settings_fname()
		var new_new_best: String = gu._new_best_flag_path()
		_rename_user_file_if_needed(dir, old_scores, new_scores)
		_rename_user_file_if_needed(dir, old_ongoing, new_ongoing)
		_rename_user_file_if_needed(dir, old_uploaded, new_uploaded)
		_rename_user_file_if_needed(dir, old_settings, new_settings)
		_rename_user_file_if_needed(dir, old_new_best, new_new_best)

# ---------- Backend score sync ----------

func on_logged_in_sync() -> void:
	if not MainCfg.use_BE or MainCfg.is_anonymous_user:
		return
	_bulk_upload_unsynced_scores()
	_sync_all_games_from_server()

func _bulk_upload_unsynced_scores() -> void:
	for entry in MainCfg.games:
		var folder: String = entry[0]
		var gu: GenericGameUtil = GenericGameUtil.new(folder, folder, 0, 5, 0)
		var all_scores: Array = gu.read_scores()
		var uploaded: Dictionary = gu.read_uploaded_scores()
		var to_upload: Array = all_scores.filter(
			func(s): return s is Array and s.size() >= 4 and not uploaded.has(int(s[0])))
		if not to_upload.is_empty():
			BE.bulk_upload_game_scores(folder, to_upload)

func mark_score_uploaded(game_name: String, session_ts: int) -> void:
	mark_scores_uploaded_for_game(game_name, [session_ts])

func mark_scores_uploaded_for_game(game_name: String, ts_list: Array) -> void:
	var gu: GenericGameUtil = GenericGameUtil.new(game_name, game_name, 0, 5, 0)
	gu.mark_scores_uploaded(ts_list)

func _sync_all_games_from_server() -> void:
	for entry in MainCfg.games:
		var folder: String = entry[0]
		BE.download_game_scores(folder, _on_game_scores_downloaded.bind(folder))

func _on_game_scores_downloaded(server_scores: Array, game_name: String) -> void:
	if server_scores.is_empty():
		return
	var gu: GenericGameUtil = GenericGameUtil.new(game_name, game_name, 0, 5, 0)
	_merge_scores_locally(gu, server_scores)
	var settings: Array = gu.read_settings()
	if not gu.shown_instructions:
		gu.shown_instructions = true
		gu.save_settings(settings)
	var ts_list: Array = []
	for ss in server_scores:
		if ss is Dictionary:
			var ts = ss.get("session_ts", null)
			if ts != null:
				ts_list.append(int(ts))
	if not ts_list.is_empty():
		gu.mark_scores_uploaded(ts_list)
	scores_last_synced_ts = int(Time.get_unix_time_from_system())
	save_settings()

func _merge_scores_locally(gu: GenericGameUtil, server_scores: Array) -> void:
	var local_scores: Array = gu.read_scores()
	var local_ts_set: Dictionary = {}
	for s in local_scores:
		if s is Array and s.size() > 0:
			local_ts_set[int(s[0])] = true
	var added: bool = false
	for ss in server_scores:
		if ss is Dictionary:
			var ts = ss.get("session_ts", null)
			if ts != null and not local_ts_set.has(int(ts)):
				var row: Array = [ts, ss.get("score", 0), ss.get("time_left", 0), ss.get("times_run", 0)]
				var extra = ss.get("extra_data", [])
				if extra is Array:
					row.append_array(extra)
				local_scores.append(row)
				added = true
	if added:
		var path: String = gu.get_scores_fname()
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file:
			for s in local_scores:
				file.store_var(s)
			file.close()

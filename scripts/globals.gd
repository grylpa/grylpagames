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

# --- Tutorials ---
# Set by the game chooser just before it launches a game, and consumed by that game's main.gd, to
# say "start in tutorial mode instead of showing the menu". A one-shot handoff rather than a
# parameter, because the chooser instantiates the game scene generically and has nowhere to pass
# arguments. Lives here rather than in the per-game settings file, which tutorial mode cannot write.
var pending_tutorial: String = ""
# Whether the player has been offered a tutorial at least once (app-level, persisted in slot 14).
# Vestigial: the app used to open a "How to play" picker on the first run after install. That
# picker is gone — a game with a tutorial now runs it automatically the first time it is opened.
# The flag stays because settings are a POSITIONAL array and slot 14 cannot be reused or dropped
# without shifting everything after it.
var shown_tutorial_offer: bool = false
# Game folders whose tutorial the player has finished, oldest first (persisted in slot 15). The
# "How to play" list uses this to sort the OPPOSITE way to the game chooser: a tutorial you have
# already done drops to the bottom, because the point of that list is what you have yet to learn.
var tutorials_done: Array = []
# Games whose tutorial has been auto-started on the player's first run. Recorded on the ATTEMPT,
# not on completion — mark_tutorial_done() only records a finished run, so tracking completion
# alone would relaunch the tutorial every session for anyone who skipped it.
var tutorials_auto_shown: Array = []
# The folder whose tutorial is running right now, so the runner can record completion without
# every game having to pass its own name.
var _running_tutorial: String = ""

var visible_screens := {}

var game := GenericGameUtil.new("Main", "main", 0,5,0)
const LAST_PROFILE_HINT_PATH := "user://last_profile_key.txt"

var active_game = null
var popup_open: bool = false

# Emitted when a half-finished gesture must be dropped. scripts/main.gd owns the per-finger state
# (which index claimed the gesture, its samples), so it listens for this rather than exposing them.
signal sig_reset_swipe

# Optional hook a game may set so the drawn path can be colored against what it is drawn over:
# takes a board Vector2i and returns the color of that cell. Left unset, the path keeps the
# overlay's own color. Cleared whenever a game is activated, so one game's probe cannot leak
# into the next.
var path_color_probe: Callable = Callable()
var scores_last_synced_ts: int = 0
var user_file_key: String = "guest"
# save_settings() writes the WHOLE settings array and the profile hint from whatever is in memory.
# Until load_settings() has run, that memory is defaults ("guest", no name, no history) — saving
# then silently overwrites a real profile's settings and repoints the hint at the unnamed guest,
# which reads to the player as "the app forgot me and lost my scores". The app always loads first
# (main.gd:48), so this only bites test/probe scenes that instance an autoload-only tree. Refuse.
var _settings_loaded: bool = false
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
# How long the drawn path takes to fade once the finger lifts. The line is laid out in SCREEN
# space, so in a game whose view scrolls it stops describing the route almost at once and should
# go quickly; where the whole board is on screen it stays meaningful and can linger.
var path_fade_sec: float = 0.6

var is_in_digitized_swipe_up:bool = false
var is_in_digitized_swipe_dn:bool = false
var digitized_swipe_mode:bool = false

signal sig_path_clear
@warning_ignore("unused_signal") signal sig_path_drawn(path: Array[Vector2i])
signal sig_need_to_close_info_popups
signal sig_stop_active_game
signal sig_global_help_button_pressed
signal sig_update_bottom_bar(buttonsstr_or_arr, color, reversed)

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
	# The REAL window is set only where a real window exists to set.
	#
	# `content_scale_size` above is the whole job: it declares the logical canvas, and stretch mode
	# `canvas_items` + aspect `keep` scale that canvas into whatever the display actually is. Setting
	# `Window.size` on top of it is a no-op on native mobile, where the OS owns a fullscreen window —
	# which is the only place this function had ever run, so the line looked harmless.
	#
	# On WEB it is not a no-op: it resizes the browser canvas ELEMENT to 680x1200 CSS pixels, inside a
	# viewport that is nothing of the sort. Once mobile detection started firing on web (see
	# _web_is_mobile) that broke the build three ways at once — the game drew in a corner of the
	# screen, it crawled because a phone's 3x pixel ratio made that canvas ~2040x3600 real pixels to
	# render every frame, and taps landed on the wrong control because hit-testing used a canvas whose
	# size and offset no longer matched what the browser was painting.
	if not OS.has_feature("web"):
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

# Set only by the headless probes, so mobile layout (which is where big fonts overflow small
# cards) can be measured on a desktop build. Nothing in the app writes it.
var force_mobile: bool = false

# Cached: is_mobile() is called for every label that sizes itself, and the web check below reaches
# into JavaScript. -1 not yet asked, 0 no, 1 yes.
var _web_mobile: int = -1

func is_mobile():
	return force_mobile or OS.has_feature("mobile") or _web_is_mobile()

# The WEB export is a phone as often as it is a desktop, and `OS.has_feature("mobile")` does not
# know: a web build reports "web" plus a tag for the host OS, never "mobile". So every phone playing
# the browser build was getting the 680x788 desktop canvas and desktop type — the layout this
# project is not authored for.
#
# Two steps, because neither alone is right:
#
#   web_android / web_ios   Godot's own host tags. Correct whenever the browser is honest.
#   maxTouchPoints          the iPad problem: iPadOS Safari asks for desktop sites by default and
#                           reports as macOS, so the tag says web_macos. A Mac has no touch screen
#                           and an iPad has ten, which separates them cleanly. Same test rescues an
#                           Android tablet in desktop mode.
func _web_is_mobile() -> bool:
	if not OS.has_feature("web"):
		return false
	if _web_mobile >= 0:
		return _web_mobile == 1
	var mobile: bool = OS.has_feature("web_android") or OS.has_feature("web_ios")
	if not mobile:
		# Guarded: JavaScriptBridge exists only on web, and eval can return null if the page blocks
		# it. Anything unexpected leaves this as desktop, which is the safe way to be wrong — a
		# desktop layout on a tablet is cramped, a mobile layout on a desktop is broken.
		var touches = JavaScriptBridge.eval("navigator.maxTouchPoints || 0", true)
		if typeof(touches) == TYPE_FLOAT or typeof(touches) == TYPE_INT:
			mobile = int(touches) > 1
	_web_mobile = 1 if mobile else 0
	return mobile

# ONE mobile type scale, derived rather than guessed per label.
#
# The canvas is 680x788 on desktop and 680x1200 on mobile (see _ready). So a size in units is the
# same share of the WIDTH everywhere and a 1200/788 = 1.52x smaller share of the HEIGHT on a phone:
# 1.52 is where a font has to land just to hold its ground, before any argument about a phone being
# a physically smaller piece of glass.
#
# Almost every hand-written pair in this project is BELOW that. The tutorial's Skip button was
# 20/15 = 1.33, the score rows 26/20 = 1.30 and 28/22 = 1.27 — each one shrinking by 12-16% on the
# device it was written for. Everything with a single flat size loses the whole 34%.
#
# `ui_font_size(desktop)` is the pair, computed. Call it with the DESKTOP size and let the mobile
# one follow; never write the mobile number by hand next to it, which is how the ratios drifted.
#
# It applies ONLY where it is called, and that limit is deliberate. An earlier version scaled every
# Control automatically as it entered the tree, on the theory that a scene-authored size must be a
# desktop size. Measured, the theory is false: across the 223 sizes in the .tscn files the median is
# 30 with quartiles at 24 and 36 — the MOBILE half of the range this project's own explicit pairs
# use (desktop 20-27, mobile 32-46). The scenes were authored on a phone. Scaling them made the help
# screen, the login screen and the score rows far too large, and every screen in the app would have
# needed to opt out of it.
const MOBILE_FONT_SCALE: float = 1.6

func ui_font_size(desktop_size: int) -> int:
	return int(round(float(desktop_size) * MOBILE_FONT_SCALE)) if is_mobile() else desktop_size

# Sets a control's type from its DESKTOP size. Any code that decides a font size should come
# through here rather than writing the mobile number beside it.
func set_font_size(ctrl: Control, desktop_size: int, item: String = "font_size") -> void:
	if ctrl == null or not is_instance_valid(ctrl):
		return
	ctrl.add_theme_font_size_override(item, ui_font_size(desktop_size))

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
	if not _settings_loaded:
		push_error("MainGlobals.save_settings() called before load_settings() — refusing, " +
			"this would overwrite the stored profile with in-memory defaults")
		return
	_save_last_profile_hint()
	# Keep slot 1 reserved for backward compatibility with older settings files that
	# stored a password there. New saves intentionally persist an empty string instead.
	game.save_settings([BE.stored_username, "", BE.stored_email, show_monotonic_scores, game_chooser_view_mode, progress_tab_by_game, show_monotonic_speed, last_played_order, chart_x_mode_by_game, scores_last_synced_ts, MainCfg.is_anonymous_user, user_file_key, guest_names_used, game_font_name(), shown_tutorial_offer, tutorials_done, tutorials_auto_shown])
	# var s:SavedGrylpaBrainSettings = SavedGrylpaBrainSettings.new()
	# s.username = BE.stored_username
	# s.email = BE.stored_email
	# ResourceSaver.save(s, settings_name)

func load_settings():
	_settings_loaded = true
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
	# An int here is a pre-release save that stored the index; ignore it and take the default.
	if settings.size() > 13 and settings[13] is String:
		game_font_idx = game_font_index_by_name(settings[13])
	if settings.size() > 14:
		shown_tutorial_offer = bool(settings[14])
	if settings.size() > 15 and settings[15] is Array:
		tutorials_done = settings[15]
	if settings.size() > 16 and settings[16] is Array:
		tutorials_auto_shown = settings[16]
	apply_game_font()
	# if !ResourceLoader.exists(settings_name):
	# 	return
	# var s:SavedGrylpaBrainSettings = ResourceLoader.load(settings_name)
	# if s != null:
	# 	BE.stored_username = s.username
	# 	BE.stored_email = s.email

# A game's main.gd calls this in _ready to find out whether it was launched for its tutorial.
# One-shot: the flag is consumed, so re-entering the game normally afterwards plays normally.
func take_pending_tutorial(folder: String) -> bool:
	if pending_tutorial != folder:
		return false
	pending_tutorial = ""
	_running_tutorial = folder
	return true

# A game that HAS a tutorial teaches on the player's first run, instead of throwing the wall of
# instruction text at them. Both halves of that decision have to agree — generic_game_util's
# show_instructions() asks first (peek), then the game's main.gd claims it (take) — so this is
# split in two rather than being one call with a side effect.
#
# `has_played_before` is the game util's `shown_instructions`, which read_settings() also sets
# true whenever a scores file exists: someone who has already played is not shown a tutorial they
# never asked for.
func will_auto_tutorial(folder: String, has_played_before: bool) -> bool:
	if has_played_before or folder.is_empty():
		return false
	if not MainCfg.has_tutorial(folder):
		return false
	return not (folder in tutorials_auto_shown) and not (folder in tutorials_done)

# One-shot: claims the auto-tutorial for this game, forever. Skipping it still counts as shown,
# so it does not reappear on the next launch.
func take_auto_tutorial(folder: String, has_played_before: bool) -> bool:
	if not will_auto_tutorial(folder, has_played_before):
		return false
	tutorials_auto_shown.append(folder)
	_running_tutorial = folder
	if _settings_loaded:
		save_settings()
	return true

# For a tutorial started from inside the game (its own menu) rather than from the chooser, so
# completion is recorded the same way either route is taken.
func note_tutorial_started(folder: String) -> void:
	_running_tutorial = folder

# Called by TutorialRunner when a tutorial is played through to the end (not when it is abandoned).
func mark_tutorial_done(completed: bool) -> void:
	var folder: String = _running_tutorial
	_running_tutorial = ""
	if not completed or folder.is_empty():
		return
	tutorials_done.erase(folder)
	tutorials_done.append(folder)        # most recently finished last
	# Only persist when there is a real profile loaded to persist into. Saving before
	# load_settings() would overwrite the stored profile with in-memory defaults, which
	# save_settings() refuses anyway — this just avoids the error spam in probe trees.
	if _settings_loaded:
		save_settings()

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

# Actions fired in code (a flick that steers, a bottom-bar button, a help-screen shortcut).
#
# An InputEventAction press LATCHES the action: Input.is_action_pressed() keeps reporting it until
# something sends the matching release, and nothing here ever did. One flick steering a capsule
# "up" in pneumo therefore left "up" held down for the rest of the session, and the breathing
# games -- the only ones that poll `Input.is_action_pressed("up")` every frame -- then read a
# permanent up no matter what the finger did. Playing pneumo and switching to udbr or mother is
# exactly how it showed up.
#
# The release goes out on the NEXT frame, not immediately: late enough that _input handlers and
# is_action_just_pressed() still see the press, early enough that it cannot leak into another game.
var _sim_action_held: Array = []

func sim_action(act):
	var e = InputEventAction.new()
	e.action = act
	e.pressed = true
	Input.parse_input_event(e)
	if not _sim_action_held.has(act):
		_sim_action_held.append(act)

func _process(_delta: float) -> void:
	if _sim_action_held.is_empty():
		return
	for a in _sim_action_held:
		var r = InputEventAction.new()
		r.action = a
		r.pressed = false
		Input.parse_input_event(r)
	_sim_action_held.clear()

func YN(b: bool):
	return "Yes" if b else "No"

func find_id_in_option_button(lst: OptionButton, id: int) -> int:
	for i in range(lst.get_item_count()):
		if lst.get_item_id(i) == id:
			return i
	return -1

func update_bottom_bar(buttons_str_or_arr, _text_color: Color = Color.YELLOW, reversed: bool = false):
	# reversed = draw a dark backing strip behind the bar so the light icons stay visible
	# on light/busy game backgrounds (e.g. dino). Passed explicitly on every call, so it
	# auto-resets to normal whenever another game/menu configures the bar.
	sig_update_bottom_bar.emit(buttons_str_or_arr, _text_color, reversed)

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

# One soft radial falloff, tinted at the draw site. The main menu uses it for the pool of light
# under the title; anything else that wants a glow can take it rather than baking its own.
var _menu_glow: Texture2D = null

func menu_glow_texture() -> Texture2D:
	if _menu_glow == null:
		var d: int = 128
		var img: Image = Image.create(d, d, false, Image.FORMAT_RGBA8)
		var c: float = (d - 1) * 0.5
		for y in d:
			for x in d:
				var t: float = clampf(1.0 - Vector2(float(x) - c, float(y) - c).length() / c, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, t * t * t))
		_menu_glow = ImageTexture.create_from_image(img)
	return _menu_glow

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

# Drop any gesture in progress. Called at the start of every level, so a claim that somehow
# outlived its finger -- a release the OS never delivered -- cannot survive past the level it
# happened in, whatever else it slips through.
# Black or white, whichever stands out more against `c`. Rec.709 luma, so a yellow room counts as
# light even though its blue channel is low.
func contrasting_ink(c: Color) -> Color:
	var luma: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	return Color(0.06, 0.06, 0.06) if luma > 0.5 else Color(0.97, 0.97, 0.97)

func reset_swipe_state() -> void:
	swipe_active = false
	is_in_digitized_swipe_up = false
	is_in_digitized_swipe_dn = false
	sig_reset_swipe.emit()

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

# --- Game font -------------------------------------------------------------------------------
# The THEME font (project.godot gui/theme/custom_font) is what menus, buttons and titles use, and
# it is the only font this setting changes. In-game text mostly overrides with
# get_system_sans_font(), so it is unaffected.
# Listed best-readable first; index 0 is therefore the default. Stormfaze is last because its
# look-alikes (S/5, O/0) are the reason this setting exists at all.
#
# Every face here must have a line box close to Godot's built-in default (37 px at font size 30).
# This is the DEFAULT font for every Control in the app, so a tall face inflates every Label's
# minimum height and breaks layout everywhere at once. Check a candidate with
# `font.get_ascent(30) + font.get_descent(30)` against `ThemeDB.fallback_font` before adding it;
# more than ~8% over will shift layouts. Baloo 2 was dropped for exactly this — it measured +32%.
const GAME_FONTS: Array = [
	{"name": "Orbitron", "path": "res://art/fonts/Orbitron.ttf", "weight": 600},
	{"name": "Exo 2", "path": "res://art/fonts/Exo2.ttf", "weight": 600},
	{"name": "Space Grotesk", "path": "res://art/fonts/SpaceGrotesk.ttf", "weight": 600},
	{"name": "Stormfaze", "path": "res://art/fonts/Stormfaze.otf", "weight": 0},
]
var game_font_idx: int = 0

# Settings store the font by NAME, not by index, so reordering or inserting a face can never
# silently repoint a saved choice at a different font.
func game_font_index_by_name(nm: String) -> int:
	for i in GAME_FONTS.size():
		if str(GAME_FONTS[i]["name"]) == nm:
			return i
	return 0

func game_font_name() -> String:
	return str(GAME_FONTS[clampi(game_font_idx, 0, GAME_FONTS.size() - 1)]["name"])

# Build (but do not apply) one of the choices, so a settings screen can preview each option in
# its own face.
#
# NO FALLBACKS, deliberately. A Font's line height is the MAX over its fallbacks, and Noto Sans
# Symbols is a very tall face: attaching it took the theme font's line box from 1.23x the font
# size to 2.15x. Since this font is the DEFAULT for every Control in the app, that made every
# label ~73% taller than the built-in default all the layouts were tuned against — which showed up
# as text overlapping headers, conveyor belts running under the bottom bar, and line spacing
# everywhere looking too loose.
#
# The fallbacks bought nothing anyway: the symbols they were added for are missing from the bare
# faces AND from OpenSans, so only Noto provides them — and the theme font never needs them.
# In-game symbol text uses get_system_sans_font(), which keeps its own symbol fallbacks and is
# untouched by this. Keep every string that renders in the theme font to characters the faces
# actually have.
func build_game_font(idx: int) -> Font:
	var i: int = clampi(idx, 0, GAME_FONTS.size() - 1)
	var spec: Dictionary = GAME_FONTS[i]
	var base: FontFile = ResourceLoader.load(str(spec["path"])) as FontFile
	if base == null:
		return null
	# Wrap rather than touching `base`: ResourceLoader hands out one shared FontFile per path, so
	# mutating it would reach every other user of that face.
	var fv: FontVariation = FontVariation.new()
	fv.base_font = base
	var wght: int = int(spec.get("weight", 0))
	if wght > 0:
		# these are VARIABLE fonts; their default instance is Regular, which reads thin for a
		# game UI, so pick a heavier instance
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): wght}
	return fv

# Swap the theme's default font. Everything that does not override its font follows immediately —
# no restart, no per-node work.
func apply_game_font() -> void:
	var f: Font = build_game_font(game_font_idx)
	if f != null:
		ThemeDB.get_default_theme().default_font = f

func set_game_font(idx: int) -> void:
	game_font_idx = clampi(idx, 0, GAME_FONTS.size() - 1)
	apply_game_font()
	save_settings()

var _system_sans_font: Font = null
func _init_app_fonts() -> void:
	# A PRIVATE copy of the face. ResourceLoader hands out ONE shared FontFile per path, so setting
	# `fallbacks` on the cached instance reached every other user of this TTF — the game chooser's
	# description labels, anything that load()s the path, and any FontVariation built on it — and
	# dragged their line box from 1.23x the font size to 2.09x, because a Font's line height is the
	# MAX over its fallbacks and Noto Sans Symbols is very tall.
	#
	# On one line that only shifts the vertical centering. On a WRAPPED label it nearly doubles the
	# gap between lines, which is what "Shape is / blue or red?" looked broken for.
	var base: FontFile = ResourceLoader.load("res://art/fonts/OpenSans-SemiBold.ttf", "",
		ResourceLoader.CACHE_MODE_IGNORE) as FontFile
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

# The same face WITHOUT the symbol fallbacks — for prose.
#
# A Font's line height is the MAX over its fallbacks, and Noto Sans Symbols is a very tall face, so
# `get_system_sans_font()` reports a line box of 2.09x the font size where the bare face is 1.23x.
# On a single line that only shifts the vertical centering; on a WRAPPED label it nearly doubles
# the gap between lines, which is what "Shape is / blue or red?" looked wrong for.
#
# The theme font already solves this by carrying no fallbacks (see build_game_font). This is the
# same fix for in-game text: use THIS font for anything that is words, and get_system_sans_font()
# only where a symbol glyph is actually typeset.
var _text_font: Font = null

func get_text_font() -> Font:
	if _text_font == null:
		var base: FontFile = ResourceLoader.load("res://art/fonts/OpenSans-SemiBold.ttf") as FontFile
		if base == null:
			return get_system_sans_font()
		_text_font = base
	return _text_font

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
		var all_scores: Array = gu.read_sessions()
		var uploaded: Dictionary = gu.read_uploaded_scores()
		var to_upload: Array = all_scores.filter(
			func(rec): return rec is Dictionary and rec.has("ts") and not uploaded.has(int(rec["ts"])))
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
	var local_scores: Array = gu.read_sessions()
	var local_ts_set: Dictionary = {}
	for rec in local_scores:
		if rec is Dictionary and rec.has("ts"):
			local_ts_set[int(rec["ts"])] = true
	var added: bool = false
	for ss in server_scores:
		if ss is Dictionary:
			var ts = ss.get("session_ts", null)
			if ts != null and not local_ts_set.has(int(ts)):
				var rec: Dictionary = {
					"ts": int(ts),
					"score": ss.get("score", 0),
					"time_left": ss.get("time_left", 0),
					"times_run": ss.get("times_run", 0),
				}
				var extra = ss.get("extra_data", null)
				if extra is Dictionary:
					rec.merge(extra, true)
				elif extra is Array:
					# A row uploaded by a pre-v6 client: positional, so name it with this game's
					# own column list rather than dropping it.
					for i in extra.size():
						if i < gu.score_columns.size():
							rec[str(gu.score_columns[i])] = extra[i]
				local_scores.append(rec)
				added = true
	if added:
		var path: String = gu.get_scores_fname()
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file:
			for s in local_scores:
				file.store_var(s)
			file.close()

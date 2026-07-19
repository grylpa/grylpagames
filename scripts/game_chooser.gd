extends CanvasLayer

signal selected_game(scene, game_name)
signal sig_stop_active_game

var n_games:int = 0
var time_displayed
var added_game = []
var auto_activated_game := false

var btn_w := 200
var btn_h := 0
var btn_font_size := 0
var n_columns := 3
var _list_title_size: int = 24
var _list_desc_size: int = 20

var _account_btn: Button = null
var _account_status_dot: Panel = null
var _about_btn: Button = null
var _about_icon: Label = null
var _about_icon_d: float = 0.0
var _about_pill_h: float = 0.0
var _about_screen: CanvasLayer = null

var _icon_grid: Texture2D = preload("res://art/grid-48.png")
var _icon_list: Texture2D = preload("res://art/list-48.png")
var _icon_cat: Texture2D = preload("res://art/category_list_48.png")

const _ICON_COLOR: Color = Color(1.0, 0.8980392, 0.007843138, 1.0)

func _ready() -> void:
	MainGlobals.load_settings()
	_update_view_mode_button()
	create_grid()
	time_displayed = MainGlobals.timems()
	%VersionLabel.text = "V " + MainGlobals.version
	BE.sig_logged_in.connect(_on_BE_sig_logged_in)
	$FullScreenMessage.hide()
	_create_account_button()
	_create_about_button()

func _create_account_button() -> void:
	_account_btn = Button.new()
	_account_btn.name = "AccountButton"
	_account_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_account_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_account_btn.flat = true
	_account_btn.icon = load("res://art/user_white_filled.png")
	_account_btn.expand_icon = true
	_account_btn.custom_minimum_size = Vector2(48, 48)
	_account_btn.pressed.connect(_on_account_button_pressed)
	_account_btn.clip_contents = false
	%ListCheckButton.get_parent().add_child(_account_btn)
	_create_account_status_dot()
	_update_account_button()

func _create_account_status_dot() -> void:
	_account_status_dot = Panel.new()
	_account_status_dot.name = "StatusDot"
	_account_status_dot.custom_minimum_size = Vector2(10, 10)
	_account_status_dot.size = Vector2(10, 10)
	_account_status_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_account_status_dot.z_index = 10
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.set_border_width_all(1)
	style.border_color = Color(0.08, 0.08, 0.08, 1.0)
	_account_status_dot.add_theme_stylebox_override("panel", style)
	_account_btn.add_child(_account_status_dot)
	call_deferred("_reposition_account_status_dot")

func _reposition_account_status_dot() -> void:
	if _account_btn == null or _account_status_dot == null:
		return
	_account_status_dot.position = Vector2(_account_btn.size.x - 12, 3)

func _update_account_button() -> void:
	if _account_btn == null:
		return
	var status_color: Color = Color(0.45, 0.45, 0.45, 1.0)
	var has_local_guest: bool = MainGlobals.has_named_guest()
	var has_real_identity: bool = not BE.stored_email.is_empty() or not BE.stored_username.is_empty()
	if not MainCfg.use_BE:
		_account_btn.modulate = Color("#7fd7ffff") if MainGlobals.user_file_key != "guest" else Color("#7fd7ff90")
		status_color = Color("#4fd9ff") if MainGlobals.user_file_key != "guest" else Color(0.45, 0.45, 0.45, 1.0)
	elif BE.logged_in and not MainCfg.is_anonymous_user and has_real_identity:
		_account_btn.modulate = _ICON_COLOR
		status_color = Color("#7dff5a")
	elif BE.logged_in and MainCfg.is_anonymous_user and has_local_guest:
		_account_btn.modulate = Color(_ICON_COLOR.r, _ICON_COLOR.g, _ICON_COLOR.b, 0.816)
		status_color = Color("#ff9d2e")
	elif has_local_guest:
		_account_btn.modulate = Color("#7fd7ffff")
		status_color = Color("#4fd9ff")
	else:
		_account_btn.modulate = Color(_ICON_COLOR.r, _ICON_COLOR.g, _ICON_COLOR.b, 0.435)
	if _account_status_dot != null:
		var style: StyleBoxFlat = _account_status_dot.get_theme_stylebox("panel") as StyleBoxFlat
		if style != null:
			var style_copy: StyleBoxFlat = style.duplicate() as StyleBoxFlat
			style_copy.bg_color = status_color
			_account_status_dot.add_theme_stylebox_override("panel", style_copy)

func _on_account_button_pressed() -> void:
	var has_real_identity: bool = not BE.stored_email.is_empty() or not BE.stored_username.is_empty()
	if not MainCfg.use_BE or MainCfg.is_anonymous_user:
		var login_screen: Node = get_tree().root.get_node_or_null("Main/LoginScreen")
		if login_screen:
			if MainCfg.is_anonymous_user and login_screen.has_method("show_guest_name_only") and not MainGlobals.has_named_guest():
				login_screen.call("show_guest_name_only")
			elif login_screen.has_method("show_local_name_screen"):
				login_screen.call("show_local_name_screen")
		return
	if MainGlobals.has_named_guest():
		var login_screen: Node = get_tree().root.get_node_or_null("Main/LoginScreen")
		if login_screen and login_screen.has_method("show_account_screen"):
			login_screen.call("show_account_screen", true)
		return
	if BE.logged_in and not MainCfg.is_anonymous_user and has_real_identity:
		var display: String = BE.stored_username if not BE.stored_username.is_empty() else BE.stored_email
		MainGlobals.game.show_yesno_dlg(self, "Log Out",
			"Log out as %s?" % display, "Log Out", "Cancel",
			Callable(self, "_on_confirmed_logout"), Callable())
	else:
		BE.sig_show_login_screen.emit()

func _create_about_button() -> void:
	# Bottom-right "About" entry point: one pill-shaped button showing a round (i)
	# icon next to the version string, so the icon + text read as a single control.
	_about_screen = load("res://scripts/about_screen.gd").new()
	add_child(_about_screen)

	# The scene's plain version label is superseded by this pill.
	var vlabel: Label = %VersionLabel
	vlabel.hide()

	var is_mob: bool = MainGlobals.is_mobile()
	_about_pill_h = 56.0 if is_mob else 40.0
	_about_icon_d = _about_pill_h - 14.0
	var font_size: int = 32 if is_mob else 24

	_about_btn = Button.new()
	_about_btn.name = "AboutButton"
	_about_btn.text = "V " + MainGlobals.version
	_about_btn.add_theme_font_size_override("font_size", font_size)
	_about_btn.add_theme_color_override("font_color", _ICON_COLOR)
	_about_btn.add_theme_color_override("font_hover_color", _ICON_COLOR)
	_about_btn.add_theme_color_override("font_pressed_color", _ICON_COLOR)
	_about_btn.add_theme_color_override("font_focus_color", _ICON_COLOR)
	_about_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_about_btn.pressed.connect(_open_about)

	# One pill background; the left content margin reserves space for the icon.
	var pill: StyleBoxFlat = StyleBoxFlat.new()
	pill.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	pill.set_corner_radius_all(int(_about_pill_h / 2.0))
	pill.set_border_width_all(2)
	pill.border_color = _ICON_COLOR
	pill.content_margin_left = _about_icon_d + 18.0
	pill.content_margin_right = 18.0
	pill.content_margin_top = 4.0
	pill.content_margin_bottom = 4.0
	var pill_hover: StyleBoxFlat = pill.duplicate() as StyleBoxFlat
	pill_hover.bg_color = Color(0.16, 0.16, 0.16, 0.65)
	_about_btn.add_theme_stylebox_override("normal", pill)
	_about_btn.add_theme_stylebox_override("hover", pill_hover)
	_about_btn.add_theme_stylebox_override("pressed", pill_hover)
	_about_btn.add_theme_stylebox_override("focus", pill)
	_about_btn.custom_minimum_size = Vector2(0, _about_pill_h)

	# Round (i) icon as a child of the button so it travels with it.
	_about_icon = Label.new()
	_about_icon.text = "i"
	_about_icon.add_theme_font_size_override("font_size", int(_about_icon_d * 0.72))
	_about_icon.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08, 1.0))
	_about_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_about_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_about_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_about_icon.custom_minimum_size = Vector2(_about_icon_d, _about_icon_d)
	_about_icon.size = Vector2(_about_icon_d, _about_icon_d)
	var icon_style: StyleBoxFlat = StyleBoxFlat.new()
	icon_style.bg_color = _ICON_COLOR
	icon_style.set_corner_radius_all(int(_about_icon_d / 2.0))
	_about_icon.add_theme_stylebox_override("normal", icon_style)
	_about_btn.add_child(_about_icon)

	vlabel.get_parent().add_child(_about_btn)
	call_deferred("_position_about_button")

func _position_about_button() -> void:
	if _about_btn == null:
		return
	var sz: Vector2 = _about_btn.get_combined_minimum_size()
	sz.y = max(sz.y, _about_pill_h)
	_about_btn.size = sz
	# Anchor to the bottom-right corner with small insets so the pill sits close
	# to the corner (nudged right and down vs. the earlier larger margin).
	var margin_right: float = 2.0
	var margin_bottom: float = 2.0
	_about_btn.anchor_left = 1.0
	_about_btn.anchor_top = 1.0
	_about_btn.anchor_right = 1.0
	_about_btn.anchor_bottom = 1.0
	_about_btn.offset_right = -margin_right
	_about_btn.offset_bottom = -margin_bottom
	_about_btn.offset_left = _about_btn.offset_right - sz.x
	_about_btn.offset_top = _about_btn.offset_bottom - sz.y
	if _about_icon != null:
		_about_icon.position = Vector2(10.0, (sz.y - _about_icon_d) / 2.0)

func _open_about() -> void:
	if _about_screen != null:
		_about_screen.call("open")

func create_grid():
	await get_tree().process_frame
	var view_mode: int = MainGlobals.game_chooser_view_mode
	var list_mode: bool = view_mode == MainGlobals.ViewMode.LIST or view_mode == MainGlobals.ViewMode.CATEGORIZED
	var hsep = %GamesGrid.get_theme_constant("h_separation")
	var sbsc = %ScrollContainer.get_theme_stylebox("panel")
	var pad_l = sbsc.get_margin(SIDE_LEFT)
	var pad_r = sbsc.get_margin(SIDE_RIGHT)
	var scrollbar_w = %ScrollContainer.get_v_scroll_bar().size.x
	var viewport_w = %ScrollContainer.get_viewport_rect().size.x
	var usable_w = viewport_w - pad_l - pad_r - scrollbar_w - pad_l

	game_buttons = []
	for child in %GamesGrid.get_children():
		child.queue_free()

	if MainCfg.single_game:
		btn_w = 600
		btn_font_size = 40
		n_columns = 1
		list_mode = false
		view_mode = MainGlobals.ViewMode.GRID
	else:
		%GamesGrid.add_theme_constant_override("v_separation", %GamesGrid.get_theme_constant("h_separation"))
		if list_mode:
			n_columns = 1
			var vsep: int = 4 if view_mode == MainGlobals.ViewMode.CATEGORIZED else 8
			%GamesGrid.add_theme_constant_override("v_separation", vsep)
			if MainGlobals.is_mobile():
				btn_w = 120
				_list_title_size = 40
				_list_desc_size = 35
				btn_h = _list_title_size + 3 * _list_desc_size + 28
			else:
				btn_w = 100
				_list_title_size = 23
				_list_desc_size = 20
				btn_h = _list_title_size + 2 * _list_desc_size + 16
		elif MainGlobals.is_mobile():
			btn_font_size = 40
			n_columns = 2
			btn_w = (usable_w - (n_columns-1)*hsep) / n_columns
		else:
			n_columns = 3
			btn_w = (usable_w - (n_columns-1)*hsep) / n_columns
	if btn_h == 0:
		btn_h = btn_w

	n_games = 0
	if view_mode == MainGlobals.ViewMode.CATEGORIZED and MainCfg.single_game.is_empty():
		_build_categorized_grid()
	else:
		for g in MainCfg.games:
			var game_folder: String = g[0]
			var game_name: String = g[1]
			var game_desc: String = g[2]
			var needs_login: bool = g[4] if g.size() > 4 else false
			if MainCfg.single_game.is_empty() or MainCfg.single_game == game_folder:
				add_game(game_folder, game_name, game_desc, needs_login, list_mode)
				n_games += 1
				if MainCfg.single_game == game_folder:
					%TitleLabel.text = g[1]

	%GamesGrid.columns = n_columns
	if view_mode == MainGlobals.ViewMode.LIST:
		%GamesGrid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	else:
		%GamesGrid.size_flags_horizontal = 6

	if n_games > 1 and !MainGlobals.sig_stop_active_game.is_connected(_on_global_stop_active_game):
		MainGlobals.sig_stop_active_game.connect(_on_global_stop_active_game)

	
func _process(_delta: float) -> void:
	if MainCfg.single_game and not auto_activated_game and MainGlobals.timems() - time_displayed > 1000:
		auto_activated_game = true
		set_active_game(load(added_game[0]).instantiate(), added_game[1])

var game_buttons = []
var dict_game_name_to_needs_login = {}
func add_game(game_path, game_name, game_desc, needs_login, list_mode):
	var scene_path = "res://" + game_path + "/scenes/main.tscn"
	added_game = [scene_path, game_name, needs_login]

	# if MainCfg.single_game:
	# 	set_active_game(load(scene_path).instantiate(), game_name)
	# 	return
	var btn
	var desc

	var texture_stem = "game_screen_full.png" if MainCfg.single_game else "game_screen_200.png"
	var texture_path = "res://" + game_path + "/art/" + texture_stem
	if list_mode:
		var line_w_desc = preload("res://scenes/game_select_list_mode_line.tscn").instantiate()
		%GamesGrid.add_child(line_w_desc)
		btn = line_w_desc.button_tex
		desc = line_w_desc.desc
	else:
		btn = preload("res://scenes/game_select_button.tscn").instantiate()
		%GamesGrid.add_child(btn)

	var lbl = btn.label#get_node("Label")
	# var rad = 16
	# pnl_style.set_corner_radius_all(rad)	
	lbl.text = "" if MainCfg.single_game or list_mode else game_name
	if list_mode:
		desc.set_vals(game_name, game_desc)
		desc.set_font_sizes(_list_title_size, _list_desc_size)
	btn.texture.texture_normal = load(texture_path)
	btn.texture.texture_hover = load(texture_path)
	btn.texture.stretch_mode = TextureButton.STRETCH_SCALE
	btn.texture.mouse_exited.connect(func(): btn.release_focus())

	await get_tree().process_frame
	var ls = lbl.label_settings
	if btn_w > 0:
		var btn_tex_size: int = btn_h if list_mode else btn_w
		btn.size.x = btn_tex_size
		btn.custom_minimum_size.x = btn_tex_size
		btn.custom_minimum_size.y = btn_tex_size
		if list_mode:
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# btn.size = Vector2(btn_w, btn_h)
		# btn.custom_minimum_size = Vector2(btn_w, btn_h)
	if ls and btn_font_size > 0:
		ls.font_size = btn_font_size

	# btn._update_shader_size()

	if list_mode:
		var pnl = btn.frame
		var sb = pnl.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		sb.border_color = Color8(155,100,0,255)		# normal is ffc900
		sb.set_border_width_all(2)
		pnl.add_theme_stylebox_override("panel", sb)

		var sep = %GamesGrid.get_theme_constant("h_separation")
		var sbsc = %ScrollContainer.get_theme_stylebox("panel")
		var pad_l = sbsc.get_margin(SIDE_LEFT)
		var pad_r = sbsc.get_margin(SIDE_RIGHT)
		var scrollbar_w = %ScrollContainer.get_v_scroll_bar().size.x
		var viewport_w = %ScrollContainer.get_viewport_rect().size.x
		var usable_w = viewport_w - pad_l - pad_r - scrollbar_w - pad_l

		var target_right_w = max(200.0, usable_w - btn.size.x - sep - 8)

		desc.size.x = target_right_w
		desc.custom_minimum_size.x = target_right_w
		desc.custom_minimum_size.y = btn_h
		desc.pressed.connect(func(): _record_played(game_path); set_active_game(load(scene_path).instantiate(), game_name))

	# btn.get_node("Button").connect("pressed", func(): set_active_game(load(scene_path).instantiate(), game_name))
	btn.texture.pressed.connect(func(): _record_played(game_path); set_active_game(load(scene_path).instantiate(), game_name))

	game_buttons.append([btn, needs_login])
	if needs_login:
		dict_game_name_to_needs_login[game_name] = true
	check_buttons_that_need_login()

func _input(event: InputEvent) -> void:
	if MainGlobals.ignore_keyboard_actions:
		return
	if event.is_action_pressed("change game") and not MainCfg.single_game:
		if MainGlobals.active_game != null and not MainGlobals.is_screen_visible("main_menu"):
			MainGlobals.game.show_yesno_dlg(self, "Change Game", 
				"Are you sure you want to lose your progress in this game ?", "Yes", "Oops, No", 
				Callable(self,"_on_confirmed_change_game"), Callable(self, "_on_cancelled_dialog"))
		else:
			_on_confirmed_change_game()

func _on_cancelled_dialog():
	MainGlobals.game.pause(false)

func _on_confirmed_change_game():
	# MainGlobals.game.pause(false)
	# MainGlobals.global_need_to_close_info_popups()
	abort_active_game()

func abort_active_game():
	MainGlobals.game.pause(false)
	MainGlobals.global_need_to_close_info_popups()
	sig_stop_active_game.emit()
	# n_games = 0
	create_grid()
	show()
	MainGlobals.add_action_button(null)
	
func _record_played(game_folder: String):
	MainGlobals.last_played_order.erase(game_folder)
	MainGlobals.last_played_order.insert(0, game_folder)
	MainGlobals.save_settings()
	MainCfg.move_to_top(game_folder)

func set_active_game(scene, game_name):
	MainGlobals.digitized_swipe_mode = false
	MainGlobals.draw_path_mode = false
	MainGlobals.add_action_button(null)
	if game_name in dict_game_name_to_needs_login and !BE.logged_in:
		return
	selected_game.emit(scene, game_name)
	hide()
	
func _on_global_stop_active_game():
	print("got stop game signal")
	abort_active_game()
	
func _on_confirmed_logout() -> void:
	BE.logout()
	_update_account_button()
	BE.sig_show_login_screen.emit()

func _on_BE_sig_logged_in(success: bool, _fail_reason: BE.LoginFailReasons) -> void:
	# Log.dbg("BE.sig_login_player in game chooser")
	if success:
		$FullScreenMessage.hide()
	_update_account_button()
	check_buttons_that_need_login()

func refresh_account_state() -> void:
	_update_account_button()

func check_buttons_that_need_login():
	for b in game_buttons:
		if b[1]:
			if BE.logged_in:
				b[0].modulate = Color(1,1,1,1)
			else:
				b[0].modulate = Color(0.5,0.5,0.5,0.5)

func _on_view_mode_button_pressed() -> void:
	MainGlobals.game_chooser_view_mode = (MainGlobals.game_chooser_view_mode + 1) % (MainGlobals.ViewMode.CATEGORIZED + 1)
	MainGlobals.save_settings()
	_update_view_mode_button()
	btn_h = 0
	create_grid()

func _update_view_mode_button() -> void:
	var next_mode: int = (MainGlobals.game_chooser_view_mode + 1) % (MainGlobals.ViewMode.CATEGORIZED + 1)
	var icons: Array = [_icon_grid, _icon_list, _icon_cat]
	%ListCheckButton.icon = icons[next_mode]
	%ListCheckButton.modulate = _ICON_COLOR

func _build_categorized_grid() -> void:
	var lpo: Array = MainGlobals.last_played_order
	var sorted_cats: Array = MainCfg.CATEGORY_ORDER.duplicate()
	sorted_cats.sort_custom(func(a: String, b: String) -> bool:
		return _cat_recent_index(a, lpo) < _cat_recent_index(b, lpo)
	)
	for cat in sorted_cats:
		var cat_games: Array = []
		for g in MainCfg.games:
			if g.size() > 3 and g[3] == cat:
				cat_games.append(g)
		if cat_games.is_empty():
			continue
		cat_games.sort_custom(func(a: Array, b: Array) -> bool:
			var ai: int = lpo.find(a[0])
			var bi: int = lpo.find(b[0])
			if ai == -1: ai = 999999
			if bi == -1: bi = 999999
			return ai < bi
		)
		_add_category_header(cat)
		for g in cat_games:
			var needs_login: bool = g[4] if g.size() > 4 else false
			add_game(g[0], g[1], g[2], needs_login, true)
			n_games += 1

func _cat_recent_index(cat: String, lpo: Array) -> int:
	var best: int = 999999
	for g in MainCfg.games:
		if g.size() > 3 and g[3] == cat:
			var idx: int = lpo.find(g[0])
			if idx != -1 and idx < best:
				best = idx
	return best

func _add_category_header(cat_name: String) -> void:
	var container: MarginContainer = MarginContainer.new()
	container.size_flags_horizontal = Control.SIZE_FILL
	container.add_theme_constant_override("margin_top", 4)
	container.add_theme_constant_override("margin_bottom", -4)
	container.add_theme_constant_override("margin_left", 8)
	container.add_theme_constant_override("margin_right", 0)
	var lbl: Label = Label.new()
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", _ICON_COLOR)
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.text = cat_name.to_upper()
	container.add_child(lbl)
	%GamesGrid.add_child(container)

extends CanvasLayer

signal selected_game(scene, game_name)
signal sig_stop_active_game

var n_games:int = 0
var time_displayed
var added_game = []
var auto_activated_game: bool = false

var btn_w: int = 200
var btn_h: int = 0
var btn_font_size: int = 0
var n_columns: int = 3
var _list_title_size: int = 24
var _list_desc_size: int = 20

var _account_btn: Button = null
var _account_status_dot: Panel = null
var _about_btn: Button = null
var _about_icon: Control = null
var _about_icon_d: float = 0.0
var _about_pill_h: float = 0.0
var _progress_screen = null
var _progress_btn: Button = null
var _about_screen: CanvasLayer = null
var _settings_screen: CanvasLayer = null

var _icon_grid: Texture2D = preload("res://art/grid-48.png")
var _icon_cat: Texture2D = preload("res://art/category_list_48.png")

const _ICON_COLOR: Color = Color(1.0, 0.8980392, 0.007843138, 1.0)

# THE SCREEN'S PALETTE: the one the result cards and the stats screens already use, so the first
# screen of the app looks like the rest of it. Everything here used to be the one bright yellow
# above -- title, category headers, game names, every row's frame, both bottom buttons, and the
# dashed road lines of the background tile -- so nothing stood out from anything else. The bright
# yellow is kept where it MEANS something: the game names, and the account icon of a full login.
const _GOLD: Color = ScreenBackdrop.ACCENT
const _HAIRLINE: Color = ScreenBackdrop.PANEL_FRAME
const _NAVY: Color = ResultCard.CARD_BG
const _BG_TOP: Color = Color(0.10, 0.12, 0.19)
const _BG_BOTTOM: Color = Color(0.045, 0.055, 0.09)
const _ROW_BG: Color = Color(0.13, 0.155, 0.225, 0.92)
const _ROW_BG_HOT: Color = Color(0.17, 0.20, 0.285, 0.96)
# Category headers: the gold, softened, so they sit a step below the app's name in the top bar.
const _HEADER_GOLD: Color = Color(0.85, 0.72, 0.46, 0.9)
# Every highlight's "switch off", so a scroll can clear them all (see _hover_highlight).
var _hot_resets: Array[Callable] = []
var _headers_added: int = 0
var _bottom_bar: Panel = null

func _ready() -> void:
	%TitleLabel.text = _titled(%TitleLabel.text)
	MainGlobals.load_settings()
	_dress_screen()
	_update_view_mode_button()
	create_grid()
	time_displayed = MainGlobals.timems()
	%VersionLabel.text = "V " + MainGlobals.version
	BE.sig_logged_in.connect(_on_BE_sig_logged_in)
	$FullScreenMessage.hide()
	_create_account_button()
	_create_about_button()

# 1. A QUIET BACKGROUND: a dark navy gradient. It was `art/pipe_4_exits.png`, a road junction from the
#    maze games tiled across the whole screen, which drew as yellow dashed lines behind everything.
# 4. ONE TOP BAR: the account icon, the title and the view button on a navy strip (no line under it:
#    tried, and removed). The title sat on a dark patch of its own -- a 26-unit outline round the
#    letters -- and the icons floated on the background either side of it.
func _dress_screen() -> void:
	var grad: Gradient = Gradient.new()
	grad.set_color(0, _BG_TOP)
	grad.set_color(1, _BG_BOTTOM)
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 4
	tex.height = 256
	var bg: TextureRect = $TextureRect
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	# The list's own panel was 50% black over the old tile; over a dark gradient it only muddies it.
	var sc_style: StyleBoxFlat = (%ScrollContainer.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	sc_style.bg_color = Color(0, 0, 0, 0)
	%ScrollContainer.add_theme_stylebox_override("panel", sc_style)
	%ScrollContainer.scroll_started.connect(_clear_highlights)

	var title: Label = %TitleLabel
	# Through the app's type scale: the scene's 40 is a phone size that stayed 40 on a phone, where
	# the category headers (scaled) came out the same size and the same gold as the app's name.
	MainGlobals.set_font_size(title, 38)
	title.add_theme_color_override("font_color", _GOLD)
	title.add_theme_constant_override("outline_size", 0)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 2)
	# The strip behind the bar's contents. A MarginContainer stacks its children, each filling it, so a
	# panel added FIRST is drawn under the rest and covers the whole bar (the bar has no margins).
	var bar_margin: MarginContainer = %TitleLabel.get_parent()
	var strip: Panel = Panel.new()
	strip.name = "TopBar"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = _NAVY
	strip.add_theme_stylebox_override("panel", sb)
	bar_margin.add_child(strip)
	bar_margin.move_child(strip, 0)

# 2. A ROW IS A CARD: navy, a step lighter than the background, with a faint gold hairline that turns
#    solid gold while it is pointed at or pressed. Every row had a 3-unit bright yellow border.
func _row_style(hot: bool) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = _ROW_BG_HOT if hot else _ROW_BG
	sb.set_border_width_all(2)
	sb.border_color = _GOLD if hot else _HAIRLINE
	sb.set_corner_radius_all(10)
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_content_margin(side, 8.0)
	return sb

# A grid tile's frame: gold, not the bright yellow, and bright while pointed at.
func _tile_frame(base: StyleBoxFlat, hot: bool) -> StyleBoxFlat:
	var sb: StyleBoxFlat = base.duplicate() as StyleBoxFlat
	sb.set_border_width_all(3 if hot else 2)
	sb.border_color = _ICON_COLOR if hot else _GOLD
	return sb

# Hot while the POINTER is over any of `parts` (a row is two buttons side by side, and moving from one
# to the other must not flicker). Hover only: it also lit on a press, and on a touchscreen the start
# of a drag to scroll IS a press, on whichever game the finger happened to land -- so dragging the
# list lit a game up. A touchscreen has no hover, so there is no highlight on a phone at all, and any
# scroll clears every highlight (a mouse drag on desktop starts over a row too).
func _hover_highlight(parts: Array, apply: Callable) -> void:
	if MainGlobals.is_mobile():
		return
	var over: Dictionary = {}
	var refresh: Callable = func() -> void: apply.call(not over.is_empty())
	_hot_resets.append(func() -> void: over.clear(); refresh.call())
	for part: Control in parts:
		var key: int = part.get_instance_id()
		part.mouse_entered.connect(func() -> void: over[key] = true; refresh.call())
		part.mouse_exited.connect(func() -> void: over.erase(key); refresh.call())

func _clear_highlights() -> void:
	for reset: Callable in _hot_resets:
		if reset.is_valid():
			reset.call()

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

	# App settings live on their own overlay, reached from About.
	_settings_screen = load("res://scripts/settings_screen.gd").new()
	add_child(_settings_screen)

	# Across-games progress. It belongs here rather than inside a game because its whole job is to
	# compare games with each other; a per-game window has nothing to compare against.
	_progress_screen = load("res://scripts/progress_screen.gd").new()
	add_child(_progress_screen)
	_about_screen.connect("sig_open_settings", Callable(self, "_open_settings"))

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
	_about_btn.add_theme_color_override("font_color", _GOLD)
	_about_btn.add_theme_color_override("font_hover_color", _GOLD)
	_about_btn.add_theme_color_override("font_pressed_color", _GOLD)
	_about_btn.add_theme_color_override("font_focus_color", _GOLD)
	_about_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_about_btn.pressed.connect(_open_about)

	# One pill background; the left content margin reserves space for the icon.
	var pill: StyleBoxFlat = StyleBoxFlat.new()
	# Mostly opaque. At 0.35 the two buttons (About and Progress) were see-through over the tile
	# grid behind them, so their text competed with whatever tile happened to be underneath.
	pill.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	pill.set_corner_radius_all(int(_about_pill_h / 2.0))
	pill.set_border_width_all(2)
	pill.border_color = _GOLD
	pill.content_margin_left = _about_icon_d + 18.0
	pill.content_margin_right = 18.0
	pill.content_margin_top = 4.0
	pill.content_margin_bottom = 4.0
	var pill_hover: StyleBoxFlat = pill.duplicate() as StyleBoxFlat
	pill_hover.bg_color = Color(0.18, 0.18, 0.18, 0.92)
	_about_btn.add_theme_stylebox_override("normal", pill)
	_about_btn.add_theme_stylebox_override("hover", pill_hover)
	_about_btn.add_theme_stylebox_override("pressed", pill_hover)
	_about_btn.add_theme_stylebox_override("focus", pill)
	_about_btn.custom_minimum_size = Vector2(0, _about_pill_h)

	# Round (i) icon as a child of the button so it travels with it. It is DRAWN, not typeset:
	# a Label's height is floored by the font's line box (ascent+descent), which the symbol
	# fallbacks inflate to ~1.5x the font size — so a d x d Label silently became d x 1.5d, the
	# "circle" came out as a rounded rect, and the glyph sat below the version text's center.
	# Drawing also makes the icon independent of the player's chosen game font.
	_about_icon = Control.new()
	_about_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_about_icon.custom_minimum_size = Vector2(_about_icon_d, _about_icon_d)
	_about_icon.size = Vector2(_about_icon_d, _about_icon_d)
	_about_icon.draw.connect(_draw_info_icon)
	_about_btn.add_child(_about_icon)

	# 5. A BAR BEHIND THE TWO BUTTONS (no line along its top: tried, and removed), so they read as part of the screen rather than floating over
	#    whatever game is scrolling underneath. It takes taps too: a tap on the bar must not start the
	#    game half-hidden behind it. The list's bottom spacer (create_grid) is taller, so the last
	#    game still scrolls clear.
	_bottom_bar = Panel.new()
	_bottom_bar.name = "BottomBar"
	_bottom_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	# See-through, a little: the list scrolling under it stays in view, dimmed, so the bar reads as a
	# layer over the list rather than the end of it.
	var bb: StyleBoxFlat = StyleBoxFlat.new()
	bb.bg_color = Color(_NAVY.r, _NAVY.g, _NAVY.b, 0.78)
	_bottom_bar.add_theme_stylebox_override("panel", bb)
	_bottom_bar.anchor_left = 0.0
	_bottom_bar.anchor_right = 1.0
	_bottom_bar.anchor_top = 1.0
	_bottom_bar.anchor_bottom = 1.0
	_bottom_bar.offset_top = -(_about_pill_h + 8.0)
	_bottom_bar.offset_bottom = 0.0
	vlabel.get_parent().add_child(_bottom_bar)

	vlabel.get_parent().add_child(_about_btn)

	_progress_btn = Button.new()
	_progress_btn.name = "ProgressButton"
	_progress_btn.text = "Progress"
	_progress_btn.add_theme_font_size_override("font_size", font_size)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_progress_btn.add_theme_color_override(c, _GOLD)
	_progress_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_progress_btn.pressed.connect(_open_progress)
	# This button has no icon, so it reserves no room for one. EVERY state needs that same margin:
	# reusing About's hover style here left the normal state at 18px and the hover state at
	# icon+18, so the padding jumped on hover and the label was pushed clean out of a button whose
	# width had been measured for the narrower style — the text simply vanished under the cursor.
	var ppill: StyleBoxFlat = pill.duplicate() as StyleBoxFlat
	ppill.content_margin_left = 18.0
	var ppill_hover: StyleBoxFlat = pill_hover.duplicate() as StyleBoxFlat
	ppill_hover.content_margin_left = 18.0
	_progress_btn.add_theme_stylebox_override("normal", ppill)
	_progress_btn.add_theme_stylebox_override("hover", ppill_hover)
	_progress_btn.add_theme_stylebox_override("pressed", ppill_hover)
	_progress_btn.add_theme_stylebox_override("focus", ppill)
	_progress_btn.custom_minimum_size = Vector2(0, _about_pill_h)
	vlabel.get_parent().add_child(_progress_btn)

	call_deferred("_position_about_button")

# The classic info mark: a filled disc with a dot and a stem, both symmetric about the disc's
# center, so the glyph is optically centered whatever the UI font happens to be.
func _draw_info_icon() -> void:
	var d: float = _about_icon_d
	var c: Vector2 = Vector2(d, d) * 0.5
	var ink: Color = Color(0.08, 0.08, 0.08, 1.0)
	_about_icon.draw_circle(c, d * 0.5, _GOLD)
	var r_dot: float = d * 0.075
	_about_icon.draw_circle(c + Vector2(0.0, -0.30 * d + r_dot), r_dot, ink)
	var stem_w: float = d * 0.15
	_about_icon.draw_rect(Rect2(c.x - stem_w * 0.5, c.y - 0.10 * d, stem_w, 0.40 * d), ink, true)

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
	if _progress_btn != null:
		var psz: Vector2 = _progress_btn.get_combined_minimum_size()
		psz.y = max(psz.y, _about_pill_h)
		_progress_btn.size = psz
		_progress_btn.anchor_left = 0.0
		_progress_btn.anchor_top = 1.0
		_progress_btn.anchor_right = 0.0
		_progress_btn.anchor_bottom = 1.0
		_progress_btn.offset_left = 2.0
		_progress_btn.offset_bottom = -2.0
		_progress_btn.offset_right = _progress_btn.offset_left + psz.x
		_progress_btn.offset_top = _progress_btn.offset_bottom - psz.y

func _open_about() -> void:
	if _about_screen != null:
		_about_screen.call("open")

func _open_settings() -> void:
	if _settings_screen != null:
		_settings_screen.call("open")

func _open_progress() -> void:
	if _progress_screen != null:
		_progress_screen.call("open")

func create_grid():
	await get_tree().process_frame
	var view_mode: int = MainGlobals.game_chooser_view_mode
	var list_mode: bool = view_mode == MainGlobals.ViewMode.CATEGORIZED
	var hsep = %GamesGrid.get_theme_constant("h_separation")
	var sbsc = %ScrollContainer.get_theme_stylebox("panel")
	var pad_l = sbsc.get_margin(SIDE_LEFT)
	var pad_r = sbsc.get_margin(SIDE_RIGHT)
	var scrollbar_w = %ScrollContainer.get_v_scroll_bar().size.x
	var viewport_w = %ScrollContainer.get_viewport_rect().size.x
	var usable_w = viewport_w - pad_l - pad_r - scrollbar_w - pad_l

	game_buttons = []
	_hot_resets.clear()
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
			%GamesGrid.add_theme_constant_override("v_separation", 4)
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
	_headers_added = 0
	if view_mode == MainGlobals.ViewMode.CATEGORIZED and MainCfg.single_game.is_empty():
		_build_categorized_grid()
	else:
		for g in MainCfg.games:
			if not MainCfg.runs_on_this_platform(g):
				continue
			var game_folder: String = g[0]
			var game_name: String = g[1]
			var game_desc: String = g[2]
			var needs_login: bool = g[4] if g.size() > 4 else false
			if MainCfg.single_game.is_empty() or MainCfg.single_game == game_folder:
				add_game(game_folder, game_name, game_desc, needs_login, list_mode)
				n_games += 1
				if MainCfg.single_game == game_folder:
					%TitleLabel.text = _titled(g[1])

	# ROOM TO SCROLL THE LAST GAME CLEAR OF THE BUTTONS. About and Progress float over the bottom
	# corners of the list, so at the end of the scroll the last game sat under them. An empty row,
	# as tall as those buttons plus a gap, lets the list scroll on until it is clear -- one spacer per
	# column, so a grid's last row is still a whole row.
	if n_games > 1:
		var pad_h: float = maxf(_about_pill_h, 40.0) + 16.0
		for _col in n_columns:
			var bottom_pad: Control = Control.new()
			bottom_pad.custom_minimum_size = Vector2(0, pad_h)
			bottom_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
			%GamesGrid.add_child(bottom_pad)

	%GamesGrid.columns = n_columns
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
	# Lights this game's row or tile: on hover (desktop), and on the tap that starts it (_launch).
	var mark_hot: Callable = Callable()

	# Every game ships a 200px tile. The full-size variants only ever existed for three games
	# and have been removed, so a single-game build shows the same image as the chooser grid.
	var texture_stem = "game_screen_200.png"
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
		var row_panel: PanelContainer = desc.get_parent().get_parent() as PanelContainer
		if row_panel != null:
			row_panel.add_theme_stylebox_override("panel", _row_style(false))
			mark_hot = func(hot: bool) -> void:
				if is_instance_valid(row_panel):
					row_panel.add_theme_stylebox_override("panel", _row_style(hot))
			_hover_highlight([btn.texture, desc], mark_hot)
		desc.pressed.connect(func(): _launch(game_path, scene_path, game_name, mark_hot))
	elif not MainCfg.single_game:
		var tile_frame: PanelContainer = btn.frame
		var base_sb: StyleBoxFlat = tile_frame.get_theme_stylebox("panel") as StyleBoxFlat
		tile_frame.add_theme_stylebox_override("panel", _tile_frame(base_sb, false))
		mark_hot = func(hot: bool) -> void:
			if is_instance_valid(tile_frame):
				tile_frame.add_theme_stylebox_override("panel", _tile_frame(base_sb, hot))
		_hover_highlight([btn.texture], mark_hot)

	# btn.get_node("Button").connect("pressed", func(): set_active_game(load(scene_path).instantiate(), game_name))
	btn.texture.pressed.connect(func(): _launch(game_path, scene_path, game_name, mark_hot))

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

# STARTING A GAME SHOWS AT ONCE. The tap used to load the game's scene, build it and start it all
# inside the press handler -- 150-400 ms on a desktop (Storm: 201 ms loading, 65 building, 133
# starting), several times that on a phone -- with the screen frozen, so a tap looked like nothing
# had happened. Now the tapped game lights up the same frame, the scene file loads on a background
# thread while the screen keeps drawing, and only building and starting it (which must be on the main
# thread) happen after. A second tap while one game is starting is ignored.
var _launching: bool = false

func _launch(game_path: String, scene_path: String, game_name: String, mark_hot: Callable) -> void:
	if _launching:
		return
	_launching = true
	if mark_hot.is_valid():
		mark_hot.call(true)
	_record_played(game_path)
	# Two frames: the highlight is drawn before anything heavy starts.
	await get_tree().process_frame
	await get_tree().process_frame
	var scene: PackedScene = null
	if ResourceLoader.load_threaded_request(scene_path) == OK:
		while ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		scene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if scene == null:
		scene = load(scene_path) as PackedScene      # the thread refused: load it the plain way
	if mark_hot.is_valid():
		mark_hot.call(false)          # hidden with the chooser; clean when it comes back
	_launching = false
	if scene != null:
		set_active_game(scene.instantiate(), game_name)

func set_active_game(scene, game_name):
	MainGlobals.digitized_swipe_mode = false
	MainGlobals.draw_path_mode = false
	MainGlobals.path_color_probe = Callable()
	MainGlobals.path_fade_sec = 0.6
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
	MainGlobals.game_chooser_view_mode = _other_view_mode()
	MainGlobals.save_settings()
	_update_view_mode_button()
	btn_h = 0
	create_grid()

func _update_view_mode_button() -> void:
	# The button shows the view it switches TO.
	%ListCheckButton.icon = _icon_grid if _other_view_mode() == MainGlobals.ViewMode.GRID else _icon_cat
	%ListCheckButton.modulate = _GOLD

# Two views, the grid and the list by category. A plain alphabetical list was a third, and was dropped.
func _other_view_mode() -> int:
	if MainGlobals.game_chooser_view_mode == MainGlobals.ViewMode.GRID:
		return MainGlobals.ViewMode.CATEGORIZED
	return MainGlobals.ViewMode.GRID

func _build_categorized_grid() -> void:
	var lpo: Array = MainGlobals.last_played_order
	var sorted_cats: Array = MainCfg.CATEGORY_ORDER.duplicate()
	sorted_cats.sort_custom(func(a: String, b: String) -> bool:
		return _cat_recent_index(a, lpo) < _cat_recent_index(b, lpo)
	)
	for cat in sorted_cats:
		var cat_games: Array = []
		for g in MainCfg.games:
			if g.size() > 3 and g[3] == cat and MainCfg.runs_on_this_platform(g):
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

# A package id ending in ".dev" is a development build, so say so in the title -- the dev app and
# the store app share a name and an icon, and the id is the only thing that separates them.
#
# On Android `user_data_dir` is /data/user/0/<applicationId>/files, so the id is one of its path
# segments. No JNI plugin, and it holds in debug or release, whoever installed the app.
func _titled(base: String) -> String:
	for part in OS.get_user_data_dir().split("/"):
		if part.ends_with(".dev"):
			return "%s dev" % base
	return base

func _cat_recent_index(cat: String, lpo: Array) -> int:
	var best: int = 999999
	for g in MainCfg.games:
		if g.size() > 3 and g[3] == cat and MainCfg.runs_on_this_platform(g):
			var idx: int = lpo.find(g[0])
			if idx != -1 and idx < best:
				best = idx
	return best

# 3. A CATEGORY HEADER THAT READS AS ONE: gold, through the app's type scale (it was a flat 20, the
#    smallest text on a phone -- smaller than the descriptions under it), with room above it, so each
#    group of games reads as a group. (A hairline running from it to the edge was tried and removed.)
func _add_category_header(cat_name: String) -> void:
	var container: MarginContainer = MarginContainer.new()
	container.size_flags_horizontal = Control.SIZE_FILL
	container.add_theme_constant_override("margin_top", 4 if _headers_added == 0 else 18)
	container.add_theme_constant_override("margin_bottom", 2)
	container.add_theme_constant_override("margin_left", 6)
	container.add_theme_constant_override("margin_right", 0)
	_headers_added += 1
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lbl: Label = Label.new()
	MainGlobals.set_font_size(lbl, 18)
	lbl.add_theme_color_override("font_color", _HEADER_GOLD)
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.text = cat_name.to_upper()
	row.add_child(lbl)
	container.add_child(row)
	%GamesGrid.add_child(container)

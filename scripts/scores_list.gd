extends CanvasLayer

var cell_widths = [300,300,300,300]
var list_row = preload("res://scenes/scores_list_row.tscn")

var user_texture = load("res://art/user_white_16.png")
var no_user_texture = load("res://art/option_button_icon_empty_16.png")

var show_level := false
var show_time := false
var level_as_name := false
var time_col_name: String = "Avg Time"

var progress_mode := false
var initial_progress_mode := false
var initial_chart_mode: bool = false
var game_key := ""
var _raw_scores := []
var _progress_level_pos := -1
var _progress_time_pos := -1
var _progress_pct_pos := -1
var _progress_level_names: Dictionary = {}  # level_id -> display name
var _progress_pct_label: String = "% Correct"
var _progress_pct_format: String = "%d"
var _progress_time_label: String = "Avg Time"
var _progress_time_format: String = "%d"
var _progress_time_is_pct: bool = false
var _progress_tab_name: String = "Speed"
var _progress_score_label: String = "Score"
var _progress_pct_integer: bool = false
var _score_col_font_size: int = 0
var _row_font_size: int = 0  # when > 0, add_line overrides font size for date + level columns

var _chart_mode: bool = false
var _chart_metric: int = 0  # 0=score, 1=avg_time, 2=pct_correct
var _chart_x_mode: int = 1  # 0=by date, 1=by index; default is index
var _chart_tab_button: Button = null
var _chart_area: VBoxContainer = null
var _metric_bar: HBoxContainer = null
var _metric_buttons: Array = []
var _x_mode_switch: CheckButton = null
var _pct_metric_btn: Button = null
var _chart_control: ChartControl = null
var _header_mc: Node = null

func _ready():
	$ScoresWindow.size = MainGlobals.full_screen_size
	$ScoresWindow.position = Vector2.ZERO
	$ScoresWindow.unresizable = true
	$ScoresWindow.borderless = true
	%Title.text = "Scores"
	%TabSpacer.visible = false
	%TabMargin.visible = false
	MainGlobals.set_visible("scores",true)

	_header_mc = $ScoresWindow/ColorRect/VBoxContainer/MarginContainer2

	# Add Chart tab button to TabBar alongside Scores/Speed
	var tab_bar: HBoxContainer = %SpeedTabButton.get_parent()

	# Wrap TabBar in a PanelContainer for dark bg + top-rounded outer corners
	var tab_bar_panel: PanelContainer = PanelContainer.new()
	tab_bar_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tab_bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	tab_bar_bg.bg_color = Color(0.14, 0.14, 0.17, 1.0)
	tab_bar_bg.corner_radius_top_left = 14
	tab_bar_bg.corner_radius_top_right = 14
	tab_bar_bg.corner_radius_bottom_left = 0
	tab_bar_bg.corner_radius_bottom_right = 0
	tab_bar_panel.add_theme_stylebox_override("panel", tab_bar_bg)
	%TabMargin.add_child(tab_bar_panel)
	tab_bar.reparent(tab_bar_panel)

	_chart_tab_button = Button.new()
	_chart_tab_button.text = "Chart"
	_chart_tab_button.visible = false
	_chart_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chart_tab_button.add_theme_font_size_override("font_size", 26)
	_chart_tab_button.pressed.connect(_on_chart_tab_pressed)
	tab_bar.add_child(_chart_tab_button)

	# Build chart area: metric selector bar + chart control
	_chart_area = VBoxContainer.new()
	_chart_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart_area.add_theme_constant_override("separation", 0)
	_chart_area.visible = false
	var chart_top_spacer: Control = Control.new()
	chart_top_spacer.custom_minimum_size = Vector2(0, 0)
	_chart_area.add_child(chart_top_spacer)

	var metric_margin: MarginContainer = MarginContainer.new()
	metric_margin.add_theme_constant_override("margin_left", 80)
	metric_margin.add_theme_constant_override("margin_right", 40)
	metric_margin.add_theme_constant_override("margin_top", 0)
	metric_margin.add_theme_constant_override("margin_bottom", 2)
	var bar_panel: PanelContainer = PanelContainer.new()
	bar_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.14, 0.14, 0.17, 1.0)
	bar_bg.corner_radius_top_left = 0
	bar_bg.corner_radius_top_right = 0
	bar_bg.corner_radius_bottom_left = 14
	bar_bg.corner_radius_bottom_right = 14
	bar_panel.add_theme_stylebox_override("panel", bar_bg)
	_metric_bar = HBoxContainer.new()
	_metric_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_metric_bar.add_theme_constant_override("separation", 0)
	var metric_labels: Array = ["Score", "Avg Time", "% Correct"]
	for idx: int in range(metric_labels.size()):
		var btn: Button = Button.new()
		btn.text = metric_labels[idx]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 19)
		btn.clip_text = false
		var captured_idx: int = idx
		btn.pressed.connect(func(): _on_metric_button_pressed(captured_idx))
		_metric_bar.add_child(btn)
		_metric_buttons.append(btn)
	_pct_metric_btn = _metric_buttons[2]
	bar_panel.add_child(_metric_bar)

	# X-axis mode toggle switch: floats freely to the right, no pill background
	_x_mode_switch = CheckButton.new()
	_x_mode_switch.text = "D/#"
	_x_mode_switch.set_pressed_no_signal(true)  # default: by index
	_x_mode_switch.add_theme_font_size_override("font_size", 19)
	var dark: Color = Color(0.22, 0.22, 0.22, 1.0)
	_x_mode_switch.add_theme_color_override("font_color", dark)
	_x_mode_switch.add_theme_color_override("font_hover_color", dark)
	_x_mode_switch.add_theme_color_override("font_pressed_color", dark)
	_x_mode_switch.add_theme_color_override("font_hover_pressed_color", dark)
	_x_mode_switch.add_theme_icon_override("checked", _make_toggle_texture(true))
	_x_mode_switch.add_theme_icon_override("unchecked", _make_toggle_texture(false))
	_x_mode_switch.add_theme_icon_override("checked_mirrored", _make_toggle_texture(true))
	_x_mode_switch.add_theme_icon_override("unchecked_mirrored", _make_toggle_texture(false))
	var switch_style: StyleBoxEmpty = StyleBoxEmpty.new()
	_x_mode_switch.add_theme_stylebox_override("normal", switch_style)
	_x_mode_switch.add_theme_stylebox_override("hover", switch_style)
	_x_mode_switch.add_theme_stylebox_override("pressed", switch_style)
	_x_mode_switch.add_theme_stylebox_override("focus", switch_style)
	_x_mode_switch.add_theme_stylebox_override("hover_pressed", switch_style)
	_x_mode_switch.toggled.connect(_on_x_mode_switch_toggled)

	# Outer row: pill panel (expands) + gap + free-floating switch
	var metric_row: HBoxContainer = HBoxContainer.new()
	metric_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metric_row.add_theme_constant_override("separation", 0)
	metric_row.add_child(bar_panel)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(40, 0)
	metric_row.add_child(gap)
	metric_row.add_child(_x_mode_switch)

	metric_margin.add_child(metric_row)

	var chart_panel: PanelContainer = PanelContainer.new()
	chart_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chart_style: StyleBoxFlat = StyleBoxFlat.new()
	chart_style.bg_color = Color(0.10, 0.10, 0.12, 1.0)
	chart_style.border_color = Color(0.85, 0.65, 0.0, 1.0)
	chart_style.set_border_width_all(3)
	chart_style.set_content_margin_all(3)
	chart_panel.add_theme_stylebox_override("panel", chart_style)
	_chart_control = ChartControl.new()
	_chart_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_panel.add_child(_chart_control)
	_chart_area.add_child(chart_panel)
	_chart_area.add_child(metric_margin)

	$ScoresWindow/ColorRect/VBoxContainer.add_child(_chart_area)

	_update_tab_visuals()
	await get_tree().process_frame
	_update_x_height()

func set_progress_data(raw_scores: Array, level_pos: int, time_pos: int, pct_pos: int = -1, level_names: Dictionary = {}, pct_label: String = "% Correct", pct_format: String = "%d", time_label: String = "Avg Time", time_format: String = "%d", time_is_pct: bool = false, tab_name: String = "", score_label: String = "Score", pct_integer: bool = false) -> void:
	_raw_scores = raw_scores
	_progress_level_pos = level_pos
	_progress_time_pos = time_pos
	_progress_pct_pos = pct_pos
	_progress_level_names = level_names
	_progress_pct_label = pct_label
	_progress_pct_format = pct_format
	_progress_time_label = time_label
	_progress_time_format = time_format
	_progress_time_is_pct = time_is_pct
	_progress_tab_name = tab_name if tab_name != "" else ("Speed" if time_label == "Avg Time" else time_label)
	_progress_score_label = score_label
	_progress_pct_integer = pct_integer
	%ScoresTabButton.text = score_label if score_label != "Score" else "Scores"
	if _metric_buttons.size() > 0:
		_metric_buttons[0].text = score_label
	if saved_table != null:
		_set_header("Score", _progress_score_label, 1, true)
	if _pct_metric_btn != null:
		_pct_metric_btn.text = _progress_pct_label
	if _metric_buttons.size() > 1:
		_metric_buttons[1].text = _progress_time_label
	%Title.text = "Stats"
	%TabSpacer.visible = true
	%TabMargin.visible = true
	%SpeedTabButton.visible = time_pos >= 0
	%SpeedTabButton.text = _progress_tab_name
	if _chart_tab_button != null:
		_chart_tab_button.visible = true
	# Restore saved x-mode preference (default 1 = by index)
	_chart_x_mode = MainGlobals.chart_x_mode_by_game.get(game_key, 1) if game_key != "" else 1
	if _x_mode_switch != null:
		_x_mode_switch.set_pressed_no_signal(_chart_x_mode == 1)
	if initial_chart_mode:
		_chart_mode = true
		progress_mode = false
	elif initial_progress_mode:
		progress_mode = true
	_update_tab_visuals()
	await get_tree().process_frame
	await get_tree().process_frame
	_update_x_height()
	if initial_chart_mode:
		_show_chart_area()
		create_chart()
	elif initial_progress_mode:
		create_progress_list()

func _update_x_height() -> void:
	var mc2: Node = $ScoresWindow/ColorRect/VBoxContainer/MarginContainer2
	var h: float = mc2.position.y + mc2.size.y
	$ScoresWindow/ColorRect/XCloseScene.set_tap_height(h)

func _set_header(field_name, text, widthidx, _is_panel_visible:=false):
	var panel = %Header.get_node("HBox/" + field_name + "Panel")
	panel.visible = _is_panel_visible
	var label = panel.get_node("Label")
	label.text = text
	if widthidx < cell_widths.size():
		panel.custom_minimum_size = Vector2(cell_widths[widthidx], 1)

func add_line(texts, is_from_user):
	var row = list_row.instantiate()
	var texture = row.get_node("HBox/TextureIcon")
	var lpanel = row.get_node("HBox/DatePanel")
	var rpanel = row.get_node("HBox/ScorePanel")
	var level_panel = row.get_node("HBox/LevelPanel")
	var level_label = level_panel.get_node("Label")
	var time_panel = row.get_node("HBox/TimePanel")
	var time_label = time_panel.get_node("Label")
	var llabel = lpanel.get_node("Label")
	var rlabel = rpanel.get_node("Label")
	# rlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if is_from_user:
		texture.texture = user_texture
	else:
		texture.texture = no_user_texture
	texture.hide()
	llabel.text = MainGlobals.cap_first_word(texts[0])
	rlabel.text = MainGlobals.cap_first_word(texts[1])
	if _score_col_font_size > 0:
		rlabel.add_theme_font_size_override("font_size", _score_col_font_size)
	elif _row_font_size > 0:
		rlabel.add_theme_font_size_override("font_size", _row_font_size + 2)
	if _row_font_size > 0:
		llabel.add_theme_font_size_override("font_size", _row_font_size)
	if texts.size() > 2:
		level_label.text = MainGlobals.cap_first_word(texts[2])
		if _row_font_size > 0:
			level_label.add_theme_font_size_override("font_size", _row_font_size)
	else:
		level_label.text = ""
	if texts.size() > 3:
		time_label.text = MainGlobals.cap_first_word(texts[3])
		if _row_font_size > 0:
			time_label.add_theme_font_size_override("font_size", _row_font_size)
	lpanel.custom_minimum_size = Vector2(cell_widths[0], 1)
	rpanel.custom_minimum_size = Vector2(cell_widths[1], 1)
	level_panel.custom_minimum_size = Vector2(cell_widths[2], 1)
	time_panel.custom_minimum_size = Vector2(cell_widths[3], 1)
	level_panel.visible = show_level
	time_panel.visible = show_time
	%GridContainer.add_child(row)

var saved_table = null

func create_list(input_table):
	var vis_cols: int = 2 + (1 if show_level else 0) + (1 if show_time else 0)
	var mobile: bool = MainGlobals.is_mobile()
	if vis_cols >= 4:
		_row_font_size = 26 if mobile else 20
	elif vis_cols == 3:
		_row_font_size = 28 if mobile else 22
	else:
		_row_font_size = 0
	_score_col_font_size = 0
	var monotonic: bool = MainGlobals.show_monotonic_scores
	var new_table: Array = []
	for i in range(input_table.size() - 1, -1, -1):
		new_table.insert(0, input_table[i])
	saved_table = new_table
	var table: Array = new_table
	if monotonic:
		var filtered: Array = []
		var best: int = -1
		for i in range(new_table.size() - 1, -1, -1):  # oldest to newest (new_table is newest-first)
			var score: int = int(new_table[i][1])
			if score > best:
				best = score
				filtered.insert(0, new_table[i])
		table = filtered
	var shown_building_msg:bool = false
	if table.size() > 50:
		%OverlayMessage.show()
		%OverlayMessage.disp("Preparing scores list")
		shown_building_msg = true
	var grid = %GridContainer
	for child in grid.get_children():
		child.queue_free()
	await get_tree().process_frame

	var fixed_width = %MarginContainer.get_child(0).get_size().x
	var column_weights = [6,4,2,4]
	var spacing = 0
	var icon_width = 32
	var weight_sum = 0
	if not show_level:
		column_weights[2] = 0
	if not show_time:
		column_weights[3] = 0
	for cw in column_weights:
		weight_sum += cw
	for i in column_weights.size():
		cell_widths[i] = (fixed_width - icon_width - spacing) * column_weights[i] / weight_sum

	_set_header("Date", "Date", 0, true)
	_set_header("Score", _progress_score_label, 1, true)
	_set_header("Level", "Level", 2, show_level)
	_set_header("Time", time_col_name, 3, show_time)

	var N = table.size()
	if N == 0:
		%OverlayMessage.show()
		%OverlayMessage.disp("No scores saved yet")
		return
	var last_update_time = 0
	for i in N:
		var row = table[i]
		# var texts = [row[0], row[1], "score", "time"]
		var texts = row.duplicate(true)
		var is_user_score = false
		add_line(texts, is_user_score)
		if shown_building_msg:
			var now = MainGlobals.timems()
			if now - last_update_time > 160 or i == 20:
				last_update_time = now
				%OverlayMessage.set_progress(int(100 * (i+1) / N))
				await get_tree().process_frame

	%OverlayMessage.hide()

func _on_x_close_scene_button_pressed() -> void:
	MainGlobals.set_visible("scores",false)
	queue_free()
	# hide()

func _on_check_button_toggled(toggled_on:bool) -> void:
	if progress_mode:
		MainGlobals.show_monotonic_speed = toggled_on
	else:
		MainGlobals.show_monotonic_scores = toggled_on
	MainGlobals.save_settings()
	if _chart_mode:
		pass  # chart ignores monotonic filter
	elif progress_mode:
		create_progress_list()
	elif saved_table != null:
		create_list(saved_table)

func _on_scores_tab_pressed() -> void:
	_chart_mode = false
	progress_mode = false
	_save_tab_pref("scores")
	_update_tab_visuals()
	_show_table_area()
	if saved_table != null:
		create_list(saved_table)
	else:
		_set_header("Date", "Date", 0, true)
		_set_header("Score", _progress_score_label, 1, true)
		_set_header("Level", "Level", 2, show_level)
		_set_header("Time", time_col_name, 3, show_time)

func _on_speed_tab_pressed() -> void:
	_chart_mode = false
	progress_mode = true
	_save_tab_pref("speed")
	_update_tab_visuals()
	_show_table_area()
	create_progress_list()

func _on_chart_tab_pressed() -> void:
	_chart_mode = true
	progress_mode = false
	_save_tab_pref("chart")
	_update_tab_visuals()
	_show_chart_area()
	create_chart()

func _show_table_area() -> void:
	if _header_mc != null:
		_header_mc.visible = true
	%MarginContainer.visible = true
	if _chart_area != null:
		_chart_area.visible = false

func _show_chart_area() -> void:
	if _header_mc != null:
		_header_mc.visible = false
	%MarginContainer.visible = false
	if _chart_area != null:
		_chart_area.visible = true

func _update_tab_visuals() -> void:
	var scores_active: bool = not progress_mode and not _chart_mode
	var speed_active: bool = progress_mode and not _chart_mode
	var chart_active: bool = _chart_mode
	_apply_tab_style(%ScoresTabButton, scores_active)
	_apply_tab_style(%SpeedTabButton, speed_active)
	if _chart_tab_button != null:
		_apply_tab_style(_chart_tab_button, chart_active)
	var mono: bool = MainGlobals.show_monotonic_speed if progress_mode else MainGlobals.show_monotonic_scores
	%MonotonicCheckButton.set_pressed_no_signal(mono)
	# Update metric button pill style
	for i: int in range(_metric_buttons.size()):
		_apply_metric_style(_metric_buttons[i], i == _chart_metric)

func _apply_tab_style(btn: Button, is_active: bool) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	if is_active:
		style.bg_color = Color(0.85, 0.65, 0.0, 1.0)
		btn.add_theme_color_override("font_color", Color(0.1, 0.08, 0.0, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(0.1, 0.08, 0.0, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(0.1, 0.08, 0.0, 1.0))
	else:
		style.bg_color = Color(0, 0, 0, 0)
		style.corner_radius_top_left = 0
		style.corner_radius_top_right = 0
		btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(0.85, 0.85, 0.85, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.85, 0.85, 1.0))
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _apply_metric_style(btn: Button, is_active: bool) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	if is_active:
		style.bg_color = Color(0.85, 0.65, 0.0, 1.0)
		btn.add_theme_color_override("font_color", Color(0.1, 0.08, 0.0, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(0.1, 0.08, 0.0, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(0.1, 0.08, 0.0, 1.0))
	else:
		style.bg_color = Color(0, 0, 0, 0)
		btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(0.85, 0.85, 0.85, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.85, 0.85, 1.0))
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _save_tab_pref(tab: String) -> void:
	if game_key != "":
		MainGlobals.progress_tab_by_game[game_key] = tab
		MainGlobals.save_settings()

func create_chart() -> void:
	if _chart_control == null:
		return
	var has_time: bool = _progress_time_pos >= 0
	var has_level: bool = _progress_level_pos >= 0 and has_time
	if _metric_buttons.size() > 1:
		_metric_buttons[1].visible = has_time
	if _pct_metric_btn != null:
		_pct_metric_btn.visible = has_level and _progress_pct_pos >= 0
	if _chart_metric == 1 and not has_time:
		_chart_metric = 0
	if _chart_metric == 2 and _progress_pct_pos < 0:
		_chart_metric = 0
	_update_tab_visuals()
	var series_list: Array = []
	match _chart_metric:
		0:
			if _progress_level_pos >= 0:
				var level_pts: Dictionary = {}
				for row in _raw_scores:
					if row.size() <= 1 or int(row[1]) < 0:
						continue
					var level: int = row[_progress_level_pos] if row.size() > _progress_level_pos else 0
					if not level_pts.has(level):
						level_pts[level] = []
					level_pts[level].append(Vector2(float(row[0]), float(row[1])))
				var levels: Array = level_pts.keys()
				levels.sort()
				for si: int in range(levels.size()):
					var level: int = levels[si]
					var lname: String = _progress_level_names.get(level, "L%d" % level)
					series_list.append({"label": lname, "color": ChartControl.SERIES_COLORS[si % 8], "points": level_pts[level]})
			else:
				var pts: Array = []
				for row in _raw_scores:
					if row.size() > 1 and int(row[1]) >= 0:
						pts.append(Vector2(float(row[0]), float(row[1])))
				if not pts.is_empty():
					series_list.append({"label": _progress_score_label, "color": ChartControl.SERIES_COLORS[0], "points": pts})
			_chart_control.y_label = _progress_score_label
		1:
			if _progress_level_pos >= 0:
				var level_pts: Dictionary = {}
				for row in _raw_scores:
					if row.size() <= _progress_time_pos:
						continue
					var time_ms: int = row[_progress_time_pos]
					if time_ms <= 0 or time_ms == 9999:
						continue
					var level: int = row[_progress_level_pos]
					if not level_pts.has(level):
						level_pts[level] = []
					level_pts[level].append(Vector2(float(row[0]), float(time_ms)))
				var levels: Array = level_pts.keys()
				levels.sort()
				for si: int in range(levels.size()):
					var level: int = levels[si]
					var lname: String = _progress_level_names.get(level, "L%d" % level)
					series_list.append({"label": lname, "color": ChartControl.SERIES_COLORS[si % 8], "points": level_pts[level]})
			else:
				var pts: Array = []
				for row in _raw_scores:
					if row.size() <= _progress_time_pos:
						continue
					var time_ms: int = row[_progress_time_pos]
					if time_ms < 0 or (not _progress_time_is_pct and time_ms == 0) or time_ms == 9999:
						continue
					pts.append(Vector2(float(row[0]), float(time_ms)))
				if not pts.is_empty():
					series_list.append({"label": _progress_time_label, "color": ChartControl.SERIES_COLORS[0], "points": pts})
			_chart_control.y_label = _progress_time_label
		2:
			if _progress_pct_pos < 0:
				return
			var level_pts: Dictionary = {}
			for row in _raw_scores:
				if row.size() <= _progress_pct_pos:
					continue
				var time_ms: int = row[_progress_time_pos]
				if time_ms <= 0 or time_ms == 9999:
					continue
				var pct: int = int(row[_progress_pct_pos])
				if pct < 0:
					continue
				var level: int = row[_progress_level_pos]
				if not level_pts.has(level):
					level_pts[level] = []
				level_pts[level].append(Vector2(float(row[0]), float(pct)))
			var levels: Array = level_pts.keys()
			levels.sort()
			for si: int in range(levels.size()):
				var level: int = levels[si]
				var lname: String = _progress_level_names.get(level, "L%d" % level)
				series_list.append({"label": lname, "color": ChartControl.SERIES_COLORS[si % 8], "points": level_pts[level]})
			_chart_control.y_label = _progress_pct_label
			_chart_control.y_max_override = 100.0
	if (_chart_metric == 2 and not _progress_pct_integer) or (_chart_metric == 1 and _progress_time_is_pct):
		_chart_control.y_max_override = 100.0
	else:
		_chart_control.y_max_override = -1.0
	_chart_control.y_integer_only = (_chart_metric == 2 and _progress_pct_integer)
	_chart_control.y_min_padding = 0.1 if (_chart_metric == 1 and not _progress_time_is_pct) else 0.0
	if _chart_metric == 1 and not _progress_time_is_pct and _progress_time_format == "%d ms":
		_chart_control.y_label_divisor = 1000.0
		_chart_control.y_label_format = "%.1f s"
	else:
		_chart_control.y_label_divisor = 1.0
		_chart_control.y_label_format = ""
	_chart_control.x_as_index = (_chart_x_mode == 1)
	if _chart_x_mode == 1:
		# Assign a single global chronological index across all series so that
		# older sessions always appear further left regardless of which series they belong to.
		var all_pts: Array = []
		for si: int in range(series_list.size()):
			for pt: Vector2 in series_list[si]["points"]:
				all_pts.append({"x": pt.x, "y": pt.y, "si": si})
		all_pts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["x"] < b["x"])
		var new_pts: Array = []
		for si: int in range(series_list.size()):
			new_pts.append([])
		for i: int in range(all_pts.size()):
			var entry: Dictionary = all_pts[i]
			new_pts[entry["si"]].append(Vector2(float(i + 1), entry["y"]))
		for si: int in range(series_list.size()):
			series_list[si]["points"] = new_pts[si]
	_chart_control.set_series(series_list)

func _on_metric_button_pressed(idx: int) -> void:
	_chart_metric = idx
	_update_tab_visuals()
	create_chart()

func _on_x_mode_switch_toggled(toggled_on: bool) -> void:
	_chart_x_mode = 1 if toggled_on else 0
	if game_key != "":
		MainGlobals.chart_x_mode_by_game[game_key] = _chart_x_mode
		MainGlobals.save_settings()
	_update_tab_visuals()
	create_chart()

func _fmt_date(unixtime: int) -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unixtime)
	return "%04d/%02d/%02d" % [dt.year, dt.month, dt.day]

func _fmt_datetime(unixtime: int) -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unixtime)
	return "%04d/%02d/%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]

func _add_centered_message(grid: Control, text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 60)
	grid.add_child(spacer)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color.YELLOW)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_FILL
	grid.add_child(lbl)

func create_progress_list() -> void:
	var has_pct_peek: bool = _progress_pct_pos >= 0
	var vis_cols_p: int = 2 + (1 if has_pct_peek else 0)
	var mobile_p: bool = MainGlobals.is_mobile()
	if vis_cols_p >= 4:
		_row_font_size = 26 if mobile_p else 20
		_score_col_font_size = 0
	elif vis_cols_p == 3:
		_row_font_size = 28 if mobile_p else 22
		_score_col_font_size = 0
	else:
		_row_font_size = 0
		_score_col_font_size = 32
	var grid = %GridContainer
	for child in grid.get_children():
		child.queue_free()
	await get_tree().process_frame

	if _progress_time_pos < 0 or _raw_scores.is_empty():
		_add_centered_message(grid, "No %s data available" % _progress_time_label.to_lower())
		return

	var has_pct: bool = _progress_pct_pos >= 0
	var use_levels: bool = _progress_level_pos >= 0

	# Collect entries
	var all_entries: Array = []
	var level_data: Dictionary = {}
	for row in _raw_scores:
		if row.size() <= _progress_time_pos:
			continue
		var time_ms: int = row[_progress_time_pos]
		if time_ms < 0 or (not _progress_time_is_pct and time_ms == 0) or time_ms == 9999:
			continue
		var date_str: String = _fmt_datetime(row[0])
		var entry: Dictionary = {"date": date_str, "time_ms": time_ms, "pct": -1}
		if has_pct and row.size() > _progress_pct_pos:
			entry["pct"] = int(row[_progress_pct_pos])
		if use_levels:
			var level: int = row[_progress_level_pos]
			if not level_data.has(level):
				level_data[level] = []
			level_data[level].append(entry)
		else:
			all_entries.append(entry)

	var is_empty: bool = level_data.is_empty() if use_levels else all_entries.is_empty()
	if is_empty:
		_add_centered_message(grid, "No %s data yet — play some games first" % _progress_time_label.to_lower())
		return

	var monotonic: bool = MainGlobals.show_monotonic_speed

	# Compute column widths
	var orig_show_level := show_level
	var orig_show_time := show_time
	show_level = has_pct
	show_time = false
	var fixed_width: float = %MarginContainer.get_child(0).get_size().x
	var column_weights: Array
	if has_pct:
		column_weights = [5, 3, 2, 0]
	else:
		column_weights = [6, 4, 0, 0]
	var icon_width := 32
	var weight_sum := 0
	for cw in column_weights:
		weight_sum += cw
	for i in column_weights.size():
		cell_widths[i] = (fixed_width - icon_width) * column_weights[i] / weight_sum

	_set_header("Date", "Date", 0, true)
	_set_header("Score", _progress_time_label, 1, true)
	_set_header("Level", _progress_pct_label, 2, has_pct)
	_set_header("Time", "", 3, false)

	var _emit_entries := func(entries: Array) -> void:
		var filtered: Array = []
		var best_ms := 999999
		for entry in entries:
			var t: int = entry.time_ms
			if not monotonic or t < best_ms:
				if monotonic:
					best_ms = t
				filtered.append(entry)
		filtered.reverse()
		for entry in filtered:
			var line: Array = [entry.date, _progress_time_format % entry.time_ms]
			if has_pct and entry.pct >= 0:
				line.append(_progress_pct_format % entry.pct)
			add_line(line, false)

	if use_levels:
		var levels: Array = level_data.keys()
		levels.sort()
		levels.reverse()
		for level in levels:
			var hdr := Label.new()
			hdr.text = "  " + _progress_level_names.get(level, "Level %d" % level)
			hdr.size_flags_horizontal = Control.SIZE_FILL
			hdr.add_theme_color_override("font_color", Color(1, 0.8, 0, 1))
			hdr.add_theme_font_size_override("font_size", 26)
			hdr.add_theme_font_override("font", MainGlobals.get_system_sans_font())
			var hdr_mc: MarginContainer = MarginContainer.new()
			hdr_mc.size_flags_horizontal = Control.SIZE_FILL
			hdr_mc.add_theme_constant_override("margin_top", 0)
			hdr_mc.add_theme_constant_override("margin_bottom", -12)
			hdr_mc.add_theme_constant_override("margin_left", 0)
			hdr_mc.add_theme_constant_override("margin_right", 0)
			hdr_mc.add_child(hdr)
			grid.add_child(hdr_mc)
			_emit_entries.call(level_data[level])
	else:
		_emit_entries.call(all_entries)

	show_level = orig_show_level
	show_time = orig_show_time

func _make_toggle_texture(checked: bool) -> ImageTexture:
	var W: int = 56
	var H: int = 28
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var capsule_color: Color = Color(0.15, 0.15, 0.17, 1.0)
	var dot_color: Color = Color(0.85, 0.65, 0.0, 1.0)
	var r: float = float(H) * 0.5        # capsule end radius = 14
	var dot_r: float = r - 5.0           # dot radius = 9
	var dot_cx: float = float(W) - r if checked else r
	for y: int in range(H):
		for x: int in range(W):
			var fx: float = float(x) + 0.5
			var fy: float = float(y) + 0.5
			var in_capsule: bool = (fx >= r and fx <= float(W) - r) \
				or Vector2(fx, fy).distance_to(Vector2(r, r)) <= r \
				or Vector2(fx, fy).distance_to(Vector2(float(W) - r, r)) <= r
			var in_dot: bool = Vector2(fx, fy).distance_to(Vector2(dot_cx, r)) <= dot_r
			if in_dot:
				img.set_pixel(x, y, dot_color)
			elif in_capsule:
				img.set_pixel(x, y, capsule_color)
			else:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	return ImageTexture.create_from_image(img)

func on_esc_pressed():
	_on_x_close_scene_button_pressed()

func _on_scores_window_window_input(event:InputEvent) -> void:
	if event.is_action_pressed("esc"):
		on_esc_pressed()
	elif event.is_action_pressed("change game"):
		_on_x_close_scene_button_pressed()
		MainGlobals.stop_active_game()

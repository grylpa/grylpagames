extends "res://scripts/scores_list.gd"
# Typit scores screen = standard scores_list + a "Keys" tab.
# This is an inherited scene (root instances scores_list.tscn, script replaced).
# Because it IS a scores_list, closing (X button) works exactly like every other game.

const ORANGE: Color = Color(0.85, 0.65, 0.0, 1.0)   # selected tab background
const HDR_YELLOW: Color = Color(1.0, 1.0, 0.0, 1.0)  # standard table header color
const DIST_Y_MAX: float = 150.0                      # distance chart capped at 150%

var _typit_font: Font = null
var _key_sessions: Array = []
var _keys_area: Control = null   # whole keys page (info + fixed header + scrolling data)
var _keys_margin: MarginContainer = null   # the framed panel around it, shown/hidden as a tab
var _keys_btn: Button = null
var _view_level: int = 1         # which level's key data is shown

# Relabel only the GRID column header (not the tab buttons, which are set elsewhere):
# "Speed" → "Speed (cpm)", "Distance" → "Distance %".
func _set_header(field_name, text, widthidx, _is_panel_visible = false):
	if field_name == "Score":
		if text == "Speed":
			text = "Speed (cpm)"
		elif text == "Distance":
			text = "Distance %"
	super._set_header(field_name, text, widthidx, _is_panel_visible)

# Column widths and row metrics, in logical px, fixed so header and data rows align perfectly.
#
# Every number here is the DESKTOP value and MainGlobals scales it for a phone (x1.6), the way
# the rest of the app does it. They used to be flat constants, which is why this tab was typeset
# a size larger than the screen around it on desktop: the tab button carried a bare 26 while
# every other tab goes through set_font_size(20), and the header row carried a bare 24 against
# the standard table header's set_font_size(16). The PHONE numbers are the authored ones --
# typit only ships on a phone -- so the desktop bases below are chosen to reproduce them
# exactly: 56 / 70 / 18 / 56 / 104 / 93 wide, a 48px graphic and a 10px gutter.
var _col_key: float
var _col_gfx: float
var _col_npad: float
var _col_n: float
var _col_val: float
var _col_std: float
var _row_pad_left: float
var _side_pad: int
var _gfx_h: float

func _init_metrics() -> void:
	_col_key = float(MainGlobals.ui_font_size(35))
	_col_gfx = float(MainGlobals.ui_font_size(44))
	_col_npad = float(MainGlobals.ui_font_size(11))
	_col_n = float(MainGlobals.ui_font_size(35))
	_col_val = float(MainGlobals.ui_font_size(65))
	_col_std = float(MainGlobals.ui_font_size(58))
	_row_pad_left = float(MainGlobals.ui_font_size(6))
	_side_pad = MainGlobals.ui_font_size(6)
	_gfx_h = float(MainGlobals.ui_font_size(30))

# Override: clamp distance values to DIST_Y_MAX so the chart never draws off-screen,
# then build the standard screen and inject the Keys tab.
func set_progress_data(raw_scores: Array, level_pos: int, time_pos: int, pct_pos: int = -1,
		level_names: Dictionary = {}, pct_label: String = "% Correct", pct_format: String = "%d",
		time_label: String = "Avg Time", time_format: String = "%d", time_is_pct: bool = false,
		tab_name: String = "", score_label: String = "Score", pct_integer: bool = false) -> void:
	# Distance metric uses time_pos (index 9). Clamp those values to DIST_Y_MAX.
	var clamped: Array = []
	for row in raw_scores:
		if row is Array:
			var r: Array = (row as Array).duplicate()
			if time_pos >= 0 and r.size() > time_pos:
				r[time_pos] = mini(int(r[time_pos]), int(DIST_Y_MAX))
			clamped.append(r)
		else:
			clamped.append(row)

	await super.set_progress_data(clamped, level_pos, time_pos, pct_pos, level_names,
		pct_label, pct_format, time_label, time_format, time_is_pct, tab_name,
		score_label, pct_integer)

	_typit_font = MainGlobals.get_system_sans_font()
	_key_sessions = _load_key_sessions()
	_add_keys_tab()

# Override: pin the distance chart's y axis at DIST_Y_MAX.
func create_chart() -> void:
	super.create_chart()
	if _chart_metric == 1 and is_instance_valid(_chart_control):
		_chart_control.y_max_override = DIST_Y_MAX
		_chart_control.queue_redraw()

# ---- Key data ----

func _load_key_sessions() -> Array:
	var path: String = TypitG.get_key_data_path()
	if not FileAccess.file_exists(path):
		return []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var data: Variant = file.get_var()
	file.close()
	if data is Dictionary:
		var s: Variant = (data as Dictionary).get("sessions", [])
		if s is Array:
			return s as Array
	return []

# ---- Inject Keys tab ----

func _add_keys_tab() -> void:
	var speed_btn: Node = find_child("SpeedTabButton", true, false)
	if speed_btn == null:
		return
	var tab_bar: Node = speed_btn.get_parent()

	_keys_btn = Button.new()
	_keys_btn.text = "Keys"
	_keys_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MainGlobals.set_font_size(_keys_btn, 20)   # the size every other tab is set to
	_keys_btn.pressed.connect(_on_keys_tab_pressed)
	tab_bar.add_child(_keys_btn)
	_apply_tab_style(_keys_btn, false)

	# Every OTHER tab in the strip, found rather than named. Naming them is what broke this:
	# Scores, Speed and Charts were listed here and the Summary tab, added to scores_list later,
	# was not -- so pressing Summary left the Keys page on screen and the Keys tab lit.
	for b: Button in _sibling_tabs():
		b.pressed.connect(_on_standard_tab_pressed)
	# The strip now has one more tab than the base class sized it for.
	fit_tab_fonts()

	var vbox: Node = get_node_or_null("ScoresWindow/ColorRect/VBoxContainer")
	if vbox == null:
		return

	# Keys page = VBox [ info label, fixed header row, scrolling data ], inside the same framed
	# panel every other tab opens onto — it is a tab of this screen and has to look like one.
	var page: VBoxContainer = VBoxContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 4)
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", content_frame())
	panel.add_child(page)
	_keys_margin = MarginContainer.new()
	_keys_margin.name = "KeysMargin"
	_keys_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_keys_margin.add_theme_constant_override("margin_bottom", 10)
	_keys_margin.visible = false
	_keys_margin.add_child(panel)
	# Into the tab stack, so the Keys tab joins its content the way the others do.
	if _tabs_stack != null:
		_tabs_stack.add_child(_keys_margin)
	else:
		vbox.add_child(_keys_margin)
	_content_areas.append(_keys_margin)
	_keys_area = page

	_view_level = TypitG.selected_level
	_build_keys_content(page)

	# Restore the Keys tab if it was the last-used tab
	var pref: String = ""
	if game_key != "":
		pref = MainGlobals.progress_tab_by_game.get(game_key, "")
	if pref == "keys":
		_on_keys_tab_pressed()

# The tab buttons other than this game's own, in strip order.
func _sibling_tabs() -> Array[Button]:
	var out: Array[Button] = []
	if _keys_btn == null or not is_instance_valid(_keys_btn):
		return out
	for c: Node in _keys_btn.get_parent().get_children():
		if c is Button and c != _keys_btn:
			out.append(c as Button)
	return out

func _on_keys_tab_pressed() -> void:
	_save_tab_pref("keys")
	# One surface, chosen by name -- the same switch every other tab goes through. This used to
	# show the chart and then hide it again, which left the window's empty-state card up.
	_show_only(_keys_margin)
	%OverlayMessage.hide()
	_sync_stack_expand()
	_apply_tab_style(_keys_btn, true)
	for b: Button in _sibling_tabs():
		_apply_tab_style(b, false)

func _on_standard_tab_pressed() -> void:
	# The surfaces are already handled by _show_only; only this tab's own lit state is left.
	if _keys_btn:
		_apply_tab_style(_keys_btn, false)

# ---- Keys tab content ----

func _rebuild_keys() -> void:
	if _keys_area == null:
		return
	for c in _keys_area.get_children():
		c.queue_free()
	_build_keys_content(_keys_area as VBoxContainer)

func _build_keys_content(page: VBoxContainer) -> void:
	_init_metrics()
	var key_stats: Dictionary = _aggregate_key_stats()
	var fs_info: int = MainGlobals.ui_font_size(15)
	# The one size that is not free to be chosen: scores_list._set_header sets the standard
	# table header from 16, and this table sits behind a tab beside that one.
	var fs_hdr: int = MainGlobals.ui_font_size(16)
	var fs_name: int = MainGlobals.ui_font_size(16)
	var fs_stats: int = MainGlobals.ui_font_size(15)

	# Level selector row (1..5)
	_build_level_selector(page, fs_info)

	if key_stats.is_empty():
		_info_label(page, "No data for level %d yet." % _view_level, fs_info)
		return

	var n_s: int = TypitG.KEY_STATS_SESSIONS
	_info_label(page,
		("last %d sessions" % n_s if n_s > 0 else "all sessions") \
		+ "  ·  position from center, % of half key height",
		fs_info)

	# Fixed header row (NOT scrolled)
	var hdr_margin: MarginContainer = _side_margin()
	hdr_margin.add_theme_constant_override("margin_bottom", MainGlobals.ui_font_size(-4))
	page.add_child(hdr_margin)
	hdr_margin.add_child(_build_header_row(fs_hdr))

	# Scrolling data area
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	var data_margin: MarginContainer = _side_margin()
	scroll.add_child(data_margin)

	var data_vbox: VBoxContainer = VBoxContainer.new()
	data_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	data_vbox.add_theme_constant_override("separation", MainGlobals.ui_font_size(2))
	data_margin.add_child(data_vbox)

	var key_order: String = "qwertyuiopasdfghjklzxcvbnm "
	var shown: int = 0
	for i in range(key_order.length()):
		var ch: String = key_order[i]
		if not key_stats.has(ch):
			continue
		if int(key_stats[ch].count) < 1:
			continue
		_build_key_row(data_vbox, ch, key_stats[ch], fs_name, fs_stats)
		shown += 1

	if shown == 0:
		_info_label(data_vbox, "No key data for the current level.", fs_info)

func _side_margin() -> MarginContainer:
	var mc: MarginContainer = MarginContainer.new()
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mc.add_theme_constant_override("margin_left", _side_pad)
	mc.add_theme_constant_override("margin_right", _side_pad)
	return mc

# The row of level buttons, from the shared LevelPicker so it and the yes/no games' confusion
# matrix are one control rather than two that were drawn to look alike and then drifted.
func _build_level_selector(page: VBoxContainer, _fs: int) -> void:
	var margin: MarginContainer = _side_margin()
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", MainGlobals.ui_font_size(-6))
	page.add_child(margin)

	var levels: Array = []
	for lvl in range(1, TypitG.num_levels() + 1):
		levels.append(str(lvl))
	var made: Dictionary = LevelPicker.build("Level:", levels,
		func(i: int) -> void: _on_level_selected(i + 1))
	LevelPicker.select(made["buttons"], _view_level - 1)
	margin.add_child(made["row"])

func _on_level_selected(lvl: int) -> void:
	if lvl == _view_level:
		return
	_view_level = lvl
	_rebuild_keys()

func _build_header_row(fs: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_spacer(row, _row_pad_left)
	_cell(row, "Key", _col_key, fs, HDR_YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	_cell(row, "", _col_gfx, fs, HDR_YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	_spacer(row, _col_npad)
	_cell(row, "n", _col_n, fs, HDR_YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	_cell(row, "dx avg", _col_val, fs, HDR_YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	_cell(row, "dx std", _col_std, fs, HDR_YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	_cell(row, "dy avg", _col_val, fs, HDR_YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	_cell(row, "dy std", _col_std, fs, HDR_YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	return row

func _build_key_row(parent: Node, ch: String, ks: Dictionary,
		fs_name: int, fs_stats: int) -> void:
	var count: int = ks.count
	var kw: float = ks.key_w
	var kh: float = ks.key_h
	# dx/dy are the relative tap POSITION from the key center, per axis:
	# dx as % of half the key WIDTH, dy as % of half the key HEIGHT (100% = at the edge).
	var hw: float = kw * 0.5
	var hh: float = kh * 0.5
	var dx_pct: float = ks.mean_ax / hw * 100.0
	var dy_pct: float = ks.mean_ay / hh * 100.0
	var sdx_pct: float = ks.std_ax / hw * 100.0
	var sdy_pct: float = ks.std_ay / hh * 100.0

	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sty: StyleBoxFlat = StyleBoxFlat.new()
	sty.bg_color = Color(0.16, 0.18, 0.26, 0.85)
	sty.corner_radius_top_left = 4
	sty.corner_radius_top_right = 4
	sty.corner_radius_bottom_left = 4
	sty.corner_radius_bottom_right = 4
	# Zero horizontal content margins so card content aligns with the header row
	sty.content_margin_left = 0
	sty.content_margin_right = 0
	sty.content_margin_top = float(MainGlobals.ui_font_size(1))
	sty.content_margin_bottom = float(MainGlobals.ui_font_size(1))
	card.add_theme_stylebox_override("panel", sty)
	parent.add_child(card)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	card.add_child(row)

	_spacer(row, _row_pad_left)

	var key_txt: String = ch.to_upper() if ch != " " else "SPC"
	_cell(row, key_txt, _col_key, fs_name, Color(0.92, 0.95, 1.0, 1.0), HORIZONTAL_ALIGNMENT_CENTER)

	# Fixed cell size for ALL levels — only the key's aspect ratio (kw:kh) varies per key
	var gw: float = _col_gfx
	var gh: float = _gfx_h
	var graphic: Control = Control.new()
	graphic.custom_minimum_size = Vector2(gw, gh)
	graphic.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# Graphic: position/spread from ACTUAL tap offsets; color from spine error.
	graphic.draw.connect(_draw_key_graphic.bind(graphic,
		ks.mean_ax, ks.mean_ay, ks.std_ax, ks.std_ay, ks.mean_dx, ks.mean_dy, kw, kh))
	row.add_child(graphic)
	graphic.queue_redraw()

	_spacer(row, _col_npad)
	_cell(row, str(count), _col_n, fs_stats, Color(0.78, 0.85, 1.0, 0.90), HORIZONTAL_ALIGNMENT_CENTER)
	var sx: String = "+" if dx_pct >= 0.0 else ""
	_cell(row, "%s%.0f" % [sx, dx_pct], _col_val, fs_stats, Color(0.90, 0.95, 1.0, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_cell(row, "%.0f" % sdx_pct, _col_std, fs_stats, Color(0.70, 0.78, 0.95, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	var sy: String = "+" if dy_pct >= 0.0 else ""
	_cell(row, "%s%.0f" % [sy, dy_pct], _col_val, fs_stats, Color(0.90, 0.95, 1.0, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_cell(row, "%.0f" % sdy_pct, _col_std, fs_stats, Color(0.70, 0.78, 0.95, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	_ignore_pointer(card)

# Every control in a row ignores the pointer — which is what the standard score rows do too
# (`mouse_filter = 2` throughout scores_list_row.tscn and the grid label scenes).
#
# It is what makes the table SCROLLABLE on a phone. These rows are built in code, so they carried
# Control's default MOUSE_FILTER_STOP: each one swallowed the touch, and the ScrollContainer above
# them never saw a drag. The table had 1608 units of content in a 454-unit view and a live
# scrollbar, and still would not move under a finger.
func _ignore_pointer(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_pointer(c)

func _spacer(parent: Node, w: float) -> void:
	var sp: Control = Control.new()
	sp.custom_minimum_size = Vector2(w, 0.0)
	parent.add_child(sp)

func _cell(parent: Node, text: String, width: float, fs: int, color: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	if _typit_font:
		lbl.add_theme_font_override("font", _typit_font)
	lbl.add_theme_font_size_override("font_size", fs)
	lbl.add_theme_color_override("font_color", color)
	lbl.custom_minimum_size = Vector2(width, 0.0)
	lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lbl.clip_text = true
	lbl.horizontal_alignment = align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(lbl)

func _info_label(parent: Node, text: String, fs: int) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	if _typit_font:
		lbl.add_theme_font_override("font", _typit_font)
	lbl.add_theme_font_size_override("font_size", fs)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(lbl)

# ax,ay = mean ACTUAL offset from center (where you tap); sax,say = its std (spread).
# err_dx,err_dy = mean SPINE error (for color only).
func _draw_key_graphic(canvas: Control, ax: float, ay: float,
		sax: float, say: float, err_dx: float, err_dy: float, kw: float, kh: float) -> void:
	var inset: float = float(MainGlobals.ui_font_size(5))
	var cw: float = canvas.size.x - inset * 2.0
	var ch: float = canvas.size.y - inset * 2.0
	var key_scale: float = minf(cw / kw, ch / kh)
	var dw: float = kw * key_scale
	var dh: float = kh * key_scale
	var ox: float = inset + (cw - dw) * 0.5
	var oy: float = inset + (ch - dh) * 0.5
	canvas.draw_rect(Rect2(ox, oy, dw, dh), Color(0.12, 0.14, 0.22, 1.0))
	canvas.draw_rect(Rect2(ox, oy, dw, dh), Color(0.32, 0.40, 0.58, 0.65), false, 1.5)
	# Blob centered at the actual mean tap position, clamped to the key bounds.
	var lim_x: float = dw * 0.5
	var lim_y: float = dh * 0.5
	var cx: float = ox + dw * 0.5 + clampf(ax * key_scale, -lim_x, lim_x)
	var cy: float = oy + dh * 0.5 + clampf(ay * key_scale, -lim_y, lim_y)
	var std_mag: float = sqrt(sax * sax + say * say) * key_scale
	std_mag = clampf(std_mag, 2.0, maxf(dw, dh) * 0.42)
	# Color by the spine error magnitude (1.0 = at the key edge = radius r)
	var r_px: float = kh * 0.5
	var t: float = clampf(sqrt(err_dx * err_dx + err_dy * err_dy) / r_px, 0.0, 1.0)
	var blob_col: Color = Color.from_hsv(0.33 * (1.0 - t), 0.85, 0.90, 1.0)
	for ri in range(6, 0, -1):
		var r: float = std_mag * float(ri) / 6.0 * 2.0
		var frac: float = float(ri) / 6.0
		canvas.draw_circle(Vector2(cx, cy), r,
			Color(blob_col.r, blob_col.g, blob_col.b, exp(-2.0 * frac * frac) * 0.75),
			true, -1.0, true)
	canvas.draw_circle(Vector2(cx, cy), float(MainGlobals.ui_font_size(2)),
		Color(1.0, 1.0, 1.0, 0.95), true, -1.0, true)

# ---- Aggregate key stats ----

func _aggregate_key_stats() -> Dictionary:
	var cur_level: int = _view_level
	var max_n: int = TypitG.KEY_STATS_SESSIONS
	var filtered: Array = []
	for s in _key_sessions:
		if s is Dictionary and int(s.get("level", 0)) == cur_level:
			filtered.append(s)
	if max_n > 0 and filtered.size() > max_n:
		filtered = filtered.slice(filtered.size() - max_n)
	var lvl_idx: int = TypitG.level_index(cur_level)
	var fallback_w: float = TypitG.LEVEL_KEY_W[lvl_idx]
	var fallback_h: float = TypitG.LEVEL_KEY_H[lvl_idx]

	# acc[ch] = [n, sum_dx, sum_dy, sum_dx2, sum_dy2, w, h, sum_ax, sum_ay, sum_ax2, sum_ay2]
	var acc: Dictionary = {}
	for s in filtered:
		var kd_var: Variant = s.get("keys", {})
		if not (kd_var is Dictionary):
			continue
		for ch in (kd_var as Dictionary).keys():
			var kd: Variant = (kd_var as Dictionary)[ch]
			if not (kd is Array) or (kd as Array).size() < 5:
				continue
			var arr: Array = kd as Array
			if not acc.has(ch):
				acc[ch] = [0, 0.0, 0.0, 0.0, 0.0, fallback_w, fallback_h, 0.0, 0.0, 0.0, 0.0]
			acc[ch][0] += int(arr[0])
			acc[ch][1] += float(arr[1])
			acc[ch][2] += float(arr[2])
			acc[ch][3] += float(arr[3])
			acc[ch][4] += float(arr[4])
			if arr.size() >= 7:
				acc[ch][5] = float(arr[5])
				acc[ch][6] = float(arr[6])
			if arr.size() >= 11:
				acc[ch][7] += float(arr[7])
				acc[ch][8] += float(arr[8])
				acc[ch][9] += float(arr[9])
				acc[ch][10] += float(arr[10])
	var result: Dictionary = {}
	for ch in acc.keys():
		var a: Array = acc[ch]
		var n: int = a[0]
		if n < 1:
			continue
		var mdx: float = a[1] / float(n)   # spine-error means (for the numbers)
		var mdy: float = a[2] / float(n)
		var max_off: float = a[7] / float(n)   # actual offset means (for the graphic)
		var may_off: float = a[8] / float(n)
		result[ch] = {
			"count": n, "mean_dx": mdx, "mean_dy": mdy,
			"std_dx": sqrt(maxf(0.0, a[3] / float(n) - mdx * mdx)),
			"std_dy": sqrt(maxf(0.0, a[4] / float(n) - mdy * mdy)),
			"key_w": a[5], "key_h": a[6],
			"mean_ax": max_off, "mean_ay": may_off,
			"std_ax": sqrt(maxf(0.0, a[9] / float(n) - max_off * max_off)),
			"std_ay": sqrt(maxf(0.0, a[10] / float(n) - may_off * may_off)),
		}
	return result

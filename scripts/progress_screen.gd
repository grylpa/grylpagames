extends CanvasLayer

# The across-games progress overlay — the one screen in the app that is not about a single game.
#
# It answers "how am I doing overall?" and, for most visits, should be the only screen needed. Built
# in code and mounted by the game chooser, following about_screen.gd, because it belongs to the app
# rather than to any game.
#
# Two things about its manner are deliberate, and both come straight from the plan:
#
#   - IT LEADS WITH CATEGORIES, not games. A single game's numbers are too noisy to read month to
#     month; nobody should be scanning 34 sparklines.
#   - IT IS QUIET BY DEFAULT. The "worth a look" block appears only when several recent sessions
#     agree, and is empty the rest of the time. An empty state here is a success and reads like one.

# The app's warm accent, shared with result_card and main_menu. The About panel's brighter
# yellow was borrowed here at first and read as too loud for a screen full of small marks.
const _ACCENT: Color = ScreenBackdrop.ACCENT
const _DIM: Color = Color(0.72, 0.74, 0.78, 1.0)
const _STEADY: Color = ScreenBackdrop.STATS_STEADY
const _WATCH: Color = ScreenBackdrop.STATS_MARK
const _UNKNOWN: Color = ScreenBackdrop.STATS_QUIET

var _panel: PanelContainer = null
var _rows_area: Control = null
var _rows_box: GridContainer = null
var _summary_lbl: Label = null
var _notice_box: VBoxContainer = null

func _ready() -> void:
	layer = 128
	_build()
	hide()

func open() -> void:
	_refresh()
	show()
	# After the layout settles: the rows need the panel's real height, which is not known until the
	# containers have run at least once.
	call_deferred("_even_row_heights")

func close() -> void:
	hide()

func _build() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	root.add_child(backdrop)

	# FILLS the screen rather than shrinking to its contents. Sized to fit, the eight category rows
	# left their sparklines at the minimum height a row needs — which is far too short to read a
	# shape from, while most of the screen sat empty behind the panel.
	var center: MarginContainer = MarginContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_theme_constant_override("margin_left", 16)
	center.add_theme_constant_override("margin_right", 16)
	center.add_theme_constant_override("margin_top", 12)
	center.add_theme_constant_override("margin_bottom", 12)
	root.add_child(center)

	_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1019608, 0.1019608, 0.1215686, 1.0)
	style.set_corner_radius_all(16)
	style.set_border_width_all(2)
	style.border_color = _ACCENT
	_panel.add_theme_stylebox_override("panel", style)
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# No row is interactive, so any tap dismisses -- on the panel as well as the backdrop. Making
	# the player find the Close button to leave a screen they cannot otherwise touch is friction
	# with nothing behind it. The button stays, because it says the way out exists.
	_panel.gui_input.connect(_on_backdrop_input)
	center.add_child(_panel)

	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	_panel.add_child(margin)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(col)

	var title: Label = Label.new()
	title.text = "Your progress"
	title.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(title, 26)
	title.add_theme_color_override("font_color", _ACCENT)
	col.add_child(title)

	# Adherence first: it is the Goal 1 number, and the only line here the player can act on today.
	_summary_lbl = Label.new()
	_summary_lbl.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(_summary_lbl, 15)
	_summary_lbl.add_theme_color_override("font_color", _DIM)
	col.add_child(_summary_lbl)

	# WHAT THE ROWS MEAN. Without this the reader is looking at eight lines on eight grey bands with
	# nothing saying what either is — and the obvious guess ("a 67% band"?) is wrong.
	var key: Label = Label.new()
	# SAYS HOW WIDE THE BAND IS, in sessions rather than in sigmas. "Your usual range" alone left
	# the obvious question — how usual? — unanswered, and the obvious guess is wrong.
	key.text = "Each line is how you have been doing lately against your own usual. The band is "
	key.text += "your usual range: about 19 sessions in 20 land inside it, so a point outside is "
	key.text += "ordinary on its own. Only a run of them is worth a look."
	key.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	key.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(key, 12)
	key.add_theme_color_override("font_color", _UNKNOWN)
	col.add_child(key)

	col.add_child(_rule())

	# A GRID, not a stack of rows. Each row used to be its own HBox with a guessed minimum width on
	# the name, so a long category ("Memory & Navigation") simply overran it and shoved that row's
	# sparkline and state to the right while every other row stayed put. A grid measures each
	# column across ALL rows, which is what makes the columns actually align.
	# The grid sits inside a plain Control that takes the leftover space, rather than in the column
	# directly. _even_row_heights() writes a minimum height onto every sparkline, and from inside the
	# column that minimum travelled back up -- grid minimum, panel minimum, panel taller than the
	# screen -- and the next pass then measured the rows against the grid this pass had just grown.
	# That runaway is what made the dialog overflow on first open and settle only on the second. A
	# plain Control does not adopt its child's minimum, so the area's height is pure leftover: the
	# number the row sizing reads is now one it cannot itself change.
	_rows_area = Control.new()
	_rows_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows_area.custom_minimum_size = Vector2(0, MainGlobals.ui_font_size(40))
	_rows_area.resized.connect(_even_row_heights)
	col.add_child(_rows_area)

	_rows_box = GridContainer.new()
	_rows_box.columns = 3
	_rows_box.add_theme_constant_override("h_separation", 12)
	_rows_box.add_theme_constant_override("v_separation", 6)
	_rows_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rows_area.add_child(_rows_box)

	_notice_box = VBoxContainer.new()
	_notice_box.add_theme_constant_override("separation", 4)
	col.add_child(_notice_box)

	var close_btn: Button = Button.new()
	close_btn.text = "Close"
	MainGlobals.set_font_size(close_btn, 18)
	close_btn.pressed.connect(close)
	col.add_child(close_btn)

# The divider between sections of this panel. The FRAME's colour, like the Summary tab's -- these
# lines sit inside a panel bordered in the accent, and a grey hairline across it reads as a seam
# rather than as a division the panel is making.
#
# PANEL_FRAME rather than the border's own full-strength _ACCENT: same hue, at the weight a divider
# wants. A hairline at full strength competes with the border it is sitting inside, and it would
# also make this screen's dividers heavier than the identical ones in each game's Summary tab.
func _rule() -> Control:
	var line: ColorRect = ColorRect.new()
	line.color = ScreenBackdrop.PANEL_FRAME
	line.custom_minimum_size = Vector2(0, 1)
	return line

func _refresh() -> void:
	# REMOVED before freeing. queue_free() is deferred, so the old rows were still in the grid when
	# the new ones were added — the row count briefly doubled, the per-row height was computed
	# against the wrong denominator, and the minimum it wrote grew the panel. Every reopen added
	# another ~450px until the dialog was taller than the screen.
	_clear(_rows_box)
	_clear(_notice_box)

	var wk: Dictionary = StatsOverview.week_summary()
	if int(wk["sessions"]) == 0:
		_summary_lbl.text = "No sessions yet this week."
	else:
		_summary_lbl.text = "This week: %d sessions · %d min · %d games" % [
			int(wk["sessions"]), int(wk["minutes"]), int(wk["games"])]

	# The grid keeps its size whatever its contents (it expands to fill), so `resized` does NOT fire
	# after the rows are rebuilt — the sizing pass has to be asked for explicitly.
	var watched: Array = []
	for row: Dictionary in StatsOverview.all_rows():
		_add_row(row)
		if int(row["state"]) == StatsBaseline.State.WATCH:
			watched.append(row)

	# Empty most of the time, and that is the point — see the note at the top of this file.
	if watched.is_empty():
		return
	_notice_box.add_child(_rule())
	var head: Label = Label.new()
	head.text = "Worth a look"
	head.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(head, 16)
	head.add_theme_color_override("font_color", _WATCH)
	_notice_box.add_child(head)
	for row2: Dictionary in watched:
		var body: Label = Label.new()
		var game_title: String = _title_of(str(row2.get("worst_game", "")))
		# Describes the player's own scores and stops there. Never what it might mean about them.
		body.text = "%s has been outside your usual range recently." % (
			game_title if game_title != "" else str(row2["category"]))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(360, 0)
		body.add_theme_font_override("font", MainGlobals.get_text_font())
		MainGlobals.set_font_size(body, 14)
		body.add_theme_color_override("font_color", _DIM)
		_notice_box.add_child(body)

func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

func _title_of(folder: String) -> String:
	for entry in MainCfg.games:
		if entry.size() > 1 and entry[0] == folder:
			return str(entry[1])
	return ""

# Adds this row's three cells to the grid. Returns nothing: the grid owns the layout, and a row
# that packed itself into its own container is exactly what broke the alignment before.
func _add_row(row: Dictionary) -> void:
	# The cells come from ScreenBackdrop so that this overlay and each game's Summary tab are
	# literally the same row, built once. See ScreenBackdrop.stats_row_cells.
	for cell: Control in ScreenBackdrop.stats_row_cells(
			str(row["category"]), row.get("values", []), int(row["state"])):
		_rows_box.add_child(cell)


func _on_backdrop_input(event: InputEvent) -> void:
	# A CLICK, not any mouse button event. The wheel arrives as an InputEventMouseButton with
	# pressed = true, so scrolling was closing the window.
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		close()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# Give every row the SAME height, to the pixel.
#
# The grid distributes leftover space a pixel at a time from the top, so eight expanding rows come
# out 85, 84, 84... — barely anything on its own, and plainly uneven in a stack of eight.
func _even_row_heights() -> void:
	if _rows_box == null or not is_instance_valid(_rows_box):
		return
	var live: int = 0
	for c in _rows_box.get_children():
		if not c.is_queued_for_deletion():
			live += 1
	var count: int = live / 3
	if count <= 0:
		return
	# Measured on the AREA, not on the grid -- see the note where the area is built.
	var gap: int = _rows_box.get_theme_constant("v_separation")
	var avail: float = _rows_area.size.y - float(gap * (count - 1))
	var each: float = floorf(avail / float(count))
	if each < MainGlobals.ui_font_size(40):
		return          # not enough room to grow; the minimum already applies to every row equally
	# Width is handed back up deliberately: only the HEIGHT was looping, and without this a long
	# category name would be cut off instead of widening the panel.
	_rows_area.custom_minimum_size.x = _rows_box.get_combined_minimum_size().x
	var i: int = 1
	while i < _rows_box.get_child_count():
		var spark: Control = _rows_box.get_child(i) as Control
		if spark != null and absf(spark.custom_minimum_size.y - each) > 0.5:
			spark.custom_minimum_size.y = each
		i += 3

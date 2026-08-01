extends CanvasLayer

# App-level "Settings" overlay. Built entirely in code and added as a child of the GameChooser,
# so it needs no dedicated .tscn — same pattern as about_screen.gd.
#
# Currently holds one setting: the GAME FONT, i.e. the theme's default font. That is the font used
# by menus, buttons and titles; in-game text mostly overrides it with MainGlobals
# get_system_sans_font(), so changing this does not affect gameplay text.
#
# Unlike the About overlay this does NOT close on a tap anywhere — it has controls in it, and a
# tap-to-dismiss would fire while the player is choosing. Only the X button and the dimmed
# backdrop close it.

const _ACCENT: Color = Color(0.9843137, 0.85490197, 0.1882353, 1.0)
const _DIM: Color = Color(0.72, 0.72, 0.72, 1.0)
# Deliberately exercises the look-alikes a display font tends to blur. ASCII only: the preview is
# drawn in the face itself, which has no fallbacks, so anything exotic would render as tofu.
const _SAMPLE: String = "0O 1lI 5S 8B 2Z - Level 3 - 25 s"
const _MIN_SCROLL_H: float = 160.0

var _panel: PanelContainer = null
var _scroll: ScrollContainer = null
var _title: Label = null
var _close_btn: Button = null
var _header_nodes: Array = []
var _body_nodes: Array = []
var _font_buttons: Array = []      # one Button per choice, each drawn in its own face
var _sample_labels: Array = []
var _mark_labels: Array = []       # fixed-width selection-marker column, one per row
var _sample_indents: Array = []    # MarginContainer indenting each sample to match its name
var _scroll_room: float = 0.0     # tallest the scroll viewport may be on this screen

func _ready() -> void:
	layer = 129     # one above About, which is 128
	_build()
	hide()

func open() -> void:
	_refresh_selection()
	_apply_layout()
	show()
	await get_tree().process_frame
	await _fit_scroll()

func close() -> void:
	hide()

func _build() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# Dimmed backdrop; tapping it closes the overlay (the panel above blocks its own taps).
	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	root.add_child(backdrop)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP   # taps inside must not reach the backdrop
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1019608, 0.1019608, 0.1215686, 1.0)
	style.set_corner_radius_all(16)
	style.set_border_width_all(2)
	style.border_color = _ACCENT
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title_row: HBoxContainer = HBoxContainer.new()
	vbox.add_child(title_row)

	_title = Label.new()
	_title.text = "Settings"
	_title.add_theme_color_override("font_color", _ACCENT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(_title)

	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.flat = true
	_close_btn.add_theme_color_override("font_color", _ACCENT)
	_close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_btn.pressed.connect(close)
	title_row.add_child(_close_btn)

	# Everything below the title row scrolls, so the panel always fits the screen no matter how many
	# fonts the list grows to or how short the device is.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	var body: VBoxContainer = VBoxContainer.new()
	# tight: each font's name and its sample belong together, and the whole list should fit
	# without scrolling at the shipped count (the indent on the sample carries the grouping)
	body.add_theme_constant_override("separation", 4)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)

	var head: Label = Label.new()
	head.text = "Game font"
	head.add_theme_color_override("font_color", _ACCENT)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(head)
	_header_nodes.append(head)

	var note: Label = Label.new()
	note.text = "Used by menus, buttons and titles. Takes effect immediately."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", _DIM)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(note)
	_body_nodes.append(note)

	# One row per font. Each row is drawn IN THAT FONT, with a sample of the characters a display
	# face most often blurs — so the choice can be judged without applying it first.
	#
	# The name and its sample must share one left edge, which rules out prefixing either with
	# spaces: the name is a Button (whose stylebox adds its own left padding) while the sample is a
	# Label (which has none), and both are set in a PROPORTIONAL face, so a space prefix lands in a
	# different place on every row. Instead the marker gets its own fixed-width column and the two
	# text nodes are stripped of horizontal padding, so their left edges are equal by construction.
	for i in MainGlobals.GAME_FONTS.size():
		var preview: Font = MainGlobals.build_game_font(i)

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		body.add_child(row)

		var mark: Label = Label.new()
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(mark)
		_mark_labels.append(mark)

		var btn: Button = Button.new()
		btn.text = str(MainGlobals.GAME_FONTS[i]["name"])
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = true
		# zero the button's own padding, or its text starts further right than the sample below it
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(_on_font_chosen.bind(i))
		if preview != null:
			btn.add_theme_font_override("font", preview)
		row.add_child(btn)
		_font_buttons.append(btn)

		# the sample is indented by exactly the marker column, so it aligns with the name above it
		var indent: MarginContainer = MarginContainer.new()
		indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(indent)
		_sample_indents.append(indent)

		var sample: Label = Label.new()
		sample.text = _SAMPLE
		sample.add_theme_color_override("font_color", _DIM)
		sample.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if preview != null:
			sample.add_theme_font_override("font", preview)
		indent.add_child(sample)
		_sample_labels.append(sample)

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()

func _on_font_chosen(idx: int) -> void:
	MainGlobals.set_game_font(idx)
	_refresh_selection()
	# the title/header overrides pin a specific face, so they have to be rebuilt on a change;
	# that and the note also change the content's height, hence the refit
	_apply_layout()
	call_deferred("_fit_scroll")

# The chosen row gets the accent color and a marker; the rest stay plain.
func _refresh_selection() -> void:
	for i in _font_buttons.size():
		var chosen: bool = i == MainGlobals.game_font_idx
		var btn: Button = _font_buttons[i]
		var col: Color = _ACCENT if chosen else Color(0.88, 0.88, 0.88, 1.0)
		# ASCII marker: the rows are drawn in the candidate face, which has no fallbacks, and every
		# one of them is missing the round bullet glyphs. It sits in its own fixed-width column, so
		# selecting a row never shifts its name sideways.
		var mark: Label = _mark_labels[i]
		mark.text = ">" if chosen else ""
		mark.add_theme_color_override("font_color", _ACCENT)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			btn.add_theme_color_override(state, col)

func _apply_layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var is_mob: bool = MainGlobals.is_mobile()
	var pad: float = 24.0

	var title_size: int = 52 if is_mob else 34
	var header_size: int = 34 if is_mob else 20
	var body_size: int = 30 if is_mob else 18
	var close_size: int = 44 if is_mob else 26

	_title.add_theme_font_size_override("font_size", title_size)
	_close_btn.add_theme_font_size_override("font_size", close_size)
	_close_btn.custom_minimum_size = Vector2(close_size + 14, close_size + 14)
	for n in _header_nodes:
		n.add_theme_font_size_override("font_size", header_size)
	for n in _body_nodes:
		n.add_theme_font_size_override("font_size", body_size)
	for b in _font_buttons:
		b.add_theme_font_size_override("font_size", header_size)
	# one marker column width, shared by the markers and the sample indent, so a name and its
	# sample always start at the same x
	var mark_w: float = roundf(float(header_size) * 0.75)
	for m in _mark_labels:
		m.add_theme_font_size_override("font_size", header_size)
		m.custom_minimum_size = Vector2(mark_w, 0)
	for mi in _sample_indents:
		mi.add_theme_constant_override("margin_left", int(mark_w))
	# the sample is the readability test, so keep it at the size real UI text uses
	for sl in _sample_labels:
		sl.add_theme_font_size_override("font_size", body_size)

	var panel_w: float = vp.x - 2.0 * pad
	if not is_mob:
		panel_w = min(panel_w, 620.0)
	_panel.custom_minimum_size = Vector2(panel_w, 0)

	# Start from an estimate of the chrome (title row + panel margins); _fit_scroll replaces it with
	# a measurement once there has been a layout pass.
	_scroll_room = maxf(_MIN_SCROLL_H, vp.y - 2.0 * pad - (title_size + 86.0))
	_scroll.custom_minimum_size = Vector2(0, _scroll_room)

# Size the scroll viewport to whatever is actually left on screen: the panel must never be taller
# than the screen (the list scrolls instead), and must not leave dead space when the list fits.
# Both the chrome and the content are MEASURED here rather than predicted, which is why this runs
# after a layout pass — an estimate that is wrong in either direction shows up as a clipped panel
# or a gap, and the numbers depend on the chosen font.
func _fit_scroll() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var pad: float = 24.0
	for _pass in 2:
		var chrome: float = maxf(0.0, _panel.size.y - _scroll.size.y)
		_scroll_room = maxf(_MIN_SCROLL_H, vp.y - 2.0 * pad - chrome)
		var content_h: float = (_scroll.get_child(0) as Control).get_combined_minimum_size().y
		_scroll.custom_minimum_size = Vector2(0, minf(_scroll_room, content_h))
		await get_tree().process_frame

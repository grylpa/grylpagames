extends CanvasLayer

# App-level "About" overlay. Built entirely in code and added as a child of the
# GameChooser, so it needs no dedicated .tscn. Shows the app name/version, the
# grylpa developer identity + clickable contact links, a privacy note, and
# third-party asset credits. Dismissed by the X button or by tapping the dimmed
# backdrop. Sizing/fonts adapt to mobile so the text stays readable and the body
# scrolls by touch.

const _ACCENT: Color = Color(0.9843137, 0.85490197, 0.1882353, 1.0)
const _LINK: Color = Color(0.4, 0.788, 1.0, 1.0)

var _panel: PanelContainer = null
var _scroll: ScrollContainer = null
var _title: Label = null
var _close_btn: Button = null
var _version_lbl: Label = null
var _body_nodes: Array = []
var _link_nodes: Array = []
var _header_nodes: Array = []
var _spacer_nodes: Array = []

# Tap-to-dismiss: a press+release that barely moved is a tap (close); a press
# that travels is a scroll/drag (ignore, so the body still scrolls).
const _TAP_MAX_MOVE: float = 12.0
var _pressing: bool = false
var _press_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	layer = 128
	_build()
	hide()

func open() -> void:
	if _version_lbl != null:
		_version_lbl.text = "Version " + MainGlobals.version
	_apply_layout()
	show()

func close() -> void:
	hide()

func _build() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# Dimmed backdrop; tapping it closes the overlay.
	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(backdrop)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	_panel = PanelContainer.new()
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
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title row with a close button.
	var title_row: HBoxContainer = HBoxContainer.new()
	vbox.add_child(title_row)

	_title = Label.new()
	_title.text = "Nomizo"
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

	# Scrollable body so long credits never push the panel off-screen. Every
	# non-interactive line ignores the mouse so a touch drag reaches the
	# ScrollContainer (otherwise the labels swallow the drag and it can't scroll).
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)

	_version_lbl = _add_text(body, "Version " + MainGlobals.version, Color(0.72, 0.72, 0.72, 1.0))
	_body_nodes.append(_version_lbl)
	_body_nodes.append(_add_text(body, "A collection of small challenging and relaxing games.", Color(0.9, 0.9, 0.9, 1.0)))

	_header_nodes.append(_add_header(body, "Developer"))
	_link_nodes.append(_add_link(body, "grylpa.com", "https://grylpa.com"))
	_link_nodes.append(_add_link(body, "info@grylpa.com", "mailto:info@grylpa.com"))

	_header_nodes.append(_add_header(body, "Privacy"))
	_body_nodes.append(_add_text(body, "No account is required to play. Nomizo runs entirely on your device — it sends nothing over the internet, and your scores and settings stay on your device.", Color(0.9, 0.9, 0.9, 1.0)))

	_header_nodes.append(_add_header(body, "Credits"))
	_body_nodes.append(_add_text(body, "Sound effects — Kenney (kenney.nl), CC0", Color(0.85, 0.85, 0.85, 1.0)))
	_body_nodes.append(_add_text(body, "Fonts — Open Sans, Noto Sans Symbols, JetBrains Mono (SIL OFL 1.1); Stormfaze (CC0)", Color(0.85, 0.85, 0.85, 1.0)))
	_body_nodes.append(_add_text(body, "Made with the Godot Engine.", Color(0.85, 0.85, 0.85, 1.0)))

func _add_text(parent: VBoxContainer, txt: String, col: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = txt
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", col)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(lbl)
	return lbl

func _add_header(parent: VBoxContainer, txt: String) -> Label:
	# Extra breathing room *before* each header so a section reads as a group
	# (header tight to its own text, wider gap separating it from the previous
	# section). A single VBox separation can't vary per-gap, so use a spacer.
	if parent.get_child_count() > 0:
		var spacer: Control = Control.new()
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spacer.custom_minimum_size = Vector2(0, 12)
		parent.add_child(spacer)
		_spacer_nodes.append(spacer)
	var lbl: Label = Label.new()
	lbl.text = txt
	lbl.add_theme_color_override("font_color", _ACCENT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	return lbl

func _add_link(parent: VBoxContainer, txt: String, target: String) -> LinkButton:
	var lb: LinkButton = LinkButton.new()
	lb.text = txt
	lb.underline = LinkButton.UNDERLINE_MODE_ALWAYS
	lb.add_theme_color_override("font_color", _LINK)
	lb.add_theme_color_override("font_hover_color", Color(0.6, 0.86, 1.0, 1.0))
	lb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	lb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lb.pressed.connect(func() -> void: OS.shell_open(target))
	parent.add_child(lb)
	return lb

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
	for n in _link_nodes:
		n.add_theme_font_size_override("font_size", body_size)

	var spacer_h: float = 22.0 if is_mob else 12.0
	for s in _spacer_nodes:
		s.custom_minimum_size = Vector2(0, spacer_h)

	var panel_w: float = vp.x - 2.0 * pad
	if not is_mob:
		panel_w = min(panel_w, 620.0)
	_panel.custom_minimum_size = Vector2(panel_w, 0)

	# Bound the scroll viewport so the whole panel fits the screen and the body
	# scrolls inside it. Leave room for the title row + panel margins.
	var chrome_h: float = (title_size + 46.0) + 40.0
	var scroll_h: float = vp.y - 2.0 * pad - chrome_h
	scroll_h = clamp(scroll_h, 200.0, 1400.0)
	_scroll.custom_minimum_size = Vector2(0, scroll_h)

func _input(event: InputEvent) -> void:
	# A tap anywhere dismisses the overlay. We track press/release ourselves (via
	# _input, which runs before the GUI pass) so a scroll drag on the body is not
	# mistaken for a tap. The close is deferred so this same event still reaches
	# any control under the finger first — e.g. a link tap opens the link, then
	# the overlay closes.
	if not visible:
		return
	var is_press: bool = false
	var is_release: bool = false
	var pos: Vector2 = _press_pos
	if event is InputEventScreenTouch:
		is_press = event.pressed
		is_release = not event.pressed
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_press = event.pressed
		is_release = not event.pressed
		pos = event.position
	else:
		return
	if is_press:
		_pressing = true
		_press_pos = pos
	elif is_release and _pressing:
		_pressing = false
		if pos.distance_to(_press_pos) <= _TAP_MAX_MOVE:
			call_deferred("close")

extends CanvasLayer

# The "How to play" overlay on the game chooser: pick a game and be taught it by playing it.
#
# It lists ONLY the games that have an authored tutorial (MainCfg.tutorials). That is the point of
# putting it here rather than inside each game — from the chooser a player can see at a glance
# which games will teach them, instead of entering each one to find out.
#
# Built in code and added as a child of the GameChooser, following scripts/about_screen.gd.

signal sig_start_tutorial(folder: String)

const _ACCENT: Color = Color(0.9843137, 0.85490197, 0.1882353, 1.0)
const _TAP_MAX_MOVE: float = 12.0

var _panel: PanelContainer = null
var _list: VBoxContainer = null
var _pressing: bool = false
var _press_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	layer = 128
	_build()
	hide()

func open() -> void:
	_populate()
	_apply_layout()
	show()

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
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var is_mob: bool = MainGlobals.is_mobile()

	var title: Label = Label.new()
	title.text = "How to play"
	title.add_theme_font_size_override("font_size", 36 if is_mob else 26)
	title.add_theme_color_override("font_color", _ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var blurb: Label = Label.new()
	blurb.text = "Pick a game and it will teach you by playing it.\nNothing you do in a tutorial is scored."
	blurb.add_theme_font_size_override("font_size", 22 if is_mob else 16)
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(blurb)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var close_btn: Button = Button.new()
	close_btn.text = "Close"
	close_btn.add_theme_font_size_override("font_size", 24 if is_mob else 18)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.custom_minimum_size = Vector2(160, 0)
	close_btn.pressed.connect(close)
	vbox.add_child(close_btn)

func _populate() -> void:
	for c in _list.get_children():
		c.queue_free()
	var is_mob: bool = MainGlobals.is_mobile()
	var row_h: float = 84.0 if is_mob else 62.0

	for entry in _ordered_entries():
		var folder: String = String(entry[0])
		var display_name: String = String(entry[1])
		var desc: String = String(entry[2])
		var category: String = String(entry[3]) if entry.size() > 3 else ""

		var row: Button = Button.new()
		row.custom_minimum_size = Vector2(0, row_h)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.pressed.connect(_on_row_pressed.bind(folder))
		_list.add_child(row)

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(hbox)

		# The game's own chooser thumbnail, so the row is recognizable at a glance.
		var thumb_path: String = "res://%s/art/game_screen_200.png" % folder
		if ResourceLoader.exists(thumb_path):
			var tex: TextureRect = TextureRect.new()
			tex.texture = load(thumb_path)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.custom_minimum_size = Vector2(row_h - 12.0, row_h - 12.0)
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(tex)

		var texts: VBoxContainer = VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(texts)

		# Title row: the game name in yellow, with its category in white beside it, so the list
		# reads as "what kind of thing is this" and not just a list of names.
		var title_row: HBoxContainer = HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 10)
		title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_child(title_row)

		var nm: Label = Label.new()
		nm.text = display_name
		nm.add_theme_font_size_override("font_size", 26 if is_mob else 19)
		nm.add_theme_color_override("font_color", _ACCENT)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_row.add_child(nm)

		if not category.is_empty():
			var cat: Label = Label.new()
			cat.text = category
			cat.add_theme_font_size_override("font_size", 18 if is_mob else 14)
			cat.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
			cat.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			cat.mouse_filter = Control.MOUSE_FILTER_IGNORE
			title_row.add_child(cat)

		var ds: Label = Label.new()
		ds.text = desc
		ds.add_theme_font_size_override("font_size", 19 if is_mob else 14)
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ds.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_child(ds)

	if _list.get_child_count() == 0:
		var none: Label = Label.new()
		none.text = "No tutorials are available yet."
		none.add_theme_font_size_override("font_size", 22 if is_mob else 16)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(none)

# Deliberately the REVERSE of the game chooser, which floats what you played last to the top.
# This list is about what you have yet to learn, so a tutorial you have already finished sinks to
# the bottom — and among those, the one you finished most recently sinks furthest.
func _ordered_entries() -> Array:
	var todo: Array = []
	var done: Array = []
	for entry in MainCfg.games:
		var folder: String = String(entry[0])
		if not MainCfg.has_tutorial(folder):
			continue
		if MainGlobals.tutorials_done.has(folder):
			done.append(entry)
		else:
			todo.append(entry)
	done.sort_custom(func(a, b):
		return MainGlobals.tutorials_done.find(String(a[0])) \
			< MainGlobals.tutorials_done.find(String(b[0])))
	return todo + done

func _apply_layout() -> void:
	var screen: Vector2 = Vector2(MainGlobals.screen_size)
	_panel.custom_minimum_size = Vector2(minf(screen.x - 40.0, 620.0), 0)
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Leave room top and bottom so the panel never runs off a short screen; the list scrolls.
	_panel.custom_minimum_size.y = minf(screen.y - 120.0, 640.0)

func _on_row_pressed(folder: String) -> void:
	close()
	sig_start_tutorial.emit(folder)

# Tap the backdrop to dismiss; a press that travels is a scroll, so ignore it.
func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			_pressing = true
			_press_pos = event.position
		elif _pressing:
			_pressing = false
			if event.position.distance_to(_press_pos) <= _TAP_MAX_MOVE:
				close()

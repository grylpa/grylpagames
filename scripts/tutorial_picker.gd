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
# Thumbnail framing, matching what the chooser renders in LIST mode: the rounded structure of
# scenes/game_select_button.tscn (PanelClipper + PanelFrame, radius 8) with the border color and
# width game_chooser.gd:447 overrides onto %PanelFrame there.
#
# The stylebox around it matters as much as the color value: the chooser's frame keeps
# `border_blend = true` over a transparent grey bg, so the same Color8(155,100,0) paints lighter
# than it does on a plain opaque border. An earlier attempt used this exact value without the blend
# and it looked wrong for that reason, not because the value was.
# DESKTOP IS UNCHANGED from the version that worked — these are its original numbers. Only the
# mobile figures were raised, to the chooser's list-mode sizes (game_chooser.gd:345-346), because
# the picker was unreadable on a phone.
static func _title_fs() -> int:
	return 38 if MainGlobals.is_mobile() else 19

static func _desc_fs() -> int:
	return 33 if MainGlobals.is_mobile() else 14

# The thumbnail is a fixed size, NOT derived from the row height — tying it to the row meant the
# bigger mobile fonts inflated the icon to 200px and left no room for the text beside it.
# The category sits beside the game name, so it wants to be quieter than the description that sits
# under it — on a phone, where the fonts are much larger, the two being equal made it shout.
static func _cat_fs() -> int:
	return 26 if MainGlobals.is_mobile() else 14

static func _icon_px() -> float:
	return 110.0 if MainGlobals.is_mobile() else 46.0

static func _row_h() -> float:
	if not MainGlobals.is_mobile():
		return 58.0
	# Mobile only: tall enough for one title line and two description lines at the larger fonts,
	# measured from the font rather than from its point size.
	var f: Font = ThemeDB.fallback_font
	if f == null:
		return float(_title_fs() + 2 * _desc_fs() + 20)
	# The padding is generous because the worst case — a name line plus a two-line description —
	# fills the card, and at these font sizes a tight fit reads as cramped.
	return f.get_height(_title_fs()) + 2.0 * f.get_height(_desc_fs()) + 32.0

const ICON_RADIUS: int = 8
# 3 on a phone, matching scenes/game_select_button.tscn's own width. The color is the dark amber
# the chooser uses in list mode, which at 2px on a small icon is very easy to miss.
static func _icon_border() -> int:
	return 5 if MainGlobals.is_mobile() else 2
const ICON_BORDER_COLOR: Color = Color8(155, 100, 0, 255)

var _panel: PanelContainer = null
var _list: VBoxContainer = null
var _scroll: ScrollContainer = null
# Drag-to-scroll state. The rows are Buttons with MOUSE_FILTER_STOP, so they consume the drag
# before the ScrollContainer ever sees it — which is why swiping the list did nothing. Each row
# forwards its drags here instead, and a drag suppresses the tap that would otherwise follow.
var _drag_active: bool = false
var _drag_from_y: float = 0.0
var _drag_scroll0: float = 0.0
var _drag_moved: bool = false
const _DRAG_SLOP: float = 8.0
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
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var is_mob: bool = MainGlobals.is_mobile()

	var title: Label = Label.new()
	title.text = "How to play"
	title.add_theme_font_size_override("font_size", _title_fs())
	title.add_theme_color_override("font_color", _ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var blurb: Label = Label.new()
	blurb.text = "Pick a game and it will teach you by playing it"
	blurb.add_theme_font_size_override("font_size", _desc_fs())
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(blurb)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_scroll = scroll

	_list = VBoxContainer.new()
	# Each row carries its own background, so the gap only has to separate two cards rather than
	# stand in for the boundary between them — tight on desktop, roomier on a phone where the
	# cards are much taller.
	_list.add_theme_constant_override("separation", 10 if MainGlobals.is_mobile() else 4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var close_btn: Button = Button.new()
	close_btn.text = "Close"
	close_btn.add_theme_font_size_override("font_size", _title_fs())
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.custom_minimum_size = Vector2(220 if is_mob else 160, 0)
	close_btn.pressed.connect(close)
	vbox.add_child(close_btn)

func _populate() -> void:
	for c in _list.get_children():
		c.queue_free()
	var row_h: float = _row_h()

	for entry in _ordered_entries():
		var folder: String = String(entry[0])
		var display_name: String = String(entry[1])
		var desc: String = String(entry[2])
		var category: String = String(entry[3]) if entry.size() > 3 else ""

		var row: Button = Button.new()
		row.custom_minimum_size = Vector2(0, row_h)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.pressed.connect(_on_row_pressed.bind(folder))
		row.gui_input.connect(_on_row_gui_input.bind(row))
		_style_row(row)
		_list.add_child(row)

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		# Inset from the card edges. Anchored full-rect, the row's contents start exactly on the
		# background's boundary, so the thumbnail sat hard against it and poked out past the
		# rounded corner. The stylebox's own content margins do not help here — anchors ignore them.
		hbox.offset_left = 10.0
		hbox.offset_right = -10.0
		hbox.offset_top = 4.0
		hbox.offset_bottom = -4.0
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(hbox)

		# The game's own chooser thumbnail, built the way the chooser builds its own
		# (scenes/game_select_button.tscn): a PanelContainer with clip_children and a rounded
		# stylebox rounds the IMAGE, and a second panel laid over it draws the rounded border.
		# A TextureRect cannot round its own corners, which is why an ordinary bordered panel left
		# the image's square corners sitting on top of the arcs.
		var thumb_path: String = "res://%s/art/game_screen_200.png" % folder
		if ResourceLoader.exists(thumb_path):
			var icon: float = _icon_px()
			var holder: Control = Control.new()
			holder.custom_minimum_size = Vector2(icon, icon)
			holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(holder)

			var clipper: PanelContainer = PanelContainer.new()
			clipper.set_anchors_preset(Control.PRESET_FULL_RECT)
			clipper.mouse_filter = Control.MOUSE_FILTER_IGNORE
			clipper.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
			var cs: StyleBoxFlat = StyleBoxFlat.new()
			# Opaque: with CLIP_CHILDREN_ONLY this shape is the MASK and is never itself drawn.
			cs.bg_color = Color(1, 1, 1, 1)
			cs.set_corner_radius_all(ICON_RADIUS)
			clipper.add_theme_stylebox_override("panel", cs)
			holder.add_child(clipper)

			var tex: TextureRect = TextureRect.new()
			tex.texture = load(thumb_path)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			clipper.add_child(tex)

			var frame: PanelContainer = PanelContainer.new()
			frame.set_anchors_preset(Control.PRESET_FULL_RECT)
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var fsb: StyleBoxFlat = StyleBoxFlat.new()
			fsb.bg_color = Color(0.6, 0.6, 0.6, 0)
			fsb.set_border_width_all(_icon_border())
			fsb.border_color = ICON_BORDER_COLOR
			fsb.border_blend = true
			fsb.set_corner_radius_all(ICON_RADIUS)
			frame.add_theme_stylebox_override("panel", fsb)
			holder.add_child(frame)

		var texts: VBoxContainer = VBoxContainer.new()
		# A little air between the name row and the description, on a phone only.
		if MainGlobals.is_mobile():
			texts.add_theme_constant_override("separation", 8)
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
		nm.add_theme_font_size_override("font_size", _title_fs())
		# TOP for both, with the category nudged down by the difference in ASCENT below. Centring
		# the two line boxes (which is what VERTICAL_ALIGNMENT_CENTER does) lines up their boxes,
		# not their text: a smaller font has a shorter ascent, so its baseline ends up higher and
		# it reads as sitting above the name. Matching baselines is what looks aligned.
		nm.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		nm.add_theme_color_override("font_color", _ACCENT)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_row.add_child(nm)

		if not category.is_empty():
			var cat: Label = Label.new()
			cat.text = category
			cat.add_theme_font_size_override("font_size", _cat_fs())
			cat.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
			cat.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			cat.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cat.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			# Drop the category by however much taller the name's ascent is, so both sit on one
			# baseline.
			var nf: Font = nm.get_theme_font("font")
			var drop: int = 0
			if nf != null:
				drop = maxi(0, int(round(nf.get_ascent(_title_fs()) - nf.get_ascent(_cat_fs()))))
			var cat_wrap: MarginContainer = MarginContainer.new()
			cat_wrap.add_theme_constant_override("margin_top", drop)
			cat_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cat_wrap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			title_row.add_child(cat_wrap)
			cat_wrap.add_child(cat)

		var ds: Label = Label.new()
		ds.text = desc
		ds.add_theme_font_size_override("font_size", _desc_fs())
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# The row height comes from the chooser's formula, which budgets 3 description lines on
		# mobile and 2 on desktop. Cap the label to that budget or a long description simply runs
		# out of the bottom of its card. (The chooser gets away without a cap because its own
		# desc scene squeezes wrapped lines with line_spacing = -30.)
		# -1 means "no limit". 0 means ZERO LINES — which is why the description vanished on
		# desktop. Only mobile needs a cap, to keep the row height predictable.
		ds.max_lines_visible = 2 if MainGlobals.is_mobile() else -1
		ds.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_child(ds)

	if _list.get_child_count() == 0:
		var none: Label = Label.new()
		none.text = "No tutorials are available yet."
		none.add_theme_font_size_override("font_size", _desc_fs())
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

# Each game gets a soft card of its own — a solid rounded background rather than a framed button.
# Enough to tell one row from the next at a glance, not enough to compete with the game names.
func _style_row(btn: Button) -> void:
	var base: StyleBoxFlat = StyleBoxFlat.new()
	# Light enough to tell one card from the next. At 0.06 the cards were almost invisible against
	# the panel on a phone.
	base.bg_color = Color(1, 1, 1, 0.13)
	base.set_corner_radius_all(12)
	base.content_margin_left = 8.0
	base.content_margin_right = 8.0
	base.content_margin_top = 4.0
	base.content_margin_bottom = 4.0
	var hi: StyleBoxFlat = base.duplicate() as StyleBoxFlat
	hi.bg_color = Color(1, 1, 1, 0.22)
	btn.add_theme_stylebox_override("normal", base)
	# On touch there is no pointer to move away, so Godot keeps the control "hovered" after the
	# finger lifts and the highlight stays painted on whichever row a swipe began on. Hover means
	# nothing on a phone anyway, so it is simply not highlighted there.
	btn.add_theme_stylebox_override("hover", hi if not MainGlobals.is_mobile() else base)
	btn.add_theme_stylebox_override("pressed", hi)
	btn.add_theme_stylebox_override("focus", base)
	btn.focus_mode = Control.FOCUS_NONE

func _apply_layout() -> void:
	var screen: Vector2 = Vector2(MainGlobals.screen_size)
	# Full screen width — no side gutters.
	_panel.custom_minimum_size = Vector2(screen.x, 0)
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Take as much height as the screen will give, so as many games fit at once as possible; the
	# list still scrolls if there are more than fit.
	_panel.custom_minimum_size.y = maxf(screen.y - 64.0, 240.0)

# Rows forward their drags here so the list can be scrolled by swiping over them. Touch events are
# emulated as mouse events (project.godot: emulate_touch_from_mouse), so handling the mouse pair
# covers finger and pointer alike.
func _on_row_gui_input(event: InputEvent, row: Button) -> void:
	if _scroll == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_active = true
			_drag_moved = false
			_drag_from_y = event.global_position.y
			_drag_scroll0 = float(_scroll.scroll_vertical)
		else:
			_drag_active = false
			# Drop any lingering highlight/focus from the row the swipe started on.
			row.release_focus()
	elif event is InputEventMouseMotion and _drag_active:
		var dy: float = event.global_position.y - _drag_from_y
		if absf(dy) >= _DRAG_SLOP:
			_drag_moved = true
		if _drag_moved:
			_scroll.scroll_vertical = int(_drag_scroll0 - dy)

func _on_row_pressed(folder: String) -> void:
	# A swipe ends with the button emitting `pressed` too; that must not launch a tutorial.
	if _drag_moved:
		_drag_moved = false
		return
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

class_name LevelPicker
extends RefCounted

# The row of small square buttons that picks which level a stats panel is showing.
#
# It began in typit's Keys tab and was then rebuilt by eye for the yes/no games' confusion
# matrix, which came out a different font at a different size in different colours — two
# controls doing the same job and looking unrelated. It is one thing now, and both call it.
#
# The only deliberate change from typit's original: an idle button used to be
# Color(0.16, 0.18, 0.26), near enough to the panel behind it that the levels you were not on
# read as empty space rather than as choices.

const SELECTED_BG: Color = Color(0.85, 0.65, 0.0, 1.0)
const IDLE_BG: Color = Color(0.27, 0.30, 0.39, 1.0)
const SELECTED_FG: Color = Color(0.08, 0.09, 0.12, 1.0)
const IDLE_FG: Color = Color(0.88, 0.91, 0.96, 1.0)
const TITLE_FG: Color = Color(1.0, 1.0, 1.0, 1.0)
const SEPARATION: int = 6

# The desktop size; MainGlobals scales it for a phone. Typit's selector was built from the same
# number by way of its own `fs_info`.
const FONT_DESKTOP: int = 15

static func font_size() -> int:
	return MainGlobals.ui_font_size(FONT_DESKTOP)

# `title` labels the row ("Level:"); `labels` is one short string per choice. `on_pick` is called
# with the INDEX of the button pressed — the caller knows what its own indices mean.
#
# Returns {"row": HBoxContainer, "buttons": Array}. Call `select()` to light one.
static func build(title: String, labels: Array, on_pick: Callable) -> Dictionary:
	var fs: int = font_size()
	var face: Font = MainGlobals.get_system_sans_font()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", SEPARATION)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	if title != "":
		var lbl: Label = Label.new()
		lbl.text = title
		lbl.add_theme_font_override("font", face)
		lbl.add_theme_font_size_override("font_size", fs)
		lbl.add_theme_color_override("font_color", TITLE_FG)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lbl)

	var buttons: Array = []
	for i in labels.size():
		var b: Button = Button.new()
		b.text = str(labels[i])
		# Sized from the type, so the row grows with it rather than being clipped by it.
		b.custom_minimum_size = Vector2(float(fs) * 2.4, float(fs) + 14.0)
		b.add_theme_font_override("font", face)
		b.add_theme_font_size_override("font_size", fs)
		var idx: int = i
		b.pressed.connect(func() -> void: on_pick.call(idx))
		row.add_child(b)
		buttons.append(b)
		style(b, false)
	return {"row": row, "buttons": buttons}

static func style(b: Button, on: bool) -> void:
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = SELECTED_BG if on else IDLE_BG
	st.corner_radius_top_left = 6
	st.corner_radius_top_right = 6
	st.corner_radius_bottom_left = 6
	st.corner_radius_bottom_right = 6
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", st)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", SELECTED_FG if on else IDLE_FG)
	b.add_theme_color_override("font_hover_color", SELECTED_FG if on else IDLE_FG)
	b.add_theme_color_override("font_pressed_color", SELECTED_FG if on else IDLE_FG)

# Light exactly one of them.
static func select(buttons: Array, chosen: int) -> void:
	for i in buttons.size():
		style(buttons[i], i == chosen)

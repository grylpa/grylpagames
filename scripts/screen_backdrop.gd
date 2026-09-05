extends RefCounted
class_name ScreenBackdrop

# The drawn ground under a full-screen screen — the main menu and the help screen so far. Both used
# to be the same tiled grass photo, which is why they looked like the same screen twice.
#
# A gradient, a pool of light at the top so the screen has a top rather than being evenly dark,
# slow dust so it is not a still image, and a vignette that settles the edges onto whatever card
# sits in the center. Nothing rotates and nothing loops in place.
#
# Each screen passes its OWN two colors. Telling them apart at a glance is the point: the menu is
# blue-slate, help is green — the hue the help screen has always had, minus the photo.

const MENU_TOP: Color = Color(0.114, 0.137, 0.204)
const MENU_BOT: Color = Color(0.043, 0.055, 0.086)
const HELP_TOP: Color = Color(0.086, 0.161, 0.145)
const HELP_BOT: Color = Color(0.031, 0.067, 0.059)
const INSTR_TOP: Color = Color(0.145, 0.125, 0.216)
const INSTR_BOT: Color = Color(0.055, 0.047, 0.094)
# The two card games' boards. Green, which is the color both have always had, minus the tiled photo.
const FRIENDS_TOP: Color = Color(0.075, 0.157, 0.106)
const FRIENDS_BOT: Color = Color(0.027, 0.063, 0.043)
const WERIS_TOP: Color = Color(0.106, 0.145, 0.086)
const WERIS_BOT: Color = Color(0.035, 0.063, 0.031)
const LOGIN_TOP: Color = Color(0.106, 0.114, 0.180)
const LOGIN_BOT: Color = Color(0.035, 0.043, 0.075)
const SCORES_TOP: Color = Color(0.098, 0.129, 0.176)
const SCORES_BOT: Color = Color(0.031, 0.051, 0.078)
const ACCENT: Color = Color(0.976, 0.792, 0.353)
# The hairline a tab's content is framed with -- and, inside that frame, the line that separates one
# section from the next. Defined once here because two files draw it: scores_list frames the panel,
# GameInstrument divides the Summary tab inside it. A separator in some unrelated grey reads as a
# seam where the panel was joined; in the frame's own colour it reads as part of the frame.
const PANEL_FRAME: Color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.45)

# --- the stats screens -----------------------------------------------------------------------
#
# The progress overlay, the baseline band's markers, the sparklines and the matrices all draw from
# here rather than each inventing a yellow of their own. The first pass did invent one — a bright
# Color(1, 0.72, 0.28) repeated across four files — which read as louder than anything else in the
# app and belonged to no palette. These are the warm and semantic colors the app already uses.
#
# STATS_MARK is deliberately a deeper ORANGE than ACCENT: it marks a session outside the player's
# usual range, and has to be tellable from the gold that frames the panel around it.
const STATS_MARK: Color = Color(0.949, 0.545, 0.235)      # the app's orange
const STATS_STEADY: Color = Color(0.243, 0.706, 0.400)    # the app's green
const STATS_HOT: Color = Color(0.878, 0.267, 0.271)       # the app's red, for a matrix's hottest cell
const STATS_QUIET: Color = Color(0.45, 0.47, 0.52)        # "not yet" — present, not shouting

# Attaches a drawn backdrop as `parent`'s first child and returns it. The caller advances `t` and
# calls queue_redraw(); keeping the clock outside means a hidden screen costs nothing.
static func attach(parent: Control) -> Control:
	var bg: Control = parent.get_node_or_null("Backdrop") as Control
	if bg == null:
		bg = Control.new()
		bg.name = "Backdrop"
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		parent.add_child(bg)
		parent.move_child(bg, 0)
	return bg

static func draw(bg: Control, t: float, top: Color, bot: Color, accent: Color) -> void:
	var w: float = bg.size.x
	var h: float = bg.size.y
	if w < 4.0 or h < 4.0:
		return
	bg.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([top, top, bot, bot]))

	var glow: Texture2D = MainGlobals.menu_glow_texture()
	if glow != null:
		var gw: float = w * 1.5
		bg.draw_texture_rect(glow, Rect2(w * 0.5 - gw * 0.5, -gw * 0.30, gw, gw * 0.75), false,
			Color(accent.r, accent.g, accent.b, 0.14))

	for i in 18:
		var seed_f: float = float(i) * 1.6180339
		var speed: float = 5.0 + fmod(seed_f * 31.0, 7.0)
		var y: float = h - fposmod(fmod(seed_f * 197.0, h) + t * speed, h)
		var x: float = fmod(seed_f * 389.0, w) + sin(t * 0.35 + seed_f * 5.0) * 18.0
		var a: float = 0.08 + 0.11 * (0.5 + 0.5 * sin(t * 0.6 + seed_f * 3.0))
		bg.draw_circle(Vector2(x, y), 1.7 + fmod(seed_f * 7.0, 1.9), Color(1, 1, 1, a))

	var vw: float = 120.0
	var dark: Color = Color(0.0, 0.0, 0.0, 0.30)
	var clear: Color = Color(0.0, 0.0, 0.0, 0.0)
	bg.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vw, 0), Vector2(vw, h), Vector2(0, h)]),
		PackedColorArray([dark, clear, clear, dark]))
	bg.draw_polygon(PackedVector2Array([Vector2(w - vw, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - vw, h)]),
		PackedColorArray([clear, dark, dark, clear]))
	bg.draw_polygon(PackedVector2Array([Vector2(0, h - vw * 1.4), Vector2(w, h - vw * 1.4), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([clear, clear, dark, dark]))

# The card that holds a screen's contents: a faint pane, not an outline on a photo.
static func card_style(radius: int = 24) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 1.0, 1.0, 0.045)
	sb.set_corner_radius_all(radius)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(1.0, 1.0, 1.0, 0.10)

	var vmar:float = 20.0
	var hmar:float = 20.0

	sb.content_margin_left = hmar
	sb.content_margin_top = vmar
	sb.content_margin_right = hmar
	sb.content_margin_bottom = vmar
	return sb

# ONE ROW of the stats look: a name, a sparkline, and a word for how it is going.
#
# Built here rather than in either screen because BOTH use it -- the global "Your progress" overlay,
# a row per category, and each game's Summary tab, a row per metric of that game. They are meant to
# read as the same thing at two zoom levels, and two copies of this would drift apart the first time
# one of them was adjusted.
#
# `values` are distances from the player's own baseline in units of their own spread, positive =
# better, whatever direction the underlying metric runs in. That is what lets one fixed scale serve
# every row, and it is why the band is the same height in all of them.
static func stats_row_cells(row_name: String, values: Array, state: int) -> Array:
	var name_lbl: Label = Label.new()
	name_lbl.text = row_name
	name_lbl.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(name_lbl, 15)

	var spark: Sparkline = Sparkline.new()
	# Width fixed; the HEIGHT is a minimum the caller may raise once it knows its own size, so
	# every row can be made exactly equal. Expanding here instead lets the container hand the
	# remainder out unevenly and the first row comes out a pixel taller than the rest.
	spark.custom_minimum_size = Vector2(MainGlobals.ui_font_size(150), MainGlobals.ui_font_size(40))
	spark.size_flags_vertical = Control.SIZE_FILL
	spark.set_values(values)
	# Every value is already a distance from a baseline in units of its own spread, so the band a
	# row should be sitting in is simply "near zero" -- the same for every row.
	spark.set_band(-StatsBaseline.BAND_SD, StatsBaseline.BAND_SD)
	spark.fixed_lo = -3.0
	spark.fixed_hi = 3.0

	var state_lbl: Label = Label.new()
	state_lbl.add_theme_font_override("font", MainGlobals.get_text_font())
	MainGlobals.set_font_size(state_lbl, 13)
	match state:
		StatsBaseline.State.WATCH:
			state_lbl.text = "watch"
			state_lbl.add_theme_color_override("font_color", STATS_MARK)
		StatsBaseline.State.STEADY:
			state_lbl.text = "steady"
			state_lbl.add_theme_color_override("font_color", STATS_STEADY)
		StatsBaseline.State.IMPROVING:
			state_lbl.text = "improving"
			state_lbl.add_theme_color_override("font_color", STATS_STEADY)
		_:
			state_lbl.text = "not yet"
			state_lbl.add_theme_color_override("font_color", STATS_QUIET)
	return [name_lbl, spark, state_lbl]


static func style_title(label: Label, accent: Color) -> void:
	label.add_theme_font_override("font", MainGlobals.get_text_font())
	label.add_theme_color_override("font_color", accent)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	label.add_theme_constant_override("outline_size", 6)


# --- widgets on a screen ---------------------------------------------------------------------
#
# A card and a title were enough while the only screens using this were the menu and help, which
# are lists of buttons. The login screen and the scores screen also have TEXT FIELDS and TABS, and
# both had their own hand-rolled versions — the login tabs drew a yellow 3px outline open at the
# bottom, the fields were flat near-black rectangles from the scene file. They are here so those
# two screens do not each invent one again.

# A text field: a recessed pane, and the accent only when it has focus. The ring is what says
# "typing goes here", so nothing else on the screen may wear it.
static func style_field(le: LineEdit, accent: Color) -> void:
	le.add_theme_font_override("font", MainGlobals.get_text_font())
	le.add_theme_color_override("font_color", Color(0.929, 0.941, 0.969))
	le.add_theme_color_override("font_placeholder_color", Color(0.929, 0.941, 0.969, 0.38))
	le.add_theme_color_override("caret_color", accent)
	le.add_theme_color_override("selection_color", Color(accent.r, accent.g, accent.b, 0.30))
	for state in ["normal", "focus", "read_only"]:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(0.0, 0.0, 0.0, 0.32)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 16.0
		sb.content_margin_right = 16.0
		sb.content_margin_top = 12.0
		sb.content_margin_bottom = 12.0
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(accent.r, accent.g, accent.b, 0.85) if state == "focus" \
			else Color(1.0, 1.0, 1.0, 0.12)
		le.add_theme_stylebox_override(state, sb)

# A tab: a pill that is FILLED when it is the one you are on and flat when it is not. The old login
# tabs were an outline open at the bottom, which is a shape that only works when the thing below it
# is a panel with the same border — and it was not.
static func style_tab(btn: Button, accent: Color, active: bool) -> void:
	btn.add_theme_font_override("font", MainGlobals.get_text_font())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, Color(0.153, 0.118, 0.043) if active else Color(0.929, 0.941, 0.969, 0.72))
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		if active:
			sb.bg_color = accent.darkened(0.10) if state == "pressed" else accent
		else:
			sb.bg_color = Color(1.0, 1.0, 1.0, 0.10 if state in ["hover", "pressed"] else 0.045)
		sb.set_corner_radius_all(14)
		sb.content_margin_top = 12.0
		sb.content_margin_bottom = 12.0
		sb.content_margin_left = 14.0
		sb.content_margin_right = 14.0
		btn.add_theme_stylebox_override(state, sb)

# A label that is a caption over a field, or a line of small print. Both are the same face at the
# same size; only the weight of the color differs.
static func style_caption(label: Label, muted: bool = false) -> void:
	label.add_theme_font_override("font", MainGlobals.get_text_font())
	label.add_theme_color_override("font_color",
		Color(0.929, 0.941, 0.969, 0.60) if muted else Color(0.929, 0.941, 0.969))
	label.add_theme_constant_override("outline_size", 0)

# The close X wears the SCREEN TITLE's color. It is the other end of the same header — a title in
# the app's accent beside an X in a slightly different yellow is two decisions where there should
# be one, and every screen had picked its own: (1,1,0), (0.835,0.863,0), (1,1,0.02).
static func style_close(x_close: Node, accent: Color) -> void:
	if x_close == null or not is_instance_valid(x_close):
		return
	x_close.icon_color = accent
	x_close.text_color = accent

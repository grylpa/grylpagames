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
const ACCENT: Color = Color(0.976, 0.792, 0.353)

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

static func style_title(label: Label, accent: Color) -> void:
	label.add_theme_font_override("font", MainGlobals.get_text_font())
	label.add_theme_color_override("font_color", accent)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	label.add_theme_constant_override("outline_size", 6)

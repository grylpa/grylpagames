extends RefCounted
class_name GameButton

# The app's button, in the same language as the dialog buttons (scripts/result_card.gd): a flat
# filled rounded rectangle, one shade darker while held, no border, no shadow, no movement.
#
# It was a drawn "3D" face standing on a base, sinking 7px when pressed. Two things were wrong with
# that beyond the dated look:
#
#  - **7px is a lurch.** A press should be acknowledged, not animated.
#  - **It could not stay in sync.** The LABEL is positioned by Godot's stylebox state, which
#    reverts to `normal` the moment the pointer leaves a held button; the drawn face followed
#    `button_down`, which does not fire again until release. Press, drag off, and the text rose
#    while the face stayed down. Any custom drawing that has to track the button's own press state
#    has this bug available to it; a stylebox that only changes COLOR cannot.
#
# So the states differ in fill alone, and the content margins are identical across all of them —
# which is what guarantees the label never moves.

const CORNER: int = 16
const MARGIN_V: float = 14.0
const MARGIN_H: float = 26.0

# ONE size for the primary button in every game, so START in dino and START in Moving Cards are
# the same object. The width follows the guideline "taxi's NEW GAME spans two thirds of the
# screen"; the font is what looks right inside that, NOT what fills it — "NEW GAME" at 71 exactly
# fills the text room and is jammed against the padding. At 60 it is 325 wide, 72% of the button,
# with 64px of air each side.
const PRIMARY_WIDTH_FRAC: float = 2.0 / 3.0
const PRIMARY_FONT: int = 60
const PRIMARY_HEIGHT: float = 126.0

# Continue is the same button one step down — narrower and set smaller, so that in taxi, where the
# two sit together, NEW GAME is unmistakably the louder of them.
const CONTINUE_WIDTH_FRAC: float = 0.78
const CONTINUE_FONT: int = 36
const CONTINUE_HEIGHT: float = 92.0

const SECONDARY_FONT: int = 30

static func primary_size() -> Vector2:
	return Vector2(float(MainGlobals.screen_size.x) * PRIMARY_WIDTH_FRAC, PRIMARY_HEIGHT)

static func continue_size() -> Vector2:
	return Vector2(primary_size().x * CONTINUE_WIDTH_FRAC, CONTINUE_HEIGHT)

static func style(btn: Button, face: Color, ink: Color, font_size: int, ghost: bool = false) -> void:
	btn.add_theme_font_override("font", MainGlobals.get_text_font())
	btn.add_theme_font_size_override("font_size", font_size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, face if ghost else ink)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = face
		if ghost:
			sb.bg_color = Color(face.r, face.g, face.b, 0.10 if state == "pressed" else 0.0)
			sb.border_width_left = 2
			sb.border_width_top = 2
			sb.border_width_right = 2
			sb.border_width_bottom = 2
			sb.border_color = Color(face.r, face.g, face.b, 0.75)
		elif state == "pressed":
			sb.bg_color = face.darkened(0.16)
		elif state == "hover":
			sb.bg_color = face.lightened(0.10)
		sb.set_corner_radius_all(CORNER)
		# Identical in every state. This is the line that keeps the label still.
		sb.content_margin_top = MARGIN_V
		sb.content_margin_bottom = MARGIN_V
		sb.content_margin_left = MARGIN_H
		sb.content_margin_right = MARGIN_H
		btn.add_theme_stylebox_override(state, sb)
	# a button restyled from an older drawn version leaves its face behind
	var stale: Node = btn.get_node_or_null("GameButtonFace")
	if stale != null:
		stale.queue_free()

# A slow heartbeat for the one button the player is meant to press.
#
# It breathes a GLOW behind the button, and never the button itself. Scaling a Control
# re-rasterizes its text every frame at a fractional size, so the letters crawl along their
# outlines — the shimmer is the glyph rasterizer, not the tween. Fading a texture is smooth at any
# size, and it leaves the button flat and still.
#
# Bound to the button, so it dies with it: a looping tween made on the scene root outlives the
# screen it animates.
static func pulse(btn: Button, face: Color) -> Tween:
	btn.scale = Vector2.ONE
	var halo: Control = btn.get_node_or_null("GameButtonGlow") as Control
	if halo == null:
		halo = Control.new()
		halo.name = "GameButtonGlow"
		halo.show_behind_parent = true
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		halo.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.add_child(halo)
	for c in halo.draw.get_connections():
		halo.draw.disconnect(c["callable"])
	halo.draw.connect(func() -> void: _draw_glow(halo, btn, face))
	var t: Tween = btn.create_tween()
	t.set_loops()
	for target in [1.0, 0.0]:
		t.tween_method(func(v: float) -> void:
			btn.set_meta("gb_glow", v)
			if is_instance_valid(halo):
				halo.queue_redraw(),
			1.0 - target, target, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return t

static func _draw_glow(halo: Control, btn: Button, face: Color) -> void:
	var glow: float = float(btn.get_meta("gb_glow", 0.0))
	if glow <= 0.001:
		return
	var tex: Texture2D = MainGlobals.menu_glow_texture()
	if tex == null:
		return
	var pad: float = 24.0 + 10.0 * glow
	halo.draw_texture_rect(tex,
		Rect2(-pad, -pad * 0.6, halo.size.x + pad * 2.0, halo.size.y + pad * 1.2), false,
		Color(face.r, face.g, face.b, 0.08 + 0.14 * glow))

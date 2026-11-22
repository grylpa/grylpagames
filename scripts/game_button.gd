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

# What makes a flat button inviting is LIGHT and ATTENTION, not elevation. Three things, all
# behind the button, so the button itself stays flat and perfectly still:
#
#   glow    a soft halo breathing under it — the button looks lit rather than raised
#   rim     a hairline of its own color just outside the edge, breathing with the glow
#   ripple  every few seconds one ring travels outward and fades, the way a notification asks
#           to be looked at. One ring, not a loop of them.
#
# Everything is drawn OUTSIDE the button's rect, which also means none of it has to be clipped to
# the rounded corners — a sweep across the face would, and would show square corners doing it.
const _RIPPLE_PERIOD: float = 3.6
const _RIPPLE_LIFE: float = 1.15

static func _draw_glow(halo: Control, btn: Button, face: Color) -> void:
	var w: float = halo.size.x
	var h: float = halo.size.y
	if w < 8.0 or h < 8.0:
		return
	var glow: float = float(btn.get_meta("gb_glow", 0.0))
	var tex: Texture2D = MainGlobals.menu_glow_texture()
	if tex != null and glow > 0.001:
		var pad: float = 24.0 + 10.0 * glow
		halo.draw_texture_rect(tex, Rect2(-pad, -pad * 0.6, w + pad * 2.0, h + pad * 1.2), false,
			Color(face.r, face.g, face.b, 0.08 + 0.14 * glow))

	var rim: StyleBoxFlat = StyleBoxFlat.new()
	rim.bg_color = Color(0, 0, 0, 0)
	rim.set_corner_radius_all(CORNER + 3)
	rim.border_width_left = 2
	rim.border_width_top = 2
	rim.border_width_right = 2
	rim.border_width_bottom = 2
	rim.border_color = Color(face.r, face.g, face.b, 0.16 + 0.20 * glow)
	halo.draw_style_box(rim, Rect2(-3.0, -3.0, w + 6.0, h + 6.0))

	var t: float = fposmod(float(Time.get_ticks_msec()) / 1000.0, _RIPPLE_PERIOD)
	if t < _RIPPLE_LIFE:
		var k: float = t / _RIPPLE_LIFE
		var spread: float = 4.0 + k * 20.0
		var ring: StyleBoxFlat = StyleBoxFlat.new()
		ring.bg_color = Color(0, 0, 0, 0)
		ring.set_corner_radius_all(CORNER + int(spread))
		ring.border_width_left = 2
		ring.border_width_top = 2
		ring.border_width_right = 2
		ring.border_width_bottom = 2
		# fades as it travels, so the last thing the eye sees is it leaving
		ring.border_color = Color(face.r, face.g, face.b, 0.34 * (1.0 - k) * (1.0 - k))
		halo.draw_style_box(ring, Rect2(-spread, -spread, w + spread * 2.0, h + spread * 2.0))

# THE BECKON (2026-11-22): a button that must be pressed NOW -- the menu's "How to play" for a game whose tutorial the
# player has not seen (main_menu.gd `_beckon`). A first run used to start the tutorial on its own; now the poster comes
# first and this button calls for it -- with LIGHT, never motion: FILLED in the face color, its words set larger
# (`font_size`, 0 keeps them), a warm glow breathing round it, every BECKON_PERIOD a soft band of light SWEEPING across
# its face (a canvas shader on the button, so it follows the rounded corners and crosses the words) with one ripple
# leaving, and a few small sparkles twinkling round its edges, each at its own pace. The button never moves.
# (Tuned with the user: a cartoon-phone RATTLE, fast or slow, with or without rests, was "way too nervous"; they asked
# for something "very very noticeable but also nice to see".) `stop_beckon` puts the button back exactly as it was.
const BECKON_PERIOD: float = 2.6
const _SHINE_TIME: float = 0.95         # the sweep's crossing, at the start of each period
const _BECKON_RIPPLE_LIFE: float = 1.6
# sparkles round the edge: x as a share of the width (<0 / >1: off the ends), y as a share of the height, size,
# twinkle rate (per second) and phase
const _SPARKLES: Array = [[-0.04, 0.05, 1.0, 0.55, 0.0], [0.22, -0.30, 0.8, 0.48, 0.35], [0.70, -0.26, 1.1, 0.62, 0.7],
	[1.05, 0.25, 0.9, 0.51, 0.15], [0.86, 1.28, 0.8, 0.58, 0.55], [0.12, 1.24, 0.9, 0.45, 0.85]]

const _SHINE_SHADER: String = """
shader_type canvas_item;
// a band of light across the button's face, its place `sweep` (0..1 across; outside: none). Applied to whatever the
// button draws -- its rounded face and its words -- so it never shows past the corners.
uniform float sweep = -1.0;
uniform vec2 box = vec2(200.0, 60.0);
varying vec2 lp;
void vertex() {
	lp = VERTEX;
}
void fragment() {
	vec4 c = COLOR;
	float x = lp.x + (box.y - lp.y) * 0.45;
	float center = mix(-box.y, box.x + box.y, sweep);
	float w = box.y * 0.70;
	float band = 1.0 - smoothstep(0.0, w, abs(x - center));
	float core = 1.0 - smoothstep(0.0, w * 0.25, abs(x - center));
	c.rgb = mix(c.rgb, vec3(1.0, 0.98, 0.90), clamp(band * 0.55 + core * 0.40, 0.0, 1.0));
	COLOR = c;
}
"""
static var _shine: Shader = null

static func beckon(btn: Button, face: Color, ink: Color, font_size: int = 0) -> void:
	if btn.has_meta("gb_beckon_tween"):
		return
	# the outlined look, kept to be put back
	var saved: Dictionary = {}
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb: StyleBox = btn.get_theme_stylebox(st)
		saved[st] = sb
		var filled: StyleBoxFlat = (sb as StyleBoxFlat).duplicate() as StyleBoxFlat if sb is StyleBoxFlat \
				else StyleBoxFlat.new()
		filled.draw_center = true
		filled.bg_color = face.darkened(0.12) if st == "pressed" else (face.lightened(0.08) if st == "hover" else face)
		filled.border_color = face.lightened(0.35)
		btn.add_theme_stylebox_override(st, filled)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		saved[c] = btn.get_theme_color(c)
		btn.add_theme_color_override(c, ink)
	if font_size > 0:
		saved["font_size"] = btn.get_theme_font_size("font_size")
		btn.add_theme_font_size_override("font_size", font_size)
	btn.set_meta("gb_beckon_saved", saved)
	btn.set_meta("gb_beckon_material", btn.material)
	if _shine == null:
		_shine = Shader.new()
		_shine.code = _SHINE_SHADER
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _shine
	btn.material = mat
	var halo: Control = Control.new()
	halo.name = "GameButtonBeckon"
	halo.show_behind_parent = true
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_child(halo)
	halo.draw.connect(func() -> void: _draw_beckon(halo, btn, face))
	var t: Tween = btn.create_tween()
	t.set_loops()
	t.tween_method(func(v: float) -> void: _beckon_frame(btn, halo, mat, v), 0.0, BECKON_PERIOD, BECKON_PERIOD)
	btn.set_meta("gb_beckon_tween", t)

static func stop_beckon(btn: Button) -> void:
	if not btn.has_meta("gb_beckon_tween"):
		return
	var t: Tween = btn.get_meta("gb_beckon_tween") as Tween
	if t != null and t.is_valid():
		t.kill()
	btn.remove_meta("gb_beckon_tween")
	var saved: Dictionary = btn.get_meta("gb_beckon_saved", {})
	btn.remove_meta("gb_beckon_saved")
	for k in saved.keys():
		if String(k) == "font_size":
			btn.add_theme_font_size_override("font_size", int(saved[k]))
		elif saved[k] is StyleBox:
			btn.add_theme_stylebox_override(String(k), saved[k] as StyleBox)
		else:
			btn.add_theme_color_override(String(k), saved[k] as Color)
	btn.material = btn.get_meta("gb_beckon_material", null) as Material
	btn.remove_meta("gb_beckon_material")
	var halo: Node = btn.get_node_or_null("GameButtonBeckon")
	if halo != null:
		halo.queue_free()

static func _beckon_frame(btn: Button, halo: Control, mat: ShaderMaterial, t: float) -> void:
	if not is_instance_valid(btn):
		return
	var k: float = t / _SHINE_TIME
	# eased, so the light slows a little as it enters and leaves
	mat.set_shader_parameter("sweep", smoothstep(0.0, 1.0, k) if k <= 1.0 else -1.0)
	mat.set_shader_parameter("box", btn.size)
	btn.set_meta("gb_beckon_t", t)
	if is_instance_valid(halo):
		halo.queue_redraw()

static func _draw_beckon(halo: Control, btn: Button, face: Color) -> void:
	var w: float = halo.size.x
	var h: float = halo.size.y
	if w < 8.0 or h < 8.0:
		return
	var t: float = float(btn.get_meta("gb_beckon_t", 0.0))
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	# the glow, breathing slowly (one breath a period), brightest as the light crosses
	var breath: float = 0.5 + 0.5 * cos(TAU * t / BECKON_PERIOD)
	var tex: Texture2D = MainGlobals.menu_glow_texture()
	if tex != null:
		var pad: float = 42.0 + 16.0 * breath
		var lit: Color = face.lightened(0.25)
		halo.draw_texture_rect(tex, Rect2(-pad, -pad * 0.8, w + pad * 2.0, h + pad * 1.6), false,
			Color(lit.r, lit.g, lit.b, 0.45 + 0.40 * breath))
	# and a halo hugging its rounded outline (a stylebox's soft shadow, in gold), breathing with it
	var aura: StyleBoxFlat = StyleBoxFlat.new()
	aura.bg_color = Color(face.r, face.g, face.b, 0.0)
	aura.set_corner_radius_all(CORNER)
	aura.shadow_color = Color(face.r, face.g, face.b, 0.40 + 0.30 * breath)
	aura.shadow_size = int(14.0 + 10.0 * breath)
	halo.draw_style_box(aura, Rect2(0.0, 0.0, w, h))
	# one soft ripple leaves with each sweep
	if t < _BECKON_RIPPLE_LIFE:
		var k: float = t / _BECKON_RIPPLE_LIFE
		var spread: float = 3.0 + (1.0 - (1.0 - k) * (1.0 - k)) * 30.0      # slowing as it goes
		var rsb: StyleBoxFlat = StyleBoxFlat.new()
		rsb.bg_color = Color(0, 0, 0, 0)
		rsb.set_corner_radius_all(CORNER + int(spread))
		rsb.border_width_left = 2
		rsb.border_width_top = 2
		rsb.border_width_right = 2
		rsb.border_width_bottom = 2
		var rc: Color = face.lightened(0.35)
		rsb.border_color = Color(rc.r, rc.g, rc.b, 0.7 * (1.0 - k) * (1.0 - k))
		halo.draw_style_box(rsb, Rect2(-spread, -spread, w + spread * 2.0, h + spread * 2.0))
	# the sparkles: each a four-pointed star with a soft glint, coming and going at its own pace
	var unit: float = clampf(h * 0.28, 8.0, 18.0)
	for sp in _SPARKLES:
		var a: float = sin(TAU * (now * float(sp[3]) + float(sp[4])))
		if a <= 0.0:
			continue
		a = a * a
		var c: Vector2 = Vector2(float(sp[0]) * w, float(sp[1]) * h)
		var r: float = unit * float(sp[2]) * (0.6 + 0.4 * a)
		var col: Color = Color(1.0, 0.97, 0.86, a)
		if tex != null:
			halo.draw_texture_rect(tex, Rect2(c - Vector2(r, r) * 1.6, Vector2(r, r) * 3.2), false,
				Color(face.r, face.g, face.b, 0.55 * a))
		var pts: PackedVector2Array = PackedVector2Array()
		for j in 8:
			var ang: float = float(j) * PI / 4.0 + 0.0
			var rr: float = r if j % 2 == 0 else r * 0.22
			pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
		halo.draw_colored_polygon(pts, col)
